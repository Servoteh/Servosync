VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_CFG_Lokal"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PrimeniUslove1V()
On Error GoTo Err_Point
 Dim stSQL As String
 Dim stCNNString As String
 
 'stSQL = "SELECT * FROM CFG_Lokal"
 
stSQL = "SELECT CFG_Lokal.*"
'stSQL = stSQL & ", ParametarUKategoriji([CFG_Lokal].[Parametar],[Forms]![CFGReadWrite]![ZaKatPar]) AS ParUKat"
'stSQL = stSQL & ", CFG_Apl_Parametri_DEF.Tip, CFG_Apl_Parametri_DEF.Opis, CFG_Apl_Parametri_DEF.DIVUnos"
'stSQL = stSQL & ", Not IsNull([CFG_Apl_Parametri_DEF].[Parametar]) AS ImaDEF "
stSQL = stSQL & " FROM CFG_Lokal"
'stSQL = stSQL & " LEFT JOIN CFG_Apl_Parametri_DEF ON CFG_Lokal.Parametar = CFG_Apl_Parametri_DEF.Parametar"
stSQL = stSQL & " WHERE (CFG_Lokal.Parametar Like '" & "%" & Nz([Forms]![CFGReadWrite]![ZaParametar], "%") & "%" & "')"
'stSQL = stSQL & " AND ((ParametarUKategoriji([CFG_Lokal].[Parametar],[Forms]![CFGReadWrite]![ZaKatPar]))=True)"
'stSQL = stSQL & " AND ((CStr(Nz([CFG_Lokal].[Vrednost],"<<NULL>>"))) Like "*" & CStr(Nz([Forms]![CFGReadWrite]![ZaVrednostParametra],"*")) & "*")"
'stSQL = stSQL & " AND ((CStr(Nz([CFG_Apl_Parametri_DEF].[Opis],"<<Null>>"))) Like "*" & CStr(Nz([Forms]![CFGReadWrite]![ZaOpis],"*")) & "*")"
'stSQL = stSQL & " AND ((ZadovoljenUslovZaBoolVal(ParametarPostojiUTabeli("CFG_Apl_Parametri_DEF",[CFG_Lokal]![Parametar]),[Forms]![CFGReadWrite]![ZaImaDef]))=True)"
'stSQL = stSQL & " AND ((ZadovoljenUslovZaBoolVal([CFG_Apl_Parametri_DEF].[GlobalPar],[Forms]![CFGReadWrite]![ZaDefGlobal]))=True)"
'stSQL = stSQL & " AND ((ZadovoljenUslovZaBoolVal([CFG_Apl_Parametri_DEF].[LokalPar],[Forms]![CFGReadWrite]![ZaDefLokal]))=True))"
stSQL = stSQL & " ORDER BY CFG_Lokal.Parametar;"
 
 'stCNNString = "Provider=Microsoft.Jet.OLEDB.4.0;Data Source=C:\SHARES\AcBaze\QBigBit\BB_CFG_Lokal.mdb;Persist Security Info=False"
 'Set Me.Recordset = ADO_GetRST(stCNNString, stSQL)
 
 Set Me.Recordset = ADO_GetRST(LIB_CFGRW.CNN_CFG_Lokal, stSQL)
 
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, ""
 Resume Exit_Point
End Function
Public Function PrimeniUslove()

 'SetProperlyRecordSource CNN_CFG_Lokal, Me
 Me.Requery
End Function
Private Sub ComboPronadjiParametar_GotFocus()
    Me!ComboPronadjiParametar.Requery
End Sub

Private Sub ComboVrednost_AfterUpdate()
    Me!Vrednost = Me!ComboVrednost
End Sub

Private Sub ComboVrednost_GotFocus()
On Error Resume Next
    Me!ComboVrednost.Requery
    Me!ComboVrednost = Me!Vrednost
    Me!ComboVrednost.LimitToList = SamoDozvoljeneVrednostiParametra(Nz(Me!Parametar, ""))
End Sub

Private Sub Form_Delete(Cancel As Integer)
On Error GoTo Exit_Sub:
 Dim retValOk As Boolean
 
 retValOk = DeleteParametar("CFG_Lokal", Me!Parametar, Me.Parent!ZaIDFirma)
 Cancel = retValOk
 'PrimeniUslove
 
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
