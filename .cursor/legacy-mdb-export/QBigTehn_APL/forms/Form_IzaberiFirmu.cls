VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_IzaberiFirmu"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit
Private Function PonistiIPrimeni()
Dim ctl As control
 Set ctl = Screen.ActiveControl
 
 ctl.Value = Null
 PrimeniUslove
 ctl.SetFocus
 
End Function
Private Function NadjiFirmu(Optional IDFirma As Variant)
On Error GoTo Err_Point

Dim pIDFirma As Long

    If IsMissing(IDFirma) Then
      pIDFirma = BBCFG.IDFirma
    ElseIf IsNull(IDFirma) Then
     pIDFirma = BBCFG.IDFirma
    Else
     pIDFirma = CLng(IDFirma)
    End If
    
    Me.RecordsetClone.FindFirst "[IDBaze] = " & pIDFirma
    Me.Bookmark = Me.RecordsetClone.Bookmark
    
Exit_Point:
  Exit Function
Err_Point:
  BBErrorMSG err, "IzaberiFirmu::NadjiFirmu"
  Resume Exit_Point
End Function
Public Function PrimeniUslove()
 Me.Requery
End Function
Private Function ZatvoriSveOtvoreneForme() As Boolean
On Error GoTo Err_Point
 Dim frm As Form
 Dim stMsg As String
 Dim retValOk As Boolean
 
 stMsg = ""
 retValOk = True
 
 For Each frm In Application.Forms
  If (frm.Name <> "Prva maska") And (frm.Name <> "IzaberiFirmu") Then
    stMsg = stMsg & vbCrLf & frm.Name
    'frm.Close
  End If
 Next
 If stMsg <> "" Then
   stMsg = "Za promenu aktivne firme treba zatvoriti forme: " & vbCrLf & stMsg
   stMsg = stMsg & vbCrLf & vbCrLf & "Da li nastavljate (sa zatvaranjem otvorenih formi)?"
   If Not BBPitanje(stMsg) Then
     retValOk = False
     GoTo Exit_Point
   Else
     While Application.Forms.Count > 2
        For Each frm In Application.Forms
           If (frm.Name <> "Prva maska") And (frm.Name <> "IzaberiFirmu") Then
              DoCmd.Close acForm, frm.Name, acSavePrompt
           End If
        Next
     Wend
    
   End If
 End If
Exit_Point:
  ZatvoriSveOtvoreneForme = retValOk
  Exit Function
Err_Point:
  BBErrorMSG err, "IzaberiFirmu::ZatvoriSveOtvoreneForme"
  retValOk = False
  Resume Exit_Point
End Function

Private Function IzaberiFirmuZaRad() As Boolean

On Error GoTo Err_Point
    
    Dim retValOk As Boolean
    
    If Not ZatvoriSveOtvoreneForme() Then
      retValOk = False
      GoTo Exit_Point
    End If
    
    retValOk = True
    '13-01-2020 Set BBCFG = Nothing
    AktivnaFirma = ""
    BBCFG.IDFirma = Me!IDBaze
    'Ulinuto: 27-10-2021 IDAktivneBaze = BBCFG.IDFirma
    '13-01-2020 PostaviGlobalneParametre
    
    'StartnoZakljucavanjeRoba
    'StartnoZakljucavanjeGK
    
    '13-01-2020  If F_ProveraPorukaInterval > 0 Then BBOpenForm "P_PorukeTimerForm"
    IzaberiFirmuZaRad = True
    
    If IsLoaded("Prva maska") Then
       Forms("Prva maska").PrikaziAktivnuFirmu
    End If

Exit_Point:
On Error Resume Next
  IzaberiFirmuZaRad = retValOk
Exit Function

Err_Point:
  BBErrorMSG err, "IzaberiFirmu::IzaberiFirmuZaRad"
  retValOk = False
  Resume Exit_Point
End Function

Private Function DodajRadniFajl(stNazivFirme As String) As Long
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim IDNoveBaze As Long
Dim stSQL As String

retValOk = True

IDNoveBaze = SledeciAutoID("[Radni fajlovi]", "IDBaze")

