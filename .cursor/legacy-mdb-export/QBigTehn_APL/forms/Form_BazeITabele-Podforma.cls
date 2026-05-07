VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BazeITabele-Podforma"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Dim StaroImeTabele As String
Dim NovoImeTabele As String

Private Sub CurrentSourceDataBase_DblClick(Cancel As Integer)
    If Not Me.Recordset.Updatable Then
     DozvoliUnos
    End If
     If IsLinkedTableAccess(Me!Name) Or IsLinkedODBC(Me!Name) Then
      Me!CurrentSourceDataBase = CurrentDb.TableDefs(Me!Name).Connect  'F_CheckLink(Me!Name)
     Else
      BBMsgBox_BigBit "Tabela " & Me!Name & " nije linkovana."
     End If
End Sub

Private Sub DugmeForsirajNoviLinkZaTabelu_Click()
'Modifikovano: 02-02-2022
Dim stNewCNNString As String

If Nz(Me!CurrentSourceDataBase, "") = "" Then
    stNewCNNString = Forms!BazeITabele!Baza
ElseIf Nz(Me!CurrentSourceDataBase, "Unknown!") = "Unknown!" Then
    stNewCNNString = Forms!BazeITabele!Baza
Else
    stNewCNNString = Nz(Me!CurrentSourceDataBase, "")
End If

    If ForsirajNoviLinkZaTabelu(Me!Name, Me!SourceTableName, stNewCNNString, Nz(Forms!BazeITabele!UserName, ""), Nz(Forms!BazeITabele!Password, "")) Then
     BBMsgBox_BigBit "Uspešno", 2
    Else
     BBMsgBox_BigBit "Nije uspelo"
    End If
End Sub

Private Sub Form_AfterUpdate()
 If Me!CheckRenameLinkedTable And StaroImeTabele <> NovoImeTabele Then
     If RenameLokalTable(StaroImeTabele, NovoImeTabele) Then
      If Me!CheckAutoNext Then
       DoCmd.GoToRecord , , acNext
       DoCmd.GoToControl "Name"
       If Nz(Me!NamePrefixDEL, "") <> "" Then
         If Me!Name Like Me!NamePrefixDEL & "*" Then
          Me!Name = Right(Me!Name, Len(Me!Name) - Len(NamePrefixDEL))
         End If
       End If
        Me!Name = Me!NamePrefixADD & Me!Name
      End If
     Else
      Me.Undo
     End If
  End If
End Sub

Private Sub Form_BeforeUpdate(Cancel As Integer)
On Error Resume Next
 StaroImeTabele = Nz(Me!ComboName.OldValue, "")
 NovoImeTabele = Me!Name
  
End Sub

Private Sub RenameTableName(StaroImeTabele As String, NovoImeTabele As String)
    If PostojiTabelaUBazi(StaroImeTabele, CurrentDb) Then
     If BBPitanje("Da li zelite da promenim ime tabele u lokalnoj bazi?") Then
       CurrentDb.TableDefs(StaroImeTabele).Name = NovoImeTabele
     End If
    End If
End Sub

Private Sub ComboName_DblClick(Cancel As Integer)
 Dim stMsg As String
    If Not IsNull(Me![Name]) Then
       PogledajTabelu (Me![Name])
    Else
    stMsg = ListaSvihTabela(Me.Parent!Baza)
     If stMsg <> "" Then
       Me!ComboName.RowSource = stMsg
       'MsgBox ListaSvihTabela(Me.Parent!Baza), vbInformation, "QMegaTeh"
     End If
    End If
End Sub
Private Sub PogledajTabelu(TblName As String)
On Error GoTo Err_PogledajTabelu
    Dim Poruka As String
    
    If Not PostojiTabelaUBazi(TblName, CurrentDb) Then
     MsgBox "Ne postoji tabela.", vbExclamation, "QMegaTeh"
    ElseIf SysCheckLink(TblName) Then
      DoCmd.OpenTable TblName, acNormal, acEdit
    Else
      Poruka = "Tabela nije dostupna." & vbCrLf & vbCrLf
      Poruka = Poruka & "CnnString: " & CurrentDb.TableDefs(TblName).Connect
      MsgBox Poruka, vbExclamation, "QMegaTeh"
    End If

Exit_PogledajTabelu:
    Exit Sub

Err_PogledajTabelu:
    MsgBox err.Description
    Resume Exit_PogledajTabelu
    
End Sub

Private Sub DozvoliUnos()
    Dim txtSqlRset As String
    Dim txtSqlRsetDozvoljenUnos As String
    txtSqlRset = "SELECT BazeITabele.*, [Name]=[SourceTableName] AS JednakaImenaTabela, [CurrentSourceDataBase]=[Baza] AS JednakeBaze, Baze.UserName, Baze.Password "
txtSqlRset = txtSqlRset & " FROM BazeITabele INNER JOIN Baze ON BazeITabele.IDBaze = Baze.IDBaze "
txtSqlRset = txtSqlRset & " ORDER BY BazeITabele.ID;"

