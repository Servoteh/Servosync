Attribute VB_Name = "SMS_Modul"
Option Compare Database
Option Explicit


Public Function SMSTextZaSaldo(Iznos As Double, NaDan As Date) As String
    Dim tmpst As String
    
    tmpst = "Vase dospele a neizmirene obaveze na dan " & NaDan & " iznose " & Din(Iznos) & "din. Molimo Vas da ih sto pre izmirite."
    tmpst = tmpst & " " & DLookup("[Firma]", "Radni fajlovi", "[IDBaze] = " & F_IDAktivneBaze())
    SMSTextZaSaldo = tmpst
End Function
