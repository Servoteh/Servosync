/**
 * UI tab „Obaveštenja” u Održavanju.
 * URL: /maintenance/notifications
 *
 * Outbox nad `maint_notification_log` — worker
 * (`supabase/functions/maint-notify-dispatch`) obrađuje queued/failed.
 * UI dozvoljava chief/admin (i ERP admin) da ručno vrate failed → queued.
 *
 * RLS za `maint_notification_log` (vidi `add_maintenance_module.sql`) dozvoljava
 * SELECT samo `maint_profile_role() IN ('chief','management','admin')` ili ERP admin.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { getAuth } from '../../state/auth.js';
import {
  fetchMaintNotifications,
  retryMaintNotification,
  fetchMaintMachines,
} from '../../services/maintenance.js';
import { buildMaintenanceMachinePath } from '../../lib/appPaths.js';

/**
 * Uloge koje po RLS-u mogu da čitaju log.
 * @param {object|null} prof
 */
export function canAccessMaintNotifications(prof) {
  if (getAuth().role === 'admin') return true;
  const r = prof?.role;
  return r === 'chief' || r === 'management' || r === 'admin';
}

/**
 * Uloge koje mogu da okidaju retry (SECURITY DEFINER RPC to proverava, ali UI
 * krije dugme za ostale da ne dobiju 42501 u UI-ju).
 * @param {object|null} prof
 */
export function canRetryMaintNotification(prof) {
  if (getAuth().role === 'admin') return true;
  const r = prof?.role;
  return r === 'chief' || r === 'admin';
}

const STATUSES = [
  { v: 'all', l: 'Svi' },
  { v: 'queued', l: 'Na čekanju' },
  { v: 'sent', l: 'Poslato' },
  { v: 'failed', l: 'Greška' },
];

/**
 * Korisnički naziv statusa dostave — srpski, u jednini.
 * @param {string} s
 */
function statusLabelSr(s) {
  const v = String(s || '').toLowerCase();
  if (v === 'sent') return 'Poslato';
  if (v === 'queued') return 'Na čekanju';
  if (v === 'failed') return 'Greška';
  return s || '';
}

function statusBadge(s) {
  const v = String(s || '').toLowerCase();
  if (v === 'sent') return 'mnt-badge mnt-badge--running';
  if (v === 'queued') return 'mnt-badge mnt-badge--degraded';
  if (v === 'failed') return 'mnt-badge mnt-badge--down';
  return 'mnt-badge';
}

function fmtIso(iso) {
  if (!iso) return '';
  return String(iso).replace('T', ' ').slice(0, 16);
}

function severityFromPayload(payload) {
  if (!payload || typeof payload !== 'object') return '';
  const sev = payload.severity;
  return sev ? String(sev) : '';
}

/**
 * Korisnički naziv ozbiljnosti (isti kao u index.js — ali kopija ovde da
 * izbegnemo cross-module helper sada; TODO: izdvojiti u shared util).
 * @param {string} sev
 */
function severityLabelSr(sev) {
  const s = String(sev || '').toLowerCase();
  if (s === 'critical') return 'Kritično';
  if (s === 'major') return 'Visok';
  if (s === 'minor') return 'Nizak';
  if (s === 'info') return 'Info';
  return sev || '';
}

/**
 * Formatira primaoca: ako je obaveštenje „stub" (čeka da worker rasporedi
 * primaoce), prikaži friendly label umesto internog `pending`.
 * @param {object} row
 */
function recipientCell(row) {
  if (row.recipient === 'pending' && !row.recipient_user_id) {
    return `<span class="mnt-muted" title="Sistem će rasporediti primaoce pri sledećem prolazu">čeka dostavu</span>`;
  }
  const rcp = row.recipient ? escHtml(row.recipient) : '';
  if (row.channel === 'in_app' && row.recipient_user_id) {
    return `<span class="mnt-muted" title="ID korisnika: ${escHtml(String(row.recipient_user_id))}">korisnik aplikacije</span>`;
  }
  return rcp || '<span class="mnt-muted">—</span>';
}

