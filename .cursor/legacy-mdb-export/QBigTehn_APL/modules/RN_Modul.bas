Attribute VB_Name = "RN_Modul"
Option Compare Database
Option Explicit
Public RNP As New RN_Class
Public Function F_RN_IDRN() As Long
   F_RN_IDRN = Nz(RNP.IDRN(), -1)
End Function

Public Function F_RN_IDKomitent(Optional IDKomitent) As Long
Dim lnRetVal As Long
    lnRetVal = RNP.IDKomitent
    F_RN_IDKomitent = lnRetVal
End Function
Public Function F_RN_IDPredmet(Optional IDPredmet) As Long
Dim lnRetVal As Long
    lnRetVal = RNP.IDPredmet
    F_RN_IDPredmet = lnRetVal
End Function
Public Function F_RN_IdentBroj() As String
Dim lnRetVal As String
    lnRetVal = RNP.IdentBroj
    F_RN_IdentBroj = lnRetVal
End Function
Public Function F_RN_Varijanta(Optional Varijanta) As Long
Dim lnRetVal As Long
    lnRetVal = RNP.Varijanta
    F_RN_Varijanta = lnRetVal
End Function
Public Function F_RN_DatumUnosa() As Date
Dim retVal As Date
    retVal = ADO_Lookup(F_CNNString("SQL"), "[DatumUnosa]", "tRN", "[IDRN]=" & F_RN_IDRN())
    F_RN_DatumUnosa = retVal
End Function

Public Function PostojiSaglasnost(IDRN As Long) As Long
    PostojiSaglasnost = Nz(DLookup("Saglasan", "tSaglasanRN", "[IDRN] = " & IDRN), False)
End Function
Public Function DefiniseSaglasan(IDRadnik As Long) As Long
    DefiniseSaglasan = Nz(DLookup("DefiniseSaglasan", "tRadnici", "[SifraRadnika] = " & IDRadnik), False)
End Function
Public Function DefiniseLansiran(IDRadnik As Long) As Long
    DefiniseLansiran = Nz(DLookup("DefiniseLansiran", "tRadnici", "[SifraRadnika] = " & IDRadnik), False)
End Function
Public Function BrojStavkiNaRN(IDRN As Long) As Long
    BrojStavkiNaRN = DCount("*", "tStavkeRN", "[IDRN] = " & IDRN)
End Function
Public Function NadjiRadniNalog(Optional IDRN, Optional stFindControlName)
On Error GoTo Err_Point

 Dim pVisibleIDRN As Boolean
 Dim pIDRN As Long
 Dim pFindControlName As String
 Dim pForm As Form
 Dim pCtl As control
    
    Set pCtl = Screen.ActiveControl
    Set pForm = Screen.ActiveControl.Parent
    
    If IsMissing(stFindControlName) Then
     pFindControlName = "IDRN"
    Else
     pFindControlName = stR(stFindControlName)
    End If
    
    If IsMissing(IDRN) Then
      pIDRN = pCtl.Value ' CLng(Screen.ActiveControl.Value)
    Else
       pIDRN = CLng(IDRN)
    End If
    
    pVisibleIDRN = pForm.Controls(pFindControlName).Visible 'pVisibleIDRN = Me![Sifra artikla].Visible
    pForm.Controls(pFindControlName).Visible = True 'Me![Sifra artikla].Visible = True
    pForm.Controls(pFindControlName).SetFocus 'DoCmd.GoToControl "IDRN"
    DoCmd.FindRecord pIDRN
    pCtl.SetFocus 'DoCmd.GoToControl "NadjiKatBroj"
    pCtl.Value = Null ' Me!NadjiKatBroj = Null
    pForm.Controls(pFindControlName).Visible = pVisibleIDRN 'Me![Sifra artikla].Visible = pVisibleIDRN
    
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
   
   BBErrorMSG err, "NadjiArtikal"
   Resume Exit_Point
   
End Function


Public Function stSQL_Append_VrsteKomitentaIzBigBita() As String
On Error GoTo Err_Point
    Dim stRetVal As String
           
    stRetVal = ""
    stRetVal = stRetVal & " INSERT INTO [Vrste sifara] ( [Vrsta sifre], Opis )"
    stRetVal = stRetVal & " SELECT [EXT_Vrste sifara].[Vrsta sifre], [EXT_Vrste sifara].Opis"
    stRetVal = stRetVal & " FROM [EXT_Vrste sifara] LEFT JOIN [Vrste sifara] ON [EXT_Vrste sifara].[Vrsta sifre] = [Vrste sifara].[Vrsta sifre]"
    stRetVal = stRetVal & " WHERE ((([Vrste sifara].[Vrsta sifre]) Is Null));"
        
Exit_Point:
    stSQL_Append_VrsteKomitentaIzBigBita = stRetVal
    Exit Function

Err_Point:
    MsgBox err.Description
    stRetVal = ""
    Resume Exit_Point
End Function

Public Function DaLiPostojeDodatnaOvlascenjaZaRadnika(Optional pIDRadnika As Long = -1) As Boolean
On Error GoTo Err_Point
    Dim IDRadnika As Long
    Dim retValOk As Boolean
    Dim VrsteRadnika As Long
    
    If Nz(pIDRadnika, -1) = -1 Then
        IDRadnika = BBTehn.IDRadnik
    Else
        IDRadnika = pIDRadnika
    End If
    'VrsteRadnika = Nz(DLookup("[IDVrsteRadnika]", "tRadnici", "[SifraRadnika] = " & IDRadnika), 0)
    VrsteRadnika = Nz(ADO_Lookup(CNN_CurrentDataBase, "[IDVrsteRadnika]", "tRadnici", "[SifraRadnika] = " & IDRadnika), 0)
    'retValOk = Nz(DLookup("DodatnaOvlascenja", "tVrsteRadnika", "IDVrsteRadnika = " & VrsteRadnika), False)
    retValOk = Nz(ADO_Lookup(CNN_CurrentDataBase, "[DodatnaOvlascenja]", "tVrsteRadnika", "[IDVrsteRadnika] = " & VrsteRadnika), False)
    
