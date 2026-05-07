Attribute VB_Name = "RN_SQLUpiti"
Option Compare Database
Option Explicit
Public Function IzvrsiNekiUpit(DATUM, ukljuciDatum)
Dim strSQL As String
Dim trdug, ID As Double

   ' DELETE T_PoseteSastav.*, T_PoseteSastav.IDPoseta
   ' FROM T_PoseteSastav
   ' WHERE (((T_PoseteSastav.IDPoseta)=[ZaIDposeta]));

   ' UPDATE T_Posete SET T_Posete.Prioritet = [Unos]
   ' WHERE (((T_Posete.IDPoseta)=[ZaIDPoseta]));

    
    strSQL = "UPDATE PazariZetTbl SET PazariZetTbl.CekDug='" & trdug & Chr(39) & _
            " WHERE PazariZetTbl.IDPazara=" & ID

    DoCmd.SetWarnings False
    DoCmd.RunSQL strSQL
    DoCmd.SetWarnings True
        
    
           
       
            strSQL = "UPDATE PazariZetTbl SET PazariZetTbl.CekDug='" & trdug & Chr(39) & _
            " WHERE PazariZetTbl.IDPazara=" & ID

            DoCmd.SetWarnings False
                DoCmd.RunSQL strSQL
            DoCmd.SetWarnings True
            
End Function

Public Function ObrisiPostupakZaIDPostupka(IDPostupka As Long)
Dim strSQL As String

    strSQL = "DELETE tTehPostupak.*, tTehPostupak.IDPostupka" & _
             " FROM tTehPostupak" & _
             " WHERE (((tTehPostupak.IDPostupka)=" & IDPostupka & "));"

    
    DoCmd.SetWarnings False
    DoCmd.RunSQL strSQL
    DoCmd.SetWarnings True
        
    
End Function

