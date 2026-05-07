Attribute VB_Name = "PDM_PDFCommon"
Option Compare Database
Option Explicit
Private Declare PtrSafe Sub CopyMemory Lib "kernel32" Alias "RtlMoveMemory" ( _
    Destination As Any, _
    Source As Any, _
    ByVal Length As Long)
#If VBA7 Then
    Private Declare PtrSafe Function ShellExecute Lib "shell32.dll" Alias "ShellExecuteA" _
    (ByVal hwnd As LongPtr, _
     ByVal lpOperation As String, _
     ByVal lpFile As String, _
     ByVal lpParameters As String, _
     ByVal lpDirectory As String, _
     ByVal nShowCmd As Long) As LongPtr
#Else
    Private Declare Function ShellExecute Lib "shell32.dll" Alias "ShellExecuteA" _
    (ByVal hwnd As Long, _
     ByVal lpOperation As String, _
     ByVal lpFile As String, _
     ByVal lpParameters As String, _
     ByVal lpDirectory As String, _
     ByVal nShowCmd As Long) As Long
#End If
Public Function GetBrojCrtezaIReviziju() As Collection
    On Error GoTo Err_Point

    Dim rezultat As New Collection
    Dim pAktivnaForma As Form
    Dim pSubForma As Form
    Dim ctl As control
    Dim BrojCrteza As Variant
    Dim Revizija As Variant

    BrojCrteza = Null
    Revizija = Null

    '=== 1?? Aktivna forma ===
    On Error Resume Next
    Set pAktivnaForma = Screen.ActiveControl.Parent
    On Error GoTo Err_Point

    If Not pAktivnaForma Is Nothing Then
        ' --- pokušaj da proèitaš direktno iz glavne forme ---
        If KontrolaPostoji(pAktivnaForma, "BrojCrteza") Then
            BrojCrteza = Nz(pAktivnaForma!BrojCrteza, Null)
        End If
        If KontrolaPostoji(pAktivnaForma, "Revizija") Then
            Revizija = Nz(pAktivnaForma!Revizija, Null)
        End If

        '=== 2?? Ako nisu pronaðene, pokušaj u subformama ===
        If (IsNull(BrojCrteza) Or IsNull(Revizija)) Then
            For Each ctl In pAktivnaForma.Controls
                If ctl.ControlType = acSubform Then
                    Set pSubForma = ctl.Form
                    If KontrolaPostoji(pSubForma, "BrojCrteza") And KontrolaPostoji(pSubForma, "Revizija") Then
                        BrojCrteza = Nz(pSubForma!BrojCrteza, Null)
                        Revizija = Nz(pSubForma!Revizija, Null)
                        Exit For
                    End If
                End If
            Next ctl
        End If
    End If

    '=== 3?? Upakuj rezultat u Collection ===
    rezultat.Add BrojCrteza, "BrojCrteza"
    rezultat.Add Revizija, "Revizija"
    Set GetBrojCrtezaIReviziju = rezultat
    Exit Function

'=== Obrada greške ===
Err_Point:
    Set rezultat = New Collection
    rezultat.Add Null, "BrojCrteza"
    rezultat.Add Null, "Revizija"
    Set GetBrojCrtezaIReviziju = rezultat
End Function

Public Function KontrolaPostoji(frm As Form, ctlName As String) As Boolean
    On Error Resume Next
    Dim tmp As control
    Set tmp = frm.Controls(ctlName)
    KontrolaPostoji = (err.Number = 0)
    err.Clear
End Function

Public Function ZaBase64StringKreirajPDFFajl(stBase64 As String, stFileName As String) As Boolean
On Error GoTo Err_Point
    Dim retValOk As Boolean
    
    retValOk = True
    If FileExists(stFileName) Then
        Kill stFileName
    End If
    
    'Open stFileName For Binary As #1
    '   Put #1, 1, DecodeBase64(stBase64)
    'Close #1
    Call ConvertBase64ToFile(stFileName, stBase64)
    
