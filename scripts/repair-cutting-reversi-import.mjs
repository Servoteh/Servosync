#!/usr/bin/env node
/**
 * Repair pogrešno uvezene REVERSI (CUTTING_TOOL + MACHINE) redove koji su završili u magacinu.
 *
 * Očekuje se da je bulk import već koristio `bulk_import_legacy_key` i `legacy_skip_source_decrement`;
 * ovaj skript je za starije uvoz gdje je magacin dobijao ``pre-seed`` pa su količine pogrešne.
 *
 * Korišćenje:
 *   SUPABASE_URL=... SERVICE_ROLE_KEY=... node scripts/repair-cutting-reversi-import.mjs --file=stavke.csv [--dry-run]
 *
 * Bez service role ključa skripta ne dira bazu — ispiše plan ili grešku.
 *
 * Produkcijske SQL operacije za „storno’’ magacina / usklađivanje zavisne su od konkretnog stanja;
 * proširi ovaj fajl `matchRowsFromCsv`-om i RPC pozivima kada se potvrdi format CSV iz legacy sistema.
 */

import process from 'node:process';

const args = Object.fromEntries(
  process.argv.slice(2).map((a) => {
    const [k, v] = a.split('=');
    return [k.replace(/^--/, ''), v ?? true];
  }),
);

async function main() {
  const dry = args['dry-run'] !== false && args['dry-run'] !== 'false';
  // eslint-disable-next-line no-console
  console.log(
    `[repair-cutting-reversi-import] dry-run=${dry} file=${args.file || '(none)'} — stub: ovde dodati parsiranje CSV, hash legacy ključa, i transakcione pozive Supabase.`,
  );
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
