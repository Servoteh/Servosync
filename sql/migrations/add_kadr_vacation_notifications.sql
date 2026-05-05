-- ============================================================
-- Kadrovski notifikacioni SECURITY DEFINER helperi (Faza K5 — Opcija A)
-- ============================================================
-- Fajl je idempotent (CREATE OR REPLACE / IF NOT EXISTS).
--
-- Funkcije:
--   kadr_queue_vacation_notification(uuid, text, text)
--     → upisuje email + whatsapp red u kadr_notification_log
--       kada se GO zahtev odobri ili odbije
--
--   kadr_queue_payroll_notifications(int, int)
--     → upisuje email + whatsapp redove za sve zaposlene koji
--       imaju upisane sate za dati mesec (obračun sati)
--       vraća broj upisanih redova
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1. GO zahtev — odobren ili odbijen
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.kadr_queue_vacation_notification(
  p_vacation_request_id uuid,
  p_new_status          text,           -- 'approved' | 'rejected'
  p_rejection_note      text DEFAULT ''
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_emp_name   text;
  v_emp_email  text;
  v_emp_phone  text;
  v_emp_id     uuid;
  v_date_from  date;
  v_date_to    date;
  v_days_count int;
  v_subject    text;
  v_email_body text;
  v_wa_body    text;
  v_payload    jsonb;
BEGIN
  SELECT
    COALESCE(e.full_name, e.first_name || ' ' || e.last_name, 'Zaposleni'),
    e.email,
    e.phone,
    e.id,
    vr.date_from,
    vr.date_to,
    vr.days_count
  INTO v_emp_name, v_emp_email, v_emp_phone, v_emp_id,
       v_date_from, v_date_to, v_days_count
  FROM vacation_requests vr
  JOIN employees e ON e.id = vr.employee_id
  WHERE vr.id = p_vacation_request_id;

  IF NOT FOUND THEN RETURN; END IF;

  v_payload := jsonb_build_object(
    'status',      p_new_status,
    'date_from',   v_date_from,
    'date_to',     v_date_to,
    'days_count',  v_days_count
  );

  IF p_new_status = 'approved' THEN
    v_subject := 'Rešenje o godišnjem odmoru — ' || v_emp_name;

    v_email_body :=
      '<div style="font-family:sans-serif;max-width:520px;margin:0 auto;color:#1a1a1a;">'
      || '<h2 style="color:#16a34a;margin-bottom:4px;">✅ Zahtev za GO odobren</h2>'
      || '<p>Poštovani/a <strong>' || v_emp_name || '</strong>,</p>'
      || '<p>Vaš zahtev za <strong>godišnji odmor</strong> je <strong style="color:#16a34a">ODOBREN</strong>.</p>'
      || '<table style="border-collapse:collapse;margin:16px 0;width:100%;max-width:360px;">'
      || '<tr style="background:#f0fdf4;">'
      ||   '<td style="padding:8px 14px;border:1px solid #d1fae5;">Period odmora</td>'
      ||   '<td style="padding:8px 14px;border:1px solid #d1fae5;font-weight:600;">'
      ||     to_char(v_date_from, 'DD.MM.YYYY') || ' – ' || to_char(v_date_to, 'DD.MM.YYYY')
      ||   '</td>'
      || '</tr>'
      || '<tr>'
      ||   '<td style="padding:8px 14px;border:1px solid #e2e8f0;">Radnih dana</td>'
      ||   '<td style="padding:8px 14px;border:1px solid #e2e8f0;font-weight:600;">'
      ||     COALESCE(v_days_count::text, '—')
      ||   '</td>'
      || '</tr>'
      || '</table>'
      || '<p>Ovo obaveštenje služi kao potvrda o odobrenom godišnjem odmoru.</p>'
      || '<hr style="border:none;border-top:1px solid #e2e8f0;margin:20px 0;">'
      || '<p style="font-size:.85em;color:#64748b;">Srdačan pozdrav,<br><em>HR odeljenje — Servoteh</em></p>'
      || '</div>';

    v_wa_body :=
      'Vaš zahtev za GO je ODOBREN: '
      || to_char(v_date_from, 'DD.MM.YYYY') || ' – ' || to_char(v_date_to, 'DD.MM.YYYY')
      || ' (' || COALESCE(v_days_count::text, '?') || ' radnih dana).'
      || ' — Servoteh HR';

  ELSIF p_new_status = 'rejected' THEN
    v_subject := 'Zahtev za GO odbijen — ' || v_emp_name;

    v_email_body :=
      '<div style="font-family:sans-serif;max-width:520px;margin:0 auto;color:#1a1a1a;">'
      || '<h2 style="color:#dc2626;margin-bottom:4px;">❌ Zahtev za GO odbijen</h2>'
      || '<p>Poštovani/a <strong>' || v_emp_name || '</strong>,</p>'
      || '<p>Vaš zahtev za godišnji odmor (<strong>'
      ||   to_char(v_date_from, 'DD.MM.YYYY') || ' – ' || to_char(v_date_to, 'DD.MM.YYYY')
      || '</strong>) je <strong style="color:#dc2626">ODBIJEN</strong>.</p>'
      || CASE WHEN COALESCE(p_rejection_note, '') <> ''
         THEN '<p><strong>Razlog:</strong> ' || p_rejection_note || '</p>'
         ELSE '' END
      || '<p>Za više informacija obratite se neposrednom rukovodiocu ili HR-u.</p>'
      || '<hr style="border:none;border-top:1px solid #e2e8f0;margin:20px 0;">'
      || '<p style="font-size:.85em;color:#64748b;">Srdačan pozdrav,<br><em>HR odeljenje — Servoteh</em></p>'
      || '</div>';

    v_wa_body :=
      'Vaš zahtev za GO je ODBIJEN ('
      || to_char(v_date_from, 'DD.MM.YYYY') || ' – ' || to_char(v_date_to, 'DD.MM.YYYY') || ').'
      || CASE WHEN COALESCE(p_rejection_note, '') <> ''
         THEN ' Razlog: ' || p_rejection_note
         ELSE '' END
      || ' — Servoteh HR';
  ELSE
    RETURN;
  END IF;

  -- Email
  IF v_emp_email IS NOT NULL AND v_emp_email <> '' THEN
    INSERT INTO kadr_notification_log (
      channel, recipient, subject, body, notification_type,
      employee_id, related_entity_type, related_entity_id, payload, status, scheduled_at
    ) VALUES (
      'email', v_emp_email, v_subject, v_email_body,
      'vacation_' || p_new_status,
      v_emp_id, 'vacation_request', p_vacation_request_id,
      v_payload, 'queued', now()
    );
  END IF;

  -- WhatsApp
  IF v_emp_phone IS NOT NULL AND v_emp_phone <> '' THEN
    INSERT INTO kadr_notification_log (
      channel, recipient, subject, body, notification_type,
      employee_id, related_entity_type, related_entity_id, payload, status, scheduled_at
    ) VALUES (
      'whatsapp', v_emp_phone, v_subject, v_wa_body,
      'vacation_' || p_new_status,
      v_emp_id, 'vacation_request', p_vacation_request_id,
      v_payload, 'queued', now()
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.kadr_queue_vacation_notification(uuid, text, text) TO authenticated;

-- ────────────────────────────────────────────────────────────
-- 2. Obračun sati — mesečna evidencija za sve zaposlene
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.kadr_queue_payroll_notifications(
  p_period_year  int,
  p_period_month int
) RETURNS int   -- broj upisanih notifikacionih redova
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_rec          record;
  v_count        int := 0;
  v_period_label text;
  v_subject      text;
  v_email_body   text;
  v_wa_body      text;
  v_payload      jsonb;
  v_total        numeric;
  v_field_row    text;
BEGIN
  v_period_label := to_char(
    make_date(p_period_year, p_period_month, 1),
    'TMMonth YYYY'
  );

  FOR v_rec IN
    SELECT
      e.id                                                       AS emp_id,
      COALESCE(e.full_name,
               e.first_name || ' ' || e.last_name,
               'Zaposleni')                                      AS emp_name,
      e.email,
      e.phone,
      COALESCE(SUM(wh.hours),           0)                       AS regular_hours,
      COALESCE(SUM(wh.overtime_hours),  0)                       AS overtime_hours,
      COALESCE(SUM(wh.field_hours),     0)                       AS field_hours,
      COALESCE(SUM(wh.two_machine_hours), 0)                     AS two_machine_hours,
      COUNT(DISTINCT wh.work_date)                               AS work_days
    FROM work_hours wh
    JOIN employees e ON e.id = wh.employee_id
    WHERE EXTRACT(YEAR  FROM wh.work_date)::int = p_period_year
      AND EXTRACT(MONTH FROM wh.work_date)::int = p_period_month
      AND e.is_active = true
    GROUP BY e.id, emp_name, e.email, e.phone
  LOOP
    v_total := v_rec.regular_hours + v_rec.overtime_hours;

    v_field_row := CASE WHEN v_rec.field_hours > 0
      THEN '<tr><td style="padding:7px 14px;border:1px solid #e2e8f0;">Terenska</td>'
        || '<td style="padding:7px 14px;border:1px solid #e2e8f0;text-align:right;">'
        || v_rec.field_hours::text || 'h</td></tr>'
      ELSE '' END;

    v_subject := 'Obračun sati za ' || v_period_label || ' — ' || v_rec.emp_name;

    v_email_body :=
      '<div style="font-family:sans-serif;max-width:520px;margin:0 auto;color:#1a1a1a;">'
      || '<h2 style="color:#2563eb;margin-bottom:4px;">📋 Obračun sati — ' || v_period_label || '</h2>'
      || '<p>Poštovani/a <strong>' || v_rec.emp_name || '</strong>,</p>'
      || '<p>Ovde je pregled Vaše evidencije radnih sati za <strong>' || v_period_label || '</strong>:</p>'
      || '<table style="border-collapse:collapse;margin:14px 0;width:100%;max-width:380px;">'
      || '<tr style="background:#eff6ff;">'
      ||   '<td style="padding:8px 14px;border:1px solid #dbeafe;"><strong>Redovni sati</strong></td>'
      ||   '<td style="padding:8px 14px;border:1px solid #dbeafe;text-align:right;font-weight:700;">'
      ||     v_rec.regular_hours::text || 'h</td>'
      || '</tr>'
      || '<tr>'
      ||   '<td style="padding:7px 14px;border:1px solid #e2e8f0;">Prekovremeni</td>'
      ||   '<td style="padding:7px 14px;border:1px solid #e2e8f0;text-align:right;">'
      ||     v_rec.overtime_hours::text || 'h</td>'
      || '</tr>'
      || v_field_row
      || '<tr style="background:#f8fafc;border-top:2px solid #94a3b8;">'
      ||   '<td style="padding:8px 14px;border:1px solid #cbd5e1;"><strong>Ukupno</strong></td>'
      ||   '<td style="padding:8px 14px;border:1px solid #cbd5e1;text-align:right;font-weight:700;">'
      ||     v_total::text || 'h</td>'
      || '</tr>'
      || '<tr>'
      ||   '<td style="padding:7px 14px;border:1px solid #e2e8f0;font-size:.9em;color:#64748b;">Radnih dana</td>'
      ||   '<td style="padding:7px 14px;border:1px solid #e2e8f0;text-align:right;font-size:.9em;color:#64748b;">'
      ||     v_rec.work_days::text || '</td>'
      || '</tr>'
      || '</table>'
      || '<p style="font-size:.88em;color:#64748b;">Ukoliko imate pitanja u vezi sa ovom evidencijom, obratite se HR odeljenju.</p>'
      || '<hr style="border:none;border-top:1px solid #e2e8f0;margin:20px 0;">'
      || '<p style="font-size:.85em;color:#64748b;">Srdačan pozdrav,<br><em>HR odeljenje — Servoteh</em></p>'
      || '</div>';

    v_wa_body :=
      'Obračun sati za ' || v_period_label || ': '
      || 'redovni ' || v_rec.regular_hours::text || 'h'
      || ', prekovremeni ' || v_rec.overtime_hours::text || 'h'
      || CASE WHEN v_rec.field_hours > 0 THEN ', terenska ' || v_rec.field_hours::text || 'h' ELSE '' END
      || ' (ukupno ' || v_total::text || 'h). '
      || 'Za pitanja kontaktujte HR. — Servoteh';

    v_payload := jsonb_build_object(
      'period_year',       p_period_year,
      'period_month',      p_period_month,
      'regular_hours',     v_rec.regular_hours,
      'overtime_hours',    v_rec.overtime_hours,
      'field_hours',       v_rec.field_hours,
      'two_machine_hours', v_rec.two_machine_hours,
      'work_days',         v_rec.work_days
    );

    -- Email
    IF v_rec.email IS NOT NULL AND v_rec.email <> '' THEN
      INSERT INTO kadr_notification_log (
        channel, recipient, subject, body, notification_type,
        employee_id, payload, status, scheduled_at
      ) VALUES (
        'email', v_rec.email, v_subject, v_email_body, 'payroll_statement',
        v_rec.emp_id, v_payload, 'queued', now()
      );
      v_count := v_count + 1;
    END IF;

    -- WhatsApp
    IF v_rec.phone IS NOT NULL AND v_rec.phone <> '' THEN
      INSERT INTO kadr_notification_log (
        channel, recipient, subject, body, notification_type,
        employee_id, payload, status, scheduled_at
      ) VALUES (
        'whatsapp', v_rec.phone, v_subject, v_wa_body, 'payroll_statement',
        v_rec.emp_id, v_payload, 'queued', now()
      );
      v_count := v_count + 1;
    END IF;

  END LOOP;

  RETURN v_count;
END;
$$;

GRANT EXECUTE ON FUNCTION public.kadr_queue_payroll_notifications(int, int) TO authenticated;
