VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_MRP_Pregled"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit


Private Sub DugmeStop_Click()
    DoCmd.Close
End Sub

Private Sub Form_Load()
    Me.lblLagerAzuriran.Caption = GetMRPSyncInfo()
End Sub

Private Sub Form_Open(Cancel As Integer)
    PrikaziAPPRev
    Me!FilterObradjeni = Null
    'SetujPrikaziSve False
    'SetujDetaljnoMRPPotreba False
    
End Sub
Private Sub PrikaziAPPRev()
  Me!TrenutniUser = CurrentUser() & " (" & Environ("UserName") & ")"
  'Me!LabelWinUser.Caption = Environ("UserName")
End Sub
Public Function PrimeniUslove()
On Error GoTo Err_PrimeniUslove
   If BBCFG.SQLDB Then
     Me!Podforma.SourceObject = "ReklamniPanel"
   End If
   
   TabIzbor_Change
   
Exit_PrimeniUslove:
    Exit Function
TrebaPrimenitiUslove vbBlack
Err_PrimeniUslove:
    MsgBox err.Description
    Resume Exit_PrimeniUslove
    
End Function
Private Function ClearCurrentVal()
   Screen.ActiveControl.Value = Null
   PrimeniUslove
End Function
Private Sub FrameIzbor_AfterUpdate()
    SetujRealizacijaMRPPotreba False
    If Me!FrameIzbor = 1 Then
        Me!Podforma.SourceObject = "MRP_PregledSaZalihama"
    ElseIf Me!FrameIzbor = 2 Then
        Me!Podforma.SourceObject = "MRP_PregledPoDobavljacima"
        'SetujPrikaziSve True
        Exit Sub
    ElseIf Me!FrameIzbor = 3 Then
        Me!Podforma.SourceObject = "MRP_PregledSamoNabavku"
     ElseIf Me!FrameIzbor = 4 Then
        Me!Podforma.SourceObject = "MRP_PregledRezervisano"
    Else
        Me!Podforma.SourceObject = "ReklamniPanel"
    End If
 'TrebaPrimenitiUslove vbBlack
    'SetujPrikaziSve False

End Sub
Private Function TrebaPrimenitiUslove(Optional boolYesNo) As Boolean
Dim retVal As Boolean

If Not IsMissing(boolYesNo) Then
    If CBool(boolYesNo) Then
       Me!DugmePrimeniUslove.ForeColor = vbRed
    Else
       Me!DugmePrimeniUslove.ForeColor = vbBlack
    End If
End If
  retVal = (Me!DugmePrimeniUslove.ForeColor = vbRed)
  TrebaPrimenitiUslove = retVal
End Function


Private Function SetujRealizacijaMRPPotreba(ByVal Prikazi As Boolean) As Boolean
    
    Me!labelFilterObradjeni.Visible = Prikazi
    Me!FilterObradjeni.Visible = Prikazi
End Function
Private Sub cmdAzurirajLager_Click()
On Error GoTo Err_Point

    DoCmd.Hourglass True

    ' 1. Napuni TMP (Access › SQL)
    If Not NapuniTMP_MRP_Stanje() Then
        MsgBox "Greška pri punjenju TMP tabele.", vbCritical
        GoTo Exit_Point
    End If

    ' 2. Sync u glavnu tabelu
    'ADO_ExecSQL CNN_CurrentDataBase, "EXEC dbo.spMRP_SyncStanjeArtikala '" & CurrentUser() & "'"
    If ADO_ExecSP(CNN_CurrentDataBase, "spMRP_SyncStanjeArtikala", CurrentUser()) Then
        
        Call ADO_ExecSP(CNN_CurrentDataBase, "spMRP_SetStatus", "Lager", CurrentUser())
        ' 3. Osveži prikaz
        PrimeniUslove
        ' 4. Osveži info o vremenu sync-a
        Me.lblLagerAzuriran.Caption = GetMRPSyncInfo()
        MsgBox "Lager je uspešno ažuriran.", vbInformation
    Else
        MsgBox "Lager NIJE uspešno ažuriran.", vbInformation
    End If
    
Exit_Point:
    DoCmd.Hourglass False
    Exit Sub

Err_Point:
    BBErrorMSG err, "cmdAzurirajLager_Click"
    Resume Exit_Point

End Sub


Private Sub FrameRealizacija_AfterUpdate()
    SetujRealizacijaMRPPotreba True
    If Me!FrameRealizacija = 1 Then
        Me!FilterObradjeni = False
        Me!FilterObradjeni.Visible = False
        Me!labelFilterObradjeni.Visible = False
        Me!Podforma.SourceObject = "MRP_DetaljanPregledSaZalihama"
    ElseIf Me!FrameRealizacija = 2 Then
        Me!FilterObradjeni = Null
        Me!FilterObradjeni.Visible = False
        Me!labelFilterObradjeni.Visible = False
        Me!Podforma.SourceObject = "MRP_DetaljanPregledSvihMRPPotreba"
    ElseIf Me!FrameRealizacija = 3 Then
        Me!FilterObradjeni = True
        Me!FilterObradjeni.Visible = False
        Me!labelFilterObradjeni.Visible = False
        Me!Podforma.SourceObject = "MRP_DetaljanPregledSvihMRPPotreba"
    Else
        Me!Podforma.SourceObject = "ReklamniPanel"
    End If
 'TrebaPrimenitiUslove vbBlack
    'SetujPrikaziSve False

End Sub

Private Sub TabIzbor_Change()
    If Me!TabIzbor = 0 Then
        FrameRealizacija_AfterUpdate
    ElseIf Me!TabIzbor = 1 Then
        FrameIzbor_AfterUpdate
    Else
    
    End If
End Sub

