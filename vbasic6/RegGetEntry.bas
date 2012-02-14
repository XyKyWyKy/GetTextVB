Attribute VB_Name = "wRegGetEntry"
Option Explicit

'@author   Lindsay Bigelow (lindsaybigelow@cad2data.com)
'@version  1.0  8/00

''==== PRIVATE =============================
'
Private Enum RegDataTypes

    REG_SZ = 1                 ' Unicode nul terminated string
    REG_EXPAND_SZ = 2          ' Unicode nul terminated string
    '
    REG_DWORD = 4              ' 32-bit number
    REG_DWORD_BIG_ENDIAN = 5   ' 32-bit number
    '
    REG_MULTI_SZ = 7           ' Multiple Unicode strings
    '
    '(... other types ignored for now)
End Enum

Private Enum RegRootKeys
    HKEY_CLASSES_ROOT = &H80000000
    HKEY_CURRENT_USER = &H80000001
    HKEY_LOCAL_MACHINE = &H80000002
    HKEY_USERS = &H80000003
    HKEY_PERFORMANCE_DATA = &H80000004
    HKEY_CURRENT_CONFIG = &H80000005
    HKEY_DYN_DATA = &H80000006
End Enum

Private Const ERROR_SUCCESS = 0&
Private Const ERROR_MORE_DATA = 234             ' buffer insufficient for data
Private Const ERROR_NO_MORE_ITEMS = 259&

'security access mask constants:
Private Const READ_CONTROL = &H20000
Private Const SYNCHRONIZE = &H100000

Private Const KEY_QUERY_VALUE = &H1
Private Const KEY_ENUMERATE_SUB_KEYS = &H8
Private Const KEY_NOTIFY = &H10

Private Const STANDARD_RIGHTS_READ = (READ_CONTROL)

Private Const KEY_READ = ((STANDARD_RIGHTS_READ Or _
                                KEY_QUERY_VALUE Or _
                                KEY_ENUMERATE_SUB_KEYS Or _
                                KEY_NOTIFY) _
                            And (Not SYNCHRONIZE))

Private Declare Function RegOpenKeyEx Lib "advapi32.dll" Alias "RegOpenKeyExA" ( _
                            ByVal hKey As Long, _
                            ByVal strSubKey As String, _
                            ByVal dwReserved As Long, _
                            ByVal samDesired As Long, _
                            dwHandle As Long _
                        ) As Long

Private Declare Function RegQueryValueEx_String Lib "advapi32.dll" Alias "RegQueryValueExA" ( _
                            ByVal hKey As Long, _
                            ByVal lpValueName As String, _
                            ByVal lpReserved As Long, _
                            lpType As Long, _
                            ByVal lpData As String, _
                            lpcbData As Long _
                        ) As Long

Private Declare Function RegCloseKey Lib "advapi32.dll" ( _
                            ByVal hKey As Long _
                        ) As Long


'******************************
'** read arbitrary registry entry
'
'@example: get shell command for a file extension:
'   sTmp = RegGetEntry("HKCR\.txt", "" )
'   sCmd = RegGetEntry("HKCR\" & sTmp & "\shell\open\command", "" )
'   dwRtn = Shell(sCmd & sFileName)
'
'@returns  string value; if a failure occurs, returns DefaultReturn
'
'@author   Lindsay Bigelow (lindsaybigelow@cad2data.com)
'@version  1.0  3/6/98
'@version  2.0  1/22/11 - add DefaultReturn
'@version  2.1  29-Jan-2012 - add short root names (HKLM, HKCU, HKCR)
'
Function RegGetEntry( _
                    ByVal Path As String, _
                    Optional ByVal ValueName As String = "", _
                    Optional ByVal DefaultReturn As String = "" _
                ) As String

    On Error GoTo RegGetEntry_Err

    Dim dwRtn       As Long
    Dim dwHandle    As Long
    Dim dwType      As Long
    Dim sTmp        As String: sTmp = DefaultReturn

    Dim bufData     As String
    Dim lenBufData  As Long

    Dim HRoot       As Long
    Dim SubKey      As String

    xSplitPath Path, HRoot, SubKey

    '-- get handle to subkey:
    dwRtn = RegOpenKeyEx( _
                    HRoot, _
                    SubKey, ByVal 0&, _
                    KEY_READ, _
                    dwHandle)
    If (dwRtn <> ERROR_SUCCESS) Then
        GoTo RegGetEntry_Exit
    End If

    Const BUFLEN = 1024
    lenBufData = BUFLEN
    bufData = String$(lenBufData + 1, 0)

    dwRtn = RegQueryValueEx_String( _
                    dwHandle, _
                    ValueName, _
                    ByVal 0&, dwType, _
                    bufData, lenBufData)

    If (dwRtn = ERROR_MORE_DATA) Then
        sTmp = "(data too long for buffer)"
        GoTo RegGetEntry_Exit
    End If

    If (lenBufData > 0) And (lenBufData < BUFLEN) Then

        If ((dwType = REG_SZ) Or (dwType = REG_EXPAND_SZ)) Then

            sTmp = Left$(bufData, lenBufData - 1)

        ElseIf ((dwType = REG_DWORD) Or (dwType = REG_DWORD_BIG_ENDIAN)) Then

            dwRtn = xStrToDword(bufData, (dwType = REG_DWORD_BIG_ENDIAN))
            sTmp = CStr(dwRtn)
        Else
            sTmp = "(data not string or DWORD)"
        End If
    End If

