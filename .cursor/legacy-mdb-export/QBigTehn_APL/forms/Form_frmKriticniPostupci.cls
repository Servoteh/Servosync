VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_frmKriticniPostupci"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PrimeniUslove()
   BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
   Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
End Function
Private Sub Form_Load()
    PrimeniUslove
    Call ObojiIkonicu
End Sub

Private Sub ObojiIkonicu()
On Error Resume Next

    Dim krit As Integer
    krit = Nz(Me!Kriticnost, 0)
    
    Select Case krit
        Case 3
            Me!txtIkonica = "?"
            Me!txtIkonica.ForeColor = RGB(220, 0, 0)   ' crvena
        Case 2
            Me!txtIkonica = "?"
            Me!txtIkonica.ForeColor = RGB(255, 140, 0) ' narandžasta
        Case 1
            Me!txtIkonica = "?"
            Me!txtIkonica.ForeColor = RGB(255, 200, 0) ' žuta
        Case Else
            Me!txtIkonica = ""
    End Select

End Sub

Private Sub Form_Current()
    Call ObojiIkonicu
End Sub


