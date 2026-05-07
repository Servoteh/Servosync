Attribute VB_Name = "BBPravaPristupa"
Option Compare Database
Option Explicit

Public Function BB_PravaPristupaPodesiFormu(ByRef aktForma As Form, Optional ByVal LinkCriteria = "", Optional UserName) As Boolean
'Modifikovano: 29-06-2020
On Error GoTo err_BBPravaPristupaPodesiFormu
    Dim BigBit As DAO.Database
    Dim QTabPrava As DAO.QueryDef
    Dim TabPrava As DAO.Recordset
    Dim ctl As control
    Dim ZaUsera As String
    Dim ZaFormu As String
    Dim retVal As Boolean
    
    retVal = True
    
    If Not BBCFG.SysPravaPristupaPodesiFormu Then
     BB_PravaPristupaPodesiFormu = retVal
     Exit Function
    End If
    
    If IsMissing(UserName) Then
       If BBCFG.TestPravaPristupa Then
            ZaUsera = BBCFG.DefaultLimitedUser
       Else
        ZaUsera = CurrentUser()
       End If
    Else
       ZaUsera = CStr(UserName)
    End If
    ZaFormu = aktForma.Name
    
    Set BigBit = CurrentDb
    Set QTabPrava = BigBit.QueryDefs("Q_BBPravaPristupa")
    QTabPrava.Parameters("[ZaUsera]") = ZaUsera
    QTabPrava.Parameters("[ZaFormu]") = ZaFormu

    Set TabPrava = QTabPrava.OpenRecordset(dbOpenDynaset, dbSeeChanges)
    TabPrava.Sort = "ID"
    
    On Error Resume Next
    TabPrava.MoveFirst
    On Error GoTo err_BBPravaPristupaPodesiFormu
    While Not TabPrava.EOF
        If (TabPrava!ImeKontrole) = "[Form]" Then
                    If Nz(TabPrava!RecordSource, "") <> "" Then
                        aktForma.RecordSource = TabPrava!RecordSource
                        '********************
                        If Nz(LinkCriteria, "") <> "" Then
                            aktForma.Filter = "(" & LinkCriteria & ")"
                            aktForma.FilterOn = True
                        End If
                        '********************
                    End If
                    If Nz(TabPrava!Filter, "") <> "" Then
                        If Nz(aktForma.Filter, "") <> "" Then
                         aktForma.Filter = "(" & aktForma.Filter & ") AND (" & TabPrava!Filter & ")"
                         aktForma.FilterOn = True
                        Else
                         aktForma.Filter = TabPrava!Filter
                         aktForma.FilterOn = True
                        End If
                    End If
                    If Nz(TabPrava!Locked, False) Then
                        aktForma.AllowEdits = False
                        aktForma.AllowAdditions = False
                        aktForma.AllowDeletions = False
                    End If
                   ' Debug.Print "ZaFormu= " & ZaFormu & "   TabPrava!ImeKontrole=" & TabPrava!ImeKontrole
                   If Nz(TabPrava!RecordSource, "") <> "" Then
                    On Error Resume Next
                    DoCmd.GoToRecord , , acLast
                    On Error GoTo err_BBPravaPristupaPodesiFormu
                   End If
        Else
        
        For Each ctl In aktForma.Controls
            If (ctl.Name = TabPrava!ImeKontrole) Or (TabPrava!ImeKontrole) = "*" Then
                'test
                 If ctl.Name = "DugmeNoviSlog" Then
                  Debug.Print ctl.Name, ctl.ControlType
                 End If
                'test
                If ctl.Visible Then ctl.Visible = TabPrava!Visible
                
                If ctl.ControlType = acComboBox Or _
                    ctl.ControlType = acListBox Or _
                    ctl.ControlType = acTextBox Or _
                    ctl.ControlType = acCheckBox Or _
                    ctl.ControlType = acCommandButton Or _
                    ctl.ControlType = acOptionButton Or _
                    ctl.ControlType = acTabCtl _
                    Then
                If ctl.Enabled Then ctl.Enabled = TabPrava!Enabled
                End If
                
                If ctl.ControlType = acComboBox Or _
                    ctl.ControlType = acListBox Or _
                    ctl.ControlType = acCheckBox Or _
                    ctl.ControlType = acTextBox Then
                    If Not ctl.Locked Then ctl.Locked = TabPrava!Locked
                    If Nz(TabPrava!Vrednost, "") <> "" Then ctl.DefaultValue = TabPrava!Vrednost
                End If
                If (ctl.ControlType = acComboBox Or ctl.ControlType = acListBox) _
                     And (Nz(TabPrava!RecordSource, "") <> "") Then
                        ctl.RowSource = TabPrava!RecordSource
                End If
                
            End If
            
        Next
        End If
        TabPrava.MoveNext
        
    Wend
