VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_UnosZahtevaZaNabavku"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit


Private Sub CmbPronadji_AfterUpdate()
    Me.DataEntry = False
    DoCmd.GoToControl "IDZahtevaZaNabavku"
    DoCmd.FindRecord Me![CmbPronadji]
    Me![CmbPronadji] = Null
    DoCmd.GoToControl "CmbPronadji"

End Sub

Private Sub DugmeNoviZahtev_Click()
On Error GoTo Err_DugmeNoviZahtev_Click


    DoCmd.GoToRecord , , acNewRec
    Me!BrojZahteva = OdrediSledeciBrojZahteva
    DoCmd.GoToControl "Opis"
    
Exit_DugmeNoviZahtev_Click:
    Exit Sub

Err_DugmeNoviZahtev_Click:
    MsgBox err.Description
    Resume Exit_DugmeNoviZahtev_Click
    
End Sub

Private Sub DugmePosaljiMail_Click()
    BBMail_OtvoriFormuZaSlanjeSpecifikacijeNabavke
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
    If IsLoaded("ZahteviZaNabavku") Or IsLoaded("PregledUpitaZaDobavljace") Then
        ' Prikazi
    Else
        Me.DataEntry = True
    
        If IsLoaded("Prva Maska") Then
            Me!DugmeKreirajUpit.Enabled = True
        Else
            Me!DugmeKreirajUpit.Enabled = False
        End If
        'DoCmd.GoToRecord , , acLast
        'DoCmd.GoToControl "CmbPronadji"
        'DugmeNoviZahtev_Click
    End If
End Sub
Private Sub DugmeKreirajUpit_Click()
On Error GoTo Err_DugmeNapraviIzlazniDok_Click
'On Error Resume Next

    If Nz(Me!IDZahtevaZaNabavku, 0) = 0 Then
     MsgBox "Izaberite dokument Specifikacije.", vbCritical, "BigBit"
     Exit Sub
    End If
    
    If Nz(DLookup("[CountOfIDStavke]", "SpecifikacijaBrojStavki"), 0) = 0 Then
     MsgBox "Dokument Specifikacije nabavke je bez stavki.", vbCritical, "BigBit"
     Exit Sub
    End If
        
        KreirajTmpTabeluUTmpBazi "tmp_UpitDobavljacu", "UpitNabavkeZa_tmp_table"
        'DoCmd.OpenForm "KreirajUpitZaDobavlaca"
        DoCmd.OpenForm "ProknjiziStavkeNabavkeUUpit"
        Forms![ProknjiziStavkeNabavkeUUpit]!IDZahtevaZaNabavku = Forms![UnosZahtevaZaNabavku]![IDZahtevaZaNabavku]
        Forms![ProknjiziStavkeNabavkeUUpit]!Opis = Forms![UnosZahtevaZaNabavku]![Opis]
        Forms![ProknjiziStavkeNabavkeUUpit]!DatumZahteva = Forms![UnosZahtevaZaNabavku]![DatumZahteva]
        Forms![ProknjiziStavkeNabavkeUUpit]!IDPredmetDok = Forms![UnosZahtevaZaNabavku]![IDPredmetDok]
        Forms![ProknjiziStavkeNabavkeUUpit]!SifraProdavca = Forms![UnosZahtevaZaNabavku]![InicijatorZahteva]
        Forms![ProknjiziStavkeNabavkeUUpit]!Napomena = Forms![UnosZahtevaZaNabavku]![Napomena]
        Forms![ProknjiziStavkeNabavkeUUpit]!IDPredmetDok.Requery
        Forms![ProknjiziStavkeNabavkeUUpit]!SifraProdavca.Requery
        Forms![ProknjiziStavkeNabavkeUUpit].Requery
        
        Forms![ProknjiziStavkeNabavkeUUpit]!IzZahtevaIDZahteva = Forms![UnosZahtevaZaNabavku]![IDZahtevaZaNabavku]
      

Exit_DugmeNapraviIzlazniDok_Click:
    Exit Sub

Err_DugmeNapraviIzlazniDok_Click:
    MsgBox err.Description
    Resume Exit_DugmeNapraviIzlazniDok_Click
    
End Sub
Private Sub DugmePrint_Click()
On Error GoTo Err_DugmePrint_Click

    Dim stDocName As String

    stDocName = "SpecifikacijaZaNabavku"
    DoCmd.OpenReport stDocName, acPreview

Exit_DugmePrint_Click:
    Exit Sub

Err_DugmePrint_Click:
    MsgBox err.Description
    Resume Exit_DugmePrint_Click
    
End Sub

