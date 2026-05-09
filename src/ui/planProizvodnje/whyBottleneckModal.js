/**
 * Plan proizvodnje — „Zašto ovde?“ / bottleneck panel.
 * Čita isključivo polja koja već dolaze iz v_production_operations(_effective),
 * bez novog backend-a.
 */

import { escHtml } from '../../lib/dom.js';
import { formatDate } from '../../lib/date.js';
import { rokUrgencyClass, formatSecondsHm, plannedSeconds } from '../../services/planProizvodnje.js';

let active = null;

/**
 * @param {object} row — red kao iz v_production_operations_effective
 * @returns {{
 *   summaryLine: string,
 *   tags: { key: string, label: string }[],
 *   blocks: { title: string, lines: string[] }[],
 *   footnote: string
 * }}
 */
export function buildWhyExplanation(row) {
  if (!row || typeof row !== 'object') {
    return {
      summaryLine: 'Nema podataka za analizu.',
      tags: [],
      blocks: [],
      footnote: '',
    };
  }

  const tags = [];
  const blocks = [];

  const status = row.local_status || 'waiting';
  const urgent = !!row.is_urgent;
  const ready = !!row.is_ready_for_processing;
  const prevSt = row.previous_operation_status || 'none';
  const rokClass = rokUrgencyClass(row.rok_izrade);
  const rokLabel = row.rok_izrade ? formatDate(row.rok_izrade) : null;

  const effMac = row.assigned_machine_code || row.effective_machine_code || row.original_machine_code;
  const origMac = row.original_machine_code;

  /* Tagovi (vizuelni signal na vrhu) */
  if (status === 'blocked') tags.push({ key: 'blocked', label: 'Blokirano' });
  if (!ready) tags.push({ key: 'pred', label: 'Čeka prethodnu op.' });
  if (urgent) tags.push({ key: 'hitno', label: 'HITNO (RN)' });
  if (rokClass === 'overdue' || rokClass === 'today') {
    tags.push({ key: 'rok', label: rokClass === 'overdue' ? 'Rok istekao' : 'Rok danas' });
  }
  if (row.is_cooperation_effective) tags.push({ key: 'coop', label: 'Kooperacija' });
  if (!row.is_non_machining && !row.cam_ready) tags.push({ key: 'cam', label: 'CAM nije spreman' });

  /* Blok 1: glavni uzrok (šta trenutno vuče) */
  const mainLines = [];
  if (status === 'blocked') {
    mainLines.push(
      'Operacija je u statusu **Blokirano** u Planu proizvodnje — planer je eksplicitno zaustavio rad ili sledeći korak dok se blokada ne reši.',
    );
  }
  if (!ready) {
    const po = row.previous_operation_operacija;
    const pm = row.previous_operation_machine_code;
    const prevHuman = po != null
      ? `operacija ${String(po).padStart(2, '0')}${pm ? ` (mašina ${pm})` : ''}`
      : 'prethodna operacija (nepoznat broj)';
    if (prevSt === 'in_progress') {
      mainLines.push(
        `Prethodni korak u tehnološkom nizu je **u radu** (${prevHuman}). Ova operacija ne može da se smatra „spremnom" dok se prethodna ne zatvori po količini.`,
      );
    } else if (prevSt === 'not_started') {
      mainLines.push(
        `Prethodni korak **nije počeo** (${prevHuman}). Ova operacija čeka start prethodne.`,
      );
    } else {
      mainLines.push(
        `**Spremnost** za obradu na ovoj operaciji nije ispunjena — čeka se završetak ${prevHuman}.`,
      );
    }
  }
  if (row.is_cooperation_effective) {
    const partner = row.cooperation_partner ? String(row.cooperation_partner).trim() : '';
    const ret = row.cooperation_expected_return ? formatDate(row.cooperation_expected_return) : '';
    const src = row.cooperation_source || '';
    mainLines.push(
      `**Kooperacija** je aktivna${src ? ` (izvor: ${src})` : ''}.${partner ? ` Partner: ${partner}.` : ''}${ret ? ` Očekovani povratak (plan): ${ret}.` : ''}`,
    );
  }
  if (!row.is_non_machining && !row.cam_ready && ready && status !== 'blocked') {
    mainLines.push(
      '**CAM** nije označen kao spreman — ako je programiranje usko grlo, operacija može čekati i uprkos slobodnoj mašini.',
    );
  }
  if ((rokClass === 'overdue' || rokClass === 'today') && mainLines.length === 0) {
    mainLines.push(
      rokClass === 'overdue'
        ? `**Rok isporuke** je u prošlosti (${rokLabel || '—'}) — pritisak na redosled, ali modul ne menja automatski prethodne operacije.`
        : `**Rok isporuke** je danas (${rokLabel || '—'}) — prioritet u listi pomoću HITNO/pin/rok sortiranja.`,
    );
  }

  if (mainLines.length === 0) {
    mainLines.push(
      'Nema jednog „tvrdog" blokatora u podacima: prethodna operacija je zatvorena, status nije blokiran, ova operacija se u listi ponaša prema **redosledu na mašini** (ručni prioritet + automatsko sortiranje).',
    );
  }

  blocks.push({ title: 'Šta trenutno vuče kašnjenje / red', lines: mainLines });

  /* Blok 2: zašto je u ovom položaju liste */
  const orderLines = [];
  const man = row.shift_sort_order;
  if (man != null && man !== '') {
    orderLines.push(
      `Postoji **ručni prioritet** (pin / drag-and-drop): \`shift_sort_order = ${escHtml(String(man))}\` — ovaj red ide pre automatskog sorta.`,
    );
  } else {
    orderLines.push('**Nema** ručnog \`shift_sort_order\` — redosled je od automatskog pravila u bazi.');
  }

  const bucket = row.auto_sort_bucket;
  if (bucket != null && bucket !== '') {
    orderLines.push(`**Automatski bucket** (\`auto_sort_bucket = ${escHtml(String(bucket))}\`): ${escHtml(describeAutoSortBucket(row))}`);
  }

  orderLines.push(
    'Globalno sortiranje u aplikaciji: prvo ručni red, zatim bucket, pa **rok** (`rok_izrade`), pa BigTehn **prioritet** (`prioritet_bigtehn`), pa RN i broj operacije.',
  );

  orderLines.push(
    `Plan u ovom modulu je **lista prioriteta po mašini (${escHtml(String(effMac || '—'))})**, ne kalendarsko zakazivanje po satima. Pozicija u listi određuje ko je „sledeći na redu" kada mašina oslobodi kapacitet.`,
  );

  blocks.push({ title: 'Zašto je u ovom redosledu na mašini', lines: orderLines });

  /* Blok 3: kontekst RN-a */
  const ctxLines = [];
  ctxLines.push(`**Efektivna mašina:** ${escHtml(String(effMac || '—'))}${origMac && origMac !== effMac ? ` (original iz BigTehn-a: ${escHtml(String(origMac))})` : ''}.`);
  ctxLines.push(`**Lokalni status:** ${escHtml(statusLabel(status))}. **Prijava u BigTehn:** ${row.is_done_in_bigtehn ? 'završena' : 'nije završena'} · komada urađeno ${row.komada_done ?? 0} / ${row.komada_total ?? 0}.`);
  ctxLines.push(`**Planirano / prijavljeno vreme:** ${escHtml(formatSecondsHm(plannedSeconds(row)))} / ${escHtml(formatSecondsHm(row.real_seconds))}.`);
  if (row.shift_note && String(row.shift_note).trim()) {
    ctxLines.push(`**Napomena smene:** ${escHtml(String(row.shift_note).trim())}`);
  }

  blocks.push({ title: 'Kontekst operacije', lines: ctxLines });

  /* Blok 4: šta pomeraj znači */
  const footnote = 'Pomeranje nagore u listi skraćuje čekanje **na ovoj mašini**, ne ubrzava automatski prethodne operacije u tehnološkom niti drugu mašinu. Za uticaj na ceo RN koristite tehnološki postupak (📋) i druge mašine u lancu.';

  blocks.push({
    title: 'Šta ako se promeni redosled',
    lines: [
      footnote,
    ],
  });

  const summaryLine = pickSummaryLine({
    status,
    ready,
    prevSt,
    urgent,
    rokClass,
    cooperation: !!row.is_cooperation_effective,
    camBlocking: !row.is_non_machining && !row.cam_ready,
    blocked: status === 'blocked',
  });

  return {
    summaryLine,
    tags,
    blocks,
    footnote,
  };
}

