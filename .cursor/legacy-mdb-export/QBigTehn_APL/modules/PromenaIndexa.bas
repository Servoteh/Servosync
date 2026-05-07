Attribute VB_Name = "PromenaIndexa"
Option Compare Database
Option Explicit

Sub PromeniIndexeUTabeli(nametabela As String, nameindex As String, PocevOd As Long)
   'call PromeniIndexeUTabeli("SHUTTLERobne Stavke", "IDStavke", 1)
   ' On Error Resume Next
    Dim Criteria As String
    Dim BigBit As DAO.Database
    Dim Tabela As DAO.Recordset
    Dim n As Long
    
    Set BigBit = CurrentDb

    
     Set Tabela = BigBit.OpenRecordset("SELECT * FROM [" & nametabela & "] ORDER BY [" & nameindex & "] DESC;")
    Debug.Print "Radim tabelu " & nametabela & "."
    
    If (Tabela.BOF And Tabela.EOF) Then  ' Inace tabela nema slogova
        Debug.Print "Tabela " & nametabela & " ima 0 slogova."
    Else
        Tabela.MoveLast
        Debug.Print "Tabela " & nametabela & " ima " & Tabela.RecordCount & " slogova."
        Tabela.MoveFirst
    
        n = PocevOd
        Do Until Tabela.EOF ' Until end of file.
            'Debug.Print "Sada radim " & N & " slog."
        
            Tabela.Edit
            'tabela![IDNaloga] = N
            Tabela.Fields(nameindex) = n
            Tabela.Update
            Tabela.MoveNext    ' Move to next record.
            n = n + 1
        Loop
        Debug.Print "Reindex uradjen na " & n - PocevOd & " slogova."
        Debug.Print "__________________________________________________________"
    End If
    
    Tabela.Close
    BigBit.Close
    
    Set Tabela = Nothing
    Set BigBit = Nothing
    
End Sub
