VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledPrimopredaje"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit


Private Function ClearCurrentVal()
   Screen.ActiveControl.Value = Null
   PrimeniUslove
End Function


Private Sub BrojCrteza_DblClick(Cancel As Integer)
    SetujFilterZaKontrolu
    PrimeniUslove
End Sub
Public Function DodeliVrednostFilteru()
    SetujFilterZaKontrolu
    PrimeniUslove
End Function

Private Sub DugmeDetaljnoCrtez_Click()
On Error GoTo Err_DugmeDetaljnoCrtez_Click

    Dim DocName As String
    Dim LinkCriteria As String
    
    On Error Resume Next
    DetaljnoCrtez Me!IDCrtez
    
Exit_DugmeDetaljnoCrtez_Click:
    Exit Sub

Err_DugmeDetaljnoCrtez_Click:
    MsgBox Error$
    Resume Exit_DugmeDetaljnoCrtez_Click

End Sub

Private Sub DugmeOdbaciPrimopredaju_Click()
On Error GoTo Err_Handler

    Dim lngIDRN As Long
    Dim retValOk As Boolean
    
    lngIDRN = CLng(Nz(Me!IDRN, -1))
    '**************************
    ' Ovo je kod kad odobravam primopredaju. Tu moram i da imam gUserSifraRadnika ua insert u tablicu odobrenih
    'gUserSifraRadnika = IDRadnikZaCurrentUser()
    'retValOk = ADO_ExecSP(CNN_CurrentDataBase, "spPromeniStatusPrimopredaje", mIDRN, 1, Me!cmbTehnolog, gUserSifraRadnika)
    '********************
    
    retValOk = ADO_ExecSP(CNN_CurrentDataBase, "spPromeniStatusPrimopredaje", lngIDRN, 2)
    
    If retValOk Then
        MsgBox "Status primopredaje je uspešno promenjen.", vbInformation
        PrimeniUslove
    Else
        MsgBox "Status primopredaje NIJE promenjen.", vbInformation
    End If

Exit_Point:
    Exit Sub
Err_Handler:
    MsgBox "Greška: " & err.Description, vbCritical
    Resume Exit_Point

End Sub

Private Sub DugmeOdobriPrimopredaju_Click()
On Error GoTo Err_Handler

    'Dim lngIDRN As Long
    'lngIDRN = CLng(Nz(Me!IDRN, -1))
    
    'Call ADO_ExecSP(CNN_CurrentDataBase, "spPromeniStatusPrimopredaje", lngIDRN, 1)
    
    'PrimeniUslove

    'MsgBox "Status primopredaje je uspešno promenjen.", vbInformation
    If Nz(Me!IDRN, 0) <> 0 Then
        DoCmd.OpenForm "frmIzborTehnologa", , , , , , Me!IDRN
    Else
        MsgBox "Ne postoji selektovana primopredaja za odobravanje.", vbInformation
    End If
    
Exit_Point:
    Exit Sub
Err_Handler:
    MsgBox "Greška: " & err.Description, vbCritical
    Resume Exit_Point
End Sub

Private Sub DugmePrimopredajaDetaljno_Click()
On Error GoTo Err_DugmeDetaljnoCrtez_Click

    Dim DocName As String
    Dim LinkCriteria As String
    On Error Resume Next

    'DocName = "Primopredaja"
    'LinkCriteria = "[IDRN] = " & Me!IDRN
    'BBOpenForm DocName, , , LinkCriteria
    PrikaziDokRN Me!IDRN, True
    
    'While IsLoaded("Primopredaja")
    '    DoEvents
    'Wend
    'PrimeniUslove
    
Exit_DugmeDetaljnoCrtez_Click:
    Exit Sub

Err_DugmeDetaljnoCrtez_Click:
    MsgBox Error$
    Resume Exit_DugmeDetaljnoCrtez_Click

End Sub