exit_BBPravaPristupaPodesiFormu:
    
    Set TabPrava = Nothing
    Set QTabPrava = Nothing
    Set BigBit = Nothing
    BB_PravaPristupaPodesiFormu = retVal
Exit Function
err_BBPravaPristupaPodesiFormu:
    MsgBox err.Description & vbCrLf & "Prava pristupa nisu podesena." & vbCrLf & "ctl.Name=" & ctl.Name & vbCrLf & "TabPrava!ImeKontrole = " & TabPrava!ImeKontrole, vbExclamation, "QMegaTeh"
    retVal = False
 Resume exit_BBPravaPristupaPodesiFormu
End Function
Public Function BB_PravaPristupaPodesiReport(aktReport As Report) As Boolean
On Error GoTo err_BBPravaPristupaPodesiReport

    Dim BigBit As DAO.Database
    Dim QTabPrava As DAO.QueryDef
    Dim TabPrava As DAO.Recordset
    Dim ctl As control
    Dim ZaUsera As String
    Dim ZaReport As String
    Dim retVal As Boolean
    
    retVal = True
    
    Set BigBit = CurrentDb
    Set QTabPrava = BigBit.QueryDefs("Q_BBPravaPristupa")
    ZaUsera = CurrentUser()
    'If UserUGrupi(ZaUsera, "LimitedUsers") Or BBTestPravaPristupa Then ZaUsera = "*"
    If BBCFG.TestPravaPristupa Then
     'ZaUsera = "NSUser"
     ZaUsera = BBCFG.DefaultLimitedUser
    End If
    ZaReport = aktReport.Name
    QTabPrava.Parameters("[ZaUsera]") = ZaUsera
    QTabPrava.Parameters("[ZaFormu]") = ZaReport

    Set TabPrava = QTabPrava.OpenRecordset
    TabPrava.Sort = "ID"
    
    On Error Resume Next
    TabPrava.MoveFirst
    On Error GoTo err_BBPravaPristupaPodesiReport
    While Not TabPrava.EOF
        If (TabPrava!ImeKontrole) = "[Report]" Then
                    If Nz(TabPrava!RecordSource, "") <> "" Then
                        aktReport.RecordSource = TabPrava!RecordSource
                    End If
                    If Nz(TabPrava!Filter, "") <> "" Then
                        aktReport.Filter = TabPrava!Filter
                        aktReport.FilterOn = True
                    End If
                    'Debug.Print "ZaReport= " & ZaReport & "   TabPrava!ImeKontrole=" & TabPrava!ImeKontrole
        Else
        
        For Each ctl In aktReport.Controls
            If (ctl.Name = TabPrava!ImeKontrole) Or (TabPrava!ImeKontrole) = "*" Then
                
                If ctl.Visible Then ctl.Visible = TabPrava!Visible
                
                If ctl.ControlType = acComboBox Or _
                    ctl.ControlType = acListBox Or _
                    ctl.ControlType = acTextBox Or _
                    ctl.ControlType = acCheckBox Or _
                    ctl.ControlType = acCommandButton _
                    Then
                If ctl.Enabled Then ctl.Enabled = TabPrava!Enabled
                End If
                
                If ctl.ControlType = acComboBox Or _
                    ctl.ControlType = acListBox Or _
                    ctl.ControlType = acCheckBox Or _
                    ctl.ControlType = acTextBox Then
                    'If Not ctl.Locked Then ctl.Locked = TabPrava!Locked
                    'If Nz(TabPrava!Vrednost, "") <> "" Then ctl.DefaultValue = TabPrava!Vrednost
                End If
                If (ctl.ControlType = acComboBox Or ctl.ControlType = acListBox) _
                     And (Nz(TabPrava!RecordSource, "") <> "") Then
                        ctl.RowSource = TabPrava!RecordSource
                End If
                
            End If
            
        Next
        End If
        TabPrava.MoveNext
        
    Wend
