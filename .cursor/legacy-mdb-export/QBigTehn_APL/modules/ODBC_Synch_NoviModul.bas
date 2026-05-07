Attribute VB_Name = "ODBC_Synch_NoviModul"
Option Compare Database
Option Explicit

Public Function spSaveMPDok(IDFirma As Long, Godina As Long, OJ As Long, OD As Long _
                            , IDDok As Long, IDProdavnica As Long, IDKasa As Long _
                            , IDKupac As Long, IDRadniNalog, IDPredmet _
                            , BrojDokumenta As String, VrstaDokumenta As String _
                            , DatumDokumenta As Date, DatumValute As Date _
                            , Opis As Variant, SifraProdavca As Long, Kurs As Double _
                            , PrimljenNovac As Currency _
                            , PrimljeniCekovi As Currency _
                            , PrimljenaKartica As Currency _
                            , DatIVreme As Date _
                            , Depozit As Currency _
                            , RabatProc As Double _
                            , Smena As Byte _
                            , Level As Byte _
                            , Zakljucano As Boolean _
                            , StampanFiskalno As Boolean _
                            , FiktRabat As Double _
                            , BrojStola As Long _
                            , Naplaceno As Boolean _
                            , BrojStampanja As Integer _
                            , LimitIznos As Currency _
                            , PrimljeniVirmani As Currency _
                            ) As Boolean
'Kreirano: 12-03-2021
On Error GoTo Err_Point
Dim pCMD As New ADODB.Command

 pCMD.ActiveConnection = CNN_MasterDB
 pCMD.CommandType = adCmdStoredProc
 pCMD.CommandText = "spSaveMPDok"
 
 pCMD.Parameters.Refresh
    pCMD.Parameters("@IDFirma") = IDFirma
    pCMD.Parameters("@Godina") = Godina
    pCMD.Parameters("@OJ") = OJ
    pCMD.Parameters("@OD") = OD
    pCMD.Parameters("@IDDok") = IDDok
    pCMD.Parameters("@IDProdavnica") = IDProdavnica
    pCMD.Parameters("@IDKasa") = IDKasa
    pCMD.Parameters("@IDKupac") = IDKupac
    pCMD.Parameters("@IDRadniNalog") = IDRadniNalog
    pCMD.Parameters("@IDPredmet") = IDPredmet
    pCMD.Parameters("@BrojDokumenta") = BrojDokumenta
    pCMD.Parameters("@VrstaDokumenta") = VrstaDokumenta
    pCMD.Parameters("@DatumDokumenta") = SQLFormatDatuma(DatumDokumenta, False)
    pCMD.Parameters("@DatumValute") = SQLFormatDatuma(DatumValute, False)
    pCMD.Parameters("@Opis") = Opis
    pCMD.Parameters("@SifraProdavca") = SifraProdavca
    pCMD.Parameters("@Kurs") = Kurs
    pCMD.Parameters("@PrimljenNovac") = PrimljenNovac
    pCMD.Parameters("@PrimljeniCekovi") = PrimljeniCekovi
    pCMD.Parameters("@PrimljenaKartica") = PrimljenaKartica
    pCMD.Parameters("@DatIVreme") = SQLFormatDatumIVreme(DatIVreme, False)
    pCMD.Parameters("@Depozit") = Depozit
    pCMD.Parameters("@RabatProc") = RabatProc
    pCMD.Parameters("@Smena") = Smena
    pCMD.Parameters("@Level") = Level
    pCMD.Parameters("@Zakljucano") = SQLFormatBoolean(Zakljucano)
    pCMD.Parameters("@StampanFiskalno") = SQLFormatBoolean(StampanFiskalno)
    pCMD.Parameters("@FiktRabat") = FiktRabat
    pCMD.Parameters("@BrojStola") = BrojStola
    pCMD.Parameters("@Naplaceno") = SQLFormatBoolean(Naplaceno)
    pCMD.Parameters("@BrojStampanja") = BrojStampanja
    pCMD.Parameters("@LimitIznos") = LimitIznos
    pCMD.Parameters("@PrimljeniVirmani") = PrimljeniVirmani
    
  pCMD.Execute
Exit_Point:
 On Error Resume Next
  spSaveMPDok = (pCMD.ActiveConnection.Errors.Count = 0)
  pCMD.ActiveConnection.Close
  Set pCMD = Nothing
  
Exit Function
Err_Point:
  BBErrorMSG err, "spSaveMPDok"
  Resume Exit_Point:
