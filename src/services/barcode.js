/**
 * Barcode skeniranje preko kamere (Android Chrome + iOS Safari + desktop).
 *
 * - iOS / desktop: ZXing (`@zxing/browser`).
 * - Android Chrome + mode AUTO: `BarcodeDetector` kada postoji, inače ZXing.
 * - Debug: `sessionStorage.loc_scan_decode_mode` = `AUTO` | `ZXING_ONLY` | `BARCODE_DETECTOR_ONLY`
 *
 * Usage:
 *   const ctrl = await startScan(videoEl, {
 *     onResult: (text) => { ... },
 *     onError: (err) => { ... }
 *   });
 *   ctrl.stop();
 */

import { BrowserMultiFormatReader } from '@zxing/browser';
import { BarcodeFormat, DecodeHintType } from '@zxing/library';

export { normalizeBarcodeText, parseBigTehnBarcode } from '../lib/barcodeParse.js';

const LIVE_SCAN_HINTS = new Map();
LIVE_SCAN_HINTS.set(DecodeHintType.POSSIBLE_FORMATS, [
  BarcodeFormat.CODE_128,
  BarcodeFormat.CODE_39,
]);
LIVE_SCAN_HINTS.set(DecodeHintType.TRY_HARDER, false);

const LIVE_SCAN_HINTS_TRY_HARDER = new Map(LIVE_SCAN_HINTS);
LIVE_SCAN_HINTS_TRY_HARDER.set(DecodeHintType.TRY_HARDER, true);

/** Android (ne-Chrome): ZXing live sa TRY_HARDER. */
const LIVE_SCAN_HINTS_ANDROID_FALLBACK = new Map(LIVE_SCAN_HINTS);
LIVE_SCAN_HINTS_ANDROID_FALLBACK.set(DecodeHintType.TRY_HARDER, true);

const STILL_IMAGE_SCAN_HINTS = new Map();
STILL_IMAGE_SCAN_HINTS.set(DecodeHintType.POSSIBLE_FORMATS, [
  BarcodeFormat.CODE_128,
  BarcodeFormat.CODE_39,
]);
STILL_IMAGE_SCAN_HINTS.set(DecodeHintType.TRY_HARDER, true);

const ZXING_READER_OPTIONS = {
  delayBetweenScanAttempts: 50,
  delayBetweenScanSuccess: 200,
  tryPlayVideoTimeout: 5000,
};

const SESSION_DECODE_MODE_KEY = 'loc_scan_decode_mode';

/**
 * @param {'AUTO'|'ZXING_ONLY'|'BARCODE_DETECTOR_ONLY'} mode
 */
export function setScanDecodeMode(mode) {
  if (mode !== 'ZXING_ONLY' && mode !== 'BARCODE_DETECTOR_ONLY' && mode !== 'AUTO') return;
  try {
    sessionStorage.setItem(SESSION_DECODE_MODE_KEY, mode);
  } catch {
    /* ignore */
  }
}

/**
 * Mapira tačku (client koordinate) u normalizovane [0,1] koordinate **video kadra**
 * kada je `<video>` sa `object-fit: cover` (izrezane ivice kadra).
 *
 * @param {HTMLVideoElement} videoEl
 * @param {number} clientX
 * @param {number} clientY
 * @returns {{ x: number, y: number } | null}
 */
export function mapPointerToVideoNormalizedPlane(videoEl, clientX, clientY) {
  if (!videoEl?.getBoundingClientRect) return null;
  const rect = videoEl.getBoundingClientRect();
  const vw = videoEl.videoWidth || 0;
  const vh = videoEl.videoHeight || 0;
  const px = clientX - rect.left;
  const py = clientY - rect.top;
  if (!rect.width || !rect.height) return null;
  if (!vw || !vh) {
    return {
      x: Math.min(1, Math.max(0, px / rect.width)),
      y: Math.min(1, Math.max(0, py / rect.height)),
    };
  }
  const scale = Math.max(rect.width / vw, rect.height / vh);
  const dispW = vw * scale;
  const dispH = vh * scale;
  const offX = (rect.width - dispW) / 2;
  const offY = (rect.height - dispH) / 2;
  const rx = (px - offX) / dispW;
  const ry = (py - offY) / dispH;
  return {
    x: Math.min(1, Math.max(0, rx)),
    y: Math.min(1, Math.max(0, ry)),
  };
}

