#Include tray-icon.ahk

; This checks if a window is, in fact a window, as opposed to the desktop or a menu, etc.
; WS_MINIMIZEBOX: 0x20000
; WS_CAPTION: 0xC00000
; WS_POPUP(for tooltips etc): 0x80000000
isValidWindow(winTitle)
{
  WinGet, s, Style, %winTitle%
  return s & 0x20000 || (s & 0xC00000 && !(s & 0x80000000)) ? 1 : 0
  ; WS_MINIMIZEBOX OR (WS_CAPTION AND !WS_POPUP)
}

toggleAppWindow(ahk_exe, ahk_class := "", title := "", bin_target := "", strategy := 0)
{
  winTitle := title
  if (ahk_class != "")
  {
    winTitle .= " ahk_class " . ahk_class
  }
  if (ahk_exe != "")
  {
    winTitle .= " ahk_exe " . ahk_exe . ".exe"
  }

  if !WinExist(winTitle)
  {
    if (bin_target == "")
    {
      bin_target := ahk_exe
    }
    Run, %bin_target%
    return
  }

  ; Strategy #1 - activate the matching window by simulating tray icon click
  if (strategy == 1)
  {
    if WinActive(winTitle)
    {
      ; 0x112 = WM_SYSCOMMAND, 0xF060 = SC_CLOSE
      PostMessage, 0x112, 0xF060
    }
    else
    {
      TrayIcon_Button(ahk_exe . ".exe", "L")
    }
    return
  }

  ; Strategy #2 - minimize / activate the matching window with smallest ahk_id
  if (strategy == 2)
  {
    WinGet, winList, List, %winTitle%
    Loop, %winList%
    {
      idxWin := winList%A_Index%
      if (!targetWin)
      {
        targetWin := idxWin
      }
      else if (targetWin > idxWin)
      {
        targetWin := idxWin
      }
    }
    targetWinTitle := "ahk_id " . targetWin
    if WinActive(targetWinTitle)
    {
      WinMinimize, %targetWinTitle%
    }
    else
    {
      WinActivate, %targetWinTitle%
    }
    return
  }

  ; Default strategy - minimize / activate all matching windows
  if WinActive(winTitle)
  {
    ; Hide in reverse order to avoid flickering.
    WinGet, winList, List, %winTitle%
    Loop, %winList%
    {
      idx := winList + 1 - A_Index
      idxWinTitle := "ahk_id " . winList%idx%
      if (isValidWindow(idxWinTitle))
      {
        WinMinimize, %idxWinTitle%
      }
    }
  }
  else
  {
    ; Show in reverse order to get all windows back.
    WinGet, winList, List, %winTitle%
    Loop, %winList%
    {
      idx := A_Index
      idxWinTitle := "ahk_id " . winList%idx%
      if (isValidWindow(idxWinTitle))
      {
        WinActivate, %idxWinTitle%
      }
    }
  }
}

getCommonAppLink(name)
{
  return A_ProgramsCommon . "\" . name . ".lnk"
}

getUserAppLink(name)
{
  return A_Programs . "\" . name . ".lnk"
}

getScoopAppLink(name)
{
  return A_Programs . "\Scoop Apps\" . name . ".lnk"
}

hideActiveWindow()
{
  global hiddenWindows

  activeWindow := WinExist("A")
  activeWinTitle := "ahk_id " . activeWindow
  if isValidWindow(activeWinTitle)
  {
    hiddenWindows .= (hiddenWindows ? "|" : "") . activeWindow
    WinHide, %activeWinTitle%

    WinGet, winList, List
    Loop, %winList%
    {
      hwid := winList%A_Index%
      winTitle := "ahk_id " . hwid
      if (isValidWindow(winTitle))
      {
        break
      }
    }
    WinActivate, %winTitle%
  }
}

showHiddenWindows()
{
  global hiddenWindows

  Loop, Parse, hiddenWindows, |
    WinShow ahk_id %A_LoopField%
  hiddenWindows = ""
}
