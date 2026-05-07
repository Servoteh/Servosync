Attribute VB_Name = "LIB_Upomoc"
Option Compare Database   'Use database order for string comparisons
Option Explicit

Function F_Pomoc()
    If CurrentUser = "Negovan" Then
      '  DoCmd.OpenForm "BB_Prog"
      DoCmd.OpenForm "CNN_List"
    Else
     Pomoc
    End If
End Function

Sub Pomoc()
 On Error GoTo Err_Pomoc

    Dim DocName As String
    Dim KljucnaRec As String

    KljucnaRec = Screen.ActiveForm.Name
    SpecPomoc (KljucnaRec)

Exit_Pomoc:
    Exit Sub

Err_Pomoc:
    MsgBox "Ne mogu vam pomoci.", , "QMegaTeh"
    Resume Exit_Pomoc

End Sub

Sub SpecPomoc(KljucnaRec As String)
    
    Dim DocName As String
    DocName = "Pomoc"
    DoCmd.OpenForm DocName

Forms![Pomoc]![Dugme Novi slog].Visible = True
Forms![Pomoc]![IDHelp].Visible = True

    Forms![Pomoc]![TraziHelp] = KljucnaRec
    DoCmd.GoToControl "IDHelp"
    DoCmd.FindRecord KljucnaRec
    If KljucnaRec <> Forms![Pomoc]![IDHelp] Then
       DoCmd.GoToRecord , , A_NEWREC
       Forms![Pomoc]![IDHelp] = KljucnaRec
       Rem MsgBox ("Pomoc nije definisana! Mozete je uneti sada.")
    End If
   
Rem Forms![Pomoc]![TraziHelp] = Null
Rem Forms![Pomoc]![Dugme Novi slog].Visible = False
Rem Forms![Pomoc]![IDHelp].Visible = False

End Sub

