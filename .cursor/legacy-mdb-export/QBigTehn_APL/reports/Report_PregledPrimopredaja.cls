VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Report_PregledPrimopredaja"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub Detail0_Print(Cancel As Integer, PrintCount As Integer)
    'DrawBoxArroundAllDetailControls Me
End Sub

Private Sub Report_Open(Cancel As Integer)
    SetProperlyRecordSource BBCFG.CNNString, Me, "ODBC_ftPregledRNZaPrimopredaju"
    PostaviNaslovPoStatusu
End Sub
Private Sub PostaviNaslovPoStatusu()
    On Error Resume Next

    Dim stArg As Long
    stArg = Forms![PregledPrimopredaje]!ZaIDStatusPrimopredaje 'LCase$(Trim$(Nz(Me.OpenArgs, "")))

    Select Case stArg
        Case 1 '"odobren", "saglasan", "saglasnost"
            Me!lblNaslov.Caption = "Pregled odobrenih primopredaja"

        Case 3 '"lansiran", "lansirano"
            Me!lblNaslov.Caption = "Pregled lansiranih primopredaja"

        Case 2 '"odbijen", "odbijeno"
            Me!lblNaslov.Caption = "Pregled odbijenih primopredaja"

        Case 0 '"obrada", "u obradi"
            Me!lblNaslov.Caption = "Pregled primopredaja u obradi"

        Case Else
            Me!lblNaslov.Caption = "Pregled svih primopredaja"
    End Select

    On Error GoTo 0
End Sub

Private Sub PrimeniKolonePoStatusu()
    On Error Resume Next

    Dim stArg As Long
    stArg = Forms![PregledPrimopredaje]!ZaIDStatusPrimopredaje

    Select Case stArg
        Case 1 '"odobren", "saglasan", "saglasnost"
            ' sakrij status
            SetCtrlVis False, "Status"

            ' prikaži odobrio + datum
            SetCtrlVis True, "PrimopredajuOdobrio"
            SetCtrlVis True, "lblPrimopredajuOdobrio"
            SetCtrlVis True, "DatumOdobravanja"
            SetCtrlVis True, "lblDatumOdobravanja"

            ' sakrij lansirano
            SetCtrlVis False, "PrimopredajuLansirao"
            SetCtrlVis False, "lblPrimopredajuLansirao"
            SetCtrlVis False, "DatumLansiranja"
            SetCtrlVis False, "lblDatumLansiranja"

        Case 3 '"lansiran", "lansirano"
            ' sakrij status
            SetCtrlVis False, "Status"

            ' prikaži lansirao + datum
            SetCtrlVis True, "PrimopredajuLansirao"
            SetCtrlVis True, "lblPrimopredajuLansirao"
            SetCtrlVis True, "DatumLansiranja"
            SetCtrlVis True, "lblDatumLansiranja"

            ' sakrij odobreno
            SetCtrlVis False, "PrimopredajuOdobrio"
            SetCtrlVis False, "lblPrimopredajuOdobrio"
            SetCtrlVis False, "DatumOdobravanja"
            SetCtrlVis False, "lblDatumOdobravanja"

            PomeriLansiraneNaMestoOdobrenih_Report

        Case Else
            ' sve ostalo / svi – prikaži status, sakrij oba seta
            SetCtrlVis True, "Status"

            SetCtrlVis False, "PrimopredajuOdobrio"
            SetCtrlVis False, "lblPrimopredajuOdobrio"
            SetCtrlVis False, "DatumOdobravanja"
            SetCtrlVis False, "lblDatumOdobravanja"

            SetCtrlVis False, "PrimopredajuLansirao"
            SetCtrlVis False, "lblPrimopredajuLansirao"
            SetCtrlVis False, "DatumLansiranja"
            SetCtrlVis False, "lblDatumLansiranja"
    End Select

    On Error GoTo 0
End Sub

Private Sub SetCtrlVis(ByVal bVisible As Boolean, ByVal ctlName As String)
    On Error Resume Next
    Me.Controls(ctlName).Visible = bVisible
    On Error GoTo 0
End Sub

Private Sub PomeriLansiraneNaMestoOdobrenih_Report()
    On Error Resume Next

    Me!PrimopredajuLansirao.Left = Me!PrimopredajuOdobrio.Left
    Me!lblPrimopredajuLansirao.Left = Me!lblPrimopredajuOdobrio.Left

    Me!DatumLansiranja.Left = Me!DatumOdobravanja.Left
    Me!lblDatumLansiranja.Left = Me!lblDatumOdobravanja.Left

    On Error GoTo 0
End Sub

