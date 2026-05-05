/**
 * Moj profil — self-service modul (Faza K5).
 *
 * Dostupan SVIM ulogovanim korisnicima (viewer, pm, hr, admin…).
 * Svako vidi SAMO SVOJE podatke:
 *   - Profil (ime, pozicija, odeljenje, tim)
 *   - Godišnji odmor — saldo tekuće godine
 *   - Moji zahtevi za GO — tabela sa statusom
 *   - Moja odsustva — tabela
 *   - Revers — trenutna zaduženja alata / opreme (view `v_rev_my_issued_tools`)
 *
 * "Podnesi zahtev" — modal sa 3 polja (od / do / napomena).
 * Admin/HR/menadžment/leadpm/pm imaju picker zaposlenog u modalu
 * (mogu podneti u ime drugog iz svog odeljenja ili svačije).
 *
 * Mount:
 *   renderMojProfilModule(rootEl, { onBackToHub, onLogout });
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { formatDate, daysInclusive, workDaysInclusive } from '../../lib/date.js';
import { loadHolidaysForRange, holidayDateSet } from '../../services/holidays.js';
import { toggleTheme } from '../../lib/theme.js';
import { logout } from '../../services/auth.js';
import {
  getAuth,
  getCurrentUser,
  canSubmitVacationRequestForOthers,
  canManageVacationRequests,
  getManagedDepartments,
} from '../../state/auth.js';
import { hasSupabaseConfig } from '../../lib/constants.js';
import { sbReq } from '../../services/supabase.js';
import { mapDbEmployee } from '../../services/employees.js';
import { mapDbAbsence } from '../../services/absences.js';
import { mapDbBalance } from '../../services/vacation.js';
import {
  mapDbVacReq,
  saveVacationRequestToDb,
  loadVacationRequestsForEmployeeFromDb,
  loadMyVacationRequestsFromDb,
} from '../../services/vacationRequests.js';
import { fetchMyIssuedTools } from '../../services/reversiService.js';
import { compareEmployeesByLastFirst, employeeDisplayName } from '../../lib/employeeNames.js';

/* ── Helperi ────────────────────────────────────────────────────── */

/** 'MMDD' → 'DD.MM.' (npr. '1219' → '19.12.') */
function _formatSlavaDay(mmdd) {
  if (!mmdd || mmdd.length !== 4) return mmdd || '';
  return `${mmdd.slice(2)}.${mmdd.slice(0, 2)}.`;
}

/* ── Konstante ──────────────────────────────────────────────────── */

const STATUS_LABEL = { pending: 'Na čekanju', approved: 'Odobreno', rejected: 'Odbijeno' };
const STATUS_CLASS = { pending: 't-sluzbeno', approved: 't-godisnji', rejected: 't-bolovanje' };

const ABS_TYPE_LABELS = {
  godisnji: 'Godišnji odmor', bolovanje: 'Bolovanje', sluzbeno: 'Službeni put',
  slava: 'Krsna slava', placeno: 'Plaćeno odsustvo', neplaceno: 'Neplaćeno odsustvo',
  slobodan: 'Slobodan dan', ostalo: 'Ostalo',
};

const REV_DOC_TYPE_LABEL = {
  TOOL: 'Alat',
  COOPERATION_GOODS: 'Kooperacija',
};

const REV_DOC_STATUS_LABEL = {
  OPEN: 'Otvoren',
  PARTIALLY_RETURNED: 'Delimično vraćen',
};

/* ── Lokalni state ─────────────────────────────────────────────── */

let rootEl = null;
let onBackToHubCb = null;
let onLogoutCb = null;

let myEmployee = null;       // employees red za ulogovanog korisnika
let myBalance  = null;       // vacation_balance za tekuću godinu
let myAbsences = [];         // sopstvena odsustva
let myRequests = [];         // vacation_requests za mene
let allEmployees = [];       // za picker (samo za upravljačke role)
let myReversalIssued = [];  // v_rev_my_issued_tools (Revers)
let myReversalLoadErr = null;

/* ── Root render ────────────────────────────────────────────────── */