Private Sub DugmePrint_Click()
    PreviewPDFCrtez_Binary
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
    PrikaziAPPRev
    PostaviStatusnuLiniju
   ' Me!PrikaziSveStavke = False
    '****************************
    If UserUGrupi(CurrentUser(), "OdobriPrimoPred") Or UserUGrupi(CurrentUser(), "Admins") Then
        Me!DugmeOdobriPrimopredaju.Enabled = True
    End If
    
    If Nz(Me.OpenArgs, "") = "Obrada" Then
        Me!ZaIDStatusPrimopredaje = 0
        OvoJePregledPrimopredajaUObradi
        'Me!ZaIDStatusPrimopredaje.Locked = True
        Me!ZaIDStatusPrimopredaje.Enabled = False
    ElseIf Nz(Me.OpenArgs, "") = "Odobren" Then
        Me!ZaIDStatusPrimopredaje = 1
        OvoJePregledOdobrenihPrimopredaja
        'Me!ZaIDStatusPrimopredaje.Locked = True
        Me!ZaIDStatusPrimopredaje.Enabled = False
    ElseIf Nz(Me.OpenArgs, "") = "Odbijen" Then
        Me!ZaIDStatusPrimopredaje = 2
        OvoJePregledOdbijenihPrimopredaja
        'Me!ZaIDStatusPrimopredaje.Locked = True
        Me!ZaIDStatusPrimopredaje.Enabled = False
    ElseIf Nz(Me.OpenArgs, "") = "Lansiran" Then
        Me!ZaIDStatusPrimopredaje = 3
        OvoJePregledLansiranihPrimopredaja
        'Me!ZaIDStatusPrimopredaje.Locked = True
        Me!ZaIDStatusPrimopredaje.Enabled = False
    Else
        Me!ZaIDStatusPrimopredaje = Null
        OvoJePregledSvihPrimopredaja
    End If
    '*****************************
    Call PrimeniVidljivostKolonaPoStatusu(Me.OpenArgs)
    
End Sub


Private Sub PDMCrtezTrazi_AfterUpdate()
    Dim rs As DAO.Recordset
    Set rs = Me.RecordsetClone
    
    rs.FindFirst "IDCrtez = " & Nz(Me!PDMCrtezTrazi, 0)
    
    Me![PDMCrtezTrazi] = Null
    
End Sub

Private Sub DugmePrviSlog_Click()
    Me.Recordset.MoveFirst
End Sub
Private Sub DugmePrethodniSlog_Click()
    With Me.Recordset
        If Not .BOF Then .MovePrevious
        If .BOF Then .MoveFirst
    End With
End Sub
Private Sub DugmeSledeciSlog_Click()
    With Me.Recordset
        If Not .EOF Then .MoveNext
        If .EOF Then .MoveLast
   '     Me!PodFrmA.Form.PrikaziCrtezIReference
   End With
End Sub
Private Sub DugmePoslednjiSlog_Click()
    Me.Recordset.MoveLast
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


Public Function PrimeniUslove()
On Error GoTo Err_Point

    SetProperlyRecordSource BBCFG.CNNString, Me
    PrimeniColorKeyZaBojuPozadine Me
    
Exit_Point:
On Error Resume Next

Exit Function
Err_Point:
 BBErrorMSG err, "PrimeniUslove"
 Resume Exit_Point:
End Function


Private Sub Form_Load()
    NapuniListuStampaca Me.lstStampaci
    PrimeniUslove
End Sub
Private Sub Form_Unload(Cancel As Integer)
    CloseConnectionOnCurrentForm Me
End Sub
Public Sub DefinisiBojuPozadine(frm As Form, ParamArray controlNames() As Variant)
    Dim i As Long, nm As String
    Dim fc As FormatConditions
    Dim rule As FormatCondition

    For i = LBound(controlNames) To UBound(controlNames)
        nm = CStr(controlNames(i))
        With frm.Controls(nm)
            Set fc = .FormatConditions
            fc.Delete  ' poèisti stara pravila

            ' 6 pravila za ColorKey = 0..5
            Set rule = fc.Add(acExpression, , "[ColorKey]=0")
            rule.BackColor = RGB(235, 235, 235)

            Set rule = fc.Add(acExpression, , "[ColorKey]=1")
            rule.BackColor = RGB(221, 235, 247)

            Set rule = fc.Add(acExpression, , "[ColorKey]=2")
            rule.BackColor = RGB(226, 239, 218)

            Set rule = fc.Add(acExpression, , "[ColorKey]=3")
            rule.BackColor = RGB(255, 242, 204)

            Set rule = fc.Add(acExpression, , "[ColorKey]=4")
            rule.BackColor = RGB(237, 226, 246)

            Set rule = fc.Add(acExpression, , "[ColorKey]=5")
            rule.BackColor = RGB(252, 228, 214)
        End With
    Next i
