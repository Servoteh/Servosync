VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_KreirajNoveNalogeZaIDPredmet"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit

Public Function PrimeniUslove()
'   BBTimerStart
'    SetProperlyRecordSource BBCFG.CNNString, Me
'   Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
 Me.Requery
End Function
Private Function F_ClearCurrentValIPrimeniUslove()
    F_ClearCurrentVal
    PrimeniUslove
End Function


Private Sub DugmeKreirajNaloge_Click()
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    
    retValOk = KreirajNalogeZaNoviPredmet
    If retValOk Then
        Me!ZaIDPredmet = Null
        ZaIDPRedmet_AfterUpdate
        Me!noviIDPredmet = Null
        PrimeniUslove
        'SetujCaptionZaDugme
    End If
    
Exit_Point:
    On Error Resume Next
    
Exit Sub

Err_Point:
    BBErrorMSG err, "DugmeKreirajNaloge"
    retValOk = False
    Resume Exit_Point
End Sub

Private Sub DugmePripremiPodatke_Click()
 Dim TimerStart As Single
 Dim TimerEnd As Single
 Dim stTrajanje As String
 If IsNull(Me!ZaIDPredmet) Then
        MsgBox "Morate da definišete za koji predmet kopirate naloge", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "ZaIDPredmet"
        Exit Sub
    End If
    
    If IsNull(Me!noviIDPredmet) Then
        MsgBox "Morate da definišete u koji novi predmet kopirate naloge", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "noviIDPredmet"
        Exit Sub
    End If
    
    If Me!noviIDPredmet = Me!ZaIDPredmet Then
        MsgBox "Isti su brojevi predmeta", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "noviIDPredmet"
        Exit Sub
    End If
    
    If Not IsDate(Me!DatumUnosa) Then
        MsgBox "Morate da definišete datum naloga", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "DatumUnosa"
        Exit Sub
    End If
    
    If Not IsDate(Me!RokIzrade) Then
        MsgBox "Morate da definišete rok za izradu", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "RokIzrade"
        Exit Sub
    End If
    
    If IsNull(Me!KoificijentZaKolicinu) Then
        MsgBox "Morate da definišete koeficijent sa kojim množite broj komada za izrada", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "KoificijentZaKolicinu"
        Exit Sub
    End If
    
    If IsNull(Me!SifraRadnika) Then
        MsgBox "Potrebno je definisati tehnologa koji potpisuje kreiranje novih naloga", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "SifraRadnika"
        Exit Sub
    End If

 If BBPitanje("Da li ste sigurni?") Then
    Me!LabelTrajanjeUpita.Caption = "Sacekajte..."
    TimerStart = Timer
     PripremiPodatke
    TimerEnd = Timer
    'stTrajanje = "Priprema je trajala " & Format(TimerEnd - TimerStart, "###0.00000") & " sec."
    'BBMsgBox "Podaci su pripremljeni." & vbCrLf & vbCrLf & stTrajanje, 1
    Me!LabelTrajanjeUpita.Caption = "Query=" & Format(TimerEnd - TimerStart, "###0.00000") & " sec."
 End If
End Sub

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox Error$
    Resume Exit_DugmeStop_Click
    
End Sub
Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
    If PostojiTabelaUBazi("tmp_NaloziZaKreiranjeNovogProjekta", CurrentDb) Then
        ObrisiSadrzajTabele "tmp_NaloziZaKreiranjeNovogProjekta"
    End If
    
    If Nz(ADO_Lookup(CNN_CurrentDataBase, "[IDVrsteRadnika]", "tRadnici", "[SifraRadnika] = " & IDRadnikZaCurrentUser()), 0) = 1 Then
        Me!SifraRadnika = IDRadnikZaCurrentUser()
        Me!SifraRadnika.Requery
    End If
    PrimeniUslove
    'SetujCaptionZaDugme
    If IsNull(Me!ZaIDPredmet) And IsNull(Me!noviIDPredmet) Then
        Me!DugmeKreirajNaloge.Caption = "Kreiraj sve naloge po izabranom predmetu broj [] u broj []"
    End If
