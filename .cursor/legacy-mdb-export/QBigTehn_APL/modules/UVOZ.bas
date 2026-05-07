Attribute VB_Name = "UVOZ"
Option Compare Database
Option Explicit

Public Sub ObracunajUvoz(CarKurs As Double, _
                          ObrKurs As Double, _
                          PovCarOsn As Double, _
                          Spedicija As Double, _
                          OstaliZavTros As Double, _
                          DevVredFak As Double, _
                          StavkeCarStopa As Double, _
                          DevNabCena As Double, _
                          procztdob As Double, _
                          procztsop As Double, _
                          DinNabCen As Double)

    Dim carosnjm As Double     ' carinska osnovica po JediniciMere
    Dim carinajm As Double      ' carina po JM
    Dim osnpdvjm As Double      ' osnovica ulaznog PDV po JM
    'Dim DinNabCen As Double
    'Dim procztdob As Double
    'Dim procztsop As Double
    Dim brutonabvredbezcarine As Double
    Dim brutonabkoefbezcarine As Double
    Dim BrutoNabCena As Double
    

    If Nz(DevVredFak, 0) <> 0 Then
        carosnjm = DevNabCena * CarKurs
        carosnjm = carosnjm + PovCarOsn / DevVredFak * DevNabCena
        
        carinajm = carosnjm * (StavkeCarStopa / 100)
        
        osnpdvjm = carosnjm + carinajm + (Spedicija / DevVredFak) * DevNabCena
        
        DinNabCen = DevNabCena * ObrKurs
        'DinNabCen = DinNabCen + carinajm + (Spedicija / DevVredFak) * DevNabCena
        
        If DinNabCen <> 0 Then
            procztdob = ((osnpdvjm / DinNabCen) - 1) * 100
        Else
            procztdob = 0
        End If
        
        brutonabvredbezcarine = DevVredFak * ObrKurs
        brutonabvredbezcarine = brutonabvredbezcarine + PovCarOsn
        brutonabvredbezcarine = brutonabvredbezcarine + Spedicija + OstaliZavTros
        
        brutonabkoefbezcarine = brutonabvredbezcarine / DevVredFak
        BrutoNabCena = DevNabCena * brutonabkoefbezcarine + carinajm
        If DinNabCen <> 0 Then
            procztsop = ((BrutoNabCena / DinNabCen) - 1) * 100 - procztdob
        Else
            procztsop = 0
        End If
    'Modifikovano: 16-12-2020
    Else
       DinNabCen = DevNabCena * ObrKurs
    End If

End Sub

Public Function ZTDobUvoz(CarKurs As Double, _
                          ObrKurs As Double, _
                          PovCarOsn As Double, _
                          Spedicija As Double, _
                          OstaliZavTros As Double, _
                          DevVredFak As Double, _
                          StavkeCarStopa As Double, _
                          DevNabCena As Double) As Double
                          
    Dim DinNabCen As Double
    Dim procztdob As Double
    Dim procztsop As Double
    
    ObracunajUvoz CarKurs, _
                    ObrKurs, _
                    PovCarOsn, _
                    Spedicija, _
                    OstaliZavTros, _
                    DevVredFak, _
                    StavkeCarStopa, _
                    DevNabCena, _
                    procztdob, _
                    procztsop, _
                    DinNabCen
                    
    ZTDobUvoz = (procztdob / 100) * DinNabCen

End Function
Public Function ZTSopUvoz(CarKurs As Double, _
                          ObrKurs As Double, _
                          PovCarOsn As Double, _
                          Spedicija As Double, _
                          OstaliZavTros As Double, _
                          DevVredFak As Double, _
                          StavkeCarStopa As Double, _
                          DevNabCena As Double) As Double
                          
    Dim DinNabCen As Double
    Dim procztdob As Double
    Dim procztsop As Double
    
    ObracunajUvoz CarKurs, _
                    ObrKurs, _
                    PovCarOsn, _
                    Spedicija, _
                    OstaliZavTros, _
                    DevVredFak, _
                    StavkeCarStopa, _
                    DevNabCena, _
                    procztdob, _
                    procztsop, _
                    DinNabCen
                    
    ZTSopUvoz = (procztsop / 100) * DinNabCen

End Function

Public Function DinNabCenUvoz(CarKurs As Double, _
                          ObrKurs As Double, _
                          PovCarOsn As Double, _
                          Spedicija As Double, _
                          OstaliZavTros As Double, _
                          DevVredFak As Double, _
                          StavkeCarStopa As Double, _
                          DevNabCena As Double) As Double
                          
    Dim DinNabCen As Double
    Dim procztdob As Double
    Dim procztsop As Double
    
    ObracunajUvoz CarKurs, _
                    ObrKurs, _
                    PovCarOsn, _
                    Spedicija, _
                    OstaliZavTros, _
                    DevVredFak, _
                    StavkeCarStopa, _
                    DevNabCena, _
                    procztdob, _
                    procztsop, _
                    DinNabCen
                    
    DinNabCenUvoz = DinNabCen

End Function


