Attribute VB_Name = "PRNModul"
Option Compare Database
Option Explicit

'---------------------START-----------------------------------------
' Author: Jose Hernandez

Type PrtDevNameStr 'See PrtDevNames property in Help
RGB As String * 104
End Type

Type PrtDevModeStr 'See PrtDevMode property in Help
RGB As String * 68
End Type

Type udtAccPrinterDEV 'Printer info from Reports
Source As String
DevName As PrtDevNameStr
DevMode As PrtDevModeStr
End Type

Private Function GetPrinterInfoEX(ByVal strSrc As String) As udtAccPrinterDEV
On Error GoTo Proc_Error
'PURPOSE: Get DevNames & DevMode for access report
'strSrc = name of report with the printer settings.
BBOpenReport strSrc, acDesign, , , acHidden 'Open color settings report
With GetPrinterInfoEX
.DevName.RGB = Reports(strSrc).PrtDevNames 'Get DevNames Structure
.DevMode.RGB = Reports(strSrc).PrtDevMode 'Get DevNames Structure
.Source = strSrc
End With
DoCmd.Close acReport, strSrc, acSaveNo
Proc_Exit:
If IsReportLoaded(strSrc) = True Then DoCmd.Close acReport, strSrc, acSaveNo
Exit Function
Proc_Error:
MsgBox err.Description
Resume Proc_Exit
End Function

Function IsReportLoaded(ByVal strReport As String) As Integer
' Returns True if the specified report is loaded.
IsReportLoaded = CBool(SysCmd(acSysCmdGetObjectState, acReport, strReport) <> 0)
End Function

Function Print2AnyPrinter(strReport As String, strFilter As String, strPrinterSettings As String) As Long
On Error GoTo Proc_Error
'Returns: 0 = Success!
'strReport = Report you want to print
'strFilter = Your Filter If you do not have one then pass "" as the value
'strPrinterSettings = The Report that has the printer settings! (Create a new report and Set its Default Printer.)
'ISSUES: The reports MUST be opened in Design View on order to set thePrtDevNames!

Dim udtPrinterDEV As udtAccPrinterDEV
Dim lngRetval As Long

udtPrinterDEV = GetPrinterInfoEX(strPrinterSettings)

BBOpenReport strReport, acViewDesign, , , acHidden
Reports(strReport).PrtDevNames = udtPrinterDEV.DevName.RGB
If Len(strFilter & "") > 0 Then
Reports(strReport).FilterOn = True
Reports(strReport).Filter = strFilter
End If
BBOpenReport strReport, acViewPreview
DoCmd.PrintOut acPrintAll 'Print Report
Proc_Exit:
If IsReportLoaded(strReport) = True Then DoCmd.Close acReport, strReport, acSaveNo
Exit Function
Proc_Error:
MsgBox err.Description
Print2AnyPrinter = err.Number
Resume Proc_Exit
End Function
'-------------------------------END-------------------------------------

Public Sub PostaviPrinterZaReport(ImeReporta As String)
' PRN+ImeReporta je ime parametra (ako je zadat) u CFG_Lokal fajlu
' PRNDefault je default printer u sistemu
' koji nosi ime realnog printera!
Dim StvarnoImePrinteraZaReport As Variant
Dim errPoruka As String
    
    StvarnoImePrinteraZaReport = ReadParametar("CFG_Lokal", "PRN" & ImeReporta)
    
    If IsNull(StvarnoImePrinteraZaReport) Then
        'parametar [PRNimereporta] nije zadat
        'errPoruka = "CFG_Lokal parametar [" & "PRN" & ImeReporta & "] nije definisan."
        'MsgBox errPoruka, vbInformation, "BBKafe"
    Else
     On Error Resume Next
     Set Application.Printer = Application.Printers(StvarnoImePrinteraZaReport)
     If err Then
         errPoruka = "Printer [" & StvarnoImePrinteraZaReport & "] ne postoji ili nije dostupan!"
         errPoruka = errPoruka & vbCrLf & "Podesite u CFG_Lokal fajlu ime printera za [" & "PRN" & ImeReporta & "]"
         errPoruka = errPoruka & vbCrLf & "ili obrisite parametar ako zelite da koristite default printer."
         MsgBox errPoruka, vbCritical, "BBKafe"
         'Cancel = True
     End If
    End If
End Sub
Public Sub TestProcitajSvePrintere()
Dim i As Integer, j As Integer
For i = 0 To Application.Printers.Count - 1
    Debug.Print Application.Printers(i).DeviceName
    Debug.Print , "DriverName = "; Application.Printers(i).DriverName
    Debug.Print , "RightMargin = "; Application.Printers(i).RightMargin
    Debug.Print , "Port = "; Application.Printers(i).Port
    
