Attribute VB_Name = "modSyncMirrorTabele"
Option Compare Database
Option Explicit

'===========================================================
'  SyncMirrorZaProjekt
'
'  Za dati ZaIDCrtez:
'   1) Iz SQL-a (PDM) povlaèi listu KataloskiBroj za NABAVNE delove iz BOM-a
'   2) Iz eksternog lagera (EXT_BB_T_25.MDB) èita stavke za te kataloške brojeve
'   3) U SQL mirror (RobnaDokumentaMirror, RobneStavkeMirror) obriše samo
'      stare stavke za te kataloške brojeve i upiše sveže.
'
'  Pretpostavlja:
'   - BBCFG.CNNString -> konekcioni string ka SQL bazi (QBigTehn)
'   - BazaZaTip("EXTBAZA") -> vraæa putanju do BB_T_25.MDB
'   - U SQL-u postoje tabele:
'       dbo.RobnaDokumentaMirror (IDDok, VrstaDokumenta, DatumDokumenta)
'       dbo.RobneStavkeMirror    (IDStavke, IDDok, SifraArtikla,
'                                KataloskiBroj, IDMagacin,
'                                KolicinaUlaz, KolicinaIzlaz, PoslednjaIzmena)
'===========================================================
Public Function SyncMirrorZaKatBroj(ByVal KatBroj As String, ByVal SessionID As String) As Boolean
On Error GoTo Err_Handler

    Dim dbExt   As DAO.Database
    Dim rsExt   As DAO.Recordset
    Dim stSQL   As String
    Dim stBazaExt As String
    
    Dim kUlaz As Double, kIzlaz As Double

    SyncMirrorZaKatBroj = False
    If Len(Nz(KatBroj, "")) = 0 Then Exit Function

    '------------------------------------------------
    ' 1) OBRIŠI STARE PODATKE samo za ovu sesiju
    '------------------------------------------------
    stSQL = "DELETE FROM RobneStavkeMirror " & _
            "WHERE SessionID = '" & SessionID & "' " & _
            "  AND KataloskiBroj = N'" & SqlEscape(KatBroj) & "'"
    Call ADO_ExecSQL(CNN_CurrentDataBase(), stSQL)

    '------------------------------------------------
    ' 2) OTVORI EXTERNI LAGER (linkovane tabele)
    '------------------------------------------------
    Set dbExt = CurrentDb

    '------------------------------------------------
    ' 3) UÈITAJ STAVKE iz Access baze za taj kataloški broj
    '------------------------------------------------
    stSQL = _
        "SELECT " & _
        "   RS.IDStavke, " & _
        "   RS.IDDok, " & _
        "   RS.[Sifra artikla] AS SifraArtikla, " & _
        "   RS.IDMagacin, " & _
        "   RS.Kolicina, " & _
        "   RA.[Kataloski broj] AS KataloskiBroj, " & _
        "   D.[Vrsta dokumenta] AS VrstaDokumenta, " & _
        "   D.[Datum dokumenta] AS DatumDokumenta " & _
        "FROM ([EXT_T_Robne stavke] AS RS " & _
        "INNER JOIN EXT_R_Artikli AS RA " & _
        "   ON RS.[Sifra artikla] = RA.[Sifra artikla]) " & _
        "INNER JOIN [EXT_T_Robna dokumenta] AS D " & _
        "   ON RS.IDDok = D.IDDok " & _
        "WHERE RA.[Kataloski broj] = '" & SqlEscape(KatBroj) & "'"

    Set rsExt = dbExt.OpenRecordset(stSQL, dbOpenSnapshot)

    If rsExt.EOF Then GoTo Clean_Exit

    '------------------------------------------------
    ' 4) INSERT u MIRROR
    '------------------------------------------------
    BeginTrans

    Do While Not rsExt.EOF

        ' INSERT dokumenta (za ovaj session)
        stSQL = _
            "IF NOT EXISTS (" & _
            "    SELECT 1 FROM RobnaDokumentaMirror " & _
            "    WHERE SessionID = '" & SessionID & "' " & _
            "      AND IDDok = " & CLng(rsExt!IDDok) & _
            ") " & _
            "INSERT INTO RobnaDokumentaMirror " & _
            "(SessionID, IDDok, VrstaDokumenta, DatumDokumenta) VALUES (" & _
            "'" & SessionID & "', " & _
            CLng(rsExt!IDDok) & ", " & _
            "N'" & SqlEscape(Nz(rsExt!VrstaDokumenta, "")) & "', " & _
            "'" & Format$(rsExt!DatumDokumenta, "yyyy-mm-dd") & "')"

        Call ADO_ExecSQL(CNN_CurrentDataBase(), stSQL)

        kUlaz = 0: kIzlaz = 0
        If Nz(rsExt!Kolicina, 0) > 0 Then kUlaz = CDbl(rsExt!Kolicina)
        If Nz(rsExt!Kolicina, 0) < 0 Then kIzlaz = Abs(CDbl(rsExt!Kolicina))

        ' INSERT stavke
        stSQL = _
            "INSERT INTO RobneStavkeMirror " & _
            "(SessionID, IDStavke, IDDok, SifraArtikla, KataloskiBroj, IDMagacin, " & _
            " KolicinaUlaz, KolicinaIzlaz, PoslednjaIzmena) VALUES (" & _
            "'" & SessionID & "', " & _
            CLng(rsExt!IDStavke) & ", " & _
            CLng(rsExt!IDDok) & ", " & _
            CLng(rsExt!SifraArtikla) & ", " & _
            "N'" & SqlEscape(KatBroj) & "', " & _
            CLng(rsExt!IDMagacin) & ", " & _
            SqlDec(kUlaz) & ", " & _
            SqlDec(kIzlaz) & ", GETDATE())"

        Call ADO_ExecSQL(CNN_CurrentDataBase(), stSQL)

        rsExt.MoveNext
    Loop

    CommitTrans
    SyncMirrorZaKatBroj = True


Clean_Exit:
    On Error Resume Next
    If Not rsExt Is Nothing Then rsExt.Close
    Exit Function

Err_Handler:
    Debug.Print "SyncMirrorZaKatBroj ERROR: "; err.Number; err.Description
    Resume Clean_Exit
End Function


'===========================================================
' Pomocne funkcije
'===========================================================

Private Function SqlEscape(ByVal s As String) As String
    SqlEscape = Replace(s, "'", "''")
End Function

Private Function SqlDec(ByVal d As Double) As String
    SqlDec = Replace(CStr(d), ",", ".")
End Function

