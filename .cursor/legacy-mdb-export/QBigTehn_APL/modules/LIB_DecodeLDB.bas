Attribute VB_Name = "LIB_DecodeLDB"
Option Compare Database
Option Explicit

Private Sub ShowUserRosterMultipleUsers()
    Dim cn As New ADODB.Connection
    Dim rs As New ADODB.Recordset
    Dim i, j As Long

    Set cn = CurrentProject.Connection

    ' The user roster is exposed as a provider-specific schema rowset
    ' in the Jet 4.0 OLE DB provider.  You have to use a GUID to
    ' reference the schema, as provider-specific schemas are not
    ' listed in ADO's type library for schema rowsets

    Set rs = cn.OpenSchema(adSchemaProviderSpecific, _
    , "{947bb102-5d43-11d1-bdbf-00c04fb92675}")

    'Output the list of all users in the current database.
    Debug.Print rs.Fields(0).Name, "", rs.Fields(1).Name, _
    "", rs.Fields(2).Name, rs.Fields(3).Name

    While Not rs.EOF
        Debug.Print rs.Fields(0), rs.Fields(1), _
        rs.Fields(2), rs.Fields(3)
        rs.MoveNext
    Wend

End Sub
Private Sub ShowUserRosterMultipleUsers_acc2000()
    Dim cn As New ADODB.Connection
    Dim cn2 As New ADODB.Connection
    Dim rs As New ADODB.Recordset
    Dim i, j As Long

    cn.Provider = "Microsoft.Jet.OLEDB.4.0"
    'cn.Open "Data Source=c:\Northwind.mdb"
    ' "C:\SHARES\AcBaze\BJovanovic\BigBitTG\TG\BB_BT_TG.MDB"
    cn.Open "Data Source=C:\SHARES\AcBaze\BJovanovic\BigBitTG\TG\BB_BT_TG.MDB"
    
    'cn2.Open "Provider=Microsoft.Jet.OLEDB.4.0;" _
    & "Data Source=c:\Northwind.mdb"

    ' The user roster is exposed as a provider-specific schema rowset
    ' in the Jet 4 OLE DB provider.  You have to use a GUID to
    ' reference the schema, as provider-specific schemas are not
    ' listed in ADO's type library for schema rowsets

    Set rs = cn.OpenSchema(adSchemaProviderSpecific, _
    , "{947bb102-5d43-11d1-bdbf-00c04fb92675}")

    'Output the list of all users in the current database.

    Debug.Print rs.Fields(0).Name, "", rs.Fields(1).Name, _
    "", rs.Fields(2).Name, rs.Fields(3).Name

    While Not rs.EOF
        Debug.Print rs.Fields(0), rs.Fields(1), _
        rs.Fields(2), rs.Fields(3)
        rs.MoveNext
    Wend

End Sub


