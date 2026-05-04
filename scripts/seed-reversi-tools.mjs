/**
 * Reversi Sprint R2 — Seed alata iz xlsx fajlova
 *
 * Sta radi:
 *  1. Kreira lokaciju magacina alata ALAT-MAG-01 (ako ne postoji)
 *  2. Uvozi alate iz dva xlsx fajla u rev_tools (preskače duplikat oznaka)
 *  3. Za svaki alat kreira INITIAL_PLACEMENT u magacinu (ako ne postoji)
 *  4. Za alate koji su zaduzeni: kreira rev_documents + rev_document_lines
 *     + REVERSAL_ISSUE pokret (ako reversal za taj alat vec ne postoji)
 *
 * Pokretanje:
 *   node scripts/seed-reversi-tools.mjs
 *
 * Obavezni env vars:
 *   SUPABASE_URL
 *   SUPABASE_SERVICE_ROLE_KEY
 *   SEED_ISSUED_BY_USER_ID   — UUID iz auth.users za issued_by na dokumentima
 *
 * Za RPC (loc_create_movement zahteva auth.uid()):
 *   SUPABASE_ANON_KEY
 *   SEED_USER_JWT            — JWT korisnika (npr. admin) koji sme da poziva loc_create_movement
 *
 * Opcioni:
 *   DRY_RUN=true
 */

import { createClient } from '@supabase/supabase-js'
import * as XLSX from 'xlsx'
import { readFileSync, existsSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import { config } from 'dotenv'

config()

const __dirname = dirname(fileURLToPath(import.meta.url))

const SUPABASE_URL = process.env.SUPABASE_URL
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY
const SEED_ISSUED_BY = process.env.SEED_ISSUED_BY_USER_ID
const SEED_USER_JWT = process.env.SEED_USER_JWT
const DRY_RUN = process.env.DRY_RUN === 'true'

const MAG_LOCATION_CODE = 'ALAT-MAG-01'
const MAG_LOCATION_NAME = 'Magacin alata'

const XLSX_FILES = [
  {
    path: resolve(__dirname, 'data/Akumulatorske_brusilice.xlsx'),
    label: 'Brusilice',
  },
  {
    path: resolve(__dirname, 'data/Akumulatorske_s_rafilice_hilti.xlsx'),
    label: 'Šrafilice Hilti',
  },
]

if (!SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
  console.error('❌  SUPABASE_URL i SUPABASE_SERVICE_ROLE_KEY su obavezni.')
  process.exit(1)
}
if (!SEED_ISSUED_BY) {
  console.error('❌  SEED_ISSUED_BY_USER_ID je obavezan.')
  process.exit(1)
}
if (!DRY_RUN && (!SUPABASE_ANON_KEY || !SEED_USER_JWT)) {
  console.error(
    '❌  Za pravo pokretanje potrebni su SUPABASE_ANON_KEY i SEED_USER_JWT (JWT korisnika sa pravom na lokacije — loc_create_movement koristi auth.uid()).'
  )
  process.exit(1)
}

if (DRY_RUN) {
  console.log('🔍  DRY RUN — ništa se neće upisati u bazu.')
}

/** Service role — zaobilazi RLS za insert/select tabele */
const adminSb = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

/** Korisnički JWT — za RPC koji zahteva auth.uid() */
const userSb =
  SUPABASE_ANON_KEY && SEED_USER_JWT
    ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
        auth: { autoRefreshToken: false, persistSession: false },
        global: { headers: { Authorization: `Bearer ${SEED_USER_JWT}` } },
      })
    : null

function log(msg) {
  console.log(`  ${msg}`)
}
function ok(msg) {
  console.log(`  ✅  ${msg}`)
}
function skip(msg) {
  console.log(`  ⏭️   ${msg}`)
}
function warn(msg) {
  console.warn(`  ⚠️   ${msg}`)
}
function err(msg) {
  console.error(`  ❌  ${msg}`)
}

function parseDate(raw) {
  if (!raw || String(raw).trim() === '' || String(raw) === 'NaN') return null
  const s = String(raw).trim().replace(' 00:00:00', '').replace(/\.$/, '')
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return s
  const dot = s.match(/^(\d{1,2})\.(\d{1,2})\.(\d{4})$/)
  if (dot) {
    const [, d, m, y] = dot
    return `${y}-${m.padStart(2, '0')}-${d.padStart(2, '0')}`
  }
  return null
}

