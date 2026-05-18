/**
 * Kadrovska — SUB-TAB „Mesečni obračun" (Faza K3.2, samo admin).
 *
 * Ciklus isplate:
 *   ▸ PRVI DEO (akontacija)  — unos do ~5. u mesecu.
 *   ▸ DRUGI DEO (konačno)    — unos od 15. do 20., obračunat po formuli:
 *     BAZA       = satničari: hourly_rate × hours_worked
 *                  fiksni:   fixed_salary
 *     UKUPNO_RSD = BAZA + transport_rsd + per_diem_rsd × domestic_days
 *     DRUGI_DEO  = UKUPNO_RSD − advance_amount
 *     UKUPNO_EUR = per_diem_eur × foreign_days   (zasebna isplata)
 *
 * UX:
 *   - Gore: month-picker, chips, dugmad „Pripremi mesec", „Excel", „Osveži".
 *   - Sredina: veliki grid (tabela) sa inline edit poljima.
 *   - Svaka izmena polja trigeruje LIVE preview totals u istom redu
 *     (bez DB poziva); klikom na „Sačuvaj" taj red se PATCH-uje u bazi.
 *   - „Pripremi mesec" poziva RPC kadr_payroll_init_month(y, m) koji
 *     kreira draft red po aktivnom zaposlenom sa snapshot-om uslova.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { formatDate } from '../../lib/date.js';
import {
  compareEmployeesByLastFirst,
  employeeDisplayName,
} from '../../lib/employeeNames.js';
import { canAccessSalary, getIsOnline } from '../../state/auth.js';
import { hasSupabaseConfig } from '../../lib/constants.js';
import { kadrPayrollState, kadrovskaState, kadrSalaryState } from '../../state/kadrovska.js';
import { ensureEmployeesLoaded, ensureCurrentSalariesLoaded } from '../../services/kadrovska.js';
import {
  loadPayrollByMonth,
  upsertPayroll,
  deletePayroll,
  initPayrollMonth,
  computeDisplayTotals,
  refreshPayrollComputationContext,
} from '../../services/salaryPayroll.js';
import { renderSummaryChips } from './shared.js';
import { loadXlsx } from '../../lib/xlsx.js';
import { askConfirm } from '../../lib/confirm.js';

const MONTH_NAMES = [
  'Januar', 'Februar', 'Mart', 'April', 'Maj', 'Jun',
  'Jul', 'Avgust', 'Septembar', 'Oktobar', 'Novembar', 'Decembar',
];

let rootEl = null;

function payrollEmployee(row) {
  return kadrovskaState.employees.find(e => e.id === row.employeeId) || null;
}

function payrollEmployeeName(row) {
  return employeeDisplayName(payrollEmployee(row)) || employeeDisplayName(row) || row.employeeName || '';
}

function comparePayrollRows(a, b) {
  const ea = payrollEmployee(a);
  const eb = payrollEmployee(b);
  if (ea && eb) return compareEmployeesByLastFirst(ea, eb);
  return compareEmployeesByLastFirst(ea || a, eb || b);
}

/* ── Public API ─────────────────────────────────────────────── */

export function renderPayrollSubtab() {
  if (!canAccessSalary()) {
    return `<div class="kadr-empty" style="margin:40px 24px">🔒 Samo administrator.</div>`;
  }
  const y = kadrPayrollState.selectedYear;
  const m = kadrPayrollState.selectedMonth;

  const years = [];
  const yNow = new Date().getFullYear();
  for (let yy = yNow - 3; yy <= yNow + 1; yy++) years.push(yy);

  return `
    <section class="kadr-panel-inner" aria-label="Mesečni obračun">
      <div class="kadr-summary-strip" id="payrSummary"></div>
      <div class="kadrovska-toolbar payroll-toolbar">
        <button class="btn btn-ghost" id="payrPrevMonth" title="Prethodni mesec">‹</button>
        <select id="payrMonth" class="kadrovska-filter" aria-label="Mesec">
          ${MONTH_NAMES.map((name, i) => `<option value="${i + 1}"${(i + 1) === m ? ' selected' : ''}>${name}</option>`).join('')}
        </select>
        <select id="payrYear" class="kadrovska-filter" aria-label="Godina">
          ${years.map(yy => `<option value="${yy}"${yy === y ? ' selected' : ''}>${yy}</option>`).join('')}
        </select>
        <button class="btn btn-ghost" id="payrNextMonth" title="Sledeći mesec">›</button>
        <input type="text" class="kadrovska-search" id="payrSearch" placeholder="Pretraga zaposlenih…">
        <div class="kadrovska-toolbar-spacer"></div>
        <button class="btn btn-ghost" id="payrReload">🔄 Osveži</button>
        <button class="btn btn-ghost" id="payrExport">📊 Excel</button>
        <button class="btn btn-ghost" id="payrPdfAll" title="Otvori PDF sa svim obračunima za izabrani mesec (filtrirano + jedan dokument)">📄 PDF svi</button>
        <button class="btn btn-primary" id="payrInit" title="Kreiraj draft redove za sve aktivne zaposlene za izabrani mesec">+ Pripremi mesec</button>
        <button class="btn btn-warning" id="payrLockMonth" title="Markiraj sve finalizovane redove kao isplaćene — više ne mogu da se menjaju">🔒 Zaključaj mesec</button>
      </div>
      <div class="payroll-hint">
        <strong>Prvi deo</strong> = akontacija (do 5. u mesecu). <strong>Drugi deo</strong> = ukupno − prvi deo (15–20. u mesecu).
        Za aktivne uslove K3.3 ukupno se računa iz <strong>mesečnog grida</strong> (GO i državni praznici = 8h radnog dana, bol.: bo 0,65× / bop 1×) + ova polja za prevoz i dnevnice.
      </div>
      <main class="kadrovska-main payroll-main">
        <div class="payroll-grid-wrap">
          <table class="kadrovska-table payroll-grid" id="payrTable">
            <thead>
              <tr>
                <th class="sticky-col">Zaposleni</th>
                <th>Tip</th>
                <th title="Akontacija (prvi deo)">I deo</th>
                <th title="Datum isplate I dela">I deo – datum</th>
                <th title="Satnica × sati ili fiksna plata">Sati / Fixno</th>
                <th>Prevoz</th>
                <th title="Broj domaćih terena × dinarska dnevnica">Dom. tereni</th>
                <th title="Broj ino terena × devizna dnevnica">Ino tereni</th>
                <th title="Ukupno RSD = baza + prevoz + dinarske dnevnice">Ukupno RSD</th>
                <th title="Devizne dnevnice zasebno">Ukupno EUR</th>
                <th title="II deo = UKUPNO RSD − I deo">II deo</th>
                <th>II deo – datum</th>
                <th>Status</th>
                <th class="col-actions">Akcije</th>
              </tr>
            </thead>
            <tbody id="payrTbody"></tbody>
          </table>
        </div>
        <div class="kadrovska-empty" id="payrEmpty" style="display:none;margin-top:16px;">
          <div class="kadrovska-empty-title">Nema obračuna za ${MONTH_NAMES[m - 1]} ${y}.</div>
          <div>Klikni <strong>+ Pripremi mesec</strong> da se kreiraju draft redovi za sve aktivne zaposlene.</div>
        </div>
      </main>
    </section>`;
}

