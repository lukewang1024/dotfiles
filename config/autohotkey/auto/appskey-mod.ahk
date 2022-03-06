#Include utils\register-hotkeys.ahk

; One of the qwirks of AHK
#If GetKeyState("AppsKey", "P")
#If

Hotkey, If, GetKeyState("AppsKey"`, "P") ; Note the last comma needs escape
registerHotkeys("TriggerAppsKeyFuncLabel")
registerHotkeys("TriggerAppsKeyFuncLabel", ">!")
registerHotkeys("TriggerAppsKeyFuncLabel", ">^>!")
Hotkey, If
