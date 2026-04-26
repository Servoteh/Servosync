/**
 * Email templates za sastanci-notify-dispatch.
 * Svi tekstovi su srpski, latinica.
 * HTML koristi inline CSS (kompatibilno sa Outlook, Gmail).
 */

export type EmailContent = {
  subject: string;
  html: string;
  text: string;
  replyTo?: string;
};

const PRIMARY = '#2563eb';
const GRAY    = '#6b7280';
const BORDER  = '#e5e7eb';
const BG_GRAY = '#f9fafb';

function layout(bodyHtml: string, preheader: string, appUrl: string, settingsUrl: string): string {
  return `<!DOCTYPE html>
<html lang="sr">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Servoteh</title></head>
<body style="margin:0;padding:0;background:#f3f4f6;font-family:Arial,Helvetica,sans-serif;">
<span style="display:none;max-height:0;overflow:hidden;">${preheader}</span>
<table width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f3f4f6;padding:24px 0;">
  <tr><td align="center">
    <table width="600" cellpadding="0" cellspacing="0" border="0"
           style="max-width:600px;width:100%;background:#ffffff;border-radius:8px;
                  border:1px solid ${BORDER};overflow:hidden;">

      <!-- Header -->
      <tr><td style="background:${PRIMARY};padding:20px 32px;">
        <span style="color:#ffffff;font-size:18px;font-weight:bold;letter-spacing:0.5px;">
          SERVOTEH d.o.o.
        </span>
        <span style="color:#bfdbfe;font-size:13px;margin-left:12px;">Sistem za upravljanje</span>
      </td></tr>

      <!-- Body -->
      <tr><td style="padding:32px;">
        ${bodyHtml}
      </td></tr>

      <!-- Footer -->
      <tr><td style="background:${BG_GRAY};padding:16px 32px;border-top:1px solid ${BORDER};">
        <p style="margin:0;font-size:12px;color:${GRAY};line-height:1.6;">
          Ovo je automatska poruka iz Servoteh sistema.<br>
          <a href="${settingsUrl}" style="color:${PRIMARY};text-decoration:none;">
            Promeni podešavanja notifikacija
          </a>
          &nbsp;·&nbsp;
          <a href="${appUrl}" style="color:${PRIMARY};text-decoration:none;">
            Otvori aplikaciju
          </a>
        </p>
      </td></tr>

    </table>
  </td></tr>
</table>
</body>
</html>`;
}

function badge(text: string, color: string): string {
  return `<span style="display:inline-block;background:${color}20;color:${color};
    border:1px solid ${color}40;border-radius:4px;padding:2px 8px;
    font-size:12px;font-weight:600;">${text}</span>`;
}

function metaRow(label: string, value: string): string {
  return `<tr>
    <td style="padding:4px 0;font-size:13px;color:${GRAY};width:120px;">${label}</td>
    <td style="padding:4px 0;font-size:13px;color:#111827;font-weight:600;">${value || '—'}</td>
  </tr>`;
}

// ── Templates ────────────────────────────────────────────────────────────────

function tAkcijaNew(p: Record<string, unknown>): EmailContent {
  const naslov   = String(p.naslov   ?? '');
  const rok      = String(p.rok_text ?? p.rok ?? '');
  const odgLabel = String(p.odg_label ?? '');
  const prioritet = String(p.prioritet ?? '');

  const subject = `Nova akcija: ${naslov}`;
  const preheader = `Dodeljena ti je nova akcija${rok ? ' (rok: ' + rok + ')' : ''}.`;

  const prioBadge = prioritet === 'visok' ? badge('Visok prioritet', '#dc2626')
                  : prioritet === 'srednji' ? badge('Srednji prioritet', '#d97706')
                  : '';

  const html = `
    <h2 style="margin:0 0 4px;font-size:20px;color:#111827;">Nova akcija</h2>
    <p style="margin:0 0 20px;font-size:14px;color:${GRAY};">Dodeljena ti je nova akcija.</p>
    <div style="background:${BG_GRAY};border-left:4px solid ${PRIMARY};
                border-radius:4px;padding:16px 20px;margin-bottom:20px;">
      <p style="margin:0 0 6px;font-size:16px;font-weight:bold;color:#111827;">${naslov}</p>
      ${prioBadge}
      <table style="margin-top:12px;border-collapse:collapse;" cellpadding="0" cellspacing="0">
        ${rok ? metaRow('Rok', rok) : ''}
        ${odgLabel ? metaRow('Odgovoran', odgLabel) : ''}
      </table>
    </div>`;

  const text = `Nova akcija: ${naslov}\n${rok ? 'Rok: ' + rok + '\n' : ''}${odgLabel ? 'Odgovoran: ' + odgLabel + '\n' : ''}`;

  return { subject, html, text };
}

