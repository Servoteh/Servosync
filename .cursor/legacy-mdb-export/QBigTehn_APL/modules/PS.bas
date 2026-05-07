Attribute VB_Name = "PS"
Option Compare Database
Option Explicit
Public Function PS_CenaZaTip(TipCene As String, ProsecnaNC As Double, ProsecnaVPC As Double, PoslednjaNC As Double, PoslednjaVPC As Double) As Double
    Dim retVal As Double
    Select Case TipCene
        Case "PoslednjaNC"
        retVal = PoslednjaNC
        Case "PoslednjaVPC"
        retVal = PoslednjaVPC
        Case "ProsecnaNC"
        retVal = ProsecnaNC
        Case "ProsecnaVPC"
        retVal = ProsecnaVPC
        Case Else
        retVal = 0
    End Select
     PS_CenaZaTip = retVal
    
End Function

