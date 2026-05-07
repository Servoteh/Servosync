Attribute VB_Name = "GlavnaKnjiga"
Option Compare Database
Option Explicit
Private pDefaultDatumStavke As Variant
Public Function ZakljucanNalogGK(IDNaloga As Long) As Boolean
   ZakljucanNalogGK = Nz(DLookup("[Zakljucano]", "[T_Nalozi]", "[IDNaloga] = " & IDNaloga), True)
End Function
Public Function IDNalogaZaStavkuGK(IDStavka As Long) As Long
 Dim retVal As Long
  retVal = Nz(DLookup("[IDNaloga]", "[T_Glavna knjiga]", "[StavkaID] = " & IDStavka), 0)
  IDNalogaZaStavkuGK = retVal
End Function
Public Function ZakljucanaStavkaGK(IDStavka As Long) As Boolean
   ZakljucanaStavkaGK = Nz(DLookup("[Zakljucano]", "[T_Nalozi]", "[IDNaloga] = " & IDNalogaZaStavkuGK(IDStavka)), True)
End Function
Public Function PrintujNalogGK(rptName As String, IDNaloga As Long)
On Error GoTo Err_Point
    
    DoCmd.OpenReport rptName, acPreview, , "IDNaloga = " & IDNaloga

Exit_Point:
    Exit Function

Err_Point:
    'MsgBox err.Description
    BBErrorMSG err, "PrintujNalogGK(rptName=" & rptName & ", IDNaloga=" & IDNaloga & ")"
    Resume Exit_Point
    
End Function

Public Property Get DefaultDatumStavke() As Variant
If IsEmpty(pDefaultDatumStavke) Or IsNull(pDefaultDatumStavke) Then
 pDefaultDatumStavke = Format(Date, "Short date")
End If
   DefaultDatumStavke = Format(pDefaultDatumStavke, "Short date")
End Property

Public Property Let DefaultDatumStavke(ByVal vNewValue As Variant)
   pDefaultDatumStavke = Format(vNewValue, "Short date")
End Property
Private Sub Class_Initialize()
  pDefaultDatumStavke = Format(Date, "Short date")
End Sub

Public Sub KarticaKomitenta(ByVal Konto As String, ByVal IDKomitent As Long, Optional ByVal ZaKonto2, Optional ByVal ZaGodinu)
   Const stFormName = "GKKartica"
   
   DoCmd.OpenForm stFormName
   If IsLoaded(stFormName) Then
    'Forms(stFormName)!ZaKonto = Konto
     'Forms!GKKartica.PronadjiSifruKomitenta (IDKomitent)
     Forms(stFormName).PrikaziKarticu (Konto), (IDKomitent), ZaKonto2, ZaGodinu
   End If
End Sub
Public Sub GKKarticaKomitenta(ByVal Konto As String, ByVal IDKomitent As Long, Optional ByVal ZaKonto2, Optional ByVal ZaGodinu)
   KarticaKomitenta Konto, IDKomitent, ZaKonto2, ZaGodinu
End Sub
Public Function OtvoreneStavkeKomitenta(ByVal Konto As String, ByVal IDKomitent As Long, Optional ByVal ZaGodinu)
'Kreirano: 24-08-2020
On Error GoTo Err_Point
    Const stFormName = "GKKartica"

DoCmd.OpenForm stFormName
If IsLoaded(stFormName) Then
    Forms(stFormName)!TabIzbor = 1
    Forms(stFormName).PrikaziKarticu Konto, IDKomitent, , ZaGodinu
End If

Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, ""
 Resume Exit_Point
End Function
Public Sub OpisKontaNijeUListi(ByRef ComboOpisKonta As ComboBox, ByVal NewData As String, ByRef Response As Integer)
  Dim SQLStr As String
    'Koristi se u OnNotInList kod izbora artikla
    
    
      ComboOpisKonta.RowSource = "SELECT [Kontni plan].Konto as ID, [Kontni plan].Opis,[Kontni plan].Konto FROM [Kontni plan] WHERE ((([Kontni plan].Opis) Like '*" & NewData & "*'))  ORDER BY [Kontni plan].Opis;"
      ComboOpisKonta.ColumnCount = 3
      ComboOpisKonta.BoundColumn = 1
      ComboOpisKonta.ColumnWidths = "0cm;10cm;2cm"
      ComboOpisKonta.ColumnHeads = True
      ComboOpisKonta.ListWidth = 6804  '1cm = 567
    
    
    'ComboArt.Value = Null
    Response = acDataErrContinue
