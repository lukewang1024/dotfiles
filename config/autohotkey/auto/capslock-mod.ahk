#Include utils\register-hotkeys.ahk

; One of the qwirks of AHK
#If GetKeyState("Capslock", "P")
#If

Hotkey, If, GetKeyState("Capslock"`, "P") ; Note the last comma needs escape
registerHotkeys("TriggerCapslockFuncLabel")
registerHotkeys("TriggerCapslockFuncLabel", "+")
Hotkey, If
