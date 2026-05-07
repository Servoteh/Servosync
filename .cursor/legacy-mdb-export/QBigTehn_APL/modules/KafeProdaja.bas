Attribute VB_Name = "KafeProdaja"
Option Compare Database
Option Explicit

Public Function UpisiURacunProdaju(IDArtikal As Long, KolicinaZaProdaju As Double, ProdDinCena As Currency, PDVTarifa As String) As Boolean
Dim rs As Object
Dim OK As Boolean
OK = True
    If Nz(IDArtikal, 0) = 0 Then
       OK = False
       MsgBox "Morate odrediti artikal.", vbExclamation, "Tehnologija"
    ElseIf Not IsNumeric(KolicinaZaProdaju) Or Nz(KolicinaZaProdaju, 0) = 0 Then
        OK = False
       MsgBox "Morate uneti kolicinu.", vbExclamation, "Tehnologija"
    ElseIf Nz(ProdDinCena, 0) = 0 Then
       OK = False
       MsgBox "Nekorektna prodajna cena.", vbExclamation, "Tehnologija"
    End If
    
If OK And IsLoaded("Racun") Then
    If Forms![Racun]![Racun - Podforma].[Form].AllowAdditions Or Forms![Racun]![Racun - Podforma].[Form].AllowEdits Then
    
        Forms![Racun]![Racun - Podforma].Form![IDArtikal] = IDArtikal
        Forms![Racun]![Racun - Podforma].Form![Kolicina] = Nz(KolicinaZaProdaju, 0)
        Forms![Racun]![Racun - Podforma].Form![DinCena] = Nz(ProdDinCena, 0)
        Forms![Racun]![Racun - Podforma].Form![Tarifa] = PDVTarifa
    
        'DoCmd.Close
        BBOpenForm "Racun"
        DoCmd.GoToControl "Racun - Podforma"
        On Error Resume Next
        DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70
     
        Set rs = Forms![Racun]![Racun - Podforma].RecordsetClone
    
        Forms![Racun]![Racun - Podforma].Requery
        If Not rs.EOF Then Forms![Racun]![Racun - Podforma].Bookmark = rs.Bookmark
        DoCmd.GoToRecord , , A_NEWREC
        'Forms![Racun]![Racun - Podforma].GoToRecord , , A_NEWREC
        OK = True
    Else
        MsgBox "Racun je zakljucan!", vbCritical, "Tehnologija"
        OK = False
    End If
End If
    UpisiURacunProdaju = OK
End Function
Public Function UpisiUNRacunProdaju(IDArtikal As Long, KolicinaZaProdaju As Double, ProdDinCena As Currency, PDVTarifa As String) As Boolean
Dim rs As Object
Dim OK As Boolean
OK = True
    If Nz(IDArtikal, 0) = 0 Then
       OK = False
       MsgBox "Morate odrediti artikal.", vbExclamation, "Tehnologija"
    ElseIf Not IsNumeric(KolicinaZaProdaju) Or Nz(KolicinaZaProdaju, 0) = 0 Then
        OK = False
       MsgBox "Morate uneti kolicinu.", vbExclamation, "Tehnologija"
    ElseIf Nz(ProdDinCena, 0) = 0 Then
       OK = False
       MsgBox "Nekorektna prodajna cena.", vbExclamation, "Tehnologija"
    End If
    
If OK And IsLoaded("NRacun") Then
    If Forms![NRacun]![NRacunPodforma].[Form].AllowAdditions Or Forms![NRacun]![NRacunPodforma].[Form].AllowEdits Then
    
        Forms![NRacun]![NRacunPodforma].Form![IDArtikal] = IDArtikal
        Forms![NRacun]![NRacunPodforma].Form![Kolicina] = Nz(KolicinaZaProdaju, 0)
        Forms![NRacun]![NRacunPodforma].Form![DinCena] = Nz(ProdDinCena, 0)
        Forms![NRacun]![NRacunPodforma].Form![Tarifa] = PDVTarifa
    
        'DoCmd.Close
        BBOpenForm "NRacun"
        DoCmd.GoToControl "NRacunPodforma"
        On Error Resume Next
        DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70
     
        Set rs = Forms![NRacun]![NRacunPodforma].RecordsetClone
    
        Forms![NRacun]![NRacunPodforma].Requery
        If Not rs.EOF Then Forms![NRacun]![NRacunPodforma].Bookmark = rs.Bookmark
        DoCmd.GoToRecord , , A_NEWREC
        'Forms![Racun]![Racun - Podforma].GoToRecord , , A_NEWREC
        OK = True
    Else
        MsgBox "Raèun je zakljucan!", vbCritical, "Tehnologija"
        OK = False
    End If
