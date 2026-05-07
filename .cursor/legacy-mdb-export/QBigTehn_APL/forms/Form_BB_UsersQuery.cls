VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BB_UsersQuery"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Const imeTMPupita = "~TmpUserQueryDesign~"
Private Function F_PrimeniUslove()
 Me.Requery
End Function
Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub
Private Sub DugmeNoviSlog_Click()
On Error GoTo Err_DugmeNoviSlog_Click


    DoCmd.GoToRecord , , acNewRec
    On Error Resume Next
    DoCmd.GoToControl "RBr"

Exit_DugmeNoviSlog_Click:
    Exit Sub

Err_DugmeNoviSlog_Click:
    MsgBox err.Description
    Resume Exit_DugmeNoviSlog_Click
    
End Sub

Private Sub Form_Open(Cancel As Integer)
DoCmd.Maximize

 If UserUGrupi(CurrentUser, "PowerfulUsers") Then
   Me!DugmeExecute.Visible = True
   Me!Label_ImeUBazi.Visible = True
   Me!ImeUBazi.Visible = True
 End If
End Sub

Private Sub ImeObjekta_DblClick(Cancel As Integer)
    OtvoriObjekatUDizajnModu Me!TipObjekta, Me!ImeObjekta
End Sub

Private Sub ImeUBazi_DblClick(Cancel As Integer)
    Me!ImeUBazi = IzberiMDBFajl(Me!ImeUBazi)
End Sub

Private Sub DugmeExecute_Click()
On Error GoTo Err_DugmeExecute_Click

    Dim retVal As Boolean
    Dim recaff As Long
    If Nz(Me!ImeUBazi, "") = "" Then
       Me!ImeUBazi = CurrentDb.Name
       Me!ImeUBazi.Requery
       DoEvents
    End If
    retVal = QueryExecute(Me!ImeUBazi, Me!QSQLText, recaff)
    MsgBox "Uspešno= " & retVal & vbCrLf & "RecordsAffected= " & recaff, vbInformation, "QMegaTeh"

Exit_DugmeExecute_Click:
    Exit Sub

Err_DugmeExecute_Click:
    MsgBox err.Description
    Resume Exit_DugmeExecute_Click
    
End Sub

Private Function SQLEdit(Optional inputSQLText = "") As Boolean
On Error GoTo err_Func
Dim OkRetVal As Boolean
Dim qDef As DAO.QueryDef
'Dim imeTMPupita As String
Dim SQLText As String

    'imeTMPupita = "~TmpUserQueryDesign~"
    SQLText = Nz(inputSQLText, "SELECT 1")
    OkRetVal = True
'On Error Resume Next
    If PostojiQuery(imeTMPupita) Then
        CurrentDb.QueryDefs.Delete imeTMPupita
    End If
    Set qDef = CurrentDb.CreateQueryDef(imeTMPupita, SQLText)
    DoCmd.OpenQuery imeTMPupita, acViewDesign
    Set qDef = Nothing
exit_Func:
    SQLEdit = OkRetVal
Exit Function
err_Func:
 OkRetVal = False
 BBErrorMSG err, "SQLEdit"
 Resume exit_Func
End Function

Private Sub QSQLText_DblClick(Cancel As Integer)
 SQLEdit Me!QSQLText
End Sub
Private Sub FFQSQLText_DblClick(Cancel As Integer)
  SQLEdit Me!QSQLText
End Sub
Private Sub ExportXLSX_Click()
On Error GoTo Err_ExportXLSX_Click

    Dim stDocName As String

    stDocName = Me!QName ' "~TmpUserQueryDesign~"
    'stDocName = "SELECT * FROM R_Artikli;"
    If BBExportXLS(stDocName, Me!QName) Then
     BBMsgBox_BigBit "QBigTehn", "Podaci su uspešno exportovani"
    Else
     BBMsgBox_BigBit "QBigTehn", "Podaci NISU uspešno exportovani!"
    End If
    

Exit_ExportXLSX_Click:
    Exit Sub

Err_ExportXLSX_Click:
    MsgBox err.Description
    Resume Exit_ExportXLSX_Click
    
End Sub
Private Sub DugmeSnimiUpit_Click()
On Error GoTo Err_DugmeSnimiUpit_Click
Dim stPitanje As String

    DoCmd.RunCommand acCmdSaveRecord
    
    If Not Me!QName Like "UQ_*" Then
     MsgBox "Ime upita mora poèinjati sa UQ_" & vbCrLf & vbCrLf & "Promenite ime i pokušajte ponovo.", vbInformation, "QMegaTeh"
     Exit Sub
    End If
    If PostojiQuery(Me!QName) Then
     stPitanje = "Upit " & Me!QName & " veæ postoji." & vbCrLf
     stPitanje = stPitanje & vbCrLf & "Da li želite da ga promenite?"
     If BBPitanje(stPitanje) Then
      CurrentDb.QueryDefs.Delete Me!QName
     Else
      Exit Sub
     End If
    End If
    
    If KreirajUpitUBazi("CurrentDb", Me!QName, Me!QSQLText) Then
       BBMsgBox_BigBit "QBigTehn", "Uspešno"
    Else
       BBMsgBox_BigBit "QBigTehn", "Nije uspelo!"
    End If
    
Exit_DugmeSnimiUpit_Click:
    Exit Sub

Err_DugmeSnimiUpit_Click:
    BBErrorMSG err
    Resume Exit_DugmeSnimiUpit_Click
    
End Sub
Private Sub DugmeOpenQuery_Click()
On Error GoTo Err_DugmeOpenQuery_Click

    Dim stDocName As String
    
   stDocName = Me!QName
   If Nz(stDocName, "") = "" Then
    Exit Sub
   End If
   If PostojiQuery(stDocName) Then
    DoCmd.OpenQuery stDocName, acViewNormal, acReadOnly
   Else
    BBMsgBox_BigBit "QBigTehn", "Ne postoji upit [" & stDocName & "]"
   End If

Exit_DugmeOpenQuery_Click:
    Exit Sub

Err_DugmeOpenQuery_Click:
    MsgBox err.Description
    Resume Exit_DugmeOpenQuery_Click
    
End Sub
Private Sub DugmePrint_Click()
On Error GoTo Err_DugmePrint_Click

    Dim stDocName As String

    stDocName = "BB_UsersQuery"
    DoCmd.OpenReport stDocName, acPreview

Exit_DugmePrint_Click:
    Exit Sub

Err_DugmePrint_Click:
    MsgBox err.Description
    Resume Exit_DugmePrint_Click
    
End Sub
