Attribute VB_Name = "ZaRecnik"
Option Compare Database
Option Explicit

Public Function UkloniSpecZnake1(txtSrpski) As String
Dim retVal As String
retVal = txtSrpski
While InStr(retVal, "&") <> 0
    retVal = Left$(retVal, InStr(retVal, "&") - 1) & Right(retVal, Len(retVal) - InStr(retVal, "&"))
Wend
UkloniSpecZnake1 = retVal
End Function
Public Function UkloniSpecZnake(ByVal txtSrpski) As String
Dim retVal As String
Dim Znak As String
Dim ordznak As Integer
Dim i As Integer
retVal = ""
txtSrpski = Nz(txtSrpski, "")
For i = 1 To Len(txtSrpski)
    Znak = Mid$(txtSrpski, i, 1)
    ordznak = Asc(Znak)
    If Znak = " " Or Znak = "/" Or Znak = "-" Or Znak = "%" Or Znak = "(" Or Znak = ")" Or ordznak >= 46 Then
        retVal = retVal & Znak
    End If
Next i
UkloniSpecZnake = retVal
End Function
Public Function VratiPrevediTabCTL(ByRef ctl As TabControl)
 Dim i As Integer
 
  For i = 1 To ctl.Pages.Count
    
    ctl.Pages(i - 1).Caption = ctl.Pages(i - 1).tag
    
  Next i
  
End Function
Public Function PrevediTabCTL(ByRef ctl As TabControl, ByVal IDSaJezika As Long, ByVal IDNaJezik As Long, Optional ByVal UradiPrevedRecPoRec As Boolean = False)
 Dim i As Integer
 
  For i = 1 To ctl.Pages.Count
    
    ctl.Pages(i - 1).tag = ctl.Pages(i - 1).Caption
    ctl.Pages(i - 1).Caption = PrevediText(ctl.Pages(i - 1).Caption, IDSaJezika, IDNaJezik)
    
  Next i
  
End Function
Public Function PrevediFormuIliReport(ByRef frm As Object, ByVal IDSaJezika As Long, ByVal IDNaJezik As Long, Optional ByVal UradiPrevedRecPoRec As Boolean = False)
Dim ctl As control
Dim i As Integer

'For i = 0 To frm.Properties.Count - 1
'    Debug.Print i, "    ", frm.Properties(i).Name, frm.Properties(i)
'Next
If frm.tag = "Prevedeno sa " & CStr(IDSaJezika) & " na " & CStr(IDNaJezik) Then
' VEC JE PREVEDENO
 Exit Function
End If
If (IDSaJezika <> IDNaJezik) Then
    frm.tag = "Prevedeno sa " & CStr(IDSaJezika) & " na " & CStr(IDNaJezik)
    For Each ctl In frm
      'For i = 0 To ctl.Properties.Count
      '  Debug.Print i, "    ", ctl.Properties(i), ctl.Properties(i).Name
      'Next
    'Debug.Print ctl.Properties("ControlType"), IIf(ctl.Properties("ControlType") = acLabel, "Jeste", "Nije")
        If ctl.Properties("ControlType") = acLabel _
        Or ctl.Properties("ControlType") = acCommandButton Then
            
            If ctl.Properties("ControlType") = acTabCtl Then
            End If
            
            ctl.Properties("Tag") = ctl.Properties("Caption")
            ctl.Properties("Caption") = PrevediText(ctl.Properties("Caption"), IDSaJezika, IDNaJezik)
            
            If UradiPrevedRecPoRec Then
                If ctl.Properties("Tag") = ctl.Properties("Caption") Then
                    ctl.Properties("Caption") = PrevediRecPoRec(ctl.Properties("Caption"), IDSaJezika, IDNaJezik, False)
                End If
            End If
            
        End If
 
        If ctl.Properties("ControlType") = acTabCtl Then
         PrevediTabCTL ctl, IDSaJezika, IDNaJezik, UradiPrevedRecPoRec
        End If
        
        If ctl.Properties("ControlType") = acSubform Then
        On Error Resume Next
              PrevediFormuIliReport ctl.Form, IDSaJezika, IDNaJezik, UradiPrevedRecPoRec
        End If
    Next
 Else
   'MsgBox "Nekorektno zadati parametri za Sub PrevediFormu!", vbCritical, "QMegaTeh"
