Attribute VB_Name = "LIB_Utility"
Option Compare Database
Option Explicit

Public Function FindRecordOnForm(ByRef frm As Form, stFind As String) As Boolean
 
 On Error Resume Next

Dim rs As Object
Dim retValOk As Boolean

    Set rs = frm.Recordset.Clone
    If TypeOf rs Is ADODB.Recordset Then
        rs.Find stFind
    Else
        rs.FindFirst stFind
    End If
    If Not rs.EOF Then
        frm.Bookmark = rs.Bookmark
        retValOk = True
    Else
        retValOk = False
    End If

Exit_Point:
On Error Resume Next
 FindRecordOnForm = retValOk
 
 rs.Close
 Set rs = Nothing
 
Exit Function

Err_Point:
    BBErrorMSG err, "FindRecordOnForm"
    retValOk = False
    Resume Exit_Point
End Function
