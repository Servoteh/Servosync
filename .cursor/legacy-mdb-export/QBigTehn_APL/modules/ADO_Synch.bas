Attribute VB_Name = "ADO_Synch"
Option Compare Database
Option Explicit
Public ADO_Komentar As String

Public Function CreateDirTree(ByVal PathWithoutFile As String) As Boolean
On Error GoTo errFunc

Const sep = "\"
Dim dirTree() As String
Dim dirName As String
Dim lpos As Integer
Dim retVal As Boolean
Dim arrDim As Integer
Dim locPath As String

arrDim = 0
locPath = PathWithoutFile

    retVal = False
    Do
     lpos = InStr(locPath, sep)
     If (lpos > 0) Then
         dirName = Left(locPath, lpos - 1)
         If dirName <> "" Then
          arrDim = arrDim + 1
          ReDim Preserve dirTree(arrDim)
          dirTree(arrDim - 1) = dirName
         End If
      locPath = Right(locPath, Len(locPath) - lpos)
     End If
    Loop While lpos > 0
    If Trim(locPath) <> "" Then
        arrDim = arrDim + 1
        ReDim Preserve dirTree(arrDim)
        dirTree(arrDim - 1) = Trim(locPath)
    End If
    

 'testiranje
 ' Dim i As Integer
 ' For i = 0 To arrDim - 1
 '  Debug.Print i, dirTree(i)
 ' Next i
 'kraj testiranja

 
  Dim i As Integer
  dirName = ""
  For i = 0 To arrDim - 1
   dirName = dirName & dirTree(i) & "\"
   If Not DirExists(dirName) Then
    MkDir dirName
   End If
  Next i
  retVal = True
exitFunc:
     CreateDirTree = retVal
Exit Function
errFunc:
 MsgBox "Greška u funkciji <CreateDirTree>"
 retVal = False
 Resume exitFunc

End Function

Public Function KreirajShuttleDB(Optional ObrisiAkoPostoji As Boolean = True) As Boolean
On Error GoTo Err_Point

Dim retValOk As Boolean
Dim stImeBaze As String
Dim postojiBaza As Boolean
Dim wrkAcc As Workspace
Dim stPWD As String

If Not IsAccessCNNString(CNN_SHUTTLE) Then
   retValOk = False
   KreirajShuttleDB = retValOk
   Exit Function
End If

   stImeBaze = GetParFromCnnString("Data Source=", CNN_SHUTTLE)
   retValOk = CreateDirTree(FolderFromPath(stImeBaze))
   'retValOk = BBCreateDatabase(stImeBaze, True)
   If Not (stImeBaze Like "*.MDB") Then
        stImeBaze = stImeBaze & ".MDB"
    End If
    postojiBaza = (Dir(stImeBaze) <> "")
    If postojiBaza Then
        If ObrisiAkoPostoji Then
            Kill stImeBaze
        Else
            retValOk = False
            KreirajShuttleDB = retValOk
            Exit Function
        End If
    End If
   
   If CurrentUser <> "Admin" Then
    stPWD = "telefon"
   Else
    stPWD = ""
   End If
   Set wrkAcc = CreateWorkspace("", "admin", stPWD)
   Call wrkAcc.CreateDatabase(stImeBaze, dbLangGeneral, dbVersion40)
   'Call BBCompactDatabase(stImeBaze)

Exit_Point:
On Error Resume Next
 wrkAcc.Close
 Set wrkAcc = Nothing
   
 KreirajShuttleDB = retValOk

Exit Function
 
Err_Point:
 BBErrorMSG err, "KreirajShuttleDB"
 retValOk = False
 Resume Exit_Point
End Function
Public Function EXPORT_IzMasterUShuttle(TableName_MASTER As String, TableName_SHUTTLE As String, Optional ByVal SQLWHERE = "", Optional OnErrorShowMsg As Boolean = True) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

 retValOk = ADO_ExportTable(CNN_MasterDB, TableName_MASTER, CNN_SHUTTLE, TableName_SHUTTLE, SQLWHERE, True, OnErrorShowMsg)
 
Exit_Point:
On Error Resume Next
 EXPORT_IzMasterUShuttle = retValOk
Exit Function
 
Err_Point:
 BBErrorMSG err, "EXPORT_IzMasterUShuttle"
 retValOk = False
 Resume Exit_Point
End Function
Public Function IMPORT_IzShuttleUKasu(TableName_SHUTTLE As String, TableName_KASA As String, Optional ByVal SQLWHERE = "", Optional OnErrorShowMsg As Boolean = False) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

 retValOk = ADO_ExportTable(CNN_SHUTTLE, TableName_SHUTTLE, LIB_CFGRW.CNN_CurrentDataBase, TableName_KASA, SQLWHERE, False, OnErrorShowMsg)
 
