Attribute VB_Name = "Planer"
Option Compare Database
Option Explicit

Public Function BrojNeobradjenihPoruka_SLAVISA(Optional ByVal ZaDatum) As Long
'Modifikovano: 10-05-19

On Error GoTo Err_Point

Dim stSQL As String
Dim stSQL_WHERE As String
Dim OdDatuma As String, DoDatuma As String
Dim OdVremena As String, DoVremena As String
Dim ZaCheckUradjeno As Boolean
Dim BrojPoruka As Long

Dim BrojDanaUnapred
Dim BrojDanaUnazad

If Not PostojiTabelaUBazi("T_Planer", CurrentDb) Then
 BrojNeobradjenihPoruka_SLAVISA = 0
 Exit Function
End If
If IsMissing(ZaDatum) Then
  ZaDatum = Date
End If

BrojDanaUnapred = Nz(ReadCFGParametar("Planer_BrojDanaUnapred"), 0)
If Not IsNumeric(BrojDanaUnapred) Then
  BrojDanaUnapred = 0
Else
  BrojDanaUnapred = Abs(CInt(BrojDanaUnapred))
End If

BrojDanaUnazad = Nz(ReadCFGParametar("Planer_BrojDanaUnazad"), 0)
If Not IsNumeric(BrojDanaUnazad) Then
  BrojDanaUnazad = 0
Else
  BrojDanaUnazad = Abs(CInt(BrojDanaUnazad))
End If

OdDatuma = DateAdd("d", -BrojDanaUnazad, ZaDatum)
DoDatuma = DateAdd("d", BrojDanaUnapred, ZaDatum)

OdDatuma = "#" & Format(OdDatuma, "MM/dd/yy") & "#"
DoDatuma = "#" & Format(DoDatuma, "MM/dd/yy") & "#"

OdVremena = "00:00:00"
DoVremena = "23:59:59"
ZaCheckUradjeno = False

'stSQL = "SELECT T_Planer.* FROM T_Planer"
'"AND ((Format([KadaVreme],""Short Time""))>=" & OdVremena & ") And (Format([KadaVreme],""Short Time""))<=" & DoVremena & ") AND ((ZadovoljenUslovZaBoolVal([CheckUradjeno]," & ZaCheckUradjeno & "))=True))"
'stSQL = stSQL & " " & stSQL_WHERE

stSQL_WHERE = "(T_Planer.KadaDatum Between " & OdDatuma & " And " & DoDatuma & ")  AND (T_Planer.CheckUradjeno=False)"

BrojPoruka = DCount("*", "T_Planer", stSQL_WHERE)

Exit_Point:
 On Error Resume Next
 BrojNeobradjenihPoruka_SLAVISA = BrojPoruka
Exit Function

Err_Point:
 BBErrorMSG err, "BrojNeobradjenihPoruka"
 BrojPoruka = 0
 Resume Exit_Point
End Function

Public Function ProveriInboxPlanera() As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    retValOk = True
    
    If Nz(ReadParametar("CFG_Global", "Planer_Start"), False) Then
     If BrojNeobradjenihPoruka > 0 Then
        BBOpenForm "PlanerPopUp"
     End If
    End If
    
Exit_Point:
    On Error Resume Next
    ProveriInboxPlanera = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "ProveriInboxPlanera"
    retValOk = False
    Resume Exit_Point
End Function
Public Function GetPlanerUser() As String
    On Error Resume Next
    GetPlanerUser = UCase(CurrentUser)
End Function
Public Function BrojNeobradjenihPoruka_OLD(Optional ByVal ZaDatum As Variant) As Long
On Error GoTo Err_Point

    Dim BrojDanaUnapred As Long
    Dim BrojDanaUnazad As Long
    Dim OdDatuma As Date
    Dim DoDatuma As Date
    Dim stUser As String
    Dim retVal As Variant

    If IsMissing(ZaDatum) Or IsNull(ZaDatum) Then
        ZaDatum = Date
    End If
    
   ' BrojDanaUnapred = Nz(ReadCFGParametar("Planer_BrojDanaUnapred"), 0)
   ' If Not IsNumeric(BrojDanaUnapred) Then
   '   BrojDanaUnapred = 0
   ' Else
   '   BrojDanaUnapred = Abs(CInt(BrojDanaUnapred))
   ' End If
    
   ' BrojDanaUnazad = Nz(ReadCFGParametar("Planer_BrojDanaUnazad"), 0)
   ' If Not IsNumeric(BrojDanaUnazad) Then
   '   BrojDanaUnazad = 0
   ' Else
   '   BrojDanaUnazad = Abs(CInt(BrojDanaUnazad))
   ' End If

    BrojDanaUnapred = Abs(Nz(ReadCFGParametar("Planer_BrojDanaUnapred"), 0))
    BrojDanaUnazad = Abs(Nz(ReadCFGParametar("Planer_BrojDanaUnazad"), 0))

    OdDatuma = DateAdd("d", -BrojDanaUnazad, ZaDatum)
    DoDatuma = DateAdd("d", BrojDanaUnapred, ZaDatum)

    stUser = GetPlanerUser()

    retVal = ADO_GetValFromUDFS( _
                CNN_CurrentDataBase, _
                "ftBrojVidljivihPorukaPlanera", _
                stUser, _
                SQLFormatDatuma(OdDatuma), _
                SQLFormatDatuma(DoDatuma) _
             )

    BrojNeobradjenihPoruka_OLD = Nz(retVal, 0)

Exit_Point:
    Exit Function

Err_Point:
    BBErrorMSG err, "BrojNeobradjenihPoruka_OLD"
    BrojNeobradjenihPoruka_OLD = 0
End Function


Public Function BrojNeobradjenihPoruka(Optional ByVal ZaDatum As Variant) As Long
On Error GoTo Err_Point

    Dim BrojDanaUnapred As Long
    Dim BrojDanaUnazad As Long
    Dim OdDatuma As Variant
    Dim DoDatuma As Variant
    Dim stUser As String
    Dim lBroj As Long

    If IsMissing(ZaDatum) Or IsNull(ZaDatum) Then
        ZaDatum = Date
    End If

    BrojDanaUnapred = Abs(Nz(ReadCFGParametar("Planer_BrojDanaUnapred"), 0))
    BrojDanaUnazad = Abs(Nz(ReadCFGParametar("Planer_BrojDanaUnazad"), 0))

    OdDatuma = DateAdd("d", -BrojDanaUnazad, ZaDatum)
    DoDatuma = DateAdd("d", BrojDanaUnapred, ZaDatum)
    
    'OdDatuma = "#" & Format(OdDatuma, "MM/dd/yy") & "#"
    'DoDatuma = "#" & Format(DoDatuma, "MM/dd/yy") & "#"


    stUser = GetPlanerUser()

    ' Poziv SP sa OUTPUT parametrom
    Call ADO_ExecSP_WithOutput( _
                                CNN_CurrentDataBase, _
                                "spBrojVidljivihPorukaPlanera", _
                                lBroj, _
                                stUser, _
                                SQLFormatDatuma(OdDatuma, False), _
                                SQLFormatDatuma(DoDatuma, False) _
                            )


    BrojNeobradjenihPoruka = Nz(lBroj, 0)

Exit_Point:
    Exit Function

Err_Point:
    BBErrorMSG err, "BrojNeobradjenihPoruka"
    BrojNeobradjenihPoruka = 0
End Function


