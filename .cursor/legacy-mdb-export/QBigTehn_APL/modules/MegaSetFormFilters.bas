Attribute VB_Name = "MegaSetFormFilters"
Option Compare Database
Option Explicit

' Proverava da li kontrola postoji na formi
Private Function KontrolaPostoji(frm As Access.Form, ctlName As String) As Boolean
    On Error Resume Next
    Dim tmp As String
    tmp = frm.Controls(ctlName).Name
    KontrolaPostoji = (err.Number = 0)
    err.Clear
    On Error GoTo 0
End Function

' Univerzalna procedura: uzima vrednost iz sourceCtl, upisuje je u filter kontrolu i osvežava
Public Sub PostaviFilterZaKontrolu( _
        ByVal sourceCtl As control, _
        Optional ByVal targetFilterCtlName As String = "", _
        Optional ByVal filterPrefix As String = "Za", _
        Optional ByVal useRecordSourceParam As Boolean = True, _
        Optional ByVal applyDirectFilter As Boolean = False)

    Dim frm As Access.Form
    Set frm = sourceCtl.Parent

    Dim targetName As String
    If targetFilterCtlName <> "" Then
        targetName = targetFilterCtlName
    Else
        targetName = filterPrefix & sourceCtl.Name     ' npr. ZaBrojCrteza
    End If

    If Not KontrolaPostoji(frm, targetName) Then
        MsgBox "Filter kontrola '" & targetName & "' nije pronaðena na formi " & frm.Name, vbExclamation
        Exit Sub
    End If

    Dim val As Variant
    val = sourceCtl.Value
    If IsNull(val) Or Trim$(CStr(val)) = "" Then
        MsgBox "Izvorna kontrola nema vrednost za filtriranje.", vbInformation
        Exit Sub
    End If

    ' Upis u kontrolu koja se koristi kao parametar u query-ju
    frm.Controls(targetName).Value = val

    ' Ako se forma oslanja na tu kontrolu kao parametar u RecordSource-u (npr. u kriterijumu query-ja piše
    ' [Forms]![ImeForme]![ZaBrojCrteza]), dovoljno je requery:
    If useRecordSourceParam Then
        frm.Requery
    End If

    ' Opcionalno: direktno postavi filter na polje sa istim imenom kao sourceCtl
    If applyDirectFilter Then
        Dim filt As String
        If IsNumeric(val) Then
            filt = "[" & sourceCtl.Name & "]=" & val
        Else
            filt = "[" & sourceCtl.Name & "]=" & """" & Replace(val, """", """""") & """"
        End If
        frm.Filter = filt
        frm.FilterOn = True
    End If
End Sub

Public Sub SetujFilterZaKontrolu()
    Dim pFindControlName As String
    Dim pForm As Form
    Dim pCtl As control
    
    Set pCtl = Screen.ActiveControl
    Set pForm = Screen.ActiveForm
    
    ' Konvencija: filter-kontrola se zove "Za" & srcCtl.Name
    pFindControlName = "Za" & pCtl.Name
    
    If Not KontrolaPostoji(pForm, pCtl.Name) Then
        MsgBox "Filter-kontrola '" & pFindControlName & "' nije pronaðena na formi " & pForm.Name, vbExclamation
        Exit Sub
    End If
    
    ' Upis vrednosti u filter-kontrolu
    pForm.Controls(pFindControlName).Value = pCtl.Value
    
    
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
   
   BBErrorMSG err, "NadjiArtikal"
   Resume Exit_Point
   

End Sub

