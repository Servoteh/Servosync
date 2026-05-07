VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_BBCFG"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Private Function ImaIzmena() As Boolean
 On Error GoTo Err_Point
 Dim ctl As control
 Dim retValImaIzmena  As Boolean
 
 retValImaIzmena = False
 
 For Each ctl In Me.Controls
    If ctl.tag Like "CFG*" Then
     retValImaIzmena = retValImaIzmena Or (Nz(ctl.Value, "") <> Nz(ReadParametar(ctl.tag, ctl.Name), ""))
    End If
 Next ctl
 
Exit_Point:
ImaIzmena = retValImaIzmena
Exit Function

Err_Point:
 BBErrorMSG err, "ImaIzmena"
 retValImaIzmena = True
 Resume Exit_Point
End Function
Private Function ProcitajSveCFGVrednosti() As Boolean
On Error GoTo Err_Point
 Dim ctl As control
 Dim retValOk  As Boolean
 
 retValOk = True
 
 For Each ctl In Me.Controls
    If ctl.tag Like "CFG*" Then
     ctl.Value = ReadParametar(ctl.tag, ctl.Name, , Me!ZaIDFirma)
    End If
 Next ctl
 
Exit_Point:
ProcitajSveCFGVrednosti = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ProcitajSveCFGVrednosti"
 retValOk = False
 Resume Exit_Point
End Function
Private Function ZapamtiSveCFGVrednosti() As Boolean
On Error GoTo Err_Point
 Dim ctl As control
 Dim retValOk  As Boolean
 
 retValOk = True
 
 For Each ctl In Me.Controls
    If ctl.tag Like "CFG*" Then
     'ctl.Value = ReadParametar(ctl.tag, ctl.Name)
     retValOk = retValOk And WriteParametar(ctl.tag, ctl.Name, ctl.Value, Me!ZaIDFirma)
    End If
 Next ctl
 
 'i postavi nove parametre
 Set BBCFG = Nothing
 Call F_AFNaziv
   
Exit_Point:
ZapamtiSveCFGVrednosti = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ZapamtiSveCFGVrednosti"
 retValOk = False
 Resume Exit_Point
End Function

Private Sub AktivnaFirma_AfterUpdate()
    Me!ZaIDFirma = Me!AktivnaFirma
    ProcitajSveCFGVrednosti
End Sub

Private Sub Form_Close()
If ImaIzmena Then
 If BBPitanje("Da li želite da sacuvate izmene?") Then
   ZapamtiSveCFGVrednosti
 End If
End If
End Sub

Private Sub Form_Open(Cancel As Integer)
 
 
 Set AktivnaFirma.Recordset = RST_Combo(CNN_CurrentDataBase, "Radni fajlovi", "", "IDBaze", "IDBaze", "Firma")
 Set ZaIDFirma.Recordset = RST_Combo(CNN_CurrentDataBase, "Radni fajlovi", "", "IDBaze", "IDBaze", "Firma")
    
 Me!ZaIDFirma = BBCFG.Firma.IDFirma
 Me!AktivnaFirma = BBCFG.Firma.IDFirma 'BBCFG.Firma.Naziv
 
 ProcitajSveCFGVrednosti
 
End Sub
Private Sub DugmeStop_Click()
On Error GoTo Err_DugmeStop_Click


   ' If Me.Dirty Then Me.Dirty = False
    DoCmd.Close

Exit_DugmeStop_Click:
    Exit Sub

Err_DugmeStop_Click:
    MsgBox err.Description
    Resume Exit_DugmeStop_Click
    
End Sub
Private Sub SnimiParametre_Click()
On Error GoTo Err_SnimiParametre_Click


    ZapamtiSveCFGVrednosti
    
Exit_SnimiParametre_Click:
    Exit Sub

Err_SnimiParametre_Click:
    MsgBox err.Description
    Resume Exit_SnimiParametre_Click
    
End Sub

Private Sub ZaIDFirma_AfterUpdate()
    Me!AktivnaFirma = Me!ZaIDFirma
    ProcitajSveCFGVrednosti
End Sub
