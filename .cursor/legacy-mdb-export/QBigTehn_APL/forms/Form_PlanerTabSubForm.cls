VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PlanerTabSubForm"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub Form_Current()
On Error Resume Next
  Me.Parent!ZaIDPlaner = Nz(Me!ID, 0)
  'Call Me.Parent.PrimeniUslove
  Call Me.Parent.PrikaziIzabraniPlaner
  'PrikaziPoruku
End Sub
Private Sub PostaviKolonu()
    If Me!Label_KoJeUradio.Caption Like "Ko je*" Then
       Me!Label_KoJeUradio.Caption = "Od" & vbCrLf & "koga"
       Me!KoJeUradio.ControlSource = "OdKoga"
    ElseIf Me!Label_KoJeUradio.Caption Like "Od*" Then
       Me!Label_KoJeUradio.Caption = "Za" & vbCrLf & "koga"
       Me!KoJeUradio.ControlSource = "ZaKoga"
    ElseIf Me!Label_KoJeUradio.Caption Like "Za*" Then
       Me!Label_KoJeUradio.Caption = "Ko je" & vbCrLf & "uradio"
       Me!KoJeUradio.ControlSource = "KoJeUradio"
    Else
       Me!Label_KoJeUradio.Caption = "Ko je" & vbCrLf & "uradio"
       Me!KoJeUradio.ControlSource = "KoJeUradio"
    End If
End Sub
Private Sub KoJeUradio_DblClick(Cancel As Integer)
    PostaviKolonu
End Sub
Private Sub Label_KoJeUradio_DblClick(Cancel As Integer)
    PostaviKolonu
End Sub
