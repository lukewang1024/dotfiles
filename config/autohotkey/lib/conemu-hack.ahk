;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; ConEmu workarounds ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; Override the issue of mintty capturing keystrokes would make ConEmu unable to switch tabs
; Win-Z somehow doesn't work in Win8 onward, that is why Ctrl-Alt-Z is used instead...
;
ConEmuSwitchFocus(key)
{
  ; switch focus by Ctrl-Alt-Z (configured in ConEmu)
  Send ^!z
  Send %key%
}

#IfWinActive ahk_class VirtualConsoleClass
^1::ConEmuSwitchFocus("^1")
^2::ConEmuSwitchFocus("^2")
^3::ConEmuSwitchFocus("^3")
^4::ConEmuSwitchFocus("^4")
^5::ConEmuSwitchFocus("^5")
^6::ConEmuSwitchFocus("^6")
^7::ConEmuSwitchFocus("^7")
^8::ConEmuSwitchFocus("^8")
^9::ConEmuSwitchFocus("^9")
#!p::ConEmuSwitchFocus("!p")
#IfWinActive