function tAkcijaChanged(p: Record<string, unknown>): EmailContent {
  const naslov    = String(p.naslov ?? '');
  const rok       = String(p.rok_text ?? p.rok ?? '');
  const statusNew = String(p.status_new ?? '');
  const statusOld = String(p.status_old ?? '');
  const odgLabel  = String(p.odg_label ?? '');

  const subject = `Akcija ažurirana: ${naslov}`;
  const preheader = `Promenjena je tvoja akcija.`;

  const statusLine = statusOld && statusNew && statusOld !== statusNew
    ? `<p style="margin:8px 0 0;font-size:13px;color:${GRAY};">
         Status: <s>${statusOld}</s> → <strong>${statusNew}</strong>
       </p>`
    : '';

  const html = `
    <h2 style="margin:0 0 4px;font-size:20px;color:#111827;">Akcija ažurirana</h2>
    <p style="margin:0 0 20px;font-size:14px;color:${GRAY};">Tvoja akcija je promenjena.</p>
    <div style="background:${BG_GRAY};border-left:4px solid #d97706;
                border-radius:4px;padding:16px 20px;margin-bottom:20px;">
      <p style="margin:0 0 6px;font-size:16px;font-weight:bold;color:#111827;">${naslov}</p>
      <table style="margin-top:8px;border-collapse:collapse;" cellpadding="0" cellspacing="0">
        ${rok ? metaRow('Rok', rok) : ''}
        ${odgLabel ? metaRow('Odgovoran', odgLabel) : ''}
      </table>
      ${statusLine}
    </div>`;

  const text = `Akcija ažurirana: ${naslov}\n${rok ? 'Rok: ' + rok + '\n' : ''}${statusNew ? 'Status: ' + statusNew + '\n' : ''}`;

  return { subject, html, text };
}

function tMeetingInvite(p: Record<string, unknown>, appUrl: string): EmailContent {
  const naslov      = String(p.naslov      ?? '');
  const datum       = String(p.datum       ?? '');
  const vreme       = String(p.vreme       ?? '');
  const mesto       = String(p.mesto       ?? '');
  const tip         = String(p.tip         ?? '');
  const organizator = String(p.organizator ?? '');
  const sastanakId  = String(p.sastanak_id ?? '');

  const datumFmt = datum ? datum.split('-').reverse().join('.') : '';
  const subject  = `Pozivnica: ${naslov} — ${datumFmt}`;
  const preheader = `Pozvani ste na sastanak ${datumFmt}${vreme ? ' u ' + vreme : ''}.`;

  const link = sastanakId ? `${appUrl}sastanci/${sastanakId}` : `${appUrl}sastanci`;

  const html = `
    <h2 style="margin:0 0 4px;font-size:20px;color:#111827;">Pozivnica na sastanak</h2>
    <p style="margin:0 0 20px;font-size:14px;color:${GRAY};">Pozvani ste na sledeći sastanak.</p>
    <div style="background:${BG_GRAY};border-left:4px solid ${PRIMARY};
                border-radius:4px;padding:16px 20px;margin-bottom:20px;">
      <p style="margin:0 0 8px;font-size:17px;font-weight:bold;color:#111827;">${naslov}</p>
      ${tip ? badge(tip, PRIMARY) : ''}
      <table style="margin-top:12px;border-collapse:collapse;" cellpadding="0" cellspacing="0">
        ${datumFmt ? metaRow('Datum', datumFmt) : ''}
        ${vreme ? metaRow('Vreme', vreme) : ''}
        ${mesto ? metaRow('Mesto', mesto) : ''}
        ${organizator ? metaRow('Organizator', organizator) : ''}
      </table>
    </div>
    <p style="margin:0;">
      <a href="${link}"
         style="display:inline-block;background:${PRIMARY};color:#ffffff;
                text-decoration:none;padding:10px 20px;border-radius:6px;
                font-size:14px;font-weight:600;">
        Otvori sastanak
      </a>
    </p>`;

  const text = `Pozivnica: ${naslov}\nDatum: ${datumFmt}${vreme ? '\nVreme: ' + vreme : ''}${mesto ? '\nMesto: ' + mesto : ''}\n${link}`;

  return { subject, html, text, replyTo: organizator.includes('@') ? organizator : undefined };
}

