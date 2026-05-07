Attribute VB_Name = "LIB_NasaSlova"
Option Compare Binary ' Jako bitno zbog funkcije ZameniNasaSlova
Option Explicit
'***************************************************************
'Modifikovano: 21-12-2019
'Stavljeno u poseban modul zbog Option Compare Binary
'***************************************************************
Public Function ZameniNasaSlova(st As String) As Variant

    Dim umesto(10) As String
    Dim stavi(10) As String
    Dim i As Long
    
    If Not IsNull(st) Then
    
    umesto(1) = "Š": stavi(1) = "S"
    umesto(2) = "š": stavi(2) = "s"
    umesto(3) = "Ž": stavi(3) = "Z"
    umesto(4) = "ž": stavi(4) = "z"
    umesto(5) = "È": stavi(5) = "C"
    umesto(6) = "è": stavi(6) = "c"
    umesto(7) = "Æ": stavi(7) = "C"
    umesto(8) = "æ": stavi(8) = "c"
    umesto(9) = "Ð": stavi(9) = "Dj"
    umesto(10) = "ð": stavi(10) = "dj"
    
    For i = 1 To 10
        'st = ZameniStr(umesto(i), stavi(i), st) 'Modifikovano: 21-12-2019
        st = Replace(st, umesto(i), stavi(i))    'Modifikovano: 21-12-2019
    Next i
    
    End If
    
    ZameniNasaSlova = st
    
End Function
Public Function YusciTo1250(st As String) As Variant

    Dim umesto(10) As String
    Dim stavi(10) As String
    Dim i As Long
    
    If Not IsNull(st) Then
    
    umesto(1) = "[": stavi(1) = "Š"
    umesto(2) = "{": stavi(2) = "š"
    umesto(3) = "@": stavi(3) = "Ž"
    umesto(4) = "`": stavi(4) = "ž"
    umesto(5) = "^": stavi(5) = "È"
    umesto(6) = "~": stavi(6) = "è"
    umesto(7) = "]": stavi(7) = "Æ"
    umesto(8) = "}": stavi(8) = "æ"
    umesto(9) = "\": stavi(9) = "Ð"
    umesto(10) = "|": stavi(10) = "ð"
    
    For i = 1 To 10
        'st = ZameniStr(umesto(i), stavi(i), st)    'Modifikovano: 21-12-2019
        st = Replace(st, umesto(i), stavi(i))       'Modifikovano: 21-12-2019
    Next i
    
    End If
    
    YusciTo1250 = st
    
End Function
