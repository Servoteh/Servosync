VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Pisarnica_UnosPredmeta"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Const STDPodforma = "T_Predmeti_Prilozi"
Public Function PrimeniUslove()
    Me!Podforma.Form.PrimeniUslove
End Function
Private Function SledeciBrojPredmeta() As String

On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stRetVal As String

retValOk = True
stRetVal = ""



'stRetVal = CStr(1 + DCount("*", "T_Predmeti", "ORGAN='" & CStr(Nz(Me!ORGAN, "-")) & "' AND KLASIF='" & CStr(Nz(Me!KLASIF, "-")) & "' AND Godina=" & Nz(Me!Godina, 0)))
'!ORGAN se ne uzima u obtir kod numeracije
stRetVal = CStr(1 + DCount("*", "T_Predmeti", "KLASIF='" & CStr(Nz(Me!KLASIF, "-")) & "' AND Godina=" & CStr(Nz(Me!Godina, 0))))

Exit_Point:
 On Error Resume Next
       SledeciBrojPredmeta = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "SledeciBrojPredmeta"
 retValOk = False
 Resume Exit_Point

End Function
Private Function OdrediBrojPredmeta() As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

retValOk = True

If Trim(CStr(Nz(Me!Godina, "-"))) = "-" Then
   MsgBox "Za dodelu broja predmeta morate uneti vrednost ""Godina"".", vbExclamation, "BBPisarnica"
   retValOk = False
   GoTo Exit_Point
End If

If Trim(CStr(Nz(Me!ORGAN, "-"))) = "-" Then
   MsgBox "Za dodelu broja predmeta morate uneti vrednost ""Organ"".", vbExclamation, "BBPisarnica"
   retValOk = False
   GoTo Exit_Point
End If

If Trim(CStr(Nz(Me!KLASIF, "-"))) = "-" Then
   MsgBox "Za dodelu broja predmeta morate uneti vrednost ""Klasifikacija"".", vbExclamation, "BBPisarnica"
   retValOk = False
   GoTo Exit_Point
End If

    If CStr(Nz(Me!BROJ, "")) = "" Then
        Me!BROJ = SledeciBrojPredmeta
    Else
       If BBPitanje("Da li zaista želite da promenite broj predmeta?", vbDefaultButton2) Then
        Me!BROJ = SledeciBrojPredmeta
       End If
    End If
 
Exit_Point:
 On Error Resume Next
 OdrediBrojPredmeta = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "OdrediBrojPredmeta"
 retValOk = False
 Resume Exit_Point

End Function

Private Sub BROJ_DblClick(Cancel As Integer)
    OdrediBrojPredmeta
End Sub

Private Sub DugmePrimeniUslove_Click()
    PrimeniUslove
End Sub

Private Sub DugmeNoviSlog_Click()
    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "Godina"
End Sub
Public Function PostaviPodformu()
On Error GoTo Err_Point
Dim pZakljucano
Dim stSubFormName As String


On Error Resume Next
    pZakljucano = Me!Zakljucano
On Error GoTo Err_Point

If IsEmpty(pZakljucano) Or IsNull(pZakljucano) Then
   stSubFormName = STDPodforma
ElseIf Me!Zakljucano Then
   stSubFormName = STDPodforma
Else
    stSubFormName = STDPodforma
End If
Me!Podforma.SourceObject = stSubFormName


Exit_Point:
 On Error Resume Next

Exit Function

Err_Point:
 BBErrorMSG err, "PostaviPodformu"
 Resume Exit_Point
End Function
Private Sub DugmePoslednjiSlog_Click()
 Dim pIDDok
 pIDDok = Me!IDPredmet
 
    Me!Podforma.SourceObject = ""
    BBTSMoveLastRecord
    
On Error Resume Next
    If Nz(Me!IDPredmet, 0) = Nz(pIDDok, 0) Then
       PostaviPodformu
    End If
 
End Sub

Private Sub DugmePrethodniSlog_Click()
Dim pIDDok
 pIDDok = Me!IDPredmet
 
    Me!Podforma.SourceObject = ""
    BBTSMovePreviousRecord
    
On Error Resume Next
    If Nz(Me!IDPredmet, 0) = Nz(pIDDok, 0) Then
       PostaviPodformu
    End If

End Sub
Private Function PrintujOmotZaPredmet(IDPredmet As Long, VRSTA As String) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stReportName As String
Dim stWhere As String
Dim intVrsta As Integer

retValOk = True

intVrsta = Eval(VRSTA)

Select Case intVrsta
    Case 1
        stReportName = "OmotZaPredmet"
    Case 2
        stReportName = "OmotZaPredmet"
    Case 7
        stReportName = "OmotZaPredmet"
Case Else
        stReportName = "OmotZaPredmet"
        'MsgBox "Ne postoji omot za izabranu vrstu= " & VRSTA, vbExclamation, "BBPisarnica"
        'retValOk = False
        'GoTo exit_Point
End Select

stWhere = "IDPredmet=" & CStr(IDPredmet)

DoCmd.OpenReport stReportName, acViewPreview, , stWhere

Exit_Point:
 On Error Resume Next
       PrintujOmotZaPredmet = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PrintujOmotZaPredmet"
 retValOk = False
 Resume Exit_Point

End Function
Private Sub DugmePrint_Click()
    PrintujOmotZaPredmet CLng(Nz(Me!IDPredmet, 0)), Nz(Me!VRSTA, 0)
