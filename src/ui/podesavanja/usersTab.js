/**
 * Podešavanja → Korisnici tab.
 *
 * Pregled, search, filter (uloga, status), edit (modal) i delete redova
 * iz `user_roles` tabele. INSERT je SVESNO blokiran iz UI-ja — vidi
 * komentar u src/services/users.js.
 *
 * Render flow:
 *   1) renderUsersTab() → vraća HTML (page header + stats + toolbar + tabela)
 *   2) wireUsersTab(root) → wire-uje search/filter, akcije reda i modal handler
 *   3) refreshUsers() → cache-first paint pa async DB sync
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { ROLE_LABELS } from '../../lib/constants.js';
import { canManageUsers, getCurrentUser, getIsOnline } from '../../state/auth.js';
import { hasSupabaseConfig } from '../../lib/constants.js';
import { allData } from '../../state/planMontaze.js';
import {
  usersState,
  loadUsersCache,
  saveUsersCache,
} from '../../state/users.js';
import {
  loadUsersFromDb,
  saveUserToDb,
  deleteUserRoleFromDb,
  mapDbUser,
  inviteUserViaEdge,
  inviteUserRoleViaRpc,
} from '../../services/users.js';
import { loadSubDepartments, loadDepartments } from '../../services/orgStructure.js';

let _onChangeRoot = null;
let _modalEl = null;
let _inviteModalEl = null;
let _filters = { search: '', role: '', status: '' };
/** @type {{ id: number, name: string, department_id: number, deptName?: string }[]} */
let _subDeptOptions = [];

/* ── PUBLIC ──────────────────────────────────────────────────────────── */

export async function refreshUsers(force = false) {
  if (!usersState.items.length) {
    usersState.items = loadUsersCache();
  }
  if (usersState.loaded && !force && (!getIsOnline() || !hasSupabaseConfig())) {
    return;
  }
  if (getIsOnline() && hasSupabaseConfig()) {
    const fresh = await loadUsersFromDb();
    if (Array.isArray(fresh)) {
      usersState.items = fresh.map(mapDbUser);
      saveUsersCache(usersState.items);
    }
  }
  usersState.loaded = true;
}

export function renderUsersTab() {
  return `
    ${_pageHeaderHtml()}
    <div class="set-stats-grid" id="usersSummary">${_statsHtml()}</div>
    ${_toolbarHtml()}
    <main class="kadrovska-main" style="padding:0">
      ${_tableHtml()}
    </main>
  `;
}

export function wireUsersTab(root, { onChange } = {}) {
  _onChangeRoot = onChange || null;

  const search    = root.querySelector('#usersSearch');
  const roleF     = root.querySelector('#usersRoleFilter');
  const statusF   = root.querySelector('#usersStatusFilter');
  const refreshBtn = root.querySelector('#usersRefreshBtn');
  const inviteBtn  = root.querySelector('#usersInviteBtn');

  search?.addEventListener('input', () => {
    _filters.search = search.value;
    _rerenderTableAndSummary(root);
  });
  roleF?.addEventListener('change', () => {
    _filters.role = roleF.value;
    _rerenderTableAndSummary(root);
  });
  statusF?.addEventListener('change', () => {
    _filters.status = statusF.value;
    _rerenderTableAndSummary(root);
  });
  refreshBtn?.addEventListener('click', async () => {
    refreshBtn.disabled = true;
    const orig = refreshBtn.textContent;
    refreshBtn.textContent = '⟳ Osvežavam…';
    try {
      await refreshUsers(true);
      _rerenderTableAndSummary(root);
      showToast('✅ Lista osvežena');
    } catch (e) {
      console.error('[users] refresh err', e);
      showToast('⚠ Greška pri osvežavanju');
    } finally {
      refreshBtn.disabled = false;
      refreshBtn.textContent = orig;
    }
  });
  inviteBtn?.addEventListener('click', () => _openInviteModal());

  _ensureSubDeptOptions().catch(() => {});

  _wireTbody(root);
}

/* ── INTERNAL: rendering ─────────────────────────────────────────────── */

function _pageHeaderHtml() {
  return `
    <div class="set-page-header">
      <div class="set-page-header-icon">👤</div>
      <div>
        <h2 class="set-page-header-title">Korisnici</h2>
        <p class="set-page-header-sub">Upravljanje pristupom korisnika sistemu</p>
      </div>
    </div>
  `;
}

