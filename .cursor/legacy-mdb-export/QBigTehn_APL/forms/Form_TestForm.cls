VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_TestForm"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Dim SifraRadnika As Long
Public gSessionID As String
Private Sub Command28_Click()
    Dim db As DAO.Database
    'Set db = DBEngine.OpenDatabase(BazaZaTip("EXTBAZA"))
    Set db = CurrentDb
    Dim t As DAO.TableDef
    For Each t In db.TableDefs
        Debug.Print t.Name
    Next

End Sub
Private Sub Command29_Click()
    gSessionID = CreateObject("Scriptlet.TypeLib").Guid
    MsgBox gSessionID
End Sub

Private Sub Command30_Click()
    Call ObrisiRNizExcela
End Sub

Private Sub tglStatus_Click()
    Call ObojiToggle
    MsgBox gSessionID
End Sub
Private Sub Form_Current()
    Call ObojiToggle
End Sub

Private Sub ObojiToggle()
    With Me.tglStatus
        If .Value = True Then
            ' ? svetlo zelena (ispravno u Accessu)
            .BackColor = RGB(200, 200, 255)
            .ForeColor = RGB(0, 80, 0)
        Else
            ' ? svetlo crvena (ovo radi ispravno i bez zamene)
            .BackColor = RGB(255, 200, 200)
            .ForeColor = RGB(120, 0, 0)
        End If
    End With
End Sub



Public Function TEST_ProveriRNZIzUnosaBarKoda(ByVal pIDRadnik As Long, stBarKod As String) As Boolean
On Error Resume Next
    
    Dim stBarKodPom As String
    Dim DuzstBarKodPom, i, Pos As Integer
    Dim ind As Boolean
    Dim retValOk As Boolean
    Dim Masina, RadNaMasini As Long
    Dim BrojOperacijaLogovanogRadnikaURN As Integer
    Dim Operacija As Long
    Dim RJgrupaRC As String
    
    Dim pIDPredmet As Long
    Dim stIdentBroj As String
    Dim pVarijanta As Long
    Dim pPrnTimer As Long
    
    stBarKodPom = stBarKod
    DuzstBarKodPom = Len(stBarKodPom)
    i = 0
    ind = True
    
    While DuzstBarKodPom <> 0 And ind
        Pos = InStr(1, stBarKodPom, ":", vbTextCompare)
        Select Case i
        Case 0
        Case 1
            pIDPredmet = CLng(Left(stBarKodPom, Pos - 1))
        Case 2
            stIdentBroj = Left(stBarKodPom, Pos - 1)
        Case 3
            pVarijanta = CLng(Left(stBarKodPom, Pos - 1))
         Case 4
            pPrnTimer = CLng(stBarKodPom)
            ind = False
        End Select
        i = i + 1
        stBarKodPom = Mid(stBarKodPom, Pos + 1)
        DuzstBarKodPom = Len(stBarKodPom)
    Wend
    
      
    BrojOperacijaLogovanogRadnikaURN = BrojOperacijaZaRadnikaUProcitanomRN(pIDPredmet, stIdentBroj, pVarijanta, pIDRadnik)
    MsgBox "Sifra radnika= " & SifraRadnika & " BrojOperacijaLogovanogRadnikaURN= " & BrojOperacijaLogovanogRadnikaURN
    
    Select Case BrojOperacijaLogovanogRadnikaURN
        Case -1
            BBMsgBox "GREŠKA!!!", "Došlo je do greške u èitanju podataka!!!", , 5, 0, 18, , 255
            Call BBTSUndo
            DoCmd.Close acForm, "BarKod_Unos"
            DoCmd.OpenForm "ReklamniPanel_Login"
        Case 0
            BBMsgBox "GREŠKA!!!", "Izabrali ste nalog u kojem nema OPERACIJA koju vi treba da radite!!!", , 5, 0, 18, , 255
            'DugmePonistiUnos_Click
            Call BBTSUndo
            DoCmd.Close acForm, "BarKod_Unos"
            DoCmd.OpenForm "ReklamniPanel_Login"
        Case 1
            
            retValOk = ProcitajOperacijuZaRadnikaUProcitanomRN(pIDPredmet, stIdentBroj, pVarijanta, pIDRadnik, Operacija, RJgrupaRC)
            
            MsgBox "Sifra radnika= " & SifraRadnika & " Operacija= " & Operacija & " RJgrupaRC= " & RJgrupaRC
            Me!ProcitajBarKod = Null
            
            If ProveriKolicine(pIDPredmet, stIdentBroj, pVarijanta, Operacija, 1) Then
                MsgBox "DOBAR UNOS!!!"
            Else
                BBMsgBox "GREŠKA!!!", "PROVERITE BROJ KOMADA", "Radite operaciju po kojoj je napravljeno potreban broj komada!!!", 5, vbYes, 16, 14, 125
                'DugmePonistiUnos_Click
                
            End If
            
        Case Else
            
    End Select
    
Exit_Point:
 On Error Resume Next
 TEST_ProveriRNZIzUnosaBarKoda = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "TEST_ProveriRNZIzUnosaBarKoda"
    retValOk = False
    Resume Exit_Point
End Function

Private Sub ProcitajBarKod_AfterUpdate()
    TEST_ProveriRNZIzUnosaBarKoda SifraRadnika, Me!ProcitajBarKod
End Sub

Private Sub UnetiPassword_AfterUpdate()
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim UnetiPassword As String
    Dim IDRadnika As Long
    Dim Podatak As Variant
    Dim NoviRadnikSifra As Long
    
    retValOk = True
    Podatak = Nz(Me![UnetiPassword], "")
    
    Me![UnetiPassword] = Null
    SifraRadnika = -1

    IDRadnika = Nz(ADO_Lookup(CNN_CurrentDataBase, "SifraRadnika", "tRadnici", "IDKartice='" & Podatak & "' AND Aktivan=" & SQLFormatBoolean(True)), -1)
    If IDRadnika = -1 Then
        MsgBox "U bazi NE POSTOJI radnik sa proèitanim brojem kartice!!!", vbInformation, "QBigTehn"
        Me!UnetiPassword = Null
        
        retValOk = False
    Else
        SifraRadnika = IDRadnika
        Me!UnetiPassword = Null
        Me!ProcitajBarKod = Null
        Me!ProcitajBarKod.SetFocus
    End If
       
Exit_Point:
 On Error Resume Next
Exit Sub

Err_Point:
    BBErrorMSG err, "UnetiPassword_AfterUpdate"
    Resume Exit_Point
End Sub

Public Sub ObrisiRNizExcela()

On Error GoTo ErrH

Dim rs As DAO.Recordset
Dim lIDRN As Long
Dim cnt As Long

Set rs = CurrentDb.OpenRecordset("SELECT IDRN FROM ExcelRNZaBrisanje WHERE IDRN Is Not Null")

If rs.EOF Then
    MsgBox "Nema naloga za brisanje.", vbInformation
    Exit Sub
End If

rs.MoveFirst

Do While Not rs.EOF

    lIDRN = rs!IDRN
    
    Call ADO_ExecSP(CNN_CurrentDataBase, _
                    "spObrisiKompletanNalogSaPostupkom", _
                    lIDRN)

    cnt = cnt + 1
    
    rs.MoveNext

Loop

rs.Close

MsgBox "Obrisano naloga: " & cnt, vbInformation

Exit Sub

ErrH:
MsgBox err.Description

End Sub
