/**
 * CMMS IT oprema — specijalizovan prikaz za `maint_assets.asset_type = it`
 * + dodatna tabela `maint_it_asset_details`.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  fetchMaintAssets,
  fetchMaintItAssetDetails,
  patchMaintAsset,
  upsertMaintItAssetDetails,
} from '../../services/maintenance.js';
import { canManageMaintCatalog } from './maintCatalogTab.js';

const STATUS_LABELS = {
  running: 'Radi',
  degraded: 'Smetnje',
  down: 'Zastoj',
  maintenance: 'Održavanje',
};

function statusLabel(s) {
  return STATUS_LABELS[s] || s || '—';
}

function statusBadgeClass(s) {
  if (s === 'running') return 'mnt-badge mnt-badge--running';
  if (s === 'degraded') return 'mnt-badge mnt-badge--degraded';
  if (s === 'down') return 'mnt-badge mnt-badge--down';
  if (s === 'maintenance') return 'mnt-badge mnt-badge--maintenance';
  return 'mnt-badge';
}

function parseDate(v) {
  if (!v) return null;
  const d = new Date(String(v).slice(0, 10) + 'T00:00:00');
  return Number.isFinite(d.getTime()) ? d : null;
}

function daysUntil(v) {
  const d = parseDate(v);
  if (!d) return null;
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  return Math.round((d.getTime() - today.getTime()) / 86400000);
}

function dueLabel(v) {
  const days = daysUntil(v);
  if (days === null) return '—';
  if (days < 0) return `kasni ${Math.abs(days)} d`;
  if (days === 0) return 'danas';
  if (days === 1) return 'sutra';
  return `za ${days} d`;
}

function dueBadgeClass(v) {
  const days = daysUntil(v);
  if (days === null) return 'mnt-badge';
  if (days < 0) return 'mnt-badge mnt-badge--down';
  if (days <= 30) return 'mnt-badge mnt-badge--degraded';
  return 'mnt-badge mnt-badge--running';
}

function needsAttention(row) {
  const d = row.details || {};
  const licenseDays = daysUntil(d.license_expires_at);
  const warrantyDays = daysUntil(d.warranty_expires_at);
  const backupDays = d.last_backup_at ? daysUntil(d.last_backup_at) : null;
  return (licenseDays !== null && licenseDays <= 30)
    || (warrantyDays !== null && warrantyDays <= 30)
    || (d.backup_required && (!d.last_backup_at || backupDays < -7));
}

function readItForm(wrap) {
  const lastBackupRaw = wrap.querySelector('[name="last_backup_at"]')?.value || '';
  return {
    asset: {
      name: wrap.querySelector('[name="name"]')?.value?.trim() || '',
      status: wrap.querySelector('[name="status"]')?.value || 'running',
      manufacturer: wrap.querySelector('[name="manufacturer"]')?.value?.trim() || null,
      model: wrap.querySelector('[name="model"]')?.value?.trim() || null,
      serial_number: wrap.querySelector('[name="serial_number"]')?.value?.trim() || null,
      supplier: wrap.querySelector('[name="supplier"]')?.value?.trim() || null,
      notes: wrap.querySelector('[name="asset_notes"]')?.value?.trim() || null,
    },
    details: {
      device_type: wrap.querySelector('[name="device_type"]')?.value?.trim() || null,
      hostname: wrap.querySelector('[name="hostname"]')?.value?.trim() || null,
      ip_address: wrap.querySelector('[name="ip_address"]')?.value?.trim() || null,
      mac_address: wrap.querySelector('[name="mac_address"]')?.value?.trim() || null,
      operating_system: wrap.querySelector('[name="operating_system"]')?.value?.trim() || null,
      assigned_to: wrap.querySelector('[name="assigned_to"]')?.value?.trim() || null,
      license_key: wrap.querySelector('[name="license_key"]')?.value?.trim() || null,
      license_expires_at: wrap.querySelector('[name="license_expires_at"]')?.value || null,
      warranty_expires_at: wrap.querySelector('[name="warranty_expires_at"]')?.value || null,
      backup_required: !!wrap.querySelector('[name="backup_required"]')?.checked,
      last_backup_at: lastBackupRaw ? `${lastBackupRaw}:00` : null,
      notes: wrap.querySelector('[name="it_notes"]')?.value?.trim() || null,
    },
  };
}

function openItAssetModal({ row, prof, onSaved }) {
  const canEdit = canManageMaintCatalog(prof);
  if (!canEdit) {
    showToast('Nemaš ovlašćenje za izmenu IT opreme');
    return;
  }
  const d = row.details || {};
  const statusOpts = Object.entries(STATUS_LABELS).map(([k, v]) => `<option value="${escHtml(k)}"${row.status === k ? ' selected' : ''}>${escHtml(v)}</option>`).join('');
  const lastBackupValue = d.last_backup_at ? String(d.last_backup_at).slice(0, 16) : '';
  const wrap = document.createElement('div');
  wrap.className = 'kadr-modal-overlay';
  wrap.innerHTML = `<div class="kadr-modal" style="max-width:860px">
    <div class="kadr-modal-title">Detalji IT opreme</div>
    <div class="kadr-modal-subtitle"><code>${escHtml(row.asset_code || '')}</code> · ${escHtml(row.name || '')}</div>
    <div class="kadr-modal-err" id="mntItErr"></div>
    <form id="mntItForm">
      <div class="mnt-it-form-grid">
        <label class="form-label">Naziv *
          <input class="form-input" name="name" required value="${escHtml(row.name || '')}">
        </label>
        <label class="form-label">Status
          <select class="form-input" name="status">${statusOpts}</select>
        </label>
        <label class="form-label">Tip uređaja
          <input class="form-input" name="device_type" value="${escHtml(d.device_type || '')}" placeholder="laptop, desktop, server, printer…">
        </label>
        <label class="form-label">Hostname
          <input class="form-input" name="hostname" value="${escHtml(d.hostname || '')}">
        </label>
        <label class="form-label">IP adresa
          <input class="form-input" name="ip_address" value="${escHtml(d.ip_address || '')}">
        </label>
        <label class="form-label">MAC adresa
          <input class="form-input" name="mac_address" value="${escHtml(d.mac_address || '')}">
        </label>
        <label class="form-label">Operativni sistem
          <input class="form-input" name="operating_system" value="${escHtml(d.operating_system || '')}">
        </label>
        <label class="form-label">Zadužen / lokacija
          <input class="form-input" name="assigned_to" value="${escHtml(d.assigned_to || '')}">
        </label>
        <label class="form-label">Proizvođač
          <input class="form-input" name="manufacturer" value="${escHtml(row.manufacturer || '')}">
        </label>
        <label class="form-label">Model
          <input class="form-input" name="model" value="${escHtml(row.model || '')}">
        </label>
        <label class="form-label">Serijski broj
          <input class="form-input" name="serial_number" value="${escHtml(row.serial_number || '')}">
        </label>
        <label class="form-label">Dobavljač
          <input class="form-input" name="supplier" value="${escHtml(row.supplier || '')}">
        </label>
        <label class="form-label">Licenca / ključ
          <input class="form-input" name="license_key" value="${escHtml(d.license_key || '')}">
        </label>
        <label class="form-label">Licenca važi do
          <input class="form-input" name="license_expires_at" type="date" value="${escHtml(d.license_expires_at || '')}">
        </label>
        <label class="form-label">Garancija važi do
          <input class="form-input" name="warranty_expires_at" type="date" value="${escHtml(d.warranty_expires_at || row.warranty_until || '')}">
        </label>
        <label class="form-label">Poslednji backup
          <input class="form-input" name="last_backup_at" type="datetime-local" value="${escHtml(lastBackupValue)}">
        </label>
        <label class="mnt-wo-check mnt-it-form-full"><input type="checkbox" name="backup_required" ${d.backup_required ? 'checked' : ''}> Backup je obavezan za ovo sredstvo</label>
        <label class="form-label mnt-it-form-full">IT napomene
          <textarea class="form-input" name="it_notes" rows="2">${escHtml(d.notes || '')}</textarea>
        </label>
        <label class="form-label mnt-it-form-full">Napomene sredstva
          <textarea class="form-input" name="asset_notes" rows="2">${escHtml(row.notes || '')}</textarea>
        </label>
      </div>
      <div class="kadr-modal-actions" style="margin-top:16px">
        <button type="button" class="btn" id="mntItCancel" style="background:var(--surface3)">Otkaži</button>
        <button type="submit" class="btn">Sačuvaj</button>
      </div>
    </form>
  </div>`;
  document.body.appendChild(wrap);
  const close = () => wrap.remove();
  wrap.addEventListener('click', e => { if (e.target === wrap) close(); });
  wrap.querySelector('#mntItCancel')?.addEventListener('click', close);
  wrap.querySelector('#mntItForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const err = wrap.querySelector('#mntItErr');
    if (err) err.textContent = '';
    const payload = readItForm(wrap);
    if (!payload.asset.name) {
      if (err) err.textContent = 'Naziv je obavezan.';
      return;
    }
    const okAsset = await patchMaintAsset(row.asset_id, payload.asset);
    const detail = okAsset ? await upsertMaintItAssetDetails(row.asset_id, payload.details) : null;
    if (!okAsset || !detail) {
      if (err) err.textContent = 'Snimanje nije uspelo (RLS, duplikat hostname-a ili nevalidni podaci).';
      return;
    }
    showToast('IT oprema sačuvana');
    close();
    onSaved?.();
  });
}

function mergeItAssets(assets, details) {
  const byAsset = new Map(details.map(d => [d.asset_id, d]));
  return assets.map(a => ({ ...a, details: byAsset.get(a.asset_id) || null }));
}

/**
 * @param {HTMLElement} host
 * @param {{ prof: object|null }} opts
 */
