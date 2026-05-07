Attribute VB_Name = "RN_BiranjePredmeta"
Option Compare Database
Option Explicit

Public Function DetaljnoPostupak(Optional ByVal IDRN)
'Modifikovano: 08-07-2020
On Error GoTo Err_DetaljnoPostupak

    Dim DocName As String
    Dim LinkCriteria As String
    Dim ZaIDRN
    
 '   CheckRSType
    
    If IsMissing(IDRN) Then
    On Error Resume Next
        ZaIDRN = Screen.ActiveForm.Controls("IDRN").Value 'Screen.ActiveForm.Recordset("Sifra artikla")
        'If err Then
        '   err.Clear
        '   ZaIDRN = Screen.ActiveForm.Controls("IDRN").Value 'Screen.ActiveForm.Recordset("Sifra artikla")
        '   If err Then
        '      GoTo Err_DetaljnoPostupak
        '   End If
        'End If
     'ZaIDRN = IDRNSaAktivneForme()
    Else
     ZaIDRN = IDRN
    End If
    
    If IsNumeric(ZaIDRN) And Not IsEmpty(ZaIDRN) Then
        DocName = "UnosRN"
        LinkCriteria = "[IDRN] = " & ZaIDRN
        BBOpenForm DocName, , , LinkCriteria
    Else
     Beep
    End If

Exit_DetaljnoPostupak:
    Exit Function

Err_DetaljnoPostupak:
    BBErrorMSG err, "DetaljnoPostupak"
    Resume Exit_DetaljnoPostupak
    
End Function
Public Function KarticaPostupka(Optional ByVal IDRN, Optional IDMagacin, Optional Profakture As Boolean = False, Optional ZaRezervacije = Null)
'Modifikovano: 02-09-2020 Uvedena nova forma VPKarticaPostupka i podforma VPKarticaPostupka_Podforma
On Error GoTo Err_KarticaPostupka

    Dim DocName As String
    Dim LinkCriteria As String
    Dim ZaIDRN
    'stDocName = "Kartica TehPostupka"
    'stLinkCriteria = "[IDRN]=" & Me!Podforma![IDRN]
    If IsMissing(IDRN) Then
     On Error Resume Next
     ZaIDRN = Screen.ActiveForm.Recordset("IDRN")
    Else
     ZaIDRN = IDRN
    End If
    
    If IsNumeric(ZaIDRN) And Not IsEmpty(ZaIDRN) Then
        'DocName = "Kartica artikla"
        DocName = "Kartica TehPostupka"
        LinkCriteria = "[IDRN] = " & ZaIDRN
        BBOpenForm DocName, , , LinkCriteria
        'If Not IsMissing(IDMagacin) Then
        ' If IsLoaded(DocName) Then
        '  Forms(DocName)!ComboZaMagacin = IDMagacin
        '
        '  If CBool(Nz(Profakture, False)) Then
        '
        '     Forms(DocName)!OdLevel = 250
        '     Forms(DocName)!DoLevel = 250
        '     Forms(DocName)!CheckKarticaProf = True
        '     Forms(DocName)!CheckZaRezervisi = ZaRezervacije
        '  End If
          
          Forms(DocName).PrimeniUslove
         
         'End If
        'End If
    Else
     Beep
    End If
 
Exit_KarticaPostupka:
    Exit Function

Err_KarticaPostupka:
    BBErrorMSG err, "KarticaPostupka"
    Resume Exit_KarticaPostupka
    
End Function
Public Function KarticaTehnoloskogPostupka(Optional ByVal IDRN)
   Call KarticaPostupka(IDRN)