export function renderMojProfilModule(root, { onBackToHub, onLogout } = {}) {
  rootEl = root;
  onBackToHubCb = onBackToHub || null;
  onLogoutCb    = onLogout    || null;

  const auth = getAuth();

  root.innerHTML = `
    <section id="module-moj-profil" class="kadrovska-section" aria-label="Moj profil">
      <div class="kadr-sticky-header-chrome">
        ${_headerHtml(auth)}
      </div>
      <div class="kadr-panel-host" id="mojProfilPanelHost">
        <div class="mp-loading" id="mpLoading" style="padding:40px;text-align:center;color:var(--text2)">
          Učitavanje podataka…
        </div>
      </div>
    </section>`;

  root.querySelector('#mpBackBtn').addEventListener('click', () => onBackToHubCb?.());
  root.querySelector('#mpThemeToggle').addEventListener('click', () => toggleTheme());
  root.querySelector('#mpLogoutBtn').addEventListener('click', async () => {
    await logout();
    onLogoutCb?.();
  });

  _loadAndRender();
}

/* ── Header ─────────────────────────────────────────────────────── */

function _headerHtml(auth) {
  return `
    <header class="kadrovska-header">
      <div class="kadrovska-header-left">
        <button class="btn-hub-back" id="mpBackBtn" title="Nazad na module" aria-label="Nazad na module">
          <span class="back-icon" aria-hidden="true">←</span>
          <span>Moduli</span>
        </button>
        <div class="kadrovska-title">
          <span class="ktitle-mark" aria-hidden="true">👤</span>
          <span>Moj profil</span>
        </div>
      </div>
      <div class="kadrovska-header-right">
        <button class="theme-toggle" id="mpThemeToggle" title="Promeni temu" aria-label="Promeni temu">
          <span class="theme-icon-dark">🌙</span>
          <span class="theme-icon-light">☀️</span>
        </button>
        <span class="role-indicator role-viewer" id="mpRoleLabel">${escHtml((auth.role || 'viewer').toUpperCase())}</span>
        <button class="hub-logout" id="mpLogoutBtn">Odjavi se</button>
      </div>
    </header>`;
}

/* ── Učitavanje podataka ────────────────────────────────────────── */

async function _loadAndRender() {
  const host = rootEl?.querySelector('#mojProfilPanelHost');
  if (!host) return;

  const email = (getCurrentUser()?.email || '').toLowerCase();
  const year  = new Date().getFullYear();
  const canSubmitForOthers = canSubmitVacationRequestForOthers();

  try {
    if (!hasSupabaseConfig()) {
      _renderOffline(host);
      return;
    }

    /* Parallelni fetch: sopstveni employee, saldo, odsustva, zahtevi */
    const [empData, balData, absData, reqData, allEmpData, revIssuedRes] = await Promise.all([
      sbReq(`v_employees_safe?email=eq.${encodeURIComponent(email)}&select=*&limit=1`),
      sbReq(`v_vacation_balance?year=eq.${year}&select=*`),
      sbReq(`absences?select=*&order=date_from.desc`),
      loadMyVacationRequestsFromDb(),
      canSubmitForOthers
        ? sbReq('v_employees_safe?select=id,full_name,first_name,last_name,department,is_active&is_active=eq.true&order=full_name')
        : Promise.resolve(null),
      fetchMyIssuedTools(),
    ]);

    myReversalLoadErr = revIssuedRes?.ok ? null : (revIssuedRes?.error || 'Učitavanje reversa nije uspelo');
    myReversalIssued =
      revIssuedRes?.ok && Array.isArray(revIssuedRes.data) ? revIssuedRes.data : [];

    myEmployee = empData && empData.length > 0 ? mapDbEmployee(empData[0]) : null;

    if (myEmployee) {
      /* Saldo samo za ovog zaposlenog */
      const myBalRow = balData ? balData.find(b => b.employee_id === myEmployee.id) : null;
      myBalance = myBalRow ? mapDbBalance(myBalRow) : null;

      /* Odsustva — filtriraj samo sopstvena */
      myAbsences = absData
        ? absData
            .filter(a => a.employee_id === myEmployee.id)
            .map(mapDbAbsence)
        : [];

      /* Zahtevi — sopstveni + zahtevi gde je employee_id = moj (za slučaj kad je neko drugi podneo za mene) */
      const reqAll = reqData || [];
      const reqForMe = await loadVacationRequestsForEmployeeFromDb(myEmployee.id);
      const combined = [...reqAll, ...(reqForMe || [])];
      /* Deduplikuj po id */
      const seen = new Set();
      myRequests = combined.filter(r => {
        if (seen.has(r.id)) return false;
        seen.add(r.id);
        return true;
      }).sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')));
    } else {
      myBalance  = null;
      myAbsences = [];
      myRequests = reqData || [];
    }

    /* Praznici za tekuću i sledeću godinu (Option B — radni dani) */
    await loadHolidaysForRange(`${year}-01-01`, `${year + 1}-12-31`);

    /* Lista svih zaposlenih za picker (upravljačke role) */
    if (canSubmitForOthers && allEmpData) {
      const managedDepts = getManagedDepartments();
      let list = allEmpData.map(mapDbEmployee);
      /* leadpm/pm: filtrirati samo odeljenja kojima upravljaju */
      if (managedDepts && managedDepts.length > 0) {
        list = list.filter(e => managedDepts.includes(e.department));
      }
      list.sort(compareEmployeesByLastFirst);
      allEmployees = list;
    } else {
      allEmployees = [];
    }

    _renderContent(host);
  } catch (e) {
    console.error('[mojProfil] load failed', e);
    host.innerHTML = `<div style="padding:40px;text-align:center;color:var(--warn)">Greška pri učitavanju podataka.</div>`;
  }
}

