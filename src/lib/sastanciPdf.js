/**
 * jsPDF PDF generator za sastanke — Roboto font (UTF-8 sa srpskim karakterima).
 *
 * Fontovi se fetchuju iz /public/fonts/ (committed u repo, bez CDN).
 * jsPDF se učitava lazy sa CDN-a (isti izvor kao pdf.js, ali odvojena instanca).
 *
 * Eksportuje:
 *   generateSastanakPdf(sastanakFull, options?) → Promise<Blob>
 *     sastanakFull = rezultat getSastanakFull(id) ++ { pmTeme?, akcioniPlan? }
 *     options = { includeAkcije: true, includePotpisi: true }
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
    // jsPDF sa CDN-a
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
        s.onload = () => { s.dataset.loaded = '1'; resolve(); };
        s.onerror = () => reject(new Error('Nije moguće učitati jsPDF'));
        document.head.appendChild(s);
      });
    }

    // Roboto fontovi iz public/fonts/
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

/* ── PDF layout helpers ─────────────────────────────────────────────────────── */

const MARGIN = 20;
const PAGE_W = 210;    // A4 mm
const PAGE_H = 297;
const CONTENT_W = PAGE_W - MARGIN * 2;
const HEADER_H = 14;   // visina zaglavlja na svakoj stranici
const FOOTER_H = 10;
const LINE_H = 6;
const BODY_TOP = MARGIN + HEADER_H + 4;
const BODY_BOTTOM = PAGE_H - MARGIN - FOOTER_H;

function initDoc(jsPDF, regularB64, boldB64) {
  const doc = new jsPDF({ orientation: 'portrait', unit: 'mm', format: 'a4' });

  doc.addFileToVFS('Roboto-Regular.ttf', regularB64);
  doc.addFont('Roboto-Regular.ttf', 'Roboto', 'normal');
  doc.addFileToVFS('Roboto-Bold.ttf', boldB64);
  doc.addFont('Roboto-Bold.ttf', 'Roboto', 'bold');

  return doc;
}

