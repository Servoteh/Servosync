Attribute VB_Name = "Kamate"
Option Compare Database
Option Explicit
Global PrethodnaKamata As Variant

Function IzracunajKoeficijentKamate(TrebaDaPlati As Date, Platio As Date) As Double

Dim rst As DAO.Recordset, dbs As DAO.Database
Dim strCriteria As String
Dim Stopa As Double, n As Integer
Dim danakam As Variant
Dim DatumIzr As Date
Dim pom As Variant, tekkoef As Variant, ukkoef As Variant

pom = 1
DatumIzr = TrebaDaPlati
If Platio <= TrebaDaPlati Then               'ako je placeno na vreme
    ukkoef = 0
    GoTo Izlaz
Else
    Set dbs = CurrentDb
    Set rst = dbs.OpenRecordset("KamatneStope", dbOpenDynaset)
    strCriteria = "[OdDatumaStope] < " & Month(TrebaDaPlati)
    rst.FindFirst strCriteria                       'predvideti ako ne nadje
    Do
       rst.MoveNext
        If rst![OdDatumaStope] >= TrebaDaPlati Then                     'Me![DatumValute]
          Exit Do
        End If
   Loop
    rst.MovePrevious
NovaStopa:
    Stopa = rst![IznosStope]
    n = rst![ZaDana]
    rst.MoveNext
    If rst.EOF Then                     'da li je zadnji zapis
        GoTo ZadnjiZapis
    End If
    If Platio > rst![OdDatumaStope] Then    'ako je presao u sledecu stopu
            danakam = rst![OdDatumaStope] - DatumIzr
            DatumIzr = rst![OdDatumaStope]                           'za novi ciklus
            tekkoef = (1 + (Stopa / 100)) ^ (danakam / n)          'koeficijent po tekucoj stopi
            ukkoef = pom * tekkoef                                         'ukupni koeficijent
            pom = ukkoef                                                      'za novi ciklus
            GoTo NovaStopa
     Else                                                                           'ako racuna u tekucoj stopi
            danakam = Platio - DatumIzr                                 'Me![DatumPlacanja]
            tekkoef = (1 + (Stopa / 100)) ^ (danakam / n)          'koeficijent po tekucoj stopi
            ukkoef = pom * tekkoef                                         'ukupni koeficijent
            pom = ukkoef
      End If
      GoTo krajnji
ZadnjiZapis:
            danakam = Platio - DatumIzr
            tekkoef = (1 + (Stopa / 100)) ^ (danakam / n)          'koeficijent po tekucoj stopi
            ukkoef = pom * tekkoef
    End If
krajnji:
    ukkoef = ukkoef - 1
    IzracunajKoeficijentKamate = ukkoef
    rst.Close
    Set dbs = Nothing
Izlaz:
End Function

Function IzracunajKoeficijentKamate1(TrebaDaPlati As Date, Platio As Date) As Double

Dim rst As DAO.Recordset, dbs As DAO.Database
Dim strCriteria As String
Dim Stopa As Double, n As Integer
Dim danakam As Variant
Dim DatumIzr As Date, DatumStope As Date
Dim pom As Variant, tekkoef As Variant, ukkoef As Variant
Dim racunazadnji As Boolean

pom = 1
racunazadnji = False
DatumIzr = TrebaDaPlati
If Platio <= TrebaDaPlati Then               'ako je placeno na vreme
    ukkoef = 0
    GoTo Izlaz
Else
    Set dbs = CurrentDb
    Set rst = dbs.OpenRecordset("KamatneStope", dbOpenDynaset)
'**********************************************************************************
    rst.MoveFirst
    Do                                                     'trazi prvi slog kome pripada datum valute
        Stopa = rst![IznosStope]
        n = rst![ZaDana]
        If rst![OdDatumaStope] = TrebaDaPlati Then    'ako je pocetak stope jednak datumu valute
            Exit Do                                                     'uzima taj slog za racun
        Else
            If rst![OdDatumaStope] > TrebaDaPlati Then  'ako je pocetak stope veci od datuma valute
                rst.MovePrevious                                     'uzima prethodni slog kao zadnji ciji je datum manji
                If rst.BOF Then
                    rst.MoveFirst
                    If Platio > rst![OdDatumaStope] Then
                        'GoTo ZadnjiZapis                            'ako je to prvi slog i to manji od datuma valute
                        GoTo racuna
                    Else
                        ukkoef = 1
                        GoTo krajnji
                    End If
                End If
                Exit Do
             End If
        End If
        rst.MoveNext                                  'ako je pocetak stope manji od datuma valute
        If rst.EOF Then
            GoTo ZadnjiZapis                        'ako je zadnji slog a svi datumi stopa manji od datuma valute
        End If
    Loop
'**********************************************************************************
NovaStopa:                                                                        'sad racuna koeficijent
       Stopa = rst![IznosStope]
       n = rst![ZaDana]
       rst.MoveNext                                                              'ide na sledeci slog
            If rst.EOF Then
               rst.MoveLast                                                       'ako je zadnji slog i dalje manij od platio
               danakam = Platio - rst![OdDatumaStope]
               tekkoef = (1 + (Stopa / 100)) ^ (danakam / n)          'koeficijent po tekucoj stopi
               ukkoef = pom * tekkoef
               GoTo krajnji
            End If                                                                             'za zadnji obracun
racuna:
       If Platio > rst![OdDatumaStope] Then                                      'ako prelazi u sledecu stopu
            danakam = rst![OdDatumaStope] - DatumIzr
            DatumIzr = rst![OdDatumaStope]                                       'za novi ciklus
            tekkoef = (1 + (Stopa / 100)) ^ (danakam / n)          'koeficijent po tekucoj stopi
            ukkoef = pom * tekkoef                                         'ukupni koeficijent
            pom = ukkoef                                                      'za novi ciklus
            GoTo NovaStopa
       Else                                                                         'ako racuna samo u tekucoj stopi
            danakam = Platio - DatumIzr                                 'Me![DatumPlacanja]
            tekkoef = (1 + (Stopa / 100)) ^ (danakam / n)          'koeficijent po tekucoj stopi
            ukkoef = pom * tekkoef                                         'ukupni koeficijent
            pom = ukkoef
            GoTo krajnji
      End If
ZadnjiZapis:
            danakam = Platio - DatumIzr
            tekkoef = (1 + (Stopa / 100)) ^ (danakam / n)          'koeficijent po tekucoj stopi
            ukkoef = pom * tekkoef
    End If
krajnji:
    ukkoef = ukkoef - 1
    IzracunajKoeficijentKamate1 = ukkoef
    rst.Close
    Set dbs = Nothing
Izlaz:
End Function

Private Function IzracunajKoeficijentKamateRucnoKonformni(TrebaDaPlati As Date, Platio As Date, VRSTA As Long) As Double


Dim rst As DAO.Recordset, dbs As DAO.Database
Dim CriteriaManji As String, CriteriaVeci As String, CriteriaIsti As String, CriteriaVeciIsti As String
Dim Stopa As Double, n As Long
Dim danakam As Variant
Dim DatumIzr As Date
Dim pom As Variant, tekkoef As Variant, ukkoef As Variant
Dim pomdat As Date

pom = 1
DatumIzr = TrebaDaPlati
If Platio <= TrebaDaPlati Then               'ako je placeno na vreme
    ukkoef = 0
    GoTo Izlaz
