Attribute VB_Name = "POPIS"
Option Compare Database
Option Explicit


Public Function CenaZaUpisUPopis(KojaCena As String, NCN, ZTS, ZTD, KLVP, KLMP, STVP, STMP, CenaIzCenovnika) As Currency
Dim retVal
    Select Case KojaCena
        Case "Nabavna neto"
            retVal = NCN
        Case "Nabavna bruto"
            retVal = NCN + ZTS + ZTD
        Case "Kalkulativna VP"
            retVal = KLVP
        Case "Kalkulativna MP"
            retVal = KLMP
        Case "Stvarna VP"
            retVal = STVP
        Case "Stvarna MP"
            retVal = STMP
        Case "CENOVNIK"
            retVal = CenaIzCenovnika
        Case Else
            retVal = 0
     End Select
     CenaZaUpisUPopis = CCur(Nz(retVal, 0))
End Function
Public Function VPLLCenaZaUpisUPopis(KojaCena As String, PNCZaliha, PoslednjaKLNC, PoslednjaKLVPC, PoslednjaKLMPC, CenaIzCenovnika) As Currency
' datum kreiranja: 14-06-2019
Dim retVal
    Select Case KojaCena
        Case "PNCZaliha"
            retVal = PNCZaliha
        Case "PoslednjaKLNC"
            retVal = PoslednjaKLNC
        Case "PoslednjaKLVPC"
            retVal = PoslednjaKLVPC
        Case "PoslednjaKLMPC"
            retVal = PoslednjaKLMPC
        Case "CenaIzCenovnika"
            retVal = CenaIzCenovnika
        Case Else
            retVal = 0
     End Select
     VPLLCenaZaUpisUPopis = CCur(Nz(retVal, 0))
End Function