function drawPageHeader(doc, naslov, pageNum, totalPages) {
  doc.setFont('Roboto', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(37, 99, 235); // #2563eb
  doc.text('SERVOTEH d.o.o.', MARGIN, MARGIN + 5);
  doc.setFont('Roboto', 'normal');
  doc.setTextColor(80, 80, 80);
  doc.text('ZAPISNIK SA SASTANKA', PAGE_W / 2, MARGIN + 5, { align: 'center' });
  doc.text(`${pageNum} / ${totalPages}`, PAGE_W - MARGIN, MARGIN + 5, { align: 'right' });
  doc.setDrawColor(229, 231, 235);
  doc.line(MARGIN, MARGIN + 8, PAGE_W - MARGIN, MARGIN + 8);
  // Footer
  doc.setFontSize(7);
  doc.setTextColor(150, 150, 150);
  doc.text(naslov.slice(0, 80), MARGIN, PAGE_H - MARGIN + 4);
  doc.setTextColor(0, 0, 0);
}

function checkPageBreak(doc, y, heightNeeded, naslov, pageState) {
  if (y + heightNeeded > BODY_BOTTOM) {
    doc.addPage();
    pageState.pageNum++;
    drawPageHeader(doc, naslov, pageState.pageNum, '?');
    return BODY_TOP;
  }
  return y;
}

function drawSectionHeading(doc, y, text) {
  doc.setFont('Roboto', 'bold');
  doc.setFontSize(12);
  doc.setTextColor(17, 24, 39);
  doc.text(text, MARGIN, y);
  doc.setDrawColor(37, 99, 235);
  doc.line(MARGIN, y + 1.5, PAGE_W - MARGIN, y + 1.5);
  doc.setTextColor(0, 0, 0);
  return y + LINE_H + 2;
}

function drawMetaRow(doc, y, label, value) {
  doc.setFont('Roboto', 'normal');
  doc.setFontSize(9);
  doc.setTextColor(107, 114, 128);
  doc.text(label, MARGIN, y);
  doc.setTextColor(17, 24, 39);
  doc.setFont('Roboto', 'bold');
  const wrapped = doc.splitTextToSize(value || '—', CONTENT_W - 45);
  doc.text(wrapped, MARGIN + 45, y);
  doc.setFont('Roboto', 'normal');
  doc.setTextColor(0, 0, 0);
  return y + Math.max(1, wrapped.length) * LINE_H;
}

function drawTable(doc, y, headers, rows, colWidths) {
  const rowH = LINE_H;
  const startX = MARGIN;

  // Header row
  doc.setFillColor(243, 244, 246);
  doc.rect(startX, y - 4, CONTENT_W, rowH, 'F');
  doc.setFont('Roboto', 'bold');
  doc.setFontSize(8);
  doc.setTextColor(55, 65, 81);
  let x = startX + 2;
  headers.forEach((h, i) => {
    doc.text(h, x, y);
    x += colWidths[i];
  });
  y += rowH;

  doc.setFont('Roboto', 'normal');
  doc.setTextColor(17, 24, 39);

  rows.forEach((row, ri) => {
    if (ri % 2 === 1) {
      doc.setFillColor(249, 250, 251);
      doc.rect(startX, y - 4, CONTENT_W, rowH, 'F');
    }
    x = startX + 2;
    row.forEach((cell, ci) => {
      const cellW = colWidths[ci] - 4;
      const parts = doc.splitTextToSize(String(cell || '—'), cellW);
      doc.text(parts[0], x, y);
      x += colWidths[ci];
    });
    y += rowH;
  });

  doc.setDrawColor(229, 231, 235);
  doc.rect(startX, y - rows.length * rowH - rowH, CONTENT_W, (rows.length + 1) * rowH);

  return y + 2;
}

/* ── Glavna funkcija ─────────────────────────────────────────────────────────  */

/**
 * @param {object} sast Rezultat getSastanakFull + opcionalno pmTeme, akcioniPlan
 * @param {{ includeAkcije?: boolean, includePotpisi?: boolean }} [options]
 * @returns {Promise<Blob>}
 */
export async function generateSastanakPdf(sast, options = {}) {
  const { includeAkcije = true, includePotpisi = true } = options;

  const { jsPDF, regularB64, boldB64 } = await loadLibs();
  const doc = initDoc(jsPDF, regularB64, boldB64);

  const naslov = sast.naslov || 'Zapisnik';
  const pageState = { pageNum: 1 };

  // ── STRANA 1: META INFO ──────────────────────────────────────────────────
  drawPageHeader(doc, naslov, 1, '?');
  let y = BODY_TOP;

  // Naslov
  doc.setFont('Roboto', 'bold');
  doc.setFontSize(16);
  doc.setTextColor(17, 24, 39);
  const naslovWrapped = doc.splitTextToSize(naslov, CONTENT_W);
  doc.text(naslovWrapped, MARGIN, y);
  y += naslovWrapped.length * 8 + 4;

  doc.setDrawColor(229, 231, 235);
  doc.line(MARGIN, y, PAGE_W - MARGIN, y);
  y += 6;

  // Meta tabela
  y = drawSectionHeading(doc, y, 'Informacije o sastanku');

  const datumFmt = sast.datum
    ? String(sast.datum).split('-').reverse().join('.') : '—';
  const vremeFmt = sast.vreme ? String(sast.vreme).slice(0, 5) : '—';

  const SASTANAK_TIPOVI = {
    redovni: 'Redovni', vanredni: 'Vanredni', koordinacioni: 'Koordinacioni',
    projektni: 'Projektni', prezentacija: 'Prezentacija', obuka: 'Obuka',
    operativni: 'Operativni',
  };

  y = drawMetaRow(doc, y, 'Datum', datumFmt);
  y = drawMetaRow(doc, y, 'Vreme', vremeFmt);
  y = drawMetaRow(doc, y, 'Mesto', sast.mesto || '—');
  y = drawMetaRow(doc, y, 'Tip', SASTANAK_TIPOVI[sast.tip] || sast.tip || '—');
  y = drawMetaRow(doc, y, 'Vodio', sast.vodioLabel || sast.vodioEmail || '—');
  y = drawMetaRow(doc, y, 'Zaključio', sast.zakljucanByEmail || '—');
  y += 4;

  // Učesnici
  if (sast.ucesnici?.length) {
    y = checkPageBreak(doc, y, 20, naslov, pageState);
    y = drawSectionHeading(doc, y, 'Učesnici');

    const ucRow = sast.ucesnici.map(u => [
      u.label || u.email,
      u.pozvan ? 'Da' : 'Ne',
      u.prisutan ? 'Da' : 'Ne',
    ]);
    y = drawTable(doc, y,
      ['Ime / Email', 'Pozvan', 'Prisutan'],
      ucRow,
      [CONTENT_W - 40, 20, 20],
    );
    y += 4;
  }

  // ── STRANA 2+: ZAPISNIK (presek aktivnosti) ──────────────────────────────
  y = checkPageBreak(doc, y, 20, naslov, pageState);
  y = drawSectionHeading(doc, y, 'Zapisnik');

  if (sast.aktivnosti?.length) {
    sast.aktivnosti.forEach((a, idx) => {
      const heightGuess = 20;
      y = checkPageBreak(doc, y, heightGuess, naslov, pageState);

      // Naslov aktivnosti
      doc.setFont('Roboto', 'bold');
      doc.setFontSize(10);
      doc.setTextColor(17, 24, 39);
      const aktNaslov = `${idx + 1}. ${a.naslov}`;
      const aktWrapped = doc.splitTextToSize(aktNaslov, CONTENT_W);
      doc.text(aktWrapped, MARGIN, y);
      y += aktWrapped.length * LINE_H + 1;

      // Meta (odgovoran, rok, status) — jedan red
      if (a.odgLabel || a.rok) {
        doc.setFont('Roboto', 'normal');
        doc.setFontSize(8);
        doc.setTextColor(107, 114, 128);
        const metaParts = [];
        if (a.odgLabel) metaParts.push(`Odgovoran: ${a.odgLabel}`);
        if (a.rokText || a.rok) metaParts.push(`Rok: ${a.rokText || a.rok}`);
        if (a.status) metaParts.push(`Status: ${a.status}`);
        doc.text(metaParts.join('   ·   '), MARGIN + 2, y);
        doc.setTextColor(0, 0, 0);
        y += LINE_H;
      }

      // Sadrzaj (plain text, bez HTML)
      const tekst = (a.sadrzajText || a.napomena || '').trim();
      if (tekst) {
        doc.setFont('Roboto', 'normal');
        doc.setFontSize(9);
        doc.setTextColor(31, 41, 55);
        const lines = doc.splitTextToSize(tekst, CONTENT_W - 4);
        lines.forEach(line => {
          y = checkPageBreak(doc, y, LINE_H + 1, naslov, pageState);
          doc.text(line, MARGIN + 2, y);
          y += LINE_H;
        });
      }

      y += 3;
      doc.setDrawColor(229, 231, 235);
      doc.line(MARGIN, y, PAGE_W - MARGIN, y);
      y += 4;
    });
  } else {
    doc.setFont('Roboto', 'normal');
    doc.setFontSize(9);
    doc.setTextColor(107, 114, 128);
    doc.text('Nema aktivnosti.', MARGIN, y);
    y += LINE_H + 4;
  }

  // ── STRANA N: AKCIONI PLAN ───────────────────────────────────────────────
  if (includeAkcije && sast.akcioniPlan?.length) {
    y = checkPageBreak(doc, y, 20, naslov, pageState);
    y = drawSectionHeading(doc, y, 'Akcioni plan');

    const akcijeRows = sast.akcioniPlan.map((a, i) => [
      String(i + 1),
      a.naslov || '',
      a.odgovoranLabel || a.odgovoranText || a.odgovoranEmail || '—',
      a.rokText || (a.rok ? String(a.rok).split('-').reverse().join('.') : '—'),
      a.effectiveStatus || a.status || '—',
    ]);

    y = checkPageBreak(doc, y, akcijeRows.length * LINE_H + 16, naslov, pageState);
    y = drawTable(doc, y,
      ['RB', 'Naslov', 'Odgovoran', 'Rok', 'Status'],
      akcijeRows,
      [12, CONTENT_W - 92, 35, 25, 20],
    );
    y += 4;
  }

  // ── STRANA N+1: POTPISI ─────────────────────────────────────────────────
  if (includePotpisi && sast.ucesnici?.length) {
    y = checkPageBreak(doc, y, 30, naslov, pageState);
    y = drawSectionHeading(doc, y, 'Potpisi učesnika');

    sast.ucesnici.filter(u => u.prisutan).forEach(u => {
      y = checkPageBreak(doc, y, 18, naslov, pageState);
      doc.setFont('Roboto', 'normal');
      doc.setFontSize(9);
      doc.setTextColor(17, 24, 39);
      doc.text(u.label || u.email, MARGIN, y);
      doc.setDrawColor(180, 180, 180);
      doc.line(MARGIN + 60, y + 1, PAGE_W - MARGIN, y + 1);
      y += 14;
    });
  }

  // ── Retrospektivno postavi brojeve stranica ───────────────────────────────
  const totalPages = doc.internal.getNumberOfPages();
  for (let i = 1; i <= totalPages; i++) {
    doc.setPage(i);
    drawPageHeader(doc, naslov, i, totalPages);
  }

  return doc.output('blob');
}
