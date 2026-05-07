Attribute VB_Name = "BiranjeArtikla"
Option Compare Database
Option Explicit

Public IzabraniArtikal As Long
Public Function imeKontroleCijiJeControlSource(ByRef frm As Form, ByVal stControlSource) As Variant
'Modifikovano: 09-01-2022
On Error GoTo Err_Point
  Dim ctl As control
  Dim retVal As Variant
  
 retVal = Null
 If frm Is Nothing Then
   retVal = Null
   GoTo Exit_Point
 End If
 
 For Each ctl In frm.Controls
      If ctl.Properties("ControlType") = acTextBox Or _
         ctl.Properties("ControlType") = acComboBox Or _
         ctl.Properties("ControlType") = acListBox Or _
         ctl.Properties("ControlType") = acCheckBox Then
        If ctl.Properties("ControlSource") = stControlSource Then
           retVal = ctl.Name
           Exit For
        End If
      End If
  Next
Exit_Point:
  On Error Resume Next
  imeKontroleCijiJeControlSource = retVal
Exit Function
Err_Point:
 BBErrorMSG err, "imeKontroleCijiJeControlSource"
 Resume Exit_Point
End Function
Public Function NadjiArtikal(Optional IDArt, Optional stFindControlName)
On Error GoTo Err_Point

 Dim pVisibleSifraArtikla As Boolean
 Dim pIDArt As Long
 Dim pFindControlName As String
 Dim pForm As Form
 Dim pCtl As control
    
    Set pCtl = Screen.ActiveControl
    Set pForm = Screen.ActiveControl.Parent
    
    If IsMissing(stFindControlName) Then
     pFindControlName = "Sifra artikla"
    Else
     pFindControlName = stR(stFindControlName)
    End If
    
    If IsMissing(IDArt) Then
      pIDArt = pCtl.Value ' CLng(Screen.ActiveControl.Value)
    Else
       pIDArt = CLng(IDArt)
    End If
    
    pVisibleSifraArtikla = pForm.Controls(pFindControlName).Visible 'pVisibleSifraArtikla = Me![Sifra artikla].Visible
    pForm.Controls(pFindControlName).Visible = True 'Me![Sifra artikla].Visible = True
    pForm.Controls(pFindControlName).SetFocus 'DoCmd.GoToControl "Sifra artikla"
    DoCmd.FindRecord pIDArt
    pCtl.SetFocus 'DoCmd.GoToControl "NadjiKatBroj"
    pCtl.Value = Null ' Me!NadjiKatBroj = Null
    pForm.Controls(pFindControlName).Visible = pVisibleSifraArtikla 'Me![Sifra artikla].Visible = pVisibleSifraArtikla
    
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
   
   BBErrorMSG err, "NadjiArtikal"
   Resume Exit_Point
   
End Function

Public Function NadjiArtikal_NERADIDOBRO(Optional ByVal IDArt As Variant, Optional ZadrziFokus As Boolean = True) 'Ovo ne može ?!, Optional ByRef InRecordset As Object)
On Error GoTo err_Func
  ' Pronadji artikal na aktivnoj formi
    Dim rstClone As Object
    Dim rst As Object
    Dim ctl As control
    Dim frm As Form
    Dim tmpIDArt
    
    Set ctl = Screen.ActiveControl
    Set frm = Screen.ActiveForm
    
    If IsMissing(IDArt) Then
      tmpIDArt = ctl.Value
    Else
       tmpIDArt = IDArt
    End If
    
   ' If IsMissing(InRecordset) Or IsEmpty(InRecordset) Then
   '   Set rst = Screen.ActiveForm.Recordset
   ' Else
   '   Set rst = InRecordset
   ' End If
   
    'Set rst = Screen.ActiveForm.Recordset
    Set rst = ctl.Parent.Recordset
    Set rstClone = rst.Clone
    
    
    
    If TypeOf rstClone Is ADODB.Recordset Then
     rstClone.Find "[Sifra artikla] = " & stR(Nz(tmpIDArt, 0))
    Else
     rstClone.FindFirst "[Sifra artikla] = " & stR(Nz(tmpIDArt, 0))
    End If
    
    If Not rstClone.EOF Then
        'rst.Bookmark = rstClone.Bookmark
        frm.Bookmark = rstClone.Bookmark
      If stR(rst![Sifra artikla]) <> stR(tmpIDArt) Then
        Beep
      End If
    Else
      Beep
    End If
    If ZadrziFokus Then
         ctl.SetFocus
    End If
    ctl.Value = Null

