VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "BBImport_Class"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Const DefaultNameLinkedTable = "~tmp_T_Linked~"
Private pImeLinkovaneTabele As String
Private pImeFajlaZaImport As String

Public ImportedRST As DAO.Recordset

Public Function LinkTableToXLS(Optional FromFile) As Boolean
On Error GoTo err_Func
Dim retValOk As Boolean
retValOk = True
   If Not IsMissing(FromFile) Then
    pImeFajlaZaImport = FromFile
   End If
   
   If Nz(pImeFajlaZaImport, "") = "" Then
     MsgBox "Morate izabrati fajl za import", vbExclamation, "QMegaTeh"
     retValOk = False
     GoTo exit_Func:
   End If
   
   If Not FileExists(pImeFajlaZaImport) Then
     MsgBox "Ne postoj fajl: " & pImeFajlaZaImport, vbExclamation, "QMegaTeh"
     retValOk = False
     GoTo exit_Func:
   End If
   
   If PostojiTabelaUBazi(pImeLinkovaneTabele, CurrentDb) Then
    DoCmd.DeleteObject acTable, pImeLinkovaneTabele
   End If
   
   DoCmd.TransferSpreadsheet acLink, , pImeLinkovaneTabele, pImeFajlaZaImport, True

   'ReadRSTFromTable
   
exit_Func:
LinkTableToXLS = retValOk
Exit Function

err_Func:
 BBErrorMSG err, "LinkTableToXLS"
 retValOk = False
 Resume exit_Func
End Function
Public Function HasField(stFieldName As String) As Boolean

 Dim retValOk As Boolean
 
 On Error Resume Next
 retValOk = (CurrentDb.TableDefs(pImeLinkovaneTabele).Fields(stFieldName).Name = stFieldName)
 
 If err.Number <> 0 Then
        retValOk = False
 Else
        retValOk = True
 End If
 
 HasField = retValOk
End Function
Public Function ShowLinkedTable()
 DoCmd.OpenTable pImeLinkovaneTabele, acViewNormal, acReadOnly
End Function
Public Function PrikaziStavkeZaImport()
 
 DoCmd.OpenQuery "Q_ProfakturaStavkeZaImport_XLS", acViewNormal, acReadOnly
 
End Function
Private Function ReadRSTFromTable()
 Set ImportedRST = CurrentDb.OpenRecordset(pImeLinkovaneTabele)
End Function
Private Function ReadRSTZaProdaju()
Dim stSQL As String

stSQL = "SELECT tmp_ImportLinked_XLS_Slavisa.Rbr, R_Artikli.[Sifra artikla], CCur([kolicina]) AS Imp_Kolicina, CCur([VPCena]) AS Imp_VPCena"
stSQL = stSQL & " FROM R_Artikli INNER JOIN tmp_ImportLinked_XLS_Slavisa ON R_Artikli.[Kataloski broj] = tmp_ImportLinked_XLS_Slavisa.KatBroj"
stSQL = stSQL & " ORDER BY tmp_ImportLinked_XLS_Slavisa.Rbr;"

End Function
Public Property Get ImeFajlaZaImport() As Variant
 ImeFajlaZaImport = pImeFajlaZaImport
End Property
Public Property Let ImeFajlaZaImport(ByVal vNewValue As Variant)
 pImeFajlaZaImport = Nz(vNewValue, "")
End Property
Private Sub Class_Initialize()
 'pImeFajlaZaImport = "C:\SHARES\AcBaze\BigBit\IMPORT\Profaktura.xls"
 'pImeFajlaZaImport = OpenFile("*.xls")
 pImeFajlaZaImport = "C:\SHARES\AcBaze\BigBit\IMPORT\Profaktura.xls"
 'pImeLinkovaneTabele = "tmp_T_ProfakturaStavkeZaImport_XLS" '& CurrentUser()
 pImeLinkovaneTabele = DefaultNameLinkedTable
End Sub
Private Sub Class_Terminate()
' Debug.Print "Class_Terminate BBImport_Class"
On Error Resume Next
If PostojiTabelaUBazi(pImeLinkovaneTabele, CurrentDb) Then
   DoCmd.DeleteObject acTable, pImeLinkovaneTabele
End If
End Sub
Public Function ImportRST()
 Dim stSQL As String
 stSQL = "SELECT [" & pImeLinkovaneTabele & "].*"
 stSQL = stSQL & " FROM [" & pImeLinkovaneTabele & "]"
 stSQL = stSQL & " ORDER BY [" & pImeLinkovaneTabele & "].Rbr;"

 Set ImportedRST = CurrentDb.OpenRecordset(stSQL, , dbReadOnly)
 
End Function
Public Function UpisiUProfakturuStavke(ByVal IDDokProf As Long, ByVal IDMagacin As Long, ByRef Neuspesno As Long) As Boolean
 On Error GoTo err_Func
  Dim IDArtikal
  Dim retValOk As Boolean
  Dim tmpOk As Boolean
  
  ImportRST
  'ImportedRST.Sort = "KatBroj DESC"
  ImportedRST.MoveFirst
  
  retValOk = True
  
  While Not ImportedRST.EOF
   IDArtikal = DFirst("[Sifra artikla]", "R_Artikli", "[Kataloski broj] = '" & ImportedRST!KatBroj & "'")
   If Not IsNull(IDArtikal) Then
    tmpOk = ProknjiziRobnuStavkuPROF(IDDokProf, CLng(IDArtikal), ImportedRST!Kolicina, ImportedRST!VPCena, IDMagacin)
    If Not tmpOk Then
     Neuspesno = Neuspesno + 1
    End If
    retValOk = retValOk And tmpOk
    'Debug.Print ImportedRST!Rbr, ImportedRST!KatBroj
   Else
    retValOk = False
    Neuspesno = Neuspesno + 1
   End If
   ImportedRST.MoveNext
  Wend
 
exit_Func:
  UpisiUProfakturuStavke = retValOk
 Exit Function
err_Func:
 BBErrorMSG err, "BBImport_Class.UpisiUProfakturuStavke"
 retValOk = False
 Resume exit_Func:
End Function
Public Function UpisiUPopisStavke(ByVal IDPopis As Long, ByRef Neuspesno As Long) As Boolean
 On Error GoTo err_Func
  Dim IDArtikal
  Dim retValOk As Boolean
  Dim tmpOk As Boolean
  
  ImportRST
  'ImportedRST.Sort = "KatBroj DESC"
  ImportedRST.MoveFirst
  
  retValOk = True
  
  While Not ImportedRST.EOF
   IDArtikal = DFirst("[Sifra artikla]", "R_Artikli", "[Kataloski broj] = '" & ImportedRST!KatBroj & "'")
   If Not IsNull(IDArtikal) Then
    tmpOk = DodajStavkuUPopis(IDPopis, CLng(IDArtikal), 0, ImportedRST!Kolicina, ImportedRST!Cena)
    If Not tmpOk Then
     Neuspesno = Neuspesno + 1
    End If
    retValOk = retValOk And tmpOk
    'Debug.Print ImportedRST!Rbr, ImportedRST!KatBroj
   Else
    retValOk = False
    Neuspesno = Neuspesno + 1
   End If
   ImportedRST.MoveNext
  Wend
 
exit_Func:
  UpisiUPopisStavke = retValOk
 Exit Function
err_Func:
 BBErrorMSG err, "BBImport_Class.UpisiUPopisStavke"
 retValOk = False
 Resume exit_Func:
End Function
