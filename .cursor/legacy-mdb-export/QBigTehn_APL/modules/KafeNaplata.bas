Attribute VB_Name = "KafeNaplata"
Option Compare Database
Option Explicit

Public Function PostojiIzabaraniRacunZaNaplatu(ByVal IDDok As Long, ByVal IDProdavnica As Long, ByVal IDKasa As Long) As Boolean
    Dim stWhere As String
    'tmpSQL = "SELECT KAFE_IzabraniRacuniZaNaplatu.* FROM KAFE_IzabraniRacuniZaNaplatu WHERE (((KAFE_IzabraniRacuniZaNaplatu.IDDok)= " & IDDok & ") AND ((KAFE_IzabraniRacuniZaNaplatu.IDProdavnica)= " & IDProdavnica & ") AND ((KAFE_IzabraniRacuniZaNaplatu.IDKasa)= " & IDKasa & "))"
    stWhere = "(((KAFE_IzabraniRacuniZaNaplatu.IDDok)= " & IDDok & ") AND ((KAFE_IzabraniRacuniZaNaplatu.IDProdavnica)= " & IDProdavnica & ") AND ((KAFE_IzabraniRacuniZaNaplatu.IDKasa)= " & IDKasa & "))"
    PostojiIzabaraniRacunZaNaplatu = (DCount("*", "KAFE_IzabraniRacuniZaNaplatu", stWhere) <> 0)
End Function
Public Function DodajIzabaranRacunZaNaplatu(ByVal IDDok As Long, ByVal IDProdavnica As Long, ByVal IDKasa As Long) As Boolean
On Error GoTo err_Func
    Dim rst As DAO.Recordset
    Dim retVal As Boolean
    'Set rst = CurrentDb.OpenRecordset("KAFE_IzabraniRacuniZaNaplatu", dbOpenTable)
    Set rst = CurrentDb.OpenRecordset("KAFE_IzabraniRacuniZaNaplatu")
    rst.AddNew
    rst!IDDok = IDDok
    rst!IDProdavnica = IDProdavnica
    rst!IDKasa = IDKasa
    rst.Update
    retVal = True
exit_Func:
    On Error Resume Next
    rst.Close
    Set rst = Nothing
    DodajIzabaranRacunZaNaplatu = retVal
Exit Function
err_Func:
    MsgBox err.Description
    retVal = False
    Resume exit_Func
End Function
Public Function IzbaciIzabaranRacunZaNaplatu(ByVal IDDok As Long, ByVal IDProdavnica As Long, ByVal IDKasa As Long) As Boolean
On Error GoTo err_Func
    Dim rst As DAO.Recordset
    Dim retVal As Boolean
    Dim stWhere As String
    
    stWhere = "((IDDok= " & IDDok & ") AND (IDProdavnica= " & IDProdavnica & ") AND (IDKasa= " & IDKasa & "))"
    Set rst = CurrentDb.OpenRecordset("KAFE_IzabraniRacuniZaNaplatu", dbOpenDynaset)
    
    rst.MoveLast 'da bi izbrojao slogove
    If rst.RecordCount > 1 Then 'Ne moze se izbaciti poslednji racun
        rst.FindFirst stWhere
        If Not rst.NoMatch Then
            rst.Delete
            retVal = True
        Else
            retVal = False
        End If
    Else
        'Ne moze se izbaciti poslednji racun
        retVal = False
    End If
exit_Func:
    On Error Resume Next
    rst.Close
    Set rst = Nothing
    IzbaciIzabaranRacunZaNaplatu = retVal
Exit Function
err_Func:
    MsgBox err.Description
    retVal = False
    Resume exit_Func
End Function
Public Function IzbaciSveIzabraneRacuneZaNaplatu() As Boolean
  On Error Resume Next
  DoCmd.SetWarnings False
    DoCmd.OpenQuery "KAFE_IzabraniRacuniZaNaplatu_Obrisi"
  DoCmd.SetWarnings True
  IzbaciSveIzabraneRacuneZaNaplatu = (DCount("*", "KAFE_IzabraniRacuniZaNaplatu") = 0)
End Function
Public Sub UpisiPlacanjeUMPDok(IDDok As Long, IDProdavnica As Long, IDKasa As Long, VrstaPlacanja As String, Iznos As Currency)
    On Error GoTo err_Sub
    Dim rst_MPDok As DAO.Recordset
    Dim txtSQL As String
    txtSQL = "SELECT T_MPDokumenta.* FROM T_MPDokumenta WHERE (((T_MPDokumenta.IDDok)= " & IDDok & ") AND ((T_MPDokumenta.IDProdavnica)= " & IDProdavnica & ") AND ((T_MPDokumenta.IDKasa)= " & IDKasa & "));"
    Set rst_MPDok = CurrentDb.OpenRecordset(txtSQL, dbOpenDynaset)

        If rst_MPDok!IDDok <> IDDok Or rst_MPDok!IDProdavnica <> IDProdavnica Or rst_MPDok!IDKasa <> IDKasa Then
            MsgBox "Ne postoji dokument u koji treba upisati naplatu " & VrstaPlacanja, vbCritical, "BBKafe"
        ElseIf rst_MPDok!StampanFiskalno Then
           MsgBox "Ovaj raèun je odštampan na fiskalnom štampaèu i ne može se menjati vrsta plaæanja!", vbExclamation, "BBKafe"
        Else
            rst_MPDok.Edit
            If VrstaPlacanja = "KES" Then
                rst_MPDok!PrimljenNovac = Iznos
            ElseIf VrstaPlacanja = "CEK" Then
                rst_MPDok!PrimljeniCekovi = Iznos
            ElseIf VrstaPlacanja = "KARTICA" Then
                rst_MPDok!PrimljenaKartica = Iznos
            End If
            rst_MPDok.Update
        End If
    
Exit_Sub:

  rst_MPDok.Close
  Set rst_MPDok = Nothing
Exit Sub

err_Sub:
    MsgBox err.Description
    Resume Exit_Sub
End Sub
Public Function IznosMPRacuna(ByVal IDDok As Long, ByVal IDProdavnica As Long, ByVal IDKasa As Long) As Currency
On Error GoTo err_Func
    
    Dim defQZaStavke As DAO.QueryDef
    Dim Stavke As DAO.Recordset
    Dim retValIznosRacuna As Currency

    Set defQZaStavke = CurrentDb.QueryDefs("FiskalniRacun")
    defQZaStavke.Parameters("ZaIdDok") = IDDok
    defQZaStavke.Parameters("ZaIdProdavnica") = IDProdavnica
    defQZaStavke.Parameters("ZaIdKasa") = IDKasa
    Set Stavke = defQZaStavke.OpenRecordset()

'If Stavke.RecordCount <= 0 Then
'    MsgBox "Ovaj fiskalni raèun nema stavki za štampanje!", vbExclamation, "QMegaTeh"
'    GoTo ZatvoriRST
'End If
 retValIznosRacuna = 0
 While Not Stavke.EOF
    retValIznosRacuna = retValIznosRacuna + (Stavke!Kolicina * Stavke!ProdajnaCena)
    Stavke.MoveNext
 Wend
ZatvoriRST:
 Stavke.Close
 Set Stavke = Nothing
 defQZaStavke.Close
 Set defQZaStavke = Nothing
 IznosMPRacuna = retValIznosRacuna
Exit Function

err_Func:

 MsgBox Error$
 Resume ZatvoriRST

End Function