End If
    UpisiUNRacunProdaju = OK
End Function

'---------------
Public Function UpisiProdaju(IDArtikal As Long, KolicinaZaProdaju As Double, ProdDinCena As Currency, PDVTarifa As String) As Boolean
Dim rs As Object
Dim OK As Boolean
OK = True
    If Nz(IDArtikal, 0) = 0 Then
       OK = False
       MsgBox "Morate odrediti artikal.", vbExclamation, "Tehnologija"
    ElseIf Not IsNumeric(KolicinaZaProdaju) Or Nz(KolicinaZaProdaju, 0) = 0 Then
        OK = False
       MsgBox "Morate uneti kolicinu.", vbExclamation, "Tehnologija"
    ElseIf Nz(ProdDinCena, 0) = 0 Then
       OK = False
       MsgBox "Nekorektna prodajna cena.", vbExclamation, "Tehnologija"
    End If
    
If OK And IsLoaded("PrvaMaskaKonobar") Then
    If Forms![PrvaMaskaKonobar]![Podforma].[Form].AllowAdditions And Forms![PrvaMaskaKonobar]![Podforma].[Form].AllowEdits Then
    
        Forms![PrvaMaskaKonobar]![Podforma].Form![Sifra artikla] = IDArtikal
        Forms![PrvaMaskaKonobar]![Podforma].Form![Kolicina] = Nz(KolicinaZaProdaju, 0)
        Forms![PrvaMaskaKonobar]![Podforma].Form![KalkulativnaMPCena] = Nz(ProdDinCena, 0)
        Forms![PrvaMaskaKonobar]![Podforma].Form![StvarnaMPCena] = Nz(ProdDinCena, 0)
        Forms![PrvaMaskaKonobar]![Podforma].Form![TarifaRoba] = PDVTarifa
    
        'DoCmd.Close
        BBOpenForm "PrvaMaskaKonobar"
        DoCmd.GoToControl "Podforma"
        On Error Resume Next
        DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70
     
        Set rs = Forms![PrvaMaskaKonobar]![Podforma].RecordsetClone
    
        Forms![PrvaMaskaKonobar]![Podforma].Requery
        If Not rs.EOF Then Forms![PrvaMaskaKonobar]![Podforma].Bookmark = rs.Bookmark
        DoCmd.GoToRecord , , A_NEWREC
        'Forms![Racun]![Racun - Podforma].GoToRecord , , A_NEWREC
        OK = True
    Else
        MsgBox "Nije dozvoljen unos!", vbCritical, "Tehnologija"
        OK = False
    End If
End If
    UpisiProdaju = OK
End Function
Public Function PTUpisiProdaju(IDArtikal As Long, KolicinaZaProdaju As Double, ProdDinCena As Currency, PDVTarifa As String) As Boolean
Dim rs As Object
Dim OK As Boolean
OK = True
    If Nz(IDArtikal, 0) = 0 Then
       OK = False
       MsgBox "Morate odrediti artikal.", vbExclamation, "Tehnologija"
    ElseIf Not IsNumeric(KolicinaZaProdaju) Or Nz(KolicinaZaProdaju, 0) = 0 Then
        OK = False
       MsgBox "Morate uneti kolicinu.", vbExclamation, "Tehnologija"
    ElseIf Nz(ProdDinCena, 0) = 0 Then
       OK = False
       MsgBox "Nekorektna prodajna cena.", vbExclamation, "Tehnologija"
    End If
    
If OK And IsLoaded("PTKonobar") Then
    If Forms![PTKonobar]![Podforma].[Form].AllowAdditions And Forms![PTKonobar]![Podforma].[Form].AllowEdits Then
    
        Forms![PTKonobar]![Podforma].Form![Sifra artikla] = IDArtikal
        Forms![PTKonobar]![Podforma].Form![Kolicina] = Nz(KolicinaZaProdaju, 0)
        Forms![PTKonobar]![Podforma].Form![KalkulativnaMPCena] = Nz(ProdDinCena, 0)
        Forms![PTKonobar]![Podforma].Form![StvarnaMPCena] = Nz(ProdDinCena, 0)
        Forms![PTKonobar]![Podforma].Form![TarifaRoba] = PDVTarifa
    
        'DoCmd.Close
        BBOpenForm "PTKonobar"
        DoCmd.GoToControl "Podforma"
        On Error Resume Next
        DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70
     
        Set rs = Forms![PTKonobar]![Podforma].RecordsetClone
    
        Forms![PTKonobar]![Podforma].Requery
        If Not rs.EOF Then Forms![PTKonobar]![Podforma].Bookmark = rs.Bookmark
        DoCmd.GoToRecord , , A_NEWREC
        'Forms![Racun]![Racun - Podforma].GoToRecord , , A_NEWREC
        OK = True
    Else
        MsgBox "Nije dozvoljen unos!", vbCritical, "Tehnologija"
        OK = False
    End If