function classifyRecipient(zaduzio) {
  if (!zaduzio || String(zaduzio).trim() === '' || String(zaduzio) === 'NaN') {
    return { type: 'MAGACIN', label: '' }
  }
  const z = String(zaduzio).trim()
  const zl = z.toLowerCase()
  const magacinKw = ['magacin']
  const deptKw = ['odeljenje', 'odelenje', 'hala', 'hidraulika', 'bravarsko', 'montaža', 'montaza']
  if (magacinKw.some((k) => zl.includes(k))) return { type: 'MAGACIN', label: z }
  if (deptKw.some((k) => zl.includes(k))) return { type: 'DEPARTMENT', label: z }
  return { type: 'EMPLOYEE', label: z }
}

function toSlug(str) {
  return str
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .substring(0, 50)
}

function parseXlsx(filePath) {
  const wb = XLSX.readFile(filePath)
  const ws = wb.Sheets[wb.SheetNames[0]]
  const rows = XLSX.utils.sheet_to_json(ws, { defval: '' })
  return rows.map((row) => {
    const clean = {}
    for (const [k, v] of Object.entries(row)) {
      clean[k.trim()] = typeof v === 'string' ? v.trim() : v
    }
    return clean
  })
}

/** Sledeći broj dokumenta kao u rev_next_doc_number (TOOL) — ako RPC ne radi */
async function nextToolDocNumber() {
  const prefix = 'REV-TOOL'
  const year = String(new Date().getFullYear())
  const pattern = `${prefix}-${year}-`
  const { data: rows, error } = await adminSb
    .from('rev_documents')
    .select('doc_number')
    .like('doc_number', `${pattern}%`)
  if (error) {
    warn(`Čitanje rev_documents za numeraciju: ${error.message}`)
    return `${pattern}${String(1).padStart(4, '0')}`
  }
  let max = 0
  for (const r of rows || []) {
    const m = String(r.doc_number || '').match(/-(\d{4})$/)
    if (m) max = Math.max(max, parseInt(m[1], 10))
  }
  return `${pattern}${String(max + 1).padStart(4, '0')}`
}

async function rpcRevNextDocNumber() {
  if (!userSb) return nextToolDocNumber()
  const { data, error } = await userSb.rpc('rev_next_doc_number', { p_doc_type: 'TOOL' })
  if (error || data == null) {
    warn(`rev_next_doc_number RPC: ${error?.message || 'null'} — koristim lokalnu numeraciju`)
    return nextToolDocNumber()
  }
  return typeof data === 'string' ? data : String(data)
}

async function rpcGetOrCreateRecipientLocation(recipientType, recipientKey, recipientLabel) {
  if (!userSb) throw new Error('userSb nije konfigurisan')
  const { data, error } = await userSb.rpc('rev_get_or_create_recipient_location', {
    p_recipient_type: recipientType,
    p_recipient_key: recipientKey,
    p_recipient_label: recipientLabel,
  })
  if (error) throw new Error(error.message)
  return data
}

/**
 * Virtuelna lokacija primaoca — fallback ako RPC nije dostupan service JWT-u
 */
async function ensureRecipientLocationFallback(recipientType, recipientKey, recipientLabel) {
  const { data: existing } = await adminSb
    .from('rev_recipient_locations')
    .select('loc_location_id')
    .eq('recipient_type', recipientType)
    .eq('recipient_key', recipientKey)
    .maybeSingle()

  if (existing?.loc_location_id) return existing.loc_location_id

  let locCode
  let locType
  if (recipientType === 'EMPLOYEE') {
    locType = 'FIELD'
    locCode = `ZADU-R-${recipientKey.substring(0, 8)}`
  } else if (recipientType === 'DEPARTMENT') {
    locType = 'FIELD'
    locCode = `ZADU-O-${recipientKey}`
  } else {
    locType = 'SERVICE'
    locCode = `ZADU-K-${recipientKey}`
  }

  const { data: locRow, error: locErr } = await adminSb
    .from('loc_locations')
    .upsert(
      {
        location_code: locCode,
        name: `Zaduzeno: ${recipientLabel}`,
        location_type: locType,
        is_active: true,
        notes: 'Automatski kreirana virtuelna lokacija za reversal primalac (seed R2)',
      },
      { onConflict: 'location_code' }
    )
    .select('id')
    .single()

  if (locErr) throw new Error(locErr.message)

  await adminSb.from('rev_recipient_locations').upsert(
    {
      recipient_type: recipientType,
      recipient_key: recipientKey,
      recipient_label: recipientLabel,
      loc_location_id: locRow.id,
    },
    { onConflict: 'recipient_type,recipient_key' }
  )

  return locRow.id
}

