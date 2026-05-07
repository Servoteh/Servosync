Attribute VB_Name = "APVP"
Option Compare Database
Option Explicit

Public Function APVP_MakeODBCQuery(stPodUpit As String, Optional ByVal QueryName) As Boolean
On Error GoTo err_Func
Dim retValOk As Boolean
Dim SQLText As String
Dim QName As String

If IsMissing(QueryName) Then
 QName = "ODBC_" & stPodUpit
Else
 QName = QueryName
End If

retValOk = (IsLoaded("APVP") And BBCFG.SQLDB) 'treba nam forma zbog parametara

If Not retValOk Then
  retValOk = False
  GoTo exit_Func:
End If

   SQLText = TextExecuteSP("spAPVP", stPodUpit, _
                            F_IDFirma(), Forms!APVP!ZaGodinu, _
                            Forms!APVP!OdLevel, Forms!APVP!DoLevel, _
                            CheckFieldToSQL(Forms!APVP!CheckUlaz), _
                            CheckFieldToSQL(Forms!APVP!CheckNabCenaIzUlaza), _
                            Forms!APVP!ZaMagacin, _
                            SQLFormatDatuma(Forms!APVP![Od datuma]), _
                            SQLFormatDatuma(Forms!APVP![Do datuma]), _
                            Forms!APVP!ZaVrstuDokumenta, Forms!APVP!OsimZaVrstuDokumenta, _
                            Forms!APVP!ZaBrojNaloga, _
                            Forms!APVP!ZaVrstuNaloga, _
                            Forms!APVP!ZaIDRadniNalog, _
                            Forms!APVP!ZaGrupu, Forms!APVP!ZaPodgrupu, Forms!APVP!ZaPoreklo, _
                            Forms!APVP!ZaArtikal, _
                            Forms!APVP!ZaKupca, Forms!APVP!ZaMISP, _
                            Forms!APVP!ZaVrstuKupca, _
                            Forms!APVP!ZaProdavcaNaKomitentu, Forms!APVP!ZaProdavcaNaDok, _
                            CheckFieldToSQL(Forms!APVP!CheckKOTP), _
                            CheckFieldToSQL(Forms!APVP!CheckKODJ), _
                            CheckFieldToSQL(Forms!APVP!CheckInternaDokumentaKL), _
                            Forms!APVP!KLZaMagacin, _
                            SQLFormatDatuma(Forms!APVP![KLOd datuma]), _
                            SQLFormatDatuma(Forms!APVP![KLDo datuma]), Forms!APVP![ZaRegionNaKomitentu], _
                            Forms!APVP!ZaVrstuDokumentaPROF, Forms!APVP!LevelProf, _
                            Forms!APVP!IDDobZaArt)
                            
   retValOk = BBCreateQuery(QName, SQLText)
   
exit_Func:
  APVP_MakeODBCQuery = retValOk
  Exit Function
Exit Function

err_Func:
  BBErrorMSG err, "APVP_MakeODBCQuery"
  retValOk = False
  Resume exit_Func:
End Function

