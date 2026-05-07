VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBInfo"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PostaviFokusNaKontrolu()
On Error GoTo Err_Point
   Forms(Me!ComboOtvoreneForme).Controls(Me!BBImeKontrole).SetFocus
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PostaviFokusNaKontrolu"
 Resume Exit_Point
End Function

Private Sub BBImeKontrole_AfterUpdate()
   PostaviFokusNaKontrolu
End Sub

Private Sub BBImeKontrole_DblClick(Cancel As Integer)
    BB_NapraviTabeluSvihKontrolaNaFormi Forms(Me!ComboOtvoreneForme)
End Sub

Private Sub CheckAllowBayPassKey_AfterUpdate()

   ' Vidi modul StartUp-proceduru: SetStartupProperties
   ' Pazljivo!
   If Not ChangeProperty("AllowBypassKey", dbBoolean, CheckAllowBayPassKey) Then
    MsgBox "Vrednost nije promenjena."
   Else
    'MsgBox "Vazi samo jedno startovanje!"
   End If
End Sub

Private Sub CheckBBTestPravaPristupa_AfterUpdate()
    'BBTestPravaPristupa = Me!CheckBBTestPravaPristupa
    BBCFG.TestPravaPristupa = Me!CheckBBTestPravaPristupa
End Sub

Private Sub ComboOtvoreneForme_AfterUpdate()
   Me!RecordSourceIzabraneForme = Forms(Me!ComboOtvoreneForme).RecordSource
   BB_NapraviTabeluSvihKontrolaNaFormi Forms(Me!ComboOtvoreneForme)
End Sub

Private Sub ComboCurrentDBProperties_AfterUpdate()
On Error GoTo Err_Point
    Me!ComboCurrentDBPropertiesVal = CurrentDb.Properties(Me!ComboCurrentDBProperties).Value
Exit_Point:
     On Error Resume Next
Exit Sub

Err_Point:
    BBErrorMSG err, "ComboCurrentDBProperties_AfterUpdate"
    Resume Exit_Point
End Sub

Private Sub ComboCenovnik_DblClick(Cancel As Integer)
    DoCmd.OpenForm "Cenovnik"
End Sub

Private Sub Command38_Click()
    DoCmd.OpenTable "BBDefUser"
End Sub

Private Sub CurrentDBProperties_AfterUpdate()
On Error GoTo Err_Point
    Me!CurrentDBPropertiesVal = CurrentDb.Properties(Me!CurrentDBProperties).Value

Exit_Point:
     On Error Resume Next
Exit Sub

Err_Point:
    BBErrorMSG err, "CurrentDBProperties_AfterUpdate"
    Resume Exit_Point
End Sub

Private Sub DefaultLimitedUser_AfterUpdate()
    BBCFG.DefaultLimitedUser = Me!DefaultLimitedUser
End Sub


Private Sub DugmeER_EXT_KnjigaStatusa_Click()
    DoCmd.OpenForm "ER_EXT_KnjigaStatusa"
    DoCmd.Close acForm, "BBInfo"
End Sub

Private Sub DugmeImportIzPG_Click()
On Error GoTo Err_DugmeImportIzPG_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    
    DoCmd.Close acForm, Me.Name
    stDocName = "PS_TabeleZaImportIzPG"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeImportIzPG_Click:
    Exit Sub

Err_DugmeImportIzPG_Click:
    MsgBox err.Description
    Resume Exit_DugmeImportIzPG_Click
    
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

Private Function GetValueListDBProperties() As String
    Dim strValList As String
    Dim i As Integer
    
    For i = 0 To CurrentDb.Properties.Count - 1
     strValList = strValList & CurrentDb.Properties(i).Name & ";"
    Next i
    strValList = Left$(strValList, Len(strValList) - 1)
    GetValueListDBProperties = strValList
End Function
Private Sub PopuniFormu()

    Me!MDW = Application.DBEngine.Properties("SystemDB")
    Me!AplName = CurrentDb.Name
    Me!CNNString = BBCFG.CnnStringBezPWD
    Me!BBAppRev = F_APPRev("QMegaTeh")
    Me!DBRev = F_APPRev("DB")
    Me!QBigBit_LIB_Rev = GetMyLibVer()
    
    Me![ComboCurrentDBProperties].RowSource = GetValueListDBProperties()
    
    If CurrentUser = "Negovan" Then
        Me![CheckAllowBayPassKey].Locked = False
    End If
    Me!CheckBBTestPravaPristupa = BBCFG.TestPravaPristupa 'BBTestPravaPristupa
    Me!DefaultLimitedUser = BBCFG.DefaultLimitedUser
    
    On Error Resume Next
    Me!ComboOtvoreneForme.RowSource = ListaOtvorenihFormi()
    Me!ComboOtvoreneForme = Screen.ActiveForm.Name
    BB_NapraviTabeluSvihKontrolaNaFormi Forms(Me!ComboOtvoreneForme)
    Me!RecordSourceIzabraneForme = Forms(Me!ComboOtvoreneForme).RecordSource
    Me!BBImeKontrole = Screen.ActiveControl.Name
    Me!ControlSourceIzabraneKontrole = Screen.ActiveControl.ControlSource
    Me!TagIzabraneKontrole = Screen.ActiveControl.tag
    
    Me!StartUpParVrednost = CurrentDb.Properties(Me!ComboStartUpPar).Value
    
    Me!TextZaPrikaz = [Bliski susret].BBStart_LogText
    
    
