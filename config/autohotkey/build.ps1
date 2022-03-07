$dir = $PSCommandPath | Split-Path -Parent
Ahk2Exe.exe /in "$dir\kbmod.ahk" /icon "$dir\res\kbmod.ico"