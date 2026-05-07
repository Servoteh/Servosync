Attribute VB_Name = "BRISANJE"
Option Compare Database
Option Explicit

Public Function ObrisiSadrzajTabele(TblName As String, Optional ByRef Komentar As String) As Boolean
On Error GoTo err_ObrisiSadrzajTabele

    Dim db As DAO.Database
    Dim QDel As DAO.QueryDef
    Dim varRet As Boolean
    
    Set db = CurrentDb
    
    'kreirmo PRIVREMENI objekat (jer mu je ime "")
    Set QDel = db.CreateQueryDef("", "DELETE [" & TblName & "].* FROM [" & TblName & "];")
    
   ' BeginTrans
        QDel.Execute dbSeeChanges
        'MsgBox "U tabeli " & tblName & " obrisano je " & QDel.RecordsAffected & " slogova."
        'Debug.Print "U tabeli " & TblName & " obrisano je " & QDel.RecordsAffected & " slogova."
        Komentar = Komentar & vbCrLf & "U tabeli " & TblName & " obrisano je " & QDel.RecordsAffected & " slogova."
    ' CommitTrans
varRet = True
exit_ObrisiSadrzajTabele:

On Error Resume Next
    
    db.Close
    Set db = Nothing
    Set QDel = Nothing
 
 ObrisiSadrzajTabele = varRet
Exit Function

err_ObrisiSadrzajTabele:

 Select Case err.Number
    
Case Else
 MsgBox "Error: " & err.Number & " " & err.Description
End Select
varRet = False
Resume exit_ObrisiSadrzajTabele
End Function
'OVO NE RADI
Public Function ObrisiSadrzajSvihTabelaUExtBazi(strdbName As String) As Boolean
On Error GoTo err_ObrisiSadrzajTabelaUBazi

Dim extDB As DAO.Database
Dim extTbl As DAO.TableDef
Dim extQDel As DAO.QueryDef

Set extDB = OpenDatabase(strdbName, , , "UID=Slavisa")
For Each extTbl In extDB.TableDefs
    'Debug.Print extTbl.Name, IIf(Len(extTbl.Connect) > 0, "LINKED", "")
    
    'Proveravamo da li je tabela linkovana
    'i ako jeste ne radimo nista
    If Len(extTbl.Connect) = 0 Then
        Set extQDel = extDB.CreateQueryDef("", "DELETE [" & extTbl.Name & "].* FROM [" & extTbl.Name & "];")
        extQDel.Execute
    End If
Next extTbl

exit_ObrisiSadrzajTabelaUBazi:

'On Error Resume Next
Set extTbl = Nothing
Set extQDel = Nothing
extDB.Close
Set extDB = Nothing
Exit Function

err_ObrisiSadrzajTabelaUBazi:
 Select Case err.Number
 Case Else
  MsgBox "Error: " & err.Number & " " & err.Description
 End Select
 Resume exit_ObrisiSadrzajTabelaUBazi

End Function
Public Function ObrisiSadrzajSvihTabelaUBaziZaTip(TipBaze As String) As Boolean
On Error GoTo err_ObrisiSadrzajTabelaUBazi
Dim varRet As Boolean
Dim db As DAO.Database
Dim Qrst As DAO.QueryDef
Dim rst As DAO.Recordset

Set db = CurrentDb
Set Qrst = db.CreateQueryDef("", "SELECT BazeITabele.* FROM Baze " & _
                                 "INNER JOIN BazeITabele ON Baze.IDBaze = BazeITabele.IDBaze " & _
                                 "WHERE (((Baze.TipBaze)='" & TipBaze & "')) " & _
                                 "ORDER BY BazeITabele.ID;")



Set rst = Qrst.OpenRecordset()

rst.MoveFirst
varRet = True
While Not rst.EOF
    'varRet = varRet And ObrisiSadrzajTabele(rst("Name"))
    Debug.Print rst("Name")
    rst.MoveNext
Wend
 varRet = True
    

exit_ObrisiSadrzajTabelaUBazi:
On Error Resume Next

rst.Close
Set rst = Nothing
Set Qrst = Nothing
db.Close
Set db = Nothing
ObrisiSadrzajSvihTabelaUBaziZaTip = varRet
Exit Function

err_ObrisiSadrzajTabelaUBazi:
 Select Case err.Number
 Case Else
  MsgBox "Error: " & err.Number & " " & err.Description
 End Select
 Resume exit_ObrisiSadrzajTabelaUBazi

