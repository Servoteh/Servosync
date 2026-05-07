Attribute VB_Name = "PPS_Modul"
Option Compare Database
Option Explicit

Public Function BB_Offset() As Long

    BB_Offset = Nz(Forms!PPS!txtOffset, 0)

End Function


Public Function BB_PageSize() As Long

    BB_PageSize = Nz(Forms!PPS!txtPageSize, 20)

End Function