Public Function AktivniUseriNaBazi(PutanjaDoMDBFajla As String, Optional PrikaziPoruku As Boolean = False, Optional XMLFileName) As String
' AktivniUseriNaBazi("C:\SHARES\AcBaze\BJovanovic\BigBitTG\TG\BB_BT_TG.MDB",True)
 On Error GoTo err_Func
 
    Dim cn As New ADODB.Connection
    Dim rs As New ADODB.Recordset
    Dim i As Long
    Dim stXMLFileName As String
    Dim stRetVal As String
    Dim SaveXML As Boolean
    Dim nst As String
    
    stRetVal = "Aktivni korisnici na bazi: " & vbCrLf & vbCrLf & PutanjaDoMDBFajla & vbCrLf & vbCrLf
    nst = ""
    
    If IsMissing(XMLFileName) Then
      SaveXML = False
    Else
     SaveXML = True
     stXMLFileName = XMLFileName
    End If
    
    'Provider=Microsoft.ACE.OLEDB.12.0;
    'User ID=Slavisa;
    'vData Source=C:\SHARES\AcBaze\BigBit\BigBit_APL_2010.MDB;
    'Mode=Share Deny None;
    'Extended Properties="";
    'Jet OLEDB:System database=C:\SHARES\AcBaze\BigBit\Bigbit.mdw;
    'Jet OLEDB:Registry Path=Software\Microsoft\Office\14.0\Access\Access Connectivity Engine;
    'Jet OLEDB:Database Password="";
    'Jet OLEDB:Engine Type=5;
    'Jet OLEDB:Database Locking Mode=1;
    'Jet OLEDB:Global Partial Bulk Ops=2;
    'Jet OLEDB:Global Bulk Transactions=1;
    'Jet OLEDB:New Database Password="";
    'Jet OLEDB:Create System Database=False;
    'Jet OLEDB:Encrypt Database=False;
    'Jet OLEDB: Don 't Copy Locale on Compact=False;
    'Jet OLEDB:Compact Without Replica Repair=False;
    'Jet OLEDB:SFP=False;
    'Jet OLEDB:Support Complex Data=True
    
    cn.Provider = "Microsoft.Jet.OLEDB.4.0"
    If UserUGrupi("ReadUser", "Users") Then
     cn.Properties("User ID") = "ReadUser"
    Else
     cn.Properties("User ID") = CurrentUser()
     cn.Properties("Password") = InputBox("Password: ", "UserName: " & CurrentUser())
    End If
    
    cn.Properties("Jet OLEDB:System database") = Application.DBEngine.Properties("SystemDB") '"C:\SHARES\AcBaze\BigBit\Bigbit.mdw"
    cn.Open "Data Source=" & PutanjaDoMDBFajla
    
    'cn2.Open "Provider=Microsoft.Jet.OLEDB.4.0;" _
    & "Data Source=c:\Northwind.mdb"

    ' The user roster is exposed as a provider-specific schema rowset
    ' in the Jet 4 OLE DB provider.  You have to use a GUID to
    ' reference the schema, as provider-specific schemas are not
    ' listed in ADO's type library for schema rowsets

    Set rs = cn.OpenSchema(adSchemaProviderSpecific, _
    , "{947bb102-5d43-11d1-bdbf-00c04fb92675}")

    'rs.Save "D:\TMP\XML\AktivniUseriNaBazi.xml", PersistFormatEnum.adPersistXML
    
    'stXMLFileName = "D:\TMP\XML\AktivniUseriNaBazi.xml"
    If SaveXML Then
     If FileExists(stXMLFileName) Then
      Kill stXMLFileName
     End If
     rs.Save stXMLFileName, PersistFormatEnum.adPersistXML
    End If
    
    'Output the list of all users in the current database.
    For i = 0 To rs.Fields().Count - 2
     nst = CStr(Nz(rs.Fields(i).Name, "Null"))
         nst = Replace(nst, Chr(0), " ") ' ZameniStr(Chr(0), " ", nst)
         nst = Trim(nst)
         nst = DoChRight(nst, 15, " ")
      stRetVal = stRetVal & " " & nst 'CStr(rs.Fields(i).Value)
     'stRetVal = stRetVal & Left(DoChRight(Trim(Nz(rs.Fields(i).Name, "Null")), 20, " "), 20)
     'stRetVal = stRetVal & Trim(Nz(rs.Fields(i).Name, "<<Null>>")) & "/"
    Next i
    stRetVal = stRetVal & vbCrLf
  
    While Not rs.EOF
     For i = 0 To rs.Fields().Count - 2
         nst = CStr(Nz(rs.Fields(i).Value, "Null"))
         nst = Replace(nst, Chr(0), " ") 'ZameniStr(Chr(0), " ", nst)
         nst = Trim(nst)
         nst = DoChRight(nst, 30, " ")
         stRetVal = stRetVal & " " & nst 'CStr(rs.Fields(i).Value)
        'stRetVal = stRetVal & Trim(CStr(Nz(rs.Fields(i), "<<Null>>"))) & "/"
        'stRetVal = stRetVal & DoChRight("x", 20, " ") 'DoChRight(Trim(Nz(rs.Fields(i), "<<Null>>")), 20, " ")
       
     Next i
     stRetVal = stRetVal & vbCrLf
     rs.MoveNext
    Wend
exit_Func:
  On Error Resume Next
   
  rs.Close
  Set rs = Nothing
  cn.Close
  
  If PrikaziPoruku Then
   MsgBox stRetVal, vbInformation, "QMegaTeh"
   'BBMsgBox stRetVal
  End If
  
  AktivniUseriNaBazi = stRetVal

Exit Function
err_Func:
 BBErrorMSG err, "AktivniUseriNaBazi_TXT" '(" & PutanjaDoMDBFajla & ")"
 stRetVal = stRetVal & vbCrLf & "err: " & err.Description
 Resume exit_Func:
End Function
'****************************
Public Function AktivniUseriNaSQLBazi(ConnectionString As String, Optional PrikaziPoruku As Boolean = False, Optional XMLFileName) As String
'Modifikovano: 30-08-2021
'Modifikovano: 03-11-2021
 On Error GoTo err_Func
 Const cSir = 20
    Dim pCNNString As String
    Dim cnn As New ADODB.Connection
    Dim cmd As New ADODB.Command
    Dim rst As New ADODB.Recordset
    Dim i As Long
    Dim stXMLFileName As String
    Dim stRetVal As String
    Dim SaveXML As Boolean
    Dim nst As String
    
    
       pCNNString = ConnectionString
    
   
    stRetVal = "Aktivni korisnici na bazi: " & vbCrLf & vbCrLf & BBCFG.CnnStringBezPWD() & vbCrLf & vbCrLf
    nst = ""
    
    If IsMissing(XMLFileName) Then
      SaveXML = False
    Else
     SaveXML = True
     stXMLFileName = XMLFileName
    End If
    
    'cnn.ConnectionString = BBCFG.CNNString
    cnn.ConnectionString = pCNNString
    cnn.Open
    
    cmd.ActiveConnection = cnn
    cmd.CommandText = "spAktivniUseri"
    cmd.CommandType = adCmdStoredProc
    cmd.ActiveConnection.CursorLocation = adUseClient 'ako ovo ne stavim ne radi XML tj. ne može da se vrati na poèetak recordseta
    cmd.Parameters.Refresh
    'Cmd.Parameters("@DBName") = "AlGrosso"
    cmd.Parameters("@DBName") = GetParFromCnnString("DATABASE=", F_CNNString("SQL"))
    Set rst = cmd.Execute()
    
    'Output the list of all users in the current database.
    For i = 0 To rst.Fields().Count - 1
     nst = CStr(Nz(rst.Fields(i).Name, "Null"))
         nst = Replace(nst, Chr(0), " ") 'ZameniStr(Chr(0), " ", nst)
         nst = Trim(nst)
          If rst.Fields(i).Name = "program_name" Then
            nst = Left(DoChRight(nst, 50, " "), 50)
         ElseIf rst.Fields(i).Name = "uid" Then
            nst = Left(DoChRight(nst, 5, " "), 5)
         ElseIf rst.Fields(i).Name = "hostprocess" Then
            nst = Left(DoChRight(nst, 11, " "), 11)
         Else
            nst = Left(DoChRight(nst, cSir, " "), cSir)
         End If
      stRetVal = stRetVal & " " & nst 'CStr(rst.Fields(i).Value)
     'stRetVal = stRetVal & Left(DoChRight(Trim(Nz(rst.Fields(i).Name, "Null")), 20, " "), 20)
     'stRetVal = stRetVal & Trim(Nz(rst.Fields(i).Name, "<<Null>>")) & "/"
    Next i
    stRetVal = stRetVal & vbCrLf
    
    While Not rst.EOF
     For i = 0 To rst.Fields().Count - 1
         nst = CStr(Nz(rst.Fields(i).Value, "Null"))
         nst = Replace(nst, Chr(0), " ") 'ZameniStr(Chr(0), " ", nst)
         nst = Trim(nst)
         If rst.Fields(i).Name = "program_name" Then
            nst = Left(DoChRight(nst, 50, " "), 50)
         ElseIf rst.Fields(i).Name = "uid" Then
            nst = Left(DoChRight(nst, 5, " "), 5)
         ElseIf rst.Fields(i).Name = "hostprocess" Then
            nst = Left(DoChRight(nst, 11, " "), 11)
         Else
            nst = Left(DoChRight(nst, cSir, " "), cSir)
         End If
         stRetVal = stRetVal & " " & nst 'CStr(rst.Fields(i).Value)
        'stRetVal = stRetVal & Trim(CStr(Nz(rst.Fields(i), "<<Null>>"))) & "/"
        'stRetVal = stRetVal & DoChRight("x", 20, " ") 'DoChRight(Trim(Nz(rst.Fields(i), "<<Null>>")), 20, " ")
       
     Next i
     stRetVal = stRetVal & vbCrLf
     rst.MoveNext
    Wend
    
    If SaveXML Then
     If FileExists(stXMLFileName) Then
      Kill stXMLFileName
     End If
     rst.Save stXMLFileName, PersistFormatEnum.adPersistXML
    End If
  
exit_Func:
  On Error Resume Next
  
  rst.Close
  Set rst = Nothing
  cnn.Close
  
  If PrikaziPoruku Then
   MsgBox stRetVal, vbInformation, "QMegaTeh"
   'BBMsgBox stRetVal
  End If
  
  AktivniUseriNaSQLBazi = stRetVal

Exit Function
err_Func:
 BBErrorMSG err, "AktivniUseriNaSQLBazi" '(" & cnnString & ")"
 stRetVal = stRetVal & vbCrLf & "err: " & err.Description
 Resume exit_Func:
End Function

