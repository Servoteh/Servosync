VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_SRPENG_SrpskiPodforma"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private Sub Srpski_DblClick(Cancel As Integer)
    Forms!SRPENG_Recnik!ComboSrpski = Me!Srpski
    
    Forms!SRPENG_Recnik.RecordsetClone.FindFirst "[Srpski] = '" & Forms!SRPENG_Recnik![ComboSrpski] & "'"
    Forms!SRPENG_Recnik.Bookmark = Forms!SRPENG_Recnik.RecordsetClone.Bookmark
    Forms!SRPENG_Recnik.ComboEngleski = Null
End Sub
