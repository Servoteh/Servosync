VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_zsfrmCalendar"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

' Set the first displayed day of the week.  In the
' US, this is Sunday (1).  In other countries,
' use the appropriate number (1 == Sunday, 7 == Saturday).
Const FIRST_DAY = 2

' Color to show weekend days.
Const COLOR_WEEKEND = 255

Const D_SUN = "Ne"
Const D_MON = "Po"
Const D_TUE = "Ut"
Const D_WED = "Sr"
Const D_THU = "Èe"
Const D_FRI = "Pe"
Const D_SAT = "Su"

Dim astrDays(1 To 7) As String

' The date passed in from the caller (possibly null)
Dim dtStartDate As udDateType

Dim intStartDOW As Integer

' Store away today's date.
Dim intYearToday As Integer
Dim intMonthToday As Integer
Dim intDayToday As Integer

Dim aintMonthLen(1 To 12) As Integer
Dim strSelected As String

' Constants used to control movement on the form.
' These constants match the interval values
' needed by DateAdd().
Const CHANGE_DAY = "d"
Const CHANGE_MONTH = "m"
Const CHANGE_YEAR = "yyyy"
Const CHANGE_WEEK = "ww"

Const MOVE_FORWARD = 0
Const MOVE_BACKWARD = 1

'-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
' Constant month values.
Const M_JAN = 1
Const M_FEB = 2
Const M_MAR = 3
Const M_APR = 4
Const M_MAY = 5
Const M_JUN = 6
Const M_JUL = 7
Const M_AUG = 8
Const M_SEP = 9
Const M_OCT = 10
Const M_NOV = 11
Const M_DEC = 12
'-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

' Key Codes
Const KEY_LBUTTON = &H1
Const KEY_RBUTTON = &H2
Const KEY_CANCEL = &H3
Const KEY_MBUTTON = &H4    ' NOT contiguous with L & RBUTTON
Const KEY_BACK = &H8
Const KEY_TAB = &H9
Const Key_Clear = &HC
Const KEY_RETURN = &HD
Const Key_SHIFT = &H10
Const KEY_CONTROL = &H11
Const KEY_MENU = &H12
Const KEY_PAUSE = &H13
Const KEY_CAPITAL = &H14
Const KEY_ESCAPE = &H1B
Const KEY_SPACE = &H20
Const KEY_PRIOR = &H21
Const KEY_NEXT = &H22
Const KEY_END = &H23
Const KEY_HOME = &H24
Const Key_Left = &H25
Const KEY_UP = &H26
Const Key_Right = &H27
Const KEY_DOWN = &H28
Const KEY_SELECT = &H29
Const KEY_PRINT = &H2A
Const KEY_EXECUTE = &H2B
Const KEY_SNAPSHOT = &H2C
Const KEY_INSERT = &H2D
Const KEY_DELETE = &H2E
Const KEY_HELP = &H2F

' KEY_A thru KEY_Z are the same as their ASCII equivalents: 'A' thru 'Z'
' KEY_0 thru KEY_9 are the same as their ASCII equivalents: '0' thru '9'

Const KEY_NUMPAD0 = &H60
Const KEY_NUMPAD1 = &H61
Const KEY_NUMPAD2 = &H62
Const KEY_NUMPAD3 = &H63
Const KEY_NUMPAD4 = &H64
Const KEY_NUMPAD5 = &H65
Const KEY_NUMPAD6 = &H66
Const KEY_NUMPAD7 = &H67
Const KEY_NUMPAD8 = &H68
Const KEY_NUMPAD9 = &H69
Const KEY_MULTIPLY = &H6A
Const KEY_ADD = &H6B
Const KEY_SEPARATOR = &H6C
Const KEY_SUBTRACT = &H6D
Const KEY_DECIMAL = &H6E
Const KEY_DIVIDE = &H6F
Const KEY_F1 = &H70
Const KEY_F2 = &H71
Const KEY_F3 = &H72
Const KEY_F4 = &H73
Const KEY_F5 = &H74
Const KEY_F6 = &H75
Const KEY_F7 = &H76
Const KEY_F8 = &H77
Const KEY_F9 = &H78
Const KEY_F10 = &H79
Const KEY_F11 = &H7A
Const KEY_F12 = &H7B
Const KEY_F13 = &H7C
Const KEY_F14 = &H7D
Const KEY_F15 = &H7E
Const KEY_F16 = &H7F