export async function wirePayrollSubtab(panelEl) {
  if (!canAccessSalary()) return;
  rootEl = panelEl;

  panelEl.querySelector('#payrPrevMonth').addEventListener('click', () => shiftMonth(-1));
  panelEl.querySelector('#payrNextMonth').addEventListener('click', () => shiftMonth(+1));
  panelEl.querySelector('#payrMonth').addEventListener('change', (e) => setMonth(+e.target.value));
  panelEl.querySelector('#payrYear').addEventListener('change', (e) => setYear(+e.target.value));
  panelEl.querySelector('#payrSearch').addEventListener('input', debounce(refreshRows, 120));
  panelEl.querySelector('#payrReload').addEventListener('click', () => reloadPeriod(true));
  panelEl.querySelector('#payrInit').addEventListener('click', initCurrentMonth);
  panelEl.querySelector('#payrExport').addEventListener('click', exportXlsx);
  panelEl.querySelector('#payrLockMonth').addEventListener('click', lockMonthBulk);
  panelEl.querySelector('#payrPdfAll')?.addEventListener('click', openBulkPayslipsPdf);

  await ensureEmployeesLoaded();
  await reloadPeriod(true);
}

/* ── State / period helpers ─────────────────────────────────── */

function periodKey(y, m) { return `${y}-${String(m).padStart(2, '0')}`; }
function currentKey() { return periodKey(kadrPayrollState.selectedYear, kadrPayrollState.selectedMonth); }

function shiftMonth(delta) {
  let y = kadrPayrollState.selectedYear;
  let m = kadrPayrollState.selectedMonth + delta;
  while (m < 1)  { m += 12; y -= 1; }
  while (m > 12) { m -= 12; y += 1; }
  kadrPayrollState.selectedYear = y;
  kadrPayrollState.selectedMonth = m;
  syncPickers();
  reloadPeriod(true);
}
function setMonth(m) { kadrPayrollState.selectedMonth = m; reloadPeriod(true); }
function setYear(y)  { kadrPayrollState.selectedYear  = y; reloadPeriod(true); }

function syncPickers() {
  if (!rootEl) return;
  rootEl.querySelector('#payrMonth').value = String(kadrPayrollState.selectedMonth);
  rootEl.querySelector('#payrYear').value  = String(kadrPayrollState.selectedYear);
}

/* ── Load ───────────────────────────────────────────────────── */

async function reloadPeriod(force = false) {
  if (!canAccessSalary()) return;
  const key = currentKey();
  if (force || !kadrPayrollState.byPeriod.has(key)) {
    if (!getIsOnline() || !hasSupabaseConfig()) {
      kadrPayrollState.byPeriod.set(key, []);
    } else {
      const rows = await loadPayrollByMonth(kadrPayrollState.selectedYear, kadrPayrollState.selectedMonth);
      kadrPayrollState.byPeriod.set(key, rows || []);
    }
  }
  if (getIsOnline() && hasSupabaseConfig()) {
    await ensureCurrentSalariesLoaded();
    await refreshPayrollComputationContext(
      kadrPayrollState.selectedYear,
      kadrPayrollState.selectedMonth,
      kadrSalaryState.current,
    );
  }
  refreshRows();
}

/**
 * Bulk lock — sve redove u statusu `finalized` prebaci u `paid` (immutable).
 * Draft / advance_paid se NE diraju (još nisu spremni). Ako nema kandidata,
 * korisnik dobija jasan toast.
 */
async function lockMonthBulk() {
  if (!canAccessSalary()) return;
  const rows = kadrPayrollState.byPeriod.get(currentKey()) || [];
  const candidates = rows.filter(r => r.status === 'finalized');
  if (!candidates.length) {
    const draftCount = rows.filter(r => r.status === 'draft' || r.status === 'advance_paid').length;
    if (draftCount) {
      showToast(`ℹ Nema finalizovanih redova. ${draftCount} red(ova) još nisu finalizovani.`);
    } else {
      showToast('ℹ Nema redova za zaključavanje');
    }
    return;
  }
  const y = kadrPayrollState.selectedYear;
  const m = kadrPayrollState.selectedMonth;
  const ok = await askConfirm({
    title: `Zaključavanje meseca ${MONTH_NAMES[m - 1]} ${y}`,
    body: `${candidates.length} red(ova) će biti markirano kao ISPLAĆENO. Nakon toga se ti redovi VIŠE NE MOGU menjati ni brisati. Ova akcija se ne može poništiti.`,
    confirmLabel: 'Zaključaj',
    danger: true,
    requireType: 'ZAKLJUČAJ',
  });
  if (!ok) return;

  const btn = rootEl.querySelector('#payrLockMonth');
  btn.disabled = true;
  const txt = btn.textContent;
  btn.textContent = '⏳ Zaključavanje…';

  let okCount = 0;
  let failCount = 0;
  for (const r of candidates) {
    try {
      const saved = await upsertPayroll({ ...r, status: 'paid' });
      if (saved) {
        Object.assign(r, saved);
        okCount += 1;
      } else {
        failCount += 1;
      }
    } catch (e) {
      console.error('[payroll] lockMonth row', r.id, e);
      failCount += 1;
    }
  }
  btn.disabled = false;
  btn.textContent = txt;
  refreshRows();
  if (failCount === 0) {
    showToast(`🔒 Zaključano ${okCount} red(ova)`);
  } else {
    showToast(`⚠ Zaključano ${okCount}, neuspešno ${failCount} red(ova)`);
  }
}

