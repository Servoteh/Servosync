Attribute VB_Name = "APGK"
Option Compare Database
Option Explicit

Public Function DetaljnoStavkaUNaloguGK(ByVal IDStavkaGK As Long, Optional ByVal IDNalogaGK, Optional POPDVPopUp = False)
'Modifikovano: 13-10-2021
'Modifikovano: 15-12-2021
'Modifikovano: 29-01-2023
  On Error GoTo Err_DetaljnoStavkaUNaloguGK

    Dim stDocName As String
    Dim stLinkCriteria As String
    Dim UF As Boolean
    Dim Blagajna As Boolean
    Dim stavkazatrazenje As Long
    Dim fkctrl As control
    Dim pIDNalogaGK As Long
    Dim pGodinaNaloga As Long
    Dim stPitanje As String
        
        If IsMissing(IDNalogaGK) Then
          pIDNalogaGK = IDNalogaZaStavkuGK(IDStavkaGK)
        Else
          pIDNalogaGK = CLng(IDNalogaGK)
        End If
        
        Blagajna = False
        
        stavkazatrazenje = IDStavkaGK
        stLinkCriteria = "[IDNaloga]=" & pIDNalogaGK
        
        If Blagajna Then
           stDocName = "Blagajna"
        Else
           stDocName = BBCFG.UnosNalogaGK_FormName         ' "Unos naloga glavne knjige"
        End If
        
        '29-01-2023
        If IsLoaded(stDocName) Then
           DoCmd.Close acForm, stDocName, acSavePrompt
        End If
        
        'ako nije uspeo da zatvori formu ondakomentar
        If IsLoaded(stDocName) Then
           MsgBox "Za prikaz izabrane stavke u nalogu morate zatvoriti formu " & stDocName, vbExclamation, "QBigTeh"
           GoTo Exit_DetaljnoStavkaUNaloguGK
        End If
        
        pGodinaNaloga = Nz(ADO_Lookup(CNN_CurrentDataBase, "Godina", "T_Nalozi", stLinkCriteria), 0)
        If pGodinaNaloga <> F_Godina() Then
           stPitanje = ""
           stPitanje = stPitanje & "Ova stavka se nalazi u nalogu iz " & CStr(pGodinaNaloga) & ". godine, a vi ste sada u " & CStr(F_Godina()) & ". godini." & vbCrLf
           stPitanje = stPitanje & "Ako želite da vidite ovaj nalog morate da promenite godinu." & vbCrLf & vbCrLf
           stPitanje = stPitanje & "Da li želite da se ""prebacite"" u " & CStr(pGodinaNaloga) & " godinu?" & vbCrLf
           If BBPitanje(stPitanje) Then
              If IsLoaded("Prva maska") Then
                Forms("Prva maska")!Godina = pGodinaNaloga
                Forms("Prva maska")!Godina.Requery
              End If
              BBCFG.Godina = pGodinaNaloga
           Else
            GoTo Exit_DetaljnoStavkaUNaloguGK
           End If
        End If
        
        BBOpenForm stDocName                '15-12-2021 , , , stLinkCriteria
        PronadjiSlogNaFormi Forms(stDocName), stLinkCriteria  '15-12-2021
        
        If Blagajna Then
            DoCmd.GoToControl ("Stavke blagajne")
            Set fkctrl = Forms![Blagajna]![Stavke blagajne].Form![StavkaID]
        Else
            If BBCFG.UnosNalogaGK_FormName = "GKNalog" Then
             DoCmd.GoToControl ("Podforma")
             Set fkctrl = Forms(BBCFG.UnosNalogaGK_FormName)![Podforma].Form![StavkaID] 'Forms![Unos naloga glavne knjige]![Stavke naloga].Form![StavkaID]
            Else
             DoCmd.GoToControl ("Stavke naloga")
             Set fkctrl = Forms![Unos naloga glavne knjige]![Stavke Naloga].Form![StavkaID]
            End If
        End If
        fkctrl.Visible = True
        DoCmd.GoToControl fkctrl.Name
        DoCmd.FindRecord stavkazatrazenje
        DoCmd.GoToControl ("Konto")
        fkctrl.Visible = False
  If POPDVPopUp Then
   POPDVStavkeGK_PopUp IDStavkaGK
  End If
   
Exit_DetaljnoStavkaUNaloguGK:
    Exit Function

Err_DetaljnoStavkaUNaloguGK:
    MsgBox err.Description
    Resume Exit_DetaljnoStavkaUNaloguGK
    
End Function

Public Function OsnovicaPoPDVSemi(DugPot As Boolean, Duguje As Currency, Potrazuje As Currency, PDVOsnovica As Boolean, PDVStopa As Currency) As Currency
 Dim Iznos As Currency
 Dim Osnovica As Currency
 Dim PDV As Currency

    
    If DugPot Then
        Iznos = Duguje
    Else
        Iznos = Potrazuje
    End If
    
    If PDVOsnovica Then
     Osnovica = Round(Iznos, 2)
     PDV = Round(Osnovica * (PDVStopa / 100), 2)
    Else
     PDV = Round(Iznos, 2)
     Osnovica = Round(PDV / (PDVStopa / 100), 2)
    End If
    
  OsnovicaPoPDVSemi = Osnovica
    
