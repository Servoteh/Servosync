/** Reversi — vrednosti kolone rev_tools.asset_kind (usklađeno sa CHECK u migraciji). */

export const REV_ASSET_KIND = {
  GENERAL_TOOL: 'GENERAL_TOOL',
  PPE_WORKWEAR: 'PPE_WORKWEAR',
  PPE_FOOTWEAR: 'PPE_FOOTWEAR',
  PPE_OTHER: 'PPE_OTHER',
};

/** @type {Record<string, string>} */
export const REV_ASSET_KIND_LABEL = {
  [REV_ASSET_KIND.GENERAL_TOOL]: 'Alat / oprema',
  [REV_ASSET_KIND.PPE_WORKWEAR]: 'Radna odeća',
  [REV_ASSET_KIND.PPE_FOOTWEAR]: 'Zaštitna obuća',
  [REV_ASSET_KIND.PPE_OTHER]: 'Ostala LZO',
};

export const REV_ASSET_KIND_OPTIONS = [
  REV_ASSET_KIND.GENERAL_TOOL,
  REV_ASSET_KIND.PPE_WORKWEAR,
  REV_ASSET_KIND.PPE_FOOTWEAR,
  REV_ASSET_KIND.PPE_OTHER,
];

/**
 * @param {string|null|undefined} kind
 * @returns {string}
 */
export function formatRevAssetKind(kind) {
  if (!kind) return '—';
  return REV_ASSET_KIND_LABEL[kind] || kind;
}

/**
 * Mapiranje iz CSV (zaglavlje: vrsta, klasa, asset_kind, …).
 * @param {string|null|undefined} raw
 * @returns {string} jedna od REV_ASSET_KIND vrednosti
 */
export function parseRevAssetKindCsv(raw) {
  const s = String(raw ?? '')
    .trim()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/\s+/g, '_');
  if (!s) return REV_ASSET_KIND.GENERAL_TOOL;

  const direct = String(raw ?? '').trim().toUpperCase();
  if (direct === 'GENERAL_TOOL' || direct === 'PPE_WORKWEAR' || direct === 'PPE_FOOTWEAR' || direct === 'PPE_OTHER') {
    return direct;
  }

  const gen = new Set(['alat', 'oprema', 'tool', 'general', 'general_tool']);
  const wear = new Set(['radna_odeca', 'odeca', 'workwear', 'kombinezon', 'mantil', 'haljina', 'bluza', 'pantalone']);
  const feet = new Set(['cipele', 'cizme', 'obuca', 'footwear', 'safety_shoes', 'antistaticke_cipele', 'zastitne_cipele']);
  const lzo = new Set(['lzo', 'ppe', 'zastita', 'rukavice', 'naocare', 'slusalice', 'respirator', 'kaciga', 'ostala_lzo']);
  if (gen.has(s)) return REV_ASSET_KIND.GENERAL_TOOL;
  if (wear.has(s)) return REV_ASSET_KIND.PPE_WORKWEAR;
  if (feet.has(s)) return REV_ASSET_KIND.PPE_FOOTWEAR;
  if (lzo.has(s)) return REV_ASSET_KIND.PPE_OTHER;

  return REV_ASSET_KIND.GENERAL_TOOL;
}
