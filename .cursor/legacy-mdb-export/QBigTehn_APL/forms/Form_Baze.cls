VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Baze"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub PrimeniUslove()
  
 Me!FirmazaBaze.DefaultValue = "'" & Me!ComboFirmaZaBaze & "'"
 Me.Requery
 
 'Me!ComboCNNStringName = "CNN_CurrentDataBase"
 Me!ComboCNNStringName = "CNN_CFG_Sys"
 Me!CNNString = BBReadProperty(Me!ComboCNNStringName)
    
 If Not UskladjeniSviCNN_LIBIAPL(, True) Then
    If BBPitanje("Da li želite da uskladim CNN za LIB-a sa aplikacijom?") Then
        PostaviSveCNNIzFIT
    End If
 End If

End Sub
Private Sub Baza_DblClick(Cancel As Integer)
    OvdeIzaberiBazu
End Sub

Private Sub Baza_GotFocus()
  Me!Baza.Requery
End Sub

Private Sub CNNString_AfterUpdate()
    LIB_CFGRW.CNNReset
End Sub

Private Sub ComboCNNStringName_AfterUpdate()
    Me!CNNString = BBReadProperty(Me!ComboCNNStringName)
End Sub
Private Sub UpisiSysFITFirmaU_CFG_Sys()
'Kreirano: 19-04-2021
 Dim retValOk As Boolean
 Dim stPitanje As String
 
    stPitanje = "Da li želite da upišem SysFITFirma=" & Me!ComboFirmaZaBaze & vbCrLf
    stPitanje = stPitanje & "u tabelu CFG_Sys?"
    stPitanje = stPitanje & vbCrLf & vbCrLf
    stPitanje = stPitanje & "CNN_CFG_Sys=" & CNN_CFG_Sys
    
    If BBPitanje(stPitanje) Then
        retValOk = WriteParametar("CFG_Sys", "SysFITFirma", Me!ComboFirmaZaBaze)
    Else
        retValOk = False
    End If
    If retValOk Then
     MsgBox "Parametar SysFITFirma=" & Me!ComboFirmaZaBaze & " je upisan u CFG_Sys", vbInformation, "QMegaTeh"
    Else
     MsgBox "Parametar SysFITFirma=" & Me!ComboFirmaZaBaze & " NIJE upisan u CFG_Sys", vbCritical, "QMegaTeh"
    End If
    
End Sub
Private Sub ComboFirmaZaBaze_AfterUpdate()
'Modifikovano: 08-04-2021
'Modifikovano: 19-04-2021
 Dim retValOk As Boolean

 
    Me!FirmazaBaze.DefaultValue = "'" & Me!ComboFirmaZaBaze & "'"
    '[Bliski susret].FirmazaBaze = Me!ComboFirmaZaBaze
    'BBCFG.Firma.Naziv = Me!ComboFirmaZaBaze
    Me.Requery
    Me!ComboFirmaZaBaze.Requery
    
    'Modifikovano: 19-04-2021 UpisiSysFITFirmaU_CFG_Sys
    
    retValOk = BBCreateProperty("FITFirma", , Me!ComboFirmaZaBaze)
    If retValOk Then
     MsgBox "Property FITFirma=" & Me!ComboFirmaZaBaze & " je kreiran/upisan u APL", vbInformation, "QMegaTeh"
    Else
     MsgBox "Property FITFirma=" & Me!ComboFirmaZaBaze & " NIJE kreiran/upisan u APL!", vbCritical, "QMegaTeh"
    End If
    
End Sub

Private Sub ComboFirmaZaBaze_DblClick(Cancel As Integer)
 On Error GoTo Err_DugmeBaze_Firme_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    Dim stFind As String
    
    stFind = Nz(Me![FirmazaBaze], "")
    stDocName = "Baze_Firme"
    
    'stLinkCriteria = "[FirmaZaBaze]=" & "'" & Me![FirmazaBaze] & "'"
    DoCmd.OpenForm stDocName, , , stLinkCriteria
    DoCmd.GoToControl "FirmaZaBaze"
    DoCmd.FindRecord stFind
Exit_DugmeBaze_Firme_Click:
    Exit Sub

Err_DugmeBaze_Firme_Click:
    MsgBox err.Description
    Resume Exit_DugmeBaze_Firme_Click
End Sub

Private Sub ComboFirmaZaBaze_GotFocus()
    Me!ComboFirmaZaBaze.Requery
End Sub

Private Sub ComboTipBaze_AfterUpdate()
    Me!IDBaze = Me!ComboTipBaze.Column(1)
