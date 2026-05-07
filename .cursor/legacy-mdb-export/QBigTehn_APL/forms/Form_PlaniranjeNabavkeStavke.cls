VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_PlaniranjeNabavkeStavke"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub Form_AfterUpdate()
    Me.Parent.DefinisiEnabledZaDugmice
End Sub

Private Sub Form_Current()
    ProveriZakljucavanje
End Sub

Private Sub Form_Open(Cancel As Integer)
'    PrimeniUslove
End Sub

Private Sub Form_Unload(Cancel As Integer)
'    CloseConnectionOnCurrentForm Me
End Sub
Private Sub ProveriZakljucavanje()
'Application.Echo False
    If Nz(Forms![PlaniranjeNabavke].Zakljucano, False) Then
        
        Me.Detail.BackColor = BBCFG.ColorLock
        Me.FormFooter.BackColor = BBCFG.ColorLock
        Me.FormHeader.BackColor = BBCFG.ColorLock
        
        Me.AllowEdits = False
        Me.AllowDeletions = False
        Me.AllowAdditions = False
    Else
        Me.Detail.BackColor = BBCFG.ColorUnLock
        Me.FormFooter.BackColor = BBCFG.ColorUnLock
        Me.FormHeader.BackColor = BBCFG.ColorUnLock
        
        Me.AllowEdits = True
        Me.AllowDeletions = True
        Me.AllowAdditions = True
        
    End If
  'Application.Echo True
End Sub


Private Sub SifraArtikla_AfterUpdate()
On Error GoTo Err_Point
    Dim retValOk As Boolean
    Dim Zalihe As Double
    Dim Rezervisano As Double
    Dim SlobodneZalihe As Double
    Dim SifraArtikla As Long
    
    
    If Not IsNull(Me!SifraArtikla) Then
        SifraArtikla = Me!SifraArtikla
        Me!KataloskiBrojStavke = Me!SifraArtikla.Column(2)
        Me!NazivArtiklaStavke = Me!SifraArtikla.Column(1)
        
        Zalihe = Nz(DLookup("PlusMinusKolicina", "BB_StanjeKolicinaNaDan", "[Sifra artikla] = " & stR(SifraArtikla)), 0)
        Rezervisano = Nz(DLookup("RezervisanaKolicina", "BB_RezervisaneKolicine", "[Sifra artikla] = " & stR(SifraArtikla)), 0)
        SlobodneZalihe = Zalihe - Rezervisano
        If SlobodneZalihe >= 0 Then
            'retValOk = ADO_UpdateColumn(CNN_CurrentDataBase, "PDM_PlaniranjeStavke", "Zalihe", SlobodneZalihe, "IDPlanStavka=" & CStr(Me!IDPlanStavka))
            'If retValOk Then
                Me!Zalihe = SlobodneZalihe
            'End If
        End If
                    
    End If

Exit_Point:
Exit Sub

Err_Point:
MsgBox err.Description
Resume Exit_Point


End Sub