End Sub
Private Sub Kreirati_AfterUpdate()
    If PostojiNalogSaIstimBrojem Then
       MsgBox "Nalog sa ovim brojem predmeta, brojem naloga i varijante veæ postoji u bazi" & vbCrLf & "Ne možete ga opet kreirati", vbInformation
        If Me.Dirty Then
            Me.Undo
        End If
       DoCmd.CancelEvent
    Else
        DoCmd.RunCommand acCmdSaveRecord
    End If
End Sub

Private Sub noviIDPredmet_AfterUpdate()
    If PostojiTabelaUBazi("tmp_NaloziZaKreiranjeNovogProjekta", CurrentDb) Then
        ObrisiSadrzajTabele "tmp_NaloziZaKreiranjeNovogProjekta"
        Me!DugmeKreirajNaloge.Caption = "[]"
    End If
   ' SetujCaptionZaDugme
End Sub

Private Sub ZaIDPRedmet_AfterUpdate()
    If PostojiTabelaUBazi("tmp_NaloziZaKreiranjeNovogProjekta", CurrentDb) Then
        ObrisiSadrzajTabele "tmp_NaloziZaKreiranjeNovogProjekta"
        Me!DugmeKreirajNaloge.Caption = "[]"
    End If
    PrimeniUslove
    'SetujCaptionZaDugme
End Sub
Public Function KreirajNalogeZaNoviPredmet_Promenjena() As Boolean
' 26-07-2024 sam prebacio source na TMP
On Error GoTo Err_Point
    
    Dim retValOk As Boolean
    Dim Uspesno As Integer
    Dim Neuspesno As Integer
    Dim stMsg As String
    Dim stSQL As String
    Dim rst As ADODB.Recordset
    Dim BrojRNZaIDPredmet As Integer
    Dim TimerPlus As Integer
    Dim StartTime As Single
    Dim endTime As Single
    Dim elapsedTime As Single
    
    retValOk = True
    
    stSQL = PassTroughQueryEvalAllPar("ODBC_ftPregledNalogaZaKreiranjeNovogProjekta")
    Set rst = ADO_GetRST(CNN_CurrentDataBase, stSQL)
    
    If IsNull(Me!ZaIDPredmet) Then
        MsgBox "Morate da definišete za koji predmet kopirate naloge", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "ZaIDPredmet"
        retValOk = False
        GoTo Exit_Point
    End If
   
    If IsNull(Me!noviIDPredmet) Then
        MsgBox "Morate da definišete u koji novi predmet kopirate naloge", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "noviIDPredmet"
        retValOk = False
        GoTo Exit_Point
    End If
    
    If Me!noviIDPredmet = Me!ZaIDPredmet Then
        MsgBox "Isti su brojevi predmeta", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "noviIDPredmet"
        retValOk = False
        GoTo Exit_Point
    End If
    
    If Not IsDate(Me!DatumUnosa) Then
        MsgBox "Morate da definišete datum naloga", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "DatumUnosa"
        retValOk = False
        GoTo Exit_Point
    End If
    
    If Not IsDate(Me!RokIzrade) Then
        MsgBox "Morate da definišete rok za izradu", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "RokIzrade"
        retValOk = False
        GoTo Exit_Point
    End If
    
    If IsNull(Me!KoificijentZaKolicinu) Then
        MsgBox "Morate da definišete koeficijent sa kojim množite broj komada za izrada", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "KoificijentZaKolicinu"
        retValOk = False
        GoTo Exit_Point
    End If
    
    If IsNull(Me!SifraRadnika) Then
        MsgBox "Potrebno je definisati tehnologa koji potpisuje kreiranje novih naloga", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "SifraRadnika"
        retValOk = False
        GoTo Exit_Point
    End If
    
    BrojRNZaIDPredmet = Nz(DCount("*", "tRN", "[IDPredmet] = " & Me!noviIDPredmet), 0)
    If BrojRNZaIDPredmet > 0 Then
        MsgBox "Za ovaj broj predmeta veæ imate definisane naloga", vbInformation, "Obavezno polje"
        DoCmd.GoToControl "noviIDPredmet"
        retValOk = False
        GoTo Exit_Point
    End If
    
    If rst.EOF And rst.BOF Then
     'ne postoje stavke u recordsetu
        retValOk = False
        GoTo Exit_Point
    Else
        rst.MoveFirst
    End If
  
    Uspesno = 0
    Neuspesno = 0
    stMsg = ""
    TimerPlus = 0
    
    StartTime = Timer
    
    While Not rst.EOF
    
        retValOk = KreirajNalogZaIDRN(rst!IDRN, Me!noviIDPredmet, Me!DatumUnosa, Me!SifraRadnika, Me!RokIzrade, Me!KoificijentZaKolicinu, TimerPlus)
        
        TimerPlus = TimerPlus + 10
        
        If retValOk Then
            Uspesno = Uspesno + 1
        Else
            Neuspesno = Neuspesno + 1
        End If
        
        rst.MoveNext
    Wend
    
    ' Inicijalizacija završnog vremena
    endTime = Timer
    
    ' Izraèunavanje proteklog vremena
    elapsedTime = endTime - StartTime
    
