Attribute VB_Name = "Virmani"
Option Compare Database
Option Explicit

Public Sub KreirajVirman(IDDokIzRobnog As Long, IznosZaUplatu As Currency, IDDobavljac As Long, Opis As String, BrojDokumenta As String, DatumValute As Date)
On Error GoTo Err_Point

Dim stFormaSaPodacima As String

 If Not IsNumeric(IDDokIzRobnog) Then
  BBMsgBox_BigBit "Ne može se kreirati nalog za prenos!"
  Exit Sub
 End If
 
 If IDDokIzRobnog <> 0 Then
    If DCount("*", "Virmani", "IDDokIzRobnog = " & IDDokIzRobnog) > 0 Then
     If BBPitanje("Po ovom dokumentu je vec kreiran nalog za prenos." & vbCrLf & vbCrLf & "Da li želite da ga prikažem?") Then
      BBOpenForm "UnosVirmana", , , "IDDokIzRobnog = " & IDDokIzRobnog
     End If
     Exit Sub
    End If
 End If
 
 If IznosZaUplatu < 0 Then
  BBMsgBox_BigBit "Negativan iznos!"
  Exit Sub
 End If
 
 BBOpenForm "UnosVirmana"
 
 If Not IsLoaded("UnosVirmana") Then
  BBMsgBox_BigBit "Ne može se kreirati nalog za prenos!"
  Exit Sub
 End If
 
 
 DoCmd.GoToRecord , , acNewRec
On Error Resume Next
    DoCmd.GoToControl ("ComboNaTeret")
    Forms!UnosVirmana!ComboNaTeret = BBCFG.MaticnaSifra
    Forms!UnosVirmana![Virmani.Mesto] = Forms!UnosVirmana![NaTeretMesto]
    Forms!UnosVirmana!NaTeretZiroRacun = IIf(Nz(Forms!UnosVirmana!ComboNaTeret.Column(2), "") = "", Null, Forms!UnosVirmana!ComboNaTeret.Column(2))
    Forms!UnosVirmana!SvrhaDoznake = "UPLATA ZA ROBU"
    Forms!UnosVirmana!ComboUKorist = Forms![Ulazna faktura]![Sifra komitenta]
    
    Forms!UnosVirmana!UKoristZiroRacun = IIf(Nz(Forms!UnosVirmana!ComboUKorist.Column(2), "") = "", Null, Forms!UnosVirmana!ComboUKorist.Column(2))
    Forms!UnosVirmana!Iznos = IznosZaUplatu
    Forms!UnosVirmana!SifraPlacanja = "221"
    Forms!UnosVirmana!PNBOdobModel = "99"
    If BBCFG.UFKLStampaOkreni Then
     Forms!UnosVirmana!PNBOdobBroj = Opis
    Else
     Forms!UnosVirmana!PNBOdobBroj = BrojDokumenta
    End If
    Forms!UnosVirmana!DPO = DatumValute
    Forms!UnosVirmana!IDDokIzRobnog = IDDokIzRobnog
     DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70
    Forms!UnosVirmana!Iznos.SetFocus
    
Exit_Point:

Exit Sub

Err_Point:
 BBErrorMSG err, "KreirajVirman"
 Resume Exit_Point
End Sub
