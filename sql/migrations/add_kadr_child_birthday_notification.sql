-- ═══════════════════════════════════════════════════════════════════════════
-- KADROVSKA — NOTIFIKACIJE: Rođendan deteta zaposlenog (Faza K4 dopuna)
--
-- Dodaje novi alert tip:
--   • child_birthday — rođendan deteta zaposlenog (opciono, novi flag)
--
-- Aditivno proširuje postojeći HR notifikacioni sistem
-- (kadr_schedule_hr_reminders + kadr_notification_log + hr-notify-dispatch).
-- Ne menja semantiku za medical_expiring, contract_expiring, birthday,
-- work_anniversary — postojeći flow ostaje identičan.
--
-- Idempotentno — bezbedno za re-run.
--
-- Depends on: add_kadr_notifications.sql (config/log/funkcija postoje)
--             add_kadr_employee_extended.sql (employee_children postoji)
-- ═══════════════════════════════════════════════════════════════════════════

-- 0) Sanity --------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename='kadr_notification_config') THEN
    RAISE EXCEPTION 'Missing kadr_notification_config. Run add_kadr_notifications.sql first.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename='kadr_notification_log') THEN
    RAISE EXCEPTION 'Missing kadr_notification_log. Run add_kadr_notifications.sql first.';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_tables WHERE tablename='employee_children') THEN
    RAISE EXCEPTION 'Missing employee_children. Run add_kadr_employee_extended.sql first.';
  END IF;
END $$;

-- 1) Config: dodaj toggle za rođendan deteta ----------------------------
ALTER TABLE kadr_notification_config
  ADD COLUMN IF NOT EXISTS child_birthday_enabled BOOLEAN NOT NULL DEFAULT false;

-- 2) Proširi CHECK constraint na notification_type ----------------------
-- Dodaj 'child_birthday' bez gubitka postojećih dozvoljenih vrednosti.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
     WHERE conname = 'kadr_notif_type_chk'
       AND conrelid = 'kadr_notification_log'::regclass
  ) THEN
    ALTER TABLE kadr_notification_log DROP CONSTRAINT kadr_notif_type_chk;
  END IF;
  ALTER TABLE kadr_notification_log
    ADD CONSTRAINT kadr_notif_type_chk
    CHECK (notification_type IN (
      'medical_expiring', 'contract_expiring',
      'birthday', 'work_anniversary',
      'child_birthday'
    ));
END $$;

