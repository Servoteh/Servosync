Attribute VB_Name = "LIB_OS"
Option Compare Database   'Use database order for string comparisons
Option Explicit

Function BrojMeseci(dat1, dat2 As Variant) As Integer
Dim brm As Integer
 On Error Resume Next
   If IsDate(dat1) And IsDate(dat2) Then

      brm = DateDiff("m", dat1, dat2)
      If brm < 0 Then brm = 0
   
   Else: brm = 0

   End If
  BrojMeseci = brm
End Function

Function KoefOtpisa(StopaOtpisa As Double, dat1, dat2 As Variant) As Double

    KoefOtpisa = (BrojMeseci(dat1, dat2) / 12#) * (StopaOtpisa / 100#)

End Function

Function VrednostAmortizacije(OdDat, DoDat As Variant, StopaOtpisa As Double, vrednostOS As Currency) As Double
Dim VredAm As Currency
      VredAm = vrednostOS * KoefOtpisa(StopaOtpisa, OdDat, DoDat)
      VredAm = Round(VredAm, 2)

      VrednostAmortizacije = VredAm
End Function

Function VrednostRevalorizacije(OdDat, DoDat As Variant, vrednostOS As Currency, DatumNabavke As Variant) As Double

On Error Resume Next       'GoTo GreskaREV

    Dim BigBit As DAO.Database
    Dim TabRevKoef As DAO.Recordset
    Dim ZaGodinu, OdGodine, DoGodine As Integer
    Dim ZaMesec, OdMeseca, DoMeseca, PoslednjiMesec As Integer
    Dim RevKoef As Double

    Set BigBit = CurrentDb
    Set TabRevKoef = BigBit.OpenRecordset("OS_Stope revalorizacije", DB_OPEN_DYNASET, dbSeeChanges)

    OdGodine = DatePart("yyyy", OdDat)
    DoGodine = DatePart("yyyy", DoDat)
    
   ' If oddat > DatumNabavke Then                           'Ovo je vazilo
   '    OdMeseca = DatePart("m", oddat) + 1                 'zakljucno sa 2000 godinom
   ' Else                                                   'kada se revalorizacija racunala
   '     OdMeseca = DatePart("m", oddat)                    'i za mesec nabavke OS
   ' End If                                                 'promenjeno je u 2002 a odnosi se i na 2001 godiny
    
    OdMeseca = DatePart("m", OdDat) + 1                     'Primenjuje se od 01-01-2002 i za 2001
    
    PoslednjiMesec = DatePart("m", DoDat)
    

    If OdMeseca > 12 Then
     OdMeseca = 1
     OdGodine = OdGodine + 1
    End If

    RevKoef = 1#

    For ZaGodinu = OdGodine To DoGodine
    
        TabRevKoef.MoveFirst                                      ' Pozicioniraj se na prvi rekord
        TabRevKoef.FindFirst "[Godina]= " & ZaGodinu
        If TabRevKoef.NoMatch Then
           
        Else
           If ZaGodinu < DoGodine Then DoMeseca = 12 Else DoMeseca = PoslednjiMesec

           For ZaMesec = OdMeseca To DoMeseca

                Select Case ZaMesec
                Case 1
                   RevKoef = RevKoef * (1# + TabRevKoef![01])
                Case 2
                   RevKoef = RevKoef * (1# + TabRevKoef![02])
                Case 3
                   RevKoef = RevKoef * (1# + TabRevKoef![03])
                Case 4
                   RevKoef = RevKoef * (1# + TabRevKoef![04])
                Case 5
                   RevKoef = RevKoef * (1# + TabRevKoef![05])
                Case 6
                   RevKoef = RevKoef * (1# + TabRevKoef![06])
                Case 7
                   RevKoef = RevKoef * (1# + TabRevKoef![07])
                Case 8
                   RevKoef = RevKoef * (1# + TabRevKoef![08])
                Case 9
                   RevKoef = RevKoef * (1# + TabRevKoef![09])
                Case 10
                   RevKoef = RevKoef * (1# + TabRevKoef![10])
                Case 11
                   RevKoef = RevKoef * (1# + TabRevKoef![11])
                Case 12
                   RevKoef = RevKoef * (1# + TabRevKoef![12])
                End Select
           
           Next ZaMesec

        End If
        OdMeseca = 1
 Next ZaGodinu
 
Set TabRevKoef = Nothing
Set BigBit = Nothing
VrednostRevalorizacije = (RevKoef - 1#) * vrednostOS

Exit Function

GreskaREV:
 MsgBox Error$
 Resume Next
   
  
End Function

Public Function RevKoef(OdDat, DoDat As Variant) As Double
  On Error Resume Next
    Dim BigBit As DAO.Database
    Dim TabRevKoef As DAO.Recordset
    Dim ZaGodinu, OdGodine, DoGodine As Integer
    Dim ZaMesec, OdMeseca, DoMeseca, PoslednjiMesec As Integer
    Dim v_RevKoef As Double

    Set BigBit = CurrentDb
    Set TabRevKoef = BigBit.OpenRecordset("OS_Stope revalorizacije", DB_OPEN_DYNASET, dbSeeChanges)

    OdGodine = DatePart("yyyy", OdDat)
    DoGodine = DatePart("yyyy", DoDat)
    
    OdMeseca = DatePart("m", OdDat)
    PoslednjiMesec = DatePart("m", DoDat)
    


    v_RevKoef = 1#

    For ZaGodinu = OdGodine To DoGodine
    
        TabRevKoef.MoveFirst                                      ' Pozicioniraj se na prvi rekord
        TabRevKoef.FindFirst "[Godina]= " & ZaGodinu
        If TabRevKoef.NoMatch Then
           
        Else
           If ZaGodinu < DoGodine Then DoMeseca = 12 Else DoMeseca = PoslednjiMesec

           For ZaMesec = OdMeseca To DoMeseca

                Select Case ZaMesec
                Case 1
                   v_RevKoef = v_RevKoef * (1# + TabRevKoef![01])
                Case 2
                   v_RevKoef = v_RevKoef * (1# + TabRevKoef![02])
                Case 3
                   v_RevKoef = v_RevKoef * (1# + TabRevKoef![03])
                Case 4
                   v_RevKoef = v_RevKoef * (1# + TabRevKoef![04])
                Case 5
                   v_RevKoef = v_RevKoef * (1# + TabRevKoef![05])
                Case 6
                   v_RevKoef = v_RevKoef * (1# + TabRevKoef![06])
                Case 7
                   v_RevKoef = v_RevKoef * (1# + TabRevKoef![07])
                Case 8
                   v_RevKoef = v_RevKoef * (1# + TabRevKoef![08])
                Case 9
                   v_RevKoef = v_RevKoef * (1# + TabRevKoef![09])
                Case 10
                   v_RevKoef = v_RevKoef * (1# + TabRevKoef![10])
                Case 11
                   v_RevKoef = v_RevKoef * (1# + TabRevKoef![11])
                Case 12
                   v_RevKoef = v_RevKoef * (1# + TabRevKoef![12])
                End Select
           
           Next ZaMesec

        End If
        OdMeseca = 1
 Next ZaGodinu
 
Set TabRevKoef = Nothing
Set BigBit = Nothing
RevKoef = (v_RevKoef - 1#)

End Function

Public Function IznosAmortizacijeZaMesec(ZaMesec As Integer, StopaOtpisa As Double, nadatum As Variant, UkVred, ukotpis As Double) As Double
    Dim mesamort As Double
    Dim novavred As Double
    Dim StartMesec, RastMesec As Integer
    
    StartMesec = DatePart("m", nadatum) + 1
    If StartMesec > 12 Then StartMesec = 1
    
    RastMesec = ZaMesec - StartMesec + 1
    If RastMesec > 0 Then
     novavred = UkVred - ukotpis
    
     If novavred <= 0 Then
         mesamort = 0#
     Else
         mesamort = (StopaOtpisa / 1200#) * UkVred
         If novavred < (mesamort * RastMesec) Then
             mesamort = novavred - (mesamort * (RastMesec - 1))
             If mesamort < 0 Then mesamort = 0
         End If
        
     End If
    Else
     mesamort = 0
    End If
    IznosAmortizacijeZaMesec = mesamort
End Function

Public Function DatumPocetkaObracunaRevAm(DATUM As Variant) As Variant
    Dim nm, ng As Integer
    Dim ndatum As Variant
    nm = DatePart("m", DATUM)
    ng = DatePart("yyyy", DATUM)
    nm = nm + 1
    If nm > 12 Then
        nm = 1
        ng = ng + 1
    End If
   ndatum = "01-" & nm & "-" & ng
   DatumPocetkaObracunaRevAm = ndatum
End Function

Function PoreskaVredAm(AmGrupa, OdDat, DoDat As Variant, StopaAm As Double, vrednostOS, ProdVredOS As Currency, PetProsZarada As Currency, VredGrupe As Currency) As Double
Dim VredAm As Currency
Dim OdDatuma, DoDatuma As Date
    If OdDat <> DoDat Then
        OdDatuma = IIf(OdDat <> CVDate("31-12-" & Year(DoDat) - 1), CVDate("31-12-" & Year(DoDat) - 1), OdDat)
        DoDatuma = IIf(DoDat <> CVDate("31-12-" & Year(DoDat)), CVDate("31-12-" & Year(DoDat)), DoDat)
        VredAm = (vrednostOS - ProdVredOS) * KoefOtpisa(StopaAm, OdDatuma, DoDatuma)
        VredAm = Round(VredAm, 2)
        VredAm = IIf(VredAm < 0, ProdVredOS + VredAm, VredAm)
        'VredGrupe = Nz(DLookup("[NeotpisanaVrednost]", "OS_PAVredPoGrupama", " [AmGrupa] = '" & AmGrupa & "'"),0)
        VredGrupe = VredGrupe * (1 - StopaAm / 100)
        VredAm = IIf(VredGrupe < PetProsZarada, vrednostOS, VredAm)
    Else
        VredAm = 0
    End If
      PoreskaVredAm = VredAm
End Function

