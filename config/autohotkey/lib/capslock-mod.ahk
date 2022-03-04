; Press Capslock -> Esc
Capslock Up::handleCapslockUp()

; Make Win Key + Capslock work like Capslock
#Capslock::
if GetKeyState("CapsLock", "T") = 1
  SetCapsLockState, AlwaysOff
else
  SetCapsLockState, AlwaysOn
return

;;;;;;;;;;;;;;;;;;;;;;
;;; Core functions ;;;
;;;;;;;;;;;;;;;;;;;;;;

capslockFuncTriggered := false

triggerCapslockFunc()
{
  global capslockFuncTriggered
  capslockFuncTriggered := true
  switch (A_ThisHotKey)
  {
    ;;;
    ;;; vim-like navigations
    ;;;
    case "j": Send {Down}
    case "k": Send {Up}
    case "h": Send {Left}
    case "l": Send {Right}

    ;;;
    ;;; Hyper app toggles
    ;;;
    case "a": toggleAppWindow("Taskmgr", "TaskManagerWindow")                                                                   ; a - Task Manager
    case "c": toggleAppWindow("chrome", "Chrome_WidgetWin_1")                                                                   ; c - Chrome
    case "d": toggleAppWindow("Lingoes", "Afx:400000:0", "", getUserAppLink("Lingoes"))                                         ; d - Lingoes
    case "e": toggleAppWindow("msedge", "Chrome_WidgetWin_1")                                                                   ; e - Edge
    case "f": toggleAppWindow("firefox", "MozillaWindowClass", "", getScoopAppLink("Firefox"))                                  ; f - Firefox
    case "m": toggleAppWindow("foobar2000", "{97E27FAA-C0B3-4b8e-A693-ED7881E99FC1}", "", getScoopAppLink("Foobar2000"))        ; m - Foobar2000
    case "n": toggleAppWindow("Notepad", "Notepad")                                                                             ; n - Notepad
    case "s": toggleAppWindow("sublime_text", "PX_WINDOW_CLASS", "", getScoopAppLink("Sublime Text 4"))                         ; s - Sublime Text
    case "v": toggleAppWindow("Code", "Chrome_WidgetWin_1", "", getScoopAppLink("Visual Studio Code"))                          ; v - VS Code
    case "w": toggleAppWindow("WeChat", "WeChatMainWndForPC", "WeChat", getCommonAppLink("WeChat\WeChat"))                      ; w - WeChat
    case "x": toggleAppWindow("Seal", "Chrome_WidgetWin_1", "Seal", getCommonAppLink("Seal"))                                   ; x - Seal
    case "z": toggleAppWindow("Explorer", "CabinetWClass")                                                                      ; z - Explorer
    case "Space": toggleAppWindow("Feishu", "Chrome_WidgetWin_0", "Feishu", getUserAppLink("Feishu"))                           ; Space - Feishu
    case "SC027": toggleAppWindow("WindowsTerminal", "CASCADIA_HOSTING_WINDOW_CLASS", "", getScoopAppLink("Windows Terminal"))  ; ; - Windows Terminal
    case "'": toggleAppWindow("alacritty", "Window Class", "", getScoopAppLink("Alacritty"))                                    ; ' - Alacritty
    case "\": toggleAppWindow("KeePass", "WindowsForms10.Window.8.app.0.30495d1_r6_ad1", "", getScoopAppLink("KeePass"))        ; \ - KeePass
    case ".": toggleAppWindow("sublime_merge", "PX_WINDOW_CLASS", "", getScoopAppLink("Sublime Merge"))                         ; . - Sublime Merge

    ;;;
    ;;; HyperAlt app toggles
    ;;;
    case "+a": toggleAppWindow("atom", "Chrome_WidgetWin_1")                                                                    ; a - Atom
    case "+m": toggleAppWindow("Spotify", "SpotifyMainWindow")                                                                  ; m - Spotify
    case "+o": toggleAppWindow("ONENOTE", "Framework::CFrame")                                                                  ; o - OneNote
    case "+w": toggleAppWindow("WhatsApp", "Chrome_WidgetWin_1")                                                                ; w - WhatsApp
    case "+z": toggleAppWindow("Zeplin", "Chrome_WidgetWin_1")                                                                  ; z - Zeplin
    case "+0": toggleAppWindow("v2rayN", "WindowsForms10.Window.8.app.0.34f5582_r6_ad1", "", getScoopAppLink("v2rayN"))         ; 0 - v2rayN
    case "+Space": toggleAppWindow("Feishu", "Chrome_WidgetWin_0", "Feishu Meetings")                                           ; Space - Feishu Meeting
    case "+SC027": defaultCapslockHandler()
  }
}

