VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_RNPregledZag"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit

Private Function TrebaPrimenitiUslove(Optional lColor) As Boolean
Dim retVal As Boolean

If Not IsMissing(lColor) Then
    Me!DugmePrimeniUslove.ForeColor = lColor
End If
  retVal = (Me!DugmePrimeniUslove.ForeColor = vbRed)
  TrebaPrimenitiUslove = retVal
End Function

Private Sub DoDatumaNaloga_AfterUpdate()
    PrimeniUslove
    DoCmd.GoToControl "ZaPredmet"
End Sub

Private Sub DoDatumaNaloga_DblClick(Cancel As Integer)
    'Me!DoDatumaNaloga = Null
    Call PopupCalendar(Screen.ActiveControl, False)
    PrimeniUslove
    DoCmd.GoToControl "DoDatumaNaloga"
End Sub

Private Sub Dugme___Detalji_doku_Click()
On Error GoTo Err_Command24_Click

    Dim IDRN As Long
    
    IDRN = Nz(Forms![RNPregledZag]![RNPregledPodforma].Form![IDRN])
    If IDRN <> 0 Then
        PrikaziDokRN IDRN
    Else
        MsgBox "Niste izabrali stavku za detaljan prikaz radnog naloga"
    End If
    
Exit_Command24_Click:
    Exit Sub

Err_Command24_Click:
    MsgBox err.Description
    Resume Exit_Command24_Click

End Sub

Public Function PrimeniUslove()
On Error GoTo Err_Point
    
    PostaviDefaultDatume Me
    PostaviPodformeSTD
    Forms![RNPregledZag]![RNPregledPodforma].Form.PrimeniUslove
    Forms![RNPregledZag]![RNPregledStavkePodforma].Form.PrimeniUslove
    Forms![RNPregledZag]![RNPregledPostupciPodforma].Form.PrimeniUslove
    TrebaPrimenitiUslove vbBlack
    
Exit_Point:
    Exit Function

Err_Point:
    MsgBox Error$
    Resume Exit_Point
    
End Function



Private Sub Dugme_print_Click()
On Error GoTo Err_DugmePrint_Click

    Dim stDocName As String
    
    If IsNull(Me!ZaRJgrupaRC) Then
        If IsNull(Me!ZaRadnika) Then
            stDocName = "RNPregled"
        Else
            stDocName = "RNPregledPoRadniku"
        End If
    Else
        stDocName = "RNPregledPoRJ"
    End If
    
    DoCmd.OpenReport stDocName, acPreview
 
Exit_DugmePrint_Click:
   Exit Sub

Err_DugmePrint_Click:
    MsgBox err.Description
    Resume Exit_DugmePrint_Click

End Sub

Private Sub Dugme_Stop_Click()
On Error GoTo Err_Dugme_stop_Click


    DoCmd.Close

Exit_Dugme_stop_Click:
    Exit Sub

Err_Dugme_stop_Click:
    MsgBox Error$
    Resume Exit_Dugme_stop_Click
    
End Sub

Private Sub DugmeExportUExcel_Click()
On Error GoTo Err_DugmeExport_Click

    Dim stDocName As String
    stDocName = RNPregledPodforma.[Form].RecordSource
    If Nz(stDocName, "") = "" Then
        Exit Sub
    End If
    If CurrentDb.QueryDefs(stDocName).Name = stDocName Then
        'If TrebaPrimenitiUslove() Then PrimeniUslove
        DoCmd.OutputTo acOutputQuery, stDocName, , , True
    Else
        BBMsgBox_BigBit "Ne postoji upit [" & stDocName & "]"
   End If
Exit_DugmeExport_Click:
    Exit Sub

Err_DugmeExport_Click:
    MsgBox err.Description, vbInformation, "QMegaTeh"
    Resume Exit_DugmeExport_Click

End Sub

Private Sub DugmePrimeniUslove_Click()
    PrimeniUslove
End Sub
Private Sub Form_Activate()
    DoCmd.Maximize
End Sub

