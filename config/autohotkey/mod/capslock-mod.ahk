#Include app-toggle.ahk
#Include system.ahk
#Include window-snap.ahk

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
    case "+j": moveMouse(10)
    case "+k": moveMouse(-10)
    case "+h": moveMouse(-10, true)
    case "+l": moveMouse(10, true)
    case "+Enter": Send {LButton}
    case "+Backspace": Send {RButton}

    ;;;
    ;;; snap window
    ;;;
    ; left half
    case "Left"       : snapActiveWindow(  0,   0,  .5,   1)
    ; right half
    case "Right"      : snapActiveWindow( .5,   0,  .5,   1)
    ; top half
    case "Up"         : snapActiveWindow(  0,   0,   1,  .5)
    ; bottom half
    case "Down"       : snapActiveWindow(  0,  .5,   1,  .5)
    ; fullscreen
    case "Enter"      : snapActiveWindow(  0,   0,   1,   1)
    case "NumpadEnter": snapActiveWindow(  0,   0,   1,   1)
    ; center
    case "Numpad5"    : snapActiveWindow( .2,  .2,  .6,  .6)
    case "NumpadClear": snapActiveWindow( .2,  .2,  .6,  .6)
    case "Backspace"  : snapActiveWindow( .2,  .2,  .6,  .6)
    ; left 2/3
    case "+Up"        : snapActiveWindow(  0,   0, .67,   1)
    case "Numpad4"    : snapActiveWindow(  0,   0, .67,   1)
    case "NumpadLeft" : snapActiveWindow(  0,   0, .67,   1)
    ; right 1/3
    case "+Down"      : snapActiveWindow(.67,   0, .33,   1)
    case "Numpad6"    : snapActiveWindow(.67,   0, .33,   1)
    case "NumpadRight": snapActiveWindow(.67,   0, .33,   1)
    ; top 2/3
    case "Numpad8"    : snapActiveWindow(  0,   0,   1, .67)
    case "NumpadUp"   : snapActiveWindow(  0,   0,   1, .67)
    ; bottom 1/3
    case "Numpad2"    : snapActiveWindow(  0, .67,   1, .33)
    case "NumpadDown" : snapActiveWindow(  0, .67,   1, .33)
    ; top left
    case "Numpad7"    : snapActiveWindow(  0,   0,  .5,  .5)
    case "NumpadHome" : snapActiveWindow(  0,   0,  .5,  .5)
    ; top right
    case "Numpad9"    : snapActiveWindow( .5,   0,  .5,  .5)
    case "NumpadPgUp" : snapActiveWindow( .5,   0,  .5,  .5)
    ; bottom left
    case "Numpad1"    : snapActiveWindow(  0,  .5,  .5,  .5)
    case "NumpadEnd"  : snapActiveWindow(  0,  .5,  .5,  .5)
    ; bottom right
    case "Numpad3"    : snapActiveWindow( .5,  .5,  .5,  .5)
    case "NumpadPgDn" : snapActiveWindow( .5,  .5,  .5,  .5)

    ;;;
    ;;; move window across displays
    ;;;
    case "+Left"      : Send #+{Left}
    case "+Right"     : Send #+{Right}

    ;;;
    ;;; Hyper app toggles
    ;;;
    case "a": toggleAppWindowExactMatch("msedge", "Chrome_WidgetWin_1")                                                                   ; a - Edge
    case "c": toggleAppWindowExactMatch("chrome", "Chrome_WidgetWin_1")                                                                   ; c - Chrome
    case "d": toggleAppWindowExactMatch("Lingoes", "Afx:400000:0", "", getUserAppLink("Lingoes"), 4)                                      ; d - Lingoes
    case "e": toggleAppWindowExactMatch("sublime_text", "PX_WINDOW_CLASS", "", getScoopAppLink("Sublime Text 4"))                         ; e - Sublime Text
    case "f": toggleAppWindowExactMatch("firefox", "MozillaWindowClass", "", getScoopAppLink("Firefox"))                                  ; f - Firefox
    case "i": toggleAppWindowExactMatch("Cursor", "Chrome_WidgetWin_1", "", getUserAppLink("Cursor"))                                     ; i - Cursor
    case "m": toggleAppWindowExactMatch("foobar2000", "{97E27FAA-C0B3-4b8e-A693-ED7881E99FC1}", "", getScoopAppLink("Foobar2000"))        ; m - Foobar2000
    case "n": toggleAppWindowExactMatch("Notepad", "Notepad")                                                                             ; n - Notepad    
    case "v": toggleAppWindowExactMatch("Code", "Chrome_WidgetWin_1", "", getScoopAppLink("Visual Studio Code"))                          ; v - VS Code
    case "w": toggleAppWindowExactMatch("Weixin", "Qt51514QWindowIcon", "", getCommonAppLink("WeChat Beta\WeChat Beta"), 4)               ; w - WeChat
    case "x": toggleAppWindowExactMatch("Corplink", "Chrome_WidgetWin_1", "SealSuite", getCommonAppLink("Feilian"))                       ; x - Feilian
    case "z": toggleAppWindowExactMatch("Explorer", "CabinetWClass")                                                                      ; z - Explorer
    case "``": toggleAppWindowExactMatch("ApplicationFrameHost", "ApplicationFrameWindow", "Calculator", "calculator:")                   ; ` - Calculator
    case "1": toggleAppWindowPartialMatch("ApplicationFrameHost", "ApplicationFrameWindow", "- Calendar", "outlookcal:")                  ; 1 - Calendar
    case "3": toggleAppWindowPartialMatch("ApplicationFrameHost", "ApplicationFrameWindow", "- Mail", "outlookmail:")                     ; 3 - Mail
    case "5": toggleAppWindowExactMatch("WinSCP", "TScpCommanderForm", "", getScoopAppLink("WinSCP"))                                     ; 5 - WinSCP
    case "9": toggleAppWindowExactMatch("Charles", "SunAwtFrame", "", getUserAppLink("Charles\Charles"))                                  ; 9 - Charles
    case "0": toggleAppWindowExactMatch("Proxifier", "Proxifier32Cls", "", getScoopAppLink("Proxifier PE"), 4)                            ; 0 - Proxifier
    case "Space": toggleAppWindowExactMatch("Feishu", "Chrome_WidgetWin_1", "Feishu", getCommonAppLink("Feishu"))                         ; Space - Feishu
    case "SC027": toggleAppWindowExactMatch("WindowsTerminal", "CASCADIA_HOSTING_WINDOW_CLASS", "", getScoopAppLink("Windows Terminal"))  ; ; - Windows Terminal
    case "'": toggleAppWindowExactMatch("alacritty", "Window Class", "", getScoopAppLink("Alacritty"))                                    ; ' - Alacritty
    case "\": toggleAppWindowExactMatch("KeePassXC", "Qt51511QWindowIcon", "", getScoopAppLink("KeePassXC"))                              ; \ - KeePassXC
    case ".": toggleAppWindowExactMatch("sublime_merge", "PX_WINDOW_CLASS", "", getScoopAppLink("Sublime Merge"))                         ; . - Sublime Merge
    case "/": toggleAppWindowExactMatch("doublecmd", "TTOTAL_CMD", "", getScoopAppLink("Double Commander"))                               ; z - Double Commander

    ;;;
    ;;; HyperAlt app toggles
    ;;;
    case "+a": toggleAppWindowExactMatch("Taskmgr", "TaskManagerWindow")                                                                  ; a - Task Manager
    case "+d": toggleAppWindowExactMatch("zeal", "Qt5QWindowIcon", "", getScoopAppLink("Zeal"))                                           ; d - Zeal
    case "+m": toggleAppWindowExactMatch("QQMusic", "TXGuiFoundation", "", getUserAppLink("QQMusic"), 4)                                  ; m - QQ Music
    case "+o": toggleAppWindowExactMatch("ONENOTE", "Framework::CFrame")                                                                  ; o - OneNote
    case "+s": toggleAppWindowExactMatch("Spotify", "Chrome_WidgetWin_0", "", getUserAppLink("Spotify"))                                  ; s - Spotify
    case "+w": toggleAppWindowExactMatch("WhatsApp", "Chrome_WidgetWin_1")                                                                ; w - WhatsApp
    case "+0": toggleAppWindowExactMatch("v2rayN", "WindowsForms10.Window.8.app.0.34f5582_r6_ad1", "", getScoopAppLink("v2rayN"))         ; 0 - v2rayN
    case "+Space": toggleAppWindowExactMatch("Feishu", "Chrome_WidgetWin_0", "Feishu Meetings", getUserAppLink("Feishu"))                 ; Space - Feishu Meeting
    case "+/": toggleAppWindowExactMatch("filezilla", "wxWindowNR", "", getScoopAppLink("FileZilla"))                                     ; / - FileZilla

    default: defaultCapslockHandler()
  }
}

TriggerCapslockFuncLabel:
  triggerCapslockFunc()
  return

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