exit_Func:
Exit Function
  
err_Func:
 BBErrorMSG err, "NadjiArtikal_NERADIDOBRO"
 Resume exit_Func:
End Function

Public Function DetaljnoArtikal(Optional ByVal IDArtikal)
'Modifikovano: 08-07-2020
On Error GoTo Err_DetaljnoArtikal

    Dim DocName As String
    Dim LinkCriteria As String
    Dim ZaIDArtikal
    
 '   CheckRSType
    
    If IsMissing(IDArtikal) Then
    On Error Resume Next
        ZaIDArtikal = Screen.ActiveForm.Controls("Sifra artikla").Value 'Screen.ActiveForm.Recordset("Sifra artikla")
        If err Then
           err.Clear
           ZaIDArtikal = Screen.ActiveForm.Controls("IDArtikal").Value 'Screen.ActiveForm.Recordset("Sifra artikla")
           If err Then
              GoTo Err_DetaljnoArtikal
           End If
        End If
     'ZaIDArtikal = IDArtikalSaAktivneForme()
    Else
     ZaIDArtikal = IDArtikal
    End If
    
    If IsNumeric(ZaIDArtikal) And Not IsEmpty(ZaIDArtikal) Then
        DocName = "Unos artikala"
        LinkCriteria = "[Sifra artikla] = " & ZaIDArtikal
        BBOpenForm DocName, , , LinkCriteria
    Else
     Beep
    End If

Exit_DetaljnoArtikal:
    Exit Function

Err_DetaljnoArtikal:
    BBErrorMSG err, "DetaljnoArtikal"
    Resume Exit_DetaljnoArtikal
    
End Function
Public Function VPKarticaArtikla(Optional ByVal IDArtikal, Optional IDMagacin)
   Call KarticaArtikla(IDArtikal, IDMagacin)
End Function
Public Function KarticaArtikla(Optional ByVal IDArtikal, Optional IDMagacin, Optional Profakture As Boolean = False, Optional ZaRezervacije = Null)
'Modifikovano: 02-09-2020 Uvedena nova forma VPKarticaArtikla i podforma VPKarticaArtikla_Podforma
On Error GoTo Err_KarticaArtikla

    Dim DocName As String
    Dim LinkCriteria As String
    Dim ZaIDArtikal
    
    If IsMissing(IDArtikal) Then
     On Error Resume Next
     ZaIDArtikal = Screen.ActiveForm.Recordset("Sifra artikla")
     If err Then
      ZaIDArtikal = Screen.ActiveForm.Recordset("IDArtikal")
     End If
     On Error GoTo Err_KarticaArtikla
    Else
     ZaIDArtikal = IDArtikal
    End If
    
    If IsNumeric(ZaIDArtikal) And Not IsEmpty(ZaIDArtikal) Then
        'DocName = "Kartica artikla"
        DocName = "VPKarticaArtikla"
        LinkCriteria = "[Sifra artikla] = " & ZaIDArtikal
        BBOpenForm DocName, , , LinkCriteria
        If Not IsMissing(IDMagacin) Then
         If IsLoaded(DocName) Then
          Forms(DocName)!ComboZaMagacin = IDMagacin
          
          If CBool(Nz(Profakture, False)) Then
          
             Forms(DocName)!OdLevel = 250
             Forms(DocName)!DoLevel = 250
             Forms(DocName)!CheckKarticaProf = True
             Forms(DocName)!CheckZaRezervisi = ZaRezervacije
          End If
          
          Forms(DocName).PrimeniUslove
         
         End If
        End If
    Else
     Beep
    End If
 
Exit_KarticaArtikla:
    Exit Function

