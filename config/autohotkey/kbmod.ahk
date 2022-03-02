#SingleInstance Force
#NoEnv
#Persistent
#usehook ; possibly intercept windows binds

SendMode Input
SetTitleMatchMode, 3
DetectHiddenWindows, On

SetCapsLockState, AlwaysOff

Menu, Tray, Icon, %A_ScriptDir%\res\kbmod.ico

#include %A_ScriptDir%\lib
#include capslock-mod.ahk
#include conemu-hack.ahk

; Remap Win-Shift-Q to Alt-F4
#+q::Send !{F4}

; Reload by Ctrl-Alt-Shift-R
^!+r::Reload