End Sub
Public Sub GKKarticaKontaSinteticka(Optional ByVal Konto1 As String, Optional ByVal Konto2 As String, Optional PrimeniUslove As Boolean = True, Optional stPodforma)
   
   Const stFormName = "Kartica konta sinteticka"
   
   DoCmd.OpenForm stFormName
   If IsLoaded(stFormName) Then
      Forms(stFormName)!ZaKonto = Konto1
      If Not IsMissing(Konto2) And Nz(Konto2, "") <> "" Then
         Forms(stFormName)!ZaKonto2 = Konto2
      End If
      If PrimeniUslove Then
        Call Forms(stFormName).PrimeniUslove(stPodforma)
     End If
   End If
End Sub

Public Function PrintujIOS(IDKomitent As Long, VrstaIOS As Boolean, Optional CheckDev As Boolean = False, Optional ZaDevValutu)
On Error GoTo Err_PrintujIOS

    Dim stDocName As String
    Dim Uslov As String
    
    If CheckDev And Nz(ZaDevValutu, "*") = "*" Then
        MsgBox "Morate zadati valutu za koju zelite IOS!", , "QMegaTeh"
        GoTo Exit_PrintujIOS
    End If
    
    If Nz(IDKomitent, -1) <> -1 Then
        Uslov = "[Sifra]= " & IDKomitent
    Else
        Uslov = ""
    End If
    
    stDocName = "NIOS_SQL"
    
    'BBOpenReport stDocName, acPreview, , Uslov
    DoCmd.OpenReport stDocName, acPreview, , Uslov

Exit_PrintujIOS:
    Exit Function

Err_PrintujIOS:
    MsgBox err.Description
    Resume Exit_PrintujIOS
    
End Function
Public Function PrintujOTST(IDKomitent As Long, VrstaIOS As Boolean, Optional CheckDev As Boolean = False, Optional ZaDevValutu)
On Error GoTo Err_PrintujIOS

    Dim stDocName As String
    Dim Uslov As String
    
    If CheckDev And Nz(ZaDevValutu, "*") = "*" Then
        MsgBox "Morate zadati valutu za koju zelite OTST!", , "QMegaTeh"
        GoTo Exit_PrintujIOS
    End If
    
    If Nz(IDKomitent, -1) <> -1 Then
        Uslov = "[Sifra]= " & IDKomitent
    Else
        Uslov = ""
    End If
    
    stDocName = "OTST_SQL"
    
    'BBOpenReport stDocName, acPreview, , Uslov
    DoCmd.OpenReport stDocName, acPreview, , Uslov

Exit_PrintujIOS:
    Exit Function

Err_PrintujIOS:
    MsgBox err.Description
    Resume Exit_PrintujIOS
    
End Function
Public Function ObrisiNalogGK(IDFirma As Long, Godina As Long, IDNaloga As Long) As Boolean
'Kreirano: 10-01-2022
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stSQL As String

stSQL = ""
stSQL = stSQL & " DELETE FROM [T_Nalozi]"
stSQL = stSQL & " WHERE     (IDFirma=" & stR(IDFirma) & ")"
stSQL = stSQL & "       AND (Godina=" & stR(Godina) & ")"
stSQL = stSQL & "       AND (IDNaloga=" & stR(IDNaloga) & ")"

retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)

Exit_Point:
 On Error Resume Next
       ObrisiNalogGK = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ObrisiNalogGK"
 retValOk = False
 Resume Exit_Point

End Function
Public Function ObrisiStavkuGK(StavkaID As Long) As Boolean
'Kreirano: 10-01-2022
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stSQL As String

stSQL = ""
stSQL = stSQL & " DELETE FROM [T_Glavna knjiga]"
stSQL = stSQL & " WHERE     (StavkaID=" & stR(StavkaID) & ")"


retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)

Exit_Point:
 On Error Resume Next
       ObrisiStavkuGK = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ObrisiStavkuGK"
 retValOk = False
 Resume Exit_Point

End Function

Public Function F_GKZaGodinu() As Variant
On Error GoTo Err_Point
Dim retValZaGodinu As Variant
Dim cfgGKOdDatuma As Variant

 cfgGKOdDatuma = ReadCFGParametar("GKOdDatuma", "ZaGodinu")
    
    If cfgGKOdDatuma = "ZaGodinu" Then
        retValZaGodinu = F_Godina()
    Else
        retValZaGodinu = Null
    End If
        

Exit_Point:
 On Error Resume Next
       F_GKZaGodinu = retValZaGodinu
Exit Function

Err_Point:
 BBErrorMSG err, "F_GKZaGodinu"
 retValZaGodinu = Year(Date)
 Resume Exit_Point
End Function
Public Function F_GKOdDatumaNaloga(Optional ExplicitValue As Boolean = False) As Variant
'Modifikovano: 21-01-2023 => uveden parametar Optional ExplicitValue As Boolean = False

