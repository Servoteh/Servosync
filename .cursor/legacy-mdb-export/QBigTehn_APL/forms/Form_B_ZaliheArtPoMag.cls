VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_B_ZaliheArtPoMag"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PripremiPodatkeUzPitanje()
 Dim TimerStart As Single
 Dim TimerEnd As Single
 Dim stTrajanje As String
 Dim OK As Boolean
 
 If BBPitanje("Da li želite da preraèunam zalihe?") Then
    TimerStart = Timer
     PripremiPodatke
    TimerEnd = Timer
    stTrajanje = "Priprema je trajala " & Format(TimerEnd - TimerStart, "###0.00000") & " sec."
    BBMsgBox "Podaci su pripremljeni." & vbCrLf & vbCrLf & stTrajanje, 2
 End If
End Function
Public Function PripremiPodatke()
 Dim OK As Boolean
     Me!B_ZaliheArtPoMagPodforma.Visible = False
     Me!B_ZaliheArtPoMagPodforma.Form.RecordSource = ""
     OK = PripremiTMPTabeluUTMPBazi("tmp_B_ZaliheArtPoMagIProd", "B_ZaliheArtPoMagIProd", , True, , "IDObjekat", "IDArtikal")
     Me!B_ZaliheArtPoMagPodforma.Form.RecordSource = "tmp_B_ZaliheArtPoMagIProd"
     Me!B_ZaliheArtPoMagPodforma.Visible = True
  PripremiPodatke = OK
End Function
Private Function PrikaziArtikalZaPrikaz()
 Me!B_ZaliheArtPoMagPodforma.Visible = False
 Me.Filter = ("[Sifra artikla] = " & stR(Nz(Me!IDArtikalZaPrikaz, 0)))
 Me.FilterOn = True
 Me!B_ZaliheArtPoMagPodforma.Visible = True
End Function

Private Sub ComboBarKod_AfterUpdate()
 Me!IDArtikalZaPrikaz = Me!ComboBarKod
 Me![ComboBarKod] = Null
 PrikaziArtikalZaPrikaz
End Sub
Private Sub ComboKatBroj_AfterUpdate()

Me!IDArtikalZaPrikaz = Me!ComboKatBroj
Me![ComboKatBroj] = Null
PrikaziArtikalZaPrikaz

Exit Sub
'**************************************************
    ' Find the record that matches the control.
    Dim rs As Object
    
    Set rs = Me.Recordset.Clone
    rs.FindFirst "[Sifra artikla] = " & stR(Nz(Me![ComboKatBroj], 0))
    If Not rs.EOF Then Me.Bookmark = rs.Bookmark
    Me![ComboKatBroj] = Null
    Me!IDArtikalZaPrikaz = Me![Sifra artikla]
'**************************************************
End Sub

Private Sub ComboNazivArtikla_AfterUpdate()

 Me!IDArtikalZaPrikaz = Me!ComboNazivArtikla
 Me!ComboNazivArtikla = Null
 PrikaziArtikalZaPrikaz

End Sub

Private Sub ComboNazivArtikla_NotInList(NewData As String, Response As Integer)
    NazivArtiklaNijeUListi Me!ComboNazivArtikla, NewData, Response, Me!MPCenovnik
End Sub
Private Sub Form_Open(Cancel As Integer)
    
    
    Me!VPDoLevel.DefaultValue = Nz(ReadParametar("CFG_Global", "VPLevelZalihe"), F_NivoBaze())
    
    DoCmd.GoToControl "ComboKatBroj"
    Rem Call BB_PravaPristupaPodesiFormu(Me)
    
    PripremiPodatke
    
    DoCmd.GoToControl "ComboKatBroj"
    'DoCmd.MoveSize , , 5720
    'PrikaziArtikalZaPrikaz   'preneto na OnLoad
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




Private Sub DugmeZalihePoObj_Click()
On Error GoTo Err_DugmeZalihePoObj_Click

    Dim stDocName As String
    Dim ImeForme As String
    ImeForme = Me.Name
    
    DoCmd.Minimize
    
    stDocName = "B_ZaliheArtPoMagIProd_CT"
    DoCmd.OpenQuery stDocName, acNormal, acReadOnly
    
    DoCmd.Close acForm, ImeForme, acSavePrompt
Exit_DugmeZalihePoObj_Click:
    Exit Sub

Err_DugmeZalihePoObj_Click:
    MsgBox err.Description
    Resume Exit_DugmeZalihePoObj_Click
    
End Sub
