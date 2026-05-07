VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBMail_ZaNabavku"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
 
Private ImefajlaPDF As String
Private ImeFajlaXLS As String

Private ImeDir As String
Private CistoImeFajla As String
Private stDocName
Private EmailClass As New Email_Class
'Dim WithEvents oSMTP As OSSMTP.SMTPSession
Private WithEvents objMailer As OSSMTP.SMTPSession
Attribute objMailer.VB_VarHelpID = -1

Private Function CreateAttachments() As String
' Modifikovano: 20-02-2022
On Error GoTo Err_Point
  Dim OK As Boolean
  'Dim rstDef As QueryDef
  'Dim rst As DAO.Recordset
  Dim stMsg As String
  'Dim ImeUpita As String
  Dim stRetVal As String
  
    'stDocName = "Faktura - DEFAULT"
    stDocName = "SpecifikacijaZaNabavku"
    'ImeUpita = ""
    ImeDir = Me!ImeDirZaAtt
    
    CistoImeFajla = "Specifikacija_" & Me!BrojPredmeta
    CistoImeFajla = PopraviCistoImeFajla(ZameniNasaSlova(CistoImeFajla))
    
    'Set rstDef = CurrentDb.QueryDefs(ImeUpita)
    'rstDef.Parameters(0) = Me!IDDok
    'Set rst = rstDef.OpenRecordset(dbOpenDynaset, dbSeeChanges)
    stRetVal = ""
    If Me!CheckPDF Then
        ImefajlaPDF = ImeDir & CistoImeFajla & ".PDF"
        On Error Resume Next
        DoCmd.OutputTo acOutputReport, stDocName, acFormatPDF, ImefajlaPDF
        If err Then
         MsgBox "PDF fajl nije uspešno kreiran i nece se pojaviti u attachmentu e-maila!", vbExclamation, "BigBit"
         ImefajlaPDF = ""
         err.Clear
         On Error GoTo Err_Point
        End If
    End If
    
    If Me!CheckXLS Then
        ImeFajlaXLS = ImeDir & CistoImeFajla & ".XLS"
        'DoCmd.OutputTo acOutputQuery, ImeUpita, acFormatXLS, ImeFajlaXLS
    End If
    
  
    
Exit_Point:
    On Error Resume Next
    CreateAttachments = ImefajlaPDF
    'Set rstDef = Nothing
    'rst.Close
    'Set rst = Nothing
Exit Function

Err_Point:
    MsgBox err.Description, vbExclamation, "BigBit"
    Resume Exit_Point
End Function

Private Sub CheckAllAttach_AfterUpdate()
    Me!CheckPDF = Me!CheckAllAttach
    Me!CheckXLS = Me!CheckAllAttach
    Me!CheckCleanUp = Me!CheckAllAttach
End Sub

Private Sub DugmeCreateAttachments_Click()
    CreateAttachments
End Sub



Private Sub DugmePosaljiMail_Click()
On Error GoTo Err_DugmePosaljiMail_Click
   
    Dim OK As Boolean
    OK = True
    Dim stPutanjaFajla() As Variant
    'Set EmailClass = Nothing
    Dim i As Integer
    ReDim stPutanjaFajla(lstAttachments.ListCount)
    For i = 0 To lstAttachments.ListCount - 1
      stPutanjaFajla(i) = CStr(lstAttachments.Column(0, i))
    Next
    
    'Ok = CreateEmailWithOutlook(Nz(Me!Email, ""), "", "", Nz(Me!Subject, ""), Nz(Me!MessageBody, ""), ImefajlaPDF, ImeFajlaXLS, ImeFajlaCSV, ImeFajlaXML, ImeFajlaSNP, ImeFajlaXPS)
    OK = OK And SendAnEmail(EmailClass, Nz(Me!Email, ""), Nz(Me!Cc, ""), Nz(Me!Bcc, ""), Nz(Me!ReplayToAddress, ""), _
                            Nz(Me!Subject, ""), Nz(Me!MessageBody, ""), stPutanjaFajla())
    
Exit_DugmePosaljiMail_Click:
    On Error Resume Next
    If OK Then
        MsgBox "Služba nabavke je upoznata sa specifikacijom za nabavku"
    Else
        MsgBox "Mail NIJE  prosleðen službi nabavke"
    End If
    'DoCmd.Close
    Exit Sub

Err_DugmePosaljiMail_Click:
    MsgBox err.Description, vbExclamation, "BigBit"
    OK = False
    Resume Exit_DugmePosaljiMail_Click
    
