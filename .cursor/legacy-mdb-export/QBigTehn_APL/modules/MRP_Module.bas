Attribute VB_Name = "MRP_Module"
Option Compare Database
Option Explicit
'Public pZaIDPotreba As Long
'Public Function F_ZaIDPotreba() As Long
'    If pZaIDPotreba = 0 Then
'        MsgBox "IDPotreba nije postavljen!", vbExclamation
'    End If
'    F_ZaIDPotreba = pZaIDPotreba
'End Function
Public Function NapuniTMP_MRP_Stanje(Optional ByVal ZaIDPotrebe As Long = 0) As Boolean
On Error GoTo Err_Point

    Dim rs As DAO.Recordset
    Dim sql As String
    Dim batch As String
    Dim batchSize As Long
    Dim cnt As Long

    batchSize = 300

    ' =====================================
    ' 1. KREIRAJ TMP MDB
    ' =====================================
    'If Nz(ZaIDPotrebe, 0) = 0 Then
    '    Call KreirajTmpTabeluUTmpBazi("TMP_MRP_Stanje", "qry_TMP_MRP_Stanje")
    'Else
    '    pZaIDPotreba = ZaIDPotrebe
    '    Call KreirajTmpTabeluUTmpBazi("TMP_MRP_Stanje", "qry_TMP_MRP_StanjeZaIDPotreba")
    'End If
    If Nz(ZaIDPotrebe, 0) = 0 Then

        On Error Resume Next
        TempVars.Remove "ZaIDPotreba"
        On Error GoTo Err_Point

        Call KreirajTmpTabeluUTmpBazi("TMP_MRP_Stanje", "qry_TMP_MRP_Stanje")

    Else

        On Error Resume Next
        TempVars.Remove "ZaIDPotreba"
        On Error GoTo Err_Point

        TempVars.Add "ZaIDPotreba", CLng(ZaIDPotrebe)

        Call KreirajTmpTabeluUTmpBazi("TMP_MRP_Stanje", "qry_TMP_MRP_StanjeZaIDPotreba")

    End If
    

    ' =====================================
    ' 2. OBRIŠI SQL TMP
    ' =====================================
    ADO_ExecSQL CNN_CurrentDataBase, "DELETE FROM MRP_StanjeArtikala_TMP"

    ' =====================================
    ' 3. ÈITAJ TMP MDB
    ' =====================================
    Set rs = CurrentDb.OpenRecordset("SELECT * FROM TMP_MRP_Stanje", dbOpenSnapshot)

    'If rs.EOF Then Exit Function
    If rs.EOF Then
        NapuniTMP_MRP_Stanje = True
        Exit Function
    End If
    ' =====================================
    ' 4. BATCH INSERT U SQL
    ' =====================================
    batch = ""
    cnt = 0

    Do While Not rs.EOF

        If cnt = 0 Then
            batch = "INSERT INTO MRP_StanjeArtikala_TMP (SifraArtikla, Zalihe, Rezervisane, KataloskiBroj, Naziv, JedinicaMere) VALUES "
        Else
            batch = batch & ","
        End If

        batch = batch & "(" & _
            rs!SifraArtikla & "," & _
            Replace(Nz(rs!Zalihe, 0), ",", ".") & "," & _
            Replace(Nz(rs!Rezervisane, 0), ",", ".") & "," & _
            "'" & Replace(Nz(rs![Kataloski broj], ""), "'", "''") & "'," & _
            "'" & Replace(Nz(rs!Naziv, ""), "'", "''") & "'," & _
            "'" & Replace(Nz(rs![Jedinica mere], ""), "'", "''") & "'" & _
        ")"

        cnt = cnt + 1

        If cnt >= batchSize Then
            ADO_ExecSQL CNN_CurrentDataBase, batch
            batch = ""
            cnt = 0
        End If

        rs.MoveNext
    Loop

    If cnt > 0 Then
        ADO_ExecSQL CNN_CurrentDataBase, batch
    End If

    NapuniTMP_MRP_Stanje = True
    Exit Function

Err_Point:
    NapuniTMP_MRP_Stanje = False
    BBErrorMSG err, "NapuniTMP_MRP_Stanje"

End Function