End Function
Public Function PDVPoPDVSemi(DugPot As Boolean, Duguje As Currency, Potrazuje As Currency, PDVOsnovica As Boolean, PDVStopa As Currency) As Currency
 Dim Iznos As Currency
 Dim Osnovica As Currency
 Dim PDV As Currency

    
    If DugPot Then
        Iznos = Duguje
    Else
        Iznos = Potrazuje
    End If
    
    If PDVOsnovica Then
     Osnovica = Round(Iznos, 2)
     PDV = Round(Osnovica * (PDVStopa / 100), 2)
    Else
     PDV = Round(Iznos, 2)
     Osnovica = Round(PDV / (PDVStopa / 100), 2)
    End If
    
  PDVPoPDVSemi = PDV
    
End Function
Public Function DetaljnoRobnaStavkaUGK(IDDokIzRobnog)
On Error GoTo Err_Point
Dim IDStavkaGK
Dim IDNalogGK
   
 If Not IsNumeric(IDDokIzRobnog) Then
  MsgBox "Morate izabrati dokument!", vbExclamation, "QMegaTeh"
  Exit Function
 End If
 
    IDStavkaGK = ADO_Lookup(CNN_CurrentDataBase, "[StavkaID]", "[T_Glavna knjiga]", "[IDDokIzRobnog]=" & IDDokIzRobnog)
    If IsNumeric(IDStavkaGK) Then
      IDNalogGK = IDNalogaZaStavkuGK(CLng(IDStavkaGK))
     DetaljnoStavkaUNaloguGK IDStavkaGK, IDNalogGK
    Else
     MsgBox "Ovaj dokument nije proknjižen u GK.", vbInformation, "QMegaTeh"
    End If

Exit_Point:
On Error Resume Next
    
Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
    
End Function

Public Function DetaljnoUslugaStavkaUGK(IDDokIzUsluga)
'Kreirano: 15-11-2021
On Error GoTo Err_Point
Dim IDStavkaGK
Dim IDNalogGK
   
 If Not IsNumeric(IDDokIzUsluga) Then
  MsgBox "Morate izabrati dokument!", vbExclamation, "QMegaTeh"
  Exit Function
 End If
 
    IDStavkaGK = ADO_Lookup(CNN_CurrentDataBase, "[StavkaID]", "[T_Glavna knjiga]", "[IDDokIzUsluga]=" & IDDokIzUsluga)
    If IsNumeric(IDStavkaGK) Then
      IDNalogGK = IDNalogaZaStavkuGK(CLng(IDStavkaGK))
     DetaljnoStavkaUNaloguGK IDStavkaGK, IDNalogGK
    Else
     MsgBox "Ovaj dokument nije proknjižen u GK.", vbInformation, "QMegaTeh"
    End If

Exit_Point:
On Error Resume Next
    
Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
    
End Function
Public Function DetaljnoIDCM_IzlazUGK(IDCM_Izlaz)
'Kreirano: 16-12-2021
On Error GoTo Err_Point
Dim IDStavkaGK
Dim IDNalogGK
   
 If Not IsNumeric(IDCM_Izlaz) Then
  MsgBox "Morate izabrati dokument!", vbExclamation, "QMegaTeh"
  Exit Function
 End If
 
    IDStavkaGK = ADO_Lookup(CNN_CurrentDataBase, "[StavkaID]", "[T_Glavna knjiga]", "[IDCM_Izlaz]=" & IDCM_Izlaz)
    If IsNumeric(IDStavkaGK) Then
      IDNalogGK = IDNalogaZaStavkuGK(CLng(IDStavkaGK))
     DetaljnoStavkaUNaloguGK IDStavkaGK, IDNalogGK
    Else
     MsgBox "Ovaj dokument nije proknjižen u GK.", vbInformation, "QMegaTeh"
    End If

Exit_Point:
On Error Resume Next
    
Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
    
End Function
Public Function DetaljnoIDCM_UlazUGK(IDCM_Ulaz)
'Kreirano: 16-12-2021
On Error GoTo Err_Point
Dim IDStavkaGK
Dim IDNalogGK
   
 If Not IsNumeric(IDCM_Ulaz) Then
  MsgBox "Morate izabrati dokument!", vbExclamation, "QMegaTeh"
  Exit Function
 End If
 
    IDStavkaGK = ADO_Lookup(CNN_CurrentDataBase, "[StavkaID]", "[T_Glavna knjiga]", "[IDCM_Ulaz]=" & IDCM_Ulaz)
    If IsNumeric(IDStavkaGK) Then
      IDNalogGK = IDNalogaZaStavkuGK(CLng(IDStavkaGK))
     DetaljnoStavkaUNaloguGK IDStavkaGK, IDNalogGK
    Else
     MsgBox "Ovaj dokument nije proknjižen u GK.", vbInformation, "QMegaTeh"
    End If

