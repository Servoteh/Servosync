Attribute VB_Name = "ProdavciModule"
Option Compare Database
Option Explicit

Public Function ProdavciMISP_DodajMISPZaKomitenta(IDProdavac As Long, IDKomitent As Long)
On Error GoTo Err_Point
 Dim stSQL As String
 Dim retValOk As Boolean
 
 retValOk = True
 
 DoCmd.Hourglass True
 
 stSQL = CurrentDb.QueryDefs("ProdavciMISP_DodajMISPZaKomitenta").sql
 stSQL = Replace(stSQL, "[ZaIDProdavac]", CStr(IDProdavac))
 stSQL = Replace(stSQL, "[ZaIDKomitent]", CStr(IDKomitent))
 
 CurrentDb.Execute stSQL, dbSeeChanges
 'DoCmd.RunSQL stSQL

Exit_Point:
 On Error Resume Next
 DoCmd.Hourglass False
 ProdavciMISP_DodajMISPZaKomitenta = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ProdavciMISP_DodajMISPZaKomitenta"
 retValOk = False
 Resume Exit_Point
End Function
Public Function ImeProdavcaZaKomitenta(IDKomitent As Long) As String
'Kreirano: 28-08-2020
On Error GoTo Err_Point

Dim SifraProdavca
Dim stRetVal
   stRetVal = ""
   SifraProdavca = DLookup("[Sifra prodavca]", "Komitenti", "[Sifra]=" & IDKomitent)
   If IsNumeric(SifraProdavca) Then
      stRetVal = DLookup("[Prodavac]", "Prodavci", "[Sifra prodavca]=" & CLng(SifraProdavca))
   End If
 
Exit_Point:
 On Error Resume Next
  ImeProdavcaZaKomitenta = Nz(stRetVal, "")
Exit Function

Err_Point:
 BBErrorMSG err, "ImeProdavcaZaKomitenta"
 stRetVal = ""
 Resume Exit_Point
End Function
Public Function F_ProdavacZaSifruProdavca(SifraProdavca As Variant) As String
'Kreirano: 20-04-2022

On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stRetVal As String

retValOk = True
stRetVal = ""

If IsNumeric(SifraProdavca) Then
    stRetVal = Nz(ADO_Lookup(CNN_CurrentDataBase, "Prodavac", "Prodavci", "[Sifra prodavca]=" & stR(CLng(SifraProdavca))), "")
Else
    stRetVal = ""
End If

Exit_Point:
       F_ProdavacZaSifruProdavca = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_ProdavacZaSifruProdavca"
 retValOk = False
 Resume Exit_Point
End Function
Public Function F_IDProdavacZaKomitenta(IDKomitent As Long) As Long
'Kreirano: 30-01-2023

On Error GoTo Err_Point
Dim retValOk As Boolean
Dim retVal As Long

retValOk = True
retVal = 0


    retVal = Nz(ADO_Lookup(CNN_CurrentDataBase, "[Sifra prodavca]", "Komitenti", "[Sifra]=" & stR(IDKomitent)), 0)


Exit_Point:
       F_IDProdavacZaKomitenta = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_IDProdavacZaKomitenta"
 retValOk = False
 Resume Exit_Point
End Function
