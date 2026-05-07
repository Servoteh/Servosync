VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_IzborStolaPanel"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
Dim OtvoreniRacuni(1 To 200, 0 To 3) As Long

Private Sub PostaviStolove()
    Dim ctl As control
    Dim rstDef As DAO.QueryDef
    Dim rst As DAO.Recordset
    Dim nadjensto As Boolean
    Dim IDKonobarKojiRadi As Long
    Dim BrojStola As Integer
    Dim IDKupac As Long
    
    
    'Set rstdef = CurrentDb.QueryDefs("RacuniZaIzborNaDan")
    Set rstDef = CurrentDb.QueryDefs("ZauzetiStolovi")
    rstDef.Parameters("OdDatuma") = DateAdd("d", -1, Forms!PrvaMaskaKonobar!DanasnjiDatum)
    rstDef.Parameters("DoDatuma") = DateAdd("d", 1, Forms!PrvaMaskaKonobar!DanasnjiDatum)
    rstDef.Parameters("ZaIDProdavnica") = Forms!PrvaMaskaKonobar!IDProdavnica
    Set rst = rstDef.OpenRecordset(dbOpenDynaset, dbSeeChanges)
    
    IDKonobarKojiRadi = CLng(Nz(Forms!PrvaMaskaKonobar!IDKonobar, 0))
    IDKupac = CLng(Nz(ReadParametar("CFG_Lokal", "STDKupac"), 0))
    For Each ctl In Me.Controls
        
        If ctl.ControlType = acCommandButton And ctl.Name Like "StoBroj*" Then
            BrojStola = CInt(ctl.tag)
            OtvoreniRacuni(BrojStola, 0) = 0            'IDRacun
            OtvoreniRacuni(BrojStola, 1) = 0            'IDProdavnica
            OtvoreniRacuni(BrojStola, 2) = BrojStola    'Broj stola
            OtvoreniRacuni(BrojStola, 3) = IDKupac    'IDKomitent
            
            ctl.Caption = ctl.tag
            If IDKonobarKojiRadi <= 0 Then
                ctl.Enabled = False
            Else
                ctl.Enabled = True
            End If
        If Not (rst.EOF And rst.BOF) Then
            rst.MoveFirst
        End If
        nadjensto = False
        While Not rst.EOF And Not nadjensto
            If CStr(rst!Sto) = CStr(ctl.tag) Then
                'ctl.Caption = rst!Konobar & vbCrLf & ctl.Tag & vbCrLf & "(" & rst!NazivKupca & ")" '& DoChLeft(Din(rst!IznosNaRacunu), 10, " ")
                ctl.Caption = rst!Konobar & vbCrLf & ctl.tag
                ctl.ForeColor = vbBlue
                nadjensto = True
                If (rst!IDKonobar = IDKonobarKojiRadi) Or (rst!IDKonobar = 0) Then
                    BrojStola = CInt(ctl.tag)
                    OtvoreniRacuni(BrojStola, 0) = rst!IDRacun        'IDRacun
                    OtvoreniRacuni(BrojStola, 1) = rst!IDProdavnica   'IDProdavnica
                    OtvoreniRacuni(BrojStola, 2) = BrojStola          'Broj stola
                    OtvoreniRacuni(BrojStola, 3) = rst!IDKupac        'IDKupac
                    If IDKonobarKojiRadi = 0 Then
                       ctl.Enabled = False
                    Else
                       ctl.Enabled = True
                    End If
                Else
                    ctl.Enabled = False
                End If
            End If
         rst.MoveNext
        Wend
        
        End If
      
    Next
   rstDef.Close
   Set rstDef = Nothing
   rst.Close
   Set rst = Nothing
End Sub

Private Sub Form_Close()
'    UpisiUDnevnik CurrentUser(), "", Me.Name, "Close"
End Sub

Private Sub Form_Error(DataErr As Integer, Response As Integer)
    MsgBox "Greska IzborStolaPanel! Error: " & DataErr, vbExclamation, "Tehnologija"
    Response = acDataErrContinue
End Sub

Private Sub Form_Open(Cancel As Integer)
    'OtvoreniRacuni = Array(200, 2)
    PostaviStolove
   ' UpisiUDnevnik CurrentUser(), "", Me.Name, "Open"
End Sub
Private Function StoJeIzabran()
 Dim aktivnaKontrola As control
 Set aktivnaKontrola = Screen.ActiveControl
 Dim BrojStola As Integer
 'Dim PredlogZaBrojPorudzbine As Integer
 Dim IDRacun As Long
 Dim IDKupac As Long
    'MsgBox "Izabrano: " & AktivnaKontrola.Parent.Name & " Sto broj " & AktivnaKontrola.Tag
    'MsgBox "Izabran je sto broj " & AktivnaKontrola.Caption
    BrojStola = CInt(aktivnaKontrola.tag)
    Forms!PrvaMaskaKonobar!BrojStola = BrojStola
    IDRacun = OtvoreniRacuni(BrojStola, 0)
    IDKupac = OtvoreniRacuni(BrojStola, 3)
    If IDRacun = 0 Then
       IDRacun = OtvoriRacun(BrojStola, Forms!PrvaMaskaKonobar!IDKonobar, Forms!PrvaMaskaKonobar!IDProdavnica, IDKupac, Forms!PrvaMaskaKonobar!IDKasa, Forms!PrvaMaskaKonobar!LimitIznos)
       OtvoreniRacuni(BrojStola, 1) = Forms!PrvaMaskaKonobar!IDProdavnica
    End If
    KonobarUzimaRacun Forms!PrvaMaskaKonobar!IDKonobar, IDRacun, Forms!PrvaMaskaKonobar!IDProdavnica, Forms!PrvaMaskaKonobar!IDKasa
    Forms!PrvaMaskaKonobar!IDRacun = IDRacun
    Forms!PrvaMaskaKonobar!IDProdavnica = OtvoreniRacuni(BrojStola, 1)
    Forms!PrvaMaskaKonobar!IDKomitent = OtvoreniRacuni(BrojStola, 3)
    'PredlogZaBrojPorudzbine = 1 + Nz(DMax("[Porudzbina]", "RacunStavke", "[IDRacun] = " & IDRacun & " and [IDProdavnica] = " & OtvoreniRacuni(BrojStola, 1)), 0)
    'Forms!PrvaMaskaKonobar!PredlogZaBrojPorudzbine = PredlogZaBrojPorudzbine
    Forms!PrvaMaskaKonobar!PredlogZaBrojPorudzbine = SledecaTura(IDRacun, OtvoreniRacuni(BrojStola, 1))
    Forms!PrvaMaskaKonobar!Podforma.SourceObject = "Prodaja"
End Function

