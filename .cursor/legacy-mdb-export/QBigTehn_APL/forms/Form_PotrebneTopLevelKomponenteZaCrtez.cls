VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PotrebneTopLevelKomponenteZaCrtez"
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
   PrikaziBrojPodsklopova
End Function


Private Sub Form_Load()
    PrimeniUslove
End Sub
Public Sub PrikaziBrojPodsklopova()

    Dim rs As DAO.Recordset
    Dim lCount As Long

    Set rs = Me.RecordsetClone

    If Not (rs.BOF And rs.EOF) Then
        rs.MoveLast
        lCount = rs.RecordCount
    Else
        lCount = 0
    End If

    rs.Close

    Me!txtBrojPodsklopova = lCount

End Sub