stSQL = ""
stSQL = stSQL & "INSERT INTO [Radni fajlovi]" & vbCrLf
stSQL = stSQL & "           ([IDBaze]" & vbCrLf
stSQL = stSQL & "           ,[Firma]" & vbCrLf
stSQL = stSQL & "           )" & vbCrLf
stSQL = stSQL & "    Values" & vbCrLf
stSQL = stSQL & "           (" & CStr(IDNoveBaze) & vbCrLf
stSQL = stSQL & "           ,'" & stNazivFirme & "'" & vbCrLf
stSQL = stSQL & "            )" & vbCrLf

retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
 
Exit_Point:
 On Error Resume Next
       DodajRadniFajl = IDNoveBaze
Exit Function

Err_Point:
 BBErrorMSG err, "DodajRadniFajl"
 retValOk = False
 Resume Exit_Point

End Function
Private Sub DodajNovuFirmu_Click()
On Error GoTo Err_Point

    Dim stDocName As String
    Dim stLinkCriteria As String
    Dim IDNoveBaze As Long
    Dim stNaziv As String
    
    stNaziv = InputBox("Unesite naziv nove firme", "QBigTeh")
    If stNaziv <> "" Then
       IDNoveBaze = DodajRadniFajl(stNaziv)
       PrimeniUslove
       PronadjiSlogNaFormi Me, "IDBaze = " & CStr(IDNoveBaze)
       DugmeDetaljnoRadniFajl_Click
    Else
        Exit Sub
    End If

Exit_Point:
    Exit Sub

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
End Sub

Private Sub DugmeIzaberiFirmuZaRad_Click()
    If IzaberiFirmuZaRad() Then
     DoCmd.Close acForm, "IzaberiFirmu", acSavePrompt
    End If
End Sub


Private Sub DugmeZatvoriForme_Click()
    ZatvoriSveOtvoreneForme
End Sub

Private Sub Firma_DblClick(Cancel As Integer)
    IzaberiFirmuZaRad
    DoCmd.Close acForm, Me.Name, acSavePrompt
End Sub

Private Sub Form_Close()
    If IsLoaded("Prva maska") Then
     'DoCmd.SelectObject acForm, "Prva maska"
     DoCmd.OpenForm "Prva maska"
    End If
End Sub

Private Sub Form_Open(Cancel As Integer)
    Me!AktivnaBazaPodataka = BBCFG.CnnStringBezPWD()
    NadjiFirmu
    
    If UserUGrupi(CurrentUser(), "PowerfulUsers") Then
        Me!DodajNovuFirmu.Enabled = True
    Else
        On Error Resume Next
        DoCmd.GoToControl "DugmeIzaberiFirmuZaRad"
        Me!DodajNovuFirmu.Enabled = False
    End If
End Sub


Private Sub DetaljnoRadniFajl()
On Error GoTo Err_DetaljnoRadniFajl

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "RadniFajlDetaljno"
    
    stLinkCriteria = "[IDBaze]=" & Me![IDBaze]
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DetaljnoRadniFajl:
    Exit Sub

Err_DetaljnoRadniFajl:
    MsgBox err.Description
    Resume Exit_DetaljnoRadniFajl
    
End Sub
Private Sub DugmeDetaljnoRadniFajl_Click()
On Error GoTo Err_DugmeDetaljnoRadniFajl_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "RadniFajlDetaljno"
    IzaberiFirmuZaRad
    stLinkCriteria = "[IDBaze]=" & Me![IDBaze]
    DoCmd.Close
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DugmeDetaljnoRadniFajl_Click:
    Exit Sub

Err_DugmeDetaljnoRadniFajl_Click:
    MsgBox err.Description
    Resume Exit_DugmeDetaljnoRadniFajl_Click
    
End Sub


Private Sub DugmeHideNavPane_Click()
On Error GoTo Err_HideNavPane_Click
Static bVisible As Boolean

If IsEmpty(bVisible) Then
    bVisible = True
End If

            If bVisible Then
            '            DoCmd.SelectObject acTable, , True
            DoCmd.SelectObject acModule, , True
            DoCmd.RunCommand acCmdWindowUnhide
        Else
            '           DoCmd.SelectObject acTable, , True
            '           DoCmd.SelectObject acTable, "_Rev", True
            '           DoCmd.NavigateTo ("acNavigationCategoryObjectType")
                        
            DoCmd.SelectObject acModule, , True
            DoCmd.RunCommand acCmdWindowHide
        End If
            
Exit_HideNavPane_Click:
    Exit Sub

Err_HideNavPane_Click:
    MsgBox err.Description
    Resume Exit_HideNavPane_Click
    
End Sub
