/**
 * CMMS podešavanja — centralna pravila za SLA, auto-WO i notifikacije.
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  fetchMaintNotificationRules,
  fetchMaintSettings,
  insertMaintNotificationRule,
  patchMaintNotificationRule,
  patchMaintSettings,
} from '../../services/maintenance.js';
import { canManageMaintCatalog } from './maintCatalogTab.js';

const PRIORITIES = [
  ['p1_zastoj', 'P1 zastoj'],
  ['p2_smetnja', 'P2 smetnja'],
  ['p3_manje', 'P3 manje'],
  ['p4_planirano', 'P4 planirano'],
];

const CHANNELS = [
  ['in_app', 'In-app'],
  ['email', 'Email'],
  ['telegram', 'Telegram'],
  ['whatsapp', 'WhatsApp'],
];

const ROLES = [
  ['', '—'],
  ['operator', 'Operator'],
  ['technician', 'Tehničar'],
  ['chief', 'Šef'],
  ['management', 'Menadžment'],
  ['admin', 'Admin'],
];

const SEVERITIES = [
  ['', 'Sve'],
  ['minor', 'Minor'],
  ['major', 'Major'],
  ['critical', 'Critical'],
];

const ASSET_TYPES = [
  ['', 'Sva sredstva'],
  ['machine', 'Mašina'],
  ['vehicle', 'Vozilo'],
  ['it', 'IT'],
  ['facility', 'Objekat'],
];

function bool(v) {
  return v === true;
}

function intOrDefault(v, fallback) {
  const n = Number(v);
  return Number.isFinite(n) ? Math.max(0, Math.round(n)) : fallback;
}

function readSettingsForm(host) {
  const channelInputs = [...host.querySelectorAll('[name="notification_channels"]:checked')];
  return {
    auto_create_wo_major: !!host.querySelector('[name="auto_create_wo_major"]')?.checked,
    auto_create_wo_critical: !!host.querySelector('[name="auto_create_wo_critical"]')?.checked,
    safety_marker_requires_wo: !!host.querySelector('[name="safety_marker_requires_wo"]')?.checked,
    default_wo_priority: host.querySelector('[name="default_wo_priority"]')?.value || 'p4_planirano',
    major_wo_due_hours: intOrDefault(host.querySelector('[name="major_wo_due_hours"]')?.value, 48),
    critical_wo_due_hours: intOrDefault(host.querySelector('[name="critical_wo_due_hours"]')?.value, 8),
    preventive_due_warning_days: intOrDefault(host.querySelector('[name="preventive_due_warning_days"]')?.value, 7),
    notification_enabled: !!host.querySelector('[name="notification_enabled"]')?.checked,
    notify_on_major_incident: !!host.querySelector('[name="notify_on_major_incident"]')?.checked,
    notify_on_critical_incident: !!host.querySelector('[name="notify_on_critical_incident"]')?.checked,
    notify_on_overdue_preventive: !!host.querySelector('[name="notify_on_overdue_preventive"]')?.checked,
    notification_channels: channelInputs.map(x => x.value),
    notes: host.querySelector('[name="notes"]')?.value?.trim() || null,
  };
}

function priorityOptions(value) {
  return PRIORITIES.map(([v, l]) => `<option value="${escHtml(v)}"${value === v ? ' selected' : ''}>${escHtml(l)}</option>`).join('');
}

function channelChecks(values, disabled) {
  const selected = new Set(Array.isArray(values) ? values : []);
  return CHANNELS.map(([v, l]) => `
    <label class="mnt-wo-check">
      <input type="checkbox" name="notification_channels" value="${escHtml(v)}" ${selected.has(v) ? 'checked' : ''} ${disabled ? 'disabled' : ''}>
      ${escHtml(l)}
    </label>`).join('');
}

function selectOptions(list, selected) {
  return list.map(([v, l]) => `<option value="${escHtml(v)}"${String(selected || '') === v ? ' selected' : ''}>${escHtml(l)}</option>`).join('');
}

function ruleRows(rules, canEdit) {
  return (rules || []).map(r => `<tr data-mnt-rule-id="${escHtml(r.rule_id)}">
    <td>${escHtml(r.event_type || '')}<div class="mnt-muted">${escHtml(r.enabled ? 'aktivno' : 'isključeno')}</div></td>
    <td>${escHtml(r.severity || 'sve')}<div class="mnt-muted">${escHtml(r.asset_type || 'sva sredstva')}</div></td>
    <td>${escHtml(r.target_role || '—')}</td>
    <td>${escHtml(r.channel || '')}</td>
    <td>${escHtml(String(r.delay_minutes ?? 0))} min<div class="mnt-muted">L${escHtml(String(r.escalation_level ?? 0))}</div></td>
    <td>${escHtml(r.notes || '')}</td>
    <td>${canEdit ? `<button type="button" class="btn btn-xs" data-mnt-rule-toggle>${r.enabled ? 'Isključi' : 'Uključi'}</button>` : ''}</td>
  </tr>`).join('');
}

/**
 * @param {HTMLElement} host
 * @param {{ prof: object|null }} opts
 */
