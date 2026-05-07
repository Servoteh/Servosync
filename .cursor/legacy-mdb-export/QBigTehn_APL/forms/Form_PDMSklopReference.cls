VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PDMSklopReference"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Dim formInitialized As Boolean
Public Function PrimeniUslove()
On Error GoTo Err_PrimeniUslove_Point
   
    SetProperlyRecordSource BBCFG.CNNString, Me
    
Exit_PrimeniUslove_Point:
    On Error Resume Next
    Exit Function

Err_PrimeniUslove_Point:
    MsgBox err.Description
    Resume Exit_PrimeniUslove_Point
End Function

Private Sub Form_Current()
    If Not formInitialized Then
        formInitialized = True
        Exit Sub
    End If
    
    ' Poziv funkcije u drugoj podformi:
    If Not Me.NewRecord Then
        'Forms!frmGlavna!PodFrmB.Form.PrimeniUslove Me!IDCrtez
        PrikaziReference Me!TrebaIDCrtez
        OsveziNiziNivo
    End If
    
End Sub

Private Sub Form_Load()
    formInitialized = False
'    PrimeniUslove
End Sub
Private Sub OsveziNiziNivo()
    On Error Resume Next

    Dim frmSledeca As Form
    Dim lngIDCrtez As Long
    Dim rs As Object ' ADO Recordset

    ' Referenca na sledeæu podformu
    Set frmSledeca = Forms!PDMSklop.Controls("PodFrmC").Form
    Set rs = frmSledeca.Recordset

    If Not (rs Is Nothing) Then
        If Not rs.EOF Then
            'rs.MoveFirst
            'lngIDCrtez = Nz(rs.Fields("TrebaIDCrtez").Value, 0)
            'PDMSklop.TrebaIDCrtez = lngIDCrtez
            'Forms!PDMSklop!PodFrmC.Form.PrimeniUslove
        Else
            PDMSklop.ZaPodSklopTrebaIDCrtez = -1
            Forms!PDMSklop!PodFrmC.Form.PrimeniUslove
        End If
    End If

    On Error GoTo 0
End Sub

Private Sub Form_Open(Cancel As Integer)
    SetProperlyRecordSource BBCFG.CNNString, Me
    PrikaziReference
End Sub
Public Function PrikaziReference(Optional parIDCrtez)
On Error GoTo Err_Point

 Dim pIDCrtezZaPrikaz As Long
 Dim retValOk As Boolean
 Dim PodFrmC As Form
    
    retValOk = True
 
    
    If Not IsMissing(parIDCrtez) Then
        pIDCrtezZaPrikaz = parIDCrtez
    ElseIf Not (Me.Recordset.BOF And Me.Recordset.EOF) Then
        ' Postoji bar jedan zapis, bezbedno èitati polje
        pIDCrtezZaPrikaz = Nz(Me!TrebaIDCrtez, 0)
    Else
        ' Nema zapisa – fallback
        pIDCrtezZaPrikaz = 0
    End If

    PDMSklop.TrebaIDCrtez = pIDCrtezZaPrikaz
   
    'If pIDCrtezZaPrikaz <> 0 Then
        On Error Resume Next
        Forms("PDMSklop").Controls("PodFrmC").SourceObject = "Form.PDMPodSklopReference"
    'End If
    
    On Error GoTo 0
    'On Error GoTo err_Point
 
Exit_Point:
On Error Resume Next
   PrikaziReference = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziReference"
 retValOk = False
 Resume Exit_Point
End Function