export async function renderMaintItAssetsPanel(host, opts) {
  const canEdit = canManageMaintCatalog(opts.prof);
  const state = { q: new URLSearchParams(window.location.search).get('q') || '', attentionOnly: false };

  const load = async () => {
    host.innerHTML = `<div class="mnt-panel"><p class="mnt-muted">Učitavam IT opremu…</p></div>`;
    const assets = await fetchMaintAssets({ type: 'it', q: state.q, includeArchived: false, limit: 1000 });
    if (!Array.isArray(assets)) {
      host.innerHTML = `<div class="mnt-panel"><p class="mnt-muted">Ne mogu da učitam IT opremu. Proveri RLS ili migracije.</p></div>`;
      return;
    }
    const details = await fetchMaintItAssetDetails(assets.map(a => a.asset_id));
    render(mergeItAssets(assets, details));
  };

  const render = rowsAll => {
    const rows = state.attentionOnly ? rowsAll.filter(needsAttention) : rowsAll;
    const licenses = rowsAll.filter(r => {
      const days = daysUntil(r.details?.license_expires_at);
      return days !== null && days <= 30;
    }).length;
    const warranties = rowsAll.filter(r => {
      const days = daysUntil(r.details?.warranty_expires_at || r.warranty_until);
      return days !== null && days <= 30;
    }).length;
    const backups = rowsAll.filter(r => {
      const d = r.details || {};
      const backupDays = d.last_backup_at ? daysUntil(d.last_backup_at) : null;
      return d.backup_required && (!d.last_backup_at || backupDays < -7);
    }).length;
    const missing = rowsAll.filter(r => !r.details).length;
    const table = rows.map(r => {
      const d = r.details || {};
      const warranty = d.warranty_expires_at || r.warranty_until || '';
      const backupDays = d.last_backup_at ? daysUntil(d.last_backup_at) : null;
      const backupText = d.backup_required
        ? (d.last_backup_at ? `${Math.abs(backupDays ?? 0)} d ${backupDays < 0 ? 'od backup-a' : 'do datuma'}` : 'nema backup')
        : 'nije obavezan';
      return `<tr data-mnt-it-id="${escHtml(r.asset_id)}">
        <td><code>${escHtml(r.asset_code || '')}</code><div><strong>${escHtml(r.name || '')}</strong></div></td>
        <td>${escHtml(d.device_type || '—')}<div class="mnt-muted">${escHtml([r.manufacturer, r.model].filter(Boolean).join(' ') || '')}</div></td>
        <td>${escHtml(d.hostname || '—')}<div class="mnt-muted">${escHtml(d.ip_address || '')}</div></td>
        <td>${escHtml(d.assigned_to || '—')}<div class="mnt-muted">${escHtml(d.operating_system || '')}</div></td>
        <td><span class="${statusBadgeClass(r.status)}">${escHtml(statusLabel(r.status))}</span></td>
        <td><span class="${dueBadgeClass(d.license_expires_at)}">${escHtml(dueLabel(d.license_expires_at))}</span><div class="mnt-muted">${escHtml(d.license_expires_at || '—')}</div></td>
        <td><span class="${dueBadgeClass(warranty)}">${escHtml(dueLabel(warranty))}</span><div class="mnt-muted">${escHtml(warranty || '—')}</div></td>
        <td>${escHtml(backupText)}<div class="mnt-muted">${escHtml(d.last_backup_at ? String(d.last_backup_at).slice(0, 10) : '')}</div></td>
        <td>${canEdit ? '<button type="button" class="btn btn-xs" data-mnt-it-edit>Detalji</button>' : ''}</td>
      </tr>`;
    }).join('');

    host.innerHTML = `
      <div class="mnt-assets-head">
        <div>
          <h3 style="font-size:16px;margin:0 0 4px">IT oprema</h3>
          <p class="mnt-muted" style="margin:0">Specijalizovan pregled računara, servera, mrežne opreme, licenci, garancije i backup obaveza.</p>
        </div>
        <span class="mnt-muted">${rows.length} prikazano</span>
      </div>
      <div class="mnt-kpi-row">
        <button type="button" class="mnt-kpi ${licenses ? 'mnt-kpi--late' : 'mnt-kpi--zero'}" data-mnt-it-attention><span class="mnt-kpi-label">Licence ≤30d</span><span class="mnt-kpi-val">${licenses}</span></button>
        <button type="button" class="mnt-kpi ${warranties ? 'mnt-kpi--late' : 'mnt-kpi--zero'}" data-mnt-it-attention><span class="mnt-kpi-label">Garancije ≤30d</span><span class="mnt-kpi-val">${warranties}</span></button>
        <button type="button" class="mnt-kpi ${backups ? 'mnt-kpi--maintenance' : 'mnt-kpi--zero'}" data-mnt-it-attention><span class="mnt-kpi-label">Backup pažnja</span><span class="mnt-kpi-val">${backups}</span></button>
        <div class="mnt-kpi ${missing ? 'mnt-kpi--degraded' : 'mnt-kpi--zero'}"><span class="mnt-kpi-label">Bez detalja</span><span class="mnt-kpi-val">${missing}</span></div>
      </div>
      <div class="mnt-asset-toolbar">
        <input class="form-input" id="mntItSearch" type="search" placeholder="Pretraga IT opreme…" value="${escHtml(state.q)}">
        <label class="mnt-wo-check"><input type="checkbox" id="mntItAttentionOnly" ${state.attentionOnly ? 'checked' : ''}> Samo pažnja</label>
        <span class="mnt-muted">${rows.length} od ${rowsAll.length}</span>
      </div>
      <div class="mnt-table-wrap">
        <table class="mnt-table">
          <thead><tr><th>Sredstvo</th><th>Tip / model</th><th>Hostname / IP</th><th>Zadužen / OS</th><th>Status</th><th>Licenca</th><th>Garancija</th><th>Backup</th><th></th></tr></thead>
          <tbody>${table || '<tr><td colspan="9" class="mnt-muted">Nema IT opreme za prikaz.</td></tr>'}</tbody>
        </table>
      </div>`;

    let timer = 0;
    host.querySelector('#mntItSearch')?.addEventListener('input', e => {
      state.q = e.target.value || '';
      window.clearTimeout(timer);
      timer = window.setTimeout(load, 250);
    });
    host.querySelector('#mntItAttentionOnly')?.addEventListener('change', e => {
      state.attentionOnly = !!e.target.checked;
      render(rowsAll);
    });
    host.querySelectorAll('[data-mnt-it-attention]').forEach(btn => {
      btn.addEventListener('click', () => {
        state.attentionOnly = true;
        render(rowsAll);
      });
    });
    host.querySelectorAll('[data-mnt-it-edit]').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.closest('[data-mnt-it-id]')?.getAttribute('data-mnt-it-id');
        const row = rowsAll.find(r => String(r.asset_id) === String(id));
        if (row) openItAssetModal({ row, prof: opts.prof, onSaved: load });
      });
    });
  };

  await load();
}
