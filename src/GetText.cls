VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "CGetText"
Attribute VB_GlobalNameSpace = True
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
'********************************
' ** GNU gettext workalike for VB, version 0
'
' copyright 2012 Lindsay Bigelow
'
' This program is free software: you can redistribute it and/or modify
' it under the terms of the GNU General Public License as published by
' the Free Software Foundation, either version 3 of the License, or
' (at your option) any later version.
'
' This program is distributed in the hope that it will be useful,
' but WITHOUT ANY WARRANTY; without even the implied warranty of
' MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
' GNU General Public License for more details.
'
' You should have received a copy of the GNU General Public License
' along with this program.  If not, see <http://www.gnu.org/licenses/>.
'
' gettext is part of the GNU Translation Project (gnu.org/software/gettext)
'
Option Explicit

Private m_sT_Initialized  As Boolean
Private m_sT_Source       As Long
Private m_sT_Language       As String
Private m_sT_Path         As String
Private m_dictT           As Scripting.Dictionary
Private m_lastError       As String

'******************************
'** most recent error message, if any
'
Public Property Get LastError() As String
Attribute LastError.VB_Description = "most recent error message, if any"
    LastError = m_lastError
End Property

'******************************
'** get a list of supported initialzation methods
'
' currently the only initialization method is through text files
'
Public Property Get OptionIDList() As String
Attribute OptionIDList.VB_Description = "get a list of supported initialzation methods"
    OptionIDList = "OptionID=0 (text file; <App.Path>\Lang\<language>-po.txt)"
End Property