Private Sub Form_Open(Cancel As Integer)
   ' PostaviPodformeSTD
    Me!OdDatumaNaloga = DateAdd("d", -F_MaxDanaZaPeriodNaloga(), Date)
    'PostaviKomboPolja
    Me!PoslePoslednje = False
    'PrimeniUslove
End Sub

Private Sub Obrisi_DoDatumaNaloga_Click()
    ObrisiVrednostPrethodneKontrole
    PrimeniUslove
End Sub

Private Sub Obrisi_DoDatumaPredmeta_Click()
    ObrisiVrednostPrethodneKontrole
    PrimeniUslove
End Sub

Private Sub Obrisi_OdDatumaNaloga_Click()
    ObrisiVrednostPrethodneKontrole
    PrimeniUslove
End Sub

Private Sub Obrisi_OdDatumaPredmeta_Click()
    ObrisiVrednostPrethodneKontrole
    PrimeniUslove
End Sub

Private Sub OdDatumaNaloga_AfterUpdate()
    PrimeniUslove
    DoCmd.GoToControl "DoDatumaNaloga"
End Sub

Private Sub OdDatumaNaloga_DblClick(Cancel As Integer)
   ' Me!OdDatumaNaloga = Null
    Call PopupCalendar(Screen.ActiveControl, False)
    PrimeniUslove
    DoCmd.GoToControl "OdDatumaNaloga"
End Sub

Private Sub OdDatumaPredmeta_AfterUpdate()
    PrimeniUslove
    DoCmd.GoToControl "DoDatumaPredmeta"
End Sub

Private Sub OdDatumaPredmeta_DblClick(Cancel As Integer)
'    Me!OdDatumaPredmeta = Null
    Call PopupCalendar(Screen.ActiveControl, False)
    PrimeniUslove
    DoCmd.GoToControl "OdDatumaPredmeta"
End Sub
Private Sub DoDatumaPredmeta_AfterUpdate()
    PrimeniUslove
    DoCmd.GoToControl "OdDatumaNaloga"
End Sub

Private Sub DoDatumaPredmeta_DblClick(Cancel As Integer)
   ' Me!DoDatumaPredmeta = Null
    Call PopupCalendar(Screen.ActiveControl, False)
    PrimeniUslove
    DoCmd.GoToControl "DoDatumaPredmeta"
End Sub


Private Sub ZaBrojCrteza_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaBrojCrteza_DblClick(Cancel As Integer)
    Me!ZaBrojCrteza = Null
    PrimeniUslove
End Sub

Private Sub ZaBrojCrteza_GotFocus()
    Me!ZaBrojCrteza.Requery
End Sub

Private Sub ZaIdentBroj_AfterUpdate()
PrimeniUslove
End Sub

Private Sub ZaIdentBroj_DblClick(Cancel As Integer)
    Me!ZaIdentBroj = Null
    PrimeniUslove
End Sub

Private Sub ZaIdentBroj_Enter()
    Me!ZaIdentBroj.Requery
End Sub

Private Sub ZaKomitenta_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaKomitenta_DblClick(Cancel As Integer)
    Me!ZaKomitenta = Null
    PrimeniUslove
End Sub

Private Sub ZaPredmet_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaPredmet_DblClick(Cancel As Integer)
    Me!ZaPredmet = Null
    PrimeniUslove
End Sub
Private Sub DugmeKarticaTehPostupka_Click()
On Error GoTo Err_DugmeKarticaTehPostupka_Click

    KarticaTehnoloskogPostupka Forms![RNPregledZag]![RNPregledPodforma].Form![IDRN]
    
Exit_DugmeKarticaTehPostupka_Click:
    Exit Sub

Err_DugmeKarticaTehPostupka_Click:
    MsgBox err.Description
    Resume Exit_DugmeKarticaTehPostupka_Click
    
End Sub

Private Sub ZaRadnika_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaRadnika_DblClick(Cancel As Integer)
    Me!ZaRadnika = Null
    PrimeniUslove
End Sub

Private Sub ZaRJgrupaRC_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaRJgrupaRC_DblClick(Cancel As Integer)
    Me!ZaRJgrupaRC = Null
    PrimeniUslove
End Sub

Private Sub ZaVezaSa_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaVezaSa_DblClick(Cancel As Integer)
    Me!ZaVezaSa = Null
    PrimeniUslove
