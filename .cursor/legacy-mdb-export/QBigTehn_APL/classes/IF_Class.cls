VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "IF_Class"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'Modifikovano: 09-01-2023 => ReportSpec

Option Compare Database
Option Explicit

Private pIDDok As Variant
Private pIDMagacinDok As Variant
Private pCaller As String
Private pTextZaRacun As String
Private pCheckMemorandumVisible As Boolean
Private pCheckTRNaFakturiVisible As Boolean
Private pFakturaSaOpisomStavke As Boolean
Private pCheckPIP As Boolean
Private pIDKomitent As Variant
Private pCheckProdajaSaPDV As Boolean
Private pCenovnik As Variant
Private pIzvozVrstaProdaje As Variant
Private pLevel As Variant
Private pKategorija_PO As Variant
Private pOznaka_PO As Variant
Private pSortNaReportu As String
Private pReportSpec As String

'Modifikovano: 06-12-2021
Private pOSN_Kolicina As Boolean

Public Function SetDataFromForm(stFormName As String) As Boolean
'Modifikovano: 06-12-2021
'Modifikovano: 18-10-2022
On Error GoTo Err_Point
Dim retValOk As Boolean

    retValOk = True
    pIDDok = Forms(stFormName)!IDDok
    
    pIDMagacinDok = Nz(Forms(stFormName)!IDMagacinDOK, ReadCFGParametar("STDMagacin"))
    'pCaller = Forms(stFormName).Name
    pTextZaRacun = Forms(stFormName)!TekstZaRacun
    pCheckMemorandumVisible = Forms(stFormName)!CheckMemorandumVisible
    pCheckTRNaFakturiVisible = Forms(stFormName)!CheckTRNaFakturiVisible
    pFakturaSaOpisomStavke = Forms(stFormName)!FakturaSaOpisomStavke
    pCheckPIP = Forms(stFormName)!CheckPiP
    pIDKomitent = Forms(stFormName)![Sifra komitenta]
    
    pCheckProdajaSaPDV = Nz(ADO_Lookup(CNN_CurrentDataBase, "[Prodaja sa PPP]", "R_Vrste dokumenata", "[Vrsta dokumenta]='" & Forms(stFormName)![Vrsta dokumenta] & "'"), True)
    
    'pTekuciRacun = Nz(Forms(stFormName)!ComboUplatniRacun.Column(1), F_AFTekuciRacun())
    pCenovnik = Forms(stFormName)!ComboCenovnik
    pIzvozVrstaProdaje = Forms(stFormName)!ComboIzvozVrstaProdaje
    pOSN_Kolicina = Forms(stFormName)!PrintOSN_Kolicina
    pLevel = Forms(stFormName)!Level
    pKategorija_PO = Forms(stFormName)!Kategorija_PO
    pOznaka_PO = Forms(stFormName)!Oznaka_PO
    pSortNaReportu = Forms(stFormName)!SortNaReportu
Exit_Point:
 On Error Resume Next
 SetDataFromForm = retValOk
Exit Function

Err_Point:
BBErrorMSG err, "IF_Class::SetDataFromForm"
retValOk = False
Resume Exit_Point
End Function
Public Function PreuzeoZaPrevoz(Optional IDVozac) As String
On Error GoTo Err_Point
 Dim stRetVal As String
 Dim pIDVozac
 
 
 If Not IsNumeric(pIDDok) Then
    stRetVal = ""
    GoTo Exit_Point
 End If
 
 If IsMissing(IDVozac) Then
     pIDVozac = ADO_Lookup(CNN_CurrentDataBase, "[IDVozac]", "[T_Robna dokumenta]", "[IDDok]=" & pIDDok)
 Else
     pIDVozac = IDVozac
 End If
 
 If Not IsNumeric(pIDVozac) Then
    stRetVal = ""
    GoTo Exit_Point
 End If
 
 stRetVal = ADO_Lookup(CNN_CurrentDataBase, "[Naziv]", "Komitenti", "[Sifra]=" & CLng(pIDVozac))
 If stRetVal = "-" Then
    stRetVal = ""
 Else
  stRetVal = stRetVal & vbCrLf & ADO_Lookup(CNN_CurrentDataBase, "[Mesto]", "Komitenti", "[Sifra]=" & CLng(pIDVozac))
  stRetVal = stRetVal & ", " & ADO_Lookup(CNN_CurrentDataBase, "[Adresa]", "Komitenti", "[Sifra]=" & CLng(pIDVozac))
  stRetVal = stRetVal & vbCrLf & "PIB: " & ADO_Lookup(CNN_CurrentDataBase, "[PIB]", "Komitenti", "[Sifra]=" & CLng(pIDVozac))
  
  
  If ADO_PostojiKolonaUTabeli(CNN_CurrentDataBase, "Komitenti", "MB") Then
   stRetVal = stRetVal & " MB: " & ADO_Lookup(CNN_CurrentDataBase, "[MB]", "Komitenti", "[Sifra]=" & CLng(pIDVozac))
  ElseIf ADO_PostojiKolonaUTabeli(CNN_CurrentDataBase, "Komitenti", "MaticniBroj") Then
   stRetVal = stRetVal & " MB: " & ADO_Lookup(CNN_CurrentDataBase, "[MaticniBroj]", "Komitenti", "[Sifra]=" & CLng(pIDVozac))
  End If
 
 End If
 
