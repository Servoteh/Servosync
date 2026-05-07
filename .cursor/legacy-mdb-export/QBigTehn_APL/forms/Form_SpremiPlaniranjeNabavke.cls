VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_SpremiPlaniranjeNabavke"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub DugmeKreirajPlanNabavke_Click()
    On Error GoTo Err_Point
    Dim stSQL As String
    Dim IDPredmet As Long
    Dim IDCrtez As Long
    Dim SifraRadnika As Long
    Dim BrojKomada As Integer
    Dim IDPlan As Long
    Dim stLinkCriteria As String
    
    IDPredmet = Nz(Me!IDPredmet, 0)
    IDCrtez = Nz(Forms![PDMCrteziPregled]![IDCrtez], 0)
    BrojKomada = Nz(Me!BrojKomadaSklopa, 0)
    SifraRadnika = Nz(Me!SifraRadnika, 0)
    
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
    
    Set rs = ADO_GetRSTFromUDFT(CNN_CurrentDataBase, "dbo.ftBOMNabavniDeloviKolicine", IDCrtez)

    ' --- Provera da li postoji bar jedan slog ---
    If rs Is Nothing Or rs.EOF Then
        MsgBox "Za izabrani sklop ne postoje nabavni delovi." & vbCrLf & _
               "Planiranje nabavke nije moguæe.", vbInformation
        rs.Close
        Set rs = Nothing
        Exit Sub
    End If
    
    rs.Close
    Set rs = Nothing
    
    If KreirajDokumentPlaniranjaNabavke(IDPredmet, IDCrtez, BrojKomada, SifraRadnika, IDPlan) Then
        Call UpisiPotpisAkoJePrazan(IDPlan)
        Call UpdatePlaniranjeStavke_SifraArtikla_Zalihe(IDPlan)
        MsgBox "Dokument planiranja nabavke gotovih delova je kreiran"
        stLinkCriteria = "[IDPlan] = " & IDPlan
        BBOpenForm "PlaniranjeNabavke", , , stLinkCriteria
    End If
    
Exit_Point:
    Exit Sub

Err_Point:
    MsgBox Error$
    Resume Exit_Point

End Sub

Private Sub Form_Load()
    Me!SifraRadnika = IDRadnikZaCurrentUser()
    Me!SifraRadnika.Requery
End Sub

