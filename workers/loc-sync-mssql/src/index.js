/**
 * Entry point: inicijalizacija klijenata, polling petlja, graceful shutdown.
 *
 * Preduslov SQL migracija:
 *   sql/migrations/add_loc_module.sql
 *   sql/migrations/add_loc_step3_cleanup.sql
 *   sql/migrations/add_loc_step5_sync_rpcs.sql
 */

import { config } from './config.js';
import { createLogger } from './logger.js';
import { createSupabaseWorkerClient } from './supabaseClient.js';
import { createMssqlClient } from './mssqlClient.js';
import { processBatch } from './processor.js';

const logger = createLogger(config.worker.logLevel);

let shuttingDown = false;
let mssql = null;
/* Härd-3: heartbeat interval handle — clear-uje se u graceful shutdown-u. */
let heartbeatTimer = null;

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

/**
 * Härd-3: pošalji heartbeat ka Supabase-u (upsert u loc_sync_worker_heartbeat).
 * Pozadinski tik — greške se loguju, ne ruše proces. Ako migracija
 * `add_loc_sync_health_monitor.sql` nije primenjena, RPC vraća 404 i
 * logger upozorava (worker svejedno radi posao).
 */
async function sendHeartbeat(supabase) {
  try {
    await supabase.upsertHeartbeat(config.worker.id, {
      batch_size: config.worker.batchSize,
      poll_ms: config.worker.pollIntervalMs,
      node_version: process.version,
    });
  } catch (err) {
    logger.warn('heartbeat failed', { error: err?.message || String(err) });
  }
}

async function main() {
  logger.info('starting worker', {
    worker_id: config.worker.id,
    batch_size: config.worker.batchSize,
    poll_ms: config.worker.pollIntervalMs,
  });

  const supabase = createSupabaseWorkerClient(config.supabase);

  try {
    mssql = await createMssqlClient(config.mssql);
    logger.info('mssql pool connected', {
      host: config.mssql.server,
      database: config.mssql.database,
    });
  } catch (err) {
    logger.error('mssql connect failed', { error: err?.message || String(err) });
    process.exit(1);
  }

  /* Härd-3: prvo „live" heartbeat odmah, pa svakih 60s. pg_cron job
   * `loc_sync_health_check_hourly` posle 10 min tišine šalje admin alert. */
  await sendHeartbeat(supabase);
  heartbeatTimer = setInterval(() => {
    if (shuttingDown) return;
    void sendHeartbeat(supabase);
  }, 60_000);
  if (typeof heartbeatTimer.unref === 'function') heartbeatTimer.unref();

  /* Glavna petlja. Ne throw-uje — logujemo i spavamo pa probamo ponovo. */
  while (!shuttingDown) {
    const t0 = Date.now();
    let batchSize = 0;
    try {
      const events = await supabase.claimBatch(config.worker.id, config.worker.batchSize);
      batchSize = events.length;
      if (batchSize > 0) {
        const { ok, failed } = await processBatch({ supabase, mssql, logger }, events);
        logger.info('batch processed', {
          count: batchSize,
          ok,
          failed,
          duration_ms: Date.now() - t0,
        });
      } else {
        logger.debug('no pending events');
      }
    } catch (err) {
      logger.error('loop iteration failed', { error: err?.message || String(err) });
    }

    if (shuttingDown) break;
    const nextMs = batchSize > 0 ? config.worker.pollIntervalMs : config.worker.idleIntervalMs;
    await sleep(nextMs);
  }

  logger.info('shutdown: closing mssql');
  if (heartbeatTimer) {
    clearInterval(heartbeatTimer);
    heartbeatTimer = null;
  }
  if (mssql) await mssql.close();
  logger.info('shutdown complete');
}

function onSignal(sig) {
  if (shuttingDown) return;
  logger.info('signal received', { signal: sig });
  shuttingDown = true;
}
process.on('SIGTERM', () => onSignal('SIGTERM'));
process.on('SIGINT', () => onSignal('SIGINT'));
process.on('unhandledRejection', err => {
  logger.error('unhandledRejection', { error: err?.message || String(err) });
});

main().catch(err => {
  logger.error('fatal', { error: err?.message || String(err) });
  process.exit(1);
});
