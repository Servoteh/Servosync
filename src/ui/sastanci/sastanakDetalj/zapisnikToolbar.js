import { escHtml } from '../../../lib/dom.js';

const TB_BUTTONS = [
  { cmd: 'undo', label: '↶', title: 'Undo' },
  { cmd: 'redo', label: '↷', title: 'Redo' },
  { sep: true },
  { cmd: 'bold', label: 'B', title: 'Bold', wrap: 'b' },
  { cmd: 'italic', label: 'I', title: 'Italic', wrap: 'i' },
  { cmd: 'underline', label: 'U', title: 'Underline', wrap: 'u' },
  { sep: true },
  { cmd: 'formatBlock', arg: 'h1', label: 'H1', title: 'Naslov 1' },
  { cmd: 'formatBlock', arg: 'h2', label: 'H2', title: 'Naslov 2' },
  { cmd: 'formatBlock', arg: 'h3', label: 'H3', title: 'Naslov 3' },
  { sep: true },
  { cmd: 'insertUnorderedList', label: '•', title: 'Lista' },
  { cmd: 'insertOrderedList', label: '1.', title: 'Numerisana lista' },
  { sep: true },
  { cmd: 'createLink', label: '🔗', title: 'Link' },
  { cmd: 'insertImage', label: '🖼', title: 'Slika (URL)' },
  { cmd: 'removeFormat', label: '✕', title: 'Ukloni format' },
];

export function renderZapisnikToolbarHtml() {
  return `
    <div class="zs-editor-toolbar zs-editor-toolbar--full" role="toolbar" aria-label="Formatiranje zapisnika">
      ${TB_BUTTONS.map(b => {
        if (b.sep) return '<span class="zs-tb-sep" aria-hidden="true"></span>';
        return `<button type="button" class="zs-tb" data-cmd="${escHtml(b.cmd)}"${b.arg ? ` data-arg="${escHtml(b.arg)}"` : ''} title="${escHtml(b.title)}">${b.label}</button>`;
      }).join('')}
    </div>
  `;
}

/**
 * @param {HTMLElement} toolbarEl
 * @param {HTMLElement} editorEl
 * @param {{ onChange?: () => void, onManualSave?: () => void }} [handlers]
 */
export function wireZapisnikToolbar(toolbarEl, editorEl, handlers = {}) {
  if (!toolbarEl || !editorEl) return;

  toolbarEl.querySelectorAll('.zs-tb').forEach(btn => {
    btn.addEventListener('mousedown', (e) => {
      e.preventDefault();
      editorEl.focus();
      const cmd = btn.dataset.cmd;
      const arg = btn.dataset.arg;

      if (cmd === 'createLink') {
        const url = window.prompt('URL linka (https://…)');
        if (url) document.execCommand('createLink', false, url);
      } else if (cmd === 'insertImage') {
        const url = window.prompt('URL slike (https://…)');
        if (url) document.execCommand('insertImage', false, url);
      } else if (cmd === 'formatBlock' && arg) {
        document.execCommand('formatBlock', false, arg);
      } else {
        document.execCommand(cmd, false, arg || null);
      }
      editorEl.dispatchEvent(new Event('input', { bubbles: true }));
      handlers.onChange?.();
    });
  });

  const onKey = (e) => {
    if (!editorEl.contains(document.activeElement) && document.activeElement !== editorEl) return;
    if (!(e.ctrlKey || e.metaKey)) {
      if (e.key === 'Escape') {
        editorEl.blur();
        e.preventDefault();
      }
      return;
    }
    const k = e.key.toLowerCase();
    if (k === 's') {
      e.preventDefault();
      handlers.onManualSave?.();
    } else if (k === 'b') {
      e.preventDefault();
      document.execCommand('bold');
      handlers.onChange?.();
    } else if (k === 'i') {
      e.preventDefault();
      document.execCommand('italic');
      handlers.onChange?.();
    } else if (k === 'u') {
      e.preventDefault();
      document.execCommand('underline');
      handlers.onChange?.();
    }
  };

  document.addEventListener('keydown', onKey);
  return () => document.removeEventListener('keydown', onKey);
}