End Sub

Private Sub ComboTipBaze_DblClick(Cancel As Integer)
    DoCmd.OpenTable "Baze_Tipovi"
End Sub

Private Sub DugmePostaviCNNIzFIT_Click()
Dim retValOk As Boolean
    retValOk = PostaviSveCNNIzFIT
    If retValOk Then
       MsgBox "Svi CNN stringovi su postavljeni.", vbInformation, "QBigTeh"
    Else
       MsgBox "Nisu svi CNN stringovi postavljeni.", vbExclamation, "QBigTeh"
    End If
End Sub

Private Sub DugmeCNN_Click()
    'LIB_OpenForm "CNN", , , , , , "CNN_CurrentDataBase"
    LIB_OpenForm "CNN_List"
End Sub

Private Sub DugmeForsirajSveLinkove_Click()
On Error GoTo Err_DugmeForsirajSveLinkove_Click

    Dim stDocName As String
    Dim retValOk As Boolean
    Dim YesToAll As Boolean
    
    If Not BBPitanje("Da li ste sigurni?") Then
       'MsgBox "Linkovi nisu promenjeni.", vbInformation, "QMegaTeh"
       Exit Sub
    End If
    
    DoCmd.SetWarnings False
    stDocName = "Baze_CheckLink_PonistiUTabelama"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    YesToAll = Not BBPitanje("Da li da pitam za svaku tabelu posebno?")
    retValOk = ForsirajSveLinkoveUSvimBazama(YesToAll)
    If retValOk Then
       MsgBox "Forsiranje svih definisanih linkova je uspešno završeno.", , "QMegaTeh"
    Else
       MsgBox "Forsiranje svih definisanih linkova NIJE uspešno završeno!", vbExclamation, "QMegaTeh"
    End If
    
    Me.Requery
    
Exit_DugmeForsirajSveLinkove_Click:
    DoCmd.SetWarnings True
    PostaviSveCNNIzFIT
Exit Sub

Err_DugmeForsirajSveLinkove_Click:
    MsgBox err.Description
    MsgBox "Forsiranje svih linkova nije uspelo.", vbCritical + vbOKOnly
    Resume Exit_DugmeForsirajSveLinkove_Click
    
End Sub

Private Sub DugmeObrisiNepotrebneLinkove_Click()
 Dim OK As Boolean
 If BBPitanje("Da li ste sigurni?") Then
    OK = ObrisiNepotrebneLinkovaneTabeleZaFirmu(Me!ComboFirmaZaBaze)
 End If
End Sub

Private Sub DugmePrikaziNepotrebneLinkove_Click()
Dim stRetVal As String

stRetVal = ListaNepotrebnihLinkovaZaFirmu(Me!ComboFirmaZaBaze)
MsgBox stRetVal, , "QMegaTeh"

End Sub

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub
Private Sub OvdeIzaberiBazu()
On Error GoTo Err_OvdeIzaberiBazu

    Dim ImeBaze As Variant
    
    'ImeBaze = IzaberiBazu()
    ImeBaze = OpenFileDialog(, Me!Baza)
    If Not IsNull(ImeBaze) Then Me!Baza = ImeBaze
    

Exit_OvdeIzaberiBazu:
    Exit Sub

Err_OvdeIzaberiBazu:
    MsgBox err.Description
    Resume Exit_OvdeIzaberiBazu
    
End Sub
Private Sub DugmeUpisiSQLCnnUSveBaze_Click()
On Error GoTo Err_Point

    If BBPitanje("Da li ste sigurni?") Then
    DoCmd.SetWarnings False
       DoCmd.OpenQuery "BazeITabele_UpisiNovuSQLBazu"
    DoCmd.SetWarnings True
       'PronadjiSlogNaFormi Me, "IDBaze = 60"
       'Me!Baza = "ODBC;" & SetParToCNNString("DATABASE", "ES_Synch_DB", Me!CNNString)
       'DoCmd.RunCommand acCmdSaveRecord
       Me.Requery
    End If
    
Exit_Point:
 On Error Resume Next
 DoCmd.SetWarnings True
Exit Sub

Err_Point:
 BBErrorMSG err, "DugmeUpisiSQLCnnUSveBaze_Click"
 Resume Exit_Point
End Sub

