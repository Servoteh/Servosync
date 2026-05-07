VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_CNN_Access"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Public CNNString As String

Public Function RasclaniCNNString()
  Dim stPar As String
   
   CNNString = Nz(Me.Parent.Form!CNNString, "")
   
   Me!Provider = GetParFromCnnString("Provider=", CNNString)
   Me!Data_Source = GetParFromCnnString("Data Source=", CNNString)
   Me!Persist_Security_Info = GetParFromCnnString("Persist Security Info=", CNNString)
   Me!User_ID = GetParFromCnnString("User ID=", CNNString)
   Me!Password = GetParFromCnnString("Password=", CNNString)
    stPar = GetParFromCnnString("Persist Security Info=", CNNString)
    If stPar = "True" Then
      Me!Persist_Security_Info = "True"
    Else
      Me!Persist_Security_Info = "False"
    End If
   Me!MDW = GetParFromCnnString("Jet OLEDB:System database=", CNNString)
End Function
Private Function KreirajCNNString1V()
On Error GoTo Err_Point

 CNNString = ""
 CNNString = CNNString & IIf(CNNString = "", "", ";") & "Provider=" & Me!Provider
 CNNString = CNNString & IIf(CNNString = "", "", ";") & "Data Source=" & Me!Data_Source
 CNNString = CNNString & IIf(CNNString = "", "", ";") & "Persist Security Info=" & Me!Persist_Security_Info
 If Nz(Me!User_ID, "") <> "" Then
    CNNString = CNNString & IIf(CNNString = "", "", ";") & "User ID=" & Me!User_ID
 End If
 If Nz(Me!Password, "") <> "" Then
    CNNString = CNNString & IIf(CNNString = "", "", ";") & "Password=" & Me!Password
 End If
 If Nz(Me!MDW, "") <> "" Then
    CNNString = CNNString & IIf(CNNString = "", "", ";") & "Jet OLEDB:System database=" & Me!MDW
 End If

Exit_Point:
    On Error Resume Next
    Me.Parent.Form!CNNString = CNNString
Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
End Function
Private Sub Data_Source_DblClick(Cancel As Integer)
    Dim stRetVal As String
    stRetVal = OpenFile()
    If stRetVal <> "" Then
      Me!Data_Source = stRetVal
      KreirajCNNString
    End If
End Sub
Private Sub MDW_DblClick(Cancel As Integer)
Dim stRetVal As String
    stRetVal = OpenFile()
    If stRetVal <> "" Then
      Me!MDW = stRetVal
      KreirajCNNString
    End If
End Sub
Private Function KreirajCNNString()
On Error GoTo Err_Point

 CNNString = CreateAccess_CNNString(Me!Data_Source, Me!Provider, Me!Persist_Security_Info, Me!User_ID, Me!Password, Me!MDW)

Exit_Point:
    On Error Resume Next
    Me.Parent.Form!CNNString = CNNString
Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
End Function
