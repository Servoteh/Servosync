Attribute VB_Name = "Nalepnice"
Option Compare Database
Option Explicit
Public Sub PopuniTablicuNNIDZaNalepnice(ZaIDSet As Long)
On Error GoTo ErrPopuni
    
    Dim BigBit As DAO.Database
    Dim QZaN As DAO.Recordset
    Dim StavkeN As DAO.Recordset
    Dim i As Integer
    
    If Not PostojiTabelaUBazi("NalepniceNNID", CurrentDb) Then
     Call BBMakeTable("NalepniceNNID")
    End If
    
    Set BigBit = CurrentDb
    Set QZaN = BigBit.OpenRecordset("SELECT * FROM Nalepnice WHERE IDSet=" & ZaIDSet, dbOpenDynaset, dbSeeChanges)
    Set StavkeN = BigBit.OpenRecordset("NalepniceNNID", dbOpenDynaset, dbSeeChanges)

QZaN.MoveFirst                                      ' Pozicioniraj se na prvi rekord

Do Until QZaN.EOF                                   ' Pocetak petlje
    
     For i = 1 To QZaN![Kolicina]
    
        StavkeN.AddNew
        StavkeN![ID] = QZaN![ID]
        StavkeN.Update
        
     Next i
     
   
   QZaN.MoveNext                                   ' Pozicioniraj se na sledeci rekord
Loop                                                        ' Kraj petlje
exit_Puni:
 On Error Resume Next
    StavkeN.Close
    Set StavkeN = Nothing
    QZaN.Close
    Set QZaN = Nothing
    BigBit.Close
    Set BigBit = Nothing
    
Exit Sub

ErrPopuni:

 MsgBox Error$
 Resume exit_Puni:
End Sub
Public Sub PopuniTablicuNNID(Brojslogova As Long)
On Error GoTo ErrPopuni
    
    Dim BigBit As DAO.Database
    Dim StavkeN As DAO.Recordset
    Dim i As Integer
    
    Set BigBit = CurrentDb
    Set StavkeN = BigBit.OpenRecordset("NalepniceNNID", DB_OPEN_DYNASET)

'StavkeN.MoveFirst                                      ' Pozicioniraj se na prvi rekord
   
     For i = 1 To Brojslogova
    
        StavkeN.AddNew
        StavkeN![ID] = i
        StavkeN.Update
        
     Next i
     
    StavkeN.Close
    Set StavkeN = Nothing
    BigBit.Close
    Set BigBit = Nothing
Exit Sub

ErrPopuni:

 MsgBox Error$
 Resume Next
End Sub
Public Sub ObrisiTablicuNNID()
 DoCmd.SetWarnings False
 DoCmd.OpenQuery "NalepniceNNIDObrisiStavke", acNormal, acEdit
 DoCmd.SetWarnings True
End Sub