Private Sub DugmeUradiCompact_Click()
 On Error GoTo Err_Compact

    Dim stDocName As String

    stDocName = Me!Baza
    If BBCompactDatabase(stDocName) Then
     BBMsgBox_BigBit "Compact na bazi" & vbCrLf & vbCrLf & stDocName & vbCrLf & vbCrLf & " je uspešno uraðen", , , ColorConstants.vbGreen
    Else
     BBMsgBox_BigBit "Compact na bazi" & vbCrLf & vbCrLf & stDocName & vbCrLf & vbCrLf & " NIJE USPEŠNO URAÐEN", , , ColorConstants.vbRed
    End If

Exit_Compact:
    Exit Sub

Err_Compact:
    MsgBox err.Description
    Resume Exit_Compact
End Sub

Private Sub DugmeWritePropertyToAPL_Click()
On Error GoTo Err_Point
    If BBCreateProperty(Me!ComboCNNStringName, , Me!CNNString) Then
       MsgBox "Uspešno kreiran/izmenjen", vbInformation, "QBigTeh"
    Else
       MsgBox "Neuspešno kreiran/izmenjen", vbExclamation, "QBigTeh"
    End If
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "DugmeWritePropertyToAPL_Click"
 Resume Exit_Point
End Sub

Private Sub Form_Error(DataErr As Integer, Response As Integer)
Dim NovaBaza As String

 If DataErr = 3044 Or DataErr = 3024 Then
  'MsgBox "DataErr =" & DataErr
  'Ovo ne radi dobro!
  'ForsirajNoviLinkZaTabelu "BazeIFirme", "BazeIFirme", ";DATABASE=C:\SHARES\TGroup\AcBaze\BigBitTG\BB_FIT.mdb"
  NovaBaza = ";DATABASE=" & CurrentDBPath & F_SysBB_FIT() '"BB_FIT.mdb"
  Call ForsirajNoviLinkZaTabelu("BazeIFirme", "BazeIFirme", NovaBaza)
  Call ForsirajNoviLinkZaTabelu("BazeITabele", "BazeITabele", NovaBaza)
  Call ForsirajNoviLinkZaTabelu("Baze_CnnString", "Baze_CnnString", NovaBaza)
  Response = acDataErrContinue
  Me.Requery
 Else
    MsgBox "DataErr =" & DataErr
 End If
End Sub
Private Sub DugmePostavi_CFG_T_Tabele_Click()
    If Postavi_CFG_T_Tabele(True, False, False, False) Then
     MsgBox "Tabele/Upiti su uspešno postavljeni.", vbInformation, "QMegaTeh"
    Else
     MsgBox "Tabele/Upiti nisu uspešno postavljeni.", vbExclamation, "QMegaTeh"
    End If
End Sub
Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
'    If Not BBCFG Is Nothing Then
'       Me!UserPassword = BBCFG.UserPassword
'    End If

PrimeniUslove

    If CurrentUser = "Negovan" Then
     Exit Sub
    ElseIf Not UserUGrupi(CurrentUser(), "PowerfulUsers") Then
     Cancel = True
    End If
End Sub
Private Sub DugmeSveTabeleUBazi_Click()
On Error GoTo Err_DugmeSveTabeleUBazi_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "BazeITabele"
    
    'stLinkCriteria = "[IDBaze]=" & Me![IDBaze]
    'BBOpenForm stDocName, , , stLinkCriteria
    DoCmd.OpenForm stDocName, , , stLinkCriteria
    
    Forms![BazeITabele].RecordsetClone.FindFirst "[IDBaze]=" & Forms![baze]![IDBaze]
    Forms![BazeITabele].Bookmark = Forms![BazeITabele].RecordsetClone.Bookmark

Exit_DugmeSveTabeleUBazi_Click:
    Exit Sub

Err_DugmeSveTabeleUBazi_Click:
    MsgBox err.Description
    Resume Exit_DugmeSveTabeleUBazi_Click
    
End Sub
Private Sub DugmePronadjiIZameni_Click()
On Error GoTo Err_DugmePronadjiIZameni_Click

    Dim stDocName As String

    DoCmd.SetWarnings False
    stDocName = "BAZE_PronadjiIZameni"
    DoCmd.OpenQuery stDocName, acNormal, acEdit

Exit_DugmePronadjiIZameni_Click:
    Me.Requery
    DoCmd.SetWarnings True
    Exit Sub

Err_DugmePronadjiIZameni_Click:
    MsgBox err.Description
    Resume Exit_DugmePronadjiIZameni_Click
    
End Sub

Private Sub IDBaze_AfterUpdate()
 On Error Resume Next
    Me!TipBaze = DLookup("[TipBaze]", "Baze_Tipovi", "[IDBaze]= " & Me!IDBaze)