Const KEY_NUMLOCK = &H90

' Shift parameter masks
Const SHIFT_MASK = 1
Const CTRL_MASK = 2
Const ALT_MASK = 4

Private Function Base7(wValue As Integer)
    ' Convert a number, up to 48 decimal, into base 7.
    Base7 = (wValue \ 7) & (wValue Mod 7)
End Function

Private Sub ChangeDate(strMoveUnit As String, intDirection As Integer)
    ' Called from OnPush property of the next/previous month/year buttons.
    Dim intMonth As Integer
    Dim intYear As Integer
    Dim intDay As Integer
    Dim varDate As Variant
    Dim varOldDate As Variant
    Dim intInc As Integer
    Dim rstrInterval As String

    On Error GoTo ChangeDateError

    ' Get the current values from the form.
    intYear = Me!Year
    intMonth = Me!Month
    intDay = Me!Day

    intInc = IIf(intDirection = MOVE_FORWARD, 1, -1)
    varOldDate = DateSerial(intYear, intMonth, intDay)
    varDate = DateAdd(strMoveUnit, intInc, varOldDate)
    

    If (intDirection = MOVE_BACKWARD And varDate > varOldDate) Then
        ' This should only happen when you go backward from
        ' 1/1/100 to 12/31/1999.  Just a quirk of Access' date
        ' handling!
        Exit Sub
    End If

    intMonth = DatePart("m", varDate)
    intYear = DatePart("yyyy", varDate)
    Me!Day = DatePart("d", varDate)

    ' If the month and year haven't changed, then just
    ' move to the selected day.  It's a lot faster.
    If Me!Month = intMonth And Me!Year = intYear Then
        HandleIndent "lbl" & Day2Button((Me!Day), intStartDOW)
    Else
        ' Set the values on the form and then display the new calendar.
        Me!Month = intMonth
        Me!txtMonth = GetMonthName(intMonth)
        Me!Year = intYear
        DisplayCal
    End If

ChangeDateExit:
    Exit Sub

ChangeDateError:
    Resume ChangeDateExit
End Sub

Private Sub cmdCancel_Click()
    DoCmd.Close
End Sub

Private Sub CmdNextMonth_Click()
    ChangeDate CHANGE_MONTH, MOVE_FORWARD
End Sub

Private Sub CmdNextMonth_KeyDown(KeyCode As Integer, Shift As Integer)
    HandleKeys KeyCode, Shift
End Sub

Private Sub CmdNextYear_Click()
    ChangeDate CHANGE_YEAR, MOVE_FORWARD
End Sub

Private Sub CmdNextYear_KeyDown(KeyCode As Integer, Shift As Integer)
    HandleKeys KeyCode, Shift
End Sub

Private Sub cmdOK_Click()
    ' Just hide the calendar form.  This makes it possible for the caller
    ' to get at the date that was chosen.
    Dim var As Variant
    var = SelectDate(strSelected)
End Sub

Private Sub CmdPreviousMonth_Click()
    ChangeDate CHANGE_MONTH, MOVE_BACKWARD
End Sub

Private Sub CmdPreviousMonth_KeyDown(KeyCode As Integer, Shift As Integer)
    HandleKeys KeyCode, Shift
End Sub

Private Sub CmdPreviousYear_Click()
    ChangeDate CHANGE_YEAR, MOVE_BACKWARD
End Sub

Private Sub CmdPreviousYear_KeyDown(KeyCode As Integer, Shift As Integer)
    HandleKeys KeyCode, Shift
End Sub

Private Function Day2Button(wDay As Integer, intStartDay As Integer)
    Day2Button = Base7(wDay + intStartDay - 2 + 7) + 1
End Function

Private Function DaysInMonth(varMonthNumber As Variant) As Integer
    ' Get the number of days in the passed-in month.
    ' If the month isn't February, we know its length.
    If varMonthNumber <> M_FEB Then
        DaysInMonth = aintMonthLen(varMonthNumber)
    Else
        ' Since Access knows the leap year stuff, let's let IT do the work here!
        ' Get the last day of the month of February for the currently displayed year.
        DaysInMonth = DatePart("d", DateSerial(Me!Year, M_MAR, 1) - 1)
    End If
End Function