End Sub
Private Sub OvoJePregledPrimopredajaUObradi()
On Error GoTo Err_Point

        Me!lblNazivForme.Caption = "Crteži predati na odobrenje"
        Me.Caption = "Predati crteži"
        
        Me!DugmePrimopredajaDetaljno.Visible = False
        
        'Me!DugmeFiskalniRacun.Enabled = False
        'Me!DugmePrebaciNaProf.Enabled = False
        
        'Me!TabCtlZaIF.Pages("Profaktura").Visible = True
        
Exit_Point:
On Error Resume Next

Exit Sub

Err_Point:
   MsgBox err.Description
   Resume Next
End Sub

Private Sub OvoJePregledOdobrenihPrimopredaja()
On Error GoTo Err_Point

        Me!lblNazivForme.Caption = "Odobreni Crteži"
        Me.Caption = "Odobreni crteži"
        
        Me!DugmeOdobriPrimopredaju.Visible = False
        Me!DugmeOdbaciPrimopredaju.Visible = False
        
        'Me!TabCtlZaIF.Pages("Profaktura").Visible = True
        
Exit_Point:
On Error Resume Next

Exit Sub

Err_Point:
   MsgBox err.Description
   Resume Next
End Sub
Private Sub OvoJePregledOdbijenihPrimopredaja()
On Error GoTo Err_Point

        Me!lblNazivForme.Caption = "Odbijeni Crteži"
        Me.Caption = "Odbijeni crteži"
        
        Me!DugmeOdobriPrimopredaju.Visible = False
        Me!DugmeOdbaciPrimopredaju.Visible = False
        Me!DugmePrimopredajaDetaljno.Visible = False
        'Me!TabCtlZaIF.Pages("Profaktura").Visible = True
        
Exit_Point:
On Error Resume Next

Exit Sub

Err_Point:
   MsgBox err.Description
   Resume Next
End Sub

Private Sub OvoJePregledSvihPrimopredaja()
On Error GoTo Err_Point

        Me!lblNazivForme.Caption = "Svi predati crteži"
        Me.Caption = "Svi predati crteži"
    
        Me!DugmeOdobriPrimopredaju.Visible = False
        Me!DugmeOdbaciPrimopredaju.Visible = False
        
        'Me!TabCtlZaIF.Pages("Profaktura").Visible = True
        
Exit_Point:
On Error Resume Next

Exit Sub

Err_Point:
   MsgBox err.Description
   Resume Next
End Sub
Private Sub OvoJePregledLansiranihPrimopredaja()
On Error GoTo Err_Point

        Me!lblNazivForme.Caption = "Lansirani Crteži"
        Me.Caption = "Lansirani crteži"
        
        Me!DugmeOdobriPrimopredaju.Visible = False
        Me!DugmeOdbaciPrimopredaju.Visible = False
        Me!DugmePrimopredajaDetaljno.Visible = False
        'Me!TabCtlZaIF.Pages("Profaktura").Visible = True
        
Exit_Point:
On Error Resume Next

Exit Sub

Err_Point:
   MsgBox err.Description
   Resume Next
End Sub
Public Function StampajSvePDFCrtezeNaFormi_Binary( _
    ByVal frm As Form, _
    Optional ByVal DirektnoNaStampac As Boolean = False _
) As Boolean

On Error GoTo Err_Point

Dim rs As DAO.Recordset
Dim cnn As ADODB.Connection
Dim rsPDF As ADODB.Recordset

Dim stBrojCrteza As String
Dim stRevizija As String
Dim stFileName As String
Dim sql As String

Dim bytes() As Byte
Dim chunk() As Byte
Dim totalSize As Long

Dim lCount As Long
Dim OK As Boolean
Dim f As Integer

OK = True

Set rs = frm.RecordsetClone

If rs.BOF And rs.EOF Then
    MsgBox "Nema slogova za štampu.", vbInformation, "QBigTehn"
    StampajSvePDFCrtezeNaFormi_Binary = False
    GoTo CleanUp