'******************************
'** escape special characters for sExp(), sR_(), sT_()
'   eg, double the quote and percent characters
'
Function sEsc(s As String) As String
Attribute sEsc.VB_Description = "escape special characters for sExp(), sR_(), sT_()"

    Const DQUOTE = """"
    Const DQUOTE2 = """"""
    Const PERCENT = "%"
    Const PERCENT2 = "%%"
    
    If (InStr(1, s, DQUOTE, vbBinaryCompare)) Then
        
        If (InStr(1, s, PERCENT, vbBinaryCompare)) Then
            
            sEsc = Replace(Replace(s, DQUOTE, DQUOTE2), PERCENT, PERCENT2)
        Else
            sEsc = Replace(s, DQUOTE, DQUOTE2)
        End If
        
    ElseIf (InStr(1, s, PERCENT, vbBinaryCompare)) Then
    
        sEsc = Replace(s, PERCENT, PERCENT2)
    Else
        sEsc = s
    End If
End Function

'******************************
'** insert args(0) into msg in place of '%1', args(1) in place of '%2', etc.
'
'  - escape literal "%" characters by doubling, ie "%%"
'      @see sEsc() for escaping "%" and quote char
'  - embed a carriage return with "%n"
'  - embed a tab character with "%t"
'  - enter "comment" mode with "%z"
'     (stop processing; text after "%z" not passed to output; useful for passing note to translator)
'
'@author   Lindsay Bigelow (lindsaybigelow@cad2data.com)
'@version   1.0 8/10/2000
'@version   1.1 3/20/2011  - "%n", "%t" support; use CStringBuf
'@version   1.2 3/31/2011  - "%z" support; speed tweak
'
Function sExp(ByVal msg As String, ParamArray args()) As String
Attribute sExp.VB_Description = "insert args(0) into msg in place of '%1', args(1) in place of '%2', etc."

    Const DELIM = "%"

    Dim sbRtn As CStringBuf: Set sbRtn = New CStringBuf
    Dim ub    As Long:       ub = UBound(args)
    Dim L     As Long:       L = Len(msg)
    Dim p     As Long:       p = 1
    Dim pR    As Long
    Dim s1    As String
    Dim n     As Long
    Dim arrp  As Boolean

    ' this bit allows us to pass a ParamArray from one method to another:
    '   ('args' will be a 1-element array with args(0)
    '    containing the original args array)
    '
    If (ub >= 0) Then
        If ((VarType(args(0)) And vbArray) = vbArray) Then
            Debug.Assert (ub = 0)
            arrp = True  'condition described above applies
            ub = UBound(args(0))
        End If
    End If
    
    Do While (p <= L)
    
        pR = InStr(p, msg, DELIM, vbBinaryCompare)
        If (pR = 0) Then
            sbRtn.AppendString Mid$(msg, p)
            Exit Do
        End If
        
        'append portion before DELIM:
        sbRtn.AppendString Mid$(msg, p, (pR - p))
        p = (pR + 1)
        If (p > L) Then
            'trailing delim; ignore:
            Exit Do
        End If
        
        s1 = Mid$(msg, p, 1)
        If (s1 = DELIM) Then
            ' double delim, meaning one literal delim:
            sbRtn.AppendChar DELIM
        Else
            'next number is a reference
            n = Val(s1)
            If ((n < 1) Or (n > (ub + 1))) Then
                If (s1 = "n") Then
                    sbRtn.AppendNewLine
                ElseIf (s1 = "t") Then
                    sbRtn.AppendChar vbTab
                ElseIf (s1 = "z") Then
                    Exit Do
                Else
                    Debug.Assert (False) 'missing arg or bad ID
                End If
            Else
                If (arrp) Then
                    sbRtn.AppendString (args(0)(n - 1))
                Else
                    sbRtn.AppendString (args(n - 1))
                End If
            End If
        End If 'not double delim
        p = (p + 1)
    Loop
    
    sExp = sbRtn.StringValue
End Function

'******************************
'** translate strings, with formatting:
'   look up translated msg using argument "s" as key;
'   insert args(0) into translated msg in place of '%1',
'   args(1) in place of '%2', etc.
'
'  - escape literal "%" characters by doubling, ie "%%"
'  - embed a carriage return with "%n"
'  - embed a tab character with "%t"
'  - enter "comment" mode with "%z"
'     (stop processing; text after "%z" not passed to output; useful for passing note to translator)
'
'@version 1.0 LB 06-Mar-2011
'@version 1.1 LB 17-Mar-2011
'
Function sT_(ByVal s As String, ParamArray args() As Variant) As String
Attribute sT_.VB_Description = "translate strings, with formatting"

    On Error Resume Next
    
    If (Len(s) = 0) Then
        sT_ = ""
        Exit Function
    End If
    
    If (m_sT_Initialized) Then
        sT_ = m_dictT.Item(s)
        If (Err) Then
            Err.Clear
            sT_ = ""
        End If
    End If
    
    If (Len(sT_) = 0) Then
        sT_ = s
    End If

    If (InStr(1, sT_, "%")) Then
        sT_ = sExp(sT_, args)
    End If
End Function

'******************************
'** set locale and other options; must be called *before* calling sT_()
'
'@param OptionID - set underlying method for loading strings
'    (this argument is currently IGNORED; set to 0 for compatibility
'     with future versions)
'
'@param sLanguage  - set language for loading strings. This argument is not
'   needed or desirable. It is better to use the following Registry settings:
'   if nothing is set, default =
'   <current user>\Control Panel\International\@sLanguage=
'   can be overridden by setting
'   <current user>\Software\VB and VBA Program Settings\<program>\General\@Language
'
'@param sPath - set root folder for strings. This argument is not
'   needed or desirable. It is better to use the default:
'   <App.Path>\Lang
'   which can also be overridden by setting
'   ...\VB and VBA Program Settings\<program>\General\@GetTextVB Path
'
'@return True on success
'
' language file name & location:
'   for stOptUseTxt, path = (sPath + "\" + sLanguage + "-po.txt")
'   (example: if language is "ES", save translation file as "<App.Path>\Lang\ES-po.txt")
'
'@version 1.0 LB 17-Mar-2011
'
Function sT_Init( _
                ByVal OptionID As Long, _
                Optional ByVal sLanguage As String = "", _
                Optional ByVal sPath = "" _
            ) As Boolean
Attribute sT_Init.VB_Description = "set locale and other options; must be called first. OptionID is currently IGNORED; always = 0 (init from text file)"
            
#If (1) Then
    OptionID = 0 'this argument is currently IGNORED; set to default=stOptUseTxt
#End If
            
    On Error Resume Next
    
    If (Len(sPath) = 0) Then
        sPath = GetSetting((App.Title), "general", "GetTextVB Path", "")
        If (Len(sPath) = 0) Then
            sPath = (App.Path) & "\Lang"
        ElseIf (InStr(1, sPath, "\") = 0) Then
            sPath = (App.Path) & "\" & sPath
        End If
    End If
    m_sT_Path = sPath
                
    If (Len(sLanguage) = 0) Then
        sLanguage = GetSetting((App.Title), "general", "Language", "")
        If (Len(sLanguage) = 0) Then
            sLanguage = RegRead( _
                        "HKEY_CURRENT_USER\Control Panel\International", _
                        "sLanguage", "")
            If (Len(sLanguage) = 0) Then
                Debug.Assert (False)
                m_lastError = "sT_Init: no valid Language value"
                Err.Clear
                Exit Function
            End If
        End If
    End If
    m_sT_Language = sLanguage
    
    'set fallback values:
    sT_Init = False
    m_sT_Source = -1  'invalid
    m_sT_Initialized = False
    
    Err.Clear
    Set m_dictT = xGetDictionary(m_lastError)
    If (Err) Then
        Debug.Assert (False)
        m_lastError = "sT_Init: can't create Dictionary object: " & m_lastError
        Err.Clear
        sT_Init = False
        Exit Function
    End If
    
    Dim sFile  As String
    
    Select Case (OptionID)
    '
    Case 0

        '** using <locale>-po.txt (simplified gettext)
        '
        sFile = m_sT_Path & "\" & m_sT_Language & "-po.txt"
        m_sT_Source = 0
        
    Case Else
        Debug.Assert (False) 'step
        m_lastError = "sT_Init: invalid OptionID: " & OptionID
        sT_Init = False
        Exit Function
    End Select
    
    Dim hFile  As Long: hFile = FreeFile()
    
    Open sFile For Input Access Read Shared As #hFile
    If (Err) Then
        m_lastError = "sT_Init: Error opening '" & sFile & "': " & Err.Description
        Err.Clear
        sT_Init = False
        Exit Function
    End If

    Dim sLine   As String
    Dim sName   As String
    Dim sValue  As String
    '
    ' TODO: this will not correctly parse gettext .po files ===================================
    '      eg, .po has embedded newlines in strings (etc? need to obtain .po grammar)
    '
    Do While Not (EOF(hFile))

        sName = ""
        sValue = ""
        Err.Clear
        
        Line Input #hFile, sLine
        
        If (Left$(sLine, 7) = "msgid """) Then
        
            If (Right$(sLine, 1) <> """") Then
                Debug.Assert (False) 'no quote as last char; ignore
            Else
                sName = Mid$(sLine, 8, Len(sLine) - 8)
                If ((Err = 0) And (Len(sName) > 0)) Then
                    
                    Line Input #hFile, sLine
                    If (Err) Then
                        Err.Clear
                        Exit Do
                    End If
                    
                    If (Left$(sLine, 8) = "msgstr """) Then
                        
                        If (Right$(sLine, 1) <> """") Then
                            Debug.Assert (False) 'no quote as last char; ignore
                        Else
                            sValue = Mid$(sLine, 9, Len(sLine) - 9)
                            If ((Err = 0) And (Len(sValue) > 0)) Then
                                
                                m_dictT(sName) = sValue
                                If (Err) Then
                                    Debug.Assert (False)
                                    Err.Clear  'ignore duplicates
                                End If
                                
                            End If 'Len(sValue)
                        End If
                        
                    End If 'sLine = "msgstr..."
                    
                End If 'Len(sName)
            
            End If
        End If 'sLine = "msgid..."
    Loop
    
    Close #hFile
    Err.Clear
    
    m_lastError = ""
    m_sT_Initialized = True
    sT_Init = True
End Function

'******************************
'
Private Function xGetDictionary(Optional errMsg As String = "") As Scripting.Dictionary

    On Error Resume Next
    
    Set xGetDictionary = CreateObject("Scripting.Dictionary")
    If (Err) Then
        Debug.Assert (False)
        Err.Clear
        Shell Environ("COMSPEC") & " /c regsvr32 /s scrrun.dll"
        Set xGetDictionary = CreateObject("Scripting.Dictionary")
        If (Err) Then
            Debug.Assert (False)
            errMsg = "can't create Scripting.Dictionary object: " & Err.Description
            Err.Clear
            Set xGetDictionary = Nothing
            Exit Function
        End If
    End If
    errMsg = "" 'success
End Function

'******************************
'
Private Sub Class_Terminate()

    On Error Resume Next
    
    Set m_dictT = Nothing
    
    Err.Clear
    
End Sub