Err_KarticaArtikla:
    BBErrorMSG err, "KarticaArtikla"
    Resume Exit_KarticaArtikla
    
End Function
Public Function MPKarticaArtikla(Optional ByVal IDArtikal, Optional IDProdavnica)
On Error GoTo Err_KarticaArtikla

    Dim DocName As String
    Dim LinkCriteria As String
    Dim ZaIDArtikal
    
    If IsMissing(IDArtikal) Then
     On Error Resume Next
     ZaIDArtikal = Screen.ActiveForm.Recordset("Sifra artikla")
     On Error GoTo Err_KarticaArtikla
    Else
     ZaIDArtikal = IDArtikal
    End If
    
    If IsNumeric(ZaIDArtikal) Then
        DocName = "MPKarticaArtikla"
        LinkCriteria = "[Sifra artikla] = " & ZaIDArtikal
        BBOpenForm DocName, , , LinkCriteria
        If Not IsMissing(IDProdavnica) Then
         If IsLoaded(DocName) Then
          If IsNumeric(IDProdavnica) Then
            Forms(DocName)!ZaProdavnicu = IDProdavnica
            Forms(DocName).Requery
          End If
         End If
        End If
    Else
     Beep
    End If
 
Exit_KarticaArtikla:
    Exit Function

Err_KarticaArtikla:
    BBErrorMSG err, "KarticaArtikla"
    Resume Exit_KarticaArtikla
    
End Function
Public Function KomisionaKarticaArtikla(Optional ByVal IDArtikal, Optional IDKupac)
On Error GoTo Err_KomisionaKarticaArtikla

    Dim DocName As String
    Dim LinkCriteria As String
    Dim ZaIDArtikal
    
    If IsMissing(IDArtikal) Then
     On Error Resume Next
     ZaIDArtikal = Screen.ActiveForm.Recordset("Sifra artikla")
     On Error GoTo Err_KomisionaKarticaArtikla
    Else
     ZaIDArtikal = IDArtikal
    End If
    
    If IsNumeric(ZaIDArtikal) Then
        DocName = "KomisionKarticaArtikla"
        LinkCriteria = "[Sifra artikla] = " & ZaIDArtikal
        BBOpenForm DocName, , , LinkCriteria
        If Not IsMissing(IDKupac) Then
         If IsLoaded(DocName) Then
          Forms(DocName)!ZaKupca = IDKupac
          Forms(DocName).Requery
         End If
        End If
    Else
     Beep
    End If
 
Exit_KomisionaKarticaArtikla:
    Exit Function

Err_KomisionaKarticaArtikla:
    BBErrorMSG err, "KomisionaKarticaArtikla"
    Resume Exit_KomisionaKarticaArtikla
    
End Function
Public Function NormativArtikla(Optional ByVal IDArtikal)
On Error GoTo Err_NormativArtikla

    Dim DocName As String
    Dim LinkCriteria As String
    Dim ZaIDArtikal
    
    If IsMissing(IDArtikal) Then
     ZaIDArtikal = Screen.ActiveForm.Recordset("Sifra artikla")
    Else
     ZaIDArtikal = IDArtikal
    End If
    
    If IsNumeric(ZaIDArtikal) Then
        DocName = "Unos recepta"
        LinkCriteria = "[Sifra artikla] = " & ZaIDArtikal
        BBOpenForm DocName, , , LinkCriteria
    Else
     Beep
    End If
 
Exit_NormativArtikla:
    Exit Function

Err_NormativArtikla:
    BBErrorMSG err, "NormativArtikla"
    Resume Exit_NormativArtikla
    
End Function
Public Function RastavnicaArtikla(Optional ByVal IDArtikal)
On Error GoTo Err_RastavnicaArtikla

    Dim DocName As String
    Dim LinkCriteria As String
    Dim ZaIDArtikal
    
    If IsMissing(IDArtikal) Then
     ZaIDArtikal = Screen.ActiveForm.Recordset("Sifra artikla")
    Else
     ZaIDArtikal = IDArtikal
    End If
    
    If IsNumeric(ZaIDArtikal) Then
        DocName = "Rastavnice_Unos"
        LinkCriteria = "[Sifra artikla] = " & ZaIDArtikal
        BBOpenForm DocName, , , LinkCriteria
    Else
     Beep
    End If
 
