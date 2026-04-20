/**
 * MSSQL client pool + poziv stored procedure `dbo.sp_ApplyLocationEvent`.
 *
 * Očekivani potpis SP-ja (prilagoditi stvarnoj definiciji u ERP-u):
 *   CREATE PROCEDURE dbo.sp_ApplyLocationEvent
 *     @EventId UNIQUEIDENTIFIER,
 *     @Payload NVARCHAR(MAX)     -- JSON payload iz loc_sync_outbound_events.payload
 *   AS ...
 *
 * Ako procedura ima drugi potpis, samo ovu funkciju ažurirati — ostatak
 * worker-a (claim/loop/logger) ostaje isti.
 */

import sql from 'mssql';

/**
 * @param {import('../src/config.js').config['mssql']} cfg
 */
export async function createMssqlClient(cfg) {
  const pool = await new sql.ConnectionPool({
    server: cfg.server,
    port: cfg.port,
    user: cfg.user,
    password: cfg.password,
    database: cfg.database,
    options: cfg.options,
    pool: cfg.pool,
  }).connect();

  async function close() {
    try {
      await pool.close();
    } catch (_ignored) {
      /* tiho */
    }
  }

  /**
   * Poziva dbo.sp_ApplyLocationEvent. Bilo koji throw se interpretira
   * kao "FAILED" u worker-u.
   *
   * @param {{ eventId: string, payload: object, targetProcedure?: string }} evt
   * @returns {Promise<{ returnValue: number, output: object }>}
   */
  async function applyLocationEvent(evt) {
    const proc = evt.targetProcedure || 'dbo.sp_ApplyLocationEvent';
    const req = pool.request();
    req.input('EventId', sql.UniqueIdentifier, evt.eventId);
    req.input('Payload', sql.NVarChar(sql.MAX), JSON.stringify(evt.payload ?? {}));
    /* timeout 30s — sprečava da worker ostane zakačen na failing SP. */
    req.timeout = 30_000;
    const result = await req.execute(proc);
    return {
      returnValue: result.returnValue ?? 0,
      output: result.output ?? {},
    };
  }

  return { pool, close, applyLocationEvent };
}