function pickSummaryLine(o) {
  if (o.blocked) return 'Glavni signal: operacija je ručno blokirana u planu.';
  if (!o.ready) {
    if (o.prevSt === 'in_progress') return 'Glavni signal: čeka se završetak prethodne operacije koja je u radu.';
    if (o.prevSt === 'not_started') return 'Glavni signal: prethodna operacija u nizu još nije počela.';
    return 'Glavni signal: tehnološki niz — čeka se prethodni korak.';
  }
  if (o.cooperation) return 'Glavni signal: kooperacija (spoljni tok).';
  if (o.camBlocking) return 'Glavni signal: moguće CAM / programiranje kao usko grlo.';
  if (o.urgent) return 'Glavni signal: RN je označen kao HITNO — biće više u automatskom „bucket"-u.';
  if (o.rokClass === 'overdue' || o.rokClass === 'today') return 'Glavni signal: pritisak roka isporuke.';
  return 'Glavni signal: redosled na mašini (ručno + automatski sort), bez trenutnog „tvrđeg" blokatora u podacima.';
}

function statusLabel(s) {
  switch (s) {
    case 'waiting': return 'Čeka';
    case 'in_progress': return 'U radu';
    case 'blocked': return 'Blokirano';
    case 'completed': return 'Završeno';
    default: return s || '—';
  }
}

