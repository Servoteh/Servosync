VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Primopredaja"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit
Dim pImePodforme As String
Private Function StatusEditDugmeta() As Boolean
  StatusEditDugmeta = (Nz(Me!DugmeEdit, False))
End Function
Private Function PodesiPrikazForme()
On Error GoTo Err_Point
    
    If IsLoaded("PregledPoPredmetima") Then
        Me!DugmeObrisiNalog.Enabled = False
    Else
        Me!DugmeObrisiNalog.Enabled = True
    End If
        
Exit_Point:
On Error Resume Next

Exit Function

Err_Point:
    BBErrorMSG err, "PodesiPrikazForme"
    Resume Next
End Function
Private Function STDWhere() As String
Dim stWhere As String
 'stWhere = "([tRN].IDStatusPrimopredaje<>F_RN_IDStatusPrimopredaje_UObradi())"
 stWhere = "( (([tRN].IDStatusPrimopredaje)<>F_RN_IDStatusDefUObradi()) AND (([tRN].IDStatusPrimopredaje)<>F_RN_IDStatusDefLansiran()) )"
 STDWhere = stWhere
End Function
Private Function PrviIDRN() As Long
On Error GoTo Err_Point
 Dim retVal
 retVal = DMin("[IDRN]", "tRN", STDWhere())
 retVal = CLng(Nz(retVal, 0))
 
Exit_Point:
 On Error Resume Next
 PrviIDRN = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "PrviIDRN"
 retVal = 0
 Resume Exit_Point
End Function
Private Function PoslednjiIDRN() As Long
On Error GoTo Err_Point
 Dim retVal
 Dim stWhere As String
 'stWHERE = "[Ulaz] = False AND [Level] <= " & F_NivoBaze() & " AND [IDFirma] = " & F_IDFirma() & " AND [Godina] = " & F_Godina()
 'stWhere = "((([T_Robna dokumenta].Ulaz)=No) AND (([T_Robna dokumenta].Level) Between [Forms]![IF]![OdLevel] And [Forms]![IF]![OdLevel]) AND (([T_Robna dokumenta].IDFirma)=F_IDFirma()) AND (([T_Robna dokumenta].Godina)=F_Godina()))"
 stWhere = STDWhere()
 retVal = DMax("[IDRN]", "tRN", stWhere)
 retVal = CLng(Nz(retVal, 0))
 
Exit_Point:
 On Error Resume Next
 PoslednjiIDRN = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "PoslednjiIDRN"
 retVal = 0
 Resume Exit_Point
End Function
Private Function PrethodniIDRN() As Long
On Error GoTo Err_Point
 Dim retVal
 Dim stWhere As String
 
 stWhere = STDWhere() & " AND [IDRN]<" & Me!IDRNZaPrikaz
 If Not IsNumeric(Me!IDRNZaPrikaz) Or IsEmpty(Me!IDRNZaPrikaz) Then
  retVal = PoslednjiIDRN
 Else
  retVal = DMax("[IDRN]", "tRN", stWhere)
  retVal = CLng(Nz(retVal, 0))
 End If
 
 If retVal = 0 Then
    retVal = PrviIDRN()
 End If

Exit_Point:
 On Error Resume Next
 PrethodniIDRN = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "PrethodniIDRN"
 retVal = 0
 Resume Exit_Point
End Function
Private Function SledeciIDRN() As Long
On Error GoTo Err_Point
 
Dim retVal
If Not IsNumeric(Me!IDRNZaPrikaz) Or IsEmpty(Me!IDRNZaPrikaz) Then
  retVal = PoslednjiIDRN
 Else
  retVal = DMin("[IDRN]", "tRN", STDWhere() & " AND [IDRN]>" & Me!IDRNZaPrikaz)
  retVal = CLng(Nz(retVal, 0))
 End If
 
 If retVal = 0 Then
    retVal = PoslednjiIDRN()
 End If
 
Exit_Point:
 On Error Resume Next
 SledeciIDRN = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "SledeciIDRN"
 retVal = 0
 Resume Exit_Point
End Function