defaultCapslockHandler()
{
  global capslockFuncTriggered
  capslockFuncTriggered := true

  ToolTip, % "Key " . A_ThisHotKey . " is not registered as Capslock shortcut."
  SetTimer, RemoveCapslockToolTip, -1000
  return

  RemoveCapslockToolTip:
    ToolTip
  return
}

handleCapslockUp()
{
  global capslockFuncTriggered

  if (capslockFuncTriggered == false)
  {
    Send {Esc}
  }
  else
  {
    capslockFuncTriggered := false
  }
}

;;;;;;;;;;;;;;;;;;;;;;
;;; Util functions ;;;
;;;;;;;;;;;;;;;;;;;;;;

isValidWindow(winTitle)
{
  WinGetClass, winClass, %winTitle%
  WinGetTitle, title, %winTitle%
  return title <> ""
}

toggleAppWindow(ahk_exe, ahk_class := "", title := "", bin_target := "")
{
  winTitle := title
  if (ahk_class != "")
  {
    winTitle .= " ahk_class " . ahk_class
  }
  if (ahk_exe != "")
  {
    winTitle .= " ahk_exe " . ahk_exe . ".exe"
  }

  if !WinExist(winTitle)
  {
    if (bin_target == "")
    {
      bin_target := ahk_exe
    }
    Run, %bin_target%
    return
  }

  if WinActive(winTitle)
  {
    ; Hide in reverse order to avoid flickering.
    WinGet, winList, List, %winTitle%
    Loop, %winList%
    {
      idx := winList + 1 - A_Index
      idxWinTitle := "ahk_id " . winList%idx%
      if (isValidWindow(idxWinTitle))
      {
        WinMinimize, %idxWinTitle%
      }
    }
  }
  else
  {
    ; Show in reverse order to get all windows back.
    WinGet, winList, List, %winTitle%
    Loop, %winList%
    {
      idx := winList + 1 - A_Index
      idxWinTitle := "ahk_id " . winList%idx%
      if (isValidWindow(idxWinTitle))
      {
        WinActivate, %idxWinTitle%
      }
    }
  }
}

getCommonAppLink(name)
{
  return A_ProgramsCommon . "\" . name . ".lnk"
}

getUserAppLink(name)
{
  return A_Programs . "\" . name . ".lnk"
}

getScoopAppLink(name)
{
  return A_Programs . "\Scoop Apps\" . name . ".lnk"
}

;;;;;;;;;;;;;;;;;;;;;
;;; Register keys ;;;
;;;;;;;;;;;;;;;;;;;;;

#If GetKeyState("Capslock", "P")

