Attribute VB_Name = "Uskladjivanje prodaje"
Option Compare Database   'Use database order for string comparisons
Option Explicit

Function F_UpisiPoslednjeKalkulativneCeneUProdaju()

    UpisiPoslednjeKalkulativneCeneUProdaju

End Function

Sub UpisiPoslednjeKalkCeneUProdajuOld()
On Error GoTo Greska
    Dim BigBit As DAO.Database
    Dim Prodaja As DAO.Recordset
    Dim LastKalkQ As DAO.QueryDef
    Dim LastKalk As DAO.Recordset
    Dim KalkVPCena As Currency
    Dim Criteria As String

    Set BigBit = CurrentDb
    Set Prodaja = BigBit.OpenRecordset("Stavke u dokumentima", DB_OPEN_DYNASET, dbSeeChanges)
    Set LastKalkQ = BigBit.QueryDefs("Poslednja KL za Artikal do datuma")

    
Prodaja.MoveFirst   ' Locate first record.

Do Until Prodaja.EOF    ' Begin loop.
    If (Not Prodaja![Ulaz]) And Abs(Prodaja![Kalkulativna VP cena]) < 0.01 Then
        
        LastKalkQ.Parameters("Do Datuma") = Prodaja![Datum dokumenta]
        LastKalkQ.Parameters("Za artikal") = Prodaja![Sifra artikla]
        Set LastKalk = LastKalkQ.OpenRecordset()
        LastKalk.MoveFirst
        KalkVPCena = Nz(LastKalk![LastOfKalkulativna VP cena], 0)
        Debug.Print LastKalkQ.Parameters("Za artikal") & "  VP= "; KalkVPCena
        LastKalk.Close

        Prodaja.Edit    ' Enable editing.
        Prodaja![Kalkulativna VP cena] = KalkVPCena
        Prodaja.Update  ' Save changes.

    End If
    Prodaja.MoveNext    ' Locate next record.
Loop ' End of loop.

Set BigBit = Nothing
Set Prodaja = Nothing
Set LastKalkQ = Nothing
Set LastKalk = Nothing

Exit Sub

Greska:
 MsgBox Error$
 Resume Next

End Sub

Sub UpisiPoslednjeKalkulativneCeneUProdaju()

On Error GoTo GreskaVP

    Dim BigBit As DAO.Database
    Dim TabZaPop As DAO.Recordset

    Dim SifArt As Long
    Dim KalkVP As Currency

    Set BigBit = CurrentDb
    Set TabZaPop = BigBit.OpenRecordset("QZaPopravkuVP", DB_OPEN_DYNASET, dbSeeChanges)
    
TabZaPop.MoveFirst                                      ' Pozicioniraj se na prvi rekord
SifArt = TabZaPop![Sifra artikla]
KalkVP = TabZaPop![Kalkulativna VP cena]

Do Until TabZaPop.EOF                                   ' Pocetak petlje

    If (TabZaPop![Ulaz]) Then
        SifArt = TabZaPop![Sifra artikla]
        KalkVP = TabZaPop![Kalkulativna VP cena]

    ElseIf SifArt = TabZaPop![Sifra artikla] Then
           TabZaPop.Edit                                ' Dozvoli izmene
           TabZaPop![Kalkulativna VP cena] = KalkVP
           TabZaPop.Update                              ' Sacuvaj izmene

    End If
    TabZaPop.MoveNext                                   ' Pozicioniraj se na sledeci rekord
    Debug.Print SifArt
Loop                                                    ' Kraj petlje

Set TabZaPop = Nothing
Set BigBit = Nothing

Exit Sub

GreskaVP:
 MsgBox Error$
 Resume Next

End Sub

Sub UpisiVazeceNabavneCene()

On Error GoTo GreskaNAB

    Dim BigBit As DAO.Database
    Dim TabZaPop As DAO.Recordset

    Dim SifArt As Long
    Dim KalkNAB As Currency

    Set BigBit = CurrentDb
    Set TabZaPop = BigBit.OpenRecordset("QZaPopravkuNAB", DB_OPEN_DYNASET, dbSeeChanges)
    