async function initCurrentMonth() {
  if (!canAccessSalary()) return;
  const btn = rootEl.querySelector('#payrInit');
  btn.disabled = true;
  const txt = btn.textContent;
  btn.textContent = '⏳ Kreiranje…';
  try {
    const n = await initPayrollMonth(kadrPayrollState.selectedYear, kadrPayrollState.selectedMonth);
    if (n == null) {
      showToast('⚠ Nije uspelo — proveri migraciju i da li si admin');
    } else {
      showToast(n > 0 ? `✅ Kreirano ${n} novih redova` : 'ℹ Svi aktivni zaposleni već imaju red za ovaj mesec');
    }
    await reloadPeriod(true);
  } catch (e) {
    console.error('[payroll] init', e);
    showToast('⚠ Greška pri pripremi meseca');
  } finally {
    btn.disabled = false;
    btn.textContent = txt;
  }
}

/* ── Render rows ────────────────────────────────────────────── */

function refreshRows() {
  if (!rootEl || !canAccessSalary()) return;
  const rows = kadrPayrollState.byPeriod.get(currentKey()) || [];
  const q = (rootEl.querySelector('#payrSearch').value || '').trim().toLowerCase();

  const filtered = q
    ? rows.filter(r => {
        const hay = [payrollEmployeeName(r), r.employeeName, r.employeePosition, r.employeeDepartment].join(' ').toLowerCase();
        return hay.includes(q);
      })
    : rows;
  const sorted = filtered.slice().sort(comparePayrollRows);

  const sumRsd = rows.reduce((a, r) => {
    const p = computeDisplayTotals(r);
    return a + (p.payrollK33 ? p.totalRsd : (r.totalRsd || 0));
  }, 0);
  const sumEur = rows.reduce((a, r) => {
    const p = computeDisplayTotals(r);
    return a + (p.payrollK33 ? p.totalEur : (r.totalEur || 0));
  }, 0);
  const sumAdv = rows.reduce((a, r) => a + (r.advanceAmount || 0), 0);
  const sumSec = rows.reduce((a, r) => {
    const p = computeDisplayTotals(r);
    return a + (p.payrollK33 ? p.secondPartRsd : (r.secondPartRsd || 0));
  }, 0);
  const countDraft = rows.filter(r => r.status === 'draft').length;
  const countFinal = rows.filter(r => r.status === 'finalized' || r.status === 'paid').length;

  renderSummaryChips('payrSummary', [
    { label: 'Zaposlenih', value: rows.length, tone: 'accent' },
    { label: 'Draft', value: countDraft, tone: countDraft ? 'warn' : 'muted' },
    { label: 'Finalizovano / isplaćeno', value: countFinal, tone: 'ok' },
    { label: 'I deo (akontacija)', value: fmtRsd(sumAdv), tone: 'muted' },
    { label: 'II deo (konačno)', value: fmtRsd(sumSec), tone: 'muted' },
    { label: 'Ukupno RSD', value: fmtRsd(sumRsd), tone: 'accent' },
    { label: 'Ukupno EUR', value: `${fmtNum(sumEur)} EUR`, tone: 'accent' },
  ]);

  const tbody = rootEl.querySelector('#payrTbody');
  const empty = rootEl.querySelector('#payrEmpty');
  if (!sorted.length) {
    tbody.innerHTML = '';
    empty.style.display = 'block';
    return;
  }
  empty.style.display = 'none';
  tbody.innerHTML = sorted.map(rowHtml).join('');
  wireRowEvents(tbody);
}

