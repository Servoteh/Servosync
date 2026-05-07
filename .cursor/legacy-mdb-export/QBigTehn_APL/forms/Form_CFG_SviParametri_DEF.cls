VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_CFG_SviParametri_DEF"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Public Function PrimeniUslove()
 SetProperlyRecordSource "", Me
End Function

Private Sub DugmeExport_GLOBAL_Click()
Dim rst As Recordset
Dim retValOk As Boolean

    Set rst = Me.RecordsetClone
    retValOk = CFG_Global_ImportRst(rst)
    'rst.Close
    Set rst = Nothing

End Sub


Private Sub Form_Open(Cancel As Integer)
    PrimeniUslove
End Sub

Private Sub ImaGlobal_DblClick(Cancel As Integer)
 Dim retValOk As Boolean
 Dim stImeTabele As String
 
 stImeTabele = "CFG_Global"
 
 If Me!ImaGlobal Then 'BRISANJE
    retValOk = DeleteParametar(stImeTabele, Me!Parametar, Me.Parent!ZaIDFirma)
    If Not retValOk Then
      MsgBox "Parametar " & Me!Parametar & "= " & Me!Vrednost & vbCrLf & "nije obrisan u tabeli " & stImeTabele
    End If
 Else 'DODAVANJE
    retValOk = WriteParametar(stImeTabele, Me!Parametar, Me!Vrednost, Me.Parent!ZaIDFirma, Me!Opis)
    If Not retValOk Then
      MsgBox "Parametar " & Me!Parametar & "= " & Me!Vrednost & vbCrLf & "nije upisan u tabelu " & stImeTabele
    End If
 End If
 Me!ImaGlobal.Requery
End Sub

Private Sub ImaLokal_DblClick(Cancel As Integer)
 Dim retValOk As Boolean
 Dim stImeTabele As String
 
 stImeTabele = "CFG_Lokal"
 
 If Me!ImaLokal Then 'BRISANJE
    retValOk = DeleteParametar(stImeTabele, Me!Parametar, Me.Parent!ZaIDFirma)
    If Not retValOk Then
      MsgBox "Parametar " & Me!Parametar & "= " & Me!Vrednost & vbCrLf & "nije obrisan u tabeli " & stImeTabele
    End If
 Else 'DODAVANJE
    retValOk = WriteParametar(stImeTabele, Me!Parametar, Me!Vrednost, Me.Parent!ZaIDFirma, Me!Opis)
    If Not retValOk Then
      MsgBox "Parametar " & Me!Parametar & "= " & Me!Vrednost & vbCrLf & "nije upisan u tabelu " & stImeTabele
    End If
 End If
 Me!ImaLokal.Requery
End Sub

Private Sub Parametar_DblClick(Cancel As Integer)
    Me.Parent!ZaParametar = Me!Parametar
    PrimeniUslove
End Sub

Private Sub Vrednost_DblClick(Cancel As Integer)
    Me.Parent!ZaVrednostParametra = Me!Vrednost
    PrimeniUslove
End Sub
Private Sub ComboPronadjiParametar_AfterUpdate()
    ' Find the record that matches the control.
    Dim rs As Object

    Set rs = Me.Recordset.Clone
    'rs.FindFirst "[Parametar] = '" & Me![ComboPronadjiParametar] & "'"
    If TypeOf rs Is ADODB.Recordset Then
        rs.Find "[Parametar] = '" & Me![ComboPronadjiParametar] & "'"
    Else
        rs.FindFirst "[Parametar] = '" & Me![ComboPronadjiParametar] & "'"
    End If
    
    If Not rs.EOF Then Me.Bookmark = rs.Bookmark
    Me![ComboPronadjiParametar] = Null
End Sub
Private Sub DugmeExport_LOKAL_Click()
'Kreirano: 26-10-2021
On Error GoTo Err_Point

Dim rst As Recordset
Dim retValOk As Boolean

    Set rst = Me.RecordsetClone
    retValOk = CFG_Lokal_ImportRst(rst)
    'rst.Close
    Set rst = Nothing

Exit_Point:
   
Exit Sub

Err_Point:
    MsgBox err.Description
    Resume Exit_Point
    
End Sub
Private Function CFG_Global_ImportRst(rst As Recordset) As Boolean
'Kreirano: 26-10-2021
On Error GoTo Err_Point
    Dim stDocName As String
    Dim retValOk As Boolean
    
    rst.MoveFirst
    retValOk = True
    
    DoCmd.Hourglass True
    
    While (Not rst.EOF) And (retValOk = True)
        If rst!GlobalPar Then
            retValOk = LIB_CFGRW.WriteParametar("CFG_Global", rst!Parametar, rst!Vrednost, Me.Parent!ZaIDFirma, rst!Opis)
        End If
        rst.MoveNext
    Wend
    
Exit_Point:
On Error Resume Next
        DoCmd.Hourglass False
        CFG_Global_ImportRst = retValOk
        PrimeniUslove
Exit Function

Err_Point:
    retValOk = False
    BBErrorMSG err, "CFG_Global_ImportRst"
    Resume Exit_Point
    
End Function
Private Function CFG_Lokal_ImportRst(rst As Recordset) As Boolean
'Kreirano: 26-10-2021
On Error GoTo Err_Point
    Dim stDocName As String
    Dim retValOk As Boolean
    
    rst.MoveFirst
    retValOk = True
    
    DoCmd.Hourglass True
    While (Not rst.EOF) And (retValOk = True)
        If rst!LokalPar Then
            retValOk = LIB_CFGRW.WriteParametar("CFG_Lokal", rst!Parametar, rst!Vrednost, Me.Parent!ZaIDFirma, rst!Opis)
        End If
        rst.MoveNext
    Wend
        
Exit_Point:
On Error Resume Next
        DoCmd.Hourglass False
        CFG_Lokal_ImportRst = retValOk
        PrimeniUslove
Exit Function

Err_Point:
    retValOk = False
    BBErrorMSG err, "CFG_Lokal_ImportRst"
    Resume Exit_Point
    
End Function
Private Sub DugmeExport_LOKAL_Click_26102021()
'Modifikovano: 19-01-2020
On Error GoTo Err_DugmeExport_Click

    Dim stDocName As String

    DoCmd.SetWarnings False
    
    'stDocName = "CFG_APL_ExportULokal"
    stDocName = "CFG_Apl_Parametri_DEF_ExportU_CFG_Lokal"
    DoCmd.OpenQuery stDocName, acNormal, acEdit

Exit_DugmeExport_Click:
    DoCmd.SetWarnings True
    Me.Requery
    Exit Sub

Err_DugmeExport_Click:
    MsgBox err.Description
    Resume Exit_DugmeExport_Click
    
End Sub

Private Sub DugmeImport_Click()
On Error GoTo Err_DugmeImport_Click

    Dim stDocName As String
    
    DoCmd.SetWarnings False
    
    stDocName = "CFG_Global_ImportUAPL_DEF"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    stDocName = "CFG_Global_ImportUAPL_DozvoljeneVrednosti"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    stDocName = "CFG_Global_ImportUAPL"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
     
    
    stDocName = "CFG_Lokal_ImportUAPL_DEF"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    stDocName = "CFG_Lokal_ImportUAPL_DozvoljeneVrednosti"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    
    stDocName = "CFG_Lokal_ImportUAPL"
    DoCmd.OpenQuery stDocName, acNormal, acEdit

Exit_DugmeImport_Click:
    DoCmd.SetWarnings True
    Me.Requery
    Exit Sub

Err_DugmeImport_Click:
    MsgBox err.Description
    Resume Exit_DugmeImport_Click
    
End Sub



