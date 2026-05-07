Attribute VB_Name = "DecodeSopot"
Option Compare Database
Option Explicit
Global arrZaDekodiranje(1 To 40, 1 To 2) As String

Dim NapunjenNiz As Boolean

Public Function ASCDecode(stRec As String) As String

Dim i As Integer
Dim stRetVal As String

stRetVal = ""
For i = 1 To Len(stRec)
    stRetVal = stRetVal & ChrW(AscW(Mid(stRec, i, 1))) & "=" & CStr(AscW(Mid(stRec, i, 1))) & " "
Next i

ASCDecode = stRetVal
End Function
Public Function UpisiUTabelu(dbSlovo As String, dbKod As Long, acSlovo As String, acKod As Long, dbRec As String, acRec As String) As Boolean

Dim rst As Recordset

Set rst = CurrentDb.OpenRecordset("KodoviSvi")
    
  rst.AddNew
    
    rst!dbSlovo = dbSlovo
    rst!AscB = AscB(dbSlovo)
    rst!Asc = Asc(dbSlovo)
    rst!dbKod = dbKod
    rst!acSlovo = acSlovo
    rst!acKod = acKod
    rst!dbRec = dbRec
    rst!acRec = acRec
  rst.Update
  
  SetClipboard "dbSlovo=" & dbSlovo & " acSlovo=" & acSlovo
  
rst.Close
Set rst = Nothing

End Function
Public Function UpisiKodove(dbRec As String, acRec As String) As Boolean

Dim i As Integer
Dim retValOk As Boolean
Dim dbSlovo As String
Dim dbKod As Long
Dim acSlovo As String
Dim acKod As Long

SetClipboard dbRec & "=>" & acRec
retValOk = True
For i = 1 To Len(Trim(dbRec))
    dbSlovo = Mid(dbRec, i, 1)
    dbKod = AscW(dbSlovo)
    
    acSlovo = Mid(acRec, i, 1)
    acKod = AscW(acSlovo)
    
    
    Call UpisiUTabelu(dbSlovo, dbKod, acSlovo, acKod, dbRec, acRec)
Next i

UpisiKodove = retValOk

End Function
Public Function NapuniNiz()
Dim i As Integer
Dim rst As Recordset

If NapunjenNiz Then
    Exit Function
End If

Set rst = CurrentDb.OpenRecordset("Kodovi")
i = 1
While Not rst.EOF
    arrZaDekodiranje(i, 1) = rst!dbSlovo
    arrZaDekodiranje(i, 2) = rst!acSlovo
    
    rst.MoveNext
    i = i + 1
Wend

rst.Close
Set rst = Nothing
NapunjenNiz = True

    
End Function
Public Function dbDekode(dbRec As Variant)
Dim stRetVal As String
stRetVal = ""
Dim i As Integer

NapuniNiz

    stRetVal = Trim(Nz(dbRec, ""))
    If stRetVal <> "" Then
        For i = 1 To 40
            stRetVal = Replace(stRetVal, arrZaDekodiranje(i, 1), arrZaDekodiranje(i, 2))
        Next i
    End If
    dbDekode = stRetVal
End Function