Exit_Point:
 On Error Resume Next
    rst.Close
    Set rst = Nothing
           
    If Uspesno > 0 Then
       stMsg = "Uspešno kreirano: " & Uspesno & " dokumenata" & vbCrLf
    End If
    
    If Neuspesno > 0 Then
       stMsg = stMsg & "Nespešno kreirano: " & Neuspesno & " dokumenata"
    End If
    
    If stMsg <> "" Then
     MsgBox stMsg & " za " & Round(elapsedTime, 2) & " sekundi", IIf(Neuspesno > 0, vbExclamation, vbInformation), "Kreiranje naloga"
    End If
    KreirajNalogeZaNoviPredmet_Promenjena = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "KreirajNalogeZaNoviPredmet_Promenjena"
 retValOk = False
 Resume Exit_Point

End Function

Public Function KreirajNalogZaIDRN(ByVal ZaIDRN As Long, ByVal noviIDPredmet As Long, ByVal DatumNaloga As Date, ByVal SifraRadnika As Long, _
                                    ByVal RokIzrade As Date, ByVal KoeficijentZaKolicinu As Double, ByVal TimerPlus As Integer) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    '@StariIDRN int  = Null
    ',@ZaNoviIDPredmet int = null
    ',@SifraRadnika int=0
    ',@DatumUnosa date = getDate
    ',@KoificijentZaKolicinu real=1.0
    ',@RokIzrade date = getDate
    ',@Potpis nvarchar(20)=null
    ',@PrnTimer int=0
   ' Debug.Print ZaIDRN, noviIDPredmet, IDRadnikZaCurrentUser(), SQLFormatDatuma(DatumNaloga, False), KoeficijentZaKolicinu, SQLFormatDatuma(RokIzrade, False), CurrentUser(), CLng(Timer)
     retValOk = ADO_ExecSP(BBCFG.CNNString, "spKreirajSveStavkeRNZaNoviIDPredmetiZaNoviIDKomitent", _
                                                ZaIDRN, _
                                                noviIDPredmet, _
                                                SifraRadnika, _
                                                SQLFormatDatuma(DatumNaloga, False), _
                                                KoeficijentZaKolicinu, _
                                                SQLFormatDatuma(RokIzrade, False), _
                                                CurrentUser(), _
                                                CLng(Timer + TimerPlus))
    
Exit_Point:
    On Error Resume Next
    KreirajNalogZaIDRN = retValOk
    Exit Function
    
Err_Point:
     BBErrorMSG err, "KreirajNalogZaIDRN"
     Resume Exit_Point
End Function

Private Sub SetujCaptionZaDugme()
    If IsNull(Me!ZaIDPredmet) Then
        Me!DugmeKreirajNaloge.Caption = "[]"
    Else
        Me!DugmeKreirajNaloge.Caption = "Kreiraj sve naloge po izabranom predmetu broj [" & Me!ZaIDPredmet.Column(1) & "] u broj [" & Me!noviIDPredmet.Column(1) & "]"
    End If
End Sub

Private Sub ZaIDPRedmet_GotFocus()
    Me!ZaIDPredmet.Requery
