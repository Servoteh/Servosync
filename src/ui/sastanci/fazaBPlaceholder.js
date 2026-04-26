/**
 * Placeholder dok se u Fazi B ne uradi pun detalj sastanka.
 */
export function openFazaBPlaceholderModal(akcija = 'Detalj') {
  const overlay = document.createElement('div');
  overlay.className = 'sast-modal-overlay';
  overlay.innerHTML = `
    <div class="sast-modal sast-modal--narrow" role="dialog" aria-modal="true">
      <header class="sast-modal-header">
        <h3>${akcija}</h3>
        <button type="button" class="sast-modal-close" aria-label="Zatvori">✕</button>
      </header>
      <div class="sast-modal-body">
        <p class="sast-fazab-msg">Detalj sastanka u Fazi B (zapisnik, presek stanja, itd.).</p>
      </div>
      <footer class="sast-modal-footer">
        <button type="button" class="btn btn-primary" data-action="ok">Razumem</button>
      </footer>
    </div>
  `;
  document.body.appendChild(overlay);
  const close = () => overlay.remove();
  overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });
  overlay.querySelector('.sast-modal-close')?.addEventListener('click', close);
  overlay.querySelector('[data-action=ok]')?.addEventListener('click', close);
}
