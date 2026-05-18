-- ============================================================
-- add_kadr_weekly_risk_summary.sql
--
-- C3.4 follow-up: auto-cron weekly risk summary email.
--
-- Funkcija public.kadr_queue_weekly_risk_summary() generiše tekst rizika
-- za sve aktivne zaposlene (per pravilima iz reportsTab._computeRiskLevel:
-- visok = >7 dana bolovanja u 12m ILI istekli dokumenti; srednji = 4–7 d
-- ILI ističe ≤30 d) i upiše JEDAN red po email primaocu iz
-- kadr_notification_config.email_recipients u kadr_notification_log.
--
-- notification_type = 'weekly_risk_summary' (novi tip; trigger NIJE potreban
-- jer Edge funkcija hr-notify-dispatch čita SVE redove sa status='queued').
--
-- Vraća broj upisanih redova (0 ako nema config-a, primalaca, ili rizika).
--
-- ──────────────────────────────────────────────────────────────
-- ZAKAZIVANJE (zahteva pg_cron extension):
--
--   SELECT cron.schedule(
--     'kadr-weekly-risk-summary-monday-07',
--     '0 7 * * 1',                              -- svakog ponedeljka u 07:00
--     $$SELECT public.kadr_queue_weekly_risk_summary();$$
--   );
--
-- ZA REVOKE TESTIRANJE (admin ručno):
--   SELECT public.kadr_queue_weekly_risk_summary();
--
-- Edge funkcija hr-notify-dispatch će sledeći trigger (eksterni cron) da
-- skine te redove i pošalje ih kao normalne email-ove.
-- ──────────────────────────────────────────────────────────────
-- Depends:
--   add_kadr_notifications.sql        (kadr_notification_log, _config)
--   add_kadr_dashboard_action_stack_rpc.sql  (isti risk pristup)
--   add_kadrovska_phase1.sql          (absences, contracts)
--   add_kadr_employee_extended.sql    (employees.medical_exam_expires)
-- ============================================================

CREATE OR REPLACE FUNCTION public.kadr_queue_weekly_risk_summary()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today              date := CURRENT_DATE;
  v_period_start       date := CURRENT_DATE - interval '12 months';
  v_email_recipients   text[];
  v_count              int := 0;
  v_now_iso            timestamptz := now();
  v_email              text;
  v_high_rows          text := '';
  v_med_rows           text := '';
  v_high_count         int := 0;
  v_med_count          int := 0;
  v_med_soon_count     int := 0;
  v_con_soon_count     int := 0;
  v_subject            text;
  v_html_body          text;
  v_text_body          text;
  r                    record;