Exit_RastavnicaArtikla:
    Exit Function

Err_RastavnicaArtikla:
    BBErrorMSG err, "RastavnicaArtikla"
    Resume Exit_RastavnicaArtikla
    
End Function
Public Function IzaberiArtikal(Optional ZaNaziv As String) As Long
On Error Resume Next
Dim stFormName As String
    stFormName = ReadCFGParametar("FORM.IzborArtikla")
    BBOpenForm stFormName
    Forms(stFormName)!ZaNaziv = ZaNaziv
    Forms(stFormName).Requery
    IzaberiArtikal = IzabraniArtikal
End Function

Public Sub NazivArtiklaNijeUListi(ByRef ComboArt As ComboBox, ByVal NewData As String, ByRef Response As Integer, Optional ByVal Cenovnik As String)
'Modifikovano: 05-12-2020 Postavlja ADO Recordset
'Modifikovano: 20-10-2023 NewData proverava i Kataloski broj
  Dim stSQL As String
    'Koristi se u OnNotInList kod izbora artikla
    
    If Nz(Cenovnik, "") = "" Then
      stSQL = ""
      stSQL = stSQL & "SELECT R_Artikli.[Sifra artikla], R_Artikli.[Naziv], R_Artikli.[Kataloski broj]"
      stSQL = stSQL & " FROM R_Artikli"
      stSQL = stSQL & " WHERE (((R_Artikli.Naziv) Like '%" & NewData & "%')) OR (((R_Artikli.[Kataloski broj]) Like '%" & NewData & "%'))"
      stSQL = stSQL & " ORDER BY R_Artikli.Naziv, R_Artikli.[Kataloski broj];"
      'ComboArt.RowSource = stSQL
      Set ComboArt.Recordset = ADO_GetRST(BBCFG.CNNString, stSQL, dbOptimistic, adUseClient, adOpenStatic, True)
      
      ComboArt.ColumnCount = 3
      ComboArt.BoundColumn = 1
      ComboArt.ColumnWidths = "0cm;15cm;3cm" ' "0cm;10cm;3cm"
      ComboArt.ColumnHeads = True
      ComboArt.ListWidth = 10206  '7371
    Else
      '***********************
        'Modifikovano: 05-12-2020
        stSQL = ""
        stSQL = stSQL & "SELECT R_Artikli.[Sifra artikla] AS IDArtikal, R_Artikli.Naziv, c.Cena, R_Artikli.[Tarifa robe] AS Tarifa"
        stSQL = stSQL & " FROM R_Artikli LEFT JOIN"
        stSQL = stSQL & " ("
        stSQL = stSQL & " SELECT Cenovnik.[Sifra artikla],Cenovnik.cena"
        stSQL = stSQL & " FROM Cenovnik"
        stSQL = stSQL & " WHERE  ((Cenovnik.[Vrsta dokumenta]) = '" & Cenovnik & "')"
        stSQL = stSQL & " ) as c"
        stSQL = stSQL & " ON R_Artikli.[Sifra artikla] = c.[Sifra artikla]"
        stSQL = stSQL & " WHERE ((R_Artikli.Naziv) Like '%" + NewData + "%')"
        stSQL = stSQL & " ORDER BY IIf([Grupa] Like 'SIR%','ZZ','') + [Naziv]"
      '***********************
      'ComboArt.RowSource = stSQL
      Set ComboArt.Recordset = ADO_GetRST(BBCFG.CNNString, stSQL, dbOptimistic, adUseClient, adOpenStatic, True)
      ComboArt.ColumnCount = 4
      ComboArt.BoundColumn = 1
      ComboArt.ColumnWidths = "0cm;15cm;3cm;0cm" '"0cm;10cm;3cm;0cm"
      ComboArt.ColumnHeads = True
      ComboArt.ListWidth = 10206  '7371
    End If
    
    'ComboArt.Value = Null
    Response = acDataErrContinue
