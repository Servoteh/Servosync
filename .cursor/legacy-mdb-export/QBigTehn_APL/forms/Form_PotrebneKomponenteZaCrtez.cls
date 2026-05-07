VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PotrebneKomponenteZaCrtez"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private mStack As Collection
Private mCaptionBase As String
Public Sub PushStack(IDCrtez As Long, BrojCrteza As String, Revizija As String, _
                     BrojKomada As Long, Naziv As String)

    If mStack Is Nothing Then
        Set mStack = New Collection
    End If

    mStack.Add IDCrtez & "|" & BrojCrteza & "|" & Revizija & "|" & BrojKomada & "|" & Naziv

End Sub

Private Sub BrojKomadaZaIzradu_AfterUpdate()
    Me!Podforma.SourceObject = "ReklamniPanel"
    Me!Podforma.SourceObject = "PregledPotrebnihKomponentiZaCrtez"
End Sub
Private Sub cmdBack_Click()

    If mStack.Count <= 1 Then Exit Sub

    mStack.Remove mStack.Count

    Dim arr
    arr = Split(mStack(mStack.Count), "|")

    Call PregledPotrebnihKomponentiZaCrtez( _
        val(arr(0)), _
        arr(1), _
        arr(2), _
        val(arr(3)), _
        arr(4) _
    )

    Call OsveziCaption
    Call OsveziBackDugme
    
End Sub
Private Sub DugmeSastavnica_Click()
On Error GoTo Err_Dugme_Printuj_kalkul_Click

    Dim stDocName As String
    stDocName = "Sastavnica"
    
    Me.Visible = False
    
    DoCmd.OpenReport stDocName, acViewPreview
    
    While IsReportLoaded(stDocName)
        DoEvents
    Wend
    
    Me.Visible = True
    Me.SetFocus
        
    
    
Exit_Dugme_Printuj_kalkul_Click:
    Exit Sub

Err_Dugme_Printuj_kalkul_Click:
    If err.Number <> 2501 Then MsgBox Error$
    Resume Exit_Dugme_Printuj_kalkul_Click
End Sub

Private Sub DugmeStop_Click()
    DoCmd.Close
End Sub
Public Function PreviewTree(ByVal IDCrtez As Long) As Boolean
On Error GoTo Err_Handler
   
    Dim ID As Long
    'ID = Nz(Me!ZaIDCrtez, 0)
    ID = IDCrtez
    
    If ID = 0 Then
        MsgBox "Nije zadat ID crteža (ZaIDCrtez je 0 ili Null).", vbInformation, "TreeView"
        Exit Function
    End If

    ' 1) Postavi SourceObject subforme (ako veæ nije)
    If Me!Podforma1.SourceObject <> "Form.frmPDMTreeView_Sub" Then
        Me!Podforma1.SourceObject = "Form.frmPDMTreeView_Sub"
        DoEvents            ' da Access stigne da uèita formu u subformu
    End If

    ' 2) Prosledi ID subformi
    Me!Podforma1.Form.SetIDCrtez ID

Exit_Handler:
    Exit Function

Err_Handler:
    MsgBox "Greška: " & err.Number & " - " & err.Description, vbExclamation, "DugmeTree_Click"
    Resume Exit_Handler

End Function
Private Sub DugmeTree_Click()
On Error GoTo Err_Handler
    
    'ProsiriFormu
    
    Dim ID As Long
    ID = Nz(Me!ZaIDCrtez, 0)
    
    If ID = 0 Then
        MsgBox "Nije zadat ID crteža (ZaIDCrtez je 0 ili Null).", vbInformation, "TreeView"
        Exit Sub
    End If

    ' 1) Postavi SourceObject subforme (ako veæ nije)
    If Me!Podforma1.SourceObject <> "Form.frmPDMTreeView_Sub" Then
        Me!Podforma1.SourceObject = "Form.frmPDMTreeView_Sub"
        DoEvents            ' da Access stigne da uèita formu u subformu
    End If

    ' 2) Prosledi ID subformi
    Me!Podforma1.Form.SetIDCrtez ID

Exit_Handler:
    Exit Sub

Err_Handler:
    MsgBox "Greška: " & err.Number & " - " & err.Description, vbExclamation, "DugmeTree_Click"
    Resume Exit_Handler
End Sub

Private Sub Form_Load()