export async function renderMaintSettingsPanel(host, opts) {
  const canEdit = canManageMaintCatalog(opts.prof);
  host.innerHTML = `<div class="mnt-panel"><p class="mnt-muted">Učitavam podešavanja…</p></div>`;
  const [settings, rules] = await Promise.all([
    fetchMaintSettings(),
    fetchMaintNotificationRules(),
  ]);
  if (!settings) {
    host.innerHTML = `<div class="mnt-panel"><p class="mnt-muted">Podešavanja nisu dostupna. Proveri migraciju ili RLS.</p></div>`;
    return;
  }

  const disabled = canEdit ? '' : 'disabled';
  host.innerHTML = `
    <div class="mnt-assets-head">
      <div>
        <h3 style="font-size:16px;margin:0 0 4px">Podešavanja održavanja</h3>
        <p class="mnt-muted" style="margin:0">Centralna CMMS pravila za auto radne naloge, SLA pragove i notifikacije.</p>
      </div>
      <span class="mnt-muted">Ažurirano: ${escHtml(String(settings.updated_at || '').slice(0, 16).replace('T', ' ') || '—')}</span>
    </div>

    <form id="mntSettingsForm" class="mnt-settings-form">
      <div class="mnt-settings-grid">
        <section class="mnt-panel">
          <h3 style="font-size:15px;margin:0 0 10px">Radni nalozi i SLA</h3>
          <label class="mnt-wo-check"><input type="checkbox" name="auto_create_wo_major" ${bool(settings.auto_create_wo_major) ? 'checked' : ''} ${disabled}> Auto WO za major incidente</label>
          <label class="mnt-wo-check"><input type="checkbox" name="auto_create_wo_critical" ${bool(settings.auto_create_wo_critical) ? 'checked' : ''} ${disabled}> Auto WO za critical incidente</label>
          <label class="mnt-wo-check"><input type="checkbox" name="safety_marker_requires_wo" ${bool(settings.safety_marker_requires_wo) ? 'checked' : ''} ${disabled}> Safety marker uvek traži WO</label>
          <div class="mnt-settings-two">
            <label class="form-label">Default prioritet WO
              <select class="form-input" name="default_wo_priority" ${disabled}>${priorityOptions(settings.default_wo_priority || 'p4_planirano')}</select>
            </label>
            <label class="form-label">Preventiva upozorenje dana
              <input class="form-input" name="preventive_due_warning_days" type="number" min="0" step="1" value="${escHtml(settings.preventive_due_warning_days ?? 7)}" ${disabled}>
            </label>
            <label class="form-label">Major SLA sati
              <input class="form-input" name="major_wo_due_hours" type="number" min="1" step="1" value="${escHtml(settings.major_wo_due_hours ?? 48)}" ${disabled}>
            </label>
            <label class="form-label">Critical SLA sati
              <input class="form-input" name="critical_wo_due_hours" type="number" min="1" step="1" value="${escHtml(settings.critical_wo_due_hours ?? 8)}" ${disabled}>
            </label>
          </div>
        </section>

        <section class="mnt-panel">
          <h3 style="font-size:15px;margin:0 0 10px">Notifikacije</h3>
          <label class="mnt-wo-check"><input type="checkbox" name="notification_enabled" ${bool(settings.notification_enabled) ? 'checked' : ''} ${disabled}> Notifikacije uključene</label>
          <label class="mnt-wo-check"><input type="checkbox" name="notify_on_major_incident" ${bool(settings.notify_on_major_incident) ? 'checked' : ''} ${disabled}> Major incident</label>
          <label class="mnt-wo-check"><input type="checkbox" name="notify_on_critical_incident" ${bool(settings.notify_on_critical_incident) ? 'checked' : ''} ${disabled}> Critical incident</label>
          <label class="mnt-wo-check"><input type="checkbox" name="notify_on_overdue_preventive" ${bool(settings.notify_on_overdue_preventive) ? 'checked' : ''} ${disabled}> Kašnjenje preventive</label>
          <div class="mnt-settings-channels">${channelChecks(settings.notification_channels, !canEdit)}</div>
        </section>
      </div>

      <section class="mnt-panel" style="margin-top:12px">
        <h3 style="font-size:15px;margin:0 0 10px">Status šabloni</h3>
        <div class="mnt-settings-statuses">
          ${Object.entries(settings.status_labels || {}).map(([k, v]) => `<div><code>${escHtml(k)}</code><span>${escHtml(String(v))}</span></div>`).join('')}
          ${Object.entries(settings.wo_status_labels || {}).map(([k, v]) => `<div><code>WO ${escHtml(k)}</code><span>${escHtml(String(v))}</span></div>`).join('')}
        </div>
        <p class="mnt-muted" style="margin:10px 0 0">Status šabloni se za sada čuvaju kao centralna referenca; promena labela ide u sledećem koraku kada ih povežemo kroz sve postojeće panele.</p>
      </section>

      <section class="mnt-panel" style="margin-top:12px">
        <div class="mnt-att-head">
          <h3 style="font-size:15px;margin:0">Pravila eskalacije</h3>
          <span class="mnt-muted">${rules.length} pravila</span>
        </div>
        <div class="mnt-table-wrap" style="margin-top:10px">
          <table class="mnt-table">
            <thead><tr><th>Događaj</th><th>Filter</th><th>Uloga</th><th>Kanal</th><th>Kašnjenje</th><th>Napomena</th><th></th></tr></thead>
            <tbody>${ruleRows(rules, canEdit) || '<tr><td colspan="7" class="mnt-muted">Nema pravila.</td></tr>'}</tbody>
          </table>
        </div>
        ${canEdit ? `<div class="mnt-settings-rule-form">
          <select class="form-input" name="rule_severity">${selectOptions(SEVERITIES, 'major')}</select>
          <select class="form-input" name="rule_asset_type">${selectOptions(ASSET_TYPES, '')}</select>
          <select class="form-input" name="rule_target_role">${selectOptions(ROLES, 'chief')}</select>
          <select class="form-input" name="rule_channel">${selectOptions(CHANNELS, 'in_app')}</select>
          <input class="form-input" name="rule_delay_minutes" type="number" min="0" step="1" value="0" placeholder="min">
          <button type="button" class="btn btn-xs" id="mntRuleAdd">Dodaj pravilo</button>
        </div>` : ''}
      </section>

      <section class="mnt-panel" style="margin-top:12px">
        <label class="form-label">Napomena za pravila održavanja
          <textarea class="form-input" name="notes" rows="3" ${disabled}>${escHtml(settings.notes || '')}</textarea>
        </label>
      </section>

      <div class="kadr-modal-err" id="mntSettingsErr"></div>
      <div style="display:flex;align-items:center;gap:10px;margin-top:12px">
        ${canEdit ? '<button type="submit" class="btn" id="mntSettingsSave">Sačuvaj podešavanja</button>' : ''}
        <span class="mnt-muted">${canEdit ? 'Izmene su dostupne šefu/adminu održavanja i ERP menadžmentu.' : 'Nemaš ovlašćenje za izmenu podešavanja.'}</span>
      </div>
    </form>`;

  if (!canEdit) return;
  host.querySelectorAll('[data-mnt-rule-toggle]').forEach(btn => {
    btn.addEventListener('click', async () => {
      const id = btn.closest('[data-mnt-rule-id]')?.getAttribute('data-mnt-rule-id');
      const rule = rules.find(r => String(r.rule_id) === String(id));
      if (!id || !rule) return;
      btn.disabled = true;
      const ok = await patchMaintNotificationRule(id, { enabled: !rule.enabled });
      if (!ok) showToast('Snimanje pravila nije uspelo');
      await renderMaintSettingsPanel(host, opts);
    });
  });
  host.querySelector('#mntRuleAdd')?.addEventListener('click', async () => {
    const payload = {
      event_type: 'incident_created',
      severity: host.querySelector('[name="rule_severity"]')?.value || null,
      asset_type: host.querySelector('[name="rule_asset_type"]')?.value || null,
      target_role: host.querySelector('[name="rule_target_role"]')?.value || null,
      channel: host.querySelector('[name="rule_channel"]')?.value || 'in_app',
      delay_minutes: intOrDefault(host.querySelector('[name="rule_delay_minutes"]')?.value, 0),
      escalation_level: 0,
      enabled: true,
    };
    const row = await insertMaintNotificationRule(payload);
    if (!row) {
      showToast('Dodavanje pravila nije uspelo');
      return;
    }
    showToast('Pravilo dodato');
    await renderMaintSettingsPanel(host, opts);
  });
  host.querySelector('#mntSettingsForm')?.addEventListener('submit', async e => {
    e.preventDefault();
    const err = host.querySelector('#mntSettingsErr');
    if (err) err.textContent = '';
    const payload = readSettingsForm(host);
    if (payload.major_wo_due_hours <= 0 || payload.critical_wo_due_hours <= 0) {
      if (err) err.textContent = 'SLA sati moraju biti veći od nule.';
      return;
    }
    const btn = host.querySelector('#mntSettingsSave');
    if (btn) btn.disabled = true;
    const saved = await patchMaintSettings(payload).catch(() => null);
    if (btn) btn.disabled = false;
    if (!saved) {
      if (err) err.textContent = 'Snimanje nije uspelo (RLS ili nevalidna podešavanja).';
      return;
    }
    showToast('Podešavanja održavanja sačuvana');
    await renderMaintSettingsPanel(host, opts);
  });
}