function _statsHtml() {
  const all     = usersState.items;
  const active  = all.filter(u => u.isActive).length;
  const admins  = all.filter(u => u.role === 'admin').length;
  const hr      = all.filter(u => u.role === 'hr').length;
  const pms     = all.filter(u => u.role === 'pm' || u.role === 'leadpm').length;
  const mgmt    = all.filter(u => u.role === 'menadzment').length;
  const viewers = all.filter(u => u.role === 'viewer').length;

  const card = (icon, label, value, accent = false) => `
    <div class="set-stat-card${accent ? ' set-stat-card--accent' : ''}">
      <span class="set-stat-icon">${icon}</span>
      <div class="set-stat-body">
        <div class="set-stat-label">${label}</div>
        <div class="set-stat-value">${value}</div>
      </div>
    </div>`;

  return [
    card('👤', 'Ukupno',      all.length, true),
    card('✅', 'Aktivni',     active),
    card('🛡', 'Admin',       admins),
    card('🏥', 'HR',          hr),
    card('📋', 'PM / Lead',   pms),
    card('📊', 'Menadžment',  mgmt),
    card('👁', 'Viewer',      viewers),
  ].join('');
}

function _toolbarHtml() {
  const n = _filtered().length;
  return `
    <div class="set-toolbar" id="usersToolbar">
      <input type="text" class="form-input" id="usersSearch" style="flex:1;min-width:200px"
             placeholder="Pretraga po imenu, email-u, timu…"
             value="${escHtml(_filters.search)}">
      <div class="set-toolbar-field">
        <span class="set-toolbar-field-label">Uloga</span>
        <select class="form-input" id="usersRoleFilter" style="min-width:130px">
          <option value="">Sve uloge</option>
          ${Object.entries(ROLE_LABELS).map(([k, v]) =>
            `<option value="${k}"${_filters.role === k ? ' selected' : ''}>${escHtml(v)}</option>`
          ).join('')}
        </select>
      </div>
      <div class="set-toolbar-field">
        <span class="set-toolbar-field-label">Status</span>
        <select class="form-input" id="usersStatusFilter" style="min-width:120px">
          <option value="">Svi statusi</option>
          <option value="active"${_filters.status === 'active' ? ' selected' : ''}>Aktivni</option>
          <option value="inactive"${_filters.status === 'inactive' ? ' selected' : ''}>Neaktivni</option>
        </select>
      </div>
      <button type="button" class="btn btn-ghost" id="usersRefreshBtn" title="Osveži listu iz baze">↻ Osveži</button>
      ${canManageUsers()
        ? `<button type="button" class="btn btn-primary" id="usersInviteBtn">+ Pozovi korisnika</button>`
        : ''}
      <span style="font-size:11px;color:var(--text3);align-self:center" id="usersCount">${n} ${n === 1 ? 'korisnik' : 'korisnika'}</span>
    </div>
    <div style="font-size:11px;color:var(--text3);margin:-6px 0 14px">
      Pozivnica kreira Auth nalog + ulogu. Menadžment: pododeljenja u formi (Kadrovska scope).
    </div>
  `;
}

function _filtered() {
  let items = usersState.items.slice();
  if (_filters.role) items = items.filter(u => u.role === _filters.role);
  if (_filters.status === 'active')   items = items.filter(u => u.isActive);
  else if (_filters.status === 'inactive') items = items.filter(u => !u.isActive);
  const q = String(_filters.search || '').trim().toLowerCase();
  if (q) {
    items = items.filter(u =>
      [u.email, u.fullName, u.team, ROLE_LABELS[u.role] || u.role]
        .map(v => String(v || '').toLowerCase())
        .some(v => v.includes(q))
    );
  }
  return items;
}

function _initials(name) {
  const parts = String(name || '').trim().split(/\s+/);
  return ((parts[0]?.[0] || '') + (parts[1]?.[0] || '')).toUpperCase() || '?';
}

function _avatarColor(str) {
  let h = 0;
  for (let i = 0; i < str.length; i++) h = (h * 31 + str.charCodeAt(i)) & 0xffff;
  return String(h % 6);
}

