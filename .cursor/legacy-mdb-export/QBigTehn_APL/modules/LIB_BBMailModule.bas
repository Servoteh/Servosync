Attribute VB_Name = "LIB_BBMailModule"
Option Compare Database
Option Explicit

Public Function CreateEmailWithOutlook(MessageTo As String, MessageCC As String, MessageBCC As String, Subject As String, MessageBody As String, ParamArray Attachments()) As Boolean     'Optional MessageAttachment As String = "") As Boolean
'Modifikovano: 25-05-2023 => dodati parametri MessageCC i MessageBCC
On Error GoTo err_Func
    Dim retValOk As Boolean
    Dim i As Integer
    
    ' Define app variable and get Outlook using the "New" keyword
    'Dim olApp As New Outlook.Application
    Dim olApp As Object
    'Dim olMailItem As Outlook.MailItem  ' An Outlook Mail item
    Dim olMailItem As Object
    
retValOk = True
    Set olApp = CreateObject("Outlook.Application") 'Create a new instance
'    Set olMailItem = olApp.CreateItem() '(olMailItem)
    
    ' Create a new email object
    Set olMailItem = olApp.CreateItem(0)

    ' Add the To/Subject/Body to the message and display the message
    With olMailItem
      '  .Sender
      '  .SenderEmailAddress
      '  .SenderName
      '  .SendUsingAccount
    
        .To = MessageTo
        If MessageCC <> "" Then
        .Cc = MessageCC
        End If
        
        If MessageBCC <> "" Then
        .Bcc = MessageBCC
        End If
        
        .Subject = Subject
        .body = MessageBody
        '.Attachments.Add ("C:\Users\Slavisa\Downloads\Apps_Users_dusan.kotorcevic.pdf")
        'If Nz(MessageAttachment, "") <> "" Then
        ' .Attachments.Add MessageAttachment
        'End If
        For i = LBound(Attachments()) To UBound(Attachments())
         If Nz(Attachments(i), "") <> "" Then
          If FileExists(Attachments(i)) Then
           .Attachments.Add Attachments(i)
          End If
          'Debug.Print "Attachments(" & i & ")=", Attachments(i), TypeName(Attachments(i))
         End If
        Next i
    
        '.BodyFormat = acFormatHTML
        '.HTMLBody = "<htmltags>Body Content</htmltags>"
        .Display    ' To show the email message to the user
        '.send       ' Send the message immediately
    End With

exit_Func:
' Release all object variables
On Error Resume Next
    Set olMailItem = Nothing
    Set olApp = Nothing
    CreateEmailWithOutlook = retValOk
    
Exit Function
err_Func:
 MsgBox err.Description, vbExclamation, "QMegaTeh"
 retValOk = False
 Resume exit_Func
End Function
Public Function BBMail(Optional EMailIliIDKomitent, Optional stReportName)
On Error GoTo Err_Point

Const MailFormName = "BBMail"
Dim pForm As Form
Dim stAktivanReport As String
Dim stFileName As String

DoCmd.OpenForm MailFormName
Set pForm = Forms(MailFormName)
If Not IsMissing(EMailIliIDKomitent) Then
    If EMailIliIDKomitent Like "*@*" Then
      pForm.EmailTo = EMailIliIDKomitent
    ElseIf IsNumeric(EMailIliIDKomitent) Then
      pForm.IDKomitent = CLng(EMailIliIDKomitent)
    Else
      'pForm.ReportName = EMailIliIDKomitent
      stAktivanReport = EMailIliIDKomitent
    End If
End If
 
If Not IsMissing(stReportName) Then
   'pForm.ReportName = stReportName
   stAktivanReport = stReportName
Else

   If Reports.Count > 0 Then
      stAktivanReport = Reports(Reports.Count - 1).Name
   Else
      stAktivanReport = ""
   End If
End If

If stAktivanReport <> "" Then
   'DoCmd.OpenReport stAktivanReport, acViewPreview
    
    stFileName = "C:\SHARES\EXPORT\test\" & stAktivanReport & ".pdf"
    
   DoCmd.OutputTo acOutputReport, stAktivanReport, acFormatPDF, stFileName, False
   pForm.ReportName = stFileName
End If


Exit_Point:
 On Error Resume Next
Exit Function

Err_Point:
 BBErrorMSG err, "BBMail"
 Resume Exit_Point
End Function
