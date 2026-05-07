VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_SpecifikacijaNabavkeIUpiti"
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
    
Public Function PrimeniUslove()
    Me!PodformaA.Requery
    Me!PodformaB.Requery
End Function




Private Sub ZaKataloskiBroj_AfterUpdate()
    Me!ZaNazivArtikla = Me!ZaKataloskiBroj
    PrimeniUslove
End Sub

Private Sub ZaKataloskiBroj_DblClick(Cancel As Integer)
    Me!ZaNazivArtikla = Null
    Me!ZaKataloskiBroj = Null
    PrimeniUslove
End Sub

Private Sub ZaKataloskiBrojOpis_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaKataloskiBrojOpis_DblClick(Cancel As Integer)
    Me!ZaKataloskiBrojOpis = Null
    PrimeniUslove
End Sub

Private Sub ZaNazivArtikla_AfterUpdate()
    Me!ZaKataloskiBroj = Null
    PrimeniUslove
End Sub

Private Sub ZaNazivArtikla_DblClick(Cancel As Integer)
    Me!ZaNazivArtikla = Null
    Me!ZaKataloskiBroj = Null
    PrimeniUslove
End Sub

Private Sub ZaNazivArtiklaOpis_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaNazivArtiklaOpis_DblClick(Cancel As Integer)
    Me!ZaNazivArtiklaOpis = Null
    PrimeniUslove
End Sub
