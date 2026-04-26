/**
 * Supabase Edge Function: `sastanci-notify-dispatch`
 *
 * Batch dispatch worker za outbox `public.sastanci_notification_log`.
 * Pokreće ga Supabase Scheduled Trigger (svakih 2–5 min) ili ručno.
 *
 * Tok:
 *   1) `sastanci_dispatch_dequeue(batch)` — lock-uje batch SKIP LOCKED.
 *   2) Za svaki red:
 *      • channel = 'whatsapp' → permanent fail (nije implementiran u Fazi C).
 *      • channel = 'email'    → Resend API; DRY-RUN ako nema RESEND_API_KEY.
 *   3) Mark sent (batch) / failed (exponential backoff).
 *
 * Env varijable (Supabase Secrets):
 *   SUPABASE_URL                 (auto)
 *   SUPABASE_SERVICE_ROLE_KEY    (auto)
 *   RESEND_API_KEY               (opciono; bez njega → DRY-RUN)
 *   RESEND_FROM                  (default: noreply@servoteh.rs)
 *   VITE_PUBLIC_APP_URL          (default: https://servoteh-plan-montaze.pages.dev/)
 *   SAST_DISPATCH_BATCH          (default: 25)
 *
 * Deploy:
 *   supabase functions deploy sastanci-notify-dispatch --no-verify-jwt
 */

// deno-lint-ignore-file no-explicit-any
// @ts-ignore Deno runtime
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { buildEmailFor } from './templates.ts';

// ── Env vars ──────────────────────────────────────────────────────────────────

const SUPABASE_URL  = Deno.env.get('SUPABASE_URL')              ?? '';
const SERVICE_ROLE  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const RESEND_KEY    = Deno.env.get('RESEND_API_KEY')            ?? '';
const RESEND_FROM   = Deno.env.get('RESEND_FROM')               ?? 'noreply@servoteh.rs';
const APP_URL       = (Deno.env.get('VITE_PUBLIC_APP_URL')      ?? 'https://servoteh-plan-montaze.pages.dev/').replace(/\/?$/, '/');
const BATCH         = Number(Deno.env.get('SAST_DISPATCH_BATCH') ?? '25') || 25;
const MAX_ATTEMPTS  = 5;
const AUDIT_ACTOR   = 'sastanci-notify-dispatch@edge.servoteh';

if (!SUPABASE_URL || !SERVICE_ROLE) {
  console.error('[sast-dispatch] SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY nisu postavljeni');
}

// ── Tipovi ────────────────────────────────────────────────────────────────────

type NotifRow = {
  id: string;
  kind: string;
  channel: 'email' | 'whatsapp';
  recipient_email: string;
  recipient_label: string | null;
  subject: string;
  body_html: string | null;
  body_text: string | null;
  related_sastanak_id: string | null;
  related_akcija_id: string | null;
  attempts: number;
  payload: Record<string, unknown> | null;
};

// ── RPC helper (svi pozivi nose X-Audit-Actor) ────────────────────────────────

async function rpc<T = unknown>(fn: string, args: Record<string, unknown>): Promise<T | null> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      'Content-Type':  'application/json',
      'apikey':        SERVICE_ROLE,
      'Authorization': `Bearer ${SERVICE_ROLE}`,
      'X-Audit-Actor': AUDIT_ACTOR,
      'Prefer':        'return=representation',
    },
    body: JSON.stringify(args),
  });

  if (!res.ok) {
    console.error(`[rpc ${fn}] ${res.status}`, await res.text());
    return null;
  }

  const txt = await res.text();
  if (!txt) return null;
  try { return JSON.parse(txt) as T; } catch { return null; }
}

// ── Backoff ───────────────────────────────────────────────────────────────────

function backoffSec(attempts: number): number {
  // 5 min → 10 min → 20 min → 40 min → 80 min, cap 6h
  return Math.min(300 * Math.pow(2, Math.max(0, attempts - 1)), 6 * 60 * 60);
}

// ── Dispatchers ───────────────────────────────────────────────────────────────

type DispatchResult = { ok: true } | { ok: false; error: string; permanent?: boolean };

