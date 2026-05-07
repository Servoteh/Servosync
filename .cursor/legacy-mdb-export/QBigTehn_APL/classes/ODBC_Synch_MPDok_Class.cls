VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "ODBC_Synch_MPDok_Class"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private pIDDok As Long
Private pIDProdavnica As Long
Private pIDKasa As Long

Private pRstDok As DAO.Recordset
Private pRstStavke As DAO.Recordset

Private pLogText As String
Private pLogFileName As String

Private pErrNumber As Long
Private pErrDescription As String

Private pCNNString As String
Private pCNN As New ADODB.Connection
Private pCMD As New ADODB.Command
Private Sub SetMyError(err As ErrObject)
 pErrNumber = err.Number
 pErrDescription = err.Description
End Sub
Private Sub ClearMyError()
 pErrNumber = 0
 pErrDescription = ""
End Sub
Private Function RstDokSQLText() As String
Dim RetValST As String
 
 RetValST = "SELECT T_MPDokumenta.* FROM T_MPDokumenta "
 RetValST = RetValST & " WHERE (((T_MPDokumenta.IDDok)= " & pIDDok & ") AND ((T_MPDokumenta.IDProdavnica)= " & pIDProdavnica & ") AND ((T_MPDokumenta.IDKasa)=" & pIDKasa & "));"
 
 RstDokSQLText = RetValST
End Function
Private Function RstStavkeSQLText() As String
Dim RetValST As String
 
 RetValST = "SELECT T_MPStavke.* FROM T_MPStavke "
 RetValST = RetValST & " WHERE (((T_MPStavke.IDDok)= " & pIDDok & ") AND ((T_MPStavke.IDProdavnice)= " & pIDProdavnica & ") AND ((T_MPStavke.IDKasa)=" & pIDKasa & "));"
 
 RstStavkeSQLText = RetValST
End Function
Private Function spSaveMPDok() As Boolean
'Modifikovano: 21-09-2019 -> spSaveMPStav = (pCMD.Parameters(0).Value = 0) And (Not IsEmpty(pCMD.Parameters(0).Value))

On Error GoTo Err_Point

 pCMD.ActiveConnection.CursorLocation = adUseClient
 pCMD.CommandType = adCmdStoredProc
 pCMD.CommandText = "spSaveMPDok"
 pCMD.Parameters.Refresh
    pCMD.Parameters("@IDFirma") = pRstDok!IDFirma
    pCMD.Parameters("@Godina") = pRstDok!Godina
    pCMD.Parameters("@OJ") = pRstDok!OJ
    pCMD.Parameters("@OD") = pRstDok!OD
    pCMD.Parameters("@IDDok") = pRstDok!IDDok
    pCMD.Parameters("@IDProdavnica") = pRstDok!IDProdavnica
    pCMD.Parameters("@IDKasa") = pRstDok!IDKasa
    pCMD.Parameters("@IDKupac") = pRstDok!IDKupac
    pCMD.Parameters("@IDRadniNalog") = pRstDok!IDRadniNalog
    pCMD.Parameters("@IDPredmet") = pRstDok!IDPredmet
    pCMD.Parameters("@BrojDokumenta") = pRstDok![Broj dokumenta]
    pCMD.Parameters("@VrstaDokumenta") = pRstDok![Vrsta dokumenta]
    pCMD.Parameters("@DatumDokumenta") = pRstDok![Datum dokumenta]
    pCMD.Parameters("@DatumValute") = pRstDok![Datum valute]
    pCMD.Parameters("@Opis") = pRstDok!Opis
    pCMD.Parameters("@SifraProdavca") = pRstDok![Sifra prodavca]
    pCMD.Parameters("@Kurs") = pRstDok!Kurs
    pCMD.Parameters("@PrimljenNovac") = pRstDok!PrimljenNovac
    pCMD.Parameters("@PrimljeniCekovi") = pRstDok!PrimljeniCekovi
    pCMD.Parameters("@PrimljenaKartica") = pRstDok!PrimljenaKartica
    pCMD.Parameters("@DatIVreme") = pRstDok!DatIVreme
    pCMD.Parameters("@Depozit") = pRstDok!Depozit
    pCMD.Parameters("@RabatProc") = pRstDok!RabatProc
    pCMD.Parameters("@Smena") = pRstDok!Smena
    pCMD.Parameters("@Level") = pRstDok!Level
    pCMD.Parameters("@Zakljucano") = pRstDok!Zakljucano
    pCMD.Parameters("@StampanFiskalno") = pRstDok!StampanFiskalno
    pCMD.Parameters("@FiktRabat") = pRstDok!FiktRabat
    pCMD.Parameters("@BrojStola") = pRstDok!BrojStola
    pCMD.Parameters("@Naplaceno") = pRstDok!Naplaceno
    pCMD.Parameters("@BrojStampanja") = pRstDok!BrojStampanja
    pCMD.Parameters("@LimitIznos") = pRstDok!LimitIznos
    pCMD.Parameters("@PrimljeniVirmani") = pRstDok!PrimljeniVirmani
    
  pCMD.Execute