Exit_Point:
On Error Resume Next
 If stRetVal = "" Or stRetVal = "-" Then
     stRetVal = vbCrLf & "Broj l.k.:_____________________"
     stRetVal = stRetVal & vbCrLf & vbCrLf
     stRetVal = stRetVal & "Reg. br. vozila: ________________"
 End If
PreuzeoZaPrevoz = stRetVal
Exit Function

Err_Point:
    stRetVal = ""
    Resume Exit_Point
End Function
Public Function RobuIzdao(Optional IDMagacin) As String
'Modifikovano: 12-01-2022
On Error GoTo Err_Point
 Dim IDMagacioner
 Dim stRetVal As String
 Dim stMagacioner As String
 Dim stBrLkMagacioner As String
 
 Dim pIDMagacin
 Dim stSQL As String
 Dim rst As DAO.Recordset
 
 stMagacioner = "xxx"
 
 If Not IsNumeric(pIDDok) Then
    stRetVal = ""
    GoTo Exit_Point
 End If
 
 If IsMissing(IDMagacin) Then
     pIDMagacin = ADO_Lookup(CNN_CurrentDataBase, "[IDMagacinDOK]", "[T_Robna dokumenta]", "[IDDok]=" & pIDDok)
 Else
     pIDMagacin = IDMagacin
 End If
 
 If Not IsNumeric(pIDMagacin) Then
    stRetVal = ""
    GoTo Exit_Point
 End If
 
 IDMagacioner = Nz(ADO_Lookup(CNN_CurrentDataBase, "PripremioRobu", "T_StatusDokumenata", "IDDok = " & stR(pIDDok)), 0)
 
 stSQL = "SELECT * FROM Magacini WHERE IDMagacin=" & CStr(pIDMagacin)
 Set rst = CurrentDb.OpenRecordset(stSQL, dbOpenDynaset, dbSeeChanges, dbReadOnly)
 If rst.EOF And rst.BOF Then
    stRetVal = ""
    GoTo Exit_Point
 End If
 
 rst.MoveFirst
 If Nz(IDMagacioner, 0) = 0 Then
        If Nz(rst!ImeMagacionera) <> "" Then
           stMagacioner = rst!ImeMagacionera & vbCrLf
        Else
           stMagacioner = vbCrLf
        End If
        
        If Nz(rst!BrLkMagacionera) <> "" Then
           stMagacioner = stMagacioner & "Broj l.k.: " & rst!BrLkMagacionera & vbCrLf
        Else
           stMagacioner = stMagacioner & "Broj l.k.:_____________________" & vbCrLf
        End If
 Else ' If IsNull(IDMagacioner) Then
        stMagacioner = Nz(ADO_Lookup(CNN_CurrentDataBase, "ImeIPrezime", "Radnici", "IDRadnik=" & CLng(IDMagacioner)), "") & vbCrLf
        stBrLkMagacioner = Nz(ADO_Lookup(CNN_CurrentDataBase, "BrLK", "Radnici", "IDRadnik=" & CLng(IDMagacioner)), "")
        
        If stBrLkMagacioner <> "" Then
           stMagacioner = stMagacioner & "Broj l.k.: " & stBrLkMagacioner & vbCrLf
        Else
           stMagacioner = stMagacioner & "Broj l.k.:_____________________" & vbCrLf
        End If
        
        
 End If ' ELSE If IsNull(IDMagacioner) Then
 
 stRetVal = stMagacioner & "iz magacina " & rst!Magacin & vbCrLf
 stRetVal = stRetVal & Nz(rst!UlicaIBroj, "")
 
 If Nz(rst!MESTO, "") <> "" Then
  stRetVal = stRetVal & ", " & Nz(rst!MESTO, "")
 End If

Exit_Point:
On Error Resume Next
rst.Close
Set rst = Nothing
RobuIzdao = stRetVal
Exit Function

