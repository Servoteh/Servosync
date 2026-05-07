Attribute VB_Name = "APL_CNN"
Option Compare Database
Option Explicit
Public Function UskladjenCNN_LIBIAPL(stCNN_LibName As String, stAPL_LokalTableName As String, Optional ByRef stMsg, Optional DisplayMSG As Boolean = False) As Boolean
On Error GoTo Err_Point

 Dim stCNN_APL As String
 Dim stCNN_LIB As String
 Dim retValOk As Boolean
 Dim pstMSG As String
 
 On Error Resume Next 'Možda ne postoji lokalna tabela
   stCNN_APL = Nz(GetParFromCnnString("DATABASE=", CurrentDb.TableDefs(stAPL_LokalTableName).Connect), "")
   retValOk = (err.Number = 0)
 On Error GoTo Err_Point
 If Not retValOk Then
    stCNN_APL = "Ne postoji lokalna tabela " & stAPL_LokalTableName
 End If
 stCNN_LIB = Nz(GetParFromCnnString("DATABASE=", Eval(stCNN_LibName & "()")), "") 'ako CNN gadja SQL bazu
 
 If stCNN_LIB = "" Then 'ako CNN ne gadja SQL bazu
    stCNN_LIB = Nz(GetParFromCnnString("Data Source=", Eval(stCNN_LibName & "()")), "") 'ako CNN gadja Access bazu
 End If
 
 retValOk = (Trim(stCNN_APL) = Trim(stCNN_LIB))
 
 If Not retValOk Then
    pstMSG = pstMSG & stCNN_LibName & "=" & stCNN_LIB
    pstMSG = pstMSG & vbCrLf & stAPL_LokalTableName & "=" & stCNN_APL
    
    If Not IsMissing(stMsg) Then
        stMsg = stMsg & vbCrLf & pstMSG & vbCrLf
    End If
    
    If DisplayMSG Then
        pstMSG = "Nisu uskladjeni CNN!" & vbCrLf & vbCrLf & pstMSG
        MsgBox pstMSG, vbExclamation, "QBigTeh"
    End If
 End If

Exit_Point:
 On Error Resume Next
 UskladjenCNN_LIBIAPL = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "UskladjenCNN_LIBIAPL"
 retValOk = False
 Resume Exit_Point
End Function
Public Function UskladjeniSviCNN_LIBIAPL(Optional ByRef stMsg, Optional DisplayMSG As Boolean = False) As Boolean
On Error GoTo Err_Point
 Dim pstMSG As String
 Dim retValOk As Boolean
 
 retValOk = True
 retValOk = retValOk And UskladjenCNN_LIBIAPL("CNN_CurrentDataBase", "_T_Rev", pstMSG, False)
 retValOk = retValOk And UskladjenCNN_LIBIAPL("CNN_CFG_Global", "CFG_Global", pstMSG, False)
 retValOk = retValOk And UskladjenCNN_LIBIAPL("CNN_CFG_Lokal", "CFG_Lokal", pstMSG, False)
 'retValOk = retValOk And UskladjenCNN_LIBIAPL("CNN_TempDB", "KAFE_IzabraniRacuniZaNaplatu", pstMSG, False)
 'retValOk = retValOk And UskladjenCNN_LIBIAPL("CNN_SHUTTLE", "SHUTTLE_R_Artikli", pstMSG, False)
 'retValOk = retValOk And UskladjenCNN_LIBIAPL("CNN_ESDB", "es_order", pstMSG, False)
 If Not retValOk Then
    If Not IsMissing(stMsg) Then
       stMsg = pstMSG
    End If
    If DisplayMSG Then
        pstMSG = "Nisu uskladjeni CNN!" & vbCrLf & vbCrLf & pstMSG
        MsgBox pstMSG, vbExclamation, "QBigTeh"
    End If
 End If

Exit_Point:
 On Error Resume Next
 UskladjeniSviCNN_LIBIAPL = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "UskladjeniSviCNN_LIBIAPL"
 retValOk = False
 Resume Exit_Point
End Function
Public Function CNNStringZaFITTabelu(stTableName As String) As String
Dim stCNNRetVal As String

    stCNNRetVal = BazaZaTabelu(stTableName)
    
 If stCNNRetVal = "" Then
    stCNNRetVal = "" 'zbog citkosti
 ElseIf stCNNRetVal Like "ODBC*" Then
    stCNNRetVal = Replace(stCNNRetVal, "ODBC;", "")
 Else
    stCNNRetVal = CreateAccess_CNNString(stCNNRetVal)
 End If
 
 CNNStringZaFITTabelu = stCNNRetVal
End Function
Public Function CNNStringZaFITTip(stFITTip As String) As String
Dim stCNNRetVal As String

    stCNNRetVal = BazaZaTip(stFITTip)
    
 If stCNNRetVal = "" Then
    stCNNRetVal = "" 'zbog citkosti
 ElseIf stCNNRetVal Like "ODBC*" Then
    stCNNRetVal = Replace(stCNNRetVal, "ODBC;", "")
 Else
    stCNNRetVal = CreateAccess_CNNString(stCNNRetVal)
 End If
 
   CNNStringZaFITTip = stCNNRetVal
End Function
Public Function PostaviSveCNNIzFIT() As Boolean
'Modifikovano 23-08-2021
On Error GoTo Err_Point
 Dim retValOk As Boolean
 Dim stCNNString As String
 
 retValOk = True
 
 'retValOK = retValOK And BBCreateProperty("CNN_FIT", , CNNStringZaFITTip("BB_FIT"))
 retValOk = retValOk And BBCreateProperty("CNN_CFG_Lokal", , CNNStringZaFITTabelu("CFG_Lokal"))
 retValOk = retValOk And BBCreateProperty("CNN_CFG_Global", , CNNStringZaFITTabelu("CFG_Global"))
 retValOk = retValOk And BBCreateProperty("CNN_CurrentDataBase", , CNNStringZaFITTip("BigTehn_T"))
 
  If Nz(BazaZaTip("MasterDB"), "-") = "-" Then '23-08-2021          Ako nije definisana baza MasterDB, onda je to CurrentDatabase, tj. BigBit_T
    retValOk = retValOk And BBCreateProperty("CNN_MasterDB", , CNNStringZaFITTip("BigBit_T"))
  Else
    retValOk = retValOk And BBCreateProperty("CNN_MasterDB", , CNNStringZaFITTip("MasterDB"))
  End If
 
 retValOk = retValOk And BBCreateProperty("CNN_ESDB", , CNNStringZaFITTip("ES"))
 retValOk = retValOk And BBCreateProperty("CNN_SHUTTLE", , CNNStringZaFITTip("SHUTTLE"))
 retValOk = retValOk And BBCreateProperty("CNN_TempDB", , CNNStringZaFITTip("TMP"))
 
 CNNReset
 
Exit_Point:
 On Error Resume Next
 PostaviSveCNNIzFIT = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PostaviSveCNNIzFIT"
 retValOk = False
 Resume Exit_Point
End Function