End Function
Public Function spSaveMPStav(IDStavke As Long _
                            , IDDok As Long _
                            , IDProdavnice As Long _
                            , IDKasa As Long _
                            , SifraArtikla As Long _
                            , Kolicina As Double _
                            , KalkulativnaMPCena As Currency _
                            , StvarnaMPCena As Currency _
                            , TAKSA As Currency _
                            , TarifaRoba As String _
                            , IDStavMagOtpreme As Long _
                            , Porudzbina As Byte _
                            , DatIVremePor As Date _
                            , Pripremljeno As Boolean _
                            , Izdato As Boolean _
                            , DatIVremePripreme As Variant) As Boolean
                            
'Kreirano: 12-03-2021
On Error GoTo Err_Point
Dim pCMD As New ADODB.Command

 pCMD.ActiveConnection = CNN_MasterDB
 pCMD.CommandType = adCmdStoredProc
 pCMD.CommandText = "spSaveMPStav"
 
 pCMD.Parameters.Refresh
    pCMD.Parameters("@IDStavke") = IDStavke
    pCMD.Parameters("@IDDok") = IDDok
    pCMD.Parameters("@IDProdavnice") = IDProdavnice
    pCMD.Parameters("@IDKasa") = IDKasa
    pCMD.Parameters("@SifraArtikla") = SifraArtikla
    pCMD.Parameters("@Kolicina") = Kolicina
    pCMD.Parameters("@KalkulativnaMPCena") = KalkulativnaMPCena
    pCMD.Parameters("@StvarnaMPCena") = StvarnaMPCena
    pCMD.Parameters("@Taksa") = TAKSA
    pCMD.Parameters("@TarifaRoba") = TarifaRoba
    pCMD.Parameters("@IDStavMagOtpreme") = IDStavMagOtpreme
    pCMD.Parameters("@Porudzbina") = Porudzbina
    pCMD.Parameters("@DatIVremePor") = SQLFormatDatumIVreme(DatIVremePor, False)
    pCMD.Parameters("@Pripremljeno") = Pripremljeno
    pCMD.Parameters("@Izdato") = Izdato
    pCMD.Parameters("@DatIVremePripreme") = SQLFormatDatumIVreme(DatIVremePripreme, False)
  
  pCMD.Execute
  
Exit_Point:
  On Error Resume Next
  'spSaveMPStav = (pCMD.Parameters(0).Value = 0) And (Not IsEmpty(pCMD.Parameters(0).Value))
  spSaveMPStav = (pCMD.ActiveConnection.Errors.Count = 0)
  pCMD.ActiveConnection.Close
  Set pCMD = Nothing
  
Exit Function
Err_Point:
  BBErrorMSG err, "spSaveMPStav"
  Resume Exit_Point:
End Function
Public Function SQLText_MPDokZaSynch(Optional SveKolone As Boolean = False) As String
Dim stSQL As String
 
 If SveKolone Then
    stSQL = ""
    stSQL = stSQL & " SELECT rd.*"
    stSQL = stSQL & " FROM T_MPDokumenta AS rd INNER JOIN"
    stSQL = stSQL & " ( SELECT T_MPDokumenta.IDDok, T_MPDokumenta.IDProdavnica, T_MPDokumenta.IDKasa"
    stSQL = stSQL & "   FROM T_MPDokumenta INNER JOIN T_MPStavke ON (T_MPDokumenta.IDKasa = T_MPStavke.IDKasa) AND (T_MPDokumenta.IDProdavnica = T_MPStavke.IDProdavnice) AND (T_MPDokumenta.IDDok = T_MPStavke.IDDok)"
    stSQL = stSQL & "   WHERE (((T_MPStavke.DIVSynch) Is Null))"
    stSQL = stSQL & "   GROUP BY T_MPDokumenta.IDDok, T_MPDokumenta.IDProdavnica, T_MPDokumenta.IDKasa"
    stSQL = stSQL & "  )  AS KojaDokumenta ON (rd.IDDok = KojaDokumenta.IDDok) AND (rd.IDProdavnica = KojaDokumenta.IDProdavnica) AND (rd.IDKasa = KojaDokumenta.IDKasa)"

 Else
    stSQL = ""
    stSQL = stSQL & " SELECT T_MPDokumenta.IDDok, T_MPDokumenta.IDProdavnica, T_MPDokumenta.IDKasa"
    stSQL = stSQL & " FROM T_MPDokumenta INNER JOIN T_MPStavke ON (T_MPDokumenta.IDKasa = T_MPStavke.IDKasa) AND (T_MPDokumenta.IDProdavnica = T_MPStavke.IDProdavnice) AND (T_MPDokumenta.IDDok = T_MPStavke.IDDok)"
    stSQL = stSQL & " WHERE (((T_MPStavke.DIVSynch) Is Null))"
    stSQL = stSQL & " GROUP BY T_MPDokumenta.IDDok, T_MPDokumenta.IDProdavnica, T_MPDokumenta.IDKasa"
 End If
    
 SQLText_MPDokZaSynch = stSQL