Exit_Point:
 On Error Resume Next
  spSaveMPDok = (pCMD.Parameters(0).Value = 0) And (Not IsEmpty(pCMD.Parameters(0).Value))
Exit Function
Err_Point:
  BBErrorMSG err, "spSaveMPDok"
  Resume Exit_Point:
End Function
Private Function spSaveMPStav() As Boolean
'Modifikovano: 21-09-2019 -> spSaveMPStav = (pCMD.Parameters(0).Value = 0) And (Not IsEmpty(pCMD.Parameters(0).Value))

On Error GoTo Err_Point

 pCMD.ActiveConnection.CursorLocation = adUseClient
 pCMD.CommandType = adCmdStoredProc
 pCMD.CommandText = "spSaveMPStav"
 pCMD.Parameters.Refresh
    pCMD.Parameters("@IDStavke") = pRstStavke!IDStavke
    pCMD.Parameters("@IDDok") = pRstStavke!IDDok
    pCMD.Parameters("@IDProdavnice") = pRstStavke!IDProdavnice
    pCMD.Parameters("@IDKasa") = pRstStavke!IDKasa
    pCMD.Parameters("@SifraArtikla") = pRstStavke![Sifra artikla]
    pCMD.Parameters("@Kolicina") = pRstStavke!Kolicina
    pCMD.Parameters("@KalkulativnaMPCena") = pRstStavke!KalkulativnaMPCena
    pCMD.Parameters("@StvarnaMPCena") = pRstStavke!StvarnaMPCena
    pCMD.Parameters("@Taksa") = pRstStavke!TAKSA
    pCMD.Parameters("@TarifaRoba") = pRstStavke!TarifaRoba
    pCMD.Parameters("@IDStavMagOtpreme") = pRstStavke!IDStavMagOtpreme
    pCMD.Parameters("@Porudzbina") = pRstStavke!Porudzbina
    pCMD.Parameters("@DatIVremePor") = pRstStavke!DatIVremePor
    pCMD.Parameters("@Pripremljeno") = pRstStavke!Pripremljeno
    pCMD.Parameters("@Izdato") = pRstStavke!Izdato
    pCMD.Parameters("@DatIVremePripreme") = pRstStavke!DatIVremePripreme
  
  pCMD.Execute
Exit_Point:
  On Error Resume Next
  spSaveMPStav = (pCMD.Parameters(0).Value = 0) And (Not IsEmpty(pCMD.Parameters(0).Value))
Exit Function
Err_Point:
  BBErrorMSG err, "spSaveMPStav"
  Resume Exit_Point:
