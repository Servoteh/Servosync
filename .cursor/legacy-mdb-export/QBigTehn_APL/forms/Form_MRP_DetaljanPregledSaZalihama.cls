VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_MRP_DetaljanPregledSaZalihama"
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

Private Sub DugmeKreirajPlan_Click()

    On Error GoTo Err_Point

    Dim rs As ADODB.Recordset
    Dim IDPlan As Long
    Dim pZaIDPotreba As Long
    
    'If IsNull(Forms![MRP_Pregled]![Podforma].Form![IDPotreba]) Then
    If IsNull(Me.[IDPotreba]) Then
        MsgBox "Izaberi MRP potrebu", vbExclamation
        Exit Sub
    End If
    
    'If Nz(Forms![MRP_Pregled]![Podforma].Form![IDPlan], 0) <> 0 Then
    If Nz(Me.[IDPlan], 0) <> 0 Then
        If MsgBox("Plan veæ postoji. Otvori ga?", vbQuestion + vbYesNo) = vbYes Then
            DoCmd.OpenForm "PlaniranjeNabavke", , , "IDPlan=" & Me.[IDPlan] 'Forms![MRP_Pregled]![Podforma].Form![IDPlan]
        End If
        Exit Sub
    End If

    pZaIDPotreba = Me.IDPotreba 'Forms![MRP_Pregled]![Podforma].Form![IDPotreba]

    ' 1. Napuni TMP
    Call NapuniTMP_MRP_Stanje(pZaIDPotreba)
    
    
    ' 2. Kreiraj plan
    Set rs = ADO_GetRSTFromSP( _
        CNN_CurrentDataBase, _
        "spMRP_KreirajIRealizujPlan", _
        pZaIDPotreba, _
        CurrentUser() _
    )

    If Not rs.EOF Then

        IDPlan = rs!IDPlan

        MsgBox _
            "Plan uspešno kreiran!" & vbCrLf & vbCrLf & _
            "Broj stavki: " & rs!BrojStavki & vbCrLf & _
            "Rezervisano: " & Format(rs!UkupnoRezervisano, "0.##") & vbCrLf & _
            "Za nabavku: " & Format(rs!UkupnoZaNabavku, "0.##"), _
            vbInformation, "MRP Plan"
        
        DoCmd.OpenForm "PlaniranjeNabavke", , , "IDPlan=" & IDPlan
        
        'While IsLoaded("PlaniranjeNabavke")
        '    DoEvents
        'Wend
        PrimeniUslove
    End If
    
    
Exit_Point:
    Exit Sub

Err_Point:
    MsgBox err.Description, vbCritical, "Greška"
End Sub

Private Sub Form_Load()
    PrimeniUslove
End Sub


Private Sub Detail_Paint()
    Select Case Me.ColorKey
        Case 1
            Me.Detail.BackColor = RGB(235, 235, 235)  ' siva
        Case 2
            Me.Detail.BackColor = RGB(255, 255, 240) 'RGB(255, 250, 205) 'RGB(255, 255, 224) 'RGB(255, 255, 210) 'RGB(255, 242, 204)  ' žuta
        Case 3
            Me.Detail.BackColor = RGB(220, 240, 255)  ' plavièasta
        Case 4
            Me.Detail.BackColor = RGB(226, 239, 218)  ' zelena
        Case 5
            Me.Detail.BackColor = RGB(237, 226, 246)  ' ljubièasta
        Case 6
        Me.Detail.BackColor = RGB(252, 228, 214)  ' narandžasta
    Case Else
        Me.Detail.BackColor = vbWhite
    End Select
    
    
    'If Me.ColorKey = 1 Then
    '    Me.Detail.BackColor = RGB(225, 230, 234)
    'Else
    '    Me.Detail.BackColor = vbWhite
    'End If
    
    
End Sub

