VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Baze_APL"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PrimeniUslove()
On Error GoTo err_Sub
 
 '   If PostojiForma(Me!ListPodforma) Then
 '      Me!Podforma.SourceObject = Me!ListPodforma
 '   Else
 '      Me!Podforma.SourceObject = "ReklamniPanel"
 '   End If
    
   If Me!OptionGroupPodforma = 1 Then
    Me!Podforma.SourceObject = "Baze_Tipovi_APL"
   ElseIf Me!OptionGroupPodforma = 2 Then
    Me!Podforma.SourceObject = "BazeITabele_APL"
   Else
    Me!Podforma.SourceObject = "ReklamniPanel"
   End If
   
  
Exit_Sub:
    Exit Function
    
err_Sub:
    MsgBox "ErrNo:" & err.Number & vbCrLf & err.Description
    Resume Exit_Sub
  
End Function
Private Function ClearCurrentVal()
   Screen.ActiveControl.Value = Null
   PrimeniUslove
End Function

Private Sub BB_FIT_Database_DblClick(Cancel As Integer)
     Me!BB_FIT_Database = IzberiMDBFajl(Me!BB_FIT_Database)
End Sub

Private Sub CheckTableBazeITabele_Click()
   Call UporediTabeluSaAPL(BazaZaTip("BB_FIT"), "BazeITabele", "BazeITabele_APL")
End Sub

Private Sub CheckTableBazeTipovi_Click()
   Call UporediTabeluSaAPL(BazaZaTip("BB_FIT"), "Baze_Tipovi", "Baze_Tipovi_APL")
End Sub

Private Sub DugmeCFG_Click()
    OtvoriFormuCFGReadWrite
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

Private Sub Form_Open(Cancel As Integer)
Dim stTMP

    If (CurrentUser() <> "Negovan") And Not UserUGrupi(CurrentUser(), "PowerFulUsers") Then
     Cancel = True
    Else
      '  Me!BB_FIT_Database = BazaZaTip("BB_FIT")
     stTMP = CStr(Nz(CurrentDb.TableDefs("Baze_Tipovi").Connect, ""))
     stTMP = Replace(stTMP, ";DATABASE=", "")
     Me!BB_FIT_Database = stTMP
    End If
End Sub


Private Sub DugmeRadniFajlDetaljno_Click()
On Error GoTo Err_DugmeRadniFajlDetaljno_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stLinkCriteria = "[IDBaze]=" & F_IDAktivneBaze()
    stDocName = "RadniFajlDetaljno"
    BBOpenForm stDocName, , , stLinkCriteria

Exit_DugmeRadniFajlDetaljno_Click:
    Exit Sub

Err_DugmeRadniFajlDetaljno_Click:
    MsgBox err.Description
    Resume Exit_DugmeRadniFajlDetaljno_Click
    
End Sub
Private Sub DugmeReLoadPar_Click()
On Error GoTo Err_DugmeReLoadPar_Click

    Dim tmp As String

    Set BBCFG = Nothing
    tmp = BBCFG.Firma.Naziv ' da se ponovo inicijalizuje...
    'BBMsgBox "Saèekajte ... ", 5
    

Exit_DugmeReLoadPar_Click:
    Exit Sub

Err_DugmeReLoadPar_Click:
    MsgBox err.Description
    Resume Exit_DugmeReLoadPar_Click
    
End Sub

Private Sub DugmeRevInfo_Click()
On Error GoTo Err_DugmeRevInfo_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "_APPRev"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeRevInfo_Click:
    Exit Sub

Err_DugmeRevInfo_Click:
    MsgBox err.Description
    Resume Exit_DugmeRevInfo_Click
    
End Sub
Private Sub DugmeODBCSynchDesign_Click()
On Error GoTo Err_DugmeODBCSynchDesign_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "ODBC_Synch_Design"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeODBCSynchDesign_Click:
    Exit Sub

Err_DugmeODBCSynchDesign_Click:
    MsgBox err.Description
    Resume Exit_DugmeODBCSynchDesign_Click
    
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
Private Sub DugmeForsirajBBFITLinkove_Click()
On Error GoTo Err_DugmeForsirajBBITLinkove_Click

    Dim retValOk As Boolean
    If IsLoaded("Baze") Then
      If BBPitanje("Otvorena je forma Baze. Trebalo bi je zatvoriti." & vbCrLf & "Da li zelite da zatvorim formu Baze?") Then
         DoCmd.Close acForm, "Baze"
      Else
         If Not BBPitanje("Da li nastavljate proces forsiranja BB_FIT linkova?") Then
           MsgBox "Linkovi za BB_FIT nisu forsirani.", vbInformation, "QMegaTeh"
           Exit Sub
         End If
      End If
    End If
    
    retValOk = ForsirajBBFitLinkove(Me!BB_FIT_Database) 'ForsirajNoveLinkoveZaTipBaze("BB_FIT", Me!BB_FIT_Database)
    
    If retValOk Then
       MsgBox "Uspešno.", vbInformation, "QMegaTeh"
    Else
       MsgBox "Neuspešno!", vbExclamation, "QMegaTeh"
    End If
    Me.Requery
    Me!Podforma.Requery
    
