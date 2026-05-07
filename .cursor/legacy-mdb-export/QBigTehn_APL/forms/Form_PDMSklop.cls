VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PDMSklop"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Public Function PrikaziCrtezIReference(Optional parIDCrtez)
On Error GoTo Err_Point

 Dim pIDCrtezZaPrikaz As Long
 Dim retValOk As Boolean
 Dim PodFrmSklop As Form
 Dim PodFrmB As Form
    
 retValOk = True
 
 Set PDMSklop = Nothing
 
 If Not IsMissing(parIDCrtez) Then
    pIDCrtezZaPrikaz = parIDCrtez
 Else
    pIDCrtezZaPrikaz = Me!IDCrtez
 End If
    
    PDMSklop.IDCrtez = pIDCrtezZaPrikaz
    Me!IDCrtezZaPrikaz = PDMSklop.IDCrtez()
    
    retValOk = SetProperlyRecordSource(BBCFG.CNNString, Me)
    
    On Error Resume Next
    Forms("PDMSklop").Controls("PodFrmB").SourceObject = "Form.PDMSklopReference"

    
    On Error GoTo 0
    
Exit_Point:
On Error Resume Next
   PrikaziCrtezIReference = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PrikaziCrtezIReference"
 retValOk = False
 Resume Exit_Point
End Function

Private Sub Form_Open(Cancel As Integer)
On Error GoTo Err_Point

Dim stFilter As String
   
   If Nz(Me.OpenArgs, "") = "Nabavka" Then
       Me!CheckNabavka = True
       OvoJeNabavka
    Else
       Me!CheckNabavka = False
       OvoJeProizvodnja
    End If
    
    If Me.FilterOn Then
        stFilter = Nz(Me.Filter)
        stFilter = Replace(stFilter, " ", "")
        stFilter = Replace(stFilter, "[IDCrtez]=", "")
        If IsNumeric(stFilter) Then
            Me!IDCrtezZaPrikaz = CLng(stFilter)
        Else
            Me!IDCrtezZaPrikaz = PoslednjiIDCrtez
        End If
    Else
        If PDMSklop.Caller = "DetaljnoCrtez" Then
         Me!IDCrtezZaPrikaz = PDMSklop.IDCrtez
        Else
         Me!IDCrtezZaPrikaz = PoslednjiIDCrtez()
        End If
    End If
  
    PrikaziCrtezIReference Me!IDCrtezZaPrikaz
    
    DoCmd.GoToControl "PDMCrtezTrazi"
   
 
 Exit Sub
Err_Point:
  BBErrorMSG err, "Form_Open"
  Resume Next
End Sub

Private Sub Form_Unload(Cancel As Integer)
    CloseConnectionOnCurrentForm Me
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
Private Sub PDMCrtezTrazi_AfterUpdate()
    Call PrikaziCrtezIReference(Me!PDMCrtezTrazi)
    Me![PDMCrtezTrazi] = Null
    Exit Sub
End Sub


Private Sub PrikaziAPPRev()
  'Me!BBAppRev.Caption = F_APPRev()
  Me!TrenutniUser = CurrentUser() & " (" & Environ("UserName") & ")"
  'Me!LabelWinUser.Caption = Environ("UserName")
End Sub
Private Sub PostaviStatusnuLiniju()
    'Me!NazivAktivneKT = CCKZaSve.NazivAktivneKT
   ' Me!AktivanKorisnik = CurrentUser()
End Sub

Private Sub PDMCrtezTrazi_GotFocus()
    Me!PDMCrtezTrazi.Requery
End Sub

Private Function PrviIDCrtez() As Long
On Error GoTo Err_Point
 Dim retVal
 retVal = DMin("[IDCrtez]", "PDMCrtezi", STDWhere())
 retVal = CLng(Nz(retVal, 0))
 
Exit_Point:
 On Error Resume Next
 PrviIDCrtez = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "PrviIDCrtez"
 retVal = 0
 Resume Exit_Point
