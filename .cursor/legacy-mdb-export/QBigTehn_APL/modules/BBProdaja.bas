Attribute VB_Name = "BBProdaja"
Option Compare Database
Option Explicit

Public Function MP_UpisiURacunProdaju(IDArtikal As Long, KolicinaZaProdaju As Double, ProdDinCena As Currency, PDVTarifa As String) As Boolean
Dim rs As Object
Dim OK As Boolean
OK = True
    If Nz(IDArtikal, 0) = 0 Then
       OK = False
       MsgBox "Morate odrediti artikal.", vbExclamation, "QMegaTeh"
    ElseIf Not IsNumeric(KolicinaZaProdaju) Or Nz(KolicinaZaProdaju, 0) = 0 Then
        OK = False
       MsgBox "Morate uneti kolicinu.", vbExclamation, "QMegaTeh"
    ElseIf Nz(ProdDinCena, 0) = 0 Then
       OK = False
       MsgBox "Nekorektna prodajna cena.", vbExclamation, "QMegaTeh"
    End If
    
If OK And IsLoaded("MPRacun") Then
    If Forms![MPRacun]![MPRacun-Podforma].[Form].AllowAdditions Or Forms![MPRacun]![MPRacun-Podforma].[Form].AllowEdits Then
    
        Forms![MPRacun]![MPRacun-Podforma].Form![ComboSifraArtikla] = IDArtikal
        Forms![MPRacun]![MPRacun-Podforma].Form![Kolicina] = Nz(KolicinaZaProdaju, 0)
        Forms![MPRacun]![MPRacun-Podforma].Form![StvarnaMPCena] = Nz(ProdDinCena, 0)
        Forms![MPRacun]![MPRacun-Podforma].Form![TarifaRoba] = PDVTarifa
    
        'DoCmd.Close
        BBOpenForm "MPRacun"
        DoCmd.GoToControl "MPRacun-Podforma"
        On Error Resume Next
        DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70
     
        Set rs = Forms![MPRacun]![MPRacun-Podforma].RecordsetClone
    
        Forms![MPRacun]![MPRacun-Podforma].Requery
        If Not rs.EOF Then Forms![MPRacun]![MPRacun-Podforma].Bookmark = rs.Bookmark
        DoCmd.GoToRecord , , A_NEWREC
        'Forms![Racun]![Racun - Podforma].GoToRecord , , A_NEWREC
        OK = True
    Else
        MsgBox "Racun je zakljucan!", vbCritical, "QMegaTeh"
        OK = False
    End If
End If
    MP_UpisiURacunProdaju = OK
End Function
Public Function VP_UpisiURacunProdaju_NETREBA(ByVal IDDok As Long, IDMagacin As Long, ByVal IDArtikal As Long, ByVal Kolicina As Double, ByVal VPCena As Currency) As Boolean
On Error GoTo err_Func
        Dim BigBit As DAO.Database
        Dim QZaCene As DAO.Recordset
        Dim DefQZaCene As DAO.QueryDef
        Dim RobneStavke As DAO.Recordset
        Dim retVal As Boolean
        
        retVal = True
        Set BigBit = CurrentDb
        Set DefQZaCene = BigBit.QueryDefs("VP_Cene")
         
        Set QZaCene = DefQZaCene.OpenRecordset()
        Set RobneStavke = BigBit.OpenRecordset("T_Robne stavke", dbOpenDynaset, dbSeeChanges)
        
        QZaCene.FindFirst ("[IDArtikal]  = " & IDArtikal)
        If (QZaCene.NoMatch) Then
            retVal = False
            If F_ProveraZalihaMag() Then
                MsgBox "Nije nadjena ulazna kalkulacija!", vbCritical, "QMegaTeh"
            End If
        Else
            RobneStavke.AddNew
            
            RobneStavke!IDDok = IDDok
            RobneStavke!IDMagacin = IDMagacin
            RobneStavke![Sifra artikla] = IDArtikal
            RobneStavke![Kolicina] = Kolicina
            RobneStavke![Zavisni trosak - sopstveni] = 0
            RobneStavke![Zavisni trosak - dobavljac] = 0
            RobneStavke![Nabavna cena - neto] = IIf(QZaCene![ProsecnaNabavnaCena] <= 0.001, Nz(QZaCene![PoslednjaNabavnaCena], 0), QZaCene![ProsecnaNabavnaCena])
            RobneStavke![Kalkulativna VP cena] = QZaCene![PoslednjaVPCena]
            RobneStavke![Kalkulativna MP cena] = QZaCene![PoslednjaMPCena]
            
            RobneStavke![Stvarna VP cena] = VPCena
            RobneStavke![Stvarna MP cena] = Round(VPCena * (1 + QZaCene!PDVStopa / 100), 2)
            
            RobneStavke![TAKSA] = 0
            RobneStavke![Obracunat porez na ulazu - roba] = False
            RobneStavke![Tarifa - roba - ulaz] = QZaCene![Tarifa robe]
            RobneStavke![Obracunat porez na usluge] = False
            RobneStavke![Tarifa - usluge - izlaz] = "1"
            RobneStavke![Obracunat  porez na robu] = True
            RobneStavke![Tarifa - roba - Izlaz] = QZaCene![Tarifa robe]
            'RobneStavke![KasaProc] = QZaCene![KasaProc]
            'RobneStavke![Rabatproc] = QZaCene![Rabatproc]
            'RobneStavke![Robne stavke.Odlozeno] = QZaCene![Odlozeno]
            RobneStavke![Neoporezivi deo] = 0
            RobneStavke![Akciza] = 0
            RobneStavke![FiksniPorez] = 0
            RobneStavke![DevNabCena] = 0
            
            RobneStavke.Update
            
        End If
