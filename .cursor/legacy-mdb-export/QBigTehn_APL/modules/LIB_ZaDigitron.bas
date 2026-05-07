Attribute VB_Name = "LIB_ZaDigitron"
Option Compare Database
Option Explicit


Public Function VrednostIzrazaZaDigitron(stIzraz, BrojDecimala) As Double
 Dim Vred As Variant
  On Error Resume Next
    stIzraz = IzbaciZnak(stIzraz, ",")
    Vred = Round(Eval(Nz([stIzraz], 0)), BrojDecimala)
    While ((Not IsNumeric(Vred)) Or IsEmpty(Vred)) And (Len(stIzraz) > 0)
        stIzraz = Right(stIzraz, Len(stIzraz) - 1)
        Vred = Round(Eval(Nz([stIzraz], 0)), BrojDecimala)
    Wend
    
    If Not IsNumeric(Vred) Then Vred = 0
    
    VrednostIzrazaZaDigitron = Vred
End Function

Private Function IzbaciZnak(stIzraz, Znak As String) As Variant
 On Error Resume Next
  Dim retVal As String
    retVal = CStr(Nz(stIzraz, ""))
    
    While InStr(retVal, Znak) <> 0
        retVal = Left$(retVal, InStr(retVal, Znak) - 1) & Right$(retVal, Len(retVal) - InStr(retVal, Znak))
    Wend
    IzbaciZnak = retVal
End Function
