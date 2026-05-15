# PP-D — test plan (manuelno)

1. RN sa tri linije (glodanje, struganje, brušenje na različitim `line_id`), u modalu označi samo dve → treća ostaje u planu na svom tabu/mašini; dve nestaju iz plana.
2. Skini obe iz kooperacije u modalu (odčekiraj + sačuvaj) → sve se vraćaju u plan (posle osvežavanja).
3. Legacy: postojeći `cooperation_status` bez redova u `production_cooperation_ops` — **cela** linija i dalje isključena iz plana (isto kao ranije).
4. Read-only korisnik: dugme **Kooperacija** disabled (kao ostala edit dugmad); modal se ne otvara kao editor.
5. Tab **Kooperacija**: prikazuje iste operacije koje su „isključene iz plana” prema novom predikatu.
