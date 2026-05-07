Attribute VB_Name = "BBJson"
Option Compare Database
Option Explicit
'****************************************
'25-05-2018
'****************************************
Public Enum JsonTagTypeEnum
    JsonTagType_TEXT
    JsonTagType_NUMBER
    JsonTagType_BOOLEAN
End Enum
Public Enum JsonArrayDimEnum
    TagName = 0
    TagValue = 1
End Enum
Public Function JsonTypeFromDBType(dbType As DataTypeEnum) As JsonTagTypeEnum
  Select Case dbType
        Case dbBoolean
            JsonTypeFromDBType = JsonTagTypeEnum.JsonTagType_BOOLEAN
        Case dbLong, dbCurrency, dbSingle, dbDouble   '4, 5, 6, 7 ' fieldtype 4=long, 5=Currency, 6=Single, 7-Double
            JsonTypeFromDBType = JsonTagTypeEnum.JsonTagType_NUMBER
        Case Else
            JsonTypeFromDBType = JsonTagTypeEnum.JsonTagType_TEXT
    End Select
End Function
Public Function CreateJsonNodeString(NodeName As String, TagValue As Variant, Optional TagType = JsonTagTypeEnum.JsonTagType_TEXT) As String
On Error GoTo Err_Point
' CREATE JSON TAG

Dim VarDat As String
Dim NoNulls As Boolean
Dim QuoteID As String
Dim stRetVal As String

NoNulls = True ' set NoNulls = true to remove all null values within output ELSE set to false

' build JSON TAG from data passed
    
        If TagType = JsonTagType_NUMBER Then QuoteID = ""     ' No quote for numbers
        QuoteID = Chr(34) ' double quote for text
      
        If IsNull(TagValue) Then  ' deal with null values
            VarDat = "Null": QuoteID = ""   ' no quote for nulls
            If NoNulls = True Then VarDat = "": QuoteID = Chr(34)                       ' null text to empty quotes
            If NoNulls = True And TagType = JsonTagTypeEnum.JsonTagType_NUMBER Then VarDat = "0": QuoteID = ""     ' null number to zero without quotes
        Else
         If TagType = JsonTagType_BOOLEAN Then
            VarDat = Trim(CBool(TagValue))
         Else
            VarDat = Trim(TagValue)
         End If
        End If
        
        VarDat = Replace(VarDat, Chr(34), "'") ' replace double quote with single quote
        VarDat = Replace(VarDat, Chr(8), "")   ' remove backspace
        VarDat = Replace(VarDat, Chr(10), "")  ' remove line feed
        VarDat = Replace(VarDat, Chr(12), "")  ' remove form feed
        VarDat = Replace(VarDat, Chr(13), "")  ' remove carriage return
        VarDat = Replace(VarDat, Chr(9), "   ")  ' replace tab with spaces
        
        stRetVal = Chr(34) & NodeName & Chr(34) & ":" & QuoteID & VarDat & QuoteID
        
Exit_Point:
 On Error Resume Next
 CreateJsonNodeString = stRetVal
 
Exit Function

Err_Point:
 BBErrorMSG err, "JsonTag"
 Resume Exit_Point:
End Function
Public Function JSONStringFromFields(flds As Fields) As String
' CREATE JSON STRING FROM Fields
On Error GoTo Err_Point

Dim fld As Field
Dim stJsonRow As String
Dim stRetVal As String

stRetVal = ""

Set fld = Nothing

   stRetVal = ""
' build JSON string from fields data passed
    stRetVal = stRetVal & "{" & vbCrLf
    ' build JSON record from table/query record using fieldname and type arrays
    For Each fld In flds
        'VarFT = JsonTypeFromDBType(fld.Type)
        stJsonRow = CreateJsonNodeString(fld.Name, fld.Value, JsonTypeFromDBType(fld.Type))
        
        If flds(flds.Count - 1).Name <> fld.Name Then 'ako nije poslednje polje
         stJsonRow = stJsonRow & "," ' dodaj zapetu
        End If
        'If looper < fieldcount Then jsonRow = jsonRow & "," ' add comma if not last field
        
        stRetVal = stRetVal & Chr(9) & stJsonRow & vbCrLf
    Next fld
    stRetVal = stRetVal & "}"

Exit_Point:
 On Error Resume Next
 JSONStringFromFields = stRetVal
 
Exit Function

Err_Point:
 BBErrorMSG err, "JsonStringFromFields"
 Resume Exit_Point:
End Function
'*********************************************************************
Public Function JsonStringFromRst(rst As DAO.Recordset, Optional stListName) As String
On Error GoTo Err_Point
' CREATE JSON STRING FROM Recordset

Dim stRetVal As String