exit_BBPravaPristupaPodesiReport:
    
    Set TabPrava = Nothing
    Set QTabPrava = Nothing
    Set BigBit = Nothing
    BB_PravaPristupaPodesiReport = retVal
Exit Function
err_BBPravaPristupaPodesiReport:
    MsgBox err.Description & vbCrLf & "Prava pristupa nisu podesena.", vbExclamation, "QMegaTeh"
    retVal = False
 Resume exit_BBPravaPristupaPodesiReport
End Function
Public Function BB_NapraviTabeluSvihKontrolaNaFormi(aktForma As Form) As Boolean
On Error GoTo err_Napravi

    Dim BigBit As DAO.Database
    Dim TabKontrole As DAO.Recordset
    Dim ctl As control
    Dim retVal As Boolean
    
    retVal = True
    DoCmd.SetWarnings False
    DoCmd.OpenQuery "tmp_T_KontroleNaFormi_DELETE"
    DoCmd.SetWarnings True
    Set BigBit = CurrentDb
    Set TabKontrole = BigBit.OpenRecordset("tmp_T_KontroleNaFormi")
    
    
    For Each ctl In aktForma.Controls
         On Error GoTo err_Napravi
          TabKontrole.AddNew
          TabKontrole!ImeForme = aktForma.Name
          TabKontrole!ImeKontrole = ctl.Name
          TabKontrole!TipKontrole = ctl.ControlType
         On Error Resume Next
          'TabKontrole!TabOrder = ctl.TabOrder
          'aktForma.Section("Detail").SetTabOrder
          TabKontrole!TabStop = ctl.TabStop
          TabKontrole.Update
    Next
exit_Napravi:
    
    Set TabKontrole = Nothing
    Set BigBit = Nothing
    BB_NapraviTabeluSvihKontrolaNaFormi = retVal
    DoCmd.SetWarnings True
Exit Function
err_Napravi:
   If err.Number = 91 Then
   Else
    MsgBox err.Description & vbCrLf & "Tabela kontrola nije napravljena.", vbExclamation, "QMegaTeh"
   End If
    retVal = False
 Resume exit_Napravi
End Function

Public Function OtvoriFormuPravaPristupa() As Boolean
On Error Resume Next
Dim aktForma As Form
Dim aktivnaKontrola As control

Set aktForma = Screen.ActiveForm
Set aktivnaKontrola = Screen.ActiveControl

Call BB_NapraviTabeluSvihKontrolaNaFormi(aktForma)
    BBOpenForm "BBPravaPristupa"
 'Forms!BBPravaPristupa.ImeUsera
 If Not (aktivnaKontrola Is Nothing) Then
  Forms!BBPravaPristupa!ZaImeForme = aktivnaKontrola.Parent.Name
  Forms!BBPravaPristupa!ImeForme.DefaultValue = "'" & aktivnaKontrola.Parent.Name & "'"
  'Forms!BBPravaPristupa!ImeForme.DefaultValue = "'" & aktForma.Name & "'" 'modifikovano 27-05-19
  Forms!BBPravaPristupa.ImeKontrole.DefaultValue = "'" & aktivnaKontrola.Name & "'"
 Else
  Forms!BBPravaPristupa!ImeForme.DefaultValue = "'" & aktForma.Name & "'"
  Forms!BBPravaPristupa!ZaImeForme = aktForma.Name
  Forms!BBPravaPristupa.ImeKontrole.DefaultValue = "'[Form]'"
 End If

 Forms!BBPravaPristupa!ZaImeUsera = BBCFG.DefaultLimitedUser
 'Forms!BBPravaPristupa!ImeForme.DefaultValue = "'" & aktForma.Name & "'"
 'DoCmd.GoToRecord acDataForm, "BBPravaPristupa", acNewRec
 'Forms!BBPravaPristupa!ImeKontrole = aktivnaKontrola.Name
 Forms!BBPravaPristupa.Requery
 OtvoriFormuPravaPristupa = True