Public Function PrikaziRNIStavke(Optional parIDRN)
'Modifikovano: 19-01-2020
On Error GoTo Err_PrikaziRNIStavke
Dim pIDRNZaPrikaz As Long
 
 If Not IsMissing(parIDRN) Then
    pIDRNZaPrikaz = parIDRN
 Else
    pIDRNZaPrikaz = Me!IDRNZaPrikaz
 End If
 
 Call PrikaziRN(pIDRNZaPrikaz)
 Call PrikaziStavke(pIDRNZaPrikaz)

 
Exit_PrikaziRNIStavke:
    Exit Function

Err_PrikaziRNIStavke:
    MsgBox err.Description
    Resume Exit_PrikaziRNIStavke
    
End Function
Private Function PrikaziRN(Optional parIDRN)
On Error GoTo Err_Point

 Dim pIDRNZaPrikaz As Long
 Dim retValOk As Boolean
 
 retValOk = True
 
 If Not IsMissing(parIDRN) Then
    pIDRNZaPrikaz = parIDRN
 Else
    pIDRNZaPrikaz = Me!IDRNZaPrikaz
 End If
    
    RNP.IDRN = pIDRNZaPrikaz
    'RNP.CheckPiP = Me!CheckPiP
    Me!IDRNZaPrikaz = RNP.IDRN()
    
    If StatusEditDugmeta() Then
        retValOk = PostaviEditabilanRSource(pIDRNZaPrikaz)
        Me![Podforma].SourceObject = "PrimopredajaUnosStavkiRN"
        Me!Podforma.LinkMasterFields = "IDRN"
        Me!Podforma.LinkChildFields = "IDRN"
    Else
        retValOk = SetProperlyRecordSource(BBCFG.CNNString, Me)
        Me![Podforma].SourceObject = "PregledStavkiPrimopredajaRN"
        'Me!Stavke.LinkMasterFields = "IDRN"
        'Me!Stavke.LinkChildFields = "IDRN"
    End If
    PodesiDugmeEdit
    
Exit_Point:
On Error Resume Next
   PrikaziRN = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziRN"
 retValOk = False
 Resume Exit_Point
End Function
Private Function PrikaziStavke(Optional parIDRN, Optional parDocPodforma) As Boolean
'Modifikovano: 19-01-2020
On Error GoTo Err_Point

Dim pIDRNZaPrikaz As Long
Dim stDocPodforma As String
Dim retValOk As Boolean
 
 retValOk = True
 
 If Not IsMissing(parIDRN) Then
    pIDRNZaPrikaz = parIDRN
 Else
    pIDRNZaPrikaz = Nz(Me!IDRNZaPrikaz, 0)
 End If
    
 If Not IsMissing(parDocPodforma) Then
   stDocPodforma = parDocPodforma
 Else
   If StatusEditDugmeta() Then
        stDocPodforma = "PrimopredajaUnosStavkiRN" 'Me![Podforma].SourceObject
   Else
        stDocPodforma = "PregledStavkiPrimopredajaRN" 'Me![Podforma].SourceObject
   End If
 End If

 
 Me![Podforma].SourceObject = stDocPodforma
 
 
Exit_Point:
On Error Resume Next
   PrikaziStavke = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziStavke"
 retValOk = False
 Resume Exit_Point
End Function
Private Function PostaviEditabilanRSource(IDRNZaEdit As Long) As Boolean
On Error GoTo Err_Point
Dim stSQLEditOn As String
Dim retValOk As Boolean
        
      retValOk = True
      stSQLEditOn = "SELECT * FROM [tRN]"
      stSQLEditOn = stSQLEditOn & " WHERE (IDRN = " & IDRNZaEdit & ");"
      
      Set Me.Recordset = ADO_GetRST(BBCFG.CNNString, stSQLEditOn)
      
Exit_Point:
On Error Resume Next
 
 PostaviEditabilanRSource = retValOk

Exit Function

Err_Point:
  BBErrorMSG err, "PostaviEditabilanRSource"
  retValOk = False
  Resume Exit_Point
