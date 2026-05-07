Attribute VB_Name = "CM_Modul"
Option Compare Database
Option Explicit

Public Function CM_Izlaz_UveziPodatkeIzRobnogDokumenta(IDCMIzlaz As Long, IDDokIzRobnog As Long) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
'    EXEC spCM_Izlaz_ImportIz_T_Izvoz_Stavke
'                                             @IDFirma int
'                                            ,@Godina int = null
'                                            ,@OdLevel smallint = null
'                                            ,@DoLevel smallint = null
'                                            ,@ZaliheOdDatuma date = null
'                                            ,@ZaliheDoDatuma date = null
'                                            ,@IDRobniDok int
'                                            --,@ZaVrstuProdaje nvarchar(255) = null
'                                            ,@IDCM int
    
      retValOk = ADO_ExecSP(BBCFG.CNNString, "spCM_Izlaz_ImportIz_T_Izvoz_Stavke", F_IDFirma(), F_Godina(), 0, 0, _
                                            SQLFormatDatuma(F_OdDatuma(), False), Null, IDDokIzRobnog, IDCMIzlaz)
    
Exit_Point:
     On Error Resume Next
     CM_Izlaz_UveziPodatkeIzRobnogDokumenta = retValOk
    Exit Function
    
Err_Point:
     BBErrorMSG err, "CM_Izlaz_UveziPodatkeIzRobnogDokumenta"
     Resume Exit_Point
End Function
Public Function CM_Izlaz_UveziZaliheIzMagacinskogBroja(IDCMIzlaz As Long, ImportMagBroj As String, IDKupac As Long, CenovnikVrstaDok As String, NaDan As Date) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    '@IDFirma int,
    '@Godina int,
    '@IDCM int,
    '@ZaMagacinskiBroj nvarchar(50),
    '@IDKupac int = null,
    '@CenovnikVrstaDok nvarchar(50) = null,
    '@NaDan Date = null
    
      retValOk = ADO_ExecSP(BBCFG.CNNString, "spCM_Izlaz_ImportZaliheZaMagBroj", F_IDFirma(), F_Godina(), IDCMIzlaz, ImportMagBroj, IDKupac, CenovnikVrstaDok, SQLFormatDatuma(NaDan, False))
    
Exit_Point:
     On Error Resume Next
     CM_Izlaz_UveziZaliheIzMagacinskogBroja = retValOk
    Exit Function
    
Err_Point:
     BBErrorMSG err, "CM_Izlaz_UveziZaliheIzMagacinskogBroja"
     Resume Exit_Point
End Function
Public Function TrPakArtIzCMUlaz(CMUlaz_IDStavke As Variant) As Double
On Error GoTo Err_Point
Dim retVal As Double
Dim rstCM As ADODB.Recordset

If Nz(CMUlaz_IDStavke, -1) = -1 Then
   retVal = 0
Else
    Set rstCM = ADO_GetRST(BBCFG.CNNString, "SELECT *  FROM T_CMStavke_Ulaz WHERE ID=" & stR(CMUlaz_IDStavke), dbOptimistic, , adOpenStatic)
    If Not rstCM.EOF Then
        retVal = IIf(rstCM!ArtKoleta <> 0, rstCM!Kolicina / rstCM!ArtKoleta, 0)
    Else
        retVal = 0
    End If
    rstCM.Close
    Set rstCM = Nothing
End If

Exit_Point:
 On Error Resume Next
    If Not (rstCM Is Nothing) Then
       rstCM.Close
       Set rstCM = Nothing
    End If
    TrPakArtIzCMUlaz = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "TrPakArtIzCMUlaz"
 retVal = 0
 Resume Exit_Point
End Function
Public Function BrutoKGArtIzCMUlaz(CMUlaz_IDStavke As Variant) As Double
On Error GoTo Err_Point
Dim retVal As Double
Dim rstCM As ADODB.Recordset

If Nz(CMUlaz_IDStavke, -1) = -1 Then
   retVal = 0
