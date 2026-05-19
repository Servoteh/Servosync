BEGIN;

DROP POLICY IF EXISTS "petf_storage_read" ON storage.objects;
DROP POLICY IF EXISTS "petf_storage_insert" ON storage.objects;
DROP POLICY IF EXISTS "petf_storage_update" ON storage.objects;
DROP POLICY IF EXISTS "petf_storage_delete" ON storage.objects;

DROP FUNCTION IF EXISTS public.pb_delete_eng_tip_category(uuid);
DROP FUNCTION IF EXISTS public.pb_upsert_eng_tip_category(jsonb);
DROP FUNCTION IF EXISTS public.pb_list_eng_tip_categories();
DROP FUNCTION IF EXISTS public.pb_delete_eng_tip_file(uuid);
DROP FUNCTION IF EXISTS public.pb_add_eng_tip_file(uuid, text, text, text, bigint);
DROP FUNCTION IF EXISTS public.pb_toggle_eng_tip_like(uuid);
DROP FUNCTION IF EXISTS public.pb_soft_delete_eng_tip(uuid);
DROP FUNCTION IF EXISTS public.pb_save_eng_tip(jsonb);
DROP FUNCTION IF EXISTS public.pb_get_eng_tip(uuid);
DROP FUNCTION IF EXISTS public.pb_list_eng_tips(jsonb);
DROP FUNCTION IF EXISTS public.pb_eng_tip_excerpt(text, int);
DROP FUNCTION IF EXISTS public.pb_eng_tip_can_manage(uuid);
DROP FUNCTION IF EXISTS public.pb_eng_tip_visible(uuid);
DROP FUNCTION IF EXISTS public.can_write_pb_eng_tips();
DROP FUNCTION IF EXISTS public.pb_eng_tips_search_tsv_sync() CASCADE;
DROP FUNCTION IF EXISTS public.pb_eng_tip_likes_count_sync() CASCADE;

DROP TABLE IF EXISTS public.pb_eng_tip_files CASCADE;
DROP TABLE IF EXISTS public.pb_eng_tip_likes CASCADE;
DROP TABLE IF EXISTS public.pb_eng_tips CASCADE;
DROP TABLE IF EXISTS public.pb_eng_tip_categories CASCADE;
DROP TYPE IF EXISTS public.pb_eng_tip_status;

DELETE FROM storage.buckets WHERE id = 'pb-eng-tip-files';

NOTIFY pgrst, 'reload schema';
COMMIT;
