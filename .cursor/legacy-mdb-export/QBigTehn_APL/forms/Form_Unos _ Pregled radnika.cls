VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Unos / Pregled radnika"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database   'Use database order for string comparisons
Option Explicit
Public Function PrimeniUslove()
    Me.Requery
End Function


Private Sub Dugme_Novi_prodavac_Click()
On Error GoTo Err_Dugme_Novi_prodavac_Click


    DoCmd.GoToRecord , , A_NEWREC
    DoCmd.GoToControl "Radnik"

Exit_Dugme_Novi_prodavac_Click:
    Exit Sub

Err_Dugme_Novi_prodavac_Click:
    MsgBox Error$
    Resume Exit_Dugme_Novi_prodavac_Click
    
End Sub

Private Sub Dugme_Stop_Click()
On Error GoTo Err_Dugme_stop_Click


    DoCmd.Close

Exit_Dugme_stop_Click:
    Exit Sub

Err_Dugme_stop_Click:
    MsgBox Error$
    Resume Exit_Dugme_stop_Click
    
End Sub

Private Sub DugmeSnimiSlog_Click()
On Error GoTo Err_DugmeSnimiSlog_Click


    DoCmd.DoMenuItem acFormBar, acRecordsMenu, acSaveRecord, , acMenuVer70

Exit_DugmeSnimiSlog_Click:
    Exit Sub

Err_DugmeSnimiSlog_Click:
    MsgBox err.Description
    Resume Exit_DugmeSnimiSlog_Click
    
End Sub

Private Sub DugmeTest_Click()
    SetClipboard Me!IDKartice
End Sub

Private Sub Form_Open(Cancel As Integer)
    'Call BB_PravaPristupaPodesiFormu(Me)
    DoCmd.Maximize
     If UserUGrupi(CurrentUser(), "Admins") Then
        Me!DugmeTest.Visible = True
    Else
        Me!DugmeTest.Visible = False
    End If
    Me!CheckAktivan = True
    Me.Requery
End Sub

Private Sub Password_DblClick(Cancel As Integer)
    If Me!Password.InputMask = "" Then
        Me!Password.InputMask = "Password"
    Else
        Me!Password.InputMask = ""
    End If
End Sub
Private Function IzaberiSliku(Optional ZagStr = "Izaberite fajl") As Variant
Dim lngFlags As Long
Dim ImeFajla As Variant
    Dim gfni As adh_accOfficeGetFileNameInfo
    
    On Error GoTo HandleErrors

    With gfni
        .lngFlags = lngFlags
        .strFilter = "BMP,JPG Files (*.*)"
        .lngFilterIndex = CInt("1")
        .strFile = ""
        .strDlgTitle = ZagStr
        .strOpenTitle = "Select"
        .strFile = ""
        .strInitialDir = PutanjaDoFajla(Application.CurrentDb.Name)
        '.strFile = "Z:\HALCOM\"
        '.strInitialDir = Forms![FX_HAL_KnjizenjeIzvoda]!ImportIzFajla
        
    End With
    If adhOfficeGetFileName(gfni, True) = adhcAccErrSuccess Then
        ImeFajla = Trim(gfni.strFile)
    Else
        ImeFajla = Null
    End If
    
ExitHere:
    IzaberiSliku = ImeFajla
    Exit Function

HandleErrors:    DoCmd.GoToControl ("Sifra")
    DoCmd.FindRecord (Me![PronadjiPoNazivu])
    Me![PronadjiPoNazivu] = Null
    DoCmd.GoToControl ("PronadjiPoNazivu")

    MsgBox "Error: " & err.Description & " (" & err.Number & ")"
    Resume ExitHere
End Function
Private Sub PotpisSlika_DblClick(Cancel As Integer)
    Dim IzabraniFajl
    IzabraniFajl = IzaberiSliku()
    If Not IsNull(IzabraniFajl) Then Me!PotpisSlika = IzabraniFajl
End Sub

Private Sub PronadjiPoNazivu_AfterUpdate()
    DoCmd.GoToControl ("SifraRadnika")
    DoCmd.FindRecord (Me![PronadjiPoNazivu])
    Me![PronadjiPoNazivu] = Null
    DoCmd.GoToControl ("IDKartice")
End Sub

Private Sub ZaIDVrsteRadnika_AfterUpdate()
    Me.Requery
End Sub

Private Sub ZaRadnuJedinicu_AfterUpdate()
    Me.Requery
End Sub