/**
 * @typedef {object} ScanController
 * @property {() => void} stop
 * @property {() => Promise<boolean>} toggleTorch
 * @property {() => Promise<ZoomCapability|null>} getZoom
 * @property {(value: number) => Promise<boolean>} setZoom
 * @property {(x:number,y:number,videoEl?:HTMLVideoElement|null) => Promise<boolean>} tapFocus
 *   Ako je `videoEl` prosleđen, `x`/`y` su **client** koordinate (npr. pointer.clientX/Y) za mapiranje object-fit:cover.
 *   Ako `videoEl` nije prosleđen, `x`/`y` su već normalizovani [0,1] u ravni video kadra.
 * @property {() => Promise<void>} refocusAfterZoom
 */

/**
 * @typedef {object} ZoomCapability
 * @property {number} min
 * @property {number} max
 * @property {number} step
 * @property {number} current
 */

export function isScanSupported() {
  return (
    typeof navigator !== 'undefined' &&
    !!navigator.mediaDevices?.getUserMedia &&
    typeof window !== 'undefined'
  );
}

export function isAndroidWebPlatform() {
  if (typeof navigator === 'undefined') return false;
  const ua = navigator.userAgent || '';
  if (/Android/i.test(ua)) return true;
  try {
    const uad = /** @type {{ mobile?: boolean, brands?: { brand?: string }[] }} */ (
      /** @type {unknown} */ (navigator).userAgentData
    );
    if (uad && uad.mobile === true && Array.isArray(uad.brands)) {
      const brands = uad.brands.map(b => String(b.brand || '')).join(' ');
      if (/Android/i.test(brands)) return true;
    }
  } catch {
    /* ignore */
  }
  return false;
}

export function isAndroidWebCameraTorchZoomHidden() {
  return isAndroidWebPlatform();
}

export function isAndroidChromeBrowser() {
  if (!isAndroidWebPlatform()) return false;
  const ua = typeof navigator !== 'undefined' ? navigator.userAgent || '' : '';
  if (/Firefox|SamsungBrowser|EdgA/i.test(ua)) return false;
  return /Chrome\//.test(ua);
}

/**
 * Podrazumevano na Android Chrome-u: **ZXING_ONLY** (isti put kao Firefox —
 * ZXing + TRY_HARDER). BarcodeDetector + forsiran continuous AF često daju
 * mutniji preview. Ručno: `sessionStorage.loc_scan_decode_mode`.
 *
 * @returns {'AUTO'|'ZXING_ONLY'|'BARCODE_DETECTOR_ONLY'}
 */
export function getScanDecodeMode() {
  try {
    const v = sessionStorage.getItem(SESSION_DECODE_MODE_KEY);
    if (v === 'ZXING_ONLY' || v === 'BARCODE_DETECTOR_ONLY' || v === 'AUTO') return v;
  } catch {
    /* ignore */
  }
  if (isAndroidChromeBrowser()) return 'ZXING_ONLY';
  return 'AUTO';
}

/** @param {HTMLVideoElement} videoEl */
function waitVideoReady(videoEl) {
  return new Promise(resolve => {
    if (!videoEl) {
      resolve();
      return;
    }
    if (videoEl.readyState >= HTMLMediaElement.HAVE_METADATA) {
      resolve();
      return;
    }
    const done = () => {
      videoEl.removeEventListener('loadedmetadata', done);
      videoEl.removeEventListener('canplay', done);
      resolve();
    };
    videoEl.addEventListener('loadedmetadata', done, { once: true });
    videoEl.addEventListener('canplay', done, { once: true });
  });
}

