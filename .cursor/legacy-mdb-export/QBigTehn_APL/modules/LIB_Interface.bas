Attribute VB_Name = "LIB_Interface"
Option Compare Database
Option Explicit


Public BBCFG As New BBCFG_Class

Public Function LIB_OpenForm(ByVal FormName As String, Optional ByVal View = acNormal, Optional ByVal filterName As String = "", Optional ByVal WhereCondition As String = "", Optional ByVal DataMode = acFormPropertySettings, Optional ByVal WindowMode = acWindowNormal, Optional OpenArgs) As Variant
On Error GoTo Err_Point

    DoCmd.OpenForm FormName, View, filterName, WhereCondition, DataMode, WindowMode, OpenArgs

Exit_Point:
On Error Resume Next

Exit Function

Err_Point:
 BBErrorMSG err, "LIB_OpenForm(" & FormName & "...)"
 Resume Exit_Point
End Function
Public Function LIB_IntroComment(stComment As String)
On Error GoTo Err_Point

If IsLoaded("Intro") Then
    If Nz(Forms!Intro!OpisPoslaKojiSeRadi, "") = "" Then
     Forms!Intro!OpisPoslaKojiSeRadi = stComment
    Else
     Forms!Intro!OpisPoslaKojiSeRadi = Forms!Intro!OpisPoslaKojiSeRadi & "   ->  " & BBTimerTrajanjeSec() & Chr(13) & Chr(10)
     Forms!Intro!OpisPoslaKojiSeRadi = Forms!Intro!OpisPoslaKojiSeRadi & stComment
    End If
 Forms!Intro.Repaint
 'Forms!Intro!OpisPoslaKojiSeRadi.SetFocus
End If

Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "LIB_IntroComment"
 Resume Exit_Point
End Function
Public Function GetMyLibVer(Optional ByVal MyLibRefName As Variant, Optional stAPP As String = "QBigBit_LIB", Optional TableName, Optional OnlyRev As Boolean = False) As String
'Kreirano: 22-01-2021
On Error GoTo Err_Point
Dim stRetVal
Dim VerDatum 'As Date
Dim Ver As String
Dim IDRev As Long
Dim stWhere As String
Dim pstTableName As String
Dim stMyLibRefName As String
Dim stCNN_LIB As String

If IsMissing(MyLibRefName) Then
     stMyLibRefName = "QBigBit_LIB_5V" 'Replace(CurrentProject.Name, ".accdb", "")
Else
    stMyLibRefName = CStr(Nz(MyLibRefName, "QBigBit_LIB_5V")) 'Replace(CurrentProject.Name, ".accdb", "")))
End If

If IsMissing(TableName) Then
     pstTableName = "_APPRev"
Else
    pstTableName = CStr(Nz(TableName, "_APPRev"))
End If

If Nz(GetRefPath(stMyLibRefName), "") = "" Then
     stRetVal = "-"
     GoTo Exit_Point
End If

stCNN_LIB = CreateAccess_CNNString(GetRefPath(stMyLibRefName))
stRetVal = ADO_Lookup(stCNN_LIB, "[VerDatum]", pstTableName)

'VerDatum = DMax("[VerDatum]", pstTableName, "APP='" & stAPP & "'")
VerDatum = ADO_Lookup(stCNN_LIB, "[MaxVal]", "SELECT MAX([VerDatum]) as MaxVal FROM " & pstTableName & " WHERE APP='" & stAPP & "'")

If Not IsDate(VerDatum) Then
  stRetVal = "-"
  GoTo Exit_Point
End If

stWhere = "(Format([VerDatum],""dd-MM-yy"")='" & Format(CVDate(VerDatum), "dd-MM-yy") & "')"    'UH!
stWhere = stWhere & " AND (" & Chr(34) & "APP='" & stAPP & "'" & Chr(34) & ")"                  'UH UH!

'IDRev = DMax("[ID]", pstTableName, stWhere)
IDRev = ADO_Lookup(stCNN_LIB, "[MaxVal]", "SELECT MAX([ID]) as MaxVal FROM " & pstTableName & " WHERE " & stWhere)

Ver = ADO_Lookup(stCNN_LIB, "Ver", pstTableName, "[ID]=" & IDRev)

If OnlyRev Then
  stRetVal = Ver
Else
  stRetVal = "Ver: " & Ver & vbCrLf & Format(VerDatum, "dd.MM.yyyy.")
End If

Exit_Point:
 On Error Resume Next
 GetMyLibVer = stRetVal
Exit Function

Err_Point:
  BBErrorMSG err, "GetMyLibVer"
  Resume Exit_Point
End Function
Public Function GetDBVer(CNNString As String, Optional TableName, Optional OnlyRev As Boolean = False) As String
'Kreirano: 25-12-2021
On Error GoTo Err_Point
Dim stRetVal
Dim VerDatum 'As Date
Dim Ver As String
Dim IDRev As Long
Dim stWhere As String
Dim pstTableName As String
Dim stMyLibRefName As String

If IsMissing(TableName) Then
     pstTableName = "_Rev"
Else
    pstTableName = CStr(Nz(TableName, "_Rev"))
End If

stRetVal = ADO_Lookup(CNNString, "[VerDatum]", pstTableName)
VerDatum = ADO_Lookup(CNNString, "[MaxVal]", "SELECT MAX([VerDatum]) as MaxVal FROM " & pstTableName)     '& " WHERE APP='" & stAPP & "'")

If Not IsDate(VerDatum) Then
  stRetVal = "-"
  GoTo Exit_Point
End If

stWhere = "(Format([VerDatum],'dd-MM-yy')='" & Format(CVDate(VerDatum), "dd-MM-yy") & "')"    'UH!
'stWhere = stWhere & " AND (" & Chr(34) & "APP='" & stAPP & "'" & Chr(34) & ")"                  'UH UH!

'IDRev = DMax("[ID]", pstTableName, stWhere)
IDRev = ADO_Lookup(CNNString, "[MaxVal]", "SELECT MAX([ID]) as MaxVal FROM " & pstTableName & " WHERE " & stWhere)

Ver = ADO_Lookup(CNNString, "Ver", pstTableName, "[ID]=" & IDRev)

If OnlyRev Then
  stRetVal = Ver
Else
  stRetVal = "Ver: " & Ver & vbCrLf & Format(VerDatum, "dd.MM.yyyy.")
End If

Exit_Point:
 On Error Resume Next
 GetDBVer = stRetVal
Exit Function

Err_Point:
  BBErrorMSG err, "GetDBVer"
  Resume Exit_Point
End Function