TabZaPop.MoveFirst                                      ' Pozicioniraj se na prvi rekord
SifArt = TabZaPop![Sifra artikla]
KalkNAB = TabZaPop![Kalkulativna NAB cena]

Do Until TabZaPop.EOF                                   ' Pocetak petlje

    If (TabZaPop![Ulaz]) Then
        SifArt = TabZaPop![Sifra artikla]
        KalkNAB = TabZaPop![Kalkulativna NAB cena]

    ElseIf SifArt = TabZaPop![Sifra artikla] Then
           TabZaPop.Edit                                ' Dozvoli izmene
           TabZaPop![Kalkulativna NAB cena] = KalkNAB
           TabZaPop.Update                              ' Sacuvaj izmene

    End If
    TabZaPop.MoveNext                                   ' Pozicioniraj se na sledeci rekord
    Debug.Print SifArt
Loop                                                    ' Kraj petlje

Set TabZaPop = Nothing
Set BigBit = Nothing

Exit Sub

GreskaNAB:
 ' MsgBox Error$
 Resume Next



End Sub

Sub UpisiProsecneNabiVPCeneUProdaju()

On Error GoTo GreskaProsNAB


    Dim BigBit As DAO.Database
    Dim TabZaPop As DAO.Recordset

    Dim SifArt As Long
    Dim StanjeNabVred As Currency
    Dim StanjeVPVred As Currency
    Dim StanjeKol As Double
    Dim PoslednjaNabCena As Currency
    Dim PoslednjaVPCena As Currency
    Dim BrDecimala As Long

    Set BigBit = CurrentDb()
    Set TabZaPop = BigBit.OpenRecordset("QZaUpisCenaUProdaju", dbOpenDynaset)
    
TabZaPop.MoveFirst                                      ' Pozicioniraj se na prvi rekord
SifArt = TabZaPop![Sifra artikla]
StanjeKol = 0#
StanjeNabVred = 0#
StanjeVPVred = 0#
BrDecimala = F_BrDecIzKl()

BeginTrans

Do Until TabZaPop.EOF                                   ' Pocetak petlje

    If (TabZaPop![Ulaz]) Then

        If SifArt = TabZaPop![Sifra artikla] Then
           StanjeKol = StanjeKol + TabZaPop![Kol]
           StanjeNabVred = StanjeNabVred + TabZaPop![NabCena] * TabZaPop![Kol]
           StanjeVPVred = StanjeVPVred + TabZaPop![VPCena] * TabZaPop![Kol]
           If Abs(StanjeKol) >= 0.01 Then
            PoslednjaNabCena = Round(StanjeNabVred / StanjeKol, BrDecimala)
            PoslednjaVPCena = Round(StanjeVPVred / StanjeKol, BrDecimala)
           End If
        Else
           SifArt = TabZaPop![Sifra artikla]
           StanjeKol = TabZaPop![Kol]
           StanjeNabVred = TabZaPop![NabCena] * TabZaPop![Kol]
           PoslednjaNabCena = TabZaPop![NabCena]
           StanjeVPVred = TabZaPop![VPCena] * TabZaPop![Kol]
           PoslednjaVPCena = TabZaPop![VPCena]
        End If

    Else
        If SifArt = TabZaPop![Sifra artikla] Then
           TabZaPop.Edit                                ' Dozvoli izmene
             If Abs(StanjeKol) >= 0.01 Then
              
              If (Forms![Kartica artikla]![Od datuma] <= TabZaPop![Datum dokumenta]) And (TabZaPop![Datum dokumenta] <= Forms![Kartica artikla]![Do datuma]) Then
                TabZaPop![NabCenaZaUpis] = Round(StanjeNabVred / StanjeKol, BrDecimala)
                TabZaPop![VPCena] = Round(StanjeVPVred / StanjeKol, BrDecimala)
              End If
              
                StanjeKol = StanjeKol + TabZaPop![Kol]
                StanjeNabVred = StanjeNabVred + TabZaPop![NabCena] * TabZaPop![Kol]
                PoslednjaNabCena = TabZaPop![NabCena]
                StanjeVPVred = StanjeVPVred + TabZaPop![VPCena] * TabZaPop![Kol]
                PoslednjaVPCena = TabZaPop![VPCena]
                
             Else
                 If (Forms![Kartica artikla]![Od datuma] <= TabZaPop![Datum dokumenta]) And (TabZaPop![Datum dokumenta] <= Forms![Kartica artikla]![Do datuma]) Then
                    TabZaPop![NabCenaZaUpis] = PoslednjaNabCena
                    TabZaPop![VPCena] = PoslednjaVPCena
                 End If
             End If
           TabZaPop.Update                              ' Sacuvaj izmene
        End If

    End If
    TabZaPop.MoveNext                                   ' Pozicioniraj se na sledeci rekord
    Debug.Print SifArt
