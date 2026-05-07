Attribute VB_Name = "TK_KEPU_MP"
Option Compare Database   'Use database order for string comparisons
Option Explicit
Sub ProknjiziuTRKMPkaoZadIRazd()

On Error GoTo ErrTrkMPZadIRazd
    
    Dim BigBit As DAO.Database
    Dim defQZaTK As DAO.QueryDef
    Dim QZaTK As DAO.Recordset
    Dim StavkeTK As DAO.Recordset
    Dim stOpis


    Set BigBit = CurrentDb
    Set defQZaTK = BigBit.QueryDefs("Dokumenta koja nisu uneta u TRGOVACKU KNJIGU")
    defQZaTK.Parameters("[Forms]![Trgovacka knjiga]![OsimZaPoreklo]") = [Forms]![Trgovacka knjiga]![OsimZaPoreklo]
    defQZaTK.Parameters("[Forms]![Trgovacka knjiga]![Od datuma]") = [Forms]![Trgovacka knjiga]![Od datuma]
    defQZaTK.Parameters("[Forms]![Trgovacka knjiga]![Do datuma]") = [Forms]![Trgovacka knjiga]![Do datuma]
    defQZaTK.Parameters("[Forms]![Trgovacka knjiga]![ComboZaProdavnicu]") = [Forms]![Trgovacka knjiga]![ComboZaProdavnicu]
    defQZaTK.Parameters("[Forms]![Trgovacka knjiga]![ZaVrstuDokumenta]") = [Forms]![Trgovacka knjiga]![ZaVrstuDokumenta]
    Set QZaTK = defQZaTK.OpenRecordset()
    Set StavkeTK = BigBit.OpenRecordset("Trgovacka knjiga", DB_OPEN_DYNASET, dbSeeChanges)

QZaTK.MoveFirst                                      ' Pozicioniraj se na prvi rekord

Do Until QZaTK.EOF                                   ' Pocetak petlje

   
              
    
    If QZaTK![KnjizitiTKZad] Then
    
        StavkeTK.AddNew
        StavkeTK![IDDok] = QZaTK![IDDok]
        StavkeTK![Datum knjizenja] = QZaTK![Datum dokumenta]
        StavkeTK![Vrsta dokumenta] = QZaTK![Vrsta dokumenta]
        stOpis = Left$(Nz(QZaTK![OpisDokumenta], QZaTK![Vrsta dokumenta] & " " & QZaTK![Broj dokumenta]) & "/" & QZaTK![Datum dokumenta] & "/" & Nz(QZaTK![NazivDobavljaca], "Roba iz magacina"), 50)
        StavkeTK![Opis] = stOpis
        If F_TrgovackaPoKursu() Then
            StavkeTK![Zaduzenje] = Round(QZaTK![RazduzenjePoKursu], 2)
        Else
            StavkeTK![Zaduzenje] = Round(QZaTK![Razduzenje], 2)
        End If
        StavkeTK![Razduzenje] = 0#
        StavkeTK![Datum uplate] = Null
        StavkeTK![Iznos uplate] = 0#
        StavkeTK![IDProdavnica] = QZaTK![IDProdavnica]
        StavkeTK![Level] = QZaTK![Level]
        StavkeTK.Update
        
     End If
     
    If QZaTK![KnjizitiTKRazd] Then
    
        StavkeTK.AddNew
        StavkeTK![IDDok] = -QZaTK![IDDok]
        StavkeTK![Datum knjizenja] = QZaTK![Datum dokumenta]
        StavkeTK![Vrsta dokumenta] = QZaTK![Vrsta dokumenta]
        StavkeTK![Opis] = "Dnevni pazar"
        If F_TrgovackaPoKursu() Then
            If F_KnjiziRazlikeNaTK() Then
                StavkeTK![Zaduzenje] = Round(QZaTK![RazlikaZadPoKursu], 2)
            Else
                StavkeTK![Zaduzenje] = 0
            End If
            StavkeTK![Razduzenje] = Round(QZaTK![RazduzenjePoKursu], 2)
        Else
            If F_KnjiziRazlikeNaTK() Then
                StavkeTK![Zaduzenje] = Round(QZaTK![RazlikaZad], 2)
            Else
                StavkeTK![Zaduzenje] = 0
            End If
            StavkeTK![Razduzenje] = Round(QZaTK![Razduzenje], 2)
        End If
        StavkeTK![Datum uplate] = Null
        StavkeTK![Iznos uplate] = 0#
        StavkeTK![IDProdavnica] = QZaTK![IDProdavnica]
        StavkeTK.Update
    End If
   
   QZaTK.MoveNext                                   ' Pozicioniraj se na sledeci rekord
