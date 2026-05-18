/**
 * Column sort utility (C5).
 *
 * Reusable pattern: klikni na <th data-sort-key="..."> → cikluje asc → desc → reset.
 * State persistira u sessionStorage pod zadatim ključem.
 *
 * Pattern:
 *
 *   const sort = createColumnSort({
 *     storageKey: 'pm_abs_sort_v1',
 *     accessors: {
 *       employee: (r) => r.employeeName,
 *       type:     (r) => r.type,
 *       dateFrom: (r) => r.dateFrom || '',
 *       dateTo:   (r) => r.dateTo   || '',
 *       days:     (r) => Number(r.daysCount || 0),
 *     },
 *     onChange: () => refreshTab(),
 *   });
 *
 *   // U HTML: <th data-sort-key="employee" class="sortable">Zaposleni <span class="kadr-sort-ind"></span></th>
 *   // U wire: sort.wire(panelEl, '#myTable');
 *   // U refresh: const sorted = sort.apply(filtered);  sort.updateIndicators(panelEl, '#myTable');
 *
 * Tabela MORA imati klasu .kadr-sortable na <table> da bi CSS hover/indicator radio.
 */

/**
 * @param {{
 *   storageKey: string,
 *   accessors: Record<string, (row:any)=>any>,
 *   onChange: () => void,
 * }} opts
 */
export function createColumnSort(opts) {
  const { storageKey, accessors, onChange } = opts || {};
  if (!storageKey || !accessors || typeof onChange !== 'function') {
    throw new Error('createColumnSort: storageKey, accessors, onChange required');
  }

  let state = (() => {
    try {
      const raw = sessionStorage.getItem(storageKey);
      if (!raw) return { key: null, dir: null };
      const [k, d] = raw.split(':');
      if (!k || (d !== 'asc' && d !== 'desc')) return { key: null, dir: null };
      if (!accessors[k]) return { key: null, dir: null };
      return { key: k, dir: d };
    } catch { return { key: null, dir: null }; }
  })();

  function persist() {
    try {
      if (state.key) sessionStorage.setItem(storageKey, `${state.key}:${state.dir}`);
      else sessionStorage.removeItem(storageKey);
    } catch { /* noop */ }
  }

  function cycle(key) {
    if (!accessors[key]) return;
    if (state.key !== key) state = { key, dir: 'asc' };
    else if (state.dir === 'asc') state = { key, dir: 'desc' };
    else state = { key: null, dir: null };
    persist();
    onChange();
  }

  /** Vraća sortiran NIZ (immutable kopija). Ako nema active sort → vraća original list. */
  function apply(list) {
    if (!state.key) return list;
    const acc = accessors[state.key];
    const sign = state.dir === 'desc' ? -1 : 1;
    return list.slice().sort((a, b) => {
      const va = acc(a);
      const vb = acc(b);
      /* Numerička poređenja ako su oba broja */
      if (typeof va === 'number' && typeof vb === 'number') {
        if (va === vb) return 0;
        return va < vb ? -1 * sign : 1 * sign;
      }
      const sa = String(va ?? '').toLowerCase();
      const sb = String(vb ?? '').toLowerCase();
      if (sa === sb) return 0;
      if (!sa) return 1;   /* prazne na kraju */
      if (!sb) return -1;
      return sa < sb ? -1 * sign : 1 * sign;
    });
  }

  function wire(rootEl, tableSelector) {
    if (!rootEl) return;
    const table = rootEl.querySelector(tableSelector);
    if (!table) return;
    table.classList.add('kadr-sortable');
    table.querySelectorAll('th[data-sort-key].sortable').forEach(th => {
      th.addEventListener('click', () => cycle(th.dataset.sortKey));
    });
  }

  function updateIndicators(rootEl, tableSelector) {
    if (!rootEl) return;
    const table = rootEl.querySelector(tableSelector);
    if (!table) return;
    table.querySelectorAll('th[data-sort-key].sortable').forEach(th => {
      const key = th.dataset.sortKey;
      const ind = th.querySelector('.kadr-sort-ind');
      const active = state.key === key;
      th.classList.toggle('is-sorted', active);
      th.classList.toggle('is-sorted-desc', active && state.dir === 'desc');
      if (ind) {
        ind.textContent = active ? (state.dir === 'desc' ? '▼' : '▲') : '';
      }
    });
  }

  return { apply, wire, updateIndicators, getState: () => ({ ...state }) };
}