Exit_Point:
 On Error Resume Next
    DaLiPostojeDodatnaOvlascenjaZaRadnika = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "DaLiPostojeDodatnaOvlascenjaZaRadnika"
    retValOk = False
    Resume Exit_Point
End Function
Public Function IDRadnikZaCurrentUser() As Long
On Error GoTo Err_Point

    Dim pID As Variant
    
    pID = Nz(ADO_Lookup(CNN_CurrentDataBase, "[SifraRadnika]", "tRadnici", "[LogAcc] = '" & CurrentUser() & "'"), 0)
    pID = NullToZero(pID)            ' If Not IsNum(ID) Then ID = 0 svejedno
        
       
Exit_Point:
 On Error Resume Next
 IDRadnikZaCurrentUser = pID
Exit Function

Err_Point:
    BBErrorMSG err, "IDRadnikZaCurrentUser"
    pID = -1
    Resume Exit_Point
End Function
Public Function IDProdavacZaCurrentUser() As Long
On Error GoTo Err_Point
    Dim pID As Variant
    
    'ID = DLookup("[SifraRadnika]", "tRadnici", "[LogAcc] = '" & CurrentUser & "'")
    pID = Nz(ADO_Lookup(CNN_CurrentDataBase, "[SifraRadnika]", "tRadnici", "[LogAcc] = '" & CurrentUser() & "'"), -1)
    pID = NullToZero(pID)            ' If Not IsNum(ID) Then ID = 0 svejedno
        
       
Exit_Point:
 On Error Resume Next
 IDProdavacZaCurrentUser = pID
Exit Function

Err_Point:
    BBErrorMSG err, "IDProdavacZaCurrentUser"
    pID = -1
    Resume Exit_Point
End Function

Function F_Timer() As String
    F_Timer = CLng(Timer)
End Function
Public Function PrepisiZaglavljePostupka(ByRef NoviIDRN As Long, ByVal ZaIDRN As Long, Optional BrojPredmeta As String) As Boolean
On Error GoTo Err_DugmePrepisiStavkeIzNaloga_Click

    Dim stSQL As String
    Dim stSQLWhere As String
    Dim retValOk As Boolean
    Dim IDRN As Long
    Dim chNavodnici As String
    Dim rst As ADODB.Recordset
    Dim nVarijanta As Integer
    
    stSQL = ""
    
    If BBCFG.SQLDB Then
        chNavodnici = Chr(39)
    Else
        chNavodnici = Chr(34)
    End If
    
    stSQL = stSQL & " SELECT *"
    stSQL = stSQL & " FROM tRN"
    stSQL = stSQL & " WHERE (((tRN.IDRN)=" & ZaIDRN & "));"
    
    Set rst = ADO_GetRST(CNN_CurrentDataBase, stSQL)
    
    nVarijanta = SledecaVrednostVarijante(rst![IDPredmet], rst![BrojCrteza], rst![Revizija])
    
    stSQL = ""
            stSQL = stSQL & "    INSERT INTO tRN" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "              IDPredmet" & vbCrLf
            stSQL = stSQL & "            , IdentBroj" & vbCrLf
            stSQL = stSQL & "            , Varijanta" & vbCrLf
            stSQL = stSQL & "            , BBIDKomitent" & vbCrLf
            stSQL = stSQL & "            , BBNazivPredmeta" & vbCrLf
            stSQL = stSQL & "            , BBDatumOtvaranja" & vbCrLf
            stSQL = stSQL & "            , DatumUnosa" & vbCrLf
            stSQL = stSQL & "            , Komada" & vbCrLf
            stSQL = stSQL & "            , BrojCrteza" & vbCrLf
            stSQL = stSQL & "            , Proizvod" & vbCrLf
            
            stSQL = stSQL & "            , TezinaNeobrDela" & vbCrLf
            stSQL = stSQL & "            , NazivDela" & vbCrLf
            stSQL = stSQL & "            , IdentMaterijala" & vbCrLf
            stSQL = stSQL & "            , Materijal" & vbCrLf
            stSQL = stSQL & "            , DimenzijaMaterijala" & vbCrLf
            stSQL = stSQL & "            , JM" & vbCrLf
            stSQL = stSQL & "            , TezinaObrDela" & vbCrLf
            stSQL = stSQL & "            , Napomena" & vbCrLf
            stSQL = stSQL & "            , StatusRN" & vbCrLf
            stSQL = stSQL & "            , RokIzrade" & vbCrLf
            
            stSQL = stSQL & "            , DIVUnosaRN" & vbCrLf
            stSQL = stSQL & "            , DIVIspravkeRN" & vbCrLf
            stSQL = stSQL & "            , SifraRadnika" & vbCrLf
            stSQL = stSQL & "            , Zakljucano" & vbCrLf
            stSQL = stSQL & "            , Potpis" & vbCrLf
            stSQL = stSQL & "            , PrnTimer" & vbCrLf
            stSQL = stSQL & "            , VezaSaBrojemCrteza" & vbCrLf
            stSQL = stSQL & "            , IDVrstaKvaliteta" & vbCrLf
            
            stSQL = stSQL & "            , Revizija" & vbCrLf
            stSQL = stSQL & "            , IDPrimopredaje" & vbCrLf
            stSQL = stSQL & "            , IDCrtez" & vbCrLf
            stSQL = stSQL & "            , IDStatusPrimopredaje" & vbCrLf
            
            stSQL = stSQL & "            )" & vbCrLf
            stSQL = stSQL & "   VALUES" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "            " & stR(rst![IDPredmet]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![IdentBroj], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            'stSQL = stSQL & "            ," & chNavodnici & Replace(ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsSledeciBrojRadnogNaloga", BrojPredmeta, 1), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(nVarijanta) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![BBIDKomitent]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![BBNazivPredmeta], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatuma(rst![BBDatumOtvaranja], False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatuma(rst![DatumUnosa], False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![Komada]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![BrojCrteza], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Proizvod], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            
            stSQL = stSQL & "            ," & stR(rst![TezinaObrDela]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![NazivDela], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![IdentMaterijala]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Materijal], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![DimenzijaMaterijala], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![JM], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![TezinaObrDela]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Napomena], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & SQLFormatBoolean(rst![StatusRN]) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatuma(rst![RokIzrade], False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![SifraRadnika]) & vbCrLf
            stSQL = stSQL & "            ," & SQLFormatBoolean(False) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & Replace(CurrentUser(), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(0) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![VezaSaBrojemCrteza], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(0) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Revizija], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![IDPrimopredaje]) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![IDCrtez]) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![IDStatusPrimopredaje]) & vbCrLf
            
            stSQL = stSQL & "            )" & vbCrLf
            
            'SetClipboard stSQL
            
            retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
            
            NoviIDRN = ADO_IDENTITY 'ADO_Lookup(CNN_CurrentDataBase, "SELECT @@IDENTITY")

    
