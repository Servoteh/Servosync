Attribute VB_Name = "KafeKreiranjeDokumenata"
Option Compare Database
Option Explicit
Public Function PostojiCenovnik(stCenVrstaDok As String) As Boolean
  Dim retValOk As Boolean
  retValOk = (DCount("[CenVrstaDok]", "CEN_DozvoljeniCenovnici", "[CenVrstaDok]='" & stCenVrstaDok & "'") > 0)
  PostojiCenovnik = retValOk
End Function
Public Function PostojiOtvorenRacunZaSto(BrojStola As Long) As Boolean
    Dim BrojKartice
    BrojKartice = DLookup("[BrojKartice]", "OtvoreniRacuniSaBrojemKartice", "[BrojStola] = " & BrojStola)
    BrojKartice = Nz(BrojKartice, "")
    PostojiOtvorenRacunZaSto = (BrojKartice <> "")
End Function

Public Function OtvoriRacun(ByVal BrojStola As Integer, IDKonobar As Long, IDProdavnica As Long, IDKomitent As Long, IDKasa As Long, LimitIznos As Currency) As Long
On Error GoTo Err_Point

    Dim TableDok As DAO.Recordset
    Dim NoviIDRacun As Long
    
    Set TableDok = CurrentDb.TableDefs("T_MPDokumenta").OpenRecordset(dbOpenDynaset, dbSeeChanges)
    TableDok.AddNew
    
    TableDok!IDFirma = F_IDFirma()
    TableDok!Godina = F_Godina()
    TableDok!IDProdavnica = IDProdavnica
    TableDok!IDKupac = IDKomitent
    TableDok!IDKasa = IDKasa
    TableDok![Sifra prodavca] = IDKonobar
    TableDok!BrojStola = BrojStola
   ' If BBCFG.SQLDB Then
   '    TableDok!IDDok = SledeciID("T_MPDokumenta", "IDDok")    'Nz(DMax("IDDok", "T_MPDokumenta"), 0) + 1
   ' End If
    
    TableDok![Broj dokumenta] = IDProdavnica & "-" & TableDok!IDDok
    TableDok![Vrsta dokumenta] = "MP1"
    TableDok![LimitIznos] = LimitIznos
    'NoviIDRacun = TableDok!IDDok
     TableDok.Update
    NoviIDRacun = LastIDENTITY()  'TableDok!IDDok
     TableDok.FindFirst "IDDok=" & CStr(NoviIDRacun)
     If Not TableDok.NoMatch Then
        TableDok.Edit
        TableDok![Broj dokumenta] = IDProdavnica & "-" & NoviIDRacun
        TableDok.Update
     End If
Exit_Point:
  On Error Resume Next
    TableDok.Close
    Set TableDok = Nothing
    OtvoriRacun = NoviIDRacun
Exit Function

Err_Point:
    BBErrorMSG err, "OtvoriRacun"
    Resume Exit_Point
End Function

Public Sub ObrisiRacun(IDRacun As Long, IDProdavnica As Long, Ulaz As Boolean)
    Dim TableDok As DAO.Recordset
    Dim SQLCommand As String
    
    SQLCommand = "DELETE RacuniZaglavlja.*, RacuniZaglavlja.IDRacun, RacuniZaglavlja.IDProdavnica, RacuniZaglavlja.Ulaz FROM RacuniZaglavlja WHERE (((RacuniZaglavlja.IDRacun)=" & IDRacun & " ) AND ((RacuniZaglavlja.IDProdavnica)=" & IDProdavnica & ") AND ((RacuniZaglavlja.Ulaz)=" & Ulaz & " ));"
    
    DoCmd.RunSQL SQLCommand

End Sub
Public Function IsAutoNumber(stTableName As String, Optional stFieldName) As Boolean
'Modifikovano: 14-11-2019
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim fld As Field
    Dim BigBit As DAO.Database
    
    
If IsMissing(stFieldName) Then
   retValOk = False
   Set BigBit = CurrentDb
   For Each fld In BigBit.TableDefs(stTableName).Fields
    retValOk = retValOk Or ((fld.Attributes And dbAutoIncrField) = dbAutoIncrField)
   Next
   BigBit.Close
   Set BigBit = Nothing
Else
     retValOk = ((CurrentDb.TableDefs(stTableName).Fields(stFieldName).Attributes And dbAutoIncrField) = dbAutoIncrField)
End If

Exit_Point:
 
 On Error Resume Next
 IsAutoNumber = retValOk

Exit Function

Err_Point:
 BBErrorMSG err, "IsAutoNumber"
 retValOk = False
 Resume Exit_Point
End Function
