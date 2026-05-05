-- Sinhronizacija odeljenja + ispravka imena (iz Excel/slike, 2026-04-29)
BEGIN;
SET statement_timeout = '300s';

UPDATE public.employees
SET
  full_name = 'Durutović Jelena',
  first_name = 'Jelena',
  last_name = 'Durutović',
  department = 'Administracija',
  updated_at = now()
WHERE id = 'b448ee90-f361-47d1-972c-61307f302a3b'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Korkut Dragana',
  first_name = 'Dragana',
  last_name = 'Korkut',
  department = 'Administracija',
  updated_at = now()
WHERE id = '6e73eca4-310a-48f4-9700-1f9f9b4b067f'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Mišković Nikola',
  first_name = 'Nikola',
  last_name = 'Mišković',
  department = 'Administracija',
  updated_at = now()
WHERE id = '1f9220a0-ba57-43bb-bb84-a251d9451810'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Stanišić Jelena',
  first_name = 'Jelena',
  last_name = 'Stanišić',
  department = 'Administracija',
  updated_at = now()
WHERE id = '96bea6bd-cbe6-40c3-9803-573f7869d3c6'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Birovljev Stevan',
  first_name = 'Stevan',
  last_name = 'Birovljev',
  department = 'Brušenje',
  updated_at = now()
WHERE id = '2ab04c30-53ea-476d-b9be-a44159798f90'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Glišić Lazar',
  first_name = 'Lazar',
  last_name = 'Glišić',
  department = 'Brušenje',
  updated_at = now()
WHERE id = '69ea1aba-84c6-48f9-8fb2-40210a43ee81'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Pantić Miloš',
  first_name = 'Miloš',
  last_name = 'Pantić',
  department = 'Brušenje',
  updated_at = now()
WHERE id = 'ff32e040-8628-4a05-ab5f-a1b0b8f4a1ee'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Vujičić Miloš',
  first_name = 'Miloš',
  last_name = 'Vujičić',
  department = 'Brušenje',
  updated_at = now()
WHERE id = '7622ca83-5f79-4874-b6f2-e0ccac694cbb'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Živković Slobodan',
  first_name = 'Slobodan',
  last_name = 'Živković',
  department = 'Brušenje',
  updated_at = now()
WHERE id = '0065933b-a5d6-479b-8081-521bfb3bb073'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Dobromirović Veljko',
  first_name = 'Veljko',
  last_name = 'Dobromirović',
  department = 'Čelične montaže',
  updated_at = now()
WHERE id = 'f101dfe7-c4c5-4cc9-9b15-7fb5712644f0'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Marić Jovan',
  first_name = 'Jovan',
  last_name = 'Marić',
  department = 'Čelične montaže',
  updated_at = now()
WHERE id = 'c7d157b7-cba5-4112-b38c-e431a154a5ef'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Mladenović Marko',
  first_name = 'Marko',
  last_name = 'Mladenović',
  department = 'Čelične montaže',
  updated_at = now()
WHERE id = 'b532450c-38d7-432e-b47e-4c0c64271a2b'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Dobromirović Dragan',
  first_name = 'Dragan',
  last_name = 'Dobromirović',
  department = 'Čelično projektovanje',
  updated_at = now()
WHERE id = '7a405835-7a09-43c0-b9a4-38770160dfa4'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Janković Mihajlo',
  first_name = 'Mihajlo',
  last_name = 'Janković',
  department = 'Praksa',
  updated_at = now()
WHERE id = '600cd1e3-70c5-484c-b62e-aef28503fee2'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Radelić Uroš',
  first_name = 'Uroš',
  last_name = 'Radelić',
  department = 'Praksa',
  updated_at = now()
WHERE id = '86e98f49-ce48-49de-be2a-4d42c1c75bb2'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Milojević Jovan',
  first_name = 'Jovan',
  last_name = 'Milojević',
  department = 'Inženjer prodaje',
  updated_at = now()
