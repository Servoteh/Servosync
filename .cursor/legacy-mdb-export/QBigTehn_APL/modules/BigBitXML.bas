Attribute VB_Name = "BigBitXML"
Option Compare Database
Option Explicit
Public Function UcitajXMLFajl(imeXMLfajla As String)
'On Error GoTo errClose:
    
    Dim InputChar, InputString, ImePolja, VrednostPolja As String
    Dim CitaSeImePolja As Boolean
    Dim BrojNavodnika As Integer
    Dim PoslednjaDvaZnaka As String
    Dim BrojSloga As Long
    
    
    
    BrojSloga = 0
    PoslednjaDvaZnaka = ""
    
   DoCmd.Hourglass True
   DoCmd.SetWarnings False
   DoCmd.OpenQuery "XML_Imported_ObrisiTabelu"
   DoCmd.SetWarnings True
   
    'Open "D:\AcBaze\BBEOROL\B_Beorol2008\2008178R.xml" For Input As #1 ' Open file for input.
    Open imeXMLfajla For Input As #1 ' Open file for input.
        Do While Not EOF(1) ' Loop until end of file.
            InputChar = Input(1, #1) ' Read data into two variables.
            InputString = InputString & InputChar
            PoslednjaDvaZnaka = Right$(PoslednjaDvaZnaka & InputChar, 2)
            If InputChar = ">" Then    ' kraj sloga
                'Debug.Print Len(InputString), InputString
                InputString = ""
            End If
            
            Select Case InputChar
            Case " ", ">", "\", "/"
                If BrojNavodnika = 0 Then
                 CitaSeImePolja = True
                ' Debug.Print BrojSloga, ImePolja & "=" & Trim(VrednostPolja)
                 SnimiSlogUXMLTabelu "-", BrojSloga, Trim(ImePolja), Trim(VrednostPolja)
                 ImePolja = ""
                 VrednostPolja = ""
                 Else
                    VrednostPolja = VrednostPolja & InputChar
                End If
            Case "="
                CitaSeImePolja = False
            Case """"
                BrojNavodnika = (BrojNavodnika + 1) Mod 2
            Case "<"
            Case Else
                If CitaSeImePolja Then
                    ImePolja = ImePolja & InputChar
                Else
                    VrednostPolja = VrednostPolja & InputChar
                End If
            End Select
            
            If PoslednjaDvaZnaka = "/>" Then BrojSloga = BrojSloga + 1
            
        Loop
errClose:
    Close #1    ' Close file.
    DoCmd.SetWarnings True
    DoCmd.Hourglass False
End Function
Private Sub SnimiSlogUXMLTabelu(imeTabele, BrojSloga, ImePolja, VrednostPolja)

    Dim tbl As DAO.Recordset
    Set tbl = CurrentDb.OpenRecordset("xml_Imported", dbOpenDynaset)
    

    tbl.AddNew

    tbl![imeTabele] = Left(imeTabele, 50)
    tbl![BrojSloga] = BrojSloga
    tbl![ImePolja] = Left(ImePolja, 150)
    tbl![VrednostPolja] = Left(VrednostPolja, 150)
    tbl.Update
    
    
    tbl.Close
    Set tbl = Nothing
End Sub