End Function
Public Function ObrisiBazuZaNovogKorisnika(ByRef Komentar As String) As Boolean
On Error GoTo err_ObrisiSadrzajTabelaUBazi
Dim varRet As Boolean
    
    varRet = varRet And ObrisiSadrzajTabele("Cenovnik", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("Depoziti", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("InoKontniPlan", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("KNG_Artikli", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("KNG_Artikli_2", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("Komitenti", Komentar)
    'varRet = varRet And ObrisiSadrzajTabele("Kontni plan",komentar)
    'varRet = varRet And ObrisiSadrzajTabele("KOPIJA Robna dokumenta",komentar)
    'varRet = varRet And ObrisiSadrzajTabele("KOPIJA Robne stavke",komentar)
    varRet = varRet And ObrisiSadrzajTabele("Kursna lista", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("Magacini", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("MPStavkeNivelacije", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("Nalepnice", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("NalepniceNNID", Komentar)
    'varRet = varRet And ObrisiSadrzajTabele("OS_Stope revalorizacije",komentar)
    varRet = varRet And ObrisiSadrzajTabele("Parametri za rad", Komentar)
    'varRet = varRet And ObrisiSadrzajTabele("Pozicije",komentar)
    varRet = varRet And ObrisiSadrzajTabele("Prodavci", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("ProdavciZaGK", Komentar)
    'varRet = varRet And ObrisiSadrzajTabele("ProduktObrade",komentar)
    varRet = varRet And ObrisiSadrzajTabele("R_Artikli", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("R_Grupa", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("R_Podgrupa", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("R_Poreklo", Komentar)
    'varRet = varRet And ObrisiSadrzajTabele("R_Tarife",komentar)
    'varRet = varRet And ObrisiSadrzajTabele("R_Vrste dokumenata",komentar)
    'varRet = varRet And ObrisiSadrzajTabele("RadniNalozi",komentar)
    varRet = varRet And ObrisiSadrzajTabele("stavke nivelacije", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Glavna knjiga", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Knjiga KEPU", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_MPDokumenta", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_MPStavke", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Nalozi", Komentar)
    'varRet = varRet And ObrisiSadrzajTabele("T_OS_Sredstva",komentar)
    'varRet = varRet And ObrisiSadrzajTabele("T_OS_Stavke",komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Popis stavke", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Popis zaglavlja", Komentar)
    'varRet = varRet And ObrisiSadrzajTabele("T_Profakture",komentar)
    'varRet = varRet And ObrisiSadrzajTabele("T_Profakture stavke",komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Recepti", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Robna dokumenta", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Robne stavke", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Trebovanja", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Trebovanja stavke", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Trgovacka knjiga", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Usluge dokumenta", Komentar)
    varRet = varRet And ObrisiSadrzajTabele("T_Usluge stavke", Komentar)
    'varRet = varRet And ObrisiSadrzajTabele("Vrsta naloga",komentar)
    'varRet = varRet And ObrisiSadrzajTabele("Vrste sifara",komentar)

exit_ObrisiSadrzajTabelaUBazi:
On Error Resume Next

ObrisiBazuZaNovogKorisnika = varRet
Exit Function

err_ObrisiSadrzajTabelaUBazi:
 Select Case err.Number
 Case Else
  MsgBox "Error: " & err.Number & " " & err.Description
 End Select
 Resume exit_ObrisiSadrzajTabelaUBazi

End Function

Public Function DijalogZaBrisanjeRDok(IDDok As Long)
'Kreirano: 13-03-2020

On Error GoTo Err_Point
 Dim stFormName As String
 
 stFormName = "BrisanjeRobnogDokumenta"
 DoCmd.OpenForm stFormName
 Forms(stFormName).[IDDokZaBrisanje] = IDDok
 Forms(stFormName).PrimeniUslove
 
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "DijalogZaBrisanjeRDok"
 Resume Exit_Point
End Function
Public Function spObrisiGKZaAutoKnjizenja(IDFirma As Long, Godina As Long, OdLevel As Byte, DoLevel As Byte, OdDatumaNaloga As Date, DoDatumaNaloga As Date, ZaVrstuNaloga As Variant, ObrisiZaglavlja As Boolean) As Boolean
'kreirano: 18-08-2020
On Error GoTo Err_Point
Dim retValOk As Boolean

'     @IDFirma int = Null
'    ,@Godina int = Null
'    ,@OdLevel int = Null
'    ,@DoLevel int = Null
'    ,@OdDatumaNaloga Date = Null
'    ,@DoDatumaNaloga Date = Null
'    ,@ZaVrstuNaloga nvarchar(20) = Null
'    ,@ObrisiZaglavlja bit = 0

retValOk = ADO_ExecSP(BBCFG.CNNString, "spObrisiGKZaAutoKnjizenja", IDFirma, Godina, OdLevel, DoLevel, _
                    SQLFormatDatuma(OdDatumaNaloga, False), SQLFormatDatuma(DoDatumaNaloga, False), _
                    ZaVrstuNaloga, SQLFormatBoolean(ObrisiZaglavlja))

Exit_Point:
 On Error Resume Next
 spObrisiGKZaAutoKnjizenja = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "spObrisiGKZaAutoKnjizenja"
 retValOk = False
 Resume Exit_Point
End Function

