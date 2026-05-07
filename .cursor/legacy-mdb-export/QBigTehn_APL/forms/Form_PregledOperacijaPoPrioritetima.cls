VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledOperacijaPoPrioritetima"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Dim aktivnaForma As Form
Dim aktivanreport As Report
Dim aktivnaKontrola  As control
Public Function PrimeniUslove(Optional nIDStavkeRN As Long = 0)
    
    BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
    Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
    
End Function

Private Sub Form_Open(Cancel As Integer)
    PrimeniUslove
End Sub

Private Sub Form_Current()
    If Me!Prioritet.Value <> Me!Prioritet.OldValue Then
        Me!Prioritet.ForeColor = vbRed
        Me!Prioritet.FontBold = True
    End If
End Sub

Private Sub Prioritet_GotFocus()
    DoCmd.GoToControl "PrioritetUnos"
End Sub

Private Sub PrioritetUnos_AfterUpdate()
    Dim sledeciIDStavkeRN As Long
    sledeciIDStavkeRN = Nz(ADO_GetValFromUDFS(CNN_CurrentDataBase, "fsIDStavkeRNSledecegSlogaPreUpdataPrioriteta", _
                            Forms![PregledPoPredmetima]![OdDatumaNaloga], _
                            Forms![PregledPoPredmetima]![DoDatumaNaloga], _
                            Forms![PregledPoPredmetima]![OdDatumaPredmeta], _
                            Forms![PregledPoPredmetima]![DoDatumaPredmeta], _
                            Forms![PregledPoPredmetima]![ZaIdentBroj], _
                            Forms![PregledPoPredmetima]![ZaPredmet], _
                            Forms![PregledPoPredmetima]![ZaKomitenta], _
                            Forms![PregledPoPredmetima]![LansiranRN], _
                            Forms![PregledPoPredmetima]![ZaBrCrteza], _
                            Forms![PregledPoPredmetima]![ZaNazivDela], _
                            Forms![PregledPoPredmetima]![ZaMaterijal], _
                            Forms![PregledPoPredmetima]![ZaDimMaterijala], _
                            Forms![PregledPoPredmetima]![SaglasanRN], _
                            Forms![PregledPoPredmetima]![ZaVezaSa], _
                            Forms![PregledPoPredmetima]![ZaIDVrstaKvaliteta], _
                            Forms![PregledPoPredmetima]![StatusRN], _
                            Forms![PregledPoPredmetima]![ZaVarijanta], _
                            Forms![PregledPoPredmetima]![ZaRevizija], _
                            Me!IDStavkeRN), 0)

    Call ADO_UpdateColumn(CNN_CurrentDataBase, "tStavkeRN", "Prioritet", Me!PrioritetUnos, "IDStavkeRN = " & Me!IDStavkeRN)
    PrimeniUslove
    'MsgBox sledeciIDStavkeRN
    If Not IsNull(sledeciIDStavkeRN) Then
        With Me.RecordsetClone
            .FindFirst "IDStavkeRN=" & sledeciIDStavkeRN
            If Not .NoMatch Then Me.Bookmark = .Bookmark
        End With
    End If
    'Me!Prioritet.SetFocus
End Sub

Private Sub PrioritetUnos_GotFocus()
    Me!PrioritetUnos = Me!Prioritet
End Sub
' U modulu vaše podforme:
Private Sub PrioritetUnosChatGPT_AfterUpdate()
    Dim cnn As ADODB.Connection
    Dim rs       As ADODB.Recordset
    Dim currID   As Long
    Dim nextID   As Long
    Dim recNum   As Long
    
    ' 1) Zapamti trenutni IDStavkeRN
    currID = Me!IDStavkeRN
    
    ' 2) Naði sljedeæi IDStavkeRN u trenutnom poretku
    Set cnn = New ADODB.Connection
    cnn.Open CNN_CurrentDataBase 'CurrentProject.Connection.ConnectionString
    rs.ActiveConnection = cnn
    
    'Set rs = New ADODB.Recordset
    'Set cnn = CurrentProject.Connection
    With rs
        .CursorLocation = adUseClient
        .Open Me.RecordSource, cnn, adOpenStatic, adLockReadOnly
        
        ' pozicije su 0-based; prvo naði current
        .Find "IDStavkeRN=" & currID, , adSearchForward
        If Not .EOF Then
            .MoveNext
            If Not .EOF Then
                nextID = .Fields("IDStavkeRN").Value
            End If
        End If
        .Close
    End With
    
    MsgBox "tekuci ID=" & currID & vbCrLf & "sledeci ID=" & nextID
    'Exit Sub
    
    ' 3) Ažuriraj Prioritet u bazi
    'ADO_UpdateColumn "tStavkeRN", "Prioritet", Me!PrioritetUnos, currID
    Call ADO_UpdateColumn(CNN_CurrentDataBase, "tStavkeRN", "Prioritet", Me!PrioritetUnos, "IDStavkeRN = " & Me!IDStavkeRN)
    
    ' 4) Osveži prikaz (re-sort po Prioritetu)
    'Me.Requery
    PrimeniUslove
    ' 5) Ponavljamo otvaranje ADO recordseta da dobijemo novu poziciju nextID
    If nextID > 0 Then
        Set rs = New ADODB.Recordset
        With rs
            .CursorLocation = adUseClient
            .Open Me.RecordSource, cnn, adOpenStatic, adLockReadOnly
            
            .Find "IDStavkeRN=" & nextID, , adSearchForward
            If Not .EOF Then
                recNum = .AbsolutePosition '+ 1   ' 1-based za GoToRecord
                DoCmd.GoToRecord , , acGoTo, recNum
            End If
            
            .Close
        End With
    End If
    
    ' 6) Vrati fokus na unos za novi prioritet
    'Me!PrioritetUnos = Null
    'Me!PrioritetUnos.SetFocus
    
    ' cleanup
    Set rs = Nothing
    Set cnn = Nothing
End Sub