End Function
Public Function SQLText_MPStavZaSynch() As String
Dim stSQL As String
 
    stSQL = ""
    stSQL = stSQL & " SELECT T_MPStavke.*"
    stSQL = stSQL & " FROM T_MPDokumenta INNER JOIN T_MPStavke ON (T_MPDokumenta.IDKasa = T_MPStavke.IDKasa) AND (T_MPDokumenta.IDProdavnica = T_MPStavke.IDProdavnice) AND (T_MPDokumenta.IDDok = T_MPStavke.IDDok)"
    stSQL = stSQL & " WHERE (((T_MPStavke.DIVSynch) Is Null))"

 SQLText_MPStavZaSynch = stSQL
End Function

Public Function BrojMPDokZaSynch() As Long
On Error GoTo Err_Point

Dim stSQL As String
Dim retVal As Long

retVal = ADO_Lookup(CNN_CurrentDataBase, "BrojSlogova", "SELECT COUNT(*) as BrojSlogova FROM (" & SQLText_MPDokZaSynch() & ") as dom")

Exit_Point:
 On Error Resume Next
       BrojMPDokZaSynch = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "BrojMPDokZaSynch"
 Resume Exit_Point
End Function
Public Function BrojMPStavZaSynch() As Long
On Error GoTo Err_Point

Dim stSQL As String
Dim retVal As Long

retVal = ADO_Lookup(CNN_CurrentDataBase, "BrojSlogova", "SELECT COUNT(*) as BrojSlogova FROM (" & SQLText_MPStavZaSynch() & ") as dom")

Exit_Point:
 On Error Resume Next
       BrojMPStavZaSynch = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "BrojMPStavZaSynch"
 Resume Exit_Point
End Function
Public Function VrednostMPStavZaSynch() As Double
On Error GoTo Err_Point

Dim stSQL As String
Dim retVal As Double

stSQL = "SELECT SUM(Kolicina*StvarnaMPCena) as MPVrednost FROM (" & SQLText_MPStavZaSynch() & ") as dom"

retVal = Nz(ADO_Lookup(CNN_CurrentDataBase, "MPVrednost", stSQL), 0)

Exit_Point:
 On Error Resume Next
       VrednostMPStavZaSynch = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "VrednostMPStavZaSynch"
 Resume Exit_Point
End Function
Public Function SynchMPStavkeZaDok(IDDok As Long, IDProdavnica As Long, IDKasa As Long) As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim OK As Boolean
Dim rstMPStav As ADODB.Recordset
Dim stSQL As String

retValOk = True
stSQL = ""
stSQL = stSQL & " SELECT T_MPStavke.*"
stSQL = stSQL & " FROM T_MPStavke "
stSQL = stSQL & " WHERE (((T_MPStavke.IDDok)= " & IDDok & ") AND ((T_MPStavke.IDProdavnice)= " & IDProdavnica & ") AND ((T_MPStavke.IDKasa)=" & IDKasa & "));"

Set rstMPStav = ADO_GetRST(CNN_CurrentDataBase, stSQL, dbOptimistic, adUseClient, adOpenKeyset, True)

While Not rstMPStav.EOF
    OK = spSaveMPStav(rstMPStav!IDStavke _
                    , rstMPStav!IDDok _
                    , rstMPStav!IDProdavnice _
                    , rstMPStav!IDKasa _
                    , rstMPStav![Sifra artikla] _
                    , rstMPStav!Kolicina _
                    , rstMPStav!KalkulativnaMPCena _
                    , rstMPStav!StvarnaMPCena _
                    , rstMPStav!TAKSA _
                    , rstMPStav!TarifaRoba _
                    , rstMPStav!IDStavMagOtpreme _
                    , rstMPStav!Porudzbina _
                    , rstMPStav!DatIVremePor _
                    , rstMPStav!Pripremljeno _
                    , rstMPStav!Izdato _
                    , rstMPStav!DatIVremePripreme)
                    
    If OK Then
       rstMPStav!DIVSynch = Now()
       rstMPStav.Update
    End If
     
    retValOk = retValOk And OK
    rstMPStav.MoveNext
