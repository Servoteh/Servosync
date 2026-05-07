VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_frmPDMTreeView_Sub"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
' U UserFormu ili Access formi, u VBA projektu gde si referencirao MSComctlLib:
Private m_tvwEvents As clsTreeViewEvents
Private m_IDCrtez As Long

Public Sub SetIDCrtez(ByVal v As Long)
    m_IDCrtez = v
    If m_IDCrtez > 0 Then
        Call InitTree
    End If
End Sub

' Inicijalizacija TreeView kontrole (npr. u Form_Open)
Public Function InitTree()
    Dim tvw As MSComctlLib.TreeView
    Set tvw = Me!TreeView0.Object
    
    tvw.Nodes.Clear
    
    Dim rootID As Long
    Dim rootLabel As String
    Dim rs As DAO.Recordset
    
    rootID = m_IDCrtez
    If rootID = 0 Then Exit Function

    Set rs = CurrentDb.OpenRecordset( _
            "SELECT BrojCrteza, Revizija FROM PDMCrtezi WHERE IDCrtez=" & rootID)

    If Not rs.EOF Then
        rootLabel = rs!BrojCrteza & "-" & rs!Revizija
    Else
        rootLabel = "Nepoznat crtež " & rootID
    End If
    rs.Close

    Dim ndRoot As MSComctlLib.Node
    Set ndRoot = tvw.Nodes.Add(, , "R" & rootID, rootLabel)
    ndRoot.tag = rootID

    LoadChildren tvw, ndRoot, rootID
    'Call ExpandAllNodes
    
    ' Ako je ukljuèeno "Proširi sve"
    'If Me.Parent!chkExpandAll = True Then
    '    Call ExpandAllNodes
    'Else
        ndRoot.Expanded = True   ' samo prvi nivo
    'End If

End Function

Private Sub LoadChildren(tvw As MSComctlLib.TreeView, _
                         parentNode As MSComctlLib.Node, _
                         parentID As Long)

    Dim rs As DAO.Recordset
    Dim sql As String
    Dim childID As Long
    Dim childKey As String
    Dim lbl As String
    Dim nd As MSComctlLib.Node

    sql = "SELECT K.TrebaIDCrtez, C.BrojCrteza, C.Revizija, K.PotrebnoKomada " & _
          "FROM KomponentePDMCrteza AS K " & _
          "INNER JOIN PDMCrtezi AS C ON C.IDCrtez = K.TrebaIDCrtez " & _
          "WHERE K.ZaIDCrtez = " & parentID

    Set rs = CurrentDb.OpenRecordset(sql, dbOpenSnapshot)

    Do While Not rs.EOF

        childID = rs!TrebaIDCrtez
        childKey = parentNode.key & "_" & childID
        lbl = rs!BrojCrteza & "-" & rs!Revizija & " (x" & rs!PotrebnoKomada & ")"

        ' Dodaj node
        Set nd = tvw.Nodes.Add( _
                    Relative:=parentNode.key, _
                    Relationship:=tvwChild, _
                    key:=childKey, _
                    Text:=lbl)

        nd.tag = childID

        ' (Opcionalno — ikonice, aktiviraæemo kasnije)
        'If ImaDecu(childID) Then
        '    nd.Image = "sklop"
        '    nd.SelectedImage = "sklop"
        'Else
        '    nd.Image = "deo"
        '    nd.SelectedImage = "deo"
        'End If

        ' Rekurzija — puni decu
        LoadChildren tvw, nd, childID

        rs.MoveNext
    Loop

    rs.Close
    Set rs = Nothing
End Sub

Public Sub ExpandAllNodes()
    Dim tvw As MSComctlLib.TreeView
    Dim nd As MSComctlLib.Node

    Set tvw = Me!TreeView0.Object

    If tvw.Nodes.Count = 0 Then Exit Sub

    Set nd = tvw.Nodes(1) ' root node
    ExpandNodeRecursive nd
End Sub

Private Sub ExpandNodeRecursive(ByVal nd As MSComctlLib.Node)
    Dim child As MSComctlLib.Node

    On Error Resume Next

    nd.Expanded = True   ' proširi ovaj

    ' proveri decu
    Set child = nd.child
    While Not child Is Nothing
        ExpandNodeRecursive child   ' rekurzija za svako dete
        Set child = child.Next      ' preði na sledeæi èvor na istom nivou
    Wend
End Sub

