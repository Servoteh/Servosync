VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Zastita"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub APLHDSn_DblClick(Cancel As Integer)
On Error Resume Next
    Me!APLHDSn = CurrentDb.Properties("BBHDSn").Value
End Sub

Private Sub DigmeWritePropToAPL_Click()
  If BBCreateProperty("BBHDSn", dbText, BBReadRealHDSN()) Then
    MsgBox "Uspešno je kreiran Property BBHDSn.", vbInformation, "QMegaTeh"
  Else
    MsgBox "Nije kreiran Property BBHDSn.", vbExclamation, "QMegaTeh"
  End If
End Sub

Private Sub DugmeReadFromReg_Click()
    Me!RegHDSN = Zastita.BBReadFromRegHDSN()
    Me!RegName = Zastita.BBReadFromRegName()
    If Nz(Me!RegKeyR, "") <> "" Then
        Me!RegValR = Zastita.BBReadRegKey(Me!RegKeyR)
    End If
End Sub

Private Sub DugmeReadReal_Click()
    Me!RealHDSN = Zastita.BBReadRealHDSN()
End Sub

Private Sub DugmeWiteToReg_Click()
    Zastita.BBWriteToRegHDSN
End Sub

Private Sub DugmeWriteToRegSPEC_Click()
 If Nz(Me!RegKeyW, "") <> "" Then 'And Not IsNull(Me!RegValW) Then
    Me!CheckWriteToRegSpec = Zastita.BBWriteRegKey(Me!RegKeyW, Nz(Me!RegValW, ""))
 Else
    Me!CheckWriteToRegSpec = False
 End If
End Sub

Private Sub Form_Open(Cancel As Integer)
Dim retVal As String
    SetClipboard GetComputerName()
    If Zastita.DozvoljenoPostavljenjeZastite() Then
        Me!RegGrana = "Registry: " & Zastita.RegGrana & Zastita.ProgName
    Else
       ' DoCmd.Quit
       QuitBigBit
    End If
    
End Sub

Private Sub RegKeyR_AfterUpdate()
    If Nz(Me!RegKeyR, "") <> "" Then
        Me!RegValR = Zastita.BBReadRegKey(Me!RegKeyR)
    End If
End Sub

Private Sub RegKeyW_AfterUpdate()
    Me!CheckWriteToRegSpec = Null
End Sub

Private Sub RegValW_AfterUpdate()
     Me!CheckWriteToRegSpec = Null
End Sub