End Sub

Private Sub DugmeUpisiProsUlNCUCenovnik_Click()
On Error GoTo Err_Point
Dim retValOk As Boolean

If IsNull(Me!ComboCenovnik) Then
    MsgBox "Morate uneti u koji cenovnika upisujete cene.", vbExclamation, "QMegaTeh"
    GoTo Exit_Point
End If
If Not PostojiCenovnik(Nz(Me!ComboCenovnik, "")) Then
   MsgBox "Izabrani cenovnik nije definisan." & vbCrLf & vbCrLf & "(morate ga kreirati u opciji Cenovnik)", vbExclamation, "QMegaTeh"
   GoTo Exit_Point
End If

    If BBPitanje("Da li ste sigurni?") Then
        If BBCFG.SQLDB Then
          retValOk = spUpisiProsULNCUCenovnik(Me!ComboCenovnik, F_IDFirma(), Me!Godina, 0, 0, _
                                                           Me!CeneZaMagacin, Me!ProsULNC_OdDatuma, Me!ProsULNC_DoDatuma, Null, Null, Null, Null)
        Else
          retValOk = BBT_ProsUlNabCene_UpisiUCenovnik()
        End If
        
      If retValOk Then
        MsgBox "Cene su upisane.", vbInformation, "QMegaTeh"
      Else
        MsgBox "Cene nisu upisane!", vbExclamation, "QMegaTeh"
      End If
      'PrimeniUslove
    End If
    
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "DugmeUpisiProsUlNCUCenovnik_Click"
 Resume Exit_Point
End Sub

Private Sub UpisiUIzlazeCeneIzCenovnika()
On Error GoTo Err_Point:
Dim retValOk As Boolean
    
  retValOk = True
  
  If IsNull(Me!ComboCenovnik) Then
    MsgBox "Morate izabrati cenovnik iz kojeg upisujete cene.", vbExclamation, "QMegaTeh"
    retValOk = False
    GoTo Exit_Point
  End If

If BBCFG.SQLDB Then
  retValOk = spNabCeneIzCenovnika_UpisiUProdaju(Me!ComboCenovnik, F_IDFirma(), Me!Godina, Me!Prodaja_OdLevel, Me!Prodaja_DoLevel, _
                                                Me!MagacinProdaje, Me!Prodaja_OdDatuma, Me!Prodaja_DoDatuma, Me!VrstaDokumentaProdaje)
Else
  DoCmd.SetWarnings False
   DoCmd.OpenQuery "BBT_NabCeneIzCenovnika_UpisiUProdaju", acViewNormal, acEdit
  DoCmd.SetWarnings True
End If

Exit_Point:
   On Error Resume Next
   DoCmd.SetWarnings True
   If retValOk Then
    MsgBox "Cene su upisane u prodaju", vbInformation, "QMegaTeh"
   Else
    MsgBox "Cene nisu upisane u prodaju!", vbExclamation, "QMegaTeh"
   End If
Exit Sub
Err_Point:
 BBErrorMSG err, "UpisiUIzlazeCeneIzCenovnika"
 retValOk = False
 Resume Exit_Point

End Sub
Private Sub UpisiCeneIzCenovnikaURobneStavke()
On Error GoTo Err_Point:
Dim retValOk As Boolean
    
  retValOk = True
  
  If IsNull(Me!ComboCenovnik) Then
    MsgBox "Morate izabrati cenovnik iz kojeg upisujete cene.", vbExclamation, "QMegaTeh"
    retValOk = False
    GoTo Exit_Point
  End If

 If (Me!UlaznaDokumentaZaUpisCena <> 0) And (Nz(Me!VrstaDokumentaProdaje, "Null") = "Null") Then
    MsgBox "Za ovu kombinaciju parametara MORATE izabrati vrstu dokumenta za upis cena!", vbExclamation, "QMegaTeh"
    retValOk = False
    GoTo Exit_Point
  End If
  
  If Not BBPitanje("Da li ste sigurni?") Then
    retValOk = False
    GoTo Exit_Point
  End If
  
  retValOk = spNabCeneIzCenovnika_Upisi_NC_KLVP(Me!ComboCenovnik, Me!UlaznaDokumentaZaUpisCena, F_IDFirma(), Me!Godina, Me!Prodaja_OdLevel, Me!Prodaja_DoLevel, _
                                                Me!MagacinProdaje, Me!Prodaja_OdDatuma, Me!Prodaja_DoDatuma, Me!VrstaDokumentaProdaje)