Loop                                                        ' Kraj petlje

    StavkeTK.Close
    Set StavkeTK = Nothing
    QZaTK.Close
    Set QZaTK = Nothing
    BigBit.Close
    Set BigBit = Nothing
Exit Sub

ErrTrkMPZadIRazd:

 MsgBox Error$
 Resume Next

End Sub
Sub NEVAZI_ProknjiziuTRKMPkaoZadIRazd()

On Error GoTo ErrTrkMPZadIRazd
    
    Dim BigBit As DAO.Database
    Dim defQZaTK As DAO.QueryDef
    Dim QZaTK As DAO.Recordset
    Dim StavkeTK As DAO.Recordset


    Set BigBit = CurrentDb
    Set defQZaTK = BigBit.QueryDefs("Dokumenta koja nisu uneta u TRGOVACKU KNJIGU")
    defQZaTK.Parameters("[Forms]![Trgovacka knjiga]![OsimZaPoreklo]") = [Forms]![Trgovacka knjiga]![OsimZaPoreklo]
    Set QZaTK = defQZaTK.OpenRecordset()
    Set StavkeTK = BigBit.OpenRecordset("Trgovacka knjiga", DB_OPEN_DYNASET, dbSeeChanges)

QZaTK.MoveFirst                                      ' Pozicioniraj se na prvi rekord

Do Until QZaTK.EOF                                   ' Pocetak petlje

   
              
    
    If QZaTK![KnjizitiTKZad] Then
    
        StavkeTK.AddNew
        StavkeTK![IDDok] = QZaTK![IDDok]
        StavkeTK![Datum knjizenja] = QZaTK![Datum dokumenta]
        StavkeTK![Vrsta dokumenta] = QZaTK![Vrsta dokumenta]
        StavkeTK![Opis] = Left$(QZaTK![Broj dokumenta] & " * " & QZaTK![Datum dokumenta] & " * " & QZaTK![OpisDokumenta] & "Roba iz magacina", 50)
        If F_TrgovackaPoKursu() Then
            StavkeTK![Zaduzenje] = Round(QZaTK![RazduzenjePoKursu], 2)
        Else
            StavkeTK![Zaduzenje] = Round(QZaTK![Razduzenje], 2)
        End If
        StavkeTK![Razduzenje] = 0#
        StavkeTK![Datum uplate] = Null
        StavkeTK![Iznos uplate] = 0#
        StavkeTK![IDProdavnica] = QZaTK![IDProdavnica]
        StavkeTK.Update
        
     End If
     
    If QZaTK![KnjizitiTKRazd] Then
    
        StavkeTK.AddNew
        StavkeTK![IDDok] = -QZaTK![IDDok]
        StavkeTK![Datum knjizenja] = QZaTK![Datum dokumenta]
        StavkeTK![Vrsta dokumenta] = QZaTK![Vrsta dokumenta]
        StavkeTK![Opis] = "Dnevni pazar"
        If F_TrgovackaPoKursu() Then
            If F_KnjiziRazlikeNaTK() Then
                StavkeTK![Zaduzenje] = Round(QZaTK![RazlikaZadPoKursu], 2)
            Else
                StavkeTK![Zaduzenje] = 0
            End If
            StavkeTK![Razduzenje] = Round(QZaTK![RazduzenjePoKursu], 2)
        Else
            If F_KnjiziRazlikeNaTK() Then
                StavkeTK![Zaduzenje] = Round(QZaTK![RazlikaZad], 2)
            Else
                StavkeTK![Zaduzenje] = 0
            End If
            StavkeTK![Razduzenje] = Round(QZaTK![Razduzenje], 2)
        End If
        StavkeTK![Datum uplate] = Null
        StavkeTK![Iznos uplate] = 0#
        StavkeTK![IDProdavnica] = QZaTK![IDProdavnica]
        StavkeTK.Update
    End If
   
   QZaTK.MoveNext                                   ' Pozicioniraj se na sledeci rekord
