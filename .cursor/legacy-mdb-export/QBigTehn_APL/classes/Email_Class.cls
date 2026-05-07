VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Email_Class"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private pEmailAcct As String  ' SMTPUserName
Private pEmailAcctPwd As String
Private pFromEmail As String
Private pFromDisplayName As String
Private pSMTPhost As String
Private pSMTPport As Integer
Private pReplyToAddress As String
Private pEmailSluzbeNabavka As String
Private pKorisnikAplikacije As String
Public Property Get SMTPhost() As String
    SMTPhost = pSMTPhost
End Property
Public Property Let SMTPhost(ByVal vNewValue As String)
    pSMTPhost = vNewValue
End Property
Public Property Get SMTPport() As Integer
    SMTPport = pSMTPport
End Property
Public Property Let SMTPport(ByVal vNewValue As Integer)
    pSMTPport = vNewValue
End Property
Public Property Get EmailAcct() As String
    EmailAcct = pEmailAcct
End Property
Public Property Let EmailAcct(ByVal vNewValue As String)
    pEmailAcct = vNewValue
End Property
Public Property Get EmailAcctPwd() As String
    EmailAcctPwd = pEmailAcctPwd
End Property
Public Property Let EmailAcctPwd(ByVal vNewValue As String)
    pEmailAcctPwd = vNewValue
End Property
Public Property Get FromEmail() As String
    FromEmail = pFromEmail
End Property
Public Property Let FromEmail(ByVal vNewValue As String)
    pFromEmail = vNewValue
End Property
Public Property Get FromDisplayName() As String
    FromDisplayName = pFromDisplayName
End Property
Public Property Let FromDisplayName(ByVal vNewValue As String)
    pFromDisplayName = vNewValue
End Property
Public Property Get ReplyToAddress() As String
    ReplyToAddress = pReplyToAddress
End Property
Public Property Let ReplyToAddress(ByVal vNewValue As String)
    pReplyToAddress = vNewValue
End Property
Public Property Get EmailSluzbeNabavka() As String
    EmailSluzbeNabavka = pEmailSluzbeNabavka
End Property
Public Property Let EmailSluzbeNabavka(ByVal vNewValue As String)
    pEmailSluzbeNabavka = vNewValue
End Property
Public Property Get KorisnikAplikacije() As String
    KorisnikAplikacije = pKorisnikAplikacije
End Property
Public Property Let KorisnikAplikacije(ByVal vNewValue As String)
    pKorisnikAplikacije = vNewValue
End Property
'Private Sub ER_Terminate()
'    Set ERReader = Nothing
'End Sub
Private Sub Email_Initialize()
    pSMTPhost = Nz(LIB_CFGRW.ReadParametar("CFG_Global", "SMTPhost"), "")
    pSMTPport = Nz(LIB_CFGRW.ReadParametar("CFG_Global", "SMTPport"), "")
    pEmailAcct = Nz(LIB_CFGRW.ReadParametar("CFG_Global", "EmailAcct"), "")
    pEmailAcctPwd = Nz(LIB_CFGRW.ReadParametar("CFG_Global", "EmailAcctPwd"), "")
    pFromEmail = Nz(LIB_CFGRW.ReadParametar("CFG_Global", "FromEmail"), "")
    
    'pEmailAcct = Nz(CFGRW.ReadParametar("CFG_Global", "EmailAcct"), "nabavka1@servoteh.com")  ' bigbit@servoteh.com
    'pEmailAcctPwd = Nz(CFGRW.ReadParametar("CFG_Global", "EmailAcctPwd"), "!12345St")  ' Sraf@123!
    'pFromEmail = Nz(CFGRW.ReadParametar("CFG_Lokal", "FromEmail"), "nabavka1@servoteh")   'bigbit@servoteh.com
    pFromDisplayName = Nz(LIB_CFGRW.ReadParametar("CFG_Lokal", "FromDisplayName"), "")
    pReplyToAddress = Nz(LIB_CFGRW.ReadParametar("CFG_Lokal", "ReplyToAddress"), F_EmailZaCurrentUser())
    pEmailSluzbeNabavka = Nz(LIB_CFGRW.ReadParametar("CFG_Global", "EmailSluzbeNabavka"), "nabavka@servoteh.com")
    pKorisnikAplikacije = ""
End Sub
Private Sub Class_Initialize()
    Email_Initialize
End Sub


