Attribute VB_Name = "Rest"
Option Compare Database
Option Explicit

Global DemoApl As Boolean

Public Function NumberOfRecords(TableName As String) As Long
  On Error GoTo err_NumberOfRecords
    Dim dbs As DAO.Database, rst As DAO.Recordset
    Dim retNumber

    ' Return reference to current database.
    Set dbs = CurrentDb
    ' Open table-type Recordset object.
    Set rst = dbs.OpenRecordset(TableName)
    If rst.EOF Then
        retNumber = 0
    Else
        rst.MoveLast
        retNumber = rst.RecordCount
    End If
exit_NumberOfRecords:
    
    On Error Resume Next
    rst.Close
    Set rst = Nothing
    dbs.Close
    Set dbs = Nothing
    NumberOfRecords = retNumber
Exit Function
err_NumberOfRecords:
    Select Case err.Number
        Case 3078
        MsgBox "Tabela " & TableName & " ne postoji u ovoj bazi!", vbCritical + vbOKOnly
    Case Else
    MsgBox err.Description
    End Select
    
    retNumber = 0
    Resume exit_NumberOfRecords
End Function

Public Sub CheckRun()
On Error GoTo Err_CheckRun
 Dim dbs As DAO.Database, rst As DAO.Recordset
 Dim KrajRada As Boolean
 Dim msgtxt As String
 
 'If CurrentUser() = "Demo" Then DemoApl = True Else DemoApl = False
 If CurrentUser() = "Demo" Then
    DemoApl = True
 Else
    DemoApl = False
 End If
    ' Return reference to current database.
    Set dbs = CurrentDb
    ' Open table-type Recordset object.
    Set rst = dbs.OpenRecordset("MSysTab")
    KrajRada = False
    
    rst.MoveFirst
    Do
    'msgtxt = msgtxt & " " & rst![name]
        If NumberOfRecords(rst![Name]) < rst![NoRecords] Then
          KrajRada = KrajRada Or False
        Else
    '      msgtxt = msgtxt & " " & rst![name]
          KrajRada = True
        End If
     rst.MoveNext
    Loop While Not rst.EOF
    
    rst.Close
    Set rst = Nothing
    dbs.Close
    Set dbs = Nothing
    ' MsgBox ("DemoApl = " & DemoApl)
Exit_CheckRun:

If KrajRada And DemoApl Then
    RegUser (2)
    'MsgBox (msgtxt)
    Quit
End If
Exit Sub
Err_CheckRun:
    KrajRada = True
    msgtxt = msgtxt & " Neki error!"
    Resume Exit_CheckRun
End Sub

Public Function F_CheckRun()
    CheckRun
End Function

Public Sub RegUser(ind As Byte)
'Modifikovano: 12-12-2020
'Prestaje se sa koriscenjem tabele MsysAccess

On Error GoTo Err_RegStart


Exit Sub

'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
'OVO ISPODSE NE IZVRŠAVA!!
'!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

 Dim dbs As DAO.Database, rst As DAO.Recordset
 
  If Not PostojiPoljeUTabeli("SysUserName", CurrentDb.TableDefs("MsysAccess")) Then
    Call KreirajPoljeUTabeli(ImeFajlaZaTabelu("MsysAccess"), "MsysAccess", "SysUserName", dbText, 20)
  End If
 
    ' Return reference to current database.
    Set dbs = CurrentDb
    ' Open table-type Recordset object.
    Set rst = dbs.OpenRecordset("MSysAccess")
        
    rst.AddNew
    rst!dstart = ind
    rst![DTime] = Now()
     If PostojiPoljeUTabeli("SysUserName", CurrentDb.TableDefs("MsysAccess")) Then
      rst![DUser] = Left(CurrentUser(), rst![DUser].Size)
      rst![SysUserName] = Left(Environ("UserName"), rst![SysUserName].Size)
     Else
      rst![DUser] = Left(Environ("UserName") & "/" & CurrentUser(), rst![DUser].Size)
     End If
    rst![DLevel] = F_NivoBaze()
    rst![DMachine] = GetComputerName()
    rst.Update
       
Exit_RegStart:
    On Error Resume Next
    rst.Close
    Set rst = Nothing
    dbs.Close
    Set dbs = Nothing
Exit Sub

Err_RegStart:
    Select Case err.Number
    Case Else
    MsgBox err.Description
    End Select
    
    Resume Exit_RegStart
End Sub


