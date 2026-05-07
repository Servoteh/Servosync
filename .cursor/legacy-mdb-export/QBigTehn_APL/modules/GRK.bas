Attribute VB_Name = "GRK"
Option Compare Database
Option Explicit


Public Sub NapraviAutoKompenzaciju(KompImeUpita As String, ZaKonto1 As String, ZaKonto2 As String, ZaPoziciju As String, ZaKomitenta As Long, KompIznos As Currency, IDGrk As Long)
On Error GoTo err_Sub
' NapraviAutoKompenzaciju "GRK_OTST_ZKIK","20400","43500","*",4351,5000000,322
 Dim RstOTST_DEF As DAO.QueryDef
 Dim RstOTST As DAO.Recordset
 Dim RstKOMP As DAO.Recordset
 
 Dim PrometDuguje As Currency
 Dim PrometPotrazuje As Currency
 
 Dim DugKIznos As Currency
 Dim PotKIznos As Currency
 
 PrometDuguje = 0
 PrometPotrazuje = 0
 
 Set RstOTST_DEF = CurrentDb.QueryDefs(KompImeUpita)
 RstOTST_DEF.Parameters("[Forms]![GRKZag]![FilterZakonto1]") = ZaKonto1
 RstOTST_DEF.Parameters("[Forms]![GRKZag]![FilterZaKonto2]") = ZaKonto2
 RstOTST_DEF.Parameters("[Forms]![GRKZag]![FilterZaPoziciju]") = ZaPoziciju
 RstOTST_DEF.Parameters("[Forms]![GRKZag]![ZaKomitenta]") = ZaKomitenta
 Set RstOTST = RstOTST_DEF.OpenRecordset(dbOpenForwardOnly)
 Set RstKOMP = CurrentDb.OpenRecordset("T_GRKStavke")

 
 While Not RstOTST.EOF And ((PrometDuguje < KompIznos) Or (PrometPotrazuje < KompIznos))
  DoEvents
  DugKIznos = 0
  PotKIznos = 0
  
  If PrometDuguje < KompIznos Then
   If PrometDuguje + RstOTST!Duguje > KompIznos Then
     DugKIznos = KompIznos - PrometDuguje
   Else
     DugKIznos = RstOTST!Duguje
   End If
  End If
  
  If PrometPotrazuje < KompIznos Then
   If PrometPotrazuje + RstOTST!Potrazuje > KompIznos Then
     PotKIznos = KompIznos - PrometPotrazuje
   Else
     PotKIznos = RstOTST!Potrazuje
   End If
  End If
  
  If Abs(DugKIznos) >= 0.01 Or Abs(PotKIznos) >= 0.001 Then
   RstKOMP.AddNew
   RstKOMP!IDGrk = IDGrk
   RstKOMP!IDStavkeIzGK = RstOTST!StavkaID
   RstKOMP!Opis = "Auto"
   RstKOMP!Duguje = DugKIznos
   RstKOMP!Potrazuje = PotKIznos
   RstKOMP.Update
  End If
  
  PrometDuguje = PrometDuguje + DugKIznos
  PrometPotrazuje = PrometPotrazuje + PotKIznos
  
  'Debug.Print Din(RstOTST!Duguje), Din(RstOTST!Potrazuje), Din(PrometDuguje), Din(PrometPotrazuje)
  RstOTST.MoveNext
 Wend
Exit_Sub:
 On Error Resume Next
 RstKOMP.Close
 Set RstKOMP = Nothing
 RstOTST.Close
 Set RstOTST = Nothing
 RstOTST_DEF.Close
 Set RstOTST_DEF = Nothing
 Exit Sub
err_Sub:
  'MsgBox "Error: " & Err.Description & " (" & Err.Number & ")"
  
   BBErrorMSG err, "NapraviAutoKompenzaciju"
    
  Resume Exit_Sub:
 End Sub
