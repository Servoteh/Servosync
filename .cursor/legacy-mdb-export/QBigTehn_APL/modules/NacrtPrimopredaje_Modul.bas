Attribute VB_Name = "NacrtPrimopredaje_Modul"
Option Compare Database
Option Explicit
Public gRokIzradeResult As Variant
Public gDialogResultOK As Boolean

Public Function BrojOtvorenihZaglavljaNacrta() As Integer

    Dim rstNacrt As ADODB.Recordset
    Dim stSQL As String
    Dim SifraRadnika As Long
    
    SifraRadnika = IDRadnikZaCurrentUser

    stSQL = "SELECT IDNacrtPrim, DatumNacrta, BrojPredmeta, BrojKomada,Komitenti.Naziv AS NazivKomitenta"
    stSQL = stSQL & " FROM NacrtPrimopredaje INNER JOIN Predmeti ON NacrtPrimopredaje.IDPredmet = Predmeti.IDPredmet"
    stSQL = stSQL & " INNER JOIN Komitenti ON Komitenti.Sifra = Predmeti.IDKomitent"
    stSQL = stSQL & " WHERE (IDProjektant = " & SifraRadnika & ")"
    stSQL = stSQL & " AND (IDStatusNacrtaPrimopredaje = " & 0 & ")"
    
    
    Set rstNacrt = ADO_GetRST(BBCFG.CNNString, stSQL)
    BrojOtvorenihZaglavljaNacrta = rstNacrt.RecordCount
End Function

Public Function PromeniStatusCrtezaPriRaduSaNacrtom(ByVal IDNacrtPrim As Long, ByVal IDStatusCrteza As Integer) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    Dim stSQL As String
    
    ' èuvari
    If IDNacrtPrim <= 0 Then
        PromeniStatusCrtezaPriRaduSaNacrtom = False
        Exit Function
    End If
    ' opc: ogranièi vrednosti statusa na dozvoljeni skup (0,1,2...)
    If IDStatusCrteza < 0 Or IDStatusCrteza > 2 Then ' prilagodi gornju granicu po tvojoj šemi
        PromeniStatusCrtezaPriRaduSaNacrtom = False
        Exit Function
    End If
    
    stSQL = ""
    stSQL = stSQL & "UPDATE pc SET pc.IDStatusCrteza = " & IDStatusCrteza & vbCrLf
    stSQL = stSQL & "FROM dbo.PDMCrtezi AS pc " & vbCrLf
    stSQL = stSQL & "INNER JOIN dbo.NacrtPrimopredajeStavke AS nps " & vbCrLf
    stSQL = stSQL & "   ON nps.IDCrtez = pc.IDCrtez " & vbCrLf
    stSQL = stSQL & "WHERE nps.IDNacrtPrim = " & IDNacrtPrim & " " & vbCrLf
    ' stSQL = stSQL & "  AND pc.Nabavka = 0 " & vbCrLf   ' <- ukljuèi ako treba
    stSQL = stSQL & "  AND ISNULL(pc.IDStatusCrteza, 0) < " & IDStatusCrteza & ";"

    If ADO_ExecSQL(CNN_CurrentDataBase, stSQL) Then
        retValOk = True
    Else
        retValOk = False
    End If
    
Exit_Point:
    On Error Resume Next
    PromeniStatusCrtezaPriRaduSaNacrtom = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "PromeniStatusCrtezaPriRaduSaNacrtom"
    retValOk = False
    Resume Exit_Point
End Function


Public Function DodajCrtezUNacrt( _
    ByVal pIDNacrtPrim As Long, _
    ByVal pIDCrtez As Long, _
    ByVal pTipNacrta As Integer) As Boolean

