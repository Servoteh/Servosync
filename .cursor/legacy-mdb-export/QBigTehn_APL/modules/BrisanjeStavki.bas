Attribute VB_Name = "BrisanjeStavki"
Option Compare Database
Option Explicit

Public Function PrenesiMPStavkuUObrisano(IDStavke As Long, IDDok As Long, IDProdavnice As Long, IDKasa As Long) As Boolean
    On Error GoTo err_ObrisiStavku

    Dim db As DAO.Database
    Dim QCopySQL As String
    Dim QDeleteSQL As String
    Dim QCopy As DAO.QueryDef
    Dim QDelete As DAO.QueryDef
    Dim varRet As Boolean
    
    Set db = CurrentDb
    
    QCopySQL = "INSERT INTO T_MPStavke_Obrisane ( IDStavke, IDDok, IDProdavnice, IDKasa, [Sifra artikla], Kolicina, KalkulativnaMPCena, StvarnaMPCena, Taksa, TarifaRoba, IDStavMagOtpreme, Porudzbina, DatIVremePor )"
    QCopySQL = QCopySQL & " SELECT T_MPStavke.IDStavke, T_MPStavke.IDDok, T_MPStavke.IDProdavnice, T_MPStavke.IDKasa, T_MPStavke.[Sifra artikla], T_MPStavke.Kolicina, T_MPStavke.KalkulativnaMPCena, T_MPStavke.StvarnaMPCena, T_MPStavke.Taksa, T_MPStavke.TarifaRoba, T_MPStavke.IDStavMagOtpreme, T_MPStavke.Porudzbina, T_MPStavke.DatIVremePor"
    QCopySQL = QCopySQL & " FROM T_MPStavke"
    QCopySQL = QCopySQL & " WHERE (((T_MPStavke.IDStavke)=" & IDStavke & ") AND ((T_MPStavke.IDDok)=" & IDDok & ") AND ((T_MPStavke.IDProdavnice)= " & IDProdavnice & ") AND ((T_MPStavke.IDKasa)= " & IDKasa & "));"
    
    QDeleteSQL = "DELETE T_MPStavke.* FROM T_MPStavke"
    QDeleteSQL = QDeleteSQL & " WHERE (((T_MPStavke.IDStavke)=" & IDStavke & ") AND ((T_MPStavke.IDDok)=" & IDDok & ") AND ((T_MPStavke.IDProdavnice)= " & IDProdavnice & ") AND ((T_MPStavke.IDKasa)= " & IDKasa & "));"
    
    'kreirmo PRIVREMENI objekat (jer mu je ime "")
    Set QCopy = db.CreateQueryDef("", QCopySQL)
    Set QDelete = db.CreateQueryDef("", QDeleteSQL)
    varRet = True
    
    BeginTrans
        QCopy.Execute
        'MsgBox "Iz tabele T_MPStavke kopirano je " & QCopy.RecordsAffected & " slogova."
        varRet = varRet And (QCopy.RecordsAffected = 1)
        
        QDelete.Execute
        'MsgBox "U tabeli T_MPStavke obrisano je " & QDelete.RecordsAffected & " slogova."
        varRet = varRet And (QDelete.RecordsAffected = 1)
    CommitTrans

exit_ObrisiStavku:

On Error Resume Next
    
    db.Close
    Set db = Nothing
    Set QCopy = Nothing
    Set QDelete = Nothing
 
 PrenesiMPStavkuUObrisano = varRet
Exit Function

err_ObrisiStavku:
 Rollback
 Select Case err.Number
    
Case Else
 MsgBox "Error: " & err.Number & " " & err.Description
End Select
varRet = False
Resume exit_ObrisiStavku
End Function

