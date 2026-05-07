VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_VrednostiZaKombo"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Public Function PrimeniUslove()
    Me.Requery
    DoCmd.GoToRecord , , acNewRec
End Function

Private Sub Form_BeforeUpdate(Cancel As Integer)
    Me!Kolona = Me!ZaKolonu
End Sub

Private Sub Form_Close()
    Dim stFormName As String
    If Nz(Me.OpenArgs, "") = "" Then Exit Sub

    stFormName = Me.OpenArgs

    ' Forma mora biti otvorena
    If Not CurrentProject.AllForms(stFormName).IsLoaded Then Exit Sub
    ' Pozovi osvežavanje preko public metode
    Select Case Me!ZaKolonu
        Case "NazivDela"
            Call Forms(stFormName).OsveziComboNazivDela
        Case "Materijal"
            Call Forms(stFormName).OsveziComboMaterijal
        Case "DimenzijaMaterijala"
            Call Forms(stFormName).OsveziComboDimenzijaMaterijala
    End Select
End Sub