async function rpcLocCreateMovement(payload) {
  if (!userSb) throw new Error('SEED_USER_JWT potreban za loc_create_movement')
  const { data, error } = await userSb.rpc('loc_create_movement', { payload })
  if (error) throw new Error(error.message)
  if (!data || typeof data !== 'object') throw new Error('loc_create_movement: prazan odgovor')
  if (data.ok !== true) {
    throw new Error(`loc_create_movement: ${data.error || JSON.stringify(data)}`)
  }
  return data.id
}

async function ensureMagacinLocation() {
  console.log('\n📦  Korak 1: Lokacija magacina alata')

  const { data: existing } = await adminSb
    .from('loc_locations')
    .select('id, location_code, name')
    .eq('location_code', MAG_LOCATION_CODE)
    .maybeSingle()

  if (existing) {
    skip(`Lokacija ${MAG_LOCATION_CODE} već postoji (id: ${existing.id})`)
    return existing.id
  }

  if (DRY_RUN) {
    ok(`[DRY RUN] Kreirao bi lokaciju ${MAG_LOCATION_CODE}`)
    return 'dry-run-location-id'
  }

  const { data, error } = await adminSb
    .from('loc_locations')
    .insert({
      location_code: MAG_LOCATION_CODE,
      name: MAG_LOCATION_NAME,
      location_type: 'WAREHOUSE',
      is_active: true,
      notes: 'Kreirana automatski — seed alata Sprint R2',
    })
    .select('id')
    .single()

  if (error) {
    err(`Greška pri kreiranju lokacije: ${error.message}`)
    process.exit(1)
  }

  ok(`Kreirana lokacija ${MAG_LOCATION_CODE} (id: ${data.id})`)
  return data.id
}

async function importTools() {
  console.log('\n🔧  Korak 2: Uvoz alata iz xlsx fajlova')

  const allTools = []

  for (const { path: xlsxPath, label } of XLSX_FILES) {
    if (!existsSync(xlsxPath)) {
      err(`Nedostaje fajl: ${xlsxPath}\n     Kopiraj xlsx u scripts/data/ (vidi scripts/data/README.txt)`)
      process.exit(1)
    }
    log(`Čitam: ${xlsxPath} (${label})`)
    let rows
    try {
      rows = parseXlsx(xlsxPath)
    } catch (e) {
      err(`Ne mogu da pročitam ${xlsxPath}: ${e.message}`)
      process.exit(1)
    }

    for (const row of rows) {
      const oznaka = String(row['OZNAKA'] ?? '').trim()
      const naziv = String(row['NAZIV'] ?? '').trim()
      if (!oznaka || !naziv) {
        warn(`Preskaćem red bez oznake ili naziva: ${JSON.stringify(row)}`)
        continue
      }
      const zaduzio = row['ZADUŽIO'] ?? row['ZADUZIO'] ?? ''
      const recipient = classifyRecipient(zaduzio)
      allTools.push({
        oznaka,
        naziv,
        napomena: String(row['NAPOMENA'] ?? '').trim() || null,
        datum_kupovine: parseDate(row['DATUM kupovine'] ?? row['DATUM KUPOVINE'] ?? ''),
        status: 'active',
        recipient_type: recipient.type,
        recipient_label: recipient.label,
      })
    }
    ok(`Pročitano ${rows.length} redova iz ${label}`)
  }

  log(`Ukupno alata za uvoz: ${allTools.length}`)

  if (DRY_RUN) {
    ok(`[DRY RUN] Upisao bi ${allTools.length} alata u rev_tools`)
    return allTools.map((t) => ({ ...t, id: null, loc_item_ref_id: null }))
  }

  const seen = new Set()
  let inserted = 0
  for (const t of allTools) {
    if (seen.has(t.oznaka)) continue
    seen.add(t.oznaka)

    const { data: row } = await adminSb.from('rev_tools').select('id, oznaka, loc_item_ref_id').eq('oznaka', t.oznaka).maybeSingle()

    if (row) continue

    const { error } = await adminSb.from('rev_tools').insert({
      oznaka: t.oznaka,
      naziv: t.naziv,
      napomena: t.napomena,
      datum_kupovine: t.datum_kupovine,
      status: t.status,
    })
    if (error) {
      err(`Insert rev_tools ${t.oznaka}: ${error.message}`)
      process.exit(1)
    }
    inserted++
  }

  ok(`Novi insert-i u rev_tools: ${inserted} (postojeće oznake preskočene)`)

  const { data: allInDb, error: fetchError } = await adminSb
    .from('rev_tools')
    .select('id, oznaka, loc_item_ref_id')
    .in(
      'oznaka',
      [...new Set(allTools.map((x) => x.oznaka))]
    )

  if (fetchError) {
    err(`Greška pri čitanju alata: ${fetchError.message}`)
    process.exit(1)
  }

  const idMap = Object.fromEntries((allInDb || []).map((t) => [t.oznaka, t]))
  return allTools.map((t) => ({
    ...t,
    id: idMap[t.oznaka]?.id,
    loc_item_ref_id: idMap[t.oznaka]?.loc_item_ref_id,
  }))
}

