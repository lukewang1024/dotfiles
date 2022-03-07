snapActiveWindow(winPlaceHorizontal, winPlaceVertical, winSizeWidth, winSizeHeight) {
  WinGet, activeWin, ID, A
  if (activeWin == 0) {
      return
  }

  ; Some apps cannot be moved when maximized
  WinGet, minMax, MinMax, ahk_id %activeWin%
  if (minMax == 1) {
      WinRestore, ahk_id %activeWin%
  }

  activeMon := getMonitorIndexFromWindow(activeWin)
  SysGet, workArea, MonitorWorkArea, %activeMon%

  workAreaWidth := workAreaRight - workAreaLeft
  workAreaHeight := workAreaBottom - workAreaTop

  width := workAreaWidth * winSizeWidth
  height := workAreaHeight * winSizeHeight
  posX := workAreaLeft + workAreaWidth * winPlaceHorizontal
  posY := workAreaTop + workAreaHeight * winPlaceVertical

  WinMove, A, , %posX%, %posY%, %width%, %height%
}

/**
 * getMonitorIndexFromWindow retrieves the HWND (unique ID) of a given window.
 * @param {Uint} windowHandle
 * @author shinywong
 * @link http://www.autohotkey.com/board/topic/69464-how-to-determine-a-window-is-in-which-monitor/?p=440355
 */
getMonitorIndexFromWindow(windowHandle) {
  ; Starts with 1.
  monitorIndex := 1

  VarSetCapacity(monitorInfo, 40)
  NumPut(40, monitorInfo)

  if (monitorHandle := DllCall("MonitorFromWindow", "uint", windowHandle, "uint", 0x2))
    && DllCall("GetMonitorInfo", "uint", monitorHandle, "uint", &monitorInfo) {
    monitorLeft   := NumGet(monitorInfo,  4, "Int")
    monitorTop    := NumGet(monitorInfo,  8, "Int")
    monitorRight  := NumGet(monitorInfo, 12, "Int")
    monitorBottom := NumGet(monitorInfo, 16, "Int")
    workLeft      := NumGet(monitorInfo, 20, "Int")
    workTop       := NumGet(monitorInfo, 24, "Int")
    workRight     := NumGet(monitorInfo, 28, "Int")
    workBottom    := NumGet(monitorInfo, 32, "Int")
    isPrimary     := NumGet(monitorInfo, 36, "Int") & 1

    SysGet, monitorCount, MonitorCount

    Loop, %monitorCount% {
      SysGet, tempMon, Monitor, %A_Index%

      ; Compare location to determine the monitor index.
      if ((monitorLeft = tempMonLeft) and (monitorTop = tempMonTop)
        and (monitorRight = tempMonRight) and (monitorBottom = tempMonBottom)) {
        monitorIndex := A_Index
        break
      }
    }
  }

  return %monitorIndex%
}