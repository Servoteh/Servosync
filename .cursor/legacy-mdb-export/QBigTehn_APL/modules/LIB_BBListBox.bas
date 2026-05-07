Attribute VB_Name = "LIB_BBListBox"
Option Compare Database
Option Explicit


Public Function IsSelectedInListBox_(ByVal vVal, ByRef ctlListBox As ListBox) As Boolean
 Dim retVal As Boolean
 Dim varItm As Variant
 
 retVal = False
    For Each varItm In ctlListBox.ItemsSelected
        retVal = retVal Or (vVal = ctlListBox.ItemData(varItm))
    Next varItm

 IsSelectedInListBox_ = retVal
End Function
Public Function IsSelectedInListBox(ByVal vVal, frmName As String, ctlListBoxName As String) As Boolean
'Forms("Pregled Artikala").Controls("ListGrupe").ItemsSelected.count
  Dim ctlListBox As ListBox
  Dim varItm As Variant
  Dim retVal As Boolean
 
 If Not IsLoaded(frmName) Then
  IsSelectedInListBox = True
  Exit Function
 End If
 
 On Error Resume Next
 If Forms(frmName).Controls(ctlListBoxName).ItemsSelected.Count = 0 Then
    IsSelectedInListBox = True
  Exit Function
 End If
 
 retVal = False
    For Each varItm In Forms(frmName).Controls(ctlListBoxName).ItemsSelected
        retVal = retVal Or (vVal = Forms(frmName).Controls(ctlListBoxName).ItemData(varItm))
    Next varItm
  IsSelectedInListBox = retVal
End Function
Public Sub ClearListBox(frmName As String, ctlListBoxName As String)
'Forms("Pregled Artikala").Controls("ListGrupe").ItemsSelected.count
  Dim ctlListBox As ListBox
    Dim i As Long
    Dim tmpRowSource
 
 If Not IsLoaded(frmName) Then
  Exit Sub
 End If
 
 If Forms(frmName).Controls(ctlListBoxName).ItemsSelected.Count = 0 Then
  Exit Sub
 End If
 tmpRowSource = Forms(frmName).Controls(ctlListBoxName).RowSource
 Forms(frmName).Controls(ctlListBoxName).RowSource = tmpRowSource
 ' Forms(frmName).Controls(ctlListBoxName).Requery
 
 '   For i = 1 To Forms(frmName).Controls(ctlListBoxName).ItemsSelected.Count
 '       Debug.Print Forms(frmName).Controls(ctlListBoxName).ItemData(i)
 '   Next i
End Sub

