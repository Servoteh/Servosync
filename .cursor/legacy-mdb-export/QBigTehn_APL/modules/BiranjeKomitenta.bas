Attribute VB_Name = "BiranjeKomitenta"
Option Compare Database
Option Explicit
Public Sub NazivKomitentaNijeUListi(ByRef ComboKomitent As ComboBox, ByVal NewData As String, ByRef Response As Integer, Optional ByVal VrstaSifre As String)
  Dim SQLStr As String
    'Koristi se u OnNotInList kod izbora artikla
    
    If Nz(VrstaSifre, "") = "" Then
      'ComboKomitent.RowSource = "SELECT Komitenti.Sifra, Komitenti.Naziv, Komitenti.Mesto, Komitenti.Adresa, Komitenti.PIB FROM Komitenti WHERE (((Komitenti.Naziv) Like '*" & NewData & "*')) ORDER BY Komitenti.Naziv, Komitenti.[Sifra];"
      ComboKomitent.RowSource = "SELECT Komitenti.Sifra, Komitenti.Naziv, Komitenti.Mesto, Komitenti.Adresa, Komitenti.PIB FROM Komitenti WHERE (((Komitenti.Naziv) Like '*" & NewData & "*')) OR (((Komitenti.SkraceniNaziv) Like '*" & NewData & "*')) ORDER BY Komitenti.Naziv, Komitenti.[Sifra];"
      ComboKomitent.ColumnCount = 5
      ComboKomitent.BoundColumn = 1
      ComboKomitent.ColumnWidths = "0cm;7cm;3cm;5cm;3cm"
      ComboKomitent.ColumnHeads = True
      ComboKomitent.ListWidth = 10206 '7371
    End If
    
    'ComboArt.Value = Null
    Response = acDataErrContinue
End Sub
Public Function DetaljnoKomitent(Optional ByVal IDKomitent)

On Error GoTo Err_DetaljnoKomitent

    Dim DocName As String
    Dim LinkCriteria As String
    Dim ZaIDKomitent
    
 '   CheckRSType
    
    If IsMissing(IDKomitent) Then
     ZaIDKomitent = Screen.ActiveForm.Controls("Sifra").Value 'Screen.ActiveForm.Recordset("Sifra artikla")
     'ZaIDKomitent = IDKomitentSaAktivneForme()
    Else
     ZaIDKomitent = IDKomitent
    End If
    If IsNumeric(ZaIDKomitent) Then
        DocName = "Unos komitenata"
        LinkCriteria = "[Sifra] = " & ZaIDKomitent
        BBOpenForm DocName, , , LinkCriteria
    Else
     Beep
    End If

Exit_DetaljnoKomitent:
    Exit Function

Err_DetaljnoKomitent:
    BBErrorMSG err, "DetaljnoKomitent"
    Resume Exit_DetaljnoKomitent
    
End Function
Public Function NadjiKomitenta(Optional IDKomitent, Optional stFindControlName)
'**********************************************
'Kreirano: 14.01.2019.
'Opis: Pronalazi komitenta na aktivnoj formi
'**********************************************
On Error GoTo Err_Point

 Dim pVisibleSifraKomitenta As Boolean
 Dim pIDKomitent As Long
 Dim pFindControlName As String
 Dim pForm As Form
 Dim pCtl As control
    
    Set pCtl = Screen.ActiveControl
    Set pForm = Screen.ActiveControl.Parent
    
    If IsMissing(stFindControlName) Then
     pFindControlName = "Sifra"
    Else
     pFindControlName = stR(stFindControlName)
    End If
    
    If IsMissing(IDKomitent) Then
      pIDKomitent = pCtl.Value ' CLng(Screen.ActiveControl.Value)
    Else
       pIDKomitent = CLng(IDKomitent)
    End If
    
    pVisibleSifraKomitenta = pForm.Controls(pFindControlName).Visible 'pVisibleSifraKomitenta = Me![Sifra artikla].Visible
    pForm.Controls(pFindControlName).Visible = True 'Me![Sifra artikla].Visible = True
    pForm.Controls(pFindControlName).SetFocus 'DoCmd.GoToControl "Sifra artikla"
    DoCmd.FindRecord pIDKomitent
    pCtl.SetFocus
    pCtl.Value = Null
    pForm.Controls(pFindControlName).Visible = pVisibleSifraKomitenta 'Me![Sifra artikla].Visible = pVisibleSifraKomitenta
    
Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
   
   BBErrorMSG err, "NadjiKomitenta"
   Resume Exit_Point
   
End Function