End Sub
Private Function DefaultFolderZaAtt() As String
 Dim stRetVal As String
 
 stRetVal = Nz(BazaZaTip("BB_EXPORT"), Environ("TMP") & "\")
 If Nz(stRetVal, "-") = "-" Then
   stRetVal = Environ("TMP") & "\"
 End If
 If Not DirExists(stRetVal) Then
   stRetVal = Environ("UserProfile") & "\"
 End If
 
 DefaultFolderZaAtt = stRetVal
End Function

Private Function DefaultSubject() As String
On Error Resume Next
 Dim stRetVal
  'stRetVal = "Kupac: " & Me![Naziv] & " " & Me![Vrsta dokumenta] & ": " & Me![Broj dokumenta] & " ID: " & Me![IDDok]
  stRetVal = Me![Broj dokumenta] & " (ID = " & Me![IDDok] & ")"
  DefaultSubject = stRetVal
End Function
Private Sub PrimeniUslove()
On Error GoTo Err_Point
        
    'Set EmailClass = Nothing
   
     Me.Requery
     Me!Subject = DefaultSpecifikacijaNabavkeSubject(Me!BrojPredmeta, Me!BrojZahteva)
     Me!MessageBody = DefaultSpecifikacijaNabavkeMessageBody(Me!InicijatorZahteva, Me!RokZaZavrsetak, Nz(Me!Opis, ""), Nz(Me!Napomena, ""))
     Me!ImeDirZaAtt = DefaultFolderZaAtt()
     Me!From = EmailClass.FromEmail
     'Me!ReplayToAddress = EmailClass.ReplyToAddress
     Me!Email = EmailClass.EmailSluzbeNabavka
     
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "PrimeniUslove"
 Resume Exit_Point
End Sub
Private Sub DugmePrikaziPrilog_Click()
    PrikaziPrilog
End Sub


Private Sub Email_DblClick(Cancel As Integer)
     Me!Email.Locked = False
End Sub



Private Sub Form_Close()
On Error Resume Next

 If Me!CheckCleanUp Then
     Kill ImefajlaPDF
     Kill ImeFajlaXLS
 End If
End Sub

Private Sub Form_Load()
    Set objMailer = New OSSMTP.SMTPSession
End Sub

Private Sub Form_Open(Cancel As Integer)
    PrimeniUslove
    lstAttachments.AddItem CreateAttachments
End Sub

Private Sub Form_Unload(Cancel As Integer)
    Set objMailer = Nothing
End Sub

Private Sub From_AfterUpdate()
    If EmailClass.FromEmail = Me!From Then
    Else
        EmailClass.FromEmail = Me!From
    End If
End Sub

Private Sub ImeDirZaAtt_AfterUpdate()
 If Not FileExists(Me!ImeDirZaAtt) Then
  MsgBox "Ne postoji folder!", vbCritical, "BigBit"
  Me!ImeDirZaAtt = DefaultFolderZaAtt()
 End If
End Sub

Private Sub ImeDirZaAtt_DblClick(Cancel As Integer)
 Dim IzabraniFolder
 IzabraniFolder = Me!ImeDirZaAtt
 
 IzabraniFolder = OpenFolder(IzabraniFolder)
 If Nz(IzabraniFolder, "") <> "" Then
  Me!ImeDirZaAtt = IzabraniFolder
 End If
End Sub



Private Sub ZaIDDok_AfterUpdate()
 If Not IsNumeric(Me!ZaIDDok) Then
  MsgBox "Nekorektna vrednost!", vbCritical, "BigBit"
  Me!ZaIDDok = Me!ZaIDDok.OldValue
 End If
  PrimeniUslove
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

Private Sub ZaIDDok_DblClick(Cancel As Integer)
If UserUGrupi(CurrentUser(), "PowerfulUsers") Then
   'Me!ZaIDDok.BackColor = AcColorIndex.acColorIndexWhite
   Me!ZaIDDok.BackColor = ColorConstants.vbWhite
   Me!ZaIDDok.Locked = False
End If
End Sub

Private Function UkloniNavodnike(ByVal st As String) As String
    Dim i As Integer
    Dim retVal As String
    retVal = ""
    For i = 1 To Len(st)
      If Mid(st, i, 1) <> Chr(34) Then
        retVal = retVal & Mid$(st, i, 1)
      End If
    Next i
  UkloniNavodnike = retVal
End Function
Private Sub PrikaziPrilog()
On Error GoTo Err_DugmeRecalc_Click
    Dim retValOk As Boolean
    
    retValOk = True
    
    If lstAttachments.ListIndex > -1 Then
        If FileExists(lstAttachments.Value) Then
            RunIt (lstAttachments.Value)
        Else
            MsgBox "Ne postoji fajl koji je selektovan u list priloga", vbInformation
        End If
    Else
        MsgBox "Niste selektovali koji prilog želite da vidite", vbInformation
    End If
    
Exit_DugmeRecalc_Click:
    Exit Sub

Err_DugmeRecalc_Click:
    MsgBox err.Description
    Resume Exit_DugmeRecalc_Click

End Sub
Public Function DodajFajlaKaoPrilog() As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim fajlLink As String
        
    retValOk = True
    
    fajlLink = Nz(OpenFileDialog("Izaberite fajl", ""), "")
    
    If FileExists(fajlLink) Then
        lstAttachments.AddItem fajlLink
    End If
    
Exit_Point:
    On Error Resume Next
    DodajFajlaKaoPrilog = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "DodajFajlaKaoPrilog"
    retValOk = False
    Resume Exit_Point

End Function


Private Function SendAnEmail(ByRef clasEmal As Email_Class, ByVal strRecipients As String, ByVal strCC As String, ByVal strBCC As String, strReplyToAddress As String, _
                            ByVal strSubject As String, ByVal strMessage As String, ByRef strAttachments() As Variant) As Boolean
On Error GoTo Err_Point
    
    Dim retValOk As Boolean
    retValOk = True
    'Set objMailer = New clsSendMail
    Set objMailer = New OSSMTP.SMTPSession
    objMailer.Server = clasEmal.SMTPhost
    objMailer.AuthenticationType = OSSMTP.authentication_type.AuthLogin
    objMailer.UserName = clasEmal.EmailAcct 'strEmailAcct
    objMailer.Password = clasEmal.EmailAcctPwd 'strEmailAcctPwd
    'objMailer.MaxRecipients = 4000
    
    objMailer.MailFrom = clasEmal.FromEmail 'strFromEmail ' sa koje adrese se šalje mail
    'objMailer.FromDisplayName = clasEmal.FromDisplayName
    'objMailer.Delimiter = ","
    objMailer.SendTo = strRecipients
    objMailer.Cc = strCC
    objMailer.Bcc = strBCC
    
    objMailer.ReplyTo = strReplyToAddress
    
    objMailer.MessageSubject = strSubject
    objMailer.MessageText = strMessage
        
    'objMailer.Attachments = strAttachments
    Dim i As Integer
    i = UBound(strAttachments())
    For i = 0 To i - 1 'lstAttachments.ListCount - 1
      objMailer.Attachments.Add (CStr(strAttachments(i))) '(CStr(lstAttachments.Column(0, i)))
      Debug.Print CStr(strAttachments(i))
    Next
       
    txtStatus.SetFocus
    objMailer.SendEmail
   
  
Exit_Point:
    On Error Resume Next
    'objMailer.Disconnect
    Set objMailer = Nothing
    SendAnEmail = retValOk
    
Exit Function

Err_Point:
    'BErrorMSG Err, "NazivFunkcije"
    MsgBox "Message from SendAnEmail" & vbCrLf & vbCrLf & "Unable to send an email." & vbCrLf & vbCrLf & "Error " & err.Number & ". " & err.Description, vbExclamation
    retValOk = False
    Resume Exit_Point

End Function

Private Sub objMailer_ErrorSMTP(ByVal Number As Integer, Description As String)
  txtStatus = txtStatus & "Error " & Number & ": " & Description & vbCrLf
  txtStatus.selstart = Len(txtStatus)
End Sub

Private Sub objMailer_StatusChanged(ByVal Status As String)
  txtStatus = txtStatus & objMailer.Status & vbCrLf
  'Debug.Print objMailer.Status
  txtStatus.selstart = Len(txtStatus)
End Sub

Private Sub DugmeDodajPrilog_Click()
    DodajFajlaKaoPrilog
End Sub

Private Sub DugmeObrisiPrilog_Click()
    If BBPitanje("Ovim izbacujete selektovani prilog iz maila." & "Da li nastavljate akciju?") Then
        If lstAttachments.ListIndex > -1 Then lstAttachments.RemoveItem lstAttachments.ListIndex
    End If
End Sub