Exit_Point:
 On Error Resume Next
    ZaBase64StringKreirajPDFFajl = retValOk
Exit Function

Err_Point:
    BBErrorMSG err, "ZaBase64StringKreirajPDFFajl"
    retValOk = False
    Resume Exit_Point
End Function


Public Function PreviewPDFCrtez_Binary_Verz2() As Boolean

On Error GoTo Err_Point

    Dim cnn As ADODB.Connection
    Dim rs As ADODB.Recordset
    
    Dim bytes() As Byte
    
    Dim podaci As Collection
    Dim stBrojCrteza As String
    Dim stRevizija As String
    
    Dim sql As String
    Dim filePath As String
    Dim f As Integer
    
    Set podaci = GetBrojCrtezaIReviziju()
    
    stBrojCrteza = Nz(podaci("BrojCrteza"), "")
    stRevizija = Nz(podaci("Revizija"), "")
    
    If Len(stBrojCrteza) = 0 Or Len(stRevizija) = 0 Then
    
        MsgBox "BrojCrteza ili Revizija nisu pronaðeni.", vbExclamation
        Exit Function
        
    End If
    
    
    Set cnn = New ADODB.Connection
    cnn.Open CNN_CurrentDataBase
    
    
    sql = "SELECT PDFBinary FROM PDM_PDFCrtezi WHERE BrojCrteza = N'" & _
          Replace(stBrojCrteza, "'", "''") & _
          "' AND Revizija = N'" & _
          Replace(stRevizija, "'", "''") & "'"
    
    
    Set rs = New ADODB.Recordset
    rs.Open sql, cnn, adOpenForwardOnly, adLockReadOnly
    
    
    If rs.EOF Then
    
        MsgBox "PDF nije pronaðen.", vbInformation
        GoTo Exit_Point
        
    End If
    
    
    bytes = rs.Fields("PDFBinary").Value
    
    
    filePath = Environ$("TEMP") & "\~" & stBrojCrteza & "_" & stRevizija & ".pdf"
    
    
    f = FreeFile
    
    Open filePath For Binary Access Write As #f
    
    Put #f, 1, bytes
    
    Close #f
    
    
    RunIt filePath
    
    
Exit_Point:
On Error Resume Next

    rs.Close
    cnn.Close
    
    Set rs = Nothing
    Set cnn = Nothing
    
    PreviewPDFCrtez_Binary_Verz2 = True

Exit Function


Err_Point:
    MsgBox err.Description, vbCritical
    PreviewPDFCrtez_Binary_Verz2 = False

End Function
Public Function VariantToBytes(ByVal v As Variant) As Byte()

    Dim stm As Object
    Dim b() As Byte
    
    If IsNull(v) Then
        ReDim b(0)
        VariantToBytes = b
        Exit Function
    End If
    
    Set stm = CreateObject("ADODB.Stream")
    
    stm.Type = 1 ' adTypeBinary
    stm.Open
    stm.Write v
    stm.Position = 0
    
    b = stm.Read
    
    stm.Close
    Set stm = Nothing
    
    VariantToBytes = b

End Function

