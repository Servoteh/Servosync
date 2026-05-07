VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_dlgRokIzrade"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Public RokIzradeResult As Variant
Public DialogResultOK As Boolean


Private Sub cmdOK_Click()

    If Not IsDate(Me.txtRokIzrade) Then
        MsgBox "Morate uneti ispravan datum.", vbExclamation
        Exit Sub
    End If
    
    If CDate(Me.txtRokIzrade) < Date Then
        MsgBox "Rok izrade ne može biti u prošlosti.", vbExclamation
        Exit Sub
    End If
    
    gRokIzradeResult = CDate(Me.txtRokIzrade)
    gDialogResultOK = True
    
    DoCmd.Close acForm, Me.Name

End Sub


Private Sub cmdCancel_Click()

    gDialogResultOK = False
    gRokIzradeResult = Null
    
    DoCmd.Close acForm, Me.Name

End Sub


Private Sub Form_Load()

    gDialogResultOK = False
    gRokIzradeResult = Null
    
    Me.txtRokIzrade = Date + 7

End Sub



Private Sub txtRokIzrade_BeforeUpdate(Cancel As Integer)

    If IsDate(Me.txtRokIzrade) Then
    
        If Me.txtRokIzrade < Date Then
        
            MsgBox "Rok izrade ne može biti u prošlosti.", vbExclamation
            
            Cancel = True
            
        End If
        
    End If

End Sub

