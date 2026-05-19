/**
 * REVERSI punoekranski skener (shell kao lokacije/scanModal.js).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import { normalizeBarcodeText } from '../../lib/barcodeParse.js';
import {
  startScan,
  stopScan,
  isAndroidWebCameraTorchZoomHidden,
  isAndroidChromeBrowser,
  isAndroidWebPlatform,
} from '../../services/barcode.js';
import {
  fetchHandToolByBarcode,
  fetchCuttingToolByBarcode,
  fetchEmployeeByCardBarcode,
} from '../../services/reversiService.js';

const OVERLAY_ID = 'revScanOverlayRoot';

function debounce(fn, ms) {
  let t = null;
  return (...args) => {
    clearTimeout(t);
    t = setTimeout(() => fn(...args), ms);
  };
}

function isIOSWebPlatform() {
  if (typeof navigator === 'undefined') return false;
  const ua = navigator.userAgent || '';
  if (/iPad|iPhone|iPod/i.test(ua)) return true;
  return ua.includes('Mac') && typeof document !== 'undefined' && 'ontouchend' in document;
}

function bindIOSVisualViewportFix(overlayEl) {
  const vv = window.visualViewport;
  if (!vv || !overlayEl) return () => {};
  const apply = () => {
    overlayEl.style.position = 'fixed';
    overlayEl.style.top = `${vv.offsetTop}px`;
    overlayEl.style.left = `${vv.offsetLeft}px`;
    overlayEl.style.width = `${vv.width}px`;
    overlayEl.style.height = `${vv.height}px`;
    overlayEl.style.right = 'auto';
    overlayEl.style.bottom = 'auto';
  };
  apply();
  vv.addEventListener('resize', apply);
  vv.addEventListener('scroll', apply);
  return () => {
    vv.removeEventListener('resize', apply);
    vv.removeEventListener('scroll', apply);
    for (const k of ['top', 'left', 'width', 'height', 'right', 'bottom']) {
      overlayEl.style.removeProperty(k);
    }
  };
}

async function forceAppReload() {
  try {
    if ('serviceWorker' in navigator) {
      const regs = await navigator.serviceWorker.getRegistrations();
      await Promise.all(regs.map((r) => r.unregister().catch(() => {})));
    }
  } catch {
    /* ignore */
  }
  try {
    if ('caches' in window) {
      const names = await caches.keys();
      await Promise.all(names.map((n) => caches.delete(n).catch(() => {})));
    }
  } catch {
    /* ignore */
  }
  const url = new URL(window.location.href);
  url.searchParams.set('_r', String(Date.now()));
  window.location.replace(url.toString());
}

/**
 * @param {string} raw
 * @returns {Promise<{ kind: 'HAND'|'CUTTING'|'EMPLOYEE'|'UNKNOWN', barcode: string, data: object|null }>}
 */
export async function resolveReversiBarcode(raw) {
  const barcode = normalizeBarcodeText(String(raw || '')).trim();
  if (!barcode) return { kind: 'UNKNOWN', barcode: '', data: null };

  if (/^ALAT-\d{6}$/i.test(barcode)) {
    const r = await fetchHandToolByBarcode(barcode);
    if (r.ok && r.data) return { kind: 'HAND', barcode, data: r.data };
    return { kind: 'HAND', barcode, data: null };
  }

  if (/^RZN-\d{6}$/i.test(barcode)) {
    const r = await fetchCuttingToolByBarcode(barcode);
    if (r.ok && r.data) return { kind: 'CUTTING', barcode, data: r.data };
    return { kind: 'CUTTING', barcode, data: null };
  }

  if (/^[A-Z0-9]{4,16}$/i.test(barcode) && !/^ALAT-/i.test(barcode) && !/^RZN-/i.test(barcode)) {
    const r = await fetchEmployeeByCardBarcode(barcode);
    if (r.ok && r.data) return { kind: 'EMPLOYEE', barcode, data: r.data };
    return { kind: 'EMPLOYEE', barcode, data: null };
  }

  return { kind: 'UNKNOWN', barcode, data: null };
}

function removeOverlay() {
  document.getElementById(OVERLAY_ID)?.remove();
}

/**
 * @param {{
 *   title?: string,
 *   hint?: string,
 *   decodeProfile?: 'item'|'location',
 *   acceptKinds?: Array<'HAND'|'CUTTING'|'EMPLOYEE'|'ANY'>,
 *   onResult: (parsed: { kind: string, barcode: string, data: object|null }) => void|Promise<void>,
 *   onClose?: () => void,
 *   continuous?: boolean,
 *   acceptUnknown?: boolean,
 * }} opts
 */