End If
    PTUpisiProdaju = OK
End Function

Public Function UpisiMPProdaju(IDArtikal As Long, CenovnikVrstaDok As String, KolicinaZaProdaju As Double) As Boolean
Dim rs As Object

 Dim RetValMPCena As Currency
 Dim RetValKLMPCena As Currency
 Dim RetValTarifaRobe As String
 Dim RetValTaksa As Currency
 Dim KupacRabat As Currency



Dim OK As Boolean
OK = True
    If Nz(IDArtikal, 0) = 0 Then
       OK = False
       MsgBox "Morate odrediti artikal.", vbExclamation, "QMegaTeh"
    ElseIf Not IsNumeric(KolicinaZaProdaju) Or Nz(KolicinaZaProdaju, 0) = 0 Then
        OK = False
       MsgBox "Morate uneti kolièinu.", vbExclamation, "QMegaTeh"
    End If
    
   ' ElseIf Nz(ProdDinCena, 0) = 0 Then
   '    Ok = False
   '    MsgBox "Nekorektna prodajna cena.", vbExclamation, "QMegaTeh"
   ' End If
    
If OK And IsLoaded("MPRacun") Then
    If Not CBool(Forms![MPRacun]!StampanFiskalno) And Forms![MPRacun]![MPRacun-Podforma].[Form].AllowAdditions And Forms![MPRacun]![MPRacun-Podforma].[Form].AllowEdits Then
        
        KupacRabat = CCur(Nz(Forms![MPRacun]![KupacRabat], 0))
        Call OdrediCenuZaKasaBlok_OLD(CenovnikVrstaDok, IDArtikal, KupacRabat, RetValMPCena, RetValKLMPCena, RetValTarifaRobe, RetValTaksa)
        
        If Nz(RetValMPCena, 0) <= 0 Then
            OK = False
            MsgBox "Nekorektna prodajna cena.", vbExclamation, "QMegaTeh"
            UpisiMPProdaju = OK
            Exit Function
        End If
        
        If BBCFG.Kasa_NeMenjajArtikal And _
            (Nz(Forms![MPRacun]![MPRacun-Podforma].Form![Sifra artikla], 0) > 0) And _
            (Nz(Forms![MPRacun]![MPRacun-Podforma].Form![Sifra artikla], 0) <> IDArtikal) Then
                OK = False
                MsgBox "Ne može se menjati artikal koji je otkucan!", vbExclamation, "QMegaTeh"
                UpisiMPProdaju = OK
                Exit Function
        End If
        
        If (Nz(Forms![MPRacun]![MPRacun-Podforma].Form![Kolicina], 0) > Nz(KolicinaZaProdaju, 0)) And BBCFG.Kasa_NeManjaKolicina Then
            OK = False
            MsgBox "Nova kolièina može da bude samo veæa od prethodne!", vbExclamation, "QMegaTeh"
            UpisiMPProdaju = OK
            Exit Function
        End If
        
        
        
        Forms![MPRacun]![MPRacun-Podforma].Form![Sifra artikla] = IDArtikal
        Forms![MPRacun]![MPRacun-Podforma].Form![Kolicina] = Nz(KolicinaZaProdaju, 0)
        Forms![MPRacun]![MPRacun-Podforma].Form![KalkulativnaMPCena] = RetValKLMPCena
        Forms![MPRacun]![MPRacun-Podforma].Form![StvarnaMPCena] = RetValMPCena
        Forms![MPRacun]![MPRacun-Podforma].Form![TarifaRoba] = RetValTarifaRobe
        
        'DoCmd.Close
       ' BBDebug.DebugPrintTimer "START BBOpenForm MPRacun"
        '!!!!!BBOpenForm "MPRacun" 'NEMOJ DA KORISTIS BBOpenForm jer je jako spora!!!
        DoCmd.OpenForm "MPRacun"
        DoCmd.GoToControl "MPRacun-Podforma"
        On Error Resume Next
        DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70
     
        Set rs = Forms![MPRacun]![MPRacun-Podforma].RecordsetClone
        'BBDebug.DebugPrintTimer "START Forms![MPRacun]![MPRacun-Podforma].Requery"
        Forms![MPRacun]![MPRacun-Podforma].Requery
        If Not rs.EOF Then Forms![MPRacun]![MPRacun-Podforma].Bookmark = rs.Bookmark
        DoCmd.GoToRecord , , A_NEWREC
        'Forms![Racun]![Racun - Podforma].GoToRecord , , A_NEWREC
        OK = True
        'BBDebug.DebugPrintTimer "END BBOpenForm MPRacun"
    Else
        MsgBox "Nije dozvoljen unos!", vbCritical, "QMegaTeh"
        OK = False
    End If
