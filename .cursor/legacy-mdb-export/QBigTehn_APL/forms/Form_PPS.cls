VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PPS"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit
Private pstSourceObject1 As String
Private pstSourceObject2 As String
Private Function TrebaPrimenitiUslove(Optional lColor) As Boolean
   TrebaPrimenitiUslove = F_TrebaPrimenitiUslove(lColor, Me, Me!DugmePrimeniUslove)
End Function
Public Function F_PrimeniUslove(Optional stSourceObject1, Optional stSourceObject2)
On Error GoTo Err_Point

If Not IsMissing(stSourceObject1) Then
    pstSourceObject1 = stSourceObject1
End If
If Not IsMissing(stSourceObject2) Then
    pstSourceObject2 = stSourceObject2
End If


  If IsMissing(stSourceObject1) Then
     stSourceObject1 = pstSourceObject1
  Else
     pstSourceObject1 = stSourceObject1
  End If
  If IsMissing(stSourceObject2) Then
     stSourceObject2 = pstSourceObject2
  Else
     pstSourceObject2 = stSourceObject2
  End If
  Me!Podforma1.SourceObject = stSourceObject1
  Me!Podforma2.SourceObject = stSourceObject2

  F_TrebaPrimenitiUslove vbBlack, Me, Me!DugmePrimeniUslove
  
Exit_Point:
    On Error Resume Next
    Exit Function
    
Err_Point:
    BBErrorMSG err, "PrimeniUslove"
    Resume Exit_Point
End Function

Private Sub cmdExcel_Click()
On Error GoTo Err_DugmeExport_Click
    
    Call ExportFormToExcel(Me.Podforma1.Form, Me.Podforma2.Form)
        
Exit_DugmeExport_Click:
    Exit Sub

Err_DugmeExport_Click:
    MsgBox err.Description, vbInformation, "BigBit"
    Resume Exit_DugmeExport_Click
End Sub

Private Sub cmdPDF_Click()
On Error GoTo Err_DugmeExport_Click
    
    Call ExportFormToPDF(Me.Podforma1.Form)

Exit_DugmeExport_Click:
    Exit Sub

Err_DugmeExport_Click:
    MsgBox err.Description, vbInformation, "BigBit"
    Resume Exit_DugmeExport_Click
End Sub

Private Sub Command199_Click()
    Call KreirajLokalnuTablicuIzSP("spStrukturaProizvodaPoRedosledu", "tStrukturaProizvodaTMP")
End Sub


Private Sub DugmeDetaljnoDokument_Click()
On Error GoTo Err_Command24_Click

    Dim IDRN As Long
    
    IDRN = Nz(Forms![PPS]![Podforma1].Form![IDRN], 0)
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

Private Sub DugmePrethodniSlog_Click()
    Me.ZaOffset = Nz(Me.ZaOffset, 0) - Nz(Me.ZaPageSize, 20)

    If Me.ZaOffset < 0 Then Me.ZaOffset = 0

    PrimeniUslove
End Sub

Private Sub DugmePrethodniSlog1_Click()
On Error GoTo Err_Dugme___Prethodni_sl_Click
   
    DoCmd.GoToControl "Podforma1"
    DoCmd.GoToRecord , , A_PREVIOUS
    
Exit_Dugme___Prethodni_sl_Click:
    Exit Sub

Err_Dugme___Prethodni_sl_Click:
    MsgBox Error$
    Resume Exit_Dugme___Prethodni_sl_Click

End Sub

Private Sub DugmeSledeciSlog_Click()
    Me.ZaOffset = Nz(Me.ZaOffset, 0) + Nz(Me.ZaPageSize, 20)
    PrimeniUslove

End Sub

Private Sub DugmeSledeciSlog1_Click()
On Error GoTo Err_Dugme___Sledeci_slog_Click
   
    DoCmd.GoToControl "Podforma1"
    DoCmd.GoToRecord , , A_NEXT
    
Exit_Dugme___Sledeci_slog_Click:
    Exit Sub

Err_Dugme___Sledeci_slog_Click:
    MsgBox Error$
    Resume Exit_Dugme___Sledeci_slog_Click

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


Private Sub DugmeKarticaTehPostupka_Click()
On Error GoTo Err_DugmeKarticaTehPostupka_Click

    
    Dim IDRN As Long
    
    IDRN = Nz(Forms![PPS]![Podforma1].Form![IDRN], 0)
    If IDRN <> 0 Then
        KarticaTehnoloskogPostupka IDRN
    Else
        MsgBox "Niste izabrali stavku za karticu radnog naloga"
    End If
Exit_DugmeKarticaTehPostupka_Click:
    Exit Sub

Err_DugmeKarticaTehPostupka_Click:
    MsgBox err.Description
    Resume Exit_DugmeKarticaTehPostupka_Click

End Sub

Private Sub DugmePrimeniUslove_Click()
    PrimeniUslove
