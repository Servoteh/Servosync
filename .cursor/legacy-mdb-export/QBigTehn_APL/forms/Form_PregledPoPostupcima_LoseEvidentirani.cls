VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PregledPoPostupcima_LoseEvidentirani"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function PrimeniUslove()
   BBTimerStart
    SetProperlyRecordSource BBCFG.CNNString, Me
   Me!LabelTrajanjeUpita.Caption = BBTimerTrajanjeSec("Query=")
End Function
Private Sub BrojPredmeta_DblClick(Cancel As Integer)
    Forms![PregledPoPostupcima]!ZaPredmet = Me!IDPredmet
    PrimeniUslove
End Sub

Private Sub DetaljnoDokumentPoKucanju_Click()
 Dim ID As Variant
    ID = RNFromIdentBroj(Me!IdentBroj)
    
    If ID = -1 Then
        MsgBox "Nema RN za ovaj IdentBroj"
    ElseIf ID = 0 Then
        MsgBox "Ima više RN za ovaj IdentBroj"
    Else
        PrikaziDokRN ID
    End If
End Sub

Private Sub DetaljnodokumentPoUnosu_Click()
    Dim ID As Variant
    ID = RNFromIdentBroj(Me!IdentBroj_RN)
    
    If ID = -1 Then
        MsgBox "Nema RN za ovaj IdentBroj"
    ElseIf ID = 0 Then
        MsgBox "Ima više RN za ovaj IdentBroj"
    Else
        PrikaziDokRN ID
    End If
End Sub

Private Sub DugmeKarticaPoKucanju_Click()
Dim ID As Variant
    ID = RNFromIdentBroj(Me!IdentBroj)
    
    If ID = -1 Then
        MsgBox "Nema RN za ovaj IdentBroj"
    ElseIf ID = 0 Then
        MsgBox "Ima više RN za ovaj IdentBroj"
    Else
        KarticaTehnoloskogPostupka ID
    End If
End Sub

Private Sub DugmeKarticaPoUnosu_Click()
    Dim ID As Variant
    ID = RNFromIdentBroj(Me!IdentBroj_RN)
    
    If ID = -1 Then
        MsgBox "Nema RN za ovaj IdentBroj"
    ElseIf ID = 0 Then
        MsgBox "Ima više RN za ovaj IdentBroj"
    Else
        KarticaTehnoloskogPostupka ID
    End If
End Sub

Private Sub DugmeOtvoriTehPostupakPoKucanju_Click()
Dim ID As Long
    ID = RNFromIdentBroj(Me!IdentBroj)
    
    If ID = -1 Then
        MsgBox "Nema RN za ovaj IdentBroj"
    ElseIf ID = 0 Then
        MsgBox "Ima više RN za ovaj IdentBroj"
    Else
        OtvoriTehPostupkeZaIDRN ID
    End If
End Sub

Private Sub DugmeOtvoriTehPostupakPoUnosu_Click()
    Dim ID As Long
    ID = RNFromIdentBroj(Me!IdentBroj_RN)
    
    If ID = -1 Then
        MsgBox "Nema RN za ovaj IdentBroj"
    ElseIf ID = 0 Then
        MsgBox "Ima više RN za ovaj IdentBroj"
    Else
        OtvoriTehPostupkeZaIDRN ID
    End If

End Sub

Private Sub DugmePostupci_Click()
    Dim ID As Long
    ID = RNFromIdentBroj(Me!IdentBroj)
    
    If ID = -1 Then
        MsgBox "Nema RN za ovaj IdentBroj"
    ElseIf ID = 0 Then
        MsgBox "Ima više RN za ovaj IdentBroj"
    Else
        OtvoriStavkeRNZaIDRN ID
    End If

End Sub

Private Sub DugmeStavke_Click()
    Dim ID As Long
    ID = RNFromIdentBroj(Me!IdentBroj_RN)
    
    If ID = -1 Then
        MsgBox "Nema RN za ovaj IdentBroj"
    ElseIf ID = 0 Then
        MsgBox "Ima više RN za ovaj IdentBroj"
    Else
        OtvoriStavkeRNZaIDRN ID
    End If

End Sub

Private Sub DugmeUpdateVarijanta_Click()
    If Me!IdentBroj_RN = Me!IdentBroj Then
        If UpdateVarijanta(Me!IDRN) Then
            PrimeniUslove
        End If
    Else
        MsgBox "Broj naloga nije isti"
    End If
End Sub

Private Sub Form_Load()
    PrimeniUslove
End Sub

Private Sub IdentBroj_DblClick(Cancel As Integer)
    Forms![PregledPoPostupcima]!ZaIdentBroj = Me!IdentBroj
    PrimeniUslove
End Sub
Private Sub RJgrupaRC_DblClick(Cancel As Integer)
    Forms![PregledPoPostupcima]!ZaRJgrupaRC = Me!RJgrupaRC
    PrimeniUslove
End Sub

Private Sub DugmeObrisiPostupak_Click()
On Error GoTo Err_DugmeObrisiPostupak_Click
    
    If BBPitanje("Ovim brišete izabrani slog, tj. operaciju. Da li nastavljate?") Then
        Call ADO_ExecSP(CNN_CurrentDataBase, "spObrisiTP", Me!IDPostupka)
        PrimeniUslove
    End If
    
Exit_DugmeObrisiPostupak_Click:
    Exit Sub

Err_DugmeObrisiPostupak_Click:
    MsgBox err.Description
    Resume Exit_DugmeObrisiPostupak_Click
    
End Sub
Public Function RNFromIdentBroj(ByVal IdentBroj As String) As Variant
    Dim n As Variant
    Dim IDRN As Variant

    ' 1) Koliko RN postoji za dati IdentBroj?
    n = ADO_Lookup(CNN_CurrentDataBase(), "Count(*)", "tRN", "IdentBroj = '" & Replace(IdentBroj, "'", "''") & "'")

    If IsNull(n) Or n = 0 Then
        RNFromIdentBroj = -1
        Exit Function
    End If

    If n > 1 Then
        RNFromIdentBroj = 0
        Exit Function
    End If

    ' 2) Pošto je = 1 › uzmi IDRN
    IDRN = ADO_Lookup(CNN_CurrentDataBase(), "IDRN", "tRN", "IdentBroj = '" & Replace(IdentBroj, "'", "''") & "'")
    
    RNFromIdentBroj = IDRN
End Function
Public Function UpdateVarijanta(IDRN As Long) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim stWhere As String
    stWhere = "IDRN = " & Me!IDRN
    
    retValOk = ADO_UpdateColumn(CNN_CurrentDataBase, "tTehPostupak", "Varijanta", Me!Varijanta_RN, stWhere)
     
Exit_Point:
 On Error Resume Next
 UpdateVarijanta = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "UpdateVarijanta"
    retValOk = False
    Resume Exit_Point
    
End Function
Public Sub OtvoriTehPostupkeZaIDRN(IDRN As Long)

    DoCmd.OpenTable "tTehPostupak", acViewNormal   'datasheet view
    DoCmd.ApplyFilter , "IDRN = " & IDRN

End Sub

Public Sub OtvoriStavkeRNZaIDRN(IDRN As Long)

    DoCmd.OpenTable "tStavkeRN", acViewNormal   'datasheet view
    DoCmd.ApplyFilter , "IDRN = " & IDRN

End Sub
