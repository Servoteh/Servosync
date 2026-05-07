Attribute VB_Name = "_TEST_MOJ"
Option Compare Database
Option Explicit

Sub TestKreiranjaFoldera()
    Dim BaznaPutanja As String
    Dim BrojRadnogNaloga As String
    Dim NoviFolder As String

    BaznaPutanja = RNP.RootFolderDokumentacije
    BrojRadnogNaloga = "RN 2025/04\Specijalni-Test" ' primer sa problematiènim znakovima

    NoviFolder = KreirajFolderZaFajloveNaloga(BrojRadnogNaloga, "10", RNP.FolderTehnologa)

    MsgBox "Kreiran folder: " & vbCrLf & NoviFolder
End Sub
Public Function MoveFilesToFolders_ByOrder_JOIN() As Boolean
    Dim db       As DAO.Database
    Dim rs       As DAO.Recordset
    Dim fso      As Object
    Dim sSQL     As String
    
    Dim sLink        As String
    Dim sFileName    As String
    Dim strOrderNum  As String
    Dim strOperacija  As String
    Dim sFolderPath  As String
    Dim sNoviLink As String
    ' 1) Pripremimo SQL s JOIN-om preko tri tablice:
    sSQL = _
      "SELECT s.ID, s.LinkSlika, r.IdentBroj, sr.Operacija " & _
      "FROM tStavkeRNSlike AS s " & _
      "INNER JOIN tStavkeRN    AS sr ON s.IDStavkeRN = sr.IDStavkeRN " & _
      "INNER JOIN tRN          AS r  ON sr.IDRN       = r.IDRN " & _
      "WHERE s.LinkSlika IS NOT NULL;"
    
    Set db = CurrentDb
    Set rs = db.OpenRecordset(sSQL, dbOpenDynaset)
    Set fso = CreateObject("Scripting.FileSystemObject")
    
    Do While Not rs.EOF
        sLink = rs!LinkSlika                     ' puni path
        sFileName = fso.GetFileName(sLink)       ' npr. "123.jpg"
        strOrderNum = rs!IdentBroj               ' npr. "2025-0042"
        strOperacija = rs!Operacija
        ' 2) Sastavimo puni put foldera na temelju broja naloga
        'sFolderPath = "C:\MojiFolderi\" & strOrderNum
        
        ' 3) Kreiramo folder (vaša funkcija)
        'CreateFolder sFolderPath
        SacuvajSkicuNapomenuNaServer sLink, strOrderNum, strOperacija, RNP.FolderTehnologa, sNoviLink
        'KreirajFolderZaFajloveNaloga strOrderNum, strOperacija, RNP.FolderTehnologa
        
        ' 4) Premještamo datoteku
        On Error Resume Next
        fso.MoveFile Source:=sLink, _
                     Destination:=sNoviLink
        If err.Number <> 0 Then
            Debug.Print "Greška pri premještanju: " & err.Description
            err.Clear
        Else
            ' 5) Ažuriramo bazu (po želji)
            rs.Edit
            rs!LinkSlika = sNoviLink
            rs!ImeFajla = sFileName
            rs.Update
        End If
        On Error GoTo 0
        
        rs.MoveNext
    Loop
    
    ' 6) Èišæenje
    rs.Close:  Set rs = Nothing
    Set db = Nothing
    Set fso = Nothing
End Function

Public Sub PrikaziSveSlikeUBazi()
    Dim img As Object
    Dim i As Long
    Dim Poruka As String

    For Each img In CurrentProject.Images
        i = i + 1
        Poruka = Poruka & i & ". " & img.Name & vbCrLf
    Next

    MsgBox Poruka, vbInformation, "Slike u bazi"
End Sub
Public Sub TestSlika()
    On Error GoTo NePostoji
    Dim img As Object
    Set img = CurrentProject.Images("ikonicaPreuzimanja")
    MsgBox "Slika pronaðena!", vbInformation
    Exit Sub
NePostoji:
    MsgBox "Slika nije pronaðena.", vbExclamation
End Sub
Public Function TESTProveraRecordSourca() As Boolean
    
    Dim retValOk As Boolean
    retValOk = True
    Dim frm As AccessObject
    Dim f As Form
    Dim src As String
    
    For Each frm In CurrentProject.AllForms
        DoCmd.OpenForm frm.Name, acDesign, , , , acHidden
        Set f = Forms(frm.Name)
        
        src = Nz(f.RecordSource, "")
        Debug.Print frm.Name & " --> " & src
        
        DoCmd.Close acForm, frm.Name, acSaveNo
    Next

        
    TESTProveraRecordSourca = retValOk


End Function
