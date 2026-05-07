Attribute VB_Name = "BBFIT"
Option Compare Database
Option Explicit
Public Function F_Baze_SQL(Optional ZaTipBaze) As String
'Modifikovano: 19-10-2021
On Error GoTo Err_Point

 Dim stRetVal As String

 If IsMissing(ZaTipBaze) Or IsNull(ZaTipBaze) Then
    stRetVal = "SELECT BazeIFirme.* FROM BazeIFirme WHERE (((BazeIFirme.FirmaZaBaze)= """ & F_FirmaZaBaze() & """));"
 Else
    stRetVal = "SELECT BazeIFirme.* FROM BazeIFirme WHERE (BazeIFirme.FirmaZaBaze= """ & F_FirmaZaBaze() & """) And (BazeIFirme.TipBaze=""" & CStr(ZaTipBaze) & """);"
 End If

Exit_Point:
 On Error Resume Next
       F_Baze_SQL = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "F_Baze_SQL(..)"
 stRetVal = ""
 Resume Exit_Point
End Function
Public Function ForsirajBBFitLinkove(NovaBaza As String) As Boolean
'Datum kreiranja: 17-08-2018

Dim retVal As Boolean
  retVal = True
  retVal = retVal And ForsirajNoviLinkZaTabelu("Baze_Tipovi", "Baze_Tipovi", NovaBaza)
  retVal = retVal And ForsirajNoviLinkZaTabelu("BazeIFirme", "BazeIFirme", NovaBaza)
  retVal = retVal And ForsirajNoviLinkZaTabelu("BazeITabele", "BazeITabele", NovaBaza)
  retVal = retVal And ForsirajNoviLinkZaTabelu("Baze_CnnString", "Baze_CnnString", NovaBaza)
  retVal = retVal And ForsirajNoviLinkZaTabelu("Baze_Firme", "Firme", NovaBaza)
  
  ForsirajBBFitLinkove = retVal
End Function
Public Sub CheckLinkPonistZaIDBaze(ZaIDBaze As Long)
 Dim stSQL As String
  
  stSQL = "UPDATE BazeITabele SET BazeITabele.CheckLink = Null, BazeITabele.CurrentSourceDataBase = Null "
  stSQL = stSQL & " WHERE (((BazeITabele.IDBaze)= " & ZaIDBaze & "));"
  On Error Resume Next
  DoCmd.SetWarnings False
  DoCmd.RunSQL stSQL, False
  DoCmd.SetWarnings True
  err.Clear
End Sub
Public Function F_FirmaZaBaze() As String
'Modifikovano: 05-02-2021
    'F_FirmaZaBaze = Nz(ReadParametar("CFG_Sys", "SysFITFirma"), "DEFAULT")
    F_FirmaZaBaze = Nz(BBReadProperty("FITFirma", False), "DEFAULT")
End Function
Public Function F_SysFitLevel() As Integer
    F_SysFitLevel = Nz(ReadParametar("CFG_Sys", "SysFitLevel"), 0)
End Function
Public Function F_SysBB_FIT() As String
    F_SysBB_FIT = Nz(ReadParametar("CFG_Sys", "SysBB_FIT"), "BB_FIT.MDB")
End Function
Public Function F_SysTipKorisnika() As String
    F_SysTipKorisnika = Nz(ReadParametar("CFG_Sys", "SysTipKorisnika"), 0)
End Function
Public Function VezaSaBazom() As String
'Odavde se uzima za SQL Cnn string, a za Access MDB fajl za link
Dim stRetVal As String
  'VezaSaBazom = BazaZaTip("BigBit_T")
  '*****
  'stRetVal = CurrentDb.TableDefs("T_Predmeti").Connect
  stRetVal = CurrentDb.TableDefs("R_Artikli").Connect
  If Not stRetVal Like "ODBC*" Then
     stRetVal = Replace(stRetVal, ";DATABASE=", "")
  Else
     stRetVal = BazaZaTip("BigTehn_T")
  End If
  VezaSaBazom = stRetVal
End Function
Public Function SourceTableNameZaTabelu(imeTabele As String) As String
Dim IDBaze
Dim stRetVal As String
 'stRetVal = Nz(DLookup("[SourceTableName]", "BazeITabele", "[Name]= '" & imeTabele & "'"), "")
 '28-11-2021
 stRetVal = Nz(DLookup("[SourceTableName]", "BazeITabele", "[Name]= '" & imeTabele & "'"), imeTabele)
 SourceTableNameZaTabelu = stRetVal
End Function
Public Function BazaZaTabelu(imeTabele As String) As String
Dim IDBaze
Dim stRetVal As String
    IDBaze = DLookup("[IDBaze]", "BazeITabele", "[Name]= '" & imeTabele & "'")
    If Not IsNull(IDBaze) Then
     stRetVal = Nz(DLookup("[Baza]", "BazeIFirme", "([FirmaZaBaze] = '" & F_FirmaZaBaze() & "') AND ([IDBaze] = " & IDBaze & ")"), "")
    Else
    stRetVal = ""
    End If
    BazaZaTabelu = stRetVal
End Function
Public Function BazaZaTip(TipBaze As String) As Variant
'Modifikovano: 09-04-2021

   Dim stRetVal As String
   Dim stSysFITFirma As String
   Dim stWhereUslov As String
   
   '09-04-2021 stSysFITFirma = Nz(ReadParametar("CFG_Sys", "SysFITFirma"), "DEFAULT")
   'citamo property iz APL da bi smo znali koja je firma!
   stSysFITFirma = F_FirmaZaBaze() ' BBReadProperty("FITFirma", True)
   
   stWhereUslov = "([FirmaZaBaze] = '" & stSysFITFirma & "')"
   stWhereUslov = stWhereUslov & " AND [TipBaze] = '" & TipBaze & "'"
   '09-04-2021 stRetVal = Nz(DLookup("Baza", "BazeIFirme", stWhereUslov), "-")
   stRetVal = Nz(ADO_Lookup(CNN_FIT(), "Baza", "BazeIFirme", stWhereUslov), "-")
   
   BazaZaTip = stRetVal
End Function
Public Function IDBazeZaTabelu(imeTabele As String) As Variant
  IDBazeZaTabelu = DLookup("IDBaze", "BazeITabele", "Name = '" & imeTabele & "'")
End Function
Public Function IDBazeZaTipBaze(TipBaze As String) As Variant
  IDBazeZaTipBaze = DLookup("IDBaze", "Baze_Tipovi", "TipBaze = '" & TipBaze & "'")
End Function
Public Function TipBazeZaIDBaze(IDBaze As Long) As String
  TipBazeZaIDBaze = DLookup("TipBaze", "Baze_Tipovi", "IDBaze = " & IDBaze)
End Function
Public Function TipBazeZaTabelu(imeTabele As String) As Variant

  TipBazeZaTabelu = TipBazeZaIDBaze(IDBazeZaTabelu(imeTabele))
End Function

Public Function TrebaLinkZaTabelu(ImeFirme As String, imeTabele As String) As Boolean
 Dim intIDBazeZaTabelu
 Dim retVal As Boolean
 
   intIDBazeZaTabelu = IDBazeZaTabelu(imeTabele)
   If IsNull(intIDBazeZaTabelu) Then
      retVal = True
   Else
      If intIDBazeZaTabelu = 200 Then 'BB_FIT Uvek treba!
       retVal = True 'BB_FIT Uvek treba!
      Else
       retVal = Nz(DLookup("ForsirajNoviLink", "BazeIFirme", "FirmaZaBaze = '" & ImeFirme & "'" & " AND IDBaze = " & intIDBazeZaTabelu), False)
      End If
   End If
   TrebaLinkZaTabelu = retVal
End Function
Public Function RootDirZaFirmu(stFirma As String) As String
   Dim stRetVal As String
   
   stRetVal = ""
   On Error Resume Next
   stRetVal = Nz(DLookup("[RootDir]", "Baze_Firme", "[FirmaZaBaze] = '" & stFirma & "'"), "")
   RootDirZaFirmu = stRetVal
End Function