function _renderOffline(host) {
  host.innerHTML = `
    <div style="padding:40px;text-align:center;color:var(--text2)">
      <div style="font-size:2rem;margin-bottom:12px">📡</div>
      <div>Aplikacija radi u offline modu — podaci nisu dostupni.</div>
    </div>`;
}

/* ── Content render ─────────────────────────────────────────────── */

function _renderContent(host) {
  const year = new Date().getFullYear();

  host.innerHTML = `
    <div class="mp-content" style="max-width:900px;margin:0 auto;padding:16px 16px 80px;">

      ${_profileCardHtml()}
      ${_balanceCardHtml(year)}

      ${_reversiIssuedSectionHtml()}

      <div class="mp-section-header" style="display:flex;align-items:center;justify-content:space-between;margin:24px 0 8px;">
        <h3 style="margin:0;font-size:1rem;font-weight:600;color:var(--text)">Zahtevi za godišnji odmor</h3>
        <button class="btn btn-primary" id="mpNewRequestBtn" style="gap:6px;">
          + Podnesi zahtev
        </button>
      </div>
      ${_requestsTableHtml()}

      <div class="mp-section-header" style="margin:32px 0 8px;">
        <h3 style="margin:0;font-size:1rem;font-weight:600;color:var(--text)">Moja odsustva</h3>
      </div>
      ${_absencesTableHtml()}

    </div>`;

  host.querySelector('#mpNewRequestBtn').addEventListener('click', () => _openRequestModal());
  host.querySelectorAll('a.mp-reversi-link').forEach((a) => {
    a.addEventListener('click', (ev) => {
      ev.preventDefault();
      import('../router.js').then(({ navigateToAppPath }) => navigateToAppPath('/reversi'));
    });
  });
}

/* ── Profil kartica ─────────────────────────────────────────────── */

