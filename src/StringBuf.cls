VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "CStringBuf"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Attribute VB_Description = "Buffer for String data, with formatting methods\r\nauthor: Lindsay Bigelow (lindsaybigelow@cad2data.com)"
Attribute VB_Ext_KEY = "SavedWithClassBuilder" ,"Yes"
Attribute VB_Ext_KEY = "Top_Level" ,"Yes"
Attribute VB_Ext_KEY = "RVB_UniqueId" ,"3B004A900134"
Attribute VB_Ext_KEY = "SavedWithClassBuilder6" ,"Yes"
Option Base 0

Option Explicit

'** Buffer for String data, with formatting methods
'
'@author   Lindsay Bigelow (lindsaybigelow@cad2data.com)
'@version   1.0     1/5/2001

Public Enum StringBufErrors
    sbufErrStringTooLong = vbObjectError + 1024 + 1
    sbufErrIndexOutOfBounds = vbObjectError + 1024 + 2
    sbufErrBadArgument = vbObjectError + 1024 + 10
End Enum

Public Enum StringBufConstants
    sbufMaxLength = (&H7FFFFFF0 \ 2)    'arbitrary -  not tested
End Enum

'>>>>>>>>>>>>>>>>>>>>>>>
Private Const STRING_TOO_LONG = "String too long"
Private Const INDEX_OUT_OF_BOUNDS = "Index out of bounds"
'>>>>>>>>>>>>>>>>>>>>>>>

Private m_str As String
Private m_size As Long
Private m_len As Long

Private Const STRINGLEN_INIT = 64

'******************************
'** append a 'character' (1-char String) to this string
'
'@param char character to append (if length > 1, ignore extra characters;
'                                 if length = 0, do nothing)
'@param Count number of repetitions; always >= 1
'
'@exception sbufErrStringTooLong if string gets too long
'
Public Function AppendChar(ByVal char As String, Optional ByVal Count As Long = 1) As CStringBuf
Attribute AppendChar.VB_Description = "append a 'character' (1-char String) to this string"

    If (Count < 1) Then
        Count = 1
    End If

    Dim newLen  As Long:   newLen = m_len + Count

    If (newLen > m_size) Then
        If (newLen > sbufMaxLength) Then
            Err.Raise sbufErrStringTooLong, , "AppendChar: " & STRING_TOO_LONG
        End If
        Me.SetCapacity newLen
    End If

    If (Count = 1) Then

        Mid$(m_str, m_len + 1, 1) = char
    Else
        Mid$(m_str, m_len + 1, Count) = String$(Count, Asc(char))
    End If

    m_len = newLen

    Set AppendChar = Me
End Function

'******************************
'** append a newline (cr + lf) to this string
'
'@exception sbufErrStringTooLong if string gets too long
'
Public Function AppendNewLine() As CStringBuf
Attribute AppendNewLine.VB_Description = "append a newline (cr + lf) to this string"

    Dim newLen  As Long:   newLen = m_len + 2

    If (newLen > m_size) Then
        If (newLen > sbufMaxLength) Then
            Err.Raise sbufErrStringTooLong, , "AppendNewline: " & STRING_TOO_LONG
        End If
        Me.SetCapacity newLen
    End If

    Mid$(m_str, m_len + 1, 2) = vbCrLf
    m_len = newLen

    Set AppendNewLine = Me
End Function

'******************************
'** add a string to this string
'
'@param strIn       - string to append
'@param width       - pad string to be at least 'width' chars;
'                     if negative, pad precedes 'strIn'
'@param clipToWidth - if True, truncate strIn to width chars if rq'd
'@param addNewLine  - if True, append a newline (cr + lf) after strIn
'
'@exception sbufErrStringTooLong if string gets too long
'
Public Function AppendString( _
                        strIn As String, _
                        Optional ByVal width As Long = 0, _
                        Optional ByVal clipToWidth As Boolean = False, _
                        Optional ByVal addNewLine As Boolean = False _
                    ) As CStringBuf

    Dim LenStr    As Long:     LenStr = Len(strIn)
    Dim pad1st    As Boolean:  pad1st = (width < 0)
    Dim absWidth  As Long:     absWidth = Abs(width)
    Dim newLen    As Long:     newLen = m_len + LenStr
    Dim pSpace    As Long
    Dim pStr      As Long

    If ((clipToWidth) And (absWidth > 0) And (LenStr > absWidth)) Then
        LenStr = absWidth
    End If

    absWidth = absWidth - LenStr
    If (absWidth > 0) Then
        newLen = newLen + absWidth
    End If

    If (addNewLine) Then
        newLen = newLen + 2
    End If

    If (newLen > m_size) Then
        If (newLen > sbufMaxLength) Then
            Err.Raise sbufErrStringTooLong, , "AppendString: " & STRING_TOO_LONG
        End If
        Me.SetCapacity newLen
    End If

    If (width = 0) Then

        pStr = m_len + 1
    Else
        If (pad1st) Then
            pSpace = m_len + 1
            pStr = m_len + absWidth + 1
        Else
            pStr = m_len + 1
            pSpace = m_len + LenStr + 1
        End If

        Mid$(m_str, pSpace, absWidth) = Space$(absWidth)
    End If

    Mid$(m_str, pStr, LenStr) = strIn
    If (addNewLine) Then
        Mid$(m_str, pStr + LenStr + 1, 2) = vbCrLf
    End If
    m_len = newLen

    Set AppendString = Me