Loop                                                    ' Kraj petlje

Exit_ProsNab:

If MsgBox("Upisati nove prosecne nabavne i VP cene u SVE kartice?" _
           & vbCr & "Ako odgovorite sa Yes ne mozete vratiti na prethodno!" _
           , vbYesNo) = vbYes Then
          CommitTrans   'wrkDefault.CommitTrans
        Else
          Rollback      'wrkDefault.Rollback
        End If

        

TabZaPop.Close
Set TabZaPop = Nothing
BigBit.Close
Set BigBit = Nothing

Exit Sub

GreskaProsNAB:
 MsgBox Error$
 Resume Exit_ProsNab

End Sub

Public Sub UpisiIDStavOtpremeuMP()
    On Error GoTo GreskaUpis


    Dim BigBit As DAO.Database
    Dim RMP_OtpremaIProdaja As DAO.Recordset
    Dim MPStavke As DAO.Recordset

    Dim IDProdavnice, SifArt, IDStavMagOtpreme As Long
    

    Set BigBit = CurrentDb()
    Set RMP_OtpremaIProdaja = BigBit.OpenRecordset("RMP_OtpremaIProdaja", dbOpenDynaset)
    Set MPStavke = BigBit.OpenRecordset("T_MPStavke", dbOpenDynaset)
    
RMP_OtpremaIProdaja.MoveFirst                                      ' Pozicioniraj se na prvi rekord

DoCmd.Hourglass True
BeginTrans

Do Until RMP_OtpremaIProdaja.EOF                                   ' Pocetak petlje
   'Pronadji prvu/sledecu otpremu
   '!!!!TREBALO BI NAPRAVITI I UPISIVANJE 0 U "PRVE" [IDStavMagOtpreme] u te stavke !!!!
   Do While Not RMP_OtpremaIProdaja.EOF
       If RMP_OtpremaIProdaja![Otprema] Then
         IDProdavnice = RMP_OtpremaIProdaja![Sifra komitenta]
         SifArt = RMP_OtpremaIProdaja![Sifra artikla]
         IDStavMagOtpreme = RMP_OtpremaIProdaja![IDStavke]
         RMP_OtpremaIProdaja.MoveNext
       Else
        Exit Do
       End If
   Loop
    
    Do While Not RMP_OtpremaIProdaja.EOF
          
       If RMP_OtpremaIProdaja![Sifra komitenta] = IDProdavnice And _
             RMP_OtpremaIProdaja![Sifra artikla] = SifArt And _
             Not RMP_OtpremaIProdaja![Otprema] Then
             MPStavke.FindFirst "IDStavke = " & RMP_OtpremaIProdaja![IDStavke]
                        If MPStavke.NoMatch Then
                           MsgBox "Koja je ovo glupost!?"
                           GoTo Exit_Upis
                        End If
             MPStavke.Edit
             MPStavke![IDStavMagOtpreme] = IDStavMagOtpreme
             MPStavke.Update
             Debug.Print SifArt
             RMP_OtpremaIProdaja.MoveNext
     Else
        Exit Do
     End If
    Loop
 
Loop                                                    ' Kraj petlje

Exit_Upis:
DoCmd.Hourglass False
If MsgBox("Upisati nove ID otpreme iz magacina u SVE stavke?" _
           & vbCr & "Ako odgovorite sa Yes ne mozete vratiti na prethodno!" _
           , vbYesNo) = vbYes Then
          CommitTrans   'wrkDefault.CommitTrans
        Else
          Rollback      'wrkDefault.Rollback
        End If

        

RMP_OtpremaIProdaja.Close
Set RMP_OtpremaIProdaja = Nothing

