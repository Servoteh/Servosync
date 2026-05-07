Attribute VB_Name = "Mega_Base64_Encoder_Decoder"
Option Compare Database
Option Explicit

Public Function ConvertFileToBase64(strFilePath As String) As String
On Error GoTo Err_Point

    Const adTypeBinary = 1
    Dim retVal As String
    Dim streamInput As Object
    Dim xmlDoc As Object
    Dim xmlElem As Object

    ' Proveri da li fajl postoji
    If Dir(strFilePath) = "" Then
        ConvertFileToBase64 = ""
        Exit Function
    End If

    Set streamInput = CreateObject("ADODB.Stream")
    Set xmlDoc = CreateObject("MSXML2.DOMDocument.6.0")   ' sigurnije od "Microsoft.XMLDOM"
    Set xmlElem = xmlDoc.createElement("b64")

    streamInput.Type = adTypeBinary
    streamInput.Open
    streamInput.LoadFromFile strFilePath

    xmlElem.DataType = "bin.base64"
    xmlElem.nodeTypedValue = streamInput.Read
    retVal = Replace(xmlElem.Text, vbLf, "")

Exit_Point:
    On Error Resume Next
    streamInput.Close
    Set streamInput = Nothing
    Set xmlDoc = Nothing
    Set xmlElem = Nothing
    ConvertFileToBase64 = retVal
    Exit Function

Err_Point:
    Debug.Print "Greška u ConvertFileToBase64: " & err.Number & " - " & err.Description
    retVal = ""
    Resume Exit_Point
End Function
Public Sub ConvertBase64ToFile(ByVal strFilePath As String, ByVal strBase64 As String)
On Error GoTo Err_Point

    Const adTypeBinary = 1
    Const adSaveCreateOverWrite = 2
    
    Dim streamOutput As Object
    Dim xmlDoc As Object
    Dim xmlElem As Object
    Dim FolderPath As String
    
    '=== Provera ulaznih parametara ===
    If Len(Nz(strFilePath, "")) = 0 Then Exit Sub
    If Len(Nz(strBase64, "")) = 0 Then Exit Sub
    
    '=== Kreiraj folder ako ne postoji ===
    FolderPath = Left(strFilePath, InStrRev(strFilePath, "\") - 1)
    If Dir(FolderPath, vbDirectory) = "" Then
        MkDir FolderPath
    End If
    
    '=== Kreiraj potrebne objekte ===
    Set streamOutput = CreateObject("ADODB.Stream")
    Set xmlDoc = CreateObject("MSXML2.DOMDocument.6.0")   ' sigurnije od "Microsoft.XMLDOM"
    Set xmlElem = xmlDoc.createElement("b64")

    '=== Dekodiranje ===
    xmlElem.DataType = "bin.base64"
    xmlElem.Text = strBase64
    
    streamOutput.Type = adTypeBinary
    streamOutput.Open
    streamOutput.Write xmlElem.nodeTypedValue
    streamOutput.SaveToFile strFilePath, adSaveCreateOverWrite
    
Exit_Point:
    On Error Resume Next
    streamOutput.Close
    Set streamOutput = Nothing
    Set xmlDoc = Nothing
    Set xmlElem = Nothing
    Exit Sub

Err_Point:
    Debug.Print "Greška u ConvertBase64ToFile: " & err.Number & " - " & err.Description
    Resume Exit_Point
End Sub

