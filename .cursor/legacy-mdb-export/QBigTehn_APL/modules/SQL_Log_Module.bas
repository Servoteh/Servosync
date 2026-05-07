Attribute VB_Name = "SQL_Log_Module"
Option Compare Database
Option Explicit
Private Declare PtrSafe Function GetComputerName Lib "kernel32" Alias "GetComputerNameA" ( _
    ByVal lpBuffer As String, nSize As Long) As Long

Public Sub KreirajSQLLogTabelu()
    On Error GoTo Err_Handler
    
    Dim db As DAO.Database
    Dim tdf As DAO.TableDef
    Dim sql As String
    Dim tabelaPostoji As Boolean
    
    Set db = CurrentDb
    tabelaPostoji = False
    
    ' proveri da li tabela veæ postoji
    For Each tdf In db.TableDefs
        If tdf.Name = "SQL_Log" Then
            tabelaPostoji = True
            Exit For
        End If
    Next
    
    If tabelaPostoji Then
        MsgBox "Tabela SQL_Log veæ postoji – nije kreirana ponovo.", vbInformation
    Else
        sql = ""
        sql = sql & "CREATE TABLE SQL_Log (" & vbCrLf
        sql = sql & "   ID AUTOINCREMENT PRIMARY KEY," & vbCrLf
        sql = sql & "   DatumVreme DATETIME," & vbCrLf
        sql = sql & "   SQLText LONGTEXT," & vbCrLf
        sql = sql & "   DurationSec DOUBLE," & vbCrLf
        sql = sql & "   UserName TEXT(50)," & vbCrLf
        sql = sql & "   Status TEXT(20)," & vbCrLf
        sql = sql & "   ErrorMessage LONGTEXT" & vbCrLf
        sql = sql & ")"
        
        db.Execute sql, dbFailOnError
        MsgBox "Tabela SQL_Log je uspešno kreirana.", vbInformation
    End If
    
Exit_Point:
    On Error Resume Next
    Set db = Nothing
    Exit Sub
    
Err_Handler:
    MsgBox "Greška: " & err.Description, vbCritical
    Resume Exit_Point
End Sub

Public Sub LogSQL(ByVal strSQL As String, ByVal duration As Double, ByVal Status As String, Optional ByVal errMsg As String = "")
    On Error Resume Next
    
    Dim db As DAO.Database
    Dim strInsert As String
    
    Set db = CurrentDb
    
    strInsert = "INSERT INTO SQL_Log (DatumVreme, SQLText, DurationSec, UserName, Status, ErrorMessage) " & _
                "VALUES (Now(), " & _
                "'" & Replace(strSQL, "'", "''") & "', " & _
                duration & ", " & _
                "'" & Environ("Username") & "', " & _
                "'" & Status & "', " & _
                IIf(errMsg = "", "Null", "'" & Replace(errMsg, "'", "''") & "'") & ")"
    
    db.Execute strInsert
End Sub