Else
    Set dbs = CurrentDb
    Set rst = dbs.OpenRecordset("OK_StopeSortirane", dbOpenDynaset)
    CriteriaManji = "[OdDatumaStope] < # " & Format(TrebaDaPlati, "m-d-yy") & "# And [IDVrstaStope] = " & VRSTA
    CriteriaVeci = "[OdDatumaStope] > # " & Format(TrebaDaPlati, "m-d-yy") & "# And [IDVrstaStope] = " & VRSTA
    CriteriaIsti = "[OdDatumaStope] = # " & Format(TrebaDaPlati, "m-d-yy") & "# And [IDVrstaStope] = " & VRSTA
    CriteriaVeciIsti = "[OdDatumaStope] >= # " & Format(TrebaDaPlati, "m-d-yy") & "# And [IDVrstaStope] = " & VRSTA
    

        
    rst.FindFirst CriteriaIsti                      'trazi da li ima istih datuma
    pomdat = rst![OdDatumaStope]
    If rst.NoMatch Then
            GoTo trazimanji                          'ako nije nasao iste datume
    End If
    GoTo pripremaprvi                               'ako je nasao iste datume
trazimanji:
    rst.FindFirst CriteriaManji                   'ako nema istih, trazi prvi manji datum stope
    pomdat = rst![OdDatumaStope]
    If rst.NoMatch Then
        'MsgBox "Stopa za period Datuma Valute nije uneta"
            'GoTo pripremaprvi
        GoTo IzlazZatvori                          'nijedan datum stope nije manji od datuma valute
    End If
    Do
        rst.FindNext CriteriaManji
        If rst.NoMatch Then
              pomdat = rst![OdDatumaStope]
              GoTo pripremaprvi
        End If
        pomdat = rst![OdDatumaStope]
       'rst.MoveNext
       ' If rst![OdDatumaStope] >= TrebaDaPlati Then                     'Me![DatumValute]
       '   Exit Do
       ' End If
   Loop                                                 'ovim je nadjen zadnji manji
pripremaprvi:
   Stopa = rst![IznosStope]
   n = rst![ZaDana]
   'DatumIzr = rst![OdDatumaStope]
   rst.FindFirst CriteriaVeci                    'posle zadnjeg manjeg, trazi prvi veci
        If rst.NoMatch Then
            danakam = Platio - DatumIzr                                 'ako je ovo ujedno i zadnji
            tekkoef = (1 + (Stopa / 100)) ^ (danakam / n)          'koeficijent po tekucoj stopi
            ukkoef = pom * tekkoef                                         'ukupni koeficijent
            GoTo krajnji
         End If
    'rst.MovePrevious
NovaStopa:
    pomdat = rst![OdDatumaStope]
    'Stopa = rst![IznosStope]
    'n = rst![ZaDana]
    'rst.MoveNext
    'If rst.EOF Then                     'da li je zadnji zapis
    '    GoTo ZadnjiZapis
    'End If
    If Platio > rst![OdDatumaStope] Then    'ako je presao u sledecu stopu
            danakam = rst![OdDatumaStope] - DatumIzr
            DatumIzr = rst![OdDatumaStope]                           'za novi ciklus
            tekkoef = (1 + (Stopa / 100)) ^ (danakam / n)          'koeficijent po tekucoj stopi
            ukkoef = pom * tekkoef                                         'ukupni koeficijent
            pom = ukkoef                                                      'za novi ciklus
            Stopa = rst![IznosStope]
            n = rst![ZaDana]
            rst.FindNext CriteriaVeci
            If rst.NoMatch Then
                GoTo ZadnjiZapis
            Else
                GoTo NovaStopa
            End If
     Else                                                                           'ako racuna u tekucoj stopi
            danakam = Platio - DatumIzr                                 'Me![DatumPlacanja]
            tekkoef = (1 + (Stopa / 100)) ^ (danakam / n)          'koeficijent po tekucoj stopi
            ukkoef = pom * tekkoef                                         'ukupni koeficijent
            pom = ukkoef
      End If
      GoTo krajnji
ZadnjiZapis:
            danakam = Platio - DatumIzr
            tekkoef = (1 + (Stopa / 100)) ^ (danakam / n)          'koeficijent po tekucoj stopi
            ukkoef = pom * tekkoef
    End If
krajnji:
    ukkoef = ukkoef - 1
    IzracunajKoeficijentKamateRucnoKonformni = ukkoef
IzlazZatvori:
     rst.Close
    Set dbs = Nothing
Izlaz:
End Function
'Klasicna metoda
Private Function IzracunajKoeficijentKamateRucnoKlasicni(TrebaDaPlati As Date, Platio As Date, VRSTA As Long) As Double


Dim rst As DAO.Recordset, dbs As DAO.Database
Dim CriteriaManji As String, CriteriaVeci As String, CriteriaIsti As String, CriteriaVeciIsti As String
Dim Stopa As Double, n As Long
Dim danakam As Variant
Dim DatumIzr As Date
Dim pom As Variant, tekkoef As Variant, ukkoef As Variant
Dim pomdat As Date

pom = 0
DatumIzr = TrebaDaPlati
If Platio <= TrebaDaPlati Then               'ako je placeno na vreme
    ukkoef = 0
    GoTo Izlaz
Else
    Set dbs = CurrentDb
    Set rst = dbs.OpenRecordset("OK_StopeSortirane", dbOpenDynaset)
    CriteriaManji = "[OdDatumaStope] < # " & Format(TrebaDaPlati, "m-d-yy") & "# And [IDVrstaStope] = " & VRSTA
    CriteriaVeci = "[OdDatumaStope] > # " & Format(TrebaDaPlati, "m-d-yy") & "# And [IDVrstaStope] = " & VRSTA
    CriteriaIsti = "[OdDatumaStope] = # " & Format(TrebaDaPlati, "m-d-yy") & "# And [IDVrstaStope] = " & VRSTA
    CriteriaVeciIsti = "[OdDatumaStope] >= # " & Format(TrebaDaPlati, "m-d-yy") & "# And [IDVrstaStope] = " & VRSTA
    

        
    rst.FindFirst CriteriaIsti                      'trazi da li ima istih datuma
    pomdat = rst![OdDatumaStope]
    If rst.NoMatch Then
            GoTo trazimanji                          'ako nije nasao iste datume
    End If
    GoTo pripremaprvi                               'ako je nasao iste datume
trazimanji:
    rst.FindFirst CriteriaManji                   'ako nema istih, trazi prvi manji datum stope
    pomdat = rst![OdDatumaStope]
    If rst.NoMatch Then
        'MsgBox "Stopa za period Datuma Valute nije uneta"
            'GoTo pripremaprvi
        GoTo IzlazZatvori                          'nijedan datum stope nije manji od datuma valute
    End If
    Do
        rst.FindNext CriteriaManji
        If rst.NoMatch Then
              pomdat = rst![OdDatumaStope]
              GoTo pripremaprvi
        End If
        pomdat = rst![OdDatumaStope]
       'rst.MoveNext
       ' If rst![OdDatumaStope] >= TrebaDaPlati Then                     'Me![DatumValute]
       '   Exit Do
       ' End If
   Loop                                                 'ovim je nadjen zadnji manji
pripremaprvi:
   Stopa = rst![IznosStope]
   n = rst![ZaDana]
   'DatumIzr = rst![OdDatumaStope]
   rst.FindFirst CriteriaVeci                    'posle zadnjeg manjeg, trazi prvi veci
        If rst.NoMatch Then
            danakam = Platio - DatumIzr                                 'ako je ovo ujedno i zadnji
            'tekkoef = (1 + (Stopa / 100)) ^ (danakam / N)          'koeficijent po tekucoj stopi
            'ukkoef = pom * tekkoef                                         'ukupni koeficijent
            tekkoef = ((Stopa / 100) / n) * danakam
            ukkoef = pom + tekkoef
            GoTo krajnji
         End If
    'rst.MovePrevious
