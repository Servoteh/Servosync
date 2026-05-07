VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PotrebniGotoviDeloviZaCrtez"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private mStack As Collection
Private mCaptionBase As String
Public Sub PushStack(IDCrtez As Long, BrojCrteza As String, Revizija As String, _
                     BrojKomada As Long, Naziv As String)

    If mStack Is Nothing Then
        Set mStack = New Collection
    End If

    mStack.Add IDCrtez & "|" & BrojCrteza & "|" & Revizija & "|" & BrojKomada & "|" & Naziv

End Sub
Private Sub cmdBack_Click()

    If mStack.Count <= 1 Then Exit Sub

    mStack.Remove mStack.Count

    Dim arr
    arr = Split(mStack(mStack.Count), "|")
    Me!Podforma.SourceObject = "ReklamniPanel"
    NapuniTmpPDMKataloske val(arr(0)), Me!TopLevelOnly
    Call PregledPotrebnihGotovihDelovaZaCrtez( _
        val(arr(0)), _
        arr(1), _
        arr(2), _
        val(arr(3)), _
        arr(4) _
    )

    Call OsveziCaption
    Call OsveziBackDugme
    
End Sub
Private Sub cmdSastavnicaPodsklopa_Click()

    mStack.Add _
        Me!Podforma2.Form!IDCrtez & "|" & _
        Me!Podforma2.Form!BrojCrteza & "|" & _
        Me!Podforma2.Form!Revizija & "|" & _
        Nz(Me!Podforma2.Form!BrojKomada, 1) & "|" & _
        Me!Podforma2.Form!Naziv
    Me!Podforma.SourceObject = "ReklamniPanel"
    NapuniTmpPDMKataloske Me!Podforma2.Form!IDCrtez, Me!TopLevelOnly
    
    Call PregledPotrebnihGotovihDelovaZaCrtez( _
            Me!Podforma2.Form!IDCrtez, _
            Me!Podforma2.Form!BrojCrteza, _
            Me!Podforma2.Form!Revizija, _
            Nz(Me!Podforma2.Form!BrojKomada, 1), _
            Me!Podforma2.Form!Naziv _
    )

    Call OsveziCaption
    Call OsveziBackDugme
    
End Sub
Private Sub OsveziPutanju()

On Error GoTo Err_Handler

    Dim i As Long
    Dim arr
    Dim s As String

    s = ""

    For i = 1 To mStack.Count
        
        arr = Split(mStack(i), "|")
        
        If s <> "" Then s = s & " > "
        s = s & arr(4) ' Naziv
        
    Next i

    Me!txtPutanja = s

Exit_Handler:
    Exit Sub

Err_Handler:
    Resume Exit_Handler

End Sub
Private Sub OsveziBackDugme()

On Error Resume Next
    Me!cmdBack.Enabled = (mStack.Count > 1)

End Sub
Public Sub OsveziCaption()

On Error GoTo Err_Handler

    Dim i As Long
    Dim arr
    Dim s As String

    s = ""

    For i = 1 To mStack.Count
        arr = Split(mStack(i), "|")
        
        If s <> "" Then s = s & " > "
        s = s & arr(4)
    Next i

    Me.Caption = "Sastavnica delova: " & s

Exit_Handler:
    Exit Sub

Err_Handler:
    Resume Exit_Handler

End Sub

Private Sub BrojKomadaZaIzradu_AfterUpdate()
    Me!Podforma.SourceObject = "ReklamniPanel"
    Me!Podforma.SourceObject = "PregledGotovihDelovaZaCrtez"
End Sub

Private Sub cmdStampajPDFCrtez_Click()
        Call StampajPDFCrtez_Binary( _
                                Me!BrojCrteza, _
                                Me!Revizija, _
                                Me)

End Sub

Private Sub DugmePreview_Click()
        Call PreviewPDFCrtez_Binary(Me!BrojCrteza, _
                                Me!Revizija, _
                                Me)
End Sub

Private Sub DugmeTree_Click()
On Error GoTo Err_Handler
    
        
    Dim ID As Long
    ID = Nz(Me!ZaIDCrtez, 0)
    
    If ID = 0 Then
        MsgBox "Nije zadat ID crteža (ZaIDCrtez je 0 ili Null).", vbInformation, "TreeView"
        Exit Sub
    End If

    ' 1) Postavi SourceObject subforme (ako veæ nije)
    If Me!Podforma1.SourceObject <> "Form.frmPDMTreeView_Sub" Then
        Me!Podforma1.SourceObject = "Form.frmPDMTreeView_Sub"
        DoEvents            ' da Access stigne da uèita formu u subformu
    End If

    ' 2) Prosledi ID subformi
    Me!Podforma1.Form.SetIDCrtez ID

