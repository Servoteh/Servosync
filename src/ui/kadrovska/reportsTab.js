/**
 * Kadrovska / Izveštaji.
 *
 * Trenutno samo "Bolovanja" pod-tab (legacy paritet). Struktura ostavljena
 * tako da se kasnije lako dodaju ostali izveštaji (godišnji, prekovr., teren).
 *
 * Bolovanja izveštaj:
 *   - Izvor: work_hours (šifra bo u mesečnom gridu), ne tabela absences.
 *   - Filteri: zaposleni, odeljenje (firma), period (manual From/To,
 *     month picker, year picker, ili "sva vremena").
 *   - Per-employee aggregati: count evidencija, ukupno dana u periodu,
 *     prosek po evidenciji, datum poslednjeg bolovanja, "trenutno na
 *     bolovanju" pill.
 *   - Summary chips + footer UKUPNO red u tabeli.
 *   - XLSX export (lazy CDN load): 2 sheet-a — "sažetak" i "detalji".
 *
 * Bez framework-a / inline handler-a.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { daysInclusive } from '../../lib/date.js';
import {
  compareEmployeesByLastFirst,
  employeeDisplayName,
} from '../../lib/employeeNames.js';
import { canViewEmployeePii, isAdmin } from '../../state/auth.js';
import { KADR_EDU_LEVEL_LABELS } from '../../lib/constants.js';
import {
  kadrovskaState,
  kadrVacationState,
  kadrChildrenState,
  kadrAbsencesState,
  kadrContractsState,
  orgStructureState,
} from '../../state/kadrovska.js';
import {
  ensureEmployeesLoaded,
  ensureVacationLoaded,
  ensureOrgStructureLoaded,
  ensureAbsencesLoaded,
  ensureContractsLoaded,
} from '../../services/kadrovska.js';
import {
  bolovanjeListFromWorkHours,
  countGoDaysByEmployeeForYear,
  overtimeByEmployeeForPeriod,
  fieldWorkByEmployeeForPeriod,
} from '../../services/workHoursAbsenceReporting.js';
import { loadChildrenForEmployee } from '../../services/employeeChildren.js';
import { loadAllMedExamStatus } from '../../services/medicalExams.js';
import { openMedicalExamsModal } from './medicalExamsModal.js';
import { CERT_TYPE_LABELS, loadAllCertificateStatus } from '../../services/certificates.js';
import { openCertificatesModal } from './certificatesModal.js';
import { AUDIT_TABLE_LABELS, loadAuditLog, diffAuditRow } from '../../services/auditLog.js';
import { triggerWeeklyRiskSummary } from '../../services/hrNotifications.js';
import { renderSummaryChips } from './shared.js';
import { loadXlsx } from '../../lib/xlsx.js';
import { downloadCsv } from '../../lib/csv.js';

let panelRoot = null;
/** Bolovanja iz work_hours (mesečni grid), keš za trenutni period filtera. */
let sickBolItemsCache = [];

async function _reloadSickBolItems() {
  const { from: pFrom, to: pTo } = _readPeriod();
  sickBolItemsCache = (pFrom && pTo)
    ? await bolovanjeListFromWorkHours(pFrom, pTo)
    : await bolovanjeListFromWorkHours('', '');
}

/* ─── HELPERS ──────────────────────────────────────────────────────────── */

function _isoToday() {
  const t = new Date();
  return `${t.getFullYear()}-${String(t.getMonth() + 1).padStart(2, '0')}-${String(t.getDate()).padStart(2, '0')}`;
}