End Sub

Private Sub DugmePrviSlog_Click()

 Dim pIDDok
 pIDDok = Me!IDPredmet
 
    Me!Podforma.SourceObject = ""
    BBTSMoveFirstRecord
    
On Error Resume Next
    If Nz(Me!IDPredmet, 0) = Nz(pIDDok, 0) Then
       PostaviPodformu
    End If
 
End Sub

Private Sub DugmeSledeciSlog_Click()
Dim pIDDok
 pIDDok = Me!IDPredmet
 
    BBTSMoveNextRecord
    
On Error Resume Next
    If Nz(Me!IDPredmet, 0) = Nz(pIDDok, 0) Then
       PostaviPodformu
    End If
End Sub

Private Sub DugmeSnimiSlog_Click()
On Error GoTo Err_Point

 If Not Nz(Me!Zakljucano, False) Then
    DoCmd.RunCommand acCmdSaveRecord
 End If

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "DugmeSnimiSlog_Click"
 Resume Exit_Point

End Sub

Private Sub DugmeStop_Click()
    On Error GoTo Err_DugmeStop_Click


    If Me.Dirty Then Me.Dirty = False
    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
End Sub

Private Sub Form_BeforeUpdate(Cancel As Integer)
    If Not PitajDaLiSuDobriDatumiZaGodinu(Me!Godina, Me!DATUMP) Then
       Cancel = True
    End If
    Me!PoslednjaIzmena = Now()
End Sub
Private Function ComboRequery()

On Error GoTo Err_Point
Dim retValOk As Boolean
retValOk = True

Me!SOPIS.Requery
Me!Opis.Requery

Exit_Point:
 On Error Resume Next
       ComboRequery = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ComboRequery"
 retValOk = False
 Resume Exit_Point

End Function
Private Function OfarbajPredmet() As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim intVrsta As Integer
Dim boja As Long
    
    retValOk = True
    
    intVrsta = CInt(Nz(Me!VRSTA, 0))
    
    If intVrsta = 1 Then
        boja = vbRed
    ElseIf intVrsta = 2 Then
        boja = vbYellow
    ElseIf intVrsta = 7 Then
        boja = vbWhite
    Else
        boja = 16764057  '&H99CCFF
    End If
    
   
Exit_Point:
 On Error Resume Next
       'Me!Label_NazivForme.BackColor = boja
       'Me!STRANKA_Label.BackColor = boja
        Me!VRSTA_Label.BackColor = boja

       OfarbajPredmet = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "OfarbajPredmet"
 retValOk = False
 Resume Exit_Point

End Function

Private Sub Form_Current()
    ProveriZakljucavanje
    ComboRequery
    OfarbajPredmet
End Sub

Private Sub Form_Open(Cancel As Integer)
    DoCmd.GoToRecord , , acLast
    DoCmd.GoToControl "DugmeNoviSlog"
End Sub
Private Sub ProveriZakljucavanje()
On Error GoTo err_Sub

If Not BBCFG.SysProveraZakljucavanja Then
 Exit Sub
End If

BBCFG.SetAppEcho False, "Form_Current"
If Nz(Me!Zakljucano, False) Then
        Me.FormHeader.BackColor = BBCFG.ColorLock
        Me.Detail.BackColor = BBCFG.ColorLock
        Me.AllowEdits = False
        Me.AllowDeletions = False
        
        'Me!DugmeNapraviIzlazniDok.Enabled = False
        
  Else
        Me.FormHeader.BackColor = BBCFG.ColorUnLock
        Me.Detail.BackColor = BBCFG.ColorUnLock
        Me.AllowEdits = True
        Me.AllowDeletions = True
        
        'Me!DugmeNapraviIzlazniDok.Enabled = True
        
  End If
  
  PostaviPodformu
  
Exit_Sub:
 BBCFG.SetAppEcho True, "Form_Current"
Exit Sub
err_Sub:
 'BBErrorMSG Err, "Ulazna faktura/ProveriZakljucavanje"
 Resume Exit_Sub
End Sub


Private Sub KLASIF_AfterUpdate()
 ComboRequery
End Sub

Private Sub ORGAN_AfterUpdate()
    If Me!ORGAN.OldValue <> Me!ORGAN Then
       MsgBox "Promenom ove vrednosti menja se i broj predmeta!", vbExclamation, "BB_Pisarnica"
    End If
End Sub

Private Sub VRSTA_AfterUpdate()
    OfarbajPredmet
End Sub

Private Sub Zakljucavanje_Click()
On Error GoTo Err_Zakljucavanje_Click

Me!Podforma.SourceObject = ""

If Not IsNull(Me!IDPredmet) Then
    ZakOtkDok "T_Predmeti", "IDPredmet", Me!IDPredmet, Not Nz(Me!Zakljucano, False)
End If

 BBCFG.SetAppEcho False, "Zakljucavanje_Click"
Me.Recalc
 BBCFG.SetAppEcho True, "Zakljucavanje_Click"
 
ProveriZakljucavanje

Exit_Zakljucavanje_Click:
  BBCFG.SetAppEcho True, "Zakljucavanje_Click"
Exit Sub

Err_Zakljucavanje_Click:
    MsgBox err.Description
    Resume Exit_Zakljucavanje_Click
    
End Sub
