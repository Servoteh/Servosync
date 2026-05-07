Attribute VB_Name = "BBODBC_Testovi"
Option Compare Database
Option Explicit

Public Function ODBCExportTablePodToClient(MasterTable As String, ClientTable As String, CnnStringMaster As String, CnnStringClient As String)
   Dim pCnnStringClient As ADODB.Connection
End Function

Public Function ODBCReadTable(TableName As String, CNNString As String, ByRef pRST As ADODB.Recordset)
   'Const pCnnString = "ODBC;Description=QBigBit;DRIVER=SQL Server;SERVER=(local);Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=QBigBit;Regional=Yes"
   Dim pCNN As New ADODB.Connection
   Dim pCMD As New ADODB.Command
   'Dim pRst As New ADODB.Recordset
   Dim pCNNString As String
   Dim retVal As String
   
   'pCNNString = "ODBC;Description=QBigBit;DRIVER=SQL Server;SERVER=(local);Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=QBigBit;Regional=Yes"
   pCNNString = "ODBC;Description=VuleMarket;DRIVER=SQL Server;SERVER=P50\SQLEXPRESS;Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=VuleMarket;Regional=Yes"
   pCNN.ConnectionString = pCNNString
   pCNN.Open

   pCMD.CommandText = "SELECT * FROM [" & TableName & "]"
   Set pCMD.ActiveConnection = pCNN
   Set pRST = pCMD.Execute()
    While Not pRST.EOF
     Debug.Print pRST!Naziv
     pRST.MoveNext
   Wend
   'retval = pCnn.DefaultDatabase
   pCNN.Close
   
   Set ODBCReadTable = pRST
   
End Function
Public Sub ODBCTest1()
 Dim pRST As New ADODB.Recordset
 Call ODBCReadTable("Komitenti", "ODBC;Description=QBigBit;DRIVER=SQL Server;SERVER=(local);Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=QBigBit;Regional=Yes", pRST)
   While Not pRST.EOF
     Debug.Print pRST!Naziv
     pRST.MoveNext
   Wend
  pRST.Close
End Sub

'**************************
'Attributes and Name Properties Example (VB)
Public Sub ReadAttrAndNameProp()
    On Error GoTo ErrorHandler

    'recordset and connection variables
    Dim Cnxn As ADODB.Connection
    Dim strCnxn As String
    Dim rstKomitentis As ADODB.Recordset
    Dim strSQLKomitenti As String
     'record variables
    Dim adoField As ADODB.Field
    Dim adoProp As ADODB.Property
    
    ' Open connection
    'strCnxn = "Provider='sqloledb';Data Source='MySqlServer';" & _
    '    "Initial Catalog='Pubs';Integrated Security='SSPI';"
    strCnxn = "ODBC;Description=QBigBit;DRIVER=SQL Server;SERVER=(local);Trusted_Connection=Yes;APP=Microsoft Office 2010;DATABASE=QBigBit;Regional=Yes"
        
    Set Cnxn = New ADODB.Connection
    Cnxn.Open strCnxn
   
    ' Open recordset
    Set rstKomitentis = New ADODB.Recordset
    strSQLKomitenti = "Komitenti"
    rstKomitentis.Open strSQLKomitenti, Cnxn, adOpenForwardOnly, adLockReadOnly, adCmdTable
    'the above two lines openign the recordset are identical as
    'the default values for CursorType and LockType arguments match those shown
    
    ' Display the attributes of the connection
    Debug.Print "Connection attributes = " & Cnxn.Attributes
    
    ' Display the property attributes of the Komitenti Table
    Debug.Print "Property attributes:"
    For Each adoProp In rstKomitentis.Properties
        Debug.Print "   " & adoProp.Name & " = " & adoProp.Attributes
    Next adoProp
    
    ' Display the field attributes of the Komitenti Table
    Debug.Print "Field attributes:"
    For Each adoField In rstKomitentis.Fields
       Debug.Print "   " & adoField.Name & " = " & adoField.Attributes
    Next adoField

    ' Display fields of the Komitenti Table which are NULLABLE
    Debug.Print "NULLABLE Fields:"
    For Each adoField In rstKomitentis.Fields
        If CBool(adoField.Attributes And adFldIsNullable) Then
            Debug.Print "   " & adoField.Name
        End If
    Next adoField

    ' clean up
    rstKomitentis.Close
    Cnxn.Close
    Set rstKomitentis = Nothing
    Set Cnxn = Nothing
    Exit Sub
    
