Attribute VB_Name = "Komitenti"
Option Compare Database
Option Explicit
Public Function VrstaSifreKomitenta(IDKomitent As Variant) As String
'Kreirano: 23-01-2021
On Error GoTo Err_Point
    Dim stRetVal As String
    

 stRetVal = Nz(ADO_Lookup(BBCFG.CNNString, "[Vrsta sifre]", "Komitenti", "[Sifra]=" & stR(Nz(IDKomitent, -1))), "")
 
Exit_Point:
 On Error Resume Next
 VrstaSifreKomitenta = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "VrstaSifreKomitenta"
 Resume Exit_Point
End Function
Public Function spDodajTRZaKomitenta(IDKomitent As Long _
                                   , stBrojTR As String _
                                   , Optional stNazivBanke As String = "-" _
                                   , Optional Rbr As Long = 0 _
                                   , Optional Devizni As Boolean = False _
                                   , Optional stNapomena = Null _
                                   , Optional Aktivan As Boolean = True _
                                   , Optional IDBanke = Null)
'Kreirano: 21-01-2021
On Error GoTo Err_Point
Dim retValOk As Boolean

'BBCFG.CNNString,
 retValOk = ExecSPByRefPar("spDodajTRZaKomitenta", _
                                   "@IDFirma = " & F_IDFirma() _
                                 , "@Godina  = " & F_Godina() _
                                 , "@IDKomitent = " & IDKomitent _
                                 , "@BrojTR = " & stBrojTR _
                                 , "@NazivBanke = " & stNazivBanke _
                                 , "@RBr = " & Rbr _
                                 , "@Devizni = " & SQLFormatBoolean(Devizni) _
                                 , "@Napomena = " & Nz(stNapomena, Null) _
                                 , "@Aktivan = " & SQLFormatBoolean(Aktivan) _
                                 , "@IDBanke = " & Nz(IDBanke, 0))
                                 

Exit_Point:
 On Error Resume Next
 spDodajTRZaKomitenta = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "spDodajTRZaKomitenta"
 retValOk = False
 Resume Exit_Point
End Function

Public Function F_NazivKomitentaZaID(IDKomitent As Variant) As String
'Kreirano: 20-04-2022

On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stRetVal As String

retValOk = True
stRetVal = ""

If IsNumeric(IDKomitent) Then
    stRetVal = Nz(ADO_Lookup(CNN_CurrentDataBase, "Naziv", "Komitenti", "Sifra=" & stR(CLng(IDKomitent))), "")
Else
    stRetVal = ""
End If

Exit_Point:
       F_NazivKomitentaZaID = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_NazivKomitentaZaID"
 retValOk = False
 Resume Exit_Point
End Function
Public Function UpisiNoviRabatZaPorekloKodSvihKomitenata(ZaPoreklo As String, NoviRabatProc As Double) As Boolean
'Kreirano: 11-03-2023
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stSQL As String

retValOk = True

stSQL = ""
stSQL = stSQL & " UPDATE [RabatiPoreklo]"
stSQL = stSQL & "    SET [RabatProc] = " & CStr(NoviRabatProc)
stSQL = stSQL & "  WHERE [IDPoreklo] = '" & ZaPoreklo & "'"

retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)

Exit_Point:
 On Error Resume Next
       UpisiNoviRabatZaPorekloKodSvihKomitenata = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "UpisiNoviRabatZaPorekloKodSvihKomitenata"
 retValOk = False
 Resume Exit_Point

End Function
Public Function UpisiNoviRabatZaPodgrupuKodSvihKomitenata(ZaPodgrupu As String, NoviRabatProc As Double) As Boolean
'Kreirano: 11-03-2023
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stSQL As String

retValOk = True

stSQL = ""
stSQL = stSQL & " UPDATE [RabatiPodgrupa]"
stSQL = stSQL & "    SET [RabatProc] = " & CStr(NoviRabatProc)
stSQL = stSQL & "  WHERE [IDPodgrupa] = '" & ZaPodgrupu & "'"

retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)

Exit_Point:
 On Error Resume Next
       UpisiNoviRabatZaPodgrupuKodSvihKomitenata = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "UpisiNoviRabatZaPodgrupuKodSvihKomitenata"
 retValOk = False
 Resume Exit_Point

End Function
Public Function UpisiNoviRabatZaGrupuKodSvihKomitenata(ZaGrupu As String, NoviRabatProc As Double) As Boolean
'Kreirano: 11-03-2023
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stSQL As String

retValOk = True

stSQL = ""
stSQL = stSQL & " UPDATE [Rabati]"
stSQL = stSQL & "    SET [RabatProc] = " & CStr(NoviRabatProc)
stSQL = stSQL & "  WHERE [IDGrupa] = '" & ZaGrupu & "'"

retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)

Exit_Point:
 On Error Resume Next
       UpisiNoviRabatZaGrupuKodSvihKomitenata = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "UpisiNoviRabatZaGrupuKodSvihKomitenata"
 retValOk = False
 Resume Exit_Point

End Function

Public Function spUpisiKomitentaUCrnuListu(IDKomitent As Long _
                                        , DATUM As Date _
                                        , Opis As String _
                                        , Vazi As Boolean _
                                        ) As Boolean
'Kreirano: 30-05-2023
On Error GoTo Err_Point
Dim retValOk As Boolean


 retValOk = ExecSPByRefPar("spUpisiKomitentaUCrnuListu", _
                                   "@IDKomitent = " & IDKomitent _
                                 , "@Datum = " & SQLFormatDatuma(DATUM, False) _
                                 , "@Opis = " & Opis _
                                 , "@Vazi = " & SQLFormatBoolean(Vazi) _
                                 )
                                 

Exit_Point:
 On Error Resume Next
 spUpisiKomitentaUCrnuListu = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "spUpisiKomitentaUCrnuListu"
 retValOk = False
 Resume Exit_Point
End Function