NovaStopa:
    pomdat = rst![OdDatumaStope]
    'Stopa = rst![IznosStope]
    'n = rst![ZaDana]
    'rst.MoveNext
    'If rst.EOF Then                     'da li je zadnji zapis
    '    GoTo ZadnjiZapis
    'End If
    If Platio > rst![OdDatumaStope] Then    'ako je presao u sledecu stopu
            danakam = rst![OdDatumaStope] - DatumIzr
            DatumIzr = rst![OdDatumaStope]                           'za novi ciklus
            'tekkoef = (1 + (Stopa / 100)) ^ (danakam / N)          'koeficijent po tekucoj stopi
            'ukkoef = pom * tekkoef                                         'ukupni koeficijent
            tekkoef = ((Stopa / 100) / n) * danakam
            ukkoef = pom + tekkoef
            pom = ukkoef                                                      'za novi ciklus
            Stopa = rst![IznosStope]
            n = rst![ZaDana]
            rst.FindNext CriteriaVeci
            If rst.NoMatch Then
                GoTo ZadnjiZapis
            Else
                GoTo NovaStopa
            End If
     Else                                                                           'ako racuna u tekucoj stopi
            danakam = Platio - DatumIzr                                 'Me![DatumPlacanja]
            'tekkoef = (1 + (Stopa / 100)) ^ (danakam / N)          'koeficijent po tekucoj stopi
            'ukkoef = pom * tekkoef                                         'ukupni koeficijent
            tekkoef = ((Stopa / 100) / n) * danakam
            ukkoef = pom + tekkoef
            pom = ukkoef
      End If
      GoTo krajnji
ZadnjiZapis:
            danakam = Platio - DatumIzr
            'tekkoef = (1 + (Stopa / 100)) ^ (danakam / N)          'koeficijent po tekucoj stopi
            'ukkoef = pom * tekkoef
            tekkoef = ((Stopa / 100) / n) * danakam
            ukkoef = pom + tekkoef
    End If
krajnji:
    'ukkoef = ukkoef - 1
    IzracunajKoeficijentKamateRucnoKlasicni = ukkoef
IzlazZatvori:
     rst.Close
    Set dbs = Nothing
Izlaz:
End Function
Public Function IzracunajKoeficijentKamateRucno(TrebaDaPlati As Date, Platio As Date, VRSTA As Long, VrstaObracuna As Long) As Double
Dim retVal As Double
    If VrstaObracuna = 1 Then  'Konformni
        retVal = IzracunajKoeficijentKamateRucnoKonformni(TrebaDaPlati, Platio, VRSTA)
    Else                        'klasicni
        retVal = IzracunajKoeficijentKamateRucnoKlasicni(TrebaDaPlati, Platio, VRSTA)
    End If
    IzracunajKoeficijentKamateRucno = Round(retVal, 10)
End Function

Function IzracunajIznosKamateIspravan(KontoBroj As Variant, NazivKomitenta As Variant, BrojDokumenta As Variant, VRSTA As Long) As Double

Dim rst As DAO.Recordset, dbs As DAO.Database
Dim Criteria As String
Dim pom As Variant, pomkoef As Variant, Koeficijent As Variant
Dim pomdat As Date
Dim pomime As String
Dim pomkonto As String, pomdok As String
Dim Iznos As Variant
Dim DATUM As Date
Dim Kamata As Variant
Dim uracunatakamata As Integer