export function openReversiScanOverlay(opts) {
  removeOverlay();

  const title = opts.title || 'Skeniraj barkod';
  const hint = opts.hint || 'Usmeri kameru na barkod nalepnice';
  const accept = new Set(opts.acceptKinds?.length ? opts.acceptKinds : ['ANY']);
  const continuous = !!opts.continuous;
  const acceptUnknown = !!opts.acceptUnknown;
  const decodeProfile = opts.decodeProfile === 'location' ? 'location' : 'item';

  const overlay = document.createElement('div');
  overlay.id = OVERLAY_ID;
  overlay.className = 'loc-scan-overlay rev-scan-overlay';
  overlay.innerHTML = `
    <div class="loc-scan-stage" data-stage="scan">
      <video class="loc-scan-video" id="revScanVideo" playsinline webkit-playsinline autoplay muted></video>
      <div class="loc-scan-reticle" aria-hidden="true"></div>
      <div class="loc-scan-laser" aria-hidden="true"></div>

      <div class="loc-scan-topbar">
        <button type="button" class="loc-scan-btn" data-rev-scan="close" aria-label="Zatvori">✕</button>
        <div class="loc-scan-title">${escHtml(title)}</div>
        <button type="button" class="loc-scan-btn" data-rev-scan="torch" aria-label="Baterijska lampa">💡</button>
      </div>

      <div class="loc-scan-hint">${escHtml(hint)}<br>
        Tap za fokus ·
        <button type="button" class="loc-scan-manual rev-scan-reload-btn" data-rev-scan="reload">Ažuriraj app</button>
      </div>

      <div class="loc-scan-zoom" id="revScanZoom" hidden>
        <button type="button" class="loc-zoom-btn" data-rev-zoom-step="-1" aria-label="Smanji zoom">−</button>
        <input type="range" class="loc-zoom-range" id="revScanZoomRange" min="1" max="5" step="0.1" value="1" aria-label="Zoom">
        <span class="loc-zoom-val" id="revScanZoomVal">1×</span>
        <button type="button" class="loc-zoom-btn" data-rev-zoom-step="1" aria-label="Povećaj zoom">+</button>
      </div>

      <div class="loc-scan-status" id="revScanStatus" aria-live="polite"></div>

      <div class="rev-scan-chips" id="revScanChips" hidden></div>
    </div>`;

  document.body.appendChild(overlay);

  if (isAndroidWebCameraTorchZoomHidden()) {
    overlay.querySelector('[data-rev-scan="torch"]')?.setAttribute('hidden', '');
  }

  const state = {
    scanCtrl: null,
    iosUnbind: null,
    busy: false,
    lastBc: '',
    lastAt: 0,
    chips: [],
  };

  const $ = (sel) => overlay.querySelector(sel);
  const videoEl = /** @type {HTMLVideoElement|null} */ ($('#revScanVideo'));

  function setStatus(msg, kind = 'info') {
    const el = $('#revScanStatus');
    if (!el) return;
    el.textContent = msg || '';
    el.dataset.kind = kind;
  }

  function cleanup() {
    if (state.iosUnbind) {
      try {
        state.iosUnbind();
      } catch {
        /* ignore */
      }
      state.iosUnbind = null;
    }
    if (state.scanCtrl) {
      stopScan(state.scanCtrl);
      state.scanCtrl = null;
    }
    if (videoEl) {
      try {
        const ms = videoEl.srcObject;
        if (ms instanceof MediaStream) {
          for (const t of ms.getTracks()) t.stop();
        }
        videoEl.srcObject = null;
      } catch {
        /* ignore */
      }
    }
  }

  function close() {
    cleanup();
    removeOverlay();
    document.removeEventListener('keydown', onEsc);
    try {
      opts.onClose?.();
    } catch {
      /* ignore */
    }
  }

  function onEsc(ev) {
    if (ev.key === 'Escape') {
      ev.preventDefault();
      close();
    }
  }
  document.addEventListener('keydown', onEsc);

  function paintChips() {
    const host = $('#revScanChips');
    if (!host) return;
    if (!continuous || !state.chips.length) {
      host.hidden = true;
      host.innerHTML = '';
      return;
    }
    host.hidden = false;
    host.innerHTML = state.chips
      .map(
        (c) =>
          `<span class="rev-scan-chip"><span class="rev-mono">${escHtml(c.barcode)}</span> ${escHtml(c.label)}</span>`,
      )
      .join('');
  }

  async function setupZoomUI() {
    if (isAndroidWebCameraTorchZoomHidden() && !isAndroidChromeBrowser()) return;
    if (!state.scanCtrl?.getZoom) return;
    const cap = await state.scanCtrl.getZoom();
    const wrap = $('#revScanZoom');
    const range = /** @type {HTMLInputElement|null} */ ($('#revScanZoomRange'));
    const label = $('#revScanZoomVal');
    if (!cap || !wrap || !range || !label) return;
    if (cap.max <= cap.min + 0.01) {
      wrap.hidden = true;
      return;
    }
    range.min = String(cap.min);
    range.max = String(cap.max);
    range.step = String(cap.step || 0.1);
    const autoZoom = Math.min(cap.max, Math.max(cap.min, 2));
    range.value = String(autoZoom);
    label.textContent = `${autoZoom.toFixed(1)}×`;
    wrap.hidden = false;
    await state.scanCtrl.setZoom?.(autoZoom);
    range.addEventListener(
      'input',
      debounce(async () => {
        const v = Number(range.value);
        label.textContent = `${v.toFixed(1)}×`;
        await state.scanCtrl?.setZoom?.(v);
      }, 220),
    );
    overlay.querySelector('[data-rev-zoom-step="-1"]')?.addEventListener('click', () => {
      range.value = String(Math.max(Number(range.min), Number(range.value) - Number(range.step || 0.1)));
      range.dispatchEvent(new Event('input'));
    });
    overlay.querySelector('[data-rev-zoom-step="1"]')?.addEventListener('click', () => {
      range.value = String(Math.min(Number(range.max), Number(range.value) + Number(range.step || 0.1)));
      range.dispatchEvent(new Event('input'));
    });
  }

  async function handleDecoded(text) {
    if (state.busy || !overlay.isConnected) return;
    const clean = normalizeBarcodeText(text);
    if (!clean) return;
    const now = Date.now();
    if (clean === state.lastBc && now - state.lastAt < 1200) return;
    state.busy = true;
    state.lastBc = clean;
    state.lastAt = now;
    try {
      const parsed = await resolveReversiBarcode(clean);
      if (parsed.kind === 'UNKNOWN') {
        if (acceptUnknown) {
          await opts.onResult(parsed);
          if (!continuous) close();
          return;
        }
        showToast('Nepoznat format barkoda');
        return;
      }
      if (!accept.has('ANY') && !accept.has(parsed.kind)) {
        showToast(`Tip ${parsed.kind} nije dozvoljen u ovom koraku`);
        return;
      }
      if (!parsed.data) {
        showToast('Barkod nije pronađen u evidenciji');
        return;
      }
      navigator.vibrate?.(80);
      const label =
        parsed.kind === 'EMPLOYEE'
          ? parsed.data.full_name || parsed.barcode
          : parsed.data.naziv || parsed.data.oznaka || parsed.barcode;
      if (continuous) {
        state.chips.unshift({ barcode: parsed.barcode, label: String(label) });
        if (state.chips.length > 12) state.chips.length = 12;
        paintChips();
      }
      await opts.onResult(parsed);
      if (!continuous) close();
    } finally {
      state.busy = false;
    }
  }

  async function startCamera() {
    if (!videoEl) return;
    setStatus('Tražim kameru…', 'info');
    if (isIOSWebPlatform()) state.iosUnbind = bindIOSVisualViewportFix(overlay);
    overlay.classList.add('loc-scan-presentation');
    try {
      state.scanCtrl = await startScan(videoEl, {
        decodeProfile,
        onResult: (t) => void handleDecoded(t),
        onError: (err) => setStatus(String(err?.message || err), 'error'),
      });
      setTimeout(() => void setupZoomUI(), 800);
      if (isAndroidWebPlatform() && isAndroidChromeBrowser()) {
        setTimeout(() => {
          if (state.scanCtrl && overlay.isConnected) {
            setStatus('Tap na ekran za fokus · zoom 1.5×–2× za sitne nalepnice', 'info');
          }
        }, 6000);
      }
    } catch (err) {
      setStatus(String(err?.message || err), 'error');
    }
  }

  overlay.querySelector('[data-rev-scan="close"]')?.addEventListener('click', close);
  overlay.querySelector('[data-rev-scan="reload"]')?.addEventListener('click', () => void forceAppReload());
  overlay.querySelector('[data-rev-scan="torch"]')?.addEventListener('click', async () => {
    if (state.scanCtrl?.toggleTorch) await state.scanCtrl.toggleTorch();
  });

  videoEl?.addEventListener('pointerdown', async (ev) => {
    if (!state.scanCtrl?.tapFocus || !videoEl) return;
    const ok = await state.scanCtrl.tapFocus(ev.clientX, ev.clientY, videoEl);
    if (ok) {
      const rect = videoEl.getBoundingClientRect();
      const ring = document.createElement('div');
      ring.className = 'loc-scan-focus-ring';
      ring.style.left = `${ev.clientX - rect.left}px`;
      ring.style.top = `${ev.clientY - rect.top}px`;
      videoEl.parentElement?.appendChild(ring);
      setTimeout(() => ring.remove(), 600);
    }
  });

  void startCamera();
}