Next i
End Sub
Public Function ListaPrintera(ByRef ukprintera As Integer) As Variant
    Dim retArray() As String
    Dim i As Integer
     
    ukprintera = Application.Printers.Count
    ReDim retArray(ukprintera - 1)
    For i = 0 To ukprintera - 1
     retArray(i) = Application.Printers(i).DeviceName
    Next i
    
    'For i = 0 To Application.Printers.Count - 1
    '     Debug.Print retArray(i)
    'Next i
    
    ListaPrintera = retArray
End Function

Public Function PostojiPrinter(prnName As String) As Boolean
On Error GoTo err_PostojiPrinter
    Dim retVal As Boolean
    retVal = False
    retVal = (Application.Printers(prnName).DeviceName = prnName)
exit_PostojiPrinter:
    PostojiPrinter = retVal
Exit Function
err_PostojiPrinter:
    retVal = False
    Resume exit_PostojiPrinter
End Function

Public Sub PrintujReportNaPrinter(rptName As String, prnName As String)
'CutePDF Writer
On Error GoTo Err_DugmePraviTest_Click
    Dim retVal As Long

    If prnName = "Default" Or prnName = "DefaultReport" Then
        BBOpenReport rptName, acViewNormal
    Else
        retVal = Print2AnyPrinter(rptName, "", prnName)
    End If
Exit_DugmePraviTest_Click:

    Exit Sub

Err_DugmePraviTest_Click:
    MsgBox "ErrNo: " & err.Number & vbCrLf & err.Description
    Resume Exit_DugmePraviTest_Click
    
End Sub
Function IzaberiPrinter() As String
    Dim Poruka As String
    Dim i As Integer
    Dim ukprintera As Integer
    Dim IzabranPrinter As String
    Dim BrojIzabranogPrintera As Integer
    Dim OK As Boolean
    Dim BrojDefaultPrintera
     
  
    ukprintera = Application.Printers.Count
    
    For i = 0 To ukprintera - 1
     Poruka = Poruka & vbCrLf & CStr(i) & "  -  " & Application.Printers(i).DeviceName
     If Application.Printers(i).DeviceName = Application.Printer.DeviceName Then
        BrojDefaultPrintera = i
     End If
    Next i
    
    Do
    OK = True
    IzabranPrinter = InputBox(Poruka, "Izaberite printer", BrojDefaultPrintera)
    On Error Resume Next
    If IzabranPrinter = "" Then 'Nije izabrano nista tj.Cancel
    Else
        BrojIzabranogPrintera = CInt(IzabranPrinter)
        If BrojIzabranogPrintera >= 0 And BrojIzabranogPrintera < Application.Printers.Count Then
            IzabranPrinter = Application.Printers(BrojIzabranogPrintera).DeviceName
        Else
            MsgBox "Neispravan izbor!", vbCritical, "BBKafe"
            OK = False
        End If
    End If
    Loop While Not OK
    IzaberiPrinter = IzabranPrinter
End Function
Public Function ReadCFGImePrinteraZaReport(ImeReporta As String) As String
Dim StvarnoImePrinteraZaReport
Dim odgovor
Dim Poruka As String
    StvarnoImePrinteraZaReport = ReadParametar("CFG_Lokal", "PRN" & ImeReporta)
    If IsNull(StvarnoImePrinteraZaReport) Then
        Poruka = "Printer za report [PRN" & ImeReporta & "] nije definisan."
        Poruka = Poruka & vbCrLf & "Da li želite da definišete printer za ovaj report?"
        odgovor = MsgBox(Poruka, vbExclamation + vbYesNo, "BBKafe")
        If odgovor = vbYes Then
            StvarnoImePrinteraZaReport = IzaberiPrinter()
            If Nz(StvarnoImePrinteraZaReport, "") <> "" Then
                Call WriteParametar("CFG_Lokal", "PRN" & ImeReporta, StvarnoImePrinteraZaReport)
            Else
                StvarnoImePrinteraZaReport = "Default"
            End If
        End If
    End If
    ReadCFGImePrinteraZaReport = Nz(StvarnoImePrinteraZaReport, "")
End Function
Public Sub DrawBoxArroundControl(ByRef ctl As control, Optional newHeight, Optional lngColor = 0, Optional LineWidth = 1)
    Dim RPT As Report
    Dim sngTop As Single, sngLeft As Single
    Dim sngWidth As Single, sngHeight As Single

    Set RPT = ctl.Parent ' Me
    RPT.DrawWidth = LineWidth
    sngTop = RPT.ScaleTop + ctl.Left
    
    ' Left inside edge.
    sngLeft = RPT.ScaleLeft
    'sngLeft = Me!Opis.Left
    
    ' Width inside edge.
    'sngWidth = rpt.ScaleWidth
    'sngWidth = rpt.Width
    sngWidth = ctl.Left + ctl.Width '+ Me!PDVOznaka.Width
    ' Height inside edge.
    'sngHeight = rpt.ScaleHeight
    'sngHeight = rpt.Height
    If IsMissing(newHeight) Then
      sngHeight = RPT.height 'visina ista kao visina detail sekcije
     ' sngHeight = rpt.Section(acDetail).Height 'ovo nije dobro
    Else
       sngHeight = newHeight
    End If
   
    ' Make color red.
    'lngColor = RGB(255, 0, 0)
    
    ' Draw line as a box.
    RPT.Line (sngTop, sngLeft)-(sngWidth, sngHeight), lngColor, B

