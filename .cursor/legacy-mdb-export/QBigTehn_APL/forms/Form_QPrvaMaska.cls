VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_QPrvaMaska"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit

Private Sub PrikaziAPPRev()
  Me!BBAppRev.Caption = F_APPRev()
  Me!txtCurrentUser = CurrentUser() & " (" & Environ("UserName") & ")"
  'Me!LabelWinUser.Caption = Environ("UserName")
End Sub


Private Sub BBAppRev_DblClick(Cancel As Integer)
    BBOpenForm ("CFGReadWrite")
End Sub

Private Sub Form_Close()

If CurrentUser <> "Negovan" Then
    'DoCmd.Quit
    QuitBigBit
Else
    QuitBigBit False, True, True
End If
End Sub

Private Sub Form_Load()
    Me.RibbonName = RibbonNameZaIzabranuFormuIUsera(Me.Name)
End Sub

Private Sub Form_Open(Cancel As Integer)
' On Error Resume Next
    
    PrikaziAPPRev
    
    'BBPravaPristupa.BB_PravaPristupaPodesiFormu Me
        
    If Zastita.Zasticen Then
        'DoCmd.Quit
        QuitBigBit
    End If
    
   
    DoCmd.Maximize
    
    ProveriInboxPlanera
   
   'If F_PrebaciKomitenteIzEXTBaze() Then
   '     Me!DugmePreuziIzBB.Visible = True
   'Else
   '     Me!DugmePreuziIzBB.Visible = False
   'End If
   
    'If Nz(ReadParametar("CFG_Global", "Planer_Start"), False) Then
    ' If Planer.BrojNeobradjenihPoruka > 0 Then
    '    BBOpenForm "PlanerPopUp"
    ' End If
    'End If
   
End Sub


Private Sub Form_Unload(Cancel As Integer)
    'fp_ClosePort False
End Sub