End Function
Public Function OtvoriFormuZaUsera_OLD(stUserName As String, stFormName As String, Optional ByVal View = acNormal, Optional ByVal filterName As String = "", Optional ByVal WhereCondition As String = "", Optional ByVal DataMode = acFormPropertySettings, Optional ByVal WindowMode = acWindowNormal, Optional OpenArgs) As Boolean

On Error GoTo err_BBPravaPristupaPodesiFormu

    Dim BigBit As DAO.Database
    Dim QTabPrava As DAO.QueryDef
    Dim TabPrava As DAO.Recordset
    Dim aktForma As Form
    Dim ctl As control
    Dim retVal As Boolean
    
    retVal = True
    
    Set BigBit = CurrentDb
    Set QTabPrava = BigBit.QueryDefs("Q_BBPravaPristupa")
   
    'If UserUGrupi(ZaUsera, "LimitedUsers") Or BBTestPravaPristupa Then ZaUsera = "*"
    'If BBTestPravaPristupa Then stUserName = "NSUser" 'stUserName = "UnosPorUser"
    If BBCFG.TestPravaPristupa Then
     'ZaUsera = "NSUser"
     stUserName = BBCFG.DefaultLimitedUser
    End If
    
    QTabPrava.Parameters("[ZaUsera]") = stUserName
    QTabPrava.Parameters("[ZaFormu]") = stFormName

    'Set TabPrava = QTabPrava.OpenRecordset
    Set TabPrava = QTabPrava.OpenRecordset(dbOpenDynaset, dbSeeChanges)
    TabPrava.Sort = "ID"
    
   ' On Error Resume Next
    If Not TabPrava.EOF Then    ' Ako je forma "pomenuta", tj. u recordsetu postoji bar jedan slog
                                ' onda se explicitno proverava da li user ima pravo da je otvori
                                ' tj. da li je kontrola = [Form] = Enabled
                                ' inaèe može da je otvori
        TabPrava.MoveLast
        TabPrava.MoveFirst
        TabPrava.FindFirst "[ImeKontrole]='[FORM]'"
        
        If TabPrava.NoMatch Then
             'NEMA PRAVA DA OTVORI FORMU!
             BBMsgBox_BigBit "Nemate prava", 1
             GoTo exit_BBPravaPristupaPodesiFormu
        ElseIf Not TabPrava!Enabled Then
             'NEMA PRAVA DA OTVORI FORMU!
             BBMsgBox_BigBit "Nemate prava", 1
             GoTo exit_BBPravaPristupaPodesiFormu
        End If
        
        'If TabPrava.EOF Then
        '    'NEMA PRAVA DA OTVORI FORMU!
        '     BBMsgBox_BigBit "Nemate prava", 1
        '     GoTo exit_BBPravaPristupaPodesiFormu
        'End If
    
        'If Not TabPrava!Enabled Then
        '  'NEMA PRAVA DA OTVORI FORMU!
        ' BBMsgBox_BigBit "Nemate prava", 1
        ' GoTo exit_BBPravaPristupaPodesiFormu
        'End If
    End If
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    Set TabPrava = Nothing
    Set QTabPrava = Nothing
    Set BigBit = Nothing
    DoCmd.OpenForm stFormName, View, filterName, WhereCondition, DataMode, WindowMode, OpenArgs
   
    If Not IsLoaded(stFormName) Then
     ' ako je forma NIJE ostala otvorena
     ' izadji iz funkcije !!!! ima situacija kada forma nije OSTALA otvorena
     GoTo exit_BBPravaPristupaPodesiFormu
    End If
    Set aktForma = Forms(stFormName)
    BBPravaPristupa.BB_PravaPristupaPodesiFormu aktForma, WhereCondition, stUserName
    '*********************************************************
    'Ovde se radi prevod ako treba
    If F_IDNaJezik <> 0 Then
     On Error Resume Next
     PrevediFormuIliReport Forms(stFormName), 0, F_IDNaJezik()
    End If
    '*********************************************************
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
    'Ovde se postavlja Ribbon prevod ako treba
    If Nz(F_StartRibbonName(), "") <> "" Then
        aktForma.RibbonName = RibbonNameZaIzabranuFormuIUsera(aktForma.Name) 'F_StartRibbonName()
    End If
    '*********************************************************
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
Exit Function
   