Exit_Handler:
    Exit Sub

Err_Handler:
    MsgBox "Greška: " & err.Number & " - " & err.Description, vbExclamation, "DugmeTree_Click"
    Resume Exit_Handler
End Sub
Public Sub PreviewTree(ByVal ZaIDCrtez As Long)
On Error GoTo Err_Handler
     
    Dim ID As Long
    ID = Nz(ZaIDCrtez, 0)
    
    If ID = 0 Then
        MsgBox "Nije zadat ID crteža (ZaIDCrtez je 0 ili Null).", vbInformation, "TreeView"
        Exit Sub
    End If

    ' 1) Postavi SourceObject subforme (ako veæ nije)
    If Me!Podforma1.SourceObject <> "Form.frmPDMTreeView_Sub" Then
        Me!Podforma1.SourceObject = "Form.frmPDMTreeView_Sub"
        DoEvents            ' da Access stigne da uèita formu u subformu
    End If

    ' 2) Prosledi ID subformi
    Me!Podforma1.Form.SetIDCrtez ID

Exit_Handler:
    Exit Sub

Err_Handler:
    MsgBox "Greška: " & err.Number & " - " & err.Description, vbExclamation, "DugmeTree_Click"
    Resume Exit_Handler
End Sub

Private Sub Form_Load()
'    DoCmd.GoToControl "BrojKomadaZaIzradu"
    Me!TopLevelOnly = True
End Sub


Private Sub RobaZaPredmet_AfterUpdate()
    If Not IsNull(Me!RobaZaPredmet) Then
        Me!cmdPoruciRobuZaRN.Caption = "Poruèi robu za " & Me!RobaZaPredmet.Column(1)
    Else
        Me!cmdPoruciRobuZaRN.Caption = "Poruèi robu za RN"
    End If
End Sub

Private Sub TopLevelOnly_AfterUpdate()
    Me!Podforma.SourceObject = "ReklamniPanel"
    NapuniTmpPDMKataloske Me!ZaIDCrtez, Me!TopLevelOnly
    Me!Podforma.SourceObject = "PregledGotovihDelovaZaCrtez"
End Sub

Private Sub cmdPoruciRobuZaRN_Click()

On Error GoTo Err_Handler

Dim sql As String
Dim IDPotreba As Long
Dim StatusDok As Integer
Dim TipEksplozije As Integer
Dim IDPredmet As Long
Dim IDCrtez As Long
Dim DatumPotrebe As Date
Dim SifraRadnika As Long
Dim stWhere As String
Dim msg As String
Dim stUser As String
Dim BrKom As Long

Dim cntBefore As Long
Dim cntAfter As Long
Dim cntAdded As Long