/**
 * Objašnjenje auto_sort_bucket (SQL iz add_production_g2_readiness_urgency.sql).
 * @param {object} row
 */
export function describeAutoSortBucket(row) {
  const st = row.local_status || 'waiting';
  const prevDone = row.is_ready_for_processing;
  const b = Number(row.auto_sort_bucket);

  if (st === 'blocked') return 'prioritet za operacije označene kao blokirane (bucket 7).';
  if (b === 1) return 'HITNO RN + spremno + U radu (najviši operativni signal).';
  if (b === 2) return 'HITNO RN + spremno + Čeka.';
  if (b === 3) return 'HITNO RN + još uvek čeka prethodnu operaciju.';
  if (b === 4) return 'standard + spremno + U radu.';
  if (b === 5) return 'standard + spremno + Čeka.';
  if (b === 6) return 'standard + čeka prethodnu operaciju (često većina backlog-a).';
  if (b === 7) return 'blokirano u planu.';
  if (b === 8) return 'preostalo / ostalo (npr. završeno u planu ili rubni slučaj).';

  /* Fallback ako broj nije poznat */
  if (!prevDone && st === 'waiting') return 'čeka prethodni korak u nizu (niži prioritet dok prethodna ne odmakne).';
  if (row.is_urgent) return 'HITNO RN — biće iznad standardnih u automatskom delu sorta.';
  return 'mešovit automatski prioritet (vidi rok i BigTehn prioritet).';
}

function lineToHtml(line) {
  const parts = String(line).split(/\*\*(.+?)\*\*/g);
  let html = '';
  for (let i = 0; i < parts.length; i += 1) {
    html += i % 2 === 1 ? `<strong>${escHtml(parts[i])}</strong>` : escHtml(parts[i]);
  }
  return html;
}

/**
 * @param {object} row
 * @returns {Promise<void>}
 */
export function openWhyBottleneckModal(row) {
  if (active) active.close();
  const data = buildWhyExplanation(row);

  return new Promise((resolve) => {
    const root = document.createElement('div');
    root.className = 'wb-overlay';
    root.setAttribute('aria-hidden', 'false');

    const subtitle = [row?.rn_ident_broj, row?.operacija != null ? `op. ${row.operacija}` : '']
      .filter(Boolean)
      .join(' · ');

    root.innerHTML = `
      <div class="wb-modal" role="dialog" aria-modal="true" aria-labelledby="wbTitle">
        <header class="wb-head">
          <div>
            <div id="wbTitle" class="wb-title">Zašto je ovo ovde?</div>
            <div class="wb-sub">${escHtml(subtitle || 'Operacija')}</div>
            <div class="wb-tags">${data.tags.map(t => `<span class="wb-tag wb-tag-${escHtml(t.key)}">${escHtml(t.label)}</span>`).join('')}</div>
          </div>
          <button type="button" class="wb-close" aria-label="Zatvori">×</button>
        </header>
        <div class="wb-summary">${escHtml(data.summaryLine)}</div>
        <div class="wb-body">
          ${data.blocks.map((bl) => `
            <section class="wb-block">
              <h3 class="wb-block-title">${escHtml(bl.title)}</h3>
              <ul class="wb-list">
                ${bl.lines.map((ln) => `<li>${lineToHtml(ln)}</li>`).join('')}
              </ul>
            </section>
          `).join('')}
        </div>
        <footer class="wb-foot">
          <button type="button" class="btn wb-btn-close">Zatvori</button>
        </footer>
      </div>
    `;

    function close() {
      if (root.parentNode) root.parentNode.removeChild(root);
      document.removeEventListener('keydown', onKey);
      if (active && active.root === root) active = null;
      resolve();
    }

    function onKey(e) {
      if (e.key === 'Escape') close();
    }

    document.addEventListener('keydown', onKey);
    root.addEventListener('click', (e) => {
      if (e.target === root) close();
    });
    root.querySelector('.wb-close').addEventListener('click', close);
    root.querySelector('.wb-btn-close').addEventListener('click', close);

    active = { root, close };
    document.body.appendChild(root);
    setTimeout(() => root.querySelector('.wb-close')?.focus(), 30);
  });
}

export function teardownWhyBottleneckModal() {
  if (active) {
    active.close();
    active = null;
  }
}