Public Function UzmiMPStavkuIzObrisano(IDStavke As Long, IDDok As Long, IDProdavnice As Long, IDKasa As Long) As Boolean
    On Error GoTo err_ObrisiStavku

    Dim db As DAO.Database
    Dim QCopySQL As String
    Dim QDeleteSQL As String
    Dim QCopy As DAO.QueryDef
    Dim QDelete As DAO.QueryDef
    Dim varRet As Boolean
    
    Set db = CurrentDb
    
    'QCopySQL = "INSERT INTO T_MPStavke ( IDStavke, IDDok, IDProdavnice, IDKasa, [Sifra artikla], Kolicina, KalkulativnaMPCena, StvarnaMPCena, Taksa, TarifaRoba, IDStavMagOtpreme, Porudzbina, DatIVremePor )"
    'QCopySQL = QCopySQL & " SELECT T_MPStavke_Obrisane.IDStavke, T_MPStavke_Obrisane.IDDok, T_MPStavke_Obrisane.IDProdavnice, T_MPStavke_Obrisane.IDKasa, T_MPStavke_Obrisane.[Sifra artikla], T_MPStavke_Obrisane.Kolicina, T_MPStavke_Obrisane.KalkulativnaMPCena, T_MPStavke_Obrisane.StvarnaMPCena, T_MPStavke_Obrisane.Taksa, T_MPStavke_Obrisane.TarifaRoba, T_MPStavke_Obrisane.IDStavMagOtpreme, T_MPStavke_Obrisane.Porudzbina, T_MPStavke_Obrisane.DatIVremePor"
    
    QCopySQL = "INSERT INTO T_MPStavke (  IDDok, IDProdavnice, IDKasa, [Sifra artikla], Kolicina, KalkulativnaMPCena, StvarnaMPCena, Taksa, TarifaRoba, IDStavMagOtpreme, Porudzbina, DatIVremePor )"
    QCopySQL = QCopySQL & " SELECT  T_MPStavke_Obrisane.IDDok, T_MPStavke_Obrisane.IDProdavnice, T_MPStavke_Obrisane.IDKasa, T_MPStavke_Obrisane.[Sifra artikla], T_MPStavke_Obrisane.Kolicina, T_MPStavke_Obrisane.KalkulativnaMPCena, T_MPStavke_Obrisane.StvarnaMPCena, T_MPStavke_Obrisane.Taksa, T_MPStavke_Obrisane.TarifaRoba, T_MPStavke_Obrisane.IDStavMagOtpreme, T_MPStavke_Obrisane.Porudzbina, T_MPStavke_Obrisane.DatIVremePor"
    QCopySQL = QCopySQL & " FROM T_MPStavke_Obrisane"
    QCopySQL = QCopySQL & " WHERE (((T_MPStavke_Obrisane.IDStavke)=" & IDStavke & ") AND ((T_MPStavke_Obrisane.IDDok)=" & IDDok & ") AND ((T_MPStavke_Obrisane.IDProdavnice)= " & IDProdavnice & ") AND ((T_MPStavke_Obrisane.IDKasa)= " & IDKasa & "));"
    
    QDeleteSQL = "DELETE T_MPStavke_Obrisane.* FROM T_MPStavke_Obrisane"
    QDeleteSQL = QDeleteSQL & " WHERE (((T_MPStavke_Obrisane.IDStavke)=" & IDStavke & ") AND ((T_MPStavke_Obrisane.IDDok)=" & IDDok & ") AND ((T_MPStavke_Obrisane.IDProdavnice)= " & IDProdavnice & ") AND ((T_MPStavke_Obrisane.IDKasa)= " & IDKasa & "));"
    
    'kreirmo PRIVREMENI objekat (jer mu je ime "")
    Set QCopy = db.CreateQueryDef("", QCopySQL)
    Set QDelete = db.CreateQueryDef("", QDeleteSQL)
    varRet = True
    
    BeginTrans
        QCopy.Execute dbSeeChanges
        'MsgBox "Iz tabele T_MPStavke kopirano je " & QCopy.RecordsAffected & " slogova."
        varRet = varRet And (QCopy.RecordsAffected = 1)
        
        QDelete.Execute dbSeeChanges
        'MsgBox "U tabeli T_MPStavke obrisano je " & QDelete.RecordsAffected & " slogova."
        varRet = varRet And (QDelete.RecordsAffected = 1)
    CommitTrans

exit_ObrisiStavku:

On Error Resume Next
    
    db.Close
    Set db = Nothing
    Set QCopy = Nothing
    Set QDelete = Nothing
 
 UzmiMPStavkuIzObrisano = varRet
Exit Function

err_ObrisiStavku:
 Rollback
 Select Case err.Number
    
Case Else
 MsgBox "Error: " & err.Number & " " & err.Description
End Select
varRet = False
Resume exit_ObrisiStavku
End Function