function _profileCardHtml() {
  const email = (getCurrentUser()?.email || '').toLowerCase();
  if (!myEmployee) {
    return `
      <div class="mp-card" style="background:var(--surface2);border:1px solid var(--border);border-radius:8px;padding:16px 20px;margin-bottom:16px;">
        <div style="color:var(--text2);font-size:.9rem;">
          Nismo pronašli Vaš zaposleni profil (email: <strong>${escHtml(email)}</strong>).<br>
          Obratite se HR-u da proveri da li je Vaš email ispravno upisan u evidenciji zaposlenih.
        </div>
      </div>`;
  }
  const emp = myEmployee;
  return `
    <div class="mp-card" style="background:var(--surface2);border:1px solid var(--border);border-radius:8px;padding:16px 20px;margin-bottom:16px;display:flex;flex-wrap:wrap;gap:16px;align-items:center;">
      <div style="width:48px;height:48px;border-radius:50%;background:var(--accent,#2563eb);display:flex;align-items:center;justify-content:center;color:#fff;font-size:1.4rem;font-weight:700;flex-shrink:0;">
        ${escHtml((emp.firstName || emp.fullName || '?')[0].toUpperCase())}
      </div>
      <div style="flex:1;min-width:180px;">
        <div style="font-weight:700;font-size:1.05rem;color:var(--text);">${escHtml(employeeDisplayName(emp) || '—')}</div>
        <div style="color:var(--text2);font-size:.85rem;margin-top:2px;">
          ${escHtml(emp.position || '—')}${emp.department ? ` · ${escHtml(emp.department)}` : ''}${emp.team ? ` · ${escHtml(emp.team)}` : ''}
        </div>
        <div style="color:var(--text3,var(--text2));font-size:.8rem;margin-top:4px;">${escHtml(email)}</div>
        ${emp.slava ? `<div style="font-size:.8rem;margin-top:5px;color:var(--text2);">🕯 Slava: <strong style="color:var(--text)">${escHtml(emp.slava)}</strong>${emp.slavaDay ? ` <span style="opacity:.7">(${_formatSlavaDay(emp.slavaDay)})</span>` : ''}</div>` : ''}
      </div>
      ${emp.hireDate ? `<div style="text-align:right;color:var(--text2);font-size:.8rem;">Zaposlen/a od<br><strong style="color:var(--text)">${escHtml(formatDate(emp.hireDate))}</strong></div>` : ''}
    </div>`;
}

/* ── GO saldo kartica ───────────────────────────────────────────── */

function _balanceCardHtml(year) {
  if (!myEmployee) return '';

  const bal = myBalance;
  const total    = bal ? bal.daysTotal + bal.daysCarriedOver : '—';
  const used     = bal ? bal.daysUsed     : '—';
  const remaining = bal ? bal.daysRemaining : '—';
  const remColor = bal
    ? (bal.daysRemaining < 0 ? 'var(--warn,#dc2626)' : bal.daysRemaining <= 3 ? 'var(--accent)' : 'var(--ok,#16a34a)')
    : 'var(--text2)';

  return `
    <div class="mp-balance-cards" style="display:flex;flex-wrap:wrap;gap:12px;margin-bottom:8px;">
      <div class="mp-bal-card" style="flex:1;min-width:120px;background:var(--surface2);border:1px solid var(--border);border-radius:8px;padding:14px 18px;text-align:center;">
        <div style="font-size:.75rem;color:var(--text2);text-transform:uppercase;letter-spacing:.04em;">Ukupno dana GO</div>
        <div style="font-size:2rem;font-weight:700;color:var(--text);font-family:var(--mono);">${total}</div>
        <div style="font-size:.75rem;color:var(--text2);">${year}. godina</div>
      </div>
      <div class="mp-bal-card" style="flex:1;min-width:120px;background:var(--surface2);border:1px solid var(--border);border-radius:8px;padding:14px 18px;text-align:center;">
        <div style="font-size:.75rem;color:var(--text2);text-transform:uppercase;letter-spacing:.04em;">Iskorišćeno</div>
        <div style="font-size:2rem;font-weight:700;color:var(--text);font-family:var(--mono);">${used}</div>
        <div style="font-size:.75rem;color:var(--text2);">dana</div>
      </div>
      <div class="mp-bal-card" style="flex:1;min-width:140px;background:var(--surface2);border:2px solid var(--border);border-radius:8px;padding:14px 18px;text-align:center;">
        <div style="font-size:.75rem;color:var(--text2);text-transform:uppercase;letter-spacing:.04em;">Preostalo</div>
        <div style="font-size:2.4rem;font-weight:800;color:${remColor};font-family:var(--mono);">${remaining}</div>
        <div style="font-size:.75rem;color:var(--text2);">dana</div>
      </div>
    </div>`;
}

/* ── Zahtevi tabela ─────────────────────────────────────────────── */

