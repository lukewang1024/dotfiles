#Include app-toggle.ahk
#Include audio-switcher.ahk
#Include system.ahk

AppsKey Up::handleAppsKeyUp()

;;;;;;;;;;;;;;;;;;;;;;
;;; Core functions ;;;
;;;;;;;;;;;;;;;;;;;;;;

appsKeyFuncTriggered := false

triggerAppsKeyFunc()
{
  global appsKeyFuncTriggered
  appsKeyFuncTriggered := true

  switch (A_ThisHotKey)
  {
    ; Toggle active window always-on-top
    case "Enter": WinSet, AlwaysOnTop, , A

    ; Hide & unhide window
    case "h": hideActiveWindow()
    case ">!h": showHiddenWindows()

    ; Move mouse cursor by arrows & wsad
    case "Up":      moveMouse(-10)
    case "Down":    moveMouse(10)
    case "Left":    moveMouse(-10, true)
    case "Right":   moveMouse(10, true)
    case ">!Up":    moveMouse(-100)
    case ">!Down":  moveMouse(100)
    case ">!Left":  moveMouse(-100, true)
    case ">!Right": moveMouse(100, true)
    case ">^Up":    moveMouse(-1)
    case ">^Down":  moveMouse(1)
    case ">^Left":  moveMouse(-1, true)
    case ">^Right": moveMouse(1, true)
    case "w":       moveMouse(-10)
    case "s":       moveMouse(10)
    case "a":       moveMouse(-10, true)
    case "d":       moveMouse(10, true)
    case ">!w":     moveMouse(-100)
    case ">!s":     moveMouse(100)
    case ">!a":     moveMouse(-100, true)
    case ">!d":     moveMouse(100, true)
    case ">^w":     moveMouse(-1)
    case ">^s":     moveMouse(1)
    case ">^a":     moveMouse(-1, true)
    case ">^d":     moveMouse(1, true)

    ; Switch between audio devices
    case "F1": switchAudioDevice(1)
    case "F2": switchAudioDevice(2)
    case "F3": switchAudioDevice(3)
    case "F4": switchAudioDevice(4)

    ; Media keys
    case "F5": Send {Media_Stop}
    case "F6": Send {Media_Prev}
    case "F7": Send {Media_Play_Pause}
    case "F8": Send {Media_Next}
    case "F9": Send {Volume_Down}
    case "F10": Send {Volume_Up}
    case "F11": Send {Volume_Mute}

    ; Power saving shortcuts
    case "F12": showCustomShutdownMenu()
    case ">!F12": systemSleep()
    case ">^F12": turnOffMonitor()
    case ">^>!F12": systemHibernate()

    case "PrintScreen": Run, ms-screenclip:

    default: defaultAppsKeyHandler()
  }
}

TriggerAppsKeyFuncLabel:
  triggerAppsKeyFunc()
  return

defaultAppsKeyHandler()
{
  global appsKeyFuncTriggered
  appsKeyFuncTriggered := true

  ToolTip, % "Key " . A_ThisHotKey . " is not registered as AppsKey shortcut."
  SetTimer, RemoveAppsKeyToolTip, -1000
  return

  RemoveAppsKeyToolTip:
    ToolTip
  return
}

handleAppsKeyUp()
{
  global appsKeyFuncTriggered

  if (appsKeyFuncTriggered == false)
  {
    Send {AppsKey}
  }
  else
  {
    appsKeyFuncTriggered := false
  }
}