function _tableHtml() {
  const items = _filtered();
  if (!items.length) return _emptyHtml();

  const editable = canManageUsers();
  const projects = Array.isArray(allData?.projects) ? allData.projects : [];
  const projName = id => {
    const p = projects.find(x => x.id === id);
    return p ? (p.code || p.name || '—') : '—';
  };

  const rows = items.map(u => {
    const created  = u.createdAt ? new Date(u.createdAt).toLocaleDateString('sr-RS') : '—';
    const projLabel = u.projectId
      ? escHtml(projName(u.projectId))
      : `<span style="color:var(--text3)">Sve</span>`;
    const statusHtml = u.isActive
      ? `<span style="display:inline-flex;align-items:center;gap:5px;font-size:12px">
           <span style="width:7px;height:7px;border-radius:50%;background:#27AE60;flex-shrink:0"></span>
           <span style="color:#27AE60;font-weight:500">Aktivan</span>
         </span>`
      : `<span style="display:inline-flex;align-items:center;gap:5px;font-size:12px">
           <span style="width:7px;height:7px;border-radius:50%;background:var(--text3);flex-shrink:0"></span>
           <span style="color:var(--text3)">Neaktivan</span>
         </span>`;
    const actions = editable
      ? `<button class="kadr-action-btn" data-user-action="edit" data-user-id="${escHtml(u.id)}" title="Izmeni">✎</button>
         ${u.isActive
        ? `<button class="kadr-action-btn" data-user-action="deactivate" data-user-id="${escHtml(u.id)}" title="Deaktiviraj">⊘</button>`
        : `<button class="kadr-action-btn" data-user-action="activate" data-user-id="${escHtml(u.id)}" title="Aktiviraj">✓</button>`}
         <button class="kadr-action-btn kadr-action-danger" data-user-action="delete" data-user-id="${escHtml(u.id)}" title="Trajno obriši red">🗑</button>`
      : `<span style="color:var(--text3);font-size:11px">samo Admin</span>`;
    const initials = _initials(u.fullName);
    const avColor  = _avatarColor(u.email);
    return `<tr data-id="${escHtml(u.id)}">
      <td>
        <div style="display:flex;align-items:center;gap:10px">
          <span class="kadr-avatar" data-av="${avColor}">${escHtml(initials)}</span>
          <span>${escHtml(u.fullName || '—')}${u.mustChangePassword ? ' <span title="Mora promeniti lozinku" style="color:var(--yellow);font-size:11px">⚠</span>' : ''}</span>
        </div>
      </td>
      <td><span style="font-family:var(--mono);font-size:11px;color:var(--text2)">${escHtml(u.email)}</span></td>
      <td><span class="user-role-badge role-${escHtml(u.role)}">${escHtml(ROLE_LABELS[u.role] || u.role)}</span></td>
      <td class="col-hide-sm">${escHtml(u.team || '—')}</td>
      <td class="col-hide-sm">${projLabel}</td>
      <td>${statusHtml}</td>
      <td class="col-hide-sm" style="font-size:11px;color:var(--text3)">${escHtml(created)}</td>
      <td class="col-actions">${actions}</td>
    </tr>`;
  }).join('');

  return `
    <table class="kadrovska-table" id="usersTable">
      <thead>
        <tr>
          <th>Ime i prezime</th>
          <th>Email</th>
          <th>Uloga</th>
          <th class="col-hide-sm">Tim</th>
          <th class="col-hide-sm">Projekat</th>
          <th>Status</th>
          <th class="col-hide-sm">Dodato</th>
          <th class="col-actions">Akcije</th>
        </tr>
      </thead>
      <tbody id="usersTbody">${rows}</tbody>
    </table>
  `;
}

function _emptyHtml() {
  return `
    <div class="kadrovska-empty" id="usersEmpty" style="margin-top:16px;">
      <div class="kadrovska-empty-title">Nema dodeljenih uloga (ili nemaš pravo da ih vidiš)</div>
      <div style="margin-top:6px">Ako si <strong>Admin</strong>, listu treba da vidiš čim se RLS politika učita. Koristi dugme <strong>Pozovi korisnika</strong> iznad tabele:</div>
    </div>
  `;
}

function _rerenderTableAndSummary(root) {
  const main = root.querySelector('main.kadrovska-main');
  if (main) main.innerHTML = _tableHtml();
  const sum = root.querySelector('#usersSummary');
  if (sum) sum.innerHTML = _statsHtml();
  const cnt = root.querySelector('#usersCount');
  if (cnt) {
    const n = _filtered().length;
    cnt.textContent = n + ' ' + (n === 1 ? 'korisnik' : 'korisnika');
  }
  const badge = root.querySelector('#setSidebarBadge-users') || root.querySelector('#setTabCountUsers');
  if (badge) badge.textContent = String(usersState.items.length);
  _wireTbody(root);
}

