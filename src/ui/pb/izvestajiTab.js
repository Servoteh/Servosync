/**
 * Izveštaji tab — kalendar, unos van-planskih sati, obračun.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { sumHours } from './izvestajiObracun.js';
import {
  createPbWorkReport,
  deletePbWorkReport,
  getPbWorkReportSummary,
} from '../../services/pb.js';
import { setPbIzvestajiSpeechRecog, pbErrorMessage } from './shared.js';

function pad2(n) {
  return String(n).padStart(2, '0');
}

function ymd(d) {
  return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
}

function monthMatrix(year, month0) {
  const first = new Date(year, month0, 1);
  const startPad = (first.getDay() + 6) % 7;
  const weeks = [];
  let cur = new Date(first);
  cur.setDate(1 - startPad);
  for (let w = 0; w < 6; w++) {
    const row = [];
    for (let d = 0; d < 7; d++) {
      row.push(new Date(cur));
      cur.setDate(cur.getDate() + 1);
    }
    weeks.push(row);
  }
  return { weeks };
}

function hoursForDay(reports, dayStr) {
  const rows = reports.filter(r => String(r.datum || '').slice(0, 10) === dayStr);
  const h = sumHours(rows);
  return { rows, h };
}

/**
 * @param {HTMLElement} root
 * @param {{
 *   getWorkReports: () => object[],
 *   getWorkReportsMonthKey?: () => string|null,
 *   loadMonthReports: (year: number, month0: number) => Promise<void>,
 *   engineers: object[],
 *   canEdit: boolean,
 *   defaultEmployeeId: string|null,
 *   actorEmail: string|null,
 *   onRefresh: (year?: number, month0?: number) => Promise<void>|void,
 * }} ctx
 */
