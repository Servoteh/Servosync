/**
 * jsPDF potpisnica za Reversi — Roboto font (UTF-8, srpski dijakritici).
 *
 * Isti obrazac kao `sastanciPdf.js`: jsPDF sa CDN-a, Roboto TTF iz `/public/fonts/`.
 */

const JSPDF_CDN = 'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js';

let _libsPromise = null;

async function arrayBufferToBase64(buf) {
  const bytes = new Uint8Array(buf);
  let bin = '';
  for (let i = 0; i < bytes.byteLength; i++) {
    bin += String.fromCharCode(bytes[i]);
  }
  return btoa(bin);
}

async function loadLibs() {
  if (_libsPromise) return _libsPromise;

  _libsPromise = (async () => {
    if (typeof window === 'undefined') {
      throw new Error('PDF je dostupan samo u pregledaču');
    }
    if (!window.jspdf) {
      await new Promise((resolve, reject) => {
        const existing = document.querySelector(`script[src="${JSPDF_CDN}"]`);
        if (existing?.dataset.loaded) return resolve();
        if (existing) {
          existing.addEventListener('load', () => resolve());
          existing.addEventListener('error', () => reject(new Error('jsPDF CDN fail')));
          return;
        }
        const s = document.createElement('script');
        s.src = JSPDF_CDN;
        s.async = true;
        s.crossOrigin = 'anonymous';
        s.onload = () => {
          s.dataset.loaded = '1';
          resolve();
        };
        s.onerror = () => reject(new Error('Nije moguće učitati jsPDF'));
        document.head.appendChild(s);
      });
    }

    const [regularBuf, boldBuf] = await Promise.all([
      fetch('/fonts/Roboto-Regular.ttf').then(r => {
        if (!r.ok) throw new Error('Roboto-Regular.ttf nije dostupan');
        return r.arrayBuffer();
      }),
      fetch('/fonts/Roboto-Bold.ttf').then(r => {
        if (!r.ok) throw new Error('Roboto-Bold.ttf nije dostupan');
        return r.arrayBuffer();
      }),
    ]);

    return {
      jsPDF: window.jspdf.jsPDF,
      regularB64: await arrayBufferToBase64(regularBuf),
      boldB64: await arrayBufferToBase64(boldBuf),
    };
  })().catch(e => {
    _libsPromise = null;
    throw e;
  });

  return _libsPromise;
}

function initDoc(jsPDF, regularB64, boldB64) {
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });
  doc.addFileToVFS('Roboto-Regular.ttf', regularB64);
  doc.addFont('Roboto-Regular.ttf', 'Roboto', 'normal');
  doc.addFileToVFS('Roboto-Bold.ttf', boldB64);
  doc.addFont('Roboto-Bold.ttf', 'Roboto', 'bold');
  return doc;
}

const PAGE_W = 210;
const PAGE_H = 297;
const MARGIN = 15;
const CONTENT_W = PAGE_W - MARGIN * 2;
const FOOTER_H = 11;
const LINE_H = 5;
const BODY_TOP_FIRST = MARGIN + 28;
const BODY_BOTTOM = PAGE_H - MARGIN - FOOTER_H - 2;
/** Minimalna visina za blok potpisa + povraćaj */
const SIGNATURE_BLOCK_H = 78;

function pad2(n) {
  return String(n).padStart(2, '0');
}

/** @param {string|Date|null|undefined} iso */
export function formatSerbianDate(iso) {
  if (!iso) return '';
  const d = iso instanceof Date ? iso : new Date(iso);
  if (Number.isNaN(d.getTime())) return String(iso).slice(0, 10);
  return `${pad2(d.getDate())}.${pad2(d.getMonth() + 1)}.${d.getFullYear()}`;
}

function formatGeneratedAt(d = new Date()) {
  return `${pad2(d.getDate())}.${pad2(d.getMonth() + 1)}.${d.getFullYear()} u ${pad2(d.getHours())}:${pad2(d.getMinutes())}`;
}

