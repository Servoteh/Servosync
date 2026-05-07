Attribute VB_Name = "Dnevnik"
Option Compare Database
Option Explicit
Public Sub UpisiUDnevnik(ByVal Korisnik As String, ByVal Opis As String, ByVal ImeForme As String, ByVal Akcija As String)
On Error Resume Next

  
 If Not BBCFG.SysVodiDnevnik() Then
  Exit Sub
 End If

Dim rs As DAO.Recordset
    Set rs = CurrentDb.OpenRecordset("Dnevnik")
        rs.AddNew
        rs!Korisnik = Left$(Korisnik, 20)
        rs!Opis = Opis
        rs!Forma = Left$(ImeForme, 50)
        rs!Akcija = Left$(Akcija, 10)
        rs.Update
    rs.Close
    Set rs = Nothing
 err.Clear
End Sub