WHERE id = '45636c5b-bf43-4ac7-a57e-e0d674c92d17'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Trifunović Bojana',
  first_name = 'Bojana',
  last_name = 'Trifunović',
  department = 'Inženjer prodaje',
  updated_at = now()
WHERE id = 'b4c63f3e-c05f-447e-bad0-89b3f0c92e9a'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Đorđević Miloš',
  first_name = 'Miloš',
  last_name = 'Đorđević',
  department = 'Kontrola kvaliteta',
  updated_at = now()
WHERE id = '0ea56445-2f85-4d72-9e14-6ee7c8100d6b'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Krstić Bogdan',
  first_name = 'Bogdan',
  last_name = 'Krstić',
  department = 'Kontrola kvaliteta',
  updated_at = now()
WHERE id = 'c5287699-1586-4a36-bfdf-7961242af856'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Ilić Aleksandar',
  first_name = 'Aleksandar',
  last_name = 'Ilić',
  department = 'Logistika',
  updated_at = now()
WHERE id = '00b5d49e-24ea-4da4-8a34-386c0ee4d5b0'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Manojlović Marijana',
  first_name = 'Marijana',
  last_name = 'Manojlović',
  department = 'Logistika',
  updated_at = now()
WHERE id = '8e0a3c78-7cbd-414f-bff9-9331449a7a7b'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Perišić Branimira',
  first_name = 'Branimira',
  last_name = 'Perišić',
  department = 'Logistika',
  updated_at = now()
WHERE id = '0764e73d-fa40-4239-901e-a9a4c6586790'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Savić Nikola',
  first_name = 'Nikola',
  last_name = 'Savić',
  department = 'Logistika',
  updated_at = now()
WHERE id = '41de672a-2819-43bc-9623-d0ba91b44e7e'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Mihajlo Mladen',
  first_name = 'Mladen',
  last_name = 'Mihajlo',
  department = 'Magacin',
  updated_at = now()
WHERE id = '4719dc70-1df1-484c-b739-440874aee6e4'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Bogdanović Jovan',
  first_name = 'Jovan',
  last_name = 'Bogdanović',
  department = 'Mašinska montaža',
  updated_at = now()
WHERE id = 'cba25d58-9ea3-4880-b5fa-1297aa6ca8e3'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Cvijetinović Mirko',
  first_name = 'Mirko',
  last_name = 'Cvijetinović',
  department = 'Mašinska montaža',
  updated_at = now()
WHERE id = '2bc9e55e-fb6d-4638-81ec-d079253709b4'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Marković Mihajlo',
  first_name = 'Mihajlo',
  last_name = 'Marković',
  department = 'Mašinska montaža',
  updated_at = now()
WHERE id = '9deb3290-60c2-4030-af63-0478b6f34873'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Marić Stefan',
  first_name = 'Stefan',
  last_name = 'Marić',
  department = 'Mašinska montaža',
  updated_at = now()
WHERE id = 'f288b8f0-904f-4810-9c10-cf4185dc009c'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Orestijević Miloš',
  first_name = 'Miloš',
  last_name = 'Orestijević',
  department = 'Mašinska montaža',
  updated_at = now()
WHERE id = 'c587743f-cb80-426f-9702-b78382b40734'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Radivojević Vladan',
  first_name = 'Vladan',
  last_name = 'Radivojević',
  department = 'Mašinska montaža',
  updated_at = now()
WHERE id = '63da3077-5b4c-4459-b622-562c79d9ffd1'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Janković Dejan',
  first_name = 'Dejan',
  last_name = 'Janković',
  department = 'Mašinska obrada',
  updated_at = now()
WHERE id = '869addb4-4267-46f5-8d40-f5c3957bde05'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Madžarević Marko',
  first_name = 'Marko',
  last_name = 'Madžarević',
  department = 'Mašinska obrada',
  updated_at = now()