function rowHtml(r) {
  const typeBadge = `<span class="kadr-type-badge t-sal-${escHtml(r.salaryType)}">${escHtml(r.salaryType)}</span>`;
  const statusBadge = `<span class="payr-status s-${escHtml(r.status)}">${statusLabel(r.status)}</span>`;
  const isHourly = r.salaryType === 'satnica';
  const locked = r.status === 'paid';
  const dis = locked ? 'disabled' : '';

  const preview = computeDisplayTotals(r);
  const dispRsd = preview.payrollK33 ? preview.totalRsd : r.totalRsd;
  const dispEur = preview.payrollK33 ? preview.totalEur : r.totalEur;
  const dispSec = preview.payrollK33 ? preview.secondPartRsd : r.secondPartRsd;

  const baseCell = isHourly
    ? `<div class="payr-cell-dual">
         <input type="number" class="payr-inp" data-f="hoursWorked" data-emp="${escHtml(r.employeeId)}" min="0" step="0.25" value="${r.hoursWorked || 0}" ${dis}>
         <span class="payr-mul">×</span>
         <input type="number" class="payr-inp w-sm" data-f="hourlyRate"  data-emp="${escHtml(r.employeeId)}" min="0" step="0.01" value="${r.hourlyRate || 0}" ${dis}>
       </div>`
    : `<input type="number" class="payr-inp w-md" data-f="fixedSalary" data-emp="${escHtml(r.employeeId)}" min="0" step="0.01" value="${r.fixedSalary || 0}" ${dis}>`;

  return `
    <tr data-id="${escHtml(r.id)}" data-emp="${escHtml(r.employeeId)}" class="payr-row s-${escHtml(r.status)}">
      <td class="sticky-col">
        <div class="emp-name">${escHtml(payrollEmployeeName(r) || '—')}</div>
        <small class="emp-sub">${escHtml([r.employeePosition, r.employeeDepartment].filter(Boolean).join(' / ') || '')}</small>
      </td>
      <td>${typeBadge}</td>
      <td><input type="number" class="payr-inp w-md" data-f="advanceAmount" data-emp="${escHtml(r.employeeId)}" min="0" step="0.01" value="${r.advanceAmount || 0}" ${dis}></td>
      <td><input type="date" class="payr-inp" data-f="advancePaidOn" data-emp="${escHtml(r.employeeId)}" value="${escHtml(r.advancePaidOn || '')}" ${dis}></td>
      <td>${baseCell}</td>
      <td><input type="number" class="payr-inp w-sm" data-f="transportRsd" data-emp="${escHtml(r.employeeId)}" min="0" step="0.01" value="${r.transportRsd || 0}" ${dis}></td>
      <td>
        <div class="payr-cell-dual">
          <input type="number" class="payr-inp w-xs" data-f="domesticDays" data-emp="${escHtml(r.employeeId)}" min="0" step="1" value="${r.domesticDays || 0}" title="Broj domaćih terena" ${dis}>
          <span class="payr-mul">×</span>
          <input type="number" class="payr-inp w-sm" data-f="perDiemRsd" data-emp="${escHtml(r.employeeId)}" min="0" step="0.01" value="${r.perDiemRsd || 0}" title="Dinarska dnevnica" ${dis}>
        </div>
      </td>
      <td>
        <div class="payr-cell-dual">
          <input type="number" class="payr-inp w-xs" data-f="foreignDays" data-emp="${escHtml(r.employeeId)}" min="0" step="1" value="${r.foreignDays || 0}" title="Broj ino terena" ${dis}>
          <span class="payr-mul">×</span>
          <input type="number" class="payr-inp w-sm" data-f="perDiemEur" data-emp="${escHtml(r.employeeId)}" min="0" step="0.01" value="${r.perDiemEur || 0}" title="Devizna dnevnica EUR" ${dis}>
        </div>
      </td>
      <td class="num"><strong data-out="totalRsd">${fmtRsd(dispRsd)}</strong></td>
      <td class="num"><strong data-out="totalEur">${fmtNum(dispEur)} EUR</strong></td>
      <td class="num"><strong data-out="secondPartRsd">${fmtRsd(dispSec)}</strong></td>
      <td><input type="date" class="payr-inp" data-f="finalPaidOn" data-emp="${escHtml(r.employeeId)}" value="${escHtml(r.finalPaidOn || '')}" ${dis}></td>
      <td>${statusBadge}</td>
      <td class="col-actions">
        <button class="btn-row-act primary" data-act="save" ${locked ? 'disabled' : ''}>💾 Sačuvaj</button>
        <button class="btn-row-act" data-act="status" title="Promeni status">↑ Status</button>
        <button class="btn-row-act" data-act="pdf" title="Generiši PDF obračun za zaposlenog">📄 PDF</button>
        <button class="btn-row-act danger" data-act="del" title="Obriši red">🗑</button>
      </td>
    </tr>`;
}

function wireRowEvents(tbody) {
  tbody.querySelectorAll('.payr-inp').forEach(inp => {
    inp.addEventListener('input', () => onRowInput(inp));
  });
  tbody.querySelectorAll('button[data-act="save"]').forEach(b => {
    b.addEventListener('click', () => saveRow(b.closest('tr')));
  });
  tbody.querySelectorAll('button[data-act="status"]').forEach(b => {
    b.addEventListener('click', () => cycleStatus(b.closest('tr')));
  });
  tbody.querySelectorAll('button[data-act="del"]').forEach(b => {
    b.addEventListener('click', () => deleteRow(b.closest('tr')));
  });
  tbody.querySelectorAll('button[data-act="pdf"]').forEach(b => {
    b.addEventListener('click', () => openPayslipPdf(b.closest('tr')));
  });
}

/* ── Live preview (FE mirror trigger) ──────────────────────── */

function collectRowPayload(tr) {
  const out = { id: tr.dataset.id, employeeId: tr.dataset.emp };
  tr.querySelectorAll('.payr-inp').forEach(inp => {
    const f = inp.dataset.f;
    if (!f) return;
    if (inp.type === 'number') out[f] = inp.value === '' ? 0 : Number(inp.value);
    else out[f] = inp.value;
  });
  /* Dohvati tip i trenutni status iz state-a */
  const rows = kadrPayrollState.byPeriod.get(currentKey()) || [];
  const existing = rows.find(r => r.id === tr.dataset.id);
  if (existing) {
    out.salaryType = existing.salaryType;
    out.periodYear = existing.periodYear;
    out.periodMonth = existing.periodMonth;
    out.status = existing.status;
    out.note = existing.note;
    out.employeeWorkType = existing.employeeWorkType;
    out.compensationModel = existing.compensationModel;
  }
  return out;
}

function onRowInput(inp) {
  const tr = inp.closest('tr');
  if (!tr) return;
  const payload = collectRowPayload(tr);
  const t = computeDisplayTotals(payload);
  const rsdEl = tr.querySelector('[data-out="totalRsd"]');
  const eurEl = tr.querySelector('[data-out="totalEur"]');
  const secEl = tr.querySelector('[data-out="secondPartRsd"]');
  if (rsdEl) rsdEl.textContent = fmtRsd(t.totalRsd);
  if (eurEl) eurEl.textContent = `${fmtNum(t.totalEur)} EUR`;
  if (secEl) secEl.textContent = fmtRsd(t.secondPartRsd);
  tr.classList.add('dirty');
}

/* ── Save / Status / Delete ──────────────────────────────── */