If Not IsMissing(stListName) Then
  stRetVal = "{" & vbCrLf
  stRetVal = stRetVal & Chr(34) & stListName & Chr(34) & ":" & vbCrLf
End If

stRetVal = stRetVal & "[" & vbCrLf

Do While Not rst.EOF
    
    stRetVal = stRetVal & JSONStringFromFields(rst.Fields)
    rst.MoveNext

   If Not rst.EOF Then
      stRetVal = stRetVal & "," & vbCrLf
   Else
    stRetVal = stRetVal & "" & vbCrLf
   End If
Loop

stRetVal = stRetVal & "]" & vbCrLf

If Not IsMissing(stListName) Then
   stRetVal = stRetVal & "}" & vbCrLf
End If
Exit_Point:
 On Error Resume Next
 JsonStringFromRst = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "JsonStringFromRst"
 Resume Exit_Point:
End Function

Public Function JsonStringFromQuery(stQueryTableSQLText As String, Optional stListName, Optional FromDB As DAO.Database) As String
'? JsonStringFromQuery("SELECT *,null as [NullValue] FROM Table1")
'? JsonStringFromQuery("Table1")
On Error GoTo Err_Point
 Dim db As DAO.Database
 Dim rst As DAO.Recordset
 Dim stRetVal As String
 
 If IsMissing(FromDB) Or (FromDB Is Nothing) Then
   Set db = CurrentDb
 Else
   Set db = FromDB
 End If
 Set rst = db.OpenRecordset(stQueryTableSQLText, RecordsetTypeEnum.dbOpenSnapshot, RecordsetOptionEnum.dbSeeChanges)
    stRetVal = JsonStringFromRst(rst, stListName)

Exit_Point:
 On Error Resume Next
 rst.Close
 Set rst = Nothing
 JsonStringFromQuery = stRetVal
 
Exit Function

Err_Point:
 BBErrorMSG err, "JsonStringFromQueryTableSQLText"
 Resume Exit_Point:
End Function
'***********************************************************************************************
Private Function RecursePropsGetNode(obj As Object, indent As Integer, stFullNodeName As String, stFindNodeName As String, ByRef retVal() As Variant, ByRef BrojNadjenih As Integer)
    Dim nextObject As Object
    Dim propValue As Variant
    Dim keys() As String
    Dim nextKeys() As String
    Dim i As Integer
   
       
    keys = LIB_JsonParser.GetKeys(obj)
    
    For i = 0 To UBound(keys)
                
        If LIB_JsonParser.GetPropertyType(obj, keys(i)) = jptValue Then
            propValue = LIB_JsonParser.GetProperty(obj, keys(i))
            'Debug.Print Space(Indent) & keys(i) & ": " & Nz(propValue, "[null]")
            'stFullNodeName = stFullNodeName & "." & Keys(i)
            'If Keys(i) = stFindNodeName Then
            
            If stFullNodeName & "." & keys(i) Like stFindNodeName Then
              'ReDim Preserve retVal(BrojNadjenih)
              'retVal(BrojNadjenih) = Nz(propValue, "[null]")
              'retVal(BrojNadjenih) = stFullNodeName & "." & Keys(i) & "=" & Nz(propValue, "[null]")
              BrojNadjenih = BrojNadjenih + 1
              
              ReDim Preserve retVal(1, BrojNadjenih)
              retVal(0, BrojNadjenih) = stFullNodeName & "." & keys(i)
              retVal(1, BrojNadjenih) = Nz(propValue, "[null]")
              
              
              'Debug.Print Space(Indent) & keys(i) & ": " & Nz(propValue, "[null]")
            End If
        Else
            Set nextObject = LIB_JsonParser.GetObjectProperty(obj, keys(i))
           '*****************************************************************
           '* nextKeys = LIB_LIB_JsonParser.GetKeys(nextObject)
           '* If LIB_LIB_JsonParser.GetPropertyType(nextObject, nextKeys(0)) = jptObject Then
           '*   stFullNodeName = stFullNodeName & "." & Keys(i)
           '* End If
                                        'stFullNodeName = stFullNodeName & "." & Keys(i)
                                        'Debug.Print Space(Indent) & keys(i)
            RecursePropsGetNode nextObject, indent + 2, stFullNodeName & "." & keys(i), stFindNodeName, retVal, BrojNadjenih
        End If
    
    Next i
    