BEGIN
  /* 1. Učitaj email primaoce iz singleton config-a. Ako nema — skip. */
  SELECT email_recipients
    INTO v_email_recipients
  FROM public.kadr_notification_config
  WHERE id = 1
    AND enabled = true;

  IF v_email_recipients IS NULL OR array_length(v_email_recipients, 1) IS NULL THEN
    RETURN 0;
  END IF;

  /* 2. Per zaposleni risk (isti algoritam kao FE u reportsTab.js). */
  FOR r IN
    WITH bo AS (
      SELECT
        a.employee_id,
        COUNT(*) AS bo_count,
        COALESCE(SUM(
          GREATEST(LEAST(a.date_to, v_today) - GREATEST(a.date_from, v_period_start), 0)::int + 1
        ), 0) AS bo_days
      FROM public.absences a
      WHERE a.type = 'bolovanje'
        AND a.date_from IS NOT NULL
        AND a.date_to   IS NOT NULL
        AND a.date_from <= v_today
        AND a.date_to   >= v_period_start
      GROUP BY a.employee_id
    ),
    con AS (
      SELECT DISTINCT ON (c.employee_id)
        c.employee_id,
        c.date_to AS con_date_to
      FROM public.contracts c
      WHERE c.is_active IS NOT FALSE
      ORDER BY c.employee_id, c.date_from DESC NULLS LAST
    )
    SELECT
      e.id,
      COALESCE(e.full_name, e.first_name || ' ' || e.last_name, 'Zaposleni') AS emp_name,
      e.department,
      COALESCE(bo.bo_days, 0) AS bo_days,
      COALESCE(bo.bo_count, 0) AS bo_count,
      e.medical_exam_expires,
      con.con_date_to,
      (e.medical_exam_expires - v_today)::int AS med_exp_days,
      (con.con_date_to        - v_today)::int AS con_exp_days
    FROM public.employees e
    LEFT JOIN bo  ON bo.employee_id = e.id
    LEFT JOIN con ON con.employee_id = e.id
    WHERE e.is_active = true
    ORDER BY e.last_name NULLS LAST, e.first_name NULLS LAST
  LOOP
    DECLARE
      v_level       text := 'low';
      v_reasons     text := '';
      v_med_str     text := '';
      v_con_str     text := '';
    BEGIN
      /* Risk klasifikacija */
      IF r.bo_days > 7 THEN
        v_level := 'high'; v_reasons := '>7 dana bolovanja (' || r.bo_days || ' d)';
      END IF;
      IF r.med_exp_days IS NOT NULL AND r.med_exp_days < 0 THEN
        v_level := 'high';
        v_reasons := CASE WHEN v_reasons = '' THEN 'Lekarski istekao' ELSE v_reasons || ' · Lekarski istekao' END;
      END IF;
      IF r.con_exp_days IS NOT NULL AND r.con_exp_days < 0 THEN
        v_level := 'high';
        v_reasons := CASE WHEN v_reasons = '' THEN 'Ugovor istekao' ELSE v_reasons || ' · Ugovor istekao' END;
      END IF;
      IF v_level <> 'high' THEN
        IF r.bo_days BETWEEN 4 AND 7 THEN
          v_level := 'medium';
          v_reasons := r.bo_days || ' dana bolovanja';
        END IF;
        IF r.med_exp_days IS NOT NULL AND r.med_exp_days BETWEEN 0 AND 30 THEN
          v_level := 'medium';
          v_reasons := CASE WHEN v_reasons = '' THEN 'Lekarski ističe ≤30 d' ELSE v_reasons || ' · Lekarski ističe ≤30 d' END;
        END IF;
        IF r.con_exp_days IS NOT NULL AND r.con_exp_days BETWEEN 0 AND 30 THEN
          v_level := 'medium';
          v_reasons := CASE WHEN v_reasons = '' THEN 'Ugovor ističe ≤30 d' ELSE v_reasons || ' · Ugovor ističe ≤30 d' END;
        END IF;
      END IF;

      /* Counts za summary */
      IF r.med_exp_days IS NOT NULL AND r.med_exp_days BETWEEN 0 AND 60 THEN
        v_med_soon_count := v_med_soon_count + 1;
      END IF;
      IF r.con_exp_days IS NOT NULL AND r.con_exp_days BETWEEN 0 AND 60 THEN
        v_con_soon_count := v_con_soon_count + 1;
      END IF;

      IF v_level = 'high' THEN
        v_high_count := v_high_count + 1;
        v_high_rows := v_high_rows
          || '<tr><td style="padding:5px 10px;border-bottom:1px solid #fee;">'
          || r.emp_name
          || CASE WHEN r.department IS NOT NULL AND r.department <> '' THEN ' <span style="color:#888">(' || r.department || ')</span>' ELSE '' END
          || '</td><td style="padding:5px 10px;border-bottom:1px solid #fee;font-size:.9em;color:#7f1d1d;">'
          || v_reasons
          || '</td></tr>';
      ELSIF v_level = 'medium' THEN
        v_med_count := v_med_count + 1;
        v_med_rows := v_med_rows
          || '<tr><td style="padding:5px 10px;border-bottom:1px solid #fef3c7;">'
          || r.emp_name
          || CASE WHEN r.department IS NOT NULL AND r.department <> '' THEN ' <span style="color:#888">(' || r.department || ')</span>' ELSE '' END
          || '</td><td style="padding:5px 10px;border-bottom:1px solid #fef3c7;font-size:.9em;color:#854d0e;">'
          || v_reasons
          || '</td></tr>';
      END IF;
    END;
  END LOOP;

  /* Ako nema ničega da prijavimo i nema dokumenata koji ističu — preskoči. */
  IF v_high_count = 0 AND v_med_count = 0 AND v_med_soon_count = 0 AND v_con_soon_count = 0 THEN
    RETURN 0;
  END IF;

  /* 3. Sastavi subject + HTML body + text body */
  v_subject := 'Servoteh HR — risk pregled ' || to_char(v_today, 'DD.MM.YYYY');

  v_html_body :=
    '<div style="font-family:sans-serif;max-width:680px;margin:0 auto;color:#1a1a1a;">'
    || '<h2 style="margin-bottom:4px;color:#1e40af;">📊 Servoteh HR — risk pregled</h2>'
    || '<p style="color:#555;margin-top:0;">Sažetak za ' || to_char(v_today, 'DD.MM.YYYY') || '</p>'
    || '<table style="border-collapse:collapse;margin:10px 0;">'
    ||   '<tr><td style="padding:4px 12px;color:#7f1d1d;font-weight:700;">Visok rizik:</td>'
    ||       '<td style="padding:4px 12px;font-weight:700;">' || v_high_count || '</td></tr>'
    ||   '<tr><td style="padding:4px 12px;color:#854d0e;font-weight:700;">Srednji rizik:</td>'
    ||       '<td style="padding:4px 12px;font-weight:700;">' || v_med_count || '</td></tr>'
    ||   '<tr><td style="padding:4px 12px;color:#555;">Lekarski ističe ≤60 d:</td>'
    ||       '<td style="padding:4px 12px;">' || v_med_soon_count || '</td></tr>'
    ||   '<tr><td style="padding:4px 12px;color:#555;">Ugovori ističu ≤60 d:</td>'
    ||       '<td style="padding:4px 12px;">' || v_con_soon_count || '</td></tr>'
    || '</table>';

  IF v_high_rows <> '' THEN
    v_html_body := v_html_body
      || '<h3 style="color:#7f1d1d;margin-top:18px;">VISOK RIZIK</h3>'
      || '<table style="border-collapse:collapse;width:100%;background:#fef2f2;border:1px solid #fecaca;border-radius:4px;">'
      || v_high_rows
      || '</table>';
  END IF;
  IF v_med_rows <> '' THEN
    v_html_body := v_html_body
      || '<h3 style="color:#854d0e;margin-top:18px;">SREDNJI RIZIK</h3>'
      || '<table style="border-collapse:collapse;width:100%;background:#fffbeb;border:1px solid #fde68a;border-radius:4px;">'
      || v_med_rows
      || '</table>';
  END IF;

  v_html_body := v_html_body
    || '<p style="font-size:.85em;color:#64748b;margin-top:18px;">'
    || 'Detalji u app-u: Kadrovska → Izveštaji → Rizik. '
    || 'Pravilo: visok = &gt;7 d bolovanja u 12 meseci ILI istekli dokumenti; srednji = 4–7 d ILI dokumenti ističu ≤30 d.'
    || '</p>'
    || '<p style="font-size:.85em;color:#64748b;">Automatski generisano — ' || to_char(v_now_iso, 'DD.MM.YYYY HH24:MI') || '</p>'
    || '</div>';

  v_text_body :=
    'Servoteh HR — risk pregled za ' || to_char(v_today, 'DD.MM.YYYY') || E'\n\n'
    || 'Visok rizik: ' || v_high_count || E'\n'
    || 'Srednji rizik: ' || v_med_count || E'\n'
    || 'Lekarski ističe (60d): ' || v_med_soon_count || E'\n'
    || 'Ugovori ističu (60d): ' || v_con_soon_count || E'\n\n'
    || 'Detalji u app-u: Kadrovska → Izveštaji → Rizik.';

  /* 4. Upiši red u log za svakog email primaoca. */
  FOREACH v_email IN ARRAY v_email_recipients LOOP
    IF v_email IS NULL OR trim(v_email) = '' THEN
      CONTINUE;
    END IF;
    INSERT INTO public.kadr_notification_log (
      channel,
      recipient,
      subject,
      body,
      notification_type,
      status,
      scheduled_at,
      next_attempt_at,
      payload,
      created_at,
      updated_at
    ) VALUES (
      'email',
      trim(v_email),
      v_subject,
      v_html_body,
      'weekly_risk_summary',
      'queued',
      v_now_iso,
      v_now_iso,
      jsonb_build_object(
        'text_body',         v_text_body,
        'high_count',        v_high_count,
        'medium_count',      v_med_count,
        'medical_soon_60d',  v_med_soon_count,
        'contracts_soon_60d', v_con_soon_count,
        'period_start',      v_period_start,
        'period_end',        v_today
      ),
      v_now_iso,
      v_now_iso
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

COMMENT ON FUNCTION public.kadr_queue_weekly_risk_summary() IS
  'Generiše tekst rizika i upiše ga u kadr_notification_log za svakog email primaoca iz config-a. '
  'Vraća broj upisanih redova. Idempotentno bezbedno za ponovne pozive (svaki poziv = nov red). '
  'Pravila skora identična FE reportsTab.js _computeRiskLevel — vidi C3.4.';

REVOKE ALL ON FUNCTION public.kadr_queue_weekly_risk_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kadr_queue_weekly_risk_summary() TO authenticated, service_role;

-- ───────────────────────────────────────────────────────────
-- Wrapper sa proverom HR/admin uloge — za ručno okidanje iz UI
-- (auth.uid() ne važi u pg_cron kontekstu, zato je odvojeno).
-- ───────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.kadr_trigger_weekly_risk_summary()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.current_user_is_hr() AND NOT public.current_user_is_admin() THEN
    RAISE EXCEPTION 'Access denied: HR or admin only';
  END IF;
  RETURN public.kadr_queue_weekly_risk_summary();
END;
$$;

COMMENT ON FUNCTION public.kadr_trigger_weekly_risk_summary() IS
  'UI wrapper: ručno okidanje weekly risk summary; proverava HR/admin RLS.';

REVOKE ALL ON FUNCTION public.kadr_trigger_weekly_risk_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kadr_trigger_weekly_risk_summary() TO authenticated, service_role;
