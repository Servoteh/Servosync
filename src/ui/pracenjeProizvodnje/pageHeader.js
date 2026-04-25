import { escHtml } from '../../lib/dom.js';

export function pageHeaderHtml(state) {
  const h = state.header || {};
  const summary = state.tab1Data?.summary || {};
  const dashboard = state.dashboard?.total || {};
  const totalOps = Number(summary.operacija_total || 0);
  const doneOps = Number(summary.zavrseno || 0);
  const pct = totalOps > 0 ? Math.round((doneOps / totalOps) * 100) : 0;
  const late = countLate(state.tab2Data?.activities || []);

  return `
    <section class="form-card" style="margin-bottom:14px">
      <div style="display:flex;justify-content:space-between;gap:16px;align-items:flex-start;flex-wrap:wrap">
        <div>
          <div class="form-section-title">Praćenje proizvodnje</div>
          <h2 style="margin:4px 0 6px">${escHtml(h.rn_broj || 'RN nije učitan')} · ${escHtml(h.masina_linija || h.radni_nalog_naziv || '')}</h2>
          <div class="form-hint">
            Kupac: <strong>${escHtml(h.kupac || '—')}</strong>
            · Projekat: <strong>${escHtml(h.projekat_naziv || h.projekat_id || '—')}</strong>
            · Isporuka: <strong>${escHtml(h.datum_isporuke || '—')}</strong>
            · Koordinator: <strong>${escHtml(h.koordinator || '—')}</strong>
          </div>
          ${h.napomena ? `<div class="form-hint" style="margin-top:6px">Napomena: ${escHtml(h.napomena)}</div>` : ''}
        </div>
        <div style="display:flex;gap:8px;flex-wrap:wrap;justify-content:flex-end">
          ${metric('Završeno operacija', `${pct}%`)}
          ${metric('Kasni aktivnosti', late)}
          ${metric('Aktivnosti', dashboard.ukupno ?? (state.tab2Data?.activities || []).length)}
          ${state.canEdit ? metric('Pristup', 'edit') : metric('Pristup', 'read-only')}
        </div>
      </div>
    </section>
  `;
}

function metric(label, value) {
  return `
    <div class="pp-counter" style="min-width:116px;text-align:center">
      <div style="font-size:18px;font-weight:800;color:var(--text)">${escHtml(value)}</div>
      <div style="font-size:11px;text-transform:uppercase;letter-spacing:.35px">${escHtml(label)}</div>
    </div>
  `;
}

function countLate(activities) {
  return activities.filter(a => a.kasni).length;
}
