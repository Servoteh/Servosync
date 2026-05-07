VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "UF_Class"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private pIDDok As Variant
Private pIDMagacinDok As Variant
Private pCaller As String
Private pIDKomitent As Variant

Public Function SetDataFromForm(stFormName As String) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

    retValOk = True
    pIDDok = Forms(stFormName)!IDDok
    pIDMagacinDok = Nz(Forms(stFormName)!IDMagacinDOK, ReadCFGParametar("STDMagacin"))
    pIDKomitent = Forms(stFormName)![Sifra komitenta]
    
Exit_Point:
 On Error Resume Next
 SetDataFromForm = retValOk
Exit Function

Err_Point:
BBErrorMSG err, "UF_Class::SetDataFromForm"
retValOk = False
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

Private Sub Class_Initialize()
    
    pIDDok = -1
    pIDMagacinDok = 0
    pCaller = ""
    
End Sub

Public Property Get IDKomitent() As Long
   IDKomitent = pIDKomitent
End Property

Public Property Let IDKomitent(ByVal vNewValue As Long)
   pIDKomitent = vNewValue
End Property