Exit_DugmeForsirajBBITLinkove_Click:
    Exit Sub

Err_DugmeForsirajBBITLinkove_Click:
    MsgBox err.Description
    Resume Exit_DugmeForsirajBBITLinkove_Click
    
End Sub
Private Function UporediTabeluSaAPL(BazaUKojojSeProverava As String, ImeTabeleUBazi As String, ImeTabeleAPL As String)
On Error GoTo Err_ProveriFitTabelu

    Dim stRetVal As String
    Dim retValOk As Boolean
    Dim stBazaOriginal As String
    Dim tipPoruke
    
    stBazaOriginal = CurrentDb.Name
    
    retValOk = Check2Tables(stBazaOriginal, BazaUKojojSeProverava, ImeTabeleAPL, ImeTabeleUBazi, stRetVal)
    If stRetVal = "" Then
       stRetVal = "RetVal: " & "Sve je OK"
    End If
    stRetVal = "Provera tabela " & ImeTabeleUBazi & " i " & ImeTabeleAPL & " je " & IIf(retValOk, "je uspešno", "NIJE USPEŠNO") & " izvršena." & vbCrLf & stRetVal
    If retValOk Then
       'stRetVal = "Komanda je uspešno izvršena:" & vbCrLf & stRetVal
       tipPoruke = vbInformation
    Else
       'stRetVal = "Komanda NIJE uspešno izvršena:" & vbCrLf & stRetVal
       tipPoruke = vbExclamation
    End If
    MsgBox stRetVal, tipPoruke, "QMegaTeh"
    
Exit_ProveriFitTabelu:
    Exit Function

Err_ProveriFitTabelu:
    MsgBox err.Description
    Resume Exit_ProveriFitTabelu
    
End Function

Private Sub SynchTabeluSaAPL(BazaUKojojSeProverava As String, ImeTabeleUBazi As String, ImeTabeleAPL As String)
    On Error GoTo Err_Point

    Dim stRetVal As String
    Dim retValOk As Boolean
    Dim stBazaOriginal As String
    Dim tipPoruke
    
    stBazaOriginal = CurrentDb.Name
    
    '*********************************!!!!!! USKLADI RELACIJE MORA DA BUDE FALSE!!!!!!!!!!!!!!!!!!!!*******************
    retValOk = Synch2Tables(stBazaOriginal, BazaUKojojSeProverava, ImeTabeleAPL, ImeTabeleUBazi, stRetVal, True, False)
    '*********************************!!!!!! USKLADI RELACIJE MORA DA BUDE FALSE!!!!!!!!!!!!!!!!!!!!*******************
    If stRetVal = "" Then
       stRetVal = "RetVal: " & "Sve je OK"
    End If
    stRetVal = "Sinhronizacija tabela " & ImeTabeleUBazi & " i " & ImeTabeleAPL & " je " & IIf(retValOk, "je uspešno", "NIJE USPEŠNO") & " izvršena." & vbCrLf & stRetVal
    If retValOk Then
       'stRetVal = "Komanda je uspešno izvršena:" & vbCrLf & stRetVal
       tipPoruke = vbInformation
    Else
       'stRetVal = "Komanda NIJE uspešno izvršena:" & vbCrLf & stRetVal
       tipPoruke = vbExclamation
    End If
    MsgBox stRetVal, tipPoruke, "QMegaTeh"
    
Exit_Point:
    Exit Sub

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
    
End Sub

Private Sub SynchTableBazeITabele_Click()
    Call SynchTabeluSaAPL(BazaZaTip("BB_FIT"), "BazeITabele", "BazeITabele_APL")
End Sub

Private Sub SynchTableBazeTipovi_Click()
    Call SynchTabeluSaAPL(BazaZaTip("BB_FIT"), "Baze_Tipovi", "Baze_Tipovi_APL")
End Sub
Private Sub DugmeBaze_Click()
On Error GoTo Err_DugmeBaze_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Baze"
    DoCmd.OpenForm stDocName, , , stLinkCriteria

Exit_DugmeBaze_Click:
    Exit Sub

Err_DugmeBaze_Click:
    MsgBox err.Description
    Resume Exit_DugmeBaze_Click
    
End Sub
