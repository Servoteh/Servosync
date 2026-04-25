import { escHtml } from '../../lib/dom.js';
import { statusBadgeHtml } from './statusBadge.js';

export function dashboardFooterHtml(state) {
  const dashboard = state.dashboard || {};
  const total = dashboard.total || {};
  const poOdeljenjima = dashboard.po_odeljenjima || [];
  const late = topLateActivities(state.tab2Data?.activities || []);

  return `
    <section class="form-card" style="margin-top:14px">
      <div class="form-section-title">Pregled operativnog plana</div>
      <div style="display:flex;gap:8px;flex-wrap:wrap;margin:10px 0 14px">
        ${metric('Ukupno', total.ukupno ?? 0)}
        ${metric('Završeno', total.zavrseno ?? 0)}
        ${metric('U toku', total.u_toku ?? 0)}
        ${metric('Blokirano', total.blokirano ?? 0)}
        ${metric('Nije krenulo', total.nije_krenulo ?? 0)}
        ${metric('Najkasniji plan', total.najkasniji_planirani_zavrsetak || '—')}
      </div>
      <div style="display:grid;grid-template-columns:minmax(280px,1fr) minmax(280px,1fr);gap:14px">
        <div class="pp-table-wrap">
          <table class="pp-table">
            <thead>
              <tr>
                <th>Odeljenje</th><th class="pp-cell-num">Ukupno</th><th>Završeno</th><th>U toku</th><th>Blokirano</th><th>Najkasnije</th>
              </tr>
            </thead>
            <tbody>
              ${poOdeljenjima.length ? poOdeljenjima.map(r => `
                <tr>
                  <td class="pp-cell-strong">${escHtml(r.odeljenje || '—')}</td>
                  <td class="pp-cell-num">${escHtml(r.ukupno ?? 0)}</td>
                  <td>${escHtml(r.zavrseno ?? 0)}</td>
                  <td>${escHtml(r.u_toku ?? 0)}</td>
                  <td>${escHtml(r.blokirano ?? 0)}</td>
                  <td>${escHtml(r.najkasniji_planirani_zavrsetak || '—')}</td>
                </tr>
              `).join('') : `<tr><td colspan="6" class="pp-cell-muted">Nema aktivnosti po odeljenjima.</td></tr>`}
            </tbody>
          </table>
        </div>
        <div class="pp-table-wrap">
          <table class="pp-table">
            <thead><tr><th>Top kašnjenja</th><th>Status</th><th class="pp-cell-num">Rezerva</th></tr></thead>
            <tbody>
              ${late.length ? late.map(a => `
                <tr>
                  <td>${escHtml(a.naziv_aktivnosti || '—')}</td>
                  <td>${statusBadgeHtml(a, { button: false })}</td>
                  <td class="pp-cell-num">${escHtml(a.rezerva_dani ?? '—')}</td>
                </tr>
              `).join('') : `<tr><td colspan="3" class="pp-cell-muted">Nema aktivnosti koje kasne.</td></tr>`}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  `;
}

function metric(label, value) {
  return `
    <div class="pp-counter">
      <strong style="color:var(--text)">${escHtml(value)}</strong>
      <span style="margin-left:6px">${escHtml(label)}</span>
    </div>
  `;
}

function topLateActivities(activities) {
  return [...(activities || [])]
    .filter(a => a.kasni)
    .sort((a, b) => Number(a.rezerva_dani ?? 99999) - Number(b.rezerva_dani ?? 99999))
    .slice(0, 5);
}