/**
 * @param {MediaStreamTrack} track
 * @param {MediaTrackConstraints} constraints
 * @param {string} label
 * @returns {Promise<boolean>}
 */
export async function safeApplyConstraints(track, constraints, label) {
  if (!track?.applyConstraints) return false;
  try {
    await track.applyConstraints(constraints);
    console.info('[barcode][scan]', label, 'OK', {
      requested: constraints,
      settingsAfter: track.getSettings?.() ?? null,
    });
    return true;
  } catch (err) {
    console.warn('[barcode][scan]', label, 'FAIL', {
      name: err?.name,
      message: err?.message,
      constraint: err?.constraint,
      requested: constraints,
      settingsAfter: track.getSettings?.() ?? null,
    });
    return false;
  }
}

/**
 * @param {MediaStreamTrack} track
 * @param {Record<string, unknown>} flat
 * @param {string} label
 * @param {boolean} isAndroid
 */
async function safeApplyFlatCompat(track, flat, label, isAndroid) {
  if (!track?.applyConstraints) return false;
  const attempts = isAndroid
    ? [
        () => track.applyConstraints({ advanced: [flat] }),
        () => track.applyConstraints(flat),
      ]
    : [
        () => track.applyConstraints(flat),
        () => track.applyConstraints({ advanced: [flat] }),
      ];
  for (const run of attempts) {
    try {
      await run();
      console.info('[barcode][scan]', label, 'OK', { flat, settingsAfter: track.getSettings?.() ?? null });
      return true;
    } catch (err) {
      console.warn('[barcode][scan]', label, 'attempt fail', err?.name, err?.message, { flat });
    }
  }
  console.warn('[barcode][scan]', label, 'all attempts failed', { flat });
  return false;
}

/** @param {MediaStreamTrack|null} track */
async function logScanDiagnosticsOnce(track) {
  if (!track) return;
  try {
    const devices = navigator.mediaDevices?.enumerateDevices
      ? await navigator.mediaDevices.enumerateDevices()
      : [];
    const vids = devices.filter(d => d.kind === 'videoinput').map(d => ({ deviceId: d.deviceId, label: d.label }));
    console.info('[barcode][scan] diagnostics (once)', {
      userAgent: typeof navigator !== 'undefined' ? navigator.userAgent : '',
      getSupportedConstraints: navigator.mediaDevices?.getSupportedConstraints?.() ?? null,
      capabilities: track.getCapabilities?.() ?? null,
      settings: track.getSettings?.() ?? null,
      constraints: track.getConstraints?.() ?? null,
      videoInputs: vids,
    });
  } catch (e) {
    console.warn('[barcode][scan] diagnostics failed', e);
  }
}

/**
 * @param {MediaStreamTrack} track
 * @param {boolean} isAndroid
 */
async function refocusRound(track, isAndroid, nx, ny) {
  const caps = track.getCapabilities?.() || {};
  const modes = Array.isArray(caps.focusMode) ? caps.focusMode.map(String) : [];
  const hasPoi = 'pointsOfInterest' in caps;
  const x = Math.min(1, Math.max(0, nx));
  const y = Math.min(1, Math.max(0, ny));
  if (modes.includes('single-shot') && hasPoi) {
    await safeApplyFlatCompat(
      track,
      /** @type {any} */ ({ focusMode: 'single-shot', pointsOfInterest: [{ x, y }] }),
      'refocus: single-shot',
      isAndroid,
    );
    await new Promise(r => setTimeout(r, 280));
  }
  /* Na Android Chrome-u `continuous` posle single-shot često „zaključa“ mutan AF
   * za blisku nalepnicu; Firefox ovde ionako ne ide kroz istu granu. */
  if (modes.includes('continuous') && !isAndroidChromeBrowser()) {
    await safeApplyFlatCompat(track, /** @type {any} */ ({ focusMode: 'continuous' }), 'refocus: continuous', isAndroid);
  }
}