Dim cntBOM As Long
Dim cntSkip As Long
Dim VecPostoji As Long
Dim odgovor As VbMsgBoxResult
    '-------------------------------------------------
    ' VALIDACIJE
    '-------------------------------------------------
    
    If IsNull(Me!DatumPotrebe) Then
        MsgBox "Morate definisati datum potrebe.", vbExclamation
        Exit Sub
    End If
    
    If IsNull(Me!RobaZaPredmet) Then
        MsgBox "Morate definisati projekat.", vbExclamation
        Exit Sub
    End If
    
    If Nz(Me!BrojKomZaProizvodnju, 0) = 0 Then
        MsgBox "Morate da definišete broj komada sklopa za koji planirate nabavku.", vbExclamation
        Exit Sub
    End If
    
    IDPredmet = Nz(Me!RobaZaPredmet, 0)
    IDCrtez = Nz(Me!ZaIDCrtez, 0)
    DatumPotrebe = Me!DatumPotrebe
    SifraRadnika = IDRadnikZaCurrentUser()
    stUser = Replace(CurrentUser(), "'", "''")
    BrKom = Nz(Me!BrojKomZaProizvodnju, 1)
    
    If Nz(Me!TopLevelOnly, False) Then
        TipEksplozije = 1
    Else
        TipEksplozije = 2
    End If
    
    ' =====================================
    ' 1. PROVERA DA LI VEÆ POSTOJI OTVORENA POTREBA
    ' =====================================
    VecPostoji = Nz(ADO_Lookup(CNN_CurrentDataBase, "IDPotreba", "MRP_Potrebe", _
                        "IDPredmet=" & IDPredmet & _
                        " AND IDCrtezRoot=" & IDCrtez & _
                        " AND Status IN (0,2)" _
                    ), 0)

    If VecPostoji <> 0 Then

        odgovor = MsgBox( _
            "Za ovaj crtež veæ postoji otvorena potreba." & vbCrLf & _
            "Broj dokumenta: " & VecPostoji & vbCrLf & vbCrLf & _
            "Da li želite da ipak nastavite?", _
            vbQuestion + vbYesNo + vbDefaultButton2, _
            "Upozorenje")

        If odgovor = vbNo Then Exit Sub

    End If
    
    '-------------------------------------------------
    ' POSTOJI LI MRP DOKUMENT
    '-------------------------------------------------
    
    stWhere = "IDPredmet=" & IDPredmet & _
              " AND IDCrtezRoot=" & IDCrtez & _
              " AND TipEksplozije=" & TipEksplozije
    
    IDPotreba = Nz(DLookup("IDPotreba", "MRP_Potrebe", stWhere), 0)
    
    '-------------------------------------------------
    ' AKO POSTOJI › proveri status
    '-------------------------------------------------
    
    If IDPotreba > 0 Then
    
        StatusDok = Nz(DLookup("Status", "MRP_Potrebe", "IDPotreba=" & IDPotreba), 0)
    
        If StatusDok > 0 Then
            MsgBox "MRP dokument je veæ u planiranju i ne može se regenerisati.", vbExclamation
            Exit Sub
        End If
    
    End If
    
    '-------------------------------------------------
    ' INFO PRE GENERISANJA
    '-------------------------------------------------
    
    msg = InfoMRP_Potrebe(IDCrtez, TipEksplozije, BrKom)
    
    If MsgBox(msg & vbCrLf & vbCrLf & _
              "Da li želite da generišete MRP potrebe?", _
              vbQuestion + vbYesNo) = vbNo Then Exit Sub
    
    '-------------------------------------------------
    ' KREIRAJ ZAGLAVLJE AKO TREBA
    '-------------------------------------------------
    
    If IDPotreba = 0 Then
    
        sql = "INSERT INTO MRP_Potrebe "
        sql = sql & "(IDPredmet,IDCrtezRoot,Izvor,TipEksplozije,DatumPotrebe,"
        sql = sql & "DIVUnosaKorisnik,DIVIzmena,DIVIzmenaKorisnik,PlaniranaKolicina,SifraRadnika) "
    
        sql = sql & "VALUES ("
        sql = sql & IDPredmet & ","
        sql = sql & IDCrtez & ",1,"
        sql = sql & TipEksplozije & ",'"
        sql = sql & Format(DatumPotrebe, "yyyy-mm-dd") & "','"
        sql = sql & stUser & "','"
        sql = sql & Format(Now(), "yyyy-mm-dd HH:nn:ss") & "','"
        sql = sql & stUser & "',"
        sql = sql & BrKom & ","
        sql = sql & SifraRadnika & ")"
        
        If Not ADO_ExecSQL(CNN_CurrentDataBase, sql, True) Then
            MsgBox "Nije moguæe kreirati MRP dokument.", vbCritical
            Exit Sub
        End If
    
        IDPotreba = Nz(DLookup("IDPotreba", "MRP_Potrebe", stWhere), 0)
    
        If IDPotreba = 0 Then
            MsgBox "Greška pri pronalaženju MRP dokumenta.", vbCritical
            Exit Sub
        End If
    
    End If
    
    '-------------------------------------------------
    ' BROJANJE PRE
    '-------------------------------------------------
    
    cntBefore = DCount("*", "MRP_PotrebeStavke", _
        "IDPotreba IN (SELECT IDPotreba FROM MRP_Potrebe WHERE IDPredmet=" & IDPredmet & ")")
    
    '-------------------------------------------------
    ' BROJANJE BOM-a
    '-------------------------------------------------
    Dim rs As Object

    sql = "SELECT COUNT(*) AS CNT " & _
          "FROM dbo.ftMRP_PotrebeZaCrtez(" & IDCrtez & "," & TipEksplozije & ",1)"
    
    Set rs = ADO_GetRST(CNN_CurrentDataBase, sql)
    
    If Not rs.EOF Then
        cntBOM = Nz(rs!cnt, 0)
    Else
        cntBOM = 0
    End If
    
    rs.Close
    Set rs = Nothing
        
    '-------------------------------------------------
    ' INSERT BEZ DUPLIKATA (GLAVNI DEO)
    '-------------------------------------------------
    
    sql = "INSERT INTO MRP_PotrebeStavke "
    sql = sql & "(IDPotreba,IDCrtezIzvora,IDCrtezNabavke,"
    sql = sql & "KataloskiBrojStavka,NazivArtiklaStavka,JedinicaMereStavka,"
    sql = sql & "IzvorStavke,KolicinaPotrebna,DatumPotrebe,"
    sql = sql & "DIVUnosaKorisnik,DIVIzmena,DIVIzmenaKorisnik) "
    
    sql = sql & "SELECT "
    sql = sql & IDPotreba & ","
    sql = sql & "F.RoditeljCrtez,"
    sql = sql & "F.IDCrtezNabavke,"
    sql = sql & "F.KataloskiBroj,"
    sql = sql & "F.Naziv,"
    sql = sql & "F.JM,"
    sql = sql & "1,"
    sql = sql & "F.Kolicina,"
    sql = sql & "'" & Format(DatumPotrebe, "yyyy-mm-dd") & "',"
    sql = sql & "'" & stUser & "',"
    sql = sql & "'" & Format(Now(), "yyyy-mm-dd HH:nn:ss") & "',"
    sql = sql & "'" & stUser & "' "
    
    sql = sql & "FROM dbo.ftMRP_PotrebeZaCrtez("
    sql = sql & IDCrtez & "," & TipEksplozije & "," & BrKom & ") F "
    
    'sql = sql & "WHERE NOT EXISTS ("
    'sql = sql & "SELECT 1 FROM MRP_PotrebeStavke S "
    'sql = sql & "INNER JOIN MRP_Potrebe P ON P.IDPotreba = S.IDPotreba "
    'sql = sql & "WHERE P.IDPredmet = " & IDPredmet & " "
    'sql = sql & "AND S.IDCrtezNabavke = F.IDCrtezNabavke)"
    
    If Not ADO_ExecSQL(CNN_CurrentDataBase, sql, True) Then
        MsgBox "Greška pri generisanju MRP stavki.", vbCritical
        Exit Sub
    End If
    
    '-------------------------------------------------
    ' BROJANJE POSLE
    '-------------------------------------------------
    
    cntAfter = DCount("*", "MRP_PotrebeStavke", _
        "IDPotreba IN (SELECT IDPotreba FROM MRP_Potrebe WHERE IDPredmet=" & IDPredmet & ")")
    
    cntAdded = cntAfter - cntBefore
    
    cntSkip = cntBOM - cntAdded
    If cntSkip < 0 Then cntSkip = 0
    
    '-------------------------------------------------
    ' UPDATE ARTIKLI
    '-------------------------------------------------
    
    Call UpdateMRPStavke_SifraArtikla(IDPotreba)
    
    '-------------------------------------------------
    ' INSERT/UPDATE ZALIHA
    '-------------------------------------------------
    Call AzurirajLagerZaStavkePlaniraneNabavke(IDPotreba)
    
    '-------------------------------------------------
    ' PORUKA
    '-------------------------------------------------
    
    'MsgBox "MRP generisanje završeno." & vbCrLf & vbCrLf & _
           "Dodato novih stavki: " & cntAdded & vbCrLf & _
           "Duplikati nisu ubacivani.", vbInformation
    
    If cntAdded = 0 Then
        MsgBox "Sve stavke veæ postoje u MRP dokumentima.", vbInformation
    Else
         
        MsgBox _
            "MRP generisanje završeno." & vbCrLf & vbCrLf & _
            "Ukupno iz BOM-a: " & cntBOM & vbCrLf & _
            "Dodato: " & cntAdded & vbCrLf & _
            "Preskoèeno (duplikati): " & cntSkip, _
            vbInformation
        DoCmd.Close
    End If
    
    
Exit Sub

'-------------------------------------------------
' ERROR
'-------------------------------------------------

Err_Handler:

MsgBox "Greška: " & err.Description, vbCritical

End Sub
