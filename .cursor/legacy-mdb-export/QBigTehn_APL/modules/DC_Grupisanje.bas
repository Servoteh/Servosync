Attribute VB_Name = "DC_Grupisanje"
Option Compare Database
Option Explicit

Public Sub DC_RazdeliICStavke(ZaIDDok As Long, brojStavkiUGrupi As Long)
On Error GoTo GreskaRazdeliICStavke

    Dim BigBit As DAO.Database
    Dim QTabStav As DAO.QueryDef
    Dim TabStav As DAO.Recordset
    Dim Rbr As Long
    Dim NoviIDDok As Long
    Dim UkBrojStavki As Long
    
    NoviIDDok = CLng(Nz(DMax("[IDDok]", "IC_stavke"), 0)) + 1
  
    
    Set BigBit = CurrentDb
    Set TabStav = BigBit.OpenRecordset("Robne stavke", DB_OPEN_DYNASET, dbSeeChanges)
    Set QTabStav = BigBit.QueryDefs("bar_ICStavkeZaIzabraniDok")
    QTabStav.Parameters("[ZaIDDok]") = ZaIDDok
    
    Set TabStav = QTabStav.OpenRecordset()
    
    UkBrojStavki = TabStav.RecordCount
    If UkBrojStavki <= brojStavkiUGrupi Then
        GoTo EXIT_DC_RazdeliICStavke
    End If
    TabStav.MoveFirst
    
    TabStav.AbsolutePosition = brojStavkiUGrupi
    Rbr = 0
    
Do Until TabStav.EOF
    If Rbr = brojStavkiUGrupi Then
        Rbr = 0
        NoviIDDok = NoviIDDok + 1
    End If

   TabStav.Edit
   Rbr = Rbr + 1
   TabStav![IDDok] = NoviIDDok

   TabStav.Update 'Sacuvaj izmene
   TabStav.MoveNext
   
Loop
EXIT_DC_RazdeliICStavke:
    TabStav.Close
    Set TabStav = Nothing
    Set QTabStav = Nothing
    BigBit.Close
    Set BigBit = Nothing
    
    
    
Exit Sub

GreskaRazdeliICStavke:
 MsgBox Error$
 Resume Next

End Sub
