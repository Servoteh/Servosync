/**
 * Reversi — modali (novo zaduženje, povraćaj, dodaj alat).
 */

import { escHtml, showToast } from '../../lib/dom.js';
import {
  fetchAvailableTools,
  fetchEmployees,
  issueReversal,
  confirmReturn,
  fetchDocumentLines,
  fetchDocumentById,
  fetchEmployeeDepartment,
  uploadReversalPdf,
  updateDocPdfMeta,
  insertTool,
  initialPlacementForTool,
  getMagacinLocationId,
  clearMagacinLocationCache,
} from '../../services/reversiService.js';
import { generateReversalPdf, openPdfInNewTab, getPdfBlob } from '../../lib/reversiPdf.js';

function modalShell(title, bodyHtml, footerHtml, id) {
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="kadr-modal-overlay rev-modal-overlay" id="${id}" role="dialog" aria-modal="true">
      <div class="kadr-modal rev-modal">
        <div class="kadr-modal-header">
          <h2 id="${id}Title">${escHtml(title)}</h2>
          <button type="button" class="kadr-modal-close" data-rev-close aria-label="Zatvori">×</button>
        </div>
        <div class="kadr-modal-body rev-modal-body">${bodyHtml}</div>
        <div class="kadr-modal-footer rev-modal-footer">${footerHtml}</div>
      </div>
    </div>`;
  return wrap.firstElementChild;
}

function closeOverlay(el) {
  el?.remove();
}

function attachClose(root, onClose) {
  root.querySelector('[data-rev-close]')?.addEventListener('click', () => {
    closeOverlay(root);
    onClose?.();
  });
  root.addEventListener('click', e => {
    if (e.target === root) {
      closeOverlay(root);
      onClose?.();
    }
  });
}

function fmtDateShort(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return String(iso).slice(0, 10);
  return d.toLocaleDateString('sr-Latn-RS', { day: 'numeric', month: 'numeric', year: 'numeric' });
}

/**
 * @param {{ onSuccess?: () => void, preselectedTool?: object|null }} opts
 */
export function openIssueReversalModal(opts = {}) {
  const id = `revIssue_${Date.now()}`;
  let step = 1;
  const state = {
    docType: 'TOOL',
    recipientKind: 'EMPLOYEE',
    recipientEmployeeId: null,
    recipientEmployeeName: '',
    recipientDepartment: '',
    companyName: '',
    companyPib: '',
    expectedReturnDate: '',
    napomenaDoc: '',
    toolLines: [],
    coopLines: [],
    empSearch: '',
    empDropdown: [],
    toolPickSearch: '',
    availableTools: [],
  };

  if (opts.preselectedTool?.id) {
    state.toolLines.push({
      tool_id: opts.preselectedTool.id,
      oznaka: opts.preselectedTool.oznaka,
      naziv: opts.preselectedTool.naziv,
      napomena: '',
    });
  }

  const overlay = modalShell(
    'Novo zaduženje',
    '<div id="revIssueBody"></div>',
    '<div id="revIssueFoot"></div>',
    id,
  );
  document.body.appendChild(overlay);
  attachClose(overlay, opts.onClose);

  async function loadAvailable() {
    const r = await fetchAvailableTools();
    state.availableTools = r.ok && Array.isArray(r.data) ? r.data : [];
  }

  async function loadEmployeesDebounced(q) {
    const r = await fetchEmployees(q);
    state.empDropdown = r.ok && Array.isArray(r.data) ? r.data : [];
  }

  let empT = null;

  function paint() {
    const body = overlay.querySelector('#revIssueBody');
    const foot = overlay.querySelector('#revIssueFoot');
    if (!body || !foot) return;

    if (step === 1) {
      body.innerHTML = `
        <div class="rev-form-grid">
          <fieldset class="rev-fieldset">
            <legend>Tip dokumenta</legend>
            <label><input type="radio" name="revDocType" value="TOOL" ${state.docType === 'TOOL' ? 'checked' : ''}/> Alat</label>
            <label><input type="radio" name="revDocType" value="COOPERATION_GOODS" ${state.docType === 'COOPERATION_GOODS' ? 'checked' : ''}/> Kooperaciona roba</label>
          </fieldset>
          <fieldset class="rev-fieldset">
            <legend>Primalac</legend>
            <label><input type="radio" name="revRec" value="EMPLOYEE" ${state.recipientKind === 'EMPLOYEE' ? 'checked' : ''}/> Radnik</label>
            <label><input type="radio" name="revRec" value="DEPARTMENT" ${state.recipientKind === 'DEPARTMENT' ? 'checked' : ''}/> Odeljenje</label>
            <label><input type="radio" name="revRec" value="EXTERNAL_COMPANY" ${state.recipientKind === 'EXTERNAL_COMPANY' ? 'checked' : ''}/> Eksterna firma</label>
          </fieldset>
          <div id="revRecFields"></div>
          <label>Rok povraćaja <input type="date" id="revExpRet" value="${escHtml(state.expectedReturnDate || '')}" class="input"/></label>
          <label>Napomena dokumenta <textarea id="revDocNote" rows="2" class="input">${escHtml(state.napomenaDoc || '')}</textarea></label>
        </div>`;

      const rf = body.querySelector('#revRecFields');
      if (state.recipientKind === 'EMPLOYEE') {
        rf.innerHTML = `
          <div class="rev-autocomplete-wrap">
            <label>Pretraga radnika
              <input type="text" id="revEmpSearch" class="input" placeholder="Ime…" value="${escHtml(state.recipientEmployeeName || state.empSearch || '')}" autocomplete="off"/>
            </label>
            <div id="revEmpList" class="rev-autocomplete-list"></div>
          </div>`;
      } else if (state.recipientKind === 'DEPARTMENT') {
        rf.innerHTML = `<label>Naziv odeljenja <input type="text" id="revDept" class="input" value="${escHtml(state.recipientDepartment)}"/></label>`;
      } else {
        rf.innerHTML = `
          <label>Naziv firme <input type="text" id="revCoName" class="input" value="${escHtml(state.companyName)}"/></label>
          <label>PIB (opciono) <input type="text" id="revCoPib" class="input" value="${escHtml(state.companyPib)}"/></label>`;
      }

      body.querySelectorAll('input[name="revDocType"]').forEach(r => {
        r.addEventListener('change', () => {
          state.docType = r.value;
          paint();
        });
      });
      body.querySelectorAll('input[name="revRec"]').forEach(r => {
        r.addEventListener('change', () => {
          state.recipientKind = r.value;
          paint();
        });
      });

      const empIn = body.querySelector('#revEmpSearch');
      if (empIn) {
        empIn.addEventListener('input', () => {
          state.empSearch = empIn.value;
          clearTimeout(empT);
          empT = setTimeout(async () => {
            await loadEmployeesDebounced(state.empSearch);
            const list = body.querySelector('#revEmpList');
            if (!list) return;
            list.innerHTML = state.empDropdown
              .map(
                e =>
                  `<button type="button" class="rev-ac-item" data-eid="${escHtml(e.id)}" data-name="${escHtml(e.full_name)}">${escHtml(e.full_name)}</button>`,
              )
              .join('');
            list.querySelectorAll('.rev-ac-item').forEach(btn => {
              btn.addEventListener('click', () => {
                state.recipientEmployeeId = btn.getAttribute('data-eid');
                state.recipientEmployeeName = btn.getAttribute('data-name') || '';
                empIn.value = state.recipientEmployeeName;
                list.innerHTML = '';
              });
            });
          }, 300);
        });
      }

      body.querySelector('#revExpRet')?.addEventListener('change', e => {
        state.expectedReturnDate = e.target.value || '';
      });
      body.querySelector('#revDocNote')?.addEventListener('input', e => {
        state.napomenaDoc = e.target.value;
      });
      body.querySelector('#revDept')?.addEventListener('input', e => {
        state.recipientDepartment = e.target.value;
      });
      body.querySelector('#revCoName')?.addEventListener('input', e => {
        state.companyName = e.target.value;
      });
      body.querySelector('#revCoPib')?.addEventListener('input', e => {
        state.companyPib = e.target.value;
      });

      foot.innerHTML = `
        <button type="button" class="btn" data-rev-close>Otkaži</button>
        <button type="button" class="btn btn-primary" id="revIssueNext">Sledeće →</button>`;
      foot.querySelector('#revIssueNext')?.addEventListener('click', () => {
        if (state.recipientKind === 'EMPLOYEE') {
          if (!state.recipientEmployeeId) {
            showToast('Izaberite radnika iz liste predloga');
            return;
          }
        }
        if (state.recipientKind === 'DEPARTMENT' && !state.recipientDepartment.trim()) {
          showToast('Unesite odeljenje');
          return;
        }
        if (state.recipientKind === 'EXTERNAL_COMPANY' && !state.companyName.trim()) {
          showToast('Unesite naziv firme');
          return;
        }
        step = 2;
        void paintStep2();
      });
      return;
    }

    if (step === 2) void paintStep2();
    if (step === 3) void paintStep3();
  }

  async function paintStep2() {
    const body = overlay.querySelector('#revIssueBody');
    const foot = overlay.querySelector('#revIssueFoot');
    if (!body || !foot) return;

    if (state.docType === 'TOOL') {
      await loadAvailable();
      const optsHtml = state.availableTools
        .filter(t => !state.toolLines.some(l => l.tool_id === t.id))
        .map(t => `<option value="${escHtml(t.id)}">${escHtml(t.oznaka)} — ${escHtml(t.naziv)}</option>`)
        .join('');
      body.innerHTML = `
        <p class="rev-muted">Dodajte bar jedan alat.</p>
        <div class="rev-row">
          <select id="revToolSel" class="input"><option value="">— Izaberi alat —</option>${optsHtml}</select>
          <button type="button" class="btn" id="revToolAdd">+ Dodaj</button>
        </div>
        <table class="rev-table"><thead><tr><th>Oznaka</th><th>Naziv</th><th>Pribor</th><th></th></tr></thead>
        <tbody id="revToolRows"></tbody></table>`;

      function renderToolRows() {
        const tb = body.querySelector('#revToolRows');
        if (!tb) return;
        tb.innerHTML = state.toolLines
          .map(
            (l, i) =>
              `<tr><td>${escHtml(l.oznaka)}</td><td>${escHtml(l.naziv)}</td><td><input type="text" class="input input-sm" data-tln="${i}" value="${escHtml(l.napomena || '')}"/></td><td><button type="button" class="btn btn-sm" data-rm="${i}">🗑</button></td></tr>`,
          )
          .join('');
        tb.querySelectorAll('input[data-tln]').forEach(inp => {
          inp.addEventListener('input', () => {
            const idx = Number(inp.getAttribute('data-tln'));
            if (state.toolLines[idx]) state.toolLines[idx].napomena = inp.value;
          });
        });
        tb.querySelectorAll('[data-rm]').forEach(btn => {
          btn.addEventListener('click', () => {
            const idx = Number(btn.getAttribute('data-rm'));
            state.toolLines.splice(idx, 1);
            renderToolRows();
          });
        });
      }
      renderToolRows();

      body.querySelector('#revToolAdd')?.addEventListener('click', () => {
        const sel = body.querySelector('#revToolSel');
        const tid = sel?.value;
        if (!tid) return;
        const t = state.availableTools.find(x => x.id === tid);
        if (!t) return;
        state.toolLines.push({ tool_id: t.id, oznaka: t.oznaka, naziv: t.naziv, napomena: '' });
        sel.value = '';
        renderToolRows();
      });

      foot.innerHTML = `
        <button type="button" class="btn" id="revBack2">← Nazad</button>
        <button type="button" class="btn btn-primary" id="revTo3">Sledeće →</button>`;
      foot.querySelector('#revBack2')?.addEventListener('click', () => {
        step = 1;
        paint();
      });
      foot.querySelector('#revTo3')?.addEventListener('click', () => {
        if (state.toolLines.length === 0) {
          showToast('Dodajte bar jedan alat');
          return;
        }
        step = 3;
        paintStep3();
      });
    } else {
      body.innerHTML = `
        <div class="rev-coop-add rev-form-grid">
          <label>Broj crteža <input type="text" id="revDrw" class="input"/></label>
          <label>Naziv dela <input type="text" id="revPn" class="input"/></label>
          <label>Količina <input type="number" id="revQty" class="input" step="0.001" value="1"/></label>
          <label>Jedinica <input type="text" id="revUnit" class="input" value="kom"/></label>
          <label>Radni nalog (opciono) <input type="text" id="revWo" class="input"/></label>
          <label>Napomena <input type="text" id="revLnNote" class="input"/></label>
          <button type="button" class="btn" id="revCoopAdd">+ Dodaj stavku</button>
        </div>
        <table class="rev-table"><thead><tr><th>Crtež</th><th>Naziv</th><th>Kol</th><th>Napomena</th><th></th></tr></thead>
        <tbody id="revCoopRows"></tbody></table>`;

      function renderCoop() {
        const tb = body.querySelector('#revCoopRows');
        if (!tb) return;
        tb.innerHTML = state.coopLines
          .map(
            (l, i) =>
              `<tr><td>${escHtml(l.drawing_no)}</td><td>${escHtml(l.part_name)}</td><td>${escHtml(String(l.quantity))}</td><td>${escHtml(l.napomena || '')}</td><td><button type="button" class="btn btn-sm" data-cr="${i}">🗑</button></td></tr>`,
          )
          .join('');
        tb.querySelectorAll('[data-cr]').forEach(btn => {
          btn.addEventListener('click', () => {
            state.coopLines.splice(Number(btn.getAttribute('data-cr')), 1);
            renderCoop();
          });
        });
      }

      body.querySelector('#revCoopAdd')?.addEventListener('click', () => {
        const drawing_no = body.querySelector('#revDrw')?.value?.trim() || '';
        const part_name = body.querySelector('#revPn')?.value?.trim() || '';
        const quantity = Number(body.querySelector('#revQty')?.value) || 1;
        const unit = body.querySelector('#revUnit')?.value?.trim() || 'kom';
        const work_order_id = body.querySelector('#revWo')?.value?.trim() || '';
        const napomena = body.querySelector('#revLnNote')?.value?.trim() || '';
        if (!drawing_no && !part_name) {
          showToast('Unesite broj crteža ili naziv dela');
          return;
        }
        state.coopLines.push({
          drawing_no,
          part_name,
          quantity,
          unit,
          work_order_id,
          napomena,
        });
        renderCoop();
      });
      renderCoop();

      foot.innerHTML = `
        <button type="button" class="btn" id="revBack2c">← Nazad</button>
        <button type="button" class="btn btn-primary" id="revTo3c">Sledeće →</button>`;
      foot.querySelector('#revBack2c')?.addEventListener('click', () => {
        step = 1;
        paint();
      });
      foot.querySelector('#revTo3c')?.addEventListener('click', () => {
        if (state.coopLines.length === 0) {
          showToast('Dodajte bar jednu stavku');
          return;
        }
        step = 3;
        paintStep3();
      });
    }
  }

  function paintStep3() {
    const body = overlay.querySelector('#revIssueBody');
    const foot = overlay.querySelector('#revIssueFoot');
    if (!body || !foot) return;

    const recLabel =
      state.recipientKind === 'EMPLOYEE'
        ? state.recipientEmployeeName || '—'
        : state.recipientKind === 'DEPARTMENT'
          ? state.recipientDepartment
          : state.companyName;

    let linesHtml = '';
    if (state.docType === 'TOOL') {
      linesHtml = state.toolLines
        .map(
          (l, i) =>
            `<li>${i + 1}. ${escHtml(l.naziv)} (oznaka: ${escHtml(l.oznaka)}) — ${escHtml(l.napomena || '—')}</li>`,
        )
        .join('');
    } else {
      linesHtml = state.coopLines
        .map(
          (l, i) =>
            `<li>${i + 1}. ${escHtml(l.drawing_no || '—')} — ${escHtml(l.part_name)} — ${escHtml(String(l.quantity))} ${escHtml(l.unit)}</li>`,
        )
        .join('');
    }

    body.innerHTML = `
      <div class="rev-preview">
        <h3>Pregled reversal dokumenta</h3>
        <p><strong>Primalac:</strong> ${escHtml(recLabel)}</p>
        <p><strong>Tip:</strong> ${state.docType === 'TOOL' ? 'Alat' : 'Kooperaciona roba'}</p>
        <p><strong>Rok povraćaja:</strong> ${escHtml(state.expectedReturnDate || '—')}</p>
        <ul>${linesHtml}</ul>
      </div>`;

    foot.innerHTML = `
      <button type="button" class="btn" id="revBack3">← Nazad</button>
      <button type="button" class="btn btn-primary" id="revSubmit">Kreiraj dokument</button>`;
    foot.querySelector('#revBack3')?.addEventListener('click', () => {
      step = 2;
      void paintStep2();
    });
    foot.querySelector('#revSubmit')?.addEventListener('click', async () => {
      const btn = foot.querySelector('#revSubmit');
      if (btn) btn.disabled = true;
      try {
        const payload = {
          doc_type: state.docType,
          recipient_type: state.recipientKind,
          expected_return_date: state.expectedReturnDate || null,
          napomena: state.napomenaDoc || null,
          lines: [],
        };
        if (state.recipientKind === 'EMPLOYEE') {
          payload.recipient_employee_id = state.recipientEmployeeId;
          payload.recipient_employee_name = state.recipientEmployeeName || null;
        } else if (state.recipientKind === 'DEPARTMENT') {
          payload.recipient_department = state.recipientDepartment;
        } else {
          payload.recipient_company_name = state.companyName;
          payload.recipient_company_pib = state.companyPib || null;
        }

        if (state.docType === 'TOOL') {
          payload.lines = state.toolLines.map((l, i) => ({
            line_type: 'TOOL',
            tool_id: l.tool_id,
            quantity: 1,
            unit: 'kom',
            napomena: l.napomena || '',
            sort_order: i + 1,
          }));
        } else {
          payload.lines = state.coopLines.map((l, i) => ({
            line_type: 'PRODUCTION_PART',
            drawing_no: l.drawing_no || null,
            part_name: l.part_name || null,
            quantity: l.quantity,
            unit: l.unit || 'kom',
            work_order_id: l.work_order_id || null,
            napomena: l.napomena || '',
            sort_order: i + 1,
          }));
        }

        const res = await issueReversal(payload);
        if (!res.ok) {
          showToast(res.error || 'Greška pri kreiranju');
          return;
        }
        const docNum = res.data?.doc_number || '';
        console.log('[reversi] created', docNum, res.data);
        showToast(docNum ? `Reversal ${docNum} kreiran` : 'Dokument kreiran');
        closeOverlay(overlay);
        opts.onSuccess?.();
      } finally {
        if (btn) btn.disabled = false;
      }
    });
  }

  paint();
}

/**
 * @param {{ document: object, magacinLocationId: string|null, locations: object[], onSuccess?: () => void }} opts
 */
export function openConfirmReturnModal(opts) {
  const doc = opts.document;
  const id = `revRet_${Date.now()}`;
  const overlay = modalShell(
    `Potvrdi povraćaj — ${doc.doc_number || ''}`,
    '<div id="revRetBody"><p>Učitavanje…</p></div>',
    '<div id="revRetFoot"></div>',
    id,
  );
  document.body.appendChild(overlay);
  attachClose(overlay, opts.onClose);

  const locOptions = (opts.locations || []).map(
    l =>
      `<option value="${escHtml(l.id)}" ${l.id === opts.magacinLocationId ? 'selected' : ''}>${escHtml(l.location_code)} — ${escHtml(l.name)}</option>`,
  );

  void (async () => {
    const lr = await fetchDocumentLines(doc.id);
    const lines = lr.ok && Array.isArray(lr.data) ? lr.data.filter(x => x.line_status === 'ISSUED') : [];
    const body = overlay.querySelector('#revRetBody');
    const foot = overlay.querySelector('#revRetFoot');
    if (!body || !foot) return;

    body.innerHTML = `
      <p><strong>Primalac:</strong> ${escHtml(
        doc.recipient_employee_name || doc.recipient_department || doc.recipient_company_name || '—',
      )}</p>
      <table class="rev-table"><thead><tr><th></th><th>Stavka</th><th>Zaduženo</th><th>Vraća</th></tr></thead>
      <tbody>${lines
        .map((ln, i) => {
          const tool = ln.rev_tools;
          const tr = Array.isArray(tool) ? tool[0] : tool;
          const label = tr ? `${tr.naziv} (${tr.oznaka})` : ln.part_name || ln.drawing_no || 'Stavka';
          const qty = Number(ln.quantity) || 1;
          return `<tr>
            <td><input type="checkbox" class="rev-ret-chk" data-idx="${i}" checked data-id="${escHtml(ln.id)}"/></td>
            <td>${escHtml(label)}</td>
            <td>${escHtml(String(qty))}</td>
            <td><input type="number" class="input input-sm rev-ret-qty" data-idx="${i}" step="0.001" min="0" max="${qty}" value="${qty}"/></td>
          </tr>`;
        })
        .join('')}</tbody></table>
      <label>Vraća u lokaciju
        <select id="revRetLoc" class="input">${locOptions.join('')}</select>
      </label>
      <label>Napomena o povraćaju <textarea id="revRetNote" rows="2" class="input"></textarea></label>`;

    foot.innerHTML = `
      <button type="button" class="btn" data-rev-close>Otkaži</button>
      <button type="button" class="btn btn-primary" id="revRetSubmit">Potvrdi povraćaj</button>`;

    foot.querySelector('#revRetSubmit')?.addEventListener('click', async () => {
      const locSel = body.querySelector('#revRetLoc');
      const returnTo = locSel?.value;
      if (!returnTo) {
        showToast('Izaberite lokaciju');
        return;
      }
      const returned_lines = [];
      body.querySelectorAll('.rev-ret-chk').forEach(chk => {
        if (!chk.checked) return;
        const idx = chk.getAttribute('data-idx');
        const lineId = chk.getAttribute('data-id');
        const qtyInp = body.querySelector(`.rev-ret-qty[data-idx="${idx}"]`);
        const q = qtyInp ? Number(qtyInp.value) : 0;
        if (lineId && q > 0) returned_lines.push({ line_id: lineId, returned_quantity: q });
      });
      if (returned_lines.length === 0) {
        showToast('Označite bar jednu stavku za povraćaj');
        return;
      }
      const btn = foot.querySelector('#revRetSubmit');
      if (btn) btn.disabled = true;
      try {
        const res = await confirmReturn({
          doc_id: doc.id,
          return_to_location_id: returnTo,
          return_notes: body.querySelector('#revRetNote')?.value?.trim() || '',
          returned_lines,
        });
        if (!res.ok) {
          showToast(res.error || 'Greška');
          return;
        }
        showToast(res.data?.all_returned ? 'Sve vraćeno' : 'Delimičan povraćaj');
        closeOverlay(overlay);
        opts.onSuccess?.();
      } finally {
        if (btn) btn.disabled = false;
      }
    });
  })();
}

export function openAddToolModal({ onSuccess } = {}) {
  const id = `revAddTool_${Date.now()}`;
  const overlay = modalShell(
    'Dodaj alat',
    `<div class="rev-form-grid">
      <label>Oznaka * <input type="text" id="revAddOz" class="input" required/></label>
      <label>Naziv * <input type="text" id="revAddNz" class="input" required/></label>
      <label>Serijski broj <input type="text" id="revAddSn" class="input"/></label>
      <label>Datum kupovine <input type="date" id="revAddDt" class="input"/></label>
      <label>Napomena <textarea id="revAddNo" rows="2" class="input"></textarea></label>
    </div>`,
    `<button type="button" class="btn" data-rev-close>Otkaži</button>
     <button type="button" class="btn btn-primary" id="revAddSubmit">Sačuvaj</button>`,
    id,
  );
  document.body.appendChild(overlay);
  attachClose(overlay);

  overlay.querySelector('#revAddSubmit')?.addEventListener('click', async () => {
    const oz = overlay.querySelector('#revAddOz')?.value?.trim();
    const nz = overlay.querySelector('#revAddNz')?.value?.trim();
    if (!oz || !nz) {
      showToast('Oznaka i naziv su obavezni');
      return;
    }
    const row = {
      oznaka: oz,
      naziv: nz,
      serijski_broj: overlay.querySelector('#revAddSn')?.value?.trim() || null,
      datum_kupovine: overlay.querySelector('#revAddDt')?.value || null,
      napomena: overlay.querySelector('#revAddNo')?.value?.trim() || null,
      status: 'active',
    };
    const ins = await insertTool(row);
    if (!ins.ok) {
      showToast(ins.error || 'Insert neuspešan');
      return;
    }
    const magId = await getMagacinLocationId();
    if (!magId) {
      showToast('Magacin ALAT-MAG-01 nije pronađen — alat je unešen bez početnog smeštaja');
      closeOverlay(overlay);
      onSuccess?.();
      return;
    }
    const pl = await initialPlacementForTool(ins.data.loc_item_ref_id, magId);
    if (!pl.ok) {
      showToast(pl.error || 'Početni smeštaj nije uspeo');
    }
    clearMagacinLocationCache();
    showToast('Alat dodat');
    closeOverlay(overlay);
    onSuccess?.();
  });
}

/**
 * Generiše PDF, otvara tab, upload u pozadini (greška storage-a samo u konzoli).
 * @param {{ docId: string, docNumber: string, docRow?: object|null }} p
 */
export async function handleReversalPdfClick({ docId, docNumber, docRow: docRowOpt }) {
  const lr = await fetchDocumentLines(docId);
  const lines = lr.ok && Array.isArray(lr.data) ? lr.data : [];
  let docRow = docRowOpt;
  if (!docRow) {
    const dr = await fetchDocumentById(docId);
    if (!dr.ok) throw new Error(dr.error || 'Dokument nije učitan');
    docRow = dr.data;
  }
  let employeeDepartment = null;
  if (docRow.recipient_type === 'EMPLOYEE' && docRow.recipient_employee_id) {
    const er = await fetchEmployeeDepartment(docRow.recipient_employee_id);
    employeeDepartment = er.ok ? er.data : null;
  }
  const pdf = await generateReversalPdf(docRow, lines, { employeeDepartment });
  openPdfInNewTab(pdf);
  void (async () => {
    try {
      const path = await uploadReversalPdf(docNumber, getPdfBlob(pdf));
      await updateDocPdfMeta(docId, path);
    } catch (err) {
      console.warn('PDF storage upload nije uspeo:', err);
    }
  })();
}

/**
 * Modal detalja dokumenta sa tabelom stavki i dugmetom za PDF.
 * @param {{ document: object, onPdfSuccess?: () => void }} opts
 */
export function openDocumentDetailsModal(opts) {
  const doc = opts.document;
  const id = `revDet_${Date.now()}`;
  const overlay = modalShell(
    `Dokument — ${doc.doc_number || ''}`,
    '<div id="revDetBody"><p>Učitavanje…</p></div>',
    `<button type="button" class="btn" data-rev-close>Zatvori</button>
     <button type="button" class="btn btn-primary" id="revDetPdf">📄 Generiši PDF</button>`,
    id,
  );
  document.body.appendChild(overlay);
  attachClose(overlay, opts.onClose);

  void (async () => {
    const body = overlay.querySelector('#revDetBody');
    if (!body) return;

    const lr = await fetchDocumentLines(doc.id);
    const lines = lr.ok && Array.isArray(lr.data) ? lr.data : [];

    const html = lines
      .map(ln => {
        const tr = ln.rev_tools;
        const t = Array.isArray(tr) ? tr[0] : tr;
        let name = '—';
        if (ln.line_type === 'TOOL' || doc.doc_type === 'TOOL') {
          name = t ? `${t.oznaka} — ${t.naziv}` : ln.drawing_no || ln.part_name || '—';
        } else {
          name = [ln.drawing_no, ln.part_name].filter(Boolean).join(' — ') || '—';
        }
        return `<tr><td>${escHtml(name)}</td><td>${escHtml(ln.napomena || '—')}</td><td>${escHtml(String(ln.quantity ?? 1))}</td><td>${escHtml(ln.line_status)}</td></tr>`;
      })
      .join('');

    body.innerHTML = `
      <p class="rev-muted"><strong>Primalac:</strong> ${escHtml(
        doc.recipient_employee_name || doc.recipient_department || doc.recipient_company_name || '—',
      )}</p>
      <table class="rev-table"><thead><tr><th>Stavka</th><th>Pribor / napomena</th><th>Kol</th><th>Status</th></tr></thead><tbody>${html || '<tr><td colspan="4">Nema stavki</td></tr>'}</tbody></table>`;

    overlay.querySelector('#revDetPdf')?.addEventListener('click', async () => {
      const btn = overlay.querySelector('#revDetPdf');
      if (btn) {
        btn.disabled = true;
        btn.textContent = '⏳';
      }
      try {
        await handleReversalPdfClick({ docId: doc.id, docNumber: doc.doc_number, docRow: doc });
        opts.onPdfSuccess?.();
      } catch (e) {
        showToast(`Greška pri generisanju PDF-a: ${e instanceof Error ? e.message : String(e)}`, 'error');
      } finally {
        if (btn) {
          btn.disabled = false;
          btn.textContent = '📄 Generiši PDF';
        }
      }
    });
  })();
}

export { fmtDateShort };