function _requestsTableHtml() {
  if (!myRequests.length) {
    return `<div style="color:var(--text2);font-size:.9rem;padding:12px 0;">Još nema podnetih zahteva za godišnji odmor.</div>`;
  }
  const rows = myRequests.map(r => {
    const stClass = STATUS_CLASS[r.status] || '';
    const stLabel = STATUS_LABEL[r.status] || r.status;
    const days = r.daysCount || daysInclusive(r.dateFrom, r.dateTo);
    return `<tr>
      <td>${r.dateFrom ? formatDate(r.dateFrom) : '—'}</td>
      <td>${r.dateTo   ? formatDate(r.dateTo)   : '—'}</td>
      <td style="font-family:var(--mono);font-weight:600;">${days}</td>
      <td><span class="kadr-type-badge ${stClass}">${escHtml(stLabel)}</span></td>
      <td class="col-hide-sm">${escHtml(r.note || '—')}</td>
      <td class="col-hide-sm" style="font-size:.8rem;color:var(--text2);">
        ${r.status === 'rejected' && r.rejectionNote
          ? `<span title="${escHtml(r.rejectionNote)}">💬 ${escHtml(r.rejectionNote.slice(0,40))}${r.rejectionNote.length > 40 ? '…' : ''}</span>`
          : (r.reviewedBy ? `${escHtml(r.reviewedBy)}` : '—')}
      </td>
    </tr>`;
  }).join('');

  return `
    <div style="overflow-x:auto;">
      <table class="kadrovska-table" style="width:100%;">
        <thead>
          <tr>
            <th>Od</th><th>Do</th><th>Dana</th><th>Status</th>
            <th class="col-hide-sm">Napomena</th>
            <th class="col-hide-sm">Odgovor HR-a</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    </div>`;
}

/* ── Odsustva tabela ────────────────────────────────────────────── */

function _absencesTableHtml() {
  if (!myEmployee) return '';
  const year = new Date().getFullYear();
  const thisYear = myAbsences.filter(a => {
    const y = a.dateFrom ? new Date(a.dateFrom).getFullYear() : 0;
    return y === year;
  });
  const rows = thisYear.length === 0
    ? `<tr><td colspan="5" style="text-align:center;color:var(--text2);padding:16px;">Nema odsustava za ${year}. godinu.</td></tr>`
    : thisYear.map(a => {
        const days = a.daysCount != null ? a.daysCount : daysInclusive(a.dateFrom, a.dateTo);
        const typeLbl = ABS_TYPE_LABELS[a.type] || a.type;
        return `<tr>
          <td><span class="kadr-type-badge t-${escHtml(a.type)}">${escHtml(typeLbl)}</span></td>
          <td>${a.dateFrom ? formatDate(a.dateFrom) : '—'}</td>
          <td>${a.dateTo   ? formatDate(a.dateTo)   : '—'}</td>
          <td style="font-family:var(--mono);font-weight:600;">${days}</td>
          <td class="col-hide-sm">${escHtml(a.note || '—')}</td>
        </tr>`;
      }).join('');

  return `
    <div style="overflow-x:auto;">
      <table class="kadrovska-table" style="width:100%;">
        <thead>
          <tr>
            <th>Tip</th><th>Od</th><th>Do</th><th>Dana</th>
            <th class="col-hide-sm">Napomena</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    </div>
    ${myAbsences.length > thisYear.length
      ? `<div style="font-size:.8rem;color:var(--text2);margin-top:6px;">Prikazano ${thisYear.length} od ${myAbsences.length} ukupnih odsustava (samo tekuća godina).</div>`
      : ''}`;
}

/** Jedan red za prikaz zaduženja iz reversa (alat ili stavka kooperacije). */
function _reversalItemDescription(row) {
  const lt = row.line_type;
  if (lt === 'PRODUCTION_PART') {
    const pn = row.part_name || '—';
    const dr = row.drawing_no ? ` · crt. ${escHtml(row.drawing_no)}` : '';
    return `${escHtml(pn)}${dr}`;
  }
  const oz = row.oznaka ? String(row.oznaka) : '';
  const nz = row.naziv ? String(row.naziv) : '';
  let s = oz && nz ? `${escHtml(oz)} — ${escHtml(nz)}` : escHtml(oz || nz || '—');
  if (row.serijski_broj) s += ` · SB ${escHtml(String(row.serijski_broj))}`;
  return s;
}