async function createInitialPlacements(tools, magacinLocId) {
  console.log('\n📍  Korak 3: INITIAL_PLACEMENT za sve alate u magacinu')

  let created = 0
  let skipped = 0

  for (const tool of tools) {
    if (!tool.id || !tool.loc_item_ref_id) {
      warn(`Alat ${tool.oznaka} nema id — preskačem INITIAL_PLACEMENT`)
      continue
    }

    const { data: existing } = await adminSb
      .from('loc_item_placements')
      .select('id')
      .eq('item_ref_table', 'rev_tools')
      .eq('item_ref_id', tool.loc_item_ref_id)
      .maybeSingle()

    if (existing) {
      skipped++
      continue
    }

    if (DRY_RUN) {
      log(`[DRY RUN] INITIAL_PLACEMENT: ${tool.oznaka} → ${MAG_LOCATION_CODE}`)
      created++
      continue
    }

    try {
      await rpcLocCreateMovement({
        item_ref_table: 'rev_tools',
        item_ref_id: tool.loc_item_ref_id,
        to_location_id: magacinLocId,
        movement_type: 'INITIAL_PLACEMENT',
        movement_reason: 'Seed R2 — početni smeštaj alata',
        note: tool.napomena ?? '',
        quantity: 1,
        order_no: '',
        drawing_no: '',
      })
      created++
    } catch (e) {
      warn(`INITIAL_PLACEMENT za ${tool.oznaka}: ${e.message}`)
    }
  }

  ok(`INITIAL_PLACEMENT: ${created} kreirano, ${skipped} preskočeno (već postoji)`)
}

