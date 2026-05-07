Attribute VB_Name = "NKEPU"
Option Compare Database
Option Explicit


Public Function KepuVredIzraza(defizraz As String, KLMP As Currency, StvarnaMP As Currency) As Currency
    
    KepuVredIzraza = VredIzraza(defizraz, KLMP, StvarnaMP, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
    
End Function
