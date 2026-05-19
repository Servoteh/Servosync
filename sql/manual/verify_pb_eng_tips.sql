-- Verifikacija posle add_pb_eng_tips.sql (korak 1)
SELECT count(*) AS categories FROM public.pb_eng_tip_categories;
SELECT slug, naziv, redosled FROM public.pb_eng_tip_categories ORDER BY redosled;

SELECT proname FROM pg_proc
 WHERE pronamespace = 'public'::regnamespace
   AND proname LIKE 'pb_%eng_tip%'
 ORDER BY 1;

-- Očekivano bez JWT sesije: ERROR "Niste prijavljeni"
-- SELECT * FROM public.pb_list_eng_tips('{}'::jsonb);

-- Iz browser DevTools (authenticated):
-- fetch('<SUPABASE_URL>/rest/v1/rpc/pb_list_eng_tips', {
--   method: 'POST',
--   headers: { 'Content-Type': 'application/json', apikey: '<anon>', Authorization: 'Bearer <access_token>' },
--   body: JSON.stringify({ p_filter: {} })
-- }).then(r => r.json()).then(console.log);
-- Očekivano: [] (prazan niz)
