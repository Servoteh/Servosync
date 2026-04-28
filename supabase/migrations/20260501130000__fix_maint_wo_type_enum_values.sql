-- ============================================================================
-- FIX: dodaj 'incident' i 'preventive' u maint_wo_type enum
-- ============================================================================
-- extend_maint_incidents_assets.sql i integrate_maint_settings_behavior.sql
-- koriste 'incident', a add_maint_preventive_auto_wo.sql koristi 'preventive' --
-- obe vrednosti nedostaju u originalnoj enum definiciji iz add_maint_work_orders.sql.
-- ============================================================================

ALTER TYPE public.maint_wo_type ADD VALUE IF NOT EXISTS 'incident';
ALTER TYPE public.maint_wo_type ADD VALUE IF NOT EXISTS 'preventive';