function _ymd(y, m1, d) {
  return `${y}-${String(m1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
}

function _fmtSrDate(ymd) {
  if (!ymd) return '';
  const [y, m, d] = String(ymd).split('-');
  if (!y || !m || !d) return ymd;
  return `${parseInt(d, 10)}.${parseInt(m, 10)}.${y}`;
}

function _periodLabel(from, to) {
  if (!from && !to) return 'Sva vremena';
  if (from && to) return _fmtSrDate(from) + ' – ' + _fmtSrDate(to);
  if (from) return 'od ' + _fmtSrDate(from);
  return 'do ' + _fmtSrDate(to);
}

/**
 * Effective period: explicit From/To → month picker → year picker → all-time.
 */
function _readPeriod() {
  return _readPeriodFor('repSick');
}

/**
 * Generičko čitanje perioda iz prefix-grupe ID-eva.
 *  - {prefix}From / {prefix}To  — eksplicitni range
 *  - {prefix}Month               — 'YYYY-MM'
 *  - {prefix}Year                — 'YYYY'
 */
function _readPeriodFor(prefix) {
  const fromEl = panelRoot?.querySelector('#' + prefix + 'From')?.value || '';
  const toEl = panelRoot?.querySelector('#' + prefix + 'To')?.value || '';
  if (fromEl || toEl) return { from: fromEl || '', to: toEl || '' };
  const monthEl = panelRoot?.querySelector('#' + prefix + 'Month')?.value || '';
  if (monthEl) {
    const [y, m] = monthEl.split('-').map(n => parseInt(n, 10));
    if (y && m) {
      const last = new Date(y, m, 0).getDate();
      return { from: _ymd(y, m, 1), to: _ymd(y, m, last) };
    }
  }
  const yEl = panelRoot?.querySelector('#' + prefix + 'Year')?.value || '';
  if (yEl) {
    const y = parseInt(yEl, 10);
    if (y >= 2000 && y <= 2100) return { from: _ymd(y, 1, 1), to: _ymd(y, 12, 31) };
  }
  return { from: '', to: '' };
}

function _intersectingDays(absFrom, absTo, periodFrom, periodTo) {
  if (!absFrom || !absTo) return 0;
  const f = periodFrom ? (absFrom < periodFrom ? periodFrom : absFrom) : absFrom;
  const t = periodTo ? (absTo > periodTo ? periodTo : absTo) : absTo;
  if (f > t) return 0;
  return daysInclusive(f, t);
}

/* ─── RENDER ───────────────────────────────────────────────────────────── */

export function renderReportsTab() {
  const curYear = String(new Date().getFullYear());
  const showChildren = canViewEmployeePii();
  const showAudit = isAdmin();
  return `
    <section class="kadr-panel-inner kadr-reports-panel" aria-label="Izveštaji">
      <div class="kadr-toolbar reports-toolbar">
        <div class="kadr-toolbar-row" role="tablist" aria-label="Izveštaj — vrsta">
          <button type="button" class="report-tab active" data-report-tab="sick" role="tab" aria-selected="true">🩺 Bolovanja</button>
          <button type="button" class="report-tab" data-report-tab="demo" role="tab" aria-selected="false">📈 Demografija</button>
          <button type="button" class="report-tab" data-report-tab="org" role="tab" aria-selected="false">🏢 Organogram</button>
          <button type="button" class="report-tab" data-report-tab="vacation" role="tab" aria-selected="false">🏖 Saldo GO</button>
          <button type="button" class="report-tab" data-report-tab="overtime" role="tab" aria-selected="false">⏱ Prekovremeni</button>
          <button type="button" class="report-tab" data-report-tab="field" role="tab" aria-selected="false">🚐 Terenski</button>
          ${showChildren ? '<button type="button" class="report-tab" data-report-tab="medical" role="tab" aria-selected="false">🩺 Lekarski</button>' : ''}
          ${showChildren ? '<button type="button" class="report-tab" data-report-tab="certs" role="tab" aria-selected="false">📜 Sertifikati</button>' : ''}
          ${showChildren ? '<button type="button" class="report-tab" data-report-tab="children" role="tab" aria-selected="false">👶 Deca</button>' : ''}
          ${showChildren ? '<button type="button" class="report-tab" data-report-tab="risk" role="tab" aria-selected="false">🎯 Rizik</button>' : ''}
          ${showAudit ? '<button type="button" class="report-tab" data-report-tab="audit" role="tab" aria-selected="false">📒 Audit log</button>' : ''}
        </div>
      </div>

      <div class="report-panel active" id="reportPanel-sick" role="tabpanel">
        <div class="kadr-toolbar">
          <div class="kadr-toolbar-row">
            <label class="kadr-field">
              <span>Zaposleni</span>
              <select id="repSickEmpFilter"><option value="">Svi zaposleni</option></select>
            </label>
            <label class="kadr-field">
              <span>Odeljenje / firma</span>
              <select id="repSickDeptFilter"><option value="">Sva odeljenja / firme</option></select>
            </label>
            <label class="kadr-field">
              <span>Mesec</span>
              <input type="month" id="repSickMonth">
            </label>
            <label class="kadr-field">
              <span>Godina</span>
              <input type="number" id="repSickYear" min="2000" max="2100" value="${curYear}" style="max-width:90px">
            </label>
            <label class="kadr-field">
              <span>Od</span>
              <input type="date" id="repSickFrom">
            </label>
            <label class="kadr-field">
              <span>Do</span>
              <input type="date" id="repSickTo">
            </label>
            <button type="button" class="btn btn-ghost" id="repSickReset">Resetuj filtere</button>
            <button type="button" class="btn btn-ghost" id="repSickExport" title="Izvoz u Excel">📊 Excel</button>
            <button type="button" class="btn btn-ghost" id="repSickExportCsv" title="Izvoz u CSV">📑 CSV</button>
            <span class="kadr-count" id="repSickCount">0 evidencija</span>
          </div>
        </div>
        <div class="kadr-summary-strip" id="repSickSummary"></div>
        <div class="kadr-table-wrap">
          <table class="kadr-table report-sick-table">
            <thead>
              <tr>
                <th>Zaposleni</th>
                <th class="col-hide-sm">Odeljenje</th>
                <th>Br. evid.</th>
                <th>Σ dana (period)</th>
                <th class="col-hide-sm">Prosek (d)</th>
                <th class="col-hide-sm">Poslednje</th>
                <th>Trenutno?</th>
              </tr>
            </thead>
            <tbody id="repSickTbody"></tbody>
            <tfoot id="repSickTfoot"></tfoot>
          </table>
        </div>
        <div id="repSickEmpty" class="kadr-empty" style="display:none">Nema bolovanja u izabranom periodu.</div>
      </div>

      <div class="report-panel" id="reportPanel-demo" role="tabpanel" hidden>
        <div class="kadr-toolbar">
          <div class="kadr-toolbar-row">
            <label class="kadr-field">
              <span>Status</span>
              <select id="repDemoStatus">
                <option value="active" selected>Samo aktivni</option>
                <option value="all">Svi</option>
              </select>
            </label>
            <button type="button" class="btn btn-ghost" id="repDemoExport" title="Izvoz u Excel">📊 Excel</button>
          </div>
        </div>
        <div class="kadr-summary-strip" id="repDemoSummary"></div>
        <div class="kadr-demo-grid" id="repDemoGrid"></div>
      </div>

      <div class="report-panel" id="reportPanel-org" role="tabpanel" hidden>
        <div class="kadr-toolbar">
          <div class="kadr-toolbar-row">
            <label class="kadr-field">
              <span>Status</span>
              <select id="repOrgStatus">
                <option value="active" selected>Samo aktivni</option>
                <option value="all">Svi</option>
              </select>
            </label>
            <label class="kadr-field">
              <span>Pretraga zaposlenog</span>
              <input type="text" id="repOrgSearch" placeholder="ime ili pozicija…">
            </label>
            <button type="button" class="btn btn-ghost" id="repOrgExpand">⬇ Otvori sve</button>
            <button type="button" class="btn btn-ghost" id="repOrgCollapse">⬆ Zatvori sve</button>
          </div>
        </div>
        <div class="kadr-summary-strip" id="repOrgSummary"></div>
        <div class="kadr-org-tree" id="repOrgTree"></div>
        <div id="repOrgEmpty" class="kadr-empty" style="display:none">Org struktura nije konfigurisana — popuni odeljenja u Zaposleni tabu.</div>
      </div>

      <div class="report-panel" id="reportPanel-vacation" role="tabpanel" hidden>
        <div class="kadr-toolbar">
          <div class="kadr-toolbar-row">
            <label class="kadr-field">
              <span>Godina</span>
              <input type="number" id="repVacYear" min="2000" max="2100" value="${curYear}" style="max-width:90px">
            </label>
            <label class="kadr-field">
              <span>Status</span>
              <select id="repVacStatus">
                <option value="active" selected>Samo aktivni</option>
                <option value="all">Svi</option>
              </select>
            </label>
            <button type="button" class="btn btn-ghost" id="repVacExport" title="Izvoz u Excel">📊 Excel</button>
            <button type="button" class="btn btn-ghost" id="repVacExportCsv" title="Izvoz u CSV">📑 CSV</button>
            <span class="kadr-count" id="repVacCount">0 zaposlenih</span>
          </div>
        </div>
        <div class="kadr-summary-strip" id="repVacSummary"></div>
        <div class="kadr-table-wrap">
          <table class="kadr-table">
            <thead>
              <tr>
                <th>Zaposleni</th>
                <th class="col-hide-sm">Odeljenje</th>
                <th>Dana pravo</th>
                <th>Preneto</th>
                <th>Iskorišćeno</th>
                <th>Preostalo</th>
              </tr>
            </thead>
            <tbody id="repVacTbody"></tbody>
          </table>
        </div>
        <div id="repVacEmpty" class="kadr-empty" style="display:none">Nema podataka o GO za izabranu godinu.</div>
      </div>

      <div class="report-panel" id="reportPanel-overtime" role="tabpanel" hidden>
        <div class="kadr-toolbar">
          <div class="kadr-toolbar-row">
            <label class="kadr-field">
              <span>Mesec</span>
              <input type="month" id="repOtMonth">
            </label>
            <label class="kadr-field">
              <span>Godina</span>
              <input type="number" id="repOtYear" min="2000" max="2100" value="${curYear}" style="max-width:90px">
            </label>
            <label class="kadr-field">
              <span>Od</span>
              <input type="date" id="repOtFrom">
            </label>
            <label class="kadr-field">
              <span>Do</span>
              <input type="date" id="repOtTo">
            </label>
            <button type="button" class="btn btn-ghost" id="repOtReset">Resetuj filtere</button>
            <button type="button" class="btn btn-ghost" id="repOtExport" title="Izvoz u Excel">📊 Excel</button>
            <span class="kadr-count" id="repOtCount">0 zaposlenih</span>
          </div>
        </div>
        <div class="kadr-summary-strip" id="repOtSummary"></div>
        <div class="kadr-table-wrap">
          <table class="kadr-table">
            <thead>
              <tr>
                <th>Zaposleni</th>
                <th class="col-hide-sm">Odeljenje</th>
                <th>Σ prekovr. (h)</th>
                <th class="col-hide-sm">Dani sa prekovr.</th>
                <th class="col-hide-sm">2 mašine (h)</th>
                <th class="col-hide-sm">Poslednji datum</th>
              </tr>
            </thead>
            <tbody id="repOtTbody"></tbody>
            <tfoot id="repOtTfoot"></tfoot>
          </table>
        </div>
        <div id="repOtEmpty" class="kadr-empty" style="display:none">Nema prekovremenog rada u izabranom periodu.</div>
      </div>

      <div class="report-panel" id="reportPanel-field" role="tabpanel" hidden>
        <div class="kadr-toolbar">
          <div class="kadr-toolbar-row">
            <label class="kadr-field">
              <span>Mesec</span>
              <input type="month" id="repFwMonth">
            </label>
            <label class="kadr-field">
              <span>Godina</span>
              <input type="number" id="repFwYear" min="2000" max="2100" value="${curYear}" style="max-width:90px">
            </label>
            <label class="kadr-field">
              <span>Od</span>
              <input type="date" id="repFwFrom">
            </label>
            <label class="kadr-field">
              <span>Do</span>
              <input type="date" id="repFwTo">
            </label>
            <label class="kadr-field">
              <span>Tip</span>
              <select id="repFwType">
                <option value="">Sve</option>
                <option value="domestic">Domaći</option>
                <option value="foreign">Inostrani</option>
              </select>
            </label>
            <button type="button" class="btn btn-ghost" id="repFwReset">Resetuj filtere</button>
            <button type="button" class="btn btn-ghost" id="repFwExport" title="Izvoz u Excel">📊 Excel</button>
            <span class="kadr-count" id="repFwCount">0 zaposlenih</span>
          </div>
        </div>
        <div class="kadr-summary-strip" id="repFwSummary"></div>
        <div class="kadr-table-wrap">
          <table class="kadr-table">
            <thead>
              <tr>
                <th>Zaposleni</th>
                <th class="col-hide-sm">Odeljenje</th>
                <th>Domaći (dani)</th>
                <th class="col-hide-sm">Domaći (h)</th>
                <th>Inostrani (dani)</th>
                <th class="col-hide-sm">Inostrani (h)</th>
                <th class="col-hide-sm">Σ dani</th>
                <th class="col-hide-sm">Poslednji datum</th>
              </tr>
            </thead>
            <tbody id="repFwTbody"></tbody>
            <tfoot id="repFwTfoot"></tfoot>
          </table>
        </div>
        <div id="repFwEmpty" class="kadr-empty" style="display:none">Nema terenskog rada u izabranom periodu.</div>
      </div>

      ${showChildren ? `
      <div class="report-panel" id="reportPanel-certs" role="tabpanel" hidden>
        <div class="kadr-toolbar">
          <div class="kadr-toolbar-row">
            <label class="kadr-field">
              <span>Tip</span>
              <select id="repCertType">
                <option value="" selected>Svi tipovi</option>
                ${Object.entries(CERT_TYPE_LABELS).map(([k, v]) => `<option value="${k}">${escHtml(v)}</option>`).join('')}
              </select>
            </label>
            <label class="kadr-field">
              <span>Status</span>
              <select id="repCertStatus">
                <option value="problem" selected>Problemi (istekli + ističu)</option>
                <option value="expired">Samo istekli</option>
                <option value="expiring_soon">Samo ističu &lt;30 dana</option>
                <option value="lifetime">Trajni</option>
                <option value="all">Svi</option>
              </select>
            </label>
            <button type="button" class="btn btn-ghost" id="repCertReload">🔄 Osveži</button>
            <button type="button" class="btn btn-ghost" id="repCertExport" title="Izvoz u Excel">📊 Excel</button>
            <button type="button" class="btn btn-ghost" id="repCertExportCsv" title="Izvoz u CSV">📑 CSV</button>
            <span class="kadr-count" id="repCertCount">0 sertifikata</span>
          </div>
        </div>
        <div class="kadr-summary-strip" id="repCertSummary"></div>
        <div class="kadr-table-wrap">
          <table class="kadr-table">
            <thead>
              <tr>
                <th>Zaposleni</th>
                <th>Tip</th>
                <th>Naziv / br.</th>
                <th>Izdat</th>
                <th>Ističe</th>
                <th>Status</th>
                <th class="col-actions">Akcije</th>
              </tr>
            </thead>
            <tbody id="repCertTbody"></tbody>
          </table>
        </div>
        <div id="repCertEmpty" class="kadr-empty" style="display:none">Nema sertifikata u izabranom filteru.</div>
      </div>
      ` : ''}

      ${showChildren ? `
      <div class="report-panel" id="reportPanel-medical" role="tabpanel" hidden>
        <div class="kadr-toolbar">
          <div class="kadr-toolbar-row">
            <label class="kadr-field">
              <span>Status</span>
              <select id="repMedStatus">
                <option value="problem" selected>Problemi (istekli + ističu + nikad)</option>
                <option value="expired">Samo istekli</option>
                <option value="expiring_soon">Samo ističu &lt;30 dana</option>
                <option value="never">Nikad nije bio</option>
                <option value="all">Svi</option>
              </select>
            </label>
            <button type="button" class="btn btn-ghost" id="repMedReload">🔄 Osveži</button>
            <button type="button" class="btn btn-ghost" id="repMedExport" title="Izvoz u Excel">📊 Excel</button>
            <button type="button" class="btn btn-ghost" id="repMedExportCsv" title="Izvoz u CSV">📑 CSV</button>
            <span class="kadr-count" id="repMedCount">0 zaposlenih</span>
          </div>
        </div>
        <div class="kadr-summary-strip" id="repMedSummary"></div>
        <div class="kadr-table-wrap">
          <table class="kadr-table">
            <thead>
              <tr>
                <th>Zaposleni</th>
                <th class="col-hide-sm">Odeljenje</th>
                <th>Poslednji pregled</th>
                <th>Važi do</th>
                <th>Status</th>
                <th class="col-actions">Akcije</th>
              </tr>
            </thead>
            <tbody id="repMedTbody"></tbody>
          </table>
        </div>
        <div id="repMedEmpty" class="kadr-empty" style="display:none">Nema podataka o lekarskim pregledima.</div>
      </div>
      ` : ''}

      ${showChildren ? `
      <div class="report-panel" id="reportPanel-risk" role="tabpanel" hidden>
        <div class="kadr-toolbar">
          <div class="kadr-toolbar-row">
            <label class="kadr-field">
              <span>Status</span>
              <select id="repRiskStatus">
                <option value="active" selected>Samo aktivni</option>
                <option value="all">Svi</option>
              </select>
            </label>
            <label class="kadr-field">
              <span>Period (meseci unazad)</span>
              <select id="repRiskMonths">
                <option value="6">6 meseci</option>
                <option value="12" selected>12 meseci</option>
                <option value="24">24 meseca</option>
              </select>
            </label>
            <label class="kadr-field">
              <span>Min. nivo</span>
              <select id="repRiskLevel">
                <option value="all" selected>Svi</option>
                <option value="medium">Srednji i visok</option>
                <option value="high">Samo visok</option>
              </select>
            </label>
            <button type="button" class="btn btn-ghost" id="repRiskExport" title="Izvoz u Excel">📊 Excel</button>
            <button type="button" class="btn btn-ghost" id="repRiskEmail" title="Stavi nedeljni risk pregled u queue (HR email iz Notifikacije)">📧 Pošalji HR-u</button>
            <span class="kadr-count" id="repRiskCount">0 zaposlenih</span>
          </div>
        </div>
        <div class="kadr-summary-strip" id="repRiskSummary"></div>
        <div class="kadr-heatmap-section" id="repRiskHeatmap"></div>
        <div class="kadr-table-wrap">
          <table class="kadr-table" id="repRiskTable">
            <thead>
              <tr>
                <th>Zaposleni</th>
                <th class="col-hide-sm">Odeljenje</th>
                <th title="Broj dana bolovanja u izabranom periodu">BO dana</th>
                <th class="col-hide-sm" title="Broj evidencija bolovanja">BO evid.</th>
                <th title="Lekarski pregled — kad ističe">Lekarski</th>
                <th class="col-hide-sm" title="Aktivni ugovor — kad ističe">Ugovor</th>
                <th>Rizik</th>
                <th class="col-hide-sm">Razlog</th>
              </tr>
            </thead>
            <tbody id="repRiskTbody"></tbody>
          </table>
        </div>
        <div id="repRiskEmpty" class="kadr-empty" style="display:none">Nema zaposlenih sa indikatorima rizika za izabrane filtere.</div>
        <div class="kadr-risk-note">
          <strong>Napomena:</strong> Risk skor je prediktivni indikator zasnovan na istorijskim podacima i blizini isteka dokumenata.
          Visok rizik = >7 dana bolovanja u periodu ILI istekli dokumenti.
          Srednji = 4–7 dana bolovanja ILI dokumenti ističu ≤30 dana.
          Niski = manje od 4 dana bolovanja i sve uredu.
        </div>
      </div>
      ` : ''}

      ${showAudit ? `
      <div class="report-panel" id="reportPanel-audit" role="tabpanel" hidden>
        <div class="kadr-toolbar">
          <div class="kadr-toolbar-row">
            <label class="kadr-field">
              <span>Tabela</span>
              <select id="repAuditTable">
                <option value="">Sve</option>
                ${Object.entries(AUDIT_TABLE_LABELS).map(([k, v]) => `<option value="${k}">${escHtml(v)}</option>`).join('')}
              </select>
            </label>
            <label class="kadr-field">
              <span>Akcija</span>
              <select id="repAuditAction">
                <option value="">Sve</option>
                <option value="INSERT">INSERT</option>
                <option value="UPDATE">UPDATE</option>
                <option value="DELETE">DELETE</option>
              </select>
            </label>
            <label class="kadr-field">
              <span>Od</span>
              <input type="date" id="repAuditFrom">
            </label>
            <label class="kadr-field">
              <span>Do</span>
              <input type="date" id="repAuditTo">
            </label>
            <button type="button" class="btn btn-ghost" id="repAuditReload">🔄 Učitaj</button>
            <button type="button" class="btn btn-ghost" id="repAuditExport" title="Izvoz u CSV">📑 CSV</button>
            <span class="kadr-count" id="repAuditCount">0 zapisa</span>
          </div>
        </div>
        <div class="kadr-summary-strip" id="repAuditSummary"></div>
        <div class="kadr-table-wrap">
          <table class="kadr-table">
            <thead>
              <tr>
                <th>Vreme</th>
                <th>Akter</th>
                <th>Akcija</th>
                <th>Tabela</th>
                <th>Zaposleni</th>
                <th>Promene</th>
              </tr>
            </thead>
            <tbody id="repAuditTbody"></tbody>
          </table>
        </div>
        <div id="repAuditEmpty" class="kadr-empty" style="display:none">Nema audit zapisa za izabrani filter.</div>
      </div>
      ` : ''}

      ${showChildren ? `
      <div class="report-panel" id="reportPanel-children" role="tabpanel" hidden>
        <div class="kadr-toolbar">
          <div class="kadr-toolbar-row">
            <button type="button" class="btn btn-ghost" id="repChildrenExport" title="Izvoz u Excel">📊 Excel</button>
            <span class="kadr-count" id="repChildrenCount">0 dece</span>
          </div>
        </div>
        <div class="kadr-summary-strip" id="repChildrenSummary"></div>
        <div class="kadr-table-wrap">
          <table class="kadr-table">
            <thead>
              <tr>
                <th>Zaposleni</th>
                <th>Dete — ime</th>
                <th>Datum rođenja</th>
                <th>Starost (god.)</th>
              </tr>
            </thead>
            <tbody id="repChildrenTbody"></tbody>
          </table>
        </div>
        <div id="repChildrenEmpty" class="kadr-empty" style="display:none">Nema upisane dece.</div>
      </div>
      ` : ''}
    </section>
  `;
}

/* ─── FILTERS POPULATE ────────────────────────────────────────────────── */

function _populateFilters() {
  const sel = panelRoot?.querySelector('#repSickEmpFilter');
  if (sel) {
    const prev = sel.value;
    const sortedEmp = kadrovskaState.employees.slice()
      .sort(compareEmployeesByLastFirst);
    sel.innerHTML = '<option value="">Svi zaposleni</option>'
      + sortedEmp.map(e => `<option value="${escHtml(e.id)}">${escHtml(employeeDisplayName(e) || '—')}${e.isActive ? '' : ' (neaktivan)'}</option>`).join('');
    if (prev && Array.from(sel.options).some(o => o.value === prev)) sel.value = prev;
  }
  const dsel = panelRoot?.querySelector('#repSickDeptFilter');
  if (dsel) {
    const prev = dsel.value;
    let deptOpts = '';
    if (orgStructureState.departments.length) {
      const list = [...orgStructureState.departments].sort((a, b) => a.sort_order - b.sort_order || a.name.localeCompare(b.name, 'sr'));
      deptOpts = list.map(d => `<option value="${d.id}">${escHtml(d.name)}</option>`).join('');
    } else {
      const set = new Set();
      kadrovskaState.employees.forEach(e => {
        if (e.department) set.add(String(e.department).trim());
      });
      deptOpts = Array.from(set).sort((a, b) => a.localeCompare(b, 'sr'))
        .map(d => `<option value="${escHtml(d)}">${escHtml(d)}</option>`).join('');
    }
    dsel.innerHTML = '<option value="">Sva odeljenja / firme</option>' + deptOpts;
    if (prev && Array.from(dsel.options).some(o => o.value === prev)) dsel.value = prev;
  }
}

/* ─── REPORT RENDER ───────────────────────────────────────────────────── */

function _aggregate() {
  const empFilter = panelRoot?.querySelector('#repSickEmpFilter')?.value || '';
  const deptFilter = panelRoot?.querySelector('#repSickDeptFilter')?.value || '';
  const { from: pFrom, to: pTo } = _readPeriod();

  const allSick = sickBolItemsCache;
  const empById = new Map(kadrovskaState.employees.map(e => [e.id, e]));
  const today = _isoToday();

  const perEmp = new Map();
  let kept = 0;
  allSick.forEach(a => {
    if (!a.employeeId) return;
    if (empFilter && a.employeeId !== empFilter) return;
    const emp = empById.get(a.employeeId);
    if (deptFilter) {
      if (!emp) return;
      const deptId = parseInt(deptFilter, 10);
      if (orgStructureState.departments.length && !isNaN(deptId)) {
        if (emp.departmentId !== deptId) return;
      } else {
        if (emp.department !== deptFilter) return;
      }
    }
    const days = _intersectingDays(a.dateFrom, a.dateTo, pFrom, pTo);
    if (days <= 0) return;
    kept++;
    if (!perEmp.has(a.employeeId)) {
      perEmp.set(a.employeeId, {
        emp: emp || null,
        id: a.employeeId,
        name: emp ? employeeDisplayName(emp) : '(obrisan)',
        dept: emp?.departmentName || emp?.department || '',
        count: 0,
        totalDays: 0,
        lastTo: '',
        currentlyActive: false,
        durations: [],
      });
    }
    const r = perEmp.get(a.employeeId);
    r.count++;
    r.totalDays += days;
    if (a.dateFrom && a.dateTo && a.dateFrom <= today && a.dateTo >= today) r.currentlyActive = true;
    if (a.dateTo && (!r.lastTo || a.dateTo > r.lastTo)) r.lastTo = a.dateTo;
    r.durations.push(daysInclusive(a.dateFrom, a.dateTo));
  });

  return { perEmp, kept, pFrom, pTo, empFilter, deptFilter, empById, today, allSick };
}

async function _renderSickReport() {
  try {
    await _reloadSickBolItems();
  } catch (err) {
    console.error('[reports] bolovanje iz work_hours', err);
    sickBolItemsCache = [];
  }
  const tbody = panelRoot?.querySelector('#repSickTbody');
  const tfoot = panelRoot?.querySelector('#repSickTfoot');
  const empty = panelRoot?.querySelector('#repSickEmpty');
  const countEl = panelRoot?.querySelector('#repSickCount');
  const badge = document.getElementById('kadrTabCountReports');
  if (!tbody) return;

  const { perEmp, kept, pFrom, pTo } = _aggregate();
  const empCount = perEmp.size;
  let sumDays = 0, currentNow = 0;
  perEmp.forEach(r => {
    sumDays += r.totalDays;
    if (r.currentlyActive) currentNow++;
  });
  const avgPerEmp = empCount ? Math.round((sumDays / empCount) * 10) / 10 : 0;

  if (badge) badge.textContent = String(empCount);
  if (countEl) countEl.textContent = `${kept} ${kept === 1 ? 'evidencija' : 'evidencija'} · ${empCount} ${empCount === 1 ? 'zaposleni' : 'zaposlenih'}`;

  renderSummaryChips('repSickSummary', [
    { label: 'Period', value: _periodLabel(pFrom, pTo), tone: 'muted' },
    { label: 'Zaposlenih sa bolovanjem', value: empCount, tone: empCount > 0 ? 'accent' : 'muted' },
    { label: 'Σ Dana', value: sumDays, tone: sumDays > 0 ? 'warn' : 'muted' },
    { label: 'Prosek dana / radnik', value: avgPerEmp, tone: 'muted' },
    { label: 'Trenutno na bolovanju', value: currentNow, tone: currentNow > 0 ? 'warn' : 'muted' },
  ]);

  if (empCount === 0) {
    tbody.innerHTML = '';
    if (tfoot) tfoot.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  const rows = Array.from(perEmp.values()).sort((a, b) => {
    if (b.totalDays !== a.totalDays) return b.totalDays - a.totalDays;
    return String(a.name).localeCompare(String(b.name), 'sr');
  });

  tbody.innerHTML = rows.map(r => {
    const avg = r.durations.length
      ? Math.round((r.durations.reduce((a, b) => a + b, 0) / r.durations.length) * 10) / 10
      : 0;
    const last = r.lastTo ? _fmtSrDate(r.lastTo) : '—';
    const cur = r.currentlyActive
      ? '<span class="kadr-pill warn">DA</span>'
      : '<span class="kadr-pill muted">ne</span>';
    return `<tr>
      <td><strong>${escHtml(r.name)}</strong></td>
      <td class="col-hide-sm">${escHtml(r.dept || '—')}</td>
      <td>${r.count}</td>
      <td><strong>${r.totalDays}</strong></td>
      <td class="col-hide-sm">${avg}</td>
      <td class="col-hide-sm">${escHtml(last)}</td>
      <td>${cur}</td>
    </tr>`;
  }).join('');

  if (tfoot) {
    tfoot.innerHTML = `<tr class="row-totals">
      <td colspan="2" style="text-align:right;font-weight:700">UKUPNO</td>
      <td>${rows.reduce((s, r) => s + r.count, 0)}</td>
      <td><strong>${sumDays}</strong></td>
      <td colspan="3"></td>
    </tr>`;
  }
}

/* ═════════════════════════════════════════════════════════════════════
   DEMOGRAFIJA (rod / starost / obrazovanje / staž)
   ═════════════════════════════════════════════════════════════════════ */

function _ageYears(birthDate) {
  if (!birthDate) return null;
  const d = new Date(birthDate);
  if (isNaN(d)) return null;
  const t = new Date();
  let y = t.getFullYear() - d.getFullYear();
  const m = t.getMonth() - d.getMonth();
  if (m < 0 || (m === 0 && t.getDate() < d.getDate())) y--;
  return y;
}

function _tenureYears(hireDate) {
  if (!hireDate) return null;
  const d = new Date(hireDate);
  if (isNaN(d)) return null;
  return _ageYears(hireDate);
}

const AGE_BUCKETS = [
  { k: '<25',    min: 0,  max: 24 },
  { k: '25–34',  min: 25, max: 34 },
  { k: '35–44',  min: 35, max: 44 },
  { k: '45–54',  min: 45, max: 54 },
  { k: '55+',    min: 55, max: 200 },
];
const TENURE_BUCKETS = [
  { k: '<1 god', min: 0,  max: 0 },
  { k: '1–2',    min: 1,  max: 2 },
  { k: '3–5',    min: 3,  max: 5 },
  { k: '6–10',   min: 6,  max: 10 },
  { k: '11–20',  min: 11, max: 20 },
  { k: '20+',    min: 21, max: 200 },
];

function _bucketize(val, buckets) {
  if (val == null) return '(nepoznato)';
  for (const b of buckets) {
    if (val >= b.min && val <= b.max) return b.k;
  }
  return '(nepoznato)';
}

function _aggregateDemo() {
  const status = panelRoot?.querySelector('#repDemoStatus')?.value || 'active';
  const emps = kadrovskaState.employees.filter(e => status === 'all' || e.isActive);

  const gender = new Map([['M', 0], ['Z', 0], ['(nepoznato)', 0]]);
  const ageDist = new Map(AGE_BUCKETS.map(b => [b.k, 0]).concat([['(nepoznato)', 0]]));
  const tenDist = new Map(TENURE_BUCKETS.map(b => [b.k, 0]).concat([['(nepoznato)', 0]]));
  const eduDist = new Map();
  const deptDist = new Map();

  emps.forEach(e => {
    gender.set(e.gender || '(nepoznato)', (gender.get(e.gender || '(nepoznato)') || 0) + 1);
    const age = _ageYears(e.birthDate);
    ageDist.set(_bucketize(age, AGE_BUCKETS), (ageDist.get(_bucketize(age, AGE_BUCKETS)) || 0) + 1);
    const ten = _tenureYears(e.hireDate);
    tenDist.set(_bucketize(ten, TENURE_BUCKETS), (tenDist.get(_bucketize(ten, TENURE_BUCKETS)) || 0) + 1);
    const eduLbl = e.educationLevel
      ? (KADR_EDU_LEVEL_LABELS[e.educationLevel] || e.educationLevel)
      : '(nepopunjeno)';
    eduDist.set(eduLbl, (eduDist.get(eduLbl) || 0) + 1);
    const dept = e.department || '(nedodeljeno)';
    deptDist.set(dept, (deptDist.get(dept) || 0) + 1);
  });

  return { total: emps.length, gender, ageDist, tenDist, eduDist, deptDist };
}

function _miniCardHtml(title, dist, { order = null, sortDesc = true } = {}) {
  let entries = Array.from(dist.entries()).filter(([, n]) => n > 0);
  if (order) {
    const idx = new Map(order.map((k, i) => [k, i]));
    entries.sort((a, b) => (idx.get(a[0]) ?? 999) - (idx.get(b[0]) ?? 999));
  } else if (sortDesc) {
    entries.sort((a, b) => b[1] - a[1] || String(a[0]).localeCompare(String(b[0]), 'sr'));
  }
  const total = entries.reduce((s, [, n]) => s + n, 0) || 1;
  const rows = entries.map(([k, n]) => {
    const pct = Math.round((n / total) * 100);
    return `<div class="demo-row">
      <span class="demo-k">${escHtml(k)}</span>
      <span class="demo-bar"><span style="width:${pct}%"></span></span>
      <span class="demo-v">${n} <small>(${pct}%)</small></span>
    </div>`;
  }).join('');
  return `<div class="demo-card">
    <h4>${escHtml(title)}</h4>
    ${rows || '<div class="emp-sub">Nema podataka.</div>'}
  </div>`;
}

function _renderDemo() {
  if (!panelRoot) return;
  const host = panelRoot.querySelector('#repDemoGrid');
  if (!host) return;
  const a = _aggregateDemo();
  renderSummaryChips('repDemoSummary', [
    { label: 'Ukupno', value: a.total, tone: 'accent' },
    { label: 'Muški', value: a.gender.get('M') || 0, tone: 'muted' },
    { label: 'Ženski', value: a.gender.get('Z') || 0, tone: 'muted' },
    { label: 'Bez podataka (pol)', value: a.gender.get('(nepoznato)') || 0, tone: 'muted' },
  ]);
  const genderLabeled = new Map([
    ['Muški',     a.gender.get('M') || 0],
    ['Ženski',    a.gender.get('Z') || 0],
    ['(nepoznato)', a.gender.get('(nepoznato)') || 0],
  ]);
  host.innerHTML = [
    _miniCardHtml('Rodna struktura', genderLabeled, { order: ['Muški', 'Ženski', '(nepoznato)'] }),
    _miniCardHtml('Starosna struktura', a.ageDist, { order: AGE_BUCKETS.map(b => b.k).concat(['(nepoznato)']) }),
    _miniCardHtml('Staž', a.tenDist, { order: TENURE_BUCKETS.map(b => b.k).concat(['(nepoznato)']) }),
    _miniCardHtml('Stručna sprema', a.eduDist),
    _miniCardHtml('Po odeljenjima', a.deptDist),
  ].join('');
}

async function _exportDemoXlsx() {
  let XLSX;
  try { XLSX = await loadXlsx(); } catch { showToast('⚠ XLSX nedostupan'); return; }
  const a = _aggregateDemo();
  const sheets = [
    ['Rod', [
      ['Pol', 'Broj'],
      ['Muški', a.gender.get('M') || 0],
      ['Ženski', a.gender.get('Z') || 0],
      ['(nepoznato)', a.gender.get('(nepoznato)') || 0],
    ]],
    ['Starost', [
      ['Raspon', 'Broj'],
      ...AGE_BUCKETS.map(b => [b.k, a.ageDist.get(b.k) || 0]),
      ['(nepoznato)', a.ageDist.get('(nepoznato)') || 0],
    ]],
    ['Staž', [
      ['Raspon', 'Broj'],
      ...TENURE_BUCKETS.map(b => [b.k, a.tenDist.get(b.k) || 0]),
      ['(nepoznato)', a.tenDist.get('(nepoznato)') || 0],
    ]],
    ['Stručna sprema', [
      ['Stepen', 'Broj'],
      ...Array.from(a.eduDist.entries()).sort((x, y) => y[1] - x[1]),
    ]],
    ['Odeljenja', [
      ['Odeljenje', 'Broj'],
      ...Array.from(a.deptDist.entries()).sort((x, y) => y[1] - x[1]),
    ]],
  ];
  const wb = XLSX.utils.book_new();
  for (const [name, rows] of sheets) {
    const ws = XLSX.utils.aoa_to_sheet(rows);
    ws['!cols'] = [{ wch: 24 }, { wch: 10 }];
    XLSX.utils.book_append_sheet(wb, ws, name);
  }
  XLSX.writeFile(wb, `Demografija_${new Date().toISOString().slice(0, 10)}.xlsx`);
  showToast('📊 Izvezeno');
}

/* ═════════════════════════════════════════════════════════════════════
   ORGANOGRAM — vizuelno stablo Department → SubDepartment → Position
   ═════════════════════════════════════════════════════════════════════ */

let orgExpanded = new Set(); /* keys: "dept-<id>", "sub-<id>", "pos-<id>" */

function _orgEmployeesByGroup(emps) {
  const byPos = new Map();
  const bySubNoPos = new Map();
  const byDeptNoSub = new Map();
  const ungrouped = [];
  for (const e of emps) {
    if (e.positionId) {
      if (!byPos.has(e.positionId)) byPos.set(e.positionId, []);
      byPos.get(e.positionId).push(e);
    } else if (e.subDepartmentId) {
      if (!bySubNoPos.has(e.subDepartmentId)) bySubNoPos.set(e.subDepartmentId, []);
      bySubNoPos.get(e.subDepartmentId).push(e);
    } else if (e.departmentId) {
      if (!byDeptNoSub.has(e.departmentId)) byDeptNoSub.set(e.departmentId, []);
      byDeptNoSub.get(e.departmentId).push(e);
    } else {
      ungrouped.push(e);
    }
  }
  return { byPos, bySubNoPos, byDeptNoSub, ungrouped };
}

function _orgEmployeeRowHtml(e) {
  return `<div class="org-emp-row">
    <span class="org-emp-name">${escHtml(employeeDisplayName(e) || '—')}</span>
    ${e.position ? `<span class="emp-sub">${escHtml(e.position)}</span>` : ''}
    ${!e.isActive ? '<span class="kadr-pill muted">neaktivan</span>' : ''}
  </div>`;
}

function _renderOrgChart() {
  if (!panelRoot) return;
  const host = panelRoot.querySelector('#repOrgTree');
  const empty = panelRoot.querySelector('#repOrgEmpty');
  if (!host) return;

  const status = panelRoot.querySelector('#repOrgStatus')?.value || 'active';
  const q = (panelRoot.querySelector('#repOrgSearch')?.value || '').trim().toLowerCase();
  const allEmps = kadrovskaState.employees.filter(e => status === 'all' || e.isActive);
  const filteredEmps = q
    ? allEmps.filter(e => {
        const hay = [employeeDisplayName(e), e.position, e.department].join(' ').toLowerCase();
        return hay.includes(q);
      })
    : allEmps;

  const { byPos, bySubNoPos, byDeptNoSub, ungrouped } = _orgEmployeesByGroup(filteredEmps);
  const depts = orgStructureState.departments.slice()
    .sort((a, b) => (a.sort_order || 0) - (b.sort_order || 0) || a.name.localeCompare(b.name, 'sr'));
  const subDeptsByDept = new Map();
  for (const sd of orgStructureState.subDepartments) {
    if (!subDeptsByDept.has(sd.department_id)) subDeptsByDept.set(sd.department_id, []);
    subDeptsByDept.get(sd.department_id).push(sd);
  }
  const positionsBySub = new Map();
  const positionsByDeptNoSub = new Map();
  for (const p of orgStructureState.jobPositions) {
    if (p.sub_department_id) {
      if (!positionsBySub.has(p.sub_department_id)) positionsBySub.set(p.sub_department_id, []);
      positionsBySub.get(p.sub_department_id).push(p);
    } else if (p.department_id) {
      if (!positionsByDeptNoSub.has(p.department_id)) positionsByDeptNoSub.set(p.department_id, []);
      positionsByDeptNoSub.get(p.department_id).push(p);
    }
  }

  if (!depts.length && !ungrouped.length) {
    host.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  let totalEmp = 0;
  let totalPositions = 0;
  const sortByOrder = (a, b) => (a.sort_order || 0) - (b.sort_order || 0) || a.name.localeCompare(b.name, 'sr');

  const renderPosition = (pos) => {
    const empsHere = byPos.get(pos.id) || [];
    if (q && !empsHere.length) return ''; /* sa pretragom skrivamo prazne */
    totalPositions += 1;
    totalEmp += empsHere.length;
    const key = 'pos-' + pos.id;
    const open = q ? true : orgExpanded.has(key);
    return `<div class="org-node org-pos">
      <div class="org-node-head" data-key="${escHtml(key)}">
        <span class="org-toggle">${empsHere.length ? (open ? '▾' : '▸') : '·'}</span>
        <span class="org-icon">👤</span>
        <span class="org-name">${escHtml(pos.name)}</span>
        <span class="org-count">${empsHere.length}</span>
      </div>
      ${open ? `<div class="org-children">${empsHere.map(_orgEmployeeRowHtml).join('') || '<div class="emp-sub" style="padding:4px 0">Nema zaposlenih</div>'}</div>` : ''}
    </div>`;
  };

  const renderSubDept = (sd) => {
    const subPositions = (positionsBySub.get(sd.id) || []).slice().sort(sortByOrder);
    const subEmps = bySubNoPos.get(sd.id) || [];
    const positionHtml = subPositions.map(renderPosition).join('');
    const total = (subPositions.reduce((s, p) => s + (byPos.get(p.id) || []).length, 0)) + subEmps.length;
    if (q && !total) return '';
    const key = 'sub-' + sd.id;
    const open = q ? true : orgExpanded.has(key);
    totalEmp += subEmps.length;
    return `<div class="org-node org-sub">
      <div class="org-node-head" data-key="${escHtml(key)}">
        <span class="org-toggle">${(subPositions.length || subEmps.length) ? (open ? '▾' : '▸') : '·'}</span>
        <span class="org-icon">📂</span>
        <span class="org-name">${escHtml(sd.name)}</span>
        <span class="org-count">${total}</span>
      </div>
      ${open ? `<div class="org-children">
        ${positionHtml}
        ${subEmps.length ? `<div class="org-children-direct">${subEmps.map(_orgEmployeeRowHtml).join('')}</div>` : ''}
      </div>` : ''}
    </div>`;
  };

  const renderDept = (d) => {
    const subs = (subDeptsByDept.get(d.id) || []).slice().sort(sortByOrder);
    const noSubPositions = (positionsByDeptNoSub.get(d.id) || []).slice().sort(sortByOrder);
    const noSubEmps = byDeptNoSub.get(d.id) || [];
    const subHtml = subs.map(renderSubDept).join('');
    const posHtml = noSubPositions.map(renderPosition).join('');
    const total =
      subs.reduce((s, sd) => {
        const sp = (positionsBySub.get(sd.id) || []).reduce((ss, p) => ss + (byPos.get(p.id) || []).length, 0);
        return s + sp + (bySubNoPos.get(sd.id) || []).length;
      }, 0)
      + noSubPositions.reduce((s, p) => s + (byPos.get(p.id) || []).length, 0)
      + noSubEmps.length;
    if (q && !total) return '';
    const key = 'dept-' + d.id;
    const open = q ? true : orgExpanded.has(key);
    totalEmp += noSubEmps.length;
    return `<div class="org-node org-dept">
      <div class="org-node-head" data-key="${escHtml(key)}">
        <span class="org-toggle">${open ? '▾' : '▸'}</span>
        <span class="org-icon">🏢</span>
        <span class="org-name">${escHtml(d.name)}</span>
        <span class="org-count">${total}</span>
      </div>
      ${open ? `<div class="org-children">
        ${subHtml}
        ${posHtml}
        ${noSubEmps.length ? `<div class="org-children-direct">${noSubEmps.map(_orgEmployeeRowHtml).join('')}</div>` : ''}
      </div>` : ''}
    </div>`;
  };

  let html = depts.map(renderDept).join('');
  if (ungrouped.length) {
    const key = 'dept-none';
    const open = q ? true : orgExpanded.has(key);
    html += `<div class="org-node org-dept">
      <div class="org-node-head" data-key="${escHtml(key)}">
        <span class="org-toggle">${open ? '▾' : '▸'}</span>
        <span class="org-icon">❓</span>
        <span class="org-name">Bez odeljenja</span>
        <span class="org-count">${ungrouped.length}</span>
      </div>
      ${open ? `<div class="org-children"><div class="org-children-direct">${ungrouped.map(_orgEmployeeRowHtml).join('')}</div></div>` : ''}
    </div>`;
    totalEmp += ungrouped.length;
  }
  host.innerHTML = html;

  /* Total broj koji se renderuje smo akumulirali u petlji — nije pouzdano
     jer mora ići pre _renderOrgChart() poziva. Računamo iz allEmps. */
  const totalActive = allEmps.length;
  renderSummaryChips('repOrgSummary', [
    { label: 'Odeljenja', value: depts.length, tone: 'accent' },
    { label: 'Pododeljenja', value: orgStructureState.subDepartments.length, tone: 'muted' },
    { label: 'Pozicija', value: orgStructureState.jobPositions.length, tone: 'muted' },
    { label: 'Zaposlenih', value: totalActive, tone: 'accent' },
    { label: 'Bez odeljenja', value: ungrouped.length, tone: ungrouped.length > 0 ? 'warn' : 'muted' },
  ]);

  /* Klik na čvor zaglavlja = toggle. */
  host.querySelectorAll('.org-node-head').forEach(el => {
    el.addEventListener('click', () => {
      const k = el.dataset.key;
      if (orgExpanded.has(k)) orgExpanded.delete(k);
      else orgExpanded.add(k);
      _renderOrgChart();
    });
  });
}

function _orgExpandAll() {
  orgExpanded = new Set();
  for (const d of orgStructureState.departments) orgExpanded.add('dept-' + d.id);
  for (const s of orgStructureState.subDepartments) orgExpanded.add('sub-' + s.id);
  for (const p of orgStructureState.jobPositions) orgExpanded.add('pos-' + p.id);
  orgExpanded.add('dept-none');
  _renderOrgChart();
}
function _orgCollapseAll() {
  orgExpanded = new Set();
  _renderOrgChart();
}

/* ═════════════════════════════════════════════════════════════════════
   SALDO GO (po godini)
   ═════════════════════════════════════════════════════════════════════ */

async function _renderVacReport() {
  if (!panelRoot) return;
  const tbody = panelRoot.querySelector('#repVacTbody');
  const empty = panelRoot.querySelector('#repVacEmpty');
  const countEl = panelRoot.querySelector('#repVacCount');
  if (!tbody) return;

  const year = Number(panelRoot.querySelector('#repVacYear').value || new Date().getFullYear());
  const goFromGrid = await countGoDaysByEmployeeForYear(year);
  const status = panelRoot.querySelector('#repVacStatus').value || 'active';
  const balByEmp = new Map();
  for (const b of kadrVacationState.balances) if (b.year === year) balByEmp.set(b.employeeId, b);
  const entByEmp = new Map();
  for (const e of kadrVacationState.entitlements) if (e.year === year) entByEmp.set(e.employeeId, e);

  const emps = kadrovskaState.employees.filter(e => status === 'all' || e.isActive);
  const rows = emps.map(emp => {
    const ent = entByEmp.get(emp.id);
    const bal = balByEmp.get(emp.id);
    const daysTotal = ent?.daysTotal ?? 20;
    const daysCarried = ent?.daysCarriedOver ?? 0;
    let daysUsed = bal?.daysUsed ?? 0;
    if (!bal) {
      daysUsed = goFromGrid.get(emp.id) ?? 0;
    }
    return { emp, daysTotal, daysCarried, daysUsed, remaining: daysTotal + daysCarried - daysUsed };
  });

  if (countEl) countEl.textContent = `${rows.length} ${rows.length === 1 ? 'zaposleni' : 'zaposlenih'}`;

  const totalTot = rows.reduce((s, r) => s + r.daysTotal + r.daysCarried, 0);
  const totalUsed = rows.reduce((s, r) => s + r.daysUsed, 0);
  const totalRem = rows.reduce((s, r) => s + r.remaining, 0);
  renderSummaryChips('repVacSummary', [
    { label: 'Godina', value: year, tone: 'accent' },
    { label: 'Ukupno dana', value: totalTot, tone: 'accent' },
    { label: 'Iskorišćeno', value: totalUsed, tone: 'warn' },
    { label: 'Preostalo', value: totalRem, tone: totalRem > 0 ? 'ok' : 'muted' },
  ]);

  if (!rows.length) {
    tbody.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  tbody.innerHTML = rows.sort((a, b) => compareEmployeesByLastFirst(a.emp, b.emp)).map(r => {
    const remCls = r.remaining < 0 ? 'warn' : (r.remaining < 3 ? 'accent' : 'ok');
    return `<tr>
      <td><strong>${escHtml(employeeDisplayName(r.emp) || '—')}</strong></td>
      <td class="col-hide-sm">${escHtml(r.emp.department || '—')}</td>
      <td>${r.daysTotal}</td>
      <td>${r.daysCarried}</td>
      <td><strong>${r.daysUsed}</strong></td>
      <td><span class="kadr-type-badge t-${remCls}" style="font-family:var(--mono);font-weight:700;">${r.remaining}</span></td>
    </tr>`;
  }).join('');
}

async function _exportVacXlsx() {
  let XLSX;
  try { XLSX = await loadXlsx(); } catch { showToast('⚠ XLSX nedostupan'); return; }
  const year = Number(panelRoot.querySelector('#repVacYear').value || new Date().getFullYear());
  const status = panelRoot.querySelector('#repVacStatus').value || 'active';
  const goFromGrid = await countGoDaysByEmployeeForYear(year);
  const balByEmp = new Map();
  for (const b of kadrVacationState.balances) if (b.year === year) balByEmp.set(b.employeeId, b);
  const entByEmp = new Map();
  for (const e of kadrVacationState.entitlements) if (e.year === year) entByEmp.set(e.employeeId, e);

  const aoa = [['Zaposleni', 'Odeljenje', 'Dana pravo', 'Preneto', 'Iskorišćeno', 'Preostalo']];
  kadrovskaState.employees
    .filter(e => status === 'all' || e.isActive)
    .forEach(emp => {
      const ent = entByEmp.get(emp.id);
      const bal = balByEmp.get(emp.id);
      const dt = ent?.daysTotal ?? 20;
      const dc = ent?.daysCarriedOver ?? 0;
      const du = bal?.daysUsed ?? (goFromGrid.get(emp.id) ?? 0);
      aoa.push([employeeDisplayName(emp) || '', emp.department || '', dt, dc, du, dt + dc - du]);
    });
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  ws['!cols'] = [{ wch: 30 }, { wch: 18 }, { wch: 12 }, { wch: 10 }, { wch: 14 }, { wch: 12 }];
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, `Saldo GO ${year}`);
  XLSX.writeFile(wb, `Saldo_GO_${year}.xlsx`);
  showToast('📊 Izvezeno');
}

/* ═════════════════════════════════════════════════════════════════════
   PREKOVREMENI RAD
   ═════════════════════════════════════════════════════════════════════ */

async function _renderOvertimeReport() {
  if (!panelRoot) return;
  const tbody = panelRoot.querySelector('#repOtTbody');
  const tfoot = panelRoot.querySelector('#repOtTfoot');
  const empty = panelRoot.querySelector('#repOtEmpty');
  const countEl = panelRoot.querySelector('#repOtCount');
  if (!tbody) return;

  const { from, to } = _readPeriodFor('repOt');
  let map;
  try {
    map = await overtimeByEmployeeForPeriod(from, to);
  } catch (err) {
    console.warn('[reports] overtime', err);
    map = new Map();
  }

  const empById = new Map(kadrovskaState.employees.map(e => [e.id, e]));
  const rows = Array.from(map.entries()).map(([id, agg]) => {
    const emp = empById.get(id);
    return {
      id,
      emp,
      name: emp ? employeeDisplayName(emp) : '(obrisan)',
      dept: emp?.departmentName || emp?.department || '',
      totalOvertime: agg.totalOvertime,
      twoMachineHours: agg.twoMachineHours,
      days: agg.days,
      lastDate: agg.lastDate,
    };
  }).sort((a, b) => b.totalOvertime - a.totalOvertime
    || String(a.name).localeCompare(String(b.name), 'sr'));

  const sumOt = rows.reduce((s, r) => s + r.totalOvertime, 0);
  const sumTm = rows.reduce((s, r) => s + r.twoMachineHours, 0);
  const sumDays = rows.reduce((s, r) => s + r.days, 0);

  if (countEl) countEl.textContent = `${rows.length} ${rows.length === 1 ? 'zaposleni' : 'zaposlenih'}`;

  renderSummaryChips('repOtSummary', [
    { label: 'Period', value: _periodLabel(from, to), tone: 'muted' },
    { label: 'Zaposlenih', value: rows.length, tone: rows.length ? 'accent' : 'muted' },
    { label: 'Σ prekovr. (h)', value: sumOt, tone: sumOt > 0 ? 'warn' : 'muted' },
    { label: 'Σ dani sa prekovr.', value: sumDays, tone: 'muted' },
    { label: 'Σ 2 mašine (h)', value: sumTm, tone: sumTm > 0 ? 'accent' : 'muted' },
  ]);

  if (!rows.length) {
    tbody.innerHTML = '';
    if (tfoot) tfoot.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  tbody.innerHTML = rows.map(r => `<tr>
    <td><strong>${escHtml(r.name)}</strong></td>
    <td class="col-hide-sm">${escHtml(r.dept || '—')}</td>
    <td><strong>${r.totalOvertime}</strong></td>
    <td class="col-hide-sm">${r.days}</td>
    <td class="col-hide-sm">${r.twoMachineHours || 0}</td>
    <td class="col-hide-sm">${r.lastDate ? _fmtSrDate(r.lastDate) : '—'}</td>
  </tr>`).join('');

  if (tfoot) {
    tfoot.innerHTML = `<tr class="row-totals">
      <td colspan="2" style="text-align:right;font-weight:700">UKUPNO</td>
      <td><strong>${sumOt}</strong></td>
      <td>${sumDays}</td>
      <td>${sumTm}</td>
      <td></td>
    </tr>`;
  }
}

async function _exportOvertimeXlsx() {
  let XLSX;
  try { XLSX = await loadXlsx(); } catch { showToast('⚠ XLSX nedostupan'); return; }
  const { from, to } = _readPeriodFor('repOt');
  const map = await overtimeByEmployeeForPeriod(from, to);
  if (!map.size) { showToast('Nema podataka za izvoz'); return; }
  const empById = new Map(kadrovskaState.employees.map(e => [e.id, e]));
  const aoa = [
    ['IZVEŠTAJ — PREKOVREMENI RAD'],
    ['Period', _periodLabel(from, to)],
    [],
    ['Zaposleni', 'Odeljenje', 'Prekovr. (h)', 'Dani sa prekovr.', '2 mašine (h)', 'Poslednji datum'],
  ];
  Array.from(map.entries())
    .map(([id, a]) => ({ id, emp: empById.get(id), agg: a }))
    .sort((a, b) => b.agg.totalOvertime - a.agg.totalOvertime)
    .forEach(({ emp, agg }) => {
      aoa.push([
        emp ? (employeeDisplayName(emp) || '') : '(obrisan)',
        emp?.department || '',
        agg.totalOvertime,
        agg.days,
        agg.twoMachineHours || 0,
        agg.lastDate || '',
      ]);
    });
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  ws['!cols'] = [{ wch: 30 }, { wch: 20 }, { wch: 14 }, { wch: 16 }, { wch: 14 }, { wch: 14 }];
  ws['!merges'] = [{ s: { r: 0, c: 0 }, e: { r: 0, c: 5 } }];
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Prekovremeni');
  const tag = (from || '') + (to ? '_' + to : '') || 'all';
  XLSX.writeFile(wb, `Prekovremeni_${tag}.xlsx`);
  showToast('📊 Izvezeno');
}

/* ═════════════════════════════════════════════════════════════════════
   TERENSKI RAD (domaci / inostrani)
   ═════════════════════════════════════════════════════════════════════ */

async function _renderFieldReport() {
  if (!panelRoot) return;
  const tbody = panelRoot.querySelector('#repFwTbody');
  const tfoot = panelRoot.querySelector('#repFwTfoot');
  const empty = panelRoot.querySelector('#repFwEmpty');
  const countEl = panelRoot.querySelector('#repFwCount');
  if (!tbody) return;

  const { from, to } = _readPeriodFor('repFw');
  const typeFilter = panelRoot.querySelector('#repFwType')?.value || '';
  let map;
  try {
    map = await fieldWorkByEmployeeForPeriod(from, to);
  } catch (err) {
    console.warn('[reports] field', err);
    map = new Map();
  }

  const empById = new Map(kadrovskaState.employees.map(e => [e.id, e]));
  let rows = Array.from(map.entries()).map(([id, agg]) => {
    const emp = empById.get(id);
    return {
      id,
      emp,
      name: emp ? employeeDisplayName(emp) : '(obrisan)',
      dept: emp?.departmentName || emp?.department || '',
      ...agg,
      totalDays: agg.domesticDays + agg.foreignDays,
    };
  });
  if (typeFilter === 'domestic') rows = rows.filter(r => r.domesticDays > 0);
  else if (typeFilter === 'foreign') rows = rows.filter(r => r.foreignDays > 0);
  rows.sort((a, b) => b.totalDays - a.totalDays
    || String(a.name).localeCompare(String(b.name), 'sr'));

  const sumDomD = rows.reduce((s, r) => s + r.domesticDays, 0);
  const sumDomH = rows.reduce((s, r) => s + r.domesticHours, 0);
  const sumForD = rows.reduce((s, r) => s + r.foreignDays, 0);
  const sumForH = rows.reduce((s, r) => s + r.foreignHours, 0);

  if (countEl) countEl.textContent = `${rows.length} ${rows.length === 1 ? 'zaposleni' : 'zaposlenih'}`;

  renderSummaryChips('repFwSummary', [
    { label: 'Period', value: _periodLabel(from, to), tone: 'muted' },
    { label: 'Zaposlenih', value: rows.length, tone: rows.length ? 'accent' : 'muted' },
    { label: 'Σ domaći (dani)', value: sumDomD, tone: sumDomD > 0 ? 'accent' : 'muted' },
    { label: 'Σ inostrani (dani)', value: sumForD, tone: sumForD > 0 ? 'accent' : 'muted' },
    { label: 'Σ ukupno (dani)', value: sumDomD + sumForD, tone: 'muted' },
  ]);

  if (!rows.length) {
    tbody.innerHTML = '';
    if (tfoot) tfoot.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  tbody.innerHTML = rows.map(r => `<tr>
    <td><strong>${escHtml(r.name)}</strong></td>
    <td class="col-hide-sm">${escHtml(r.dept || '—')}</td>
    <td>${r.domesticDays}</td>
    <td class="col-hide-sm">${r.domesticHours}</td>
    <td>${r.foreignDays}</td>
    <td class="col-hide-sm">${r.foreignHours}</td>
    <td class="col-hide-sm"><strong>${r.totalDays}</strong></td>
    <td class="col-hide-sm">${r.lastDate ? _fmtSrDate(r.lastDate) : '—'}</td>
  </tr>`).join('');

  if (tfoot) {
    tfoot.innerHTML = `<tr class="row-totals">
      <td colspan="2" style="text-align:right;font-weight:700">UKUPNO</td>
      <td><strong>${sumDomD}</strong></td>
      <td>${sumDomH}</td>
      <td><strong>${sumForD}</strong></td>
      <td>${sumForH}</td>
      <td><strong>${sumDomD + sumForD}</strong></td>
      <td></td>
    </tr>`;
  }
}

async function _exportFieldXlsx() {
  let XLSX;
  try { XLSX = await loadXlsx(); } catch { showToast('⚠ XLSX nedostupan'); return; }
  const { from, to } = _readPeriodFor('repFw');
  const map = await fieldWorkByEmployeeForPeriod(from, to);
  if (!map.size) { showToast('Nema podataka za izvoz'); return; }
  const empById = new Map(kadrovskaState.employees.map(e => [e.id, e]));
  const aoa = [
    ['IZVEŠTAJ — TERENSKI RAD'],
    ['Period', _periodLabel(from, to)],
    [],
    ['Zaposleni', 'Odeljenje', 'Domaći (dani)', 'Domaći (h)', 'Inostrani (dani)', 'Inostrani (h)', 'Σ dana', 'Poslednji datum'],
  ];
  Array.from(map.entries())
    .map(([id, a]) => ({ id, emp: empById.get(id), agg: a }))
    .sort((a, b) => (b.agg.domesticDays + b.agg.foreignDays) - (a.agg.domesticDays + a.agg.foreignDays))
    .forEach(({ emp, agg }) => {
      aoa.push([
        emp ? (employeeDisplayName(emp) || '') : '(obrisan)',
        emp?.department || '',
        agg.domesticDays,
        agg.domesticHours,
        agg.foreignDays,
        agg.foreignHours,
        agg.domesticDays + agg.foreignDays,
        agg.lastDate || '',
      ]);
    });
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  ws['!cols'] = [{ wch: 30 }, { wch: 20 }, { wch: 14 }, { wch: 12 }, { wch: 16 }, { wch: 14 }, { wch: 10 }, { wch: 14 }];
  ws['!merges'] = [{ s: { r: 0, c: 0 }, e: { r: 0, c: 7 } }];
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Terenski rad');
  const tag = (from || '') + (to ? '_' + to : '') || 'all';
  XLSX.writeFile(wb, `Terenski_${tag}.xlsx`);
  showToast('📊 Izvezeno');
}

/* ═════════════════════════════════════════════════════════════════════
   SERTIFIKATI / LICENCE (samo HR/admin)
   ═════════════════════════════════════════════════════════════════════ */

let certCache = [];

const CERT_STATUS_LABELS = {
  expired:       { label: 'Istekao',     tone: 'warn' },
  expiring_soon: { label: 'Ističe <30d', tone: 'accent' },
  lifetime:      { label: 'Trajno',      tone: 'muted' },
  ok:            { label: 'Važi',        tone: 'ok' },
};

async function _renderCertsReport() {
  if (!panelRoot || !canViewEmployeePii()) return;
  const tbody = panelRoot.querySelector('#repCertTbody');
  const empty = panelRoot.querySelector('#repCertEmpty');
  const countEl = panelRoot.querySelector('#repCertCount');
  if (!tbody) return;

  const typeF = panelRoot.querySelector('#repCertType')?.value || '';
  const statF = panelRoot.querySelector('#repCertStatus')?.value || 'problem';
  if (!certCache.length) {
    try { certCache = (await loadAllCertificateStatus()) || []; }
    catch (err) { console.warn('[reports] certs', err); certCache = []; }
  }

  let rows = certCache.slice();
  if (typeF) rows = rows.filter(r => r.certType === typeF);
  if (statF === 'expired')         rows = rows.filter(r => r.status === 'expired');
  else if (statF === 'expiring_soon') rows = rows.filter(r => r.status === 'expiring_soon');
  else if (statF === 'lifetime')   rows = rows.filter(r => r.status === 'lifetime');
  else if (statF === 'problem')    rows = rows.filter(r => r.status === 'expired' || r.status === 'expiring_soon');

  /* Sort: najgori prvi */
  const ord = { expired: 0, expiring_soon: 1, ok: 2, lifetime: 3 };
  rows.sort((a, b) => {
    const oa = ord[a.status] ?? 9; const ob = ord[b.status] ?? 9;
    if (oa !== ob) return oa - ob;
    return (a.daysToExpiry ?? 9999) - (b.daysToExpiry ?? 9999);
  });

  const cExp  = certCache.filter(r => r.status === 'expired').length;
  const cSoon = certCache.filter(r => r.status === 'expiring_soon').length;
  const cLife = certCache.filter(r => r.status === 'lifetime').length;
  const cOk   = certCache.filter(r => r.status === 'ok').length;
  const sumCost = certCache.reduce((s, r) => s + (Number(r.costRsd) || 0), 0);

  renderSummaryChips('repCertSummary', [
    { label: 'Ukupno sertifikata', value: certCache.length, tone: 'accent' },
    { label: 'Istekli', value: cExp, tone: cExp > 0 ? 'warn' : 'muted' },
    { label: 'Ističu <30d', value: cSoon, tone: cSoon > 0 ? 'accent' : 'muted' },
    { label: 'Trajni', value: cLife, tone: 'muted' },
    { label: 'OK', value: cOk, tone: 'ok' },
    { label: 'Σ trošak', value: sumCost.toLocaleString('sr-RS') + ' RSD', tone: 'muted' },
  ]);

  if (countEl) countEl.textContent = `${rows.length} ${rows.length === 1 ? 'sertifikat' : 'sertifikata'}`;

  if (!rows.length) {
    tbody.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  tbody.innerHTML = rows.map(r => {
    const cls = CERT_STATUS_LABELS[r.status] || { label: r.status, tone: 'muted' };
    const days = r.daysToExpiry != null
      ? (r.daysToExpiry < 0 ? ` (${-r.daysToExpiry}d kasni)` : ` (za ${r.daysToExpiry}d)`)
      : '';
    return `<tr data-emp-id="${escHtml(r.employeeId)}">
      <td><strong>${escHtml(r.employeeName || '—')}</strong></td>
      <td>${escHtml(CERT_TYPE_LABELS[r.certType] || r.certType)}</td>
      <td>
        <strong>${escHtml(r.certName || '—')}</strong>
        ${r.documentNo ? `<div class="emp-sub">${escHtml(r.documentNo)}</div>` : ''}
      </td>
      <td>${r.issuedOn ? _fmtSrDate(r.issuedOn) : '—'}</td>
      <td>${r.expiresOn ? _fmtSrDate(r.expiresOn) + days : '<em class="emp-sub">—</em>'}</td>
      <td><span class="kadr-pill ${cls.tone}">${escHtml(cls.label)}</span></td>
      <td class="col-actions">
        <button class="btn-row-act" data-act="open">📜 Otvori</button>
      </td>
    </tr>`;
  }).join('');

  tbody.querySelectorAll('button[data-act="open"]').forEach(b => {
    b.addEventListener('click', () => {
      const empId = b.closest('tr').dataset.empId;
      openCertificatesModal(empId, {
        onChange: async () => {
          certCache = [];
          await _renderCertsReport();
        },
      });
    });
  });
}

async function _exportCertsXlsx() {
  let XLSX;
  try { XLSX = await loadXlsx(); } catch { showToast('⚠ XLSX nedostupan'); return; }
  if (!certCache.length) {
    try { certCache = (await loadAllCertificateStatus()) || []; } catch {}
  }
  if (!certCache.length) { showToast('Nema podataka za izvoz'); return; }
  const aoa = [
    ['IZVEŠTAJ — SERTIFIKATI / LICENCE'],
    ['Datum izvoza', _isoToday()],
    [],
    ['Zaposleni', 'Pozicija', 'Odeljenje', 'Tip', 'Naziv', 'Br. dokumenta', 'Izdavalac', 'Izdat', 'Ističe', 'Dana do isteka', 'Trošak (RSD)', 'Status'],
  ];
  certCache.forEach(r => {
    const cls = CERT_STATUS_LABELS[r.status] || { label: r.status };
    aoa.push([
      r.employeeName || '',
      r.employeePosition || '',
      r.employeeDepartment || '',
      CERT_TYPE_LABELS[r.certType] || r.certType,
      r.certName || '',
      r.documentNo || '',
      r.issuer || '',
      r.issuedOn || '',
      r.expiresOn || '',
      r.daysToExpiry != null ? r.daysToExpiry : '',
      r.costRsd || 0,
      cls.label,
    ]);
  });
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  ws['!cols'] = [
    { wch: 30 }, { wch: 22 }, { wch: 18 }, { wch: 18 }, { wch: 28 }, { wch: 16 },
    { wch: 22 }, { wch: 12 }, { wch: 12 }, { wch: 14 }, { wch: 12 }, { wch: 14 },
  ];
  ws['!merges'] = [{ s: { r: 0, c: 0 }, e: { r: 0, c: 11 } }];
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Sertifikati');
  XLSX.writeFile(wb, `Sertifikati_${_isoToday()}.xlsx`);
  showToast('📊 Izvezeno');
}

/* ═════════════════════════════════════════════════════════════════════
   LEKARSKI PREGLEDI (samo HR/admin) — overdue/expiring overview
   ═════════════════════════════════════════════════════════════════════ */

let medExamCache = [];

const MED_STATUS_LABELS = {
  expired:       { label: 'Istekao',        tone: 'warn' },
  expiring_soon: { label: 'Ističe <30d',    tone: 'accent' },
  never:         { label: 'Nikad',          tone: 'warn' },
  unknown_expiry:{ label: 'Bez datuma isteka', tone: 'muted' },
  ok:            { label: 'Važi',           tone: 'ok' },
};

async function _renderMedicalReport() {
  if (!panelRoot || !canViewEmployeePii()) return;
  const tbody = panelRoot.querySelector('#repMedTbody');
  const empty = panelRoot.querySelector('#repMedEmpty');
  const countEl = panelRoot.querySelector('#repMedCount');
  if (!tbody) return;

  const filter = panelRoot.querySelector('#repMedStatus')?.value || 'problem';
  if (!medExamCache.length) {
    try { medExamCache = (await loadAllMedExamStatus()) || []; }
    catch (err) { console.warn('[reports] medExam', err); medExamCache = []; }
  }

  let rows = medExamCache.slice();
  if (filter === 'expired')         rows = rows.filter(r => r.status === 'expired');
  else if (filter === 'expiring_soon') rows = rows.filter(r => r.status === 'expiring_soon');
  else if (filter === 'never')      rows = rows.filter(r => r.status === 'never' || r.status === 'unknown_expiry');
  else if (filter === 'problem')    rows = rows.filter(r => r.status === 'expired' || r.status === 'expiring_soon' || r.status === 'never');
  /* 'all' — sve */

  /* Sort: najgori prvi */
  const ord = { expired: 0, never: 1, expiring_soon: 2, unknown_expiry: 3, ok: 4 };
  rows.sort((a, b) => {
    const oa = ord[a.status] ?? 9;
    const ob = ord[b.status] ?? 9;
    if (oa !== ob) return oa - ob;
    return (a.daysToExpiry ?? 9999) - (b.daysToExpiry ?? 9999);
  });

  const cExp = medExamCache.filter(r => r.status === 'expired').length;
  const cSoon = medExamCache.filter(r => r.status === 'expiring_soon').length;
  const cNever = medExamCache.filter(r => r.status === 'never' || r.status === 'unknown_expiry').length;
  const cOk = medExamCache.filter(r => r.status === 'ok').length;

  renderSummaryChips('repMedSummary', [
    { label: 'Aktivnih zaposlenih', value: medExamCache.length, tone: 'accent' },
    { label: 'Istekli', value: cExp, tone: cExp > 0 ? 'warn' : 'muted' },
    { label: 'Ističu <30d', value: cSoon, tone: cSoon > 0 ? 'accent' : 'muted' },
    { label: 'Bez podataka', value: cNever, tone: cNever > 0 ? 'warn' : 'muted' },
    { label: 'OK', value: cOk, tone: 'ok' },
  ]);

  if (countEl) countEl.textContent = `${rows.length} ${rows.length === 1 ? 'zaposleni' : 'zaposlenih'}`;

  if (!rows.length) {
    tbody.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  tbody.innerHTML = rows.map(r => {
    const cls = MED_STATUS_LABELS[r.status] || { label: r.status, tone: 'muted' };
    const lastTxt = r.medicalExamDate ? _fmtSrDate(r.medicalExamDate) : '<em class="emp-sub">—</em>';
    const validTxt = r.medicalExamExpires ? _fmtSrDate(r.medicalExamExpires) : '<em class="emp-sub">—</em>';
    const days = r.daysToExpiry != null
      ? (r.daysToExpiry < 0 ? ` (${-r.daysToExpiry}d kasni)` : ` (za ${r.daysToExpiry}d)`)
      : '';
    return `<tr data-emp-id="${escHtml(r.employeeId)}">
      <td><strong>${escHtml(r.employeeName || '—')}</strong>
        <div class="emp-sub col-hide-sm">${escHtml(r.employeePosition || '')}</div></td>
      <td class="col-hide-sm">${escHtml(r.employeeDepartment || '—')}</td>
      <td>${lastTxt}</td>
      <td>${validTxt}${days}</td>
      <td><span class="kadr-pill ${cls.tone}">${escHtml(cls.label)}</span></td>
      <td class="col-actions">
        <button class="btn-row-act" data-act="open">🩺 Istorija</button>
      </td>
    </tr>`;
  }).join('');

  tbody.querySelectorAll('button[data-act="open"]').forEach(b => {
    b.addEventListener('click', () => {
      const empId = b.closest('tr').dataset.empId;
      openMedicalExamsModal(empId, {
        onChange: async () => {
          medExamCache = [];
          await _renderMedicalReport();
        },
      });
    });
  });
}

async function _exportMedicalXlsx() {
  let XLSX;
  try { XLSX = await loadXlsx(); } catch { showToast('⚠ XLSX nedostupan'); return; }
  if (!medExamCache.length) {
    try { medExamCache = (await loadAllMedExamStatus()) || []; } catch {}
  }
  if (!medExamCache.length) { showToast('Nema podataka za izvoz'); return; }
  const aoa = [
    ['IZVEŠTAJ — LEKARSKI PREGLEDI'],
    ['Datum izvoza', _isoToday()],
    [],
    ['Zaposleni', 'Pozicija', 'Odeljenje', 'Poslednji pregled', 'Važi do', 'Dana do isteka', 'Status'],
  ];
  medExamCache.forEach(r => {
    const cls = MED_STATUS_LABELS[r.status] || { label: r.status };
    aoa.push([
      r.employeeName || '',
      r.employeePosition || '',
      r.employeeDepartment || '',
      r.medicalExamDate || '',
      r.medicalExamExpires || '',
      r.daysToExpiry != null ? r.daysToExpiry : '',
      cls.label,
    ]);
  });
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  ws['!cols'] = [{ wch: 30 }, { wch: 22 }, { wch: 18 }, { wch: 16 }, { wch: 14 }, { wch: 14 }, { wch: 16 }];
  ws['!merges'] = [{ s: { r: 0, c: 0 }, e: { r: 0, c: 6 } }];
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Lekarski pregledi');
  XLSX.writeFile(wb, `Lekarski_pregledi_${_isoToday()}.xlsx`);
  showToast('📊 Izvezeno');
}

/* ═════════════════════════════════════════════════════════════════════
   DECA (samo admin)
   ═════════════════════════════════════════════════════════════════════ */

async function _loadAllChildren() {
  /* Učitaj decu za sve aktivne zaposlene (sequential + cache u state). */
  const emps = kadrovskaState.employees;
  const out = [];
  for (const emp of emps) {
    const arr = kadrChildrenState.byEmp.has(emp.id)
      ? kadrChildrenState.byEmp.get(emp.id)
      : await loadChildrenForEmployee(emp.id);
    if (arr) {
      kadrChildrenState.byEmp.set(emp.id, arr);
      for (const c of arr) out.push({ emp, c });
    }
  }
  return out;
}

async function _renderChildrenReport() {
  if (!panelRoot || !canViewEmployeePii()) return;
  const tbody = panelRoot.querySelector('#repChildrenTbody');
  const empty = panelRoot.querySelector('#repChildrenEmpty');
  const countEl = panelRoot.querySelector('#repChildrenCount');
  if (!tbody) return;

  const rows = await _loadAllChildren();

  if (countEl) countEl.textContent = `${rows.length} ${rows.length === 1 ? 'dete' : 'dece'}`;

  /* Distribucije: ispod 7 god (predškolski), 7–14 (osnovna), 15–18 (srednja), 19+. */
  let preschool = 0, primary = 0, secondary = 0, older = 0;
  rows.forEach(({ c }) => {
    const age = _ageYears(c.birthDate);
    if (age == null) return;
    if (age < 7) preschool++;
    else if (age <= 14) primary++;
    else if (age <= 18) secondary++;
    else older++;
  });
  renderSummaryChips('repChildrenSummary', [
    { label: 'Ukupno dece', value: rows.length, tone: 'accent' },
    { label: '< 7 god', value: preschool, tone: 'muted' },
    { label: '7–14', value: primary, tone: 'muted' },
    { label: '15–18', value: secondary, tone: 'muted' },
    { label: '19+', value: older, tone: 'muted' },
  ]);

  if (!rows.length) {
    tbody.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  rows.sort((a, b) => compareEmployeesByLastFirst(a.emp, b.emp)
    || String(a.c.birthDate || '').localeCompare(String(b.c.birthDate || '')));
  tbody.innerHTML = rows.map(({ emp, c }) => {
    const age = _ageYears(c.birthDate);
    return `<tr>
      <td><strong>${escHtml(employeeDisplayName(emp) || '—')}</strong></td>
      <td>${escHtml(c.firstName || '—')}</td>
      <td>${c.birthDate ? _fmtSrDate(c.birthDate) : '—'}</td>
      <td>${age ?? '—'}</td>
    </tr>`;
  }).join('');
}

async function _exportChildrenXlsx() {
  let XLSX;
  try { XLSX = await loadXlsx(); } catch { showToast('⚠ XLSX nedostupan'); return; }
  const rows = await _loadAllChildren();
  if (!rows.length) { showToast('Nema podataka za izvoz'); return; }
  const aoa = [['Zaposleni', 'Odeljenje', 'Ime deteta', 'Datum rođenja', 'Starost']];
  rows
    .sort((a, b) => compareEmployeesByLastFirst(a.emp, b.emp))
    .forEach(({ emp, c }) => {
      aoa.push([employeeDisplayName(emp) || '', emp.department || '', c.firstName || '', c.birthDate || '', _ageYears(c.birthDate) ?? '']);
    });
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  ws['!cols'] = [{ wch: 30 }, { wch: 18 }, { wch: 20 }, { wch: 14 }, { wch: 10 }];
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Deca zaposlenih');
  XLSX.writeFile(wb, `Deca_zaposlenih_${new Date().toISOString().slice(0, 10)}.xlsx`);
  showToast('📊 Izvezeno');
}

/* ─── EXCEL EXPORT ────────────────────────────────────────────────────── */

async function _exportToXlsx() {
  let XLSX;
  try {
    XLSX = await loadXlsx();
  } catch (err) {
    console.error('[reports] xlsx load failed', err);
    showToast('⚠ XLSX biblioteka nije dostupna');
    return;
  }
  const empFilter = panelRoot?.querySelector('#repSickEmpFilter')?.value || '';
  const deptFilter = panelRoot?.querySelector('#repSickDeptFilter')?.value || '';
  const { from: pFrom, to: pTo } = _readPeriod();
  const allSick = (pFrom && pTo)
    ? await bolovanjeListFromWorkHours(pFrom, pTo)
    : await bolovanjeListFromWorkHours('', '');
  const empById = new Map(kadrovskaState.employees.map(e => [e.id, e]));
  const today = _isoToday();

  const perEmp = new Map();
  const detail = [];
  allSick.forEach(a => {
    if (!a.employeeId) return;
    if (empFilter && a.employeeId !== empFilter) return;
    const emp = empById.get(a.employeeId);
    if (deptFilter) {
      if (!emp) return;
      const deptId = parseInt(deptFilter, 10);
      if (orgStructureState.departments.length && !isNaN(deptId)) {
        if (emp.departmentId !== deptId) return;
      } else {
        if (emp.department !== deptFilter) return;
      }
    }
    const days = _intersectingDays(a.dateFrom, a.dateTo, pFrom, pTo);
    if (days <= 0) return;
    const name = emp ? employeeDisplayName(emp) : '(obrisan)';
    const dept = emp?.department || '';
    detail.push([
      name, dept, a.dateFrom || '', a.dateTo || '',
      daysInclusive(a.dateFrom, a.dateTo),
      days,
      a.note || '',
    ]);
    if (!perEmp.has(a.employeeId)) {
      perEmp.set(a.employeeId, {
        emp, name, dept,
        count: 0, totalDays: 0, lastTo: '',
        currentlyActive: false, durations: [],
      });
    }
    const r = perEmp.get(a.employeeId);
    r.count++; r.totalDays += days;
    if (a.dateFrom && a.dateTo && a.dateFrom <= today && a.dateTo >= today) r.currentlyActive = true;
    if (a.dateTo && (!r.lastTo || a.dateTo > r.lastTo)) r.lastTo = a.dateTo;
    r.durations.push(daysInclusive(a.dateFrom, a.dateTo));
  });

  if (perEmp.size === 0) { showToast('⚠ Nema podataka za izvoz'); return; }

  /* Sheet 1: sažetak */
  const summaryAoa = [];
  summaryAoa.push(['IZVEŠTAJ O BOLOVANJIMA']);
  summaryAoa.push(['Period', _periodLabel(pFrom, pTo)]);
  summaryAoa.push(['Filter — zaposleni', empFilter ? (employeeDisplayName(empById.get(empFilter)) || empFilter) : 'Svi']);
  summaryAoa.push(['Filter — odeljenje', deptFilter || 'Sva']);
  summaryAoa.push([]);
  summaryAoa.push(['Zaposleni', 'Odeljenje', 'Broj evid.', 'Σ dana (u periodu)', 'Prosek (d) po evid.', 'Poslednje bolovanje', 'Trenutno?']);
  Array.from(perEmp.values())
    .sort((a, b) => b.totalDays - a.totalDays || a.name.localeCompare(b.name, 'sr'))
    .forEach(r => {
      const avg = r.durations.length
        ? Math.round((r.durations.reduce((a, b) => a + b, 0) / r.durations.length) * 10) / 10
        : 0;
      summaryAoa.push([r.name, r.dept || '', r.count, r.totalDays, avg, r.lastTo || '', r.currentlyActive ? 'DA' : 'ne']);
    });
  const wsSum = XLSX.utils.aoa_to_sheet(summaryAoa);
  wsSum['!cols'] = [{ wch: 30 }, { wch: 18 }, { wch: 11 }, { wch: 18 }, { wch: 16 }, { wch: 18 }, { wch: 11 }];
  wsSum['!merges'] = [{ s: { r: 0, c: 0 }, e: { r: 0, c: 6 } }];

  /* Sheet 2: detalji */
  const detailAoa = [
    ['Zaposleni', 'Odeljenje', 'Od', 'Do', 'Trajanje (d)', 'Dana u periodu', 'Napomena'],
    ...detail.sort((a, b) => String(a[0]).localeCompare(String(b[0]), 'sr')),
  ];
  const wsDet = XLSX.utils.aoa_to_sheet(detailAoa);
  wsDet['!cols'] = [{ wch: 30 }, { wch: 18 }, { wch: 12 }, { wch: 12 }, { wch: 12 }, { wch: 14 }, { wch: 40 }];

  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, wsSum, 'Bolovanja - sažetak');
  XLSX.utils.book_append_sheet(wb, wsDet, 'Bolovanja - detalji');
  const periodTag = (pFrom || '') + (pTo ? '_' + pTo : '') || 'all';
  const fname = 'Bolovanja_' + periodTag + '.xlsx';
  XLSX.writeFile(wb, fname);
  showToast('📊 Izvezeno: ' + fname);
}

/* ═════════════════════════════════════════════════════════════════════
   AUDIT LOG (samo admin)
   ═════════════════════════════════════════════════════════════════════ */

let auditCache = [];

function _fmtAuditTime(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d)) return iso;
  const pad = n => String(n).padStart(2, '0');
  return `${pad(d.getDate())}.${pad(d.getMonth() + 1)}.${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function _fmtAuditValue(v) {
  if (v == null || v === '') return '<em class="emp-sub">—</em>';
  if (typeof v === 'object') return escHtml(JSON.stringify(v));
  return escHtml(String(v));
}

function _renderAuditDiff(row) {
  if (row.action === 'INSERT') {
    const fields = row.afterData ? Object.keys(row.afterData).filter(k => k !== 'updated_at' && k !== 'created_at') : [];
    if (!fields.length) return '<em class="emp-sub">—</em>';
    const preview = fields.slice(0, 3).map(k => `${escHtml(k)}: ${_fmtAuditValue(row.afterData[k])}`).join(' · ');
    return `<span class="kadr-pill ok">+ kreiran</span> <span class="emp-sub">${preview}${fields.length > 3 ? ' …' : ''}</span>`;
  }
  if (row.action === 'DELETE') {
    return '<span class="kadr-pill warn">obrisan</span>';
  }
  const diff = diffAuditRow(row);
  const keys = Object.keys(diff);
  if (!keys.length) return '<em class="emp-sub">bez promena</em>';
  const list = keys.slice(0, 3).map(k =>
    `<div class="audit-diff-row"><strong>${escHtml(k)}</strong>: ${_fmtAuditValue(diff[k].before)} → ${_fmtAuditValue(diff[k].after)}</div>`
  ).join('');
  const more = keys.length > 3 ? `<div class="emp-sub">+ još ${keys.length - 3} promena</div>` : '';
  return list + more;
}

/* ═════════════════════════════════════════════════════════════════════
   RISK REPORT (C3.4) — predviđanje + ranjivost
   ═════════════════════════════════════════════════════════════════════ */

let _riskCache = []; // [{ emp, boDays, boCount, medExpDays, conExpDays, level, reasons }]

/** Vraća broj dana između dva YMD-a (uključuje oba kraja), 0 ako je nevalidno. */
function _daysBetweenSafe(fromYmd, toYmd) {
  if (!fromYmd || !toYmd) return 0;
  return daysInclusive(fromYmd, toYmd);
}

/** Broj dana koji se preklapa između [absFrom..absTo] i [pFrom..pTo]. */
function _overlapDays(absFrom, absTo, pFrom, pTo) {
  if (!absFrom || !absTo) return 0;
  const f = absFrom < pFrom ? pFrom : absFrom;
  const t = absTo > pTo ? pTo : absTo;
  if (f > t) return 0;
  return daysInclusive(f, t);
}

/** Broj dana do isteka iz YMD-a do danas; null ako nema datuma. */
function _daysUntilExpiry(ymd) {
  if (!ymd) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const d = new Date(ymd + 'T00:00:00');
  if (Number.isNaN(d.getTime())) return null;
  return Math.round((d - today) / 86400000);
}

function _riskExpiryBadge(days) {
  if (days == null) return { label: '—', cls: 'muted' };
  if (days < 0) return { label: `Istekao (${Math.abs(days)} d)`, cls: 'danger' };
  if (days === 0) return { label: 'Danas', cls: 'warn' };
  if (days <= 30) return { label: `za ${days} d`, cls: 'warn' };
  if (days <= 90) return { label: `za ${days} d`, cls: 'accent' };
  return { label: `za ${days} d`, cls: 'ok' };
}

/** Skor risk-a po pravilima (vidi notu ispod tabele u HTML-u). */
function _computeRiskLevel({ boDays, medExpDays, conExpDays }) {
  const reasons = [];
  let level = 'low';
  /* High triggers */
  if (boDays > 7) { reasons.push(`>7 dana bolovanja (${boDays} d)`); level = 'high'; }
  if (medExpDays != null && medExpDays < 0) { reasons.push('Lekarski istekao'); level = 'high'; }
  if (conExpDays != null && conExpDays < 0) { reasons.push('Ugovor istekao'); level = 'high'; }
  if (level === 'high') return { level, reasons };
  /* Medium triggers */
  if (boDays >= 4 && boDays <= 7) { reasons.push(`${boDays} dana bolovanja`); level = 'medium'; }
  if (medExpDays != null && medExpDays >= 0 && medExpDays <= 30) { reasons.push('Lekarski ističe ≤30 d'); level = 'medium'; }
  if (conExpDays != null && conExpDays >= 0 && conExpDays <= 30) { reasons.push('Ugovor ističe ≤30 d'); level = 'medium'; }
  if (level === 'medium') return { level, reasons };
  /* Else low — i dalje navedi šta je registrovano kao osnov */
  if (boDays > 0) reasons.push(`${boDays} dana bolovanja`);
  if (medExpDays != null) reasons.push('Lekarski OK');
  if (conExpDays != null) reasons.push('Ugovor OK');
  if (!reasons.length) reasons.push('Bez evidencija u periodu');
  return { level, reasons };
}

async function _renderRiskReport() {
  if (!panelRoot || !canViewEmployeePii()) return;
  const tbody = panelRoot.querySelector('#repRiskTbody');
  const empty = panelRoot.querySelector('#repRiskEmpty');
  const countEl = panelRoot.querySelector('#repRiskCount');
  const heatmapEl = panelRoot.querySelector('#repRiskHeatmap');
  if (!tbody) return;

  /* Učitaj zavisne podatke (cache se ako su već učitani) */
  try {
    await Promise.all([
      ensureAbsencesLoaded(),
      ensureContractsLoaded(),
    ]);
  } catch (e) {
    console.warn('[reports] risk load', e);
  }

  const statusF = panelRoot.querySelector('#repRiskStatus')?.value || 'active';
  const monthsBack = Number(panelRoot.querySelector('#repRiskMonths')?.value || 12);
  const levelF = panelRoot.querySelector('#repRiskLevel')?.value || 'all';

  /* Period za bolovanja */
  const today = new Date();
  const periodEnd = today.toISOString().slice(0, 10);
  const startDt = new Date(today);
  startDt.setMonth(startDt.getMonth() - monthsBack);
  const periodStart = startDt.toISOString().slice(0, 10);

  /* Lista zaposlenih */
  let emps = kadrovskaState.employees.slice();
  if (statusF === 'active') emps = emps.filter(e => e.isActive);
  emps.sort(compareEmployeesByLastFirst);

  /* Map<empId, Array<absence>> samo za bolovanja u periodu */
  const boByEmp = new Map();
  for (const a of (kadrAbsencesState.items || [])) {
    if (a.type !== 'bolovanje') continue;
    if (!a.dateFrom || !a.dateTo) continue;
    if (a.dateTo < periodStart || a.dateFrom > periodEnd) continue;
    if (!boByEmp.has(a.employeeId)) boByEmp.set(a.employeeId, []);
    boByEmp.get(a.employeeId).push(a);
  }

  /* Aktivni ugovor po zaposlenom — najnoviji aktivan red */
  const activeConByEmp = new Map();
  for (const c of (kadrContractsState.items || [])) {
    if (c.isActive === false) continue;
    const existing = activeConByEmp.get(c.employeeId);
    if (!existing || (c.dateFrom || '') > (existing.dateFrom || '')) {
      activeConByEmp.set(c.employeeId, c);
    }
  }

  /* Računaj risk za svakog zaposlenog */
  _riskCache = emps.map(emp => {
    const bos = boByEmp.get(emp.id) || [];
    const boDays = bos.reduce((sum, a) => sum + _overlapDays(a.dateFrom, a.dateTo, periodStart, periodEnd), 0);
    const boCount = bos.length;
    const medExpDays = _daysUntilExpiry(emp.medicalExamExpires);
    const con = activeConByEmp.get(emp.id);
    const conExpDays = con ? _daysUntilExpiry(con.dateTo) : null;
    const { level, reasons } = _computeRiskLevel({ boDays, medExpDays, conExpDays });
    return { emp, boDays, boCount, medExpDays, conExpDays, level, reasons };
  });

  /* Filter po nivou */
  let filtered = _riskCache;
  if (levelF === 'high') filtered = filtered.filter(r => r.level === 'high');
  else if (levelF === 'medium') filtered = filtered.filter(r => r.level === 'high' || r.level === 'medium');

  /* Summary chips */
  const cHigh = _riskCache.filter(r => r.level === 'high').length;
  const cMed = _riskCache.filter(r => r.level === 'medium').length;
  const cLow = _riskCache.filter(r => r.level === 'low').length;
  const medSoon = _riskCache.filter(r => r.medExpDays != null && r.medExpDays >= 0 && r.medExpDays <= 60).length;
  const conSoon = _riskCache.filter(r => r.conExpDays != null && r.conExpDays >= 0 && r.conExpDays <= 60).length;
  const totalBoDays = _riskCache.reduce((s, r) => s + r.boDays, 0);

  renderSummaryChips('repRiskSummary', [
    { label: 'Visok rizik', value: cHigh, tone: cHigh > 0 ? 'warn' : 'muted' },
    { label: 'Srednji rizik', value: cMed, tone: cMed > 0 ? 'accent' : 'muted' },
    { label: 'Nizak rizik', value: cLow, tone: 'ok' },
    { label: `Σ BO dana (${monthsBack}m)`, value: totalBoDays, tone: 'muted' },
    { label: 'Lekarski ističu ≤60 d', value: medSoon, tone: medSoon > 0 ? 'warn' : 'muted' },
    { label: 'Ugovori ističu ≤60 d', value: conSoon, tone: conSoon > 0 ? 'warn' : 'muted' },
  ]);

  /* Heatmap — koliko zaposlenih ima lekarski/ugovor koji ističe u svakom narednom mesecu (12 meseci) */
  _renderRiskHeatmap(heatmapEl);

  if (countEl) countEl.textContent = `${filtered.length} ${filtered.length === 1 ? 'zaposleni' : 'zaposlenih'}`;

  if (!filtered.length) {
    tbody.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  /* Sort: high → medium → low; unutar grupe po BO dana opadajuće */
  const order = { high: 0, medium: 1, low: 2 };
  filtered.sort((a, b) => {
    const d = (order[a.level] ?? 9) - (order[b.level] ?? 9);
    if (d !== 0) return d;
    return b.boDays - a.boDays;
  });

  tbody.innerHTML = filtered.map(r => {
    const medBadge = _riskExpiryBadge(r.medExpDays);
    const conBadge = _riskExpiryBadge(r.conExpDays);
    const levelCls = r.level === 'high' ? 'warn' : (r.level === 'medium' ? 'accent' : 'ok');
    const levelLbl = r.level === 'high' ? 'VISOK' : (r.level === 'medium' ? 'SREDNJI' : 'NIZAK');
    return `<tr>
      <td><strong>${escHtml(employeeDisplayName(r.emp) || '—')}</strong></td>
      <td class="col-hide-sm">${escHtml(r.emp.department || '—')}</td>
      <td style="font-family:var(--mono);font-weight:600">${r.boDays}</td>
      <td class="col-hide-sm">${r.boCount}</td>
      <td><span class="kadr-pill ${medBadge.cls}">${escHtml(medBadge.label)}</span></td>
      <td class="col-hide-sm"><span class="kadr-pill ${conBadge.cls}">${escHtml(conBadge.label)}</span></td>
      <td><span class="kadr-pill ${levelCls}" style="font-weight:700">${levelLbl}</span></td>
      <td class="col-hide-sm" style="font-size:.82rem;color:var(--text2)">${escHtml(r.reasons.join(' · '))}</td>
    </tr>`;
  }).join('');
}

function _renderRiskHeatmap(host) {
  if (!host) return;
  const today = new Date();
  const months = [];
  for (let i = 0; i < 12; i++) {
    const d = new Date(today.getFullYear(), today.getMonth() + i, 1);
    months.push({
      label: ['Jan','Feb','Mar','Apr','Maj','Jun','Jul','Avg','Sep','Okt','Nov','Dec'][d.getMonth()] + ' ' + String(d.getFullYear()).slice(2),
      ym: `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`,
    });
  }
  const medByMonth = new Map();
  const conByMonth = new Map();
  for (const r of _riskCache) {
    if (r.emp.medicalExamExpires) {
      const ym = r.emp.medicalExamExpires.slice(0, 7);
      medByMonth.set(ym, (medByMonth.get(ym) || 0) + 1);
    }
    /* Aktivni ugovor (uzmi iz cache-a kroz r objekat — ali nemamo direktan link) */
  }
  /* Za ugovore — iz state-a direktno */
  for (const c of (kadrContractsState.items || [])) {
    if (c.isActive === false || !c.dateTo) continue;
    const ym = c.dateTo.slice(0, 7);
    conByMonth.set(ym, (conByMonth.get(ym) || 0) + 1);
  }

  const maxMed = Math.max(1, ...Array.from(medByMonth.values()));
  const maxCon = Math.max(1, ...Array.from(conByMonth.values()));
  const maxBoth = Math.max(maxMed, maxCon);

  const cell = (val, max) => {
    if (!val) return '<span class="risk-heat-zero">·</span>';
    const intensity = Math.min(1, val / max);
    return `<span class="risk-heat-val" style="background:rgba(245, 158, 11, ${0.15 + intensity * 0.55});">${val}</span>`;
  };

  host.innerHTML = `
    <div class="risk-heatmap">
      <div class="risk-heatmap-title">Šta nas čeka — narednih 12 meseci</div>
      <table class="risk-heatmap-table">
        <thead>
          <tr>
            <th></th>
            ${months.map(m => `<th>${escHtml(m.label)}</th>`).join('')}
          </tr>
        </thead>
        <tbody>
          <tr>
            <td class="risk-heat-row-label">🩺 Lekarski ističe</td>
            ${months.map(m => `<td>${cell(medByMonth.get(m.ym) || 0, maxBoth)}</td>`).join('')}
          </tr>
          <tr>
            <td class="risk-heat-row-label">📄 Ugovor ističe</td>
            ${months.map(m => `<td>${cell(conByMonth.get(m.ym) || 0, maxBoth)}</td>`).join('')}
          </tr>
        </tbody>
      </table>
    </div>`;
}

async function _exportRiskXlsx() {
  if (!_riskCache.length) { showToast('Nema podataka za izvoz'); return; }
  showToast('⏳ Učitavam XLSX...');
  const XLSX = await loadXlsx();
  const aoa = [[
    'Zaposleni', 'Odeljenje', 'Pozicija',
    'BO dana (period)', 'BO evidencija',
    'Lekarski važi do', 'Dana do isteka lekarskog',
    'Ugovor važi do', 'Dana do isteka ugovora',
    'Rizik', 'Razlog',
  ]];
  for (const r of _riskCache) {
    const con = (kadrContractsState.items || []).find(c => c.employeeId === r.emp.id && c.isActive !== false);
    aoa.push([
      employeeDisplayName(r.emp) || '',
      r.emp.department || '',
      r.emp.position || '',
      r.boDays,
      r.boCount,
      r.emp.medicalExamExpires || '',
      r.medExpDays != null ? r.medExpDays : '',
      con?.dateTo || '',
      r.conExpDays != null ? r.conExpDays : '',
      r.level === 'high' ? 'VISOK' : (r.level === 'medium' ? 'SREDNJI' : 'NIZAK'),
      r.reasons.join(' · '),
    ]);
  }
  const ws = XLSX.utils.aoa_to_sheet(aoa);
  ws['!cols'] = [{ wch: 28 }, { wch: 20 }, { wch: 20 }, { wch: 14 }, { wch: 12 }, { wch: 14 }, { wch: 12 }, { wch: 14 }, { wch: 12 }, { wch: 10 }, { wch: 36 }];
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, 'Risk');
  XLSX.writeFile(wb, `Risk_izvestaj_${_isoToday()}.xlsx`);
  showToast('📊 Izvezeno');
}

/** Queue nedeljni risk summary u kadr_notification_log (`kadr_trigger_weekly_risk_summary`). */
async function _emailRiskToHr() {
  if (!canViewEmployeePii()) { showToast('⚠ Samo HR/admin'); return; }
  const btn = panelRoot?.querySelector('#repRiskEmail');
  if (btn) { btn.disabled = true; btn.textContent = 'Queue…'; }
  try {
    const n = await triggerWeeklyRiskSummary();
    if (n === null) {
      showToast('⚠ Nije moguće (offline ili nema prava)');
      return;
    }
    if (n === 0) {
      showToast('ℹ Nema novih redova u queue — proveri Notifikacije (email lista, uključeno) ili trenutno nema rizika za prijavu');
    } else {
      showToast(`📧 U queue: ${n} email(ova). Pošalji iz taba Notifikacije ili dispatch.`);
    }
  } finally {
    if (btn) {
      btn.disabled = false;
      btn.textContent = '📧 Pošalji HR-u';
    }
  }
}

async function _renderAuditReport() {
  if (!panelRoot || !isAdmin()) return;
  const tbody = panelRoot.querySelector('#repAuditTbody');
  const empty = panelRoot.querySelector('#repAuditEmpty');
  const countEl = panelRoot.querySelector('#repAuditCount');
  if (!tbody) return;

  const filter = {
    tableName: panelRoot.querySelector('#repAuditTable')?.value || '',
    action:    panelRoot.querySelector('#repAuditAction')?.value || '',
    fromIso:   panelRoot.querySelector('#repAuditFrom')?.value
      ? panelRoot.querySelector('#repAuditFrom').value + 'T00:00:00.000Z' : '',
    toIso:     panelRoot.querySelector('#repAuditTo')?.value
      ? panelRoot.querySelector('#repAuditTo').value + 'T23:59:59.999Z' : '',
    limit: 200,
  };

  try { auditCache = (await loadAuditLog(filter)) || []; }
  catch (e) { console.warn('[reports] audit', e); auditCache = []; }

  const cIns = auditCache.filter(r => r.action === 'INSERT').length;
  const cUpd = auditCache.filter(r => r.action === 'UPDATE').length;
  const cDel = auditCache.filter(r => r.action === 'DELETE').length;

  renderSummaryChips('repAuditSummary', [
    { label: 'Zapisa', value: auditCache.length, tone: 'accent' },
    { label: 'Kreirano', value: cIns, tone: 'ok' },
    { label: 'Promenjeno', value: cUpd, tone: 'muted' },
    { label: 'Obrisano', value: cDel, tone: cDel > 0 ? 'warn' : 'muted' },
  ]);

  if (countEl) countEl.textContent = `${auditCache.length} ${auditCache.length === 1 ? 'zapis' : 'zapisa'}`;

  if (!auditCache.length) {
    tbody.innerHTML = '';
    if (empty) empty.style.display = 'block';
    return;
  }
  if (empty) empty.style.display = 'none';

  tbody.innerHTML = auditCache.map(r => `<tr>
    <td>${escHtml(_fmtAuditTime(r.changedAt))}</td>
    <td>${escHtml(r.actorEmail || r.actorUserId || '—')}</td>
    <td><span class="kadr-pill ${r.action === 'DELETE' ? 'warn' : (r.action === 'INSERT' ? 'ok' : 'muted')}">${escHtml(r.action)}</span></td>
    <td>${escHtml(AUDIT_TABLE_LABELS[r.tableName] || r.tableName)}</td>
    <td>${escHtml(r.employeeName || '—')}</td>
    <td>${_renderAuditDiff(r)}</td>
  </tr>`).join('');
}

async function _exportAuditCsv() {
  if (!auditCache.length) { showToast('Nema podataka za izvoz'); return; }
  const headers = ['Vreme', 'Akter', 'Akcija', 'Tabela', 'Zaposleni', 'Row ID', 'Pre', 'Posle'];
  const rows = auditCache.map(r => [
    r.changedAt || '',
    r.actorEmail || r.actorUserId || '',
    r.action,
    AUDIT_TABLE_LABELS[r.tableName] || r.tableName,
    r.employeeName || '',
    r.rowId || '',
    r.beforeData ? JSON.stringify(r.beforeData) : '',
    r.afterData  ? JSON.stringify(r.afterData)  : '',
  ]);
  downloadCsv(`Audit_log_${_isoToday()}.csv`, headers, rows);
  showToast('📑 CSV izvezen');
}

/* ═════════════════════════════════════════════════════════════════════
   CSV EXPORTS — paralelni Excel-u, koristi Blob + a[download]
   ═════════════════════════════════════════════════════════════════════ */

async function _exportSickCsv() {
  const empFilter = panelRoot?.querySelector('#repSickEmpFilter')?.value || '';
  const deptFilter = panelRoot?.querySelector('#repSickDeptFilter')?.value || '';
  const { from: pFrom, to: pTo } = _readPeriod();
  const allSick = (pFrom && pTo)
    ? await bolovanjeListFromWorkHours(pFrom, pTo)
    : await bolovanjeListFromWorkHours('', '');
  const empById = new Map(kadrovskaState.employees.map(e => [e.id, e]));

  const headers = ['Zaposleni', 'Odeljenje', 'Od', 'Do', 'Trajanje (d)', 'Dana u periodu', 'Napomena'];
  const rows = [];
  allSick.forEach(a => {
    if (!a.employeeId) return;
    if (empFilter && a.employeeId !== empFilter) return;
    const emp = empById.get(a.employeeId);
    if (deptFilter) {
      if (!emp) return;
      const deptId = parseInt(deptFilter, 10);
      if (orgStructureState.departments.length && !isNaN(deptId)) {
        if (emp.departmentId !== deptId) return;
      } else {
        if (emp.department !== deptFilter) return;
      }
    }
    const days = _intersectingDays(a.dateFrom, a.dateTo, pFrom, pTo);
    if (days <= 0) return;
    rows.push([
      emp ? (employeeDisplayName(emp) || '') : '(obrisan)',
      emp?.department || '',
      a.dateFrom || '',
      a.dateTo || '',
      daysInclusive(a.dateFrom, a.dateTo),
      days,
      a.note || '',
    ]);
  });
  if (!rows.length) { showToast('⚠ Nema podataka za izvoz'); return; }
  const tag = (pFrom || '') + (pTo ? '_' + pTo : '') || 'all';
  downloadCsv(`Bolovanja_${tag}.csv`, headers, rows);
  showToast('📑 CSV izvezen');
}

async function _exportVacCsv() {
  const year = Number(panelRoot.querySelector('#repVacYear').value || new Date().getFullYear());
  const status = panelRoot.querySelector('#repVacStatus').value || 'active';
  const goFromGrid = await countGoDaysByEmployeeForYear(year);
  const balByEmp = new Map();
  for (const b of kadrVacationState.balances) if (b.year === year) balByEmp.set(b.employeeId, b);
  const entByEmp = new Map();
  for (const e of kadrVacationState.entitlements) if (e.year === year) entByEmp.set(e.employeeId, e);

  const headers = ['Zaposleni', 'Odeljenje', 'Dana pravo', 'Preneto', 'Iskorišćeno', 'Preostalo'];
  const rows = [];
  kadrovskaState.employees
    .filter(e => status === 'all' || e.isActive)
    .forEach(emp => {
      const ent = entByEmp.get(emp.id);
      const bal = balByEmp.get(emp.id);
      const dt = ent?.daysTotal ?? 20;
      const dc = ent?.daysCarriedOver ?? 0;
      const du = bal?.daysUsed ?? (goFromGrid.get(emp.id) ?? 0);
      rows.push([employeeDisplayName(emp) || '', emp.department || '', dt, dc, du, dt + dc - du]);
    });
  downloadCsv(`Saldo_GO_${year}.csv`, headers, rows);
  showToast('📑 CSV izvezen');
}

async function _exportMedCsv() {
  if (!medExamCache.length) {
    try { medExamCache = (await loadAllMedExamStatus()) || []; } catch {}
  }
  if (!medExamCache.length) { showToast('Nema podataka za izvoz'); return; }
  const headers = ['Zaposleni', 'Pozicija', 'Odeljenje', 'Poslednji pregled', 'Važi do', 'Dana do isteka', 'Status'];
  const rows = medExamCache.map(r => {
    const cls = MED_STATUS_LABELS[r.status] || { label: r.status };
    return [
      r.employeeName || '',
      r.employeePosition || '',
      r.employeeDepartment || '',
      r.medicalExamDate || '',
      r.medicalExamExpires || '',
      r.daysToExpiry != null ? r.daysToExpiry : '',
      cls.label,
    ];
  });
  downloadCsv(`Lekarski_pregledi_${_isoToday()}.csv`, headers, rows);
  showToast('📑 CSV izvezen');
}

async function _exportCertsCsv() {
  if (!certCache.length) {
    try { certCache = (await loadAllCertificateStatus()) || []; } catch {}
  }
  if (!certCache.length) { showToast('Nema podataka za izvoz'); return; }
  const headers = ['Zaposleni', 'Pozicija', 'Odeljenje', 'Tip', 'Naziv', 'Br. dokumenta', 'Izdavalac', 'Izdat', 'Ističe', 'Dana do isteka', 'Trošak (RSD)', 'Status'];
  const rows = certCache.map(r => {
    const cls = CERT_STATUS_LABELS[r.status] || { label: r.status };
    return [
      r.employeeName || '',
      r.employeePosition || '',
      r.employeeDepartment || '',
      CERT_TYPE_LABELS[r.certType] || r.certType,
      r.certName || '',
      r.documentNo || '',
      r.issuer || '',
      r.issuedOn || '',
      r.expiresOn || '',
      r.daysToExpiry != null ? r.daysToExpiry : '',
      r.costRsd || 0,
      cls.label,
    ];
  });
  downloadCsv(`Sertifikati_${_isoToday()}.csv`, headers, rows);
  showToast('📑 CSV izvezen');
}

/* ─── PUBLIC: WIRE ────────────────────────────────────────────────────── */

export async function wireReportsTab(panel) {
  panelRoot = panel;

  /* Wire filter handlers (po pravilu: promena meseca/godine briše manualni
     range; promena range-a briše mesec; promena godine briše mesec+range) */
  panel.querySelector('#repSickEmpFilter')?.addEventListener('change', () => {
    void _renderSickReport().catch(err => console.warn('[reports] sick', err));
  });
  panel.querySelector('#repSickDeptFilter')?.addEventListener('change', () => {
    void _renderSickReport().catch(err => console.warn('[reports] sick', err));
  });

  panel.querySelector('#repSickMonth')?.addEventListener('change', () => {
    const f = panel.querySelector('#repSickFrom');
    const t = panel.querySelector('#repSickTo');
    if (f) f.value = '';
    if (t) t.value = '';
    void _renderSickReport().catch(err => console.warn('[reports] sick', err));
  });
  panel.querySelector('#repSickYear')?.addEventListener('change', () => {
    const m = panel.querySelector('#repSickMonth');
    const f = panel.querySelector('#repSickFrom');
    const t = panel.querySelector('#repSickTo');
    if (m) m.value = '';
    if (f) f.value = '';
    if (t) t.value = '';
    void _renderSickReport().catch(err => console.warn('[reports] sick', err));
  });
  const onRange = () => {
    const m = panel.querySelector('#repSickMonth');
    if (m) m.value = '';
    void _renderSickReport().catch(err => console.warn('[reports] sick', err));
  };
  panel.querySelector('#repSickFrom')?.addEventListener('change', onRange);
  panel.querySelector('#repSickTo')?.addEventListener('change', onRange);

  panel.querySelector('#repSickReset')?.addEventListener('click', () => {
    ['repSickEmpFilter', 'repSickDeptFilter', 'repSickMonth', 'repSickYear', 'repSickFrom', 'repSickTo']
      .forEach(id => {
        const el = panel.querySelector('#' + id);
        if (el) el.value = '';
      });
    const y = panel.querySelector('#repSickYear');
    if (y) y.value = String(new Date().getFullYear());
    _renderSickReport().catch(err => console.warn('[reports] sick', err));
  });

  panel.querySelector('#repSickExport')?.addEventListener('click', _exportToXlsx);
  panel.querySelector('#repSickExportCsv')?.addEventListener('click', _exportSickCsv);

  /* ── Subtab switching ────────────────────────────── */
  const reportTabs = Array.from(panel.querySelectorAll('.report-tab'));
  const reportPanels = Array.from(panel.querySelectorAll('.report-panel'));
  reportTabs.forEach(btn => {
    btn.addEventListener('click', async () => {
      const tab = btn.dataset.reportTab;
      reportTabs.forEach(b => {
        const isActive = b === btn;
        b.classList.toggle('active', isActive);
        b.setAttribute('aria-selected', String(isActive));
      });
      reportPanels.forEach(p => {
        const isActive = p.id === 'reportPanel-' + tab;
        p.classList.toggle('active', isActive);
        if (isActive) p.removeAttribute('hidden');
        else p.setAttribute('hidden', '');
      });
      if (tab === 'demo') _renderDemo();
      if (tab === 'org') _renderOrgChart();
      if (tab === 'vacation') {
        const year = Number(panel.querySelector('#repVacYear').value);
        await ensureVacationLoaded(year, true);
        await _renderVacReport();
      }
      if (tab === 'overtime') await _renderOvertimeReport();
      if (tab === 'field') await _renderFieldReport();
      if (tab === 'medical') await _renderMedicalReport();
      if (tab === 'certs') await _renderCertsReport();
      if (tab === 'children') await _renderChildrenReport();
      if (tab === 'risk') await _renderRiskReport();
      if (tab === 'audit') await _renderAuditReport();
    });
  });

  /* ── Organogram listeners ─────────────────────────── */
  panel.querySelector('#repOrgStatus')?.addEventListener('change', _renderOrgChart);
  panel.querySelector('#repOrgSearch')?.addEventListener('input', _renderOrgChart);
  panel.querySelector('#repOrgExpand')?.addEventListener('click', _orgExpandAll);
  panel.querySelector('#repOrgCollapse')?.addEventListener('click', _orgCollapseAll);

  /* ── Demografija listeners ────────────────────────── */
  panel.querySelector('#repDemoStatus')?.addEventListener('change', _renderDemo);
  panel.querySelector('#repDemoExport')?.addEventListener('click', _exportDemoXlsx);

  /* ── Saldo GO listeners ──────────────────────────── */
  panel.querySelector('#repVacYear')?.addEventListener('change', async () => {
    const year = Number(panel.querySelector('#repVacYear').value);
    await ensureVacationLoaded(year, true);
    await _renderVacReport();
  });
  panel.querySelector('#repVacStatus')?.addEventListener('change', () => {
    void _renderVacReport().catch(e => console.warn('[reports] vac', e));
  });
  panel.querySelector('#repVacExport')?.addEventListener('click', _exportVacXlsx);
  panel.querySelector('#repVacExportCsv')?.addEventListener('click', _exportVacCsv);

  /* ── Prekovremeni listeners ──────────────────────── */
  const reRenderOt = () => { void _renderOvertimeReport().catch(e => console.warn('[reports] ot', e)); };
  panel.querySelector('#repOtMonth')?.addEventListener('change', () => {
    const f = panel.querySelector('#repOtFrom'); const t = panel.querySelector('#repOtTo');
    if (f) f.value = ''; if (t) t.value = '';
    reRenderOt();
  });
  panel.querySelector('#repOtYear')?.addEventListener('change', () => {
    const m = panel.querySelector('#repOtMonth'); const f = panel.querySelector('#repOtFrom'); const t = panel.querySelector('#repOtTo');
    if (m) m.value = ''; if (f) f.value = ''; if (t) t.value = '';
    reRenderOt();
  });
  const onOtRange = () => {
    const m = panel.querySelector('#repOtMonth'); if (m) m.value = '';
    reRenderOt();
  };
  panel.querySelector('#repOtFrom')?.addEventListener('change', onOtRange);
  panel.querySelector('#repOtTo')?.addEventListener('change', onOtRange);
  panel.querySelector('#repOtReset')?.addEventListener('click', () => {
    ['repOtMonth', 'repOtYear', 'repOtFrom', 'repOtTo'].forEach(id => {
      const el = panel.querySelector('#' + id); if (el) el.value = '';
    });
    const y = panel.querySelector('#repOtYear');
    if (y) y.value = String(new Date().getFullYear());
    reRenderOt();
  });
  panel.querySelector('#repOtExport')?.addEventListener('click', _exportOvertimeXlsx);

  /* ── Terenski listeners ──────────────────────────── */
  const reRenderFw = () => { void _renderFieldReport().catch(e => console.warn('[reports] fw', e)); };
  panel.querySelector('#repFwMonth')?.addEventListener('change', () => {
    const f = panel.querySelector('#repFwFrom'); const t = panel.querySelector('#repFwTo');
    if (f) f.value = ''; if (t) t.value = '';
    reRenderFw();
  });
  panel.querySelector('#repFwYear')?.addEventListener('change', () => {
    const m = panel.querySelector('#repFwMonth'); const f = panel.querySelector('#repFwFrom'); const t = panel.querySelector('#repFwTo');
    if (m) m.value = ''; if (f) f.value = ''; if (t) t.value = '';
    reRenderFw();
  });
  const onFwRange = () => {
    const m = panel.querySelector('#repFwMonth'); if (m) m.value = '';
    reRenderFw();
  };
  panel.querySelector('#repFwFrom')?.addEventListener('change', onFwRange);
  panel.querySelector('#repFwTo')?.addEventListener('change', onFwRange);
  panel.querySelector('#repFwType')?.addEventListener('change', reRenderFw);
  panel.querySelector('#repFwReset')?.addEventListener('click', () => {
    ['repFwMonth', 'repFwYear', 'repFwFrom', 'repFwTo', 'repFwType'].forEach(id => {
      const el = panel.querySelector('#' + id); if (el) el.value = '';
    });
    const y = panel.querySelector('#repFwYear');
    if (y) y.value = String(new Date().getFullYear());
    reRenderFw();
  });
  panel.querySelector('#repFwExport')?.addEventListener('click', _exportFieldXlsx);

  /* ── Sertifikati listeners ────────────────────────── */
  panel.querySelector('#repCertType')?.addEventListener('change', () => {
    void _renderCertsReport().catch(e => console.warn('[reports] certs', e));
  });
  panel.querySelector('#repCertStatus')?.addEventListener('change', () => {
    void _renderCertsReport().catch(e => console.warn('[reports] certs', e));
  });
  panel.querySelector('#repCertReload')?.addEventListener('click', () => {
    certCache = [];
    void _renderCertsReport().catch(e => console.warn('[reports] certs', e));
  });
  panel.querySelector('#repCertExport')?.addEventListener('click', _exportCertsXlsx);
  panel.querySelector('#repCertExportCsv')?.addEventListener('click', _exportCertsCsv);

  /* ── Lekarski pregledi listeners ──────────────────── */
  panel.querySelector('#repMedStatus')?.addEventListener('change', () => {
    void _renderMedicalReport().catch(e => console.warn('[reports] med', e));
  });
  panel.querySelector('#repMedReload')?.addEventListener('click', () => {
    medExamCache = [];
    void _renderMedicalReport().catch(e => console.warn('[reports] med', e));
  });
  panel.querySelector('#repMedExport')?.addEventListener('click', _exportMedicalXlsx);
  panel.querySelector('#repMedExportCsv')?.addEventListener('click', _exportMedCsv);

  /* ── Risk listeners ──────────────────────────────── */
  const reRenderRisk = () => { void _renderRiskReport().catch(e => console.warn('[reports] risk', e)); };
  panel.querySelector('#repRiskStatus')?.addEventListener('change', reRenderRisk);
  panel.querySelector('#repRiskMonths')?.addEventListener('change', reRenderRisk);
  panel.querySelector('#repRiskLevel')?.addEventListener('change', reRenderRisk);
  panel.querySelector('#repRiskExport')?.addEventListener('click', _exportRiskXlsx);
  panel.querySelector('#repRiskEmail')?.addEventListener('click', _emailRiskToHr);

  /* ── Audit log listeners ──────────────────────────── */
  const reRenderAudit = () => { void _renderAuditReport().catch(e => console.warn('[reports] audit', e)); };
  panel.querySelector('#repAuditTable')?.addEventListener('change', reRenderAudit);
  panel.querySelector('#repAuditAction')?.addEventListener('change', reRenderAudit);
  panel.querySelector('#repAuditFrom')?.addEventListener('change', reRenderAudit);
  panel.querySelector('#repAuditTo')?.addEventListener('change', reRenderAudit);
  panel.querySelector('#repAuditReload')?.addEventListener('click', reRenderAudit);
  panel.querySelector('#repAuditExport')?.addEventListener('click', _exportAuditCsv);

  /* ── Deca listeners ──────────────────────────────── */
  panel.querySelector('#repChildrenExport')?.addEventListener('click', _exportChildrenXlsx);

  /* Učitaj zaposlene + struktura */
  try {
    await Promise.all([
      ensureEmployeesLoaded(),
      ensureOrgStructureLoaded(),
    ]);
  } catch (err) {
    console.warn('[reports] data load failed', err);
  }

  _populateFilters();
  void _renderSickReport().catch(err => console.warn('[reports] sick render', err));
}