End If

Set cnn = New ADODB.Connection
cnn.Open CNN_CurrentDataBase

rs.MoveFirst

Do While Not rs.EOF

    stBrojCrteza = Nz(rs.Fields("BrojCrteza").Value, "")
    stRevizija = Nz(rs.Fields("Revizija").Value, "")

    If Len(stBrojCrteza) > 0 And Len(stRevizija) > 0 Then

        sql = "SELECT PDFBinary FROM PDM_PDFCrtezi WHERE BrojCrteza = N'" & _
              Replace(stBrojCrteza, "'", "''") & _
              "' AND Revizija = N'" & _
              Replace(stRevizija, "'", "''") & "'"

        Set rsPDF = New ADODB.Recordset
        rsPDF.Open sql, cnn, adOpenForwardOnly, adLockReadOnly

        If Not rsPDF.EOF Then

            totalSize = rsPDF.Fields("PDFBinary").ActualSize

            If totalSize > 0 Then

                ReDim bytes(0 To totalSize - 1)

                chunk = rsPDF.Fields("PDFBinary").GetChunk(totalSize)

                ' kopiranje chunk u bytes
                Dim i As Long
                For i = 0 To totalSize - 1
                    bytes(i) = chunk(i)
                Next i

                stFileName = Environ$("TEMP") & "\~" & _
                             Trim(stBrojCrteza & "_" & stRevizija & "_" & Format(Now(), "hhmmss")) & ".pdf"

                f = FreeFile
                Open stFileName For Binary Access Write As #f
                Put #f, 1, bytes
                Close #f

                If DirektnoNaStampac Then
                    StampajPDFFajl stFileName
                Else
                    RunIt stFileName
                End If

                lCount = lCount + 1

            End If

        End If

        rsPDF.Close
        Set rsPDF = Nothing

    End If

    rs.MoveNext
    DoEvents

Loop

MsgBox "Obraðeno PDF crteža: " & lCount, vbInformation, "QBigTehn"

StampajSvePDFCrtezeNaFormi_Binary = OK

CleanUp:

On Error Resume Next

If Not rs Is Nothing Then rs.Close
If Not cnn Is Nothing Then cnn.Close

Set rs = Nothing
Set cnn = Nothing

Exit Function

Err_Point:

OK = False
BBErrorMSG err, "StampajSvePDFCrtezeNaFormi_Binary"
Resume CleanUp

End Function

Private Sub cmdStampajSveCrteze_Click()
On Error GoTo Err_Point
    Dim retValOk As Boolean
    
    If MsgBox("Ovom akcijom æe se obraditi SVI prikazani crteži." & vbCrLf & _
              "Želite li da nastavite?", _
              vbQuestion + vbYesNo, "Štampa svih crteža") = vbNo Then
        Exit Sub
    End If

    retValOk = StampajSvePDFCrtezeNaFormi_Binary(Me, True) ' False = samo otvori PDF
    ' Call StampajSvePDFCrtezeNaFormi(Me, True) ' True = direktno štampaj

    Exit Sub

Err_Point:
    BBErrorMSG err, "cmdStampajSveCrteze_Click"
End Sub
Public Sub StampajPDFFajl(ByVal stPDFPath As String)
    Dim sh As Object
    Set sh = CreateObject("Shell.Application")
    sh.ShellExecute stPDFPath, "", "", "print", 0
End Sub

