VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_SpremiNacrtPrimopredaje"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Sub PopuniRecordSource()
On Error GoTo Err_Point
    Dim rstNacrt As ADODB.Recordset
    Dim stSQL As String
    Dim SifraRadnika As Long
    
    SifraRadnika = IDRadnikZaCurrentUser

    stSQL = "SELECT IDNacrtPrim, DatumNacrta, BrojPredmeta, BrojKomada, Komitenti.Naziv AS NazivKomitenta, TipNacrta, IDGlavniCrtez"
    stSQL = stSQL & " FROM NacrtPrimopredaje INNER JOIN Predmeti ON NacrtPrimopredaje.IDPredmet = Predmeti.IDPredmet"
    stSQL = stSQL & " INNER JOIN Komitenti ON Komitenti.Sifra = Predmeti.IDKomitent"
    stSQL = stSQL & " WHERE (IDProjektant = " & SifraRadnika & ")"
    stSQL = stSQL & " AND (IDStatusNacrtaPrimopredaje = " & 0 & ")"
    
    Set rstNacrt = ADO_GetRST(BBCFG.CNNString, stSQL)
    
    Select Case BrojOtvorenihZaglavljaNacrta()
        Case 0
            Me!DugmeDodajUNacrt.Caption = "Otvori novi nacrt"
            Me!DugmeDodajUNacrt.Picture = "C:\SHARES\Servoteh\QBigTehn\Ikone\add-document.png"
            Me!PrimopredajaBrojRN = Null
            Me!PrimopredajaKomitent = Null
            Me!PrimopredajaBrojNacrta = Null
            Me!PrimopredajaBrojKomada = Null
            Me!PrimopredajaTipNacrta = Null
            Me!PrimopredajaIDGlavniCrtez = Null
            Me!DugmeNacrtDetaljno.Enabled = False
        Case 1
            Me!DugmeDodajUNacrt.Caption = "Dodaj crteže u nacrt" '& vbCrLf & "za primopredaju"
            Me!DugmeDodajUNacrt.Picture = "C:\SHARES\Servoteh\QBigTehn\Ikone\file-import.png"
            PostaviKomboPolje
            Me!PrimopredajaBrojRN = rstNacrt!BrojPredmeta
            Me!PrimopredajaKomitent = rstNacrt!NazivKomitenta
            Me!PrimopredajaBrojNacrta = rstNacrt!IDNacrtPrim
            Me!PrimopredajaBrojKomada = rstNacrt!BrojKomada
            Me!PrimopredajaTipNacrta = rstNacrt!TipNacrta
            Me!PrimopredajaIDGlavniCrtez = rstNacrt!IDGlavniCrtez
            Me!DugmeNacrtDetaljno.Enabled = True
            Me!DugmeNacrtDetaljno.Picture = "C:\SHARES\Servoteh\QBigTehn\Ikone\edit.png"
        Case Else
            Me!DugmeDodajUNacrt.Caption = "Izaberi nacrt" '& vbCrLf & "dodaješ crtež"
            Me!DugmeDodajUNacrt.Picture = ""
            PostaviKomboPolje
            Me!PrimopredajaBrojNacrta.Locked = False
            Me!PrimopredajaBrojNacrta.SetFocus
    End Select
    
Exit_Point:
    Exit Sub

Err_Point:
    MsgBox Error$
    Resume Exit_Point

End Sub
Private Sub PostaviKomboPolje()
On Error GoTo Err_Point
    Dim ctl As ComboBox
    Dim stSQL As String
    
    Set ctl = Me!PrimopredajaBrojNacrta
    stSQL = "SELECT NacrtPrimopredaje.IDNacrtPrim, NacrtPrimopredaje.BrojNacrta, " & _
            "NacrtPrimopredaje.DatumNacrta, Predmeti.BrojPredmeta " & _
            "FROM NacrtPrimopredaje INNER JOIN Predmeti ON NacrtPrimopredaje.IDPredmet = Predmeti.IDPredmet " & _
            "WHERE IDProjektant=" & IDRadnikZaCurrentUser & " AND IDStatusNacrtaPrimopredaje=0 " & _
            "ORDER BY DatumNacrta;"

    With ctl
        .RowSourceType = "Table/Query"
        .RowSource = stSQL
        .ColumnCount = 4
        .BoundColumn = 1                 ' vraæa IDNacrtPrim kao Value
        .ColumnWidths = "0cm;2cm;2cm;2cm" ' sakrij ID, prikaži BrojNacrta itd.
        .Requery
    End With
Exit_Point:
    Exit Sub
Err_Point:
    BBErrorMSG err, "PostaviKomboPolje"
    Resume Exit_Point
