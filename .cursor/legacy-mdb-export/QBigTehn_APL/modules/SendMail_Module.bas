Attribute VB_Name = "SendMail_Module"
Option Compare Database
Option Explicit
'Public objMailer As vbSendMail.clsSendMail
Public EmailClass As New Email_Class
Private txtStatus As String

Public Function DefaultFolderZaAtt() As String
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
Public Function DefaultNabavkaMessageBody() As String
 Dim stRetVal As String
 
 
 stRetVal = Nz(ReadParametar("CFG_Global", "Nabavka_BodyMail"), "")
 
 If Nz(stRetVal, "") = "" Then
  stRetVal = "Poštovani," & vbCrLf
  stRetVal = stRetVal & "Najljubaznije Vas molimo da nam dostavite ponudu prema zahtevu u prilogu." & vbCrLf
  stRetVal = stRetVal & "Ponudu poslati na mail nabavka@servoteh.com." & vbCrLf & vbCrLf
  stRetVal = stRetVal & Srpski("Srdacan") & " pozdrav," & vbCrLf & vbCrLf
  'stRetVal = stRetVal & DLookup("[Firma]", "Radni fajlovi", "[IDBaze] = " & F_IDAktivneBaze()) & vbCrLf
  stRetVal = stRetVal & F_AFNaziv & vbCrLf
 End If
 
 DefaultNabavkaMessageBody = stRetVal
End Function
Public Function DefaultNabavkaSubject() As String
On Error Resume Next
    Dim stRetVal
    stRetVal = Nz(ReadParametar("CFG_Global", "Nabavka_Subject"), "")
    
    If Nz(stRetVal, "") = "" Then
     'stRetVal = "Kupac: " & Me![Naziv] & " " & Me![Vrsta dokumenta] & ": " & Me![Broj dokumenta] & " ID: " & Me![IDDok]
     stRetVal = "Upit za nabavku"
    End If
    DefaultNabavkaSubject = stRetVal
End Function

Public Function DefaultSpecifikacijaNabavkeSubject(stBrojPredmeta As String, stBrojZahteva As String) As String
On Error Resume Next
    Dim stRetVal
    stRetVal = Nz(ReadParametar("CFG_Global", "SpecifikacijaNabavke_Subject"), "")
    
    If Nz(stRetVal, "") = "" Then
        stRetVal = "Zahtev za nabavku broj " & stBrojZahteva & ", po predmetu broj " & stBrojPredmeta
    End If
    DefaultSpecifikacijaNabavkeSubject = stRetVal
End Function
Public Function DefaultSpecifikacijaNabavkeMessageBody(ByVal stInicijatorZahteva As String, ByVal krajnjiRok As Date, Optional Opis As String = "", Optional Napomena As String = "") As String
 Dim stRetVal As String
 
 
 stRetVal = Nz(ReadParametar("CFG_Global", "SpecifikacijaNabavke_BodyMail"), "")
 
 If Nz(stRetVal, "") = "" Then
  stRetVal = "Kreiran je novi zahtev za nabavku robe. Inicijator zahteva je " & stInicijatorZahteva & vbCrLf & vbCrLf
  If Opis <> "" Then stRetVal = stRetVal & "Opis: " & Opis & IIf(Napomena <> "", vbCrLf, vbCrLf & vbCrLf)
  If Napomena <> "" Then stRetVal = stRetVal & "Napomena: " & Napomena & vbCrLf & vbCrLf
  stRetVal = stRetVal & "Rok za ponudu je " & krajnjiRok & vbCrLf & vbCrLf
  
 End If
 
 DefaultSpecifikacijaNabavkeMessageBody = stRetVal
End Function
Public Function DefaultNabavkaINOMessageBody() As String
 Dim stRetVal As String
 
 
 stRetVal = Nz(ReadParametar("CFG_Global", "Nabavka_INOBodyMail"), "")
 
 If Nz(stRetVal, "") = "" Then
  stRetVal = "Dear Sir/Madam," & vbCrLf
  stRetVal = stRetVal & "In the attachment you will find our offer request.  We are waiting for your offer. Please fill free to contact us for any additional information." & vbCrLf & vbCrLf
  stRetVal = stRetVal & "Best regards," & vbCrLf & vbCrLf
  'stRetVal = stRetVal & DLookup("[Firma]", "Radni fajlovi", "[IDBaze] = " & F_IDAktivneBaze()) & vbCrLf
  stRetVal = stRetVal & F_AFNaziv & vbCrLf
 End If
 
 DefaultNabavkaINOMessageBody = stRetVal
End Function
Public Function DefaultNabavkaINOSubject() As String
On Error Resume Next
    Dim stRetVal
    stRetVal = Nz(ReadParametar("CFG_Global", "INONabavka_Subject"), "")
    
    If Nz(stRetVal, "") = "" Then
     'stRetVal = "Kupac: " & Me![Naziv] & " " & Me![Vrsta dokumenta] & ": " & Me![Broj dokumenta] & " ID: " & Me![IDDok]
     stRetVal = "Request for quotation"
    End If
    DefaultNabavkaINOSubject = stRetVal
End Function

Public Function BBMail_OtvoriFormuZaSlanjeSpecifikacijeNabavke() As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    If IsLoaded("BBMail_UpitZaDobavljaca") Or IsLoaded("BBMail_ZaNabavku") Then
       MsgBox "Morate da zatvorite otvorene forme za slanje e-maila"
       Exit Function
    Else
        Set EmailClass = Nothing
        EmailClass.KorisnikAplikacije = CurrentUser()
        DoCmd.OpenForm "BBMail_ZaNabavku"
        Forms!BBMail_ZaNabavku.Requery
    End If

Exit_Point:
 On Error Resume Next
 BBMail_OtvoriFormuZaSlanjeSpecifikacijeNabavke = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "BBMail_OtvoriFormuZaSlanjeSpecifikacijeNabavke"
    retValOk = False
    Resume Exit_Point
End Function
Public Function F_EmailZaCurrentUser() As String

    Dim Email As Variant
    'ID = DLookup("[Sifra prodavca]", "Prodavci", "[Prodavac] = '" & CurrentUser & "'")
    Email = Nz(DLookup("[Email]", "EXT_Prodavci", "[LogAcc] = '" & CurrentUser & "'"), "")
    'ID = NullToZero(ID)            ' If Not IsNum(ID) Then ID = 0 svejedno
    F_EmailZaCurrentUser = Email
    
End Function