/* ── INTERNAL: row actions ───────────────────────────────────────────── */

function _wireTbody(root) {
  root.querySelectorAll('[data-user-action]').forEach(btn => {
    btn.addEventListener('click', () => {
      const id     = btn.dataset.userId;
      const action = btn.dataset.userAction;
      if (action === 'edit') _openUserModal(id);
      else if (action === 'deactivate') _setUserActive(id, false);
      else if (action === 'activate') _setUserActive(id, true);
      else if (action === 'delete') _confirmDeleteUser(id);
    });
  });
}

/* ── INTERNAL: edit modal ────────────────────────────────────────────── */

function _openUserModal(id) {
  if (!canManageUsers()) { showToast('⚠ Samo Admin može da menja uloge'); return; }
  if (!id) { _openInviteModal(); return; }
  const u = usersState.items.find(x => x.id === id);
  if (!u) { showToast('⚠ Korisnik nije pronađen'); return; }

  _closeUserModal();
  const projects = Array.isArray(allData?.projects) ? allData.projects.slice() : [];
  projects.sort((a, b) => String(a.code || a.name || '').localeCompare(String(b.code || b.name || '')));
  const projOptions = ['<option value="">Sve / globalno</option>']
    .concat(projects.map(p => {
      const lbl = (p.code ? (p.code + ' — ') : '') + (p.name || '');
      const sel = String(u.projectId || '') === String(p.id) ? ' selected' : '';
      return `<option value="${escHtml(p.id)}"${sel}>${escHtml(lbl)}</option>`;
    })).join('');

  _modalEl = document.createElement('div');
  _modalEl.className = 'modal-overlay open';
  _modalEl.innerHTML = `
    <div class="modal-panel" role="dialog" aria-label="Izmeni ulogu">
      <div class="modal-head">
        <h3>Izmeni ulogu</h3>
        <button type="button" class="modal-close" data-um-action="close" aria-label="Zatvori">✕</button>
      </div>
      <div class="modal-body">
        <div class="form-grid">
          <label>Email<input type="email" id="umEmail" value="${escHtml(u.email)}" disabled></label>
          <label>Puno ime<input type="text" id="umFullName" value="${escHtml(u.fullName)}" placeholder="Ime Prezime"></label>
          <label>Tim<input type="text" id="umTeam" value="${escHtml(u.team)}" placeholder="npr. Tim Dobanovci"></label>
          <label>Uloga<select id="umRole">
            ${Object.entries(ROLE_LABELS).map(([k, v]) =>
              `<option value="${k}"${u.role === k ? ' selected' : ''}>${escHtml(v)}</option>`
            ).join('')}
          </select></label>
          <label>Projekat (opciono)<select id="umProject">${projOptions}</select></label>
          <label class="form-checkbox-row">
            <input type="checkbox" id="umIsActive" ${u.isActive ? 'checked' : ''}>
            <span>Nalog aktivan</span>
          </label>
          <div id="umSubDeptWrap" style="grid-column:1/-1;display:${u.role === 'menadzment' ? 'block' : 'none'}">
            <label>Pododeljenja (scope)
              <select id="umSubDepts" multiple size="6" class="form-input" style="min-height:110px;width:100%">
                ${_subDeptSelectOptions(u.managedSubDepartmentIds)}
              </select>
            </label>
          </div>
        </div>
        <div class="form-hint">Email se ne menja. Preferiraj deaktivaciju umesto brisanja.</div>
        <div id="umErr" class="form-hint" style="display:none;color:var(--red);font-weight:600"></div>
      </div>
      <div class="modal-foot">
        <button type="button" class="btn btn-ghost" data-um-action="close">Otkaži</button>
        <button type="button" class="btn btn-primary" id="umSubmitBtn">💾 Sačuvaj</button>
      </div>
    </div>
  `;
  document.body.appendChild(_modalEl);
  _modalEl.querySelectorAll('[data-um-action="close"]').forEach(b => b.addEventListener('click', _closeUserModal));
  _modalEl.addEventListener('click', ev => { if (ev.target === _modalEl) _closeUserModal(); });
  document.addEventListener('keydown', _onUmEsc);
  _modalEl.querySelector('#umSubmitBtn')?.addEventListener('click', () => _submitUserForm(id));
  const roleSel = _modalEl.querySelector('#umRole');
  const subWrap = _modalEl.querySelector('#umSubDeptWrap');
  roleSel?.addEventListener('change', () => {
    if (subWrap) subWrap.style.display = roleSel.value === 'menadzment' ? 'block' : 'none';
  });
  setTimeout(() => _modalEl?.querySelector('#umFullName')?.focus(), 50);
}