Err_Point:
    BBErrorMSG err, "RobuIzdao"
    stRetVal = ""
    Resume Exit_Point
End Function

Public Function RobuPrimio() As String
On Error GoTo Err_Point
 Dim stRetVal As String
 Dim i As Integer
 Dim UpisanBrLk As Boolean
 
 UpisanBrLk = False
 
 If Not IsNumeric(pIDDok) Then
    stRetVal = vbCrLf & "Broj l.k.:_____________________"
    GoTo Exit_Point
 End If
 
 stRetVal = Nz(ADO_Lookup(CNN_CurrentDataBase, "RobuPrimio", "SELECT RobuPrimio FROM T_StatusDokumenata WHERE IDDok=" & CStr(pIDDok)), "")
 
 If Len(Trim(stRetVal)) > 0 Then
    For i = 1 To Len(stRetVal)
     UpisanBrLk = UpisanBrLk Or IsNumeric(Mid(stRetVal, i, 1))
    Next i
 End If
 If Not UpisanBrLk Then
    stRetVal = stRetVal & vbCrLf & "Broj l.k.:_____________________"
 End If
Exit_Point:
On Error Resume Next
 RobuPrimio = stRetVal
Exit Function

Err_Point:
    stRetVal = ""
    Resume Exit_Point
End Function
Public Function RobuPrimio_OLD() As String
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim stRetVal As String
retValOk = True


stRetVal = vbCrLf & "Broj l.k.:_____________________"

Exit_Point:
 On Error Resume Next
       RobuPrimio_OLD = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "RobuPrimio"
 retValOk = False
 Resume Exit_Point

End Function
Public Function Prodavac(Optional IDProdavac) As String
On Error GoTo Err_Point
 Dim stRetVal As String
 Dim pIDProdavac
 Dim stSQL As String
 Dim rst As DAO.Recordset
 
 If Not IsNumeric(pIDDok) Then
    stRetVal = ""
    GoTo Exit_Point
 End If
 
 If IsMissing(IDProdavac) Then
     pIDProdavac = ADO_Lookup(CNN_CurrentDataBase, "[Sifra prodavca]", "[T_Robna dokumenta]", "[IDDok]=" & pIDDok)
 Else
     pIDProdavac = IDProdavac
 End If
 
 If Not IsNumeric(pIDProdavac) Then
    stRetVal = ""
    GoTo Exit_Point
 End If
 
 stSQL = "SELECT * FROM Prodavci WHERE [Sifra prodavca]=" & CStr(pIDProdavac)
 Set rst = CurrentDb.OpenRecordset(stSQL, dbOpenDynaset, dbSeeChanges, dbReadOnly)
 If rst.EOF And rst.BOF Then
    stRetVal = ""
    GoTo Exit_Point
 End If
 
 rst.MoveFirst
 If Nz(rst!ImeProdavca) <> "" Then
    stRetVal = rst!ImeProdavca & vbCrLf
 ElseIf Nz(rst!Prodavac) <> "" Then
    stRetVal = rst!Prodavac & vbCrLf
 Else
    stRetVal = vbCrLf
 End If
 If Nz(rst!BrLkProdavca) <> "" Then
    stRetVal = stRetVal & "Broj l.k.: " & rst!BrLkProdavca
 Else
   ' stRetval = stRetval & "Broj l.k.:_____________________"
 End If

Exit_Point:
On Error Resume Next
rst.Close
Set rst = Nothing
Prodavac = stRetVal
Exit Function

Err_Point:
    BBErrorMSG err, "Prodavac"
    stRetVal = ""
    Resume Exit_Point
End Function
Public Property Get IDDok() As Variant
   IDDok = pIDDok
End Property

Public Property Let IDDok(ByVal vNewValue As Variant)
On Error GoTo Err_Point
 If IsNull(vNewValue) Then
   pIDDok = -1
 ElseIf Not IsNumeric(vNewValue) Then
   pIDDok = -1
 Else
   pIDDok = CLng(vNewValue)
 End If
 
Exit_Point:
On Error Resume Next
 Exit Property
Err_Point:
 BBErrorMSG err, "Property Let IDDok"
 pIDDok = -1
 Resume Exit_Point
End Property

Public Property Get IDMagacinDOK() As Variant
   IDMagacinDOK = pIDMagacinDok
End Property

Public Property Let IDMagacinDOK(ByVal vNewValue As Variant)
On Error GoTo Err_Point
 If IsNull(vNewValue) Then
   pIDMagacinDok = -1
 ElseIf Not IsNumeric(vNewValue) Then
   pIDMagacinDok = -1
 Else
   pIDMagacinDok = CLng(vNewValue)
 End If
 
