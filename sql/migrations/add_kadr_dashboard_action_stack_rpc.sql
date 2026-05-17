-- Sprint 3.4: Kadrovska Pregled — action stack (jedan RPC umesto više GET-ova).
-- Scope: HR/admin blokovi; GO pending koristi current_user_manages_employee (paritet sa RLS).
-- Zavisi od: current_user_is_admin, current_user_is_hr, current_user_can_manage_vacreq,
--           current_user_manages_employee(uuid), v_vacation_balance.

CREATE OR REPLACE FUNCTION public.kadr_dashboard_action_stack(
  p_limit int DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_items jsonb := '[]'::jsonb;
  v_today date := CURRENT_DATE;
  v_year_curr int := EXTRACT(year FROM v_today)::int;
  v_month_prev_start date := (DATE_TRUNC('month', v_today::timestamp) - interval '1 month')::date;
  v_month_prev_end date := (DATE_TRUNC('month', v_today::timestamp) - interval '1 day')::date;
  v_is_admin boolean := public.current_user_is_admin();
  v_is_hr boolean := public.current_user_is_hr();
  v_can_manage_vacreq boolean := public.current_user_can_manage_vacreq();
BEGIN
  -- 1. Ugovori koji ističe u narednih 30 dana (HR/admin)
  IF v_is_hr OR v_is_admin THEN
    v_items := v_items || COALESCE((
      SELECT jsonb_agg(x.obj)
      FROM (
        SELECT jsonb_build_object(
          'id', 'contract_' || c.id::text,
          'type', 'contract_expiring',
          'priority', CASE WHEN c.date_to - v_today < 7 THEN 90 ELSE 50 END,
          'title', 'Ugovor ističe — ' || e.full_name,
          'subtitle', COALESCE(c.contract_type, '') || ' • do ' || c.date_to::text,
          'deep_link_tab', 'contracts',
          'deep_link_filter', jsonb_build_object('employee_id', c.employee_id::text)
        ) AS obj
        FROM public.contracts c
        JOIN public.employees e ON e.id = c.employee_id
        WHERE c.is_active IS TRUE
          AND c.date_to >= v_today
          AND c.date_to <= v_today + interval '30 days'
          AND e.is_active IS TRUE
        ORDER BY c.date_to ASC
        LIMIT 10
      ) x
    ), '[]'::jsonb);
  END IF;

  -- 2. Lekarski koji ističe (HR/admin)
  IF v_is_hr OR v_is_admin THEN
    v_items := v_items || COALESCE((
      SELECT jsonb_agg(x.obj)
      FROM (
        SELECT jsonb_build_object(
          'id', 'medical_' || e.id::text,
          'type', 'medical_expiring',
          'priority', CASE WHEN e.medical_exam_expires - v_today < 7 THEN 95 ELSE 60 END,
          'title', 'Lekarski ističe — ' || e.full_name,
          'subtitle', 'do ' || e.medical_exam_expires::text,
          'deep_link_tab', 'employees',
          'deep_link_filter', jsonb_build_object('employee_id', e.id::text)
        ) AS obj
        FROM public.employees e
        WHERE e.is_active IS TRUE
          AND e.medical_exam_expires IS NOT NULL
          AND e.medical_exam_expires >= v_today
          AND e.medical_exam_expires <= v_today + interval '30 days'
        ORDER BY e.medical_exam_expires ASC
        LIMIT 10
      ) x
    ), '[]'::jsonb);
  END IF;

  -- 3. Rođendani u narednih 7 dana (HR/admin)
  IF v_is_hr OR v_is_admin THEN
    v_items := v_items || COALESCE((
      SELECT jsonb_agg(x.obj)
      FROM (
        SELECT jsonb_build_object(
          'id', 'birthday_' || e.id::text,
          'type', 'birthday_this_week',
          'priority', 45,
          'title', '🎂 ' || e.full_name,
          'subtitle', 'Rođendan ' || to_char(e.birth_date, 'DD.MM.'),
          'deep_link_tab', 'employees',
          'deep_link_filter', jsonb_build_object('employee_id', e.id::text)
        ) AS obj
        FROM public.employees e
        WHERE e.is_active IS TRUE
          AND e.birth_date IS NOT NULL
          AND EXISTS (
            SELECT 1
            FROM generate_series(v_today, v_today + interval '7 days', interval '1 day') AS ds(d)
            WHERE to_char((ds.d)::date, 'MM-DD') = to_char(e.birth_date, 'MM-DD')
          )
        LIMIT 10
      ) x
    ), '[]'::jsonb);
  END IF;

  -- 4. slava_this_week — preskočeno (employees.slava_day nije standardizovan format)

  -- 5. Queued notifikacije (HR/admin)
  IF v_is_hr OR v_is_admin THEN
    v_items := v_items || COALESCE((
      SELECT jsonb_agg(x.obj)
      FROM (
        SELECT jsonb_build_object(
          'id', 'notif_' || knl.id::text,
          'type', 'queued_notification',
          'priority', 70,
          'title', '🔔 ' || COALESCE(knl.subject, 'Notifikacija'),
          'subtitle', COALESCE(knl.notification_type, '') || ' • ' || COALESCE(knl.channel, ''),
          'deep_link_tab', 'notifications',
          'deep_link_filter', jsonb_build_object('status', 'queued')
        ) AS obj
        FROM public.kadr_notification_log knl
        WHERE knl.status = 'queued'
        ORDER BY knl.scheduled_at ASC NULLS LAST
        LIMIT 5
      ) x
    ), '[]'::jsonb);
  END IF;

  -- 6. Pending zahtevi GO (admin/HR/menadžment/PM — paritet current_user_manages_employee)
  IF v_can_manage_vacreq THEN
    v_items := v_items || COALESCE((
      SELECT jsonb_agg(x.obj)
      FROM (
        SELECT jsonb_build_object(
          'id', 'vacreq_' || vr.id::text,
          'type', 'pending_vac_request',
          'priority', 80,
          'title', '✋ Zahtev za GO — ' || e.full_name,
          'subtitle', 'od ' || vr.date_from::text || ' do ' || vr.date_to::text,
          'deep_link_tab', 'vac-requests',
          'deep_link_filter', jsonb_build_object(
            'status', 'pending',
            'employee_id', vr.employee_id::text
          )
        ) AS obj
        FROM public.vacation_requests vr
        JOIN public.employees e ON e.id = vr.employee_id
        WHERE vr.status = 'pending'
          AND e.is_active IS TRUE
          AND public.current_user_manages_employee(vr.employee_id)
        ORDER BY vr.created_at DESC NULLS LAST
        LIMIT 10
      ) x
    ), '[]'::jsonb);
  END IF;

  -- 7. Zaposleni bez upisanih sati za prošli mesec (HR/admin)
  IF v_is_hr OR v_is_admin THEN
    v_items := v_items || COALESCE((
      SELECT jsonb_agg(x.obj)
      FROM (
        SELECT jsonb_build_object(
          'id', 'missing_grid_' || e.id::text,
          'type', 'missing_grid_prev_month',
          'priority', 85,
          'title', '⚠ Nedostaje grid — ' || e.full_name,
          'subtitle', 'Prošli mesec: 0 sati upisano',
          'deep_link_tab', 'grid',
          'deep_link_filter', jsonb_build_object(
            'employee_id', e.id::text,
            'year', EXTRACT(year FROM v_month_prev_start)::int,
            'month', EXTRACT(month FROM v_month_prev_start)::int
          )
        ) AS obj
        FROM public.employees e
        WHERE e.is_active IS TRUE
          AND e.work_type = 'ugovor'
          AND NOT EXISTS (
            SELECT 1
            FROM public.work_hours wh
            WHERE wh.employee_id = e.id
              AND wh.work_date >= v_month_prev_start
              AND wh.work_date <= v_month_prev_end
          )
          AND NOT EXISTS (
            SELECT 1
            FROM public.absences a
            WHERE a.employee_id = e.id
              AND a.date_from <= v_month_prev_start
              AND a.date_to >= v_month_prev_end
          )
        ORDER BY e.full_name ASC NULLS LAST, e.id ASC
        LIMIT 10
      ) x
    ), '[]'::jsonb);
  END IF;

  -- 8. Visok saldo GO (HR/admin)
  IF v_is_hr OR v_is_admin THEN
    v_items := v_items || COALESCE((
      SELECT jsonb_agg(x.obj)
      FROM (
        SELECT jsonb_build_object(
          'id', 'vac_high_' || vb.employee_id::text,
          'type', 'vacation_balance_high',
          'priority', 25,
          'title', '🏖️ Visok saldo GO — ' || e.full_name,
          'subtitle', vb.days_remaining::text || ' preostalih dana ' || v_year_curr::text,
          'deep_link_tab', 'vacation',
          'deep_link_filter', jsonb_build_object(
            'employee_id', vb.employee_id::text,
            'year', v_year_curr
          )
        ) AS obj
        FROM public.v_vacation_balance vb
        JOIN public.employees e ON e.id = vb.employee_id
        WHERE vb.year = v_year_curr
          AND vb.days_remaining > 15
          AND e.is_active IS TRUE
        ORDER BY vb.days_remaining DESC
        LIMIT 5
      ) x
    ), '[]'::jsonb);
  END IF;

  RETURN COALESCE((
    SELECT jsonb_agg(sub.entity ORDER BY sub.prio DESC)
    FROM (
      SELECT
        t.entity,
        (t.entity->>'priority')::int AS prio
      FROM jsonb_array_elements(v_items) AS t(entity)
      ORDER BY (t.entity->>'priority')::int DESC
      LIMIT GREATEST(COALESCE(p_limit, 10), 1)
    ) sub
  ), '[]'::jsonb);
END;
$$;

COMMENT ON FUNCTION public.kadr_dashboard_action_stack(int) IS
  'Top akcije za Kadrovska dashboard; jedan poziv umesto više REST GET-ova.';

REVOKE ALL ON FUNCTION public.kadr_dashboard_action_stack(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.kadr_dashboard_action_stack(int) TO authenticated, service_role;