End Function
Private Function STDWhere() As String
Dim stWhere As String
 stWhere = "( ([PDMCrtezi].IDStatusCrteza Between 0 And 1) AND ([PDMCrtezi].Nabavka= [Forms]![PDMSklop]![CheckNabavka]) )"
 STDWhere = stWhere
 
End Function
Private Function PoslednjiIDCrtez() As Long
On Error GoTo Err_Point
 Dim retVal
 Dim stWhere As String
 
 stWhere = STDWhere()
 retVal = DMax("[IDCrtez]", "PDMCrtezi", stWhere)
 retVal = CLng(Nz(retVal, 0))
 
Exit_Point:
 On Error Resume Next
 PoslednjiIDCrtez = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "PoslednjiIDCrtez"
 retVal = 0
 Resume Exit_Point
End Function
Private Function PrethodniIDCrtez() As Long
On Error GoTo Err_Point
 Dim retVal
 Dim stWhere As String
 
 stWhere = STDWhere() & " AND [IDCrtez]<" & Me!IDCrtezZaPrikaz
 If Not IsNumeric(Me!IDCrtezZaPrikaz) Or IsEmpty(Me!IDCrtezZaPrikaz) Then
  retVal = PoslednjiIDCrtez
 Else
  retVal = DMax("[IDCrtez]", "PDMCrtezi", stWhere)
  retVal = CLng(Nz(retVal, 0))
 End If
 
 If retVal = 0 Then
    retVal = PrviIDCrtez()
 End If

Exit_Point:
 On Error Resume Next
 PrethodniIDCrtez = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "PoslednjiIDCrtez"
 retVal = 0
 Resume Exit_Point
End Function
Private Function SledeciIDCrtez() As Long
On Error GoTo Err_Point
 Dim retVal
 
 If Not IsNumeric(Me!IDCrtezZaPrikaz) Or IsEmpty(Me!IDCrtezZaPrikaz) Then
  retVal = PoslednjiIDCrtez
 Else
  retVal = DMin("[IDCrtez]", "PDMCrtezi", STDWhere() & " AND [IDCrtez]>" & Me!IDCrtezZaPrikaz)
  retVal = CLng(Nz(retVal, 0))
 End If
 
 If retVal = 0 Then
    retVal = PoslednjiIDCrtez()
 End If
 
Exit_Point:
 On Error Resume Next
 SledeciIDCrtez = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "SledeciIDCrtez"
 retVal = 0
 Resume Exit_Point
End Function

Private Sub OvoJeNabavka()
On Error GoTo Err_Point

        Me!lblNazivForme.Caption = "Gotov deo"
        Me.Caption = "Nabavka"
        
        Me!BoxZag.BackColor = RGB(237, 247, 249)
        
        Me!CheckNabavka.DefaultValue = True
        Me!CheckNabavka.Enabled = False
        
        Me!BoxImport.Visible = False
        Me!ImportIzFajla.Visible = False
        Me!DugmeUveziPDM_XML.Visible = False
        Me!BoxPrimopredaja.Visible = False
        Me!LabelRadniNalog.Visible = False
        Me!LabelKomitent.Visible = False
        Me!LabelBrojKomadaZaProizvodnju.Visible = False
        Me!DugmeIzvrsiPrimopredaju.Visible = False
        Me!PrimopredajaIDRN.Visible = False
        Me!PrimopredajaKomitent.Visible = False
        Me!PrimopredajaBrojKomada.Visible = False
        
Exit_Point:
On Error Resume Next

Exit Sub

Err_Point:
   MsgBox err.Description
   Resume Next
End Sub

Private Sub OvoJeProizvodnja()
On Error GoTo Err_Point
    Me!lblNazivForme.Caption = "PDM Sklop"
    Me.Caption = "PDM Sklop"
    Me!BoxZag.BackColor = RGB(153, 204, 255)
    
    Me!CheckNabavka.DefaultValue = False
    Me!CheckNabavka.Enabled = False
     
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "OvoJeFaktura"
 Resume Next
End Sub