Exit_DugmePrepisiStavkeIzNaloga_Click:
    DoCmd.SetWarnings False
    DoCmd.Close acForm, "PrepisiZaglavljePostupka", acSaveYes
    Exit Function
    
Err_DugmePrepisiStavkeIzNaloga_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiStavkeIzNaloga_Click
    
End Function

Public Function PrepisiStavkeIzNaloga(ByVal pNoviIDRN As Long, ByVal pZaIDRN As Long) As Boolean
On Error GoTo Err_DugmePrepisiStavkeIzNaloga_Click
 
    Dim stSQL As String
    Dim stSQLWhere As String
    Dim retValOk As Boolean
    Dim chNavodnici As String
    Dim rst As ADODB.Recordset
    
    stSQL = ""
    
    If BBCFG.SQLDB Then
        chNavodnici = Chr(39)
    Else
        chNavodnici = Chr(34)
    End If
    
    stSQL = stSQL & " SELECT *"
    stSQL = stSQL & " FROM tStavkeRN"
    stSQL = stSQL & " WHERE (((tStavkeRN.IDRN)=" & pZaIDRN & "))"
    stSQL = stSQL & " ORDER BY Operacija;"
    
    Set rst = ADO_GetRST(CNN_CurrentDataBase, stSQL)
    If rst.RecordCount > 0 Then
        rst.MoveFirst
        While Not rst.EOF
            stSQL = ""
            stSQL = stSQL & "    INSERT INTO tStavkeRN" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "              IDRN" & vbCrLf
            stSQL = stSQL & "            , Operacija" & vbCrLf
            stSQL = stSQL & "            , RJgrupaRC" & vbCrLf
            stSQL = stSQL & "            , OpisRada" & vbCrLf
            stSQL = stSQL & "            , AlatPribor" & vbCrLf
            stSQL = stSQL & "            , Tpz" & vbCrLf
            stSQL = stSQL & "            , Tk" & vbCrLf
            stSQL = stSQL & "            , TezinaTO" & vbCrLf
            stSQL = stSQL & "            , SifraRadnika" & vbCrLf
            stSQL = stSQL & "            , DIVUnosa" & vbCrLf
            stSQL = stSQL & "            , DIVIspravke" & vbCrLf
            stSQL = stSQL & "            , Prioritet" & vbCrLf
            stSQL = stSQL & "            )" & vbCrLf
            stSQL = stSQL & "   VALUES" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "            " & stR(pNoviIDRN) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![Operacija]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![RJgrupaRC], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![OpisRada], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![AlatPribor], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![Tpz]) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![Tk]) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![TezinaTO]) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![SifraRadnika]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & IIf(ADO_Lookup(CNN_CurrentDataBase, "KoristiPrioritet", "tOperacije", "RJgrupaRC='" & Nz(rst![RJgrupaRC], "") & "'") = True, 100, 255) & vbCrLf
            stSQL = stSQL & "            )" & vbCrLf
            
            'SetClipboard stSQL
            
            retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
            rst.MoveNext
        Wend
     End If

    
    
Exit_DugmePrepisiStavkeIzNaloga_Click:
    DoCmd.SetWarnings False
    
    Exit Function

Err_DugmePrepisiStavkeIzNaloga_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiStavkeIzNaloga_Click
    
End Function

Public Function PrepisitPNDIzNaloga(ByVal pNoviIDRN As Long, ByVal pZaIDRN As Long) As Boolean
On Error GoTo Err_DugmePrepisiStavkeIzNaloga_Click
 
    Dim stSQL As String
    Dim stSQLWhere As String
    Dim retValOk As Boolean
    Dim chNavodnici As String
    Dim rst As ADODB.Recordset
    
    stSQL = ""
    
    If BBCFG.SQLDB Then
        chNavodnici = Chr(39)
    Else
        chNavodnici = Chr(34)
    End If
   
    stSQL = stSQL & " SELECT *"
    stSQL = stSQL & " FROM tPND"
    stSQL = stSQL & " WHERE (((tPND.IDRN)=" & pZaIDRN & "))"
    stSQL = stSQL & " ORDER BY OperacijaPND;"
    
    Set rst = ADO_GetRST(CNN_CurrentDataBase, stSQL)
    If rst.RecordCount > 0 Then
        rst.MoveFirst
        While Not rst.EOF
            stSQL = ""
            stSQL = stSQL & "    INSERT INTO tPND" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "              IDRN" & vbCrLf
            stSQL = stSQL & "            , PozicijaPND" & vbCrLf
            stSQL = stSQL & "            , OperacijaPND" & vbCrLf
            stSQL = stSQL & "            , RJgrupaRC" & vbCrLf
            stSQL = stSQL & "            , NazivDela" & vbCrLf
            stSQL = stSQL & "            , Komada" & vbCrLf
            stSQL = stSQL & "            , Napomena" & vbCrLf
            stSQL = stSQL & "            , DIVUnosa" & vbCrLf
            stSQL = stSQL & "            , DIVIspravke" & vbCrLf
            stSQL = stSQL & "            , SifraRadnika" & vbCrLf
            stSQL = stSQL & "            )" & vbCrLf
            stSQL = stSQL & "   VALUES" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "            " & stR(pNoviIDRN) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![PozicijaPND], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![OperacijaPND]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![RJgrupaRC], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![NazivDela], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![Komada]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Napomena], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![SifraRadnika]) & vbCrLf
            
            stSQL = stSQL & "            )" & vbCrLf
            
            retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
            rst.MoveNext
        Wend
     End If

    
    