Private Sub DisplayCal()
    ' Actually display the calendar.
    Static wInHere As Integer

    ' Let's make sure we don't end up in here recursively!
    If wInHere Then Exit Sub
    wInHere = True

    ' Figure out the starting day of week for the given month.
    intStartDOW = FirstDOM((Me!Month), (Me!Year))

    ' Finally, really display the calendar.
    ShowDate intStartDOW
    Me.Repaint
    wInHere = False
End Sub

Private Sub FillInStartValues()

    Dim varStartDate As Variant

    If Not IsDate(Me.OpenArgs) Then
        varStartDate = Date
    Else
        varStartDate = CVDate(Me.OpenArgs)
    End If
    If IsNull(varStartDate) Or IsEmpty(varStartDate) Then
        varStartDate = Date
    End If

    ' Store away the start date values (varStartDate is global).
    Me!Month = DatePart("m", varStartDate)
    Me!Year = DatePart("yyyy", varStartDate)
    Me!Day = DatePart("d", varStartDate)
    Me!txtMonth = GetMonthName((Me!Month))

End Sub

Private Function FirstDOM(intMonth As Integer, intYear As Integer) As Integer
    ' Calculate the first day of the month in question.
    FirstDOM = DatePart("w", DateSerial(intYear, intMonth, 1), FIRST_DAY)
End Function

Private Sub FixDaysInMonth(intStartDay As Integer)
    ' Turn on and off buttons in the currently displayed month.
    Dim intRow As Integer
    Dim intCol As Integer
    Dim intNumDays As Integer
    Dim intCount As Integer
    Dim strTemp As String


    intNumDays = DaysInMonth(Me!Month)
    ' If the chosen date is past the last day in this month,
    ' then just select the last day of this month.
    If Me!Day > intNumDays Then
        Me!Day = intNumDays
    End If

    intCount = 0
    For intRow = 1 To 6
        For intCol = 1 To 7
            If (intRow = 1) And (intCol < intStartDay) Then
                Me("lbl1" & intCol).Visible = False
            Else
                intCount = intCount + 1
                strTemp = "lbl" & intRow & intCol
                If intCount <= intNumDays Then
                    Me(strTemp).Visible = True
                    Me(strTemp).Caption = intCount
                Else
                    Me(strTemp).Visible = False
                End If
            End If
        Next intCol
    Next intRow
End Sub

Private Sub FixUpDisplay()

    ' Set the labels for the days of the week correctly,
    ' and set up the colors for the weekend days.

    Dim intCol As Integer
    Dim intRow As Integer
    Dim intLogicalDay As Integer
    Dim intDiff As Integer
    Dim ctl As control

    intDiff = FIRST_DAY - 1

    For intCol = 1 To 7
        intLogicalDay = ((intCol + intDiff - 1) Mod 7) + 1
        Set ctl = Me("lblDay" & intCol)
        ctl.Caption = astrDays(intLogicalDay)
        If ((intLogicalDay - 1) Mod 6) = 0 Then
            ctl.ForeColor = COLOR_WEEKEND
            For intRow = 1 To 6
                Me("lbl" & intRow & intCol).ForeColor = COLOR_WEEKEND
            Next intRow
        End If
            
    Next intCol
End Sub

Private Sub Form_KeyDown(KeyCode As Integer, Shift As Integer)
    HandleKeys KeyCode, Shift
End Sub

Private Sub Form_Open(Cancel As Integer)

    ' Initialize the array of month lengths.
    aintMonthLen(M_JAN) = 31
    aintMonthLen(M_FEB) = 28       ' Of course, this may change!
    aintMonthLen(M_MAR) = 31
    aintMonthLen(M_APR) = 30
    aintMonthLen(M_MAY) = 31
    aintMonthLen(M_JUN) = 30
    aintMonthLen(M_JUL) = 31
    aintMonthLen(M_AUG) = 31
    aintMonthLen(M_SEP) = 30
    aintMonthLen(M_OCT) = 31
    aintMonthLen(M_NOV) = 30
    aintMonthLen(M_DEC) = 31

    astrDays(1) = D_SUN
    astrDays(2) = D_MON
    astrDays(3) = D_TUE
    astrDays(4) = D_WED
    astrDays(5) = D_THU
    astrDays(6) = D_FRI
    astrDays(7) = D_SAT

    ' Get today's date stored away, so we can get back here if necessary.
    intDayToday = DatePart("d", Date)
    intYearToday = DatePart("yyyy", Date)
    intMonthToday = DatePart("m", Date)

    ' Fill in the start values (as passed in from caller).
    FillInStartValues

    ' Fix up the calendar display.
    FixUpDisplay

    ' Display the Calendar (which gets its month/year from the form)
    DisplayCal

