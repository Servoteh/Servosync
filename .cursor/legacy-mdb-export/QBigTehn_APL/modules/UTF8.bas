Attribute VB_Name = "UTF8"
Option Compare Database
Option Explicit
Public Function UTF8FileConstant() As String
 '"ï»¿"
 'asc("ï")      asc("»")     asc("¿")
 ' 239           187           191
 
 UTF8FileConstant = Chr(239) & Chr(187) & Chr(191)
End Function
Public Function StrToUTF8(stToConvert As String) As String

'È=ÄŒ
 ' U+0106  Æ   0xC4 0x86   \304\206    &#262;
 ' U+0107  æ   0xC4 0x87   \304\207    &#263;
 ' U+010C  È   0xC4 0x8C   \304\214    &#268; '? asc("Ä") = 196, ,asc("Œ") = 140
 ' U+010D  è   0xC4 0x8D   \304\215    &#269;
 ' U+0110  Ð   0xC4 0x90   \304\220    &#272;
 ' U+0111  ð   0xC4 0x91   \304\221    &#273;
 ' U+0160  Š   0xC5 0xA0   \305\240    &#352;
 ' U+0161  š   0xC5 0xA1   \305\241    &#353;
 ' U+017D  Ž   0xC5 0xBD   \305\275    &#381;
 ' U+017E  ž   0xC5 0xBE   \305\276    &#382;

    Dim retVal As String
    Dim nChar As Long
    Dim i As Integer
    For i = 1 To Len(stToConvert)
        nChar = AscW(Mid(stToConvert$, i, 1))
        If nChar < 128 Then
            retVal = retVal & Mid(stToConvert, i, 1)
        ElseIf ((nChar > 127) And (nChar < 2048)) Then
           retVal = retVal + Chr$(((nChar \ 64) Or 192))
           retVal = retVal + Chr$(((nChar And 63) Or 128))
        Else
           retVal = retVal + Chr$(((nChar \ 144) Or 234))
           retVal = retVal + Chr$((((nChar \ 64) And 63) Or 128))
           retVal = retVal + Chr$(((nChar And 63) Or 128))
        End If
    Next
    StrToUTF8 = retVal
End Function

Private Function ReadTXT(ImeFajla As String) As String
' Samo za testiranje
 'ReadTXT("C:\SHARES\Export\JesteUTF8.XML"
 Dim txtfajl As Variant
 Dim txtslog As String
 
 txtfajl = FreeFile
 Open ImeFajla For Input As #txtfajl
 Input #txtfajl, txtslog
 ReadTXT = txtslog
Close #txtfajl
End Function

Public Sub TEST_WriteTXTUTF8(ImeFajla As String, txtslog As String)
 'TEST_WriteTXTUTF8("C:\SHARES\Export\tmp.XML","Èaèak")
 'È=ÄŒ
 ' U+0106  Æ   0xC4 0x86   \304\206    &#262;
 ' U+0107  æ   0xC4 0x87   \304\207    &#263;
 ' U+010C  È   0xC4 0x8C   \304\214    &#268; '? asc("Ä") = 196, ,asc("Œ") = 140
 ' U+010D  è   0xC4 0x8D   \304\215    &#269;
 ' U+0110  Ð   0xC4 0x90   \304\220    &#272;
 ' U+0111  ð   0xC4 0x91   \304\221    &#273;
 ' U+0160  Š   0xC5 0xA0   \305\240    &#352;
 ' U+0161  š   0xC5 0xA1   \305\241    &#353;
 ' U+017D  Ž   0xC5 0xBD   \305\275    &#381;
 ' U+017E  ž   0xC5 0xBE   \305\276    &#382;

 Dim txtfajl As Variant
 Dim txtzaupis As String
 
 txtfajl = FreeFile
 Open ImeFajla For Output As #txtfajl
 
 'Print #txtfajl, "ï»¿<A>ÄŒ</A>" 'ï»¿ = 239 187 191 -  È =  196 140
 txtzaupis = txtslog
 
 'Print #txtfajl, "ï»¿<A>" & Chr(AscB(txtslog)) & Chr(Asc(txtslog)) & "</A>"
 Print #txtfajl, "ï»¿<A>" & StrToUTF8(txtzaupis) & "</A>"
Close #txtfajl
End Sub
Sub test_ExportCustomerOrderData()
 Dim objOrderInfo As AdditionalData
 Dim objOrderDetailsInfo As AdditionalData
 
 Set objOrderInfo = Application.CreateAdditionalData
 
 ' Add the Orders and Order Details tables to the data to be exported.
 Set objOrderDetailsInfo = objOrderInfo.Add("T_Robna dokumenta")
 objOrderDetailsInfo.Add "T_Robne stavke"
 
 ' Export the contents of the Customers table. The Orders and Order
 ' Details tables will be included in the XML file.
 Application.ExportXML ObjectType:=acExportTable, DataSource:="Komitenti", _
 DataTarget:="C:\SHARES\Export\XXX.xml", _
 AdditionalData:=objOrderInfo
End Sub