Exit_Point:
On Error Resume Next
 IMPORT_IzShuttleUKasu = retValOk
Exit Function
 
Err_Point:
 BBErrorMSG err, "IMPORT_IzShuttleUKasu"
 retValOk = False
 Resume Exit_Point
End Function
Public Function IMPORT_IzMasterUKasu(TableName_MASTER As String, TableName_KASA As String, Optional ByVal SQLWHERE = "", Optional OnErrorShowMsg As Boolean = False) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

 retValOk = ADO_ExportTable(CNN_MasterDB, TableName_MASTER, LIB_CFGRW.CNN_CurrentDataBase, TableName_KASA, SQLWHERE, False, OnErrorShowMsg)
 
Exit_Point:
On Error Resume Next
 IMPORT_IzMasterUKasu = retValOk
Exit Function
 
Err_Point:
 BBErrorMSG err, "IMPORT_IzMasterUKasu"
 retValOk = False
 Resume Exit_Point
End Function
Public Function EXPORT_IzKaseUMaster(TableName_KASA As String, TableName_MASTER As String, Optional ByVal SQLWHERE = "", Optional OnErrorShowMsg As Boolean = False) As Boolean
  EXPORT_IzKaseUMaster = IMPORT_IzKaseUMaster(TableName_KASA, TableName_MASTER, SQLWHERE, OnErrorShowMsg)
End Function
Public Function IMPORT_IzKaseUMaster(TableName_KASA As String, TableName_MASTER As String, Optional ByVal SQLWHERE = "", Optional OnErrorShowMsg As Boolean = False) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

 retValOk = ADO_ExportTable(LIB_CFGRW.CNN_CurrentDataBase, TableName_KASA, CNN_MasterDB, TableName_MASTER, SQLWHERE, False, OnErrorShowMsg)
 
Exit_Point:
On Error Resume Next
 IMPORT_IzKaseUMaster = retValOk
Exit Function
 
Err_Point:
 BBErrorMSG err, "IMPORT_IzKaseUMaster"
 retValOk = False
 Resume Exit_Point
End Function
Public Function UPDATE_IzShuttleUKasu(TableName_SHUTTLE As String, TableName_KASA As String, _
                                        ByVal PK_FieldName1 As String, Optional ByVal PK_FieldName2 As String = "", Optional ByVal PK_FieldName3 As String = "", _
                                        Optional OnErrorShowMsg As Boolean = False) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

 retValOk = ADO_UpdateTable(CNN_SHUTTLE, TableName_SHUTTLE, LIB_CFGRW.CNN_CurrentDataBase, TableName_KASA, PK_FieldName1, PK_FieldName2, PK_FieldName3, OnErrorShowMsg)
 
Exit_Point:
On Error Resume Next
 UPDATE_IzShuttleUKasu = retValOk
Exit Function
 
Err_Point:
 BBErrorMSG err, "UPDATE_IzShuttleUKasu"
 retValOk = False
 Resume Exit_Point
End Function
Public Function UPDATE_IzMasterUKasu(TableName_MASTER As String, TableName_KASA As String, _
                                        ByVal PK_FieldName1 As String, Optional ByVal PK_FieldName2 As String = "", Optional ByVal PK_FieldName3 As String = "", _
                                        Optional OnErrorShowMsg As Boolean = False) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

 retValOk = ADO_UpdateTable(CNN_MasterDB, TableName_MASTER, LIB_CFGRW.CNN_CurrentDataBase, TableName_KASA, PK_FieldName1, PK_FieldName2, PK_FieldName3, OnErrorShowMsg)
 
Exit_Point:
On Error Resume Next
 UPDATE_IzMasterUKasu = retValOk
Exit Function
 
Err_Point:
 BBErrorMSG err, "UPDATE_IzMasterUKasu"
 retValOk = False
 Resume Exit_Point
End Function
Public Function UPDATE_IzKaseUMaster(TableName_KASA As String, TableName_MASTER As String, _
                                        ByVal PK_FieldName1 As String, Optional ByVal PK_FieldName2 As String = "", Optional ByVal PK_FieldName3 As String = "", _
                                        Optional OnErrorShowMsg As Boolean = False) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean

 retValOk = ADO_UpdateTable(LIB_CFGRW.CNN_CurrentDataBase, TableName_KASA, CNN_MasterDB, TableName_MASTER, PK_FieldName1, PK_FieldName2, PK_FieldName3, OnErrorShowMsg)
 
Exit_Point:
On Error Resume Next
 UPDATE_IzKaseUMaster = retValOk
Exit Function
 
Err_Point:
 BBErrorMSG err, "UPDATE_IzMasterUKasu"
 retValOk = False
 Resume Exit_Point