End Sub
Private Sub DugmeDodajUNacrt_Click()
On Error GoTo Err_Point
    Dim stSQL As String
    Dim IDNacrtPrim As Long
    Dim IDCrtez As Long
    Dim TipNacrta As Integer
    Dim BrojKomada As Integer
    IDNacrtPrim = Nz(Me!PrimopredajaBrojNacrta, 0)
    IDCrtez = Nz(Forms![PDMCrteziPregled]![IDCrtez], 0)
    TipNacrta = Nz(Me!PrimopredajaTipNacrta, -1)
    BrojKomada = Nz(Me!PrimopredajaBrojKomada, 0)
    '***********************************************************
    ' --- Provera da li je izabrani crtež najnovija revizija ---
    Dim rs As ADODB.Recordset
    Dim BrojCrteza As String
    Dim Revizija As String
    Dim NajRevizija As String
    
    ' 1) Uzmi broj crteža i reviziju iz selektovanog IDCrtez
    stSQL = "SELECT BrojCrteza, Revizija FROM PDMCrtezi WHERE IDCrtez=" & IDCrtez
    Set rs = ADO_GetRST(BBCFG.CNNString, stSQL, adLockReadOnly, adUseClient, adOpenForwardOnly)
    
    If rs.EOF Then
        MsgBox "Nepostojeæi crtež!", vbCritical
        GoTo Exit_Point
    End If
    
    BrojCrteza = rs!BrojCrteza & ""
    Revizija = rs!Revizija & ""
    rs.Close
    Set rs = Nothing
    
    ' 2) Najnovija revizija za taj broj crteža
    stSQL = "SELECT MAX(Revizija) AS NajRev FROM PDMCrtezi WHERE BrojCrteza='" & BrojCrteza & "'"
    Set rs = ADO_GetRST(BBCFG.CNNString, stSQL, adLockReadOnly, adUseClient, adOpenForwardOnly)
    
    If Not rs.EOF Then
        NajRevizija = rs!NajRev & ""
    End If
    rs.Close
    Set rs = Nothing
    
    ' 3) Uporedi
    If Revizija <> NajRevizija Then
        MsgBox "Izabrani crtež NIJE najnovija revizija (trenutna: " & Revizija & _
               ", najnovija: " & NajRevizija & ").", vbExclamation
        GoTo Exit_Point
    End If
    ' --- kraj provere ---

    
    If BrojOtvorenihZaglavljaNacrta() = 1 Then
        'DodajCrtezUNacrt IDNacrtPrim, IDCrtez, TipNacrta, BrojKomada
        DodajCrtezUNacrt IDNacrtPrim, IDCrtez, TipNacrta
    ElseIf BrojOtvorenihZaglavljaNacrta() = 0 Then
        BBOpenForm "NacrtPrimopredaje", , , , acFormAdd, , "Nacrt"
    Else
        If IDNacrtPrim <> 0 And BrojKomada <> 0 And IDCrtez <> 0 And TipNacrta <> -1 Then
            'DodajCrtezUNacrt IDNacrtPrim, IDCrtez, TipNacrta, BrojKomada
            DodajCrtezUNacrt IDNacrtPrim, IDCrtez, TipNacrta
        End If
    End If
    
Exit_Point:
    Exit Sub

Err_Point:
    MsgBox Error$
    Resume Exit_Point

End Sub

Private Sub DugmeNacrtDetaljno_Click()
    Dim stLinkCriteria As String
   
    stLinkCriteria = "[IDNacrtPrim] = " & Me!PrimopredajaBrojNacrta
    BBOpenForm "NacrtPrimopredaje", , , stLinkCriteria, , , "Nacrt"
End Sub

Private Sub Form_Load()
    PopuniRecordSource
End Sub


Private Sub PrimopredajaBrojKomada_AfterUpdate()
    Call ADO_UpdateColumn(CNN_CurrentDataBase, "NacrtPrimopredaje", "BrojKomada", "'" & CStr(Nz(Me!PrimopredajaBrojKomada, 1)) & "'", "IDNacrtPrim = " & CStr(Me!PrimopredajaBrojNacrta))
End Sub

Private Sub PrimopredajaBrojNacrta_AfterUpdate()
    'Dim id As Long
    'id = Nz(Me!PrimopredajaBrojNacrta.Value, 0)
    Dim ID As Long
    ID = Nz(Me!PrimopredajaBrojNacrta.Column(0), 0) ' 0 = IDNacrtPrim

    If ID = 0 Then Exit Sub

    Dim stSQL As String
    stSQL = "SELECT IDNacrtPrim, DatumNacrta, BrojPredmeta, BrojKomada, Komitenti.Naziv AS NazivKomitenta, TipNacrta, IDGlavniCrtez " & _
            "FROM (NacrtPrimopredaje INNER JOIN Predmeti ON NacrtPrimopredaje.IDPredmet=Predmeti.IDPredmet) " & _
            "INNER JOIN Komitenti ON Komitenti.Sifra=Predmeti.IDKomitent " & _
            "WHERE IDNacrtPrim=" & ID

    Dim rs As ADODB.Recordset
    Set rs = ADO_GetRST(BBCFG.CNNString, stSQL)
    If rs.EOF Then Exit Sub

    Me!DugmeDodajUNacrt.Caption = "Dodaj crteže u nacrt primopredaje"
    Me!DugmeDodajUNacrt.Picture = "C:\SHARES\Servoteh\QBigTehn\Ikone\file-import.png"
    Me!PrimopredajaKomitent = Nz(rs!NazivKomitenta, "")
    Me!PrimopredajaBrojKomada = Nz(rs!BrojKomada, 0)
    Me!PrimopredajaBrojRN = Nz(rs!BrojPredmeta, "")
    Me!PrimopredajaBrojRN = Nz(Me!PrimopredajaBrojNacrta.Column(0), 0)
    Me!PrimopredajaTipNacrta = rs!TipNacrta
    Me!PrimopredajaIDGlavniCrtez = rs!IDGlavniCrtez
    rs.Close: Set rs = Nothing
End Sub

Private Sub PrimopredajaBrojNacrta_GotFocus()
    PostaviKomboPolje
    Me!PrimopredajaBrojNacrta.Requery
End Sub
Public Function OsveziPrikaz()
    PopuniRecordSource
End Function