function augmentPayloadWithPayrollK33(payload) {
  const disp = computeDisplayTotals(payload);
  if (!disp.payrollK33) return payload;
  return {
    ...payload,
    hoursWorked: disp.payableHours,
    compensationModel: disp.compensationModel || payload.compensationModel,
    fondSatiMeseca: disp.fondSatiMeseca,
    redovanRadSati: disp.redovanRadSati,
    prekovremeniSati: disp.prekovremeniSati,
    praznikPlaceniSati: disp.praznikPlaceniSati,
    praznikRadSati: disp.praznikRadSati,
    godisnjiSati: disp.godisnjiSati,
    slobodniDaniSati: disp.slobodniDaniSati,
    bolovanje65Sati: disp.bolovanje65Sati,
    bolovanje100Sati: disp.bolovanje100Sati,
    dveMasineSati: disp.dveMasineSati,
    payableHours: disp.payableHours,
    ukupnaZarada: disp.ukupnaZarada,
    payrollWarnings: disp.payrollWarnings,
  };
}

async function saveRow(tr) {
  if (!tr) return;
  const btn = tr.querySelector('button[data-act="save"]');
  const payload = augmentPayloadWithPayrollK33(collectRowPayload(tr));
  btn.disabled = true;
  const txt = btn.textContent;
  btn.textContent = '⏳';
  try {
    const saved = await upsertPayroll(payload);
    if (!saved) {
      showToast('⚠ Čuvanje nije uspelo');
      return;
    }
    /* Update u state-u */
    const key = currentKey();
    const rows = kadrPayrollState.byPeriod.get(key) || [];
    const idx = rows.findIndex(r => r.id === saved.id);
    if (idx >= 0) rows[idx] = { ...rows[idx], ...saved };
    else rows.push(saved);
    kadrPayrollState.byPeriod.set(key, rows);
    tr.classList.remove('dirty');
    refreshRows();
    showToast('💾 Sačuvano');
  } catch (e) {
    console.error('[payroll] save', e);
    showToast('⚠ Greška pri čuvanju');
  } finally {
    btn.disabled = false;
    btn.textContent = txt;
  }
}

async function cycleStatus(tr) {
  if (!tr) return;
  const id = tr.dataset.id;
  const rows = kadrPayrollState.byPeriod.get(currentKey()) || [];
  const r = rows.find(x => x.id === id);
  if (!r) return;
  const next = nextStatus(r.status);
  if (!next) { showToast('ℹ Već je u krajnjem statusu'); return; }
  if (next === 'paid') {
    const ok = await askConfirm({
      title: 'Markiraj kao isplaćeno',
      body: 'Obeležiti kao ISPLAĆENO? Nakon toga se red više ne može menjati.',
      confirmLabel: 'Markiraj',
      danger: true,
    });
    if (!ok) return;
  }
  const payload = augmentPayloadWithPayrollK33(collectRowPayload(tr));
  payload.status = next;
  const saved = await upsertPayroll(payload);
  if (!saved) { showToast('⚠ Nije sačuvano'); return; }
  Object.assign(r, saved);
  refreshRows();
  showToast(`→ ${statusLabel(next)}`);
}

function nextStatus(cur) {
  if (cur === 'draft') return 'advance_paid';
  if (cur === 'advance_paid') return 'finalized';
  if (cur === 'finalized') return 'paid';
  return null;
}
function statusLabel(s) {
  switch (s) {
    case 'draft': return '📝 Draft';
    case 'advance_paid': return '💰 I deo isplaćen';
    case 'finalized': return '✅ Finalizovano';
    case 'paid': return '🔒 Isplaćeno';
    default: return s || '—';
  }
}

async function deleteRow(tr) {
  if (!tr) return;
  const ok = await askConfirm({
    title: 'Brisanje obračuna',
    body: 'Obrisati ceo obračun za ovog zaposlenog u ovom mesecu? Akcija je trajna.',
    confirmLabel: 'Obriši',
    danger: true,
  });
  if (!ok) return;
  const id = tr.dataset.id;
  const deleted = await deletePayroll(id);
  if (!deleted) { showToast('⚠ Nije obrisano'); return; }
  const key = currentKey();
  const rows = (kadrPayrollState.byPeriod.get(key) || []).filter(r => r.id !== id);
  kadrPayrollState.byPeriod.set(key, rows);
  refreshRows();
  showToast('🗑 Obrisano');
}

/* ── Excel export ───────────────────────────────────────── */

async function exportXlsx() {
  if (!canAccessSalary()) return;
  const XLSX = await loadXlsx();
  const y = kadrPayrollState.selectedYear;
  const m = kadrPayrollState.selectedMonth;
  const rows = kadrPayrollState.byPeriod.get(currentKey()) || [];

  const aoa = [[
    'Zaposleni', 'Pozicija', 'Odeljenje', 'Tip',
    'I deo (RSD)', 'I deo datum',
    'Sati', 'Satnica', 'Fiksna plata',
    'Prevoz (RSD)', 'Domaći tereni', 'Dinarska dnev.',
    'Ino tereni', 'Devizna dnev. (EUR)',
    'Ukupno RSD', 'Ukupno EUR', 'II deo (RSD)',
    'II deo datum', 'Status', 'Napomena',
  ]];
  rows.slice().sort(comparePayrollRows).forEach(r => aoa.push([
    payrollEmployeeName(r), r.employeePosition, r.employeeDepartment, r.salaryType,
    r.advanceAmount, r.advancePaidOn || '',
    r.hoursWorked, r.hourlyRate, r.fixedSalary,
    r.transportRsd, r.domesticDays, r.perDiemRsd,
    r.foreignDays, r.perDiemEur,
    r.totalRsd, r.totalEur, r.secondPartRsd,
    r.finalPaidOn || '', statusLabel(r.status), r.note || '',
  ]));

  /* Ukupni red */
  const sum = (col) => rows.reduce((a, r) => a + (Number(r[col]) || 0), 0);
  aoa.push([]);
  aoa.push([
    'UKUPNO', '', '', '',
    sum('advanceAmount'), '',
    '', '', '',
    sum('transportRsd'), '', '',
    '', '',
    sum('totalRsd'), sum('totalEur'), sum('secondPartRsd'),
    '', '', '',
  ]);

  const ws = XLSX.utils.aoa_to_sheet(aoa);
  ws['!cols'] = [
    { wch: 28 }, { wch: 20 }, { wch: 16 }, { wch: 10 },
    { wch: 12 }, { wch: 12 },
    { wch: 8 }, { wch: 10 }, { wch: 12 },
    { wch: 12 }, { wch: 12 }, { wch: 14 },
    { wch: 10 }, { wch: 14 },
    { wch: 14 }, { wch: 12 }, { wch: 14 },
    { wch: 12 }, { wch: 18 }, { wch: 24 },
  ];
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, `${MONTH_NAMES[m - 1]} ${y}`);
  XLSX.writeFile(wb, `Zarade_obracun_${y}-${String(m).padStart(2, '0')}.xlsx`);
  showToast('📊 Izvezeno');
}

