VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BazeITabele"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub ComboBaza_AfterUpdate()
' Find the record that matches the control.
    
    Me.RecordsetClone.FindFirst "[IDBaze] = " & Me![ComboBaza]
    Me.Bookmark = Me.RecordsetClone.Bookmark
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
Private Sub DugmeIzaberiBazu_Click()
On Error GoTo Err_IzaberiBazu_Click

    Dim ImeBaze As Variant
    
    ImeBaze = IzaberiBazu()
    If Not IsNull(ImeBaze) Then
        Me!Baza = ImeBaze
        Me!ComboBaza.Requery
    End If
                                 
    

Exit_IzaberiBazu_Click:
    Exit Sub

Err_IzaberiBazu_Click:
    MsgBox err.Description
    Resume Exit_IzaberiBazu_Click
    
End Sub

Private Sub Form_Current()
    Me!ComboBaza = Me!IDBaze
End Sub

Private Sub Form_Open(Cancel As Integer)
    DoCmd.Maximize
End Sub

Private Sub DugmeCheckLink_Click()
On Error GoTo Err_DugmeCheckLink_Click

    Dim stDocName As String
  
    'stDocName = "Baze_CheckLink_PonistiUTabelama"
    'DoCmd.OpenQuery stDocName, acNormal, acEdit
     CheckLinkPonistZaIDBaze Me!IDBaze
     
    DoCmd.SetWarnings False
    ProveriLinkoveSaBazomZaIDBaze Me![IDBaze]
    
    Me![BazeITabele-Podforma].Requery
    MsgBox "Provera linkova je uspesno zavrsena."
    
Exit_DugmeCheckLink_Click:
    DoCmd.SetWarnings True
    Exit Sub

Err_DugmeCheckLink_Click:
    MsgBox err.Description
    MsgBox "Provera linkova nije uspela."
    Resume Exit_DugmeCheckLink_Click
    
End Sub
Private Sub DugmeForsirajLinkove_Click()
On Error GoTo Err_DugmeForsirajLinkove_Click

    Dim stDocName As String
    Dim varRet As Variant
    Dim YesToAll As Boolean

   ' DoCmd.SetWarnings False
   ' stDocName = "Baze_CheckLink_PonistiUTabelama"
   ' DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    CheckLinkPonistZaIDBaze Me!IDBaze
    
   ' varRet = ForsirajNoveLinkove(Me![Baza])
     YesToAll = Not BBPitanje("Da li da pitam za svaku tabelu posebno?")
     varRet = ForsirajNoveLinkoveZaIDBaze(Me!IDBaze, Me!ComboBaza.Column(1), YesToAll)
    Me![BazeITabele-Podforma].Requery
    If varRet Then
     MsgBox "Forsiranje linkova je uspešno završeno.", , "QMegaTeh"
    Else
     MsgBox "Forsiranje linkova nije uspešno završeno.", vbExclamation, "QMegaTeh"
    End If
    
Exit_DugmeForsirajLinkove_Click:
    DoCmd.SetWarnings True
    Exit Sub

Err_DugmeForsirajLinkove_Click:
    MsgBox err.Description
    MsgBox "Forsiranje linkova nije uspelo!"
    Resume Exit_DugmeForsirajLinkove_Click
    
End Sub
Private Sub DugmeProveriSveLinkove_Click()
On Error GoTo Err_DugmeProveriSveLinkove_Click

    Dim stDocName As String

    DoCmd.SetWarnings False
    stDocName = "Baze_CheckLink_PonistiUTabelama"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    ProveriSveLinkove
    
    Me![BazeITabele-Podforma].Requery
    MsgBox "Provera svih definisanih linkova je uspesno zavrsena."

Exit_DugmeProveriSveLinkove_Click:
    DoCmd.SetWarnings True
    Exit Sub

Err_DugmeProveriSveLinkove_Click:
    MsgBox err.Description
    MsgBox "Provera svih linkova nije uspela.", vbCritical + vbOKOnly
    Resume Exit_DugmeProveriSveLinkove_Click
    
End Sub
Private Sub DugmeForsirajSveLinkove_Click()
On Error GoTo Err_DugmeForsirajSveLinkove_Click

    Dim stDocName As String

    DoCmd.SetWarnings False
    stDocName = "Baze_CheckLink_PonistiUTabelama"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    ForsirajSveLinkoveUSvimBazama
    
    Me![BazeITabele-Podforma].Requery
    MsgBox "Forsiranje svih definisanih linkova je uspešno završeno.", , "QMegaTeh"

Exit_DugmeForsirajSveLinkove_Click:
    DoCmd.SetWarnings True
    Exit Sub

Err_DugmeForsirajSveLinkove_Click:
    MsgBox err.Description
    MsgBox "Forsiranje svih linkova nije uspelo.", vbCritical + vbOKOnly
    Resume Exit_DugmeForsirajSveLinkove_Click
    
End Sub

Private Sub DugmeAlati_Click()
On Error GoTo Err_DugmeAlati_Click

    Dim stDocName As String
    Dim stLinkCriteria As String

    stDocName = "Alati"
    BBOpenForm stDocName, , , stLinkCriteria, , , Me!Baza

Exit_DugmeAlati_Click:
    Exit Sub

Err_DugmeAlati_Click:
    MsgBox err.Description
    Resume Exit_DugmeAlati_Click
    
End Sub
Private Sub DugmeRefreshLinkZaIzabranuBazu_Click()
On Error GoTo Err_DugmeRefreshLinkZaIzabranuBazu_Click

    Dim OK As Boolean

    OK = RefreshujLinkoveZaIDBaze(Me!IDBaze)
    If OK Then
     MsgBox "Refresh završen Ok", vbInformation, "QMegaTeh"
    End If
    
Exit_DugmeRefreshLinkZaIzabranuBazu_Clic:
    Exit Sub

Err_DugmeRefreshLinkZaIzabranuBazu_Click:
    MsgBox err.Description
    Resume Exit_DugmeRefreshLinkZaIzabranuBazu_Clic
    
End Sub
Private Sub DugmeObrisiSadrzajSvihTabelaZaTip_Click()
On Error GoTo Err_DugmeObrisiSadrzajSvihTabelaZaTip_Click
 Dim retValOk As Boolean
 
 If Nz(Me!TipBaze, "" <> "") Then
  If BBPitanje("Da li ste 100% sigurni?") Then
    retValOk = ObrisiSadrzajSvihTabelaUBaziZaTip(Me!TipBaze)
  End If
 End If
Exit_DugmeObrisiSadrzajSvihTabelaZaTip_C:
    Exit Sub

Err_DugmeObrisiSadrzajSvihTabelaZaTip_Click:
    MsgBox err.Description
    Resume Exit_DugmeObrisiSadrzajSvihTabelaZaTip_C
    
End Sub