RegGetEntry_Exit:

    RegCloseKey dwHandle

    RegGetEntry = sTmp        '====> success
Exit Function

RegGetEntry_Err:
    Debug.Assert (False)
'    Debug.Print "RegGetEntry error:" & Error;

    RegCloseKey dwHandle

    RegGetEntry = sTmp               '====> failure
    Exit Function
End Function

'******************************
'** read arbitrary registry entry
'
'@returns  string value; if a failure occurs, returns DefaultReturn
'
Function RegRead( _
              ByVal Path As String, _
              Optional ByVal ValueName As String = "", _
              Optional ByVal DefaultReturn As String = "" _
          ) As String
          
    RegRead = RegGetEntry(Path, ValueName, DefaultReturn)
End Function

'******************************
'
'29-Jan-2012 - add short root names
'
Private Sub xSplitPath(ByVal Path As String, HRoot As Long, SubKey As String)

    Dim pL  As Long

    pL = InStr(Path, "\")
    If (pL = 0) Then
        HRoot = 0
        SubKey = ""
        Exit Sub '===> error
    End If

    Select Case (Left(Path, pL - 1))
    Case "HKEY_CLASSES_ROOT":      HRoot = HKEY_CLASSES_ROOT
    Case "HKCR":                   HRoot = HKEY_CLASSES_ROOT
    Case "HKEY_CURRENT_USER":      HRoot = HKEY_CURRENT_USER
    Case "HKCU":                   HRoot = HKEY_CURRENT_USER
    Case "HKEY_LOCAL_MACHINE":     HRoot = HKEY_LOCAL_MACHINE
    Case "HKLM":                   HRoot = HKEY_LOCAL_MACHINE
    Case "HKEY_USERS":             HRoot = HKEY_USERS
    Case "HKEY_PERFORMANCE_DATA":  HRoot = HKEY_PERFORMANCE_DATA
    Case "HKEY_CURRENT_CONFIG":    HRoot = HKEY_CURRENT_CONFIG
    Case "HKEY_DYN_DATA":          HRoot = HKEY_DYN_DATA
    Case Else
        HRoot = 0
        SubKey = ""
        Exit Sub '===> error
    End Select

    SubKey = Mid(Path, pL + 1)

End Sub

'****************************
'** interpret a binary, 4 byte value as a Long
'
Private Function xStrToDword( _
                            strData As String, _
                            Optional ByVal bIsBigEndian As Boolean = False _
                        ) As Long

        Dim dwTmp   As Long

    If (bIsBigEndian) Then

        dwTmp = AscB(MidB(strData, 4, 1)) Or _
               (AscB(MidB(strData, 3, 1)) * &H100) Or _
               (AscB(MidB(strData, 2, 1)) * &H10000) Or _
               (AscB(MidB(strData, 1, 1)) * &H1000000)
    Else
        dwTmp = AscB(MidB(strData, 1, 1)) Or _
               (AscB(MidB(strData, 2, 1)) * &H100) Or _
               (AscB(MidB(strData, 3, 1)) * &H10000) Or _
               (AscB(MidB(strData, 4, 1)) * &H1000000)
    End If

    xStrToDword = dwTmp
End Function