/* ── Plate slips PDF (C3.6) ────────────────────────────── */

/** Deljen CSS za pojedinačni i bulk PDF — page-break omogućava više payslip-ova u jednom dokumentu. */
function _payslipCss() {
  return `
  @page { size: A4; margin: 1.8cm 1.6cm; }
  body { font-family: 'Times New Roman', Georgia, serif; color:#111; font-size: 11pt; line-height: 1.45; margin: 0; }
  .payslip-page { page-break-after: always; padding-bottom: 8px; }
  .payslip-page:last-child { page-break-after: auto; }
  .doc-head { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 22px; }
  .doc-head-left .company { font-weight: 700; font-size: 13pt; color:#000; }
  .doc-head-left .addr { font-size: 10pt; color: #555; }
  .doc-head-right { text-align: right; font-size: 10pt; color:#555; }
  .doc-head-right .proto { font-weight: 700; color: #000; font-size: 11pt; }
  h1 { text-align:center; font-size: 14pt; margin: 4px 0 4px; text-transform: uppercase; letter-spacing: 0.5px; }
  h2 { text-align:center; font-size: 11pt; font-weight: 500; margin: 0 0 18px; color:#333; }
  .meta {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 4px 24px;
    margin: 14px 0 18px;
    padding: 10px 14px;
    background: #f5f5f5;
    border: 1px solid #ddd;
    border-radius: 4px;
    font-size: 10pt;
  }
  .meta-row { display: flex; justify-content: space-between; padding: 2px 0; }
  .meta-row span:first-child { color: #555; }
  .meta-row strong { color: #000; }
  table.payslip-tbl { width: 100%; border-collapse: collapse; font-size: 10.5pt; margin-bottom: 12px; }
  table.payslip-tbl td { padding: 5px 10px; border-bottom: 1px solid #eee; }
  table.payslip-tbl td.num { text-align: right; font-family: 'Courier New', monospace; }
  table.payslip-tbl tr.payslip-sum-row td { background: #eef; border-top: 2px solid #333; border-bottom: 0; font-weight: 700; }
  .payslip-totals {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 10px;
    margin: 16px 0;
    padding: 14px;
    background: #fafafa;
    border: 1px solid #ccc;
    border-radius: 6px;
  }
  .payslip-total-card { text-align: center; padding: 8px; }
  .payslip-total-card.primary { background: #e0f2fe; border: 1px solid #38bdf8; border-radius: 4px; }
  .payslip-total-card .lbl { font-size: 9pt; color: #555; text-transform: uppercase; letter-spacing: 0.4px; }
  .payslip-total-card .val { font-size: 16pt; font-weight: 800; color: #000; font-family: 'Courier New', monospace; margin-top: 3px; }
  .payslip-warn {
    margin: 14px 0;
    padding: 10px 14px;
    background: #fff7ed;
    border-left: 4px solid #f97316;
    border-radius: 4px;
    font-size: 10pt;
    color: #7c2d12;
  }
  .signs { margin-top: 36px; display:flex; justify-content: space-between; }
  .sign-box { width: 45%; text-align:center; }
  .sign-line { border-top:1px solid #333; padding-top:4px; font-size:9pt; color:#555; margin-top:40px; }
  .print-actions { margin: 14px 0; text-align:center; position: sticky; top: 0; background: rgba(255,255,255,0.95); padding: 10px 0; z-index: 10; }
  .print-actions button { padding: 8px 20px; font-size: 11pt; cursor:pointer; margin: 0 4px; }
  @media print { .print-actions { display:none; } }
  .footer-note {
    margin-top: 24px;
    padding-top: 8px;
    border-top: 1px dashed #ccc;
    font-size: 9pt;
    color: #777;
    line-height: 1.4;
  }`;
}

/**
 * Body HTML za jedan payslip (bez DOCTYPE / html wrap-a).
 * Koristi se i u pojedinačnom modal-u i u bulk dokumentu.
 */