End Function
Private Function PostaviKomboPolja()
'Kreirano: 13-01-2022
On Error GoTo Err_Point
 
 
 Set Me!ComboNazivDela.Recordset = RST_Combo(CNN_CurrentDataBase, "VrednostiZaKombo", "[Kolona]='Fco'", "Vrednost", "Vrednost")
 
 Set Me!ComboMaterijal.Recordset = RST_Combo(CNN_CurrentDataBase, "VrednostiZaKombo", "[Kolona]='Nacin otpreme'", "Vrednost", "Vrednost")
 
 Set Me!ComboDimenzijaMaterijala.Recordset = RST_Combo(CNN_CurrentDataBase, "VrednostiZaKombo", "[Kolona]='Nacin placanja'", "Vrednost", "Vrednost")
 
 Set Me!ComboVezaSaBrojemCrteza.Recordset = RST_Combo(CNN_CurrentDataBase, "VrednostiZaKombo", "[Kolona]='KS'", "Vrednost", "Vrednost")
  
 'Set Me!ComboVrstaDokumenta.Recordset = RST_Combo(CNN_CurrentDataBase, "R_Vrste dokumenata", "", "Vrsta dokumenta", "Vrsta dokumenta", "Opis")
 'Set Me!ComboCenovnik.Recordset = RST_Combo(CNN_CurrentDataBase, "CEN_DozvoljeniCenovnici", "", "CenVrstaDok", "CenVrstaDok")
 'Set Me!ComboIDMagZaPrenos.Recordset = RST_Combo(CNN_CurrentDataBase, "Magacini", "", "Magacin", "IDMagacin", "Magacin", "UlicaIBroj")
 
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "PostaviKomboPolja"
 Resume Exit_Point
End Function
Private Function EditUkljuciIskljuci(chkEdit As Boolean, Optional SourceObject As String)
On Error GoTo Err_Point

    Dim stSQLEditOn As String
    Dim IDRNZaEdit As Long
    
    On Error Resume Next
    IDRNZaEdit = Me!IDRN
    
    If err Then
     err.Clear
     IDRNZaEdit = 0
    End If
    
     If chkEdit Then
        If PostaviEditabilanRSource(IDRNZaEdit) Then
          Me![Podforma].SourceObject = "PrimopredajaUnosStavkiRN"
                    
          Me!Stavke.LinkMasterFields = "IDRN"
          Me!Stavke.LinkChildFields = "IDRN"
        Else
          'NE ZNAM STA OVDE!
        End If
     Else
          
      PrikaziRNIStavke IDRNZaEdit
      
     End If
     
   PodesiPrikazForme
   
Exit Function
    
Exit_Point:
    Exit Function

Err_Point:
    BBErrorMSG err, "EditUkljuciIskljuci"
    Resume Exit_Point
End Function
Private Sub PodesiDugmeEdit()
    With Me.DugmeEdit
        If .Value = True Then
            .Caption = "Edit mod ukljuèen"
            .BackColor = RGB(200, 255, 200)  ' svetlo zelena
            .ForeColor = RGB(0, 80, 0)       ' tamnozelena slova
        Else
            .Caption = "Edit mod iskljuèen"
            .BackColor = RGB(255, 200, 200)  ' svetlo crvena
            .ForeColor = RGB(120, 0, 0)      ' tamnocrvena slova
        End If
    End With
End Sub
Private Sub DugmeEdit_AfterUpdate()
    EditUkljuciIskljuci Me!DugmeEdit
End Sub

Private Sub DugmeEdit_Click()
    PodesiDugmeEdit
End Sub

Private Sub DugmeEdit_GotFocus()
    Me.AllowEdits = True
End Sub

Private Sub DugmeEdit_LostFocus()
    ProveriZakljucavanje
End Sub
Private Sub Dugme___Stop_Click()
On Error GoTo Err_Dugme___Stop_Click


    DoCmd.Close

Exit_Dugme___Stop_Click:
    Exit Sub

Err_Dugme___Stop_Click:
    MsgBox Error$
    Resume Exit_Dugme___Stop_Click
    
End Sub

Private Sub Dugme_Printuj_kalkul_Click()
On Error GoTo Err_Dugme_Printuj_kalkul_Click

    Dim stDocName As String
    Dim ID As Long
    
    Select Case Me!TabCtlRN
    Case 0
        'ID = Nz(DLookup("ID", "tStavkeRN_BrOperacija"), 0)
        'If ID <> 0 Then
            stDocName = "rRN"
        'Else
        '    stDocName = "rRN_BezBarKoda"
        'End If
    Case 1
        stDocName = "rRN_tPND"
    Case 2
        stDocName = "rRN_tPDM"
    Case 3
        stDocName = "rRN_tPLP"
    Case 4
        stDocName = "rRN_tKomponente"
    Case 5
        stDocName = "rRN_tNDKomponente"
    End Select
    
    DoCmd.OpenReport stDocName, A_PREVIEW

