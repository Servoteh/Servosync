Attribute VB_Name = "GlobalType"
Option Compare Database
Option Explicit

'Modifikovano: 13-01-2020
'Modifikovano: 21-09-2023 => NazivNezvanicno

Public Type TypeFirma
    IDFirma As Long
    Naziv As String
    NazivNezvanicno As String
    'PunNaziv As String
    PostBroj As String
    MESTO As String
    'Ulica As String
    'BrojUlice As String
    ADRESA As String
    Drzava As String
    TekuciRacun As String
    PIB As String
    Telefon As String
    Fax As String
    MaticniBroj As String
    JBKJS As String
    SifraDelatnosti As String
    Delatnost As String
    Email As String
    Web As String
    GLN As String
    Opstina As String
    '***************************************
    'Modifikovano: 13-01-2020
    BrDecUlKl As Integer
    BrDecIzKl As Integer
    KursDeli As Boolean
    'ProveraZalihaMag = rst("ProveraZalihaMag")
    AutoPodelaPrihoda  As Boolean
    FakturnaJeVPZaUlKl As Boolean
    KepuPoNabavnojCeni As Boolean
    TrgovackaPoKursu As Boolean
    KepuPoKursu As Boolean
    KEPUPoKNGCeni As Boolean
    GKPoKursu As Boolean
    KontoKupac As String
    KontoDobavljac As String
    KnjiziRazlikeNaTK As Boolean
    KnjiziRazlikeNaKEPU As Boolean
    KnjiziRazlikeNaMPKEPU As Boolean
    GKPoKursuObrnuto As Boolean
    ProveraPorukaInterval As Long
    DekodirajBarKod As Boolean
    'Galeb = rst("Galeb")
    Raster As Boolean
    ServerZaGaleb As Boolean
    KlijentZaGaleb As Boolean
    FP_ImeStampaca As String
    'MestoIzdavanjaRacuna = rst("MestoIzdavanjaRacuna")
    DefaultNapomena As String '= Nz(RFReadParameter("Napomena"), "Napomena o poreskom oslobodjenju: NEMA")
    
End Type

 Public Const bbcOKBackGroundColor = vbWhite
 Public Const bbcErrorBackGroundColor = vbRed
 Public Const bbcOKTextColor = vbBlack
 Public Const bbcErrorTextColor = vbRed
 Public Const bbcOKBorderColor = vbBlack
 Public Const bbcErrorBorderColor = vbRed