/**
 * @param {MediaStreamTrack} track
 * @param {boolean} isAndroid
 * @param {{ skipInitialHardwareZoom?: boolean }} [opts]
 */
async function primeCameraPipeline(track, isAndroid, opts = {}) {
  if (!track || !isAndroidChromeBrowser()) return;
  void isAndroid;
  void opts;
  /* Namerno prazan: ranije forsiran continuous + zoom na startu često je
   * pogoršavao oštrinu u Chrome-u; Firefox Android taj pipeline nije imao.
   * Dijagnostika ostaje u schedulePrimeAfterVideoReady; fokus = tap ili slider. */
}

/**
 * @param {HTMLVideoElement} videoEl
 * @param {() => MediaStreamTrack|null} getTrack
 * @param {boolean} isAndroid
 */
function schedulePrimeAfterVideoReady(videoEl, getTrack, isAndroid) {
  void waitVideoReady(videoEl).then(async () => {
    const tr = getTrack();
    if (!tr) return;
    await logScanDiagnosticsOnce(tr);
    await primeCameraPipeline(tr, isAndroid, { skipInitialHardwareZoom: true });
  });
}

/**
 * @param {{
 *   onResult: (text: string, format?: string) => void,
 *   onError?: (err: Error) => void,
 *   forceDeviceId?: string,
 * }} handlers
 * @returns {Promise<ScanController>}
 */
