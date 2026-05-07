VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_GdeSeCrtezKoristi"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub cmdStampajPDFCrtez_Click()
    Call StampajPDFCrtez_Binary( _
        Me!Podforma.Form!BrojCrteza, _
        Me!Podforma.Form!Revizija, _
        Me!Podforma.Form)

End Sub

Private Sub DugmePreview_Click()
    Call PreviewPDFCrtez_Binary(Me!Podforma.Form!BrojCrteza, _
                                Me!Podforma.Form!Revizija, _
                                Me!Podforma.Form)
End Sub

Private Sub DugmeSpisak_Click()
On Error GoTo Err_Dugme_Printuj_kalkul_Click

    Dim stDocName As String
    stDocName = "SpisakGdeSeDeoKoristi"
    
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
    If Me!Podforma1.SourceObject <> "Form.frmWhereUsed_Sub" Then
        Me!Podforma1.SourceObject = "Form.frmWhereUsed_Sub"
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

Private Sub Form_Open(Cancel As Integer)
'    DoCmd.MoveSize , , 8800
    Me!Rekurzivno = False
End Sub

Private Sub Rekurzivno_AfterUpdate()
    Me!Podforma.Form.PrimeniUslove
    On Error Resume Next
    ProsiriFormu
    Me!Podforma1.Form.InicijalizujSpolja   ' ponovo nacrtaj stablo po novom režimu
End Sub
Public Function ProsiriFormu()
 '   DoCmd.MoveSize , , Me.Width + 200
End Function
Public Sub PreviewTree(ByVal ZaIDCrtez As Long)
On Error GoTo Err_Handler
    
    
    Dim ID As Long
    ID = Nz(ZaIDCrtez, 0)
    
    If ID = 0 Then
        MsgBox "Nije zadat ID crteža (ZaIDCrtez je 0 ili Null).", vbInformation, "TreeView"
        Exit Sub
    End If

    ' 1) Postavi SourceObject subforme (ako veæ nije)
    If Me!Podforma1.SourceObject <> "Form.frmWhereUsed_Sub" Then
        Me!Podforma1.SourceObject = "Form.frmWhereUsed_Sub"
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

