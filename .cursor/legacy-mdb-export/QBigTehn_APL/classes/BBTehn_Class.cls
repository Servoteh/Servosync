VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "BBTehn_Class"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private pIDPostupka As Long
Private pIDPredmet As Long
Private pIDRadnik As Long
Private pZavrsiNalogDrugogRadnika As Boolean
Private pIDLogovanogRadnika As Long
Private pDozvoliMultitasking As Boolean
Private pIdentBroj As String
Private pVarijanta As Long
Private pOperacija As Long
Private pRJgrupaRC As String
Private pDoradaOperacije As Long
Public Property Get IDPostupka() As Long
   IDPostupka = pIDPostupka
End Property

Public Property Let IDPostupka(ByVal vNewValue As Long)
On Error GoTo Err_Point
 If IsNull(vNewValue) Then
   pIDPostupka = -1
 ElseIf Not IsNumeric(vNewValue) Then
   pIDPostupka = -1
 Else
   pIDPostupka = CLng(vNewValue)
 End If
 
Exit_Point:
On Error Resume Next
 Exit Property
Err_Point:
 BBErrorMSG err, "Property Let IDPostupka"
 pIDPostupka = -1
 Resume Exit_Point
End Property
Public Property Get IDRadnik() As Long
   'If pIDRadnik = -1 Then
   '  pIDRadnik = Nz(ADO_Lookup(CNN_CurrentDataBase, "[SifraRadnika]", "tTehPostupak", "IDPostupka = '" & pIDpostupka & "'"), "")
   'End If
   
   IDRadnik = pIDRadnik
End Property

Public Property Let IDRadnik(ByVal vNewValue As Long)
On Error GoTo Err_Point
 If IsNull(vNewValue) Then
   pIDRadnik = -1
 ElseIf Not IsNumeric(vNewValue) Then
   pIDRadnik = -1
 Else
   pIDRadnik = CLng(vNewValue)
 End If
 
Exit_Point:
On Error Resume Next
 Exit Property
Err_Point:
 BBErrorMSG err, "Property Let IDRadnik"
 pIDRadnik = -1
 Resume Exit_Point
End Property

Public Property Get IDPredmet() As Variant
    'If pIDPredmet = -1 Then
    ' 'pIDRadnik = Nz(ADO_Lookup(CNN_CurrentDataBase, "[SalesInvoiceId]", T_ER_StatusDokumenata, "RequestID = '" & UBL_RequestID & "'"), "")
    ' pIDPredmet = Nz(DLookup("[IDPredmet]", "tTehPostupak", "IDPostupka = " & pIDPostupka), -1)
    'End If
   
   IDPredmet = pIDPredmet
End Property

Public Property Let IDPredmet(ByVal vNewValue As Variant)
On Error GoTo Err_Point
 If IsNull(vNewValue) Then
   pIDPredmet = -1
 ElseIf Not IsNumeric(vNewValue) Then
   pIDPredmet = -1
 Else
   pIDPredmet = CLng(vNewValue)
 End If
 
Exit_Point:
On Error Resume Next
 Exit Property
Err_Point:
 BBErrorMSG err, "Property Let IDPredmet"
 pIDPredmet = -1
 Resume Exit_Point
End Property
Public Property Get ZavrsiNalogDrugogRadnika() As Boolean
   ZavrsiNalogDrugogRadnika = pZavrsiNalogDrugogRadnika
End Property
Public Property Let ZavrsiNalogDrugogRadnika(ByVal vNewValue As Boolean)
   pZavrsiNalogDrugogRadnika = vNewValue
End Property
Public Property Get IDLogovanogRadnika() As Long
   IDLogovanogRadnika = pIDLogovanogRadnika
End Property
Public Property Let IDLogovanogRadnika(ByVal vNewValue As Long)
   pIDLogovanogRadnika = vNewValue
End Property
Public Property Get DozvoliMultitasking() As Boolean
   DozvoliMultitasking = pDozvoliMultitasking
End Property
Public Property Let DozvoliMultitasking(ByVal vNewValue As Boolean)
   pDozvoliMultitasking = vNewValue
End Property
Private Sub Class_Initialize()
    pIDPostupka = -1
    pIDPredmet = -1
    pIDRadnik = -1
    pZavrsiNalogDrugogRadnika = False
    pIDLogovanogRadnika = -1
    pDozvoliMultitasking = False
    pIdentBroj = ""
    pVarijanta = -1
    pOperacija = -1
    pRJgrupaRC = ""
    pDoradaOperacije = -1
End Sub

Public Property Get IdentBroj() As String
   IdentBroj = pIdentBroj
End Property
Public Property Let IdentBroj(ByVal vNewValue As String)
   pIdentBroj = vNewValue
End Property
Public Property Get Varijanta() As Long
   Varijanta = pVarijanta
End Property
Public Property Let Varijanta(ByVal vNewValue As Long)
   pVarijanta = vNewValue
End Property
Public Property Get Operacija() As Long
   Operacija = pOperacija
End Property
Public Property Let Operacija(ByVal vNewValue As Long)
   pOperacija = vNewValue
End Property
Public Property Get RJgrupaRC() As String
   RJgrupaRC = pRJgrupaRC
End Property
Public Property Let RJgrupaRC(ByVal vNewValue As String)
   pRJgrupaRC = vNewValue
End Property
Public Property Get DoradaOperacije() As Long
   DoradaOperacije = pDoradaOperacije
End Property
Public Property Let DoradaOperacije(ByVal vNewValue As Long)
   pDoradaOperacije = vNewValue
End Property
