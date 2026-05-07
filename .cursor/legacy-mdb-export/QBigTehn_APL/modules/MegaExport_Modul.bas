Attribute VB_Name = "MegaExport_Modul"
Option Compare Database
Option Explicit

Public Function ExportToPDF( _
    ByVal ObjectName As String, _
    ByVal ObjectType As AcObjectType, _
    Optional ByVal FolderPath As String = "", _
    Optional ByVal FileName As String = "" _
) As Boolean

On Error GoTo Err_Point

    Dim fullPath As String
    
    If FolderPath = "" Then
        FolderPath = CurrentProject.Path
    End If
    
    If FileName = "" Then
        FileName = ObjectName & "_" & Format(Now, "yyyymmdd_hhnnss")
    End If
    
    fullPath = FolderPath & "\" & FileName & ".pdf"
    
    DoCmd.OutputTo _
        ObjectType:=ObjectType, _
        ObjectName:=ObjectName, _
        OutputFormat:=acFormatPDF, _
        OutputFile:=fullPath, _
        AutoStart:=True

    ExportToPDF = True
    Exit Function

Err_Point:
    MsgBox "Greška kod exporta u PDF: " & err.Description, vbExclamation
    ExportToPDF = False

End Function

Public Function ExportToExcel( _
    ByVal ObjectName As String, _
    ByVal ObjectType As AcObjectType, _
    Optional ByVal FolderPath As String = "", _
    Optional ByVal FileName As String = "" _
) As Boolean

On Error GoTo Err_Point

    Dim fullPath As String
    
    If FolderPath = "" Then
        FolderPath = CurrentProject.Path
    End If
    
    If FileName = "" Then
        FileName = ObjectName & "_" & Format(Now, "yyyymmdd_hhnnss")
    End If
    
    fullPath = FolderPath & "\" & FileName & ".xlsx"
    
    DoCmd.TransferSpreadsheet _
        TransferType:=acExport, _
        SpreadsheetType:=acSpreadsheetTypeExcel12Xml, _
        TableName:=ObjectName, _
        FileName:=fullPath, _
        HasFieldNames:=True

    shell "explorer.exe " & fullPath, vbNormalFocus
    
    ExportToExcel = True
    Exit Function

Err_Point:
    MsgBox "Greška kod exporta u Excel: " & err.Description, vbExclamation
    ExportToExcel = False

End Function

Public Function ExportFormToExcel_Verz2(frm As Form, Optional FileName As String = "") As Boolean

On Error GoTo Err_Point

    Dim rs As DAO.Recordset
    Dim xlApp As Object
    Dim xlWB As Object
    Dim xlWS As Object
    
    Dim i As Integer
    Dim row As Long
    Dim col As Long
    
    Dim filePath As String
    
    Set rs = frm.RecordsetClone
    
    If rs.EOF Then
        MsgBox "Nema podataka za export.", vbInformation
        Exit Function
    End If
    
    If FileName = "" Then
        FileName = frm.Name & "_" & Format(Now, "yyyymmdd_hhnnss")
    End If
    
    filePath = CurrentProject.Path & "\" & FileName & ".xlsx"
    
    Set xlApp = CreateObject("Excel.Application")
    Set xlWB = xlApp.Workbooks.Add
    Set xlWS = xlWB.Sheets(1)
    
    '========================
    ' Header (nazivi kolona)
    '========================
    
    col = 1
    
    Dim ctl As control
    
    For Each ctl In frm.Controls
    
        If ctl.ControlType = acTextBox Or ctl.ControlType = acComboBox Then
            
            If ctl.Visible = True Then
            
                If ctl.ControlSource <> "" Then
                    
                    xlWS.Cells(1, col).Value = ctl.Controls(0).Caption
                    xlWS.Cells(1, col).Font.Bold = True
                    
                    col = col + 1
                    
                End If
            
            End If
        
        End If
    
    Next ctl
    
    '========================
    ' Podaci
    '========================
    
    rs.MoveFirst
    
    row = 2
    
    Do While Not rs.EOF
    
        col = 1
        
        For Each ctl In frm.Controls
        
            If ctl.ControlType = acTextBox Or ctl.ControlType = acComboBox Then
            
                If ctl.Visible = True Then
                
                    If ctl.ControlSource <> "" Then
                    
                        xlWS.Cells(row, col).Value = rs(ctl.ControlSource)
                        col = col + 1
                    
                    End If
                
                End If
            
            End If
        
        Next ctl
        
        row = row + 1
        
        rs.MoveNext
    
    Loop
    
    '========================
    ' Formatiranje
    '========================
    
    xlWS.Rows(1).AutoFilter
    xlWS.Columns.AutoFit
    
    xlWB.SaveAs filePath
    
    xlApp.Visible = True
    
    ExportFormToExcel_Verz2 = True
    
    Exit Function

Err_Point:

    MsgBox "Greška kod exporta u Excel: " & err.Description, vbExclamation
    ExportFormToExcel_Verz2 = False

End Function
Public Function ExportFormToExcel_OLD(frm As Form) As Boolean

