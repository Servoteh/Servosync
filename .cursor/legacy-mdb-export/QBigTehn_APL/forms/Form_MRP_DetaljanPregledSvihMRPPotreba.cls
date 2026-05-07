VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_MRP_DetaljanPregledSvihMRPPotreba"
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



Private Sub Form_Load()
    PrimeniUslove
End Sub


Private Sub Detail_Paint_OLD()
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
    
End Sub
Private Sub Detail_Paint()
On Error GoTo Exit_Point

    Dim vColor As Variant
    
    ' nema recorda
    'If Me.NewRecord Then GoTo DefaultColor
    'If Me.RecordsetClone.RecordCount = 0 Then GoTo DefaultColor
    
    vColor = Null
    
    ' ako kontrola nema vrednost
    vColor = Me!ColorKey.Value
    
    If IsNull(vColor) Then GoTo DefaultColor
    
    Select Case CLng(vColor)
        Case 1
            Me.Detail.BackColor = RGB(235, 235, 235)      ' siva
        Case 2
            Me.Detail.BackColor = RGB(255, 255, 240)      ' žuta
        Case 3
            Me.Detail.BackColor = RGB(220, 240, 255)      ' plava
        Case 4
            Me.Detail.BackColor = RGB(226, 239, 218)      ' zelena
        Case 5
            Me.Detail.BackColor = RGB(237, 226, 246)      ' ljubièasta
        Case 6
            Me.Detail.BackColor = RGB(252, 228, 214)      ' narandžasta
        Case Else
            GoTo DefaultColor
    End Select

    Exit Sub

DefaultColor:
    Me.Detail.BackColor = vbWhite

Exit_Point:
End Sub
Private Sub DugmeDetaljnoMRPPotreba_Click()
On Error GoTo Err_Point_Click

    Dim IDPotreba As Variant
    Dim rs As ADODB.Recordset
    Dim sql As String

    IDPotreba = Nz(Me.IDPotreba, 0)

    ' =====================================
    ' 1. NULL PROVERA
    ' =====================================
    If IsNull(IDPotreba) Or IDPotreba = 0 Then
        MsgBox "Nije izabrana MRP potreba.", vbExclamation
        Exit Sub
    End If

    ' =====================================
    ' 2. ADO PROVERA
    ' =====================================
    sql = "SELECT 1 FROM MRP_Potrebe WHERE IDPotreba=" & IDPotreba

    Set rs = New ADODB.Recordset
    rs.Open sql, CNN_CurrentDataBase, adOpenForwardOnly, adLockReadOnly

    If rs.EOF Then
        MsgBox "MRP potreba ne postoji.", vbCritical
        rs.Close
        Set rs = Nothing
        Exit Sub
    End If

    rs.Close
    Set rs = Nothing

    ' =====================================
    ' 3. OTVORI DETALJ
    ' =====================================
    DetaljnoMRP_Potreba IDPotreba
    
    While IsLoaded("MRP_Potreba")
        DoEvents
    Wend
    PrimeniUslove
    
Exit_Point_Click:
    Exit Sub

Err_Point_Click:
    MsgBox err.Description, vbCritical
    Resume Exit_Point_Click
End Sub

Private Sub DugmeDetaljnoMRPPlan_Click()
On Error GoTo Err_Point_Click

    Dim IDPlan As Variant
    Dim rs As ADODB.Recordset
    Dim sql As String

    IDPlan = Me.IDPlan

    ' =====================================
    ' 1. NULL PROVERA
    ' =====================================
    If IsNull(IDPlan) Or IDPlan = 0 Then
        MsgBox "Za ovu MRP potrebu nije kreiran plan.", vbExclamation
        Exit Sub
    End If

    ' =====================================
    ' 2. ADO PROVERA
    ' =====================================
    sql = "SELECT 1 FROM PDM_Planiranje WHERE IDPlan=" & IDPlan

    Set rs = New ADODB.Recordset
    rs.Open sql, CNN_CurrentDataBase, adOpenForwardOnly, adLockReadOnly

    If rs.EOF Then
        MsgBox "Plan ne postoji (možda je obrisan).", vbCritical
        rs.Close
        Set rs = Nothing
        Exit Sub
    End If

    rs.Close
    Set rs = Nothing

    ' =====================================
    ' 3. OTVORI PLAN
    ' =====================================
    DetaljnoPlaniranjeNabavke IDPlan

Exit_Point_Click:
    Exit Sub

Err_Point_Click:
    MsgBox err.Description, vbCritical
    Resume Exit_Point_Click
End Sub
