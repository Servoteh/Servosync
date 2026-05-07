Attribute VB_Name = "IF_Modul"
Option Compare Database
Option Explicit

Public IFP As New IF_Class

Public Function F_IF_IDDok() As Long
   F_IF_IDDok = Nz(IFP.IDDok(), -1)
End Function
Public Function F_IF_IDMagacinDOK() As Long
   F_IF_IDMagacinDOK = IFP.IDMagacinDOK()
End Function
Public Function F_IF_TextZaRacun() As String
   F_IF_TextZaRacun = IFP.TextZaRacun()
End Function

Public Function F_IF_CheckMemorandumVisible() As Boolean
   F_IF_CheckMemorandumVisible = IFP.CheckMemorandumVisible()
End Function

Public Function F_IF_CheckTRNaFakturiVisible() As Boolean
   F_IF_CheckTRNaFakturiVisible = IFP.CheckTRNaFakturiVisible
End Function

Public Function F_IF_FakturaSaOpisomStavke() As Boolean
   F_IF_FakturaSaOpisomStavke = IFP.FakturaSaOpisomStavke
End Function
Public Function F_IF_PreuzeoZaPrevoz(Optional IDVozac) As String
Dim stRetVal As String
    stRetVal = IFP.PreuzeoZaPrevoz(IDVozac)
    F_IF_PreuzeoZaPrevoz = stRetVal
End Function
Public Function F_IF_CheckPIP() As Boolean
  F_IF_CheckPIP = IFP.CheckPiP
End Function
Public Function F_IF_RobuIzdao(Optional IDMagacin) As String
Dim stRetVal As String
    stRetVal = IFP.RobuIzdao(IDMagacin)
    F_IF_RobuIzdao = stRetVal
End Function
Public Function F_IF_RobuPrimio() As String
Dim stRetVal As String
    stRetVal = IFP.RobuPrimio()
    F_IF_RobuPrimio = stRetVal
End Function
Public Function F_IF_Prodavac(Optional IDProdavac) As String
Dim stRetVal As String
    stRetVal = IFP.Prodavac(IDProdavac)
    F_IF_Prodavac = stRetVal
End Function
Public Function F_IF_IDKomitent(Optional IDKomitent) As Long
Dim lnRetVal As Long
    lnRetVal = IFP.IDKomitent()
    F_IF_IDKomitent = lnRetVal
End Function
Public Function F_IF_Cenovnik() As String
Dim stRetVal As String
    stRetVal = IFP.Cenovnik()
    F_IF_Cenovnik = stRetVal
End Function
Public Function F_IF_Kategorija_PO() As String
Dim stRetVal As String
    stRetVal = IFP.Kategorija_PO
    F_IF_Kategorija_PO = stRetVal
End Function
Public Function F_IF_IzvozVrstaProdaje() As Variant
   F_IF_IzvozVrstaProdaje = IFP.IzvozVrstaProdaje()
End Function
Public Function F_IF_ImaAvans(Optional IDDok) As Boolean
Dim IznosAvansa As Variant
Dim pIDDok As Long
 
If Not IsMissing(IDDok) Then
   pIDDok = CLng(IDDok)
Else
   pIDDok = Nz(IFP.IDDok, -1)
End If
   IznosAvansa = Nz(ADO_Lookup(CNN_CurrentDataBase, "UkIznos", "SELECT SUM(KoristiIznosSaPDV) as UkIznos FROM T_AVR_Roba WHERE IDDok = " & stR(pIDDok)), 0)
   F_IF_ImaAvans = (IznosAvansa >= 0.01)
End Function
Public Function F_TextRokIsporuke(ByVal BrojDana As Variant) As String
'Kreirano: 15-01-2022 (prepisano iz stare Magrem APL)
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim IntBrojDana As Integer
Dim ostdana As Integer
Dim recdana As String

On Error Resume Next
  IntBrojDana = 0
  
  IntBrojDana = CInt(Nz(BrojDana, 0))
  ostdana = (IntBrojDana Mod 10)
  If ostdana = 1 And IntBrojDana <> 11 Then recdana = " dan" Else recdana = " dana"
  
Exit_Point:
 On Error Resume Next
       F_TextRokIsporuke = IIf(IntBrojDana <= 0, "Na lageru", "Rok isporuke " & IntBrojDana & recdana)
Exit Function

Err_Point:
 BBErrorMSG err, "F_TextRokIsporuke"
 retValOk = False
 Resume Exit_Point
End Function
Public Function F_TextRokIsporuke_Ino(ByVal BrojDana As Variant) As String
'Kreirano: 15-01-2022 (prepisano iz stare Magrem APL)
Dim IntBrojDana As Integer
Dim ostdana As Integer
Dim recdana As String

 On Error Resume Next
  IntBrojDana = 0
  IntBrojDana = CInt(Nz(BrojDana, 0))
  ostdana = (IntBrojDana Mod 10)
  If ostdana = 1 And IntBrojDana <> 11 Then recdana = " day" Else recdana = " days"
  F_TextRokIsporuke_Ino = IIf(IntBrojDana <= 0, "On stock", "Deliveri time " & IntBrojDana & recdana)
End Function
Public Function F_IF_SortNaReportu() As String
'Kreirano: 18-10-2022
On Error GoTo Err_Point

Dim retValOk As Boolean

Exit_Point:
 On Error Resume Next
       F_IF_SortNaReportu = IFP.SortNaReportu
Exit Function

Err_Point:
 BBErrorMSG err, "F_IF_SortNaReportu"
 retValOk = False
 Resume Exit_Point

End Function
Public Function F_IF_OSN_Kolicina() As Boolean
'Kreirano: 07-12-2022
On Error GoTo Err_Point

Dim retValOk As Boolean

Exit_Point:
 On Error Resume Next
       F_IF_OSN_Kolicina = IFP.OSN_Kolicina
Exit Function

Err_Point:
 BBErrorMSG err, "F_IF_OSN_Kolicina"
 retValOk = False
 Resume Exit_Point

End Function
