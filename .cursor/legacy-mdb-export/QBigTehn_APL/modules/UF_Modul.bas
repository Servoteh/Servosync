Attribute VB_Name = "UF_Modul"
Option Compare Database
Option Explicit

Public UFP As New UF_Class

Public Function F_UF_IDDok() As Long
   F_UF_IDDok = Nz(UFP.IDDok(), -1)
End Function
Public Function F_UF_IDMagacinDOK() As Long
   F_UF_IDMagacinDOK = UFP.IDMagacinDOK
End Function

Public Function F_UF_IDKomitent(Optional IDKomitent) As Long
Dim lnRetVal As Long
    lnRetVal = UFP.IDKomitent
    F_UF_IDKomitent = lnRetVal
End Function
Public Function F_UF_Level() As Byte
Dim retVal As Byte
    retVal = ADO_Lookup(F_CNNString("SQL"), "Level", "T_Robna dokumenta", "[IDDok]=" & F_UF_IDDok())
    F_UF_Level = retVal
End Function
Public Function F_UF_DatumDokumenta() As Date
Dim retVal As Date
    retVal = ADO_Lookup(F_CNNString("SQL"), "[Datum dokumenta]", "T_Robna dokumenta", "[IDDok]=" & F_UF_IDDok())
    F_UF_DatumDokumenta = retVal
End Function
