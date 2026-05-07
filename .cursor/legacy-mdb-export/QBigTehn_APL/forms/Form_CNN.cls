VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_CNN"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Function PrikaziPodatkeNaPodformi()

   If GetParFromCnnString("DRIVER=", Nz(Me!CNNString, "")) Like "*SQL*" Then
      Me!CNNType = "SQL"
      Me!Podforma.SourceObject = "CNN_SQL"
   ElseIf GetParFromCnnString("PROVIDER=", Nz(Me!CNNString, "")) Like "*JET*" Then
      Me!CNNType = "Access"
      Me!Podforma.SourceObject = "CNN_Access"
   End If
   
    Me!Podforma.Form.RasclaniCNNString
    
End Function

Private Sub ReadPropertyFromAPL(Optional ShowErrMsg As Boolean = True)

 Dim stTMP As String
 stTMP = Nz(BBReadProperty(Me!CNNStringName, ShowErrMsg), "")
 If stTMP <> "" Then
  Me!CNNString = stTMP
 End If
 
 PrikaziPodatkeNaPodformi
 
End Sub

Private Function PronadjiCNNStringName(CNNStringName As Variant) As Boolean
On Error GoTo Err_Point
    Dim rs As Object
    Dim retValOk As Boolean
    'Dim rs As dao.Recordset
    
    Set rs = Me.Recordset.Clone
    rs.FindFirst "[CNNStringName] = '" & Nz(CNNStringName, "") & "'"
    'If Not rs.EOF Then
    If rs![CNNStringName] = Nz(CNNStringName, "") Then
        Me.Bookmark = rs.Bookmark
        ReadPropertyFromAPL False
        retValOk = True
    Else
        retValOk = DodajNoviCNNString(CNNStringName)
    End If
    
Exit_Point:
On Error Resume Next
   PronadjiCNNStringName = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "Pronadji(" & "'" & Nz(CNNStringName, "") & "')"
    retValOk = False
    Resume Exit_Point
End Function

Private Sub CNNString_AfterUpdate()
    PrikaziPodatkeNaPodformi
End Sub

Private Sub CNNType_AfterUpdate()
On Error GoTo Err_Point
 If Me!CNNType = "SQL" Then
      Me!Podforma.SourceObject = "CNN_SQL"
 Else
      Me!Podforma.SourceObject = "CNN_Access"
 End If
 
 PrikaziPodatkeNaPodformi
 
Exit_Point:
 On Error Resume Next
Exit Sub
Err_Point:
 BBErrorMSG err, "CNNType_AfterUpdate"
 Resume Exit_Point
End Sub

Private Sub ComboCNNStringName_AfterUpdate()
    PronadjiCNNStringName Me!ComboCNNStringName
End Sub

Private Function DodajNoviCNNString(ByVal NewData As String, Optional PitajZaPotvrdu As Boolean = True) As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim DodajStvarno As Boolean

If Trim(NewData) = "" Then
    DodajStvarno = False
    retValOk = False
    GoTo Exit_Point
End If

If PitajZaPotvrdu Then
    DodajStvarno = BBPitanje("Da li želite da unesete novu vrednost=" & NewData & " u tabelu?", vbDefaultButton2)
Else
  DodajStvarno = True
End If

If DodajStvarno Then
    DoCmd.GoToRecord , , acNewRec
    Me!CNNStringName = Trim(NewData)
    DoCmd.Save
    retValOk = True
Else
    retValOk = False
End If

Exit_Point:
 On Error Resume Next
 DodajNoviCNNString = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DodajNoviCNNString"
 retValOk = False
 Resume Exit_Point
End Function

Private Sub ComboCNNStringName_DblClick(Cancel As Integer)
    ReadPropertyFromAPL
End Sub

Private Sub DugmeTestConnection_Click()
 Dim stPoruka As String
    If ADO_TestConnection(Me!CNNString, 15) Then
       stPoruka = "Test uspešan"
       MsgBox stPoruka, vbInformation, "QBigBit_LIB"
    Else
       stPoruka = "Test neuspešan"
       MsgBox stPoruka, vbExclamation, "QBigBit_LIB"
    End If
End Sub
Private Function WritePropertyToAPL()
  BBCreateProperty Me!CNNStringName, , Nz(Me!CNNString, "")
End Function
Private Sub DugmeWritePropertyToAPL_Click()
    WritePropertyToAPL
End Sub

Private Sub Form_Close()
    LIB_CFGRW.CNNReset
End Sub

Private Sub Form_Current()
    Me!ComboCNNStringName = Me!CNNStringName
    PronadjiCNNStringName Me!ComboCNNStringName
End Sub

Private Sub Form_Open(Cancel As Integer)

 If CurrentUser <> "Negovan" Then
    Me!CNNString.Visible = False
    Me!DugmeWritePropertyToAPL.Enabled = False
 End If
 
 Me!ComboCNNStringName = Nz(OpenArgs, "")
 PronadjiCNNStringName Me!ComboCNNStringName
 
End Sub
Private Sub DugmeResetCFG_Click()
On Error GoTo Err_DugmeResetCFG_Click

    
   Me!CNNString = BBReadProperty(Me!CNNStringName)
   PrikaziPodatkeNaPodformi

Exit_DugmeResetCFG_Click:
    Exit Sub

Err_DugmeResetCFG_Click:
    MsgBox err.Description
    Resume Exit_DugmeResetCFG_Click
    
End Sub

