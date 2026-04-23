/**
 * Plan Proizvodnje — grupisanje mašina po proizvodnoj tehnologiji.
 *
 * Source of truth: `bigtehn_machines_cache` (rj_code, name, department_id,
 * no_procedure). Bridge sync (BigTehn → Supabase) puni tu tabelu, a ovde u
 * čisto klijentskoj mapi tih ~100 mašina grupišemo u proizvodne kategorije
 * koje šef mašinske obrade prepoznaje.
 *
 * Zašto klijentska mapa, a ne nova SQL tabela:
 *   - Zero-touch baza: ne diramo BigTehn šemu niti novu app-tabelu — sve
 *     već postoji u poljima `department_id` i `rj_code`.
 *   - Brz feedback loop: promena grupe = jedan commit + Vite HMR, bez
 *     migracije.
 *   - Lako za testiranje (čista funkcija + statičan input iz baze).
 *
 * ── Grupe (iteracija 2) ─────────────────────────────────────────────────
 * Dva reda u UI chip-bar-u. Redosled i imena potvrđeni sa korisnikom:
 *
 *   Red 1:  Sve │ Glodanje │ Struganje │ Brušenje │ Erodiranje │ Ažistiranje
 *   Red 2:  Sečenje i savijanje │ Bravarsko │ Farbanje i površinska zaštita │
 *           CAM programiranje │ Ostalo
 *
 * Mapa mašina → grupa (po redu):
 *   glodanje            — dept '03' (SVE, uklj. 3.21/3.22 TOS WHN 13)
 *   struganje           — dept '02'
 *   brusenje            — dept '06'
 *   erodiranje          — dept '10' (Sodick, Charmilles, probijačica)
 *   azistiranje         — rj_code '8.2' (SAMO ručni radovi–ažistiranje)
 *   secenje_savijanje   — dept '01' (testera, makaze, gas, voda, plazma, laser)
 *                         + dept '15' (Apkant Hammerle)
 *   bravarsko           — rj_code 4.1, 4.11, 4.12 (savijanje + bušilice) +
 *                         4.2, 4.3, 4.4 (zavarivanje MIG-MAG, REL, TIG)
 *   farbanje            — dept '05' + rj_code '5.11'
 *   cam                 — dept '17' (CAM glodanje, CAM struganje)
 *   ostalo              — fallback: Termička obrada (dept 07), 3D štampa
 *                         (dept 21), Kooperacija/Nabavka (9.0/9.1), Opšti
 *                         nalog (0.0), Graviranje (5.9/6.8), Ispravljanje
 *                         (7.5), Štos (3.50), kontrola (8.1/8.3/8.4) itd.
 *
 * Public API:
 *   MACHINE_GROUPS                 — niz konfigova {id, label, row, match}
 *   MACHINE_GROUPS_ROW_1 / ROW_2   — pomoćni pre-filter za UI 2-redni bar
 *   getMachineGroup(machine)       — vrati id grupe za jednu mašinu
 *   filterMachinesByGroup(machines, groupId)
 *   countMachinesPerGroup(machines)
 *   sortMachinesByGroupOrder(machines)
 *   machineGroupLabel(groupId)
 */

/** rj_code-ovi bravarske grupe (savijanje + bušenje + zavarivanje). */
const BRAVARSKO_RJ_CODES = new Set([
  '4.1', '4.11', '4.12',
  '4.2', '4.3', '4.4',
]);

/**
 * Konfiguracija grupa. Redosled u nizu = redosled u UI chip-bar-u.
 *
 * `match(machine)` mora biti čista funkcija nad poljima `rj_code` i
 * `department_id`. Prva grupa (osim 'all' i 'ostalo') koja vrati true
 * uzima mašinu — zato je redosled bitan i specifične grupe idu pre širih.
 *
 * `row` (1 ili 2) govori UI-ju u kom redu chip-bar-a renderovati.
 */