On Error GoTo Err_Point

    Dim retOk As Boolean: retOk = True
    Dim saDubinom As Boolean
    Dim imaKomponente As Boolean
    Dim oldTop As Variant, newTop As Variant, IDPredmet As Variant

    ' 1) SaDubinom
    If pTipNacrta = 1 Then
        saDubinom = True                           ' glavni: uvek ceo BOM
    Else
        imaKomponente = ADO_GetValFromUDFS(CNN_CurrentDataBase, _
                          "fsIzabraniCrtezImaKomponente", pIDCrtez)
        saDubinom = (imaKomponente = True)         ' parcijalno: sklop -> BOM; deo -> samo taj deo
    End If

    ' 2) Ako je glavni, zapamti staro top-level stanje
    If pTipNacrta = 1 Then
        'oldTop = DLookup("IDGlavniCrtez", "NacrtPrimopredaje", "IDNacrtPrim=" & pIDNacrtPrim)
        oldTop = Nz(ADO_Lookup(CNN_CurrentDataBase, "[IDGlavniCrtez]", "NacrtPrimopredaje", "IDNacrtPrim = " & CLng(pIDNacrtPrim)), 0)
        'IDPredmet = DLookup("IDPredmet", "NacrtPrimopredaje", "IDNacrtPrim=" & pIDNacrtPrim)
        IDPredmet = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDPredmet", "NacrtPrimopredaje", "IDNacrtPrim= " & CLng(pIDNacrtPrim)), 0)
    End If

    ' 3) Upis stavki (SP raèuna baseline i ×BrojKomada)
    retOk = ADO_ExecSP(CNN_CurrentDataBase, "spDodajCrtezSaDubinom", pIDNacrtPrim, pIDCrtez, IIf(saDubinom, SQLFormatBoolean(True), SQLFormatBoolean(False)))
    If Not retOk Then GoTo Exit_Point

    ' 4) SAMO ZA GLAVNI: ako smo sada postavili top-level, uradi backfill mapiranja
    If pTipNacrta = 1 Then
        'newTop = DLookup("IDGlavniCrtez", "NacrtPrimopredaje", "IDNacrtPrim=" & pIDNacrtPrim)
        newTop = Nz(ADO_Lookup(CNN_CurrentDataBase, "[IDGlavniCrtez]", "NacrtPrimopredaje", "IDNacrtPrim = " & CLng(pIDNacrtPrim)), 0)
        If (IsNull(oldTop) Or oldTop = 0) And (Not IsNull(newTop)) And newTop > 0 Then
            Call ADO_ExecSP(CNN_CurrentDataBase, "spUpdateIDGlavniCrtezZaSklop", _
                            CLng(newTop), IIf(IsNull(IDPredmet), Null, CLng(IDPredmet)), 0)
        End If
    End If

    ' 5) Pred-provera / flagovi (ako koristiš te korake)
    Call ADO_ExecSP(CNN_CurrentDataBase, "spPredproveraDuplikata", pIDNacrtPrim)
    Call ADO_ExecSP(CNN_CurrentDataBase, "spFlagPredProveraDuplikat", pIDNacrtPrim)
    
    ' 6) Osvježi prikaz stavki na formi (prilagodi ime subforma/kontrole)
    On Error Resume Next
    Forms!NacrtPrimopredaje!Nacrt_Stavke.Requery
    On Error GoTo Err_Point

    ' Info poruka (po želji)
    MsgBox "Crtež je dodat u nacrt.", vbInformation

Exit_Point:
    DodajCrtezUNacrt = retOk
    Exit Function

Err_Point:
    BBErrorMSG err, "DodajCrtezUNacrt"
    retOk = False
    Resume Exit_Point
End Function

Public Function DefinisiStatusNacrtaPrimopredaje(ByVal IDNacrtPrim As Long, ByVal IDStatusNacrta As Integer) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim stSQL As String
    
    retValOk = True
    ' èuvari
    If IDNacrtPrim <= 0 Then
        DefinisiStatusNacrtaPrimopredaje = False
        Exit Function
    End If
    ' opc: ogranièi vrednosti statusa na dozvoljeni skup (0,1,2...)
    If IDStatusNacrta < 0 Or IDStatusNacrta > 1 Then ' prilagodi gornju granicu po tvojoj šemi
        DefinisiStatusNacrtaPrimopredaje = False
        Exit Function
    End If
    
    stSQL = ""
    stSQL = stSQL & "UPDATE pc SET pc.IDStatusNacrtaPrimopredaje = " & CStr(IDStatusNacrta) & vbCrLf
    stSQL = stSQL & "FROM dbo.NacrtPrimopredaje AS pc " & vbCrLf
    stSQL = stSQL & "WHERE pc.IDNacrtPrim = " & CStr(IDNacrtPrim) & vbCrLf
    stSQL = stSQL & "  AND ISNULL(pc.IDStatusNacrtaPrimopredaje, 0) < " & CStr(IDStatusNacrta) & ";"

    If ADO_ExecSQL(CNN_CurrentDataBase, stSQL) Then
        retValOk = True
    Else
        retValOk = False
    End If
    
Exit_Point:
    On Error Resume Next
    DefinisiStatusNacrtaPrimopredaje = retValOk
    Exit Function

Err_Point:
    BBErrorMSG err, "DefinisiStatusNacrtaPrimopredaje"
    retValOk = False
    Resume Exit_Point
