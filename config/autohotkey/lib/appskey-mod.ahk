AppsKey Up::handleAppsKeyUp()

;;;;;;;;;;;;;;;;;;;;;;
;;; Core functions ;;;
;;;;;;;;;;;;;;;;;;;;;;

appsKeyFuncTriggered := false

triggerAppsKeyFunc()
{
  global appsKeyFuncTriggered
  appsKeyFuncTriggered := true

  switch (A_ThisHotKey)
  {
    case "F5": Send {Media_Stop}
    case "F6": Send {Media_Prev}
    case "F7": Send {Media_Play_Pause}
    case "F8": Send {Media_Next}
    case "F9": Send {Volume_Down}
    case "F10": Send {Volume_Up}
    case "F11": Send {Volume_Mute}
    case "F12": MsgBox, 0, Quick sleep, RAlt + AppsKey + F12 to put PC into sleep`nRCtrl + RAlt + AppsKey + F12 to put PC into hibernate, 2
    case ">!F12": DllCall("PowrProf\SetSuspendState", "int", 0, "int", 0, "int", 0)
    case ">^>!F12": DllCall("PowrProf\SetSuspendState", "int", 1, "int", 0, "int", 0)
  }
}

defaultAppsKeyHandler()
{
  global appsKeyFuncTriggered
  appsKeyFuncTriggered := true

  ToolTip, % "Key " . A_ThisHotKey . " is not registered as AppsKey shortcut."
  SetTimer, RemoveAppsKeyToolTip, -1000
  return

  RemoveAppsKeyToolTip:
    ToolTip
  return
}

handleAppsKeyUp()
{
  global appsKeyFuncTriggered

  if (appsKeyFuncTriggered == false)
  {
    Send {AppsKey}
  }
  else
  {
    appsKeyFuncTriggered := false
  }
}

;;;;;;;;;;;;;;;;;;;;;
;;; Register keys ;;;
;;;;;;;;;;;;;;;;;;;;;

#If GetKeyState("AppsKey", "P")

a::triggerAppsKeyFunc()
b::triggerAppsKeyFunc()
c::triggerAppsKeyFunc()
d::triggerAppsKeyFunc()
e::triggerAppsKeyFunc()
f::triggerAppsKeyFunc()
g::triggerAppsKeyFunc()
h::triggerAppsKeyFunc()
i::triggerAppsKeyFunc()
j::triggerAppsKeyFunc()
k::triggerAppsKeyFunc()
l::triggerAppsKeyFunc()
m::triggerAppsKeyFunc()
n::triggerAppsKeyFunc()
o::triggerAppsKeyFunc()
p::triggerAppsKeyFunc()
q::triggerAppsKeyFunc()
r::triggerAppsKeyFunc()
s::triggerAppsKeyFunc()
t::triggerAppsKeyFunc()
u::triggerAppsKeyFunc()
v::triggerAppsKeyFunc()
w::triggerAppsKeyFunc()
x::triggerAppsKeyFunc()
y::triggerAppsKeyFunc()
z::triggerAppsKeyFunc()
1::triggerAppsKeyFunc()
2::triggerAppsKeyFunc()
3::triggerAppsKeyFunc()
4::triggerAppsKeyFunc()
5::triggerAppsKeyFunc()
6::triggerAppsKeyFunc()
7::triggerAppsKeyFunc()
8::triggerAppsKeyFunc()
9::triggerAppsKeyFunc()
0::triggerAppsKeyFunc()
Space::triggerAppsKeyFunc()
Tab::triggerAppsKeyFunc()
Enter::triggerAppsKeyFunc()
Esc::triggerAppsKeyFunc()
Backspace::triggerAppsKeyFunc()
ScrollLock::triggerAppsKeyFunc()
Delete::triggerAppsKeyFunc()
Insert::triggerAppsKeyFunc()
Home::triggerAppsKeyFunc()
End::triggerAppsKeyFunc()
PgUp::triggerAppsKeyFunc()
PgDn::triggerAppsKeyFunc()
Up::triggerAppsKeyFunc()
Down::triggerAppsKeyFunc()
Left::triggerAppsKeyFunc()
Right::triggerAppsKeyFunc()
F1::triggerAppsKeyFunc()
F2::triggerAppsKeyFunc()
F3::triggerAppsKeyFunc()
F4::triggerAppsKeyFunc()
F5::triggerAppsKeyFunc()
F6::triggerAppsKeyFunc()
F7::triggerAppsKeyFunc()
F8::triggerAppsKeyFunc()
F9::triggerAppsKeyFunc()
F10::triggerAppsKeyFunc()
F11::triggerAppsKeyFunc()
F12::triggerAppsKeyFunc()
-::triggerAppsKeyFunc()
=::triggerAppsKeyFunc()
[::triggerAppsKeyFunc()
]::triggerAppsKeyFunc()
SC027::triggerAppsKeyFunc() ; SC027 - semicolon
'::triggerAppsKeyFunc()
`::triggerAppsKeyFunc()
\::triggerAppsKeyFunc()
,::triggerAppsKeyFunc()
.::triggerAppsKeyFunc()
/::triggerAppsKeyFunc()

>!F12::triggerAppsKeyFunc()
>^>!F12::triggerAppsKeyFunc()

#If
