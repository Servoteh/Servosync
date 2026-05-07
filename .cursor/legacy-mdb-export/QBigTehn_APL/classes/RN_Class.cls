VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "RN_Class"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private pIDRN As Variant
Private pSifraRadnika As Variant
Private pIDKomitent As Long
Private pIDPredmet As Variant
Private pVarijanta As Variant
Private pRJgrupaRC As String
Private pIdentBroj As String
Private pRootFolderDokumentacije As String
Private pFolderTehnologa As String
Private pFolderKontrole As String
Private pBrojCrteza As String
Private pRevizija As String
Private pCaller As String
Public Property Get IDKomitent() As Long
   IDKomitent = pIDKomitent
End Property
Public Property Let IDKomitent(ByVal vNewValue As Long)
   pIDKomitent = vNewValue
End Property

Public Property Get SifraRadnika() As Long
   SifraRadnika = pSifraRadnika
End Property
Public Property Let SifraRadnika(ByVal vNewValue As Long)
   pSifraRadnika = vNewValue
End Property

Public Property Get IDPredmet() As Long
    If IsNull(pIDPredmet) Or IsEmpty(pIDPredmet) Or pIDPredmet = -1 Then
        pIDPredmet = Nz(ADO_Lookup(CNN_CurrentDataBase, "[IDPredmet]", "tRN", "IDRN = " & pIDRN), -1)
    End If
    IDPredmet = pIDPredmet
End Property
Public Property Let IDPredmet(ByVal vNewValue As Long)
   pIDPredmet = vNewValue
End Property

Public Property Get RJgrupaRC() As String
    RJgrupaRC = pRJgrupaRC
End Property
Public Property Let RJgrupaRC(ByVal vNewValue As String)
    pRJgrupaRC = vNewValue
End Property

Public Property Get IdentBroj() As String
    If IsNull(pIdentBroj) Or IsEmpty(pIdentBroj) Or pIdentBroj = "" Then
        pIdentBroj = Nz(ADO_Lookup(CNN_CurrentDataBase, "[IdentBroj]", "tRN", "IDRN = " & pIDRN), "")
    End If
    IdentBroj = pIdentBroj
End Property
Public Property Let IdentBroj(ByVal vNewValue As String)
    pIdentBroj = vNewValue
End Property

Public Property Get Varijanta() As Variant
    If IsNull(pVarijanta) Or IsEmpty(pVarijanta) Or pVarijanta = -1 Then
        pVarijanta = Nz(ADO_Lookup(CNN_CurrentDataBase, "[Varijanta]", "tRN", "IDRN = " & pIDRN), -1)
    End If
    Varijanta = pVarijanta
End Property
Public Property Let Varijanta(ByVal vNewValue As Variant)
   pVarijanta = vNewValue
End Property

Public Property Get IDRN() As Variant
   IDRN = pIDRN
End Property

Public Property Let IDRN(ByVal vNewValue As Variant)
On Error GoTo Err_Point
 If IsNull(vNewValue) Then
   pIDRN = -1
 ElseIf Not IsNumeric(vNewValue) Then
   pIDRN = -1
 Else
   pIDRN = CLng(vNewValue)
 End If
 
Exit_Point:
On Error Resume Next
 Exit Property
Err_Point:
 BBErrorMSG err, "Property Let IDRN"
 pIDRN = -1
 Resume Exit_Point
End Property
Public Function SetDataFromForm(stFormName As String) As Boolean

On Error GoTo Err_Point
Dim retValOk As Boolean

    retValOk = True
    
    pIDRN = Forms(stFormName)!IDRN
    
    pIdentBroj = CStr(Nz(Forms(stFormName)!IdentBroj, ""))
    pRJgrupaRC = CStr(Nz(Forms(stFormName)!RJgrupaRC, ""))
   
    pIDKomitent = Nz(Forms(stFormName)![Sifra komitenta], 0)
    pIDPredmet = Nz(Forms(stFormName)![IDPredmet], 0)
    pSifraRadnika = Nz(Forms(stFormName)![SifraRadnika], 0)
    'pTekuciRacun = Nz(Forms(stFormName)!ComboUplatniRacun.Column(1), F_AFTekuciRacun())
    pVarijanta = Nz(Forms(stFormName)!Varijanta, "")
    
    'pCheckDatumPrometaVisible = CBool(Nz(Forms(stFormName)![CheckDatumPrometaVisible], True))
    
Exit_Point:
 On Error Resume Next
 SetDataFromForm = retValOk
Exit Function

Err_Point:
BBErrorMSG err, "RN_Class::SetDataFromForm"
retValOk = False
Resume Exit_Point
End Function
Public Property Get RootFolderDokumentacije() As String
    RootFolderDokumentacije = pRootFolderDokumentacije
End Property
Public Property Let RootFolderDokumentacije(nRootFolderDokumentacije As String)
    pRootFolderDokumentacije = nRootFolderDokumentacije
End Property
Public Property Get FolderTehnologa() As String
    FolderTehnologa = pFolderTehnologa
End Property
Public Property Get FolderKontrole() As String
    FolderKontrole = pFolderKontrole
End Property
Public Property Get BrojCrteza() As String
    BrojCrteza = pBrojCrteza
End Property
Public Property Let BrojCrteza(ByVal vNewValue As String)
    pBrojCrteza = vNewValue
End Property
Public Property Get Revizija() As String
    Revizija = pRevizija
End Property
Public Property Let Revizija(ByVal vNewValue As String)
    pRevizija = vNewValue
End Property
Public Property Get Caller() As String
    Caller = pCaller
End Property
Public Property Let Caller(ByVal vNewValue As String)
    pCaller = vNewValue
End Property
Private Sub Class_Initialize()
    pIDRN = -1
    
    'pCaller = ""
    pRJgrupaRC = "-"
    pSifraRadnika = 0
    pIdentBroj = ""
    pIDKomitent = -1
    pIDPredmet = -1
    pVarijanta = -1
    pRootFolderDokumentacije = Nz(ReadParametar("CFG_Global", "RootFolderDokumentacije"), "\\srv\QBigTehn_Files$\")
    pFolderTehnologa = Nz(ReadParametar("CFG_Global", "FolderTehnologa"), "Tehnologija\")
    pFolderKontrole = Nz(ReadParametar("CFG_Global", "FolderKontrole"), "Kontrola\")
    pBrojCrteza = ""
    pRevizija = ""
    pCaller = ""
End Sub