a::triggerCapslockFunc()
b::triggerCapslockFunc()
c::triggerCapslockFunc()
d::triggerCapslockFunc()
e::triggerCapslockFunc()
f::triggerCapslockFunc()
g::triggerCapslockFunc()
h::triggerCapslockFunc()
i::triggerCapslockFunc()
j::triggerCapslockFunc()
k::triggerCapslockFunc()
l::triggerCapslockFunc()
m::triggerCapslockFunc()
n::triggerCapslockFunc()
o::triggerCapslockFunc()
p::triggerCapslockFunc()
q::triggerCapslockFunc()
r::triggerCapslockFunc()
s::triggerCapslockFunc()
t::triggerCapslockFunc()
u::triggerCapslockFunc()
v::triggerCapslockFunc()
w::triggerCapslockFunc()
x::triggerCapslockFunc()
y::triggerCapslockFunc()
z::triggerCapslockFunc()
1::triggerCapslockFunc()
2::triggerCapslockFunc()
3::triggerCapslockFunc()
4::triggerCapslockFunc()
5::triggerCapslockFunc()
6::triggerCapslockFunc()
7::triggerCapslockFunc()
8::triggerCapslockFunc()
9::triggerCapslockFunc()
0::triggerCapslockFunc()
Space::triggerCapslockFunc()
Tab::triggerCapslockFunc()
Enter::triggerCapslockFunc()
Esc::triggerCapslockFunc()
Backspace::triggerCapslockFunc()
ScrollLock::triggerCapslockFunc()
Delete::triggerCapslockFunc()
Insert::triggerCapslockFunc()
Home::triggerCapslockFunc()
End::triggerCapslockFunc()
PgUp::triggerCapslockFunc()
PgDn::triggerCapslockFunc()
Up::triggerCapslockFunc()
Down::triggerCapslockFunc()
Left::triggerCapslockFunc()
Right::triggerCapslockFunc()
F1::triggerCapslockFunc()
F2::triggerCapslockFunc()
F3::triggerCapslockFunc()
F4::triggerCapslockFunc()
F5::triggerCapslockFunc()
F6::triggerCapslockFunc()
F7::triggerCapslockFunc()
F8::triggerCapslockFunc()
F9::triggerCapslockFunc()
F10::triggerCapslockFunc()
F11::triggerCapslockFunc()
F12::triggerCapslockFunc()
-::triggerCapslockFunc()
=::triggerCapslockFunc()
[::triggerCapslockFunc()
]::triggerCapslockFunc()
SC027::triggerCapslockFunc() ; SC027 - semicolon
'::triggerCapslockFunc()
`::triggerCapslockFunc()
\::triggerCapslockFunc()
,::triggerCapslockFunc()
.::triggerCapslockFunc()
/::triggerCapslockFunc()

+a::triggerCapslockFunc()
+b::triggerCapslockFunc()
+c::triggerCapslockFunc()
+d::triggerCapslockFunc()
+e::triggerCapslockFunc()
+f::triggerCapslockFunc()
+g::triggerCapslockFunc()
+h::triggerCapslockFunc()
+i::triggerCapslockFunc()
+j::triggerCapslockFunc()
+k::triggerCapslockFunc()
+l::triggerCapslockFunc()
+m::triggerCapslockFunc()
+n::triggerCapslockFunc()
+o::triggerCapslockFunc()
+p::triggerCapslockFunc()
+q::triggerCapslockFunc()
+r::triggerCapslockFunc()
+s::triggerCapslockFunc()
+t::triggerCapslockFunc()
+u::triggerCapslockFunc()
+v::triggerCapslockFunc()
+w::triggerCapslockFunc()
+x::triggerCapslockFunc()
+y::triggerCapslockFunc()
+z::triggerCapslockFunc()
+1::triggerCapslockFunc()
+2::triggerCapslockFunc()
+3::triggerCapslockFunc()
+4::triggerCapslockFunc()
+5::triggerCapslockFunc()
+6::triggerCapslockFunc()
+7::triggerCapslockFunc()
+8::triggerCapslockFunc()
+9::triggerCapslockFunc()
+0::triggerCapslockFunc()
+Space::triggerCapslockFunc()
+Tab::triggerCapslockFunc()
+Enter::triggerCapslockFunc()
+Esc::triggerCapslockFunc()
+Backspace::triggerCapslockFunc()
+ScrollLock::triggerCapslockFunc()
+Delete::triggerCapslockFunc()
+Insert::triggerCapslockFunc()
+Home::triggerCapslockFunc()
+End::triggerCapslockFunc()
+PgUp::triggerCapslockFunc()
+PgDn::triggerCapslockFunc()
+Up::triggerCapslockFunc()
+Down::triggerCapslockFunc()
+Left::triggerCapslockFunc()
+Right::triggerCapslockFunc()
+F1::triggerCapslockFunc()
+F2::triggerCapslockFunc()
+F3::triggerCapslockFunc()
+F4::triggerCapslockFunc()
+F5::triggerCapslockFunc()
+F6::triggerCapslockFunc()
+F7::triggerCapslockFunc()
+F8::triggerCapslockFunc()
+F9::triggerCapslockFunc()
+F10::triggerCapslockFunc()
+F11::triggerCapslockFunc()
+F12::triggerCapslockFunc()
+-::triggerCapslockFunc()
+=::triggerCapslockFunc()
+[::triggerCapslockFunc()
+]::triggerCapslockFunc()
+SC027::triggerCapslockFunc() ; SC027 - semicolon
+'::triggerCapslockFunc()
+`::triggerCapslockFunc()
+\::triggerCapslockFunc()
+,::triggerCapslockFunc()
+.::triggerCapslockFunc()
+/::triggerCapslockFunc()

#If