Exit_DugmePrepisiStavkeIzNaloga_Click:
    DoCmd.SetWarnings False
    
    Exit Function

Err_DugmePrepisiStavkeIzNaloga_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiStavkeIzNaloga_Click
    
End Function

Public Function PrepisitPLPIzNaloga(ByVal pNoviIDRN As Long, ByVal pZaIDRN As Long) As Boolean
On Error GoTo Err_DugmePrepisiStavkeIzNaloga_Click
 
    Dim stSQL As String
    Dim stSQLWhere As String
    Dim retValOk As Boolean
    Dim chNavodnici As String
    Dim rst As ADODB.Recordset
    
    stSQL = ""
    
    If BBCFG.SQLDB Then
        chNavodnici = Chr(39)
    Else
        chNavodnici = Chr(34)
    End If
    
    stSQL = stSQL & " SELECT *"
    stSQL = stSQL & " FROM tPLP"
    stSQL = stSQL & " WHERE (((tPLP.IDRN)=" & pZaIDRN & "))"
    stSQL = stSQL & " ORDER BY IDStavkePLP;"
    
    Set rst = ADO_GetRST(CNN_CurrentDataBase, stSQL)
    If rst.RecordCount > 0 Then
        rst.MoveFirst
        While Not rst.EOF
            stSQL = ""
            stSQL = stSQL & "    INSERT INTO tPLP" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "              IDRN" & vbCrLf
            stSQL = stSQL & "            , PozicijaPLP" & vbCrLf
            stSQL = stSQL & "            , RJgrupaRC" & vbCrLf
            stSQL = stSQL & "            , Materijal" & vbCrLf
            stSQL = stSQL & "            , DimenzijaMaterijala" & vbCrLf
            stSQL = stSQL & "            , JM" & vbCrLf
            stSQL = stSQL & "            , TezinaJed" & vbCrLf
            stSQL = stSQL & "            , Komada" & vbCrLf
            stSQL = stSQL & "            , BrojPozicije" & vbCrLf
            stSQL = stSQL & "            , DIVUnosa" & vbCrLf
            stSQL = stSQL & "            , DIVIspravke" & vbCrLf
            stSQL = stSQL & "            , SifraRadnika" & vbCrLf
            stSQL = stSQL & "            )" & vbCrLf
            stSQL = stSQL & "   VALUES" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "            " & stR(pNoviIDRN) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![PozicijaPLP], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![RJgrupaRC], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Materijal], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![DimenzijaMaterijala], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![JM], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![TezinaJed]) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![Komada]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![BrojPozicije], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![SifraRadnika]) & vbCrLf
            
            stSQL = stSQL & "            )" & vbCrLf
            
            retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
            rst.MoveNext
        Wend
     End If

    
    
Exit_DugmePrepisiStavkeIzNaloga_Click:
    DoCmd.SetWarnings False
    
    Exit Function

Err_DugmePrepisiStavkeIzNaloga_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiStavkeIzNaloga_Click
    
End Function

Public Function PrepisitPDMIzNaloga(ByVal pNoviIDRN As Long, ByVal pZaIDRN As Long) As Boolean
On Error GoTo Err_DugmePrepisiStavkeIzNaloga_Click
 
    Dim stSQL As String
    Dim stSQLWhere As String
    Dim retValOk As Boolean
    Dim chNavodnici As String
    Dim rst As ADODB.Recordset
    
    stSQL = ""
    
    If BBCFG.SQLDB Then
        chNavodnici = Chr(39)
    Else
        chNavodnici = Chr(34)
    End If
    
    stSQL = stSQL & " SELECT *"
    stSQL = stSQL & " FROM tPDM"
    stSQL = stSQL & " WHERE (((tPDM.IDRN)=" & pZaIDRN & "))"
    stSQL = stSQL & " ORDER BY IDStavkePDM;"
    
    Set rst = ADO_GetRST(CNN_CurrentDataBase, stSQL)
    If rst.RecordCount > 0 Then
        rst.MoveFirst
        While Not rst.EOF
            stSQL = ""
            stSQL = stSQL & "    INSERT INTO tPDM" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "              IDRN" & vbCrLf
            stSQL = stSQL & "            , PozicijaPDM" & vbCrLf
            stSQL = stSQL & "            , OperacijaPDM" & vbCrLf
            stSQL = stSQL & "            , RJgrupaRC" & vbCrLf
            stSQL = stSQL & "            , NazivP" & vbCrLf
            stSQL = stSQL & "            , BrojCrtezaP" & vbCrLf
            stSQL = stSQL & "            , Komada" & vbCrLf
            stSQL = stSQL & "            , DIVUnosa" & vbCrLf
            stSQL = stSQL & "            , DIVIspravke" & vbCrLf
            stSQL = stSQL & "            , SifraRadnika" & vbCrLf
            stSQL = stSQL & "            )" & vbCrLf
            stSQL = stSQL & "   VALUES" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "            " & stR(pNoviIDRN) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![PozicijaPDM], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![OperacijaPDM]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![RJgrupaRC], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![NazivP], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![BrojCrtezaP], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![Komada]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![SifraRadnika]) & vbCrLf
            
            stSQL = stSQL & "            )" & vbCrLf
            
            retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
            rst.MoveNext
        Wend
     End If

    
    
Exit_DugmePrepisiStavkeIzNaloga_Click:
    DoCmd.SetWarnings False
    
    Exit Function

Err_DugmePrepisiStavkeIzNaloga_Click:
    MsgBox err.Description
    Resume Exit_DugmePrepisiStavkeIzNaloga_Click
    