End Sub
Sub MeasureLoopDuration()
    Dim StartTime As Single
    Dim endTime As Single
    Dim elapsedTime As Single
    Dim i As Integer
    
    ' Inicijalizacija poèetnog vremena
    StartTime = Timer
    
    ' Primer petlje
    For i = 1 To 1000000
        ' Neka operacija
        Dim X As Double
        X = X + 1
    Next i
    
    ' Inicijalizacija završnog vremena
    endTime = Timer
    
    ' Izraèunavanje proteklog vremena
    elapsedTime = endTime - StartTime
    
    ' Prikaz rezultata
    MsgBox "Vreme trajanja petlje je: " & elapsedTime & " sekundi."
End Sub

Private Sub PripremiPodatke()
Dim SQLStrDob, SQLStr As String
On Error GoTo Err_PripremiPodatke

    Me.RecordSource = "" 'mora da se oslobodi za exclusive tmp tabela u kojoj cuvamo rezultate upita
    PripremiTmpTabeluUBazi
    Me.RecordSource = "Q_tmp_NaloziZaKreiranjeNovogProjekta"
    SetujCaptionZaDugme
    PrimeniUslove
        
Exit_PripremiPodatke:
    Exit Sub

Err_PripremiPodatke:
    MsgBox Error$
    Resume Exit_PripremiPodatke
    
End Sub
Private Function PripremiTmpTabeluUBazi() As Boolean
On Error GoTo err_Sub

     Dim stSQL As String
     
     Dim imeTabele As String
     Dim ImeBaze As String
     Dim QName As String
     Dim retValOk As Boolean
     retValOk = True
     
    imeTabele = "tmp_NaloziZaKreiranjeNovogProjekta"
    ImeBaze = BazaZaTip("TMP")
    
    If PostojiTabelaUBazi(imeTabele, CurrentDb) Then
        ObrisiSadrzajTabele "tmp_NaloziZaKreiranjeNovogProjekta"
    End If
    
    QName = "ODBC_spPregledNalogaZaKreiranjeNovogProjekta"
    stSQL = TextSelectQForSP("spPregledNalogaZaKreiranjeNovogProjekta", Me!ZaIDPredmet)
    retValOk = retValOk And BBCreateQuery(QName, stSQL)
    stSQL = "SELECT [" & QName & "].*,0 as Kreirati INTO " & imeTabele & "  IN '" & ImeBaze & "' FROM [" & QName & "];"
 
     
     DoCmd.SetWarnings False
     DoCmd.Hourglass True
     DoCmd.RunSQL stSQL
     
     Call CreateIndex("IDRN", imeTabele, ImeBaze, True, False)
 
     Call ForsirajNoviLinkZaTabelu(imeTabele, imeTabele, ";DATABASE=" & ImeBaze)
Exit_Sub:
    DoCmd.Hourglass False
    DoCmd.SetWarnings True
    PripremiTmpTabeluUBazi = retValOk
 Exit Function

err_Sub:
 BBErrorMSG err, "PripremiTmpTabeluUBazi"
 retValOk = False
 Resume Exit_Sub:
End Function