Exit_Point:
On Error Resume Next
 Exit Property
Err_Point:
 BBErrorMSG err, "Property Let IDMagacinDOK"
 pIDMagacinDok = -1
 Resume Exit_Point
End Property

Public Property Get Caller() As String
    Caller = pCaller
End Property
Public Property Let Caller(ByVal vNewValue As String)
    pCaller = vNewValue
End Property

Public Property Get TextZaRacun() As String
    TextZaRacun = pTextZaRacun
End Property
Public Property Let TextZaRacun(ByVal vNewValue As String)
    pTextZaRacun = vNewValue
End Property

Public Property Get CheckMemorandumVisible() As Boolean
    CheckMemorandumVisible = pCheckMemorandumVisible
End Property
Public Property Let CheckMemorandumVisible(ByVal vNewValue As Boolean)
    pCheckMemorandumVisible = vNewValue
End Property

Public Property Get CheckTRNaFakturiVisible() As Boolean
    CheckTRNaFakturiVisible = pCheckTRNaFakturiVisible
End Property
Public Property Let CheckTRNaFakturiVisible(ByVal vNewValue As Boolean)
    pCheckTRNaFakturiVisible = vNewValue
End Property

Public Property Get OSN_Kolicina() As Boolean
'06-12-2021
    OSN_Kolicina = pOSN_Kolicina
End Property
Public Property Let OSN_Kolicina(ByVal vNewValue As Boolean)
'06-12-2021
    pOSN_Kolicina = vNewValue
End Property

Public Property Get FakturaSaOpisomStavke() As Boolean
    FakturaSaOpisomStavke = pFakturaSaOpisomStavke
End Property
Public Property Let FakturaSaOpisomStavke(ByVal vNewValue As Boolean)
    pFakturaSaOpisomStavke = vNewValue
End Property
Public Property Get CheckPiP() As Boolean
    CheckPiP = pCheckPIP
End Property
Public Property Let CheckPiP(ByVal vNewValue As Boolean)
    pCheckPIP = vNewValue
End Property
Private Sub Class_Initialize()
    pIDDok = -1
    pIDMagacinDok = 0
    pCaller = ""
    pTextZaRacun = "-"
    
    pCheckMemorandumVisible = True
    pCheckTRNaFakturiVisible = True
    pFakturaSaOpisomStavke = False
    pCheckPIP = False
    
    pCheckProdajaSaPDV = True
    
    '06-12-2021
    pOSN_Kolicina = False
    '18-10-2022
    pSortNaReportu = "IDStavke"
    
    '09-01-2023
    pReportSpec = ""
End Sub

Public Property Get IDKomitent() As Long
   IDKomitent = pIDKomitent
End Property

Public Property Let IDKomitent(ByVal vNewValue As Long)
   pIDKomitent = vNewValue
End Property

Public Property Get CheckProdajaSaPDV() As Boolean
   CheckProdajaSaPDV = pCheckProdajaSaPDV
End Property

Public Property Let CheckProdajaSaPDV(ByVal vNewValue As Boolean)
    pCheckProdajaSaPDV = vNewValue
End Property

Public Property Get Cenovnik() As String
    Cenovnik = pCenovnik
End Property
Public Property Let Cenovnik(ByVal vNewValue As String)
    pCenovnik = vNewValue
End Property
Public Property Get IzvozVrstaProdaje() As Variant
    IzvozVrstaProdaje = pIzvozVrstaProdaje
End Property
Public Property Let IzvozVrstaProdaje(ByVal vNewValue As Variant)
    pIzvozVrstaProdaje = vNewValue
End Property
Public Property Get Level() As Variant
'28-01-2022
    Level = pLevel
End Property

'03-06-2022
Public Property Get Kategorija_PO() As String
    Kategorija_PO = pKategorija_PO
End Property
Public Property Let Kategorija_PO(ByVal vNewValue As String)
    pKategorija_PO = vNewValue
End Property

Public Property Get Oznaka_PO() As String
    Oznaka_PO = pOznaka_PO
End Property
Public Property Let Oznaka_PO(ByVal vNewValue As String)
    pOznaka_PO = vNewValue
End Property
'18-10-2022
Public Property Get SortNaReportu() As String
    SortNaReportu = pSortNaReportu
End Property
Public Property Let SortNaReportu(ByVal vNewValue As String)
    pSortNaReportu = vNewValue
End Property
'Modifikovano: 09-01-2023 => ReportSpec
Public Property Get ReportSpec() As String
    ReportSpec = pReportSpec
End Property
Public Property Let ReportSpec(ByVal vNewValue As String)
    pReportSpec = vNewValue
End Property