-- 3) Schedule funkcija — proširena sa blokom E) Child birthday ----------
--
-- CREATE OR REPLACE re-deklariše celu funkciju (postgres limitation —
-- ne možeš parcijalno ALTER-ovati telo). Postojeći blokovi A/B/C/D su
-- 1:1 kopija iz add_kadr_notifications.sql; novi je samo blok E.
--
-- Idempotentnost child_birthday-a: skip ako za istu kombinaciju
-- (notification_type='child_birthday', related_entity_id=child.id,
-- recipient, scheduled_at::date=CURRENT_DATE) već postoji red.
--
CREATE OR REPLACE FUNCTION public.kadr_schedule_hr_reminders()
RETURNS TABLE(
  scheduled_count INT,
  skipped_count   INT,
  config_missing  BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $fn_sched$
DECLARE
  v_enabled              boolean;
  v_med_lead             int;
  v_con_lead             int;
  v_bday_enabled         boolean;
  v_ann_enabled          boolean;
  v_child_bday_enabled   boolean;
  v_wa_recipients        text[];
  v_em_recipients        text[];
  v_scheduled            int := 0;
  v_skipped              int := 0;
BEGIN
  v_enabled            := (SELECT enabled                   FROM public.kadr_notification_config WHERE id = 1);
  v_med_lead           := (SELECT medical_lead_days         FROM public.kadr_notification_config WHERE id = 1);
  v_con_lead           := (SELECT contract_lead_days        FROM public.kadr_notification_config WHERE id = 1);
  v_bday_enabled       := (SELECT birthday_enabled          FROM public.kadr_notification_config WHERE id = 1);
  v_ann_enabled        := (SELECT work_anniversary_enabled  FROM public.kadr_notification_config WHERE id = 1);
  v_child_bday_enabled := (SELECT child_birthday_enabled    FROM public.kadr_notification_config WHERE id = 1);
  v_wa_recipients      := (SELECT whatsapp_recipients       FROM public.kadr_notification_config WHERE id = 1);
  v_em_recipients      := (SELECT email_recipients          FROM public.kadr_notification_config WHERE id = 1);

  IF v_enabled IS NULL OR NOT v_enabled THEN
    scheduled_count := 0;
    skipped_count   := 0;
    config_missing  := true;
    RETURN NEXT;
    RETURN;
  END IF;

  IF array_length(v_wa_recipients, 1) IS NULL
     AND array_length(v_em_recipients, 1) IS NULL THEN
    scheduled_count := 0;
    skipped_count   := 0;
    config_missing  := true;
    RETURN NEXT;
    RETURN;
  END IF;

  /* -- A) Medical expiring ------------------------------------------- */
  WITH medical_due AS (
    SELECT e.id AS emp_id,
           COALESCE(e.full_name, e.first_name || ' ' || e.last_name, 'N/N') AS emp_name,
           e.medical_exam_expires AS due_date,
           (e.medical_exam_expires - CURRENT_DATE) AS days_left
      FROM employees e
     WHERE e.is_active = true
       AND e.medical_exam_expires IS NOT NULL
       AND e.medical_exam_expires <= CURRENT_DATE + v_med_lead
       AND e.medical_exam_expires >= CURRENT_DATE
  ),
  wa_targets AS (
    SELECT unnest(v_wa_recipients) AS recipient, 'whatsapp'::text AS channel
  ),
  em_targets AS (
    SELECT unnest(v_em_recipients) AS recipient, 'email'::text AS channel
  ),
  all_targets AS (
    SELECT * FROM wa_targets UNION ALL SELECT * FROM em_targets
  ),
  candidates AS (
    SELECT md.emp_id, md.emp_name, md.due_date, md.days_left,
           t.recipient, t.channel
      FROM medical_due md
      CROSS JOIN all_targets t
  ),
  to_insert AS (
    SELECT c.* FROM candidates c
     WHERE NOT EXISTS (
       SELECT 1 FROM kadr_notification_log n
        WHERE n.notification_type = 'medical_expiring'
          AND n.related_entity_id = c.emp_id::text
          AND n.recipient = c.recipient
          AND n.scheduled_at::date = CURRENT_DATE
     )
  ),
  ins AS (
    INSERT INTO kadr_notification_log (
      channel, recipient, subject, body,
      related_entity_type, related_entity_id, employee_id,
      notification_type, status, scheduled_at, next_attempt_at, payload
    )
    SELECT
      channel, recipient,
      format('Lekarski istice — %s', emp_name),
      format(E'Zaposleni *%s*: lekarski pregled istice %s (za %s dana).',
             emp_name, to_char(due_date, 'DD.MM.YYYY'), days_left),
      'employee_medical', emp_id::text, emp_id,
      'medical_expiring', 'queued', now(), now(),
      jsonb_build_object(
        'employee_name', emp_name,
        'due_date', due_date,
        'days_left', days_left
      )
    FROM to_insert
    RETURNING 1
  )
  SELECT count(*) INTO v_scheduled FROM ins;

  /* -- B) Contract expiring ----------------------------------------- */
  WITH contracts_due AS (
    SELECT c.id AS contract_id, c.employee_id,
           COALESCE(e.full_name, e.first_name || ' ' || e.last_name, 'N/N') AS emp_name,
           c.date_to AS due_date,
           (c.date_to - CURRENT_DATE) AS days_left
      FROM contracts c
      JOIN employees e ON e.id = c.employee_id
     WHERE e.is_active = true
       AND c.is_active = true
       AND c.date_to IS NOT NULL
       AND c.date_to <= CURRENT_DATE + v_con_lead
       AND c.date_to >= CURRENT_DATE
  ),
  wa_targets AS (
    SELECT unnest(v_wa_recipients) AS recipient, 'whatsapp'::text AS channel
  ),
  em_targets AS (
    SELECT unnest(v_em_recipients) AS recipient, 'email'::text AS channel
  ),
  all_targets AS (
    SELECT * FROM wa_targets UNION ALL SELECT * FROM em_targets
  ),
  candidates AS (
    SELECT cd.contract_id, cd.employee_id, cd.emp_name, cd.due_date, cd.days_left,
           t.recipient, t.channel
      FROM contracts_due cd
      CROSS JOIN all_targets t
  ),
  to_insert AS (
    SELECT c.* FROM candidates c
     WHERE NOT EXISTS (
       SELECT 1 FROM kadr_notification_log n
        WHERE n.notification_type = 'contract_expiring'
          AND n.related_entity_id = c.contract_id::text
          AND n.recipient = c.recipient
          AND n.scheduled_at::date = CURRENT_DATE
     )
  ),
  ins AS (
    INSERT INTO kadr_notification_log (
      channel, recipient, subject, body,
      related_entity_type, related_entity_id, employee_id,
      notification_type, status, scheduled_at, next_attempt_at, payload
    )
    SELECT
      channel, recipient,
      format('Ugovor istice — %s', emp_name),
      format(E'Ugovor o radu za *%s* istice %s (za %s dana).',
             emp_name, to_char(due_date, 'DD.MM.YYYY'), days_left),
      'employee_contract', contract_id::text, employee_id,
      'contract_expiring', 'queued', now(), now(),
      jsonb_build_object(
        'employee_name', emp_name,
        'due_date', due_date,
        'days_left', days_left,
        'contract_id', contract_id
      )
    FROM to_insert
    RETURNING 1
  )
  SELECT v_scheduled + count(*) INTO v_scheduled FROM ins;

  /* -- C) Birthday (ako je uključeno) --------------------------------- */
  IF v_bday_enabled THEN
    WITH birthdays_today AS (
      SELECT e.id AS emp_id,
             COALESCE(e.full_name, e.first_name || ' ' || e.last_name, 'N/N') AS emp_name,
             e.birth_date
        FROM employees e
       WHERE e.is_active = true
         AND e.birth_date IS NOT NULL
         AND to_char(e.birth_date, 'MM-DD') = to_char(CURRENT_DATE, 'MM-DD')
    ),
    wa_targets AS (
      SELECT unnest(v_wa_recipients) AS recipient, 'whatsapp'::text AS channel
    ),
    em_targets AS (
      SELECT unnest(v_em_recipients) AS recipient, 'email'::text AS channel
    ),
    all_targets AS (
      SELECT * FROM wa_targets UNION ALL SELECT * FROM em_targets
    ),
    candidates AS (
      SELECT bd.*, t.recipient, t.channel
        FROM birthdays_today bd
        CROSS JOIN all_targets t
    ),
    to_insert AS (
      SELECT c.* FROM candidates c
       WHERE NOT EXISTS (
         SELECT 1 FROM kadr_notification_log n
          WHERE n.notification_type = 'birthday'
            AND n.related_entity_id = c.emp_id::text
            AND n.recipient = c.recipient
            AND n.scheduled_at::date = CURRENT_DATE
       )
    ),
    ins AS (
      INSERT INTO kadr_notification_log (
        channel, recipient, subject, body,
        related_entity_type, related_entity_id, employee_id,
        notification_type, status, scheduled_at, next_attempt_at, payload
      )
      SELECT
        channel, recipient,
        format('Rodjendan — %s', emp_name),
        format(E'Danas je rodjendan zaposlenog *%s*. Srecan rodjendan!', emp_name),
        'employee_birthday', emp_id::text, emp_id,
        'birthday', 'queued', now(), now(),
        jsonb_build_object('employee_name', emp_name, 'birth_date', birth_date)
      FROM to_insert
      RETURNING 1
    )
    SELECT v_scheduled + count(*) INTO v_scheduled FROM ins;
  END IF;

  /* -- D) Work anniversary (ako je uključeno) -------------------------- */
  IF v_ann_enabled THEN
    WITH anniversaries_today AS (
      SELECT e.id AS emp_id,
             COALESCE(e.full_name, e.first_name || ' ' || e.last_name, 'N/N') AS emp_name,
             e.hire_date,
             EXTRACT(YEAR FROM AGE(CURRENT_DATE, e.hire_date))::int AS years_worked
        FROM employees e
       WHERE e.is_active = true
         AND e.hire_date IS NOT NULL
         AND to_char(e.hire_date, 'MM-DD') = to_char(CURRENT_DATE, 'MM-DD')
         AND e.hire_date < CURRENT_DATE
    ),
    wa_targets AS (
      SELECT unnest(v_wa_recipients) AS recipient, 'whatsapp'::text AS channel
    ),
    em_targets AS (
      SELECT unnest(v_em_recipients) AS recipient, 'email'::text AS channel
    ),
    all_targets AS (
      SELECT * FROM wa_targets UNION ALL SELECT * FROM em_targets
    ),
    candidates AS (
      SELECT ann.*, t.recipient, t.channel
        FROM anniversaries_today ann
        CROSS JOIN all_targets t
    ),
    to_insert AS (
      SELECT c.* FROM candidates c
       WHERE NOT EXISTS (
         SELECT 1 FROM kadr_notification_log n
          WHERE n.notification_type = 'work_anniversary'
            AND n.related_entity_id = c.emp_id::text
            AND n.recipient = c.recipient
            AND n.scheduled_at::date = CURRENT_DATE
       )
    ),
    ins AS (
      INSERT INTO kadr_notification_log (
        channel, recipient, subject, body,
        related_entity_type, related_entity_id, employee_id,
        notification_type, status, scheduled_at, next_attempt_at, payload
      )
      SELECT
        channel, recipient,
        format('Godisnjica — %s (%s god.)', emp_name, years_worked),
        format(E'Zaposleni *%s* danas slavi *%s godina* rada u firmi.', emp_name, years_worked),
        'employee_anniversary', emp_id::text, emp_id,
        'work_anniversary', 'queued', now(), now(),
        jsonb_build_object('employee_name', emp_name, 'years_worked', years_worked, 'hire_date', hire_date)
      FROM to_insert
      RETURNING 1
    )
    SELECT v_scheduled + count(*) INTO v_scheduled FROM ins;
  END IF;

  /* -- E) Child birthday (ako je uključeno) --------------------------- *
   * JOIN employee_children × employees, samo aktivni roditelji,
   * dete sa birth_date čiji MM-DD je danas. Fanout na sve WA + email
   * recipiente; idempotentno po (child.id, recipient, today).            */
  IF v_child_bday_enabled THEN
    WITH child_birthdays_today AS (
      SELECT ch.id AS child_id,
             ch.first_name AS child_first_name,
             ch.birth_date AS child_birth_date,
             EXTRACT(YEAR FROM AGE(CURRENT_DATE, ch.birth_date))::int AS child_age,
             e.id AS emp_id,
             COALESCE(e.full_name, e.first_name || ' ' || e.last_name, 'N/N') AS parent_name,
             COALESCE(NULLIF(e.email, ''), NULL) AS parent_email,
             COALESCE(NULLIF(e.department, ''), '—') AS department
        FROM employee_children ch
        JOIN employees e ON e.id = ch.employee_id
       WHERE e.is_active = true
         AND ch.birth_date IS NOT NULL
         AND to_char(ch.birth_date, 'MM-DD') = to_char(CURRENT_DATE, 'MM-DD')
         AND ch.birth_date <= CURRENT_DATE
    ),
    wa_targets AS (
      SELECT unnest(v_wa_recipients) AS recipient, 'whatsapp'::text AS channel
    ),
    em_targets AS (
      SELECT unnest(v_em_recipients) AS recipient, 'email'::text AS channel
    ),
    all_targets AS (
      SELECT * FROM wa_targets UNION ALL SELECT * FROM em_targets
    ),
    candidates AS (
      SELECT cb.*, t.recipient, t.channel
        FROM child_birthdays_today cb
        CROSS JOIN all_targets t
    ),
    to_insert AS (
      SELECT c.* FROM candidates c
       WHERE NOT EXISTS (
         SELECT 1 FROM kadr_notification_log n
          WHERE n.notification_type = 'child_birthday'
            AND n.related_entity_id = c.child_id::text
            AND n.recipient = c.recipient
            AND n.scheduled_at::date = CURRENT_DATE
       )
    ),
    ins AS (
      INSERT INTO kadr_notification_log (
        channel, recipient, subject, body,
        related_entity_type, related_entity_id, employee_id,
        notification_type, status, scheduled_at, next_attempt_at, payload
      )
      SELECT
        channel, recipient,
        format('Rodjendan deteta — %s', parent_name),
        format(
          E'Dete *%s* (od %s, %s) danas puni *%s godina*.',
          child_first_name, parent_name, department, child_age
        ),
        'employee_child', child_id::text, emp_id,
        'child_birthday', 'queued', now(), now(),
        jsonb_build_object(
          'child_first_name', child_first_name,
          'child_age',        child_age,
          'parent_name',      parent_name,
          'parent_email',     parent_email,
          'department',       department,
          'birth_date',       child_birth_date
        )
      FROM to_insert
      RETURNING 1
    )
    SELECT v_scheduled + count(*) INTO v_scheduled FROM ins;
  END IF;

  scheduled_count := v_scheduled;
  skipped_count   := v_skipped;
  config_missing  := false;
  RETURN NEXT;
END;
$fn_sched$;

REVOKE ALL ON FUNCTION public.kadr_schedule_hr_reminders() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.kadr_schedule_hr_reminders() TO service_role;

-- 4) Verifikacija -------------------------------------------------------
-- SELECT child_birthday_enabled FROM kadr_notification_config;
-- UPDATE kadr_notification_config SET child_birthday_enabled = true, birthday_enabled = true;
-- SELECT * FROM kadr_trigger_schedule_hr_reminders();
-- SELECT notification_type, recipient, status, payload
--   FROM kadr_notification_log
--  WHERE notification_type IN ('birthday', 'child_birthday')
--    AND scheduled_at::date = CURRENT_DATE
--  ORDER BY created_at DESC;
