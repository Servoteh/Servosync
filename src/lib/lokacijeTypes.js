/**
 * Poslovna klasifikacija `loc_locations.location_type`.
 *
 * Baza koristi jedan enum za sve vrste lokacija, ali UI mora svuda da govori
 * istim jezikom: HALA je veći prostor, POLICA je konkretno mesto unutar hale.
 */

export const HALL_TYPES = Object.freeze(['WAREHOUSE', 'PRODUCTION', 'ASSEMBLY', 'FIELD', 'TEMP']);
export const SHELF_TYPES = Object.freeze(['SHELF', 'RACK', 'BIN']);

export const HALL_TYPE_OPTIONS = Object.freeze([
  { value: 'WAREHOUSE', label: 'Magacin / standardna hala' },
  { value: 'PRODUCTION', label: 'Proizvodnja' },
  { value: 'ASSEMBLY', label: 'Montaža / sklapanje' },
  { value: 'FIELD', label: 'Teren' },
  { value: 'TEMP', label: 'Privremena zona' },
]);

const HALL_SET = new Set(HALL_TYPES);
const SHELF_SET = new Set(SHELF_TYPES);

export function normalizeLocType(type) {
  return String(type || '').trim().toUpperCase();
}

export function isHallType(type) {
  return HALL_SET.has(normalizeLocType(type));
}

export function isShelfType(type) {
  return SHELF_SET.has(normalizeLocType(type));
}

export function getLocationKind(type) {
  if (isHallType(type)) return 'hall';
  if (isShelfType(type)) return 'shelf';
  return 'other';
}

export function getLocationKindLabel(type, { icon = false } = {}) {
  const kind = getLocationKind(type);
  if (kind === 'hall') return icon ? 'HALA' : 'HALA';
  if (kind === 'shelf') return icon ? 'POLICA' : 'POLICA';
  return icon ? 'OSTALO' : 'OSTALO';
}

export function getLocationTypeLabel(type) {
  const t = normalizeLocType(type);
  const found = HALL_TYPE_OPTIONS.find(o => o.value === t);
  if (found) return found.label;
  if (t === 'SHELF') return 'Polica';
  if (t === 'RACK') return 'Regal';
  if (t === 'BIN') return 'Boks / pozicija';
  return t || 'Nepoznato';
}

export function canBeShelfParent(loc) {
  return !!loc && loc.is_active !== false && isHallType(loc.location_type);
}
