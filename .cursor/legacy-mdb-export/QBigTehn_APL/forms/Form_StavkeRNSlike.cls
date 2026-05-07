VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_StavkeRNSlike"
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
    dlgOpenFile.ButtonName = "Izaberi sliku"
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


        Me!Slika.Picture = Nz(Me!LinkSlika, "")

Exit_PrikaziSliku:
    Exit Sub

Err_PrikaziSliku:
    MsgBox err.Description
    Me!Slika.Picture = ""
    Resume Exit_PrikaziSliku
    
End Sub
Private Sub Form_BeforeUpdate(Cancel As Integer)
    Me!IDStavkeRN = [Forms]![UnosRN]![Podforma].[Form]![IDStavkeRN]
End Sub

Private Sub Form_Current()
    PrikaziSliku
End Sub

Private Sub Form_Open(Cancel As Integer)
    Dim Operacija As String
    Dim RJgrupaRC As String
    Dim OpisRada As String
    Operacija = DLookup("Operacija", "tStavkeRN", "IDStavkeRN =" & [Forms]![UnosRN]![Podforma].[Form]![IDStavkeRN])
    RJgrupaRC = DLookup("RJgrupaRC", "tStavkeRN", "IDStavkeRN =" & [Forms]![UnosRN]![Podforma].[Form]![IDStavkeRN])
    OpisRada = DLookup("OpisRada", "tStavkeRN", "IDStavkeRN =" & [Forms]![UnosRN]![Podforma].[Form]![IDStavkeRN])
    Me.Caption = "Broj operacije: " & Operacija & " - " & RJgrupaRC & " - " & OpisRada
End Sub

Private Sub LinkSlika_AfterUpdate()
    PrikaziSliku
End Sub

Private Sub LinkSlika_DblClick(Cancel As Integer)
    'On Error Resume Next
On Error GoTo Err_Point

    Dim LinkSlika As String
    Dim IzabraniLinkSlike As String
    Dim novoImeFajla As String
    Dim fName As String
    'LinkSlika = IzaberiSliku(Me!LinkSlika)
    IzabraniLinkSlike = IzaberiSliku(Me!LinkSlika)
    '****************************
    If Nz(IzabraniLinkSlike, "") <> "" Then
        If SacuvajSkicuNapomenuNaServer(IzabraniLinkSlike, Me!ZaIdentBroj, Me!ZaOperacija, RNP.FolderTehnologa, novoImeFajla) Then
            LinkSlika = novoImeFajla
        End If
    Else
        MsgBox "Fajl nije izabran"
    End If
    '*****************************
    If Nz(LinkSlika, "") <> "" Then
        Me!LinkSlika = LinkSlika
        Me!Slika.Picture = Nz(Me!LinkSlika, "")
        fName = LinkSlika
        While InStr(1, fName, "\") <> 0
            fName = Right$(fName, Len(fName) - InStr(1, fName, "\"))
        Wend
        Me!ImeFajla = fName
        DoCmd.RunCommand acCmdSaveRecord
    End If

Exit_Point:
    Exit Sub

Err_Point:
    MsgBox err.Description
    cmdDeleteFile LinkSlika, True
    DoCmd.RunCommand acCmdUndo
    Resume Exit_Point
End Sub
Private Sub DugmeObrisiLink_Click()
On Error GoTo Err_DugmeObrisiLink_Click

    cmdDeleteFile Me!LinkSlika

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
Private Function cmdDeleteFile(sFilePath As String, Optional Silent As Boolean = False) As Boolean
On Error GoTo Err_Point
'Silent = true -> Nema poruka
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
    If Not Silent Then
        If MsgBox("Jeste li sigurni da želite obrisati fajl:" & vbCrLf & sFileName, _
                  vbYesNo + vbQuestion, "Potvrda brisanja") <> vbYes Then
            Exit Function
        End If
    End If
    ' 4) Brisanje fajla
    On Error GoTo Err_Point
        ' Opcija A: Kill
        Kill sFilePath
        
        ' Opcija B (alternativa, ne morate koristiti ako Kill radi):
        'Set fso = CreateObject("Scripting.FileSystemObject")
        'fso.DeleteFile sFilePath, True
        DoCmd.RunCommand acCmdSelectRecord
        DoCmd.RunCommand acCmdDeleteRecord

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