async function createReversalDocuments(tools, magacinLocId) {
  console.log('\n📋  Korak 4: Reversal dokumenti za zadužene alate')

  const issuedTools = tools.filter((t) => t.recipient_type !== 'MAGACIN')
  log(`Alata sa zaduženjima: ${issuedTools.length}`)

  let created = 0
  let skipped = 0
  let failed = 0

  for (const tool of issuedTools) {
    if (!tool.id || !tool.loc_item_ref_id) {
      warn(`Alat ${tool.oznaka} nema id — preskačem reversal`)
      failed++
      continue
    }

    const { data: existingLine } = await adminSb
      .from('rev_document_lines')
      .select('id')
      .eq('tool_id', tool.id)
      .eq('line_status', 'ISSUED')
      .maybeSingle()

    if (existingLine) {
      skip(`${tool.oznaka} — reversal već postoji`)
      skipped++
      continue
    }

    if (DRY_RUN) {
      log(`[DRY RUN] REV-TOOL za ${tool.oznaka} → ${tool.recipient_type}: "${tool.recipient_label}"`)
      created++
      continue
    }

    let docNum
    try {
      docNum = await rpcRevNextDocNumber()
    } catch (e) {
      warn(`Broj dokumenta za ${tool.oznaka}: ${e.message}`)
      failed++
      continue
    }

    let recipientEmployeeId = null
    let recipientEmployeeName = null
    let recipientDepartment = null
    let revRecipientType = 'EMPLOYEE'

    if (tool.recipient_type === 'EMPLOYEE') {
      recipientEmployeeName = tool.recipient_label
      const { data: emp } = await adminSb
        .from('employees')
        .select('id')
        .ilike('full_name', `%${tool.recipient_label}%`)
        .maybeSingle()
      if (emp) recipientEmployeeId = emp.id
    } else if (tool.recipient_type === 'DEPARTMENT') {
      recipientDepartment = tool.recipient_label
      revRecipientType = 'DEPARTMENT'
    }

    const recipientKey =
      tool.recipient_type === 'EMPLOYEE'
        ? recipientEmployeeId ?? toSlug(tool.recipient_label)
        : toSlug(tool.recipient_label)

    let locId
    try {
      locId = await rpcGetOrCreateRecipientLocation(revRecipientType, recipientKey, tool.recipient_label)
    } catch (e) {
      warn(`RPC virtuelna lokacija za ${tool.oznaka}: ${e.message} — pokušavam direktan upsert`)
      try {
        locId = await ensureRecipientLocationFallback(revRecipientType, recipientKey, tool.recipient_label)
      } catch (e2) {
        warn(`Fallback lokacija za ${tool.oznaka}: ${e2.message}`)
        failed++
        continue
      }
    }

    const issueDate = tool.datum_kupovine
      ? new Date(tool.datum_kupovine + 'T12:00:00Z').toISOString()
      : new Date().toISOString()

    const { data: doc, error: docError } = await adminSb
      .from('rev_documents')
      .insert({
        doc_number: docNum,
        doc_type: 'TOOL',
        recipient_type: revRecipientType,
        recipient_employee_id: recipientEmployeeId,
        recipient_employee_name: recipientEmployeeName,
        recipient_department: recipientDepartment,
        recipient_loc_id: locId,
        issued_at: issueDate,
        issued_by: SEED_ISSUED_BY,
        status: 'OPEN',
        napomena: 'Uvezeno iz xlsx — Sprint R2',
      })
      .select('id')
      .single()

    if (docError) {
      warn(`rev_documents za ${tool.oznaka}: ${docError.message}`)
      failed++
      continue
    }

    const { data: line, error: lineError } = await adminSb
      .from('rev_document_lines')
      .insert({
        document_id: doc.id,
        line_type: 'TOOL',
        tool_id: tool.id,
        quantity: 1,
        unit: 'kom',
        napomena: tool.napomena,
        sort_order: 1,
      })
      .select('id')
      .single()

    if (lineError) {
      warn(`rev_document_lines za ${tool.oznaka}: ${lineError.message}`)
      failed++
      continue
    }

    let movementId
    try {
      movementId = await rpcLocCreateMovement({
        item_ref_table: 'rev_tools',
        item_ref_id: tool.loc_item_ref_id,
        from_location_id: magacinLocId,
        to_location_id: locId,
        movement_type: 'REVERSAL_ISSUE',
        movement_reason: `Reversal: ${docNum}`,
        note: tool.napomena ?? '',
        quantity: 1,
        order_no: '',
        drawing_no: '',
      })
    } catch (e) {
      warn(`REVERSAL_ISSUE za ${tool.oznaka}: ${e.message}`)
      failed++
      continue
    }

    await adminSb.from('rev_document_lines').update({ issue_movement_id: movementId }).eq('id', line.id)

    log(`✅  ${docNum} — ${tool.oznaka} — ${tool.recipient_label}`)
    created++
  }

  ok(`Reversal dokumenti: ${created} kreirano, ${skipped} preskočeno, ${failed} neuspelih`)
  if (failed > 0) warn(`${failed} alata nije kompletno — proveri greške iznad`)
}

async function main() {
  console.log('═══════════════════════════════════════════════════════')
  console.log(' Reversi Sprint R2 — Seed alata iz xlsx')
  console.log(`  Supabase: ${SUPABASE_URL}`)
  console.log(`  Issued by: ${SEED_ISSUED_BY}`)
  console.log(`  Dry run: ${DRY_RUN}`)
  console.log('═══════════════════════════════════════════════════════')

  const magacinLocId = await ensureMagacinLocation()
  const tools = await importTools()
  await createInitialPlacements(tools, magacinLocId)
  await createReversalDocuments(tools, magacinLocId)

  console.log('\n✅  Seed završen.')

  const inMag = tools.filter((t) => t.recipient_type === 'MAGACIN').length
  const issued = tools.filter((t) => t.recipient_type !== 'MAGACIN').length
  const employee = tools.filter((t) => t.recipient_type === 'EMPLOYEE').length
  const dept = tools.filter((t) => t.recipient_type === 'DEPARTMENT').length

  console.log(`\n  Ukupno alata: ${tools.length}`)
  console.log(`  U magacinu:   ${inMag}`)
  console.log(`  Zaduženo:     ${issued} (${employee} radniku, ${dept} odeljenju)`)
}

main().catch((e) => {
  console.error('❌  Fatalna greška:', e)
  process.exit(1)
})