' === POZOVI OVO IZ Form_Open ili Form_Load ===
Public Sub PrimeniVidljivostKolonaPoStatusu(Optional ByVal vOpenArgs As Variant)
    On Error GoTo Err_Handler

    Dim st As String
    Dim lStatus As Long

    st = Nz(vOpenArgs, Nz(Me.OpenArgs, ""))
    lStatus = ParseStatusFromOpenArgs(st)

    ' --- OVDE UPISI NAZIVE KONTROLA (textbox + label) ---
    ' Odobreno (Saglasnost)
    Dim arrOdobr() As Variant
    arrOdobr = Array( _
        "PrimopredajuOdobrio", "lblPrimopredajuOdobrio", _
        "DatumOdobravanja", "lblDatumOdobravanja" _
    )

    ' Lansirano
    Dim arrLans() As Variant
    arrLans = Array( _
        "PrimopredajuLansirao", "lblPrimopredajuLansirao", _
        "DatumLansiranja", "lblDatumLansiranja" _
    )

    ' === LOGIKA PRIKAZA ===
    ' 0 = U obradi      -> sakrij i odobreno i lansirano
    ' 1 = Odobren      -> prikaži odobreno, sakrij lansirano
    ' 2 = Odbijen      -> sakrij oba (ili po želji prikaži odobreno ako hoæeš)
    ' 3 = Lansiran      -> prikaži lansirano (odobreno možeš i da prikažeš, ali ti si tražio samo lansirane kolone)
    ' -1 / 99 / prazno  -> prikaz svih -> prikaži sve
    Select Case lStatus
        Case 1 ' odobrene / saglasne
            SetControlsVisible True, arrOdobr
            SetControlsVisible False, arrLans

        Case 3 ' lansirane
            SetControlsVisible False, arrOdobr
            SetControlsVisible True, arrLans
            PomeriLansiraneNaMestoOdobrenih
            
        Case 0 ' u obradi
            SetControlsVisible False, arrOdobr
            SetControlsVisible False, arrLans

        Case 2 ' odbijene
            SetControlsVisible False, arrOdobr
            SetControlsVisible False, arrLans

        Case Else ' prikaz svih
            SetControlsVisible True, arrOdobr
            SetControlsVisible True, arrLans
    End Select

    Exit Sub

Err_Handler:
    ' ne ruši formu zbog vidljivosti; samo preskoèi
    Debug.Print "PrimeniVidljivostKolonaPoStatusu ERR " & err.Number & " - " & err.Description
End Sub

' === Helper: postavi Visible za listu kontrola ===
Private Sub SetControlsVisible(ByVal bVisible As Boolean, ByVal arrControls As Variant)
    Dim i As Long, ctlName As String

    For i = LBound(arrControls) To UBound(arrControls)
        ctlName = CStr(arrControls(i))
        If ControlExists(ctlName) Then
            Me.Controls(ctlName).Visible = bVisible
        End If
    Next i
End Sub

Private Function ControlExists(ByVal ControlName As String) As Boolean
    On Error GoTo Err_No
    Dim tmp As control
    Set tmp = Me.Controls(ControlName)
    ControlExists = True
    Exit Function
Err_No:
    ControlExists = False
End Function

' === Parsiranje statusa iz OpenArgs (tekstualno) ===
' Podržava:
'   "Obrada"
'   "Odobren"
'   "Odbijen"
'   "Lansiran"
'   ""  -> SVE
Private Function ParseStatusFromOpenArgs(ByVal s As String) As Long
    Dim t As String
    t = LCase(Trim(Nz(s, "")))

    If Len(t) = 0 Then
        ParseStatusFromOpenArgs = -1   ' SVE
        Exit Function
    End If

    Select Case t
        Case "obrada", "u obradi"
            ParseStatusFromOpenArgs = 0

        Case "odobren", "saglasan", "saglasnost"
            ParseStatusFromOpenArgs = 1

        Case "odbijen", "odbijeno"
            ParseStatusFromOpenArgs = 2

        Case "lansiran", "lansirano"
            ParseStatusFromOpenArgs = 3

        Case Else
            ParseStatusFromOpenArgs = -1 ' fallback = SVE
    End Select
End Function

Private Sub PomeriLansiraneNaMestoOdobrenih()
    On Error Resume Next

    Me!PrimopredajuLansirao.Left = Me!PrimopredajuOdobrio.Left
    Me!lblPrimopredajuLansirao.Left = Me!lblPrimopredajuOdobrio.Left

    Me!DatumLansiranja.Left = Me!DatumOdobravanja.Left
    Me!lblDatumLansiranja.Left = Me!lblDatumOdobravanja.Left

    On Error GoTo 0
End Sub

Public Sub NapuniListuStampaca(lst As ListBox)

    Dim prt As Printer

    lst.RowSourceType = "Value List"
    lst.RowSource = ""

    For Each prt In Application.Printers

        lst.AddItem prt.DeviceName & ";" & prt.DeviceName

    Next prt

End Sub