End Sub
'****************************************
Public Function IDArtikalSaAktivneForme1V_NIJEOK()
On Error GoTo Err_Point

 Dim retIDArtikal
 
   
   retIDArtikal = Screen.ActiveForm.RecordsetClone("Sifra artikla")
   
Exit_Point:
   
   IDArtikalSaAktivneForme1V_NIJEOK = retIDArtikal

Exit Function

Err_Point:
    BBErrorMSG err, "SifraArtiklaSaAktivneForme1V"
    Resume Exit_Point
End Function
'****************************************
Public Function IDArtikalSaAktivneForme_NIJEOK()
On Error GoTo Err_Point

Dim IDArtikal
Dim pAktivnaForma As Object

    IDArtikal = Null
  On Error Resume Next
 
    Set pAktivnaForma = Screen.ActiveForm
            
            'Me.Bookmark = Me.RecordsetClone.Bookmark
            
           IDArtikal = pAktivnaForma.RecordsetClone("Sifra artikla")
           
           If err.Number <> 0 Then
            err.Clear
            IDArtikal = pAktivnaForma.Recordset("IDArtikal")
           End If
           
           If err.Number <> 0 Then
            err.Clear
            IDArtikal = pAktivnaForma.Recordset("Robne stavke.Sifra artikla")
           End If
           
           If err.Number <> 0 Then
            err.Clear
            IDArtikal = pAktivnaForma.Recordset("Profakture stavke.Sifra artikla")
           End If
  
 err.Clear
 

Exit_Point:
   IDArtikalSaAktivneForme1V_NIJEOK = IDArtikal
On Error Resume Next
 
Exit Function

Err_Point:
 BBErrorMSG err, "IDArtikalSaAktivneForme"
 On Error GoTo Exit_Point
 
End Function

Public Function ZadovoljenUslovZaObelezje(ByVal IDArtikal As Long, ByVal Obelezje As Variant, ByVal VrednostObelezja As Variant) As Boolean
 Dim retValOk As Boolean
 Dim VrednostUTabeli
 
 If Nz(Obelezje, "") = "" Then
    retValOk = True
 Else
    VrednostUTabeli = DLookup("[Vrednost]", "R_Artikli_Obelezja", "IDArtikal = " & IDArtikal)
    If IsNull(VrednostUTabeli) Then
      retValOk = False
    Else
     retValOk = CStr(VrednostUTabeli) Like ("*" & Nz(VrednostObelezja, "") & "*")
    End If
 End If
   
   ZadovoljenUslovZaObelezje = retValOk
End Function

Public Function UpisiUArtikal(ByVal IDArtikal As Long, ByVal NazivKolone As String, ByVal NovaVrednost As Variant) As Boolean
'Kreirano 10-12-2018
On Error GoTo Err_Point

    Dim retVal As Boolean
    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    
    Const TableName = "R_Artikli"
    
    Set db = CurrentDb
    If Not PostojiTabelaUBazi(TableName, db) Then
      err.Raise vbObjectError + 1, "QMegaTeh", "Ne postoji tabela " & TableName
    End If
    Set rs = db.OpenRecordset("SELECT * FROM " & TableName & " WHERE [Sifra artikla] = " & IDArtikal, dbOpenDynaset, dbSeeChanges)
    
    rs.FindFirst "[Sifra artikla] = " & IDArtikal

    If rs.NoMatch Then
       err.Raise vbObjectError + 1, "QMegaTeh", "Ne postoji artikal cija je Sifra = " & IDArtikal
    Else
        rs.Edit
        If rs(NazivKolone).Type = dbBoolean Then
            rs(NazivKolone) = CBool(NovaVrednost)
        Else
            rs(NazivKolone) = NovaVrednost
        End If
        rs.Update
        retVal = True
    End If
exit_err_Point:
On Error Resume Next
    rs.Close
    Set rs = Nothing
    Set db = Nothing
    UpisiUArtikal = retVal
Exit Function
Err_Point:
    retVal = False
    BBErrorMSG err, "UpisiUArtikal"