On Error GoTo Err_Handler

    Set mStack = New Collection
    
   ' mStack.Add Trim(Me!ZaIDCrtez) & "|" & _
               Trim(Me!BrojCrteza) & "|" & _
               Trim(Me!Revizija) & "|" & _
               Trim(Nz(Me!BrojKomadaZaIzradu, 1)) & "|" & _
               Trim(Me!Naziv)
           
    Call OsveziCaption
    Call OsveziBackDugme

Exit_Handler:
    Exit Sub

Err_Handler:
    MsgBox err.Description
    Resume Exit_Handler

End Sub
Private Sub Form_Open(Cancel As Integer)
'    DoCmd.MoveSize , , 8800
End Sub
Public Function ProsiriFormu()
 '   DoCmd.MoveSize , , Me.Width + 200
End Function


Private Sub TopLevelOnly_AfterUpdate()
    Me!Podforma.SourceObject = "ReklamniPanel"
    Me!Podforma.SourceObject = "PregledPotrebnihKomponentiZaCrtez"
End Sub
Private Sub DugmePreview_Click()
    Call PreviewPDFCrtez_Binary(Me!Podforma.Form!BrojCrteza, _
                                Me!Podforma.Form!Revizija, _
                                Me!Podforma.Form)
End Sub

Private Sub cmdStampajPDFCrtez_Click()

    Call StampajPDFCrtez_Binary( _
        Me!Podforma.Form!BrojCrteza, _
        Me!Podforma.Form!Revizija, _
        Me!Podforma.Form)


End Sub
Private Sub cmdStampajSvePDF_Click()
On Error GoTo Err_Handler

    Dim rs As DAO.Recordset
    Dim stBrojCrteza As String
    Dim stRevizija As String

    'uzmi recordset iz podforme
    Set rs = Me!Podforma.Form.RecordsetClone
    
    If rs.EOF Then
        MsgBox "Nema slogova za štampu.", vbInformation
        Exit Sub
    End If
    
    rs.MoveFirst
    
    Do While Not rs.EOF
    
        stBrojCrteza = Nz(rs!BrojCrteza, "")
        stRevizija = Nz(rs!Revizija, "")
        
        If stBrojCrteza <> "" And stRevizija <> "" Then
            Call StampajPDFCrtez_Binary(stBrojCrteza, stRevizija)
        End If
        
        rs.MoveNext
        
    Loop

Exit_Handler:
    On Error Resume Next
    rs.Close
    Set rs = Nothing
    Exit Sub

Err_Handler:
    MsgBox err.Description, vbCritical
    Resume Exit_Handler

End Sub
Private Sub cmdSastavnicaPodsklopa_Click()

    If Nz(Me!Podforma.Form!JeSklop, "") = "" Then
        MsgBox "Ovaj deo nema definisanu sastavnicu.", vbInformation
        Exit Sub
    End If

    mStack.Add _
        Me!Podforma.Form!IDCrtez & "|" & _
        Me!Podforma.Form!BrojCrteza & "|" & _
        Me!Podforma.Form!Revizija & "|" & _
        Nz(Me!Podforma.Form!BrojKomada, 1) & "|" & _
        Me!Podforma.Form!Naziv

    Call PregledPotrebnihKomponentiZaCrtez( _
            Me!Podforma.Form!IDCrtez, _
            Me!Podforma.Form!BrojCrteza, _
            Me!Podforma.Form!Revizija, _
            Nz(Me!Podforma.Form!BrojKomada, 1), _
            Me!Podforma.Form!Naziv _
    )

    Call OsveziCaption
    Call OsveziBackDugme
    
End Sub
Private Sub OsveziPutanju()

On Error GoTo Err_Handler

    Dim i As Long
    Dim arr
    Dim s As String

    s = ""

    For i = 1 To mStack.Count
        
        arr = Split(mStack(i), "|")
        
        If s <> "" Then s = s & " > "
        s = s & arr(4) ' Naziv
        
    Next i

    Me!txtPutanja = s

Exit_Handler:
    Exit Sub

Err_Handler:
    Resume Exit_Handler

End Sub
Private Sub OsveziBackDugme()

On Error Resume Next
    Me!cmdBack.Enabled = (mStack.Count > 1)

End Sub
Public Sub OsveziCaption()

On Error GoTo Err_Handler

    Dim i As Long
    Dim arr
    Dim s As String

    s = ""

    For i = 1 To mStack.Count
        arr = Split(mStack(i), "|")
        
        If s <> "" Then s = s & " > "
        s = s & arr(4)
    Next i

    Me.Caption = "Sastavnica delova: " & s

Exit_Handler:
    Exit Sub

Err_Handler:
    Resume Exit_Handler

End Sub
