VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "USLF_Class"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private pIDDok As Variant
Private pCheckPIP As Boolean
Private pCheckDatumPrometaVisible As Boolean
Private pTextZaRacun As String
Private pIDKomitent As Variant
Private pLevel As Variant
Public Property Get Level() As Variant
    Level = pLevel
End Property
Public Property Get IDKomitent() As Long
   IDKomitent = pIDKomitent
End Property

Public Property Let IDKomitent(ByVal vNewValue As Long)
   pIDKomitent = vNewValue
End Property
Public Property Get TextZaRacun() As String
    TextZaRacun = pTextZaRacun
End Property
Public Property Let TextZaRacun(ByVal vNewValue As String)
    pTextZaRacun = vNewValue
End Property
Public Property Get CheckDatumPrometaVisible() As Boolean
    CheckDatumPrometaVisible = pCheckDatumPrometaVisible
End Property
Public Property Let CheckDatumPrometaVisible(ByVal vNewValue As Boolean)
    pCheckDatumPrometaVisible = vNewValue
End Property

Public Property Get CheckPiP() As Boolean
    CheckPiP = pCheckPIP
End Property
Public Property Let CheckPiP(ByVal vNewValue As Boolean)
    pCheckPIP = vNewValue
End Property
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
Public Function SetDataFromForm(stFormName As String) As Boolean

On Error GoTo Err_Point
Dim retValOk As Boolean

    retValOk = True
    pIDDok = Forms(stFormName)!IDDok
    If IsNull(pIDDok) Then
        pTextZaRacun = Nz(ReadCFGParametar("DefaultTekstZaFakturu_Usluge", RaccunText), RaccunText)
    Else
        pTextZaRacun = CStr(Nz(Forms(stFormName)!TekstZaFakturu, ""))
    End If
    'pCheckMemorandumVisible = Forms(stFormName)!CheckMemorandumVisible
    'pCheckTRNaFakturiVisible = Forms(stFormName)!CheckTRNaFakturiVisible
    
    pCheckPIP = Nz(Forms(stFormName)!CheckPiP, 0)
    pIDKomitent = Nz(Forms(stFormName)![Sifra komitenta], 0)
    
    'pTekuciRacun = Nz(Forms(stFormName)!ComboUplatniRacun.Column(1), F_AFTekuciRacun())
    pLevel = Nz(Forms(stFormName)!Level, 0)
    'pKategorija_PO = Forms(stFormName)!Kategorija_PO
    'pOznaka_PO = Forms(stFormName)!Oznaka_PO
    'pSortNaReportu = Forms(stFormName)!SortNaReportu
    pCheckDatumPrometaVisible = CBool(Nz(Forms(stFormName)![CheckDatumPrometaVisible], True))
Exit_Point:
 On Error Resume Next
 SetDataFromForm = retValOk
Exit Function

Err_Point:
BBErrorMSG err, "USL_Class::SetDataFromForm"
retValOk = False
Resume Exit_Point
End Function