End Sub

Private Sub ZaVezaSa_GotFocus()
    Me!ZaVezaSa.Requery
End Sub


Private Sub PostaviPodformeSTD()
On Error GoTo Err_Dugme_Primeni_filter_Click

    Me!RNPregledPodforma.SourceObject = "ReklamniPanel"
    Me!RNPregledStavkePodforma.SourceObject = "ReklamniPanel2"
    Me!RNPregledPostupciPodforma.SourceObject = "ReklamniPanel3"
    

    If IsNull(Me!ZaRadnika) Then
        If IsNull(Me!ZaRJgrupaRC) Then
            Me!RNPregledPodforma.SourceObject = "RNPregled"
            Me!ZavrsenNalog.Locked = False
        Else
            Me!RNPregledPodforma.SourceObject = "RNPregledPoRJ"
            Me!ZavrsenNalog = False
            Me!ZavrsenNalog.Locked = True
        End If
    Else
        Me!ZaRJgrupaRC = Null
        Me!RNPregledPodforma.SourceObject = "RNPregledPoRadniku"
        Me!ZavrsenNalog.Locked = False
    End If
    
    Me!RNPregledStavkePodforma.SourceObject = "RNPregledStavke"
    Me!RNPregledPostupciPodforma.SourceObject = "RNPregledPostupci"

Exit_Dugme_Primeni_filter_Click:
    Exit Sub

Err_Dugme_Primeni_filter_Click:
    MsgBox Error$
    Resume Exit_Dugme_Primeni_filter_Click
    
End Sub
Private Function PostaviKomboPolja()
On Error GoTo Err_Point
    'BrojCrteza
    Set Me!ZaBrojCrteza.Recordset = RST_Combo(BBCFG.CNNString, "SELECT BrojCrteza FROM tTehnPostupak GROUP BY BrojCrteza", "[Kolona]='Fco'", "BrojCrteza")
    Set Me!DevValuta.Recordset = RST_Combo(BBCFG.CNNString, "SELECT DevValuta FROM T_CMDok_Ulaz GROUP BY DevValuta", "", "DevValuta", "DevValuta")
    Set Me!CmbParitet.Recordset = RST_Combo(BBCFG.CNNString, "SELECT Paritet FROM T_CMDok_Ulaz GROUP BY Paritet", "", "Paritet", "Paritet")
    Set Me!CmbIDMagacin.Recordset = RST_Combo(BBCFG.CNNString, "SELECT IDMagacin, Magacin FROM Magacini", "", "Magacin", "IDMagacin", "Magacin")
    Set Me!VrstaRobe.Recordset = RST_Combo(BBCFG.CNNString, "SELECT VrstaRobe FROM T_CMDok_Ulaz GROUP BY VrstaRobe", "", "VrstaRobe", "VrstaRobe")
    
    Set Me!CmbCM_VrstaDok.Recordset = RST_Combo(BBCFG.CNNString, "SELECT CM_VrstaDok FROM T_CMDok_Ulaz GROUP BY CM_VrstaDok", "", "CM_VrstaDok", "CM_VrstaDok")
    
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PostaviKomboPolja"
 Resume Exit_Point
End Function
Public Sub PostaviDefaultDatume(frm As Form)
    On Error Resume Next
    
    '=== Za naloge ===
    If IsNull(frm!OdDatumaNaloga) Or frm!OdDatumaNaloga = "" Then
        frm!OdDatumaNaloga = #1/1/1900#
    End If
    
    If IsNull(frm!DoDatumaNaloga) Or frm!DoDatumaNaloga = "" Then
        frm!DoDatumaNaloga = #12/31/2999#
    End If

    '=== Za predmete ===
    If IsNull(frm!OdDatumaPredmeta) Or frm!OdDatumaPredmeta = "" Then
        frm!OdDatumaPredmeta = #1/1/1900#
    End If
    
    If IsNull(frm!DoDatumaPredmeta) Or frm!DoDatumaPredmeta = "" Then
        frm!DoDatumaPredmeta = #12/31/2999#
    End If
End Sub

