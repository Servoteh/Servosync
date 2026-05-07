VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_UnosPassworda"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Sub Form_Open(Cancel As Integer)
    DoCmd.GoToControl "txtUnetiPassword"
End Sub

Private Sub txtUnetiPassword_AfterUpdate()
    ' On Error Resume Next

    Dim stUnetiPassword As String
    Dim UnetiID As Long
    
    stUnetiPassword = Nz(Me![txtUnetiPassword], "")
    UnetiID = Nz(DLookup("[SifraRadnika]", "tRadnici", "[PasswordRadnika] =  '" & stUnetiPassword & "'"), 0)
        
    If UnetiID <> 0 Then
         'SetujProdavca (UnetiID)
         'Forms![Unos dokumenata]![IDKonobar] = UnetiID
         'DoCmd.Close acForm, "UnosPassworda"
         KorisnikJeIzabran (UnetiID)
    End If

End Sub
Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click

    Dim stUnetiPassword As String
    Dim UnetiID As Long
    
    Me![txtUnetiPassword] = ""
    Me!txtUnetiPassword.Requery
    stUnetiPassword = Nz(Me![txtUnetiPassword], "")
    
    If stUnetiPassword <> "" Then
        UnetiID = Nz(DLookup("[SifraRadnika]", "tRadnici", "[PasswordRadnika] =  '" & stUnetiPassword & "'"), 0)
            
        If UnetiID <> 0 Then
            KorisnikJeIzabran (UnetiID)
        Else
            DoCmd.Close
        End If
    Else
        DoCmd.Close
    End If

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub
Private Function KorisnikJeIzabran(SifraRadnika As Long) As Long
 On Error Resume Next
    KorisnikAplikacije = SifraRadnika
    DoCmd.Close acForm, "UnosPassworda"
End Function