On Error GoTo Err_Point

    Dim rs As DAO.Recordset
    Dim xlApp As Object
    Dim xlWB As Object
    Dim xlWS As Object
    
    Dim r As Long
    Dim c As Long
    
    Set rs = frm.RecordsetClone
    
    If rs.EOF Then
        MsgBox "Nema podataka za export.", vbInformation
        Exit Function
    End If
    
    rs.MoveFirst
    
    Set xlApp = CreateObject("Excel.Application")
    Set xlWB = xlApp.Workbooks.Add
    Set xlWS = xlWB.Sheets(1)
    
    '========================
    ' Header
    '========================
    
    For c = 0 To rs.Fields.Count - 1
        xlWS.Cells(1, c + 1).Value = rs.Fields(c).Name
        xlWS.Cells(1, c + 1).Font.Bold = True
    Next c
    
    '========================
    ' Podaci
    '========================
    
    r = 2
    
    Do While Not rs.EOF
    
        For c = 0 To rs.Fields.Count - 1
            xlWS.Cells(r, c + 1).Value = rs.Fields(c).Value
        Next c
        
        r = r + 1
        
        rs.MoveNext
        
    Loop
    
    '========================
    ' Formatiranje
    '========================
    
    xlWS.Rows(1).AutoFilter
    xlWS.Columns.AutoFit
    
    xlApp.Visible = True
    
    ExportFormToExcel_OLD = True
    
    Exit Function

Err_Point:

    MsgBox "Greška kod exporta: " & err.Description
    ExportFormToExcel_OLD = False

End Function
Public Function ExportCurrentView(frm As Form) As Boolean

On Error GoTo Err_Point

    Dim targetForm As Form
    Dim ctl As control
    
    '================================================
    ' Ako forma ima podformu sa podacima – koristi nju
    '================================================
    
    For Each ctl In frm.Controls
    
        If ctl.ControlType = acSubform Then
        
            If ctl.Form.Recordset.RecordCount > 0 Then
            
                Set targetForm = ctl.Form
                Exit For
                
            End If
            
        End If
        
    Next ctl
    
    'Ako nema podforme – koristi trenutnu formu
    If targetForm Is Nothing Then
        Set targetForm = frm
    End If
    
    'Pozovi export
    ExportFormToExcel targetForm
    
    ExportCurrentView = True
    
    Exit Function

Err_Point:

    MsgBox "Greška kod exporta: " & err.Description, vbExclamation
    ExportCurrentView = False

End Function
Public Function ExportFormToPDF(frm As Form) As Boolean

On Error GoTo Err_Point

    Dim filePath As String
    
    filePath = CurrentProject.Path & "\" & _
               frm.Name & "_" & Format(Now, "yyyymmdd_hhnnss") & ".pdf"
    
    DoCmd.OutputTo _
        acOutputForm, _
        frm.Name, _
        acFormatPDF, _
        filePath, _
        True
        
    ExportFormToPDF = True
    
    Exit Function

Err_Point:

    MsgBox "Greška kod PDF exporta: " & err.Description
    ExportFormToPDF = False

End Function

Public Function ExportFormToExcel(frmLeft As Form, Optional frmRight As Form = Nothing) As Boolean

On Error GoTo Err_Point

    Dim rs As DAO.Recordset
    Dim rsRight As DAO.Recordset
    
    Dim xlApp As Object
    Dim xlWB As Object
    Dim xlWS As Object
    Dim xlWS2 As Object
    
    Dim r As Long
    Dim c As Long
    
    '========================
    ' LEVI RECORDSET
    '========================
    
    Set rs = frmLeft.RecordsetClone
    
    If rs.EOF Then
        MsgBox "Nema podataka za export.", vbInformation
        Exit Function
    End If
    
    rs.MoveFirst
    
    Set xlApp = CreateObject("Excel.Application")
    Set xlWB = xlApp.Workbooks.Add
    Set xlWS = xlWB.Sheets(1)
    
    xlWS.Name = "Nalozi"
    
    '========================
    ' HEADER LEVO
    '========================
    
    For c = 0 To rs.Fields.Count - 1
        xlWS.Cells(1, c + 1).Value = rs.Fields(c).Name
        xlWS.Cells(1, c + 1).Font.Bold = True
    Next c
    
    '========================
    ' PODACI LEVO
    '========================
    
    r = 2
    
    Do While Not rs.EOF
    
        For c = 0 To rs.Fields.Count - 1
            xlWS.Cells(r, c + 1).Value = rs.Fields(c).Value
        Next c
        
        r = r + 1
        
        rs.MoveNext
        
    Loop
    
    xlWS.Rows(1).AutoFilter
    xlWS.Columns.AutoFit
    
    '========================
    ' DESNI PRIKAZ (operacije)
    '========================
    
    If Not frmRight Is Nothing Then
    
        Set rsRight = frmRight.RecordsetClone
        
        If Not rsRight.EOF Then
        
            rsRight.MoveFirst
            
            Set xlWS2 = xlWB.Sheets.Add
            xlWS2.Name = "Operacije"
            
            ' HEADER
            For c = 0 To rsRight.Fields.Count - 1
                xlWS2.Cells(1, c + 1).Value = rsRight.Fields(c).Name
                xlWS2.Cells(1, c + 1).Font.Bold = True
            Next c
            
            ' PODACI
            r = 2
            
            Do While Not rsRight.EOF
            
                For c = 0 To rsRight.Fields.Count - 1
                    xlWS2.Cells(r, c + 1).Value = rsRight.Fields(c).Value
                Next c
                
                r = r + 1
                
                rsRight.MoveNext
                
            Loop
            
            xlWS2.Rows(1).AutoFilter
            xlWS2.Columns.AutoFit
            
        End If
        
    End If
    
    xlApp.Visible = True
    
    ExportFormToExcel = True
    
    Exit Function


Err_Point:

    MsgBox "Greška kod exporta: " & err.Description
    ExportFormToExcel = False

End Function
