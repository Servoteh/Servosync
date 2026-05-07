VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PS_TabeleZaImportIzPG"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Const imeTMPupita = "~ppsTmp~"

Private Function PrimeniUslove()
 Me.Requery
End Function

Private Function BrojSlogovaUTabeli(stTableName As String) As Long
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim retValNumber As Long

retValNumber = DCount("*", stTableName)

Exit_Point:
 On Error Resume Next
       BrojSlogovaUTabeli = retValNumber
Exit Function

Err_Point:
 BBErrorMSG err, "BrojSlogovaUTabeli"
 retValOk = False
 Resume Exit_Point
End Function
Private Function F_PrikaziBrojSlogova() As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim stMsgBox As String
   
   Me!BrojSlogovaIzTabele = F_BrojSlogovaUTabeli(Me!ImeIzTabele)
   Me!BrojSlogovaUTabelu = F_BrojSlogovaUTabeli(Me!ImeUTabelu)
   
 If False Then 'Optional checkMsg As Boolean = False
    stMsgBox = stMsgBox & "CountOf" & Me!ImeIzTabele & " = " & Me!BrojSlogovaIzTabele & vbCrLf
    stMsgBox = stMsgBox & "CountOf" & Me!ImeUTabelu & " = " & Me!BrojSlogovaUTabelu & vbCrLf
    MsgBox stMsgBox, vbInformation, "QMegaTeh"
 End If


Exit_Point:
 On Error Resume Next
       F_PrikaziBrojSlogova = retValOk
       DoCmd.RunCommand acCmdSaveRecord
Exit Function

Err_Point:
 BBErrorMSG err, "F_PrikaziBrojSlogova"
 retValOk = False
 Resume Exit_Point
End Function

Private Sub DugmeGetSQL_SELECT_Click()
    Me!SQL_SELECT_IzTabele = CurrentDb.QueryDefs(imeTMPupita).sql
End Sub

Private Sub DugmeInvertUradi_Click()
On Error GoTo Err_DugmeInvertUradi_Click

    Dim stDocName As String
    DoCmd.SetWarnings False
    stDocName = "PS_TabeleZaImport_InvertUradi"
    DoCmd.OpenQuery stDocName, acNormal, acEdit
    DoCmd.SetWarnings True
    PrimeniUslove
Exit_DugmeInvertUradi_Click:
    DoCmd.SetWarnings True
    Exit Sub

Err_DugmeInvertUradi_Click:
    MsgBox err.Description
    Resume Exit_DugmeInvertUradi_Click
    
End Sub
Private Sub PogledajTabelu(TblName As String)
On Error GoTo Err_PogledajTabelu

    
    DoCmd.OpenTable TblName, acNormal, acEdit

Exit_PogledajTabelu:
    Exit Sub

Err_PogledajTabelu:
    MsgBox err.Description
    Resume Exit_PogledajTabelu
    
End Sub

Private Function F_PreracunajBrojSlogova() As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim rst As Recordset

Set rst = Me.RecordsetClone
rst.MoveFirst
While Not rst.EOF
   rst.Edit
   rst!BrojSlogovaIzTabele = F_BrojSlogovaUTabeli(rst!ImeIzTabele)
   rst!BrojSlogovaUTabelu = F_BrojSlogovaUTabeli(rst!ImeUTabelu)
   rst.Update
   rst.MoveNext
Wend

Exit_Point:
 On Error Resume Next
 rst.Close
 Set rst = Nothing
       F_PreracunajBrojSlogova = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "F_PreracunajBrojSlogova"
 retValOk = False
 Resume Exit_Point
End Function

Private Sub DugmePreracunajBrojSlogova_Click()
    If F_PreracunajBrojSlogova() Then
       PrimeniUslove
    End If
End Sub

Private Sub Form_Current()
    Me!DugmeUradi1Tabelu.Caption = "ACC Prenesi" & vbCrLf & Me!ImeIzTabele & " => " & Me!ImeUTabelu
    Me!DugmeSET_IDENTITY_INSERT.Caption = "SET IDENTITY_INSERT [" & Me!ImeUTabelu & "] " & Me!IdentityOnOff
    Me!DugmeExportUSQL.Caption = "EXPORT u SQL bazu" & vbCrLf & Me!ImeIzTabele & " => " & Me!ImeUTabelu
End Sub

Private Sub IdentityOnOff_AfterUpdate()
    Me!DugmeSET_IDENTITY_INSERT.Caption = "SET IDENTITY_INSERT [" & Me!ImeUTabelu & "] " & Me!IdentityOnOff
End Sub

Private Sub ImeIzTabele_DblClick(Cancel As Integer)
 On Error Resume Next
    PogledajTabelu Me!ImeIzTabele
End Sub

Private Sub ImeUTabelu_DblClick(Cancel As Integer)
    PogledajTabelu Me!ImeUTabelu
End Sub

Private Sub DugmeUradi1Tabelu_Click()
'Modifikovano: 22-06-2020
On Error GoTo Err_DugmeUradi1Tabelu_Click
  Dim OK As Boolean
  
 '   If IsLinkedODBC(Me!ImeUTabelu) Then
 '    Ok = UradiImportIzTabeleUSQLTabelu(Me!ImeIzTabele, Me!ImeUTabelu, Trim(Nz(Me!SQLTexImport, "")), Trim(Nz(Me!SQLTextPostImport, "")), False, Me!IdentityOnOff = "On")
 '   Else
 '    Ok = UradiImportIzTabeleUTabelu(Me!ImeIzTabele, Me!ImeUTabelu, Trim(Nz(Me!SQLTexImport, "")), Trim(Nz(Me!SQLTextPostImport, "")))
 '   End If

    OK = UradiImportIzTabeleUTabelu(Me!ImeIzTabele, Me!ImeUTabelu, Trim(Nz(Me!SQLTexImport, "")), Trim(Nz(Me!SQLTextPostImport, "")))
    F_PrikaziBrojSlogova
    