Resume exit_err_Point
End Function

Public Function BrojArtikalaSaKNG2Sifrom(ByVal KngSifra_2 As String) As Long
'Kreirano 31-11-2018
 BrojArtikalaSaKNG2Sifrom = DCount("*", "R_Artikli", "KNGSifra_2 = '" & KngSifra_2 & "'")
End Function
Public Function IDArtikalZaKatBroj(ByVal ZaKatBroj As String) As Variant
'Kreirano 31-11-2018
   IDArtikalZaKatBroj = DFirst("[Sifra artikla]", "R_Artikli", "[Kataloski broj] = '" & ZaKatBroj & "'")
End Function
Public Function KNG2SifraZaIDArtikal(ByVal IDArtikal As Long) As Variant
'Kreirano 04-12-2018
   KNG2SifraZaIDArtikal = DFirst("[KNGSifra_2]", "R_Artikli", "[Sifra artikla] = " & IDArtikal)
End Function
Public Function UpisiKNG2SifruUArtikal(ByVal KngSifra_2 As String, ByVal IDArtikal As Long) As Boolean
'Kreirano 16-10-2018
'Modifikovano: 26-11-2019 dodato  dbOpenDynaset, dbSeeChanges)
On Error GoTo Err_Point

    Dim retVal As Boolean
    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    
    Const TableName = "R_Artikli"
    
    Set db = CurrentDb
    If Not PostojiTabelaUBazi(TableName, db) Then
      err.Raise vbObjectError + 1, "QMegaTeh", "Ne postoji tabela " & TableName
    End If
    Set rs = db.OpenRecordset("SELECT * FROM " & TableName & " WHERE [Sifra artikla] = " & IDArtikal, dbOpenDynaset, dbSeeChanges)
    
    rs.FindFirst "[Sifra artikla] = " & IDArtikal

    If rs.NoMatch Then
       err.Raise vbObjectError + 1, "QMegaTeh", "Ne postoji artikal cija je Sifra = " & IDArtikal
    Else
        rs.Edit
        rs("KngSifra_2") = KngSifra_2
        rs.Update
        retVal = True
    End If
exit_err_Point:
On Error Resume Next
    rs.Close
    Set rs = Nothing
    Set db = Nothing
    UpisiKNG2SifruUArtikal = retVal
Exit Function
Err_Point:
    retVal = False
    BBErrorMSG err, "UpisiKNG2SifruUArtikal"
Resume exit_err_Point
End Function
Public Function PonistiZamenu(IDArtikal As Long) As Boolean
'Kreirano 04-12-2018
On Error GoTo Err_Point

  Dim retValOk As Boolean
  Dim KNG2Sifra As String
  
  retValOk = True
  KNG2Sifra = Nz(KNG2SifraZaIDArtikal(IDArtikal), "0")
  
  If KNG2Sifra = "0" Then
    GoTo Exit_Point
  End If
  
  If Format(IDArtikal, "0") = KNG2Sifra Then
   If BrojArtikalaSaKNG2Sifrom(KNG2Sifra) > 1 Then
    MsgBox "Ovaj artikal je primarni u zameni i ne može se poništiti.", vbExclamation, "QMegaTeh"
    retValOk = False
    GoTo Exit_Point
   End If
  End If
  If BBPitanje("Da li zaista poništavate zamenu?") Then
    retValOk = UpisiKNG2SifruUArtikal("0", IDArtikal)
    If Not retValOk Then
      BBMsgBox_BigBit "Ovaj artikal je ostao kao zamena!", , ColorConstants.vbRed
    End If
  End If
Exit_Point:
On Error Resume Next
   PonistiZamenu = retValOk
Exit Function
   
Err_Point:
  BBErrorMSG err, "PonistiZamenu"
  Resume Exit_Point