End Sub

Private Function GetMonthName(intMonth As Integer) As String
    ' The year in the following expression is arbitrary.
    GetMonthName = Format(DateSerial(1995, intMonth, 1), "mmmm")
End Function

Private Sub HandleIndent(strNewSelect As String)
    If Len(strSelected) > 0 Then
        If strSelected <> strNewSelect Then
            Me(strSelected).SpecialEffect = 0
        End If
    End If
    strSelected = strNewSelect
    Me(strSelected).SpecialEffect = 1
    Me!Day = Me(strSelected).Caption

End Sub

Private Sub HandleKeys(KeyCode As Integer, Shift As Integer)

    ' Key Mappings:
    '
    ' Leftarrow = Previous Day
    ' Shift-Leftarrow = Previous Year
    ' Rightarrow = Next Day
    ' Shift-Rightarrow = Next Year
    ' Uparrow = Previous week
    ' Shift-Uparrow = Previous Month
    ' Dnarrow = Next Week
    ' Shift-Dnarrow = Next Month
    ' PgUp = Previous Month
    ' Shift-PgUp = Previous Year
    ' PgDn = Next Month
    ' Shift-PgDn = Next Year
    ' Home = Move to Today
    ' Shift-Home = Move to today in selected year.

    Dim ShiftDown As Integer

    ShiftDown = ((Shift And SHIFT_MASK) > 0)

    Select Case KeyCode
        Case KEY_ESCAPE
            DoCmd.Close
        Case KEY_RETURN
            Me.Visible = False
        Case KEY_HOME
            If ShiftDown Then
                ' Use the selected year.
                MoveToToday False
            Else
                ' Use the actual current year.
                MoveToToday True
            End If
        Case KEY_PRIOR
            If ShiftDown Then
                ChangeDate CHANGE_YEAR, MOVE_BACKWARD
            Else
                ChangeDate CHANGE_MONTH, MOVE_BACKWARD
            End If
        Case KEY_NEXT
            If ShiftDown Then
                ChangeDate CHANGE_YEAR, MOVE_FORWARD
            Else
                ChangeDate CHANGE_MONTH, MOVE_FORWARD
            End If
        Case Key_Right
            If ShiftDown Then
                ' Move to next year
                ChangeDate CHANGE_YEAR, MOVE_FORWARD
            Else
                ChangeDate CHANGE_DAY, MOVE_FORWARD
            End If
        Case Key_Left
            If ShiftDown Then
                ' Move to previous year
                ChangeDate CHANGE_YEAR, MOVE_BACKWARD
            Else
                ChangeDate CHANGE_DAY, MOVE_BACKWARD
            End If
        Case KEY_UP
            If ShiftDown Then
                ' Move to previous month
                ChangeDate CHANGE_MONTH, MOVE_BACKWARD
            Else
                ChangeDate CHANGE_WEEK, MOVE_BACKWARD
            End If
        Case KEY_DOWN
            If ShiftDown Then
                ' Move to next month
                ChangeDate CHANGE_MONTH, MOVE_FORWARD
            Else
                ChangeDate CHANGE_WEEK, MOVE_FORWARD
            End If
    End Select
    ' Tell Access to disregard the key press.
    KeyCode = 0
End Sub

Private Function HandleSelected(strName As String)
    HandleIndent strName

End Function

Private Sub MoveToToday(fUseCurrentYear As Integer)
    ' Month and year get filled in from the form.

    ' Go to the stored current date.
    Me!Month = intMonthToday
    Me!txtMonth = GetMonthName((Me!Month))
    Me!Day = intDayToday
    If fUseCurrentYear Then
        Me!Year = intYearToday
    End If

    ' Actually display the calendar.
    DisplayCal
End Sub

Private Function SelectDate(strName As String)
    HandleIndent strName
    Me.Visible = False
End Function

Private Sub ShowDate(intStartDay As Integer)
    Dim newSelected As String

    ' Fix up the visible day buttons.
    FixDaysInMonth intStartDay

    ' Set the right button as depressed when the month is displayed.
    newSelected = "lbl" & Day2Button((Me!Day), intStartDay)
    HandleIndent newSelected
    DoCmd.RepaintObject
End Sub