WHERE id = '41d1998a-2440-4f77-b30a-e912498879a4'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Nikolić Aleksandar',
  first_name = 'Aleksandar',
  last_name = 'Nikolić',
  department = 'Mašinska obrada',
  updated_at = now()
WHERE id = '698417f5-cf88-4ae6-97c6-0ab862ceadfa'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Trnavac Slobodan',
  first_name = 'Slobodan',
  last_name = 'Trnavac',
  department = 'Mašinska obrada',
  updated_at = now()
WHERE id = '4c3445ee-3d9c-4bc5-b3eb-60bc8aa17325'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Kostić Dušan',
  first_name = 'Dušan',
  last_name = 'Kostić',
  department = 'Menadžment',
  updated_at = now()
WHERE id = '36e5beb6-340b-413e-a277-d00527441c3d'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Nikolić Nenad',
  first_name = 'Nenad',
  last_name = 'Nikolić',
  department = 'Menadžment',
  updated_at = now()
WHERE id = '1ba1eb34-72fe-4e65-a853-2c8901ba898c'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Ninković Nikola',
  first_name = 'Nikola',
  last_name = 'Ninković',
  department = 'Menadžment',
  updated_at = now()
WHERE id = '489bdf18-36fe-4354-be55-76b1ae54851b'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Samardzic Marija',
  first_name = 'Marija',
  last_name = 'Samardzic',
  department = 'Nabavka',
  updated_at = now()
WHERE id = 'c6b95b70-66e8-448d-9c69-e8359183cabc'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Milošević Jovica',
  first_name = 'Jovica',
  last_name = 'Milošević',
  department = 'Tehnologija',
  updated_at = now()
WHERE id = '79d5279b-249c-4e23-85ab-b8829c0ea3e5'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Umićević Ivan',
  first_name = 'Ivan',
  last_name = 'Umićević',
  department = 'Održavanje',
  updated_at = now()
WHERE id = 'b85a3759-5f3c-4c7a-b140-5edc77d9ea4a'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Krstić Kalum',
  first_name = 'Kalum',
  last_name = 'Krstić',
  department = 'Proizvodnja',
  updated_at = now()
WHERE id = '2a9f6d9b-fb5c-4166-a997-9c78263d8c8b'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Jevtić Goran',
  first_name = 'Goran',
  last_name = 'Jevtić',
  department = 'Proizvodnja',
  updated_at = now()
WHERE id = '15775a2c-e2b6-436c-b13f-68f41936b521'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Jovanović Lazar',
  first_name = 'Lazar',
  last_name = 'Jovanović',
  department = 'Proizvodnja',
  updated_at = now()
WHERE id = '38adbc64-7f94-4c6f-8ba6-9132e98de8b9'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Kastratović Dijana',
  first_name = 'Dijana',
  last_name = 'Kastratović',
  department = 'Priprema i planiranje',
  updated_at = now()
WHERE id = '982d732e-9d3b-4b75-b845-efbcad0c3d3d'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Stanić Luka',
  first_name = 'Luka',
  last_name = 'Stanić',
  department = 'Proizvodnja',
  updated_at = now()
WHERE id = '644cc398-e3e7-4811-9f67-f234e8951575'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Stjepanović Darko',
  first_name = 'Darko',
  last_name = 'Stjepanović',
  department = 'Proizvodnja',
  updated_at = now()
WHERE id = 'b6497bbe-7db4-4e94-bf14-29ba873b0fab'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Trkulja Đuro',
  first_name = 'Đuro',
  last_name = 'Trkulja',
  department = 'Proizvodnja',
  updated_at = now()
WHERE id = 'f0c2da9a-372e-4033-98fe-53384eafc4be'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Vasić Marko',
  first_name = 'Marko',
  last_name = 'Vasić',
  department = 'Proizvodnja',
  updated_at = now()
WHERE id = 'b5937a6e-299a-404d-9f05-1ea9a386758f'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Vujatović Dejan',
  first_name = 'Dejan',
  last_name = 'Vujatović',
  department = 'Proizvodnja',
  updated_at = now()