Exit_Dugme_Printuj_kalkul_Click:
    Exit Sub

Err_Dugme_Printuj_kalkul_Click:
    If err.Number <> 2501 Then MsgBox Error$
    Resume Exit_Dugme_Printuj_kalkul_Click

End Sub

Private Sub DugmeKopirajPostupke_Click()
On Error GoTo Err_DugmeKopirajPostupke_Click

    If RN_NemaStavke_ADO(CNN_CurrentDataBase(), F_RN_IDRN()) Then
        'stDocName = "IzborNalogaZaPrepisivanje"
        'DoCmd.OpenForm stDocName, , , stLinkCriteria
        IzborNalogaZaPrepisivanje F_RN_IDRN(), Me.Name
        
        While IsLoaded("IzborNalogaZaPrepisivanje")
         DoEvents
        Wend
        PrikaziRN F_RN_IDRN()
        PrikaziStavke F_RN_IDRN()
    Else
        MsgBox "Po ovom nalogu ste veæ unosili neke postupke!!!" & vbCrLf & "ili niste otvorili novi nalog u koji prepisujete stavke drugog naloga", vbInformation
    End If
    
Exit_DugmeKopirajPostupke_Click:
    Exit Sub

Err_DugmeKopirajPostupke_Click:
    MsgBox err.Description
    Resume Exit_DugmeKopirajPostupke_Click

End Sub

Private Sub DugmeLansirajPrimopredaju_Click()
On Error GoTo Err_Handler

    ' pretpostavljam da u formi veæ imaš kolonu IDRN
    Dim lngIDRN As Long
    Dim gUserSifraRadnika As Long
    
    lngIDRN = Me!IDRN
    gUserSifraRadnika = IDRadnikZaCurrentUser()
    
    ' poziv stored procedure
    ' Parametri idu redom: CNNString, NazivSP, IDRN, NoviStatus
    'Call ADO_ExecSP(CNN_CurrentDataBase, "spLansirajPrimopredajuZaIDRN", lngIDRN)
    
    Call ADO_ExecSP(CNN_CurrentDataBase, "spPromeniStatusPrimopredaje", lngIDRN, 3, Null, gUserSifraRadnika)
    
    ' osvežavanje forme da se vide promene
    

    MsgBox "Radni nalog je uspešno lansiran.", vbInformation
    DoCmd.Close
    
Exit_Point:
    Exit Sub
Err_Handler:
    MsgBox "Greška: " & err.Description, vbCritical
    Resume Exit_Point
End Sub

Private Sub DugmeMyRequery_Click()
    PrikaziRNIStavke
    PostaviKomboPolja
End Sub

Private Sub DugmePrint_Click()
    PreviewPDFCrtez_Binary
End Sub

Private Sub Form_Activate()
    DoCmd.Maximize
End Sub

Private Sub Form_Close()
    CloseConnectionOnCurrentForm Me
End Sub

Private Sub Form_Current()
'    ProveriZakljucavanje
    RNP.IDRN = Me!IDRN
    ProveriZakljucavanje
    DugmeLansirajEnabled
End Sub
Private Sub DugmeLansirajEnabled()
    If Me!IDStatusPrimopredaje = F_RN_IDStatusDefLansiran() Then
       Me!DugmeLansirajPrimopredaju.Enabled = False
    Else
       Me!DugmeLansirajPrimopredaju.Enabled = True
    End If
End Sub
Private Sub ProveriZakljucavanje()
    Dim userReadOnly As Boolean
    userReadOnly = IsReadOnlyUser()
    
    Application.Echo False
    If Nz(Me!Zakljucano, False) Then
        Me.FormHeader1.BackColor = BBCFG.ColorLock
        Me.Detail0.BackColor = BBCFG.ColorLock
        Me.AllowEdits = False
        Me.AllowDeletions = False
    ElseIf userReadOnly Then
        Me.AllowEdits = False
        Me.AllowAdditions = False
        Me.AllowDeletions = False
        Me![Dugme -Novi dokumenat].Enabled = False
        Me!DugmeKopirajPostupke.Enabled = False
        'Me!DugmeKreirajIstiPostupak.Enabled = False
    Else
        Me.FormHeader1.BackColor = BBCFG.ColorUnLock
        Me.Detail0.BackColor = BBCFG.ColorUnLock
        Me.AllowEdits = True
        Me.AllowDeletions = True
    End If
      
    
    Application.Echo True
