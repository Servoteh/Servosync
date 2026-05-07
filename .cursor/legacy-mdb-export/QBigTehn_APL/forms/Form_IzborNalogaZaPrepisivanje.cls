VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_IzborNalogaZaPrepisivanje"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub ComboIDRN_Enter()
    Me!ComboIDRN.Requery
End Sub

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub
Private Sub DugmePrepisiStavkeIzNaloga_OLD_Click()
On Error GoTo Err_DugmePrepisiStavkeIzNaloga_Click

    Dim stDocName As String
    Dim NoviIDRN As Long
    Dim prepisaniIDRN As Long
        
    NoviIDRN = CLng([Forms]![IzborNalogaZaPrepisivanje]![ZaIDRN])
    prepisaniIDRN = CLng(Nz([Forms]![IzborNalogaZaPrepisivanje]![ComboIDRN], 0))
    If prepisaniIDRN <> 0 Then
        
        PrepisiStavkeIzNaloga NoviIDRN, prepisaniIDRN
        
        PrepisitPNDIzNaloga NoviIDRN, prepisaniIDRN
        
        PrepisitPLPIzNaloga NoviIDRN, prepisaniIDRN
        
        PrepisitPDMIzNaloga NoviIDRN, prepisaniIDRN
        
        Forms![UnosRN].Form![Podforma].Requery
    Else
        MsgBox "Niste izabrali iz kojeg naloga prepisujete tehnološki postupak", vbInformation
    End If
    
Exit_DugmePrepisiStavkeIzNaloga_Click:
    'DoCmd.SetWarnings False
    DoCmd.Close acForm, "IzborNalogaZaPrepisivanje", acSaveYes
    Exit Sub

Err_DugmePrepisiStavkeIzNaloga_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiStavkeIzNaloga_Click
    
End Sub
Private Sub DugmePrepisiStavkeIzNaloga_Click()

On Error GoTo ErrH

Dim NoviIDRN As Long
Dim IzIDRN As Long

    NoviIDRN = CLng(Me.ZaIDRN)
    IzIDRN = CLng(Nz(Me.ComboIDRN, 0))
    'NoviIDRN = CLng([Forms]![IzborNalogaZaPrepisivanje]![ZaIDRN])
    'IzIDRN = CLng(Nz([Forms]![IzborNalogaZaPrepisivanje]![ComboIDRN], 0))
        
    If IzIDRN = 0 Then
        MsgBox "Niste izabrali nalog.", vbInformation
        Exit Sub
    End If
    
    If ADO_ExecSP(CNN_CurrentDataBase, "spRN_PrepisiStavkeIzNaloga", NoviIDRN, IzIDRN) Then
        DoCmd.Close
    Else
        MsgBox "Prepisivanje stavki naloga nije uspelo.", vbInformation
    End If
    
Exit Sub

ErrH:
MsgBox err.Description

End Sub