End Function

'******************************
'** returns the length (character count) of this string buffer
'
Public Property Get Length() As Long
Attribute Length.VB_Description = "returns the length (character count) of this string buffer"

    Length = m_len
End Property

'******************************
'** get 'chars' chars from member string, starting at position 'start'
'
'@param start   first char to return
'@param chars   number of chars to return
'
'@thows sbufErrIndexOutOfBounds if 'start' is out of bounds
'
Public Function MidStr(ByVal Start As Long, ByVal chars As Long) As String
Attribute MidStr.VB_Description = "get 'chars' chars from member string, starting at position 'start'"

    If ((Start < 1) Or (Start > m_len)) Then
        Err.Raise sbufErrIndexOutOfBounds, , "MidStr: " & INDEX_OUT_OF_BOUNDS
    End If

    If (chars < 0) Then
        chars = 0
    ElseIf ((Start + chars - 1) > m_len) Then
        chars = m_len - Start + 1
    End If

    MidStr = Mid$(m_str, Start, chars)
End Function

'******************************
'** set the current capacity of the string buffer;
'   useful if planning on doing a lot of Append operations
'   and approximate final size is known
'
Public Sub SetCapacity(ByVal NewSize As Long)
Attribute SetCapacity.VB_Description = "set the current capacity of the string buffer"

    If (NewSize <> m_size) Then

        Dim temp_size As Long: temp_size = m_size

        Do While (temp_size > NewSize)
            temp_size = temp_size \ 2
            If (temp_size < 16) Then
                temp_size = 16
                Exit Do
            End If
        Loop

        Do While (temp_size < NewSize)
            temp_size = temp_size * 2
            If (temp_size > sbufMaxLength) Then
                temp_size = sbufMaxLength
                Exit Do
            End If
        Loop

        m_str = m_str & Space$(temp_size - m_size)

        m_size = temp_size
    End If

End Sub

'******************************
'** set length of this string
'   if 'NewLength' is less than current length, the string is truncated
'   if 'NewLength' is longer than current length, space chars are appended
'
'@param NewLength   new length  (can't make size larger than sbufMaxLength)
'
Public Sub SetLength(ByVal NewLength As Long)
Attribute SetLength.VB_Description = "set length of this string; if 'NewLength' is less than current length, the string is truncated; if 'NewLength' is longer than current length, space chars are appended"

    Dim oldLen  As Long: oldLen = m_len

    If (NewLength < 0) Then
        NewLength = 0
    ElseIf (NewLength > sbufMaxLength) Then
        NewLength = sbufMaxLength
    End If

    If (NewLength < m_len) Then
        m_len = NewLength
    ElseIf (NewLength > m_len) Then
        If (NewLength > m_size) Then
            Me.SetCapacity NewLength
        End If
        m_len = NewLength
    End If

End Sub

'******************************
'** get a copy of the string data [the default property]
'
Public Property Get StringValue() As String
Attribute StringValue.VB_Description = "get a copy of the string data"
Attribute StringValue.VB_UserMemId = 0

    StringValue = Left$(m_str, m_len)
End Property

'******************************
'
Private Sub Class_Initialize()

    m_size = STRINGLEN_INIT
    m_str = Space$(m_size)
    m_len = 0

End Sub

'******************************
'
Private Sub Class_Terminate()

    On Error Resume Next  'always handle errors in Class_Terminate!
    m_str = ""
    Err.Clear

End Sub

