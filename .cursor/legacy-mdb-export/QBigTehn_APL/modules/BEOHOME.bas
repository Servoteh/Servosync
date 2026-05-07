Attribute VB_Name = "BEOHOME"
Option Compare Database
Option Explicit

Public Function BEOHOMEIzaberiFajlZaImport(Optional ZagStr = "Izaberite fajl", Optional initdir = "D:\AcBaze\Beohome") As Variant
Dim lngFlags As Long
Dim ImeFajla As Variant
    Dim gfni As adh_accOfficeGetFileNameInfo
    
    On Error GoTo HandleErrors

    With gfni
        .lngFlags = lngFlags
        .strFilter = "CSV Files (*.csv)"
        .lngFilterIndex = CInt("1")
        .strFile = ""
        .strDlgTitle = ZagStr
        .strOpenTitle = "Select"
        .strFile = ""
        '.strInitialDir = PutanjaDoFajla(Forms![FX_HAL_KnjizenjeIzvoda]!ImportIzFajla)
        .strInitialDir = initdir
        '.strFile = "Z:\HALCOM\"
        '.strInitialDir = Forms![FX_HAL_KnjizenjeIzvoda]!ImportIzFajla
        
    End With
    If adhOfficeGetFileName(gfni, True) = adhcAccErrSuccess Then
        ImeFajla = Trim(gfni.strFile)
    Else
        ImeFajla = Null
    End If
    
ExitHere:
    BEOHOMEIzaberiFajlZaImport = ImeFajla
    Exit Function

HandleErrors:
    MsgBox "Error: " & err.Description & " (" & err.Number & ")"
    Resume ExitHere
End Function