ErrorHandler:
    ' clean up
    If Not rstKomitentis Is Nothing Then
        If rstKomitentis.State = adStateOpen Then rstKomitentis.Close
    End If
    Set rstKomitentis = Nothing
    
    If Not Cnxn Is Nothing Then
        If Cnxn.State = adStateOpen Then Cnxn.Close
    End If
    Set Cnxn = Nothing
    
    If err <> 0 Then
        MsgBox err.Source & "-->" & err.Description, , "Error"
    End If
End Sub
''This example uses the Delete method to remove a specified record from a Recordset.
Public Sub DeleteRecordInMKomitentiPazi()
'This example uses the Delete method to remove a specified record from a Recordset.
    On Error GoTo ErrorHandler

    Dim rstRoySched As ADODB.Recordset
    Dim Cnxn As ADODB.Connection
    Dim strCnxn As String
    Dim strSQLRoySched As String
    
    Dim strMsg As String
    Dim strTitleID As String
    Dim intLoRange As Integer
    Dim intHiRange As Integer
    Dim intRoyalty As Integer
    
     ' open connection
    Set Cnxn = New ADODB.Connection
    strCnxn = "Provider='sqloledb';Data Source='MySqlServer';" & _
        "Initial Catalog='Pubs';Integrated Security='SSPI';"
        
    Cnxn.ConnectionTimeout = 1
    Cnxn.Open strCnxn
    
    ' open RoySched table with cursor client-side
    Set rstRoySched = New ADODB.Recordset
    rstRoySched.CursorLocation = adUseClient
    rstRoySched.CursorType = adOpenStatic
    rstRoySched.LockType = adLockBatchOptimistic
    rstRoySched.Open "SELECT * FROM roysched WHERE royalty = 20", strCnxn, , , adCmdText
    
    ' Prompt for a record to delete
    strMsg = "Before delete there are " & rstRoySched.RecordCount & _
       " titles with 20 percent royalty:" & vbCr & vbCr
    
    Do While Not rstRoySched.EOF
       strMsg = strMsg & rstRoySched!title_id & vbCr
       rstRoySched.MoveNext
    Loop
    
    strMsg = strMsg & vbCr & vbCr & "Enter the ID of a record to delete:"
    strTitleID = UCase(InputBox(strMsg))
    
    If strTitleID = "" Then
        err.Raise 1, , "You didn't enter any value for the record ID."
    End If
    
    ' Move to the record and save data so it can be restored
    rstRoySched.Filter = "title_id = '" & strTitleID & "'"
    
    If rstRoySched.RecordCount < 1 Then
        err.Raise 1, , "There is no record for the record ID you entered."
    End If
    
    intLoRange = rstRoySched!lorange
    intHiRange = rstRoySched!hirange
    intRoyalty = rstRoySched!royalty
    
    ' Delete the record
    rstRoySched.Delete
    rstRoySched.UpdateBatch
    
    ' Show the results
    rstRoySched.Filter = adFilterNone
    rstRoySched.Requery
    strMsg = ""
    strMsg = "After delete there are " & rstRoySched.RecordCount & _
       " titles with 20 percent royalty:" & vbCr & vbCr
    Do While Not rstRoySched.EOF
        strMsg = strMsg & rstRoySched!title_id & vbCr
        rstRoySched.MoveNext
    Loop
    MsgBox strMsg
    
    ' Restore the data because this is a demonstration
    rstRoySched.AddNew
    rstRoySched!title_id = strTitleID
    rstRoySched!lorange = intLoRange
    rstRoySched!hirange = intHiRange
    rstRoySched!royalty = intRoyalty
    rstRoySched.UpdateBatch

    ' clean up
    rstRoySched.Close
    Set rstRoySched = Nothing
    Exit Sub
    
ErrorHandler:
    ' clean up
    If Not rstRoySched Is Nothing Then
        If rstRoySched.State = adStateOpen Then rstRoySched.Close
    End If
    Set rstRoySched = Nothing
    
    If err <> 0 Then
        MsgBox err.Source & "-->" & err.Description, , "Error"
    End If
End Sub
'EndDeleteVB
 
'*******************
'-------------------------------
'BeginAddNewVB

    'To integrate this code
    'replace the data source and initial catalog values
    'in the connection string

