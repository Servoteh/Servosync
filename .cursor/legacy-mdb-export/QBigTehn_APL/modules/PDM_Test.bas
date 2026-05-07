Attribute VB_Name = "PDM_Test"
Option Compare Database
Option Explicit

Sub CreateAndPopulatePDMDocumentTable_TEST()
    Dim db As DAO.Database
    Dim tdf As DAO.TableDef
    Dim xmlDoc As Object
    Dim txnNode As Object, docNode As Object, cfgNode As Object, attrNode As Object
    Dim attrDict As Object
    Dim sql As String
    Dim col As Variant
    Dim FieldName As String

    ' Pokupi sve atribute kao kolone
    Set attrDict = CreateObject("Scripting.Dictionary")

    ' Uèitaj XML
    Set xmlDoc = CreateObject("MSXML2.DOMDocument.6.0")
    xmlDoc.async = False
    xmlDoc.Load "C:\PDMExport\XML\1111128_A.xml" ' <- Izmeni putanju 1111131_A.xml

    If xmlDoc.parseError.ErrorCode <> 0 Then
        MsgBox "Greška: " & xmlDoc.parseError.reason
        Exit Sub
    End If

    Set txnNode = xmlDoc.SelectSingleNode("//transaction")
    Set docNode = txnNode.SelectSingleNode("document")
    Set cfgNode = docNode.SelectSingleNode("configuration")

    ' Skupi sve jedinstvene atribute
    For Each attrNode In cfgNode.SelectNodes("attribute")
        FieldName = "Attr_" & Replace(attrNode.Attributes.getNamedItem("name").Text, " ", "_")
        'fieldName = Replace(attrNode.Attributes.getNamedItem("name").Text, " ", "_")
        If Not attrDict.Exists(FieldName) Then attrDict.Add FieldName, "TEXT"
    Next

    ' Obriši postojeæu tabelu ako postoji
    Set db = CurrentDb
    On Error Resume Next
    db.Execute "DROP TABLE PDM_Document"
    On Error GoTo 0

    ' Kreiraj SQL za tabelu
    sql = "CREATE TABLE PDM_Document (" & _
          "TransactionDate DATETIME, " & _
          "TransactionType TEXT(50), " & _
          "VaultName TEXT(100), " & _
          "DocAliasSet TEXT(50), " & _
          "DocID LONG, " & _
          "DocIdAttribute TEXT(50), " & _
          "DocCfgName TEXT(50), " & _
          "DocPDMWeID LONG, " & _
          "CfgName TEXT(50), " & _
          "CfgQuantity DOUBLE"

    ' Dodaj atribute kao kolone
    For Each col In attrDict.keys
        sql = sql & ", " & col & " TEXT(255)"
    Next
    sql = sql & ")"

    ' Kreiraj tabelu
    db.Execute sql

    ' Unos podataka
    Dim rst As DAO.Recordset
    Set rst = db.OpenRecordset("PDM_Document", dbOpenDynaset)

    rst.AddNew
    rst!TransactionDate = DateAdd("s", CLng(txnNode.Attributes.getNamedItem("date").Text), #1/1/1970#)
    rst!TransactionType = txnNode.Attributes.getNamedItem("type").Text
    rst!VaultName = txnNode.Attributes.getNamedItem("vaultname").Text

    rst!DocAliasSet = docNode.Attributes.getNamedItem("aliasset").Text
    rst!docID = CLng(docNode.Attributes.getNamedItem("id").Text)
    rst!DocIdAttribute = docNode.Attributes.getNamedItem("idattribute").Text
    rst!DocCfgName = docNode.Attributes.getNamedItem("idcfgname").Text
    rst!DocPDMWeID = CLng(docNode.Attributes.getNamedItem("pdmweid").Text)

    rst!CfgName = cfgNode.Attributes.getNamedItem("name").Text
    rst!CfgQuantity = CDbl(cfgNode.Attributes.getNamedItem("quantity").Text)

    ' Dodaj vrednosti svih atributa
    For Each attrNode In cfgNode.SelectNodes("attribute")
        FieldName = "Attr_" & Replace(attrNode.Attributes.getNamedItem("name").Text, " ", "_")
        'fieldName = Replace(attrNode.Attributes.getNamedItem("name").Text, " ", "_")
        rst(FieldName) = attrNode.Attributes.getNamedItem("value").Text
    Next

    rst.Update
    rst.Close

    MsgBox "Tabela PDM_Document je uspešno kreirana i popunjena."

End Sub