Public Function KreirajNalogeZaNoviPredmet() As Boolean
On Error GoTo Err_Point
    
    Dim retValOk As Boolean
    Dim Uspesno As Integer
    Dim Neuspesno As Integer
    Dim stMsg As String
    Dim stSQL As String
    Dim BrojRNZaIDPredmet As Integer
    Dim TimerPlus As Integer
    Dim StartTime As Single
    Dim endTime As Single
    Dim elapsedTime As Single
    
    Dim rst As DAO.Recordset
    Dim sql As String
    
    sql = "SELECT * FROM tmp_NaloziZaKreiranjeNovogProjekta WHERE Kreirati = True"
    
    retValOk = True
    
    If Nz(DCount("*", "tmp_NaloziZaKreiranjeNovogProjekta", "Kreirati = " & True), 0) = 0 Then
        MsgBox "Potrebno je " & Srpski("oznaciti") & " koje naloge kreirate", vbInformation, "Obavezno"
        retValOk = False
        GoTo Exit_Point
    End If
    
    Set rst = CurrentDb.OpenRecordset(sql, DB_OPEN_DYNASET, dbSeeChanges)
    
   ' BrojRNZaIDPredmet = Nz(DCount("*", "tRN", "[IDPredmet] = " & Me!noviIDPredmet), 0)
   ' If BrojRNZaIDPredmet > 0 Then
   '     MsgBox "Za ovaj broj predmeta veæ imate definisane naloga", vbInformation, "Obavezno polje"
   '     DoCmd.GoToControl "noviIDPredmet"
   '     retValOk = False
   '     GoTo Exit_Point
   ' End If
    
    If rst.EOF And rst.BOF Then
     'ne postoje stavke u recordsetu
        retValOk = False
        GoTo Exit_Point
    Else
        rst.MoveFirst
    End If
  
    Uspesno = 0
    Neuspesno = 0
    stMsg = ""
    TimerPlus = 0
    
    StartTime = Timer
    
    While Not rst.EOF
    
        retValOk = KreirajNalogZaIDRN(rst!IDRN, Me!noviIDPredmet, Me!DatumUnosa, Me!SifraRadnika, Me!RokIzrade, Me!KoificijentZaKolicinu, TimerPlus)
        
        TimerPlus = TimerPlus + 10
        
        If retValOk Then
            Uspesno = Uspesno + 1
        Else
            Neuspesno = Neuspesno + 1
        End If
        
        rst.MoveNext
    Wend
    
    ' Inicijalizacija završnog vremena
    endTime = Timer
    
    ' Izraèunavanje proteklog vremena
    elapsedTime = endTime - StartTime
    
Exit_Point:
 On Error Resume Next
    rst.Close
    Set rst = Nothing
           
    If Uspesno > 0 Then
       stMsg = "Uspešno kreirano: " & Uspesno & " dokumenata" & vbCrLf
    End If
    
    If Neuspesno > 0 Then
       stMsg = stMsg & "Nespešno kreirano: " & Neuspesno & " dokumenata"
    End If
    
    If stMsg <> "" Then
     MsgBox stMsg & " za " & Round(elapsedTime, 2) & " sekundi", IIf(Neuspesno > 0, vbExclamation, vbInformation), "Kreiranje naloga"
    End If
    KreirajNalogeZaNoviPredmet = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "KreirajNalogeZaNoviPredmet"
 retValOk = False
 Resume Exit_Point

End Function

Private Function ExecuteScalarFunction_IGRAO_SE() As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    
    Dim conn As Object
    Dim cmd As Object
    Dim rs As Object
    Dim strConn As String
    Dim strSQL As String
    Dim result As Variant
    Dim paramValue As String
    
    ' Podešavanje parametra funkcije
    paramValue = "VrednostParametra"
    
    ' Connection string za SQL Server
    strConn = "Provider=SQLOLEDB;Data Source=ServerName;Initial Catalog=DatabaseName;User ID=YourUsername;Password=YourPassword;"
    
    ' Kreiranje objekta za povezivanje
    Set conn = CreateObject("ADODB.Connection")
    conn.Open strConn
    
    ' Kreiranje objekta za komandu
    Set cmd = CreateObject("ADODB.Command")
    cmd.ActiveConnection = conn
    cmd.CommandType = adCmdText
    
    ' SQL upit za pokretanje scalar valued funkcije
    strSQL = "SELECT dbo.MyScalarFunction(" & Me!noviIDPredmet & ",N'" & Me!IdentBroj & "'," & Me!Varijanta & ") AS FunctionResult"
    cmd.CommandText = strSQL
    
    ' Izvršavanje komande i preuzimanje rezultata
    Set rs = cmd.Execute
    If Not rs.EOF Then
        retValOk = rs.Fields("FunctionResult").Value
        'MsgBox "Rezultat funkcije: " & result
    Else
        MsgBox "Funkcija nije vratila rezultat."
    End If
    
    
Exit_Point:
    On Error Resume Next
    ' Zatvaranje objekata
    rs.Close
    conn.Close
    Set rs = Nothing
    Set cmd = Nothing
    Set conn = Nothing
    
    ExecuteScalarFunction_IGRAO_SE = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "ExecuteScalarFunction"
    retValOk = False
    Resume Exit_Point
End Function