Private Sub XXXXMain()
    On Error GoTo ErrorHandler

    'recordset and connection variables
    Dim Cnxn As ADODB.Connection
    Dim rstEmployees As ADODB.Recordset
    Dim strCnxn As String
    Dim strSQL As String
     'record variables
    Dim strID As String
    Dim strFirstName As String
    Dim strLastName As String
    Dim blnRecordAdded As Boolean

    ' Open a connection
    Set Cnxn = New ADODB.Connection
    strCnxn = "Provider='sqloledb';Data Source='MySqlServer';" & _
        "Initial Catalog='Northwind';Integrated Security='SSPI';"
    Cnxn.Open strCnxn
       
    ' Open Employees Table with a cursor that allows updates
    Set rstEmployees = New ADODB.Recordset
    strSQL = "Employees"
    rstEmployees.Open strSQL, strCnxn, adOpenKeyset, adLockOptimistic, adCmdTable
    
    ' Get data from the user
    strFirstName = Trim(InputBox("Enter first name:"))
    strLastName = Trim(InputBox("Enter last name:"))
    
    ' Proceed only if the user actually entered something
    ' for both the first and last names
    If strFirstName <> "" And strLastName <> "" Then
    
        rstEmployees.AddNew
        rstEmployees!firstname = strFirstName
        rstEmployees!LastName = strLastName
        rstEmployees.Update
        blnRecordAdded = True
        
        ' Show the newly added data
        MsgBox "New record: " & rstEmployees!EmployeeId & " " & _
        rstEmployees!firstname & " " & rstEmployees!LastName
        
    Else
        MsgBox "Please enter a first name and last name."
    End If
          
    ' Delete the new record because this is a demonstration
    Cnxn.Execute "DELETE FROM Employees WHERE EmployeeID = '" & strID & "'"
     
    ' clean up
    rstEmployees.Close
    Cnxn.Close
    Set rstEmployees = Nothing
    Set Cnxn = Nothing
    Exit Sub
    
ErrorHandler:
   ' clean up
    If Not rstEmployees Is Nothing Then
        If rstEmployees.State = adStateOpen Then rstEmployees.Close
    End If
    Set rstEmployees = Nothing
    
    If Not Cnxn Is Nothing Then
        If Cnxn.State = adStateOpen Then Cnxn.Close
    End If
    Set Cnxn = Nothing
    
    If err <> 0 Then
        MsgBox err.Source & "-->" & err.Description, , "Error"
    End If
End Sub


Public Sub TestReadXML()
 Dim pRST As New ADODB.Recordset

 pRST.Open "D:\TMP\XML\KomitentiSaServera.xml", , , , adCmdFile

 Debug.Print "Broj slogova u lokalnom rsetu: " & pRST.RecordCount
 pRST.Close
 Set pRST = Nothing
End Sub
Public Sub TestAppendXML()
 Dim pRST As New ADODB.Recordset

 pRST.Open "D:\TMP\XML\KomitentiSaServera.xml", , , , adCmdFile
 pRST.AddNew
 pRST!Naziv = "NOVI ARTIKAL"
 pRST.Update
 
 
 pRST.Save "D:\TMP\XML\KomitentiSaServera.xml", adPersistXML
 
 Debug.Print "Broj slogova u lokalnom rsetu: " & pRST.RecordCount
 pRST.Close
 Set pRST = Nothing
End Sub
Public Function TestRST()
 Dim rstADO As New ADODB.Recordset
 Dim rstDAO As DAO.Recordset
 
 Set rstDAO = CurrentDb.OpenRecordset("Komitenti", dbOpenDynaset, dbSeeChanges)
 Set rstADO = ADO_GetRST(CNN_CurrentDataBase, "SELECT * FROM Komitenti")
 
 If TypeOf rstDAO Is DAO.Recordset Then
  Debug.Print "rstDAO JESTE DAO"
 Else
  Debug.Print "rstDAO NIJE DAO"
 End If
 
 If TypeOf rstDAO Is ADODB.Recordset Then
  Debug.Print "rstDAO JESTE ADODB"
 Else
  Debug.Print "rstDAO NIJE ADODB"
 End If
 
 If TypeOf rstADO Is DAO.Recordset Then
  Debug.Print "rstADO JESTE DAO"
 Else
  Debug.Print "rstADO NIJE DAO"
 End If
 
 If TypeOf rstADO Is ADODB.Recordset Then
  Debug.Print "rstADO JESTE ADODB"
 Else
  Debug.Print "rstADO NIJE ADODB"
 End If
 
 rstADO.Close
 rstDAO.Close
 
End Function
