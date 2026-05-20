import { getCurrentUser, isAdmin } from '../../state/auth.js';
import { loadPbState, savePbState } from './shared.js';

export function pbTipModalShell(title) {
  const mobile = window.matchMedia('(max-width: 767px)').matches;
  const cls = mobile ? 'modal-overlay open pb-modal pb-modal--sheet' : 'modal-overlay open pb-modal';
  return { cls, mobile };
}

export function wirePbTipModal(wrap, panelSelector) {
  const panel = wrap.querySelector(panelSelector);
  const close = () => wrap.remove();
  wrap.addEventListener('click', e => {
    if (e.target === wrap) close();
  });
  wrap.querySelectorAll('.pb-close-modal').forEach(btn => btn.addEventListener('click', close));
  const onKey = e => {
    if (e.key === 'Escape') {
      close();
      document.removeEventListener('keydown', onKey);
    }
  };
  document.addEventListener('keydown', onKey);
  return { close, panel };
}

export function canManageEngTip(tip) {
  if (!tip) return false;
  if (isAdmin()) return true;
  const me = String(getCurrentUser()?.email || '').toLowerCase();
  const ae = String(tip.author_email || tip.author?.email || '').toLowerCase();
  return !!me && !!ae && me === ae;
}

export function formatTipDate(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleString('sr-RS', { dateStyle: 'medium', timeStyle: 'short' });
}

export async function navigatePbToProject(projectId, onClose) {
  if (!projectId) return;
  const s = loadPbState();
  s.activeTab = 'plan';
  s.activeProject = projectId;
  savePbState(s);
  onClose?.();
  const { navigateToAppPath } = await import('../router.js');
  navigateToAppPath('/projektni-biro');
}
