/**
 * Procesiranje jednog batch-a: za svaki claim-ovani event pozovi MSSQL SP
 * i markiraj SYNCED ili FAILED.
 *
 * Namerno NE paraliziramo pozive unutar jednog batch-a — redosled događaja
 * za istu stavku (npr. više TRANSFER-a u nizu) mora ostati očuvan. Ako
 * treba veći throughput, skaliraj pokretanjem više worker instanci sa
 * različitim WORKER_ID-em (SKIP LOCKED osigurava da se ne preklope).
 */

/**
 * @param {{
 *   supabase: ReturnType<import('./supabaseClient.js').createSupabaseWorkerClient>,
 *   mssql: Awaited<ReturnType<import('./mssqlClient.js').createMssqlClient>>,
 *   logger: ReturnType<import('./logger.js').createLogger>,
 * }} deps
 * @param {Array<object>} events batch iz loc_claim_sync_events
 * @returns {Promise<{ ok: number, failed: number }>}
 */
export async function processBatch(deps, events) {
  const { supabase, mssql, logger } = deps;
  let ok = 0;
  let failed = 0;

  for (const evt of events) {
    const ctx = {
      event_id: evt.id,
      source_record_id: evt.source_record_id,
      attempts: evt.attempts,
    };
    try {
      const result = await mssql.applyLocationEvent({
        eventId: evt.id,
        payload: evt.payload,
        targetProcedure: evt.target_procedure,
      });
      logger.debug('mssql sp returned', { ...ctx, returnValue: result.returnValue });
      await supabase.markSynced(evt.id);
      ok += 1;
      logger.info('event synced', ctx);
    } catch (err) {
      const msg = err?.message || String(err);
      failed += 1;
      logger.warn('event failed', { ...ctx, error: msg });
      try {
        await supabase.markFailed(evt.id, msg);
      } catch (markErr) {
        logger.error('markFailed also failed', {
          ...ctx,
          error: markErr?.message || String(markErr),
        });
      }
    }
  }

  return { ok, failed };
}