function _reversiIssuedSectionHtml() {
  if (myReversalLoadErr) {
    return `
      <div class="mp-section-header" style="margin:24px 0 8px;">
        <h3 style="margin:0;font-size:1rem;font-weight:600;color:var(--text)">Revers — zaduženja</h3>
      </div>
      <div style="color:var(--warn,#dc2626);font-size:.9rem;padding:8px 0;">
        ${escHtml(myReversalLoadErr)}
      </div>`;
  }
  if (!myReversalIssued.length) {
    return `
      <div class="mp-section-header" style="margin:24px 0 8px;">
        <h3 style="margin:0;font-size:1rem;font-weight:600;color:var(--text)">Revers — zaduženja</h3>
      </div>
      <div style="color:var(--text2);font-size:.9rem;padding:8px 0;">
        Nemate trenutnih zaduženja na reversu (alat / oprema). Za detalje i rad sa dokumentima koristite modul <a href="/reversi" class="mp-reversi-link">Reversi</a>.
      </div>`;
  }

  const rows = myReversalIssued.map((row) => {
    const dt = row.doc_type ? REV_DOC_TYPE_LABEL[row.doc_type] || row.doc_type : '—';
    const st = row.document_status
      ? REV_DOC_STATUS_LABEL[row.document_status] || row.document_status
      : '—';
    const qty = row.quantity != null ? String(row.quantity) : '—';
    const unit = row.unit ? escHtml(String(row.unit)) : '';
    const qDisplay = unit ? `${escHtml(qty)} ${unit}` : escHtml(qty);
    return `<tr>
      <td><span class="kadr-type-badge t-sluzbeno">${escHtml(dt)}</span></td>
      <td style="font-family:var(--mono);font-size:.85rem;">${escHtml(row.doc_number || '—')}</td>
      <td>${row.issued_at ? escHtml(formatDate(row.issued_at)) : '—'}</td>
      <td>${row.expected_return_date ? escHtml(formatDate(row.expected_return_date)) : '—'}</td>
      <td>${_reversalItemDescription(row)}</td>
      <td style="font-family:var(--mono);">${qDisplay}</td>
      <td class="col-hide-sm">${row.pribor ? escHtml(String(row.pribor)) : '—'}</td>
      <td class="col-hide-sm" style="font-size:.85rem;">${escHtml(st)}</td>
    </tr>`;
  }).join('');

  return `
    <div class="mp-section-header" style="display:flex;align-items:baseline;justify-content:space-between;flex-wrap:wrap;gap:8px;margin:24px 0 8px;">
      <h3 style="margin:0;font-size:1rem;font-weight:600;color:var(--text)">Revers — trenutna zaduženja</h3>
      <a href="/reversi" class="mp-reversi-link" style="font-size:.85rem;">Otvori modul Reversi →</a>
    </div>
    <p style="margin:0 0 10px;font-size:.82rem;color:var(--text2);">
      Stavke koje su na Vaše ime i još uvek nisu vraćene (otvoren ili delimično vraćen dokument).
    </p>
    <div style="overflow-x:auto;">
      <table class="kadrovska-table" style="width:100%;">
        <thead>
          <tr>
            <th>Tip</th>
            <th>Br. dokumenta</th>
            <th>Izdato</th>
            <th>Rok povr.</th>
            <th>Predmet</th>
            <th>Kol.</th>
            <th class="col-hide-sm">Pribor / nap. stavke</th>
            <th class="col-hide-sm">Status dok.</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    </div>`;
}

/* ── Modal: Podnesi zahtev ──────────────────────────────────────── */

