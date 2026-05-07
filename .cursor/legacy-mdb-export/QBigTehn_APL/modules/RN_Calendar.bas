Attribute VB_Name = "RN_Calendar"
Option Compare Database   'Use database order for string comparisons
Option Explicit

Const CALENDAR_FORM = "zsfrmCalendar"

Type udDateType
    wYear As Integer
    wMonth As Integer
    wDay As Integer
End Type


Private Function isFormLoaded(strFormName As String)
    isFormLoaded = SysCmd(SYSCMD_GETOBJECTSTATE, A_FORM, strFormName)
End Function

Function PopupCalendar(ctl As control, Optional bPrimeniUslove As Boolean = True) As Variant
    '
    ' This is the public entry point.
    ' If the passed in date is Null (as it will be if someone just
    ' opens the Calendar form raw), start on the current day.
    ' Otherwise, start with the date that is passed in.
    '
    Dim frmCal As Form
    Dim varStartDate As Variant
    
    Dim aktivnaForma As Form
    Dim txtAktivnaForma As String
    Set aktivnaForma = Screen.ActiveForm

    varStartDate = IIf(IsNull(ctl.Value), Date, ctl.Value)
    DoCmd.OpenForm CALENDAR_FORM, , , , , A_DIALOG, varStartDate

    ' You won't get here until the form is closed or hidden.
    '
    ' If the form is still loaded, then get the final chosen date
    ' from the form.  If it isn't, return Null.
    '
    If isFormLoaded(CALENDAR_FORM) Then
        Set frmCal = Forms(CALENDAR_FORM)
        ctl.Value = Format(DateSerial(frmCal!Year, frmCal!Month, frmCal!Day), "dd/mm/yy")
        DoCmd.Close A_FORM, CALENDAR_FORM
        Set frmCal = Nothing

        txtAktivnaForma = aktivnaForma.Name
        If bPrimeniUslove Then
            Forms(txtAktivnaForma).PrimeniUslove
        End If
    End If
End Function
Public Function UpisiNapomenu(IDPostupka As Long, Napomena As String) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim stWhere As String
    stWhere = "IDPostupka = " & IDPostupka
    
    retValOk = ADO_UpdateColumn(CNN_CurrentDataBase, "tTehPostupak", "Napomena", "'" & Napomena & "'", stWhere)
     
Exit_Point:
 On Error Resume Next
 UpisiNapomenu = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "UpisiNapomenu"
    retValOk = False
    Resume Exit_Point
    
End Function