Wend

Exit_Point:
 On Error Resume Next
       SynchMPStavkeZaDok = retValOk
  rstMPStav.Close
  Set rstMPStav = Nothing
Exit Function

Err_Point:
 BBErrorMSG err, "SynchMPStavkeZaDok"
 retValOk = False
 Resume Exit_Point
End Function
Public Function SynchMPDokIStavke(IDDok As Long, IDProdavnica As Long, IDKasa As Long) As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim OK As Boolean
Dim rstMPDok As ADODB.Recordset
Dim stSQL As String

retValOk = True
stSQL = ""
stSQL = stSQL & " SELECT T_MPDokumenta.*"
stSQL = stSQL & " FROM T_MPDokumenta "
stSQL = stSQL & " WHERE (((T_MPDokumenta.IDDok)= " & IDDok & ") AND ((T_MPDokumenta.IDProdavnica)= " & IDProdavnica & ") AND ((T_MPDokumenta.IDKasa)=" & IDKasa & "));"

Set rstMPDok = ADO_GetRST(CNN_CurrentDataBase, stSQL, dbOptimistic, adUseClient, adOpenKeyset, True)

While Not rstMPDok.EOF
    OK = spSaveMPDok(rstMPDok!IDFirma, rstMPDok!Godina, rstMPDok!OJ, rstMPDok!OD _
                    , rstMPDok!IDDok, rstMPDok!IDProdavnica, rstMPDok!IDKasa _
                    , rstMPDok!IDKupac, rstMPDok!IDRadniNalog, rstMPDok!IDPredmet _
                    , rstMPDok![Broj dokumenta], rstMPDok![Vrsta dokumenta] _
                    , rstMPDok![Datum dokumenta], rstMPDok![Datum valute] _
                    , rstMPDok!Opis, rstMPDok![Sifra prodavca], rstMPDok!Kurs _
                    , rstMPDok!PrimljenNovac _
                    , rstMPDok!PrimljeniCekovi _
                    , rstMPDok!PrimljenaKartica _
                    , rstMPDok!DatIVreme _
                    , rstMPDok!Depozit _
                    , rstMPDok!RabatProc _
                    , rstMPDok!Smena _
                    , rstMPDok!Level _
                    , rstMPDok!Zakljucano _
                    , rstMPDok!StampanFiskalno _
                    , rstMPDok!FiktRabat _
                    , rstMPDok!BrojStola _
                    , rstMPDok!Naplaceno _
                    , rstMPDok!BrojStampanja _
                    , rstMPDok!LimitIznos _
                    , rstMPDok!PrimljeniVirmani _
                            )
                    
     If OK Then
        OK = SynchMPStavkeZaDok(IDDok, IDProdavnica, IDKasa)
        If OK Then
            rstMPDok!DIVSynch = Now()
            rstMPDok.Update
        End If
     End If
 
    retValOk = retValOk And OK
    rstMPDok.MoveNext
Wend

Exit_Point:
 On Error Resume Next
       SynchMPDokIStavke = retValOk
  rstMPDok.Close
  Set rstMPDok = Nothing
Exit Function

Err_Point:
 BBErrorMSG err, "SynchMPDokIStavke"
 retValOk = False
 Resume Exit_Point
End Function

Public Function ADO_ObrisiSynchMPStavke(CNNString As String, OdDatuma As Date, DoDatuma As Date) As Boolean
'Kreirano: 16-03-2021
'Opis: Brise sinhronizovane T_MPStavke za zadati period
'      OdDatuma i DoDatuma moraju da budu zadati, tj. ne moze da se prosledi null
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim stSQL As String

stSQL = ""
'stSQL = stSQL & " DELETE FROM T_MPStavke"
stSQL = stSQL & " DELETE T_MPStavke.*, Format([T_MPDokumenta].[Datum dokumenta],'yyyy-mm-dd') AS Expr2, T_MPStavke.DIVSynch"
stSQL = stSQL & " FROM T_MPDokumenta INNER JOIN T_MPStavke ON (T_MPDokumenta.IDKasa = T_MPStavke.IDKasa) AND (T_MPDokumenta.IDProdavnica = T_MPStavke.IDProdavnice) AND (T_MPDokumenta.IDDok = T_MPStavke.IDDok)"