Public Function GetMRPSyncInfo() As String
On Error GoTo Err_Point

    Dim rs As ADODB.Recordset
    Dim sql As String

    sql = "SELECT PoslednjiSync FROM MRP_SyncStatus WHERE SyncKey = 'Lager'"

    Set rs = ADO_GetRST(CNN_CurrentDataBase, sql)

    If Not rs.EOF Then
        If Not IsNull(rs!PoslednjiSync) Then
            GetMRPSyncInfo = "Lager ažuriran: " & Format(rs!PoslednjiSync, "dd.mm.yyyy HH:nn")
        Else
            GetMRPSyncInfo = "Lager nije još ažuriran"
        End If
    Else
        GetMRPSyncInfo = "Nema sync statusa"
    End If
    
    'If DateDiff("n", rs!PoslednjiSync, Now()) > 30 Then
    '    GetMRPSyncInfo = GetMRPSyncInfo & " ?"
    'End If
    
Exit_Point:
    Exit Function

Err_Point:
    GetMRPSyncInfo = "Greška pri èitanju sync statusa"
    Resume Exit_Point
End Function
Public Function InfoMRP_Potrebe(IDCrtez As Long, TipEksplozije As Integer, BrojKomadaZaIzradu As Long) As String

    Dim rs As ADODB.Recordset
    Dim sql As String

    sql = _
        "SELECT COUNT(*) AS BrojArtikala," & _
        " SUM(Kolicina) AS UkupnaKolicina " & _
        "FROM dbo.ftMRP_PotrebeZaCrtez(" & _
        IDCrtez & "," & TipEksplozije & "," & BrojKomadaZaIzradu & ")"

    Set rs = ADO_GetRST(CNN_CurrentDataBase, sql)

    If Not rs.EOF Then

        InfoMRP_Potrebe = _
            "Artikala za nabavku: " & rs!BrojArtikala & vbCrLf & _
            "Ukupna kolièina: " & Format(rs!UkupnaKolicina, "0.###")

    End If

End Function
Public Function UpdateMRPStavke_SifraArtikla(ByVal pIDPotreba As Long) As Boolean

On Error GoTo Err_Handler

    Dim db As DAO.Database
    Dim rsStavke As ADODB.Recordset
    
    Dim rsArtikli As DAO.Recordset
    Dim rsDobavljaci As DAO.Recordset
    
    Dim sqlStavke As String
    
    Dim KataloskiBroj As String
    Dim SifraArtikla As Long
    Dim NazivArtikla As String
    Dim JedMere As String
    
    Dim DobavljacID As Long
    Dim VremeIsporuke As Long
    
    Dim retValOk As Boolean
    
    Set db = CurrentDb

    '-------------------------------------------------
    ' 1. Uèitaj artikle
    '-------------------------------------------------
    
    Set rsArtikli = db.OpenRecordset( _
        "SELECT [Kataloski broj], [Sifra artikla], Naziv, [Jedinica mere] " & _
        "FROM EXT_R_Artikli", dbOpenSnapshot)

    '-------------------------------------------------
    ' 2. Uèitaj dobavljaèe (primarni prvi)
    '-------------------------------------------------
    
    Set rsDobavljaci = db.OpenRecordset( _
        "SELECT IDArtikal, [Sifra dobavljaca], Primarni, VremeIsporuke " & _
        "FROM EXT_DobavljaciZaArtikal " & _
        "ORDER BY Primarni DESC", dbOpenSnapshot)

    '-------------------------------------------------
    ' 3. Uèitaj MRP stavke
    '-------------------------------------------------
    
    sqlStavke = _
        "SELECT IDPotrebaStavka, KataloskiBrojStavka " & _
        "FROM MRP_PotrebeStavke " & _
        "WHERE IDPotreba = " & pIDPotreba

    Set rsStavke = ADO_GetRST( _
                    CNN_CurrentDataBase, _
                    sqlStavke, _
                    dbOptimistic, _
                    adUseClient, _
                    adOpenStatic)

    If rsStavke.EOF Then
        UpdateMRPStavke_SifraArtikla = True
        GoTo Exit_Point
    End If

    rsStavke.MoveFirst

    Do While Not rsStavke.EOF

        KataloskiBroj = Trim(Nz(rsStavke!KataloskiBrojStavka, ""))

        If Len(KataloskiBroj) > 0 Then

            '-----------------------------------------
            ' ARTIKAL
            '-----------------------------------------
            
            rsArtikli.MoveFirst
            rsArtikli.FindFirst "[Kataloski broj] = '" & Replace(KataloskiBroj, "'", "''") & "'"

            If Not rsArtikli.NoMatch Then

                SifraArtikla = Nz(rsArtikli![Sifra artikla], 0)
                NazivArtikla = Nz(rsArtikli!Naziv, "-")
                JedMere = Nz(rsArtikli![Jedinica mere], "-")

                '-----------------------------------------
                ' DOBAVLJAÈ (primarni ili prvi)
                '-----------------------------------------
                
                DobavljacID = 0
                VremeIsporuke = 0

                If SifraArtikla <> 0 Then
                
                    rsDobavljaci.MoveFirst
                    rsDobavljaci.FindFirst "IDArtikal = " & SifraArtikla

                    If Not rsDobavljaci.NoMatch Then
                        DobavljacID = Nz(rsDobavljaci![Sifra dobavljaca], 0)
                        VremeIsporuke = Nz(rsDobavljaci!VremeIsporuke, 0)
                    End If

                End If

                '-----------------------------------------
                ' UPDATE
                '-----------------------------------------

                retValOk = ADO_UpdateColumn( _
                            CNN_CurrentDataBase, _
                            "MRP_PotrebeStavke", _
                            "SifraArtikla", _
                            SifraArtikla, _
                            "IDPotrebaStavka=" & rsStavke!IDPotrebaStavka)

                retValOk = ADO_UpdateColumn( _
                            CNN_CurrentDataBase, _
                            "MRP_PotrebeStavke", _
                            "NazivArtiklaStavka", _
                            ADO_SQLValue(NazivArtikla), _
                            "IDPotrebaStavka=" & rsStavke!IDPotrebaStavka)
                            
                retValOk = ADO_UpdateColumn( _
                            CNN_CurrentDataBase, _
                            "MRP_PotrebeStavke", _
                            "JedinicaMereStavka", _
                            ADO_SQLValue(JedMere), _
                            "IDPotrebaStavka=" & rsStavke!IDPotrebaStavka)

                retValOk = ADO_UpdateColumn( _
                            CNN_CurrentDataBase, _
                            "MRP_PotrebeStavke", _
                            "DobavljacID", _
                            DobavljacID, _
                            "IDPotrebaStavka=" & rsStavke!IDPotrebaStavka)

                retValOk = ADO_UpdateColumn( _
                            CNN_CurrentDataBase, _
                            "MRP_PotrebeStavke", _
                            "VremeIsporukeDana", _
                            VremeIsporuke, _
                            "IDPotrebaStavka=" & rsStavke!IDPotrebaStavka)

            End If

        End If

        rsStavke.MoveNext

    Loop

    UpdateMRPStavke_SifraArtikla = True