exit_BBPravaPristupaPodesiFormu:
    
    Set TabPrava = Nothing
    Set QTabPrava = Nothing
    Set BigBit = Nothing
    'BB_PravaPristupaPodesiFormu = retval
Exit Function
err_BBPravaPristupaPodesiFormu:
    MsgBox err.Description & vbCrLf & "Prava pristupa nisu podesena.", vbExclamation, "QMegaTeh"
    retVal = False
 Resume exit_BBPravaPristupaPodesiFormu
End Function
Public Function OtvoriFormuZaUsera(stUserName As String, stFormName As String, Optional ByVal View = acNormal, Optional ByVal filterName As String = "", Optional ByVal WhereCondition As String = "", Optional ByVal DataMode = acFormPropertySettings, Optional ByVal WindowMode = acWindowNormal, Optional OpenArgs) As Boolean

On Error GoTo err_BBPravaPristupaPodesiFormu

    Dim BigBit As DAO.Database
    Dim QTabPrava As DAO.QueryDef
    Dim TabPrava As DAO.Recordset
    Dim aktForma As Form
    Dim ctl As control
    Dim retVal As Boolean
    Dim finalRibbonName As String
    
    retVal = True
    
    'Set BigBit = CurrentDb
    'Set QTabPrava = BigBit.QueryDefs("Q_BBPravaPristupa")
   
    'If UserUGrupi(ZaUsera, "LimitedUsers") Or BBTestPravaPristupa Then ZaUsera = "*"
    'If BBTestPravaPristupa Then stUserName = "NSUser" 'stUserName = "UnosPorUser"
    'If BBCFG.TestPravaPristupa Then
    ' 'ZaUsera = "NSUser"
    ' stUserName = BBCFG.DefaultLimitedUser
    'End If
    
    'QTabPrava.Parameters("[ZaUsera]") = stUserName
    'QTabPrava.Parameters("[ZaFormu]") = stFormName

    'Set TabPrava = QTabPrava.OpenRecordset
   ' Set TabPrava = QTabPrava.OpenRecordset(dbOpenDynaset, dbSeeChanges)
   ' TabPrava.Sort = "ID"
    
   ' On Error Resume Next
   ' If Not TabPrava.EOF Then    ' Ako je forma "pomenuta", tj. u recordsetu postoji bar jedan slog
   '                             ' onda se explicitno proverava da li user ima pravo da je otvori
   '                             ' tj. da li je kontrola = [Form] = Enabled
   '                             ' inaèe može da je otvori
   '     TabPrava.MoveLast
   '     TabPrava.MoveFirst
   '     TabPrava.FindFirst "[ImeKontrole]='[FORM]'"
   '
   '     If TabPrava.NoMatch Then
   '          'NEMA PRAVA DA OTVORI FORMU!
   '          BBMsgBox "Nemate prava", 1
   '          GoTo exit_BBPravaPristupaPodesiFormu
   '     ElseIf Not TabPrava!Enabled Then
   '          'NEMA PRAVA DA OTVORI FORMU!
   '          BBMsgBox "Nemate prava", 1
   '          GoTo exit_BBPravaPristupaPodesiFormu
   '     End If
   '
   '     'If TabPrava.EOF Then
   '     '    'NEMA PRAVA DA OTVORI FORMU!
   '     '     BBMsgBox "Nemate prava", 1
   '     '     GoTo exit_BBPravaPristupaPodesiFormu
   '     'End If
   '
   '     'If Not TabPrava!Enabled Then
   '     '  'NEMA PRAVA DA OTVORI FORMU!
   '     ' BBMsgBox "Nemate prava", 1
   '     ' GoTo exit_BBPravaPristupaPodesiFormu
   '     'End If
   ' End If
   ' '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
   ' Set TabPrava = Nothing
   ' Set QTabPrava = Nothing
   ' Set BigBit = Nothing
    DoCmd.OpenForm stFormName, View, filterName, WhereCondition, DataMode, WindowMode, OpenArgs
   
    If Not IsLoaded(stFormName) Then
     ' ako je forma NIJE ostala otvorena
     ' izadji iz funkcije !!!! ima situacija kada forma nije OSTALA otvorena
     GoTo exit_BBPravaPristupaPodesiFormu
    End If
    Set aktForma = Forms(stFormName)
    'BBPravaPristupa.BB_PravaPristupaPodesiFormu aktForma, WhereCondition, stUserName
    '*********************************************************
    'Ovde se radi prevod ako treba
    If F_IDNaJezik <> 0 Then
     On Error Resume Next
     PrevediFormuIliReport Forms(stFormName), 0, F_IDNaJezik()
    End If
    '*********************************************************
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
    'Ovde se postavlja Ribbon  ako treba
    finalRibbonName = RibbonNameZaIzabranuFormuIUsera(stFormName)
    If finalRibbonName = "" Then
        finalRibbonName = Nz(F_StartRibbonName(), "") = ""
    End If
    'If Nz(F_StartRibbonName(), "") = "" Then
    '    aktForma.RibbonName = RibbonNameZaIzabranuFormuIUsera(aktForma.Name) 'F_StartRibbonName()
    'End If
    aktForma.RibbonName = finalRibbonName
    
    'If IsLoaded(stFormName) Then
    '    'Forms(stForm).RibbonName = RibbonNameZaIzabranuFormuIUsera(stForm)
    '    If Nz(F_StartRibbonName(), "") <> "" Then
    '        aktForma.RibbonName = RibbonNameZaIzabranuFormuIUsera(aktForma.Name) 'F_StartRibbonName()
    '        ' forsiraj refresh da se odmah vidi promena
    '        DoCmd.ShowToolbar "Ribbon", acToolbarYes
    '        CommandBars.ExecuteMso "MinimizeRibbon"
    '        CommandBars.ExecuteMso "MinimizeRibbon"
    '    End If
    'End If
    '*********************************************************
    '!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    