uracunatakamata = 0
Kamata = 0
pomkoef = 1
Koeficijent = 1
Set dbs = CurrentDb
Set rst = dbs.OpenRecordset("KamatePrviKorak")
Criteria = "[Konto] = """ & KontoBroj & """ And [Naziv] = """ & NazivKomitenta & """ And [Broj dokumenta] = """ & BrojDokumenta & """ "

rst.FindFirst Criteria                                 'trazi prvi
pomkonto = rst![Konto]
pomime = rst![Naziv]
pomdok = rst![Broj dokumenta]
pomdat = rst![Valuta dokumenta]
If rst.NoMatch Then                                   'ako nije nasao
    rst.Close
    Set dbs = Nothing
    GoTo Izlaz
End If
Iznos = rst![SaldoStavke]                                 'kad je nasao prvi
DATUM = rst![Valuta dokumenta]
uzimasledeci:                                                  'uzima sledecu stavku
rst.FindNext Criteria
pomkonto = rst![Konto]
pomime = rst![Naziv]
pomdok = rst![Broj dokumenta]
pomdat = rst![Valuta dokumenta]
If rst.NoMatch Then                                     'ako je zadnji
    'If uracunatakamata = 1 Then
    '    GoTo preskociokamatu
    'End If
    If Iznos <> 0 Then
        pomkoef = IzracunajKoeficijentKamateRucnoKonformni(rst![Valuta dokumenta], Date, VRSTA)
        Kamata = Kamata + pomkoef * Iznos
    End If
preskociokamatu:
    IzracunajIznosKamateIspravan = Kamata
    rst.Close
    Set dbs = Nothing
    GoTo Izlaz
End If
'uracunatakamata = 0                                'ako je nasao sledeci
If DATUM = rst![Valuta dokumenta] Then
    Iznos = Iznos + rst![SaldoStavke]           'ako su isti datumi
    GoTo uzimasledeci
End If
                                                             'ako su datumi razliciti, racuna kamatu za tu razliku
If Iznos <> 0 Then
    pomkoef = IzracunajKoeficijentKamateRucnoKonformni(DATUM, rst![Valuta dokumenta], VRSTA) 'zamenio datume jer su sortirani rastuce
    'koeficijent = koeficijent * (1 + pomkoef)
    Kamata = Kamata + pomkoef * Iznos
    Iznos = Iznos + rst![SaldoStavke]
Else
    'koeficijent = 1
End If
'uracunatakamata = 1
DATUM = rst![Valuta dokumenta]
GoTo uzimasledeci

Izlaz:
End Function
Function IzracunajIznosKamateNova(KontoBroj As Variant, NazivKomitenta As Variant, BrojDokumenta As Variant, VRSTA As Long) As Double

Dim rst As DAO.Recordset, dbs As DAO.Database
Dim Criteria As String
Dim pom As Variant, pomkoef As Variant, Koeficijent As Variant
Dim pomdat As Date
Dim pomime As String
Dim pomkonto As String, pomdok As String
Dim Iznos As Variant, IznosKamate As Variant
Dim DATUM As Date
Dim Kamata As Variant, KamataDoNule As Variant
Dim uracunatakamata As Integer

uracunatakamata = 0
Kamata = 0
KamataDoNule = 0
pomkoef = 1
Koeficijent = 1
Set dbs = CurrentDb
'Set rst = dbs.OpenRecordset("KamatePrviKorak")
Set rst = dbs.OpenRecordset("KamateNapravljenaTabela", dbOpenDynaset)
Criteria = "[Konto] = """ & KontoBroj & """ And [Naziv] = """ & NazivKomitenta & """ And [Broj dokumenta] = """ & BrojDokumenta & """ "

rst.FindFirst Criteria                                 'trazi prvi
pomkonto = rst![Konto]
pomime = rst![Naziv]
pomdok = rst![Broj dokumenta]
pomdat = rst![Valuta dokumenta]
If rst.NoMatch Then                                   'ako nije nasao
    rst.Close
    Set dbs = Nothing
    GoTo Izlaz
End If
Iznos = rst![SaldoStavke]                                 'kad je nasao prvi
IznosKamate = Iznos
DATUM = rst![Valuta dokumenta]
uzimasledeci:                                                  'uzima sledecu stavku
rst.FindNext Criteria
pomkonto = rst![Konto]
pomime = rst![Naziv]
pomdok = rst![Broj dokumenta]
pomdat = rst![Valuta dokumenta]
If rst.NoMatch Then                                     'ako je zadnji
    'If uracunatakamata = 1 Then
    '    GoTo preskociokamatu
    'End If
    If Iznos <> 0 Then
        pomkoef = IzracunajKoeficijentKamateRucnoKonformni(rst![Valuta dokumenta], Date, VRSTA)
        Kamata = Kamata + pomkoef * IznosKamate
       ' Kamata = Kamata + KamataDoNule
    End If
preskociokamatu:
    Kamata = Kamata + KamataDoNule
    IzracunajIznosKamateNova = Kamata
    rst.Close
    Set dbs = Nothing
    GoTo Izlaz
End If
'uracunatakamata = 0                                'ako je nasao sledeci
If DATUM = rst![Valuta dokumenta] Then
    Iznos = Iznos + rst![SaldoStavke]           'ako su isti datumi
    IznosKamate = IznosKamate + rst![SaldoStavke]
    GoTo uzimasledeci
End If
                                                             'ako su datumi razliciti, racuna kamatu za tu razliku
If Iznos <> 0 Then
    pomkoef = IzracunajKoeficijentKamateRucnoKonformni(DATUM, rst![Valuta dokumenta], VRSTA) 'zamenio datume jer su sortirani rastuce
    'koeficijent = koeficijent * (1 + pomkoef)
    Kamata = Kamata + pomkoef * IznosKamate
    Iznos = Iznos + rst![SaldoStavke]
    IznosKamate = IznosKamate + rst![SaldoStavke] + Kamata
    If Iznos = 0 Then
        IznosKamate = 0
    End If
    
Else
    'koeficijent = 1
    Iznos = rst![SaldoStavke]
    'pomkoef = IzracunajKoeficijentKamateRucno(Datum, rst![Valuta dokumenta], Vrsta) 'zamenio datume jer su sortirani rastuce
    'Kamata = pomkoef * IznosKamate
    IznosKamate = rst![SaldoStavke]
    KamataDoNule = KamataDoNule + Kamata
    Kamata = 0
End If
'uracunatakamata = 1
DATUM = rst![Valuta dokumenta]
GoTo uzimasledeci

Izlaz:
End Function


Function IzracunajKamatuDoDatuma(StavkaID As Variant, KamDoDatuma As Date) As Date

Dim rst As DAO.Recordset, dbs As DAO.Database
Dim CriteriaIsti As String
Dim pomdat As Date, pomime As String, pomkonto As String, pomdok As String

Set dbs = CurrentDb
Set rst = dbs.OpenRecordset("KamatePrviKorak", dbOpenDynaset)
CriteriaIsti = "[StavkaID] = " & StavkaID

rst.FindFirst CriteriaIsti                              'trazi prvi
pomkonto = rst![Konto]
pomime = rst![Naziv]
pomdok = rst![Broj dokumenta]
'pomdat = rst![Valuta dokumenta]
If rst.NoMatch Then                                    'ako nije nasao
        GoTo Izlaz
End If
rst.MoveNext
If rst.EOF Then
    IzracunajKamatuDoDatuma = KamDoDatuma
Else
    If pomkonto = rst![Konto] And pomime = rst![Naziv] And pomdok = rst![Broj dokumenta] Then
             IzracunajKamatuDoDatuma = rst![Valuta dokumenta]
    Else
            IzracunajKamatuDoDatuma = KamDoDatuma
    End If
End If
Izlaz:
rst.Close
Set dbs = Nothing
End Function
Function IzracunajSumuZaKamatuNova(StavkaID As Variant) As Double

Dim rst As DAO.Recordset, rstpre As DAO.Recordset, dbs As DAO.Database
Dim CriteriaIsti As String
Dim pomdat As Date, pomime As String, pomkonto As String, pomdok As String
Dim Iznos As Variant, pomIznos As Variant, IznosZaKamatu As Variant
Dim PrethodniKoeficijent As Variant, PrethodnaSuma As Variant

pomIznos = 0
IznosZaKamatu = 0
Set dbs = CurrentDb
Set rst = dbs.OpenRecordset("KamatePrviKorak", dbOpenDynaset)
CriteriaIsti = "[StavkaID] = " & StavkaID

Iznos = 0
rst.FindFirst CriteriaIsti                              'trazi prvi
pomkonto = rst![Konto]
pomime = rst![Naziv]
pomdok = rst![Broj dokumenta]
'pomdat = rst![Valuta dokumenta]
Iznos = rst![SaldoStavke]
IznosZaKamatu = Iznos
If rst.NoMatch Then                                    'ako nije nasao
        GoTo Izlaz
End If
prethodni:
rst.MovePrevious
If rst.BOF Then
    'IzracunajSumuZaKamatu = Iznos
    GoTo Izlaz
Else
    If pomkonto = rst![Konto] And pomime = rst![Naziv] And pomdok = rst![Broj dokumenta] Then
             PrethodnaSuma = DLookup("IznosKamate", "KamateDetaljnoStavka", "[StavkaId]=" & rst![StavkaID])
             If PrethodnaSuma = 0 Then
                Iznos = Iznos
                IznosZaKamatu = IznosZaKamatu
                GoTo Izlaz
             Else
                Iznos = Iznos + rst![SaldoStavke]
                If Iznos <> 0 Then
                    'PrethodniKoeficijent = DLookup("KoeficijentKamate", "KamateDetaljnoStavka", "[StavkaId]=" & rst![StavkaID])
                    'PrethodnaSuma = DLookup("SumaZaKamatu", "KamateDetaljnoStavka", "[StavkaId]=" & rst![StavkaID])
                    'pomIznos = PrethodniKoeficijent * PrethodnaSuma
                    pomIznos = PrethodnaSuma
                    IznosZaKamatu = IznosZaKamatu + pomIznos + rst![SaldoStavke]
                Else
                    IznosZaKamatu = 0                       '!!!!???? jer kad je saldo bio na nuli, dalje ne uzima kamate IznosZaKamatu + rst![SaldoStavke]
                End If
                GoTo prethodni
             End If
                GoTo prethodni
    Else
            GoTo Izlaz
    'IzracunajSumuZaKamatu = Iznos + PrethodnaSuma
    '        PrethodnaSuma = 0
    End If
End If
Izlaz:
IzracunajSumuZaKamatuNova = IznosZaKamatu
rst.Close
Set dbs = Nothing
End Function
Function IzracunajSumuZaKamatuOdStare(StavkaID As Variant) As Double

Dim rst As DAO.Recordset, dbs As DAO.Database
Dim CriteriaIsti As String
Dim pomdat As Date, pomime As String, pomkonto As String, pomdok As String
Dim Iznos As Variant, PrethodnaKamata As Variant

Set dbs = CurrentDb
Set rst = dbs.OpenRecordset("KamatePrviKorak", dbOpenDynaset)
CriteriaIsti = "[StavkaID] = " & StavkaID

Iznos = 0
rst.FindFirst CriteriaIsti                              'trazi prvi
pomkonto = rst![Konto]
pomime = rst![Naziv]
pomdok = rst![Broj dokumenta]
pomdat = rst![Valuta dokumenta]
Iznos = rst![SaldoStavke]
If rst.NoMatch Then                                    'ako nije nasao
        GoTo Izlaz
End If
prethodni:
rst.MovePrevious
If rst.BOF Then
    'IzracunajSumuZaKamatu = Iznos
    GoTo Izlaz
Else
    If pomkonto = rst![Konto] And pomime = rst![Naziv] And pomdok = rst![Broj dokumenta] Then
             PrethodnaKamata = DLookup("IznosKamate", "KamateDetaljnoStavka", "[StavkaId]=" & rst![StavkaID])
             Iznos = Iznos + rst![SaldoStavke] + PrethodnaKamata
             GoTo prethodni
    Else
                        
            GoTo Izlaz
    'IzracunajSumuZaKamatu = Iznos + PrethodnaSuma
    '        PrethodnaSuma = 0
    End If
End If
Izlaz:
IzracunajSumuZaKamatuOdStare = Iznos
rst.Close
Set dbs = Nothing
End Function
Function IzracunajSumuZaKamatu(StavkaID As Variant, KontoBroj As Variant, NazivKomitenta As Variant, BrojDokumenta As Variant) As Double

Dim rst As DAO.Recordset, dbs As DAO.Database
Dim CriteriaIsti As String
Dim pomdat As Date, pomime As String, pomkonto As String, pomdok As String, pomstavka As Long
Dim DATUM As Date, Koef As Variant
Dim Iznos As Variant, PrethodnaKamata As Variant

Set dbs = CurrentDb
Set rst = dbs.OpenRecordset("KamatePrviKorak", dbOpenDynaset)
'CriteriaIsti = "[StavkaID] = " & StavkaID
CriteriaIsti = "[Konto] = """ & KontoBroj & """ And [Naziv] = """ & NazivKomitenta & """ And [Broj dokumenta] = """ & BrojDokumenta & """ "

Iznos = 0
PrethodnaKamata = 0
rst.FindFirst CriteriaIsti                              'trazi prvi
If rst.NoMatch Then                                    'ako nije nasao
        GoTo Izlaz
End If
pomkonto = rst![Konto]
pomime = rst![Naziv]
pomdok = rst![Broj dokumenta]
pomdat = rst![Valuta dokumenta]
DATUM = pomdat
Iznos = rst![SaldoStavke]
If rst![StavkaID] = StavkaID Then                   'ovo je za prvi
    GoTo Izlaz
End If
sledeci:
rst.MoveNext
If rst.EOF Then
    'IzracunajSumuZaKamatu = Iznos
    GoTo Izlaz
Else
       If pomkonto = rst![Konto] And pomime = rst![Naziv] And pomdok = rst![Broj dokumenta] Then
             Koef = IzracunajKoeficijentKamateRucnoKonformni(DATUM, rst![Valuta dokumenta], [Forms]![KamateDetaljnoStavka]![ComboVrstaKamate])
             PrethodnaKamata = Koef * Iznos
             'PrethodnaKamata = DLookup("IznosKamate", "KamateDetaljnoStavka", "[StavkaId]=" & rst![StavkaID])
             Iznos = Iznos + rst![SaldoStavke] + PrethodnaKamata
             DATUM = rst![Valuta dokumenta]
             If rst![StavkaID] = StavkaID Then
                GoTo Izlaz
             Else
                GoTo sledeci
             End If
        Else
                        
            GoTo Izlaz
    'IzracunajSumuZaKamatu = Iznos + PrethodnaSuma
    '        PrethodnaSuma = 0
        End If
End If
Izlaz:
IzracunajSumuZaKamatu = Iznos
rst.Close
Set dbs = Nothing
End Function

Function IzracunajIznosKamate(KontoBroj As Variant, NazivKomitenta As Variant, BrojDokumenta As Variant, VRSTA As Long, KamDoDatuma As Date) As Double

Dim rst As DAO.Recordset, dbs As DAO.Database
Dim Criteria As String
Dim pom As Variant, pomkoef As Variant, Koeficijent As Variant
Dim pomdat As Date
Dim pomime As String
Dim pomkonto As String, pomdok As String
Dim Iznos As Variant
Dim DATUM As Date
Dim Kamata As Variant
Dim uracunatakamata As Integer

uracunatakamata = 0
Kamata = 0
pomkoef = 1
Koeficijent = 1
Set dbs = CurrentDb
'Set rst = dbs.OpenRecordset("KamatePrviKorak")
Set rst = dbs.OpenRecordset("KamateNapravljenaTabela", dbOpenDynaset)
Criteria = "[Konto] = """ & KontoBroj & """ And [Naziv] = """ & NazivKomitenta & """ And [Broj dokumenta] = """ & BrojDokumenta & """ "

rst.FindFirst Criteria                                 'trazi prvi
pomkonto = rst![Konto]
pomime = rst![Naziv]
pomdok = rst![Broj dokumenta]
pomdat = rst![Valuta dokumenta]
If rst.NoMatch Then                                   'ako nije nasao
    rst.Close
    Set dbs = Nothing
    GoTo Izlaz
End If
Iznos = rst![SaldoStavke]                                 'kad je nasao prvi
DATUM = rst![Valuta dokumenta]
uzimasledeci:                                                  'uzima sledecu stavku
rst.FindNext Criteria
pomkonto = rst![Konto]
pomime = rst![Naziv]
pomdok = rst![Broj dokumenta]
pomdat = rst![Valuta dokumenta]
If rst.NoMatch Then                                     'ako je zadnji
    'If uracunatakamata = 1 Then
    '    GoTo preskociokamatu
    'End If
    If Iznos <> 0 Then
        pomkoef = IzracunajKoeficijentKamateRucnoKonformni(rst![Valuta dokumenta], KamDoDatuma, VRSTA)
        Kamata = Kamata + pomkoef * Iznos
    End If
preskociokamatu:
    IzracunajIznosKamate = Kamata
    rst.Close
    Set dbs = Nothing
    GoTo Izlaz
End If
'uracunatakamata = 0                                'ako je nasao sledeci
If DATUM = rst![Valuta dokumenta] Then
    Iznos = Iznos + rst![SaldoStavke]           'ako su isti datumi
    GoTo uzimasledeci
End If
                                                             'ako su datumi razliciti, racuna kamatu za tu razliku
If Iznos <> 0 Then
    pomkoef = IzracunajKoeficijentKamateRucnoKonformni(DATUM, rst![Valuta dokumenta], VRSTA) 'zamenio datume jer su sortirani rastuce
    'koeficijent = koeficijent * (1 + pomkoef)
    Kamata = Kamata + pomkoef * Iznos
    Iznos = Iznos + rst![SaldoStavke] + pomkoef * Iznos
Else
    Iznos = Iznos + rst![SaldoStavke]
    Kamata = Kamata
    'koeficijent = 1
End If
'uracunatakamata = 1
DATUM = rst![Valuta dokumenta]
GoTo uzimasledeci

Izlaz:
End Function

Sub ProknjiziUKamate(IDKomitent As Long, Konto As String, IDKamZag As Long, akDatObr As Date)

On Error GoTo ErrProknjiziUKamate
    
    Dim Kamate As DAO.Database
    Dim defQZaKamatePot As DAO.QueryDef
    Dim defQZaKamateDug As DAO.QueryDef
    Dim QZaKamatePot As DAO.Recordset
    Dim QZaKamateDug As DAO.Recordset
    Dim TblStKamate As DAO.Recordset
    
    Dim akBrDok As String
    Dim akIznosFak, akOsnZaObr, AkUplate, akTmpOsn, akKamata As Double
    Dim akDatValute, akDatPocObr, akDatFakture As Date


    Set Kamate = CurrentDb
    
    
    Set defQZaKamateDug = Kamate.QueryDefs("OK_Kamata_AK_Dugovna")
    defQZaKamateDug.Parameters("[Forms]![KarticaObveznika]![IDObveznika]") = IDKomitent
    'defQZaKamateDug.Parameters("[ZaKonto]") = Konto
    Set QZaKamateDug = defQZaKamateDug.OpenRecordset()
    
    Set defQZaKamatePot = Kamate.QueryDefs("OK_Kamata_AK_Potrazna")
    defQZaKamatePot.Parameters("[Forms]![KarticaObveznika]![IDObveznika]") = IDKomitent
    'defQZaKamatePot.Parameters("[ZaKonto]") = Konto
    Set QZaKamatePot = defQZaKamatePot.OpenRecordset()
    
    Set TblStKamate = Kamate.OpenRecordset("OK_Stavke", dbOpenDynaset)

    If QZaKamateDug.RecordCount > 0 Then QZaKamateDug.MoveFirst
    'prvi dokument
    akBrDok = QZaKamateDug![BrDok]
    akIznosFak = QZaKamateDug![Dug]
    akDatValute = QZaKamateDug![DatValute]
    akOsnZaObr = QZaKamateDug![Dug]
    akDatFakture = QZaKamateDug![DatDok]
    akDatPocObr = DateAdd("d", 1, QZaKamateDug![DatValute])
    AkUplate = 0
    akKamata = 0
    
    If QZaKamatePot.RecordCount > 0 Then QZaKamatePot.MoveFirst
    Do Until QZaKamateDug.EOF                                   ' Pocetak petlje
            
            Do Until QZaKamatePot.EOF                                   ' Pocetak petlje
ponovoPot:
                If akOsnZaObr > 0 Then
                    ' ako je platio u valuti, smanjujemo osnovicu za obr
                    If QZaKamatePot![DatPlacanja] <= akDatValute Then
                        AkUplate = AkUplate + QZaKamatePot![Pot]
                        akTmpOsn = akOsnZaObr
                        akOsnZaObr = IIf(AkUplate > akOsnZaObr, 0, akOsnZaObr - AkUplate) '- QZaKamatePot![Pot]
                        AkUplate = IIf(AkUplate > akTmpOsn, AkUplate - akTmpOsn, 0)
                        akKamata = 0
                    Else
                       ' If akDatObr > QZaKamatePot![DatPlacanja] Then
                       '     akOsnZaObr = akOsnZaObr + akKamata
                       ' Else
                       '     akOsnZaObr = akOsnZaObr
                       ' End If
                        akOsnZaObr = akOsnZaObr + akKamata
                        
                        TblStKamate.AddNew
                        TblStKamate![IDOK] = IDKamZag
                        TblStKamate![BrojDokumenta] = akBrDok
                        TblStKamate![DatumDokumenta] = akDatFakture
                        TblStKamate![DatumValute] = akDatPocObr
                        TblStKamate![DatumPlacanja] = QZaKamatePot![DatPlacanja]
                        TblStKamate![Iznos] = akOsnZaObr
                        If Not QZaKamateDug.EOF Then TblStKamate![Duguje] = QZaKamateDug![Dug]
                        If Not QZaKamatePot.EOF Then TblStKamate![Potrazuje] = QZaKamatePot![Pot]
                        TblStKamate.Update
                        akKamata = IzracunajKoeficijentKamateRucnoKonformni(CVDate(akDatPocObr), CVDate(QZaKamatePot![DatPlacanja]), 1) * akOsnZaObr
                        
                        AkUplate = AkUplate + QZaKamatePot![Pot]
                        akTmpOsn = akOsnZaObr
                        akOsnZaObr = IIf(AkUplate > akOsnZaObr, 0, akOsnZaObr - AkUplate) '- QZaKamatePot![Pot]
                        AkUplate = IIf(AkUplate > akTmpOsn, AkUplate - akTmpOsn, 0)
                        akDatPocObr = DateAdd("d", 1, QZaKamatePot![DatPlacanja])
                    End If
                Else
                    'AkUplate = QZaKamatePot![Pot] + AkUplate
                    QZaKamateDug.MoveNext
                    akBrDok = QZaKamateDug![BrDok]
                    akIznosFak = QZaKamateDug![Dug]
                    akDatValute = QZaKamateDug![DatValute]
                    akOsnZaObr = QZaKamateDug![Dug]
                    akDatFakture = QZaKamateDug![DatDok]
                    akDatPocObr = DateAdd("d", 1, QZaKamateDug![DatValute])
                    GoTo ponovoPot
               End If
            QZaKamatePot.MoveNext                                   ' Pozicioniraj se na sledeci rekord
            Loop
              If akOsnZaObr <> 0 Then
                        
                        akOsnZaObr = akOsnZaObr '+ akKamata
                        TblStKamate.AddNew
                        TblStKamate![IDOK] = IDKamZag
                        TblStKamate![BrojDokumenta] = akBrDok
                        TblStKamate![DatumDokumenta] = akDatFakture
                       ' TblStKamate![IznosFakture] = akIznosFak
                        TblStKamate![DatumValute] = akDatPocObr
                       ' TblStKamate![IznosPlacanja] = QZaKamatePot![Pot]
                       ' TblStKamate![OdDatuma] = akDatPocObr
                        TblStKamate![DatumPlacanja] = akDatObr
                        TblStKamate![Iznos] = akOsnZaObr
                        If Not QZaKamateDug.EOF Then TblStKamate![Duguje] = QZaKamateDug![Dug]
                        If Not QZaKamatePot.EOF Then TblStKamate![Potrazuje] = QZaKamatePot![Pot]
                        TblStKamate.Update
                        akKamata = IzracunajKoeficijentKamateRucnoKonformni(CVDate(akDatPocObr), CVDate(akDatObr), 1) * akOsnZaObr

                End If
                QZaKamateDug.MoveNext
                If Not QZaKamateDug.EOF Then
                     If AkUplate <> 0 Then
                        QZaKamatePot.MovePrevious
                        AkUplate = AkUplate - QZaKamatePot![Pot]
                    End If
                    akBrDok = QZaKamateDug![BrDok]
                    akIznosFak = QZaKamateDug![Dug]
                    akDatValute = QZaKamateDug![DatValute]
                    akOsnZaObr = QZaKamateDug![Dug]
                    akDatFakture = QZaKamateDug![DatDok]
                    akDatPocObr = DateAdd("d", 1, QZaKamateDug![DatValute])
                   
                    
                End If
                Loop
        
   
    TblStKamate.Close
    Set TblStKamate = Nothing
    QZaKamatePot.Close
    Set QZaKamatePot = Nothing
    QZaKamateDug.Close
    Set QZaKamateDug = Nothing
    
    Kamate.Close
    Set Kamate = Nothing
Exit Sub

ErrProknjiziUKamate:

 MsgBox Error$
 Resume Next

End Sub
Sub ProknjiziUKamate_SADA(IDKomitent As Long, Konto As String, IDKamZag As Long, akDatObr As Date)

On Error GoTo ErrProknjiziUKamate
    
    Dim Kamate As DAO.Database
    Dim defQZaKamatePot As DAO.QueryDef
    Dim defQZaKamateDug As DAO.QueryDef
    Dim QZaKamatePot As DAO.Recordset
    Dim QZaKamateDug As DAO.Recordset
    Dim TblStKamate As DAO.Recordset
    
    Dim akBrDok As String
    Dim akIznosFak, akOsnZaObr, AkUplate, akTmpOsn, akKamata As Double
    Dim akDatValute, akDatPocObr, akDatFakture As Date


    Set Kamate = CurrentDb
    
    
    Set defQZaKamateDug = Kamate.QueryDefs("OK_Kamata_AK_Dugovna")
    defQZaKamateDug.Parameters("[Forms]![KarticaObveznika]![IDObveznika]") = IDKomitent
    'defQZaKamateDug.Parameters("[ZaKonto]") = Konto
    Set QZaKamateDug = defQZaKamateDug.OpenRecordset()
    
    Set defQZaKamatePot = Kamate.QueryDefs("OK_Kamata_AK_Potrazna")
    defQZaKamatePot.Parameters("[Forms]![KarticaObveznika]![IDObveznika]") = IDKomitent
    'defQZaKamatePot.Parameters("[ZaKonto]") = Konto
    Set QZaKamatePot = defQZaKamatePot.OpenRecordset()
    
    Set TblStKamate = Kamate.OpenRecordset("OK_Stavke", dbOpenDynaset)

    If QZaKamateDug.RecordCount > 0 Then QZaKamateDug.MoveFirst
    'prvi dokument
    akBrDok = QZaKamateDug![BrDok]
    akIznosFak = QZaKamateDug![Dug]
    akDatValute = QZaKamateDug![DatValute]
    akOsnZaObr = QZaKamateDug![Dug]
    akDatFakture = QZaKamateDug![DatDok]
    akDatPocObr = DateAdd("d", 1, QZaKamateDug![DatValute])
    AkUplate = 0
    akKamata = 0
    
    If QZaKamatePot.RecordCount > 0 Then QZaKamatePot.MoveFirst
    Do Until QZaKamateDug.EOF                                   ' Pocetak petlje
            
            Do Until QZaKamatePot.EOF                                   ' Pocetak petlje
ponovoPot:
                If akOsnZaObr > 0 Then
                    ' ako je platio u valuti, smanjujemo osnovicu za obr
                    If QZaKamatePot![DatPlacanja] <= akDatValute Then
                        AkUplate = AkUplate + QZaKamatePot![Pot]
                        akTmpOsn = akOsnZaObr
                        akOsnZaObr = IIf(AkUplate > akOsnZaObr, 0, akOsnZaObr - AkUplate) '- QZaKamatePot![Pot]
                        AkUplate = IIf(AkUplate > akTmpOsn, AkUplate - akTmpOsn, 0)
                        akKamata = 0
                    Else
                        akOsnZaObr = akOsnZaObr + akKamata
                        TblStKamate.AddNew
                        TblStKamate![IDOK] = IDKamZag
                        TblStKamate![BrojDokumenta] = akBrDok
                        TblStKamate![DatumDokumenta] = akDatFakture
                        TblStKamate![DatumValute] = akDatPocObr
                        TblStKamate![DatumPlacanja] = QZaKamatePot![DatPlacanja]
                        TblStKamate![Iznos] = akOsnZaObr
                        If Not QZaKamateDug.EOF Then TblStKamate![Duguje] = QZaKamateDug![Dug]
                        If Not QZaKamatePot.EOF Then TblStKamate![Potrazuje] = QZaKamatePot![Pot]
                        TblStKamate.Update
                        akKamata = IzracunajKoeficijentKamateRucnoKonformni(CVDate(akDatPocObr), CVDate(QZaKamatePot![DatPlacanja]), 1) * akOsnZaObr
                        
                        AkUplate = AkUplate + QZaKamatePot![Pot]
                        akTmpOsn = akOsnZaObr
                        akOsnZaObr = IIf(AkUplate > akOsnZaObr, 0, akOsnZaObr - AkUplate) '- QZaKamatePot![Pot]
                        AkUplate = IIf(AkUplate > akTmpOsn, AkUplate - akTmpOsn, 0)
                        akDatPocObr = DateAdd("d", 1, QZaKamatePot![DatPlacanja])
                    End If
                Else
                    'AkUplate = QZaKamatePot![Pot] + AkUplate
                    QZaKamateDug.MoveNext
                    akBrDok = QZaKamateDug![BrDok]
                    akIznosFak = QZaKamateDug![Dug]
                    akDatValute = QZaKamateDug![DatValute]
                    akOsnZaObr = QZaKamateDug![Dug]
                    akDatFakture = QZaKamateDug![DatDok]
                    akDatPocObr = DateAdd("d", 1, QZaKamateDug![DatValute])
                    GoTo ponovoPot
               End If
            QZaKamatePot.MoveNext                                   ' Pozicioniraj se na sledeci rekord
            Loop
              If akOsnZaObr <> 0 Then
                        
                        akOsnZaObr = akOsnZaObr + akKamata
                        TblStKamate.AddNew
                        TblStKamate![IDOK] = IDKamZag
                        TblStKamate![BrojDokumenta] = akBrDok
                        TblStKamate![DatumDokumenta] = akDatFakture
                       ' TblStKamate![IznosFakture] = akIznosFak
                        TblStKamate![DatumValute] = akDatPocObr
                       ' TblStKamate![IznosPlacanja] = QZaKamatePot![Pot]
                       ' TblStKamate![OdDatuma] = akDatPocObr
                        TblStKamate![DatumPlacanja] = akDatObr
                        TblStKamate![Iznos] = akOsnZaObr
                        If Not QZaKamateDug.EOF Then TblStKamate![Duguje] = QZaKamateDug![Dug]
                        If Not QZaKamatePot.EOF Then TblStKamate![Potrazuje] = QZaKamatePot![Pot]
                        TblStKamate.Update
                        akKamata = IzracunajKoeficijentKamateRucnoKonformni(CVDate(akDatPocObr), CVDate(akDatObr), 1) * akOsnZaObr

                End If
                QZaKamateDug.MoveNext
                If Not QZaKamateDug.EOF Then
                     If AkUplate <> 0 Then
                        QZaKamatePot.MovePrevious
                        AkUplate = AkUplate - QZaKamatePot![Pot]
                    End If
                    akBrDok = QZaKamateDug![BrDok]
                    akIznosFak = QZaKamateDug![Dug]
                    akDatValute = QZaKamateDug![DatValute]
                    akOsnZaObr = QZaKamateDug![Dug]
                    akDatFakture = QZaKamateDug![DatDok]
                    akDatPocObr = DateAdd("d", 1, QZaKamateDug![DatValute])
                   
                    
                End If
                Loop
        
   
    TblStKamate.Close
    Set TblStKamate = Nothing
    QZaKamatePot.Close
    Set QZaKamatePot = Nothing
    QZaKamateDug.Close
    Set QZaKamateDug = Nothing
    
    Kamate.Close
    Set Kamate = Nothing
Exit Sub

ErrProknjiziUKamate:

 MsgBox Error$
 Resume Next

End Sub
Sub ProknjiziUKamatePripremuKonformno(IDKomitent As Long, Konto As String, IDKamZag As Long, akDatObr As Date, PeriodOdDatuma As Date, PeriodDoDatuma As Date)

On Error GoTo ErrProknjiziUKamate
    
    Dim Kamate As DAO.Database
    
    Dim defQZaKamateAK As DAO.QueryDef
    Dim QZaKamateAK As DAO.Recordset
    Dim TblKamateStavke As DAO.Recordset
    
    Dim PrometGlavnice As Double
    Dim PrometKamate As Double
    Dim IznosKamateZaStavku As Double
    Dim akDatValute, akDatPocObr, akDatKrajObr As Date
    
    Set Kamate = CurrentDb
    Set defQZaKamateAK = Kamate.QueryDefs("OK_Kamata_AK_Priprema")
    defQZaKamateAK.Parameters("[ZaIDKomitenta]") = IDKomitent
    defQZaKamateAK.Parameters("[OdDatuma]") = PeriodOdDatuma
    defQZaKamateAK.Parameters("[DoDatuma]") = PeriodDoDatuma
    defQZaKamateAK.Parameters("[ZaKonto]") = Konto
    Set QZaKamateAK = defQZaKamateAK.OpenRecordset()
    
    Set TblKamateStavke = Kamate.OpenRecordset("OK_Stavke", dbOpenDynaset)

    If QZaKamateAK.RecordCount > 0 Then QZaKamateAK.MoveFirst
    PrometGlavnice = 0
    PrometKamate = 0
   
    Do Until QZaKamateAK.EOF        ' Pocetak petlje
        TblKamateStavke.AddNew
        PrometGlavnice = PrometGlavnice + QZaKamateAK![Dug] - QZaKamateAK![Pot]
        TblKamateStavke![IDOK] = IDKamZag
        TblKamateStavke![BrojDokumenta] = QZaKamateAK![BrDok]
        TblKamateStavke![DatumDokumenta] = QZaKamateAK![DatDok]
        TblKamateStavke![DatumValute] = QZaKamateAK![DatValute]
        
        TblKamateStavke![Iznos] = PrometGlavnice + PrometKamate
        TblKamateStavke![Saldo] = PrometGlavnice
        
        
        
        TblKamateStavke![Duguje] = QZaKamateAK![Dug]
        TblKamateStavke![Potrazuje] = QZaKamateAK![Pot]
        
        QZaKamateAK.MoveNext
        
        If Not QZaKamateAK.EOF Then
         TblKamateStavke![DatumPlacanja] = QZaKamateAK![DatValute]
        Else
            TblKamateStavke![DatumPlacanja] = akDatObr 'QZaKamateAK![DatPlacanja]
        End If
        IznosKamateZaStavku = IzracunajKoeficijentKamateRucnoKonformni(TblKamateStavke![DatumValute], TblKamateStavke![DatumPlacanja], 1) * TblKamateStavke![Iznos]
        If IznosKamateZaStavku < 0 Then
            IznosKamateZaStavku = 0
        End If
        PrometKamate = PrometKamate + IznosKamateZaStavku
        TblKamateStavke![IznosKamate] = IznosKamateZaStavku
        
        TblKamateStavke.Update
                        
        
    Loop
        
   
    TblKamateStavke.Close
    Set TblKamateStavke = Nothing
    
    QZaKamateAK.Close
    Set QZaKamateAK = Nothing
    
    Kamate.Close
    Set Kamate = Nothing
Exit Sub

ErrProknjiziUKamate:

 MsgBox Error$
 Resume Next

End Sub
Sub ProknjiziUKamatePripremu(IDKomitent As Long, Konto As String, IDKamZag As Long, akDatObr As Date, PeriodOdDatuma As Date, PeriodDoDatuma As Date, VrstaObracuna As Long)

On Error GoTo ErrProknjiziUKamate
    
    Dim Kamate As DAO.Database
    
    Dim defQZaKamateAK As DAO.QueryDef
    Dim QZaKamateAK As DAO.Recordset
    Dim TblKamateStavke As DAO.Recordset
    
    Dim PrometGlavnice As Double
    Dim PrometKamate As Double
    Dim IznosKamateZaStavku As Double
    Dim akDatValute, akDatPocObr, akDatKrajObr As Date
    
    Set Kamate = CurrentDb
    Set defQZaKamateAK = Kamate.QueryDefs("OK_Kamata_AK_Priprema")
    defQZaKamateAK.Parameters("[ZaIDKomitenta]") = IDKomitent
    defQZaKamateAK.Parameters("[OdDatuma]") = PeriodOdDatuma
    defQZaKamateAK.Parameters("[DoDatuma]") = PeriodDoDatuma
    defQZaKamateAK.Parameters("[ZaKonto]") = Konto
    Set QZaKamateAK = defQZaKamateAK.OpenRecordset()
    
    Set TblKamateStavke = Kamate.OpenRecordset("OK_Stavke", dbOpenDynaset)

    If QZaKamateAK.RecordCount > 0 Then QZaKamateAK.MoveFirst
    PrometGlavnice = 0
    PrometKamate = 0
   
    Do Until QZaKamateAK.EOF        ' Pocetak petlje
        TblKamateStavke.AddNew
        PrometGlavnice = PrometGlavnice + QZaKamateAK![Dug] - QZaKamateAK![Pot]
        TblKamateStavke![IDOK] = IDKamZag
        TblKamateStavke![BrojDokumenta] = QZaKamateAK![BrDok]
        TblKamateStavke![DatumDokumenta] = QZaKamateAK![DatDok]
        TblKamateStavke![DatumValute] = QZaKamateAK![DatValute]
        
        If VrstaObracuna = 1 Then 'konformni
         TblKamateStavke![Iznos] = PrometGlavnice + PrometKamate
        Else                      'klasicni
         TblKamateStavke![Iznos] = PrometGlavnice
        End If
        TblKamateStavke![Saldo] = PrometGlavnice
        
        
        
        TblKamateStavke![Duguje] = QZaKamateAK![Dug]
        TblKamateStavke![Potrazuje] = QZaKamateAK![Pot]
        
        QZaKamateAK.MoveNext
        
        If Not QZaKamateAK.EOF Then
         TblKamateStavke![DatumPlacanja] = QZaKamateAK![DatValute]
        Else
            TblKamateStavke![DatumPlacanja] = akDatObr 'QZaKamateAK![DatPlacanja]
        End If
        IznosKamateZaStavku = IzracunajKoeficijentKamateRucno(TblKamateStavke![DatumValute], TblKamateStavke![DatumPlacanja], 1, VrstaObracuna) * TblKamateStavke![Iznos]
        If IznosKamateZaStavku < 0 Then
            IznosKamateZaStavku = 0
        End If
        PrometKamate = PrometKamate + IznosKamateZaStavku
        TblKamateStavke![IznosKamate] = IznosKamateZaStavku
        
        TblKamateStavke.Update
                        
        
    Loop
        
   
    TblKamateStavke.Close
    Set TblKamateStavke = Nothing
    
    QZaKamateAK.Close
    Set QZaKamateAK = Nothing
    
    Kamate.Close
    Set Kamate = Nothing
Exit Sub

ErrProknjiziUKamate:

 MsgBox Error$
 Resume Next

End Sub
Public Function KreirajKamataDok(IDKomitent As String, _
                                    LokSifKom As String, _
                                    BrojObracuna As String, _
                                    DatumObracuna As Variant, _
                                    DatumValute As Variant, _
                                    Opis As String, _
                                    Napomena As Variant, _
                                    Konto As String, _
                                    OdDatuma As Date, _
                                    DoDatuma As Date, _
                                    SerijaObracuna As String, VrstaObracuna As Long) As Long
On Error GoTo GreskaKreirajKamataDok
 

    Dim BigBit As DAO.Database
    Dim TabDok As DAO.Recordset
    Dim NoviIDDok, IDMag As Long
    Dim tmp As Variant
    Dim BrojDokumenta As String
    
    
    Set BigBit = CurrentDb
    Set TabDok = BigBit.OpenRecordset("OK_Zag", DB_OPEN_DYNASET, dbSeeChanges)
    
If BrojObracuna = "" Or IsNull(BrojObracuna) Then
    BrojDokumenta = 1 + Nz(DCount("[IDOK]", "OK_Zag"), 0)
    BrojDokumenta = DoChLeft(BrojDokumenta, BBCFG.BrojZnakovaZaBrDok, "0")
Else
    BrojDokumenta = BrojObracuna
End If
  BrojDokumenta = LokSifKom & "-" & BrojDokumenta
    
TabDok.AddNew                                'Dodaj novi rekord

TabDok![IDKomitent] = IDKomitent
TabDok![BrojObracuna] = BrojDokumenta
TabDok![DatumObracuna] = DatumObracuna
TabDok![DatumValute] = DatumValute
TabDok![Opis] = Opis
TabDok![Napomena] = Napomena
TabDok![ZaKonto] = Konto
TabDok![PeriodOdDatuma] = OdDatuma
TabDok![PeriodDoDatuma] = DoDatuma
TabDok![SerijaObracuna] = SerijaObracuna
TabDok![VrstaObracuna] = VrstaObracuna
NoviIDDok = TabDok![IDOK]
TabDok.Update                    'Sacuvaj izmene

TabDok.Close
Set TabDok = Nothing
BigBit.Close
Set BigBit = Nothing

KreirajKamataDok = NoviIDDok

ExitKreirajKamataDok:
Exit Function

GreskaKreirajKamataDok:
 MsgBox Error$
 Resume Next

End Function

Public Function NovaSerijaObracuna() As String
    Dim PoslednjaSerijaObracuna As Long
    Dim retVal As String
    PoslednjaSerijaObracuna = Nz(DLookup("[NumPoslednjaSerijaObracuna]", "OK_NumPoslednjaSerijaObracuna"), 0)
    PoslednjaSerijaObracuna = PoslednjaSerijaObracuna + 1
    retVal = CStr(PoslednjaSerijaObracuna)
    retVal = DoChLeft(retVal, 3, "0")
    NovaSerijaObracuna = retVal
End Function
