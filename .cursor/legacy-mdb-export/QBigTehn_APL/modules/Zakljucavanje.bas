Attribute VB_Name = "Zakljucavanje"
Option Compare Database
Option Explicit
Public Function ZakOtkDok(stTabela As String, _
                         indxName As String, _
                         ByVal IDDok, _
                         ZakOtk As Boolean, _
                         Optional StrogoZak As Boolean = False) As Boolean
                         
On Error GoTo err_ZakOtkDok
 
Dim Uspesno As Boolean
 
If Not IsNumeric(IDDok) Then
   Uspesno = False
   GoTo exit_ZakOtkDok
End If

If Not ZakOtk And StrogoZak And stTabela = "tRN" Then
    If NalogPostojiUTehPostupku(IDDok) Then
        Uspesno = False
        MsgBox "Po ovom nalogu je " & Srpski("zapoceta") & " proizvodnja i ne moze se otkljucati!", vbExclamation, "QBigTeh"
        GoTo exit_ZakOtkDok
    End If
End If

If ZakOtk And (Not UserUGrupi(CurrentUser(), "Zakljucavanje")) Then
    Uspesno = False
    MsgBox "Nemate prava!", vbExclamation, "QBigTeh"
ElseIf (Not ZakOtk) And (Not UserUGrupi(CurrentUser(), "Otkljucavanje")) Then
    Uspesno = False
    MsgBox "Nemate prava!", vbExclamation, "QBigTeh"
Else
    Uspesno = ADO_ExecSP(CNN_CurrentDataBase, "spZakOtk", stTabela, Null, Null, stR(Nz(IDDok, 0)), SQLFormatBoolean(ZakOtk))
End If
    
exit_ZakOtkDok:
On Error Resume Next
 ZakOtkDok = Uspesno
Exit Function

err_ZakOtkDok:
 Uspesno = False
Resume exit_ZakOtkDok
End Function

Public Function spZakOtk(stTabela As String, IDFirma, Godina, OdLevel, DoLevel, OdDatuma, DoDatuma, IDDok, ZakOtk As Boolean) As Boolean
On Error GoTo Err_Point
Dim retValOk As Boolean
'   EXEC spZakOtk @Tabela nvarchar(200)
'                ,@IDFirma int
'                ,@Godina int = null
'                ,@OdLevel int = 0
'                ,@DoLevel int = 250
'                ,@ODDatuma Date = Null
'                ,@DoDatuma Date = Null
'                ,@IDDok int = Null
'                ,@ZakOtk bit

retValOk = ADO_ExecSP(CNN_CurrentDataBase, "spZakOtk", stTabela, IDFirma, Godina, OdLevel, DoLevel, SQLFormatDatuma(OdDatuma, False), SQLFormatDatuma(DoDatuma, False), IDDok, SQLFormatBoolean(ZakOtk))

Exit_Point:
 On Error Resume Next
       spZakOtk = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "spZakOtk"
 retValOk = False
 Resume Exit_Point
End Function
Public Function StartnoZakljucavanjeRoba() As Boolean
On Error GoTo Err_Point
 Dim retValOk As Boolean
 Dim StarijeOdDana As Integer
 Dim DoDatuma As Date

    retValOk = True
    If Not UserUGrupi(CurrentUser(), "Zakljucavanje") Then
        GoTo Exit_Point
    End If
    
    If Not RFReadParameter("AutoZakRoba") Then
      GoTo Exit_Point
    End If
        
    StarijeOdDana = CInt(Nz(RFReadParameter("StarijeOdDanaRoba"), 7))
    DoDatuma = CDate(Date - StarijeOdDana)
    
    '30-01-2022 retValOk = spZakOtk("T_Robna dokumenta", F_IDFirma(), F_Godina(), 0, F_NivoBaze(), Null, DoDatuma, Null, True)
    retValOk = spZakOtk("T_Robna dokumenta", F_IDFirma(), Null, 0, F_NivoBaze(), Null, DoDatuma, Null, True)
    
Exit_Point:
     On Error Resume Next
           StartnoZakljucavanjeRoba = retValOk
Exit Function
    
Err_Point:
     BBErrorMSG err, "StartnoZakljucavanjeRoba"
     retValOk = False
     Resume Exit_Point
End Function
Public Function StartnoZakljucavanjeGK() As Boolean
On Error GoTo Err_Point
 Dim retValOk As Boolean
 Dim StarijeOdDana As Integer
 Dim DoDatuma As Date

    retValOk = True
    If Not UserUGrupi(CurrentUser(), "Zakljucavanje") Then
        GoTo Exit_Point
    End If
    
    If Not RFReadParameter("AutoZakGK") Then
      GoTo Exit_Point
    End If
        
    StarijeOdDana = CInt(Nz(RFReadParameter("StarijeOdDanaGK"), 7))
    DoDatuma = CDate(Date - StarijeOdDana)
    
    '30-01-2022 retValOk = spZakOtk("T_Nalozi", F_IDFirma(), F_Godina(), 0, F_NivoBaze(), Null, DoDatuma, Null, True)
    retValOk = spZakOtk("T_Nalozi", F_IDFirma(), Null, 0, F_NivoBaze(), Null, DoDatuma, Null, True)
Exit_Point:
     On Error Resume Next
           StartnoZakljucavanjeGK = retValOk
Exit Function
    
Err_Point:
     BBErrorMSG err, "StartnoZakljucavanjeGK"
     retValOk = False
     Resume Exit_Point
End Function

Public Function ZakljucanRobniDok(IDDok) As Boolean
'Modifikovano: 19-12-2022
On Error GoTo Err_Point
Dim retValOk As Boolean

retValOk = True

 If Not IsNumeric(IDDok) Then
  retValOk = True
  GoTo Exit_Point
 End If
 
 'ZakljucanRobniDok = CBool(Nz(DLookup("[Zakljucano]", "T_Robna dokumenta", "IDDok = " & CLng(IDDok)), True))
 retValOk = CBool(Nz(ADO_Lookup(CNN_CurrentDataBase, "[Zakljucano]", "T_Robna dokumenta", "IDDok = " & CLng(IDDok)), True))
 
Exit_Point:
 On Error Resume Next
       ZakljucanRobniDok = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ZakljucanRobniDok"
 retValOk = True
 Resume Exit_Point

End Function

Public Function ZakljucanDok(stTabela As String, IDDok As Long) As Boolean
'Modifikovano: 07-03-2023
On Error GoTo Err_Point
Dim retValOk As Boolean

retValOk = True

 If Not IsNumeric(IDDok) Then
  retValOk = True
  GoTo Exit_Point
 End If
 
 'ZakljucanRobniDok = CBool(Nz(DLookup("[Zakljucano]", "T_Robna dokumenta", "IDDok = " & CLng(IDDok)), True))
 retValOk = CBool(Nz(ADO_Lookup(CNN_CurrentDataBase, "[Zakljucano]", stTabela, "IDDok = " & CLng(IDDok)), True))
 

Exit_Point:
 On Error Resume Next
       ZakljucanDok = retValOk
Exit Function

Err_Point:
 BBErrorMSG err, "ZakljucanDok"
 retValOk = True
 Resume Exit_Point

End Function