function tMeetingLocked(p: Record<string, unknown>, appUrl: string): EmailContent {
  const naslov      = String(p.naslov      ?? '');
  const datum       = String(p.datum       ?? '');
  const vreme       = String(p.vreme       ?? '');
  const zakljucaoBy = String(p.zakljucan_by ?? p.organizator ?? '');
  const sastanakId  = String(p.sastanak_id ?? '');

  const datumFmt = datum ? datum.split('-').reverse().join('.') : '';
  const subject  = `Zapisnik: ${naslov}`;
  const preheader = `Sastanak je zaključan. Zapisnik je dostupan.`;

  const link = sastanakId ? `${appUrl}sastanci/${sastanakId}` : `${appUrl}sastanci`;

  const html = `
    <h2 style="margin:0 0 4px;font-size:20px;color:#111827;">Sastanak zaključan</h2>
    <p style="margin:0 0 20px;font-size:14px;color:${GRAY};">
      Zapisnik je finalizovan i dostupan za preuzimanje.
    </p>
    <div style="background:${BG_GRAY};border-left:4px solid #059669;
                border-radius:4px;padding:16px 20px;margin-bottom:20px;">
      <p style="margin:0 0 8px;font-size:17px;font-weight:bold;color:#111827;">${naslov}</p>
      <table style="margin-top:8px;border-collapse:collapse;" cellpadding="0" cellspacing="0">
        ${datumFmt ? metaRow('Datum', datumFmt) : ''}
        ${vreme ? metaRow('Vreme', vreme) : ''}
        ${zakljucaoBy ? metaRow('Zaključio', zakljucaoBy) : ''}
      </table>
    </div>
    <p style="margin:0;">
      <a href="${link}"
         style="display:inline-block;background:#059669;color:#ffffff;
                text-decoration:none;padding:10px 20px;border-radius:6px;
                font-size:14px;font-weight:600;">
        Preuzmi PDF zapisnik
      </a>
    </p>`;

  const text = `Zapisnik: ${naslov}\nDatum: ${datumFmt}\nZapisnik je dostupan: ${link}`;

  return { subject, html, text };
}

function tActionReminder(p: Record<string, unknown>): EmailContent {
  const naslov    = String(p.naslov    ?? '');
  const rok       = String(p.rok_text  ?? p.rok ?? '');
  const prioritet = String(p.prioritet ?? '');
  const odgLabel  = String(p.odg_label ?? '');

  const isKasni = p.rok && new Date(String(p.rok)) < new Date(String(p.reminder_for ?? new Date().toISOString().slice(0, 10)));
  const isToday = p.rok && String(p.rok) === String(p.reminder_for ?? '');

  const urgencija = isKasni ? badge('KASNI', '#dc2626')
                  : isToday ? badge('Rok danas', '#d97706')
                  : badge('Rok sutra', '#2563eb');

  const subject = isKasni  ? `Akcija kasni: ${naslov}`
                : isToday  ? `Rok danas: ${naslov}`
                :             `Rok sutra: ${naslov}`;
  const preheader = `${subject}${rok ? ' (' + rok + ')' : ''}.`;

  const prioBadge = prioritet === 'visok' ? badge('Visok prioritet', '#dc2626')
                  : prioritet === 'srednji' ? badge('Srednji prioritet', '#d97706')
                  : '';

  const html = `
    <h2 style="margin:0 0 4px;font-size:20px;color:#111827;">Podsetnik za akciju</h2>
    <p style="margin:0 0 20px;font-size:14px;color:${GRAY};">Imate akciju kojoj se bliži rok.</p>
    <div style="background:${BG_GRAY};border-left:4px solid ${isKasni ? '#dc2626' : isToday ? '#d97706' : PRIMARY};
                border-radius:4px;padding:16px 20px;margin-bottom:20px;">
      <p style="margin:0 0 6px;font-size:16px;font-weight:bold;color:#111827;">${naslov}</p>
      <div style="margin-bottom:8px;">${urgencija} ${prioBadge}</div>
      <table style="border-collapse:collapse;" cellpadding="0" cellspacing="0">
        ${rok ? metaRow('Rok', rok) : ''}
        ${odgLabel ? metaRow('Odgovoran', odgLabel) : ''}
      </table>
    </div>`;

  const text = `${subject}\n${rok ? 'Rok: ' + rok + '\n' : ''}${odgLabel ? 'Odgovoran: ' + odgLabel + '\n' : ''}`;

  return { subject, html, text };
}