End Function
Public Function NadjiIdentBroj(Optional IDRN, Optional stFindControlName)
On Error GoTo Err_Point

 Dim pVisibleIDRN As Boolean
 Dim pIDRN As Long
 Dim pFindControlName As String
 Dim pForm As Form
 Dim pCtl As control
    
    Set pCtl = Screen.ActiveControl
    Set pForm = Screen.ActiveControl.Parent
    
    If IsMissing(stFindControlName) Then
     pFindControlName = "IDRN"
    Else
     pFindControlName = stR(stFindControlName)
    End If
    
    If IsMissing(IDRN) Then
      pIDRN = pCtl.Value ' CLng(Screen.ActiveControl.Value)
    Else
       pIDRN = CLng(IDRN)
    End If
    
    pVisibleIDRN = pForm.Controls(pFindControlName).Visible 'pVisibleIDRN = Me![Sifra artikla].Visible
    pForm.Controls(pFindControlName).Visible = True 'Me![Sifra artikla].Visible = True
    pForm.Controls(pFindControlName).SetFocus 'DoCmd.GoToControl "Sifra artikla"
    DoCmd.FindRecord pIDRN
    pCtl.SetFocus 'DoCmd.GoToControl "NadjiKatBroj"
    pCtl.Value = Null ' Me!NadjiKatBroj = Null
    pForm.Controls(pFindControlName).Visible = pVisibleIDRN 'Me![Sifra artikla].Visible = pVisibleIDRN
    
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
   
   BBErrorMSG err, "NadjiIdentBroj"
   Resume Exit_Point
   
End Function
Public Function KarticaLokacijaDela(ByVal pIDPredmet As Long, pBrojCrteza As String)
On Error GoTo Err_KarticaPostupka

    Dim DocName As String
    Dim LinkCriteria As String
    
    
    If pIDPredmet <> 0 And pBrojCrteza <> "" Then
        DocName = "KarticaLokacijaDela"
        BBOpenForm DocName, , , LinkCriteria
        
        If IsLoaded(DocName) Then
            Forms(DocName)!ZaIDPredmet = pIDPredmet
            Forms(DocName)!ZaBrojCrteza = pBrojCrteza
            Forms(DocName).PrimeniUslove
        Else
            Beep
        End If
    End If
 
Exit_KarticaPostupka:
    Exit Function

Err_KarticaPostupka:
    BBErrorMSG err, "KarticaPostupka"
    Resume Exit_KarticaPostupka
    
End Function
Public Function DetaljnoMRP_Potreba(Optional ByVal IDPotreba)
'Modifikovano: 08-07-2020
On Error GoTo Err_DetaljnoPotreba

    Dim DocName As String
    Dim LinkCriteria As String
    Dim ZaIDPotreba
    
 '   CheckRSType
    
    If IsMissing(IDPotreba) Then
    On Error Resume Next
        ZaIDPotreba = Screen.ActiveForm.Controls("IDPotreba").Value 'Screen.ActiveForm.Recordset("Sifra artikla")
    Else
     ZaIDPotreba = IDPotreba
    End If
    
    If IsNumeric(ZaIDPotreba) And Not IsEmpty(ZaIDPotreba) Then
        DocName = "MRP_Potreba"
        LinkCriteria = "[IDPotreba] = " & ZaIDPotreba
        BBOpenForm DocName, , , LinkCriteria, , , "EDIT"
    Else
     Beep
    End If

Exit_DetaljnoPotreba:
    Exit Function

Err_DetaljnoPotreba:
    BBErrorMSG err, "DetaljnoPotreba"
    Resume Exit_DetaljnoPotreba
    
End Function
Public Function DetaljnoPlaniranjeNabavke(Optional ByVal IDPlan)
'Modifikovano: 08-07-2020
On Error GoTo Err_DetaljnoPlan

    Dim DocName As String
    Dim LinkCriteria As String
    Dim ZaIDPlan
    
 '   CheckRSType
    
    If IsMissing(IDPlan) Then
    On Error Resume Next
        ZaIDPlan = Screen.ActiveForm.Controls("IDPlan").Value 'Screen.ActiveForm.Recordset("Sifra artikla")
    Else
     ZaIDPlan = IDPlan
    End If
    
    If IsNumeric(ZaIDPlan) And Not IsEmpty(ZaIDPlan) Then
        DocName = "PlaniranjeNabavke"
        LinkCriteria = "[IDPlan] = " & ZaIDPlan
        BBOpenForm DocName, , , LinkCriteria
    Else
     Beep
    End If

Exit_DetaljnoPlan:
    Exit Function

Err_DetaljnoPlan:
    BBErrorMSG err, "DetaljnoPlan"
    Resume Exit_DetaljnoPlan
    
End Function

