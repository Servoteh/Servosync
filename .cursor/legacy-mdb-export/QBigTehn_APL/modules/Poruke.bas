Attribute VB_Name = "Poruke"
Option Compare Database
Option Explicit

Public Function NovaPoruka(usr As String) As Boolean
    NovaPoruka = Nz(DLookup("[NovihPoruka]", "Adrese", "[Ime] = '" & usr & "'"), 0) > 0
    If NovaPoruka Then
     DoCmd.Beep
     DoCmd.Beep
    End If
End Function

Public Function NapraviPorukuIzForme()
Dim Forma, IDDok
  On Error Resume Next
  
    Forma = Screen.ActiveForm.Name
    IDDok = Eval("forms![" & Screen.ActiveForm.Name & "].IDDok")
    
    BBOpenForm "P_Poruke"
    DoCmd.GoToRecord , , acNewRec
    
    'On Error Resume Next
    Forms![P_Poruke]![ImeForme] = Forma
    Forms![P_Poruke]![IDDok] = IDDok
End Function
