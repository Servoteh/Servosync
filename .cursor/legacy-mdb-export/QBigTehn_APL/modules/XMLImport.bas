Attribute VB_Name = "XMLImport"
Option Compare Database
Option Explicit
'Public Const CNN_CurrentDataBase = "DRIVER=SQL Server;SERVER=MEGABAYT\SQLEXPRESS;Trusted_Connection=Yes;APP=QBigBit_Negovan(MEGABAYT\Vasa);DATABASE=QBigTehn"
'Public Const CNN_CurrentDataBase = "DRIVER=SQL Server;SERVER=tcp:Vasa-SQL,5765;UID=QBigTehn;PWD=QbigTehn.9496;APP=QBigTehn;DATABASE=QBigTehn"
'Public Const F_PDM_XMLFolder = "C:\PDMExport\XML\"
'Public Const F_PDM_XMLFolderImportovano = "C:\PDMExport\Importovano\"
'Public Const F_PDM_XMLFolderNeuspelo = "C:\PDMExport\Neuspelo\"
Public Function Autoexec_PokreniParsiranje() As Boolean
On Error GoTo Err_Point
    ' Pozove tvoju glavnu proceduru
    DoCmd.OpenForm "PrvaMaska"
    WriteToLog "Pokrenuto parsiranje XML fajlova."
    
    ' ... tvoj kod za parsiranje ...
    If PokreniParsiranje() Then
        ' Ako je parsiranje prošlo OK, izaği iz Access-a
        WriteToLog "Parsiranje završeno bez greške."
        DoCmd.Quit acQuitSaveNone
        Autoexec_PokreniParsiranje = True
    Else
        WriteToLog "GREŠKA: " & err.Number & " - " & err.Description
        DoCmd.Quit acQuitSaveNone
        'MsgBox "Parsiranje nije uspelo, proveri Neuspelo folder.", vbExclamation
        Autoexec_PokreniParsiranje = False
    End If

Exit_Point:
    Exit Function
    
Err_Point:
    WriteToLog "GREŠKA: " & err.Number & " - " & err.Description
    Resume Exit_Point
End Function
Public Function PokreniParsiranje(Optional ByVal sortByCreation As Boolean = False, _
                                  Optional ByVal sortAscending As Boolean = True) As Boolean
    Dim fso        As Object
    Dim FolderPath As String
    Dim folder     As Object
    Dim fFile      As Object
    Dim xmlDoc     As Object
    Dim currentPath As String
    Dim fileList() As Object
    Dim fileCount As Long
    Dim i As Long

    On Error GoTo GlobalError
    PokreniParsiranje = False

    ' Folder u kojem su XML fajlovi
    FolderPath = F_PDM_XMLFolder   ' npr. "C:\PDMExport\XML\"

    Set fso = CreateObject("Scripting.FileSystemObject")
    If Not fso.FolderExists(FolderPath) Then
        MsgBox "Ulazni folder ne postoji: " & FolderPath, vbExclamation
        GoTo CleanUp
    End If
    Set folder = fso.GetFolder(FolderPath)

    ' 1. Skupi XML fajlove u niz
    fileCount = 0
    For Each fFile In folder.Files
        If LCase(fso.GetExtensionName(fFile.Name)) = "xml" Then
            fileCount = fileCount + 1
            ReDim Preserve fileList(1 To fileCount)
            Set fileList(fileCount) = fFile
        End If
    Next fFile

    ' 2. Sortiraj po datumu
    If fileCount > 1 Then
        Call SortFileArray(fileList, sortByCreation, sortAscending)
    End If

    ' 3. Obradi fajlove redom
    For i = 1 To fileCount
        Set fFile = fileList(i)
        currentPath = fFile.Path
        On Error GoTo FileError

        ' — Uèitaj XML —
        Set xmlDoc = CreateObject("MSXML2.DOMDocument.6.0")
        xmlDoc.async = False
        If Not xmlDoc.Load(currentPath) Then
            err.Raise vbObjectError + 1, , "XML load error: " & xmlDoc.parseError.reason
        End If

        ' — Pozovi proceduru koja radi parsiranje i premeštanje fajla —
        Call UveziPDM_XMLFajl(currentPath)

ContinueLoop:
        ' Oèisti objekat prije sledeæe iteracije
        On Error Resume Next
        Set xmlDoc = Nothing
        On Error GoTo 0
    Next i

    PokreniParsiranje = True

CleanUp:
    ' Oèisti sve objekte
    On Error Resume Next
    Set folder = Nothing
    Set fso = Nothing
    Exit Function

FileError:
    Debug.Print "Greška pri obradi (" & err.Number & "): " & err.Description & "  File: " & currentPath
    Resume ContinueLoop

GlobalError:
    MsgBox "Neoèekivana greška: " & err.Description, vbCritical
    Resume CleanUp
End Function

' Pomoæna sortirajuæa procedura (jednostavan O(n^2) sortiranje, dovoljno za uobièajen broj fajlova)
Private Sub SortFileArray(ByRef arr() As Object, ByVal useCreationDate As Boolean, ByVal ascending As Boolean)
    Dim i As Long, j As Long
    Dim tmp As Object
    Dim di As Date, dj As Date

    For i = LBound(arr) To UBound(arr) - 1
        For j = i + 1 To UBound(arr)
            If useCreationDate Then
                di = arr(i).DateCreated
                dj = arr(j).DateCreated
            Else
                di = arr(i).DateLastModified
                dj = arr(j).DateLastModified
            End If

            If ascending Then
                If di > dj Then
                    Set tmp = arr(i)
                    Set arr(i) = arr(j)
                    Set arr(j) = tmp
                End If
            Else
                If di < dj Then
                    Set tmp = arr(i)
                    Set arr(i) = arr(j)
                    Set arr(j) = tmp
                End If
            End If
        Next j
    Next i
End Sub


