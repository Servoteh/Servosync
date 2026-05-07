Attribute VB_Name = "DocDatabase_Module"
Option Compare Database
Option Explicit

Public Sub DocDatabase()
 '====================================================================
 ' Name:    DocDatabase
 ' Purpose: Documents the database to a series of text files
 '
 ' Author:  Arvin Meyer
 ' Date:    June 02, 1999
 ' Comment: Uses the undocumented [Application.SaveAsText] syntax
 '          To reload use the syntax [Application.LoadFromText]
 '      Modified to set a reference to DAO 8/22/2005
 '***********************************************************
 'Application.LoadFromText acForm,"MyForm","c:\from.txt"
 '====================================================================
On Error GoTo Err_DocDatabase
Dim dbs As DAO.Database
Dim cnt As DAO.Container
Dim doc As DAO.Document
Dim i As Integer

Set dbs = CurrentDb() ' use CurrentDb() to refresh Collections

Set cnt = dbs.Containers("Forms")
For Each doc In cnt.Documents
    Application.SaveAsText acForm, doc.Name, "D:\Document\" & doc.Name & ".txt"
Next doc

Set cnt = dbs.Containers("Reports")
For Each doc In cnt.Documents
    Application.SaveAsText acReport, doc.Name, "D:\Document\" & doc.Name & ".txt"
Next doc

Set cnt = dbs.Containers("Scripts")
For Each doc In cnt.Documents
    Application.SaveAsText acMacro, doc.Name, "D:\Document\" & doc.Name & ".txt"
Next doc

Set cnt = dbs.Containers("Modules")
For Each doc In cnt.Documents
    Application.SaveAsText acModule, doc.Name, "D:\Document\" & doc.Name & ".txt"
Next doc

For i = 0 To dbs.QueryDefs.Count - 1
    Application.SaveAsText acQuery, dbs.QueryDefs(i).Name, "D:\Document\" & dbs.QueryDefs(i).Name & ".txt"
Next i

Set doc = Nothing
Set cnt = Nothing
Set dbs = Nothing

Exit_DocDatabase:
    Exit Sub


Err_DocDatabase:
    Select Case err

    Case Else
        MsgBox err.Description
        Resume Exit_DocDatabase
    End Select

End Sub
