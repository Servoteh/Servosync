import { openTemplatesModal } from './templatesModal.js';

let opened = false;

export async function renderSabloniTab(host, { canEdit }) {
  host.innerHTML = `
    <div class="sast-section">
      <p class="sast-sabloni-intro">Upravljanje šablonima za brzo kreiranje sastanaka.</p>
      ${canEdit ? '<button type="button" class="btn btn-primary" id="sastOpenTplTab">Otvori šablone</button>' : '<p class="sast-empty">Samo čitanje.</p>'}
    </div>
  `;
  if (canEdit) {
    host.querySelector('#sastOpenTplTab')?.addEventListener('click', () => {
      openTemplatesModal({ canEdit: true, onInstantiated: () => {} });
    });
    if (!opened) {
      opened = true;
      openTemplatesModal({ canEdit: true, onInstantiated: () => {} });
    }
  }
}

export function teardownSabloniTab() {
  opened = false;
}
