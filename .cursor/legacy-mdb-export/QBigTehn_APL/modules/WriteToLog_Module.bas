Attribute VB_Name = "WriteToLog_Module"
Option Compare Database
Option Explicit

' Upisuje poruku u tekst fajl loga
Public Sub WriteToLog(ByVal Message As String)
    On Error GoTo Err_Point
    
    Dim fNum As Integer
    Dim LogFile As String
    
    ' Lokacija log fajla – možeš promeniti po potrebi
    LogFile = "C:\PDMExport\APL\PDM_XMLParser.log"
    
    ' Uzmemo slobodan broj file handle-a
    fNum = FreeFile
    
    ' Dodaj u fajl (Append mode = ForAppending = 8)
    Open LogFile For Append As #fNum
    Print #fNum, Format(Now, "yyyy-mm-dd hh:nn:ss") & " - " & Message
    Close #fNum
    
Exit_Point:
    Exit Sub
    
Err_Point:
    ' Ako i ovde doðe do greške, ignoriši da ne bi program stao
    Resume Exit_Point
End Sub