End Sub

Private Sub TipBaze_DblClick(Cancel As Integer)
    DugmeSveTabeleUBazi_Click
End Sub
Private Sub DugmeNapraviBazeZaNovuFirmu_Click()
On Error GoTo Err_DugmeNapraviBazeZaNovuFirmu_Click

    Dim stDocName As String

    stDocName = "BAZE_NapraviBazeZaNovuFirmu"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    Me!ComboFirmaZaBaze.Requery
    PrimeniUslove

Exit_DugmeNapraviBazeZaNovuFirmu_Click:
    Exit Sub

Err_DugmeNapraviBazeZaNovuFirmu_Click:
    MsgBox err.Description
    Resume Exit_DugmeNapraviBazeZaNovuFirmu_Click
    
End Sub
Private Sub DugmeNeispravniLinkovi_Click()
On Error GoTo Err_DugmeNeispravniLinkovi_Click

    Dim stDocName As String

    stDocName = "Baze_NeispravniLinkoviZaFirmu"
    DoCmd.OpenQuery stDocName, acNormal, acEdit

Exit_DugmeNeispravniLinkovi_Click:
    Exit Sub

Err_DugmeNeispravniLinkovi_Click:
    MsgBox err.Description
    Resume Exit_DugmeNeispravniLinkovi_Click
    
End Sub
Private Sub DugmeCFG_Click()
On Error GoTo Err_DugmeCFG_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    'stDocName = "CFGReadWrite"
    'DoCmd.OpenForm stDocName, , , stLinkCriteria
    OtvoriFormuCFGReadWrite
    
Exit_DugmeCFG_Click:
    Exit Sub

Err_DugmeCFG_Click:
    MsgBox err.Description
    Resume Exit_DugmeCFG_Click
    
End Sub

Private Sub IDBaze_DblClick(Cancel As Integer)
 DoCmd.OpenTable "Baze_Tipovi"
End Sub

Private Sub NeispravnoT_DblClick(Cancel As Integer)
  On Error GoTo err_Sub

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "BazeITabele"

    DoCmd.OpenForm stDocName, , , stLinkCriteria
    
    Forms![BazeITabele].RecordsetClone.FindFirst "[IDBaze]=" & Forms![baze]![IDBaze]
    Forms![BazeITabele].Bookmark = Forms![BazeITabele].RecordsetClone.Bookmark
    Forms![BazeITabele]![BazeITabele-Podforma].Form![ZaDobarLink] = False
    Forms![BazeITabele]![BazeITabele-Podforma].Form.Requery
Exit_Sub:
    Exit Sub

err_Sub:
    MsgBox err.Description
    Resume Exit_Sub
End Sub

Private Sub UserPassword_AfterUpdate()
   BBCFG.UserPassword = Nz(Me!UserPassword, "")
End Sub

Private Sub ZaForsirajNoviLink_AfterUpdate()
   PrimeniUslove
End Sub
Private Sub DugmeOpenDB_Click()
On Error GoTo Err_DugmeOpenDB_Click

    Dim stDocName As String
    Dim pUserName
    Dim pPassword
    
    If Nz(Me!UserName, "") = "" Then
     pUserName = Null
    Else
     pUserName = Me!UserName
    End If
    
    If Nz(Me!Password, "") = "" Then
     pPassword = Null
    Else
     pPassword = Me!Password
    End If
    
    OpenAccessDB Me!Baza, , , pUserName, pPassword
    
    
Exit_DugmeOpenDB_Click:
    Exit Sub

Err_DugmeOpenDB_Click:
    MsgBox err.Description
    Resume Exit_DugmeOpenDB_Click
    
End Sub
Private Sub DugmeAktivniUseriNaBazi_Click()
On Error GoTo Err_DugmeAktivniUseriNaBazi_Click

    Dim stDocName As String

    'stDocName = "__BrojDokumanataPoVrstama"
    'DoCmd.OpenQuery stDocName, acNormal, acEdit
    'BBMsgBox AktivniUseriNaBazi_TXT(Me!Baza, False)
    'Call AktivniUseriNaBazi(Me!Baza)
    'DoCmd.OpenForm "Sys_AktivniUseriNaBazi"
    Call AktivniUseriNaBazi(Me!Baza, True)
    
Exit_DugmeAktivniUseriNaBazi_Click:
    Exit Sub

Err_DugmeAktivniUseriNaBazi_Click:
    MsgBox err.Description
    Resume Exit_DugmeAktivniUseriNaBazi_Click
    