function _closeUserModal() {
  document.removeEventListener('keydown', _onUmEsc);
  if (_modalEl?.parentNode) _modalEl.parentNode.removeChild(_modalEl);
  _modalEl = null;
}

function _onUmEsc(ev) { if (ev.key === 'Escape') _closeUserModal(); }

async function _submitUserForm(id) {
  if (!canManageUsers()) { showToast('⚠ Samo Admin može da menja uloge'); return; }
  const errEl  = _modalEl?.querySelector('#umErr');
  const showErr = msg => { if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; } };

  const fullName  = String(_modalEl?.querySelector('#umFullName')?.value || '').trim();
  const team      = String(_modalEl?.querySelector('#umTeam')?.value || '').trim();
  const role      = String(_modalEl?.querySelector('#umRole')?.value || 'viewer').toLowerCase();
  const projectId = _modalEl?.querySelector('#umProject')?.value || null;
  const isActive  = !!_modalEl?.querySelector('#umIsActive')?.checked;

  if (!['admin', 'leadpm', 'pm', 'menadzment', 'hr', 'viewer'].includes(role)) { showErr('Neispravna uloga'); return; }
  const existing = usersState.items.find(x => x.id === id);
  if (!existing) { showErr('Korisnik više nije u listi — osveži pa probaj ponovo'); return; }

  const managedSubDepartmentIds = _readSubDeptSelection(_modalEl?.querySelector('#umSubDepts'));
  const payload = {
    id,
    email: existing.email,
    fullName,
    team,
    role,
    projectId,
    isActive,
    managedSubDepartmentIds: role === 'menadzment' ? managedSubDepartmentIds : null,
  };
  const btn = _modalEl?.querySelector('#umSubmitBtn');
  if (btn) { btn.disabled = true; btn.textContent = 'Snimanje…'; }
  try {
    if (getIsOnline() && hasSupabaseConfig()) {
      const res    = await saveUserToDb(payload);
      if (!res) { showErr('Supabase greška — proveri dozvole (admin RLS) ili konzolu'); return; }
      const saved  = Array.isArray(res) ? res[0] : res;
      const mapped = saved ? mapDbUser(saved) : null;
      if (mapped) {
        const ix = usersState.items.findIndex(x => x.id === id);
        if (ix !== -1) usersState.items[ix] = mapped;
      }
    } else {
      const ix = usersState.items.findIndex(x => x.id === id);
      if (ix !== -1) usersState.items[ix] = { ...usersState.items[ix], ...payload };
      showToast('⚠ Offline — sačuvano lokalno');
    }
    saveUsersCache(usersState.items);
    _closeUserModal();
    _onChangeRoot?.();
    showToast('✅ Sačuvano: ' + payload.email);
  } catch (e) {
    console.error('[users] save err', e);
    showErr('Greška — vidi konzolu');
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = '💾 Sačuvaj'; }
  }
}

async function _confirmDeleteUser(id) {
  if (!canManageUsers()) { showToast('⚠ Samo Admin'); return; }
  const u = usersState.items.find(x => x.id === id);
  if (!u) return;
  const cu = getCurrentUser();
  const myEmail = String(cu?.email || '').toLowerCase();
  if (String(u.email || '').toLowerCase() === myEmail && u.role === 'admin') {
    if (!confirm('UPOZORENJE: brišeš svoju admin ulogu! Posle toga nećeš moći da upravljaš korisnicima. Sigurno?')) return;
  } else {
    const typed = prompt(
      `Trajno brisanje reda za ${u.email}.\nPreporuka: koristi Deaktiviraj (⊘).\nZa potvrdu ukucaj email:`,
      '',
    );
    if (typed === null) return;
    if (String(typed).trim().toLowerCase() !== String(u.email).toLowerCase()) {
      showToast('⚠ Brisanje otkazano — email se ne poklapa');
      return;
    }
  }
  try {
    if (getIsOnline() && hasSupabaseConfig() && !String(id).startsWith('local_')) {
      const ok = await deleteUserRoleFromDb(id);
      if (!ok) { showToast('⚠ Supabase brisanje nije uspelo'); return; }
    }
    usersState.items = usersState.items.filter(x => x.id !== id);
    saveUsersCache(usersState.items);
    _onChangeRoot?.();
    showToast('🗑 Uloga obrisana');
  } catch (e) {
    console.error(e);
    showToast('⚠ Greška');
  }
}

