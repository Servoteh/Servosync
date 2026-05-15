# PP-C — ručni test plan

1. **Mašina sa 0 prikazanih operacija:** izaberi mašinu (ili filter) tako da lista bude prazna — iznad stanja pojavljuje se traka **„Ukupno operacija: 0 · Ukupno planirano vreme: 0:00“** i footer Σ je konzistentan ako se tabela ipak vrati kasnije.
2. **Pet operacija od kojih jedna sistemski SKART/G4:** u „Po mašini” broj na traci je 5 (ili manje ako filter sakrije jednu); red sa skart izborom dobija klasu **`pp-row-scrap`**, žutu pozadinu i **„⚠ skart”** pored broja crteža; bedž kolone Spremnost ostaje kao do sada (G4).
3. **Uski ekran / mobilni:** traka **`pp-ops-agg-bar`** prelomljuje na dva vizuelna reda (bez horizontalnog štetanja kritičnog teksta).
4. **Skart + ručno HITNO + overdue rok:** proveriti da PP-B redosled ostaje bucket 0→3, a vizuel kombinacija (crveno hitno / žuto skart) je čitljiva.
5. **Zauzetost:** hover/tooltip kolone **„Otvoreno“** objašnjava da je to broj pozicija; broj odgovara broju prikazanih TP operacija kontrolnoj sumi po mašinama ako nema aktivnog RN filtera.
6. **Pregled svih:** ako mašina ima bar jednu `operationIsScrapRelease` poziciju, red gradi bedž „⚠ skart” i blagu žutu stranu kao **`pm-row-has-scrap`**.
7. **Paginacija RN po mašini:** kada postoji „još RN”, traka treba prikazati napomenu da je Σ za učitan deo liste.
