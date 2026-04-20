/**
 * Thin wrapper nad supabase-js za potrebe worker-a:
 *  - claimBatch: poziva loc_claim_sync_events RPC (FOR UPDATE SKIP LOCKED)
 *  - markSynced / markFailed: finalni statusi
 *
 * Service role key se koristi SAMO server-side (worker). NIKAD ne sme u bundle.
 */

import { createClient } from '@supabase/supabase-js';

/**
 * @param {{ url: string, serviceRoleKey: string }} cfg
 */
export function createSupabaseWorkerClient(cfg) {
  const client = createClient(cfg.url, cfg.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { 'x-loc-sync-worker': '1' } },
  });
  return {
    /**
     * @param {string} workerId
     * @param {number} batchSize
     * @returns {Promise<Array<object>>}
     */
    async claimBatch(workerId, batchSize) {
      const { data, error } = await client.rpc('loc_claim_sync_events', {
        p_worker_id: workerId,
        p_batch_size: batchSize,
      });
      if (error) throw new Error(`loc_claim_sync_events failed: ${error.message}`);
      return Array.isArray(data) ? data : [];
    },
    /**
     * @param {string} eventId UUID
     */
    async markSynced(eventId) {
      const { data, error } = await client.rpc('loc_mark_sync_synced', {
        p_event_id: eventId,
      });
      if (error) throw new Error(`loc_mark_sync_synced failed: ${error.message}`);
      return Boolean(data);
    },
    /**
     * @param {string} eventId UUID
     * @param {string} errMsg
     */
    async markFailed(eventId, errMsg) {
      const { data, error } = await client.rpc('loc_mark_sync_failed', {
        p_event_id: eventId,
        p_error: errMsg == null ? '' : String(errMsg).slice(0, 4000),
      });
      if (error) throw new Error(`loc_mark_sync_failed failed: ${error.message}`);
      return Boolean(data);
    },
  };
}