exit_Func:
On Error Resume Next
        RobneStavke.Close
        Set RobneStavke = Nothing
        QZaCene.Close
        Set QZaCene = Nothing
        Set DefQZaCene = Nothing
        Set BigBit = Nothing
 VP_UpisiURacunProdaju_NETREBA = retVal
Exit Function
err_Func:
    retVal = False
    MsgBox "Err: " & err.Number & vbCrLf & err.Description, vbCritical, "BigBit (VP_UpisiURacunProdaju_NETREBA)"
    Resume exit_Func
End Function
Public Function VP_UpisiURacunProdaju(ByVal IDDok As Long, IDMagacin As Long, ByVal IDArtikal As Long, ByVal Kolicina As Double, ByVal VPCena As Currency) As Boolean
'Modifikovano: 29-01-2021
On Error GoTo err_Func
        
        Dim QZaKL As ADODB.Recordset
        Dim stSQL As String
        
        Dim BigBit As DAO.Database
        Dim RobneStavke As DAO.Recordset
        Dim retVal As Boolean
        
        retVal = True
        Set BigBit = CurrentDb
        Set RobneStavke = BigBit.OpenRecordset("T_Robne stavke", dbOpenDynaset, dbSeeChanges)
        
        
        stSQL = TextSelectQForUDFT("ftPoslednjaKL", F_IDFirma(), Null, 0, F_NivoBaze(), IDMagacin, SQLFormatDatuma(F_DoDatuma()), IDArtikal, "DEFAULT", "DEFAULT", "DEFAULT", "DEFAULT", "DEFAULT")
        Set QZaKL = ADO_GetRST(BBCFG.CNNString, stSQL)
        QZaKL.Find ("[Sifra artikla]  = " & stR(IDArtikal))
        
        If QZaKL.EOF Then
            retVal = False
            If F_ProveraZalihaMag() Then
                MsgBox "Nije nadjena ulazna kalkulacija!", vbCritical, "QMegaTeh"
            End If
        Else
            RobneStavke.AddNew
            
            RobneStavke!IDDok = IDDok
            RobneStavke!IDMagacin = IDMagacin
            RobneStavke![Sifra artikla] = IDArtikal
            RobneStavke![Kolicina] = Kolicina
            RobneStavke![Zavisni trosak - sopstveni] = 0
            RobneStavke![Zavisni trosak - dobavljac] = 0
            'RobneStavke![Nabavna cena - neto] = IIf(QZaCene![ProsecnaNabavnaCena] <= 0.001, Nz(QZaCene![PoslednjaNabavnaCena], 0), QZaCene![ProsecnaNabavnaCena])
            RobneStavke![Nabavna cena - neto] = ProsNCZaArt(IDArtikal, F_OdDatuma, F_DoDatuma, , 0, 0, F_IDFirma())
            RobneStavke![Kalkulativna VP cena] = QZaKL![Kalkulativna VP cena]
            RobneStavke![Kalkulativna MP cena] = QZaKL![Kalkulativna MP cena]
            
            RobneStavke![Stvarna VP cena] = VPCena
            'RobneStavke![Stvarna MP cena] = Round(VPCena * (1 + QZaKL!PDVStopa / 100), 2)
            RobneStavke![Stvarna MP cena] = Round(VPCena * (1# + PDVStopaZaTarifu(QZaKL![Tarifa - roba - Izlaz]) / 100#), 2)
            
            RobneStavke![TAKSA] = 0
            RobneStavke![Obracunat porez na ulazu - roba] = False
            RobneStavke![Tarifa - roba - ulaz] = QZaKL![Tarifa - roba - ulaz]
            RobneStavke![Obracunat porez na usluge] = False
            RobneStavke![Tarifa - usluge - izlaz] = "1"
            RobneStavke![Obracunat  porez na robu] = True
            RobneStavke![Tarifa - roba - Izlaz] = QZaKL![Tarifa - roba - Izlaz]
            'RobneStavke![KasaProc] = QZaCene![KasaProc]
            'RobneStavke![Rabatproc] = QZaCene![Rabatproc]
            'RobneStavke![Robne stavke.Odlozeno] = QZaCene![Odlozeno]
            RobneStavke![Neoporezivi deo] = 0
            RobneStavke![Akciza] = 0
            RobneStavke![FiksniPorez] = 0
            RobneStavke![DevNabCena] = 0
            
            RobneStavke.Update
            
        End If
exit_Func:
On Error Resume Next
        RobneStavke.Close
        Set RobneStavke = Nothing
        QZaKL.Close
        Set QZaKL = Nothing
        Set BigBit = Nothing
 VP_UpisiURacunProdaju = retVal
Exit Function
err_Func:
    retVal = False
    MsgBox "Err: " & err.Number & vbCrLf & err.Description, vbCritical, "BigBit (VP_UpisiURacunProdaju)"
    Resume exit_Func
End Function
