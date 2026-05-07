Attribute VB_Name = "ZaliheModul"
Option Compare Database
Option Explicit
Public Function KolicnaZaSabiranjeZaliha(Ulaz As Boolean, Kolicina As Currency, ByVal IDMagacin As Long, ZaIDMagacin, Level As Byte, OdLevel As Byte, DoLevel As Byte, DatumDok As String, DoDatuma As String, Optional OdDatuma) As Currency
 Dim retVal As Currency
 retVal = 0
 If IsMissing(OdDatuma) Then
  OdDatuma = CVDate("01-01-1901")
 End If
 If IDMagacin Like Nz(ZaIDMagacin, "*") And (OdLevel <= Level) And (Level <= DoLevel) And (CVDate(DatumDok) <= CVDate(DoDatuma)) And (CVDate(DatumDok) >= CVDate(OdDatuma)) Then
    retVal = Kolicina
 Else
    retVal = 0
 End If
 
 If Not Ulaz Then retVal = -retVal
 KolicnaZaSabiranjeZaliha = retVal
End Function
Private Function ZaliheArtikla(ByVal IDArtikal As Long, ByVal IDMagacin, ByVal NaDan As String, ByVal OdLevel As Byte, ByVal DoLevel As Byte, _
                              ByRef ZaliheUMag As Currency, ByRef UkZalihe As Currency, ByRef RezZalihe As Currency, Optional ByVal OdDatuma) As Currency
'? ZaliheArtikla(342,1,cvdate("25-03-16"),0,0)
On Error GoTo err_Func

 Dim dbBigBitLIB As DAO.Database
 Dim qDef As DAO.QueryDef
 Dim rst As DAO.Recordset
 Dim retVal As Currency
 'Dim pocetak As Variant
 
 'pocetak = Timer
 
 If IsMissing(OdDatuma) Then
  OdDatuma = CVDate("01-01-1901")
 End If
 
 If Not PostojiReferenca("BigBit_APL_2010") Then
    Set dbBigBitLIB = CurrentDb
 Else
    'OpenDatabase("C:\SHARES\AcBaze\BigBit\BigBit_APL_2010.MDB")
    Set dbBigBitLIB = OpenDatabase(Application.References("BigBit_APL_2010").fullPath)
 End If
 
 Set qDef = dbBigBitLIB.QueryDefs("QZaliheArtikla")
 qDef.Parameters("ZaIDArtikal") = IDArtikal
 qDef.Parameters("ZaIDMagacin") = IDMagacin
 qDef.Parameters("OdDatuma") = CVDate(OdDatuma)
 qDef.Parameters("DoDatuma") = CVDate(NaDan)
 qDef.Parameters("OdLevel") = OdLevel
 qDef.Parameters("DoLevel") = DoLevel
 
 Set rst = qDef.OpenRecordset()
 rst.FindFirst ("[IDartikal]=" & IDArtikal)
 If rst.NoMatch Then
  ZaliheUMag = 0
  UkZalihe = 0
  RezZalihe = 0
 Else
  ZaliheUMag = rst!ZaliheUMag
  UkZalihe = rst!UkZalihe
  RezZalihe = rst!RezZalihe
 End If
 
exit_Func:
 On Error Resume Next
 rst.Close
 Set rst = Nothing
 Set qDef = Nothing
 
 dbBigBitLIB.Close
 Set dbBigBitLIB = Nothing
 
 
 ZaliheArtikla = retVal
' If CurrentUser = "Negovan" Then
'  Debug.Print (Timer - pocetak)
' End If
Exit Function
err_Func:
  retVal = 0
 BBErrorMSG err, "ZaliheArtikla"
 Resume exit_Func
End Function
Public Sub Test_spSracunajZaliheArtikla()
Dim retZaliheUMag As Currency
Dim retUkZalihe As Currency
Dim retRezZalihe As Currency
                                        
 Debug.Print spSracunajZaliheArtikla(0, 2021, 0, 0, 1, CVDate("01-01-2021"), CVDate("31-12-2021"), 4444, retZaliheUMag, retUkZalihe, retRezZalihe)
 
 Debug.Print retZaliheUMag
 Debug.Print retUkZalihe
 Debug.Print retRezZalihe
 
End Sub

Public Function spSracunajZaliheArtikla(IDFirma As Variant, _
                                        Godina As Variant, _
                                        ByVal OdLevel As Byte, _
                                        ByVal DoLevel As Byte, _
                                        ByVal IDMagacin As Long, _
                                        ByVal OdDatuma As String, _
                                        ByVal DoDatuma As String, _
                                        ByVal IDArtikal As Long, _
                                        ByRef retZaliheUMag As Currency, _
                                        ByRef retUkZalihe As Currency, _
                                        ByRef retRezZalihe As Currency) As Boolean
'Modifikovano: 23-08-2021
'Godina As Variant
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim pCMD As New ADODB.Command
Dim i As Integer, j As Integer

Dim spBrojParametara As Integer
Dim InBrojParametara As Integer

'DoCmd.Hourglass True
pCMD.ActiveConnection = F_CNNString("SQL") 'BBCFG.CNNString
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = "spSracunajZaliheArtikla"

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
 'pCMD.Parameters(0) = @RETURN_VALUE
 spBrojParametara = pCMD.Parameters.Count() - 1
 
 'svim definisanim parametrima prvo dodelimo vrednost DEFAULT tj. Empty
 For i = 1 To spBrojParametara
  pCMD.Parameters(i).Value = Empty
 Next i
 
 
  pCMD("@IDFirma").Value = IDFirma
  pCMD("@Godina").Value = Godina
  pCMD("@OdLevel").Value = OdLevel
  pCMD("@DoLevel").Value = DoLevel
  pCMD("@IDMagacin").Value = IDMagacin
  pCMD("@OdDatuma").Value = SQLFormatDatuma(OdDatuma, False)
  pCMD("@DoDatuma").Value = SQLFormatDatuma(DoDatuma, False)
  pCMD("@IDArtikal").Value = IDArtikal
  
  'pCMD("@ZaliheUMag").Value =
  'pCMD("@UkZalihe").Value =
  'pCMD("@RezZalihe").Value =
 
 