Public Function ADO_ExecFS(CNNString As String, fsName As String, ParamArray Arg()) As Boolean
'Kreirano: 22-10-2020
'Modifikovano: 31-01-2021 -> retValOk = (pCMD.ActiveConnection.Errors.Count = 0)
'Modifikovano: 04-04-2023 => provera da li ima greske i kada he pCMD.ActiveConnection.Errors.Count > 0
On Error GoTo Err_Point

Dim pCMD As New ADODB.Command

Dim i As Integer
Dim fsBrojParametara As Integer
Dim InBrojParametara As Integer
Dim stPoruka As String
Dim retValOk As Boolean
Dim strSQL As String

DoCmd.Hourglass True
pCMD.ActiveConnection = CNNString
pCMD.CommandType = adCmdText

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
 'cmd.Parameters(0) = @RETURN_VALUE
 fsBrojParametara = pCMD.Parameters.Count() - 1
 InBrojParametara = UBound(Arg()) - LBound(Arg()) + 1
 If InBrojParametara <> fsBrojParametara Then
  DoCmd.Hourglass False
  
  stPoruka = "Neuskladjeni parametri za " & fsName
  stPoruka = stPoruka & vbCrLf & "potrebno " & CStr(fsBrojParametara) & ", prosledjeno " & CStr(InBrojParametara)
  stPoruka = stPoruka & vbCrLf & vbCrLf & "Parametri koji nedostaju:" & vbCrLf
  For i = InBrojParametara + 1 To fsBrojParametara
       stPoruka = stPoruka & pCMD.Parameters(i).Name & vbCrLf
   Next i
  stPoruka = stPoruka & vbCrLf & "Da li želite da za njih prosledim 'DEFAULT'?"
  stPoruka = stPoruka & vbCrLf & "(ako odgovorite sa No proces se prekida)"
  If BBPitanje(stPoruka) Then
   For i = InBrojParametara + 1 To fsBrojParametara
       pCMD.Parameters(i).Value = Empty
   Next i
  Else
   retValOk = False
   GoTo Exit_Point
  End If
 End If

 For i = 1 To InBrojParametara
 ' problem sa datumom!
  pCMD.Parameters(i).Value = Arg(i - 1)
Next i

pCMD.CommandTimeout = 180 '10 '180 '3 minuta !!

'strSQL = "SELECT dbo." & fsName & "('" & paramValue & "') AS FunctionResult"
pCMD.CommandText = strSQL


    
pCMD.Execute

'provera da li je bilo gresaka zbog kojih komanda nije izvršena
    retValOk = True
    For i = 0 To pCMD.ActiveConnection.Errors.Count - 1
        retValOk = (retValOk And Left(CStr(pCMD.ActiveConnection.Errors.Item(i).SQLState), 1) = "0")
    Next i

Exit_Point:
On Error Resume Next

Set pCMD = Nothing
DoCmd.Hourglass False
ADO_ExecFS = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "ADO_ExecFS(" & fsName & "...)"
    retValOk = False
    Resume Exit_Point

End Function

Private Function PostojiNalogSaIstimBrojem() As Boolean
On Error GoTo Err_Point
    Dim pCMD As New ADODB.Command
    Dim rs As Object
    Dim retValOk As Boolean
    Dim strSQL As String

    retValOk = True
    
    pCMD.ActiveConnection = CNN_CurrentDataBase
    pCMD.CommandType = adCmdText
    pCMD.CommandTimeout = 30
    
    strSQL = "SELECT dbo.fsPostojiIdentBroj(" & Me!noviIDPredmet & ",N'" & Me!IdentBroj & "'," & Me!Varijanta & ") AS FunctionResult"
    pCMD.CommandText = strSQL
    
    Set rs = pCMD.Execute
    If Not rs.EOF Then
        retValOk = rs.Fields("FunctionResult").Value
        'MsgBox "Rezultat funkcije: " & result
    Else
        retValOk = False
        MsgBox "Funkcija nije vratila rezultat."
    End If
    
    
Exit_Point:
    On Error Resume Next
    ' Zatvaranje objekata
    rs.Close
    Set rs = Nothing
    PostojiNalogSaIstimBrojem = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "PostojiNalogSaIstimBrojem"
    retValOk = False
    Resume Exit_Point
End Function

