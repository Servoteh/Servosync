VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_frmWhereUsed_Sub"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit

Private m_IDCrtez As Long

Public Sub SetIDCrtez(ByVal v As Long)
    m_IDCrtez = v

    If m_IDCrtez > 0 Then
        Call InitTree
    End If
End Sub
'-------------------------------------------------------------
'  INIT TREE – Kreira root node i puni stablo
'-------------------------------------------------------------
Private Sub InitTree()
    On Error GoTo Err_Handler

    Dim tvw As MSComctlLib.TreeView
    Set tvw = Me!TreeView0.Object

    tvw.Nodes.Clear

    If m_IDCrtez = 0 Then Exit Sub

    Dim cnn As String
    Dim rs As ADODB.Recordset
    Dim sql As String
    Dim rootLabel As String
    Dim ndRoot As MSComctlLib.Node

    cnn = BBCFG.CNNString

    ' Uèitaj BrojCrteza i Revizija
    sql = "SELECT BrojCrteza, Revizija FROM PDMCrtezi WHERE IDCrtez=" & m_IDCrtez
    Set rs = ADO_GetRST(cnn, sql)

    If Not rs.EOF Then
        rootLabel = rs!BrojCrteza & "-" & rs!Revizija
    Else
        rootLabel = "Nepoznat crtež " & m_IDCrtez
    End If

    rs.Close
    Set rs = Nothing

    ' Root node
    Set ndRoot = tvw.Nodes.Add(, , "R" & m_IDCrtez, rootLabel)
    ndRoot.tag = m_IDCrtez

    ' Uèitavanje WHERE USED strukture (roditelji)
    LoadParents tvw, ndRoot, m_IDCrtez

    ' Expand/Collapse zavisno od checkbox-a u glavnoj formi
    Dim rek As Boolean
    rek = False

    On Error Resume Next
    rek = Me.Parent!Rekurzivno

    If rek = True Then
        ExpandAllNodes
    Else
        ndRoot.Expanded = True
    End If

Exit_Sub:
    Exit Sub

Err_Handler:
    MsgBox "Greška u InitTree: " & err.Description, vbCritical
    Resume Exit_Sub
End Sub


'-------------------------------------------------------------
'  LOAD PARENTS – Gde se taj crtež koristi (Where Used)
'  › koristi TVF: ftWhereUsedUnified
'-------------------------------------------------------------
Private Sub LoadParents(tvw As MSComctlLib.TreeView, _
                        parentNode As MSComctlLib.Node, _
                        childID As Long)

    On Error GoTo Err_Handler

    Dim cnn As String
    Dim rs As ADODB.Recordset
    Dim sql As String
    Dim rek As Boolean
    Dim parentID As Long
    Dim parentKey As String
    Dim lbl As String
    Dim nd As MSComctlLib.Node

    cnn = BBCFG.CNNString

    ' Uzimamo vrednost iz glavne forme — direktno ili rekurzivno
    rek = False
    On Error Resume Next
    rek = Me.Parent!Rekurzivno

    ' SQL poziv TVF funkcije
    sql = "SELECT IDRoditelja, BrojCrteza, Revizija, Nivo " & _
          "FROM dbo.ftWhereUsed(" & childID & ", " & IIf(rek, 1, 0) & ")"

    Set rs = ADO_GetRST(cnn, sql)

    Do While Not rs.EOF
        parentID = rs!IDRoditelja
        parentKey = parentNode.key & "_" & parentID

        lbl = rs!BrojCrteza & "-" & rs!Revizija & _
              "  (Nivo " & rs!Nivo & ")"

        ' Dodaj node
        Set nd = tvw.Nodes.Add(parentNode.key, tvwChild, parentKey, lbl)
        nd.tag = parentID

        ' Rekurzivno traži roditelje roditelja
        LoadParents tvw, nd, parentID

        rs.MoveNext
    Loop

    rs.Close
    Set rs = Nothing

Exit_Sub:
    Exit Sub

Err_Handler:
    MsgBox "Greška u LoadParents: " & err.Description, vbCritical
    Resume Exit_Sub
End Sub


'-------------------------------------------------------------
'  EXPAND ALL – rekurzivno otvaranje svih èvorova
'-------------------------------------------------------------
Public Sub ExpandAllNodes()
    On Error Resume Next

    Dim tvw As MSComctlLib.TreeView
    Dim nd As MSComctlLib.Node

    Set tvw = Me!TreeView0.Object

    If tvw.Nodes.Count = 0 Then Exit Sub

    Set nd = tvw.Nodes(1)
    ExpandNodeRecursive nd
End Sub

Private Sub ExpandNodeRecursive(ByVal nd As MSComctlLib.Node)
    On Error Resume Next

    Dim child As MSComctlLib.Node

    nd.Expanded = True

    Set child = nd.child
    While Not child Is Nothing
        ExpandNodeRecursive child
        Set child = child.Next
    Wend
End Sub

Public Function InicijalizujSpolja()
    InitTree
End Function
