#SingleInstance Force
#NoEnv
#Persistent
#usehook ; possibly intercept windows binds

SendMode Input
SetTitleMatchMode, 3

SetCapsLockState, AlwaysOff

Menu, Tray, Icon, %A_ScriptDir%\res\kbmod.ico

; Scripts in 'app' should behave as separate apps
Loop, %A_ScriptDir%\app\*.ahk
{
  WinClose, %A_LoopFileName% - AutoHotkey
  Run, % A_ScriptDir . "\app\" . A_LoopFileName
}

#Include %A_ScriptDir%\lib ; Set root path for other includes

; Scripts in 'auto' must not have top level return, hotkey, hotstring etc.
#Include %A_ScriptDir%\auto\appskey-mod.ahk
#Include %A_ScriptDir%\auto\capslock-mod.ahk

; Scripts in 'mod' may have any code
#Include %A_ScriptDir%\mod\appskey-mod.ahk
#Include %A_ScriptDir%\mod\capslock-mod.ahk
#Include %A_ScriptDir%\mod\conemu-hack.ahk

; Close active window by Win-Shift-Q
#+q::Send !{F4}

; Lock workstation by Ctrl-Alt-Q
^!q::DllCall("LockWorkStation")

; Reload kbmod by Ctrl-Alt-Shift-R
^!+r::Reload
