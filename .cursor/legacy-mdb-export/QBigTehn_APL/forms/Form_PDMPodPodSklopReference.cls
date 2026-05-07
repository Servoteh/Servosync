VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PDMPodPodSklopReference"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Dim formInitialized As Boolean


Private Sub Form_Current()
    If Not formInitialized Then
        formInitialized = True
        Exit Sub
    End If
    
    ' Poziv funkcije u drugoj podformi:
    If Not Me.NewRecord Then
        'Forms!frmGlavna!PodFrmB.Form.PrimeniUslove Me!IDCrtez
        PrikaziZaPodPodSklopReference Me!TrebaIDCrtez
    End If
End Sub

Private Sub Form_Load()
    formInitialized = False
    
End Sub
Public Function PrikaziZaPodPodSklopReference(Optional parIDCrtez)
On Error GoTo Err_Point

 Dim pIDCrtezZaPrikaz As Long
 Dim retValOk As Boolean
 Dim PodFrmD As Form
    
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

    PDMSklop.ZaPodPodSklopTrebaIDCrtez = pIDCrtezZaPrikaz
   
    'If pIDCrtezZaPrikaz <> 0 Then
        Forms("PDMSklop").Controls("PodFrmE").SourceObject = "Form.PDMPodPodPodSklopReference"
    'End If
 
Exit_Point:
On Error Resume Next
   PrikaziZaPodPodSklopReference = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziZaPodSklopReference"
 retValOk = False
 Resume Exit_Point
End Function

Private Sub Form_Open(Cancel As Integer)
    BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
    PrikaziZaPodPodSklopReference
End Sub