function _buildModalHtml() {
  const canForOthers = canSubmitVacationRequestForOthers();
  const today = new Date().toISOString().slice(0, 10);

  const empPickerHtml = canForOthers && allEmployees.length > 0 ? `
    <div class="emp-field col-full">
      <label for="mpReqEmpId">Zaposleni *</label>
      <select id="mpReqEmpId" required>
        ${myEmployee ? `<option value="${escHtml(myEmployee.id)}" selected>${escHtml(employeeDisplayName(myEmployee))} (ja)</option>` : '<option value="">— izaberi —</option>'}
        ${allEmployees
          .filter(e => !myEmployee || e.id !== myEmployee.id)
          .map(e => `<option value="${escHtml(e.id)}">${escHtml(employeeDisplayName(e))}${e.department ? ` · ${escHtml(e.department)}` : ''}</option>`)
          .join('')}
      </select>
    </div>` : (myEmployee ? `<input type="hidden" id="mpReqEmpId" value="${escHtml(myEmployee.id)}">` : '');

  return `
    <div class="kadr-modal-overlay" id="mpReqModal" role="dialog" aria-labelledby="mpReqModalTitle" aria-modal="true">
      <div class="kadr-modal">
        <div class="kadr-modal-title" id="mpReqModalTitle">Zahtev za godišnji odmor</div>
        <div class="kadr-modal-subtitle">Izaberi period i opciono dodaj napomenu. Prikazuju se radni dani (bez vikenda i praznika).</div>
        <div class="kadr-modal-err" id="mpReqErr"></div>
        <form id="mpReqForm">
          <div class="emp-form-grid">
            ${empPickerHtml}
            <div class="emp-field">
              <label for="mpReqFrom">Od datuma *</label>
              <input type="date" id="mpReqFrom" required value="${today}" min="${today}">
            </div>
            <div class="emp-field">
              <label for="mpReqTo">Do datuma *</label>
              <input type="date" id="mpReqTo" required value="${today}" min="${today}">
            </div>
            <div class="emp-field col-full" style="padding-top:4px;">
              <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;">
                <span style="color:var(--text2);font-size:.85rem;">Radnih dana:</span>
                <strong id="mpReqDaysDisplay" style="font-family:var(--mono);font-size:1.1rem;color:var(--text);">1</strong>
                <span id="mpReqCalDays" style="font-size:.78rem;color:var(--text3,var(--text2));"></span>
              </div>
              ${myBalance != null ? `<div style="font-size:.78rem;color:var(--text2);margin-top:4px;">Preostalo GO dana: <strong style="color:var(--ok,#16a34a)">${myBalance.daysRemaining}</strong></div>` : ''}
              <div id="mpReqBalWarn" style="display:none;margin-top:6px;padding:8px 12px;background:var(--warn-bg,rgba(220,38,38,.08));border:1px solid var(--warn,#dc2626);border-radius:6px;color:var(--warn,#dc2626);font-size:.82rem;"></div>
            </div>
            <div class="emp-field col-full">
              <label for="mpReqNote">Napomena</label>
              <textarea id="mpReqNote" maxlength="500" rows="2" placeholder="Opcioni komentar (npr. planiran odmor)…"></textarea>
            </div>
          </div>
          <div class="kadr-modal-actions">
            <button type="button" class="btn" id="mpReqCancelBtn">Otkaži</button>
            <button type="submit" class="btn btn-primary" id="mpReqSubmitBtn">Podnesi zahtev</button>
          </div>
        </form>
      </div>
    </div>`;
}

function _closeRequestModal() {
  document.getElementById('mpReqModal')?.remove();
}

function _openRequestModal() {
  if (!myEmployee && !canSubmitVacationRequestForOthers()) {
    showToast('⚠ Vaš zaposleni profil nije pronađen. Obratite se HR-u.');
    return;
  }
  _closeRequestModal();

  const wrap = document.createElement('div');
  wrap.innerHTML = _buildModalHtml();
  document.body.appendChild(wrap.firstElementChild);

  const modal  = document.getElementById('mpReqModal');
  const form   = modal.querySelector('#mpReqForm');
  const fromEl    = modal.querySelector('#mpReqFrom');
  const toEl      = modal.querySelector('#mpReqTo');
  const daysEl    = modal.querySelector('#mpReqDaysDisplay');
  const calDaysEl = modal.querySelector('#mpReqCalDays');
  const balWarnEl = modal.querySelector('#mpReqBalWarn');

  function recalcDays() {
    if (!fromEl.value || !toEl.value) { daysEl.textContent = '—'; if (calDaysEl) calDaysEl.textContent = ''; return; }
    if (toEl.value < fromEl.value) { daysEl.textContent = '⚠'; if (calDaysEl) calDaysEl.textContent = ''; return; }
    const holidays  = holidayDateSet();
    const workDays  = workDaysInclusive(fromEl.value, toEl.value, holidays);
    const calDays   = daysInclusive(fromEl.value, toEl.value);
    daysEl.textContent = String(workDays);
    if (calDaysEl) calDaysEl.textContent = calDays !== workDays ? `(${calDays} kal.)` : '';
    /* Balance warning — samo za sopstvene zahteve */
    const empIdEl = modal.querySelector('#mpReqEmpId');
    const isSelf  = !empIdEl || empIdEl.value === (myEmployee?.id || '');
    if (balWarnEl && isSelf && myBalance && typeof myBalance.daysRemaining === 'number') {
      if (workDays > myBalance.daysRemaining) {
        balWarnEl.textContent = `Tražiš ${workDays} radnih dana, a preostalo je ${myBalance.daysRemaining} dana GO.`;
        balWarnEl.style.display = 'block';
      } else {
        balWarnEl.style.display = 'none';
      }
    }
  }

  fromEl.addEventListener('change', () => {
    if (toEl.value && toEl.value < fromEl.value) toEl.value = fromEl.value;
    recalcDays();
  });
  toEl.addEventListener('change', recalcDays);
  modal.querySelector('#mpReqEmpId')?.addEventListener('change', recalcDays);
  recalcDays();

  modal.querySelector('#mpReqCancelBtn').addEventListener('click', _closeRequestModal);
  modal.addEventListener('click', e => { if (e.target === modal) _closeRequestModal(); });
  form.addEventListener('submit', e => { e.preventDefault(); _submitRequest(); });

  setTimeout(() => fromEl.focus(), 50);
}