Loop                                                        ' Kraj petlje

    StavkeTK.Close
    Set StavkeTK = Nothing
    QZaTK.Close
    Set QZaTK = Nothing
    BigBit.Close
    Set BigBit = Nothing
Exit Sub

ErrTrkMPZadIRazd:

 MsgBox Error$
 Resume Next

End Sub


Public Sub MpProknjiziUTRKMPkaoZadIRazd()
    On Error GoTo ErrMPTrkMPZadIRazd
    
    Dim BigBit As DAO.Database
    Dim defQZaTK As DAO.QueryDef
    Dim QZaTK As DAO.Recordset
    Dim StavkeTK As DAO.Recordset


    Set BigBit = CurrentDb
    Set defQZaTK = BigBit.QueryDefs("MPDokumenta koja nisu uneta u TRGOVACKU KNJIGU")
    defQZaTK.Parameters("[Forms]![Trgovacka knjiga]![OsimZaPoreklo]") = [Forms]![Trgovacka knjiga]![OsimZaPoreklo]
    defQZaTK.Parameters("[Forms]![Trgovacka knjiga]![OdLevel]") = [Forms]![Trgovacka knjiga]![OdLevel]
    defQZaTK.Parameters("[Forms]![Trgovacka knjiga]![DoLevel]") = [Forms]![Trgovacka knjiga]![DoLevel]
    
    Set QZaTK = defQZaTK.OpenRecordset()
    Set StavkeTK = BigBit.OpenRecordset("Trgovacka knjiga", DB_OPEN_DYNASET, dbSeeChanges)

QZaTK.MoveFirst                                      ' Pozicioniraj se na prvi rekord

Do Until QZaTK.EOF                                   ' Pocetak petlje

   
              
    
    If QZaTK![KnjizitiTKZad] Then
    
        StavkeTK.AddNew
        StavkeTK![IDDok] = QZaTK![IDDok]
        StavkeTK![Datum knjizenja] = QZaTK![Datum dokumenta]
        StavkeTK![Vrsta dokumenta] = QZaTK![Vrsta dokumenta]
        StavkeTK![Opis] = Left$(QZaTK![Broj dokumenta] & " * " & QZaTK![Datum dokumenta] & " * " & QZaTK![OpisDokumenta], 50)
        If F_TrgovackaPoKursu() Then
            StavkeTK![Zaduzenje] = Round(QZaTK![RazduzenjePoKursu], 2)
        Else
            StavkeTK![Zaduzenje] = Round(QZaTK![Razduzenje], 2)
        End If
        StavkeTK![Razduzenje] = 0#
        StavkeTK![Datum uplate] = Null
        StavkeTK![Iznos uplate] = 0#
        StavkeTK![IDProdavnica] = QZaTK![IDProdavnica]
        StavkeTK![Level] = QZaTK![Level]
        StavkeTK.Update
        
     End If
     
    If QZaTK![KnjizitiTKRazd] Then
    
        StavkeTK.AddNew
        StavkeTK![IDDok] = -QZaTK![IDDok]
        StavkeTK![Datum knjizenja] = QZaTK![Datum dokumenta]
        StavkeTK![Vrsta dokumenta] = QZaTK![Vrsta dokumenta]
        StavkeTK![Opis] = "Dnevni pazar"
        If F_TrgovackaPoKursu() Then
            If F_KnjiziRazlikeNaTK() Then
               StavkeTK![Zaduzenje] = Round(QZaTK![RazlikaZadPoKursu], 2)
            Else
                StavkeTK![Zaduzenje] = 0
            End If
            StavkeTK![Razduzenje] = Round(QZaTK![RazduzenjePoKursu], 2)
        Else
            If F_KnjiziRazlikeNaTK() Then
                StavkeTK![Zaduzenje] = Round(QZaTK![RazlikaZad], 2)
            Else
                StavkeTK![Zaduzenje] = 0
            End If
            StavkeTK![Razduzenje] = Round(QZaTK![Razduzenje], 2)
        End If
        StavkeTK![Datum uplate] = Null
        StavkeTK![Iznos uplate] = 0#
        StavkeTK![IDProdavnica] = QZaTK![IDProdavnica]
        StavkeTK![Level] = QZaTK![Level]
        StavkeTK.Update
    End If
   
   QZaTK.MoveNext                                   ' Pozicioniraj se na sledeci rekord
