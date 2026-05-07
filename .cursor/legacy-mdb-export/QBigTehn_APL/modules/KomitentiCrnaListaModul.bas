Attribute VB_Name = "KomitentiCrnaListaModul"
Option Compare Database
Option Explicit

Public Function NaCrnojListi(IDKom) As Boolean
' Modifikovano: 09-01-2020
On Error GoTo Err_Point

Dim retVal As Boolean
Dim Napomena As String

If IsNumeric(IDKom) Then
    retVal = Nz(DLookup("[IDKomitent]", "KomitentiCrnaLista", "[IDKomitent] = " & IDKom & " And [Vazi] = " & True), -1) = IDKom
    If retVal Then
        Napomena = CStr(Nz(DLookup("[Opis]", "KomitentiCrnaLista", "[IDKomitent] = " & IDKom), ""))
        Napomena = "NE MOZETE IZDATI FAKTURU OVOM KLIJENTU!" & vbCrLf & Napomena
        MsgBox Napomena, vbCritical, "QMegaTeh"
    End If
Else
    retVal = False
End If

Exit_Point:
On Error Resume Next
   NaCrnojListi = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "NaCrnojListi"
 Resume Exit_Point
End Function
Public Function spKomitentProveriLimit(ByVal IDFirma As Long, ByVal Godina As Variant, ByVal OdDatumaNaloga As Variant, ByVal DoDatumaNaloga As Variant _
                                 , ByVal IDKomitent As Long, ByVal NaKontu As String _
                                 , ByRef SaldoNakontu As Currency, ByRef LimitKomitenta As Currency) As Boolean
'Kreirano: 22-12-2021
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

retValOk = True
DoCmd.Hourglass True

pCMD.ActiveConnection = CNN_CurrentDataBase
pCMD.CommandType = adCmdStoredProc
pCMD.CommandText = "spKomitentProveriLimit"

pCMD.Parameters.Refresh 'posle ove komande svi parametri su definisani!
'pCMD.Parameters("@RETURN_VALUE") = CmdRetVal
pCMD.Parameters("@IDFirma") = IDFirma
pCMD.Parameters("@Godina") = Godina
pCMD.Parameters("@OdDatumaNaloga") = SQLFormatDatuma(OdDatumaNaloga, False)
pCMD.Parameters("@DoDatumaNaloga") = SQLFormatDatuma(DoDatumaNaloga, False)
pCMD.Parameters("@IDKomitent") = IDKomitent
pCMD.Parameters("@NaKontu") = NaKontu

'pCMD.Parameters("@SaldoNakontu") = SaldoNakontu ' OUTPUT
'pCMD.Parameters("@LimitKomitenta") = LimitKomitenta 'OUTPUT

pCMD.CommandTimeout = 180 '3 minuta !!

pCMD.Execute
retValOk = (pCMD.ActiveConnection.Errors.Count = 0)

SaldoNakontu = Nz(pCMD.Parameters("@SaldoNakontu").Value, 0) ' OUTPUT
LimitKomitenta = Nz(pCMD.Parameters("@LimitKomitenta").Value, 0) 'OUTPUT

Exit_Point:
On Error Resume Next

pCMD.ActiveConnection.Close
Set pCMD = Nothing

DoCmd.Hourglass False
    spKomitentProveriLimit = retValOk
Exit Function

Err_Point:

    BBErrorMSG err, "spKomitentProveriLimit(...)"
    retValOk = False
    Resume Exit_Point
    
End Function
Public Function PrekoracenLimit(IDKom) As Boolean
' Modifikovano: 09-01-2020
'Modifikovano: 22-12-2021 (Sa Sadom)
On Error GoTo Err_Point

Dim retVal As Boolean
Dim Napomena As String
Dim LimitKomitenta As Currency
Dim SaldoKomitenta As Currency



If IsNumeric(IDKom) Then
    'LimitKomitenta = CCur(Nz(DLookup("[KreditLimit]", "Komitenti", "[Sifra] = " & IDKom), 0))
    'SaldoKomitenta = 0
    'If LimitKomitenta > 0 Then
    '    SaldoKomitenta = CCur(Nz(DLookup("[Saldo]", "ES_SaldaKupaca", "[IDKomitent] = " & IDKom), 0))
    'End If
    
     ' @IDFirma int
     ',@Godina int
     ',@OdDatumaNaloga date = null
     ',@DoDatumaNaloga date = null
     ',@IDKomitent int
     ',@NaKontu nvarchar(20)
    
    
    'retVal = ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsKomitentPrekoracenLimit", F_IDFirma(), Null, SQLFormatDatuma(F_OdDatuma(), False) _
    '                                                                            , SQLFormatDatuma(F_DoDatuma(), False), IDKom, bbcfg.SvaKontaKupaca)
    
     
     
    retVal = spKomitentProveriLimit(F_IDFirma(), Null, F_GKOdDatumaNaloga(), F_DoDatuma(), CLng(IDKom), BBCFG.SvaKontaKupaca, SaldoKomitenta, LimitKomitenta)
    
    retVal = retVal And ((LimitKomitenta > 0) And (SaldoKomitenta >= LimitKomitenta) And (SaldoKomitenta > 0))
    
    If retVal Then
        Napomena = Nz(DLookup("[Opis]", "KomitentiCrnaLista", "[IDKomitent] = " & IDKom), 0)
        Napomena = "NE MOZETE IZDATI FAKTURU OVOM KLIJENTU JER JE PREKORACIO LIMIT!" & vbCr & "Limit = " & Din(LimitKomitenta) & vbCr & "Saldo = " & Din(SaldoKomitenta)
        Call MsgBox(Napomena, vbCritical, "QMegaTeh")
        'ctrl.Undo
    Else
        retVal = False
    End If
Else
    retVal = False
End If

Exit_Point:

On Error Resume Next
   PrekoracenLimit = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "PrekoracenLimit"
 Resume Exit_Point
End Function