Exit Function
   
exit_BBPravaPristupaPodesiFormu:
    
    'Set TabPrava = Nothing
    'Set QTabPrava = Nothing
    'Set BigBit = Nothing
    'BB_PravaPristupaPodesiFormu = retval
Exit Function
err_BBPravaPristupaPodesiFormu:
    MsgBox err.Description & vbCrLf & "Prava pristupa nisu podesena.", vbExclamation, "MegaAPL"
    retVal = False
 Resume exit_BBPravaPristupaPodesiFormu
End Function

Public Function OtvoriFormuCFG_TabStop(Optional ZaFormu As Form) As Boolean
On Error Resume Next
Dim aktForma As Form
Dim aktivnaKontrola As control

If IsMissing(ZaFormu) Or ZaFormu Is Nothing Then
 Set aktForma = Screen.ActiveForm
 Set aktivnaKontrola = Screen.ActiveControl
Else
 Set aktForma = ZaFormu
 Set aktivnaKontrola = ZaFormu.ActiveControl
End If

Call BB_NapraviTabeluSvihKontrolaNaFormi(aktForma)
    BBOpenForm "CFG_TabStop"
 'Forms!CFG_TabStop.ImeUsera
 If Not (aktivnaKontrola Is Nothing) Then
  Forms!CFG_TabStop!ZaFormName = aktivnaKontrola.Parent.Name
  Forms!CFG_TabStop!FormName.DefaultValue = "'" & aktivnaKontrola.Parent.Name & "'"
  Forms!CFG_TabStop.ZaControlName = aktivnaKontrola.Name
  Forms!CFG_TabStop.ControlName.DefaultValue = "'" & aktivnaKontrola.Name & "'"
 Else
  Forms!CFG_TabStop!FormName.DefaultValue = "'" & aktForma.Name & "'"
  Forms!CFG_TabStop!ZaFormName = aktForma.Name
  'Forms!CFG_TabStop.ControlName.DefaultValue = "'[Form]'"
 End If

 'Forms!CFG_TabStop!ZaImeUsera = BBCFG.DefaultLimitedUser
 'Forms!CFG_TabStop!ImeForme.DefaultValue = "'" & aktForma.Name & "'"
 'DoCmd.GoToRecord acDataForm, "CFG_TabStop", acNewRec
 'Forms!CFG_TabStop!ImeKontrole = aktivnaKontrola.Name
 Forms!CFG_TabStop.Requery
 OtvoriFormuCFG_TabStop = True