End Function
Public Function GetJSONNodeList(stFindNodeName As String, stJSonString As String, ByRef retValOk As Boolean) As Variant()
 ' vraca dvodimenzioni niz retVal(0..1,0..BrojNadjenihNodova)
 ' retVal(0, 0) = "BrojSlogova"
 ' retVal(1, 0) = BrojNadjenihNodova (UBound(retVal, 2))
 ' retval(0,x) = nodename (x: 1 .. BrojNadjenihNodova)
 ' retval(1,x) = vrednost (x: 1 .. BrojNadjenihNodova)
 '************************************
 On Error GoTo Err_Point
 
    Dim root As Object
    Dim Content As String
    Dim rootKeys() As String
    Dim keys() As String
    Dim i As Integer
    Dim obj As Object
    Dim prop As Variant
    Dim retVal() As Variant
    Dim BrojNadjenih As Integer
    Dim stFullNodeName As String
    
    BrojNadjenih = 0
    ReDim retVal(0 To 1, BrojNadjenih)
   
    Content = stJSonString
    
    Content = Replace(Content, vbCrLf, "")
    Content = Replace(Content, vbTab, "")
 
    LIB_JsonParser.InitScriptEngine
 
    Set root = LIB_JsonParser.DecodeJsonString(Content)
  
    rootKeys = LIB_JsonParser.GetKeys(root)
    
   'Call PrikaziNiz(LIB_JsonParser.GetKeys(root))
    stFullNodeName = "root"
    For i = 0 To UBound(rootKeys)
        
        'stFullNodeName = rootKeys(i)
        
        If LIB_JsonParser.GetPropertyType(root, rootKeys(i)) = jptValue Then
            prop = LIB_JsonParser.GetProperty(root, rootKeys(i))
            If stFullNodeName & "." & rootKeys(i) Like stFindNodeName Then
            'If stFullNodeName = stFindNodeName Then
              BrojNadjenih = BrojNadjenih + 1
              ReDim Preserve retVal(1, BrojNadjenih)
              retVal(0, BrojNadjenih) = stFullNodeName & "." & rootKeys(i) '& "=" & Nz(prop, "[null]")
              retVal(1, BrojNadjenih) = Nz(prop, "[null]")
              
            End If
           
        Else
            'Debug.Print rootKeys(i)
            'stFullNodeName = stFullNodeName & rootKeys(i)
            Set obj = LIB_JsonParser.GetObjectProperty(root, rootKeys(i))
            RecursePropsGetNode obj, 2, stFullNodeName & "." & rootKeys(i), stFindNodeName, retVal, BrojNadjenih
        End If
        
    Next i
Exit_Point:
 On Error Resume Next
    retVal(0, 0) = "BrojSlogova"
    retVal(1, 0) = UBound(retVal, 2)
 GetJSONNodeList = retVal
 Exit Function
Err_Point:
 'BBErrorMSG err, "GetJSONNodeList"
 retValOk = False
 Resume Exit_Point
End Function
Public Function VredIz2DimNiza(ByRef nekiNiz(), stFind As String, Optional OdIndexa As Integer = 1) As Variant

 Dim lb, ub, i
 Dim retVal As Variant
 
  lb = LBound(nekiNiz, 2)
  ub = UBound(nekiNiz, 2)
  retVal = Null
  
  For i = OdIndexa To ub
   If nekiNiz(0, i) Like stFind Then
      retVal = nekiNiz(1, i)
      Exit For
   End If
  Next
  VredIz2DimNiza = retVal
End Function
Public Function Prikazi2DimNiz(nekiNiz(), Optional ConvertToLat As Boolean = True)
'? Prikazi2DimNiz(GetJSONNodeList("*", JsonStringFromQuery("Table1")))
'? Prikazi2DimNiz(GetJSONNodeList("*", ReadFileToString("C:\SHARES\AcBaze\TEST\JsonFile_ViseSlogova.txt")))
'? Prikazi2DimNiz(GetJSONNodeList("*", ReadFileToString("C:\SHARES\AcBaze\TEST\bex\postShipmentsExample.txt")))
'? Prikazi2DimNiz(GetJSONNodeList("*", ReadFileToString("C:\SHARES\EXPORT\00000001.RAC")))
'? Prikazi2DimNiz(GetJSONNodeList("*", F_JSONStringZaDef("Bex_postShipments", 15770)))

 Dim lb, ub, i
 
  lb = LBound(nekiNiz, 2)
  ub = UBound(nekiNiz, 2)
  
  For i = 0 To ub
   If ConvertToLat Then
    Debug.Print i; Space$(5); Cyr2Lat(nekiNiz(JsonArrayDimEnum.TagName, i)) & " = " & Cyr2Lat(nekiNiz(TagValue, i))
   Else
    Debug.Print i; Space$(5); nekiNiz(JsonArrayDimEnum.TagName, i) & " = " & nekiNiz(TagValue, i)
   End If
  Next
End Function
Public Sub TestNiz()
   Dim a() As Variant
   'a = GetJSONNodeList("*state", ReadFileToString("C:\SHARES\AcBaze\TEST\JsonFile_ViseSlogova.txt"))
   Prikazi2DimNiz a
End Sub
