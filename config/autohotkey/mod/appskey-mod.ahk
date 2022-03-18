#Include audio-switcher.ahk

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
    case "Enter": WinSet, AlwaysOnTop, , A
    case "F1": switchAudioDevice(1)
    case "F2": switchAudioDevice(2)
    case "F3": switchAudioDevice(3)
    case "F4": switchAudioDevice(4)
    case "F5": Send {Media_Stop}
    case "F6": Send {Media_Prev}
    case "F7": Send {Media_Play_Pause}
    case "F8": Send {Media_Next}
    case "F9": Send {Volume_Down}
    case "F10": Send {Volume_Up}
    case "F11": Send {Volume_Mute}
    case "F12": MsgBox, 0, Quick sleep, RAlt + AppsKey + F12 to put PC into sleep`nRCtrl + RAlt + AppsKey + F12 to put PC into hibernate, 2
    case ">!F12": DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0)
    case ">^>!F12": DllCall("PowrProf\SetSuspendState", "int", 1, "int", 0, "int", 0)

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