Public Function GetBrojCrtezaIReviziju_Ex( _
    Optional ByVal pBrojCrteza As Variant, _
    Optional ByVal pRevizija As Variant, _
    Optional ByVal frm As Form = Nothing _
) As Collection

    On Error GoTo Err_Point

    Dim rezultat As New Collection
    Dim pAktivnaForma As Form
    Dim pSubForma As Form
    Dim ctl As control
    Dim BrojCrteza As Variant
    Dim Revizija As Variant

    BrojCrteza = Null
    Revizija = Null

    ' 1) Ako su parametri prosleðeni - oni imaju prioritet
    If Not IsMissing(pBrojCrteza) Then
        If Not IsNull(pBrojCrteza) Then
            If Len(Trim(CStr(pBrojCrteza))) > 0 Then
                BrojCrteza = pBrojCrteza
            End If
        End If
    End If

    If Not IsMissing(pRevizija) Then
        If Not IsNull(pRevizija) Then
            If Len(Trim(CStr(pRevizija))) > 0 Then
                Revizija = pRevizija
            End If
        End If
    End If

    ' 2) Ako nije sve naðeno, probaj iz prosleðene forme
    If (IsNull(BrojCrteza) Or IsNull(Revizija)) Then
        If Not frm Is Nothing Then
            If IsNull(BrojCrteza) Then
                If KontrolaPostoji(frm, "BrojCrteza") Then
                    BrojCrteza = Nz(frm!BrojCrteza, Null)
                End If
            End If

            If IsNull(Revizija) Then
                If KontrolaPostoji(frm, "Revizija") Then
                    Revizija = Nz(frm!Revizija, Null)
                End If
            End If
        End If
    End If

    ' 3) Ako i dalje nije naðeno, probaj staru logiku preko aktivne forme
    If (IsNull(BrojCrteza) Or IsNull(Revizija)) Then

        On Error Resume Next
        Set pAktivnaForma = Screen.ActiveControl.Parent
        On Error GoTo Err_Point

        If Not pAktivnaForma Is Nothing Then

            If IsNull(BrojCrteza) Then
                If KontrolaPostoji(pAktivnaForma, "BrojCrteza") Then
                    BrojCrteza = Nz(pAktivnaForma!BrojCrteza, Null)
                End If
            End If

            If IsNull(Revizija) Then
                If KontrolaPostoji(pAktivnaForma, "Revizija") Then
                    Revizija = Nz(pAktivnaForma!Revizija, Null)
                End If
            End If

            If (IsNull(BrojCrteza) Or IsNull(Revizija)) Then
                For Each ctl In pAktivnaForma.Controls
                    If ctl.ControlType = acSubform Then
                        Set pSubForma = ctl.Form

                        If IsNull(BrojCrteza) Then
                            If KontrolaPostoji(pSubForma, "BrojCrteza") Then
                                BrojCrteza = Nz(pSubForma!BrojCrteza, Null)
                            End If
                        End If

                        If IsNull(Revizija) Then
                            If KontrolaPostoji(pSubForma, "Revizija") Then
                                Revizija = Nz(pSubForma!Revizija, Null)
                            End If
                        End If

                        If Not IsNull(BrojCrteza) And Not IsNull(Revizija) Then Exit For
                    End If
                Next ctl
            End If
        End If
    End If

    rezultat.Add BrojCrteza, "BrojCrteza"
    rezultat.Add Revizija, "Revizija"
    Set GetBrojCrtezaIReviziju_Ex = rezultat
    Exit Function

Err_Point:
    Set rezultat = New Collection
    rezultat.Add Null, "BrojCrteza"
    rezultat.Add Null, "Revizija"
    Set GetBrojCrtezaIReviziju_Ex = rezultat
End Function
Public Function PreviewPDFCrtez_Binary( _
    Optional ByVal pBrojCrteza As Variant, _
    Optional ByVal pRevizija As Variant, _
    Optional ByVal frm As Form = Nothing _
) As Boolean

