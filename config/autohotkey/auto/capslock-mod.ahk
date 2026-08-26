#Include register-hotkeys.ahk

; One of the qwirks of AHK
#If GetKeyState("Capslock", "P") || GetKeyState("F18", "P")
#If

Hotkey, If, GetKeyState("Capslock"`, "P") || GetKeyState("F18"`, "P") ; Note the commas need escape
registerHotkeys("TriggerCapslockFuncLabel")
registerHotkeys("TriggerCapslockFuncLabel", "+")
Hotkey, If