Loop                                                        ' Kraj petlje

    StavkeTK.Close
    Set StavkeTK = Nothing
    QZaTK.Close
    Set QZaTK = Nothing
    BigBit.Close
    Set BigBit = Nothing

Exit Sub

ErrMPTrkMPZadIRazd:

 MsgBox Error$
 Resume Next
End Sub

Public Sub ProknjiziuKEPU_MPZadIRazd()
On Error GoTo ErrTrkMPZadIRazd
    
    Dim BigBit As DAO.Database
    Dim defQZaTK As DAO.QueryDef
    Dim QZaTK As DAO.Recordset
    Dim StavkeTK As DAO.Recordset


    Set BigBit = CurrentDb
    Set defQZaTK = BigBit.QueryDefs("Dokumenta koja nisu uneta u KEPU_MP")
     defQZaTK.Parameters("[Forms]![Knjiga KEPU_MP]![ZaPoreklo]") = [Forms]![Knjiga KEPU_MP]![ZaPoreklo]
    
    Set QZaTK = defQZaTK.OpenRecordset()
    Set StavkeTK = BigBit.OpenRecordset("Knjiga KEPU_MP", DB_OPEN_DYNASET, dbSeeChanges)
    
    QZaTK.MoveFirst                                      ' Pozicioniraj se na prvi rekord

Do Until QZaTK.EOF                                   ' Pocetak petlje

    If QZaTK![Ulaz] Then
        StavkeTK.AddNew
        StavkeTK![IDDok] = QZaTK![IDDok]
        StavkeTK![Datum knjizenja] = QZaTK![Datum dokumenta]
        'StavkeTK![Vrsta dokumenta] = QZaTK![Vrsta dokumenta]
        StavkeTK![Opis] = Left$(QZaTK![Broj dokumenta] & " * " & QZaTK![Datum dokumenta] & " * " & QZaTK![OpisDokumenta], 50)
        If F_TrgovackaPoKursu() Then
            StavkeTK![Zaduzenje] = Round(QZaTK![ZaduzenjePoKursu], 2)
        Else
            StavkeTK![Zaduzenje] = Round(QZaTK![Zaduzenje], 2)
        End If
        StavkeTK![Razduzenje] = 0#
        'StavkeTK![Datum uplate] = Null
        StavkeTK![Iznos uplate] = 0#
        StavkeTK![IDProdavnica] = QZaTK![IDProdavnica]
        StavkeTK.Update
    Else
        StavkeTK.AddNew
        StavkeTK![IDDok] = -QZaTK![IDDok]
        StavkeTK![Datum knjizenja] = QZaTK![Datum dokumenta]
        'StavkeTK![Vrsta dokumenta] = QZaTK![Vrsta dokumenta]
        'StavkeTK![Opis] = Left$(QZaTK![Broj dokumenta] & " * " & QZaTK![Datum dokumenta] & " * " & QZaTK![OpisDokumenta], 50)
        StavkeTK![Opis] = "Dnevni pazar"
        If F_TrgovackaPoKursu() Then
            StavkeTK![Razduzenje] = Round(QZaTK![RazduzenjePoKursu], 2)
        Else
            StavkeTK![Razduzenje] = Round(QZaTK![Razduzenje], 2)
        End If
        StavkeTK![Zaduzenje] = 0#
        'StavkeTK![Datum uplate] = Null
        StavkeTK![Iznos uplate] = 0#
        StavkeTK![IDProdavnica] = QZaTK![IDProdavnica]
        StavkeTK.Update

    End If
   QZaTK.MoveNext                                   ' Pozicioniraj se na sledeci rekord
Loop                                                        ' Kraj petlje

    StavkeTK.Close
    Set StavkeTK = Nothing
    QZaTK.Close
    Set QZaTK = Nothing
    defQZaTK.Close
    Set defQZaTK = Nothing
    BigBit.Close
    Set BigBit = Nothing
Exit Sub

ErrTrkMPZadIRazd:

 MsgBox Error$
 Resume Next

End Sub

