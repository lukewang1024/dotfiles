isValidWindow(winTitle)
{
  WinGetClass, winClass, %winTitle%
  WinGetTitle, title, %winTitle%
  return title <> ""
}

toggleAppWindow(ahk_exe, ahk_class := "", title := "", bin_target := "")
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
      idx := winList + 1 - A_Index
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