async function dispatchWhatsApp(_row: NotifRow): Promise<DispatchResult> {
  // WhatsApp nije implementiran u Fazi C — permanent fail (nema retry)
  return {
    ok: false,
    error: 'WhatsApp not enabled in this version (Faza C)',
    permanent: true,
  };
}

async function dispatchEmail(row: NotifRow): Promise<DispatchResult> {
  const content = buildEmailFor(row.kind, row.payload, APP_URL);

  const subject  = content.subject  || row.subject;
  const bodyHtml = content.html     || row.body_html || '';
  const bodyText = content.text     || row.body_text || '';
  const to       = row.recipient_email;

  if (!RESEND_KEY) {
    console.log('[DRY-RUN email]', { to, subject, kind: row.kind });
    return { ok: true };
  }

  const payload: Record<string, unknown> = {
    from:    RESEND_FROM,
    to:      [to],
    subject,
    html:    bodyHtml,
    text:    bodyText,
  };

  if (content.replyTo) {
    payload['reply_to'] = content.replyTo;
  }

  let res: Response;
  try {
    res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type':  'application/json',
        'Authorization': `Bearer ${RESEND_KEY}`,
      },
      body: JSON.stringify(payload),
    });
  } catch (e) {
    // Network error — transient, retry
    return { ok: false, error: `Network: ${String(e).slice(0, 400)}` };
  }

  if (res.ok) return { ok: true };

  const body = (await res.text()).slice(0, 800);

  // 4xx → permanent (pogrešan API key, invalid email itd.)
  if (res.status >= 400 && res.status < 500) {
    return { ok: false, error: `Resend ${res.status}: ${body}`, permanent: true };
  }

  // 5xx → transient, retry
  return { ok: false, error: `Resend ${res.status}: ${body}` };
}

async function dispatchOne(row: NotifRow): Promise<DispatchResult> {
  if (row.channel === 'whatsapp') return await dispatchWhatsApp(row);
  if (row.channel === 'email')    return await dispatchEmail(row);

  console.log(`[DRY-RUN ${row.channel}]`, row.recipient_email, '::', row.kind);
  return { ok: true };
}

// ── Batch ─────────────────────────────────────────────────────────────────────

async function runBatch(): Promise<{ processed: number; sent: number; failed: number; skipped_wa: number }> {
  const batch = await rpc<NotifRow[]>('sastanci_dispatch_dequeue', {
    p_batch_size:   BATCH,
    p_max_attempts: MAX_ATTEMPTS,
  });

  if (!batch || batch.length === 0) {
    return { processed: 0, sent: 0, failed: 0, skipped_wa: 0 };
  }

  const sentIds: string[] = [];
  let failed    = 0;
  let skippedWa = 0;

  for (const row of batch) {
    try {
      const result = await dispatchOne(row);

      if (result.ok) {
        sentIds.push(row.id);
        continue;
      }

      failed++;

      if (result.permanent || row.channel === 'whatsapp') {
        skippedWa += row.channel === 'whatsapp' ? 1 : 0;
        // Permanent fail: postavi next_attempt_at daleko u budućnost
        // (dequeue neće uzeti kad attempts >= max_attempts)
        await rpc('sastanci_dispatch_mark_failed', {
          p_id:         row.id,
          p_error:      result.error,
          p_backoff_sec: 365 * 24 * 3600, // efektivno bez retry-a
        });
      } else {
        await rpc('sastanci_dispatch_mark_failed', {
          p_id:         row.id,
          p_error:      result.error,
          p_backoff_sec: backoffSec(row.attempts + 1),
        });
      }
    } catch (e) {
      failed++;
      await rpc('sastanci_dispatch_mark_failed', {
        p_id:         row.id,
        p_error:      String(e).slice(0, 900),
        p_backoff_sec: backoffSec(row.attempts + 1),
      });
    }
  }

  if (sentIds.length) {
    await rpc('sastanci_dispatch_mark_sent', { p_ids: sentIds });
  }

  return {
    processed: batch.length,
    sent:      sentIds.length,
    failed,
    skipped_wa: skippedWa,
  };
}

// ── HTTP handler ──────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  try {
    const result = await runBatch();
    console.log('[sast-dispatch]', result);

    return new Response(JSON.stringify({ ok: true, ...result }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  } catch (e) {
    console.error('[sast-dispatch] fatal', e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { 'content-type': 'application/json' },
    });
  }
});
