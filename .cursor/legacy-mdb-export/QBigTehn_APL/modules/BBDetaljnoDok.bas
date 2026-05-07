Attribute VB_Name = "BBDetaljnoDok"
Option Compare Database
Option Explicit
Public Function PrikaziDokRN(IDRN, Optional bPrimopredaja As Boolean = False) As String
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim stLinkCriteria As String
    Dim stDocName As String
    
    Dim IDRNZaPrikaz As Long
    Dim stOpenArgs As String
    
    Dim stPitanje As String
    
    
    retValOk = False
    
    
    If Not IsNumeric(IDRN) Then
      retValOk = False
      GoTo Exit_Point
    End If
    
    If IDRN <= 0 Then
      retValOk = False
      GoTo Exit_Point
    End If
    
    '******************************************
    IDRNZaPrikaz = CLng(IDRN) '!!!!!!
    '******************************************
    stLinkCriteria = "[IDRN] = " & IDRNZaPrikaz
    If bPrimopredaja = False Then
        stDocName = "UnosRN"
    Else
        stDocName = "Primopredaja"
    End If
    
    If IsLoaded(stDocName) Then
      DoCmd.Close acForm, stDocName, acSavePrompt
      Set RNP = Nothing
    End If
    stLinkCriteria = "[IDRN]=" & IDRNZaPrikaz
    RNP.IDRN = IDRNZaPrikaz '!!!!!!!!!!!!
    RNP.Caller = "DetaljnoDokument"
    BBOpenForm stDocName, , , stLinkCriteria, , , stOpenArgs
    retValOk = IsLoaded(stDocName)
    
Exit_Point:
 On Error Resume Next
 'PrikaziRobniDok = retValOk
    PrikaziDokRN = stDocName
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziDokRN"
 retValOk = False
 Resume Exit_Point
End Function
Public Function PronadjiSlogNaFormi(ByRef frm As Form, ByVal stFind As String) As Boolean
 
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
 PronadjiSlogNaFormi = retValOk
 
 rs.Close
 Set rs = Nothing
 
Exit Function

Err_Point:
    BBErrorMSG err, "PronadjiSlogNaFormi"
    retValOk = False
    Resume Exit_Point
End Function

Public Sub DetaljnoPredmet(ByVal IDPredmet As Variant)
'Kreirano: 13-10-2021
'Modifikovano: 18-10-2021
'Modifikovano: 19-10-2021
On Error GoTo Err_Point

    Dim stDocName As String
    Dim stLinkCriteria As String
    
    stDocName = "Predmeti"
    'stLinkCriteria = "[IDPredmet]=" & Str(CLng(IDPredmet))
    BBOpenForm stDocName, , , stLinkCriteria
    If IsNumeric(IDPredmet) Then
       Call PronadjiSlogNaFormi(Forms(stDocName), "IDPredmet=" & stR(IDPredmet))
    Else
       On Error Resume Next
       DoCmd.GoToRecord , , acNewRec
    End If
    
Exit_Point:
    Exit Sub

Err_Point:
    BBErrorMSG err, "DetaljnoPredmet"
    Resume Exit_Point
    
End Sub