End Function
Public Function KreirajPorukuPoslePrimopredaje_SLAVISA(ByVal stBrojPrimopredaje As String, ByVal nSifraRadnika As Long, Optional stZaKoga As String = "") As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim Poruka As String
    Dim stSQL As String
    Dim stSQLWhere As String
    Dim chNavodnici As String
    Dim Radnik As String
    
        retValOk = True
        Radnik = Nz(ADO_Lookup(CNN_CurrentDataBase, "ImeIPrezime", "tRadnici", "[SifraRadnika] = " & nSifraRadnika), "")
        If BBCFG.SQLDB Then
            chNavodnici = Chr(39)
        Else
            chNavodnici = Chr(34)
        End If
        
        If stZaKoga = "" Then
            stZaKoga = "Za sve"
        End If
        
        Poruka = Radnik & " je kreirao-la novu primopredaju i njen broj je '" & stBrojPrimopredaje & "'" & vbCrLf
        'Poruka = Poruka & "
        
        stSQL = ""
        stSQL = stSQL & "    INSERT INTO T_Planer" & vbCrLf
        stSQL = stSQL & "            (" & vbCrLf
        stSQL = stSQL & "              KadaDatum" & vbCrLf
        stSQL = stSQL & "            , KadaVreme" & vbCrLf
        stSQL = stSQL & "            , Subject" & vbCrLf
        stSQL = stSQL & "            , Poruka" & vbCrLf
        stSQL = stSQL & "            , OdKoga" & vbCrLf
        stSQL = stSQL & "            , ZaKoga" & vbCrLf
        stSQL = stSQL & "            )" & vbCrLf
        stSQL = stSQL & "   VALUES" & vbCrLf
        stSQL = stSQL & "            (" & vbCrLf
        stSQL = stSQL & "            " & SQLFormatDatuma(Date) & vbCrLf
        stSQL = stSQL & "            ," & SQLFormatVreme(Time) & vbCrLf
        stSQL = stSQL & "            ," & chNavodnici & Replace("Kreirana nova primopredaja", chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
        stSQL = stSQL & "            ," & chNavodnici & Replace(Poruka, chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
        stSQL = stSQL & "            ," & chNavodnici & Replace(CurrentUser(), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
        stSQL = stSQL & "            ," & chNavodnici & Replace(stZaKoga, chNavodnici, chNavodnici & chNavodnici) & chNavodnici
        stSQL = stSQL & "            )" & vbCrLf
        
        retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
            
            'IDVPFR = ADO_IDENTITY
            
Exit_Point:
    On Error Resume Next
   
    KreirajPorukuPoslePrimopredaje_SLAVISA = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "KreirajPorukuPoslePrimopredaje"
    retValOk = False
    Resume Exit_Point
End Function

Public Function KreirajPorukuPoslePrimopredaje( _
    ByVal stBrojPrimopredaje As String, _
    ByVal nSifraRadnika As Long, _
    Optional ByVal stZaKoga As String = "" _
) As Boolean

On Error GoTo Err_Point

    Dim retValOk As Boolean
    Dim Poruka As String
    Dim stSQL As String
    Dim chNavodnici As String
    Dim Radnik As String

    retValOk = True

    Radnik = Nz(ADO_Lookup( _
                    CNN_CurrentDataBase, _
                    "ImeIPrezime", _
                    "tRadnici", _
                    "[SifraRadnika] = " & nSifraRadnika), _
                "")

    ' Standardizuj ZaKoga
    stZaKoga = Trim(stZaKoga)
    If stZaKoga = "" Then
        stZaKoga = "ZaSve"
    End If

    ' Escape karakter za string
    If BBCFG.SQLDB Then
        chNavodnici = Chr(39)   ' '
    Else
        chNavodnici = Chr(34)   ' "
    End If

    Poruka = Radnik & " je kreirao-la novu primopredaju i njen broj je '" & _
              stBrojPrimopredaje & "'"

    ' (opciono) ukloni nove redove
    Poruka = Replace(Poruka, vbCrLf, " ")

    stSQL = ""
    stSQL = stSQL & "INSERT INTO T_Planer" & vbCrLf
    stSQL = stSQL & "(" & vbCrLf
    stSQL = stSQL & "  KadaDatum," & vbCrLf
    stSQL = stSQL & "  KadaVreme," & vbCrLf
    stSQL = stSQL & "  Subject," & vbCrLf
    stSQL = stSQL & "  Poruka," & vbCrLf
    stSQL = stSQL & "  OdKoga," & vbCrLf
    stSQL = stSQL & "  ZaKoga" & vbCrLf
    stSQL = stSQL & ")" & vbCrLf
    stSQL = stSQL & "VALUES" & vbCrLf
    stSQL = stSQL & "(" & vbCrLf

    If BBCFG.SQLDB Then
        stSQL = stSQL & "  CAST(GETDATE() AS DATE)," & vbCrLf
        stSQL = stSQL & "  GETDATE()," & vbCrLf
    Else
        stSQL = stSQL & "  " & SQLFormatDatuma(Date) & "," & vbCrLf
        stSQL = stSQL & "  " & SQLFormatVreme(Time) & "," & vbCrLf
    End If

    stSQL = stSQL & "  " & chNavodnici & _
                     Replace("Kreirana nova primopredaja", chNavodnici, chNavodnici & chNavodnici) & _
                     chNavodnici & "," & vbCrLf

    stSQL = stSQL & "  " & chNavodnici & _
                     Replace(Poruka, chNavodnici, chNavodnici & chNavodnici) & _
                     chNavodnici & "," & vbCrLf

    stSQL = stSQL & "  " & chNavodnici & _
                     Replace(CurrentUser, chNavodnici, chNavodnici & chNavodnici) & _
                     chNavodnici & "," & vbCrLf

    stSQL = stSQL & "  " & chNavodnici & _
                     Replace(stZaKoga, chNavodnici, chNavodnici & chNavodnici) & _
                     chNavodnici & vbCrLf

    stSQL = stSQL & ")"

    retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)

Exit_Point:
    KreirajPorukuPoslePrimopredaje = retValOk
    Exit Function

Err_Point:
    BBErrorMSG err, "KreirajPorukuPoslePrimopredaje"
    retValOk = False
    Resume Exit_Point
End Function

