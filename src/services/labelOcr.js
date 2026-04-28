/**
 * OCR za tekst nalepnice (broj predmeta / TP) kada barkod ne uspe.
 * Tesseract.js se lazy-load-uje; worker se drži u sesiji dok ga terminateLabelOcrWorker ne ugasi.
 */

/** @type {import('tesseract.js').Worker | null} */
let _worker = null;

/**
 * @returns {Promise<import('tesseract.js').Worker>}
 */
async function getWorker() {
  if (_worker) return _worker;
  const { createWorker } = await import('tesseract.js');
  _worker = await createWorker('eng', 1, {
    logger: () => {},
  });
  return _worker;
}

/**
 * Oslobodi worker (npr. pri zatvaranju skener modala).
 */
export async function terminateLabelOcrWorker() {
  if (!_worker) return;
  try {
    await _worker.terminate();
  } catch (e) {
    console.warn('[labelOcr] terminate failed', e);
  }
  _worker = null;
}

/**
 * Iseci gornji desni ugao video kadra (gde je obično „Broj predmeta / TP“) i vrati canvas.
 * @param {HTMLVideoElement} video
 * @param {{ widthFraction?: number, heightFraction?: number }} [opts]
 * @returns {HTMLCanvasElement|null}
 */
export function cropTopRightLabelRegion(video, opts = {}) {
  if (!video || video.readyState < 2) return null;
  const w = video.videoWidth;
  const h = video.videoHeight;
  if (!w || !h) return null;

  const wf = opts.widthFraction ?? 0.45;
  const hf = opts.heightFraction ?? 0.28;
  const rw = Math.max(64, Math.floor(w * wf));
  const rh = Math.max(48, Math.floor(h * hf));
  const sx = w - rw;
  const sy = 0;

  const canvas = document.createElement('canvas');
  canvas.width = rw;
  canvas.height = rh;
  const ctx = canvas.getContext('2d');
  if (!ctx) return null;
  try {
    ctx.drawImage(video, sx, sy, rw, rh, 0, 0, rw, rh);
  } catch (e) {
    console.warn('[labelOcr] drawImage failed', e);
    return null;
  }
  return canvas;
}

/**
 * OCR nad canvasom — vraća ceo prepoznat tekst (latinica + cifre).
 * @param {HTMLCanvasElement} canvas
 * @returns {Promise<{ text: string } | { error: string }>}
 */
export async function recognizeLabelCanvas(canvas) {
  if (!canvas?.width || !canvas.height) {
    return { error: 'empty_frame' };
  }
  try {
    const worker = await getWorker();
    const {
      data: { text },
    } = await worker.recognize(canvas);
    return { text: typeof text === 'string' ? text : '' };
  } catch (e) {
    console.warn('[labelOcr] recognize failed', e);
    return { error: e?.message || 'recognize_failed' };
  }
}
