#Include app-toggle.ahk
#Include system.ahk
#Include window-snap.ahk
#Include hyper.ahk

Capslock Up::handleCapslockUp()
F18 Up::handleCapslockUp()

#Capslock::
#F18::
  SetCapsLockState, % GetKeyState("CapsLock", "T") ? "AlwaysOff" : "AlwaysOn"
return

TriggerCapslockFuncLabel:
  hyperDispatch()
return

handleCapslockUp()
{
  global capslockFuncTriggered
  if !capslockFuncTriggered
    SendInput, {Esc}
  capslockFuncTriggered := false
}
