# PP-F — test plan (posle deploy triggera)

1. Unos / update prijave sa `started_at` → overlay postaje `in_progress` (ako nije `blocked`).
2. Overlay `blocked` → ostaje `blocked`.
3. Ponovljeni sync iste prijave → idempotentno, bez duplog pisanja.
4. UI: kada postoji `tech_routing_started_at` i status `in_progress`, vidi se bedž **auto** (nakon što migracija doda kolonu u view).