async function _ensureSubDeptOptions() {
  if (_subDeptOptions.length) return;
  const [depts, subs] = await Promise.all([loadDepartments(), loadSubDepartments()]);
  const deptMap = new Map((depts || []).map(d => [d.id, d.name]));
  _subDeptOptions = (subs || []).map(s => ({
    id: s.id,
    name: s.name,
    department_id: s.department_id,
    deptName: deptMap.get(s.department_id) || '',
  }));
}

function _subDeptSelectOptions(selectedIds) {
  const sel = new Set((selectedIds || []).map(Number));
  if (!_subDeptOptions.length) {
    return '<option value="" disabled>Učitaj pododeljenja (Organizacija tab)…</option>';
  }
  return _subDeptOptions.map(o => {
    const label = (o.deptName ? o.deptName + ' → ' : '') + o.name;
    return `<option value="${o.id}"${sel.has(o.id) ? ' selected' : ''}>${escHtml(label)}</option>`;
  }).join('');
}

function _readSubDeptSelection(selectEl) {
  if (!selectEl) return null;
  const ids = [...selectEl.selectedOptions].map(o => Number(o.value)).filter(n => Number.isFinite(n));
  return ids.length ? ids : null;
}

async function _setUserActive(id, active) {
  if (!canManageUsers()) return;
  const u = usersState.items.find(x => x.id === id);
  if (!u) return;
  const verb = active ? 'aktivirati' : 'deaktivirati';
  if (!confirm(`${active ? 'Aktivirati' : 'Deaktivirati'} nalog ${u.email}?`)) return;
  const payload = { ...u, isActive: active };
  try {
    if (getIsOnline() && hasSupabaseConfig()) {
      const res = await saveUserToDb(payload);
      if (!res) { showToast('⚠ Snimanje nije uspelo'); return; }
      const saved = Array.isArray(res) ? res[0] : res;
      if (saved) {
        const ix = usersState.items.findIndex(x => x.id === id);
        if (ix !== -1) usersState.items[ix] = mapDbUser(saved);
      }
    } else {
      const ix = usersState.items.findIndex(x => x.id === id);
      if (ix !== -1) usersState.items[ix] = { ...usersState.items[ix], isActive: active };
    }
    saveUsersCache(usersState.items);
    _onChangeRoot?.();
    showToast(active ? '✅ Aktiviran' : '⊘ Deaktiviran');
  } catch (e) {
    console.error(e);
    showToast('⚠ Greška');
  }
}

