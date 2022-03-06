#SingleInstance Force
#NoEnv
#Persistent
#usehook ; possibly intercept windows binds

SendMode Input
SetTitleMatchMode, 3
DetectHiddenWindows, On

SetCapsLockState, AlwaysOff

Menu, Tray, Icon, %A_ScriptDir%\res\kbmod.ico

Loop, %A_ScriptDir%\app\*.ahk
{
  WinClose, %A_LoopFileName% - AutoHotkey
  Run, % A_ScriptDir . "\app\" . A_LoopFileName
}

#include %A_ScriptDir%\lib
#include appskey-mod.ahk
#include capslock-mod.ahk
#include conemu-hack.ahk

; Remap Win-Shift-Q to Alt-F4
#+q::Send !{F4}

; Reload by Ctrl-Alt-Shift-R
^!+r::Reload