WHERE id = '85cc73d2-1f68-4f38-a47a-7739a455e7bf'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Jelić Đorđe',
  first_name = 'Đorđe',
  last_name = 'Jelić',
  department = 'Projektant',
  updated_at = now()
WHERE id = '623601d1-9646-44e1-85ca-0a7391494b6a'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Ćirković Dejan',
  first_name = 'Dejan',
  last_name = 'Ćirković',
  department = 'Projektant',
  updated_at = now()
WHERE id = '785a4fc8-3bab-4457-a76d-4802d275c51e'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Ilić Pavle',
  first_name = 'Pavle',
  last_name = 'Ilić',
  department = 'Projektant',
  updated_at = now()
WHERE id = '154d39f5-4a0f-48bd-b33a-a41536e762b9'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Milovanović Milan',
  first_name = 'Milan',
  last_name = 'Milovanović',
  department = 'Projektant',
  updated_at = now()
WHERE id = 'aab199a3-3f29-4741-9532-f54e8115c9f2'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Popić Jovan',
  first_name = 'Jovan',
  last_name = 'Popić',
  department = 'Projektant',
  updated_at = now()
WHERE id = '548b0923-92de-4798-ab65-d4743ca6cd70'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Radisavljević Slaviša',
  first_name = 'Slaviša',
  last_name = 'Radisavljević',
  department = 'Projektant',
  updated_at = now()
WHERE id = '5382a06c-73bc-45d3-b0d6-06fd7878e0d4'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Stojanović Marko',
  first_name = 'Marko',
  last_name = 'Stojanović',
  department = 'Projektant',
  updated_at = now()
WHERE id = '6fb3c3e5-2aec-45f4-8bdf-c203c27e2349'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Aksentijević Nikola',
  first_name = 'Nikola',
  last_name = 'Aksentijević',
  department = 'Projektant',
  updated_at = now()
WHERE id = '718b1edb-b9fe-42c6-9c0e-58eda76a7ed7'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Anđić Mladen',
  first_name = 'Mladen',
  last_name = 'Anđić',
  department = 'Serviser',
  updated_at = now()
WHERE id = '969970e9-c8a5-46ff-8d65-c7fcdb13e7ee'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Obradović Lazar',
  first_name = 'Lazar',
  last_name = 'Obradović',
  department = 'Proizvodnja',
  updated_at = now()
WHERE id = '32948ed1-dab6-4500-a6c7-43830b632523'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Stanić Zoran',
  first_name = 'Zoran',
  last_name = 'Stanić',
  department = 'Projektant',
  updated_at = now()
WHERE id = '6982b529-dba0-473d-b1cf-fd012b09d83b'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Stojković Vuk',
  first_name = 'Vuk',
  last_name = 'Stojković',
  department = 'Proizvodnja',
  updated_at = now()
WHERE id = '2687ae63-7e6c-4518-93c7-319fb4e82242'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Tadić Luka',
  first_name = 'Luka',
  last_name = 'Tadić',
  department = 'Projektant',
  updated_at = now()
WHERE id = 'c9250ddc-be6b-4535-9290-c7ca647457cf'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Preradović Radovan',
  first_name = 'Radovan',
  last_name = 'Preradović',
  department = 'Sečenje',
  updated_at = now()
WHERE id = '7ac3f2d4-d390-4af8-be80-8223235dcac3'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Simović Ljubiša',
  first_name = 'Ljubiša',
  last_name = 'Simović',
  department = 'Priprema i planiranje',
  updated_at = now()
WHERE id = 'fe3357f9-c3a5-4c89-8a3c-1f99c1ff6077'::uuid
  AND is_active = true;

UPDATE public.employees
SET
  full_name = 'Stanić Aleksandar',
  first_name = 'Aleksandar',
  last_name = 'Stanić',
  department = 'Tehnologija',
  updated_at = now()
