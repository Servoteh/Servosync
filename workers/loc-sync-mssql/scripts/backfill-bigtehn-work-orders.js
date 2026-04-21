/**
 * Jednokratni backfill: MSSQL `dbo.tRN` → Supabase `public.bigtehn_work_orders_cache`.
 *
 * Bridge worker koji periodično puni cache ima početni prozor (~dec 2025),
 * pa stari zatvoreni RN-ovi (npr. `9000/522`) nisu u Supabase-u i aplikacija
 * ne može autofill-ovati broj crteža. Ova skripta jednokratno povuče celu
 * tabelu `tRN` i upsertuje u cache, čime se popunjava veza nalog → crtež
 * za sve istorijske RN-ove.
 *
 * Koristi iste env varijable kao runtime worker (`src/config.js`):
 *   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 *   MSSQL_HOST, MSSQL_PORT, MSSQL_USER, MSSQL_PASSWORD, MSSQL_DATABASE,
 *   MSSQL_ENCRYPT, MSSQL_TRUST_SERVER_CERT
 *
 * Primeri poziva iz `workers/loc-sync-mssql`:
 *   node scripts/backfill-bigtehn-work-orders.js --dry-run
 *   node scripts/backfill-bigtehn-work-orders.js --only-missing
 *   node scripts/backfill-bigtehn-work-orders.js --full
 *   node scripts/backfill-bigtehn-work-orders.js --ident=9000/522
 *   node scripts/backfill-bigtehn-work-orders.js --full --batch=1000
 */

import { createLogger } from '../src/logger.js';

/* mssql / config / supabase klijente učitavamo lazy u main() — tako --help
 * radi i bez .env fajla (config.js throw-uje na missing env odmah pri importu). */

const logger = createLogger(process.env.LOG_LEVEL?.toLowerCase() || 'info', 'bigtehn-backfill');

/* -------------------- CLI parsing -------------------- */