function _buildPayslipBody(r, todayStr) {
  const emp = kadrovskaState.employees.find(e => e.id === r.employeeId) || null;
  const empName = payrollEmployeeName(r) || '—';
  const period = `${MONTH_NAMES[r.periodMonth - 1] || r.periodMonth} ${r.periodYear}`;
  const protocol = `OZ-${r.periodYear}-${String(r.periodMonth).padStart(2, '0')}-${String(r.employeeId || '').slice(0, 8).toUpperCase()}`;

  const disp = computeDisplayTotals(r);
  const useK33 = !!disp.payrollK33;
  const totRsd = useK33 ? disp.totalRsd : (r.totalRsd || 0);
  const totEur = useK33 ? disp.totalEur : (r.totalEur || 0);
  const secRsd = useK33 ? disp.secondPartRsd : (r.secondPartRsd || 0);

  const isHourly = r.salaryType === 'satnica';
  const baseLabel = isHourly ? 'Satnica × Sati' : 'Fiksna plata';
  const baseValue = isHourly
    ? `${fmtNum(r.hourlyRate || 0)} × ${fmtNum(r.hoursWorked || 0)} = ${fmtRsd((r.hourlyRate || 0) * (r.hoursWorked || 0))}`
    : fmtRsd(r.fixedSalary || 0);
  const statusLbl = statusLabel(r.status);
  const showJmbg = !!(emp?.personalId);
  const positionLine = r.employeePosition || emp?.position || '';
  const deptLine = r.employeeDepartment || emp?.department || '';

  const k33Detail = useK33 ? `
    <h3 style="margin:18px 0 6px;font-size:11pt;color:#333;text-transform:uppercase;letter-spacing:0.3px;">Razlaganje sati</h3>
    <table class="payslip-tbl">
      <tbody>
        <tr><td>Fond sati u mesecu</td><td class="num">${fmtNum(disp.fondSatiMeseca || 0)}</td></tr>
        <tr><td>Redovan rad</td><td class="num">${fmtNum(disp.redovanRadSati || 0)}</td></tr>
        ${disp.prekovremeniSati ? `<tr><td>Prekovremeni sati</td><td class="num">${fmtNum(disp.prekovremeniSati)}</td></tr>` : ''}
        ${disp.praznikRadSati ? `<tr><td>Praznik — rad</td><td class="num">${fmtNum(disp.praznikRadSati)}</td></tr>` : ''}
        ${disp.praznikPlaceniSati ? `<tr><td>Praznik — plaćen (slobodan)</td><td class="num">${fmtNum(disp.praznikPlaceniSati)}</td></tr>` : ''}
        ${disp.godisnjiSati ? `<tr><td>Godišnji odmor</td><td class="num">${fmtNum(disp.godisnjiSati)}</td></tr>` : ''}
        ${disp.slobodniDaniSati ? `<tr><td>Slobodni dani</td><td class="num">${fmtNum(disp.slobodniDaniSati)}</td></tr>` : ''}
        ${disp.bolovanje65Sati ? `<tr><td>Bolovanje 65%</td><td class="num">${fmtNum(disp.bolovanje65Sati)}</td></tr>` : ''}
        ${disp.bolovanje100Sati ? `<tr><td>Bolovanje 100% (povreda / trudnoća)</td><td class="num">${fmtNum(disp.bolovanje100Sati)}</td></tr>` : ''}
        ${disp.dveMasineSati ? `<tr><td>Rad na 2 mašine</td><td class="num">${fmtNum(disp.dveMasineSati)}</td></tr>` : ''}
        <tr class="payslip-sum-row"><td><strong>Σ plaćenih sati</strong></td><td class="num"><strong>${fmtNum(disp.payableHours || 0)}</strong></td></tr>
      </tbody>
    </table>
  ` : '';

  const warnings = useK33 && Array.isArray(disp.payrollWarnings) && disp.payrollWarnings.length
    ? `<div class="payslip-warn"><strong>⚠ Upozorenja iz obračuna:</strong><ul style="margin:6px 0 0 16px;padding:0;">${disp.payrollWarnings.map(w => `<li>${escHtml(String(w))}</li>`).join('')}</ul></div>`
    : '';

  return `
  <div class="payslip-page">
    <div class="doc-head">
      <div class="doc-head-left">
        <div class="company">SERVOTEH d.o.o.</div>
        <div class="addr">Dobanovci · Kruševac</div>
      </div>
      <div class="doc-head-right">
        <div class="proto">Br. obračuna: ${escHtml(protocol)}</div>
        <div>Datum štampe: ${escHtml(todayStr)}</div>
        <div>Status: ${escHtml(statusLbl)}</div>
      </div>
    </div>

    <h1>Obračun zarade</h1>
    <h2>za period: ${escHtml(period)}</h2>

    <div class="meta">
      <div class="meta-row"><span>Zaposleni:</span><strong>${escHtml(empName)}</strong></div>
      ${showJmbg ? `<div class="meta-row"><span>JMBG:</span><strong>${escHtml(emp.personalId)}</strong></div>` : '<div></div>'}
      ${positionLine ? `<div class="meta-row"><span>Radno mesto:</span><strong>${escHtml(positionLine)}</strong></div>` : '<div></div>'}
      ${deptLine ? `<div class="meta-row"><span>Odeljenje:</span><strong>${escHtml(deptLine)}</strong></div>` : '<div></div>'}
      <div class="meta-row"><span>Tip ugovora:</span><strong>${escHtml(r.salaryType || '—')}</strong></div>
      ${emp?.workType ? `<div class="meta-row"><span>Tip rada:</span><strong>${escHtml(emp.workType)}</strong></div>` : '<div></div>'}
    </div>

    ${k33Detail}

    <h3 style="margin:18px 0 6px;font-size:11pt;color:#333;text-transform:uppercase;letter-spacing:0.3px;">Stavke obračuna</h3>
    <table class="payslip-tbl">
      <tbody>
        <tr>
          <td>${escHtml(baseLabel)}</td>
          <td class="num">${baseValue}</td>
        </tr>
        ${r.transportRsd ? `<tr><td>Prevoz</td><td class="num">${fmtRsd(r.transportRsd)}</td></tr>` : ''}
        ${r.domesticDays ? `<tr><td>Dinarske dnevnice (${r.domesticDays} × ${fmtRsd(r.perDiemRsd || 0)})</td><td class="num">${fmtRsd((r.domesticDays || 0) * (r.perDiemRsd || 0))}</td></tr>` : ''}
        ${r.foreignDays ? `<tr><td>Devizne dnevnice (${r.foreignDays} × ${fmtNum(r.perDiemEur || 0)} EUR)</td><td class="num">${fmtNum((r.foreignDays || 0) * (r.perDiemEur || 0))} EUR</td></tr>` : ''}
      </tbody>
    </table>

    <div class="payslip-totals">
      <div class="payslip-total-card primary">
        <div class="lbl">UKUPNO RSD</div>
        <div class="val">${fmtRsd(totRsd)}</div>
      </div>
      ${totEur ? `
      <div class="payslip-total-card">
        <div class="lbl">UKUPNO EUR (devizno)</div>
        <div class="val">${fmtNum(totEur)} EUR</div>
      </div>` : '<div></div>'}
      <div class="payslip-total-card">
        <div class="lbl">II deo (konačno)</div>
        <div class="val">${fmtRsd(secRsd)}</div>
      </div>
    </div>

    <table class="payslip-tbl" style="margin-top:14px;">
      <tbody>
        <tr>
          <td>I deo — akontacija</td>
          <td class="num">${fmtRsd(r.advanceAmount || 0)}</td>
          <td style="width:40%;color:#555;">${r.advancePaidOn ? 'isplaćeno ' + escHtml(formatDate(r.advancePaidOn)) : 'datum: —'}</td>
        </tr>
        <tr>
          <td>II deo — konačni iznos</td>
          <td class="num">${fmtRsd(secRsd)}</td>
          <td style="width:40%;color:#555;">${r.finalPaidOn ? 'isplaćeno ' + escHtml(formatDate(r.finalPaidOn)) : 'datum: —'}</td>
        </tr>
      </tbody>
    </table>

    ${r.note ? `<p style="margin-top:14px;padding:8px 12px;background:#fafafa;border-left:3px solid #999;font-size:10pt;"><strong>Napomena:</strong> ${escHtml(r.note)}</p>` : ''}

    ${warnings}

    <div class="signs">
      <div class="sign-box">
        <div class="sign-line">Zaposleni — potpis</div>
        <div>${escHtml(empName)}</div>
      </div>
      <div class="sign-box">
        <div class="sign-line">Obračun pripremio</div>
        <div>&nbsp;</div>
      </div>
    </div>

    <div class="footer-note">
      Ovaj obračun je informativnog karaktera. Konačni iznosi za isplatu se obračunavaju u skladu sa
      Zakonom o radu, Zakonom o porezu na dohodak građana i Zakonom o doprinosima za obavezno socijalno osiguranje.
      Za detaljnije razjašnjenje obratite se računovodstvenoj službi.
    </div>
  </div>`;
}

