Attribute VB_Name = "ZbrniRacunModule"
Option Compare Database
Option Explicit

Public Sub ZbirnaFaktura(Optional ZaGodinu As Long = False, _
                         Optional UlaznaDokumenta As String = False, _
                         Optional OdDatuma As Variant = Null, _
                         Optional DoDatuma As Variant = Null, _
                         Optional OdDatumaValute As Variant = Null, _
                         Optional DoDatumaValute As Variant = Null, _
                         Optional ZaVrstuDokumenta As Variant = Null, _
                         Optional ZaKomitenta As Variant = Null, _
                         Optional ZaMISP As Variant = Null, _
                         Optional ZaVozacaNaDok As Variant = Null, _
                         Optional ZaMagacin As Variant = Null, _
                         Optional ZaProdavca As Variant = Null, _
                         Optional ZaRadniNalog As Variant = Null, _
                         Optional OdLevel As Variant = 0, _
                         Optional DoLevel As Variant = 0, _
                         Optional ZaOznaku As Variant = Null, _
                         Optional ZaBrojDokAVR As Variant = Null)
                         
On Error GoTo Err_ZbirnaFaktura

    Dim stDocName As String

    stDocName = "frmFakturaZbirna"
    BBOpenForm stDocName
    Forms(stDocName)!ZaGodinu = ZaGodinu
    Forms(stDocName)!UlaznaDokumenta = UlaznaDokumenta ' IIf(UlaznaDokumenta, "Da", "Ne")
    Forms(stDocName)!SifraKomitenta = ZaKomitenta
    Forms(stDocName)!ComboNazivKomitenta = ZaKomitenta
    Forms(stDocName)!ComboMestoKomitenta = ZaKomitenta
    Forms(stDocName)![Od datuma] = OdDatuma
    Forms(stDocName)![Do datuma] = DoDatuma
    Forms(stDocName)![OdDatumaValute] = OdDatumaValute
    Forms(stDocName)![DoDatumaValute] = DoDatumaValute
    Forms(stDocName)![ZaVrstuDokumenta] = ZaVrstuDokumenta
    Forms(stDocName)![Za komitenta] = ZaKomitenta
    Forms(stDocName)![ZaMISP] = ZaMISP
    
    Forms(stDocName)![ZaVozaca] = ZaVozacaNaDok
    Forms(stDocName)![ZaMagacin] = ZaMagacin
    Forms(stDocName)![ZaProdavca] = ZaProdavca
    Forms(stDocName)![ZaRadniNalog] = ZaRadniNalog
    Forms(stDocName)![OdLevel] = OdLevel
    Forms(stDocName)![DoLevel] = DoLevel
    Forms(stDocName)![ZaOznaku] = ZaOznaku
    Forms(stDocName)![ZaBrojDokAVR] = ZaBrojDokAVR
    
    'Forms(stDocName).Requery
    'Forms(stDocName).Form.PrimeniUsloveNaPodformi
    Forms!frmFakturaZbirna.PrimeniUsloveNaPodformi
    Forms(stDocName).Recalc
    Forms(stDocName)!TekstZaRacun.SetFocus
    
Exit_ZbirnaFaktura:
    Exit Sub

Err_ZbirnaFaktura:
    MsgBox err.Description
    Resume Exit_ZbirnaFaktura
    
End Sub
