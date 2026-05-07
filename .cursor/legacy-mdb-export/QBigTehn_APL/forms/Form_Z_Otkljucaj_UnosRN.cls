VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Z_Otkljucaj_UnosRN"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False

Option Compare Database
Option Explicit

Private Sub Form_Open(Cancel As Integer)
 If Not IsNull(Forms![UnosRN]!IDPredmet) Then
  ZakOtkDok "tRN", "IDRN", Forms![UnosRN]!IDRN, False
 End If
 DoCmd.Close acForm, "Z_Otkljucaj_UnosRN"
End Sub

