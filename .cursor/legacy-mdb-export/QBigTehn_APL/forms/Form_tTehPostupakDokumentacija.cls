VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_tTehPostupakDokumentacija"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function IzaberiSliku(original) As String
    Dim dlgOpenFile As FileDialog
    Dim ImeFajla As String
    
    ImeFajla = Nz(original, "")
    Set dlgOpenFile = Application.FileDialog(msoFileDialogOpen)
    dlgOpenFile.Title = "QBigTehn"
    dlgOpenFile.ButtonName = "Izaberi fajl"
    dlgOpenFile.InitialFileName = ImeFajla
    dlgOpenFile.InitialView = msoFileDialogViewDetails
    
    If dlgOpenFile.Show Then
        ImeFajla = dlgOpenFile.SelectedItems(1)
    Else
        ImeFajla = ""
    End If
    
    Set dlgOpenFile = Nothing
    IzaberiSliku = ImeFajla
End Function
Private Sub PrikaziSliku()
On Error GoTo Err_PrikaziSliku

    'Me!Slika.Picture = Nz(Me!LinkSlika, "")
     Dim sPDF As String
    sPDF = Nz(Me!LinkFajla, "")
    If Len(sPDF) > 0 Then
        Me!wbPDFViewer.Navigate sPDF
    Else
        Me!wbPDFViewer.Navigate "about:blank"
    End If
    
Exit_PrikaziSliku:
    Exit Sub

Err_PrikaziSliku:
    MsgBox err.Description
    Resume Exit_PrikaziSliku
    
End Sub
Private Sub Form_BeforeUpdate(Cancel As Integer)
    Me!IDPostupka = BBTehn.IDPostupka
End Sub

Private Sub Form_Current()
    PrikaziSliku
End Sub

Private Sub Form_Open(Cancel As Integer)
    Dim Operacija As String
    Dim RJgrupaRC As String
    Dim OpisRada As String
    Operacija = BBTehn.Operacija
    RJgrupaRC = BBTehn.RJgrupaRC
    Me.Caption = "Broj operacije: " & Operacija & " - " & RJgrupaRC ' & " - " & OpisRada
End Sub

Private Sub LinkFajla_AfterUpdate()
    PrikaziSliku
End Sub

Private Sub LinkFajla_DblClick(Cancel As Integer)
    'On Error Resume Next
    Dim LinkSlika As String
    Dim IzabraniLinkSlike As String
    Dim novoImeFajla As String
    Dim fName As String
    'LinkSlika = IzaberiSliku(Me!LinkSlika)
    IzabraniLinkSlike = IzaberiSliku(Me!LinkFajla)
    '****************************
    If Nz(IzabraniLinkSlike, "") <> "" Then
        If SacuvajSkicuNapomenuNaServer(IzabraniLinkSlike, Me!ZaIdentBroj, Me!ZaOperacija, RNP.FolderKontrole, novoImeFajla) Then
            LinkSlika = novoImeFajla
        End If
    Else
        MsgBox "Fajl nije izabran"
    End If
    '*****************************
    If Nz(LinkSlika, "") <> "" Then
        Me!LinkFajla = LinkSlika
        'Me!Slika.Picture = Nz(Me!LinkSlika, "")
        fName = LinkSlika
        While InStr(1, fName, "\") <> 0
            fName = Right$(fName, Len(fName) - InStr(1, fName, "\"))
        Wend
        Me!ImeFajla = fName
        PrikaziSliku
        DoCmd.RunCommand acCmdSaveRecord
    End If
End Sub
Private Sub DugmeObrisiLink_Click()
On Error GoTo Err_DugmeObrisiLink_Click

    'cmdDeleteFile Me!LinkFajla
    ObrisiPDF
    
Exit_DugmeObrisiLink_Click:
    Exit Sub

Err_DugmeObrisiLink_Click:
    MsgBox err.Description
    Resume Exit_DugmeObrisiLink_Click
    
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
Private Function cmdDeleteFile(sFilePath As String) As Boolean
On Error GoTo Err_Point

    Dim sFileName As String
    Dim fso As Object

    ' 1) Uèitaj putanju iz polja forme
    sFileName = Nz(Me!ImeFajla, "")
    
    If sFilePath = "" Then
        MsgBox "Putanja do fajla nije definisana.", vbExclamation, "Brisanje fajla"
        Exit Function
    End If
    
    ' 2) Provjera postoji li fajl
    If Dir(sFilePath) = "" Then
        MsgBox "Fajl ne postoji:" & vbCrLf & sFilePath, vbExclamation, "Brisanje fajla"
        Exit Function
    End If
    
    ' 3) Potvrda od korisnika
    If MsgBox("Jeste li sigurni da želite obrisati fajl:" & vbCrLf & sFileName, _
              vbYesNo + vbQuestion, "Potvrda brisanja") <> vbYes Then
        Exit Function
    End If
    
    ' 4) Brisanje fajla
    On Error GoTo Err_Point
        ' Opcija A: Kill
        DoCmd.RunCommand acCmdSelectRecord
        DoCmd.RunCommand acCmdDeleteRecord
        Call BBTSMovePreviousRecord
        Kill sFilePath
        
        ' Opcija B (alternativa, ne morate koristiti ako Kill radi):
        'Set fso = CreateObject("Scripting.FileSystemObject")
        'fso.DeleteFile sFilePath, True
        
        MsgBox "Fajl je uspješno obrisan.", vbInformation, "Brisanje fajla"
        
        ' Po želji obrišite i referencu u polju forme:
        'Me!txtFilePath = Null
        
    Exit Function

Exit_Point:
    Exit Function

Err_Point:
    'MsgBox err.Description
    MsgBox "Greška pri brisanju fajla:" & vbCrLf & err.Description, _
           vbCritical, "Brisanje fajla"
    Resume Exit_Point
    
End Function

Private Function ObrisiPDF() As Boolean
    Dim sFajl As String
    
    sFajl = Nz(Me.LinkFajla, "")
    If Len(Dir(sFajl)) = 0 Then
        MsgBox "Fajl ne postoji: " & sFajl, vbExclamation
        Exit Function
    End If

    ' 1) Uèitaj prazno u WebBrowser (oslobodi plugin/handle)
    Me.wbPDFViewer.Navigate "about:blank"
    
    ' 2) Saèekaj da se navigacija završi i oslobodi fajl
    Do While Me.wbPDFViewer.ReadyState <> 4  ' 4 = READYSTATE_COMPLETE
        DoEvents
    Loop
    'Wait Now + TimeValue("0:00:01")
    
    ' 3) Obriši fajl
    On Error Resume Next
    Kill sFajl
    If err.Number <> 0 Then
        MsgBox "Greška pri brisanju fajla:" & vbCrLf & err.Description, vbCritical
    Else
        MsgBox "Fajl je uspešno obrisan.", vbInformation
        'Me.LinkFajla = ""  ' oèistite Path polje
        DoCmd.RunCommand acCmdSelectRecord
        DoCmd.RunCommand acCmdDeleteRecord
    End If
    On Error GoTo 0
End Function