End Function
Public Function SynchronizeMPDok(IDDok As Long, IDProdavnica As Long, IDKasa As Long, Optional stCNNString) As Boolean
On Error GoTo Err_Point
 Dim retValOk As Boolean
 Dim pOk As Boolean
 
 Dim BigBitDB As DAO.Database
 Dim pRstDokSQLText As String
 
 If Not IsMissing(stCNNString) Then
  pCNNString = stCNNString
 End If
 retValOk = True
 pIDDok = IDDok
 pIDProdavnica = IDProdavnica
 pIDKasa = IDKasa
 
 Set BigBitDB = CurrentDb
 Set pRstDok = BigBitDB.OpenRecordset(RstDokSQLText(), RecordsetTypeEnum.dbOpenDynaset, RecordsetOptionEnum.dbSeeChanges)  ', LockTypeEnum.dbOptimistic)
 Set pRstStavke = BigBitDB.OpenRecordset(RstStavkeSQLText(), RecordsetTypeEnum.dbOpenDynaset, RecordsetOptionEnum.dbSeeChanges)  ', LockTypeEnum.dbOptimistic)
 
 retValOk = OpenConnection '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
 
 If Not retValOk Then GoTo Exit_Point
 'else postoji konekcia ka master bazi i komanda je pripremljena
 
 If pRstDok.EOF And pRstDok.BOF Then GoTo Exit_Point
 'else postoji bar jedan slog za sinhronizaciju
 
 pRstDok.MoveFirst
 While Not pRstDok.EOF
  pOk = spSaveMPDok()
    If pOk Then
            pRstDok.Edit
             pRstDok!DIVSynch = Now()
            pRstDok.Update
           
            While Not pRstStavke.EOF
                    pOk = spSaveMPStav()
                    If pOk Then
                     pRstStavke.Edit
                      pRstStavke!DIVSynch = Now()
                     pRstStavke.Update
                    Else
                     err.Raise vbObjectError + 515, "SynchronizeMPDok", "Nemate konekciju sa MASTER bazom."
                    End If
                    pRstStavke.MoveNext
            Wend
    Else
     err.Raise vbObjectError + 515, "SynchronizeMPDok", "Nemate konekciju sa MASTER bazom."
    End If
  retValOk = retValOk And pOk
  pRstDok.MoveNext
 Wend
 
 
Exit_Point:
On Error Resume Next
 SynchronizeMPDok = retValOk
Exit Function

Err_Point:
 If err = vbObjectError + 515 Then
   BBCFG.SysSuspendSynch = BBPitanje("Da li suspendujete sinhronizaciju?")
 Else
  BBErrorMSG err, "SynchronizeMPDok"
 End If
 retValOk = False
 Resume Exit_Point
End Function
Private Property Get CNNString() As String
  CNNString = pCNNString
End Property
Private Property Let CNNString(ByVal vNewValue As String)
  pCNNString = vNewValue
End Property
Private Function OpenConnection() As Boolean
On Error GoTo Err_Point

 pErrNumber = 0
 pErrDescription = ""
 
 If pCNN.State = adStateOpen Then
    pCMD.ActiveConnection = pCNN
    OpenConnection = True
    Exit Function
 End If
  
DoCmd.Hourglass True

  pCNN.ConnectionString = pCNNString
  pCNN.CursorLocation = adUseClient
  'pCNN.ConnectionTimeout = 15
If Not BBCFG.SysSuspendSynch Then
  On Error Resume Next
  pCNN.Open pCNNString
End If
DoCmd.Hourglass False
  If pCNN.State = adStateOpen Then
     Set pCMD.ActiveConnection = pCNN
  Else
     BBCFG.SysSuspendSynch = True
     pErrNumber = vbObjectError + 515
     pErrDescription = "Disconected MasterDB"
 End If
 
Err_Point:
 DoCmd.Hourglass False
 SetMyError err
 err.Clear
 OpenConnection = (pCNN.State = adStateOpen)
End Function
Private Sub Class_Initialize()
On Error GoTo Err_Point

 Dim retValOk As Boolean
 
 ClearMyError
 pLogFileName = BBCFG.ODBC_Synch_LogFileName
 pCNNString = Replace(BazaZaTip("Synch"), "ODBC;", "")

Exit_Point:
 On Error Resume Next

Exit Sub
Err_Point:
  SetMyError err
  retValOk = False
  Resume Exit_Point:
End Sub

Private Sub Class_Terminate()
On Error Resume Next
If pCMD.ActiveConnection.State = adStateOpen Then
   pCMD.ActiveConnection.Close
End If
Set pCMD = Nothing

If pCNN.State = adStateOpen Then
   pCNN.Close
End If
Set pCNN = Nothing

pRstDok.Close
Set pRstDok = Nothing

pRstStavke.Close
Set pRstStavke = Nothing


End Sub