Else
    Set rstCM = ADO_GetRST(BBCFG.CNNString, "SELECT *  FROM T_CMStavke_Ulaz WHERE ID=" & stR(CMUlaz_IDStavke), dbOptimistic, , adOpenStatic)
    If Not rstCM.EOF Then
        retVal = IIf(rstCM!Kolicina <> 0, rstCM!ArtBruto / rstCM!Kolicina, rstCM!ArtBruto)
    Else
        retVal = 0
    End If
    rstCM.Close
    Set rstCM = Nothing
End If

Exit_Point:
 On Error Resume Next
    If Not (rstCM Is Nothing) Then
       rstCM.Close
       Set rstCM = Nothing
    End If
    BrutoKGArtIzCMUlaz = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "BrutoKGArtIzCMUlaz"
 retVal = 0
 Resume Exit_Point
End Function
Public Function NetoKGArtIzCMUlaz(CMUlaz_IDStavke As Variant) As Double
On Error GoTo Err_Point
Dim retVal As Double
Dim rstCM As ADODB.Recordset

If Nz(CMUlaz_IDStavke, -1) = -1 Then
   retVal = 0
Else
    Set rstCM = ADO_GetRST(BBCFG.CNNString, "SELECT *  FROM T_CMStavke_Ulaz WHERE ID=" & stR(CMUlaz_IDStavke), dbOptimistic, , adOpenStatic)
    If Not rstCM.EOF Then
        retVal = IIf(rstCM!Kolicina <> 0, rstCM!ArtNeto / rstCM!Kolicina, rstCM!ArtNeto)
    Else
        retVal = 0
    End If
    rstCM.Close
    Set rstCM = Nothing
End If

Exit_Point:
 On Error Resume Next
    If Not (rstCM Is Nothing) Then
       rstCM.Close
       Set rstCM = Nothing
    End If
    NetoKGArtIzCMUlaz = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "NetoKGArtIzCMUlaz"
 retVal = 0
 Resume Exit_Point
End Function
Public Function F_CM_BrojKoletaZaPackingListEXT(IDCMIzlaz As Long) As Long
  
On Error GoTo Err_Point
Dim retVal As Long
Dim stSQL

stSQL = ""
stSQL = stSQL & " SELECT COUNT(*) as BrojKoleta"
stSQL = stSQL & " FROM ("
stSQL = stSQL & "         SELECT cms.[IzlazOznakaPalete]"
stSQL = stSQL & "         FROM T_CMStavke_Izlaz as cms"
stSQL = stSQL & "         WHERE cms.IDCM =" & stR(IDCMIzlaz)
stSQL = stSQL & "         GROUP BY cms.[IzlazOznakaPalete]"
stSQL = stSQL & "     ) as r"

retVal = Nz(ADO_Lookup(BBCFG.CNNString, "[BrojKoleta]", stSQL), 0)


Exit_Point:
 On Error Resume Next
       F_CM_BrojKoletaZaPackingListEXT = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_CM_BrojKoletaZaPackingListEXT"
 retVal = 0
 Resume Exit_Point
End Function
Public Function F_RD_BrojKoletaZaPackingListEXTIzvoz(IDDok As Long) As Long
  
On Error GoTo Err_Point
Dim retVal As Long
Dim stSQL

stSQL = ""
stSQL = stSQL & " SELECT COUNT(*) as BrojKoleta"
stSQL = stSQL & " FROM ("
stSQL = stSQL & "         SELECT izs.[OznakaPalete]"
stSQL = stSQL & "         FROM T_IzvozStavke as izs"
stSQL = stSQL & "              INNER JOIN Magacini ON Magacini.IDMagacin = izs.IDMagacin"
stSQL = stSQL & "         WHERE izs.IDDok =" & stR(IDDok)
stSQL = stSQL & "         GROUP BY izs.[OznakaPalete]"
stSQL = stSQL & "     ) as r"

retVal = Nz(ADO_Lookup(BBCFG.CNNString, "[BrojKoleta]", stSQL), 0)


Exit_Point:
 On Error Resume Next
       F_RD_BrojKoletaZaPackingListEXTIzvoz = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_RD_BrojKoletaZaPackingListEXTIzvoz"
 retVal = 0
 Resume Exit_Point
End Function
