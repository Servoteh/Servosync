VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBT_BrojDokumenataPoGodinama"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PrimeniUslove()
  SetProperlyRecordSource CNN_CurrentDataBase, Me
End Function
Private Function GodinaZameniUTabeli(UTabeli As String, UmestoGodina As Long) As Boolean
On Error GoTo Err_Point

  Dim stSQL As String
  Dim retValOk As Boolean
  Dim StaviGodina
  
  retValOk = True
  
  StaviGodina = InputBox("Umesto Godina = " & Me!Godina & " stavi", "QMegaTeh", F_Godina())
    If IsNumeric(StaviGodina) Then
       If CLng(StaviGodina) <> StaviGodina Then
          MsgBox "Nekorektno zadat parametar!", vbExclamation, "QMegaTeh"
          retValOk = False
          GoTo Exit_Point
       End If
    Else
      MsgBox "Nekorektno zadat parametar!", vbExclamation, "QMegaTeh"
      retValOk = False
      GoTo Exit_Point
    End If
 If BBCFG.SQLDB Then
  stSQL = "UPDATE [" & UTabeli & "] SET [" & UTabeli & "].Godina = " & StaviGodina & " WHERE [" & UTabeli & "].Godina=" & UmestoGodina & ";"
  'PassTroughExecuteSQL stSQL
  ADO_ExecSQL BBCFG.CNNString, stSQL
 Else
  stSQL = "UPDATE [" & UTabeli & "] SET [" & UTabeli & "].Godina = " & StaviGodina & " WHERE [" & UTabeli & "].Godina=" & UmestoGodina & ";"
  CurrentDb.Execute stSQL
 End If
Exit_Point:
 GodinaZameniUTabeli = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "GodinaZameniUTabeli"
 retValOk = False
 Resume Exit_Point
End Function
Private Function GodinaZameniUTabeliIzDatuma(UTabeli As String, Optional ByVal KolonaDatum) As Boolean
On Error GoTo Err_Point

  Dim stSQL As String
  Dim retValOk As Boolean
  Dim stKolonaDatum As String
  
  retValOk = True
  If IsMissing(KolonaDatum) Then
   stKolonaDatum = "Datum dokumenta"
  Else
   stKolonaDatum = CStr(Nz(KolonaDatum, ""))
  End If
  
  KolonaDatum = InputBox("Kolona za datum = " & stKolonaDatum, "QMegaTeh", stKolonaDatum)
  
   If Nz(stKolonaDatum, "") = "" Then
      BBMsgBox_BigBit "Ništa nije uradjeno.", 2
      retValOk = False
      GoTo Exit_Point
   End If
   
   If Not PostojiPoljeUTabeli(stKolonaDatum, CurrentDb.TableDefs(UTabeli)) Then
      MsgBox "U tabeli [" & UTabeli & "] ne postoji kolona [" & stKolonaDatum & "]", vbExclamation, "QMegaTeh"
      retValOk = False
      GoTo Exit_Point
   End If
   
   If CurrentDb.TableDefs(UTabeli).Fields(stKolonaDatum).Type <> dbDate Then
      MsgBox "Kolona [" & stKolonaDatum & "] nije tipa DATUM!", vbCritical, "QMegaTeh"
      retValOk = False
      GoTo Exit_Point
   End If
   
   'CurrentDb.TableDefs("T_Robna dokumenta").Fields("Datum dokumenta").Type
   
  
  
  If BBCFG.SQLDB Then
    'stSQL = "UPDATE [" & UTabeli & "] SET Godina = DatePart(yyyy,[" & stKolonaDatum & "]);"
    'stSQL = "UPDATE [" & UTabeli & "] SET Godina = DatePart(Year,[" & stKolonaDatum & "]);"
    'PassTroughExecuteSQL stSQL  OVO NE RADI!
    
    stSQL = "UPDATE [" & UTabeli & "] as t  SET t.Godina = DatePart(""yyyy"",t.[" & stKolonaDatum & "]);"
    CurrentDb.Execute stSQL
  Else
    stSQL = "UPDATE [" & UTabeli & "] as t  SET t.Godina = DatePart(""yyyy"",t.[" & stKolonaDatum & "]);"
    CurrentDb.Execute stSQL
  End If
  
Exit_Point:
 GodinaZameniUTabeliIzDatuma = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "GodinaZameniUTabeli"
 retValOk = False
 Resume Exit_Point
End Function
Private Function IDFirmaZameniUTabeli(UTabeli As String, UmestoIDFirma As Long) As Boolean
On Error GoTo Err_Point

  Dim stSQL As String
  Dim retValOk As Boolean
  Dim StaviIDFirma
  
  retValOk = True
  
  StaviIDFirma = InputBox("Umesto IDFirma = " & Me!IDFirma & " stavi", "QMegaTeh", F_IDFirma())
    If IsNumeric(StaviIDFirma) Then
       If CLng(StaviIDFirma) <> StaviIDFirma Then
          MsgBox "Nekorektno zadat parametar!", vbExclamation
          retValOk = False
          GoTo Exit_Point
       End If
    Else
      MsgBox "Nekorektno zadat parametar!", vbExclamation, "QMegaTeh"
      retValOk = False
      GoTo Exit_Point
    End If
  
  stSQL = "UPDATE [" & UTabeli & "] SET [" & UTabeli & "].IDFirma = " & StaviIDFirma & " WHERE [" & UTabeli & "].IDFirma=" & UmestoIDFirma & ";"
  CurrentDb.Execute stSQL
  
Exit_Point:
 IDFirmaZameniUTabeli = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "IDFirmaZameniUTabeli"
 retValOk = False
 Resume Exit_Point
End Function

Private Sub DugmeRefresh_Click()
    PrimeniUslove
End Sub

Private Sub Form_Current()
On Error GoTo Err_Point

    Me!ComboKolonaDatum.RowSource = Me!TblName
    Me!ComboKolonaDatum = Null
    Me!ComboKolonaDatum.Requery

Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
 BBErrorMSG err, "Form_Current"
 Resume Exit_Point
End Sub

Private Sub Form_Open(Cancel As Integer)
    PrimeniUslove
End Sub

Private Sub Form_Unload(Cancel As Integer)
    CloseConnectionOnCurrentForm Me
End Sub

Private Sub Godina_DblClick(Cancel As Integer)
    GodinaZameniUTabeli Me!TblName, Me!Godina
    'GodinaZameniUTabeliIzDatuma Me!TblName
    PrimeniUslove
End Sub

Private Sub IDFirma_DblClick(Cancel As Integer)
    
    IDFirmaZameniUTabeli Me!TblName, Me!IDFirma
    PrimeniUslove
    
End Sub
Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


    If Me.Dirty Then Me.Dirty = False
    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub

Private Sub TblName_DblClick(Cancel As Integer)
    DoCmd.OpenTable Me!TblName, acNormal, acEdit
End Sub
Private Sub DugmeUpisiGodinuUTabeluIzKoloneDatum_Click()
On Error GoTo Err_DugmeUpisiGodinuUTabeluIzKoloneDatum_Click

    GodinaZameniUTabeliIzDatuma Me!TblName, Me!ComboKolonaDatum
    PrimeniUslove
    
Exit_DugmeUpisiGodinuUTabeluIzKoloneDatu:
    Exit Sub

Err_DugmeUpisiGodinuUTabeluIzKoloneDatum_Click:
    MsgBox err.Description
    Resume Exit_DugmeUpisiGodinuUTabeluIzKoloneDatu
    
End Sub