End If
End Function
Public Function F_PrevediFormuIliReport(ByRef frm As Object, ByVal IDSaJezika As Long, ByVal IDNaJezik As Long)
    PrevediFormuIliReport frm, IDSaJezika, IDNaJezik
End Function
Public Sub VratiPrevodForme(ByRef frm As Object)
Dim ctl As control
Dim i As Integer

    If Not (frm.tag Like "Prevedeno*") Then
        PrevediFormuIliReport frm, 0, F_IDNaJezik()
        Exit Sub
    End If
    
    frm.tag = "Vraæen prevod"
    
    For Each ctl In frm
      'For i = 0 To ctl.Properties.Count
      '  Debug.Print i, "    ", ctl.Properties(i), ctl.Properties(i).Name
      'Next
    'Debug.Print ctl.Properties("ControlType"), IIf(ctl.Properties("ControlType") = acLabel, "Jeste", "Nije")
        If ctl.Properties("ControlType") = acLabel Or ctl.Properties("ControlType") = acCommandButton Then
            ctl.Properties("Caption") = ctl.Properties("Tag")
        End If
        If ctl.Properties("ControlType") = acTabCtl Then
            VratiPrevediTabCTL ctl
        End If
        
        If ctl.Properties("ControlType") = acSubform Then
        On Error Resume Next
              VratiPrevodForme ctl.Form
        End If
        
    Next
End Sub
Public Function VratiPrevodAktivneForme()
Dim frm As Form
On Error Resume Next
  Set frm = Screen.ActiveForm
  VratiPrevodForme frm
End Function
Public Function PrevediAktivnuFormu(Optional IDNaJezik As Long = -1)
Dim frm As Form
On Error Resume Next
  If IDNaJezik = -1 Then IDNaJezik = F_IDNaJezik()
  Set frm = Screen.ActiveForm
  PrevediFormuIliReport frm, 0, IDNaJezik
End Function

Public Function Prevedi(RecSaJezika As Variant, Optional IDSaJezika As Long = 0, Optional IDNaJezik As Long = -1) As String
On Error GoTo Err_Point
Dim stRetVal As String

    
    stRetVal = Nz(RecSaJezika, "")
    
    If IDNaJezik = -1 Then IDNaJezik = F_IDNaJezik()
    stRetVal = PrevediText(stRetVal, IDSaJezika, IDNaJezik)

Exit_Point:
 On Error Resume Next
       Prevedi = stRetVal
Exit Function

Err_Point:
 BBErrorMSG err, "Prevedi"
 Resume Exit_Point
End Function
Public Function PrevediText(RecSaJezika As String, Optional IDSaJezika As Long = 0, Optional IDNaJezik As Long = -1, Optional UpisiNovuRecURecnik As Boolean = True) As String
On Error Resume Next
    Dim retVal As String
    Dim PREVOD As String
    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    Dim tmpSrpskaRec As String
    
    If IDNaJezik = -1 Then IDNaJezik = F_IDNaJezik()
    
    If IDSaJezika = IDNaJezik Then
        PrevediText = RecSaJezika
        Exit Function
    End If
    
    tmpSrpskaRec = UkloniSpecZnake(RecSaJezika)
    
    Set db = CurrentDb
    Set rs = db.OpenRecordset("SELECT * FROM T_Recnik WHERE (((T_Recnik.IDSaJezika)= " & IDSaJezika & ") AND ((T_Recnik.IDNaJezik)=" & IDNaJezik & "))")
    
    rs.FindFirst "[RecSaJezika] = '" & tmpSrpskaRec & "'"

    If rs.NoMatch Then
        If UpisiNovuRecURecnik Then
            rs.AddNew
            rs("RecSaJezika") = tmpSrpskaRec
            rs("IDSaJezika") = IDSaJezika
            rs("IDNaJezik") = IDNaJezik
            rs.Update
        End If
        PREVOD = RecSaJezika
    Else
        PREVOD = Nz(rs("RecNaJezik"), "")
    End If
    
    rs.Close
    Set rs = Nothing
    Set db = Nothing
    retVal = CStr(Nz(PREVOD, RecSaJezika))
    If retVal = "" Then retVal = RecSaJezika
    PrevediText = retVal