'–– U VBA editoru: Tools › References › oznaèi “Microsoft DAO Object Library”
Public Function OdrediSledeciBrojZahteva(Optional ByVal YearParam As Variant) As String
    On Error GoTo ErrHandler

    Dim db        As DAO.Database
    Dim rst       As DAO.Recordset
    Dim sql       As String
    Dim yearValue As String
    Dim maxNum    As Long
    Dim nextNum   As Long

    ' 1) Godina iz parametra ili tekuca godina
    If IsMissing(YearParam) Or IsNull(YearParam) Then
        yearValue = CStr(Year(Date))
    Else
        yearValue = CStr(YearParam)
    End If

    Set db = CurrentDb

    ' 2) SQL: uzmi najveæi Seq dio (pre slash) za tu godinu
    sql = _
      "SELECT TOP 1 " & _
      "  Val(Left([BrojZahteva], InStr([BrojZahteva],'/')-1)) AS Seq " & _
      "FROM EXT_ZahteviZaNabavku " & _
      "WHERE Right([BrojZahteva],4) = '" & yearValue & "' " & _
      "ORDER BY Val(Left([BrojZahteva], InStr([BrojZahteva],'/')-1)) DESC;"

    Set rst = db.OpenRecordset(sql, dbOpenSnapshot)

    If rst.EOF Then
        maxNum = 0
    Else
        maxNum = Nz(rst!seq, 0)
    End If

    rst.Close
    Set rst = Nothing
    Set db = Nothing

    ' 3) Sledeci broj je max+1, formatiraj na 4 cifre
    nextNum = maxNum + 1
    OdrediSledeciBrojZahteva = Format(nextNum, "0000") & "/" & yearValue
    Exit Function

ErrHandler:
    MsgBox "Greška u OdrediSledeciBrojZahteva: " & err.Number & " – " & err.Description, vbCritical
    OdrediSledeciBrojZahteva = ""
End Function


Private Sub DugmePrepisiStavke_Click()
On Error GoTo Err_DugmePrepisiStavke_Click

    Dim stDocName As String
    Dim stLinkCriteria As String
    
    If IsNull(Me!IDZahtevaZaNabavku) Or Me!IDZahtevaZaNabavku = 0 Then
        MsgBox "Zaglavlje nije kreirano!", vbExclamation
        Exit Sub
    End If
    
    If IsNull(Me!Opis) Or Me!Opis = 0 Then
        MsgBox "Zaglavlje nije kreirano!", vbExclamation
        Exit Sub
    End If
    
    stDocName = "IzborSpecifikacijeNabavkeZaPrepisivanje"
    DoCmd.OpenForm stDocName, , , stLinkCriteria
    
Exit_DugmePrepisiStavke_Click:
    Exit Sub

Err_DugmePrepisiStavke_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiStavke_Click
    
End Sub
Private Sub DugmeUpisiDobavljacaUSveStavke_Click()
On Error GoTo Err_DugmeUpisiMagacinUSveStavke_Click

    Dim stDocName As String
    Dim stPitanje As String
    
    If Nz(Me.Dobavljac, -1) = -1 Then
        MsgBox "Morate izabrati dobavljaca.", vbExclamation
        DoCmd.GoToControl "Dobavljac"
        Exit Sub
    End If
    
    If Nz(DCount("*", "EXT_SpecifikacijaZahtevaNabavke", "IDZahtevaZaNabavku = " & Me!IDZahtevaZaNabavku), 0) = 0 Then
        MsgBox "Morate da imati stavke u dokumentu.", vbExclamation
        DoCmd.GoToControl "Dobavljac"
        Exit Sub
    End If
    
    stPitanje = "Koriscenjem ove opcije u svaku stavku" & vbCrLf
    stPitanje = stPitanje & "upisacete definisanog dobavljaca." & vbCrLf & vbCrLf
    stPitanje = stPitanje & "Da li zaista nastavljate proces?"
    
    If Not BBPitanje(stPitanje, vbDefaultButton2) Then
     Exit Sub
    End If
    
    On Error Resume Next
    DoCmd.RunCommand acCmdSaveRecord
    On Error GoTo Err_DugmeUpisiMagacinUSveStavke_Click
    
    DoCmd.SetWarnings False
    stDocName = "Nabavka_UpisiDobavljacaUStavke"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    Me.SpecifikacijaZahtevaZaNabavku.Requery
    MsgBox "Promenjen je dobavljac na svim stavkama", , "BigBit"

Exit_DugmeUpisiMagacinUSveStavke_Click:
    DoCmd.SetWarnings True
    Exit Sub

Err_DugmeUpisiMagacinUSveStavke_Click:
    MsgBox err.Description
    Resume Exit_DugmeUpisiMagacinUSveStavke_Click
    
End Sub