Exit_DugmeUradi1Tabelu_Click:
    Exit Sub

Err_DugmeUradi1Tabelu_Click:
    MsgBox err.Description
    Resume Exit_DugmeUradi1Tabelu_Click
    
End Sub

Private Sub EditujUpit(Upit As String, Optional stTipUpita As String = "INSERT")
Dim retVal
Dim qDef As DAO.QueryDef


    On Error Resume Next
    If CurrentDb.QueryDefs(imeTMPupita).Name = "~ppsTmp~" Then
        CurrentDb.QueryDefs.Delete imeTMPupita
    End If
    If Nz(Upit, "") = "" Then
        'Upit = "SELECT [" & Me!ImeIzTabele & "].* FROM [" & Me!ImeIzTabele & "];"
        'Upit = "SELECT * FROM [" & Me!ImeIzTabele & "], [" & Me!ImeUTabelu & "];"
        If stTipUpita = "SELECT" Then
          Upit = "SELECT [" & Me!ImeIzTabele & "].* FROM [" & Me!ImeIzTabele & "], [" & Me!ImeUTabelu & "];"
        Else
          Upit = "INSERT INTO[" & Me!ImeUTabelu & "] SELECT [" & Me!ImeIzTabele & "].* FROM [" & Me!ImeIzTabele & "], [" & Me!ImeUTabelu & "];"
        End If
    End If
    Set qDef = CurrentDb.CreateQueryDef(imeTMPupita, Upit)
    DoCmd.OpenQuery imeTMPupita, acViewDesign
    Set qDef = Nothing
End Sub

Private Sub SQL_SELECT_IzTabele_DblClick(Cancel As Integer)
    EditujUpit Nz(Me!SQL_SELECT_IzTabele, ""), "SELECT"
End Sub

Private Sub SQL_SELECT_IzTabele_ff_DblClick(Cancel As Integer)
    EditujUpit Nz(Me!SQL_SELECT_IzTabele, ""), "SELECT"
End Sub

Private Sub SQLTexImport_DblClick(Cancel As Integer)
   EditujUpit Nz(Me!SQLTexImport, "")
End Sub

Private Sub SQLTexImport_ff_DblClick(Cancel As Integer)
  EditujUpit Nz(Me!SQLTexImport, "")
End Sub

Private Sub SQLTexImport_SPEC_DblClick(Cancel As Integer)
    EditujUpit Nz(Me!SQLTexImport_SPEC, "")
End Sub

Private Sub SQLTextPostImport_DblClick(Cancel As Integer)
   EditujUpit Nz(Me!SQLTextPostImport, "")
End Sub

Private Sub ZaImeIzTabele_DblClick(Cancel As Integer)
    Me!ZaImeIzTabele = Null
    PrimeniUslove
End Sub

Private Sub ZaImeUTabelu_DblClick(Cancel As Integer)
    Me!ZaImeUTabelu = Null
    PrimeniUslove
End Sub
Private Sub DugmeNoviSlog_Click()
On Error GoTo Err_DugmeNoviSlog_Click


    DoCmd.GoToRecord , , acNewRec

Exit_DugmeNoviSlog_Click:
    Exit Sub

Err_DugmeNoviSlog_Click:
    MsgBox err.Description
    Resume Exit_DugmeNoviSlog_Click
    
End Sub
Private Sub DugmeGetSQLTextImport_Click()
    Me!SQLTexImport = CurrentDb.QueryDefs(imeTMPupita).sql
End Sub
Private Sub DugmeSET_IDENTITY_INSERT_Click()
'SET IDENTITY_INSERT [ database_name . [ schema_name ] . ] table { ON | OFF }
'ADO_ExecSQL(BBCFG.CNNString,"SET IDENTITY_INSERT [dbo].[T_Rastavnice] OFF ")

On Error GoTo Err_DugmeSET_IDENTITY_INSERT_Click
 Dim retValOk As Boolean
 Dim SQLText As String
 
  SQLText = "SET IDENTITY_INSERT [" & Me!ImeUTabelu & "] " & Me!IdentityOnOff
  retValOk = ADO_ExecSQL(BBCFG.CNNString, SQLText)
  If retValOk Then
   MsgBox "Uspešno." & vbCrLf & vbCrLf & SQLText, vbInformation, "QMegaTeh"
  Else
   MsgBox "NEUSPEŠNO!" & vbCrLf & vbCrLf & SQLText, vbInformation, "QMegaTeh"
  End If

Exit_DugmeSET_IDENTITY_INSERT_Click:
    Exit Sub

Err_DugmeSET_IDENTITY_INSERT_Click:
    MsgBox err.Description
    Resume Exit_DugmeSET_IDENTITY_INSERT_Click
    
End Sub
Private Sub DugmeExportUSQL_Click()
On Error GoTo Err_DugmeExportUSQL_Click
Dim retValOk As Boolean

    retValOk = ExportujTabeluUSQL(Me!ImeIzTabele, Me!ImeUTabelu, Trim(Nz(Me!SQL_SELECT_IzTabele, ""))) ', Trim(Nz(Me!SQLTexImport, "")), Trim(Nz(Me!SQLTextPostImport, "")), False, Me!IdentityOnOff = "On")
    F_PrikaziBrojSlogova
    
Exit_DugmeExportUSQL_Click:
    Exit Sub

Err_DugmeExportUSQL_Click:
    MsgBox err.Description
    Resume Exit_DugmeExportUSQL_Click
    
End Sub
