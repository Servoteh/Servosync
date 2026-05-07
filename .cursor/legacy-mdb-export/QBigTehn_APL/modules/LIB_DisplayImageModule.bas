Attribute VB_Name = "LIB_DisplayImageModule"
Option Compare Database
Option Explicit

Public Function DisplayImage(ctlImageControl As control, strImagePath As Variant) As String
On Error GoTo Err_DisplayImage

Dim strResult As String
Dim strDatabasePath As String
Dim intSlashLocation As Integer

With ctlImageControl
    If IsNull(strImagePath) Then
        .Visible = False
        strResult = "No image name specified."
    Else
        If InStr(1, strImagePath, "\") = 0 Then
            ' Path is relative
            strDatabasePath = CurrentProject.FullName
            intSlashLocation = InStrRev(strDatabasePath, "\") 'systemski InStrRev(strDatabasePath, "\", Len(strDatabasePath))
            strDatabasePath = Left(strDatabasePath, intSlashLocation)
            strImagePath = strDatabasePath & strImagePath
        End If
        .Visible = True
        .Picture = strImagePath
        strResult = "Image found and displayed."
    End If
End With
    
Exit_DisplayImage:
    DisplayImage = strResult
    Exit Function

Err_DisplayImage:
    Select Case err.Number
        Case 2220       ' Can't find the picture.
            ctlImageControl.Visible = False
            strResult = "Can't find image in the specified name."
            Resume Exit_DisplayImage:
        Case Else       ' Some other error.
            MsgBox err.Number & " " & err.Description
            strResult = "An error occurred displaying image."
            Resume Exit_DisplayImage:
    End Select
End Function

