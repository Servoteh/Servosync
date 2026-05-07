Attribute VB_Name = "BBMsgBoxModule"
Option Compare Database
Option Explicit
Public BBMsgBoxRetVal As Long

Public Function BBMsgBox_BigBit(Poruka As String, Optional TrajanjeSec As Long = 0, Optional Dugmici As Long = vbOKOnly, Optional BojaPozadine) As Long
    DoCmd.OpenForm "BBMsgBoxFrm_BigBit"
    If TrajanjeSec <= 0 Then
        Forms!BBMsgBoxFrm_BigBit.TimerInterval = 0
    Else
        Forms!BBMsgBoxFrm_BigBit.TimerInterval = 1000
    End If
    If Dugmici = vbYesNo Then
        Forms!BBMsgBoxFrm_BigBit!DugmeDa.Visible = True
        Forms!BBMsgBoxFrm_BigBit!DugmeNe.Visible = True
        Forms!BBMsgBoxFrm_BigBit!DugmeOk.Visible = False
    Else
    End If
    If Not IsMissing(BojaPozadine) Then
    Forms!BBMsgBoxFrm_BigBit.Detail.BackColor = BojaPozadine
    End If
    
    Forms!BBMsgBoxFrm_BigBit!Poruka = Poruka
    Forms!BBMsgBoxFrm_BigBit!VremeTrajanja = TrajanjeSec
    Forms!BBMsgBoxFrm_BigBit.Repaint
    While IsLoaded("BBMsgBoxFrm_BigBit")
        DoEvents
    Wend
    BBMsgBox_BigBit = BBMsgBoxRetVal
End Function
Public Function BBMsgBox(Naslov As String, Poruka As String, Optional Poruka2 As String = "", Optional TrajanjeSec As Long = 0, _
                            Optional Dugmici As Long = vbOKOnly, Optional VelicinaSlovaPoruke As Long = 12, _
                            Optional VelicinaSlovaPoruke2 As Long = 12, Optional BojaSlova As Long = 8388608, Optional BojaSlova2 As Long = 8388608) As Long
    DoCmd.OpenForm "BBMsgBoxFrm"
    If TrajanjeSec <= 0 Then
        Forms!BBMsgBoxFrm.TimerInterval = 0
    Else
        Forms!BBMsgBoxFrm.TimerInterval = 500
    End If
    'Forms!BBMsgBoxFrm!DugmeDa.SetFocus
    If Dugmici = vbYesNo Then
        Forms!BBMsgBoxFrm!DugmeDa.Visible = True
        Forms!BBMsgBoxFrm!DugmeNe.Visible = True
        Forms!BBMsgBoxFrm!DugmeOk.Visible = False
    Else
    End If
    Forms!BBMsgBoxFrm.Caption = Naslov
    If Poruka2 <> "" Then
        Forms!BBMsgBoxFrm!Poruka = Poruka
        Forms!BBMsgBoxFrm!Poruka.FontSize = VelicinaSlovaPoruke
        Forms!BBMsgBoxFrm!Poruka.ForeColor = BojaSlova
        Forms!BBMsgBoxFrm!Poruka2 = Poruka2
        Forms!BBMsgBoxFrm!Poruka2.FontSize = VelicinaSlovaPoruke2
        Forms!BBMsgBoxFrm!Poruka2.ForeColor = BojaSlova2
    Else
        Forms!BBMsgBoxFrm!Poruka2.Visible = False
        Forms!BBMsgBoxFrm!Poruka.height = 1300
        Forms!BBMsgBoxFrm!Poruka = Poruka
        Forms!BBMsgBoxFrm!Poruka.FontSize = VelicinaSlovaPoruke
        Forms!BBMsgBoxFrm!Poruka.ForeColor = BojaSlova
    End If
    Forms!BBMsgBoxFrm!VremeTrajanja = TrajanjeSec
    Forms!BBMsgBoxFrm.Repaint
    While IsLoaded("BBMsgBoxFrm")
        DoEvents
    Wend
    BBMsgBox = BBMsgBoxRetVal
End Function

Public Function BBMsgDaLiSteSigurni(Optional Poruka As String = "Da li ste sigurni?") As Boolean
    Dim odgovor
    odgovor = MsgBox(Poruka, vbQuestion + vbYesNo, "QMegaTeh")
    BBMsgDaLiSteSigurni = (odgovor = vbYes)
End Function
Public Function BBPitanje(pitanje As String, Optional DefaultBaton = vbDefaultButton1) As Boolean
    Dim odgovor
    odgovor = MsgBox(pitanje, vbQuestion + vbYesNo + DefaultBaton, "QMegaTeh")
    BBPitanje = (odgovor = vbYes)
End Function