/**
 * Renderuje ceo panel „Obaveštenja”.
 * @param {HTMLElement} host
 * @param {{ prof: object|null, onNavigateToPath?: (p:string)=>void }} ctx
 * @param {{ status?: string, machineCode?: string }} [state]
 */
export async function renderMaintNotificationsPanel(host, ctx, state = {}) {
  const prof = ctx.prof;
  const canRetry = canRetryMaintNotification(prof);

  const status = state.status || 'queued';
  const machineCode = state.machineCode || '';

  host.innerHTML = `
    <div class="mnt-panel">
      <div style="display:flex;flex-wrap:wrap;align-items:flex-end;gap:12px;margin-bottom:12px">
        <div>
          <label class="form-label" style="margin-bottom:2px">Status</label>
          <select class="form-input" id="mntNotifStatus" style="min-width:140px">
            ${STATUSES.map(s => `<option value="${s.v}"${s.v === status ? ' selected' : ''}>${escHtml(s.l)}</option>`).join('')}
          </select>
        </div>
        <div>
          <label class="form-label" style="margin-bottom:2px">Mašina (šifra)</label>
          <input class="form-input" id="mntNotifMachine" value="${escHtml(machineCode)}" placeholder="npr. 8.3" style="min-width:140px">
        </div>
        <button type="button" class="btn" id="mntNotifApply">Primeni</button>
        <button type="button" class="btn" id="mntNotifRefresh" style="background:var(--surface3)">↻ Osveži</button>
        <span style="flex:1"></span>
        <span class="mnt-muted" id="mntNotifCount"></span>
      </div>
      <div id="mntNotifTableHost">
        <p class="mnt-muted">Učitavam…</p>
      </div>
      <details class="mnt-tech-details" style="margin-top:14px">
        <summary>Tehnički detalji</summary>
        <p class="mnt-muted" style="margin-top:8px;font-size:12px">
          Stavke u stanju „čeka dostavu" obrađuje pozadinski servis pri sledećem
          prolazu. Ako je status <strong>Greška</strong>, šef ili administrator
          može da pritisne „Ponovi" — servis će ponovo pokušati slanje.
        </p>
      </details>
    </div>
  `;

  const tableHost = host.querySelector('#mntNotifTableHost');
  const countEl = host.querySelector('#mntNotifCount');

  async function load() {
    tableHost.innerHTML = `<p class="mnt-muted">Učitavam…</p>`;
    const [rows, names] = await Promise.all([
      fetchMaintNotifications({
        status: status,
        machineCode: machineCode || undefined,
        limit: 200,
      }),
      /* Za tabelu notifikacija prikazujemo i imena arhiviranih mašina
         (istorijske notifikacije mogu referencirati kôd koji je u međuvremenu
         arhiviran u katalogu). */
      fetchMaintMachines({ includeArchived: true }),
    ]);

    if (rows === null) {
      tableHost.innerHTML = `<p class="mnt-muted">Nemaš dozvolu za pregled obaveštenja, ili migracija nije primenjena.</p>`;
      countEl.textContent = '';
      return;
    }
    const list = Array.isArray(rows) ? rows : [];
    const nameByCode = new Map(
      (Array.isArray(names) ? names : []).map(n => [n.machine_code, n.name || n.machine_code]),
    );
    countEl.textContent = list.length
      ? `${list.length} redova`
      : 'Nema redova za date filtere.';

    if (!list.length) {
      tableHost.innerHTML = `<p class="mnt-muted" style="margin-top:8px">Nema redova.</p>`;
      return;
    }

    const tbody = list
      .map(r => {
        const sev = severityFromPayload(r.payload);
        const sevBadge = sev
          ? ` <span class="${sev === 'critical' ? 'mnt-badge mnt-badge--down' : sev === 'major' ? 'mnt-badge mnt-badge--degraded' : 'mnt-badge'}">${escHtml(severityLabelSr(sev))}</span>`
          : '';
        const mcode = r.machine_code || '';
        const mDisp = mcode ? (nameByCode.get(mcode) || mcode) : '';
        const machineCell = mcode
          ? `<button type="button" class="mnt-linkish" data-mnt-nav="${buildMaintenanceMachinePath(mcode, 'pregled')}" title="${escHtml(mDisp)}">${escHtml(mcode)}</button>`
          : '<span class="mnt-muted">—</span>';
        const canAction = canRetry && r.status === 'failed';
        const actionCell = canAction
          ? `<button type="button" class="btn" style="padding:2px 10px;font-size:12px" data-mnt-notif-retry="${escHtml(String(r.id))}">Ponovi</button>`
          : '';
        const err = r.error
          ? `<br><span class="mnt-muted" style="font-size:11px" title="${escHtml(String(r.error))}">${escHtml(String(r.error).slice(0, 80))}${String(r.error).length > 80 ? '…' : ''}</span>`
          : '';
        const last = r.last_attempt_at
          ? `<br><span class="mnt-muted" style="font-size:11px">poslednji pokušaj: ${escHtml(fmtIso(r.last_attempt_at))}</span>`
          : '';
        const next = r.status !== 'sent' && r.next_attempt_at
          ? `<br><span class="mnt-muted" style="font-size:11px">sledeći pokušaj: ${escHtml(fmtIso(r.next_attempt_at))}</span>`
          : '';
        return `<tr>
          <td><span class="mnt-muted" style="font-size:11px">${escHtml(fmtIso(r.created_at))}</span></td>
          <td>${escHtml(r.channel || '')}</td>
          <td>${machineCell}${sevBadge}</td>
          <td>${recipientCell(r)}</td>
          <td>${escHtml(r.subject || '')}${err}</td>
          <td><span class="${statusBadge(r.status)}">${escHtml(statusLabelSr(r.status))}</span>${last}${next}</td>
          <td style="text-align:center">${escHtml(String(r.attempts ?? 0))}</td>
          <td>${actionCell}</td>
        </tr>`;
      })
      .join('');

    tableHost.innerHTML = `
      <div class="mnt-table-wrap">
        <table class="mnt-table" aria-label="Obaveštenja">
          <thead>
            <tr>
              <th>Kreiran</th>
              <th>Kanal</th>
              <th>Mašina</th>
              <th>Primalac</th>
              <th>Naslov / greška</th>
              <th>Status</th>
              <th>Pokušaji</th>
              <th></th>
            </tr>
          </thead>
          <tbody>${tbody}</tbody>
        </table>
      </div>
    `;

    tableHost.querySelectorAll('[data-mnt-nav]').forEach(btn => {
      btn.addEventListener('click', e => {
        e.stopPropagation();
        const p = btn.getAttribute('data-mnt-nav');
        if (p && ctx.onNavigateToPath) ctx.onNavigateToPath(p);
      });
    });
    tableHost.querySelectorAll('[data-mnt-notif-retry]').forEach(btn => {
      btn.addEventListener('click', async () => {
        const id = btn.getAttribute('data-mnt-notif-retry');
        if (!id) return;
        btn.disabled = true;
        btn.textContent = '…';
        const ok = await retryMaintNotification(id);
        if (!ok) {
          btn.disabled = false;
          btn.textContent = 'Ponovi';
          showToast('⚠ Nije moguće vratiti u red za slanje (ovlašćenja ili red ne postoji)');
          return;
        }
        showToast('✅ Vraćeno u red za slanje — servis će ponovo pokušati');
        load();
      });
    });
  }

  host.querySelector('#mntNotifApply')?.addEventListener('click', () => {
    const nextStatus = host.querySelector('#mntNotifStatus').value;
    const nextMachine = host.querySelector('#mntNotifMachine').value.trim();
    renderMaintNotificationsPanel(host, ctx, {
      status: nextStatus,
      machineCode: nextMachine,
    });
  });
  host.querySelector('#mntNotifRefresh')?.addEventListener('click', () => {
    load();
  });
  host.querySelector('#mntNotifMachine')?.addEventListener('keydown', ev => {
    if (ev.key === 'Enter') {
      ev.preventDefault();
      host.querySelector('#mntNotifApply').click();
    }
  });

  await load();
}