End Function
Public Function UpisiNovuUmestoStareKNG2Sifre(ByVal StaraKngSifra_2 As String, ByVal NovaKngSifra_2 As String) As Boolean
'Kreirano 04-12-2018
On Error GoTo Err_Point

    Dim retVal As Boolean
    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    
    Const TableName = "R_Artikli"
    retVal = True
    
    Set db = CurrentDb
    If Not PostojiTabelaUBazi(TableName, db) Then
      err.Raise vbObjectError + 1, "QMegaTeh", "Ne postoji tabela " & TableName
    End If
    Set rs = db.OpenRecordset("SELECT * FROM " & TableName & " WHERE [KNGSifra_2] = '" & StaraKngSifra_2 & "'")
    
    While Not rs.EOF
        rs.Edit
        rs("KngSifra_2") = NovaKngSifra_2
        rs.Update
        rs.MoveNext
    Wend
    
exit_err_Point:
On Error Resume Next
    rs.Close
    Set rs = Nothing
    Set db = Nothing
    UpisiNovuUmestoStareKNG2Sifre = retVal
Exit Function
Err_Point:
    retVal = False
    BBErrorMSG err, "UpisiNovuUmestoStareKNG2Sifre"
Resume exit_err_Point
End Function
Public Function CM_KarticaArtikla(IDArtikal As Variant)
On Error GoTo Err_Point

    Dim stDocName As String
    Dim stLinkCriteria As String
    
    If Not IsNumeric(IDArtikal) Then
       Exit Function
    End If
    
    stDocName = "CM_KarticaArtikla"
    
    stLinkCriteria = "[Sifra artikla]=" & stR(IDArtikal)
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_Point:
    Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
End Function
Public Function F_IDArtikalZaBarKod(ByVal BarKod As String) As Variant
On Error GoTo Err_Point
'Kreirano: 11-02-2021
Dim retVal As Variant

retVal = ADO_Lookup(BBCFG.CNNString, "[Sifra artikla]", "R_Artikli", "[Barkod]='" & BarKod & "'")
If Nz(retVal, -1) = -1 Then
    retVal = ADO_Lookup(BBCFG.CNNString, "[IDArtikal]", "R_Artikli_Barkod", "[Barkod]='" & BarKod & "'")
End If

Exit_Point:
 On Error Resume Next
       F_IDArtikalZaBarKod = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_IDArtikalZaBarKod"
 retVal = Null
 Resume Exit_Point
End Function
Public Function NAR_KarticaArtikla(IDArtikal As Variant)
On Error GoTo Err_Point

    Dim stDocName As String
    Dim stLinkCriteria As String
    
    If Not IsNumeric(IDArtikal) Then
       Exit Function
    End If
    
    stDocName = "NAR_KarticaArtikla"
    
    stLinkCriteria = "[Sifra artikla]=" & stR(IDArtikal)
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_Point:
    Exit Function

Err_Point:
    'MsgBox err.Description
    BBErrorMSG err, "NAR_KarticaArtikla"
    Resume Exit_Point
End Function
Public Function F_KutKol(Kolicina As Double, Kutija) As Integer
'Kreirano: 03-02-2022 (Magrem)

 Dim retVal As Integer
 Dim Koef As Double
 If Nz(Kutija, 0) = 0 Then
   Koef = 1
 ElseIf IsNumeric(Kutija) Then
   Koef = Abs(Kutija)
 Else
   Koef = 1
 End If
 retVal = ((Kolicina / Koef) + 0.49999)
 F_KutKol = retVal
End Function
Public Function DodajArtiklePoModelu(IDArtikalModel As Variant, Optional BrojKopija As Integer = 1) As Integer
'Kreirano: 25-02-2022

On Error GoTo Err_Point

    Dim stSQL As String
    Dim retValOk As Boolean
    Dim i As Integer
    
retValOk = True
DoCmd.Hourglass True
    
    
    If Not IsNumeric(IDArtikalModel) Then
       GoTo Exit_Point
    End If
    
    If BrojKopija <= 0 Then
       GoTo Exit_Point
    End If