Exit_Point:
   On Error Resume Next
   DoCmd.SetWarnings True
   If retValOk Then
    MsgBox "Cene su upisane", vbInformation, "QMegaTeh"
   Else
    MsgBox "Cene nisu upisane!", vbExclamation, "QMegaTeh"
   End If
Exit Sub
Err_Point:
 BBErrorMSG err, "UpisiCeneIzCenovnikaURobneStavke"
 retValOk = False
 Resume Exit_Point

End Sub

Private Sub DugmeUpisiUProdajuCeneIzCenovnika_Click()
   UpisiCeneIzCenovnikaURobneStavke
End Sub

Private Sub Form_Open(Cancel As Integer)

    If F_NivoBaze() > 0 Then
        Me!LabelLevel.Visible = True
        Me!OdLevel.Visible = True
        Me!OdLevel.ValidationRule = "BETWEEN 0 AND " & F_NivoBaze()
        Me!OdLevel.ValidationText = "Dozvoljene vrednosti su od 0 do " & F_NivoBaze()
        Me!DoLevel.Visible = True
        Me!DoLevel.ValidationRule = "BETWEEN 0 AND " & F_NivoBaze()
        Me!DoLevel.ValidationText = "Dozvoljene vrednosti su od 0 do " & F_NivoBaze()
    Else
        Me!LabelLevel.Visible = False
        Me!OdLevel.Visible = False
        Me!DoLevel.Visible = False
    End If
    
   PopuniFormu
       
End Sub
Private Sub DugmeBBPravaPristupa_Click()
On Error GoTo Err_DugmeBBPravaPristupa_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "BBPravaPristupa"
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DugmeBBPravaPristupa_Click:
    Exit Sub

Err_DugmeBBPravaPristupa_Click:
    MsgBox err.Description
    Resume Exit_DugmeBBPravaPristupa_Click
    
End Sub
Private Sub DugmeBBTabStop_Click()
On Error GoTo Err_DugmeBBTabStop_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "CFG_TabStop"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeBBTabStop_Click:
    Exit Sub

Err_DugmeBBTabStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeBBTabStop_Click
    
End Sub

Private Sub Godina_AfterUpdate()
 'BBAktGodina = Me!Godina
 BBCFG.Godina = Me!Godina
End Sub
Private Sub DugmeEDI_Click()
On Error GoTo Err_DugmeEDI_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "EDI"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeEDI_Click:
    Exit Sub

Err_DugmeEDI_Click:
    MsgBox err.Description
    Resume Exit_DugmeEDI_Click
    
End Sub
Private Sub DugmeRunQuery_Click()
On Error GoTo Err_DugmeRunQuery_Click

    Dim stDocName As String
    
    DoCmd.Close acForm, Me.Name
    stDocName = "BBT_BrojDokumenataPoGodinama"
    'DoCmd.OpenQuery stDocName, acNormal, acEdit
    DoCmd.OpenForm stDocName

Exit_DugmeRunQuery_Click:
    Exit Sub

Err_DugmeRunQuery_Click:
    MsgBox err.Description
    Resume Exit_DugmeRunQuery_Click
    
End Sub

Private Sub IDFirma_AfterUpdate()
    BBCFG.IDFirma = Me!IDFirma
End Sub

Private Sub TabCtl60_Change()
    If Me!TabCtl60 = 5 Then
       Me!txtADO_IDENTITY = ADO_IDENTITY
       Me!txtADO_ROWCOUNT = ADO_ROWCOUNT
       Me!txtADO_ROWCOUNT_WITH_ERROR = ADO_ROWCOUNT_WITH_ERROR
       Me!txtADO_EXECUTE_DURATION = ADO_EXECUTE_DURATION
    End If
End Sub

Private Sub UlaznaDokumentaZaUpisCena_AfterUpdate()
Dim stSQL As String
stSQL = "SELECT [R_Vrste dokumenata].[Vrsta dokumenta], [R_Vrste dokumenata].Opis"
stSQL = stSQL & " FROM [R_Vrste dokumenata]"

If Me!UlaznaDokumentaZaUpisCena = 1 Then
    stSQL = stSQL & " WHERE ((([R_Vrste dokumenata].Ulazni) = True))"
ElseIf Me!UlaznaDokumentaZaUpisCena = 0 Then
    stSQL = stSQL & " WHERE ((([R_Vrste dokumenata].Ulazni) = False))"
End If

stSQL = stSQL & " ORDER BY [R_Vrste dokumenata].[Vrsta dokumenta];"

    Me!VrstaDokumentaProdaje = Null
    Me!VrstaDokumentaProdaje.RowSource = stSQL
    Me!VrstaDokumentaProdaje.Requery
End Sub
