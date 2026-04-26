/**
 * Jednokratni backfill za modul Planiranje proizvodnje.
 *
 * MSSQL BigTehn:
 *   - dbo.tRN           -> public.bigtehn_work_orders_cache
 *   - dbo.tStavkeRN     -> public.bigtehn_work_order_lines_cache
 *   - dbo.tTehPostupak  -> public.bigtehn_tech_routing_cache
 *   - dbo.tTehPostupak  -> public.bigtehn_rework_scrap_cache (G4, kvalitet 1/2)
 *   - dbo.tRNKomponente -> public.bigtehn_rn_components_cache (Faza 0, hijerarhija RN–RN)
 *
 * Periodični eksterni Bridge može imati vremenski prozor (npr. 30 dana).
 * Ova skripta namerno čita po ID-u bez date filtera i upsertuje cache tabele.
 *
 * Primeri poziva iz `workers/loc-sync-mssql`:
 *   node scripts/backfill-production-cache.js --dry-run
 *   node scripts/backfill-production-cache.js --scope=open
 *   node scripts/backfill-production-cache.js --scope=all --batch=1000
 *   node scripts/backfill-production-cache.js --tables=lines,tech --scope=all
 *   node scripts/backfill-production-cache.js --tables=rn-components --scope=open
 *
 * Učitavanje .env: pored trenutnog cwd, proba se i .env pored ove skripte i
 * roditelj folder (npr. servoteh-bridge/.env kada je skripta u scripts/).
 * Ili ručno: DOTENV_CONFIG_PATH=C:\\putanja\\.env
 */

import { existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';
import sql from 'mssql';
import { createClient } from '@supabase/supabase-js';

const __dirname = dirname(fileURLToPath(import.meta.url));

/** Svi postojeći kandidati, redom; `override: true` — poslednji pobedjuje (npr. cwd/.env nad roditeljem). */
function loadDotenvFiles() {
  const ordered = [
    join(__dirname, '.env'),
    join(__dirname, '..', '.env'),
    join(process.cwd(), '.env'),
  ];
  if (process.env.DOTENV_CONFIG_PATH) {
    ordered.push(resolve(process.env.DOTENV_CONFIG_PATH));
  }
  const seen = new Set();
  const loaded = [];
  for (const raw of ordered) {
    const p = resolve(raw);
    if (seen.has(p)) continue;
    seen.add(p);
    if (!existsSync(p)) continue;
    const r = dotenv.config({ path: p, override: true });
    if (r.error) {
      console.error(`[backfill] dotenv failed: ${p} — ${r.error.message}`);
      continue;
    }
    loaded.push(p);
  }
  if (loaded.length === 0) {
    dotenv.config();
  }
  const tried = [...new Set(ordered.map(p => resolve(p)))];
  return { tried, loaded };
}

const _dotenvInfo = loadDotenvFiles();

/**
 * Ako u .env nema standardnih imena, prekopiraj iz uobičajenih aliasa (npr. bridge
 * često koristi MSSQL_SERVER umesto MSSQL_HOST). Postojeća vrednost nije prebrisana.
 */
function applyMssqlEnvAliases() {
  const setIf = (to, from) => {
    const t = process.env[to];
    if (t && String(t).trim() !== '') return;
    const f = process.env[from];
    if (f != null && String(f).trim() !== '') process.env[to] = String(f).trim();
  };
  setIf('SUPABASE_URL', 'SUPABASE_PROJECT_URL');
  setIf('SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_SERVICE_KEY');
  setIf('SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_SERVICE_ROLE');
  setIf('MSSQL_HOST', 'BIGTEHN_SQL_SERVER');
  setIf('MSSQL_PORT', 'BIGTEHN_SQL_PORT');
  setIf('MSSQL_USER', 'BIGTEHN_SQL_USER');
  setIf('MSSQL_PASSWORD', 'BIGTEHN_SQL_PASSWORD');
  setIf('MSSQL_DATABASE', 'BIGTEHN_SQL_DATABASE');
  setIf('MSSQL_ENCRYPT', 'BIGTEHN_SQL_ENCRYPT');
  setIf('MSSQL_TRUST_SERVER_CERT', 'BIGTEHN_SQL_TRUST_SERVER_CERTIFICATE');
  setIf('MSSQL_POOL_MAX', 'BIGTEHN_SQL_POOL_MAX');
  setIf('MSSQL_POOL_MIN', 'BIGTEHN_SQL_POOL_MIN');
  setIf('MSSQL_REQUEST_TIMEOUT_MS', 'BIGTEHN_SQL_REQUEST_TIMEOUT_MS');
  setIf('MSSQL_HOST', 'MSSQL_SERVER');
  setIf('MSSQL_HOST', 'MSSQL_SERVER_HOST');
  setIf('MSSQL_HOST', 'MSSQL_ADDRESS');
  setIf('MSSQL_HOST', 'MSSQL_DB_HOST');
  setIf('MSSQL_HOST', 'MSSQL_DB_SERVER');
  setIf('MSSQL_HOST', 'SQLSERVER_HOST');
  setIf('MSSQL_HOST', 'SQLSERVER_SERVER');
  setIf('MSSQL_HOST', 'SQLSERVER_ADDRESS');
  setIf('MSSQL_HOST', 'SQL_SERVER');
  setIf('MSSQL_HOST', 'SQL_SERVER_HOST');
  setIf('MSSQL_HOST', 'SQL_HOST');
  setIf('MSSQL_HOST', 'DB_HOST');
  setIf('MSSQL_HOST', 'DB_SERVER');
  setIf('MSSQL_HOST', 'DATABASE_HOST');
  setIf('MSSQL_HOST', 'DATABASE_SERVER');
  setIf('MSSQL_USER', 'MSSQL_LOGIN');
  setIf('MSSQL_USER', 'MSSQL_USERNAME');
  setIf('MSSQL_USER', 'MSSQL_DB_USER');
  setIf('MSSQL_USER', 'SQLSERVER_USER');
  setIf('MSSQL_USER', 'SQLSERVER_USERNAME');
  setIf('MSSQL_USER', 'SQL_USERNAME');
  setIf('MSSQL_USER', 'SQL_USER');
  setIf('MSSQL_USER', 'DB_USER');
  setIf('MSSQL_USER', 'DB_USERNAME');
  setIf('MSSQL_USER', 'DATABASE_USER');
  setIf('MSSQL_PASSWORD', 'MSSQL_PWD');
  setIf('MSSQL_PASSWORD', 'MSSQL_PASS');
  setIf('MSSQL_PASSWORD', 'MSSQL_DB_PASSWORD');
  setIf('MSSQL_PASSWORD', 'SQLSERVER_PASSWORD');
  setIf('MSSQL_PASSWORD', 'SQLSERVER_PWD');
  setIf('MSSQL_PASSWORD', 'SQL_PASSWORD');
  setIf('MSSQL_PASSWORD', 'SQL_PWD');
  setIf('MSSQL_PASSWORD', 'SQL_PASS');
  setIf('MSSQL_PASSWORD', 'DB_PASSWORD');
  setIf('MSSQL_PASSWORD', 'DB_PASS');
  setIf('MSSQL_PASSWORD', 'DATABASE_PASSWORD');
  setIf('MSSQL_DATABASE', 'MSSQL_DB');
  setIf('MSSQL_DATABASE', 'MSSQL_DB_NAME');
  setIf('MSSQL_DATABASE', 'SQLSERVER_DATABASE');
  setIf('MSSQL_DATABASE', 'SQLSERVER_DB');
  setIf('MSSQL_DATABASE', 'SQL_DATABASE');
  setIf('MSSQL_DATABASE', 'SQL_DB');
  setIf('MSSQL_DATABASE', 'DB_NAME');
  setIf('MSSQL_DATABASE', 'DB_DATABASE');
  setIf('MSSQL_DATABASE', 'DATABASE_NAME');
  setIf('MSSQL_DATABASE', 'DATABASE');
}

applyMssqlEnvAliases();

function pickEnv(names) {
  for (const name of names) {
    const v = process.env[name];
    if (v != null && String(v).trim() !== '') return String(v).trim();
  }
  return null;
}

function parseMssqlConnectionString(raw) {
  if (!raw || String(raw).trim() === '') return null;
  const text = String(raw).trim();
  const out = {};

  if (/^mssql:\/\//i.test(text) || /^sqlserver:\/\//i.test(text)) {
    const u = new URL(text.replace(/^sqlserver:\/\//i, 'mssql://'));
    out.server = u.hostname;
    if (u.port) out.port = Number(u.port);
    if (u.username) out.user = decodeURIComponent(u.username);
    if (u.password) out.password = decodeURIComponent(u.password);
    out.database = u.pathname ? decodeURIComponent(u.pathname.replace(/^\/+/, '')) : null;
    const db = u.searchParams.get('database') || u.searchParams.get('Database');
    if (db) out.database = db;
    return out;
  }

  for (const part of text.split(';')) {
    const idx = part.indexOf('=');
    if (idx < 0) continue;
    const key = part.slice(0, idx).trim().toLowerCase().replace(/\s+/g, '');
    const value = part.slice(idx + 1).trim();
    if (!value) continue;

    if (['server', 'datasource', 'address', 'addr', 'networkaddress', 'host'].includes(key)) {
      out.server = value.replace(/^tcp:/i, '').split(',')[0].trim();
      const portPart = value.includes(',') ? value.split(',')[1] : null;
      if (portPart && Number.isFinite(Number(portPart.trim()))) out.port = Number(portPart.trim());
    } else if (['port'].includes(key)) {
      out.port = Number(value);
    } else if (['database', 'initialcatalog'].includes(key)) {
      out.database = value;
    } else if (['user id', 'userid', 'uid', 'user', 'username'].includes(key)) {
      out.user = value;
    } else if (['password', 'pwd'].includes(key)) {
      out.password = value;
    } else if (['encrypt'].includes(key)) {
      out.encrypt = /^true|yes|1$/i.test(value);
    } else if (['trustservercertificate'].includes(key)) {
      out.trustServerCertificate = /^true|yes|1$/i.test(value);
    }
  }

  return Object.keys(out).length ? out : null;
}

function getMssqlConnectionConfig() {
  const conn = parseMssqlConnectionString(
    pickEnv([
      'MSSQL_CONNECTION_STRING',
      'MSSQL_CONN_STRING',
      'MSSQL_URL',
      'MSSQL_DATABASE_URL',
      'SQL_CONNECTION_STRING',
      'SQL_CONN_STRING',
      'SQLSERVER_CONNECTION_STRING',
      'SQLSERVER_CONN_STRING',
      'SQLSERVER_URL',
      'DATABASE_URL',
      'DATABASE_CONNECTION_STRING',
      'DB_CONNECTION_STRING',
      'CONNECTION_STRING',
    ]),
  );

  return {
    server:
      pickEnv([
        'MSSQL_HOST',
        'BIGTEHN_SQL_SERVER',
        'MSSQL_SERVER',
        'MSSQL_SERVER_HOST',
        'MSSQL_ADDRESS',
        'MSSQL_DB_HOST',
        'MSSQL_DB_SERVER',
        'SQLSERVER_HOST',
        'SQLSERVER_SERVER',
        'SQLSERVER_ADDRESS',
        'SQL_SERVER',
        'SQL_SERVER_HOST',
        'SQL_HOST',
        'DB_HOST',
        'DB_SERVER',
        'DATABASE_HOST',
        'DATABASE_SERVER',
      ]) || conn?.server,
    port: Number(pickEnv(['MSSQL_PORT', 'BIGTEHN_SQL_PORT', 'SQL_PORT', 'DB_PORT']) || conn?.port || 1433),
    user:
      pickEnv([
        'MSSQL_USER',
        'MSSQL_LOGIN',
        'MSSQL_USERNAME',
        'MSSQL_DB_USER',
        'SQLSERVER_USER',
        'SQLSERVER_USERNAME',
        'SQL_USERNAME',
        'SQL_USER',
        'DB_USER',
        'DB_USERNAME',
        'DATABASE_USER',
      ]) || conn?.user,
    password:
      pickEnv([
        'MSSQL_PASSWORD',
        'MSSQL_PWD',
        'MSSQL_PASS',
        'MSSQL_DB_PASSWORD',
        'SQLSERVER_PASSWORD',
        'SQLSERVER_PWD',
        'SQL_PASSWORD',
        'SQL_PWD',
        'SQL_PASS',
        'DB_PASSWORD',
        'DB_PASS',
        'DATABASE_PASSWORD',
      ]) || conn?.password,
    database:
      pickEnv([
        'MSSQL_DATABASE',
        'MSSQL_DB',
        'MSSQL_DB_NAME',
        'SQLSERVER_DATABASE',
        'SQLSERVER_DB',
        'SQL_DATABASE',
        'SQL_DB',
        'DB_NAME',
        'DB_DATABASE',
        'DATABASE_NAME',
        'DATABASE',
      ]) || conn?.database,
    encrypt:
      process.env.MSSQL_ENCRYPT != null
        ? boolEnv('MSSQL_ENCRYPT', true)
        : conn?.encrypt ?? true,
    trustServerCertificate:
      process.env.MSSQL_TRUST_SERVER_CERT != null
        ? boolEnv('MSSQL_TRUST_SERVER_CERT', true)
        : conn?.trustServerCertificate ?? true,
  };
}

const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };

function createLogger(level = 'info', service = 'production-backfill') {
  const min = LEVELS[level] ?? LEVELS.info;
  const log = (lvl, msg, extra) => {
    if (LEVELS[lvl] < min) return;
    const entry = {
      ts: new Date().toISOString(),
      level: lvl,
      service,
      msg,
      ...(extra && typeof extra === 'object' ? extra : {}),
    };
    const line = JSON.stringify(entry);
    if (lvl === 'error' || lvl === 'warn') process.stderr.write(line + '\n');
    else process.stdout.write(line + '\n');
  };
  return {
    debug: (msg, extra) => log('debug', msg, extra),
    info: (msg, extra) => log('info', msg, extra),
    warn: (msg, extra) => log('warn', msg, extra),
    error: (msg, extra) => log('error', msg, extra),
  };
}

const logger = createLogger(process.env.LOG_LEVEL?.toLowerCase() || 'info');

function requiredEnv(name) {
  const v = process.env[name];
  if (!v || v.trim() === '') {
    const existsReport = _dotenvInfo.tried
      .map(p => `  [${existsSync(p) ? 'x' : ' '}] ${p}`)
      .join('\n');
    const loadReport =
      _dotenvInfo.loaded.length > 0
        ? `Učitani fajlovi: ${_dotenvInfo.loaded.join(' | ')}`
        : 'Nijedan od poznatih kandidata nije učitan (prazan/fali); proban je i prazan dotenv.config().';
    throw new Error(
      `Missing required env var: ${name}\n${loadReport}\n` +
        `Fajl postoji? (x = da):\n${existsReport}\n` +
        'MSSQL: skripta podržava MSSQL_HOST/MSSQL_SERVER/SQL_SERVER/DB_HOST ili connection string MSSQL_CONNECTION_STRING/SQL_CONNECTION_STRING/DATABASE_URL. Proveri da varijabla nije komentarisana (#).',
    );
  }
  return v.trim();
}

function optionalEnv(name, fallback) {
  const v = process.env[name];
  return v && v.trim() !== '' ? v.trim() : fallback;
}

function intEnv(name, fallback) {
  const v = process.env[name];
  if (!v) return fallback;
  const n = Number(v);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

function boolEnv(name, fallback) {
  const v = process.env[name];
  if (v == null || v === '') return fallback;
  return String(v).toLowerCase() === 'true' || v === '1';
}

const TABLE_ORDER = ['work-orders', 'lines', 'tech', 'rework-scrap', 'rn-components'];

function parseArgs(argv) {
  const out = {
    scope: 'open',
    tables: TABLE_ORDER,
    dryRun: false,
    batch: 500,
    limit: null,
  };

  for (const a of argv.slice(2)) {
    if (a === '--dry-run') out.dryRun = true;
    else if (a.startsWith('--scope=')) {
      const scope = a.slice('--scope='.length).trim().toLowerCase();
      if (scope === 'open' || scope === 'all') out.scope = scope;
      else throw new Error(`Invalid --scope=${scope}; expected open|all`);
    } else if (a.startsWith('--tables=')) {
      const raw = a.slice('--tables='.length).trim();
      const tables = raw.split(',').map(s => s.trim()).filter(Boolean);
      const unknown = tables.filter(t => !TABLE_ORDER.includes(t));
      if (unknown.length) {
        throw new Error(`Invalid --tables value(s): ${unknown.join(', ')}; expected ${TABLE_ORDER.join(',')}`);
      }
      out.tables = TABLE_ORDER.filter(t => tables.includes(t));
    } else if (a.startsWith('--batch=')) {
      const n = parseInt(a.slice('--batch='.length), 10);
      if (Number.isFinite(n) && n > 0) out.batch = n;
    } else if (a.startsWith('--limit=')) {
      const n = parseInt(a.slice('--limit='.length), 10);
      if (Number.isFinite(n) && n > 0) out.limit = n;
    } else if (a === '-h' || a === '--help') {
      out.help = true;
    } else {
      logger.warn('unknown flag ignored', { flag: a });
    }
  }

  return out;
}

function printHelp() {
  const lines = [
    'Usage: node scripts/backfill-production-cache.js [options]',
    '',
    'Options:',
    '  --scope=open       (default) sync samo RN-ove gde tRN.StatusRN nije true',
    '  --scope=all        sync bez vremenskog/status filtera',
    '  --tables=a,b       work-orders,lines,tech,rework-scrap,rn-components (default: sve)',
    '  --batch=500        veličina batch-a za select/upsert (default 500)',
    '  --limit=N          ograniči ukupan broj redova po tabeli (test)',
    '  --dry-run          samo broji/čita — ne upsertuje u Supabase',
    '  -h, --help         prikaži help',
  ];
  process.stdout.write(lines.join('\n') + '\n');
}

const iso = v => (v instanceof Date ? v.toISOString() : v == null ? null : String(v));
const numOr = (v, def = 0) => (Number.isFinite(Number(v)) ? Number(v) : def);
const nullableNum = v => (v == null || v === '' ? null : numOr(v, null));
const textOrNull = v => (v == null ? null : String(v));
const boolOr = (v, def = false) => (v == null ? def : Boolean(v));

function mapWorkOrderRow(r) {
  return {
    id: Number(r.IDRN),
    item_id: nullableNum(r.IDPredmet),
    customer_id: nullableNum(r.BBIDKomitent),
    ident_broj: String(r.IdentBroj ?? '').trim(),
    varijanta: numOr(r.Varijanta),
    broj_crteza: r.BrojCrteza == null ? null : String(r.BrojCrteza).trim(),
    naziv_dela: textOrNull(r.NazivDela),
    materijal: textOrNull(r.Materijal),
    dimenzija_materijala: textOrNull(r.DimenzijaMaterijala),
    jedinica_mere: textOrNull(r.JM),
    komada: numOr(r.Komada),
    tezina_neobr: numOr(r.TezinaNeobrDela),
    tezina_obr: numOr(r.TezinaObrDela),
    status_rn: boolOr(r.StatusRN),
    zakljucano: boolOr(r.Zakljucano),
    revizija: textOrNull(r.Revizija),
    quality_type_id: nullableNum(r.IDVrstaKvaliteta),
    handover_status_id: nullableNum(r.IDStatusPrimopredaje),
    napomena: textOrNull(r.Napomena),
    rok_izrade: iso(r.RokIzrade),
    datum_unosa: iso(r.DatumUnosa),
    created_at: iso(r.DIVUnosaRN),
    modified_at: iso(r.DIVIspravkeRN),
    author_worker_id: nullableNum(r.SifraRadnika),
    synced_at: new Date().toISOString(),
  };
}

function mapLineRow(r) {
  return {
    id: Number(r.IDStavkeRN),
    work_order_id: Number(r.IDRN),
    operacija: numOr(r.Operacija),
    machine_code: textOrNull(r.RJgrupaRC),
    opis_rada: textOrNull(r.OpisRada),
    alat_pribor: textOrNull(r.AlatPribor),
    tpz: numOr(r.Tpz),
    tk: numOr(r.Tk),
    tezina_to: numOr(r.TezinaTO),
    author_worker_id: nullableNum(r.SifraRadnika),
    created_at: iso(r.DIVUnosa),
    modified_at: iso(r.DIVIspravke),
    prioritet: numOr(r.Prioritet),
    synced_at: new Date().toISOString(),
  };
}

function mapTechRow(r) {
  return {
    id: Number(r.IDPostupka),
    work_order_id: nullableNum(r.IDRN),
    item_id: nullableNum(r.IDPredmet),
    worker_id: nullableNum(r.SifraRadnika),
    quality_type_id: nullableNum(r.IDVrstaKvaliteta),
    operacija: numOr(r.Operacija),
    machine_code: textOrNull(r.RJgrupaRC),
    komada: numOr(r.Komada),
    prn_timer_seconds: nullableNum(r.PrnTimer),
    started_at: iso(r.DatumIVremeUnosa),
    finished_at: iso(r.DatumIVremeZavrsetka),
    is_completed: boolOr(r.ZavrsenPostupak),
    ident_broj: textOrNull(r.IdentBroj),
    varijanta: numOr(r.Varijanta),
    toznaka: textOrNull(r.Toznaka),
    potpis: textOrNull(r.Potpis),
    napomena: textOrNull(r.Napomena),
    dorada_operacije: numOr(r.DoradaOperacije),
    synced_at: new Date().toISOString(),
  };
}

function mapRnComponentRow(r) {
  return {
    id: Number(r.IDKomponente),
    parent_rn_id: Number(r.IDRN),
    child_rn_id: Number(r.IDRNPodkomponenta),
    broj_komada: r.BrojKomada == null ? null : numOr(r.BrojKomada, 1),
    napomena: textOrNull(r.Napomena),
    modified_at: null,
    synced_at: new Date().toISOString(),
  };
}

function mapReworkScrapRow(r) {
  return {
    id: Number(r.IDPostupka),
    work_order_id: nullableNum(r.IDRN),
    item_id: nullableNum(r.IDPredmet),
    ident_broj: textOrNull(r.IdentBroj),
    varijanta: numOr(r.Varijanta),
    operacija: numOr(r.Operacija),
    machine_code: textOrNull(r.RJgrupaRC),
    worker_id: nullableNum(r.SifraRadnika),
    quality_type_id: nullableNum(r.IDVrstaKvaliteta),
    pieces: numOr(r.Komada),
    prn_timer_seconds: nullableNum(r.PrnTimer),
    started_at: iso(r.DatumIVremeUnosa),
    finished_at: iso(r.DatumIVremeZavrsetka),
    is_completed: boolOr(r.ZavrsenPostupak),
    dorada_operacije: numOr(r.DoradaOperacije),
    napomena: textOrNull(r.Napomena),
    synced_at: new Date().toISOString(),
  };
}

const SOURCES = {
  'work-orders': {
    target: 'bigtehn_work_orders_cache',
    idCol: 'IDRN',
    from: 'dbo.tRN src',
    selectCols: [
      'src.IDRN',
      'src.IDPredmet',
      'src.BBIDKomitent',
      'src.IdentBroj',
      'src.Varijanta',
      'src.BrojCrteza',
      'src.NazivDela',
      'src.Materijal',
      'src.DimenzijaMaterijala',
      'src.JM',
      'src.Komada',
      'src.TezinaNeobrDela',
      'src.TezinaObrDela',
      'src.StatusRN',
      'src.Zakljucano',
      'src.Revizija',
      'src.IDVrstaKvaliteta',
      'src.IDStatusPrimopredaje',
      'CAST(src.Napomena AS NVARCHAR(MAX)) AS Napomena',
      'src.RokIzrade',
      'src.DatumUnosa',
      'src.DIVUnosaRN',
      'src.DIVIspravkeRN',
      'src.SifraRadnika',
    ],
    openWhere: 'ISNULL(src.StatusRN, 0) = 0',
    map: mapWorkOrderRow,
  },
  lines: {
    target: 'bigtehn_work_order_lines_cache',
    idCol: 'IDStavkeRN',
    from: 'dbo.tStavkeRN src',
    selectCols: [
      'src.IDStavkeRN',
      'src.IDRN',
      'src.Operacija',
      'src.RJgrupaRC',
      'CAST(src.OpisRada AS NVARCHAR(MAX)) AS OpisRada',
      'src.AlatPribor',
      'src.Tpz',
      'src.Tk',
      'src.TezinaTO',
      'src.SifraRadnika',
      'src.DIVUnosa',
      'src.DIVIspravke',
      'src.Prioritet',
    ],
    joinForOpen: 'INNER JOIN dbo.tRN rn ON rn.IDRN = src.IDRN',
    openWhere: 'ISNULL(rn.StatusRN, 0) = 0',
    map: mapLineRow,
  },
  tech: {
    target: 'bigtehn_tech_routing_cache',
    idCol: 'IDPostupka',
    from: 'dbo.tTehPostupak src',
    selectCols: [
      'src.IDPostupka',
      'src.SifraRadnika',
      'src.IDPredmet',
      'src.IdentBroj',
      'src.Varijanta',
      'src.PrnTimer',
      'src.DatumIVremeUnosa',
      'src.Operacija',
      'src.RJgrupaRC',
      'src.Toznaka',
      'src.Komada',
      'src.Potpis',
      'src.DatumIVremeZavrsetka',
      'src.ZavrsenPostupak',
      'CAST(src.Napomena AS NVARCHAR(MAX)) AS Napomena',
      'src.IDRN',
      'src.IDVrstaKvaliteta',
      'src.DoradaOperacije',
    ],
    joinForOpen: 'INNER JOIN dbo.tRN rn ON rn.IDRN = src.IDRN',
    openWhere: 'ISNULL(rn.StatusRN, 0) = 0',
    map: mapTechRow,
  },
  'rework-scrap': {
    target: 'bigtehn_rework_scrap_cache',
    idCol: 'IDPostupka',
    from: 'dbo.tTehPostupak src',
    selectCols: [
      'src.IDPostupka',
      'src.SifraRadnika',
      'src.IDPredmet',
      'src.IdentBroj',
      'src.Varijanta',
      'src.PrnTimer',
      'src.DatumIVremeUnosa',
      'src.Operacija',
      'src.RJgrupaRC',
      'src.Komada',
      'src.DatumIVremeZavrsetka',
      'src.ZavrsenPostupak',
      'CAST(src.Napomena AS NVARCHAR(MAX)) AS Napomena',
      'src.IDRN',
      'src.IDVrstaKvaliteta',
      'src.DoradaOperacije',
    ],
    joinForOpen: 'INNER JOIN dbo.tRN rn ON rn.IDRN = src.IDRN',
    openWhere: 'ISNULL(rn.StatusRN, 0) = 0 AND src.IDVrstaKvaliteta IN (1, 2)',
    extraWhere: 'src.IDVrstaKvaliteta IN (1, 2)',
    map: mapReworkScrapRow,
  },
  'rn-components': {
    target: 'bigtehn_rn_components_cache',
    idCol: 'IDKomponente',
    from: 'dbo.tRNKomponente src',
    selectCols: [
      'src.IDKomponente',
      'src.IDRN',
      'src.IDRNPodkomponenta',
      'src.BrojKomada',
      'CAST(src.Napomena AS NVARCHAR(MAX)) AS Napomena',
    ],
    /** Puna tabela tRNKomponente (hijerarhija ne poštuje tRN.StatusRN u istom rezu). */
    skipOpenFilter: true,
    map: mapRnComponentRow,
  },
};

function createSupabaseServiceClient() {
  return createClient(requiredEnv('SUPABASE_URL'), requiredEnv('SUPABASE_SERVICE_ROLE_KEY'), {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { 'x-production-backfill': '1' } },
  });
}

async function createMssqlPool() {
  const cfg = getMssqlConnectionConfig();
  const missing = ['server', 'user', 'password', 'database'].filter(k => !cfg[k]);
  if (missing.length) {
    const likelyKeys = Object.keys(process.env)
      .filter(k => /(MSSQL|SQLSERVER|SQL_|DB_|DATABASE|CONNECTION)/i.test(k))
      .sort();
    throw new Error(
      `Missing MSSQL connection value(s): ${missing.join(', ')}. ` +
        'Podržano je: MSSQL_HOST/MSSQL_SERVER/SQLSERVER_HOST/SQL_SERVER/DB_HOST, MSSQL_USER/MSSQL_LOGIN, MSSQL_PASSWORD/MSSQL_PWD, MSSQL_DATABASE/MSSQL_DB ili MSSQL_CONNECTION_STRING. ' +
        `Pronađena env imena (bez vrednosti): ${likelyKeys.length ? likelyKeys.join(', ') : '(nema SQL/DB ključeva)'}`,
    );
  }

  return await new sql.ConnectionPool({
    server: cfg.server,
    port: cfg.port,
    user: cfg.user,
    password: cfg.password,
    database: cfg.database,
    options: {
      encrypt: cfg.encrypt,
      trustServerCertificate: cfg.trustServerCertificate,
    },
    pool: {
      max: intEnv('MSSQL_POOL_MAX', 5),
      min: 0,
      idleTimeoutMillis: intEnv('MSSQL_IDLE_TIMEOUT_MS', 30000),
    },
    requestTimeout: intEnv('MSSQL_REQUEST_TIMEOUT_MS', 120000),
  }).connect();
}

function fromClause(src, scope) {
  if (scope === 'open' && src.joinForOpen) {
    return `${src.from} ${src.joinForOpen}`;
  }
  return src.from;
}

function whereClause(src, scope) {
  const parts = [`src.${src.idCol} > @LastId`];
  if (scope === 'open' && src.openWhere && !src.skipOpenFilter) {
    parts.push(src.openWhere);
  } else if (src.extraWhere) {
    parts.push(src.extraWhere);
  }
  return parts.join(' AND ');
}

async function countMssqlRows(sql, pool, src, scope) {
  const req = pool.request();
  req.input('LastId', sql.Int, 0);
  const q = `
    SELECT COUNT(*) AS n
    FROM ${fromClause(src, scope)}
    WHERE ${whereClause(src, scope)}
  `;
  const res = await req.query(q);
  return Number(res.recordset?.[0]?.n ?? 0);
}

async function* selectMssqlBatches(sql, pool, src, { scope, batchSize, limit }) {
  let lastId = 0;
  let fetched = 0;

  while (true) {
    const req = pool.request();
    req.input('LastId', sql.Int, lastId);
    req.input('BatchSize', sql.Int, batchSize);
    const q = `
      SELECT TOP (@BatchSize) ${src.selectCols.join(',\n        ')}
      FROM ${fromClause(src, scope)}
      WHERE ${whereClause(src, scope)}
      ORDER BY src.${src.idCol} ASC
    `;
    const res = await req.query(q);
    const rows = res.recordset ?? [];
    if (rows.length === 0) return;

    lastId = Number(rows[rows.length - 1][src.idCol]);
    fetched += rows.length;
    yield rows;

    if (rows.length < batchSize) return;
    if (limit && fetched >= limit) return;
  }
}

async function upsertBatch(sb, table, rows) {
  if (!rows.length) return;
  const { error } = await sb.from(table).upsert(rows, { onConflict: 'id' });
  if (error) throw new Error(`${table} upsert failed: ${error.message}`);
}

const RN_COMPONENTS_TABLE = 'bigtehn_rn_components_cache';

/**
 * Briše redove u Supabase čiji id više nije u MSSQL skupu nakon full sync-a.
 * Sa --limit se ne poziva (delimičan uzorak nije kompletan izvor istine).
 */
async function deleteOrphanedComponentRows(sb, mssqlIdSet) {
  const toDelete = [];
  const pageSize = 500;
  let offset = 0;

  for (;;) {
    const { data, error } = await sb
      .from(RN_COMPONENTS_TABLE)
      .select('id')
      .order('id', { ascending: true })
      .range(offset, offset + pageSize - 1);

    if (error) throw new Error(`${RN_COMPONENTS_TABLE} select ids failed: ${error.message}`);
    const batch = data ?? [];
    if (batch.length === 0) break;

    for (const row of batch) {
      if (!mssqlIdSet.has(Number(row.id))) {
        toDelete.push(row.id);
      }
    }
    offset += batch.length;
    if (batch.length < pageSize) break;
  }

  let deleted = 0;
  const chunk = 200;
  for (let i = 0; i < toDelete.length; i += chunk) {
    const part = toDelete.slice(i, i + chunk);
    const { error } = await sb.from(RN_COMPONENTS_TABLE).delete().in('id', part);
    if (error) throw new Error(`${RN_COMPONENTS_TABLE} delete failed: ${error.message}`);
    deleted += part.length;
  }

  return deleted;
}

async function syncOneTable(sql, pool, sb, tableKey, args) {
  const src = SOURCES[tableKey];
  logger.info('table sync starting', {
    table: tableKey,
    target: src.target,
    scope: args.scope,
    batch: args.batch,
    limit: args.limit,
    dry_run: args.dryRun,
  });

  const totalMssql = await countMssqlRows(sql, pool, src, args.scope);
  logger.info('mssql source size', { table: tableKey, total_rows: totalMssql });

  const mssqlComponentIds = tableKey === 'rn-components' ? new Set() : null;

  let seen = 0;
  let upserted = 0;
  let deleted = 0;

  for await (const rows of selectMssqlBatches(sql, pool, src, {
    scope: args.scope,
    batchSize: args.batch,
    limit: args.limit,
  })) {
    seen += rows.length;
    if (mssqlComponentIds) {
      for (const r of rows) mssqlComponentIds.add(Number(r[src.idCol]));
    }
    const mapped = rows.map(src.map);
    if (!args.dryRun) await upsertBatch(sb, src.target, mapped);
    upserted += mapped.length;

    logger.info('batch done', {
      table: tableKey,
      seen,
      upserted,
      last_id: rows[rows.length - 1][src.idCol],
    });

    if (args.limit && seen >= args.limit) break;
  }

  if (tableKey === 'rn-components' && !args.dryRun) {
    if (args.limit) {
      logger.warn('rn-components orphan delete skipped: --limit (delimičan sync)', {
        limit: args.limit,
      });
    } else if (mssqlComponentIds && mssqlComponentIds.size === 0) {
      if (totalMssql === 0) {
        logger.info('rn-components: MSSQL count=0 — čistim Supabase cache (siroči)', {
          total_mssql: totalMssql,
        });
        deleted = await deleteOrphanedComponentRows(sb, mssqlComponentIds);
        logger.info('rn-components orphan delete complete', { deleted });
      } else {
        logger.warn(
          'rn-components: orphan delete preskočen — nijedan red nije pročitan iz MSSQL-a a count>0 (proveri bazu / filter / prava)',
          { total_mssql: totalMssql, seen },
        );
      }
    } else {
      deleted = await deleteOrphanedComponentRows(sb, mssqlComponentIds);
      logger.info('rn-components orphan delete complete', { deleted });
    }
  }

  logger.info('table sync complete', { table: tableKey, seen, upserted, deleted, dry_run: args.dryRun });
  return { table: tableKey, seen, upserted, deleted };
}

async function runPostProductionSyncRpc(sb, args) {
  if (args.dryRun) return null;
  if (!args.tables.includes('tech')) return null;

  logger.info('post-sync rpc starting', { rpc: 'mark_in_progress_from_tech_routing' });
  const { data, error } = await sb.rpc('mark_in_progress_from_tech_routing');
  if (error) throw new Error(`mark_in_progress_from_tech_routing failed: ${error.message}`);
  logger.info('post-sync rpc complete', {
    rpc: 'mark_in_progress_from_tech_routing',
    result: data,
  });
  return data;
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help) {
    printHelp();
    return;
  }

  logger.info('production backfill starting', {
    scope: args.scope,
    tables: args.tables,
    batch: args.batch,
    limit: args.limit,
    dry_run: args.dryRun,
  });

  /* Standalone: ne zavisi od internog src/config/logger layout-a produkcionog bridge-a. */
  const sb = createSupabaseServiceClient();
  const pool = await createMssqlPool();

  try {
    const results = [];
    for (const tableKey of args.tables) {
      results.push(await syncOneTable(sql, pool, sb, tableKey, args));
    }
    const postSync = await runPostProductionSyncRpc(sb, args);
    logger.info('production backfill complete', { results, post_sync: postSync, dry_run: args.dryRun });
  } finally {
    await pool.close();
  }
}

main().catch(err => {
  logger.error('fatal', { error: err?.message || String(err), stack: err?.stack });
  process.exit(1);
});