On Error GoTo Err_Point

    Dim cnn As ADODB.Connection
    Dim rs As ADODB.Recordset
    
    Dim bytes() As Byte
    
    Dim podaci As Collection
    Dim stBrojCrteza As String
    Dim stRevizija As String
    
    Dim sql As String
    Dim filePath As String
    Dim f As Integer
    
    Set podaci = GetBrojCrtezaIReviziju_Ex(pBrojCrteza, pRevizija, frm)
    
    stBrojCrteza = Nz(podaci("BrojCrteza"), "")
    stRevizija = Nz(podaci("Revizija"), "")
    
    If Len(stBrojCrteza) = 0 Or Len(stRevizija) = 0 Then
        MsgBox "BrojCrteza ili Revizija nisu pronaðeni.", vbExclamation
        Exit Function
    End If
    
    Set cnn = New ADODB.Connection
    cnn.Open CNN_CurrentDataBase
    
    sql = "SELECT PDFBinary FROM PDM_PDFCrtezi WHERE BrojCrteza = N'" & _
          Replace(stBrojCrteza, "'", "''") & _
          "' AND Revizija = N'" & _
          Replace(stRevizija, "'", "''") & "'"
    
    Set rs = New ADODB.Recordset
    rs.Open sql, cnn, adOpenForwardOnly, adLockReadOnly
    
    If rs.EOF Then
        MsgBox "PDF nije pronaðen.", vbInformation
        GoTo Exit_Point
    End If
    
    bytes = rs.Fields("PDFBinary").Value
    
    filePath = Environ$("TEMP") & "\~" & stBrojCrteza & "_" & stRevizija & ".pdf"
    
    f = FreeFile
    Open filePath For Binary Access Write As #f
    Put #f, 1, bytes
    Close #f
    
    RunIt filePath
    
Exit_Point:
    On Error Resume Next

    rs.Close
    cnn.Close
    
    Set rs = Nothing
    Set cnn = Nothing
    
    PreviewPDFCrtez_Binary = True
    Exit Function

Err_Point:
    MsgBox err.Description, vbCritical
    PreviewPDFCrtez_Binary = False
End Function

Public Function StampajPDFCrtez_Binary( _
    Optional ByVal pBrojCrteza As Variant, _
    Optional ByVal pRevizija As Variant, _
    Optional ByVal frm As Form = Nothing _
) As Boolean

On Error GoTo Err_Point

    Dim cnn As ADODB.Connection
    Dim rs As ADODB.Recordset
    
    Dim bytes() As Byte
    
    Dim podaci As Collection
    Dim stBrojCrteza As String
    Dim stRevizija As String
    
    Dim sql As String
    Dim filePath As String
    Dim f As Integer
    
    Set podaci = GetBrojCrtezaIReviziju_Ex(pBrojCrteza, pRevizija, frm)
    
    stBrojCrteza = Nz(podaci("BrojCrteza"), "")
    stRevizija = Nz(podaci("Revizija"), "")
    
    If Len(stBrojCrteza) = 0 Or Len(stRevizija) = 0 Then
        MsgBox "BrojCrteza ili Revizija nisu pronaðeni.", vbExclamation
        Exit Function
    End If
    
    Set cnn = New ADODB.Connection
    cnn.Open CNN_CurrentDataBase
    
    sql = "SELECT PDFBinary FROM PDM_PDFCrtezi WHERE BrojCrteza = N'" & _
          Replace(stBrojCrteza, "'", "''") & _
          "' AND Revizija = N'" & _
          Replace(stRevizija, "'", "''") & "'"
    
    Set rs = New ADODB.Recordset
    rs.Open sql, cnn, adOpenForwardOnly, adLockReadOnly
    
    If rs.EOF Then
        MsgBox "PDF nije pronaðen.", vbInformation
        GoTo Exit_Point
    End If
    
    bytes = rs.Fields("PDFBinary").Value
    
    filePath = Environ$("TEMP") & "\~" & stBrojCrteza & "_" & stRevizija & ".pdf"
    
    f = FreeFile
    Open filePath For Binary Access Write As #f
    Put #f, 1, bytes
    Close #f
    
    'Štampanje
    PrintIt filePath
    
Exit_Point:

On Error Resume Next

    rs.Close
    cnn.Close
    
    Set rs = Nothing
    Set cnn = Nothing
    
    StampajPDFCrtez_Binary = True
    Exit Function

Err_Point:
    MsgBox err.Description, vbCritical
    StampajPDFCrtez_Binary = False

End Function

Public Sub PrintIt(ByVal filePath As String)

    Dim sh As Object
    
    Set sh = CreateObject("Shell.Application")
    
    sh.ShellExecute filePath, "", "", "print", 0

End Sub
