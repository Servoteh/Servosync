VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBImport"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Dim ImportC As New BBImport_Class
Dim PripremljeniPodaci As Boolean

Public Function PripremiZaImport() As Boolean
On Error GoTo err_Func
Dim retValOk As Boolean
Dim tmpOk As Boolean
Dim stMsgError As String

PripremljeniPodaci = False

 If Nz(ImportC.ImeFajlaZaImport, "") = "" Then
  ImportC.ImeFajlaZaImport = OpenFileDialog()
 End If
 Me!IzFajla = Nz(ImportC.ImeFajlaZaImport, "")
 
 If Nz(ImportC.ImeFajlaZaImport, "") = "" Then
  retValOk = False
  Exit Function
 End If
 
 retValOk = ImportC.LinkTableToXLS()
 
 If retValOk Then
  tmpOk = ImportC.HasField("RBr")
  retValOk = retValOk And tmpOk
  If Not tmpOk Then stMsgError = stMsgError & vbCrLf & "RBr"
   
  tmpOk = ImportC.HasField("KatBroj")
  retValOk = retValOk And tmpOk
  If Not tmpOk Then stMsgError = stMsgError & vbCrLf & "KatBroj"
  
  tmpOk = ImportC.HasField("Naziv")
  retValOk = retValOk And tmpOk
  If Not tmpOk Then stMsgError = stMsgError & vbCrLf & "Naziv"
  
  tmpOk = ImportC.HasField("Kolicina")
  retValOk = retValOk And tmpOk
  If Not tmpOk Then stMsgError = stMsgError & vbCrLf & "Kolicina"
  
  tmpOk = ImportC.HasField("VPCena")
  retValOk = retValOk And tmpOk
  If Not tmpOk Then stMsgError = stMsgError & vbCrLf & "VPCena"
  
  tmpOk = ImportC.HasField("Jm")
  retValOk = retValOk And tmpOk
  If Not tmpOk Then stMsgError = stMsgError & vbCrLf & "Jm"
   
   If Not retValOk Then stMsgError = "Nedostaju kolone: " & vbCrLf & stMsgError
 Else
  stMsgError = "Podaci se ne mogu importovati!"
 End If
 
 
If retValOk Then
  Me!Podforma.SourceObject = "BBImport_ProfakturaStavkeZaImport_XLS"
Else
 MsgBox stMsgError, vbExclamation, "QMegaTeh"
End If
 
exit_Func:
On Error Resume Next
 PripremljeniPodaci = retValOk
 PripremiZaImport = retValOk
Exit Function
 
err_Func:
  BBErrorMSG err, "PripremiZaImport"
  Resume exit_Func:
End Function
Private Sub NapraviKontrolu_TEST()
    Dim frm As Form
    Dim ctlLabel As control, ctlText As control
    Dim intDataX As Integer, intDataY As Integer
    Dim intLabelX As Integer, intLabelY As Integer
    Dim ImeForme As String

    ' Create new form with Orders table as its record source.
    'Set frm = CreateForm()
    'frm.RecordSource = "Orders"
    ImeForme = "BBImport_ViewLinkedTable"
    DoCmd.OpenForm ImeForme, acDesign, , , , acIcon
    Set frm = Application.Forms(ImeForme)
    
    'frm.RecordSource = "Orders"
    ' Set positioning values for new controls.
    'intLabelX = 100
    'intLabelY = 100
    'intDataX = 1000
    'intDataY = 100
    ' Create unbound default-size text box in detail section.
    Set ctlText = CreateControl(frm.Name, acTextBox, , "", "", intDataX, intDataY)
    'Forms!Customers!AddressPart.ControlSource = "City"
    ctlText.ControlSource = "Rbr"
    'ctlText.so
    ' Create child label control for text box.
    Set ctlLabel = CreateControl(frm.Name, acLabel, , ctlText.Name, "Rbr", intLabelX, intLabelY)
    ' Restore form.
    DoCmd.OpenForm ImeForme
End Sub
Private Sub NapraviKontrole_TEST()
    Dim frm As Form
    Dim ctlLabel As control, ctlText As control
    Dim intDataX As Integer, intDataY As Integer
    Dim intLabelX As Integer, intLabelY As Integer
    'Dim tFiled As Field
    Dim ImeForme As String
    Dim rst As DAO.Recordset
    Dim i As Integer
    
    ' Create new form with Orders table as its record source.
    'Set frm = CreateForm()
    'frm.RecordSource = "Orders"
    ImeForme = "BBImport_ViewLinkedTable"
    DoCmd.OpenForm ImeForme, acDesign, , , , acIcon
    'DoCmd.OpenForm ImeForme, acNormal, , , , acIcon
    Set frm = Application.Forms(ImeForme)
    
    While frm.Controls.Count > 0
     For Each ctlText In frm.Controls
      'Debug.Print "deletede=" & ctlText.Name
      DeleteControl frm.Name, ctlText.Name
     Next ctlText
    Wend
    
    Set rst = CurrentDb.OpenRecordset("~tmp_T_Linked~")
    For i = 0 To rst.Fields.Count - 1
    'frm.RecordSource = "Orders"
    ' Set positioning values for new controls.
    'intLabelX = 100
    'intLabelY = 100
    'intDataX = 1000
    'intDataY = 100
    ' Create unbound default-size text box in detail section.
    Set ctlText = CreateControl(frm.Name, acTextBox, , "", "", intDataX, intDataY)
    ctlText.ControlSource = rst.Fields(i).Name
    Set ctlLabel = CreateControl(frm.Name, acLabel, , ctlText.Name, rst.Fields(i).Name, intLabelX, intLabelY)
    'Debug.Print frm.Recordset.Fields(i).Name
    Next i
    rst.Close
    Set rst = Nothing
    DoCmd.OpenForm ImeForme