function _openPayslipWindow(title, bodyHtml) {
  const html = `<!DOCTYPE html>
<html lang="sr">
<head>
<meta charset="utf-8">
<title>${escHtml(title)}</title>
<style>${_payslipCss()}</style>
</head>
<body>
  <div class="print-actions">
    <button onclick="window.print()">🖨 Štampaj / Sačuvaj kao PDF</button>
    <button onclick="window.close()">Zatvori</button>
  </div>
  ${bodyHtml}
</body>
</html>`;
  const w = window.open('', '_blank', 'width=900,height=1200,scrollbars=1');
  if (!w) { showToast('⚠ Pop-up blocker je sprečio prozor'); return null; }
  w.document.open();
  w.document.write(html);
  w.document.close();
  return w;
}

/**
 * Otvara print-friendly stranicu sa obračunom zarade za jednog zaposlenog
 * u izabranom mesecu. Browser print → "Save as PDF".
 */
function openPayslipPdf(tr) {
  if (!canAccessSalary()) { showToast('⚠ Samo administrator'); return; }
  const id = tr.dataset.id;
  const rows = kadrPayrollState.byPeriod.get(currentKey()) || [];
  const r = rows.find(x => x.id === id);
  if (!r) { showToast('⚠ Red nije pronađen'); return; }
  const empName = payrollEmployeeName(r) || '—';
  const period = `${MONTH_NAMES[r.periodMonth - 1] || r.periodMonth} ${r.periodYear}`;
  const todayStr = formatDate(new Date().toISOString().slice(0, 10));
  _openPayslipWindow(`Obračun zarade — ${empName} — ${period}`, _buildPayslipBody(r, todayStr));
}

/**
 * Otvara konsolidovan PDF sa SVIM trenutno filtriranim payslip-ovima.
 * Svaki je na svojoj A4 stranici (page-break-after: always).
 * Browser print → jedan PDF, N stranica. Nema ZIP-a / extern lib-a.
 */
function openBulkPayslipsPdf() {
  if (!canAccessSalary()) { showToast('⚠ Samo administrator'); return; }
  if (!rootEl) return;
  const rows = kadrPayrollState.byPeriod.get(currentKey()) || [];
  if (!rows.length) { showToast('Nema obračuna u ovom mesecu'); return; }

  /* Primeni isti pretražni filter kao tabela — admin ne želi PDF zaposlenih koje ne vidi. */
  const q = (rootEl.querySelector('#payrSearch').value || '').trim().toLowerCase();
  const filtered = q
    ? rows.filter(r => {
        const hay = [payrollEmployeeName(r), r.employeeName, r.employeePosition, r.employeeDepartment].join(' ').toLowerCase();
        return hay.includes(q);
      })
    : rows;
  if (!filtered.length) { showToast('Nema zaposlenih u trenutnom filteru'); return; }

  const sorted = filtered.slice().sort(comparePayrollRows);
  const todayStr = formatDate(new Date().toISOString().slice(0, 10));
  const period = `${MONTH_NAMES[sorted[0].periodMonth - 1] || sorted[0].periodMonth} ${sorted[0].periodYear}`;
  const title = `Obračuni zarada — ${period} (${sorted.length} zaposlenih)`;
  const body = sorted.map(r => _buildPayslipBody(r, todayStr)).join('\n');

  showToast(`📄 Otvaram ${sorted.length} obračuna…`);
  _openPayslipWindow(title, body);
}

/* ── Utils ──────────────────────────────────────────────── */

function fmtRsd(n) {
  const v = Number(n || 0);
  return `${v.toLocaleString('sr-RS', { maximumFractionDigits: 2 })} RSD`;
}
function fmtNum(n) {
  const v = Number(n || 0);
  return v.toLocaleString('sr-RS', { maximumFractionDigits: 2 });
}

function debounce(fn, ms = 150) {
  let t = null;
  return function (...args) {
    clearTimeout(t);
    t = setTimeout(() => fn.apply(this, args), ms);
  };
}