function parseArgs(argv) {
  const out = {
    mode: 'only-missing', // default: samo RN-ovi koji fale u cache-u
    dryRun: false,
    batch: 500,
    ident: null, // ciljani ident_broj (npr. "9000/522")
    limit: null, // ograničenje broja redova (test)
  };
  for (const a of argv.slice(2)) {
    if (a === '--dry-run') out.dryRun = true;
    else if (a === '--only-missing') out.mode = 'only-missing';
    else if (a === '--full') out.mode = 'full';
    else if (a.startsWith('--batch=')) {
      const n = parseInt(a.slice('--batch='.length), 10);
      if (Number.isFinite(n) && n > 0) out.batch = n;
    } else if (a.startsWith('--ident=')) {
      out.ident = a.slice('--ident='.length).trim() || null;
      out.mode = 'ident';
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
    'Usage: node scripts/backfill-bigtehn-work-orders.js [options]',
    '',
    'Options:',
    '  --only-missing   (default) upsert samo RN-ova čiji IDRN nije u cache-u',
    '  --full           upsert SVIH redova iz tRN (idempotentno, sporije)',
    '  --ident=9000/522 povuci samo jedan RN po IdentBroj (useful za debug)',
    '  --batch=500      veličina batch-a za select/upsert (default 500)',
    '  --limit=N        ograniči ukupan broj procesiranih redova (test)',
    '  --dry-run        samo broji — ne upsertuje u Supabase',
    '  -h, --help       prikaži help',
  ];
  process.stdout.write(lines.join('\n') + '\n');
}

/* -------------------- Mapping tRN → cache row -------------------- */

/**
 * Mapira jedan MSSQL `tRN` red u row za `bigtehn_work_orders_cache`.
 * Kolone koje nedostaju se tiho default-uju.
 */
function mapRowToCache(r) {
  /* `bit NULL` u MSSQL-u može biti true/false/null; cache to zahteva NOT NULL boolean. */
  const boolOr = (v, def) => (v == null ? def : Boolean(v));
  /* MSSQL `datetime` dolazi kao Date objekat (mssql paket); čuvamo kao ISO. */
  const iso = v => (v instanceof Date ? v.toISOString() : v == null ? null : String(v));

  return {
    id: Number(r.IDRN),
    item_id: r.IDPredmet == null ? null : Number(r.IDPredmet),
    customer_id: r.BBIDKomitent == null ? null : Number(r.BBIDKomitent),
    ident_broj: String(r.IdentBroj ?? '').trim(),
    varijanta: Number.isFinite(Number(r.Varijanta)) ? Number(r.Varijanta) : 0,
    broj_crteza: r.BrojCrteza == null ? null : String(r.BrojCrteza).trim(),
    naziv_dela: r.NazivDela == null ? null : String(r.NazivDela),
    materijal: r.Materijal == null ? null : String(r.Materijal),
    dimenzija_materijala: r.DimenzijaMaterijala == null ? null : String(r.DimenzijaMaterijala),
    jedinica_mere: r.JM == null ? null : String(r.JM),
    komada: Number.isFinite(Number(r.Komada)) ? Number(r.Komada) : 0,
    tezina_neobr: Number.isFinite(Number(r.TezinaNeobrDela)) ? Number(r.TezinaNeobrDela) : 0,
    tezina_obr: Number.isFinite(Number(r.TezinaObrDela)) ? Number(r.TezinaObrDela) : 0,
    status_rn: boolOr(r.StatusRN, false),
    zakljucano: boolOr(r.Zakljucano, false),
    revizija: r.Revizija == null ? null : String(r.Revizija),
    quality_type_id: r.IDVrstaKvaliteta == null ? null : Number(r.IDVrstaKvaliteta),
    handover_status_id:
      r.IDStatusPrimopredaje == null ? null : Number(r.IDStatusPrimopredaje),
    napomena: r.Napomena == null ? null : String(r.Napomena),
    rok_izrade: iso(r.RokIzrade),
    datum_unosa: iso(r.DatumUnosa),
    created_at: iso(r.DIVUnosaRN),
    modified_at: iso(r.DIVIspravkeRN),
    author_worker_id: r.SifraRadnika == null ? null : Number(r.SifraRadnika),
    synced_at: new Date().toISOString(),
  };
}

/* -------------------- MSSQL selectors -------------------- */

const SELECT_COLS = [
  'IDRN',
  'IDPredmet',
  'BBIDKomitent',
  'IdentBroj',
  'Varijanta',
  'BrojCrteza',
  'NazivDela',
  'Materijal',
  'DimenzijaMaterijala',
  'JM',
  'Komada',
  'TezinaNeobrDela',
  'TezinaObrDela',
  'StatusRN',
  'Zakljucano',
  'Revizija',
  'IDVrstaKvaliteta',
  'IDStatusPrimopredaje',
  'Napomena',
  'RokIzrade',
  'DatumUnosa',
  'DIVUnosaRN',
  'DIVIspravkeRN',
  'SifraRadnika',
].join(', ');

async function countMssqlRows(sql, pool, { mode, ident, missingIds }) {
  const req = pool.request();
  let where = '1=1';
  if (mode === 'ident' && ident) {
    req.input('Ident', sql.NVarChar(50), ident);
    where = 'IdentBroj = @Ident';
  } else if (mode === 'only-missing' && missingIds) {
    /* Koristimo TVP-like workaround — umesto toga paginiramo po IDRN-u i
     * u aplikaciji filtriramo. Ovde vraćamo "ukupno u MSSQL-u" radi progress log-a. */
    where = '1=1';
  }
  const r = await req.query(`SELECT COUNT(*) AS n FROM dbo.tRN WHERE ${where}`);
  return Number(r.recordset?.[0]?.n ?? 0);
}

/**
 * Paginirano čitanje iz `tRN` po IDRN-u, sa opcionalnim filterom.
 * Yielduje batch-eve redova.
 */
async function* selectMssqlBatches(sql, pool, { mode, ident, batchSize, limit }) {
  let lastId = 0;
  let fetched = 0;
  while (true) {
    const req = pool.request();
    req.input('LastId', sql.Int, lastId);
    req.input('BatchSize', sql.Int, batchSize);
    let where = 'IDRN > @LastId';
    if (mode === 'ident' && ident) {
      req.input('Ident', sql.NVarChar(50), ident);
      where += ' AND IdentBroj = @Ident';
    }
    /* SQL Server 2012+ OFFSET/FETCH nije potreban — progoneli smo po IDRN
     * što je bezbednije (stabilan sort po PK-u). */
    const q = `
      SELECT TOP (@BatchSize) ${SELECT_COLS}
      FROM dbo.tRN
      WHERE ${where}
      ORDER BY IDRN ASC
    `;
    const res = await req.query(q);
    const rows = res.recordset ?? [];
    if (rows.length === 0) return;
    lastId = Number(rows[rows.length - 1].IDRN);
    fetched += rows.length;
    yield rows;
    if (rows.length < batchSize) return;
    if (limit && fetched >= limit) return;
  }
}

/* -------------------- Supabase upsert helper -------------------- */

function createAnonymousSupabaseClient(createClient, cfg) {
  /* Koristimo direktno createClient da bismo imali from().upsert() — worker
   * wrapper vraća samo RPC metode. */
  return createClient(cfg.url, cfg.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { 'x-bigtehn-backfill': '1' } },
  });
}

