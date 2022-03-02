; Press Capslock -> Esc
Capslock::Esc

; Make Win Key + Capslock work like Capslock
#Capslock::
if GetKeyState("CapsLock", "T") = 1
  SetCapsLockState, AlwaysOff
else
  SetCapsLockState, AlwaysOn
return

#If GetKeyState("Capslock", "P")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; vim-like navigations ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

j::Send {Down}
k::Send {Up}
h::Send {Left}
l::Send {Right}

;;;;;;;;;;;;;;;;;;;;;;;;;
;;; Hyper app toggles ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;

; a - Task Manager
a::toggleAppWindow("Taskmgr", "TaskManagerWindow")

; c - Chrome
c::toggleAppWindow("chrome", "Chrome_WidgetWin_1")

; e - Edge
e::toggleAppWindow("msedge", "Chrome_WidgetWin_1")

; f - Firefox
f::toggleAppWindow("firefox", "MozillaWindowClass", "", getScoopAppLink("Firefox"))

; m - Foobar2000
m::toggleAppWindow("foobar2000", "{97E27FAA-C0B3-4b8e-A693-ED7881E99FC1}", "", getScoopAppLink("Foobar2000"))

; n - Notepad
n::toggleAppWindow("Notepad", "Notepad")

; s - Sublime Text
s::toggleAppWindow("sublime_text", "PX_WINDOW_CLASS", "", getScoopAppLink("Sublime Text 4"))

; v - VS Code
v::toggleAppWindow("Code", "Chrome_WidgetWin_1", "", getScoopAppLink("Visual Studio Code"))

; x - Seal
x::toggleAppWindow("Seal", "Chrome_WidgetWin_1", "Seal", getCommonAppLink("Seal"))

; z - Explorer
z::toggleAppWindow("Explorer", "CabinetWClass")

; Space - Feishu
Space::toggleAppWindow("Feishu", "Chrome_WidgetWin_0", "Feishu", getAppLink("Feishu"))

; ; - Windows Terminal
SC027::toggleAppWindow("WindowsTerminal", "CASCADIA_HOSTING_WINDOW_CLASS", "", getScoopAppLink("Windows Terminal"))

; ' - Alacritty
SC028::toggleAppWindow("alacritty", "Window Class", "", getScoopAppLink("Alacritty"))

; . - Sublime Merge
SC034::toggleAppWindow("sublime_merge", "PX_WINDOW_CLASS", "", getScoopAppLink("Sublime Merge"))

; \ - KeePass
SC02B::toggleAppWindow("KeePass", "WindowsForms10.Window.8.app.0.30495d1_r6_ad1", "", getScoopAppLink("KeePass"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; HyperAlt app toggles ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; a - Atom
+a::toggleAppWindow("atom", "Chrome_WidgetWin_1")

; m - Spotify
+m::toggleAppWindow("Spotify", "SpotifyMainWindow")

; o - OneNote
+o::toggleAppWindow("ONENOTE", "Framework::CFrame")

; w - WhatsApp
+w::toggleAppWindow("WhatsApp", "Chrome_WidgetWin_1")

; z - Zeplin
+z::toggleAppWindow("Zeplin", "Chrome_WidgetWin_1")

; 0 - v2rayN
+0::toggleAppWindow("v2rayN", "WindowsForms10.Window.8.app.0.34f5582_r6_ad1", "", getScoopAppLink("v2rayN"))

; Space - Feishu Meeting
+Space::toggleAppWindow("Feishu", "Chrome_WidgetWin_0", "Feishu Meetings")

#If

;;;;;;;;;;;;;;;;;;;;;;
;;; Util functions ;;;
;;;;;;;;;;;;;;;;;;;;;;

isValidWindow(winTitle)
{
  WinGetClass, winClass, %winTitle%
  WinGetTitle, title, %winTitle%
  return title <> "" And winClass <> "Shell_SecondaryTrayWnd" And winClass <> "Shell_TrayWnd"
}

toggleAppWindow(ahk_exe, ahk_class, title := "", bin_target := "")
{
  winTitle := title . " ahk_class " . ahk_class . " ahk_exe " . ahk_exe . ".exe"

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

getAppLink(name)
{
  return A_Programs . "\" . name . ".lnk"
}

getScoopAppLink(name)
{
  return A_Programs . "\Scoop Apps\" . name . ".lnk"
}