End Function
'**********************************************************************
Public Function BB_CFG_TabStopPodesiFormu(ByRef aktForma As Form) As Boolean
On Error GoTo err_CFG_TabStopPodesiFormu

    Dim BigBit As DAO.Database
    'Dim QTabStop As DAO.QueryDef
    Dim rstTabStop As DAO.Recordset
    Dim ctlMasterForm As control
    Dim ctl As control
    Dim stSQLTabStop As String
    Dim CFG_TabStop_TableName As String
    
    Dim ZaFormu As String
    Dim retVal As Boolean
      
    retVal = True
    
    If Not BBCFG.SysTabStopPodesiFormu() Then
     BB_CFG_TabStopPodesiFormu = retVal
     Exit Function
    End If
    
    ZaFormu = aktForma.Name
    CFG_TabStop_TableName = BBCFG.SysCFG_TabStop_TableName() '"CFG_TabStop"
    
    'stSQLTabStop = "SELECT CFG_TabStop.* FROM CFG_TabStop WHERE ((([CFG_TabStop].[FormName])=[ZaFormu]));"
    stSQLTabStop = "SELECT [" & CFG_TabStop_TableName & "].* FROM [" & CFG_TabStop_TableName & "] WHERE ((([" & CFG_TabStop_TableName & "].[FormName])= """ & ZaFormu & """));"
    
    
    For Each ctlMasterForm In aktForma
        If ctlMasterForm.ControlType = acSubform Then
        '  BBDebug.DebugPrint "Radim TabStop za acSubform=" & ctlMasterForm.Name
          On Error Resume Next 'možda podforma nema sourceobject
          BB_CFG_TabStopPodesiFormu ctlMasterForm.Form
          err.Clear
          On Error GoTo err_CFG_TabStopPodesiFormu
        End If
    Next
    
    Set BigBit = CurrentDb
    'Set QTabStop = BigBit.QueryDefs("Q_BBCFG_TabStop")
    'QTabStop.Parameters("[ZaFormu]") = ZaFormu
    'Set rstTabStop = QTabStop.OpenRecordset(dbOpenDynaset, dbSeeChanges)
    Set rstTabStop = BigBit.OpenRecordset(stSQLTabStop, dbOpenDynaset, dbSeeChanges)
    rstTabStop.Sort = "ID"
    
    On Error Resume Next
    rstTabStop.MoveFirst
    On Error GoTo err_CFG_TabStopPodesiFormu
    While Not rstTabStop.EOF
            
        For Each ctl In aktForma.Controls
            If (ctl.Name = rstTabStop!ControlName) Then
                ctl.TabStop = rstTabStop!TabStop
            End If
        Next
       
        rstTabStop.MoveNext
        
    Wend
exit_CFG_TabStopPodesiFormu:
On Error Resume Next
    rstTabStop.Close
    Set rstTabStop = Nothing
    'Set QTabStop = Nothing
    Set BigBit = Nothing
    BB_CFG_TabStopPodesiFormu = retVal
Exit Function
err_CFG_TabStopPodesiFormu:
    If err = 2467 Then
    Else
     MsgBox err.Description & vbCrLf & "TabStop na formi nije podešen.", vbExclamation, "QMegaTeh"
    End If
    '& vbCrLf & "ctl.Name=" & ctl.Name & vbCrLf & "TabStop!ControlName = " & rstTabStop!ControlName
    retVal = False
 Resume exit_CFG_TabStopPodesiFormu
End Function
Function IsReadOnlyUser() As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    
    ' Ovde definišite uslov za read-only korisnike, na primer:
    If UserUGrupi(CurrentUser(), "ReadOnlyGroup") Then
        retValOk = True
    Else
        retValOk = False
    End If

Exit_Point:
    On Error Resume Next
    IsReadOnlyUser = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "IsReadOnlyUser"
    retValOk = False
    Resume Exit_Point
End Function