End Sub
Private Sub Form_Open(Cancel As Integer)
   
    pstSourceObject1 = "ReklamniPanelPPS1"
    pstSourceObject2 = "ReklamniPanelPPS2"
    'Call BB_PravaPristupaPodesiFormu(Me)
    Me!OdDatumaNaloga = DateAdd("m", -2, Date)
    TrebaPrimenitiUslove (255)
    Me!ZaOffset = 0
    Me!ZaPageSize = 20
End Sub

Private Sub Naziv_DblClick(Cancel As Integer)
    Me![Za komitenta] = Me![Sifra komitenta]
    Me!ZaMISP = Null
    Me!ZaMISP.Requery
    PrimeniUslove
End Sub

Private Sub Label_Prikaz_DblClick(Cancel As Integer)
    PrimeniUslove "ReklamniPanel"
End Sub
Private Sub OdDatuma_DblClick(Cancel As Integer)
    Me![OdDatuma] = Null
    PrimeniUslove
End Sub
Private Sub Za_komitenta_NotInList(NewData As String, Response As Integer)
    NazivKomitentaNijeUListi Me![Za komitenta], NewData, Response
End Sub

Public Function PrimeniUslove()
On Error GoTo Err_Point

    ' --- posebna logika za desnu podformu ---
    Dim OK As Boolean
    DoCmd.Echo False

    ' --- 1?? privremeno otkaèi RecordSource desne podforme ---
    On Error Resume Next
    Call F_PrimeniUslove("ReklamniPanelPPS1", "ReklamniPanelPPS2")
    Me!PPS_PregledPoOperacijama.Form.RecordSource = ""
    On Error GoTo Err_Point

    ' --- 2?? briši staru lokalnu tabelu ---
    On Error Resume Next
    CurrentDb.TableDefs.Delete "tStrukturaProizvodaTMP"
    CurrentDb.TableDefs.Refresh
    On Error GoTo Err_Point
    
    If IsNull(Me!ZaStatus) Then
        OK = KreirajLokalnuTablicuIzSP("spStrukturaProizvodaPoRedosledu", "tStrukturaProizvodaTMP")
    Else
        OK = True
    End If
    
    If OK Then
        PostaviDefaultDatume Me
        If IsNull(Me!ZaStatus) Then
            Call F_PrimeniUslove("PPS_PregledPoNalozima", "PPS_PregledPoOperacijama")
        Else
            Call F_PrimeniUslove("PPS_PregledPoNalozima", "ReklamniPanelPPS2")
        End If
        
       ' Me.lblPage.Caption = "Prikaz: " & _
                     Me.ZaOffset + 1 & _
                     " - " & _
                     Me.ZaOffset + Me.ZaPageSize
    Else
        MsgBox "Desna podforma nije osvežena jer SP nije vratila podatke.", vbInformation
    End If
    DoCmd.Echo True

Exit_Point:
    Exit Function
Err_Point:
    MsgBox "Greška u PrimeniUslove: " & err.Description, vbExclamation
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

End Sub

Private Sub OdDatumaNaloga_DblClick(Cancel As Integer)
    Call F_ClearCurrentVal
    PrimeniUslove
End Sub



Private Sub VezaSaBrojemCrteza_GotFocus()
    Me!VezaSaBrojemCrteza.Requery
End Sub

Private Sub ZaIdentBroj_GotFocus()
    Me!ZaIdentBroj.Requery
End Sub

Private Sub DugmePrethodniSlog2_Click()
On Error GoTo Err_Dugme___Prethodni_sl_Click
    
    DoCmd.GoToControl "Podforma2"
    DoCmd.GoToControl "Op1"
    DoCmd.GoToRecord , , A_PREVIOUS
    
Exit_Dugme___Prethodni_sl_Click:
    Exit Sub

Err_Dugme___Prethodni_sl_Click:
    MsgBox Error$
    Resume Exit_Dugme___Prethodni_sl_Click

End Sub

Private Sub DugmeSledeciSlog2_Click()
On Error GoTo Err_Dugme___Sledeci_slog_Click
    
    DoCmd.GoToControl "Podforma2"
    DoCmd.GoToControl "Op1"
    DoCmd.GoToRecord , , A_NEXT
    
Exit_Dugme___Sledeci_slog_Click:
    Exit Sub

Err_Dugme___Sledeci_slog_Click:
    MsgBox Error$
    Resume Exit_Dugme___Sledeci_slog_Click

End Sub

Public Function DajAktivnuPodformu() As String
    On Error Resume Next
    
    Dim ctrl As control
    Set ctrl = Screen.ActiveControl
    
    If ctrl Is Nothing Then
        DajAktivnuPodformu = ""
        Exit Function
    End If

    ' Ako je fokus direktno na subform kontrolu
    If TypeName(ctrl) = "SubForm" Then
        DajAktivnuPodformu = ctrl.Name
        Exit Function
    End If

    ' Ako je fokus unutar neke podforme
    If TypeOf ctrl.Parent Is SubForm Then
        DajAktivnuPodformu = ctrl.Parent.Name
        Exit Function
    End If

    ' Inaèe fokus je na glavnoj formi
    DajAktivnuPodformu = "PPS"
    
End Function