async function _submitRequest() {
  const errEl = document.getElementById('mpReqErr');
  const btn   = document.getElementById('mpReqSubmitBtn');
  errEl.textContent = ''; errEl.classList.remove('visible');

  const empIdEl = document.getElementById('mpReqEmpId');
  const fromEl  = document.getElementById('mpReqFrom');
  const toEl    = document.getElementById('mpReqTo');
  const noteEl  = document.getElementById('mpReqNote');

  const employeeId = empIdEl?.value || (myEmployee?.id || '');
  const dateFrom   = fromEl.value;
  const dateTo     = toEl.value;
  const note       = noteEl?.value?.trim() || '';

  if (!employeeId) {
    errEl.textContent = 'Izaberi zaposlenog.'; errEl.classList.add('visible'); return;
  }
  if (!dateFrom || !dateTo) {
    errEl.textContent = 'Datumi su obavezni.'; errEl.classList.add('visible'); return;
  }
  if (dateTo < dateFrom) {
    errEl.textContent = '"Do" ne može biti pre "Od".'; errEl.classList.add('visible'); return;
  }

  const daysCount = workDaysInclusive(dateFrom, dateTo, holidayDateSet());
  const year      = new Date(dateFrom).getFullYear();

  /* Option C — upozorenje ako traženi period premašuje preostali GO saldo */
  const isSelf = employeeId === (myEmployee?.id || '');
  if (isSelf && myBalance && typeof myBalance.daysRemaining === 'number' && daysCount > myBalance.daysRemaining) {
    const ok = confirm(
      `Traženi period ima ${daysCount} radnih dana, ali imate ${myBalance.daysRemaining} dana GO preostalih za ${year}. godinu.\n\nSvejedno podneti zahtev?`
    );
    if (!ok) return;
  }

  btn.disabled = true; btn.textContent = 'Slanje…';
  try {
    const res = await saveVacationRequestToDb({ employeeId, year, dateFrom, dateTo, daysCount, note });
    if (!res || !res.length) {
      errEl.textContent = 'Zahtev nije sačuvan. Pokušajte ponovo.';
      errEl.classList.add('visible');
      return;
    }
    const saved = mapDbVacReq(res[0]);
    myRequests = [saved, ...myRequests];
    _closeRequestModal();
    /* Osvezi prikaz zahteva bez ponovnog fetch-a */
    const host = rootEl?.querySelector('#mojProfilPanelHost');
    if (host) _renderContent(host);
    showToast('✅ Zahtev je podnet. HR će Vas obavestiti o odluci.');
  } catch (e) {
    console.error('[mojProfil] submit', e);
    errEl.textContent = 'Greška pri slanju zahteva.';
    errEl.classList.add('visible');
  } finally {
    btn.disabled = false; btn.textContent = 'Podnesi zahtev';
  }
}