export async function startScan(videoEl, { onResult, onError, forceDeviceId }) {
  if (!videoEl) throw new Error('Video element is required.');
  if (typeof onResult !== 'function') throw new Error('onResult handler is required.');
  if (!isScanSupported()) {
    const e = new Error('Kamera/MediaDevices nije podržana u ovom pregledaču.');
    onError?.(e);
    throw e;
  }

  const isAndroid = isAndroidWebCameraTorchZoomHidden();
  const mode = getScanDecodeMode();
  const useBarcodeDetectorPath =
    isAndroidChromeBrowser() &&
    typeof window !== 'undefined' &&
    typeof window.BarcodeDetector === 'function' &&
    (mode === 'AUTO' || mode === 'BARCODE_DETECTOR_ONLY');

  const videoBase = {
    width: { ideal: 1920 },
    height: { ideal: 1080 },
    frameRate: { ideal: 30 },
  };
  const constraints = forceDeviceId
    ? { video: { ...videoBase, deviceId: { exact: forceDeviceId } } }
    : { video: { ...videoBase, facingMode: { ideal: 'environment' } } };

  function getTrack() {
    const stream = /** @type {MediaStream|null} */ (videoEl.srcObject);
    if (!(stream instanceof MediaStream)) return null;
    return stream.getVideoTracks()[0] || null;
  }

  let zoomDebounceTimer = 0;

  const runRefocusAfterZoom = async () => {
    const track = getTrack();
    if (!track) return;
    await refocusRound(track, isAndroid, 0.5, 0.5);
    const caps = track.getCapabilities?.() || {};
    const modes = Array.isArray(caps.focusMode) ? caps.focusMode.map(String) : [];
    if (modes.includes('continuous') && !isAndroidChromeBrowser()) {
      await safeApplyFlatCompat(track, /** @type {any} */ ({ focusMode: 'continuous' }), 'post-zoom: continuous', isAndroid);
    }
  };

  if (useBarcodeDetectorPath && mode !== 'ZXING_ONLY') {
    /** @type {MediaStream|null} */
    let nativeStream = null;
    let rafId = 0;
    let stopped = false;
    try {
      nativeStream = await navigator.mediaDevices.getUserMedia(constraints);
    } catch (e) {
      onError?.(/** @type {Error} */ (e));
      throw e;
    }
    videoEl.srcObject = nativeStream;
    try {
      await videoEl.play();
    } catch (e) {
      for (const t of nativeStream.getTracks()) {
        try {
          t.stop();
        } catch {
          /* ignore */
        }
      }
      videoEl.srcObject = null;
      onError?.(/** @type {Error} */ (e));
      throw e;
    }

    schedulePrimeAfterVideoReady(videoEl, getTrack, isAndroid);

    /** @type {InstanceType<typeof window.BarcodeDetector>|null} */
    let detector = null;
    try {
      detector = new window.BarcodeDetector({
        formats: ['code_128', 'code_39'],
      });
    } catch (e) {
      console.warn('[barcode] BarcodeDetector init failed, falling back to ZXing', e);
      for (const t of nativeStream.getTracks()) {
        try {
          t.stop();
        } catch {
          /* ignore */
        }
      }
      videoEl.srcObject = null;
      /* fall through to ZXing below */
    }

    if (detector) {
      const tick = async () => {
        if (stopped) return;
        if (videoEl.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) {
          rafId = requestAnimationFrame(() => void tick());
          return;
        }
        try {
          const codes = await detector.detect(videoEl);
          if (stopped) return;
          if (codes && codes.length > 0) {
            const b = codes[0];
            const text = b.rawValue != null ? String(b.rawValue) : '';
            const fmt = b.format != null ? String(b.format) : undefined;
            if (text) onResult(text, fmt);
          }
        } catch (e) {
          if (!stopped) onError?.(/** @type {Error} */ (e));
        }
        if (!stopped) rafId = requestAnimationFrame(() => void tick());
      };
      rafId = requestAnimationFrame(() => void tick());

      return buildController({
        stop: () => {
          stopped = true;
          cancelAnimationFrame(rafId);
          if (zoomDebounceTimer) clearTimeout(zoomDebounceTimer);
          if (nativeStream) {
            for (const t of nativeStream.getTracks()) {
              try {
                t.stop();
              } catch {
                /* ignore */
              }
            }
          }
          try {
            videoEl.srcObject = null;
            videoEl.load();
          } catch {
            /* ignore */
          }
        },
        getTrack,
        isAndroid,
        runRefocusAfterZoom,
      });
    }
  }

  const hints =
    mode === 'ZXING_ONLY' && isAndroidChromeBrowser()
      ? LIVE_SCAN_HINTS_TRY_HARDER
      : isAndroid && !isAndroidChromeBrowser()
        ? LIVE_SCAN_HINTS_ANDROID_FALLBACK
        : LIVE_SCAN_HINTS;
  const reader = new BrowserMultiFormatReader(hints, ZXING_READER_OPTIONS);

  const controls = await reader.decodeFromConstraints(
    constraints,
    videoEl,
    (result, err) => {
      if (result) {
        try {
          onResult(result.getText(), result.getBarcodeFormat?.().toString());
        } catch (e) {
          onError?.(e);
        }
      } else if (err && err.name && err.name !== 'NotFoundException') {
        onError?.(err);
      }
    },
  );

  schedulePrimeAfterVideoReady(videoEl, getTrack, isAndroid);

  return buildController({
    stop: () => {
      try {
        controls.stop();
      } catch (e) {
        console.warn('[barcode] stop failed', e);
      }
      if (zoomDebounceTimer) clearTimeout(zoomDebounceTimer);
    },
    getTrack,
    isAndroid,
    runRefocusAfterZoom,
  });
}

/**
 * @param {object} parts
 */
