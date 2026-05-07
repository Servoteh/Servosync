VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_CNN_SQL"
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
   
   Me!Driver = GetParFromCnnString("DRIVER=", CNNString)
   Me!Server = GetParFromCnnString("SERVER=", CNNString)
   Me!Database = GetParFromCnnString("DATABASE=", CNNString)
   Me!UID = GetParFromCnnString("UID=", CNNString)
   Me!PWD = GetParFromCnnString("PWD=", CNNString)
   'Me!Trusted_Connection = GetParFromCnnString("Trusted_Connection=", CNNString)
    stPar = GetParFromCnnString("Trusted_Connection=", CNNString)
    If stPar = "Yes" Then
      Me!Trusted_Connection = "Yes"
    Else
      Me!Trusted_Connection = "No"
    End If
   Me!APP = GetParFromCnnString("APP=", CNNString)
End Function
Private Function KreirajCNNString1V() As String
On Error GoTo Err_Point
 
 CNNString = ""
 CNNString = CNNString & IIf(CNNString = "", "", ";") & "DRIVER=" & Me!Driver
 CNNString = CNNString & IIf(CNNString = "", "", ";") & "SERVER=" & Me!Server
 If Me!Trusted_Connection = "Yes" Then
    CNNString = CNNString & IIf(CNNString = "", "", ";") & "Trusted_Connection=" & Me!Trusted_Connection
 Else
    CNNString = CNNString & IIf(CNNString = "", "", ";") & "UID=" & Me!UID
    CNNString = CNNString & IIf(CNNString = "", "", ";") & "PWD=" & Me!PWD
  
 End If
 CNNString = CNNString & IIf(CNNString = "", "", ";") & "APP=" & Me!APP
 CNNString = CNNString & IIf(CNNString = "", "", ";") & "DATABASE=" & Me!Database
 
Exit_Point:
    On Error Resume Next
    Me.Parent.Form!CNNString = CNNString
Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
End Function
Private Function KreirajCNNString() As String
On Error GoTo Err_Point
  CNNString = CreateSQL_CNNString(Me!Server, Me!Database, Me!Trusted_Connection, Me!UID, Me!PWD, Me!APP)
Exit_Point:
    On Error Resume Next
    Me.Parent.Form!CNNString = CNNString
Exit Function

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
End Function
Private Sub PostaviKomboPolja()
On Error GoTo Err_Point
Dim stSQL As String

stSQL = ""
stSQL = stSQL & " SELECT Baze_CnnString.CNNString"
stSQL = stSQL & " FROM Baze_CnnString"
stSQL = stSQL & " ORDER BY Baze_CnnString.CNNString;"

Set Me!Server.Recordset = ADO_GetRST(CNN_FIT, stSQL)

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "PostaviKomboPolja"
 Resume Exit_Point
End Sub

Private Sub Database_DblClick(Cancel As Integer)
'Kreirano: 18-06-2021
On Error GoTo Err_Point

Dim stSQL As String

    stSQL = "SELECT name FROM master.sys.databases ORDER BY name"
    Me!Database.RowSource = ADO_GetRST(CNN_CFG_Sys, stSQL).GetString(, -1, , ";")

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "Database_DblClick"
 Resume Exit_Point
End Sub

Private Sub Form_Open(Cancel As Integer)
    'PostaviKomboPolja
End Sub

Private Sub Server_DblClick(Cancel As Integer)
'Kreirano: 19-12-2021
On Error GoTo Err_Point
Dim stSQL As String
Dim rst As ADODB.Recordset
Dim stNovi

stSQL = ""
stSQL = stSQL & " SELECT r.Baza  "
stSQL = stSQL & " FROM BazeIFirme AS r"
stSQL = stSQL & " WHERE ( (r.IDBaze=4) OR (r.IDBaze=35) )"
stSQL = stSQL & " GROUP BY r.Baza"
stSQL = stSQL & " ORDER BY r.Baza;"

Set rst = ADO_GetRST(CNN_FIT, stSQL) '.GetString(, -1, , ";")
stSQL = ""

While Not rst.EOF
  stNovi = GetParFromCnnString("Server=", CNNString)
  If CStr(Nz(stNovi, "")) <> "" Then
    stSQL = stSQL & stNovi & ";"
  End If
  rst.MoveNext
Wend

    Me!Server.RowSource = stSQL

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "Database_DblClick"
 Resume Exit_Point
End Sub
