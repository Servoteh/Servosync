Attribute VB_Name = "ADO_ComboRecordset"
Option Compare Database
Option Explicit
Private Function Valid_FROM(TableOrSelectSQL As String) As String
On Error GoTo Err_Point
Dim stFROM As String
 
 If Left(TableOrSelectSQL, 6) = "SELECT" Then
        stFROM = " FROM (" & TableOrSelectSQL & ") as R"
 Else
        stFROM = " FROM " & Valid_NazivKolone(TableOrSelectSQL) & " as R"
 End If
 
Exit_Point:
 On Error Resume Next
 Valid_FROM = stFROM
Exit Function

Err_Point:
 BBErrorMSG err, "Valid_FROM"
 stFROM = TableOrSelectSQL
 Resume Exit_Point
End Function
Private Function Valid_WHERE(WhereUslov As String) As String
On Error GoTo Err_Point
Dim stWhere As String
 
 If WhereUslov <> "" Then
        stWhere = " WHERE " & WhereUslov
 Else
        stWhere = ""
 End If
 
Exit_Point:
 On Error Resume Next
 Valid_WHERE = stWhere
Exit Function

Err_Point:
 BBErrorMSG err, "Valid_WHERE"
 stWhere = WhereUslov
 Resume Exit_Point
End Function
Private Function Valid_ORDER_BY(Order_By As String) As String
On Error GoTo Err_Point
Dim stOrder_By As String
 
 If Order_By <> "" Then
        stOrder_By = " ORDER By " & Valid_NazivKolone(Order_By)
 Else
        stOrder_By = ""
 End If
 
Exit_Point:
 On Error Resume Next
 Valid_ORDER_BY = stOrder_By
Exit Function

Err_Point:
 BBErrorMSG err, "Valid_ORDER_BY"
 stOrder_By = Order_By
 Resume Exit_Point
End Function
Private Function Valid_NazivKolone(ByVal Name As String) As String
'Modifikovano: 22-10-2023

Dim stRetVal As String

stRetVal = Trim(Name)

 If stRetVal <> "*" Then
    If (Left(stRetVal, 1) <> "[") Then stRetVal = "[" & stRetVal
    If (Right(stRetVal, 1) <> "]") Then stRetVal = stRetVal & "]"
 End If
 
 Valid_NazivKolone = stRetVal
 
End Function
Public Function Valid_SELECT(ParamArray Arg()) As String
On Error GoTo Err_Point

Dim InBrojParametara As Integer, i As Integer
Dim stSELECT As String

InBrojParametara = UBound(Arg()) - LBound(Arg())
stSELECT = "SELECT "
For i = 0 To InBrojParametara
   stSELECT = stSELECT & Valid_NazivKolone(Arg(i))
   If i < InBrojParametara Then
    stSELECT = stSELECT & ", "
   End If
Next i

Exit_Point:
 On Error Resume Next
 Valid_SELECT = stSELECT
Exit Function

Err_Point:
 BBErrorMSG err, "Valid_SELECT"
 Resume Exit_Point
End Function
Public Function RST_Combo(ByVal CNNString As String, ByVal TableOrSelectSQL As String, ByVal WhereUslov As String, ByVal OrderBy As String, ParamArray ColumnList()) As ADODB.Recordset
On Error GoTo Err_Point
Dim stSQL As String
Dim InBrojParametara As Integer, i As Integer
Dim stSELECT As String

    InBrojParametara = UBound(ColumnList()) - LBound(ColumnList())
    stSELECT = "SELECT "
    For i = 0 To InBrojParametara
       stSELECT = stSELECT & Valid_NazivKolone(ColumnList(i))
       If i < InBrojParametara Then
        stSELECT = stSELECT & ", "
       End If
    Next i
    
    stSQL = stSELECT
    stSQL = stSQL & Valid_FROM(TableOrSelectSQL)
    stSQL = stSQL & Valid_WHERE(WhereUslov)
    stSQL = stSQL & Valid_ORDER_BY(OrderBy)
    
    Set RST_Combo = ADO_GetRST(CNNString, stSQL, dbOptimistic, adUseClient, adOpenStatic)

Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "RST_Combo"
 Resume Exit_Point
End Function
Public Function RST_Combo_KataloskiBroj(Optional CNNString, Optional TableOrSelectSQL As String = "R_Artikli", Optional WhereUslov As String = "", Optional OrderBy As String = "Kataloski broj") As ADODB.Recordset
On Error GoTo Err_Point
Dim stSQL As String
Dim pCNNString
    
    If IsMissing(CNNString) Then
       pCNNString = LIB_CFGRW.CNN_CurrentDataBase
    Else
       pCNNString = CNNString
    End If
    
    Set RST_Combo_KataloskiBroj = RST_Combo(pCNNString, "R_Artikli", WhereUslov, OrderBy, "Sifra artikla", "Kataloski broj", "Naziv")
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "RST_Combo_KataloskiBroj"
 Resume Exit_Point