End Sub
Private Sub PrikaziDataSheetFormu()
    Dim frm As Form
    Dim ctlLabel As control, ctlText As control
    Dim ImeForme As String
    Dim rst As DAO.Recordset
    Dim i As Integer
    
    ' Create new form with Orders table as its record source.
    Set frm = CreateForm()
    'frm.Name = "~tmpForm~"
    frm.DefaultView = AcDefView.acDefViewDatasheet
    frm.RecordSource = "~tmp_T_Linked~"
        
    While frm.Controls.Count > 0
     For Each ctlText In frm.Controls
      'Debug.Print "deletede=" & ctlText.Name
      DeleteControl frm.Name, ctlText.Name
     Next ctlText
    Wend
    
    Set rst = CurrentDb.OpenRecordset("~tmp_T_Linked~")
    For i = 0 To rst.Fields.Count - 1
    'frm.RecordSource = "Orders"
    ' Set positioning values for new controls.
    'intLabelX = 100
    'intLabelY = 100
    'intDataX = 1000
    'intDataY = 100
    ' Create unbound default-size text box in detail section.
    'Set ctlText = CreateControl(frm.Name, acTextBox, , "", "", intDataX, intDataY)
    Set ctlText = CreateControl(frm.Name, acTextBox)
    ctlText.ControlSource = rst.Fields(i).Name
    'Set ctlLabel = CreateControl(frm.Name, acLabel, , ctlText.Name, rst.Fields(i).Name, intLabelX, intLabelY)
    Set ctlLabel = CreateControl(frm.Name, acLabel, , ctlText.Name, rst.Fields(i).Name)
    'Debug.Print frm.Recordset.Fields(i).Name
    Next i
    rst.Close
    Set rst = Nothing
    DoCmd.OpenForm frm.Name
    
End Sub
Private Sub DugmePrikaziFajlZaImport_Click()
' PrikaziDataSheetFormu
 ImportC.ShowLinkedTable
End Sub

Private Sub DugmePripremiPodatke_Click()
 PripremiZaImport
End Sub

Private Sub Form_Close()
' Set Import = Null
End Sub

Private Sub Form_Open(Cancel As Integer)
   Me!IzFajla = ImportC.ImeFajlaZaImport
   PripremljeniPodaci = False
End Sub

Private Sub IzFajla_AfterUpdate()
    ImportC.ImeFajlaZaImport = Me!IzFajla
End Sub

Private Sub IzFajla_DblClick(Cancel As Integer)
      ImportC.ImeFajlaZaImport = OpenFileDialog("Izaberite fajl za import")
      Me!IzFajla = ImportC.ImeFajlaZaImport
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
Private Sub DugmeUpisiUProf_Click()
On Error GoTo Err_DugmeUpisiUProf_Click
 Dim retValOk As Boolean
 Dim Neuspesno As Long

    retValOk = True
    
    
    If Not PripremljeniPodaci Then
       MsgBox "Morate prvo pripremiti podatke.", vbExclamation, "QMegaTeh"
       Exit Sub
    End If
    
    If Not IsLoaded("Profaktura") Then
     MsgBox "Nemate otvorenu profakturu.", vbExclamation, "QMegaTeh"
     retValOk = False
     Exit Sub
    End If
    
    If Not IsNumeric(Forms!Profaktura!IDDok) Then
     MsgBox "Morate uneti zaglavlje profakture.", vbExclamation, "QMegaTeh"
     retValOk = False
     Exit Sub
    End If
    
    Neuspesno = 0
    retValOk = ImportC.UpisiUProfakturuStavke(Forms!Profaktura!IDDok, Forms!Profaktura!IDMagacinDOK, Neuspesno)
    Forms!Profaktura![Profaktura - Podforma].Requery
    If Not retValOk Then
     MsgBox "NIJE upisano " & stR(Neuspesno) & " artikala." & vbCrLf & "PROVERITE!", vbExclamation, "QMegaTeh"
    Else
     MsgBox "Uspešno upisano.", vbInformation, "QMegaTeh"
    End If
    DoCmd.Close acForm, "BBImport"
    
Exit_DugmeUpisiUProf_Click:
    Exit Sub

Err_DugmeUpisiUProf_Click:
    MsgBox err.Description
    retValOk = False
    Resume Exit_DugmeUpisiUProf_Click
    
End Sub