'stSQL = stSQL & " WHERE       ( ( @OdDatuma Is Null) or ( @OdDatuma <= Format(T_MPDokumenta.[Datum dokumenta],'yyyy-MM-dd') ) )"
'stSQL = stSQL & "         AND ( ( @DoDatuma Is Null) or ( Format(T_MPDokumenta.[Datum dokumenta].'yyyy-MM-dd') <= @DoDatuma ) )"
'stSQL = stSQL & "         AND ( T_MPStavke.DIVSynch Is not Null )"
stSQL = stSQL & " WHERE (((Format([T_MPDokumenta].[Datum dokumenta],'yyyy-mm-dd')) Between @OdDatuma And @DoDatuma)"
stSQL = stSQL & "          AND ((T_MPStavke.DIVSynch) Is Not Null));"


stSQL = Replace(stSQL, "@OdDatuma", SQLFormatDatuma(OdDatuma, True))
stSQL = Replace(stSQL, "@DoDatuma", SQLFormatDatuma(DoDatuma, True))

retValOk = ADO_ExecSQL(CNNString, stSQL, True)

Exit_Point:
 On Error Resume Next
       ADO_ObrisiSynchMPStavke = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ADO_ObrisiSynchMPStavke"
 retValOk = False
 Resume Exit_Point
End Function
Public Function ADO_ObrisiSynchMPDokBezStavki(CNNString As String, OdDatuma As Date, DoDatuma As Date) As Boolean
'Kreirano: 16-03-2021
'Opis: Brise sinhronizovana T_MPDokumenta za zadati period
'      i to SAMO DOKUMENTA KOJA NEMAJU STAVKE
'      (ideja je da se prvo koristi funkcija ADO_ObrisiSynchMPStavke(CNNString As String, OdDatuma As Date, DoDatuma As Date) As Boolean
'      OdDatuma i DoDatuma moraju da budu zadati, tj. ne moze da se prosledi null
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim stSQL As String

stSQL = ""
stSQL = stSQL & " DELETE T_MPDokumenta.*"
stSQL = stSQL & " FROM            T_MPDokumenta LEFT OUTER JOIN T_MPStavke ON T_MPDokumenta.IDKasa = T_MPStavke.IDKasa AND T_MPDokumenta.IDProdavnica = T_MPStavke.IDProdavnice AND T_MPDokumenta.IDDok = T_MPStavke.IDDok"
stSQL = stSQL & " WHERE (T_MPStavke.IDStavke Is Null)"
stSQL = stSQL & "         AND ((Format([T_MPDokumenta].[Datum dokumenta],'yyyy-mm-dd')) Between @OdDatuma And @DoDatuma)"
stSQL = stSQL & "         AND ( T_MPDokumenta.DIVSynch Is not Null )"

stSQL = Replace(stSQL, "@OdDatuma", SQLFormatDatuma(OdDatuma, True))
stSQL = Replace(stSQL, "@DoDatuma", SQLFormatDatuma(DoDatuma, True))

retValOk = ADO_ExecSQL(CNNString, stSQL, True)

Exit_Point:
 On Error Resume Next
       ADO_ObrisiSynchMPDokBezStavki = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ADO_ObrisiSynchMPDokBezStavki"
 retValOk = False
 Resume Exit_Point
End Function
Public Function ADO_ObrisiSynchMPDokIStavke(CNNString As String, OdDatuma As Date, DoDatuma As Date, Optional ByRef BrojObrisanihStavki As Long, Optional ByRef BrojObrisanihDok As Long) As Boolean
'Kreirano: 16-03-2021
'Opis: Brise sinhronizovana T_MPDokumenta i T_MPStavke za zadati period
'      OdDatuma i DoDatuma moraju da budu zadati, tj. ne moze da se prosledi null
On Error GoTo Err_Point

Dim retValOk As Boolean

retValOk = True
retValOk = ADO_ObrisiSynchMPStavke(CNNString, OdDatuma, DoDatuma)
BrojObrisanihStavki = ADO_ROWCOUNT

retValOk = retValOk And ADO_ObrisiSynchMPDokBezStavki(CNNString, OdDatuma, DoDatuma)
BrojObrisanihDok = ADO_ROWCOUNT


Exit_Point:
 On Error Resume Next
       ADO_ObrisiSynchMPDokIStavke = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ADO_ObrisiSynchMPDokIStavke"
 retValOk = False
 Resume Exit_Point
End Function
