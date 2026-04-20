/**
 * Supabase Edge Function: `maint-notify-dispatch`
 *
 * Batch dispatch worker za outbox `public.maint_notification_log`.
 * Namenjen da ga pokreće Supabase Scheduled Trigger (npr. svakog minuta).
 *
 * Tok:
 *   1) Zove RPC `maint_dispatch_dequeue(batch_size, max_attempts)`
 *      koji lock-uje batch `FOR UPDATE SKIP LOCKED` i inkrementuje `attempts`.
 *   2) Za svaki red:
 *      • Ako je "stub" red (recipient = 'pending' i recipient_user_id IS NULL)
 *        — poziva RPC `maint_dispatch_fanout(parent_id)` koji raspisuje na
 *        konkretne primaoce iz `maint_user_profiles`, i parent mark-uje `sent`.
 *      • Inače — šalje poruku preko odgovarajućeg kanala.
 *        - `whatsapp` + `WA_ACCESS_TOKEN` + `WA_PHONE_NUMBER_ID` → Meta Graph API.
 *        - inače → DRY-RUN (log u console i `mark_sent`).
 *   3) Uspeh → `maint_dispatch_mark_sent(ids)`.
 *      Neuspeh → `maint_dispatch_mark_failed(id, err, backoff_sec)` (exp backoff).
 *
 * Env varijable (Supabase Secrets):
 *   - SUPABASE_URL              (auto)
 *   - SUPABASE_SERVICE_ROLE_KEY (auto, neophodno za SECURITY DEFINER RPC-ove)
 *   - WA_ACCESS_TOKEN           (opciono; bez njega radi DRY-RUN)
 *   - WA_PHONE_NUMBER_ID        (opciono; Meta phone_number_id)
 *   - WA_TEMPLATE_NAME          (opciono; npr. "incident_alert_sr")
 *   - WA_TEMPLATE_LANG          (opciono; npr. "sr")
 *   - MAINT_DISPATCH_BATCH      (opciono, default 25)
 *
 * Deploy: `supabase functions deploy maint-notify-dispatch --no-verify-jwt`
 *   (funkcija je zaštićena service_role ključem preko cron-a; JWT nije potreban).
 */

// deno-lint-ignore-file no-explicit-any
// @ts-ignore Deno runtime
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';

type NotificationRow = {
  id: string;
  channel: 'telegram' | 'email' | 'in_app' | 'whatsapp';
  recipient: string;
  recipient_user_id: string | null;
  subject: string | null;
  body: string;
  related_entity_type: string | null;
  related_entity_id: string | null;
  machine_code: string | null;
  escalation_level: number;
  attempts: number;
  payload: Record<string, unknown> | null;
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const WA_ACCESS_TOKEN = Deno.env.get('WA_ACCESS_TOKEN') ?? '';
const WA_PHONE_NUMBER_ID = Deno.env.get('WA_PHONE_NUMBER_ID') ?? '';
const WA_TEMPLATE_NAME = Deno.env.get('WA_TEMPLATE_NAME') ?? '';
const WA_TEMPLATE_LANG = Deno.env.get('WA_TEMPLATE_LANG') ?? 'sr';
const BATCH = Number(Deno.env.get('MAINT_DISPATCH_BATCH') ?? '25') || 25;
const MAX_ATTEMPTS = 8;

if (!SUPABASE_URL || !SERVICE_ROLE) {
  console.error('[maint-dispatch] Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY');
}

async function rpc<T = unknown>(fn: string, args: Record<string, unknown>): Promise<T | null> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SERVICE_ROLE,
      Authorization: `Bearer ${SERVICE_ROLE}`,
      Prefer: 'return=representation',
    },
    body: JSON.stringify(args),
  });
  if (!res.ok) {
    console.error(`[rpc ${fn}] ${res.status} ${await res.text()}`);
    return null;
  }
  const txt = await res.text();
  if (!txt) return null;
  try {
    return JSON.parse(txt) as T;
  } catch {
    return null;
  }
}

function backoffSeconds(attempts: number): number {
  /* 30s, 60s, 2m, 4m, 8m, 16m, 32m, 64m */
  return Math.min(30 * Math.pow(2, Math.max(0, attempts - 1)), 60 * 60);
}

