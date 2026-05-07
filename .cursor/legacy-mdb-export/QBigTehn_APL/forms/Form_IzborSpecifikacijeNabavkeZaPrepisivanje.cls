VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_IzborSpecifikacijeNabavkeZaPrepisivanje"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub
Private Sub DugmePrepisiStavkeIzNaloga_Click()
On Error GoTo Err_DugmePrepisiStavkeIzNaloga_Click

    Dim stDocName As String

    DoCmd.SetWarnings False
    stDocName = "ProknjiziStavkeSpecifikacijaZahtevaNabavke"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    'Forms![Unos naloga glavne knjige].Form![Stavke naloga].Requery
    Forms![UnosZahtevaZaNabavku].Form![SpecifikacijaZahtevaZaNabavku].Requery
    
Exit_DugmePrepisiStavkeIzNaloga_Click:
    DoCmd.SetWarnings False
    DoCmd.Close acForm, "IzborSpecifikacijeNabavkeZaPrepisivanje", acSaveYes
    Exit Sub

Err_DugmePrepisiStavkeIzNaloga_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiStavkeIzNaloga_Click
    
End Sub