End Sub

Public Function DrawBoxArroundAllDetailControls(ByRef rptReport As Report, Optional LineWidth As Integer = 1, Optional stSectionName, Optional ExceptControlType As Byte = acCheckBox, Optional ExceptVisibleNo As Boolean = True) As Boolean

'Modifikovano: 17-11-2022
'Optional ExceptControlType

'Modifikovano: 01-03-2022
'Optional stSectionName As String

'Modifikovano: 20-09-2023
'Optional ExceptVisibleNo As Boolean = False

On Error GoTo Err_Point
 Dim retValOk As Boolean
 Dim ctl As control
 
 retValOk = True
 
 'For Each ctl In rptReport.Section(acDetail).Controls
 If IsMissing(stSectionName) Then
    stSectionName = rptReport.Section(acDetail).Name
 End If
 
 For Each ctl In rptReport.Section(stSectionName).Controls
      If ctl.Properties("ControlType") = acObjectFrame Then
        ' Ne treba bordura  'MsgBox "Uso!"
      ElseIf ctl.Properties("ControlType") = ExceptControlType Then
        ' Ne treba bordura
      ElseIf Not ctl.Properties("Visible") = ExceptVisibleNo Then
        ' Ne treba bordura
      Else
       DrawBoxArroundControl ctl, , , LineWidth
      End If
 Next
  
Exit_Point:
  DrawBoxArroundAllDetailControls = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "DrawBoxArroundAllDetailControls"
 retValOk = False
 Resume Exit_Point
End Function
Public Function SetFontSizeAllDetailControls(ByRef rptReport As Report, Optional FontSize) As Boolean
On Error GoTo Err_Point
 Dim retValOk As Boolean
 Dim ctl As control
 
 If IsMissing(FontSize) Then
  retValOk = True
  GoTo Exit_Point
 End If
 
 For Each ctl In rptReport.Section(acDetail).Controls
  If ctl.Properties("ControlType") = acLabel Or ctl.Properties("ControlType") = acTextBox Then
      If ctl.tag <> "FixFont" Then
       ctl.FontSize = FontSize
      End If
    '  Me.[Naziv artikla].FontSize = 10
  End If
 Next
  
Exit_Point:
  SetFontSizeAllDetailControls = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "SetFontSizeAllDetailControls"
 retValOk = False
 Resume Exit_Point
End Function
Public Function PodesiPrikazReporta(ByRef rptReport As Report, stReportName As String, stSpecName As String) As Boolean ', stSectionName As String) As Boolean
'Poziva se na OnOpen reporta
'Kreirano: 09-01-2023
'Modifikovano: 10-01-2023

On Error GoTo Err_Point
 Dim retValOk As Boolean
 Dim stSQL As String
 
 Dim ctl As control
 Dim rst As New ADODB.Recordset
 
 retValOk = True
 stSQL = ""
 stSQL = stSQL & " SELECT ControlName, Visible, ControlSource, SectionName" & vbCrLf
 stSQL = stSQL & " FROM ReportSPEC " & vbCrLf
 stSQL = stSQL & " WHERE     (Report = '" & stReportName & "')" & vbCrLf
 stSQL = stSQL & "       AND (SpecName = '" & stSpecName & "')" & vbCrLf
 'stSQL = stSQL & "       AND (SectionName = '" & stSectionName & "')" & vbCrLf
 
 'For Each ctl In rptReport.Section(acDetail).Controls
 'If IsMissing(stSectionName) Then
 '   stSectionName = rptReport.Section(acDetail).Name
 'End If
 
 Set rst = ADO_GetRST(CNN_CurrentDataBase, stSQL, dbOptimistic, adUseClient, adOpenStatic)
 
 'If rst.EOF And rst.BOF Then
 '   GoTo exit_Point
 'End If
 
 While Not rst.EOF
    For Each ctl In rptReport.Section(rst!SectionName).Controls
         If ctl.Name = rst!ControlName Then
            ctl.Visible = rst!Visible
            If (ctl.ControlType = acTextBox) And Nz(rst!ControlSource, "") <> "" Then
                ctl.ControlSource = rst!ControlSource
            End If
            If (ctl.ControlType = acLabel) And Nz(rst!ControlSource, "") <> "" Then
                ctl.Caption = rst!ControlSource
            End If
            Exit For
         End If
    Next ctl
  rst.MoveNext
 Wend
  
Exit_Point:
  On Error Resume Next
  rst.Close
  Set rst = Nothing
  
  PodesiPrikazReporta = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "PodesiPrikazReporta"
 retValOk = False
 Resume Exit_Point
End Function