MPStavke.Close
Set MPStavke = Nothing

BigBit.Close
Set BigBit = Nothing

Exit Sub

GreskaUpis:
 MsgBox Error$
 Resume Exit_Upis

End Sub

Public Function DaLiImaNegZalihe(IDArtikal As Long, DoDatuma, ZaMagacin, OdLevel As Byte, DoLevel As Byte) As Boolean
    Dim retVal As Boolean
    Dim BigBit As DAO.Database
    Dim QZaNegZal As DAO.Recordset
    Dim QDefZaNegZal As DAO.QueryDef
    
    Set BigBit = CurrentDb
    Set QDefZaNegZal = BigBit.QueryDefs("NZ_NegativneZalihe")
    QDefZaNegZal.Parameters("[Forms]![NZF_NegativneZalihe]![ComboZaArtikal]") = IDArtikal
    QDefZaNegZal.Parameters("[Forms]![NZF_NegativneZalihe]![DoDatuma]") = CVDate(Nz([DoDatuma], #12/31/2099#))
    QDefZaNegZal.Parameters("[Forms]![NZF_NegativneZalihe]![ZaMagacin]") = ZaMagacin
    QDefZaNegZal.Parameters("[Forms]![NZF_NegativneZalihe]![OdLevel]") = OdLevel
    QDefZaNegZal.Parameters("[Forms]![NZF_NegativneZalihe]![DoLevel]") = DoLevel
    Set QZaNegZal = QDefZaNegZal.OpenRecordset()
    'Debug.Print QZaNegZal.RecordCount
    retVal = (QZaNegZal.RecordCount > 0)
    QZaNegZal.Close
    Set QZaNegZal = Nothing
    
    QDefZaNegZal.Close
    Set QDefZaNegZal = Nothing
    BigBit.Close
    Set BigBit = Nothing
    DaLiImaNegZalihe = retVal
End Function
Sub UpisiProsecneNabiVPCeneUProdajuZaArt(IDArtikal As Long, ZaMagacin, OdLevel As Byte, DoLevel As Byte, OdDatuma, DoDatuma)

On Error GoTo GreskaProsNAB


    Dim BigBit As DAO.Database
    Dim QDefTabZaPop As DAO.QueryDef
    Dim TabZaPop As DAO.Recordset

    Dim SifArt As Long
    Dim StanjeNabVred As Double
    Dim StanjeVPVred As Double
    Dim StanjeKol As Double
    Dim PoslednjaNabCena As Double
    Dim PoslednjaVPCena As Double
    Dim BrDecimala As Long
    Dim NZOdDatuma, NZDoDatuma As Date

    NZOdDatuma = CVDate(Nz(OdDatuma, #1/1/1901#))
    NZDoDatuma = CVDate(Nz(DoDatuma, #12/31/2099#))
    
    Set BigBit = CurrentDb()
    Set QDefTabZaPop = BigBit.QueryDefs("QZaUpisCenaUProdaju1Artikal")
    QDefTabZaPop.Parameters("ZaArtikal") = IDArtikal
    QDefTabZaPop.Parameters("ZaMagacin") = ZaMagacin
    QDefTabZaPop.Parameters("OdLevel") = OdLevel
    QDefTabZaPop.Parameters("DoLevel") = DoLevel
    
    Set TabZaPop = QDefTabZaPop.OpenRecordset()
    
TabZaPop.MoveFirst                                      ' Pozicioniraj se na prvi rekord
SifArt = TabZaPop![Sifra artikla]
StanjeKol = 0#
StanjeNabVred = 0#
StanjeVPVred = 0#
BrDecimala = F_BrDecIzKl()

BeginTrans

Do Until TabZaPop.EOF                                   ' Pocetak petlje

    If (TabZaPop![Ulaz]) Then

        If SifArt = TabZaPop![Sifra artikla] Then
           StanjeKol = StanjeKol + TabZaPop![Kol]
           StanjeNabVred = StanjeNabVred + TabZaPop![NabCena] * TabZaPop![Kol]
           StanjeVPVred = StanjeVPVred + TabZaPop![VPCena] * TabZaPop![Kol]
           If Abs(StanjeKol) >= 0.01 Then
            'PoslednjaNabCena = Round(StanjeNabVred / StanjeKol, BrDecimala)
            PoslednjaNabCena = StanjeNabVred / StanjeKol
            PoslednjaVPCena = Round(StanjeVPVred / StanjeKol, BrDecimala)
           End If
        Else
           SifArt = TabZaPop![Sifra artikla]
           StanjeKol = TabZaPop![Kol]
           StanjeNabVred = TabZaPop![NabCena] * TabZaPop![Kol]
           PoslednjaNabCena = TabZaPop![NabCena]
           StanjeVPVred = TabZaPop![VPCena] * TabZaPop![Kol]
           PoslednjaVPCena = TabZaPop![VPCena]
        End If

    Else
        If SifArt = TabZaPop![Sifra artikla] Then
           TabZaPop.Edit                                ' Dozvoli izmene
             If Abs(StanjeKol) >= 0.01 Then
              
              If (NZOdDatuma <= TabZaPop![Datum dokumenta]) And (TabZaPop![Datum dokumenta] <= NZDoDatuma) Then
                'TabZaPop![NabCenaZaUpis] = Round(StanjeNabVred / StanjeKol, BrDecimala)
                TabZaPop![NabCenaZaUpis] = StanjeNabVred / StanjeKol
                TabZaPop![VPCena] = Round(StanjeVPVred / StanjeKol, BrDecimala)
              End If
              
                StanjeKol = StanjeKol + TabZaPop![Kol]
                StanjeNabVred = StanjeNabVred + TabZaPop![NabCena] * TabZaPop![Kol]
                PoslednjaNabCena = TabZaPop![NabCena]
                StanjeVPVred = StanjeVPVred + TabZaPop![VPCena] * TabZaPop![Kol]
                PoslednjaVPCena = TabZaPop![VPCena]
                
             Else
                 If (NZOdDatuma <= TabZaPop![Datum dokumenta]) And (TabZaPop![Datum dokumenta] <= NZDoDatuma) Then
                    TabZaPop![NabCenaZaUpis] = PoslednjaNabCena
                    TabZaPop![VPCena] = PoslednjaVPCena
                 End If
             End If
           TabZaPop.Update                              ' Sacuvaj izmene
        End If

    End If
    TabZaPop.MoveNext                                   ' Pozicioniraj se na sledeci rekord
    'Debug.Print SifArt
Loop                                                    ' Kraj petlje


If MsgBox("Upisati nove prosecne nabavne i VP cene u karticu?" _
           & vbCr & "Ako odgovorite sa Yes ne mozete vratiti na prethodno!" _
           , vbYesNo, "QMegaTeh") = vbYes Then
          CommitTrans   'wrkDefault.CommitTrans
        Else
          Rollback      'wrkDefault.Rollback
        End If

Exit_ProsNab:
On Error Resume Next

QDefTabZaPop.Close
Set QDefTabZaPop = Nothing
TabZaPop.Close
Set TabZaPop = Nothing
BigBit.Close
Set BigBit = Nothing

Exit Sub

GreskaProsNAB:
 MsgBox Error$
 Rollback
 Resume Exit_ProsNab

End Sub
'*****************************************************************************
'Created: 26-11-2018
Public Function BBT_ProsUlNabCene_UpisiUProdaju() As Boolean
On Error GoTo Err_Point:
Dim retValOk As Boolean
  retValOk = KreirajTmpTabeluUTmpBazi("tmp_BBT_ProsUlNabCene", "BBT_ProsUlNabCene", , , , "Sifra artikla")
  
  DoCmd.SetWarnings False
  DoCmd.OpenQuery "BBT_ProsUlNabCene_UpisiUProdaju", acViewNormal, acEdit
  DoCmd.SetWarnings True
  

Exit_Point:
   On Error Resume Next
   DoCmd.SetWarnings True
   BBT_ProsUlNabCene_UpisiUProdaju = retValOk
Exit Function
Err_Point:
 BBErrorMSG err, "BBT_ProsUlNabCene_UpisiUProdaju"
 retValOk = False
 Resume Exit_Point
End Function

'*****************************************************************************
'Created: 05-12-2019
'treba jos da se radi!
Private Function BBT_ObrisiArtikal(IDArtikal As Long) As Boolean
On Error GoTo Err_Point:

Dim retValOk As Boolean
Dim stDELETESql
  retValOk = True
  
  DoCmd.SetWarnings False
   stDELETESql = "DELETE  FROM T_Recepti WHERE T_Recepti.ZaSifruArtikla=" & IDArtikal
   DoCmd.RunSQL stDELETESql
   
  DoCmd.SetWarnings True
  

Exit_Point:
   On Error Resume Next
   DoCmd.SetWarnings True
   BBT_ObrisiArtikal = retValOk
Exit Function
Err_Point:
 BBErrorMSG err, "BBT_ObrisiArtikal"
 retValOk = False
 Resume Exit_Point
End Function
'*****************************************************************************
'Created: 05-12-2019
Public Function BBT_PopraviPLU() As Boolean
On Error GoTo Err_Point:

Dim retValOk As Boolean
Dim rstArtikli As DAO.Recordset
Dim brojac As Long

 retValOk = True
 Set rstArtikli = CurrentDb.OpenRecordset("SELECT * FROM R_Artikli ORDER BY [Sifra artikla]", dbOpenDynaset, dbSeeChanges)
 rstArtikli.MoveFirst
 brojac = 0
 While Not rstArtikli.EOF
  
  brojac = brojac + 1
  rstArtikli.Edit
  rstArtikli!PLU = brojac
  rstArtikli.Update
  
  rstArtikli.MoveNext
 Wend
 
Exit_Point:
 On Error Resume Next
   rstArtikli.Close
   Set rstArtikli = Nothing
   
   BBT_PopraviPLU = retValOk
Exit Function
Err_Point:
 BBErrorMSG err, "BBT_PopraviPLU"
 retValOk = False
 Resume Exit_Point
End Function
'*****************************************************************************
'Kreirano: 04-02-2020
Public Function BBT_ProsUlNabCene_UpisiUCenovnik() As Boolean
On Error GoTo Err_Point:
Dim retValOk As Boolean

  retValOk = KreirajTmpTabeluUTmpBazi("tmp_BBT_ProsUlNabCene", "BBT_ProsUlNabCene", , , , "Sifra artikla")
  
  DoCmd.SetWarnings False
  DoCmd.OpenQuery "BBT_ProsUlNabCene_UpisiUCenovnik_UPDATE", acViewNormal, acEdit
  DoCmd.OpenQuery "BBT_ProsUlNabCene_UpisiUCenovnik_INSERT", acViewNormal, acEdit
  DoCmd.SetWarnings True
  

Exit_Point:
   On Error Resume Next
   DoCmd.SetWarnings True
   BBT_ProsUlNabCene_UpisiUCenovnik = retValOk
Exit Function
Err_Point:
 BBErrorMSG err, "BBT_ProsUlNabCene_UpisiUCenovnik"
 retValOk = False
 Resume Exit_Point
End Function
'*****************************************************************************
'Kreirano: 17-08-2020
'Modifikovano: 04-09-2020
Public Function spUpisiProsULNCUCenovnik(CenovnikVrstaDok As String, IDFirma As Long, Godina As Long, _
                                                        OdLevel As Byte, DoLevel As Byte, IDMagacin, _
                                                        OdDatuma As Date, DoDatuma As Date, _
                                                        KlCeheckInternaDokumenta, _
                                                        ZaGrupu, ZaPodgrupu, ZaPoreklo) As Boolean

'     @CenovnikVrstaDok nvarchar(50) = 'ProsULNC'
'    ,@IDFirma int = Null
'    ,@Godina int = Null
'    ,@OdLevel int = Null
'    ,@DoLevel int = Null
'    ,@IDMagacin int = Null
'    ,@OdDatuma Date = Null
'    ,@DoDatuma Date = Null

'    ,@KLCheckInternaDokumenta bit = Null
'    ,@ZaGrupu as nvarchar(10) = Null
'    ,@ZaPodgrupu as nvarchar(10) = Null
'    ,@ZaPoreklo as nvarchar(10) = Null
On Error GoTo Err_Point:
Dim retValOk As Boolean

  retValOk = ADO_ExecSP(BBCFG.CNNString, "spUpisiProsULNCUCenovnik", CenovnikVrstaDok, IDFirma, Godina, OdLevel, DoLevel, _
                                            IDMagacin, SQLFormatDatuma(OdDatuma, False), SQLFormatDatuma(DoDatuma, False), _
                                            SQLFormatBoolean(KlCeheckInternaDokumenta), _
                                            ZaGrupu, ZaPodgrupu, ZaPoreklo)
                                            
  

Exit_Point:
   On Error Resume Next
   DoCmd.SetWarnings True
   spUpisiProsULNCUCenovnik = retValOk
Exit Function
Err_Point:
 BBErrorMSG err, "spUpisiProsULNCUCenovnik"
 retValOk = False
 Resume Exit_Point
End Function
'*****************************************************************************
'Kreirano: 17-08-2020
Public Function spNabCeneIzCenovnika_UpisiUProdaju(CenovnikVrstaDok As String, IDFirma As Long, Godina As Long, _
                                                        OdLevel As Byte, DoLevel As Byte, IDMagacin, _
                                                        OdDatuma As Date, DoDatuma As Date, _
                                                        VrstaDokumentaProdaje) As Boolean

 '    @CenovnikVrstaDok nvarchar(50)
 '   ,@IDFirma int = Null
 '   ,@Godina int = Null
 '   ,@OdLevel int = Null
 '   ,@DoLevel int = Null
 '   ,@IDMagacin int = Null
 '   ,@OdDatuma Date = Null
 '   ,@DoDatuma Date = Null
 '   ,@VrstaDokumentaProdaje nvarchar(50)
On Error GoTo Err_Point:
Dim retValOk As Boolean

  retValOk = ADO_ExecSP(BBCFG.CNNString, "spNabCeneIzCenovnika_UpisiUProdaju", CenovnikVrstaDok, IDFirma, Godina, OdLevel, DoLevel, _
                                            IDMagacin, SQLFormatDatuma(OdDatuma, False), SQLFormatDatuma(DoDatuma, False), _
                                            VrstaDokumentaProdaje)
                                            
  

Exit_Point:
   On Error Resume Next
   DoCmd.SetWarnings True
   spNabCeneIzCenovnika_UpisiUProdaju = retValOk
Exit Function
Err_Point:
 BBErrorMSG err, "spNabCeneIzCenovnika_UpisiUProdaju"
 retValOk = False
 Resume Exit_Point
End Function

'*****************************************************************************
'Kreirano: 04-09-2020
Public Function spNabCeneIzCenovnika_Upisi_NC_KLVP(CenovnikVrstaDok As String, UlaznaDokumenta, IDFirma As Long, Godina As Long, _
                                                        OdLevel As Byte, DoLevel As Byte, IDMagacin, _
                                                        OdDatuma As Date, DoDatuma As Date, _
                                                        VrstaDokumentaProdaje) As Boolean

 '    @CenovnikVrstaDok nvarchar(50)
 '    @IzlaznaDokumenta bit = 0
 '   ,@IDFirma int = Null
 '   ,@Godina int = Null
 '   ,@OdLevel int = Null
 '   ,@DoLevel int = Null
 '   ,@IDMagacin int = Null
 '   ,@OdDatuma Date = Null
 '   ,@DoDatuma Date = Null
 '   ,@VrstaDokumentaProdaje nvarchar(50)
On Error GoTo Err_Point:
Dim retValOk As Boolean

  retValOk = ADO_ExecSP(BBCFG.CNNString, "spNabCeneIzCenovnika_Upisi_NC_KLVP", CenovnikVrstaDok, UlaznaDokumenta, IDFirma, Godina, OdLevel, DoLevel, _
                                            IDMagacin, SQLFormatDatuma(OdDatuma, False), SQLFormatDatuma(DoDatuma, False), _
                                            VrstaDokumentaProdaje)
                                            
  

Exit_Point:
   On Error Resume Next
   DoCmd.SetWarnings True
   spNabCeneIzCenovnika_Upisi_NC_KLVP = retValOk
Exit Function
Err_Point:
 BBErrorMSG err, "spNabCeneIzCenovnika_Upisi_NC_KLVP"
 retValOk = False
 Resume Exit_Point
End Function