End Sub
Private Sub DugmeRefreshAllLinks_Click()
On Error GoTo Err_DugmeRefreshAllLinks_Click

    RefreshujSveLinkoveUSvimBazama

Exit_DugmeRefreshAllLinks_Click:
    Exit Sub

Err_DugmeRefreshAllLinks_Click:
    MsgBox err.Description
    Resume Exit_DugmeRefreshAllLinks_Click
    
End Sub
Private Sub DugmeNapraviFiktivneLinkoveZaSHUTTLE_Click()
On Error GoTo Err_DugmeNapraviFiktivneLinkoveZaSHUTTLE_Click
Dim OK As Boolean

If BBPitanje("Da li ste sigurni?") Then
  OK = NapraviFiktivneLinkoveZaSHUTTLE
Else
  OK = False
End If

If OK Then
 MsgBox "Uspešno.", vbInformation, "QMegaTeh"
Else
 MsgBox "Neuspešno!", vbExclamation, "QMegaTeh"
End If
Exit_DugmeNapraviFiktivneLinkoveZaSHUTTL:
    Exit Sub

Err_DugmeNapraviFiktivneLinkoveZaSHUTTLE_Click:
    MsgBox err.Description
    Resume Exit_DugmeNapraviFiktivneLinkoveZaSHUTTL
    
End Sub
Private Sub DugmeBazeAPL_Click()
On Error GoTo Err_DugmeBazeAPL_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Baze_APL"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeBazeAPL_Click:
    Exit Sub

Err_DugmeBazeAPL_Click:
    MsgBox err.Description
    Resume Exit_DugmeBazeAPL_Click
    
End Sub
Private Function UpisiNovuBazuZaTipBaze(TipBaze As String, stNovaBaza As String) As Boolean
On Error GoTo Err_Point

Dim db As DAO.Database
Dim rstbaze As DAO.Recordset
Dim retValOk As Boolean
Dim stMsg As String
    
    retValOk = True
    Set db = CurrentDb
    Set rstbaze = db.OpenRecordset(F_Baze_SQL(), dbOpenDynaset)
    rstbaze.FindFirst "[IDBaze] = " & IDBazeZaTipBaze(TipBaze)
     If rstbaze.NoMatch Then
        retValOk = False
        stMsg = "Tip baze " & TipBaze & " nije definisan za SysFITFirma= " & F_FirmaZaBaze()
        MsgBox stMsg, vbExclamation, "QMegaTeh"
    Else
        rstbaze.Edit
        rstbaze("Baza") = stNovaBaza
        rstbaze.Update
    End If
Exit_Point:
On Error Resume Next
    rstbaze.Close
    Set rstbaze = Nothing
    db.Close
    Set db = Nothing
    UpisiNovuBazuZaTipBaze = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "UpisiNovuBazuZaTipBaze"
 retValOk = False
 Resume Exit_Point
End Function
Private Sub DugmePostaviSTDLokalneTabele_Click()
On Error GoTo Err_Point

Dim stNovaBaza As String     '= adhCurrentDBPath() & "BB_CFG_Lokal.mdb"
                              '= adhCurrentDBPath() & "BB_TMP.mdb"
Dim retValOk As Boolean
Dim stMsg As String
Dim TipBaze As String

    
    
    
    TipBaze = "LOKAL_CFG"
    stNovaBaza = adhCurrentDBPath() & "BB_CFG_Lokal.mdb"
    retValOk = ForsirajNoveLinkoveZaIDBaze(IDBazeZaTipBaze(TipBaze), stNovaBaza)
    stMsg = DoChRight(TipBaze, 20) & "=> " & IIf(retValOk, "OK", "NOT OK") & vbCrLf
    UpisiNovuBazuZaTipBaze TipBaze, stNovaBaza
    
    TipBaze = "TMP"
    stNovaBaza = adhCurrentDBPath() & "BB_TMP.mdb"
    'retValOk = ForsirajNoveLinkoveZaTipBaze(TipBaze, pBB_CFG_Lokal_FileName)
    retValOk = ForsirajNoveLinkoveZaIDBaze(IDBazeZaTipBaze(TipBaze), stNovaBaza)
    stMsg = stMsg & DoChRight(TipBaze, 20) & "=> " & IIf(retValOk, "OK", "NOT OK") & vbCrLf
    UpisiNovuBazuZaTipBaze TipBaze, stNovaBaza
    
    PrimeniUslove
    MsgBox stMsg, vbInformation, "QMegaTeh"
    
Exit_Point:
    Exit Sub

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
    
End Sub