On Error GoTo Err_Point
Dim retValOdDatumaNaloga As Variant
Dim pfGKZaGodinu As Variant
Dim cfgGKOdDatuma As Variant

    cfgGKOdDatuma = ReadCFGParametar("GKOdDatuma", "ZaGodinu")
 
    If cfgGKOdDatuma = "ZaGodinu" Then
        If ExplicitValue Then
            retValOdDatumaNaloga = F_OdDatuma(F_Godina())
        Else
            retValOdDatumaNaloga = Null
        End If
    Else
        If IsDate(cfgGKOdDatuma) Then
            retValOdDatumaNaloga = CVDate(cfgGKOdDatuma)
        Else
            retValOdDatumaNaloga = Null
        End If
    End If
        

Exit_Point:
 On Error Resume Next
       F_GKOdDatumaNaloga = retValOdDatumaNaloga
Exit Function

Err_Point:
 BBErrorMSG err, "F_GKZaGodinu"
 retValOdDatumaNaloga = Null
 Resume Exit_Point
End Function
'Public Function spDuplirajStavkuGK(IDNaloga As Long, StavkaID As Long, Optional NoviKonto As String = "Null", Optional OkreniStrane As Boolean = False, Optional Koef As float = 1) As Boolean
Public Function spDuplirajStavkuGK(IDNaloga As Long, StavkaID As Long, Optional NoviKonto As String = "Null", Optional OkreniStrane As Boolean = False, Optional Koef As Double = 1) As Boolean
'Kreirano: 14-01-2023
'
'         @IDNaloga int
'        ,@StavkaID int
'        ,@NoviKonto nvarchar(10)
'        ,@OkreniStrane bit
'        ,@Koef float = 1

On Error GoTo Err_Point
Dim retValOk As Boolean
retValOk = True

retValOk = ExecSPByRefPar("spDuplirajStavkuGK", "@IDNaloga =" & CStr(Nz(IDNaloga, "Null")) _
                                              , "@StavkaID =" & CStr(Nz(StavkaID, "Null")) _
                                              , "@NoviKonto =" & CStr(Nz(NoviKonto, "Null")) _
                                              , "@OkreniStrane =" & SQLFormatBoolean(OkreniStrane) _
                                              , "@Koef = " & CStr(Nz(Koef, 1)) _
                          )

Exit_Point:

 On Error Resume Next
       spDuplirajStavkuGK = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "spDuplirajStavkuGK"
 retValOk = False
 Resume Exit_Point

End Function
Public Function spKreirajVirmanIzStavkeGK(IDDokIzGK As Long, Optional Update As Boolean = False) As Long
'Kreirano: 21-01-2024
    
    ' @IDDokIzGK int --= 25568
    ' @Update bit = 0
    ',@IDVirman int --OUT

'Modifikovano: 18-01-2022   => ByVal OdDatumaNaloga As Date = ByVal OdDatumaNaloga As variant
'                           => ByVal DoDatumaNaloga As Date = ByVal DoDatumaNaloga As variant
     ' @IDFirma int
     ',@Godina int
     ',@OdDatumaNaloga date = null
     ',@DoDatumaNaloga date = null
     ',@IDKomitent int
     ',@NaKontu nvarchar(20
     ',@SaldoNakontu as money OUTPUT
     ',@LimitKomitenta as money OUTPUT

On Error GoTo Err_Point

Dim pCMD As New ADODB.Command
Dim retValOk As Boolean
Dim IDVirman As Long

retValOk = True
DoCmd.Hourglass True

pCMD.ActiveConnection = CNN_CurrentDataBase
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = "spKreirajVirmanIzStavkeGK"

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
'pCMD.Parameters("@RETURN_VALUE") = CmdRetVal
pCMD.Parameters("@IDDokIzGK") = IDDokIzGK
pCMD.Parameters("@Update") = SQLFormatBoolean(Update)

pCMD.CommandTimeout = 180 '3 minuta !!

pCMD.Execute
retValOk = (pCMD.ActiveConnection.Errors.Count = 0)

IDVirman = Nz(pCMD.Parameters("@IDVirman").Value, 0) ' OUTPUT

Exit_Point:
On Error Resume Next

pCMD.ActiveConnection.Close
Set pCMD = Nothing

DoCmd.Hourglass False
    spKreirajVirmanIzStavkeGK = IDVirman
Exit Function

Err_Point:

    BBErrorMSG err, "spKreirajVirmanIzStavkeGK(...)"
    retValOk = False
    IDVirman = 0
    Resume Exit_Point
        
End Function
