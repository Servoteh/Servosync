Attribute VB_Name = "Konobari"
Option Compare Database
Option Explicit

Public Sub KonobarUzimaRacun(IDKonobar As Long, IDRacun As Long, IDProdavnica As Long, IDKasa As Long)
On Error GoTo Err_KonobarUzimaRacun

Dim defRacun As DAO.QueryDef
Dim ImeKonobara As String

Set defRacun = CurrentDb.QueryDefs("UzimamRacun")
defRacun.Parameters("[Forms]![PrvaMaskaKonobar]![IDKonobar]") = IDKonobar
defRacun.Parameters("[Forms]![PrvaMaskaKonobar]![IDRacun]") = IDRacun
defRacun.Parameters("[Forms]![PrvaMaskaKonobar]![IDProdavnica]") = IDProdavnica
defRacun.Parameters("[Forms]![PrvaMaskaKonobar]![IDKasa]") = IDKasa
defRacun.Execute dbSeeChanges
If defRacun.RecordsAffected >= 1 Then 'preuzeo je racun (bar jedan)
    ImeKonobara = DLookup("[Konobar]", "Konobari", "[IDKonobar]= " & IDKonobar)
    UpisiUDnevnik CurrentUser & ":" & ImeKonobara, "Uzimam racun ID= " & IDRacun, "Prodaja", "UzimaRN"
End If

Exit_KonobarUzimaRacun:
On Error Resume Next
defRacun.Close
Set defRacun = Nothing
Exit Sub

Err_KonobarUzimaRacun:
    MsgBox err.Description
    Resume Exit_KonobarUzimaRacun
    
End Sub
Public Sub KonobarDajeRacun(IDKonobar As Long, IDRacun As Long, IDProdavnica As Long, IDKasa As Long)
On Error GoTo Err_KonobarUzimaRacun

Dim defRacun As DAO.QueryDef
Dim ImeKonobara As String

Set defRacun = CurrentDb.QueryDefs("DajemRacun")
defRacun.Parameters("[Forms]![PrvaMaskaKonobar]![IDKonobar]") = IDKonobar
defRacun.Parameters("[Forms]![PrvaMaskaKonobar]![IDRacun]") = IDRacun
defRacun.Parameters("[Forms]![PrvaMaskaKonobar]![IDProdavnica]") = IDProdavnica
defRacun.Parameters("[Forms]![PrvaMaskaKonobar]![IDKasa]") = IDKasa
defRacun.Execute dbSeeChanges
If defRacun.RecordsAffected >= 1 Then 'preuzeo je racun (bar jedan)
    ImeKonobara = DLookup("[Konobar]", "Konobari", "[IDKonobar]= " & IDKonobar)
    UpisiUDnevnik CurrentUser & ":" & ImeKonobara, "Dajem racun ID= " & IDRacun, "Prodaja", "DajeRN"
End If

Exit_KonobarUzimaRacun:
On Error Resume Next
defRacun.Close
Set defRacun = Nothing
Exit Sub

Err_KonobarUzimaRacun:
    MsgBox err.Description
    Resume Exit_KonobarUzimaRacun
    
End Sub
Public Sub NeFRNUvecajBrojStampanja(IDKonobar As Long, IDRacun As Long, IDProdavnica As Long, IDKasa As Long)
On Error GoTo Err_UvecajBrojStampanja

Dim defRacun As DAO.QueryDef
Dim ImeKonobara As String

Set defRacun = CurrentDb.QueryDefs("NeFRNUvecajBrojStampanja")
defRacun.Parameters("[Forms]![PrvaMaskaKonobar]![IDKonobar]") = IDKonobar
defRacun.Parameters("[Forms]![PrvaMaskaKonobar]![IDRacun]") = IDRacun
defRacun.Parameters("[Forms]![PrvaMaskaKonobar]![IDProdavnica]") = IDProdavnica
defRacun.Parameters("[Forms]![PrvaMaskaKonobar]![IDKasa]") = IDKasa
defRacun.Execute (dbSeeChanges)
If defRacun.RecordsAffected >= 1 Then 'preuzeo je racun (bar jedan)
    ImeKonobara = DLookup("[Konobar]", "Konobari", "[IDKonobar]= " & IDKonobar)
    UpisiUDnevnik CurrentUser & ":" & ImeKonobara, "Nefiskalni racun ID= " & IDRacun, "Prodaja", "PrintNeFRN"
End If
Exit_UvecajBrojStampanja:
    
    On Error Resume Next
    defRacun.Close
    Set defRacun = Nothing

Exit Sub

Err_UvecajBrojStampanja:
    MsgBox err.Description
    Resume Exit_UvecajBrojStampanja
    
End Sub
Public Function OznaciRacunDaJeNaplacen(IDKonobar As Long, IDRacun As Long, IDProdavnica As Long, IDKasa As Long) As Boolean
On Error GoTo errFunc

Dim Kasa As DAO.Database
Dim defRacun As DAO.QueryDef
Dim Racun As DAO.Recordset
Dim retVal As Boolean
Dim ImeKonobara
    
retVal = False
Set Kasa = CurrentDb
Set defRacun = Kasa.QueryDefs("KafeAktivniRacun")
defRacun.Parameters("ZaIDDok") = IDRacun
defRacun.Parameters("ZaIDProdavnica") = IDProdavnica
defRacun.Parameters("ZaIDKasa") = IDKasa
Set Racun = defRacun.OpenRecordset(dbOpenDynaset, dbSeeChanges)
Racun.MoveFirst
Racun.Edit
Racun!Naplaceno = True
Racun.Update
retVal = True

ImeKonobara = Nz(DLookup("[Konobar]", "Konobari", "[IDKonobar]= " & IDKonobar), "<<NULL>>")
UpisiUDnevnik CurrentUser & ":" & ImeKonobara, "Naplacen racun ID= " & IDRacun, "Prodaja", "Naplata"

ZatvoriRST:
On Error Resume Next
Racun.Close
Set Racun = Nothing
defRacun.Close
Set defRacun = Nothing
Kasa.Close
Set Kasa = Nothing
OznaciRacunDaJeNaplacen = retVal
Exit Function

errFunc:
 retVal = False
 MsgBox Error$
 Resume ZatvoriRST

End Function
Public Function KonobarSmeNefiskalniRacun(IDKonobar As Long) As Boolean
 Dim retVal As Boolean
    retVal = Nz(DLookup("[NefiskalniRN]", "Konobari", "[IDKonobar]= " & IDKonobar), False)
    KonobarSmeNefiskalniRacun = retVal
End Function
Public Function SledecaTura(IDRacun As Long, IDProdavnica As Long) As Integer
Dim PredlogZaBrojPorudzbine As Integer
    PredlogZaBrojPorudzbine = 1 + Nz(DMax("[Porudzbina]", "T_MPStavke", "[IDDok] = " & IDRacun & " and [IDProdavnice] = " & IDProdavnica), 0)
    SledecaTura = PredlogZaBrojPorudzbine
End Function
Public Function DozvoljenoStorniranjeZaPWD(PWD As String) As Boolean
 Dim retVal As Boolean
    retVal = Nz(DLookup("[Storniranje]", "Konobari", "[Password]= '" & PWD & "'"), False)
    DozvoljenoStorniranjeZaPWD = retVal
End Function