For i = 1 To BrojKopija
        stSQL = ""
        stSQL = stSQL & " INSERT INTO [dbo].[R_Artikli]" & vbCrLf
        stSQL = stSQL & "         (" & vbCrLf
        stSQL = stSQL & "            [Kataloski broj]" & vbCrLf
        stSQL = stSQL & "          , BarKod" & vbCrLf
        stSQL = stSQL & "          , PLU" & vbCrLf
        stSQL = stSQL & "          , ExtSifra" & vbCrLf
        stSQL = stSQL & "          , Naziv" & vbCrLf
        stSQL = stSQL & "          , InoNaziv, [Jedinica mere], InoJm, Pakovanje, Kutija, [Transportno pakovanje], Poreklo, Grupa, Podgrupa" & vbCrLf
        stSQL = stSQL & "          , [Tarifa robe], [Tarifa usluga], [Uvek porez na robu], [Uvek porez na usluge]" & vbCrLf
        stSQL = stSQL & "          , [VP cena], [MP cena], NabDevCena, ProdDevCena, [Minimalna kolicina], ArtTaksa, Odlozeno, [Neoporezivi deo], MaxRabatProc, Memo" & vbCrLf
        stSQL = stSQL & "          , KngSifra, ArtAkciza, KngSifra_2, ZavTrosProiz, CarStopa, IDRaster" & vbCrLf
        stSQL = stSQL & "          , CarTarifa, ZemljaPorekla, SifDob, OpisArtikla, ZaBrisanje, Aktivan, IDMestoIzdavanja, HPS, KolUPak, OsnJM, MPKaloProc, VPKaloProc" & vbCrLf
        stSQL = stSQL & "          , NeVodiZalihe, TezinaKg, Zapremina, Povrsina, RSort, KLRucProc, TezinaBrutoKG" & vbCrLf
        stSQL = stSQL & "         )" & vbCrLf
        stSQL = stSQL & " " & vbCrLf
        stSQL = stSQL & " SELECT     '" & SledeciKatBroj() & "'" & vbCrLf ' strdbo.fsSledeciKatBroj()" & vbCrLf
        stSQL = stSQL & "          , Null as BarKod" & vbCrLf
        stSQL = stSQL & "          , " & SledeciPLU & vbCrLf ' dbo.fsSledeciPLU()" & vbCrLf
        stSQL = stSQL & "          , ExtSifra" & vbCrLf
        stSQL = stSQL & "          , Naziv" & vbCrLf
        stSQL = stSQL & "          , InoNaziv, [Jedinica mere], InoJm, Pakovanje, Kutija, [Transportno pakovanje], Poreklo, Grupa, Podgrupa" & vbCrLf
        stSQL = stSQL & "          , [Tarifa robe], [Tarifa usluga], [Uvek porez na robu], [Uvek porez na usluge]" & vbCrLf
        stSQL = stSQL & "          , [VP cena], [MP cena], NabDevCena, ProdDevCena, [Minimalna kolicina], ArtTaksa, Odlozeno, [Neoporezivi deo], MaxRabatProc, Memo" & vbCrLf
        stSQL = stSQL & "          , KngSifra, ArtAkciza, KngSifra_2, ZavTrosProiz, CarStopa, IDRaster" & vbCrLf
        stSQL = stSQL & "          , CarTarifa, ZemljaPorekla, SifDob, OpisArtikla, ZaBrisanje, Aktivan, IDMestoIzdavanja, HPS, KolUPak, OsnJM, MPKaloProc, VPKaloProc" & vbCrLf
        stSQL = stSQL & "          , NeVodiZalihe, TezinaKg, Zapremina, Povrsina, RSort, KLRucProc, TezinaBrutoKG" & vbCrLf
        stSQL = stSQL & " FROM       R_Artikli AS R_Artikli_1" & vbCrLf
        stSQL = stSQL & " WHERE      R_Artikli_1.[Sifra artikla] = " & stR(IDArtikalModel) & vbCrLf
        
        retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
Next i

Exit_Point:
On Error Resume Next
        DoCmd.Hourglass False
        DodajArtiklePoModelu = i - 1
    
    Exit Function

Err_Point:
    'MsgBox err.Description
    BBErrorMSG err, "DodajArtiklePoModelu"
    retValOk = False
    Resume Exit_Point
End Function
