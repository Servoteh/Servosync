/**
 * Podešavanja notifikacija — 7. tab modula Sastanci.
 *
 * Korisnik može da uključi/isključi svaki od 6 tipova notifikacija.
 * Prefs se čuvaju u sastanci_notification_prefs (per-user).
 * WhatsApp toggle prikazan ali disabled (Faza C ograničenje).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { getCurrentUser } from '../../state/auth.js';
import { getMyPrefs, updateMyPrefs } from '../../services/sastanciPrefs.js';

let abortFlag = false;

export async function renderPodesavanjaNotifikacijaTab(host) {
  abortFlag = false;
  host.innerHTML = '<div class="sast-loading">Učitavam podešavanja…</div>';

  let prefs;
  try {
    prefs = await getMyPrefs();
  } catch (e) {
    console.error('[PodesavanjaNotif] load error', e);
  }

  if (abortFlag) return;

  if (!prefs) {
    host.innerHTML = `
      <div class="sast-arhiva-empty">
        <p>⚠ Nije moguće učitati podešavanja. Proveri konekciju.</p>
        <button type="button" class="btn" id="snpRetry">Pokušaj ponovo</button>
      </div>
    `;
    host.querySelector('#snpRetry')?.addEventListener('click', () => {
      renderPodesavanjaNotifikacijaTab(host);
    });
    return;
  }

  render(host, prefs);
}

function render(host, prefs) {
  const cu = getCurrentUser();
  const email = cu?.email || '—';

  host.innerHTML = `
    <div class="sast-prefs-wrap">
      <div class="sast-prefs-header">
        <h2 class="sast-prefs-title">Notifikacije</h2>
        <p class="sast-txt2">
          Izaberi koje notifikacije želiš da primaš putem email-a.
        </p>
      </div>

      <div class="sast-prefs-email-row">
        <span class="sast-prefs-email-label">📧 Notifikacije se šalju na:</span>
        <strong>${escHtml(email)}</strong>
      </div>

      <form class="sast-prefs-form" id="snpForm">

        <fieldset class="sast-prefs-fieldset">
          <legend class="sast-prefs-legend">Akcije</legend>

          ${toggle('on_new_akcija', 'Nova akcija dodeljena meni',
            'Primam email kada mi je dodeljena nova akcija.', prefs.on_new_akcija)}
          ${toggle('on_change_akcija', 'Promena moje akcije',
            'Primam email kada se promeni rok, status ili odgovorna osoba na mojoj akciji.', prefs.on_change_akcija)}
          ${toggle('on_action_reminder', 'Dnevni podsetnik za rokove',
            'Primam email svakog jutra (07:00) za akcije kojima uskoro ističe rok.', prefs.on_action_reminder)}
        </fieldset>

        <fieldset class="sast-prefs-fieldset">
          <legend class="sast-prefs-legend">Sastanci</legend>

          ${toggle('on_meeting_invite', 'Pozivnica na sastanak',
            'Primam email kada me neko pozove na sastanak.', prefs.on_meeting_invite)}
          ${toggle('on_meeting_locked', 'Sastanak zaključan',
            'Primam email kada je zapisnik finalizovan i PDF je dostupan za preuzimanje.', prefs.on_meeting_locked)}
          ${toggle('on_meeting_reminder', 'Podsetnik 24h pre sastanka',
            'Primam email dan pre zakazanog sastanka.', prefs.on_meeting_reminder)}
        </fieldset>

        <fieldset class="sast-prefs-fieldset sast-prefs-fieldset--disabled">
          <legend class="sast-prefs-legend">
            Drugi kanali
            <span class="sast-prefs-soon">Uskoro</span>
          </legend>

          <div class="sast-prefs-toggle-row sast-prefs-toggle-row--disabled">
            <div class="sast-prefs-toggle-info">
              <span class="sast-prefs-toggle-label">WhatsApp</span>
              <span class="sast-prefs-toggle-desc">
                Uskoro — čekamo odobrenje Meta Business naloga.
              </span>
            </div>
            <label class="sast-toggle" title="Nije dostupno u ovoj verziji">
              <input type="checkbox" disabled aria-label="WhatsApp obaveštenja — nije dostupno">
              <span class="sast-toggle-track"></span>
            </label>
          </div>
        </fieldset>

        <div class="sast-prefs-footer">
          <button type="submit" class="btn btn-primary" id="snpSave">Sačuvaj podešavanja</button>
          <span class="sast-prefs-saved" id="snpSavedMsg" aria-live="polite"></span>
        </div>

      </form>
    </div>
  `;

  host.querySelector('#snpForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const btn = host.querySelector('#snpSave');
    const msg = host.querySelector('#snpSavedMsg');
    if (btn) btn.disabled = true;

    const patch = {};
    [
      'on_new_akcija', 'on_change_akcija', 'on_action_reminder',
      'on_meeting_invite', 'on_meeting_locked', 'on_meeting_reminder',
    ].forEach(key => {
      const el = host.querySelector(`[name="${key}"]`);
      if (el) patch[key] = el.checked;
    });

    const updated = await updateMyPrefs(patch);
    if (btn) btn.disabled = false;

    if (updated) {
      if (msg) {
        msg.textContent = '✅ Sačuvano';
        setTimeout(() => { if (msg) msg.textContent = ''; }, 3000);
      }
      showToast('✅ Podešavanja notifikacija su sačuvana');
    } else {
      showToast('⚠ Čuvanje nije uspelo. Pokušaj ponovo.');
    }
  });
}

function toggle(name, label, desc, checked) {
  return `
    <div class="sast-prefs-toggle-row">
      <div class="sast-prefs-toggle-info">
        <span class="sast-prefs-toggle-label">${escHtml(label)}</span>
        <span class="sast-prefs-toggle-desc">${escHtml(desc)}</span>
      </div>
      <label class="sast-toggle" title="${escHtml(label)}">
        <input type="checkbox" name="${name}" ${checked ? 'checked' : ''} aria-label="${escHtml(label)}">
        <span class="sast-toggle-track"></span>
      </label>
    </div>
  `;
}

export function teardownPodesavanjaNotifikacijaTab() {
  abortFlag = true;
}
