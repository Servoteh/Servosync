Attribute VB_Name = "Semafor"
Option Compare Database
Option Explicit
Public Function SEMAFOR_ZauzetUredjaj(imeuredjaja As String) As Boolean
On Error Resume Next
Dim retVal
    retVal = DLookup("[Zauzet]", "Semafor", "[Uredjaj] = '" & imeuredjaja & "'")
    SEMAFOR_ZauzetUredjaj = Nz(retVal, False)
End Function
Public Function SEMAFOR_PostaviStatus(imeuredjaja As String, Status As Boolean)
    On Error Resume Next
    Dim Semafor As DAO.Recordset
    Dim stSQL As String
    stSQL = "SELECT Semafor.*, Semafor.Uredjaj FROM semafor WHERE (((Semafor.Uredjaj)= '" & imeuredjaja & "'))"
    Set Semafor = CurrentDb.OpenRecordset(stSQL)

    Semafor.MoveFirst
    
     Semafor.Edit
     Semafor!Zauzet = Status
     Semafor!StatusPromenjen = Now()
     Semafor.Update
     
    Semafor.Close
    Set Semafor = Nothing

End Function
Public Function SEMAFOR_OznaciDaJeZauzet(imeuredjaja As String)
    
   SEMAFOR_PostaviStatus imeuredjaja, True
   
End Function

Public Function SEMAFOR_OznaciDaJeSlobodan(imeuredjaja As String)

    SEMAFOR_PostaviStatus imeuredjaja, False
    
End Function