export function renderIzvestaji(root, ctx) {
  let viewYear = new Date().getFullYear();
  let viewMonth = new Date().getMonth();
  let selectedDay = ymd(new Date());
  let sliderTicks = 20;

  function engineerForActor() {
    const em = ctx.actorEmail?.toLowerCase()?.trim();
    if (!em) return null;
    const en = ctx.engineers.find(
      e => String(e.email || '').toLowerCase().trim() === em,
    );
    return en?.id ?? null;
  }

  function paint() {
    const reports = ctx.getWorkReports() || [];
    const engDefault = ctx.defaultEmployeeId || engineerForActor() || '';
    const { weeks } = monthMatrix(viewYear, viewMonth);
    const todayStr = ymd(new Date());

    const cells = weeks.map(row => `
      <tr>${row.map(cell => {
        const ds = ymd(cell);
        const inMonth = cell.getMonth() === viewMonth;
        const dow = cell.getDay();
        const isW = dow === 0 || dow === 6;
        const isToday = ds === todayStr;
        const sel = ds === selectedDay;
        const { h } = hoursForDay(reports, ds);
        let cls = 'pb-cal-cell';
        if (!inMonth) cls += ' pb-cal-cell--muted';
        if (isW) cls += ' pb-cal-cell--wknd';
        if (isToday) cls += ' pb-cal-cell--today';
        if (sel) cls += ' pb-cal-cell--sel';
        const dot = h > 0 ? `<span class="pb-cal-dot">• ${escHtml(String(h))}h</span>` : '';
        return `<td><button type="button" class="${cls}" data-day="${escHtml(ds)}">
          <span class="pb-cal-num">${cell.getDate()}</span>${dot}
        </button></td>`;
      }).join('')}</tr>`).join('');

    const monthLabel = new Date(viewYear, viewMonth, 1).toLocaleString('sr-Latn', {
      month: 'long',
      year: 'numeric',
    });

    const dayReports = reports.filter(
      r => String(r.datum || '').slice(0, 10) === selectedDay,
    );

    const defaultFrom = `${viewYear}-${pad2(viewMonth + 1)}-01`;
    const defaultTo = ymd(new Date());

    root.innerHTML = `
      <div class="pb-izv-grid">
        <section class="pb-izv-cal" aria-label="Kalendar">
          <div class="pb-izv-cal-nav">
            <button type="button" class="btn btn-sm" id="pbIzvPrev">←</button>
            <strong>${escHtml(monthLabel)}</strong>
            <button type="button" class="btn btn-sm" id="pbIzvNext">→</button>
          </div>
          <table class="pb-cal-table">
            <thead><tr>
              <th>Pon</th><th>Uto</th><th>Sre</th><th>Čet</th><th>Pet</th><th>Sub</th><th>Ned</th>
            </tr></thead>
            <tbody>${cells}</tbody>
          </table>
        </section>

        <section class="pb-izv-form-wrap">
          <h3 class="pb-section-title">Izveštaj za ${escHtml(selectedDay.split('-').reverse().join('.'))}</h3>
          <div class="pb-izv-form">
            <label class="pb-field"><span>Inženjer *</span>
              <select id="pbIzvEng" ${ctx.canEdit ? '' : 'disabled'}>
                <option value="">— izaberi —</option>
                ${(ctx.engineers || []).map(e => `
                  <option value="${escHtml(e.id)}" ${engDefault === e.id ? 'selected' : ''}>${escHtml(e.full_name)}</option>
                `).join('')}
              </select>
            </label>
            <label class="pb-field"><span>Sati (0.5–12)</span>
              <div class="pb-norm-row">
            <input type="range" id="pbIzvSatR" min="1" max="24" step="1" value="${sliderTicks}" ${ctx.canEdit ? '' : 'disabled'} />
            <input type="number" id="pbIzvSatN" min="0.5" max="12" step="0.5" value="${(sliderTicks / 2).toFixed(1)}" ${ctx.canEdit ? '' : 'disabled'} />
              </div>
            </label>
            <label class="pb-field"><span>Opis rada</span>
              <textarea id="pbIzvOpis" class="pb-textarea-lg" rows="4" placeholder="Kratki opis šta je urađeno tog dana..."
                ${ctx.canEdit ? '' : 'disabled'}></textarea>
            </label>
            ${ctx.canEdit ? `<div class="pb-izv-mic-row">
              <button type="button" class="btn btn-sm" id="pbIzvMic">🎙 Glasovni unos</button>
            </div>` : ''}
            ${ctx.canEdit ? `<div class="pb-modal-actions">
              <button type="button" class="btn btn-primary" id="pbIzvSave">Sačuvaj</button>
              <button type="button" class="btn" id="pbIzvCancel">Otkaži</button>
            </div>` : ''}
          </div>

          <div class="pb-izv-day-list">
            <h4 class="pb-section-title">Unosi za dan</h4>
            ${dayReports.length ? dayReports.map(r => `
              <div class="pb-izv-row" data-wrid="${escHtml(r.id)}">
                <span class="pb-avatar">${escHtml((r.engineer_name || '?').slice(0, 1))}</span>
                <div class="pb-izv-row-main">
                  <strong>${escHtml(r.engineer_name || '—')}</strong>
                  <span class="pb-muted">${Number(r.sati) || 0}h</span>
                  <p>${escHtml(r.opis || '')}</p>
                </div>
                ${ctx.canEdit ? `<button type="button" class="btn btn-sm pb-izv-del" data-id="${escHtml(r.id)}">✕</button>` : ''}
              </div>`).join('')
              : '<p class="pb-muted">Nema unetih izveštaja za ovaj dan.</p>'}
          </div>
        </section>

        <section class="pb-izv-sum" aria-label="Obračun po periodu">
          <h3 class="pb-section-title">Obračun po periodu</h3>
          <div class="pb-izv-sum-filters">
            <label>Od <input type="date" id="pbIzvFrom" value="${escHtml(defaultFrom)}" /></label>
            <label>Do <input type="date" id="pbIzvTo" value="${escHtml(defaultTo)}" /></label>
            <label>Inženjer
              <select id="pbIzvSumEng">
                <option value="all">Svi inženjeri</option>
                ${(ctx.engineers || []).map(e => `<option value="${escHtml(e.id)}">${escHtml(e.full_name)}</option>`).join('')}
              </select>
            </label>
            <button type="button" class="btn btn-primary btn-sm" id="pbIzvCalc">Izračunaj</button>
          </div>
          <div id="pbIzvSumOut" class="pb-izv-sum-out"></div>
        </section>
      </div>`;

    const satR = root.querySelector('#pbIzvSatR');
    const satN = root.querySelector('#pbIzvSatN');
    satR?.addEventListener('input', () => {
      sliderTicks = Number(satR.value) || 20;
      if (satN) satN.value = (sliderTicks / 2).toFixed(1);
    });
    satN?.addEventListener('input', () => {
      const v = Math.round((Number(satN.value) || 1) * 2);
      sliderTicks = Math.min(24, Math.max(1, v));
      if (satR) satR.value = String(sliderTicks);
    });

    root.querySelector('#pbIzvPrev')?.addEventListener('click', async () => {
      viewMonth -= 1;
      if (viewMonth < 0) {
        viewMonth = 11;
        viewYear -= 1;
      }
      await refreshMonth();
    });
    root.querySelector('#pbIzvNext')?.addEventListener('click', async () => {
      viewMonth += 1;
      if (viewMonth > 11) {
        viewMonth = 0;
        viewYear += 1;
      }
      await refreshMonth();
    });

    root.querySelectorAll('[data-day]').forEach(btn => {
      btn.addEventListener('click', () => {
        selectedDay = btn.getAttribute('data-day') || selectedDay;
        paint();
      });
    });

    root.querySelector('#pbIzvSave')?.addEventListener('click', async () => {
      const emp = root.querySelector('#pbIzvEng')?.value;
      const sat = Number(root.querySelector('#pbIzvSatN')?.value) || 1;
      const opis = root.querySelector('#pbIzvOpis')?.value?.trim() ?? '';
      if (!emp) {
        showToast('Izaberi inženjera');
        return;
      }
      try {
        await createPbWorkReport({
          employee_id: emp,
          datum: selectedDay,
          sati: sat,
          opis,
        });
        showToast('Sačuvano');
        root.querySelector('#pbIzvOpis').value = '';
        await ctx.onRefresh?.(viewYear, viewMonth);
      } catch (e) {
        showToast(pbErrorMessage(e));
      }
    });

    root.querySelector('#pbIzvCancel')?.addEventListener('click', () => {
      root.querySelector('#pbIzvOpis').value = '';
    });

    root.querySelectorAll('.pb-izv-del').forEach(btn => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-id');
        if (!id || !confirm('Obrisati izveštaj?')) return;
        try {
          await deletePbWorkReport(id);
          showToast('Obrisano');
          await ctx.onRefresh?.(viewYear, viewMonth);
        } catch (e) {
          showToast(pbErrorMessage(e));
        }
      });
    });

    let recog = null;
    root.querySelector('#pbIzvMic')?.addEventListener('click', () => {
      const SR = window.SpeechRecognition || window.webkitSpeechRecognition;
      const ta = root.querySelector('#pbIzvOpis');
      if (!SR || !ta) {
        showToast('Glasovni unos nije podržan u ovom pregledaču');
        return;
      }
      if (recog) {
        try { recog.stop(); } catch { /* */ }
        recog = null;
        setPbIzvestajiSpeechRecog(null);
        showToast('Mikrofon zaustavljen');
        return;
      }
      recog = new SR();
      setPbIzvestajiSpeechRecog(recog);
      recog.lang = 'sr-RS';
      recog.continuous = false;
      recog.interimResults = false;
      recog.onresult = ev => {
        const t = ev.results?.[0]?.[0]?.transcript;
        if (t) ta.value = (ta.value ? ta.value + ' ' : '') + t;
      };
      recog.onend = () => {
        recog = null;
        setPbIzvestajiSpeechRecog(null);
      };
      recog.onerror = () => showToast('Greška mikrofona');
      recog.start();
      showToast('Slušam… (klik ponovo za stop)');
    });

    async function runSum() {
      const df = root.querySelector('#pbIzvFrom')?.value || '';
      const dt = root.querySelector('#pbIzvTo')?.value || '';
      const eng = root.querySelector('#pbIzvSumEng')?.value || 'all';
      const calcBtn = root.querySelector('#pbIzvCalc');
      if (!df || !dt) {
        showToast('Izaberite period za obračun');
        return;
      }
      const empId = eng === 'all' ? null : eng;
      if (calcBtn) {
        calcBtn.disabled = true;
        calcBtn.textContent = 'Učitava…';
      }
      try {
        const summary = await getPbWorkReportSummary(df, dt, empId);
        const box = root.querySelector('#pbIzvSumOut');
        if (!box) return;
        if (!summary.length) {
          box.innerHTML = `<div style="font-size:12px;color:var(--text3);text-align:center;padding:6px">Nema unosa za odabrani period</div>`;
          return;
        }
        const totalH = summary.reduce((s, r) => s + Number(r.total_hours), 0);
        const totalN = summary.reduce((s, r) => s + r.report_count, 0);
        box.innerHTML = `
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;padding-bottom:6px;border-bottom:1px solid var(--border)">
            <span style="font-size:12px;color:var(--text2)">${totalN} izveštaj${totalN === 1 ? '' : 'a'} · ${escHtml(df)} — ${escHtml(dt)}</span>
            <span style="font-size:16px;font-weight:600;color:var(--accent)">${totalH.toFixed(1)}h ukupno</span>
          </div>
          ${summary.map(r => `
            <div style="display:flex;justify-content:space-between;font-size:11px;padding:3px 0;border-bottom:1px solid var(--border)">
              <span style="color:var(--text2)">${escHtml(r.full_name)}</span>
              <span style="color:var(--text3)">${r.report_count} izv.</span>
              <span style="font-weight:600;color:var(--accent)">${Number(r.total_hours).toFixed(1)}h</span>
            </div>`).join('')}`;
      } catch (e) {
        showToast(pbErrorMessage(e));
      } finally {
        if (calcBtn) {
          calcBtn.disabled = false;
          calcBtn.textContent = 'Izračunaj';
        }
      }
    }

    root.querySelector('#pbIzvCalc')?.addEventListener('click', () => void runSum());
  }

  async function refreshMonth() {
    try {
      await ctx.loadMonthReports(viewYear, viewMonth);
    } catch (e) {
      showToast(pbErrorMessage(e));
      return;
    }
    paint();
  }

  void refreshMonth().catch(e => showToast(pbErrorMessage(e)));
}
