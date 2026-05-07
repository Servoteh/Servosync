VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBExtra"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub CheckAllowBayPassKey_AfterUpdate()

   ' Vidi modul StartUp-proceduru: SetStartupProperties
   ' Pazljivo!
   If Not ChangeProperty("AllowBypassKey", dbBoolean, CheckAllowBayPassKey) Then
    MsgBox "Vrednost nije promenjena."
   Else
    'MsgBox "Vazi samo jedno startovanje!"
   End If
End Sub

Private Sub ComboSveAktivneForme_AfterUpdate()
On Error Resume Next
   Me!UpitNaFormi = Forms(Me!ComboSveAktivneForme).RecordSource
End Sub

Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub

Private Function SetValueList() As String
    Dim strValList As String
    Dim i As Integer
    
    For i = 0 To CurrentDb.Properties.Count - 1
     strValList = strValList & CurrentDb.Properties(i).Name & ";"
    Next i
    strValList = Left$(strValList, Len(strValList) - 1)
    SetValueList = strValList
End Function

Private Sub Form_Open(Cancel As Integer)
    Me!ComboSveTabeleIzBaze.RowSource = SveTabeleIzBaze()
    Me!ComboSviUpiti.RowSource = SviUpitiIzBaze()
    Me!ComboSveAktivneForme.RowSource = SveAktivneFome()
    
    Me![ComboStartUpPar].RowSource = SetValueList()
    If CurrentUser = "Negovan" Then
        Me![CheckAllowBayPassKey].Locked = False
    End If
    Me!MDW = Application.DBEngine.Properties("SystemDB")
    Me!APL = CurrentDb.Name
End Sub
Private Function SveTabeleIzBaze() As String
On Error GoTo ErrorFunc

Dim StatusOK As Boolean
Dim retVal As String
Dim tdf
   
    For Each tdf In CurrentDb.TableDefs
            retVal = retVal & tdf.Name & ";"
            ' Debug.Print tdf.Name
    Next tdf
exit_Func:
    SveTabeleIzBaze = retVal
Exit Function
ErrorFunc:
    MsgBox err.Description
    Resume exit_Func
End Function
Private Function SviUpitiIzBaze() As String
On Error GoTo ErrorFunc

Dim obj As AccessObject, dbs As Object
Dim retVal As String
Dim Rbr As Long
retVal = ""
    Set dbs = Application.CurrentData
    ' Search for open AccessObject objects in AllQueries collection.
    Rbr = 0
    For Each obj In dbs.AllQueries
        'If obj.IsLoaded = True Then
            ' Print name of obj.
            'Debug.Print obj.Name
            Rbr = Rbr + 1
            'Debug.Print Rbr
            If Rbr < 1000 Then
            retVal = retVal & obj.Name & ";"
                   ' If obj.Type <> acQuery Then
                   '      MsgBox obj.Name
                   ' End If
            End If
        'End If
    Next obj

exit_Func:
    SviUpitiIzBaze = retVal
Exit Function
ErrorFunc:
    MsgBox err.Description
    Resume exit_Func
End Function
Private Sub DugmeExport_Click()
On Error GoTo Err_DugmeExport_Click

    Dim stDocName As String
    Dim ImeFajla As String

    stDocName = Me!ComboSveTabeleIzBaze
    ImeFajla = SaveAsFile(stDocName & ".txt")
    
    If ImeFajla <> "" Then
     DoCmd.TransferText acExportDelim, , stDocName, ImeFajla, True
    End If

Exit_DugmeExport_Click:
    Exit Sub

Err_DugmeExport_Click:
    MsgBox err.Description
    Resume Exit_DugmeExport_Click
    
End Sub
Private Sub DugmeExportXLS_Click()
On Error GoTo Err_DugmeExport_Click

    Dim stDocName As String
    Dim ImeFajla As String

    stDocName = Me!ComboSveTabeleIzBaze
    ImeFajla = SaveAsFile(stDocName & ".xls")
    
    If ImeFajla <> "" Then
    DoCmd.TransferSpreadsheet acExport, , stDocName, ImeFajla, True
    End If
    
Exit_DugmeExport_Click:
    Exit Sub

Err_DugmeExport_Click:
    MsgBox err.Description
    Resume Exit_DugmeExport_Click
    
End Sub
Private Sub DugmePregledaj_Click()
On Error GoTo Err_DugmePregledaj_Click

    Dim stDocName As String

    stDocName = Me!ComboSveTabeleIzBaze
    DoCmd.OpenTable stDocName, acViewNormal, acReadOnly

Exit_DugmePregledaj_Click:
    Exit Sub

Err_DugmePregledaj_Click:
    MsgBox err.Description
    Resume Exit_DugmePregledaj_Click
    
End Sub


Private Sub DugmePogledajUpit_Click()
On Error GoTo Err_DugmePogledajUpit_Click

    Dim stDocName As String

    stDocName = Me!ComboSviUpiti
    DoCmd.OpenQuery stDocName, , acReadOnly

Exit_DugmePogledajUpit_Click:
    Exit Sub

Err_DugmePogledajUpit_Click:
    MsgBox err.Description
    Resume Exit_DugmePogledajUpit_Click
    
End Sub
Private Function SveAktivneFome() As String
    Dim retVal As String
    Dim obj As AccessObject, dbs As Object
    retVal = ""
    
    Set dbs = Application.CurrentProject
    ' Search for open AccessObject objects in AllForms collection.
    For Each obj In dbs.AllForms
        If obj.IsLoaded = True Then
            ' Print name of obj.
            'Debug.Print obj.Name
            ' retval = retval & obj.Name & obj.Properties("ControlSource") & ";"
            retVal = retVal & obj.Name & ";"
        End If
    Next obj
  SveAktivneFome = retVal
End Function

