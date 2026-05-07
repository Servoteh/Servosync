VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PDMXMLImportLog"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Public Function PrimeniUslove()
   BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
   Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
End Function

Private Sub DUgmePreuzmiXMLFajlove_Click()

    If PokreniParsiranje() Then
        ' Ako je parsiranje prošlo OK, izaði iz Access-a
        WriteToLog "Parsiranje završeno bez greške."
    Else
        WriteToLog "GREŠKA: " & err.Number & " - " & err.Description
    End If


End Sub

Private Sub Form_Load()
    If CurrentUser() <> "Negovan" Then
        Me!DUgmePreuzmiXMLFajlove.Visible = False
    End If
    PrimeniUslove
    'PostaviStilImportLog Me
End Sub
Private Function ClearCurrentVal()
   Screen.ActiveControl.Value = Null
   PrimeniUslove
End Function


Public Sub PostaviStilImportLog(frm As Form)
    Dim ctl As control
    Dim clrZaglavlje As Long
    Dim clrPozadina As Long
    Dim clrHeaderKolona As Long

    ' Pretvaranje HEX › VBA (&HBBGGRR)
    clrZaglavlje = &HD4E6F4      ' #F4E6D4 - bež zaglavlje forme
    clrPozadina = &HFBF6F3       ' #F3F6FB - svetlo siva / plavièasta pozadina
    clrHeaderKolona = &HF2E1D9   ' #D9E1F2 - svetlo plava za zaglavlja kolona

    ' Pozadina detalja forme
    frm.Detail.BackColor = clrPozadina

    ' Podešavanje svih kontrola
    For Each ctl In frm.Controls
        Select Case ctl.ControlType
            Case acTextBox, acComboBox, acListBox
                ctl.BackColor = vbWhite
                ctl.ForeColor = vbBlack
                On Error Resume Next
                ctl.FontName = "Segoe UI"
                ctl.FontSize = 10
                ctl.FontWeight = 400 ' Regular
                On Error GoTo 0

            Case acLabel
                ctl.BackColor = clrHeaderKolona
                ctl.ForeColor = vbBlack
                On Error Resume Next
                ctl.FontName = "Segoe UI"
                ctl.FontSize = 11
                ctl.FontWeight = 700 ' Bold
                On Error GoTo 0
        End Select
    Next ctl

    ' Boja i stil zaglavlja forme (ako postoji)
    On Error Resume Next
    frm.Section(acHeader).BackColor = clrZaglavlje
    Dim ctlHeader As control
    For Each ctlHeader In frm.Section(acHeader).Controls
        If ctlHeader.ControlType = acLabel Then
            ctlHeader.FontName = "Segoe UI Semibold"
            ctlHeader.FontSize = 14
            ctlHeader.FontWeight = 700
            ctlHeader.ForeColor = vbBlack
        End If
    Next ctlHeader
    On Error GoTo 0
End Sub

