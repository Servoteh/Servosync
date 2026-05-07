Attribute VB_Name = "CNN_Creator"
Option Compare Database
Option Explicit

Public Function CreateAccess_CNNString(Data_Source As String _
                                 , Optional Provider As String = "Microsoft.ACE.OLEDB.12.0" _
                                 , Optional Persist_Security_Info As String = "False" _
                                 , Optional User_ID As String = "" _
                                 , Optional Password As String = "" _
                                 , Optional MDW As String = "" _
                                 ) As String
                                 
'Provider="Microsoft.ACE.OLEDB.12.0"
'Provider="Microsoft.Jet.OLEDB.4.0"
On Error GoTo Err_Point
Dim stRetCNN As String

 stRetCNN = ""
 stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "Provider=" & Provider
 stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "Data Source=" & Data_Source
 stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "Persist Security Info=" & Persist_Security_Info
 If Nz(User_ID, "") <> "" Then
    stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "User ID=" & User_ID
 End If
 If Nz(Password, "") <> "" Then
    stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "Password=" & Password
 End If
 If Nz(MDW, "") <> "" Then
    stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "Jet OLEDB:System database=" & MDW
 End If

Exit_Point:
    On Error Resume Next
    CreateAccess_CNNString = stRetCNN
Exit Function

Err_Point:
    BBErrorMSG err, "CreateAccess_CNNString"
    Resume Exit_Point
End Function
Public Function CreateSQL_CNNString(Server As String _
                                    , Database As String _
                                    , Optional Trusted_Connection As String = "Yes" _
                                    , Optional UID As String = "" _
                                    , Optional PWD As String = "" _
                                    , Optional APP As String = "QBigBit" _
                                    , Optional Driver As String = "SQL Server" _
                                    ) As String
On Error GoTo Err_Point
 Dim stRetCNN As String
 
 stRetCNN = ""
 stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "DRIVER=" & Driver
 stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "SERVER=" & Server
 If Trusted_Connection = "Yes" Then
    stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "Trusted_Connection=" & Trusted_Connection
 Else
    stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "UID=" & UID
    stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "PWD=" & PWD
  
 End If
 stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "APP=" & APP
 stRetCNN = stRetCNN & IIf(stRetCNN = "", "", ";") & "DATABASE=" & Database
 
Exit_Point:
On Error Resume Next
    CreateSQL_CNNString = stRetCNN
Exit Function

Err_Point:
    BBErrorMSG err, "CreateSQL_CNNString"
    Resume Exit_Point
End Function
Public Function CnnStringBezPWD(pCNNString As String) As String
'Modifikovano: 27-12-2021
On Error GoTo Err_Point

 Dim stRetVal As String
 Dim stArray() As String
 Dim lb As Integer
 Dim ub As Integer
 Dim i As Integer
 
 stRetVal = ""
 'stArray = CnnStringAsArray() 'Split(pCNNString, ";")()
 stArray = Split(pCNNString, ";") 'Dodeljivanje jednog niza drugom; Assign One Array to Another Array
 lb = LBound(stArray) 'LBound(Split(pCNNString, ";"))
 ub = UBound(stArray) 'UBound(Split(pCNNString, ";"))
 For i = lb To ub
  ' If Not (Split(pCNNString, ";")(i) Like "UID*") And Not (Split(pCNNString, ";")(i) Like "PWD*") Then
   If Not (stArray(i) Like "UID*") _
        And Not (stArray(i) Like "PWD*") _
        And Not (stArray(i) Like "PASSWORD*") Then
   'stRetVal = stRetVal & Split(pCNNString, ";")(i) & ";"
   stRetVal = stRetVal & stArray(i) & ";"
   End If
 Next i

Exit_Point:
On Error Resume Next
 CnnStringBezPWD = stRetVal
Exit Function
Err_Point:
 stRetVal = "error"
 Resume Exit_Point

End Function