Exit_Point:
On Error Resume Next
    
Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
    
End Function
Public Function DospelaPotrazivanja(ByVal IDKomitent As Long, Optional ByVal ZaKonto As String) As Currency
'Ofa funkcija radi samo
'Kreirano: 04-11-2022

On Error GoTo Err_Point
Dim retValOk As Boolean
Dim retValIznos As Currency
Dim stSQL As String
Dim rst As ADODB.Recordset

retValOk = True
retValIznos = 0

stSQL = PassTroughQueryEvalAllPar("ODBC_ftDospeloNedospelo")
Set rst = ADO_GetRST(CNN_CurrentDataBase, stSQL)
While Not rst.EOF
    If rst("Analiticka sifra") = IDKomitent And rst("Konto") Like ZaKonto Then
        retValIznos = rst("DospeloDuguje") - rst("DospeloPotrazuje")
    End If
    rst.MoveNext
Wend


'retValOk = ExecSPByRefPar("spGKS_AnalizaDugovanja",  "@IDFirma"=cstr(F_IDFirma()) _
                                                    , @Godina=Forms![GKS]![ZaGodinu] _
                                                    , @OdLevel=Forms![GKS]![OdLevel] _
                                                    , @DoLevel=Forms![GKS]![DoLevel] _
                                                    , @ZaKonto1=Forms![GKS]![ZaKonto1] _
                                                    , @ZaKonto2=Forms![GKS]![ZaKonto2] _
                                                    , @OdDatumaNal=Forms![GKS]![OdDatumaNaloga] _
                                                    , @DoDatumaNal=Forms![GKS]![DoDatumaNaloga] _
                                                    , @OdDatumaDok=Forms![GKS]![OdDatumaDok] _
                                                    , @DoDatumaDok=Forms![GKS]![DoDatumaDok] _
                                                    , @OdDatumaValute=Forms![GKS]![OdDatumaValute] _
                                                    , @DoDatumaValute=Forms![GKS]![DoDatumaValute] _
                                                    , @ValutaDoDatuma1=Forms![GKS]![Podforma].Form!ValutaDoDatuma1 _
                                                    , @ValutaDoDatuma2=Null, @ValutaDoDatuma3=Null _
                                                    , @ZaKomitenta=Forms![GKS]![ZaKomitenta] _
                                                    , @ZaProdavcaNaKomitentu=Forms![GKS]![ZaProdavcaNaKomitentu] _
                                                    , @ZaDeoNazivaKomitenta=Forms![GKS]![ZaDeoNazivaKomitenta] _
                                                    , @ZaRegion=Forms![GKS]![ZaRegion] _
                                                    , @ZaVozaca=DEFAULT _
                                                    , @ZaDevValutu=DEFAULT _
                                                    , @ZaPoziciju=Forms![GKS]![ZaPoziciju] _
                                                    , @ZaOJ=Forms![GKS]![ZaOJ] _
                                                    , @ZaOD=Forms![GKS]![ZaOD] _
                                                    , @UslovZaSaldo=DEFAULT _
                            )
'EXECUTE spGKS_AnalizaDugovanja @IDFirma=F_IDFirma(), @Godina=Forms![GKS]![ZaGodinu], @OdLevel=Forms![GKS]![OdLevel], @DoLevel=Forms![GKS]![DoLevel], @ZaKonto1=Forms![GKS]![ZaKonto1], @ZaKonto2=Forms![GKS]![ZaKonto2], @OdDatumaNal=Forms![GKS]![OdDatumaNaloga], @DoDatumaNal=Forms![GKS]![DoDatumaNaloga], @OdDatumaDok=Forms![GKS]![OdDatumaDok], @DoDatumaDok=Forms![GKS]![DoDatumaDok], @OdDatumaValute=Forms![GKS]![OdDatumaValute], @DoDatumaValute=Forms![GKS]![DoDatumaValute], @ValutaDoDatuma1=Forms![GKS]![Podforma].Form!ValutaDoDatuma1, @ValutaDoDatuma2=Null, @ValutaDoDatuma3=Null, @ZaKomitenta=Forms![GKS]![ZaKomitenta], @ZaProdavcaNaKomitentu=Forms![GKS]![ZaProdavcaNaKomitentu], @ZaDeoNazivaKomitenta=Forms![GKS]![ZaDeoNazivaKomitenta], @ZaRegion=Forms![GKS]![ZaRegion], @ZaVozaca=DEFAULT, @ZaDevValutu=DEFAULT, @ZaPoziciju=Forms![GKS]![ZaPoziciju], @ZaOJ=Forms![GKS]![ZaOJ], @ZaOD=Forms![GKS]![ZaOD], @UslovZaSaldo=DEFAULT


Exit_Point:
 On Error Resume Next
    rst.Close
    Set rst = Nothing
    
    DospelaPotrazivanja = retValIznos
       
Exit Function

Err_Point:
 BBErrorMSG err, "DospelaPotrazivanja"
 retValOk = False
 Resume Exit_Point

End Function

