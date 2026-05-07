VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "Form_Copy Of PDMTreeView"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Compare Database
Option Explicit
' U UserFormu ili Access formi, u VBA projektu gde si referencirao MSComctlLib:
Private m_tvwEvents As clsTreeViewEvents

' Inicijalizacija TreeView kontrole (npr. u Form_Open)
Private Sub InitTree()
    Dim tvw As MSComctlLib.TreeView
    Set tvw = Me!TreeView0.Object
    
    tvw.Nodes.Clear
    
    Dim rootID As Long
    Dim rootLabel As String
    Dim rs As DAO.Recordset
    
    rootID = Me!txtRootID
    
    ' Izvuæi naziv crteža iz baze
    Set rs = CurrentDb.OpenRecordset( _
            "SELECT BrojCrteza, Revizija FROM PDMCrtezi WHERE IDCrtez=" & rootID)
    
    If Not rs.EOF Then
        rootLabel = rs!BrojCrteza & "-" & rs!Revizija
    Else
        rootLabel = "Nepoznat crtež " & rootID
    End If
    rs.Close
    
    ' Dodaj root èvor
    Dim ndRoot As MSComctlLib.Node
    Set ndRoot = tvw.Nodes.Add(, , "R" & rootID, rootLabel)
    ndRoot.tag = rootID
    
    ' Rekurzivno punjenje
    LoadChildren tvw, ndRoot, rootID
End Sub


' Rekurzivna rutina za svaki level
Private Sub LoadChildren(tvw As MSComctlLib.TreeView, _
                         parentNode As MSComctlLib.Node, _
                         parentID As Long)
    Dim rs As DAO.Recordset
    Dim sql As String
    
    sql = "SELECT K.TrebaIDCrtez, C.BrojCrteza, C.Revizija, K.PotrebnoKomada " & _
          "FROM KomponentePDMCrteza AS K " & _
          "INNER JOIN PDMCrtezi AS C ON C.IDCrtez = K.TrebaIDCrtez " & _
          "WHERE K.ZaIDCrtez = " & parentID
    
    Set rs = CurrentDb.OpenRecordset(sql, dbOpenSnapshot)
    Do While Not rs.EOF
        Dim childKey As String
        childKey = parentNode.key & "_" & rs!TrebaIDCrtez
        
        Dim lbl As String
        lbl = rs!BrojCrteza & "-" & rs!Revizija & " (x" & rs!PotrebnoKomada & ")"
        
        ' Add node (bez named argumenta Tag), veza preko objekta Node
        Dim nd As MSComctlLib.Node
        Set nd = tvw.Nodes.Add(parentNode.key, tvwChild, childKey, lbl)
        nd.tag = rs!TrebaIDCrtez
        
        ' Rekurzivno za sledeæi nivo
        LoadChildren tvw, nd, rs!TrebaIDCrtez
        
        rs.MoveNext
    Loop
    rs.Close
End Sub
Private Sub Form_Open(Cancel As Integer)
    ' Povežemo TreeView objekat s klasom
    Set m_tvwEvents = New clsTreeViewEvents
    Set m_tvwEvents.tvw = Me!TreeView0.Object

    ' Napunite stablo
    InitTree
End Sub
Public Sub ShowDetails(ByVal detailID As Long)
    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    Dim sql As String
    
    Set db = CurrentDb
    
    sql = "SELECT BrojCrteza, Revizija, Naziv, WhereUsed " & _
          "FROM PDMCrtezi " & _
          "WHERE IDCrtez = " & detailID & ";"
    
    Set rs = db.OpenRecordset(sql, dbOpenSnapshot)
    If Not rs.EOF Then
        ' Popuni kontrole na formi
        Me!TxtBrojCrteza = rs!BrojCrteza
        Me!txtRevizija = rs!Revizija
        Me!txtNaziv = rs!Naziv
        Me!txtWhereUsed = rs!WhereUsed
    Else
        ' Ako nije pronaðen, obriši polja
        Me!TxtBrojCrteza = Null
        Me!txtRevizija = Null
        Me!txtNaziv = Null
        Me!txtWhereUsed = Null
    End If
    
    rs.Close
    Set rs = Nothing
    Set db = Nothing
End Sub