End Sub

Private Sub Form_Open(Cancel As Integer)
On Error GoTo Err_Point

Dim stFilter As String
    '16-01-2021
    pImePodforme = "PregledStavkiPrimopredajaRN"
    
    If Nz(Me.OpenArgs, "") = "CallerMenu" Then
       RNP.Caller = "QPrvaMaska"
    End If
    
    If Me.FilterOn Then
        stFilter = Nz(Me.Filter)
        stFilter = Replace(stFilter, " ", "")
        stFilter = Replace(stFilter, "[IDRN]=", "")
        If IsNumeric(stFilter) Then
            Me!IDRNZaPrikaz = CLng(stFilter)
        Else
            Me!IDRNZaPrikaz = PoslednjiIDRN
        End If
    Else
        If RNP.Caller = "DetaljnoDokument" Then
            Me!IDRNZaPrikaz = RNP.IDRN
        Else
            Me!IDRNZaPrikaz = PoslednjiIDRN()
        End If
    End If
     
    PrikaziRN Me!IDRNZaPrikaz
    PrikaziStavke Me!IDRNZaPrikaz
    
    PodesiPrikazForme
    
    PostaviKomboPolja
    DoCmd.GoToControl "RNDokumentaTrazi"
    ProveriInboxPlanera
    
 Exit Sub
Err_Point:
  BBErrorMSG err, "Form_Open"
  Resume Next

End Sub

Private Sub RNDokumentaTrazi_AfterUpdate()
    Call PrikaziRNIStavke(Me![RNDokumentaTrazi])
    Me![RNDokumentaTrazi] = Null
    Exit Sub
End Sub

Private Sub TabCtlRN_Change()
    Dim stDocName As String
    Dim stLinkCriteria As String

    Dim editOn As Boolean
    Dim IDRN As Long

    ' --- trenutni RN ---
    IDRN = Nz(Me!IDRN, 0)
    editOn = (Nz(Me!DugmeEdit.Value, False) = True)
    
    Select Case Me!TabCtlRN
    Case 0
        If editOn Then
            stDocName = "PrimopredajaUnosStavkiRN"
            Me!LblPodforma.Caption = "Unos stavki tehnološkog postupka"
        Else
            stDocName = "PregledStavkiPrimopredajaRN"
            Me!LblPodforma.Caption = "Pregled stavki tehnološkog postupka"
        End If
        Me!Podforma.Width = 16860
    Case 1
        stDocName = "PrimopredajaUnosStavkiPND"
        Me!Podforma.Width = 16250
        Me!LblPodforma.Caption = "Unos nabavnih delova"
    Case 2
        stDocName = "PrimopredajaUnosStavkiPDM"
        Me!Podforma.Width = 16250
        Me!LblPodforma.Caption = "Unos delova za montažu"
    Case 3
        stDocName = "PrimopredajaUnosStavkiPLP"
        Me!Podforma.Width = 16250
        Me!LblPodforma.Caption = "Unos limova i profila"
    Case 4
        stDocName = "PrimopredajaUnosStavkiKomponente"
        Me!Podforma.Width = 16250
        Me!LblPodforma.Caption = "Unos referentnih delova i podsklopova"
    Case 5
        stDocName = "PrimopredajaUnosStavkiNDKomponente"
        Me!Podforma.Width = 16250
        Me!LblPodforma.Caption = "Unos nabavljenih delova"
    End Select
    Me!Podforma.SourceObject = stDocName
    Me!Podforma.SetFocus
    
End Sub

Private Sub Zakljucavanje_Click()
On Error GoTo Err_Zakljucavanje_Click
 

 If Not IsNull(Me!IDRN) Then
  ZakOtkDok "tRN", "IDRN", Me!IDRN, Not Nz(Me!Zakljucano, False)
 End If
 
 Application.Echo False
   Me.Recalc
   ProveriZakljucavanje
Exit_Zakljucavanje_Click:
 Application.Echo True
Exit Sub

Err_Zakljucavanje_Click:
    MsgBox err.Description
    Resume Exit_Zakljucavanje_Click
    
End Sub
