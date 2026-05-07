VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "PDM_Class"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private pIDCrtez As Variant
Private pBrojCrteza As String
Private pCaller As String
Private pRevizija As String
Private pPDMweID As Variant
Private pTrebaIDCrtez As Variant
Private pZaPodSklopTrebaIDCrtez As Variant
Private pZaPodPodSklopTrebaIDCrtez As Variant
Public Function SetDataFromForm(stFormName As String) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

    retValOk = True
    pIDCrtez = Nz(Forms(stFormName)!IDCrtez, -1)
    
    pBrojCrteza = Nz(Forms(stFormName)!BrojCrteza, "-")
    'pCaller = Forms(stFormName).Name
    pRevizija = Nz(Forms(stFormName)!Revizija, "")
        
    'pPDMweID = Forms(stFormName)![Pdmweid]
    
    
Exit_Point:
 On Error Resume Next
 SetDataFromForm = retValOk
Exit Function

Err_Point:
BBErrorMSG err, "PDM_Class::SetDataFromForm"
retValOk = False
Resume Exit_Point
End Function
Public Property Get IDCrtez() As Variant
   IDCrtez = pIDCrtez
End Property

Public Property Let IDCrtez(ByVal vNewValue As Variant)
On Error GoTo Err_Point
 If IsNull(vNewValue) Then
   pIDCrtez = -1
 ElseIf Not IsNumeric(vNewValue) Then
   pIDCrtez = -1
 Else
   pIDCrtez = CLng(vNewValue)
 End If
 
Exit_Point:
On Error Resume Next
 Exit Property
Err_Point:
 BBErrorMSG err, "Property Let IDCrteza"
 pIDCrtez = -1
 Resume Exit_Point
End Property

Public Property Get BrojCrteza() As String
   BrojCrteza = pBrojCrteza
End Property

Public Property Let BrojCrteza(ByVal vNewValue As String)
On Error GoTo Err_Point
 If IsNull(vNewValue) Then
   pBrojCrteza = "-"
 Else
   pBrojCrteza = CStr(vNewValue)
 End If
 
Exit_Point:
On Error Resume Next
 Exit Property
Err_Point:
 BBErrorMSG err, "Property Let BrojCrteza"
 pBrojCrteza = "-"
 Resume Exit_Point
End Property

Public Property Get Caller() As String
    Caller = pCaller
End Property
Public Property Let Caller(ByVal vNewValue As String)
    pCaller = vNewValue
End Property

Public Property Get Revizija() As String
    Revizija = pRevizija
End Property
Public Property Let Revizija(ByVal vNewValue As String)
    pRevizija = vNewValue
End Property

Public Property Get Pdmweid() As Long
   Pdmweid = pPDMweID
End Property

Public Property Let Pdmweid(ByVal vNewValue As Long)
   pPDMweID = vNewValue
End Property
Public Property Get TrebaIDCrtez() As Long
   TrebaIDCrtez = pTrebaIDCrtez
End Property

Public Property Let TrebaIDCrtez(ByVal vNewValue As Long)
   pTrebaIDCrtez = vNewValue
End Property
Public Property Get ZaPodSklopTrebaIDCrtez() As Long
   ZaPodSklopTrebaIDCrtez = pZaPodSklopTrebaIDCrtez
End Property

Public Property Let ZaPodSklopTrebaIDCrtez(ByVal vNewValue As Long)
   pZaPodSklopTrebaIDCrtez = vNewValue
End Property

Public Property Get ZaPodPodSklopTrebaIDCrtez() As Long
   ZaPodPodSklopTrebaIDCrtez = pZaPodPodSklopTrebaIDCrtez
End Property

Public Property Let ZaPodPodSklopTrebaIDCrtez(ByVal vNewValue As Long)
   pZaPodPodSklopTrebaIDCrtez = vNewValue
End Property


Private Sub Class_Initialize()
    pIDCrtez = -1
    pBrojCrteza = "-"
    pCaller = ""
    pRevizija = "-"
    pPDMweID = -1
    pTrebaIDCrtez = -1
    pZaPodSklopTrebaIDCrtez = -1
    pZaPodPodSklopTrebaIDCrtez = -1
End Sub

