VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_CFG_Global"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PrimeniUslove1V()
 Dim stSQL As String
 
    stSQL = "SELECT * FROM CFG_Global"
    'stSQL = "SELECT CFG_Global.Parametar, CFG_Global.Vrednost"
    'stSQL = stSQL & ", ParametarUKategoriji([CFG_Global].[Parametar],[Forms]![CFGReadWrite]![ZaKatPar]) AS ParUKat"
    'stSQL = stSQL & ", CFG_Apl_Parametri_DEF.Tip, CFG_Apl_Parametri_DEF.Opis"
    'stSQL = stSQL & ", CFG_Apl_Parametri_DEF.DIVUnos, Not IsNull([CFG_Apl_Parametri_DEF]![Parametar]) AS ImaDEF FROM CFG_Global LEFT JOIN CFG_Apl_Parametri_DEF ON CFG_Global.Parametar = CFG_Apl_Parametri_DEF.Parametar"

    'stSQL = stSQL & " WHERE (((CFG_Global.Parametar) Like "*" & Nz([Forms]![CFGReadWrite]![ZaParametar],"*") & "*") AND ((ParametarUKategoriji([CFG_Global].[Parametar],[Forms]![CFGReadWrite]![ZaKatPar]))=True) AND ((CStr(Nz([CFG_Global].[Vrednost],"<<NULL>>"))) Like "*" & CStr(Nz([Forms]![CFGReadWrite]![ZaVrednostParametra],"*")) & "*") AND ((CStr(Nz([CFG_Apl_Parametri_DEF].[Opis],"<<Null>>"))) Like "*" & CStr(Nz([Forms]![CFGReadWrite]![ZaOpis],"*")) & "*") AND ((ZadovoljenUslovZaBoolVal(ParametarPostojiUTabeli("CFG_Apl_Parametri_DEF",[CFG_Global]![Parametar]),[Forms]![CFGReadWrite]![ZaImaDef]))=True) AND ((ZadovoljenUslovZaBoolVal([CFG_Apl_Parametri_DEF].[GlobalPar],[Forms]![CFGReadWrite]![ZaDefGlobal]))=True)"
    'stSQL = stSQL & "AND ((ZadovoljenUslovZaBoolVal([CFG_Apl_Parametri_DEF].[LokalPar],[Forms]![CFGReadWrite]![ZaDefLokal]))=True)) ORDER BY CFG_Global.Parametar;"
    Set Me.Recordset = ADO_GetRST(LIB_CFGRW.CNN_CFG_Global, stSQL)

End Function
Public Function PrimeniUslove()
  SetProperlyRecordSource LIB_CFGRW.CNN_CFG_Global, Me
End Function
Private Sub ComboPronadjiParametar_GotFocus()
    Me!ComboPronadjiParametar.Requery
End Sub

Private Sub ComboVrednost_AfterUpdate()
    Me!Vrednost = Me!ComboVrednost
End Sub

Private Sub ComboVrednost_GotFocus()
On Error GoTo Err_Point
    Me!ComboVrednost.Requery
    Me!ComboVrednost = Me!Vrednost
    Me!ComboVrednost.LimitToList = SamoDozvoljeneVrednostiParametra(Nz(Me!Parametar, "<<Null>>"))
Exit_Point:
On Error Resume Next

Exit Sub

Err_Point:
BBErrorMSG err, "ComboVrednost_GotFocus"
Resume Exit_Point:
End Sub

Private Sub Form_Delete(Cancel As Integer)
On Error GoTo Exit_Sub:
 Dim retValOk As Boolean
 retValOk = DeleteParametar("CFG_Global", Me!Parametar, Me.Parent!ZaIDFirma)
 Cancel = retValOk

Exit_Sub:
On Error Resume Next
    PrimeniUslove
End Sub

Private Sub Form_Open(Cancel As Integer)
    PrimeniUslove
End Sub

Private Sub Form_Unload(Cancel As Integer)
    CloseConnectionOnCurrentForm Me
End Sub

Private Sub Parametar_AfterUpdate()
    Me!Vrednost = ReadParametar("CFG_Apl_Parametri_DEF", Me!Parametar)
End Sub

Private Sub Parametar_DblClick(Cancel As Integer)
    Me.Parent!ZaParametar = Me!Parametar
    PrimeniUslove
End Sub

Private Sub Vrednost_DblClick(Cancel As Integer)
    Me.Parent!ZaVrednostParametra = Left(CStr(Nz(Me!Vrednost, "<<Null>>")), 100)
    PrimeniUslove
End Sub
Private Sub ComboPronadjiParametar_AfterUpdate()
    ' Find the record that matches the control.
    Dim rs As Object

    Set rs = Me.Recordset.Clone
    If TypeOf rs Is ADODB.Recordset Then
        rs.Find "[Parametar] = '" & Me![ComboPronadjiParametar] & "'"
    Else
        rs.FindFirst "[Parametar] = '" & Me![ComboPronadjiParametar] & "'"
    End If
    
    If Not rs.EOF Then Me.Bookmark = rs.Bookmark
    Me![ComboPronadjiParametar] = Null
End Sub

Private Sub Vrednost_GotFocus()
    DoCmd.GoToControl "ComboVrednost"
End Sub