WHERE id = 'fee39535-2a22-46f6-937d-8790777bb33f'::uuid
  AND is_active = true;

COMMIT;

-- NEMA MAPIRANJA (ručno proveri):
--   Ana Gakašević → Gakašević Ana / Administracija (nema 1:1 mapi)
--   Dragana Madžarčić → Madžarčić Dragana / Administracija (nema 1:1 mapi)
--   Anđela Đorić → Đorić Anđela / Administracija (nema 1:1 mapi)
--   Vladimir Đelević → Đelević Vladimir / Brušenje (nema 1:1 mapi)
--   Živorad Stanković → Stanković Živorad / Brušenje (nema 1:1 mapi)
--   Željko Terzić → Terzić Željko / Brušenje (nema 1:1 mapi)
--   Mladen Markić → Markić Mladen / Čelične montaže (nema 1:1 mapi)
--   Sonja Živković → Živković Sonja / Čelično projektovanje (nema 1:1 mapi)
--   Marina Marić → Marić Marina / Kontrola kvaliteta (nema 1:1 mapi)
--   Dimitrije Uzurac → Uzurac Dimitrije / Kontrola kvaliteta (nema 1:1 mapi)
--   Slavko Lazić → Lazić Slavko / Logistika (nema 1:1 mapi)
--   Sofija Šoškić → Šoškić Sofija / Logistika (nema 1:1 mapi)
--   Radislav Popović → Popović Radislav / Magacin (nema 1:1 mapi)
--   Slavko Đokić → Đokić Slavko / Mašinska montaža (nema 1:1 mapi)
--   Petar Dražić → Dražić Petar / Mašinska montaža (nema 1:1 mapi)
--   Dragan Milivojević → Milivojević Dragan / Mašinska montaža (nema 1:1 mapi)
--   Nedeljko Šabić → Šabić Nedeljko / Mašinska montaža (nema 1:1 mapi)
--   Aleksa Šipovac → Šipovac Aleksa / Mašinska montaža (nema 1:1 mapi)
--   Milan Brčko → Brčko Milan / Mašinska obrada (nema 1:1 mapi)
--   Branko Kuzmić → Kuzmić Branko / Mašinska obrada (nema 1:1 mapi)
--   Nenad Milutinović → Milutinović Nenad / Mašinska obrada (nema 1:1 mapi)
--   Predrag Živanić → Živanić Predrag / Mašinska obrada (nema 1:1 mapi)
--   Dragoslav Đukić → Đukić Dragoslav / Mašinska obrada (nema 1:1 mapi)
--   Goran Janković → Janković Goran / Menadžment (nema 1:1 mapi)
--   Želimir Jevremović → Jevremović Želimir / Menadžment (nema 1:1 mapi)
--   Nemanja Knežević → Knežević Nemanja / Menadžment (nema 1:1 mapi)
--   Nenad Ljubinković → Ljubinković Nenad / Menadžment (nema 1:1 mapi)
--   Milan Milutinović → Milutinović Milan / Menadžment (nema 1:1 mapi)
--   Dragan Ilić → Ilić Dragan / Održavanje (nema 1:1 mapi)
--   Nataša Lalić → Lalić Nataša / Održavanje (nema 1:1 mapi)
--   Strahinja Perišić → Perišić Strahinja / Površinska zaštita (nema 1:1 mapi)
--   Mileta Cvijetinović → Cvijetinović Mileta / Proizvodnja (nema 1:1 mapi)
--   Jovan Milovanović → Milovanović Jovan / Proizvodnja (nema 1:1 mapi)
--   Nenad Bukvić → Bukvić Nenad / Proizvodnja (nema 1:1 mapi)
--   Nikola Đajić → Đajić Nikola / Proizvodnja (nema 1:1 mapi)
--   Nikola Milojević → Milojević Nikola / Proizvodnja (nema 1:1 mapi)
--   Mihajlo Nikolić → Nikolić Mihajlo / Proizvodnja (nema 1:1 mapi)
--   Nikola Nikolić → Nikolić Nikola / Proizvodnja (nema 1:1 mapi)
--   Milan Ružić → Ružić Milan / Proizvodnja (nema 1:1 mapi)
--   Stefan Simić → Simić Stefan / Proizvodnja (nema 1:1 mapi)
--   Jovan Srković → Srković Jovan / Proizvodnja (nema 1:1 mapi)
--   Miloš Stanojević → Stanojević Miloš / Proizvodnja (nema 1:1 mapi)
--   Nikola Stojanović → Stojanović Nikola / Proizvodnja (nema 1:1 mapi)
--   Ivan Zečević → Zečević Ivan / Proizvodnja (nema 1:1 mapi)
--   Tatjana Gajčić → Gajčić Tatjana / Projektant (nema 1:1 mapi)
--   Milena Jevtić → Jevtić Milena / Projektant (nema 1:1 mapi)
--   Vuk Predojević → Predojević Vuk / Projektant (nema 1:1 mapi)
--   Milan Stanimirović → Stanimirović Milan / Projektant (nema 1:1 mapi)
--   Luka Tešović → Tešović Luka / Projektant (nema 1:1 mapi)
--   Igor Votrić → Votrić Igor / Projektant (nema 1:1 mapi)
--   Jelena Đokić → Đokić Jelena / Administracija (nema 1:1 mapi)
--   Anastasija-Petra Krtinić → Krtinić Anastasija-Petra / Proizvodnja (nema 1:1 mapi)
--   Nikola Krvavac → Krvavac Nikola / Proizvodnja (nema 1:1 mapi)
--   Bojana Lalić → Lalić Bojana / Serviser (nema 1:1 mapi)
--   Slobodan Martinović → Martinović Slobodan / Proizvodnja (nema 1:1 mapi)
--   Miloš Milisavljević → Milisavljević Miloš / Čelične montaže (nema 1:1 mapi)
--   Andreja-Sava D. Mihajlovski → Mihajlovski Andreja-Sava D. / Proizvodnja (nema 1:1 mapi)
--   Nikola Mišić → Mišić Nikola / Proizvodnja (nema 1:1 mapi)
--   Vladan Perišić → Perišić Vladan / Projektant (nema 1:1 mapi)
--   Luka Popović → Popović Luka / Održavanje (nema 1:1 mapi)
--   Dejan Reljić → Reljić Dejan / Serviser (nema 1:1 mapi)
--   Viktor Rocić → Rocić Viktor / Proizvodnja (nema 1:1 mapi)
--   Dejan Stević → Stević Dejan / Proizvodnja (nema 1:1 mapi)
--   Luka Rocić → Rocić Luka / Proizvodnja (nema 1:1 mapi)
--   Dragan Đurić → Đurić Dragan / Tehnologija (nema 1:1 mapi)
--   Stefan Spasić → Spasić Stefan / Proizvodnja (nema 1:1 mapi)
--   Branislav Stojanović → Stojanović Branislav / Priprema i planiranje (nema 1:1 mapi)
--   Bojko Stojanović → Stojanović Bojko / Mašinska montaža (nema 1:1 mapi)
--   Milenko Tomić → Tomić Milenko / Logistika (nema 1:1 mapi)
--   Lazar Andrić → Andrić Lazar / Sečenje (nema 1:1 mapi)
--   Miloš Dugalić → Dugalić Miloš / Sečenje (nema 1:1 mapi)
--   Miloš Radovanović → Radovanović Miloš / Sečenje (nema 1:1 mapi)
--   Dušan Stojanović → Stojanović Dušan / Sečenje (nema 1:1 mapi)
--   Stefan Đokić → Đokić Stefan / Tehnologija (nema 1:1 mapi)
--   Veljko Milosović → Milosović Veljko / Tehnologija (nema 1:1 mapi)
