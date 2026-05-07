Attribute VB_Name = "LIB_ACS"
Option Compare Database
Option Explicit
Public Function ReadCardSlow(Optional ByVal BrojPokusaja As Long = 1, Optional ByVal SaPorukom As Boolean = True) As String

Dim i As Long
Dim Kartica As String
Dim retVal As Integer
Dim Core As Object
Dim ACSCommPort As String
Dim odgovor
Dim PonoviPetlju As Boolean
Dim StartTime, endTime As Variant

PonoviPetlju = False
ACSCommPort = InputBox("ACS.CommPort") 'Nz(ReadParametar("CFG_Lokal", "ACS.CommPort"), 1)
Set Core = CreateObject("NFCLibrary.PollingCore")

    Kartica = ""

    Call Core.Connect(ACSCommPort)
    Do
        retVal = 1
        i = 0
        While ((retVal <> 0) And (i < BrojPokusaja))
           'StartTime = Timer
            retVal = Core.ReadCard(Kartica)
           ' EndTime = Timer
           'Debug.Print EndTime - StartTime
            i = i + 1
            If i Mod 5 = 0 Then
                DoEvents
            End If
        Wend
    
        If (Kartica <> "") Then
            ReadCardSlow = Trim$(Kartica)
            PonoviPetlju = False
        Else
            ReadCardSlow = ""
        End If
        
        If ((Kartica = "") And SaPorukom) Then
            odgovor = MsgBox("Kartica nije oèitana!" & vbCrLf & "Želite da pokušate ponovo?", vbCritical + vbYesNo, "BBKafe")
            PonoviPetlju = (odgovor = vbYes)
            ' !!!!SAMO ZA TESTIRANJE ReadCardSlow = "1" !!!!
        End If
    Loop While PonoviPetlju
    Core.Disconnect

End Function

Public Function ReadCardQuick(ByRef Core, Optional ByVal BrojPokusaja As Long = 1, Optional ByVal SaPorukom As Boolean = True) As String

Dim i As Long
Dim Kartica As String
Dim retVal As Integer
'Dim Core As Object
'Dim ACSCommPort As String
Dim odgovor
Dim PonoviPetlju As Boolean
Dim StartTime, endTime As Variant

'ACSCommPort = Nz(ReadParametar("CFG_Lokal", "ACS.CommPort"), 1)
'Set Core = CreateObject("NFCLibrary.PollingCore")
'Call Core.Connect(ACSCommPort)
    Kartica = ""
    PonoviPetlju = False

    
    Do
        retVal = 1
        i = 0
        While ((retVal <> 0) And (i < BrojPokusaja))
           'StartTime = Timer
            retVal = Core.ReadCard(Kartica)
           'EndTime = Timer
           'Debug.Print EndTime - StartTime
            i = i + 1
            If i Mod 5 = 0 Then
                DoEvents
            End If
        Wend
    
        If (Kartica <> "") Then
            ReadCardQuick = Trim$(Kartica)
            PonoviPetlju = False
        Else
            ReadCardQuick = ""
        End If
        
        If ((Kartica = "") And SaPorukom) Then
            odgovor = MsgBox("Kartica nije oèitana!" & vbCrLf & "Želite da pokušate ponovo?", vbCritical + vbYesNo, "BBKafe")
            PonoviPetlju = (odgovor = vbYes)
        End If
    Loop While PonoviPetlju
 '   Core.Disconnect

End Function