/**
 * Učita sve postojeće IDRN-ove iz cache-a u Set (za --only-missing).
 */
async function loadCacheIds(sb) {
  const ids = new Set();
  const pageSize = 1000;
  for (let from = 0; ; from += pageSize) {
    const to = from + pageSize - 1;
    const { data, error } = await sb
      .from('bigtehn_work_orders_cache')
      .select('id', { count: 'exact' })
      .range(from, to)
      .order('id', { ascending: true });
    if (error) throw new Error(`cache scan failed: ${error.message}`);
    if (!data || data.length === 0) break;
    for (const row of data) ids.add(Number(row.id));
    if (data.length < pageSize) break;
  }
  return ids;
}

async function upsertBatch(sb, rows) {
  if (rows.length === 0) return;
  const { error } = await sb
    .from('bigtehn_work_orders_cache')
    .upsert(rows, { onConflict: 'id' });
  if (error) throw new Error(`upsert failed: ${error.message}`);
}

/* -------------------- Main -------------------- */

async function main() {
  const args = parseArgs(process.argv);
  if (args.help) {
    printHelp();
    return;
  }

  logger.info('backfill starting', {
    mode: args.mode,
    ident: args.ident,
    batch: args.batch,
    limit: args.limit,
    dry_run: args.dryRun,
  });

  /* Lazy imports — tek sad validiramo .env i otvaramo pool-ove. */
  const [{ default: sql }, { config }, { createMssqlClient }, { createClient }] =
    await Promise.all([
      import('mssql'),
      import('../src/config.js'),
      import('../src/mssqlClient.js'),
      import('@supabase/supabase-js'),
    ]);
  const sb = createAnonymousSupabaseClient(createClient, config.supabase);

  let missingIds = null;
  if (args.mode === 'only-missing') {
    logger.info('loading existing cache ids…');
    const existing = await loadCacheIds(sb);
    logger.info('cache ids loaded', { count: existing.size });
    missingIds = existing; // koristimo kao "postoji-set"
  }

  const mssqlWrap = await createMssqlClient(config.mssql);
  const pool = mssqlWrap.pool;

  try {
    const totalMssql = await countMssqlRows(sql, pool, {
      mode: args.mode,
      ident: args.ident,
    });
    logger.info('mssql source size', { total_rows: totalMssql });

    let upserted = 0;
    let skipped = 0;
    let seen = 0;

    for await (const rows of selectMssqlBatches(sql, pool, {
      mode: args.mode,
      ident: args.ident,
      batchSize: args.batch,
      limit: args.limit,
    })) {
      seen += rows.length;

      /* Filter po missingIds ako je only-missing. */
      const toInsert = [];
      for (const r of rows) {
        const mapped = mapRowToCache(r);
        if (args.mode === 'only-missing' && missingIds.has(mapped.id)) {
          skipped++;
          continue;
        }
        toInsert.push(mapped);
      }

      if (!args.dryRun && toInsert.length > 0) {
        await upsertBatch(sb, toInsert);
      }
      upserted += toInsert.length;

      logger.info('batch done', {
        seen,
        upserted,
        skipped,
        last_id: rows[rows.length - 1].IDRN,
      });

      if (args.limit && seen >= args.limit) break;
    }

    logger.info('backfill complete', { seen, upserted, skipped, dry_run: args.dryRun });
  } finally {
    await mssqlWrap.close();
  }
}

main().catch(err => {
  logger.error('fatal', { error: err?.message || String(err), stack: err?.stack });
  process.exit(1);
});