function toolFromLine(ln) {
  const tr = ln.rev_tools;
  return Array.isArray(tr) ? tr[0] : tr;
}

function drawFooter(doc, generatedAtStr, pageNum, totalPages) {
  doc.setFont('Roboto', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(100, 100, 100);
  const left = `Dokument generisan: ${generatedAtStr}`;
  const right = `Stranica ${pageNum} od ${totalPages}`;
  doc.text(left, MARGIN, PAGE_H - MARGIN + 4);
  doc.text(right, PAGE_W - MARGIN, PAGE_H - MARGIN + 4, { align: 'right' });
  doc.setTextColor(0, 0, 0);
}

function drawMainHeader(doc, docRow, issueDateStr) {
  doc.setFont('Roboto', 'bold');
  doc.setFontSize(11);
  doc.setTextColor(17, 24, 39);
  doc.text('SERVOTEH d.o.o.', MARGIN, MARGIN + 6);
  doc.setFont('Roboto', 'normal');
  doc.setFontSize(9);
  doc.setTextColor(60, 60, 60);
  doc.text('Beograd', MARGIN, MARGIN + 12);

  const revNo = docRow.doc_number || '—';
  doc.setFont('Roboto', 'bold');
  doc.setFontSize(10);
  doc.setTextColor(17, 24, 39);
  doc.text(`REVERSAL BR: ${revNo}`, PAGE_W - MARGIN, MARGIN + 6, { align: 'right' });
  doc.setFont('Roboto', 'normal');
  doc.setFontSize(9);
  doc.text(`Datum: ${issueDateStr}`, PAGE_W - MARGIN, MARGIN + 12, { align: 'right' });

  doc.setDrawColor(180, 180, 180);
  doc.line(MARGIN, MARGIN + 16, PAGE_W - MARGIN, MARGIN + 16);
}

function drawContinuationHeader(doc, docRow) {
  doc.setFont('Roboto', 'bold');
  doc.setFontSize(9);
  doc.text(`Reversal — ${docRow.doc_number || ''}`, MARGIN, MARGIN + 6);
  doc.setDrawColor(200, 200, 200);
  doc.line(MARGIN, MARGIN + 9, PAGE_W - MARGIN, MARGIN + 9);
}

/**
 * @param {*} doc jsPDF
 * @param {number} y
 * @param {number} heightNeeded
 * @param {{ pageNum: { n: number } }} ctx
 */
function ensureSpace(doc, y, heightNeeded, ctx) {
  if (y + heightNeeded <= BODY_BOTTOM) return y;
  doc.addPage();
  ctx.pageNum.n += 1;
  return MARGIN + 14;
}

/**
 * @param {object} docRow rev_documents
 * @param {object[]} lines rev_document_lines (+ rev_tools)
 * @param {{ employeeDepartment?: string|null }} [extra]
 * @returns {Promise<object>} jsPDF instance
 */
export async function generateReversalPdf(docRow, lines, extra = {}) {
  const { jsPDF, regularB64, boldB64 } = await loadLibs();
  const doc = initDoc(jsPDF, regularB64, boldB64);

  const issueDateStr = formatSerbianDate(docRow.issued_at) || formatSerbianDate(new Date());
  const generatedAtStr = formatGeneratedAt(new Date());
  const coopDoc = docRow.doc_type === 'COOPERATION_GOODS';

  const ctx = { docRow, pageNum: { n: 1 } };
  let y = BODY_TOP_FIRST;

  /* Primalac */
  doc.setFont('Roboto', 'bold');
  doc.setFontSize(10);
  doc.text('PRIMALAC:', MARGIN, y);
  y += LINE_H + 1;
  doc.setFont('Roboto', 'normal');
  doc.setFontSize(9);

  const rt = docRow.recipient_type;
  if (rt === 'EMPLOYEE') {
    const name = docRow.recipient_employee_name || '—';
    doc.text(name, MARGIN + 22, y);
    y += LINE_H;
    const dept = extra.employeeDepartment?.trim();
    if (dept) {
      doc.setTextColor(80, 80, 80);
      doc.text(`(Radnik — ${dept})`, MARGIN + 22, y);
      doc.setTextColor(0, 0, 0);
      y += LINE_H;
    }
  } else if (rt === 'DEPARTMENT') {
    doc.text(docRow.recipient_department || '—', MARGIN + 22, y);
    y += LINE_H + 2;
  } else if (rt === 'EXTERNAL_COMPANY') {
    const firm = docRow.recipient_company_name || '—';
    const pib = docRow.recipient_company_pib?.trim();
    doc.text(pib ? `${firm} (PIB: ${pib})` : firm, MARGIN + 22, y);
    y += LINE_H + 2;
  } else {
    doc.text('—', MARGIN + 22, y);
    y += LINE_H + 2;
  }

  y += 3;

  /* Tabela */
  const colBr = 9;
  const colOz = coopDoc ? 22 : 18;
  const colKol = 14;
  const colNote = 38;
  const colName = CONTENT_W - colBr - colOz - colKol - colNote;
  const colXs = [MARGIN, MARGIN + colBr, MARGIN + colBr + colOz, MARGIN + colBr + colOz + colName, MARGIN + colBr + colOz + colName + colKol];
  const headers = coopDoc
    ? ['Br', 'Br. crteža', 'Naziv dela', 'Kol', 'Napomena']
    : ['Br', 'Oznaka', 'Naziv', 'Kol', 'Napomena / Pribor'];

  const sorted = [...(lines || [])].sort((a, b) => (a.sort_order ?? 0) - (b.sort_order ?? 0));

  const headerRowH = LINE_H + 3;
  y = ensureSpace(doc, y, headerRowH + 8, ctx);
  doc.setFillColor(243, 244, 246);
  doc.rect(MARGIN, y - LINE_H + 1, CONTENT_W, headerRowH, 'F');
  doc.setFont('Roboto', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(55, 65, 81);
  headers.forEach((h, i) => {
    doc.text(h, colXs[i] + 1, y);
  });
  y += headerRowH - 1;
  doc.setFont('Roboto', 'normal');
  doc.setFontSize(8);
  doc.setTextColor(17, 24, 39);

  sorted.forEach((ln, idx) => {
    let oz = '—';
    let naz = '—';
    if (coopDoc || ln.line_type === 'PRODUCTION_PART') {
      oz = ln.drawing_no || '—';
      naz = ln.part_name || ln.drawing_no || '—';
    } else {
      const t = toolFromLine(ln);
      oz = t?.oznaka ?? '—';
      naz = t?.naziv ?? '—';
      if (t?.serijski_broj) naz = `${naz} (${t.serijski_broj})`;
    }
    const qtyStr = String(ln.quantity ?? 1);
    const note = (ln.napomena || '').trim() || '—';

    const wOz = colOz - 3;
    const wNa = colName - 3;
    const wNo = colNote - 3;
    const linesOz = doc.splitTextToSize(oz, wOz);
    const linesNa = doc.splitTextToSize(naz, wNa);
    const linesNo = doc.splitTextToSize(note, wNo);
    const linesBr = doc.splitTextToSize(String(idx + 1), colBr - 3);
    const linesQty = doc.splitTextToSize(qtyStr, colKol - 3);
    const maxLines = Math.max(
      linesOz.length,
      linesNa.length,
      linesNo.length,
      linesBr.length,
      linesQty.length,
      1,
    );
    const rowH = maxLines * LINE_H + 4;

    y = ensureSpace(doc, y, rowH + 2, ctx);

    doc.setDrawColor(230, 230, 230);
    doc.rect(MARGIN, y - LINE_H + 2, CONTENT_W, rowH);

    const baseY = y;
    const drawCell = (textLines, x, w) => {
      let yy = baseY;
      textLines.forEach(line => {
        doc.text(line, x + 1, yy);
        yy += LINE_H;
      });
    };

    drawCell(linesBr, colXs[0], colBr);
    drawCell(linesOz, colXs[1], colOz);
    drawCell(linesNa, colXs[2], colName);
    drawCell(linesQty, colXs[3], colKol);
    drawCell(linesNo, colXs[4], colNote);

    y = baseY + maxLines * LINE_H + 4;
  });

  y += 4;

  if (docRow.expected_return_date) {
    y = ensureSpace(doc, y, LINE_H + 4, ctx);
    doc.setFont('Roboto', 'normal');
    doc.setFontSize(9);
    doc.text(`Očekivani datum povraćaja:  ${formatSerbianDate(docRow.expected_return_date)}`, MARGIN, y);
    y += LINE_H + 4;
  }

  const napDoc = (docRow.napomena || '').trim();
  if (napDoc) {
    const wrapped = doc.splitTextToSize(`Napomena:  ${napDoc}`, CONTENT_W);
    const blockH = wrapped.length * LINE_H + 4;
    y = ensureSpace(doc, y, blockH, ctx);
    doc.setFont('Roboto', 'normal');
    doc.setFontSize(9);
    wrapped.forEach(line => {
      doc.text(line, MARGIN, y);
      y += LINE_H;
    });
    y += 4;
  }

  /* Potpisi — nova strana ako nema mesta */
  y = ensureSpace(doc, y, SIGNATURE_BLOCK_H + 6, ctx);

  doc.setDrawColor(160, 160, 160);
  doc.line(MARGIN, y, PAGE_W - MARGIN, y);
  y += 8;

  const sigLine = (labelLeft, labelRight, y0, opts = {}) => {
    doc.setFont('Roboto', 'bold');
    doc.setFontSize(9);
    doc.text(labelLeft, MARGIN, y0);
    doc.text(labelRight, PAGE_W / 2 + 5, y0);
    y0 += LINE_H + 2;
    doc.setFont('Roboto', 'normal');
    doc.setFontSize(9);
    doc.text('Ime i prezime: ______________________', MARGIN, y0);
    doc.text('Ime i prezime: ______________________', PAGE_W / 2 + 5, y0);
    y0 += LINE_H + 3;
    doc.text('Potpis:        ______________________', MARGIN, y0);
    doc.text('Potpis:        ______________________', PAGE_W / 2 + 5, y0);
    y0 += LINE_H + 3;
    doc.text('Datum:         ______________________', MARGIN, y0);
    if (opts.rightThird) {
      doc.text(opts.rightThird, PAGE_W / 2 + 5, y0);
    } else {
      doc.text('Datum:         ______________________', PAGE_W / 2 + 5, y0);
    }
    return y0 + LINE_H + 4;
  };

  y = sigLine('Predao (Servoteh):', 'Primio:', y);
  y += 4;
  doc.line(MARGIN, y, PAGE_W - MARGIN, y);
  y += 8;
  doc.setFont('Roboto', 'bold');
  doc.setFontSize(10);
  doc.text('POVRAĆAJ', MARGIN, y);
  y += LINE_H + 6;

  y = sigLine('Primio u magacin (Servoteh):', 'Predao:', y, { rightThird: 'Stanje alata:  ______________________' });

  const totalPages = doc.internal.getNumberOfPages();
  for (let i = 1; i <= totalPages; i++) {
    doc.setPage(i);
    if (i === 1) {
      drawMainHeader(doc, docRow, issueDateStr);
    } else {
      drawContinuationHeader(doc, docRow);
    }
    drawFooter(doc, generatedAtStr, i, totalPages);
  }

  return doc;
}

export function openPdfInNewTab(pdfInstance) {
  const blob = pdfInstance.output('blob');
  const url = URL.createObjectURL(blob);
  window.open(url, '_blank');
  setTimeout(() => URL.revokeObjectURL(url), 60_000);
}

export function getPdfBlob(pdfInstance) {
  return pdfInstance.output('blob');
}
