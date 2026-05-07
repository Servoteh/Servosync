Attribute VB_Name = "PDMXMLParser"
Option Compare Database
Option Explicit

Public Function ImportXMLWithReferences(ByVal xmlFilePath As String) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    
    Dim db As DAO.Database
    Dim xmlDoc As Object
    Set db = CurrentDb
    Set xmlDoc = CreateObject("MSXML2.DOMDocument.6.0")
    xmlDoc.async = False
    'xmlDoc.Load "C:\PDMExport\XML\1111138_A_Test.xml" ' <-- izmeni po potrebi
    'xmlDoc.Load "C:\PDMExport\XML\1111138_A.xml" 'xmlFilePath
    xmlDoc.Load xmlFilePath
    If xmlDoc.parseError.ErrorCode <> 0 Then
        MsgBox "Greška u XML-u: " & xmlDoc.parseError.reason
        retValOk = False
        'Exit Function
        Resume Exit_Point
    End If

    Dim txn As Object
    For Each txn In xmlDoc.SelectNodes("//transaction")
         ProcessDocumentNode txn.SelectSingleNode("document"), txn, Null, True
    Next
    'MsgBox "Import sa referencama završen."

Exit_Point:
    On Error Resume Next
    ImportXMLWithReferences = retValOk
Exit Function

Err_Point:
    MsgBox err & " - ImportXMLWithReferences"
    retValOk = False
    Resume Exit_Point
End Function

Public Function ProcessDocumentNode(ByVal docNode As Object, ByVal txnNode As Object, ByVal parentID As Variant, ByVal transaction As Boolean) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    
    Dim db As DAO.Database
    Dim cfgNode As Object, attrNode As Object
    Dim rst As DAO.Recordset
    
    Dim attrName  As String
    Dim attrValue As String
    Dim valueAttr As Object

    Set db = CurrentDb
    Set rst = db.OpenRecordset("PDM_Document", dbOpenDynaset)

    Set cfgNode = docNode.SelectSingleNode("configuration")

    rst.AddNew
    ' Osnovni iz transaction
    rst!transaction = transaction
    rst!TransactionDate = DateAdd("s", CLng(txnNode.Attributes.getNamedItem("date").Text), #1/1/1970#)
    'rst!TransactionType = txnNode.Attributes.getNamedItem("type").Text
    'rst!VaultName = txnNode.Attributes.getNamedItem("vaultname").Text

    ' Iz dokumenta
    'rst!DocAliasSet = docNode.Attributes.getNamedItem("aliasset").Text
    rst!docID = docNode.Attributes.getNamedItem("id").Text
    'rst!DocIdAttribute = docNode.Attributes.getNamedItem("idattribute").Text
    'rst!DocCfgName = docNode.Attributes.getNamedItem("idcfgname").Text
    rst!DocPDMWeID = CLng(docNode.Attributes.getNamedItem("pdmweid").Text)
    rst!ParentDocID = IIf(IsNull(parentID), Null, parentID)

    ' Iz konfiguracije
    'rst!CfgName = cfgNode.Attributes.getNamedItem("name").Text
    'rst!CfgQuantity = CDbl(cfgNode.Attributes.getNamedItem("quantity").Text)

    ' Atributi
    Dim FieldName As String
    For Each attrNode In cfgNode.SelectNodes("attribute")
        FieldName = "Attr_" & Replace(attrNode.Attributes.getNamedItem("name").Text, " ", "_")
        attrName = attrNode.Attributes.getNamedItem("name").Text
        If FieldExists(rst, FieldName) Then
            'rst(fieldName) = attrNode.Attributes.getNamedItem("value").Text
            On Error Resume Next
            Set valueAttr = attrNode.Attributes.getNamedItem("value")
            On Error GoTo 0
            
            If Not valueAttr Is Nothing Then
                attrValue = valueAttr.Text
            Else
                attrValue = ""    ' nema value atributa
            End If
            
            ' Poseban sluèaj za Revision: ako je prazan ili ne postoji, upiši "A"
            If attrName = "Revision" And Len(Trim$(attrValue)) = 0 Then
                attrValue = "A"
            End If
            
            rst(FieldName) = attrValue
        End If
    Next

    rst.Update
    rst.Close

    ' Obradi sve reference
    Dim refNode As Object
    For Each refNode In cfgNode.SelectNodes("references/document")
        Call ProcessDocumentNode(refNode, txnNode, docNode.Attributes.getNamedItem("id").Text, False)
    Next

Exit_Point:
    On Error Resume Next
    ProcessDocumentNode = retValOk
Exit Function

Err_Point:
    MsgBox err & " - ProcessDocumentNode"
    retValOk = False
    Resume Exit_Point
End Function

Public Function FieldExists(rst As DAO.Recordset, FieldName As String) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    
    On Error Resume Next
    Dim tmp
    tmp = rst(FieldName)
    retValOk = (err.Number = 0)
    err.Clear

Exit_Point:
    On Error Resume Next
    FieldExists = retValOk
Exit Function

Err_Point:
    MsgBox err & " - FieldExists"
    retValOk = False
    Resume Exit_Point
End Function