End Function
Public Function Synch_MasterToKasa_Direct(TableName_MASTER As String, TableName_KASA As String, _
                                        ByVal PK_FieldName1 As String, Optional ByVal PK_FieldName2 As String = "", Optional ByVal PK_FieldName3 As String = "", _
                                        Optional OnErrorShowMsg As Boolean = False) As Boolean
On Error GoTo Err_Point
Const BrZnLn = 180
Dim retValOk As Boolean
Dim StartTime As Variant, endTime As Variant
Dim ProlazTimeStart As Variant, ProlazTimeEnd As Variant
        
        StartTime = Timer
        
        ADO_Komentar = ""
        ADO_Komentar = ADO_Komentar & String(BrZnLn, "-")
        ADO_Komentar = ADO_Komentar & vbCrLf & Now() & " Pokrecem upit Synch_MasterToKasa_Direct('" & TableName_MASTER & "','" & TableName_KASA & "','" & PK_FieldName1 & "','" & PK_FieldName2 & "','" & PK_FieldName3 & "')" & vbCrLf
 
    ProlazTimeStart = Timer
    retValOk = UPDATE_IzMasterUKasu(TableName_MASTER, TableName_KASA, PK_FieldName1, PK_FieldName2, PK_FieldName3)
    ProlazTimeEnd = Timer
        ADO_Komentar = ADO_Komentar & "UPDATE_IzMasterUKasu.BrojSlogova = " & ADO_ROWCOUNT & " (" & ADO_ROWCOUNT_WITH_ERROR & " WITH ERROR)" & "  t= " & Format(ProlazTimeEnd - ProlazTimeStart, "###0.00000") & " sec." & vbCrLf
        
    ProlazTimeStart = Timer
    retValOk = retValOk And IMPORT_IzMasterUKasu(TableName_MASTER, TableName_KASA)
    ProlazTimeEnd = Timer
        ADO_Komentar = ADO_Komentar & "IMPORT_IzMasterUKasu.BrojSlogova = " & ADO_ROWCOUNT & " (" & ADO_ROWCOUNT_WITH_ERROR & " WITH ERROR)" & "  t= " & Format(ProlazTimeEnd - ProlazTimeStart, "###0.00000") & " sec." & vbCrLf
 
Exit_Point:
On Error Resume Next
 endTime = Timer
 Synch_MasterToKasa_Direct = retValOk
 ADO_Komentar = ADO_Komentar & Now() & " Završen upit Synch_MasterToKasa_Direct('" & TableName_MASTER & "','" & TableName_KASA & "','" & PK_FieldName1 & "','" & PK_FieldName2 & "','" & PK_FieldName3 & "')" & vbCrLf
 ADO_Komentar = ADO_Komentar & "UKUPNO VREME = " & Format(endTime - StartTime, "###0.00000") & " sec." & vbCrLf
 ADO_Komentar = ADO_Komentar & String(BrZnLn, "-") & vbCrLf
    
Exit Function
 
Err_Point:
 BBErrorMSG err, "Synch_MasterToKasa_Direct"
 retValOk = False
 Resume Exit_Point
End Function
Public Function Synch_MasterToKasaViaShuttle(TableName_MASTER As String, TableName_KASA As String, _
                                        ByVal PK_FieldName1 As String, Optional ByVal PK_FieldName2 As String = "", Optional ByVal PK_FieldName3 As String = "", _
                                        Optional OnErrorShowMsg As Boolean = False) As Boolean
On Error GoTo Err_Point
Const BrZnLn = 120
Dim retValOk As Boolean
Dim StartTime As Variant, endTime As Variant
Dim ProlazTimeStart As Variant, ProlazTimeEnd As Variant
        StartTime = Timer
        
        ADO_Komentar = ""
        ADO_Komentar = ADO_Komentar & String(BrZnLn, "-")
        ADO_Komentar = ADO_Komentar & vbCrLf & Now() & " Pokrecem upit Synch_MasterToKasaViaShuttle " & vbCrLf
 ProlazTimeStart = Timer
 retValOk = EXPORT_IzMasterUShuttle(TableName_MASTER, TableName_MASTER)
 ProlazTimeEnd = Timer
        ADO_Komentar = ADO_Komentar & "EXPORT_IzMasterUShuttle.BrojSlogova = " & ADO_ROWCOUNT & " (" & ADO_ROWCOUNT_WITH_ERROR & " WITH ERROR)" & "  t= " & Format(ProlazTimeEnd - ProlazTimeStart, "###0.00000") & " sec." & vbCrLf
        
 If retValOk Then
    ProlazTimeStart = Timer
    retValOk = UPDATE_IzShuttleUKasu(TableName_MASTER, TableName_KASA, PK_FieldName1, PK_FieldName2, PK_FieldName3)
    ProlazTimeEnd = Timer
        ADO_Komentar = ADO_Komentar & "UPDATE_IzShuttleUKasu.BrojSlogova = " & ADO_ROWCOUNT & " (" & ADO_ROWCOUNT_WITH_ERROR & " WITH ERROR)" & "  t= " & Format(ProlazTimeEnd - ProlazTimeStart, "###0.00000") & " sec." & vbCrLf
        
    ProlazTimeStart = Timer
    retValOk = retValOk And IMPORT_IzShuttleUKasu(TableName_MASTER, TableName_KASA)
    ProlazTimeEnd = Timer
        ADO_Komentar = ADO_Komentar & "IMPORT_IzShuttleUKasu.BrojSlogova = " & ADO_ROWCOUNT & " (" & ADO_ROWCOUNT_WITH_ERROR & " WITH ERROR)" & "  t= " & Format(ProlazTimeEnd - ProlazTimeStart, "###0.00000") & " sec." & vbCrLf
 End If
 