End Function
Public Function KreirajNalogDoradeIliSkarta(ByVal ZaIDRN As Long, ByVal BrojKomada As Integer, ByVal IDVrstaKvaliteta As Integer, ByVal stNapomena As String) As Long
On Error GoTo Err_DugmePrepisiStavkeIzNaloga_Click

    Dim stSQL As String
    Dim stSQLWhere As String
    Dim retValOk As Boolean
    Dim NoviIDRN As Long
    Dim chNavodnici As String
    Dim rst As ADODB.Recordset
    Dim IdentBroj As String
    Dim Sufix As String
    Dim PostojiNalogSaIstimBrojem As Boolean
    Dim stRNSQL As String
    Dim nVarijanta As Integer
    
    stSQL = ""
    
    If BBCFG.SQLDB Then
        chNavodnici = Chr(39)
    Else
        chNavodnici = Chr(34)
    End If
    
    stSQL = stSQL & " SELECT *"
    stSQL = stSQL & " FROM tRN"
    stSQL = stSQL & " WHERE (((tRN.IDRN)=" & ZaIDRN & "));"
    
    Set rst = ADO_GetRST(CNN_CurrentDataBase, stSQL)
    Sufix = "1"
    PostojiNalogSaIstimBrojem = True
    IdentBroj = Nz(rst![IdentBroj], "") & IIf(IDVrstaKvaliteta = 1, "-D", "-S") & Sufix
    While PostojiNalogSaIstimBrojem
        stRNSQL = ""
        stRNSQL = stRNSQL & "SELECT Count(*) as BrojSlogova "
        stRNSQL = stRNSQL & " FROM [dbo].[tRN]"
        stRNSQL = stRNSQL & " WHERE [IDPredmet]=" & stR(rst![IDPredmet])
        stRNSQL = stRNSQL & "   AND [IdentBroj]='" & IdentBroj & "'"
        'stRNSQL = stRNSQL & "   AND [Varijanta]=" & rst![Varijanta]
    'sufix =  ADO_Lookup(CNN_CurrentDataBase, "BrojNaloga", "SELECT COUNT(*) as BrojSlogova FROM T_MPDokumenta WHERE " & pstWhere)
        If (Nz(ADO_Lookup(CNN_CurrentDataBase, "BrojSlogova", stRNSQL), 0) > 0) Then
            Sufix = CStr(CLng(Sufix) + 1)
            IdentBroj = Nz(rst![IdentBroj], "") & IIf(IDVrstaKvaliteta = 1, "-D", "-S") & Sufix
        Else
            PostojiNalogSaIstimBrojem = False
        End If
    Wend
    nVarijanta = SledecaVrednostVarijante(rst![IDPredmet], rst![BrojCrteza], rst![Revizija])
    stSQL = ""
            stSQL = stSQL & "    INSERT INTO tRN" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "              IDPredmet" & vbCrLf
            stSQL = stSQL & "            , IdentBroj" & vbCrLf
            stSQL = stSQL & "            , Varijanta" & vbCrLf
            stSQL = stSQL & "            , BBIDKomitent" & vbCrLf
            stSQL = stSQL & "            , BBNazivPredmeta" & vbCrLf
            stSQL = stSQL & "            , BBDatumOtvaranja" & vbCrLf
            stSQL = stSQL & "            , DatumUnosa" & vbCrLf
            stSQL = stSQL & "            , Komada" & vbCrLf
            stSQL = stSQL & "            , BrojCrteza" & vbCrLf
            stSQL = stSQL & "            , Proizvod" & vbCrLf
            
            stSQL = stSQL & "            , TezinaNeobrDela" & vbCrLf
            stSQL = stSQL & "            , NazivDela" & vbCrLf
            stSQL = stSQL & "            , IdentMaterijala" & vbCrLf
            stSQL = stSQL & "            , Materijal" & vbCrLf
            stSQL = stSQL & "            , DimenzijaMaterijala" & vbCrLf
            stSQL = stSQL & "            , JM" & vbCrLf
            stSQL = stSQL & "            , TezinaObrDela" & vbCrLf
            stSQL = stSQL & "            , Napomena" & vbCrLf
            stSQL = stSQL & "            , StatusRN" & vbCrLf
            stSQL = stSQL & "            , RokIzrade" & vbCrLf
            
            stSQL = stSQL & "            , DIVUnosaRN" & vbCrLf
            stSQL = stSQL & "            , DIVIspravkeRN" & vbCrLf
            stSQL = stSQL & "            , SifraRadnika" & vbCrLf
            stSQL = stSQL & "            , Zakljucano" & vbCrLf
            stSQL = stSQL & "            , Potpis" & vbCrLf
            stSQL = stSQL & "            , PrnTimer" & vbCrLf
            stSQL = stSQL & "            , VezaSaBrojemCrteza" & vbCrLf
            stSQL = stSQL & "            , IDVrstaKvaliteta" & vbCrLf
            
            stSQL = stSQL & "            , Revizija" & vbCrLf
            stSQL = stSQL & "            , IDPrimopredaje" & vbCrLf
            stSQL = stSQL & "            , IDCrtez" & vbCrLf
            stSQL = stSQL & "            , IDStatusPrimopredaje" & vbCrLf
            
            stSQL = stSQL & "            )" & vbCrLf
            stSQL = stSQL & "   VALUES" & vbCrLf
            stSQL = stSQL & "            (" & vbCrLf
            stSQL = stSQL & "            " & stR(rst![IDPredmet]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(IdentBroj, chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(nVarijanta) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![BBIDKomitent]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![BBNazivPredmeta], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatuma(rst![BBDatumOtvaranja], False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatuma(Date, False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(BrojKomada) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![BrojCrteza], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Proizvod], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            
            stSQL = stSQL & "            ," & stR(rst![TezinaObrDela]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![NazivDela], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![IdentMaterijala]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Materijal], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![DimenzijaMaterijala], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![JM], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![TezinaObrDela]) & vbCrLf
            'stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Napomena], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(stNapomena, ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & SQLFormatBoolean(rst![StatusRN]) & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatuma(rst![RokIzrade], False) & chNavodnici & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & chNavodnici & SQLFormatDatumIVreme(Now(), False) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![SifraRadnika]) & vbCrLf
            stSQL = stSQL & "            ," & SQLFormatBoolean(False) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & Replace(CurrentUser(), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(0) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![VezaSaBrojemCrteza], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(IDVrstaKvaliteta) & vbCrLf
            
            stSQL = stSQL & "            ," & chNavodnici & Replace(Nz(rst![Revizija], ""), chNavodnici, chNavodnici & chNavodnici) & chNavodnici & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![IDPrimopredaje]) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![IDCrtez]) & vbCrLf
            stSQL = stSQL & "            ," & stR(rst![IDStatusPrimopredaje]) & vbCrLf
            
            stSQL = stSQL & "            )" & vbCrLf
            
            SetClipboard stSQL
            
            retValOk = ADO_ExecSQL(CNN_CurrentDataBase, stSQL)
            
            NoviIDRN = ADO_IDENTITY 'ADO_Lookup(CNN_CurrentDataBase, "SELECT @@IDENTITY")
            
            If NoviIDRN <> 0 Then
                PrepisiStavkeIzNaloga NoviIDRN, ZaIDRN
                PrepisitPNDIzNaloga NoviIDRN, ZaIDRN
                PrepisitPLPIzNaloga NoviIDRN, ZaIDRN
                PrepisitPDMIzNaloga NoviIDRN, ZaIDRN
            End If
            
Exit_DugmePrepisiStavkeIzNaloga_Click:
    DoCmd.SetWarnings False
    KreirajNalogDoradeIliSkarta = NoviIDRN
    Exit Function
    
Err_DugmePrepisiStavkeIzNaloga_Click:
    MsgBox err.Description
    NoviIDRN = -1
    Resume Exit_DugmePrepisiStavkeIzNaloga_Click
    
End Function

Public Function SacuvajSkicuNapomenuNaServer(ByVal ImeFajla As String, ByVal BrojRadnogNaloga As String, ByVal Operacija As String, _
                                         ByVal VrstaPosla As String, ByRef novoImeFajla As String) As Boolean
On Error Resume Next

Dim msg, dirPath, fName, dirPathOperacija As String
Dim answer As Integer
Dim RootDir As String
Dim retValOk As Boolean
Dim folder As String

    retValOk = True
    
    fName = ImeFajla
    folder = KreirajFolderZaFajloveNaloga(BrojRadnogNaloga, Operacija, VrstaPosla)
    
    If folder = "" Then
        retValOk = False
        GoTo Exit_Point:
    Else
        While InStr(1, fName, "\") <> 0
            fName = Right$(fName, Len(fName) - InStr(1, fName, "\"))
        Wend
    
        novoImeFajla = folder & "\" & fName
    
        If FileExists(novoImeFajla) Then
            answer = MsgBox("Fajl " & fName & " veæ postoji!!!" & Chr(13) & "Da li želite da ovaj fajl zamenite novim?", vbYesNo + vbDefaultButton2 + vbInformation, "MegaRN")
            If answer = vbYes Then
                FileCopy ImeFajla, novoImeFajla
                msg = "Fajl " & ImeFajla & " je arhiviran!"
                answer = MsgBox(msg, 0)
            End If
        Else
            FileCopy ImeFajla, novoImeFajla
            msg = "Fajl " & fName & " je arhiviran!"
            answer = MsgBox(msg, 0)
        End If
    End If

Exit_Point:
    On Error Resume Next
   
    SacuvajSkicuNapomenuNaServer = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "Arhiviraj skicu ili napomenu na Server"
    retValOk = False
    Resume Exit_Point
    
    
End Function
Public Function NumCharInStr(st1, st2) As Variant
'broj pojavlivanje str2 u str1
Dim br As Long
Dim pom As String
Dim karakter As String
pom = st1
br = 0
While Len(pom) <> 0
 karakter = Left(pom, 1)
 If karakter = st2 Then
    br = br + 1
 End If
 pom = Right(pom, Len(pom) - 1)
Wend
NumCharInStr = br
End Function
Public Function F_PrikaziSamoBrojRN(BrojRN As String) As Long
' 24-1-0005-1/19   24-1-0005/19
    Dim BrojCrtica As Long
    Dim retVal As String
    
    If InStrRev(BrojRN, "/") <> 0 Then
        retVal = Left(BrojRN, InStrRev(BrojRN, "/") - 1)
    Else
        retVal = BrojRN
    End If
    BrojCrtica = NumCharInStr(retVal, "-")
    Select Case BrojCrtica
        Case 2, 1
            retVal = Right(retVal, Len(retVal) - InStrRev(retVal, "-"))
        Case 3
            retVal = Left(retVal, InStrRev(retVal, "-") - 1)
            retVal = Right(retVal, Len(retVal) - InStrRev(retVal, "-"))
        Case Else
            retVal = 0
    End Select
    F_PrikaziSamoBrojRN = val(retVal)
End Function
Public Function PostojiBrojRN(BrojRN As String, IDRN As Long) As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim ID As Long
    ID = Nz(DLookup("IDRN", "RN_Zaglavlja", "RNBroj = '" & BrojRN & "' And IDRN <> " & IDRN), 0)
    If ID = 0 Then
        retValOk = False
    Else
        retValOk = True
    End If
    
Exit_Point:
    On Error Resume Next
    PostojiBrojRN = retValOk

Exit Function

Err_Point:
    BBErrorMSG err, "PostojiBrojRN"
    retValOk = False
    Resume Exit_Point
End Function
Public Function DefinisiFolderNameZaRadniNalog(ByVal BrojNaloga As String) As String
On Error GoTo Err_Point
    Dim i As Integer
    Dim ch As String
    Dim retVal As String
    Dim AllowedChars As String

    AllowedChars = ".-_"
    retVal = ""

    For i = 1 To Len(BrojNaloga)
        ch = Mid(BrojNaloga, i, 1)

        Select Case ch
            Case " ", vbTab
                ' Ukloni razmake
            Case "\", "/"
                retVal = retVal & "_"
            Case Else
                If ch Like "[A-Za-z0-9]" Or InStr(AllowedChars, ch) > 0 Then
                    retVal = retVal & ch
                End If
        End Select
    Next i

Exit_Point:
    On Error Resume Next
    DefinisiFolderNameZaRadniNalog = retVal
Exit Function

Err_Point:
    BBErrorMSG err, "DefinisiFolderNameZaRadniNalog"
    Resume Exit_Point
End Function
Public Function KreirajFolderZaFajloveNaloga(ByVal stBrojNaloga As String, stOperacija As String, stVrstaPosla As String) As String
On Error GoTo Err_Point

    Dim FolderName As String
    Dim TrenutnaPutanja As String
    Dim PotpunaPutanja As String
    'Dim Counter As Integer
    Dim OsnovnaPutanja As String
    Dim msg As String
    Dim answer As Variant
    
    OsnovnaPutanja = RNP.RootFolderDokumentacije & stVrstaPosla
    
    FolderName = DefinisiFolderNameZaRadniNalog(stBrojNaloga)
    'TrenutnaPutanja = OsnovnaPutanja & "\" & FolderName
    TrenutnaPutanja = OsnovnaPutanja & FolderName
    
    ' Ako folder ne postoji, kreiraj odmah
    'If Dir(TrenutnaPutanja, vbDirectory) = "" Then
    '    MkDir TrenutnaPutanja
    'End If
    If Not DirExists(TrenutnaPutanja) Then
        MkDir TrenutnaPutanja
    End If
    
    If err Then
        msg = "Direktorijum " & TrenutnaPutanja & " ne moze da se otvori."
        msg = msg & Chr(13)
        msg = msg & "Proces arhiviranja fajla se prekida!"
        answer = MsgBox(msg, 0)
        'retValOk = False
        'Exit Sub
        PotpunaPutanja = ""
        GoTo Exit_Point:
    End If
    
    PotpunaPutanja = TrenutnaPutanja & "\" & stOperacija
    ' Ako folder ne postoji, kreiraj odmah
    'If Dir(PotpunaPutanja, vbDirectory) = "" Then
    '    MkDir PotpunaPutanja
    '    'KreirajFolderZaFajloveNaloga = PotpunaPutanja
    'End If
    If Not DirExists(PotpunaPutanja) Then
        MkDir PotpunaPutanja
    End If
    
    If err Then
        msg = "Direktorijum " & PotpunaPutanja & " ne moze da se otvori."
        msg = msg & Chr(13)
        msg = msg & "Proces arhiviranja fajla se prekida!"
        answer = MsgBox(msg, 0)
        'retValOk = False
        'Exit Sub
        PotpunaPutanja = ""
        GoTo Exit_Point:
    End If
    
    ' Ako postoji, dodaj sufiks [1], [2], ...
    'Counter = 1
    'Do
    '    PotpunaPutanja = OsnovnaPutanja & "\" & FolderName & " [" & Counter & "]"
    '    If Dir(PotpunaPutanja, vbDirectory) = "" Then
    '        MkDir PotpunaPutanja
    '        KreirajFolderZaFajloveNaloga = PotpunaPutanja
    '        Exit Function
    '    End If
    '    Counter = Counter + 1
    'Loop

Exit_Point:
    On Error Resume Next
    KreirajFolderZaFajloveNaloga = PotpunaPutanja
Exit Function

Err_Point:
    BBErrorMSG err, "KreirajFolderZaFajloveNaloga"
    PotpunaPutanja = ""
    Resume Exit_Point
End Function


Public Sub DefinisiPrikaziSkicu(ByVal nIDRN As Long, ByVal stIdentBroj As String, ByVal stOperacija As String)
    
    DoCmd.OpenForm "StavkeRNSlike"
    
    Forms!StavkeRNSlike!ZaIDRN = nIDRN
    Forms!StavkeRNSlike!ZaIdentBroj = stIdentBroj
    Forms!StavkeRNSlike!ZaOperacija = stOperacija
    
    Forms!StavkeRNSlike.Requery

    Forms!StavkeRNSlike!ZaIDRN.Requery
    Forms!StavkeRNSlike!ZaIdentBroj.Requery
    Forms!StavkeRNSlike!ZaOperacija.Requery
    
End Sub
Public Function PremestiPostavljneDatotekuUFolder() As Boolean
On Error GoTo Err_Point

    Dim db   As DAO.Database
    Dim rs   As DAO.Recordset
    Dim fso  As Object ' FileSystemObject za rad s datotekama
    
    Dim sLink       As String
    Dim sFileName   As String
    Dim sFolderName As String
    Dim sFolderPath As String
    
    ' 1) Otvorimo vezu i Recordset
    Set db = CurrentDb
    Set rs = db.OpenRecordset( _
        "SELECT [ID], [LinkSlika] " & _
        "FROM [tStavkeRNSlike] " & _
        "WHERE [LinkSlika] IS NOT NULL", _
        dbOpenDynaset)
    
    ' 2) FileSystemObject (late binding, ne trebate postavljati ref na Scripting)
    Set fso = CreateObject("Scripting.FileSystemObject")
    
    Do While Not rs.EOF
        sLink = rs!LinkSlika                ' puni path do JPG datoteke
        sFileName = fso.GetFileName(sLink)  ' npr. "slika.jpg"
        sFolderName = fso.GetBaseName(sFileName) ' npr. "slika"
        
        ' 3) Sastavimo puni put foldera (prilagodite root po potrebi)
        sFolderPath = "C:\MojiFolderi\" & sFolderName
        
        ' 4) Kreiramo folder (koristeæi vašu veæ gotovu funkciju)
        '    Oèekuje se da CreateFolder(path) stvara cijeli putak ako ne postoji
        KreirajFolderZaFajloveNaloga sFolderPath, "", ""
        
        ' 5) Premještanje datoteke
        On Error Resume Next
        fso.MoveFile Source:=sLink, _
                     Destination:=sFolderPath & "\" & sFileName
        If err.Number <> 0 Then
            Debug.Print "Greška pri premještanju: " & sLink & " › " & err.Description
            err.Clear
        Else
            ' 6) Po želji ažuriramo link i ime datoteke u bazi
            rs.Edit
            rs!LinkSlika = sFolderPath & "\" & sFileName
            rs!ImeFajla = sFileName
            rs.Update
        End If
        On Error GoTo 0
        
        rs.MoveNext
    Loop
    
Exit_Point:
    On Error Resume Next
     ' 7) Èišæenje objekata
    rs.Close
    Set rs = Nothing
    Set db = Nothing
    Set fso = Nothing
Exit Function

Err_Point:
    BBErrorMSG err, "PremestiPostavljneDatotekuUFolder"
    Resume Exit_Point
   
End Function

Public Sub DefinisiPrikaziDokumentaciju(ByVal nIDRN As Long, ByVal stIdentBroj As String, ByVal stOperacija As String)
    
    DoCmd.OpenForm "tTehPostupakDokumentacija"
    
    'Forms!tTehPostupakDokumentacija!ZaIDRN = nIDRN
    Forms!tTehPostupakDokumentacija!ZaIdentBroj = stIdentBroj
    Forms!tTehPostupakDokumentacija!ZaOperacija = stOperacija
    
    Forms!tTehPostupakDokumentacija.Requery

    'Forms!tTehPostupakDokumentacija!ZaIDRN.Requery
    Forms!tTehPostupakDokumentacija!ZaIdentBroj.Requery
    Forms!tTehPostupakDokumentacija!ZaOperacija.Requery
    
End Sub
Public Function F_RN_IDStatusDefLansiran() As Long
    F_RN_IDStatusDefLansiran = Nz(ReadCFGParametar("RN.IDStatusDefLansiran", 3), 3)
End Function
Private Function SledecaVrednostVarijante(nIDPredmet As Long, stBrojCrteza As String, stRevizija As String) As Integer
'Kreirano: 26-06-2025
On Error GoTo Err_Point
Dim retValVarijanta
   retValVarijanta = ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsSledecaVrednostVarijante", nIDPredmet, stBrojCrteza, stRevizija)
Exit_Point:
On Error Resume Next
   
   SledecaVrednostVarijante = CInt(Nz(retValVarijanta, 0))
   
Exit Function

Err_Point:

 BBErrorMSG err, "SledecaVrednostVarijante"
 retValVarijanta = 0
 Resume Exit_Point
End Function
Public Function StatusKvaliteta(Status As Integer) As String
    Dim stRetVal As String
    Select Case Status
        Case 0: stRetVal = "DOBAR"
        Case 1: stRetVal = "DORADA"
        Case 2: stRetVal = "ŠKART"
    End Select
    StatusKvaliteta = stRetVal
End Function

Public Function F_RN_IDStatusDefUObradi() As Long
    F_RN_IDStatusDefUObradi = Nz(ReadCFGParametar("RN.IDStatusDefUObradi", 0), 0)
End Function
Public Sub IzborNalogaZaPrepisivanje(ByVal IDRN As Long, ByVal formCaller As String)
    
    DoCmd.OpenForm "IzborNalogaZaPrepisivanje"
    Forms!IzborNalogaZaPrepisivanje!ZaIDRN = IDRN
    Forms!IzborNalogaZaPrepisivanje!formCaller = formCaller
End Sub
Public Function RN_NemaStavke(IDRN As Long) As Boolean
    On Error GoTo Err_Handler

    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    Dim sql As String

    Set db = CurrentDb

    sql = _
        "SELECT tRN.IDRN " & _
        "FROM (((tRN " & _
        "LEFT JOIN tPDM ON tRN.IDRN = tPDM.IDRN) " & _
        "LEFT JOIN tPLP ON tRN.IDRN = tPLP.IDRN) " & _
        "LEFT JOIN tPND ON tRN.IDRN = tPND.IDRN) " & _
        "LEFT JOIN tStavkeRN ON tRN.IDRN = tStavkeRN.IDRN " & _
        "WHERE tRN.IDRN = " & IDRN & " " & _
        "GROUP BY tRN.IDRN " & _
        "HAVING Nz(Sum(Nz(tPDM.IDStavkePDM,0) + Nz(tPLP.IDStavkePLP,0) + Nz(tPND.IDStavkePND,0) + Nz(tStavkeRN.IDStavkeRN,0)),0) = 0;"

    Set rs = db.OpenRecordset(sql, dbOpenSnapshot)

    RN_NemaStavke = Not rs.EOF

Exit_Handler:
    On Error Resume Next
    rs.Close
    Set rs = Nothing
    Set db = Nothing
    Exit Function

Err_Handler:
    RN_NemaStavke = False
    Resume Exit_Handler
End Function
Public Function RN_NemaStavke_ADO(ByVal CNNString As String, ByVal IDRN As Long) As Boolean
    On Error GoTo Err_Handler

    Dim rs As ADODB.Recordset
    Dim sql As String

    sql = "SELECT 1 AS Rezultat " & _
          "FROM (((tRN " & _
          "LEFT JOIN tPDM ON tRN.IDRN = tPDM.IDRN) " & _
          "LEFT JOIN tPLP ON tRN.IDRN = tPLP.IDRN) " & _
          "LEFT JOIN tPND ON tRN.IDRN = tPND.IDRN) " & _
          "LEFT JOIN tStavkeRN ON tRN.IDRN = tStavkeRN.IDRN " & _
          "WHERE tRN.IDRN = " & IDRN & " " & _
          "GROUP BY tRN.IDRN " & _
          "HAVING IsNull(Sum(IsNull(tPDM.IDStavkePDM,0) + IsNull(tPLP.IDStavkePLP,0) + IsNull(tPND.IDStavkePND,0) + IsNull(tStavkeRN.IDStavkeRN,0)),0) = 0"

    Set rs = ADO_GetRST(CNNString, sql, adLockReadOnly)
    RN_NemaStavke_ADO = Not rs.EOF

Exit_Point:
    On Error Resume Next
    rs.Close
    Set rs = Nothing
    Exit Function

Err_Handler:
    RN_NemaStavke_ADO = False
    Resume Exit_Point
End Function

