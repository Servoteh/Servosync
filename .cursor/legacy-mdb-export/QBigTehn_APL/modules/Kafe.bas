Attribute VB_Name = "Kafe"
Option Compare Database
Option Explicit

Public Sub PostaviStoloveZaKonobara(ByVal UnetiID As Long, ByVal UnetiPassword As String)
    ' On Error Resume Next

    'Dim UnetiID As Variant
    Dim ZaFokus As control
    
If Not IsLoaded("PrvaMaskaKonobar") Then
    Exit Sub
End If
    Forms!PrvaMaskaKonobar!UnetiPassword = UnetiPassword
    Forms!PrvaMaskaKonobar!IDKonobar = UnetiID
    Forms!PrvaMaskaKonobar!Konobar = Null

    
      
      'UnetiID = DLookup("[IDKonobar]", "Konobari", "[Password] =  '" & UnetiPassword & "'")

        If (Not IsNull(UnetiID)) And (UnetiID <> 0) Then
            Forms!PrvaMaskaKonobar!IDKonobar = UnetiID
            Forms!PrvaMaskaKonobar!Konobar = DLookup("[Konobar]", "Konobari", "[IDKonobar] =  " & UnetiID)
            UpisiUDnevnik CurrentUser & ":" & Forms!PrvaMaskaKonobar!Konobar, "", Forms!PrvaMaskaKonobar.Name, "LogIn"
        End If
    Forms!PrvaMaskaKonobar!DanasnjiDatum = Date
    Forms!PrvaMaskaKonobar!Vreme = Time()
    If ReadParametar("CFG_Global", "KafeScenario") <> "Kelvin" Then
        Forms!PrvaMaskaKonobar!Podforma.SourceObject = "IzborStolaPanel"
    End If
End Sub
