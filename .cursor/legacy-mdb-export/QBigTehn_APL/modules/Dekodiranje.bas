Attribute VB_Name = "Dekodiranje"
Option Compare Database
Option Explicit

Private Function UkloniSpace(ByVal st As String) As String
    Dim i As Integer
    Dim retVal As String
    retVal = ""
    For i = 1 To Len(st)
      If Mid(st, i, 1) <> " " Then
        retVal = retVal & Mid$(st, i, 1)
      End If
    Next i
  UkloniSpace = retVal
End Function
Private Sub IzNazivaKolPakIOsnJM(ByVal stNaziv As String, ByRef retKolPak As Double, ByRef retOsnJm)
    Dim retVal
    Dim Naziv As String
    Dim OsnJM As String
    Dim delilac As Double
    
    Naziv = stNaziv
    Naziv = UkloniSpace(Naziv)
    
    ' ako pocinje numericom ili "/" obrisi
    While (Naziv <> "") And (IsNumeric(Left$(Naziv, 1)) Or (Left$(Naziv, 1)) = "/")
        Naziv = Right(Naziv, Len(Naziv) - 1)
    Wend
    
    'ostavi samo numerice
    While (Naziv <> "") And Not IsNumeric(Left$(Naziv, 1))
        Naziv = Right(Naziv, Len(Naziv) - 1)
    Wend
    
    If InStr(Naziv, "KG") > 0 Then
        Naziv = Left(Naziv, InStr(Naziv, "KG") - 1)
        OsnJM = "Kg"
        delilac = 1
    ElseIf InStr(Naziv, "GR") > 0 Then
        Naziv = Left(Naziv, InStr(Naziv, "GR") - 1)
        OsnJM = "Kg"
        delilac = 1000
    ElseIf InStr(Naziv, "G") > 0 Then
        Naziv = Left(Naziv, InStr(Naziv, "G") - 1)
        OsnJM = "Kg"
        delilac = 1000
     ElseIf InStr(Naziv, "LIT") > 0 Then
        Naziv = Left(Naziv, InStr(Naziv, "LIT") - 1)
        OsnJM = "L"
        delilac = 1
    ElseIf InStr(Naziv, "ML") > 0 Then
        Naziv = Left(Naziv, InStr(Naziv, "ML") - 1)
        OsnJM = "L"
        delilac = 1000
    ElseIf InStr(Naziv, "L") > 0 Then
        Naziv = Left(Naziv, InStr(Naziv, "L") - 1)
        OsnJM = "L"
        delilac = 1
    ElseIf InStr(Naziv, "M") > 0 Then
        Naziv = Left(Naziv, InStr(Naziv, "M") - 1)
        OsnJM = "M"
        delilac = 1
    Else
        delilac = 1
        OsnJM = "Kom"
    End If
    
    On Error Resume Next
    retVal = Eval(Naziv)
    If Not IsNumeric(retVal) Then retVal = 1
    retKolPak = retVal
    retKolPak = retKolPak / delilac
    If retKolPak = 0 Then retKolPak = 1
    retOsnJm = OsnJM
    'IzNazivaKolPak = retval
End Sub
Public Function IzNazivaKolPak(Naziv) As Double
  Dim KolPak As Double
  Dim OsnJM As String
    Call IzNazivaKolPakIOsnJM(Nz(Naziv, ""), KolPak, OsnJM)
    IzNazivaKolPak = KolPak
End Function
Public Function IzNazivaOsnJM(Naziv) As String
  Dim KolPak As Double
  Dim OsnJM As String
    Call IzNazivaKolPakIOsnJM(Nz(Naziv, ""), KolPak, OsnJM)
    IzNazivaOsnJM = OsnJM
End Function


Public Function CeoDeoIznosa(Iznos As Currency) As String
    Dim retVal As String
    Dim lokIznos As Currency
    lokIznos = Round(Iznos, 2)
    lokIznos = Fix(lokIznos)
    retVal = Format(lokIznos, "##,##")
    If retVal = "" Then retVal = "0"
    CeoDeoIznosa = retVal
End Function
Public Function DecDeoIznosa(Iznos As Currency) As String
    Dim retVal As String
    Dim lokIznos As Currency
    lokIznos = Round(Iznos, 2)
    lokIznos = (lokIznos - Fix(lokIznos)) * 100
    retVal = Format(lokIznos, "##00")
    DecDeoIznosa = retVal
End Function