async function sendWhatsAppTemplate(row: NotificationRow): Promise<{ ok: true } | { ok: false; error: string }> {
  if (!WA_ACCESS_TOKEN || !WA_PHONE_NUMBER_ID || !WA_TEMPLATE_NAME) {
    /* DRY-RUN: bez pravog slanja, uspešno. */
    console.log('[DRY-RUN whatsapp]', row.recipient, row.subject, '::', row.body);
    return { ok: true };
  }
  const payload = {
    messaging_product: 'whatsapp',
    to: row.recipient,
    type: 'template',
    template: {
      name: WA_TEMPLATE_NAME,
      language: { code: WA_TEMPLATE_LANG },
      components: [
        {
          type: 'body',
          parameters: [
            { type: 'text', text: row.subject ?? '' },
            { type: 'text', text: row.body ?? '' },
          ],
        },
      ],
    },
  };
  const res = await fetch(`https://graph.facebook.com/v20.0/${WA_PHONE_NUMBER_ID}/messages`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${WA_ACCESS_TOKEN}`,
    },
    body: JSON.stringify(payload),
  });
  if (res.ok) return { ok: true };
  const errText = await res.text();
  return { ok: false, error: `WA ${res.status}: ${errText.slice(0, 800)}` };
}

async function dispatchOne(row: NotificationRow): Promise<{ ok: boolean; error?: string }> {
  /* Stub red (fan-out pending): recipient='pending' && recipient_user_id IS NULL */
  if (row.recipient === 'pending' && !row.recipient_user_id) {
    const children = await rpc<number>('maint_dispatch_fanout', { p_parent_id: row.id });
    console.log(`[fanout] ${row.id} → ${children} children`);
    /* Parent je unutar fanout funkcije već obeležen kao 'sent'; worker neće pozvati mark_sent. */
    return { ok: true };
  }

  if (row.channel === 'whatsapp') {
    return await sendWhatsAppTemplate(row);
  }

  if (row.channel === 'email' || row.channel === 'telegram' || row.channel === 'in_app') {
    /* Kanali koji nisu implementirani u workeru — za sada DRY-RUN mark-sent da ne blokiraju queue. */
    console.log(`[DRY-RUN ${row.channel}]`, row.recipient, row.subject, '::', row.body);
    return { ok: true };
  }

  return { ok: false, error: `Unsupported channel: ${row.channel}` };
}

async function runBatch() {
  const batch = await rpc<NotificationRow[]>('maint_dispatch_dequeue', {
    p_batch_size: BATCH,
    p_max_attempts: MAX_ATTEMPTS,
  });
  if (!batch || batch.length === 0) {
    return { processed: 0, sent: 0, failed: 0 };
  }
  const sentIds: string[] = [];
  let failed = 0;
  /* Stub redovi su već mark-ovani kroz fanout — ne dodajemo ih u sentIds. */
  const fanoutIds = new Set<string>();
  for (const row of batch) {
    if (row.recipient === 'pending' && !row.recipient_user_id) {
      fanoutIds.add(row.id);
    }
  }

  for (const row of batch) {
    try {
      const res = await dispatchOne(row);
      if (res.ok) {
        if (!fanoutIds.has(row.id)) sentIds.push(row.id);
      } else {
        failed++;
        await rpc('maint_dispatch_mark_failed', {
          p_id: row.id,
          p_error: res.error ?? 'unknown',
          p_backoff_sec: backoffSeconds(row.attempts + 1),
        });
      }
    } catch (e) {
      failed++;
      await rpc('maint_dispatch_mark_failed', {
        p_id: row.id,
        p_error: String(e).slice(0, 900),
        p_backoff_sec: backoffSeconds(row.attempts + 1),
      });
    }
  }

  if (sentIds.length) {
    await rpc('maint_dispatch_mark_sent', { p_ids: sentIds });
  }

  return { processed: batch.length, sent: sentIds.length, failed, fanouts: fanoutIds.size };
}

serve(async req => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return new Response('Method Not Allowed', { status: 405 });
  }
  try {
    const result = await runBatch();
    return new Response(JSON.stringify({ ok: true, ...result }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  } catch (e) {
    console.error('[maint-dispatch] fatal', e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { 'content-type': 'application/json' },
    });
  }
});
