Attribute VB_Name = "BBCMD_BigBit"
Option Compare Database
Option Explicit
Private Sub MyOpenForm(ByVal FormName As String, Optional ByVal View = acNormal, Optional ByVal filterName As String = "", Optional ByVal WhereCondition As String = "", Optional ByVal DataMode = acFormPropertySettings, Optional ByVal WindowMode = acWindowNormal, Optional OpenArgs)
    DoCmd.OpenForm FormName, View, filterName, WhereCondition, DataMode, WindowMode, OpenArgs
    If F_IDNaJezik <> 0 Then
     On Error Resume Next
     PrevediFormuIliReport Forms(FormName), 0, F_IDNaJezik()
    End If
End Sub

Public Function BBOpenForm(ByVal FormName As String, Optional ByVal View = acNormal, Optional ByVal filterName As String = "", Optional ByVal WhereCondition As String = "", Optional ByVal DataMode = acFormPropertySettings, Optional ByVal WindowMode = acWindowNormal, Optional OpenArgs) As Variant
On Error GoTo Err_Point
If BBCFG.SysOpenForm = 0 Then
    OtvoriFormuZaUsera CurrentUser, FormName, View, filterName, WhereCondition, DataMode, WindowMode, OpenArgs
ElseIf BBCFG.SysOpenForm = 1 Then
    DoCmd.OpenForm FormName, View, filterName, WhereCondition, DataMode, WindowMode, OpenArgs
Else
    OtvoriFormuZaUsera CurrentUser, FormName, View, filterName, WhereCondition, DataMode, WindowMode, OpenArgs
End If
If IsLoaded(FormName) Then
  BB_CFG_TabStopPodesiFormu Forms(FormName)
End If

  '   MyOpenForm FormName, View, FilterName, WhereCondition, DataMode, WindowMode, OpenArgs
  '  Else
  '   BBMsgBox "Nemate prava", 1
  '  End If
Exit_Point:
Exit Function

Err_Point:
 BBErrorMSG err, "BBOpenForm(" & FormName & "...)"
 Resume Exit_Point
End Function
Public Function PrevediAktivanReport()
    
    'na svakom reportu OnOpen = PrevediAktivanReport()
    'MsgBox Reports(Reports.Count - 1).Name
    PrevediFormuIliReport Reports(Reports.Count - 1), 0, F_IDNaJezik()

End Function
Private Sub MyOpenReport(ByVal ReportName As String, Optional ByVal View = acViewNormal, Optional ByVal filterName As String = "", Optional ByVal WhereCondition As String = "", Optional ByVal WindowMode = acWindowNormal, Optional OpenArgs)
  On Error GoTo err_BBOpenReport
  
 If F_IDNaJezik() <> 0 Then
    DoCmd.OpenReport ReportName, acViewDesign, filterName, WhereCondition, acHidden, OpenArgs
     If Reports(ReportName).OnOpen = "" Then
        'DoCmd.BBOpenReport ReportName, acViewDesign, FilterName, WhereCondition, acHidden, OpenArgs
        'PrevediFormuIliReport Reports(ReportName), 0, F_IDNaJezik()
        Reports(ReportName).OnOpen = "=PrevediAktivanReport()"
     'ElseIf (Reports(ReportName).OnOpen <> "=PrevediAktivanReport()") And (CurrentUser = "Negovan") Then
     '       'MsgBox "Slaviša, ovaj report nije podešen za prevod!"
     End If
     DoCmd.Close acReport, ReportName, acSaveYes
 End If

exit_BBOpenReport:
    On Error Resume Next
    DoCmd.OpenReport ReportName, View, filterName, WhereCondition, WindowMode, OpenArgs
Exit Sub

err_BBOpenReport:
    If err.Number = 2601 Then 'nema prava na design
        Resume exit_BBOpenReport
    Else
        MsgBox "ErrNo: " & err.Number & vbCrLf _
                & err.Description & vbCrLf _
                & "Proces prevodjenja reporta " & ReportName _
                & " se prekida.", vbCritical, "QMegaTeh"
    End If
    Resume exit_BBOpenReport
End Sub

Public Function BBOpenReport(ByVal ReportName As String, Optional ByVal View = acViewNormal, Optional ByVal filterName As String = "", Optional ByVal WhereCondition As String = "", Optional ByVal WindowMode = acWindowNormal, Optional OpenArgs)
On Error GoTo Err_Point

 If BBCFG.SysOpenReport = 0 Then
     MyOpenReport ReportName, View, filterName, WhereCondition, WindowMode, OpenArgs
 ElseIf BBCFG.SysOpenForm = 1 Then
     DoCmd.OpenReport ReportName, View, filterName, WhereCondition, WindowMode, OpenArgs
 Else
     MyOpenReport ReportName, View, filterName, WhereCondition, WindowMode, OpenArgs
 End If
 
Exit_Point:
Exit Function

Err_Point:
 BBErrorMSG err, "BBOpenReport"
 Resume Exit_Point
End Function