End Function
Public Function PrevediRecSaSrpskogNaEngleski(RecSaJezika As String, Optional UpisiNovuRecURecnik As Boolean = False) As String
'On Error Resume Next
    Dim retVal As String
    Dim PREVOD As String
    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    Dim tmpSrpskaRec As String
    
    tmpSrpskaRec = UkloniSpecZnake(RecSaJezika)
    
    Set db = CurrentDb
    Set rs = db.OpenRecordset("SELECT * FROM T_SRPENG_Recnik WHERE (T_SRPENG_Recnik.Srpski= '" & tmpSrpskaRec & "')")
    
    rs.FindFirst "[Srpski] = '" & tmpSrpskaRec & "'"

    If rs.NoMatch Then
        If UpisiNovuRecURecnik Then
            rs.AddNew
            rs("Srpski") = tmpSrpskaRec
            'rs("Engleski") = tmpSrpskaRec
            rs.Update
        End If
        PREVOD = RecSaJezika
    Else
        PREVOD = Nz(rs("Engleski"), "")
    End If
    
    rs.Close
    Set rs = Nothing
    Set db = Nothing
    retVal = CStr(Nz(PREVOD, RecSaJezika))
    If retVal = "" Then retVal = RecSaJezika
    PrevediRecSaSrpskogNaEngleski = retVal
End Function
Public Function PrevediRecPoRec(Recenica As String, Optional IDSaJezika As Long = 0, Optional IDNaJezik As Long = -1, Optional UpisiNovuRecURecnik As Boolean = False) As String
    Dim PozicijaSeparatoraReci As Long
    Dim PrevedenaRecenica As String
    Dim RecZaPrevod As String
    Dim ostatakRecenice As String
    
   ostatakRecenice = Recenica
   PrevedenaRecenica = ""
   
   While ostatakRecenice <> ""
    PozicijaSeparatoraReci = InStr(ostatakRecenice, " ")
    If PozicijaSeparatoraReci = 0 Then 'nema " ", znaci reèenica je jedna reè
        RecZaPrevod = ostatakRecenice
        ostatakRecenice = ""
    ElseIf PozicijaSeparatoraReci = 1 Then 'reèenica poèinje sa " " pa je reè za prevod ""
        PrevedenaRecenica = PrevedenaRecenica & " "
        RecZaPrevod = ""
        ostatakRecenice = Right(ostatakRecenice, Len(ostatakRecenice) - 1)
    Else
        RecZaPrevod = Left(ostatakRecenice, PozicijaSeparatoraReci - 1)
        ostatakRecenice = Right(ostatakRecenice, Len(ostatakRecenice) - PozicijaSeparatoraReci + 1)
    End If
    If IDSaJezika = 0 And IDNaJezik = 1 Then
        PrevedenaRecenica = PrevedenaRecenica & PrevediRecSaSrpskogNaEngleski(RecZaPrevod)
    Else
        PrevedenaRecenica = PrevedenaRecenica & PrevediText(RecZaPrevod, IDSaJezika, IDNaJezik, UpisiNovuRecURecnik)
    End If
    
   Wend
   
   PrevediRecPoRec = PrevedenaRecenica
End Function
Public Function Srpski(LosSrpski As Variant) As String
'Kreirano 26-03-2022
'Modifikovano: 13-01-2023
On Error GoTo Err_Point
Dim retValOk As Boolean
Dim retVal As Variant

retValOk = True

retVal = Trim(CStr(Nz(LosSrpski, "")))
If retVal = "" Then
 GoTo Exit_Point
End If

'retVal = DLookup("Srpski", "MiniRecnik", "LosSrpski=""" & retVal & """")
'retVal = CStr(Nz(retVal, CStr(Nz(LosSrpski, ""))))
 retVal = Prevedi(retVal, 0, 99)

Exit_Point:
 On Error Resume Next
       Srpski = retVal
Exit Function

Err_Point:
 BBErrorMSG err, "Srpski"
 retValOk = False
 Resume Exit_Point
End Function