export const MACHINE_GROUPS = [
  /* ── Red 1 ─────────────────────────────────────────────────────────── */
  {
    id: 'all',
    label: 'Sve',
    row: 1,
    match: () => true,
  },
  {
    id: 'glodanje',
    label: 'Glodanje',
    row: 1,
    match: (m) => m?.department_id === '03',
  },
  {
    id: 'struganje',
    label: 'Struganje',
    row: 1,
    match: (m) => m?.department_id === '02',
  },
  {
    id: 'brusenje',
    label: 'Brušenje',
    row: 1,
    match: (m) => m?.department_id === '06',
  },
  {
    id: 'erodiranje',
    label: 'Erodiranje',
    row: 1,
    match: (m) => m?.department_id === '10',
  },
  {
    id: 'azistiranje',
    label: 'Ažistiranje',
    row: 1,
    match: (m) => String(m?.rj_code || '') === '8.2',
  },

  /* ── Red 2 ─────────────────────────────────────────────────────────── */
  {
    id: 'secenje_savijanje',
    label: 'Sečenje i savijanje',
    row: 2,
    /* Dept 01 = sečenje (testera, makaze, gas, voda, plazma, laser),
       dept 15 = Apkant presa (Hammerle 3100/4100). */
    match: (m) =>
      m?.department_id === '01' || m?.department_id === '15',
  },
  {
    id: 'bravarsko',
    label: 'Bravarsko',
    row: 2,
    match: (m) => BRAVARSKO_RJ_CODES.has(String(m?.rj_code || '')),
  },
  {
    id: 'farbanje',
    label: 'Farbanje i površinska zaštita',
    row: 2,
    match: (m) =>
      m?.department_id === '05' || String(m?.rj_code || '') === '5.11',
  },
  {
    id: 'cam',
    label: 'CAM programiranje',
    row: 2,
    match: (m) => m?.department_id === '17',
  },
  {
    id: 'ostalo',
    label: 'Ostalo',
    row: 2,
    match: () => true, /* fallback hvata sve što nije uhvaćeno gore */
  },
];

export const MACHINE_GROUPS_ROW_1 = MACHINE_GROUPS.filter((g) => g.row === 1);
export const MACHINE_GROUPS_ROW_2 = MACHINE_GROUPS.filter((g) => g.row === 2);

const GROUP_BY_ID = new Map(MACHINE_GROUPS.map((g) => [g.id, g]));
const GROUP_ORDER = new Map(MACHINE_GROUPS.map((g, i) => [g.id, i]));

/* Specifične grupe (sve osim 'all' i 'ostalo') po redosledu — koristimo
 * ih za rezolvuciju kojoj grupi mašina pripada. „Sve" hvata sve i ne sme
 * biti deo rezolucije, „Ostalo" je fallback na kraju. */
const SPECIFIC_GROUPS = MACHINE_GROUPS.filter(
  (g) => g.id !== 'all' && g.id !== 'ostalo',
);

/**
 * Vrati id grupe kojoj mašina pripada (specifičnoj). Ako ni jedna ne uhvati
 * — `'ostalo'`. Nikad ne vraća `'all'` (to je virtuelna grupa „prikaži sve").
 *
 * @param {{rj_code?: string, department_id?: string|null}|null} machine
 * @returns {string} group id
 */
export function getMachineGroup(machine) {
  if (!machine) return 'ostalo';
  for (const g of SPECIFIC_GROUPS) {
    if (g.match(machine)) return g.id;
  }
  return 'ostalo';
}

/**
 * @param {Array<object>} machines
 * @param {string} groupId
 * @returns {Array<object>}
 */
export function filterMachinesByGroup(machines, groupId) {
  if (!Array.isArray(machines)) return [];
  if (!groupId || groupId === 'all') return machines.slice();
  const g = GROUP_BY_ID.get(groupId);
  if (!g) return machines.slice();
  if (groupId === 'ostalo') {
    return machines.filter((m) => getMachineGroup(m) === 'ostalo');
  }
  return machines.filter((m) => g.match(m));
}

/**
 * Broj mašina po grupi. Mašina ulazi u tačno jednu specifičnu grupu (ili
 * 'ostalo'). Grupa 'all' je ukupno.
 *
 * @param {Array<object>} machines
 * @returns {Map<string, number>}
 */
export function countMachinesPerGroup(machines) {
  const counts = new Map(MACHINE_GROUPS.map((g) => [g.id, 0]));
  if (!Array.isArray(machines)) return counts;
  counts.set('all', machines.length);
  for (const m of machines) {
    const id = getMachineGroup(m);
    counts.set(id, (counts.get(id) || 0) + 1);
  }
  return counts;
}

/**
 * Sort mašina tako da se prvo prikazuju mašine iz „prirodne" tehnološke
 * grupe po redosledu definicije, pa onda po `rj_code` natural-sort unutar
 * grupe.
 *
 * @param {Array<object>} machines
 * @returns {Array<object>}
 */
export function sortMachinesByGroupOrder(machines) {
  if (!Array.isArray(machines)) return [];
  return machines.slice().sort((a, b) => {
    const ga = GROUP_ORDER.get(getMachineGroup(a)) ?? 9999;
    const gb = GROUP_ORDER.get(getMachineGroup(b)) ?? 9999;
    if (ga !== gb) return ga - gb;
    return String(a?.rj_code || '').localeCompare(
      String(b?.rj_code || ''),
      'sr',
      { numeric: true, sensitivity: 'base' },
    );
  });
}

/**
 * @param {string} groupId
 * @returns {string}
 */
export function machineGroupLabel(groupId) {
  return GROUP_BY_ID.get(groupId)?.label || 'Sve';
}
