#Include register-hotkeys.ahk

hyperInit()

; One of the qwirks of AHK
#If GetKeyState("Capslock", "P") || GetKeyState("F18", "P")
#If

Hotkey, If, GetKeyState("Capslock"`, "P") || GetKeyState("F18"`, "P") ; Note the commas need escape
registerHotkeys("TriggerCapslockFuncLabel")
registerHotkeys("TriggerCapslockFuncLabel", "+")
; F18 is the layer activator, never an action key. Capturing its own key-down
; would mark it as a used chord and break tap-F18 -> Escape from a remote host.
Hotkey, F18, Off
Hotkey, +F18, Off
Hotkey, If
