Attribute VB_Name = "RasterModul"
Option Compare Database
Option Explicit
Public Function KatBrojIzBarKoda(BarKod As String) As String
    Dim retVal As String
    retVal = Left$(BarKod, 9)       'Cyclamin
    If InStr(retVal, "-") > 0 Then
        retVal = Left$(retVal, InStr(retVal, "-") - 1) & "/" & Right$(retVal, Len(retVal) - InStr(retVal, "-"))
    End If
    KatBrojIzBarKoda = retVal
End Function
Public Function VrstaRasteraIzBarKoda(BarKod As String) As Long
    Dim retVal
    Dim tmpst As String
    tmpst = Mid$(BarKod, 14, 3)     'Cyclamin
    retVal = Nz(DLookup("[IDRasterVrsta]", "RasterDefVrsta", "[BarKodVrsta] = '" & tmpst & "'"), 0)
    VrstaRasteraIzBarKoda = retVal
End Function
'? KolonaRasteraIzBarKoda("551-41530-06-004-36")
Public Function KolonaRasteraIzBarKoda(BarKod As String) As Long
    Dim retVal
    Dim tmpst As String
    tmpst = Mid$(BarKod, 18, 2)        'Cyclamin
    retVal = Nz(DLookup("[IDRasterKolona]", "RasterDefKolona", "[BarKodKolona] = '" & tmpst & "'"), 0)
    KolonaRasteraIzBarKoda = retVal
End Function
Public Function DodajStavkuURasterMPStavke(IDRasterVrsta As Long, _
                                            IDRasterKolona As Long, _
                                            IDStavkeIzRobnog As Long, _
                                            IDDok As Long, _
                                            IDProdavnice As Long, _
                                            Kolicina As Double) As Boolean
    On Error GoTo GreskaUDodavanju
    Dim retVal As Boolean
    
    Dim BigBit As DAO.Database
    Dim TabRaster As DAO.Recordset
    
    retVal = True
    Set BigBit = CurrentDb
    Set TabRaster = BigBit.OpenRecordset("RasterMPStavke", DB_OPEN_DYNASET, dbSeeChanges)
    
    TabRaster.AddNew
        TabRaster!IDRasterVrsta = IDRasterVrsta
        TabRaster!IDRasterKolona = IDRasterKolona
        TabRaster!IDStavkeIzRobnog = IDStavkeIzRobnog
        TabRaster!IDDok = IDDok
        TabRaster!IDProdavnice = IDProdavnice
        TabRaster!Kolicina = Kolicina
    
    TabRaster.Update                    'Sacuvaj izmene
    
    TabRaster.Close
    Set TabRaster = Nothing
    BigBit.Close
    Set BigBit = Nothing
    DodajStavkuURasterMPStavke = retVal
Exit Function

GreskaUDodavanju:
 MsgBox Error$
 retVal = False
 Resume Next
End Function
Public Function DodajStavkuURasterStavke(IDRasterVrsta As Long, _
                                            IDRasterKolona As Long, _
                                            IDStavkeIzRobnog As Long, _
                                            Kolicina As Double) As Boolean
    On Error GoTo GreskaUDodavanju
    Dim retVal As Boolean
    
    Dim BigBit As DAO.Database
    Dim TabRaster As DAO.Recordset
    
    retVal = True
    Set BigBit = CurrentDb
    Set TabRaster = BigBit.OpenRecordset("RasterStavke", DB_OPEN_DYNASET, dbSeeChanges)
    
    TabRaster.AddNew
        TabRaster!IDRasterVrsta = IDRasterVrsta
        TabRaster!IDRasterKolona = IDRasterKolona
        TabRaster!IDStavkeIzRobnog = IDStavkeIzRobnog
        TabRaster!Kolicina = Kolicina
    
    TabRaster.Update                    'Sacuvaj izmene
    
    TabRaster.Close
    Set TabRaster = Nothing
    BigBit.Close
    Set BigBit = Nothing
    DodajStavkuURasterStavke = retVal
Exit Function

GreskaUDodavanju:
 MsgBox Error$
 retVal = False
 Resume Next
End Function