End If
    UpisiMPProdaju = OK
End Function
Public Function UpisiMPProdaju_13092017(IDArtikal As Long, KolicinaZaProdaju As Double, ProdDinCena As Currency, PDVTarifa As String) As Boolean
Dim rs As Object
Dim OK As Boolean
OK = True
    If Nz(IDArtikal, 0) = 0 Then
       OK = False
       MsgBox "Morate odrediti artikal.", vbExclamation, "Tehnologija"
    ElseIf Not IsNumeric(KolicinaZaProdaju) Or Nz(KolicinaZaProdaju, 0) = 0 Then
        OK = False
       MsgBox "Morate uneti kolièinu.", vbExclamation, "Tehnologija"
    ElseIf Nz(ProdDinCena, 0) = 0 Then
       OK = False
       MsgBox "Nekorektna prodajna cena.", vbExclamation, "Tehnologija"
    End If
    
If OK And IsLoaded("MPRacun") Then
    If Not CBool(Forms![MPRacun]!StampanFiskalno) And Forms![MPRacun]![MPRacun-Podforma].[Form].AllowAdditions And Forms![MPRacun]![MPRacun-Podforma].[Form].AllowEdits Then
    
        Forms![MPRacun]![MPRacun-Podforma].Form![Sifra artikla] = IDArtikal
        Forms![MPRacun]![MPRacun-Podforma].Form![Kolicina] = Nz(KolicinaZaProdaju, 0)
        Forms![MPRacun]![MPRacun-Podforma].Form![KalkulativnaMPCena] = Nz(ProdDinCena, 0)
        Forms![MPRacun]![MPRacun-Podforma].Form![StvarnaMPCena] = Nz(ProdDinCena, 0)
        Forms![MPRacun]![MPRacun-Podforma].Form![TarifaRoba] = PDVTarifa
        
        'DoCmd.Close
       ' BBDebug.DebugPrintTimer "START BBOpenForm MPRacun"
        '!!!!!BBOpenForm "MPRacun" 'NEMOJ DA KORISTIS BBOpenForm jer je jako spora!!!
        DoCmd.OpenForm "MPRacun"
        DoCmd.GoToControl "MPRacun-Podforma"
        On Error Resume Next
        DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70
     
        Set rs = Forms![MPRacun]![MPRacun-Podforma].RecordsetClone
        'BBDebug.DebugPrintTimer "START Forms![MPRacun]![MPRacun-Podforma].Requery"
        Forms![MPRacun]![MPRacun-Podforma].Requery
        If Not rs.EOF Then Forms![MPRacun]![MPRacun-Podforma].Bookmark = rs.Bookmark
        DoCmd.GoToRecord , , A_NEWREC
        'Forms![Racun]![Racun - Podforma].GoToRecord , , A_NEWREC
        OK = True
        'BBDebug.DebugPrintTimer "END BBOpenForm MPRacun"
    Else
        MsgBox "Nije dozvoljen unos!", vbCritical, "Tehnologija"
        OK = False
    End If
End If
    UpisiMPProdaju_13092017 = OK
End Function
Public Function BrojStavkiNaRacunu(IDDok As Long, IDProdavnica As Long, IDKasa As Long) As Long
    BrojStavkiNaRacunu = DCount("*", "T_MPStavke", "[IDDok] = " & IDDok & " and [IDProdavnice] = " & IDProdavnica & " and [IDKasa] = " & IDKasa)
End Function

Public Function BrojStolaZaKarticu(Kartica As String) As Long
    BrojStolaZaKarticu = CLng(Nz(DLookup("Broj", "BrojStolaTuraKartica", "[BrojKartice]= '" & Kartica & "'"), -1))
End Function
Public Function ArtikalNaAkciji(IDArtikal As Long) As Boolean
  Dim retVal As Boolean
    retVal = CLng(Nz(DLookup("[IDArtikal]", "ArtikliNaAkciji", "[IDArtikal] = " & IDArtikal), 0)) = IDArtikal
    ArtikalNaAkciji = retVal
End Function