function tMeetingReminder(p: Record<string, unknown>, appUrl: string): EmailContent {
  const naslov      = String(p.naslov      ?? '');
  const datum       = String(p.datum       ?? '');
  const vreme       = String(p.vreme       ?? '');
  const mesto       = String(p.mesto       ?? '');
  const tip         = String(p.tip         ?? '');
  const organizator = String(p.organizator ?? '');
  const sastanakId  = String(p.sastanak_id ?? '');

  const datumFmt = datum ? datum.split('-').reverse().join('.') : '';
  const subject  = `Sutra: ${naslov}${vreme ? ' u ' + vreme : ''}`;
  const preheader = `Podsetnik: sastanak ${datumFmt} u ${vreme}.`;

  const link = sastanakId ? `${appUrl}sastanci/${sastanakId}` : `${appUrl}sastanci`;

  const html = `
    <h2 style="margin:0 0 4px;font-size:20px;color:#111827;">Podsetnik za sastanak</h2>
    <p style="margin:0 0 20px;font-size:14px;color:${GRAY};">Sutra imate zakazan sastanak.</p>
    <div style="background:#eff6ff;border-left:4px solid ${PRIMARY};
                border-radius:4px;padding:16px 20px;margin-bottom:20px;">
      <p style="margin:0 0 8px;font-size:17px;font-weight:bold;color:#111827;">${naslov}</p>
      ${tip ? badge(tip, PRIMARY) : ''}
      <table style="margin-top:12px;border-collapse:collapse;" cellpadding="0" cellspacing="0">
        ${datumFmt ? metaRow('Datum', datumFmt) : ''}
        ${vreme ? metaRow('Vreme', vreme) : ''}
        ${mesto ? metaRow('Mesto', mesto) : ''}
        ${organizator ? metaRow('Organizator', organizator) : ''}
      </table>
    </div>
    <p style="margin:0;">
      <a href="${link}"
         style="display:inline-block;background:${PRIMARY};color:#ffffff;
                text-decoration:none;padding:10px 20px;border-radius:6px;
                font-size:14px;font-weight:600;">
        Otvori sastanak
      </a>
    </p>`;

  const text = `Podsetnik: ${naslov}\nDatum: ${datumFmt}${vreme ? '\nVreme: ' + vreme : ''}${mesto ? '\nMesto: ' + mesto : ''}\n${link}`;

  return { subject, html, text, replyTo: organizator.includes('@') ? organizator : undefined };
}

// ── Glavni export ─────────────────────────────────────────────────────────────

export function buildEmailFor(
  kind: string,
  payload: Record<string, unknown> | null,
  appUrl: string,
): EmailContent {
  const p = payload ?? {};
  const settingsUrl = `${appUrl}sastanci/podesavanja-notifikacija`;

  let content: EmailContent;

  switch (kind) {
    case 'akcija_new':       content = tAkcijaNew(p);                  break;
    case 'akcija_changed':   content = tAkcijaChanged(p);              break;
    case 'meeting_invite':   content = tMeetingInvite(p, appUrl);      break;
    case 'meeting_locked':   content = tMeetingLocked(p, appUrl);      break;
    case 'action_reminder':  content = tActionReminder(p);             break;
    case 'meeting_reminder': content = tMeetingReminder(p, appUrl);    break;
    default:
      content = {
        subject: `Obaveštenje: ${kind}`,
        html: `<p>Obaveštenje iz Servoteh sistema (${kind}).</p>`,
        text: `Obaveštenje iz Servoteh sistema (${kind}).`,
      };
  }

  // Omotaj HTML u layout (samo ako nije već layout)
  content.html = layout(content.html, content.subject, appUrl, settingsUrl);

  // Dodaj plain-text footer
  content.text += `\n\n---\nOvo je automatska poruka. Promeni podešavanja: ${settingsUrl}`;

  return content;
}