async function _openInviteModal() {
  if (!canManageUsers()) { showToast('⚠ Samo Admin'); return; }
  _closeInviteModal();
  await _ensureSubDeptOptions().catch(() => {});

  _inviteModalEl = document.createElement('div');
  _inviteModalEl.className = 'modal-overlay open';
  _inviteModalEl.innerHTML = `
    <div class="modal-panel" role="dialog" aria-label="Pozovi korisnika">
      <div class="modal-head">
        <h3>Pozovi korisnika</h3>
        <button type="button" class="modal-close" data-inv-action="close">✕</button>
      </div>
      <div class="modal-body">
        <div class="form-grid">
          <label>Email *<input type="email" id="invEmail" placeholder="ime@servoteh.com"></label>
          <label>Puno ime<input type="text" id="invFullName"></label>
          <label>Tim<input type="text" id="invTeam"></label>
          <label>Uloga<select id="invRole">
            ${Object.entries(ROLE_LABELS).map(([k, v]) =>
              `<option value="${k}"${k === 'viewer' ? ' selected' : ''}>${escHtml(v)}</option>`,
            ).join('')}
          </select></label>
          <label>Lozinka (opciono)<input type="text" id="invPassword" placeholder="auto-generisana"></label>
          <div id="invSubDeptWrap" style="grid-column:1/-1;display:none">
            <label>Pododeljenja (menadžment)
              <select id="invSubDepts" multiple size="5" class="form-input" style="min-height:100px;width:100%">
                ${_subDeptSelectOptions(null)}
              </select>
            </label>
          </div>
        </div>
        <div id="invErr" class="form-hint" style="display:none;color:var(--red)"></div>
        <div id="invOk" class="form-hint" style="display:none;color:var(--green)"></div>
      </div>
      <div class="modal-foot">
        <button type="button" class="btn btn-ghost" data-inv-action="close">Otkaži</button>
        <button type="button" class="btn btn-primary" id="invSubmitBtn">Pošalji pozivnicu</button>
      </div>
    </div>
  `;

  document.body.appendChild(_inviteModalEl);
  _inviteModalEl.querySelectorAll('[data-inv-action="close"]').forEach(b =>
    b.addEventListener('click', _closeInviteModal),
  );
  _inviteModalEl.addEventListener('click', ev => { if (ev.target === _inviteModalEl) _closeInviteModal(); });
  _inviteModalEl.querySelector('#invRole')?.addEventListener('change', e => {
    const wrap = _inviteModalEl.querySelector('#invSubDeptWrap');
    if (wrap) wrap.style.display = e.target.value === 'menadzment' ? 'block' : 'none';
  });
  _inviteModalEl.querySelector('#invSubmitBtn')?.addEventListener('click', () => _submitInvite());
  setTimeout(() => _inviteModalEl?.querySelector('#invEmail')?.focus(), 50);
}

function _closeInviteModal() {
  if (_inviteModalEl?.parentNode) _inviteModalEl.parentNode.removeChild(_inviteModalEl);
  _inviteModalEl = null;
}

async function _submitInvite() {
  const errEl = _inviteModalEl?.querySelector('#invErr');
  const okEl = _inviteModalEl?.querySelector('#invOk');
  const showErr = msg => {
    if (errEl) { errEl.textContent = msg; errEl.style.display = 'block'; }
    if (okEl) okEl.style.display = 'none';
  };

  const email = String(_inviteModalEl?.querySelector('#invEmail')?.value || '').trim().toLowerCase();
  const fullName = String(_inviteModalEl?.querySelector('#invFullName')?.value || '').trim();
  const team = String(_inviteModalEl?.querySelector('#invTeam')?.value || '').trim();
  const role = String(_inviteModalEl?.querySelector('#invRole')?.value || 'viewer').toLowerCase();
  const password = String(_inviteModalEl?.querySelector('#invPassword')?.value || '').trim();
  const managedSubDepartmentIds = _readSubDeptSelection(_inviteModalEl?.querySelector('#invSubDepts'));

  if (!email.includes('@')) { showErr('Unesite ispravan email'); return; }

  const btn = _inviteModalEl?.querySelector('#invSubmitBtn');
  if (btn) { btn.disabled = true; btn.textContent = 'Šaljem…'; }

  const payload = {
    email,
    fullName,
    team,
    role,
    projectId: null,
    password: password || undefined,
    managedSubDepartmentIds: role === 'menadzment' ? managedSubDepartmentIds : null,
  };

  try {
    let result = await inviteUserViaEdge(payload);
    if (!result?.ok) {
      result = await inviteUserRoleViaRpc(payload);
    }
    if (!result?.ok) {
      showErr(result?.message || result?.error || 'Pozivnica nije uspela — proveri Edge funkciju ili Auth');
      return;
    }
    if (result.userRole) {
      usersState.items.push(result.userRole);
      saveUsersCache(usersState.items);
    } else {
      await refreshUsers(true);
    }
    let msg = `✅ Kreirano: ${email}`;
    if (result.temporaryPassword) {
      msg += ` · privremena lozinka: ${result.temporaryPassword}`;
    }
    if (okEl) {
      okEl.textContent = msg;
      okEl.style.display = 'block';
    }
    showToast(msg);
    _onChangeRoot?.();
    if (!result.temporaryPassword) _closeInviteModal();
  } catch (e) {
    console.error('[users] invite', e);
    showErr('Greška — vidi konzolu');
  } finally {
    if (btn) { btn.disabled = false; btn.textContent = 'Pošalji pozivnicu'; }
  }
}