Exit_Point:
On Error Resume Next
 endTime = Timer
 Synch_MasterToKasaViaShuttle = retValOk
 ADO_Komentar = ADO_Komentar & Now() & " Završen upit Synch_MasterToKasaViaShuttle" & vbCrLf
 ADO_Komentar = ADO_Komentar & "UKUPNO VREME = " & Format(endTime - StartTime, "###0.00000") & " sec." & vbCrLf
 ADO_Komentar = ADO_Komentar & String(BrZnLn, "-") & vbCrLf
    
Exit Function
 
Err_Point:
 BBErrorMSG err, "Synch_MasterToKasaViaShuttle"
 retValOk = False
 Resume Exit_Point
End Function

Public Function Synch_KasaToMaster_Direct(TableName_KASA As String, TableName_MASTER As String, _
                                        ByVal PK_FieldName1 As String, Optional ByVal PK_FieldName2 As String = "", Optional ByVal PK_FieldName3 As String = "", _
                                        Optional OnErrorShowMsg As Boolean = False) As Boolean
'? Synch_KasaToMaster_Direct("T_MPDokumenta","T_MPDokumenta","IDDok","IDProdavnica","IDKasa",true)
On Error GoTo Err_Point
Const BrZnLn = 180
Dim retValOk As Boolean
Dim StartTime As Variant, endTime As Variant
Dim ProlazTimeStart As Variant, ProlazTimeEnd As Variant
        
        StartTime = Timer
        
        ADO_Komentar = ""
        ADO_Komentar = ADO_Komentar & String(BrZnLn, "-")
        ADO_Komentar = ADO_Komentar & vbCrLf & Now() & " Pokrecem upit Synch_KasaToMaster_Direct('" & TableName_KASA & "','" & TableName_MASTER & "','" & PK_FieldName1 & "','" & PK_FieldName2 & "','" & PK_FieldName3 & "')" & vbCrLf
 
    ProlazTimeStart = Timer
    retValOk = UPDATE_IzKaseUMaster(TableName_KASA, TableName_MASTER, PK_FieldName1, PK_FieldName2, PK_FieldName3, OnErrorShowMsg)
    ProlazTimeEnd = Timer
        ADO_Komentar = ADO_Komentar & "UPDATE_IzKaseUMaster.BrojSlogova = " & ADO_ROWCOUNT & " (" & ADO_ROWCOUNT_WITH_ERROR & " WITH ERROR)" & "  t= " & Format(ProlazTimeEnd - ProlazTimeStart, "###0.00000") & " sec." & vbCrLf
        
    ProlazTimeStart = Timer
    retValOk = retValOk And EXPORT_IzKaseUMaster(TableName_KASA, TableName_MASTER, , OnErrorShowMsg)
    ProlazTimeEnd = Timer
        ADO_Komentar = ADO_Komentar & "EXPORT_IzKaseUMaster.BrojSlogova = " & ADO_ROWCOUNT & " (" & ADO_ROWCOUNT_WITH_ERROR & " WITH ERROR)" & "  t= " & Format(ProlazTimeEnd - ProlazTimeStart, "###0.00000") & " sec." & vbCrLf
 
Exit_Point:
On Error Resume Next
 endTime = Timer
 Synch_KasaToMaster_Direct = retValOk
 ADO_Komentar = ADO_Komentar & Now() & " Završen upit Synch_KasaToMaster_Direct('" & TableName_KASA & "','" & TableName_MASTER & "','" & PK_FieldName1 & "','" & PK_FieldName2 & "','" & PK_FieldName3 & "')" & vbCrLf
 ADO_Komentar = ADO_Komentar & "UKUPNO VREME = " & Format(endTime - StartTime, "###0.00000") & " sec." & vbCrLf
 ADO_Komentar = ADO_Komentar & String(BrZnLn, "-") & vbCrLf
    
Exit Function
 
Err_Point:
 BBErrorMSG err, "Synch_KasaToMaster_Direct"
 retValOk = False
 Resume Exit_Point
End Function