pCMD.CommandTimeout = 180 '3 minuta !!

pCMD.Execute

retValOk = (pCMD.ActiveConnection.Errors.Count = 0)
retZaliheUMag = Nz(pCMD("@ZaliheUMag").Value, 0)
retUkZalihe = Nz(pCMD("@UkZalihe").Value, 0)
retRezZalihe = Nz(pCMD("@RezZalihe").Value, 0)

Exit_Point:
 On Error Resume Next
 Set pCMD = Nothing
 'DoCmd.Hourglass False
 spSracunajZaliheArtikla = retValOk
 
Exit Function

Err_Point:
 BBErrorMSG err, "spSracunajZaliheArtikla"
 retValOk = False
 Resume Exit_Point
End Function
'***********************************************************************************************************************************************************************************
'Modifikovano: 23-08-2021
'Opis: dodat parametar IDFirma i Godina koji nije postojao a koristi se u spSracunajZaliheArtikla
Public Function SracunajZaliheArtikla(IDFirma As Variant, Godina As Variant, ByVal IDArtikal As Long, ByVal IDMagacin As Long, ByVal OdDatuma As String, ByVal NaDan As String, ByVal OdLevel As Byte, ByVal DoLevel As Byte, _
                    ByRef ZaliheUMag As Currency, ByRef UkZalihe As Currency, ByRef RezZalihe As Currency) As Boolean
'Modifikovano: 23-08-2021
On Error GoTo err_Func

Dim retZaliheUMag As Currency
Dim retUkZalihe As Currency
Dim retRezZalihe As Currency
Dim retVal As Boolean
    
    retVal = True
    retZaliheUMag = 0
    retUkZalihe = 0
    retRezZalihe = 0
 
 If BBCFG.SQLDB Then
    'Call spSracunajZaliheArtikla(F_IDFirma(), F_Godina(), OdLevel, DoLevel, IDMagacin, OdDatuma, NaDan, IDArtikal, retZaliheUMag, retUkZalihe, retRezZalihe)
    '23-08-2021 izbacena godina! tj. salje se null
    Call spSracunajZaliheArtikla(IDFirma, Godina, OdLevel, DoLevel, IDMagacin, OdDatuma, NaDan, IDArtikal, retZaliheUMag, retUkZalihe, retRezZalihe)
 Else
   ZaliheArtikla IDArtikal, IDMagacin, NaDan, OdLevel, DoLevel, retZaliheUMag, retUkZalihe, retRezZalihe, OdDatuma
    'retZaliheUMag = DLookup("[Zalihe]", "Zalihe artiklaIF", "[Sifra artikla]=" & IDArtikal & " And [IDMagacin]=" & IDMagacin)
    'retUkZalihe = DLookup("[Zalihe]", "UkupneZaliheIF", "[Sifra artikla]=" & IDArtikal)
    'retRezZalihe = DLookup("[RezervisanaKolicina]", "RezervisaneKolicineIF", "[Sifra artikla]=" & IDArtikal)
 End If
    

exit_Func:

 ZaliheUMag = retZaliheUMag
 UkZalihe = retUkZalihe
 RezZalihe = retRezZalihe
 SracunajZaliheArtikla = retVal
Exit Function

 
err_Func:
 retVal = False
 BBErrorMSG err, "SracunajZaliheArtikla"
 Resume exit_Func
End Function
Private Function SQLVPZaliheArtikla(IDFirma, Godina, OdLevel, DoLevel, IDMagacin, OdDatuma, DoDatuma, IDArtikal As Long) As Currency
'Kreirano: 25-12-2019
On Error GoTo Err_Point
Dim retValZalihe
   retValZalihe = ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsVPZaliheArtikla", IDFirma, Godina, OdLevel, DoLevel, IDMagacin, SQLFormatDatuma(OdDatuma, False), SQLFormatDatuma(DoDatuma, False), IDArtikal)
Exit_Point:
On Error Resume Next
   
   SQLVPZaliheArtikla = CCur(Nz(retValZalihe, 0))
   
Exit Function

Err_Point:

 BBErrorMSG err, "SQLVPZaliheArtikla"
 retValZalihe = 0
 Resume Exit_Point
End Function
Public Function VPZaliheArtikla(ByVal IDFirma, ByVal Godina, ByVal OdLevel, ByVal DoLevel, ByVal IDMagacin, ByVal OdDatuma, ByVal DoDatuma, ByVal IDArtikal As Long) As Currency
'Kreirano: 25-12-2019
 Dim retVal As Currency
 
 Dim ZaliheUMag As Currency
 Dim UkZalihe As Currency
 Dim RezZalihe As Currency
 
 If BBCFG.SQLDB Then
    retVal = SQLVPZaliheArtikla(IDFirma, Godina, OdLevel, DoLevel, IDMagacin, OdDatuma, DoDatuma, IDArtikal)
 Else
    Call SracunajZaliheArtikla(IDFirma, Godina, IDArtikal, IDMagacin, OdDatuma, DoDatuma, OdLevel, DoLevel, _
                     ZaliheUMag, UkZalihe, RezZalihe)
    retVal = ZaliheUMag
 End If
 VPZaliheArtikla = retVal
End Function