Exit_Point:

    On Error Resume Next
    rsStavke.Close
    Set rsStavke = Nothing
    Set rsArtikli = Nothing
    Set rsDobavljaci = Nothing
    Set db = Nothing

    Exit Function

Err_Handler:

    BBErrorMSG err, "UpdateMRPStavke_SifraArtikla"
    UpdateMRPStavke_SifraArtikla = False
    Resume Exit_Point

End Function
Public Function UpisiPotpisAkoJePrazan_MRP(ByVal pIDPotreba As Long) As Boolean

On Error GoTo Err_Point

    Dim retValOk As Boolean
    Dim stUser As String

    stUser = Replace(CurrentUser(), "'", "''")

    retValOk = ADO_UpdateColumn( _
        CNN_CurrentDataBase, _
        "MRP_Potrebe", _
        "DIVUnosaKorisnik", _
        "'" & stUser & "'", _
        "IDPotreba = " & pIDPotreba & " AND (DIVUnosaKorisnik IS NULL OR DIVUnosaKorisnik = '')")

    UpisiPotpisAkoJePrazan_MRP = retValOk
    Exit Function

Err_Point:
    BBErrorMSG err, "UpisiPotpisAkoJePrazan_MRP"
    UpisiPotpisAkoJePrazan_MRP = False

End Function

Public Function AzurirajLagerZaStavkePlaniraneNabavke(ByVal IDPotrebe As Long)
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    
    DoCmd.Hourglass True
    'pZaIDPotreba = IDPotrebe
    ' 1. Napuni TMP (Access › SQL)
    If Not NapuniTMP_MRP_Stanje(IDPotrebe) Then
        MsgBox "Greška pri punjenju TMP tabele.", vbCritical
        GoTo Err_Point
    End If

    retValOk = ADO_ExecSP(CNN_CurrentDataBase, "spMRP_SyncStanjeArtikala", CurrentUser())
        
    
Exit_Point:
    DoCmd.Hourglass False
    AzurirajLagerZaStavkePlaniraneNabavke = retValOk
    Exit Function

Err_Point:
    BBErrorMSG err, "AzurirajLagerZaStavkePlaniraneNabavke"
    retValOk = False
    Resume Exit_Point

End Function