Public Sub MPProknjiziuKEPU_MPRazd()
  On Error GoTo ErrMPTrkMPZadIRazd
    
    Dim BigBit As DAO.Database
    Dim defQZaTK As DAO.QueryDef
    Dim QZaTK As DAO.Recordset
    Dim StavkeTK As DAO.Recordset


    Set BigBit = CurrentDb
    Set defQZaTK = BigBit.QueryDefs("MPDokumenta koja nisu uneta u KEPU_MP")
    defQZaTK.Parameters("[Forms]![Knjiga KEPU_MP]![ZaPoreklo]") = [Forms]![Knjiga KEPU_MP]![ZaPoreklo]
    Set QZaTK = defQZaTK.OpenRecordset()
    
    Set StavkeTK = BigBit.OpenRecordset("Knjiga KEPU_MP", DB_OPEN_DYNASET, dbSeeChanges)

QZaTK.MoveFirst                                      ' Pozicioniraj se na prvi rekord

Do Until QZaTK.EOF                                   ' Pocetak petlje

    
        StavkeTK.AddNew
        StavkeTK![IDDok] = -QZaTK![IDDok]
        StavkeTK![Datum knjizenja] = QZaTK![Datum dokumenta]
        StavkeTK![Opis] = "Dnevni pazar"
        If F_TrgovackaPoKursu() Then
            If F_KnjiziRazlikeNaMPKEPU() Then
              StavkeTK![Zaduzenje] = Round(QZaTK![RazlikaZadPoKursu], 2)
            Else
              StavkeTK![Zaduzenje] = 0
            End If
            StavkeTK![Razduzenje] = Round(QZaTK![RazduzenjePoKursu], 2)
        Else
            If F_KnjiziRazlikeNaMPKEPU() Then
                StavkeTK![Zaduzenje] = Round(QZaTK![RazlikaZad], 2)
            Else
                StavkeTK![Zaduzenje] = 0
            End If
            StavkeTK![Razduzenje] = Round(QZaTK![Razduzenje], 2)
        End If
        StavkeTK![Iznos uplate] = 0#
        StavkeTK![IDProdavnica] = QZaTK![IDProdavnica]
        StavkeTK.Update
   
   QZaTK.MoveNext                                   ' Pozicioniraj se na sledeci rekord
Loop                                                        ' Kraj petlje

    StavkeTK.Close
    Set StavkeTK = Nothing
    QZaTK.Close
    Set QZaTK = Nothing
    defQZaTK.Close
    Set defQZaTK = Nothing
    BigBit.Close
    Set BigBit = Nothing

Exit Sub

ErrMPTrkMPZadIRazd:

 MsgBox Error$
 Resume Next

End Sub

Public Function TK_ZaduzenjeIzMag(Ulaz As Boolean, KLMPVred As Currency, StvarnaMPVred As Currency, TKZad As Boolean, TKRazd As Boolean) As Currency
Dim Vred As Currency
Dim RazlikaZad As Currency
Dim retVal As Currency
 
 If Ulaz Then Vred = KLMPVred Else Vred = StvarnaMPVred
 If TKZad Then retVal = Vred Else retVal = 0
 TK_ZaduzenjeIzMag = retVal
End Function
Public Function TK_RazduzenjeIzMag(Ulaz As Boolean, KLMPVred As Currency, StvarnaMPVred As Currency, TKZad As Boolean, TKRazd As Boolean) As Currency
Dim Vred As Currency
Dim retVal As Currency
 
 If Ulaz Then Vred = KLMPVred Else Vred = StvarnaMPVred
 If TKRazd Then retVal = Vred Else retVal = 0
 TK_RazduzenjeIzMag = retVal
End Function
Public Function TK_OpisKnjizenjaIzMag(VrstaDok As String, BrojDok As String, BrojDokZaIF As String)
 Dim retVal As String
 'TK_OpisKnjizenjaIzMag = [R_Vrste dokumenata]![Opis] & " " & [T_Robna dokumenta]![Broj dokumenta] & " za " & [TK_DobavljaciZaIF]![Broj dokumenta] & " od " & [TK_DobavljaciZaIF]![Datum dokumenta] & " Dobavljaè " & Nz([TK_DobavljaciZaIF]![Naziv], F_AFNaziv()) & " " & Nz([TK_DobavljaciZaIF]![Mesto], F_AFMesto())
End Function
