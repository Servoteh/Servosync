VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "ComPortPar"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private pCommPortNo As Byte
Private pCommPortSettings As String
Private pTestGaleb As Boolean
Private pTestPapirGaleb As Boolean
Private pProveraNaplataCek As Boolean
Private pProveraNaplataKartica As Boolean
Private pProveraPoklopac As Boolean
Private pDelayTimeMiliSec As Single

Public Property Get CommPortNo() As Byte
    CommPortNo = pCommPortNo
End Property

Public Property Let CommPortNo(ByVal vNewValue As Byte)
    pCommPortNo = vNewValue
End Property

Public Property Get CommPortSettings() As String
    CommPortSettings = pCommPortSettings
End Property

Public Property Let CommPortSettings(ByVal vNewValue As String)
    pCommPortSettings = vNewValue
End Property
Public Property Get TestGaleb() As Boolean
    TestGaleb = pTestGaleb
End Property

Public Property Let TestGaleb(ByVal vNewValue As Boolean)
    pTestGaleb = vNewValue
End Property

Public Property Get TestPapirGaleb() As Boolean
    TestPapirGaleb = pTestPapirGaleb
End Property

Public Property Let TestPapirGaleb(ByVal vNewValue As Boolean)
    pTestPapirGaleb = vNewValue
End Property

Public Property Get ProveraNaplataCek() As Boolean
    ProveraNaplataCek = pProveraNaplataCek
End Property

Public Property Let ProveraNaplataCek(ByVal vNewValue As Boolean)
    pProveraNaplataCek = vNewValue
End Property

Public Property Get ProveraNaplataKartica() As Boolean
    ProveraNaplataKartica = pProveraNaplataKartica
End Property

Public Property Let ProveraNaplataKartica(ByVal vNewValue As Boolean)
    pProveraNaplataKartica = vNewValue
End Property
Public Property Get ProveraPoklopac() As Boolean
    ProveraPoklopac = pProveraPoklopac
End Property
Public Property Let ProveraPoklopac(ByVal vNewValue As Boolean)
    pProveraPoklopac = vNewValue
End Property

Public Property Get DelayTimeMiliSec() As Single
    DelayTimeMiliSec = pDelayTimeMiliSec
End Property
Public Property Let DelayTimeMiliSec(ByVal vNewValue As Single)
    pDelayTimeMiliSec = vNewValue
End Property
Private Sub Class_Initialize()
    'pCommPortNo = 1
    pCommPortNo = Nz(ReadParametar("CFG_Lokal", "FP.CommPort"), 1)
    'pCommPortSettings = "19200,N,8,1"
    pCommPortSettings = Nz(ReadParametar("CFG_Lokal", "FP.CommPortSettings"), "19200,N,8,1")
    pTestGaleb = Nz(ReadParametar("CFG_Lokal", "FP.TestGaleb"), False)
    pTestPapirGaleb = Nz(ReadParametar("CFG_Lokal", "FP.TestPapirGaleb"), False)
    pProveraNaplataCek = Nz(ReadParametar("CFG_Lokal", "FP.ProveraNaplataCek"), False)
    pProveraNaplataKartica = Nz(ReadParametar("CFG_Lokal", "FP.ProveraNaplataKartica"), False)
    pProveraPoklopac = Nz(ReadParametar("CFG_Lokal", "FP.ProveraPoklopac"), True)
    pDelayTimeMiliSec = Nz(ReadParametar("CFG_Lokal", "FP.DelayTimeMiliSec"), 200)
End Sub

