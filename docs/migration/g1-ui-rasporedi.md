# G1 UI rasporedi - Planiranje proizvodnje

## Trenutno stanje

- `Po masini` prikazuje operacije po izabranoj masini ili odeljenju. Napomena je trenutno pre skica i kolone masina, a labela glasi `Sefova napomena`.
- `Zauzetost masina` agregira otvorene operacije po masini iz `loadAllOpenOperations()` i nema tekstualni filter po RN/crtezu.
- `Pregled svih` gradi matricu rokova iz iste sirove liste operacija i nema tekstualni filter po RN/crtezu.

## G1 smernice za izmenu

- Filter `RN ili crtez...` je client-side i koristi isti helper za sva tri taba.
- `Po masini` zadrzava `state.rows` kao sirove redove, a tabela i footer rade nad filtriranim redovima.
- `Zauzetost masina` i `Pregled svih` agregiraju tek posle RN/crtez filtera, kako brojevi i total redovi prate vidljivi skup.
- Kolona napomene ostaje `shift_note` u bazi, ali se u UI zove `Napomena` i pomera se na kraj operativne tabele.
