/**
 * Supabase Edge Function: pb-notify-dispatch
 *
 * Dispatch worker za public.pb_notification_log (Projektni biro).
 * Deploy: supabase functions deploy pb-notify-dispatch --no-verify-jwt
 *
 * Secrets: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, RESEND_API_KEY (opciono), RESEND_FROM
 */

// deno-lint-ignore-file no-explicit-any
// @ts-ignore Deno runtime
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';

type PbRow = {
  id: string;
  channel: string;
  recipient: string;
  subject: string | null;
  body: string;
  attempts: number;
};

const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY') ?? '';
const RESEND_FROM = Deno.env.get('RESEND_FROM') ?? 'Projektni biro <noreply@servoteh.rs>';
const BATCH = Number(Deno.env.get('PB_DISPATCH_BATCH') ?? '10') || 10;

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
    console.error(`[pb-dispatch rpc ${fn}]`, res.status, await res.text());
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

async function sendEmail(row: PbRow): Promise<{ ok: true } | { ok: false; error: string }> {
  if (!RESEND_API_KEY) {
    console.log('[pb-dispatch DRY-RUN email]', row.recipient);
    return { ok: true };
  }
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${RESEND_API_KEY}`,
    },
    body: JSON.stringify({
      from: RESEND_FROM,
      to: [row.recipient],
      subject: row.subject ?? 'Projektni biro',
      text: row.body,
    }),
  });
  if (res.ok) return { ok: true };
  return { ok: false, error: `Resend ${res.status}: ${(await res.text()).slice(0, 800)}` };
}

serve(async (req) => {
  const audit = req.headers.get('x-audit-actor') ?? 'anonymous';
  console.log('[pb-notify-dispatch] actor:', audit);

  const authHeader = req.headers.get('Authorization') ?? '';
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (!SERVICE_ROLE || token !== SERVICE_ROLE) {
    return new Response(JSON.stringify({ ok: false, error: 'Unauthorized' }), {
      status: 401,
      headers: { 'content-type': 'application/json' },
    });
  }

  if (req.method !== 'POST' && req.method !== 'GET') {
    return new Response('Method Not Allowed', { status: 405 });
  }

  try {
    /* Provera digest_mode iz config tabele — ako je TRUE, grupišemo email-ove
       istog primaoca u jedan kombinovani mejl. */
    const cfgRes = await fetch(
      `${SUPABASE_URL}/rest/v1/pb_notification_config?id=eq.1&select=digest_mode`,
      {
        headers: {
          apikey: SERVICE_ROLE,
          Authorization: `Bearer ${SERVICE_ROLE}`,
        },
      },
    );
    let digest = false;
    if (cfgRes.ok) {
      const cfgArr = await cfgRes.json().catch(() => null);
      digest = Boolean(cfgArr?.[0]?.digest_mode);
    }

    const batch = await rpc<PbRow[]>('pb_dispatch_dequeue', { batch_size: BATCH });
    const rows = Array.isArray(batch) ? batch : [];
    let sent = 0;
    let failed = 0;
    let skipped = 0;

    /* Non-email kanali idu redom (whatsapp itd.). */
    const emailRows: PbRow[] = [];
    for (const row of rows) {
      if (row.channel === 'email') {
        emailRows.push(row);
        continue;
      }
      try {
        if (row.channel === 'whatsapp') {
          console.warn('[pb-dispatch] WhatsApp not configured for PB — marking sent');
          await rpc('pb_dispatch_mark_sent', { p_id: row.id });
          skipped++;
          continue;
        }
        await rpc('pb_dispatch_mark_sent', { p_id: row.id });
        skipped++;
      } catch (e) {
        failed++;
        await rpc('pb_dispatch_mark_failed', {
          p_id: row.id,
          p_error: String(e).slice(0, 900),
        });
      }
    }

    /* Email-ovi: pojedinačno ili digest po primaocu. */
    if (digest && emailRows.length > 1) {
      const groups = new Map<string, PbRow[]>();
      for (const r of emailRows) {
        const list = groups.get(r.recipient) ?? [];
        list.push(r);
        groups.set(r.recipient, list);
      }
      for (const [recipient, items] of groups) {
        if (items.length === 1) {
          const r = items[0];
          const sendRes = await sendEmail(r);
          if (sendRes.ok) {
            await rpc('pb_dispatch_mark_sent', { p_id: r.id });
            sent++;
          } else {
            await rpc('pb_dispatch_mark_failed', { p_id: r.id, p_error: 'error' in sendRes ? sendRes.error : 'fail' });
            failed++;
          }
          continue;
        }
        /* Spoji više poruka u jedan mejl. */
        const combined: PbRow = {
          id: items[0].id, /* za log; ostale markiraj individualno */
          channel: 'email',
          recipient,
          subject: `Projektni biro — ${items.length} obaveštenja`,
          body: items
            .map((it) => `• ${it.subject || '(bez naslova)'}\n${it.body}`)
            .join('\n\n———\n\n'),
          attempts: items[0].attempts,
        };
        const r = await sendEmail(combined);
        if (r.ok) {
          for (const it of items) {
            await rpc('pb_dispatch_mark_sent', { p_id: it.id });
            sent++;
          }
        } else {
          for (const it of items) {
            await rpc('pb_dispatch_mark_failed', {
              p_id: it.id,
              p_error: 'error' in r ? r.error : 'digest fail',
            });
            failed++;
          }
        }
      }
    } else {
      for (const row of emailRows) {
        try {
          const r = await sendEmail(row);
          if (r.ok) {
            await rpc('pb_dispatch_mark_sent', { p_id: row.id });
            sent++;
          } else {
            await rpc('pb_dispatch_mark_failed', {
              p_id: row.id,
              p_error: 'error' in r ? r.error : 'send failed',
            });
            failed++;
          }
        } catch (e) {
          failed++;
          await rpc('pb_dispatch_mark_failed', {
            p_id: row.id,
            p_error: String(e).slice(0, 900),
          });
        }
      }
    }

    return new Response(JSON.stringify({ ok: true, sent, failed, skipped, processed: rows.length, digest }), {
      status: 200,
      headers: { 'content-type': 'application/json' },
    });
  } catch (e) {
    console.error('[pb-dispatch] fatal', e);
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500,
      headers: { 'content-type': 'application/json' },
    });
  }
});