txtSqlRsetDozvoljenUnos = "SELECT BazeITabele.*, [Name]=[SourceTableName] AS JednakaImenaTabela, [CurrentSourceDataBase]=[Baza] AS JednakeBaze "
txtSqlRsetDozvoljenUnos = txtSqlRsetDozvoljenUnos & " FROM BazeITabele "
'txtSqlRsetDozvoljenUnos = txtSqlRsetDozvoljenUnos & "WHERE (((BazeITabele.Name) Like ""*"" & Nz([Forms]![BazeITabele]![BazeITabele-Podforma].[Form]![ZaName],""*"") & ""*"") AND ((BazeIFirme.FirmaZaBaze)=[Forms]![BazeITabele]![FirmaZaBaze]) AND ((ZadovoljenUslovZaBoolVal(InStr("";DATABASE="" & [Baza],[CurrentSourceDataBase])>0,[Forms]![BazeITabele]![BazeITabele-Podforma].[Form]![ZaDobarLink]))=True))"
txtSqlRsetDozvoljenUnos = txtSqlRsetDozvoljenUnos & "WHERE (((BazeITabele.Name) Like ""*"" & Nz([Forms]![BazeITabele]![BazeITabele-Podforma].[Form]![ZaName],""*"") & ""*"") AND ((BazeIFirme.FirmaZaBaze)=[Forms]![BazeITabele]![FirmaZaBaze]) AND ((ZadovoljenUslovZaBoolVal(InStr("";DATABASE="" & [Baza],[CurrentSourceDataBase])>0,[Forms]![BazeITabele]![BazeITabele-Podforma].[Form]![ZaDobarLink]))=True))"
txtSqlRsetDozvoljenUnos = txtSqlRsetDozvoljenUnos & " ORDER BY BazeITabele.ID;"

Me.RecordSource = txtSqlRsetDozvoljenUnos
End Sub
Private Sub DugmeNoviSlog_Click()
On Error GoTo Err_DugmeNoviSlog_Click

    DozvoliUnos
    DoCmd.GoToRecord , , acNewRec
    DoCmd.GoToControl "IDBaze"
    
Exit_DugmeNoviSlog_Click:
    Exit Sub

Err_DugmeNoviSlog_Click:
    MsgBox err.Description
    Resume Exit_DugmeNoviSlog_Click
    
End Sub

Private Sub SourceTableName_DblClick(Cancel As Integer)
If Me.Recordset.Updatable Then
    Me!SourceTableName = CurrentDb.TableDefs(Me!Name).SourceTableName
End If
End Sub

Private Sub ZaDobarLink_AfterUpdate()
   PrimeniUslove
End Sub
Private Sub PrimeniUslove()
   Me.Requery
End Sub
Private Sub ZaName_AfterUpdate()
    PrimeniUslove
End Sub

Private Sub ZaName_DblClick(Cancel As Integer)
    Me!ZaName = Null
    Me.Requery
End Sub
Private Sub DugmeObrisiLinkove_Click()
On Error GoTo Err_DugmeObrisiLinkove_Click
    Dim OK As Boolean
    OK = ObrisiLinkovaneTabeleZaIDBaze(Me!IDBaze)
    Me.Requery
    If OK Then
      BBMsgBox_BigBit "Linkovi su uspešno obrisani"
    Else
     BBMsgBox_BigBit "Linkovi NISU uspešno obrisani"
    End If
Exit_DugmeObrisiLinkove_Click:
    Exit Sub

Err_DugmeObrisiLinkove_Click:
    MsgBox err.Description
    Resume Exit_DugmeObrisiLinkove_Click
    
End Sub
Private Sub DugmeKreirajLinkove_Click()
On Error GoTo Err_DugmeKreirajLinkove_Click
    Dim OK As Boolean
    OK = KreirajLinkovaneTabeleZaIDBaze(Me!IDBaze, Forms!BazeITabele!ComboBaza.Column(1))
    Me.Requery
    If OK Then
      BBMsgBox_BigBit "Linkovi su uspešno kreirani"
    Else
     BBMsgBox_BigBit "Linkovi NISU uspešno kreirani"
    End If
Exit_DugmeKreirajLinkove_Click:
    Exit Sub

Err_DugmeKreirajLinkove_Click:
    MsgBox err.Description
    Resume Exit_DugmeKreirajLinkove_Click
    
End Sub

Private Sub DugleSledeci_Click()
On Error GoTo Err_DugleSledeci_Click


    DoCmd.GoToRecord , , acNext

Exit_DugleSledeci_Click:
    Exit Sub

Err_DugleSledeci_Click:
    MsgBox err.Description
    Resume Exit_DugleSledeci_Click
    
End Sub
Private Sub DugmeDodajPrefix_Click()
On Error GoTo Err_DugmeDodajPrefix_Click

    Dim stSQL As String

    stSQL = "UPDATE BazeITabele SET BazeITabele.Name = [Forms]![BazeITabele]![BazeITabele-Podforma].[Form]![NamePrefixADD] & [Name] WHERE (((BazeITabele.IDBaze)=[Forms]![BazeITabele]![IDBaze]));"
    DoCmd.RunSQL stSQL
    Me.Requery
    
Exit_DugmeDodajPrefix_Click:
    Exit Sub

Err_DugmeDodajPrefix_Click:
    MsgBox err.Description
    Resume Exit_DugmeDodajPrefix_Click
    
End Sub
Private Sub DugmeRefreshLink_Click()
On Error GoTo Err_DugmeRefreshLink_Click

   CurrentDb.TableDefs(Me!Name).RefreshLink

Exit_DugmeRefreshLink_Click:
    Exit Sub

Err_DugmeRefreshLink_Click:
    MsgBox err.Description
    Resume Exit_DugmeRefreshLink_Click
    
End Sub