function buildController({ stop, getTrack, isAndroid, runRefocusAfterZoom }) {
  let zoomDebounceTimer = 0;

  return {
    stop: () => {
      if (zoomDebounceTimer) clearTimeout(zoomDebounceTimer);
      stop();
    },
    toggleTorch: async () => {
      const track = getTrack();
      if (!track) return false;
      const caps = track.getCapabilities?.() || {};
      const supported = navigator.mediaDevices?.getSupportedConstraints?.() || {};
      if (isAndroidWebPlatform()) return false;
      const torchAdvertised = 'torch' in caps || supported.torch === true;
      if (!torchAdvertised) return false;
      const settings = track.getSettings?.() || {};
      const next = !settings.torch;
      const ok = await safeApplyFlatCompat(track, { torch: next }, 'torch', isAndroid);
      return ok ? next : false;
    },

    getZoom: async () => {
      const track = getTrack();
      if (!track) return null;
      if (isAndroidWebPlatform() && !isAndroidChromeBrowser()) return null;
      const caps = track.getCapabilities?.() || {};
      const s = track.getSettings?.() || {};
      const zRaw = caps.zoom;
      if (zRaw != null && typeof zRaw === 'object' && !Array.isArray(zRaw)) {
        const z = /** @type {any} */ (zRaw);
        return {
          min: Number(z.min ?? 1),
          max: Number(z.max ?? 1),
          step: Number(z.step ?? 0.1),
          current: Number(s.zoom ?? z.min ?? 1),
        };
      }
      return null;
    },

    setZoom: async value => {
      if (isAndroidWebPlatform() && !isAndroidChromeBrowser()) return false;
      return new Promise(resolve => {
        if (zoomDebounceTimer) clearTimeout(zoomDebounceTimer);
        zoomDebounceTimer = window.setTimeout(async () => {
          zoomDebounceTimer = 0;
          const tr = getTrack();
          if (!tr) {
            resolve(false);
            return;
          }
          const ok = await safeApplyFlatCompat(tr, { zoom: value }, 'setZoom(debounced)', isAndroid);
          if (ok && isAndroidChromeBrowser()) await runRefocusAfterZoom();
          resolve(ok);
        }, 220);
      });
    },

    refocusAfterZoom: runRefocusAfterZoom,

    tapFocus: async (x, y, videoElForMap) => {
      const track = getTrack();
      if (!track) return false;
      let nx = x;
      let ny = y;
      if (videoElForMap instanceof HTMLVideoElement) {
        const m = mapPointerToVideoNormalizedPlane(videoElForMap, x, y);
        if (!m) return false;
        nx = m.x;
        ny = m.y;
      }
      const caps = track.getCapabilities?.() || {};
      const modes = Array.isArray(caps.focusMode) ? caps.focusMode.map(String) : [];
      if (modes.includes('single-shot') && 'pointsOfInterest' in caps) {
        const ok = await safeApplyFlatCompat(
          track,
          /** @type {any} */ ({
            focusMode: 'single-shot',
            pointsOfInterest: [{ x: Math.min(1, Math.max(0, nx)), y: Math.min(1, Math.max(0, ny)) }],
          }),
          'tapFocus: single-shot',
          isAndroid,
        );
        if (!ok) return false;
        await new Promise(r => setTimeout(r, 320));
        if (modes.includes('continuous') && !isAndroidChromeBrowser()) {
          await safeApplyFlatCompat(track, /** @type {any} */ ({ focusMode: 'continuous' }), 'tapFocus: continuous', isAndroid);
        }
        return true;
      }
      if (modes.includes('continuous') && !isAndroidChromeBrowser()) {
        return safeApplyFlatCompat(track, /** @type {any} */ ({ focusMode: 'continuous' }), 'tapFocus: continuous only', isAndroid);
      }
      return false;
    },
  };
}

export async function decodeBarcodeFromFile(file) {
  if (!file || !(file instanceof Blob)) return { error: 'not_image' };
  if (!/^image\//.test(file.type || '')) return { error: 'not_image' };

  const url = URL.createObjectURL(file);
  try {
    const img = await loadImage(url);
    const reader = new BrowserMultiFormatReader(STILL_IMAGE_SCAN_HINTS);
    try {
      const result = await reader.decodeFromImageElement(img);
      return { text: result.getText(), format: result.getBarcodeFormat?.().toString() };
    } catch (e) {
      if (e?.name === 'NotFoundException') return { error: 'no_barcode' };
      return { error: 'decode_failed', cause: e };
    }
  } finally {
    URL.revokeObjectURL(url);
  }
}

/** @param {string} url */
function loadImage(url) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = reject;
    img.src = url;
  });
}
