#Include app-toggle.ahk
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
    case "a": toggleAppWindow("Taskmgr", "TaskManagerWindow")                                                                   ; a - Task Manager
    case "c": toggleAppWindow("chrome", "Chrome_WidgetWin_1")                                                                   ; c - Chrome
    case "d": toggleAppWindow("Lingoes", "Afx:400000:0", "", getUserAppLink("Lingoes"), 1)                                      ; d - Lingoes
    case "e": toggleAppWindow("msedge", "Chrome_WidgetWin_1")                                                                   ; e - Edge
    case "f": toggleAppWindow("firefox", "MozillaWindowClass", "", getScoopAppLink("Firefox"))                                  ; f - Firefox
    case "m": toggleAppWindow("foobar2000", "{97E27FAA-C0B3-4b8e-A693-ED7881E99FC1}", "", getScoopAppLink("Foobar2000"))        ; m - Foobar2000
    case "n": toggleAppWindow("Notepad", "Notepad")                                                                             ; n - Notepad
    case "s": toggleAppWindow("sublime_text", "PX_WINDOW_CLASS", "", getScoopAppLink("Sublime Text 4"))                         ; s - Sublime Text
    case "v": toggleAppWindow("Code", "Chrome_WidgetWin_1", "", getScoopAppLink("Visual Studio Code"))                          ; v - VS Code
    case "w": toggleAppWindow("WeChat", "WeChatMainWndForPC", "WeChat", getCommonAppLink("WeChat\WeChat"), 1)                   ; w - WeChat
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
    case "+m": toggleAppWindow("Spotify", "Chrome_WidgetWin_0", "", getUserAppLink("Spotify"))                                  ; m - Spotify
    case "+o": toggleAppWindow("ONENOTE", "Framework::CFrame")                                                                  ; o - OneNote
    case "+w": toggleAppWindow("WhatsApp", "Chrome_WidgetWin_1")                                                                ; w - WhatsApp
    case "+z": toggleAppWindow("Zeplin", "Chrome_WidgetWin_1")                                                                  ; z - Zeplin
    case "+0": toggleAppWindow("v2rayN", "WindowsForms10.Window.8.app.0.34f5582_r6_ad1", "", getScoopAppLink("v2rayN"))         ; 0 - v2rayN
    case "+Space": toggleAppWindow("Feishu", "Chrome_WidgetWin_0", "Feishu Meetings", getUserAppLink("Feishu"))                 ; Space - Feishu Meeting

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