End Function
Public Function RST_Combo_Grupa(Optional CNNString, Optional TableOrSelectSQL As String = "R_Artikli", Optional WhereUslov As String = "", Optional OrderBy As String = "Kataloski broj") As ADODB.Recordset
On Error GoTo Err_Point
Dim stSQL As String
Dim pCNNString
    
    If IsMissing(CNNString) Then
       pCNNString = LIB_CFGRW.CNN_CurrentDataBase
    Else
       pCNNString = CNNString
    End If
    
    Set RST_Combo_Grupa = RST_Combo(pCNNString, "R_Grupa", WhereUslov, OrderBy, "Grupa", "Opis")
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "RST_Combo_Grupa"
 Resume Exit_Point
End Function
Public Function SetCombo(stComboName As String, ctlCombo As control, Optional CNNString, Optional stWhere As String = "") As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim pCNNString
    
    retValOk = True
    
    If IsMissing(CNNString) Then
       pCNNString = LIB_CFGRW.CNN_CurrentDataBase
    Else
       pCNNString = CNNString
    End If

    
    If stComboName = "Grupa" Then
        Set ctlCombo.Recordset = RST_Combo(pCNNString, "R_Grupa", "", "Grupa", "Grupa", "Opis")
    ElseIf stComboName = "Podgrupa" Then
        Set ctlCombo.Recordset = RST_Combo(pCNNString, "R_Podgrupa", "", "Podgrupa", "Podgrupa", "Opis")
    ElseIf stComboName = "Poreklo" Then
        Set ctlCombo.Recordset = RST_Combo(pCNNString, "R_Poreklo", "", "Poreklo", "Poreklo", "Opis")
    ElseIf stComboName = "KatBroj" Or stComboName = "KataloskiBroj" Or stComboName = "Kataloski broj" Then
        Set ctlCombo.Recordset = RST_Combo(pCNNString, "R_Artikli", "", "Kataloski broj", "Sifra artikla", "Kataloski broj", "Naziv")
    ElseIf stComboName = "NazivArtikla" Or stComboName = "Naziv artikla" Then
        Set ctlCombo.Recordset = RST_Combo(pCNNString, "R_Artikli", "", "Naziv", "Sifra artikla", "Naziv", "Kataloski broj")
    ElseIf stComboName = "PLU" Then
        Set ctlCombo.Recordset = RST_Combo(pCNNString, "R_Artikli", "", "PLU", "Sifra artikla", "PLU", "Naziv")
    ElseIf stComboName = "Barkod" Or stComboName = "Barcod" Then
        Set ctlCombo.Recordset = RST_Combo(pCNNString, "R_Artikli", "", "Barkod", "Sifra artikla", "Barkod", "Naziv")
    ElseIf stComboName = "ExtSifra" Or stComboName = "Ext sifra" Then
        Set ctlCombo.Recordset = RST_Combo(pCNNString, "R_Artikli", "", "ExtSifra", "Sifra artikla", "ExtSifra", "Naziv")
    ElseIf stComboName = "NazivKomitenta" Or stComboName = "Kupac" Or stComboName = "Prodavnica" Then
        Set ctlCombo.Recordset = RST_Combo(pCNNString, "Komitenti", "", "Naziv", "Sifra", "Naziv")
    ElseIf stComboName = "VrstaDokumenta" Or stComboName = "Vrsta dokumenta" Then
        Set ctlCombo.Recordset = RST_Combo(pCNNString, "R_Vrste dokumenata", "", "Vrsta dokumenta", "Vrsta dokumenta", "Opis")
    ElseIf stComboName = "OpisKonta" Then
        Set ctlCombo.Recordset = RST_Combo(pCNNString, "Kontni plan", stWhere, "Opis", "Konto", "Opis")
    ElseIf stComboName = "Konto" Then
        Set ctlCombo.Recordset = RST_Combo(pCNNString, "Kontni plan", stWhere, "Konto", "Konto", "Opis")
    'ElseIf stComboName = "KontroleNaFormi" Then
    '    Set ctlCombo.Recordset = DRST_KontroleNaFormi()
    Else
       MsgBox "Nepoznat stComboName=" & stComboName & " u funkciji SetCombo", vbExclamation, "QMegaTeh"
       retValOk = False
    End If
Exit_Point:
 On Error Resume Next
 SetCombo = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "SetCombo(" & stComboName & "..."
 retValOk = False
 Resume Exit_Point
End Function

