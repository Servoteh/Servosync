# PP-B — manuelni test checklist (`sortByUrgencyAndReady`)

**Preduslov:** PP-A aktiviran (**`is_ready_for_machine`** u API); app build sa PP-B granom.

1. **Mašina sa 0 operacija** — nema grešaka u konzoli; prazan state / Poruka kao ranije.

2. **Sve nehitno, mix spremno / nespremno** — na jednoj mašini samo **`is_urgent = false`**: prvo svi redovi koji su **`is_ready_for_machine`** (interni bucket 2), zatim oni koji nisu (bucket 3); unutar grupe kao ranije (**`shift_sort_order`**, rok).

3. **Sva četiri segmenta u mixu** — ručno ili izbor RN-ova tako da postoje redovi za bucket **0** (hitno+spremno), **1** (hitno+nespremno), **2** (nehitno+spremno), **3** (nehitno+nespremno). Lista mora strogo po **0 → 1 → 2 → 3** odozgo nadole (pre pin/drag pravila koja važe unutar bucketa).

4. **Drag-drop unutar istog bucket-a** — sačuvavo redosled, **`shift_sort_order`** se ažurira kroz **`reorderOverlays`** kao ranije.

5. **Pokušaj prevlačenja iz nižeg u viši bucket** — npr. bucket 3 pre bucket 2: ostaje staro; toast da nije dozvoljeno premeštati između grupa HITNO/spremnosti.

**Dodatak:** **Pregled svih / Zauzetost** — provera da Reload ne baca grešku; zbirni brojevi kao ranije (redosled operacija ovde ne ulazi u prikaz, ali obrađuju se kao sortiran niz posle RN filtera).
