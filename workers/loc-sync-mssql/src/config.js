/**
 * Konfiguracija iz environment-a. Sve obavezne promenljive validira odmah
 * pri pokretanju — crash-early je bolje nego da polling ćuti.
 */

import 'dotenv/config';

function required(name) {
  const v = process.env[name];
  if (!v || v.trim() === '') {
    throw new Error(`Missing required env var: ${name}`);
  }
  return v.trim();
}

function optional(name, fallback) {
  const v = process.env[name];
  return v && v.trim() !== '' ? v.trim() : fallback;
}

function intOpt(name, fallback) {
  const v = process.env[name];
  if (!v) return fallback;
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

function boolOpt(name, fallback) {
  const v = process.env[name];
  if (v == null || v === '') return fallback;
  return String(v).toLowerCase() === 'true' || v === '1';
}

export const config = {
  supabase: {
    url: required('SUPABASE_URL'),
    serviceRoleKey: required('SUPABASE_SERVICE_ROLE_KEY'),
  },
  mssql: {
    server: required('MSSQL_HOST'),
    port: intOpt('MSSQL_PORT', 1433),
    user: required('MSSQL_USER'),
    password: required('MSSQL_PASSWORD'),
    database: required('MSSQL_DATABASE'),
    options: {
      encrypt: boolOpt('MSSQL_ENCRYPT', true),
      trustServerCertificate: boolOpt('MSSQL_TRUST_SERVER_CERT', true),
    },
    pool: {
      max: 5,
      min: 0,
      idleTimeoutMillis: 30000,
    },
  },
  worker: {
    id: optional('WORKER_ID', `loc-sync-${process.pid}`),
    batchSize: intOpt('BATCH_SIZE', 10),
    pollIntervalMs: intOpt('POLL_INTERVAL_MS', 5000),
    idleIntervalMs: intOpt('IDLE_INTERVAL_MS', 15000),
    logLevel: optional('LOG_LEVEL', 'info').toLowerCase(),
  },
};
