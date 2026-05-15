/**
 * Supabase Edge Function: `loc-sync-monitor-dispatch`
 *
 * Sprint LOC-Härd-3 (operativna vidljivost).
 *
 * Batch dispatcher za outbox `public.loc_sync_alerts_outbox`. Šalje plain-text
 * mejlove admin-ima kad:
 *   * `worker_down` — heartbeat tabela pokazuje da loc-sync-mssql worker nije
 *     slao signal duže od 10 minuta (dedup po danu + worker_id).
 *   * `dead_letter_digest` — u `loc_sync_outbound_events` ima stavki u
 *     DEAD_LETTER stanju (dedup po danu).
 *
 * Pokretač: Supabase Scheduled Trigger svakih 5 minuta (Cron Job u Studio-u).
 * Manualno: `curl -X POST <fn-url>` sa service-role JWT-om.
 *
 * Env varijable (Supabase Secrets):
 *   SUPABASE_URL                 (auto)
 *   SUPABASE_SERVICE_ROLE_KEY    (auto)
 *   RESEND_API_KEY               (opciono; bez njega → DRY-RUN, log u console)
 *   RESEND_FROM                  (default: noreply@servoteh.rs)
 *   LOC_SYNC_DISPATCH_BATCH      (default: 25)
 *
 * Deploy:
 *   supabase functions deploy loc-sync-monitor-dispatch --no-verify-jwt
 */

// deno-lint-ignore-file no-explicit-any
// @ts-ignore Deno runtime
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';

// ── Env vars ──────────────────────────────────────────────────────────────────

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const RESEND_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const RESEND_FROM = Deno.env.get('RESEND_FROM') ?? 'noreply@servoteh.rs';
const BATCH = Number(Deno.env.get('LOC_SYNC_DISPATCH_BATCH') ?? '25') || 25;
const AUDIT_ACTOR = 'loc-sync-monitor-dispatch@edge.servoteh';

if (!SUPABASE_URL || !SERVICE_ROLE) {
  console.error('[loc-sync-dispatch] SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY nisu postavljeni');
}

// ── Tipovi ────────────────────────────────────────────────────────────────────

type AlertRow = {
  id: string;
  kind: 'worker_down' | 'dead_letter_digest';
  dedup_key: string;
  recipient_email: string;
  subject: string;
  body_text: string;
  payload: Record<string, unknown> | null;
  attempts: number;
};

// ── RPC helper ────────────────────────────────────────────────────────────────

async function rpc<T = unknown>(fn: string, args: Record<string, unknown>): Promise<T | null> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/${fn}`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      apikey: SERVICE_ROLE,
      Authorization: `Bearer ${SERVICE_ROLE}`,
      'X-Audit-Actor': AUDIT_ACTOR,
      Prefer: 'return=representation',
    },
    body: JSON.stringify(args),
  });
  if (!res.ok) {
    console.error(`[rpc ${fn}] ${res.status}`, await res.text());
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

// ── Dispatch one ──────────────────────────────────────────────────────────────

type DispatchResult = { ok: true } | { ok: false; error: string };

async function dispatchOne(row: AlertRow): Promise<DispatchResult> {
  if (!RESEND_KEY) {
    console.log('[DRY-RUN]', {
      to: row.recipient_email,
      subject: row.subject,
      kind: row.kind,
      dedup: row.dedup_key,
    });
    return { ok: true };
  }

  const payload = {
    from: RESEND_FROM,
    to: [row.recipient_email],
    subject: row.subject,
    text: row.body_text,
  };

  let res: Response;
  try {
    res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${RESEND_KEY}`,
      },
      body: JSON.stringify(payload),
    });
  } catch (e) {
    return { ok: false, error: `Network: ${String(e).slice(0, 400)}` };
  }

  if (res.ok) return { ok: true };
  const body = (await res.text()).slice(0, 800);
  return { ok: false, error: `Resend ${res.status}: ${body}` };
}

// ── Batch run ─────────────────────────────────────────────────────────────────

async function runBatch(): Promise<{
  processed: number;
  sent: number;
  failed: number;
}> {
  const batch = await rpc<AlertRow[]>('loc_sync_dispatch_dequeue', {
    p_batch: BATCH,
  });

  if (!batch || batch.length === 0) {
    return { processed: 0, sent: 0, failed: 0 };
  }

  let sent = 0;
  let failed = 0;

  for (const row of batch) {
    try {
      const result = await dispatchOne(row);
      if (result.ok) {
        await rpc('loc_sync_dispatch_mark_sent', { p_id: row.id });
        sent++;
      } else {
        await rpc('loc_sync_dispatch_mark_failed', {
          p_id: row.id,
          p_error: result.error,
        });
        failed++;
      }
    } catch (e) {
      failed++;
      await rpc('loc_sync_dispatch_mark_failed', {
        p_id: row.id,
        p_error: String(e).slice(0, 900),
      });
    }
  }

  return { processed: batch.length, sent, failed };
}

// ── HTTP handler ──────────────────────────────────────────────────────────────

serve(async (req) => {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  if (!SUPABASE_URL || !SERVICE_ROLE) {
    return new Response(
      JSON.stringify({ ok: false, error: 'service not configured' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }

  try {
    const stats = await runBatch();
    return new Response(JSON.stringify({ ok: true, ...stats }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (e) {
    console.error('[loc-sync-dispatch] fatal', e);
    return new Response(
      JSON.stringify({ ok: false, error: String(e).slice(0, 500) }),
      { status: 500, headers: { 'Content-Type': 'application/json' } },
    );
  }
});
