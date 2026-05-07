Attribute VB_Name = "Nivelacija"
Option Compare Database   'Use database order for string comparisons
Option Explicit

Sub OdrediNeproknjizeneNivelacijeZaliha(IDDokZaNiv As Long)
On Error GoTo GreskaNivZal

    Dim BigBit As DAO.Database
    Dim QZaNiv As DAO.Recordset
    Dim StavkeNiv As DAO.Recordset

    Dim SifArt As Long
    Dim KalkVP As Double
    Dim StanjeKOlicine As Double
    Dim VrednostNivelacije As Double
    Dim BrojStavki As Long

    Set BigBit = CurrentDb
    Set QZaNiv = BigBit.OpenRecordset("QZaNeproknjizeneNivelacije", DB_OPEN_DYNASET, dbSeeChanges)
    Set StavkeNiv = BigBit.OpenRecordset("Stavke nivelacije", DB_OPEN_DYNASET, dbSeeChanges)
    
QZaNiv.MoveFirst                                      ' Pozicioniraj se na prvi rekord
SifArt = QZaNiv![Sifra artikla]
KalkVP = QZaNiv![Kalkulativna VP cena]

StanjeKOlicine = 0#
VrednostNivelacije = 0#
BrojStavki = 0

Do Until QZaNiv.EOF                                   ' Pocetak petlje
   If (SifArt = QZaNiv![Sifra artikla]) Then
      If QZaNiv![Ulaz] Then
         If (StanjeKOlicine > 0#) And (KalkVP <> QZaNiv![Kalkulativna VP cena]) Then

               StavkeNiv.AddNew
               
               StavkeNiv![IDDok] = IDDokZaNiv
               StavkeNiv![Sifra artikla] = QZaNiv![Sifra artikla]
               StavkeNiv![Kolicina] = StanjeKOlicine

               StavkeNiv![Nova nabavna cena - neto] = QZaNiv![Nabavna cena - neto]
               StavkeNiv![Novi zavisni trosak - dobavljac] = QZaNiv![Zavisni trosak - dobavljac]
               StavkeNiv![Novi zavisni trosak - sopstveni] = QZaNiv![Zavisni trosak - sopstveni]
               StavkeNiv![Nova VP cena] = QZaNiv![Kalkulativna VP cena]
               StavkeNiv![Nova MP cena] = QZaNiv![Kalkulativna MP cena]
               StavkeNiv![Nova taksa] = QZaNiv![TAKSA]
               StavkeNiv![Nova tarifa - roba] = QZaNiv![Tarifa - roba - Izlaz]
               StavkeNiv![Nova tarifa - usluge] = QZaNiv![Tarifa - usluge - izlaz]

               StavkeNiv![Stara nabavna cena - neto] = StavkeNiv![Nova nabavna cena - neto]
               StavkeNiv![Stari zavisni trosak - dobavljac] = StavkeNiv![Novi zavisni trosak - dobavljac]
               StavkeNiv![Stari zavisni trosak - sopstveni] = StavkeNiv![Novi zavisni trosak - sopstveni]
               StavkeNiv![Stara VP cena] = KalkVP
               StavkeNiv![Stara MP cena] = StavkeNiv![Nova MP cena]
               StavkeNiv![Stara taksa] = StavkeNiv![Nova taksa]
               StavkeNiv![Stara tarifa - roba] = StavkeNiv![Nova tarifa - roba]
               StavkeNiv![Stara tarifa - usluge] = StavkeNiv![Nova tarifa - usluge]

               StavkeNiv.Update

               Rem Debug.Print "Artikal  " & QZaNiv![Sifra artikla] & " dok: " & QZaNiv![Broj dokumenta] & "  Stara cena:   " & KalkVP & " Nova cena: " & QZaNiv![Kalkulativna VP cena] & " UkKolicina: " & StanjeKolicine
               Rem VrednostNivelacije = VrednostNivelacije + StanjeKolicine * (QZaNiv![Kalkulativna VP cena] - KalkVP)
               Rem BrojStavki = BrojStavki + 1

         End If
         KalkVP = QZaNiv![Kalkulativna VP cena]
         StanjeKOlicine = StanjeKOlicine + QZaNiv![UkKolicina]
      Else
         StanjeKOlicine = StanjeKOlicine - QZaNiv![UkKolicina]
      End If
   Else
    
    SifArt = QZaNiv![Sifra artikla]
    KalkVP = QZaNiv![Kalkulativna VP cena]
    StanjeKOlicine = IIf(QZaNiv![Ulaz], QZaNiv![UkKolicina], -QZaNiv![UkKolicina])

   End If
    QZaNiv.MoveNext                                   ' Pozicioniraj se na sledeci rekord
    Rem Debug.Print SifArt
Loop                                                    ' Kraj petlje

Set QZaNiv = Nothing
Set StavkeNiv = Nothing
Set BigBit = Nothing

'Debug.Print " Vrednost nivelacije: " & VrednostNivelacije
'Debug.Print " Ukupno stavki nivelacije: ", BrojStavki

Exit Sub

GreskaNivZal:
 MsgBox Error$
 Resume Next

End Sub

Sub RasknjiziNivelacijuX()
On Error GoTo GreskaNiv

    Dim BigBit As DAO.Database
    Dim TabPod As DAO.Recordset
    Dim TabNiv As DAO.Recordset

    Set BigBit = CurrentDb
    Set TabNiv = BigBit.OpenRecordset("Stavke nivelacije", DB_OPEN_DYNASET, dbSeeChanges)
    Set TabPod = BigBit.OpenRecordset("Robne stavke", DB_OPEN_DYNASET, dbSeeChanges)
    
TabNiv.MoveFirst                                      ' Pozicioniraj se na prvi rekord

Do Until TabNiv.EOF                                   ' Pocetak petlje

    If Abs(TabNiv![Stara VP cena] - TabNiv![Nova VP cena]) >= 0.01 Then

           TabPod.AddNew                                'Dodaj rekord
           TabPod![IDDok] = TabNiv![IDDok]
           
           TabPod.Update                              'Sacuvaj izmene

    End If
    TabNiv.MoveNext                                   ' Pozicioniraj se na sledeci rekord
Loop                                                  ' Kraj petlje

Set TabPod = Nothing
Set TabNiv = Nothing
Set BigBit = Nothing

Exit Sub

GreskaNiv:
 MsgBox Error$
 Resume Next
    
End Sub

 Sub MPPripremiStavkeZaNivelaciju()
On Error GoTo Err_PripremiNivelaciju

    Dim DocName As String
    If IsNull(Forms![MPNivelacija]![IDDok]) Then
       MsgBox "Morate zadati zaglavlje nivelacije!"
       GoTo Exit_PripremiNivelaciju
    End If
    DoCmd.SetWarnings False
    DocName = "MPPripremiStavkeZaNivelaciju"
    DoCmd.OpenQuery DocName, A_NORMAL, A_EDIT
    DoCmd.Close
    ' Me![MPNivelacija - Podforma].Requery
    Forms![MPNivelacija]![MPNivelacija - Podforma].Requery
    
Exit_PripremiNivelaciju:
    DoCmd.SetWarnings True
    Exit Sub

Err_PripremiNivelaciju:
    MsgBox Error$
    Resume Exit_PripremiNivelaciju
    
End Sub
 Sub MPPripremiStavkeZaNivelacijuSvihArt()
On Error GoTo Err_PripremiNivelacijuSvih

    Dim DocName As String
    If IsNull(Forms![MPNivelacija]![IDDok]) Then
       MsgBox "Morate zadati zaglavlje nivelacije!"
       GoTo Exit_PripremiNivelacijuSvih
    End If
    DoCmd.SetWarnings False
    DocName = "MPPripremiStavkeZaNivelacijuSvihArt"
    DoCmd.OpenQuery DocName, A_NORMAL, A_EDIT
    DoCmd.Close
    ' Me![MPNivelacija - Podforma].Requery
    Forms![MPNivelacija]![MPNivelacija - Podforma].Requery
    
Exit_PripremiNivelacijuSvih:
    DoCmd.SetWarnings True
    Exit Sub

Err_PripremiNivelacijuSvih:
    MsgBox Error$
    Resume Exit_PripremiNivelacijuSvih
    
End Sub

