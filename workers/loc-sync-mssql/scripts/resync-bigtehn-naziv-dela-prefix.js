/**
 * Vraća `naziv_dela` u bigtehn_work_orders_cache iz MSSQL dbo.tRN.NazivDela
 * za sve RN čiji IdentBroj počinje zadatim prefiksom (npr. 9811-1).
 *
 * Koristi se posle pogrešnog masovnog UPDATE-a koji je stavio naziv PREDMETA
 * na svaki TP u grani.
 *
 *   node scripts/resync-bigtehn-naziv-dela-prefix.js --prefix=9811
 *   node scripts/resync-bigtehn-naziv-dela-prefix.js --prefix=9811-1 --dry-run
 */

import { createLogger } from '../src/logger.js';

const logger = createLogger(
  process.env.LOG_LEVEL?.toLowerCase() || 'info',
  'resync-naziv-dela',
);

function parseArgs(argv) {
  const out = { prefix: null, dryRun: false, batch: 500 };
  for (const a of argv.slice(2)) {
    if (a === '--dry-run') out.dryRun = true;
    else if (a.startsWith('--prefix=')) out.prefix = a.slice('--prefix='.length).trim() || null;
    else if (a.startsWith('--batch=')) {
      const n = parseInt(a.slice('--batch='.length), 10);
      if (Number.isFinite(n) && n > 0) out.batch = n;
    } else if (a === '-h' || a === '--help') out.help = true;
  }
  return out;
}

function printHelp() {
  process.stdout.write(
    [
      'Usage: node scripts/resync-bigtehn-naziv-dela-prefix.js --prefix=9811-1 [options]',
      '',
      '  --prefix=9811-1   obavezno; MSSQL: IdentBroj LIKE prefix + %',
      '  --batch=500       veličina batch-a',
      '  --dry-run         samo broji, bez upisa u Supabase',
      '',
    ].join('\n') + '\n',
  );
}

async function* selectMssqlByPrefix(sql, pool, prefix, batchSize) {
  let lastId = 0;
  while (true) {
    const req = pool.request();
    req.input('LastId', sql.Int, lastId);
    req.input('BatchSize', sql.Int, batchSize);
    req.input('Prefix', sql.NVarChar(50), prefix);
    const res = await req.query(`
      SELECT TOP (@BatchSize) IDRN, IdentBroj, NazivDela
      FROM dbo.tRN
      WHERE IDRN > @LastId
        AND IdentBroj LIKE @Prefix + '%'
      ORDER BY IDRN ASC
    `);
    const rows = res.recordset ?? [];
    if (rows.length === 0) return;
    lastId = Number(rows[rows.length - 1].IDRN);
    yield rows;
    if (rows.length < batchSize) return;
  }
}

async function main() {
  const args = parseArgs(process.argv);
  if (args.help || !args.prefix) {
    printHelp();
    process.exit(args.prefix ? 0 : 1);
  }

  const [{ default: sql }, { config }, { createMssqlClient }, { createClient }] =
    await Promise.all([
      import('mssql'),
      import('../src/config.js'),
      import('../src/mssqlClient.js'),
      import('@supabase/supabase-js'),
    ]);

  const sb = createClient(config.supabase.url, config.supabase.serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const mssqlWrap = await createMssqlClient(config.mssql);
  const pool = mssqlWrap.pool;
  const syncedAt = new Date().toISOString();

  let seen = 0;
  let updated = 0;
  let errors = 0;

  try {
    for await (const rows of selectMssqlByPrefix(sql, pool, args.prefix, args.batch)) {
      seen += rows.length;
      if (args.dryRun) {
        logger.info('dry-run batch', { seen, sample: rows[0]?.IdentBroj });
        continue;
      }
      const chunk = 40;
      for (let i = 0; i < rows.length; i += chunk) {
        const slice = rows.slice(i, i + chunk);
        await Promise.all(
          slice.map(async r => {
            const id = Number(r.IDRN);
            const naziv =
              r.NazivDela == null ? null : String(r.NazivDela).trim() || null;
            const { error } = await sb
              .from('bigtehn_work_orders_cache')
              .update({ naziv_dela: naziv, synced_at: syncedAt })
              .eq('id', id);
            if (error) {
              errors++;
              logger.warn('update failed', { id, ident: r.IdentBroj, error: error.message });
            } else {
              updated++;
            }
          }),
        );
      }
      logger.info('batch', { seen, updated, errors, last_ident: rows[rows.length - 1]?.IdentBroj });
    }
    logger.info('done', { prefix: args.prefix, seen, updated, errors, dry_run: args.dryRun });
  } finally {
    await mssqlWrap.close();
  }
}

main().catch(err => {
  logger.error('fatal', { error: err?.message || String(err) });
  process.exit(1);
});
