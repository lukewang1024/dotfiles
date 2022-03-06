#SingleInstance Force
#NoEnv
#Persistent
#usehook ; possibly intercept windows binds

SendMode Input
SetTitleMatchMode, 3
DetectHiddenWindows, On

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

; Scripts in 'lib' may have any code
#Include %A_ScriptDir%\lib\appskey-mod.ahk
#Include %A_ScriptDir%\lib\capslock-mod.ahk
#Include %A_ScriptDir%\lib\conemu-hack.ahk

; Remap Win-Shift-Q to Alt-F4
#+q::Send !{F4}

; Reload by Ctrl-Alt-Shift-R
^!+r::Reload
