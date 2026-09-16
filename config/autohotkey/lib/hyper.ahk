#Include hyper-generated.ahk

#Include hyper-palette.ahk

hyperInit()
{
  global hyperData, hyperBindings, hyperTarget, hyperHistory, hyperMax, hyperGroups, hyperAppTimer, hyperMinimized, hyperConfigFile
  hyperData := hyperConfig()
  hyperBindings := {}, hyperHistory := {}, hyperMax := {}, hyperGroups := {}
  hyperMinimized := []
  for _, binding in hyperData.bindings
    hyperBindings[(binding.shift ? "+" : "") . hyperKey(binding.key)] := binding.action
  EnvGet, configDir, XDG_CONFIG_HOME
  if (configDir = "")
    configDir := A_AppData
  configFile := configDir . "\hyper\local.ini"
  hyperConfigFile := configFile
  for role, spec in hyperData.roles
  {
    IniRead, choice, %configFile%, defaults, %role%, %A_Space%
    if (choice="" && role="workChat")
      IniRead, choice, %configFile%, defaults, chat, %A_Space%
    if hyperRoleValid(choice)
      hyperData.defaults.windows[role] := choice
  }
  for name, app in hyperData.apps
  {
    if !app.HasKey("windows")
      continue
    IniRead, launch, %configFile%, launch, %name%, %A_Space%
    if (launch != "")
      app.windows.launch := launch
  }
  hyperAppTimer := Func("hyperRefreshApps")
  SetTimer, % hyperAppTimer, -250
}

hyperKey(key)
{
  static keys := {"return":"Enter", "delete":"Backspace", "escape":"Esc", "pageup":"PgUp", "pagedown":"PgDn", ";":"SC027", "``":"SC029", "pad7":"Numpad7", "pad9":"Numpad9", "pad1":"Numpad1", "pad3":"Numpad3"}
  return keys.HasKey(key) ? keys[key] : key
}

hyperDispatch()
{
  global hyperBindings, capslockFuncTriggered, hyperRustPending
  capslockFuncTriggered := true
  key := A_ThisHotkey
  if !hyperBindings.HasKey(key)
    return
  action := hyperBindings[key]
  if (IsObject(hyperRustPending) && RegExMatch(action,"^(edit|select)\."))
  {
    hyperRustCommand("{""type"":""navigate"",""request_id"":" . hyperJson(hyperRustPending.rid) . ",""action"":" . hyperJson(action) . "}")
    return
  }
  if !RegExMatch(action, "^(edit|select|mouse)\.")
  {
    KeyWait, % LTrim(key, "+")
    ; Geometry-only cycles/resizing can run while the Hyper layer stays held.
    ; This allows successive arrow taps without releasing Caps Lock each time.
    if !RegExMatch(action, "^(window\.cycle|resize\.)")
    {
      KeyWait, CapsLock
      KeyWait, F18
      KeyWait, Shift
    }
  }
  hyperRun(action)
}

hyperText(key, name := "", language := "")
{
  global hyperData
  if (language="")
    language := (DllCall("GetUserDefaultUILanguage", "UShort") & 0x3ff)=4 ? "zh" : "en"
  labels := hyperData.i18n[language]
  text := labels.HasKey(key) ? labels[key] : key
  return StrReplace(text,"{name}",name)
}

hyperKeywords(action)
{
  return action . " " . hyperText(action,"","en") . " " . hyperText(action,"","zh")
}

hyperNotice(text)
{
  text := hyperText(text)
  TrayTip, Hyper, %text%, 3
}

hyperLaunch(command, report := true)
{
  VarSetCapacity(expanded, 32768 * 2)
  DllCall("ExpandEnvironmentStrings", "str", command, "str", expanded, "uint", 32768)
  Run, %expanded%,, UseErrorLevel
  failed := ErrorLevel
  if (failed && report)
    hyperNotice(hyperText("error.launch",command))
  return !failed
}

hyperToggle(name)
{
  global hyperData, hyperGroups, hyperTarget
  app := hyperData.apps[name]
  if !app.HasKey("windows")
  {
    hyperNotice(hyperText("error.unavailable",name))
    return
  }
  spec := app.windows
  ; Web-only entries have no application window identity; never hide the browser.
  if !spec.HasKey("exe")
  {
    hyperLaunch(spec.launch)
    return
  }
  query := "ahk_exe " . spec.exe
  if spec.HasKey("class")
    query .= " ahk_class " . spec.class
  WinGet, wins, List, %query%
  if (wins = 0)
  {
    if hyperLaunch(spec.launch, false)
      return
    ; GUI applications often have a Start Menu link but no PATH entry.
    for _, folder in [A_Programs, A_ProgramsCommon]
    {
      Loop, Files, % folder . "\*.lnk", R
      {
        FileGetShortcut, %A_LoopFileFullPath%, target
        SplitPath, target, filename
        if (filename=spec.exe && hyperLaunch(A_LoopFileFullPath, false))
          return
      }
    }
    hyperNotice(hyperText("error.launch",app.title))
    return
  }
  active := hyperTarget ? hyperTarget : WinExist("A")
  belongs := false
  Loop, %wins%
    if (wins%A_Index% = active)
      belongs := true
  if belongs
  {
    saved := {active:active, windows:[]}
    Loop, %wins%
    {
      id := wins%A_Index%
      WinGet, state, MinMax, ahk_id %id%
      if (state = -1 || !isValidWindow("ahk_id " . id))
        continue
      WinGet, pid, PID, ahk_id %id%
      saved.windows.Push({id:id, pid:pid, state:state})
      WinMinimize, ahk_id %id%
    }
    hyperGroups[name] := saved
  }
  else if hyperGroups.HasKey(name)
  {
    saved := hyperGroups.Delete(name)
    for _, item in saved.windows
    {
      id := item.id
      WinGet, pid, PID, ahk_id %id%
      if (pid != item.pid)
        continue
      WinRestore, ahk_id %id%
      if (item.state = 1)
        WinMaximize, ahk_id %id%
    }
    id := WinExist("ahk_id " . saved.active) ? saved.active : wins1
    WinActivate, ahk_id %id%
  }
  else
  {
    id := wins1
    WinRestore, ahk_id %id%
    WinActivate, ahk_id %id%
  }
}

hyperRebase(rect, source, dest)
{
  mapped := rect.Clone()
  mapped.x := dest.x+(rect.x-source.x)/source.w*dest.w
  mapped.y := dest.y+(rect.y-source.y)/source.h*dest.h
  mapped.w := rect.w/source.w*dest.w
  mapped.h := rect.h/source.h*dest.h
  return mapped
}

hyperSnapshot(id)
{
  WinGetPos, x, y, w, h, ahk_id %id%
  WinGet, state, MinMax, ahk_id %id%
  WinGet, pid, PID, ahk_id %id%
  return {x:x,y:y,w:w,h:h,state:state,pid:pid}
}

hyperMove(id, rect)
{
  WinRestore, ahk_id %id%
  WinMove, ahk_id %id%,, % rect.x, % rect.y, % rect.w, % rect.h
}

hyperRestore(id, rect)
{
  WinGet, pid, PID, ahk_id %id%
  if (rect.pid != pid)
    return
  hyperMove(id, rect)
  if (rect.state = 1)
    WinMaximize, ahk_id %id%
}

hyperArea(index)
{
  SysGet, area, MonitorWorkArea, %index%
  return {x:areaLeft,y:areaTop,w:areaRight-areaLeft,h:areaBottom-areaTop}
}

hyperDirectional(areas, origin, direction)
{
  best := 0, score := ""
  for id, rect in areas
  {
    dx := rect.x + rect.w/2 - origin.x - origin.w/2
    dy := rect.y + rect.h/2 - origin.y - origin.h/2
    valid := (direction="left" && dx<0 && -dx>=Abs(dy)) || (direction="right" && dx>0 && dx>=Abs(dy)) || (direction="up" && dy<0 && -dy>=Abs(dx)) || (direction="down" && dy>0 && dy>=Abs(dx))
    distance := dx*dx + dy*dy
    if (valid && (score="" || distance<score))
      best := id, score := distance
  }
  return best
}

hyperScreenTarget(screens, current, direction)
{
  if (screens.Count()<2)
    return 0
  origin := screens[current]
  opposite := {left:"right",right:"left",up:"down",down:"up"}
  other := {left:"up",right:"down",up:"left",down:"right"}
  for _, dir in [direction,other[direction]]
  {
    result := hyperDirectional(screens,origin,dir)
    if result
      return result
    best := 0, score := -1, secondary := 0
    reverse := opposite[dir]
    for index, rect in screens
    {
      if (index=current)
        continue
      dx := rect.x+rect.w/2-origin.x-origin.w/2
      dy := rect.y+rect.h/2-origin.y-origin.h/2
      horizontal := (dir="left" || dir="right")
      primary := horizontal ? Abs(dx) : Abs(dy)
      perpendicular := horizontal ? Abs(dy) : Abs(dx)
      valid := (reverse="left" && dx<0) || (reverse="right" && dx>0) || (reverse="up" && dy<0) || (reverse="down" && dy>0)
      if (valid && primary>=perpendicular && (primary>score || (primary=score && perpendicular<secondary)))
        best := index, score := primary, secondary := perpendicular
    }
    if best
      return best
  }
  for index, rect in screens
    if (index!=current)
      return index
}

hyperRefreshApps()
{
  global hyperInstalledApps, hyperAppsUpdated
  rows := []
  try
  {
    folder := ComObjCreate("Shell.Application").NameSpace("shell:AppsFolder")
    for item in folder.Items
      rows.Push(["",item.Name,"installed." . item.Path])
    hyperInstalledApps := rows
    hyperAppsUpdated := A_TickCount
  }
  catch error
    return
}

hyperRoleDefault(role)
{
  ; The generated table remains the factory default, unaffected by local edits.
  defaults := hyperConfig()
  return defaults.defaults.windows.HasKey(role) ? defaults.defaults.windows[role] : defaults.roles[role].apps[1]
}

hyperRoleApp(role)
{
  global hyperData
  return hyperData.defaults.windows.HasKey(role) ? hyperData.defaults.windows[role] : hyperData.roles[role].apps[1]
}

hyperRoleValid(choice)
{
  global hyperData
  return (hyperData.apps.HasKey(choice) && hyperData.apps[choice].HasKey("windows")) || (SubStr(choice,1,10)="installed." && StrLen(choice)>10)
}

hyperRoleTitle(choice)
{
  global hyperData, hyperInstalledApps
  if hyperData.apps.HasKey(choice)
    return hyperData.apps[choice].title
  for _, row in hyperInstalledApps
    if (row[3]=choice)
      return row[2]
  return SubStr(choice,1,10)="installed." ? SubStr(choice,11) : choice
}

hyperRoleKeys(role)
{
  global hyperData
  result := ""
  for _, b in hyperData.bindings
    if (b.action="app." . role)
      result .= (result="" ? "" : " / ") . "H+" . (b.shift ? "Shift+" : "") . b.key
  return result
}

hyperRoleChoices(role)
{
  global hyperData, hyperInstalledApps, hyperAppsUpdated
  rows := [["",hyperText("ui.roleReset") . " · " . hyperRoleTitle(hyperRoleDefault(role)),"resetrole." . role]]
  seen := {}
  for _, name in hyperData.roles[role].apps
    if hyperData.apps[name].HasKey("windows")
    {
      rows.Push([name=hyperRoleApp(role) ? "✓" : "",hyperData.apps[name].title,"setrole." . role . "." . name])
      seen[name] := true
    }
  for name, app in hyperData.apps
    if (app.HasKey("windows") && !seen.HasKey(name))
      rows.Push([name=hyperRoleApp(role) ? "✓" : "",app.title,"setrole." . role . "." . name])
  if (!IsObject(hyperInstalledApps) || A_TickCount-hyperAppsUpdated>600000)
    hyperRefreshApps()
  for _, row in hyperInstalledApps
    rows.Push(["",row[2] . " · " . hyperText("ui.launchOnly"),"setrole." . role . "." . row[3]])
  return rows
}

hyperSetRole(role, choice)
{
  global hyperData, hyperConfigFile
  if (!hyperData.roles.HasKey(role) || !hyperRoleValid(choice))
  {
    hyperNotice(hyperText("error.role",role))
    return
  }
  SplitPath, hyperConfigFile,, configDir
  FileCreateDir, %configDir%
  IniWrite, %choice%, %hyperConfigFile%, defaults, %role%
  if ErrorLevel
  {
    hyperNotice("error.roleSave")
    return
  }
  hyperData.defaults.windows[role] := choice
  hyperNotice(hyperText("ui.roleSaved",hyperText("role." . role) . " → " . hyperRoleTitle(choice)))
}

hyperRows(group)
{
  global hyperData, hyperBindings, hyperInstalledApps, hyperAppsUpdated
  rows := []
  if hyperData.menus.HasKey(group)
    return hyperData.menus[group]
  if (group="roles")
  {
    for role, spec in hyperData.roles
      rows.Push([hyperRoleKeys(role),hyperText("role." . role) . " · " . hyperText("ui.roleCurrent",hyperRoleTitle(hyperRoleApp(role))),"role." . role])
  }
  else if (group = "windows")
  {
    WinGet, wins, List
    Loop, %wins%
    {
      id := wins%A_Index%
      if !isValidWindow("ahk_id " . id)
        continue
      WinGetTitle, title, ahk_id %id%
      rows.Push(["", title, "winid." . id])
    }
  }
  else if (group="apps")
  {
    if (!IsObject(hyperInstalledApps) || A_TickCount-hyperAppsUpdated>600000)
      hyperRefreshApps()
    for _, row in hyperInstalledApps
      rows.Push(row)
  }
  else
  {
    for key, action in hyperBindings
      if (action!="menu.all" && action!="menu.help")
        rows.Push([key, action, action])
    if (group="all")
    {
      if (!IsObject(hyperInstalledApps) || A_TickCount-hyperAppsUpdated>600000)
        hyperRefreshApps()
      for _, row in hyperInstalledApps
        rows.Push(row)
    }
  }
  return rows
}

hyperMenu(rows, title, quick := false, continuous := false)
{
  hyperRustShow(rows,title,quick,continuous)
}

hyperPortrait(id)
{
  area := hyperArea(getMonitorIndexFromWindow(id))
  return area.h>area.w
}

hyperLayout(name, area)
{
  global hyperData
  r := hyperData.layouts[name]
  return (area.h>area.w && hyperData.adaptiveLayouts.HasKey(name)) ? [r[2],r[1],r[4],r[3]] : r
}

hyperCycleLayout(name, frame, area)
{
  global hyperData
  cycle := hyperData.layoutCycles[name]
  for i, layout in cycle
  {
    r := hyperLayout(layout,area)
    if (Abs(frame.x-(area.x+area.w*r[1]))<3 && Abs(frame.y-(area.y+area.h*r[2]))<3
        && Abs(frame.w-area.w*r[3])<3 && Abs(frame.h-area.h*r[4])<3)
      return cycle[Mod(i,cycle.Length())+1]
  }
  return cycle[1]
}

hyperRun(action)
{
  global hyperData, hyperTarget, hyperHistory, hyperMax, hyperMinimized
  dot := InStr(action,"."), kind := SubStr(action,1,dot-1), arg := SubStr(action,dot+1)
  id := hyperTarget ? hyperTarget : WinExist("A")
  if (kind="window" && arg="up")
  {
    while hyperMinimized.Length()
    {
      saved := hyperMinimized.Pop()
      target := saved.id
      WinGet, pid, PID, ahk_id %target%
      WinGet, state, MinMax, ahk_id %target%
      if (pid=saved.pid && state=-1)
      {
        WinRestore, ahk_id %target%
        WinActivate, ahk_id %target%
        return
      }
    }
  }
  if (kind="app")
  {
    name := hyperRoleApp(arg)
    if (SubStr(name,1,10)="installed.")
      hyperRun(name)
    else
      hyperToggle(name)
  }
  else if (kind="role")
  {
    if hyperData.roles.HasKey(arg)
      hyperMenu(hyperRoleChoices(arg),"roleApps")
  }
  else if (kind="setrole")
  {
    split := InStr(arg,".")
    hyperSetRole(SubStr(arg,1,split-1),SubStr(arg,split+1))
  }
  else if (kind="resetrole")
  {
    if hyperData.roles.HasKey(arg)
      hyperSetRole(arg,hyperRoleDefault(arg))
  }
  else if (kind="launch")
    hyperToggle(arg)
  else if (kind="installed")
    ComObjCreate("Shell.Application").ShellExecute("shell:AppsFolder\" . arg)
  else if (kind="menu")
  {
    hyperMenu(hyperRows(arg),arg,hyperData.menus.HasKey(arg))
  }
  else if (kind="edit" || kind="select")
  {
    keys := {left:"Left",right:"Right",up:"Up",down:"Down",home:"Home",end:"End",pageup:"PgUp",pagedown:"PgDn"}
    SendInput, % (kind="select" ? "+" : "") . "{" . keys[arg] . "}"
  }
  else if (kind="winid")
    WinActivate, ahk_id %arg%
  else if (kind="desktop")
    hyperNotice("error.windowsDesktop")
  else if (kind="window" && arg="previous")
    SendInput, !{Tab}
  else if (kind="window" && (arg="left" || arg="right" || arg="up" || arg="down" || arg="maximize" || arg="restoreDown")
      && !((arg="left" || arg="right") && hyperPortrait(id)))
  {
    if !isValidWindow("ahk_id " . id)
      return
    before := hyperSnapshot(id)
    if ((arg="up" || arg="maximize") && before.state!=1)
      hyperMax[id] := before
    else if (arg!="maximize" && arg!="up")
      hyperMax.Delete(id)
    if !(arg="maximize" && before.state=1)
      hyperHistory[id] := before
    direction := arg="maximize" ? "Up" : arg="restoreDown" ? "Down" : arg
    SendInput, % "#{" . direction . "}"
    if (arg="down" || arg="restoreDown")
    {
      Sleep, 30
      WinGet, state, MinMax, ahk_id %id%
      if (state=-1)
        hyperMinimized.Push({id:id,pid:before.pid})
    }
  }
  else if (kind="window" || kind="screen" || kind="resize")
  {
    if !isValidWindow("ahk_id " . id)
      return
    before := hyperSnapshot(id)
    if (arg="undo")
    {
      if hyperHistory.HasKey(id)
        hyperRestore(id,hyperHistory.Delete(id))
      hyperMax.Delete(id)
      return
    }
    if ((kind!="resize" && kind!="screen") || !hyperHistory.HasKey(id))
      hyperHistory[id] := before
    area := hyperArea(getMonitorIndexFromWindow(id))
    if (kind="window" && hyperData.layoutCycles.HasKey(arg))
      arg := hyperCycleLayout(arg,before,area)
    if (kind="screen")
    {
      SysGet, count, MonitorCount
      screens := {}
      Loop, %count%
        screens[A_Index] := hyperArea(A_Index)
      target := hyperScreenTarget(screens,getMonitorIndexFromWindow(id),arg)
      if !target
      {
        hyperNotice("Only one screen detected")
        return
      }
      dest := screens[target]
      hyperHistory[id] := hyperRebase(hyperHistory[id],area,dest)
      if hyperMax.HasKey(id)
        hyperMax[id] := hyperRebase(hyperMax[id],area,dest)
      if (before.state=1)
      {
        ; Move the normal placement, then maximize on the destination monitor.
        if hyperMax.HasKey(id)
          hyperMove(id,hyperMax[id])
        else
        {
          WinRestore, ahk_id %id%
          normal := hyperSnapshot(id)
          hyperMove(id,hyperRebase(normal,area,dest))
        }
        WinMaximize, ahk_id %id%
      }
      else
        hyperMove(id,{x:dest.x+(before.x-area.x)/area.w*dest.w,y:dest.y+(before.y-area.y)/area.h*dest.h,w:before.w/area.w*dest.w,h:before.h/area.h*dest.h})
    }
    else if (kind="resize")
    {
      step := InStr(arg,"fast-") ? 50 : 10
      if InStr(arg,"left")
        before.w := Max(100,before.w-step)
      else if InStr(arg,"right")
        before.w += step
      else if InStr(arg,"up")
        before.h := Max(100,before.h-step)
      else
        before.h += step
      hyperMove(id,before)
    }
    else if (arg="max")
    {
      if hyperMax.HasKey(id)
        hyperRestore(id,hyperMax.Delete(id))
      else
      {
        hyperMax[id] := before
        WinMaximize, ahk_id %id%
      }
    }
    else if (arg="center")
      hyperMove(id,{x:area.x+(area.w-before.w)/2,y:area.y+(area.h-before.h)/2,w:before.w,h:before.h})
    else if (arg="fullscreen")
      hyperNotice("error.windowsFullscreen")
    else if hyperData.layouts.HasKey(arg)
    {
      r := hyperLayout(arg,area)
      hyperMax.Delete(id)
      hyperMove(id,{x:area.x+area.w*r[1],y:area.y+area.h*r[2],w:area.w*r[3],h:area.h*r[4]})
    }
  }
  else if (kind="focus")
  {
    areas := {}
    WinGet, wins, List
    Loop, %wins%
    {
      other := wins%A_Index%
      WinGet, state, MinMax, ahk_id %other%
      if (other!=id && state!=-1 && isValidWindow("ahk_id " . other))
        areas[other] := hyperSnapshot(other)
    }
    other := hyperDirectional(areas,hyperSnapshot(id),arg)
    if other
      WinActivate, ahk_id %other%
  }
  else if (kind="mode")
  {
    if (arg="resize")
      hyperHistory[id] := hyperSnapshot(id)
    rows := []
    for key, direction in {h:"left",j:"down",k:"up",l:"right"}
    {
      rows.Push([key,direction,arg . "." . direction])
      rows.Push(["S-" . key,"Fast " . direction,arg . ".fast-" . direction])
    }
    if (arg="mouse")
      for _, row in [["return","Click","mouse.click"],["delete","Right click","mouse.rightclick"],["u","Scroll up","mouse.scrollup"],["o","Scroll down","mouse.scrolldown"]]
        rows.Push(row)
    hyperMenu(rows,arg,true,true)
  }
  else if (kind="mouse")
  {
    step := InStr(arg,"fast-") ? 40 : 10
    if (arg="click")
      Click
    else if (arg="rightclick")
      Click, Right
    else if (arg="scrollup")
      Click, WheelUp
    else if (arg="scrolldown")
      Click, WheelDown
    else if InStr(arg,"left")
      MouseMove, % -step, 0, 0, R
    else if InStr(arg,"right")
      MouseMove, %step%, 0, 0, R
    else if InStr(arg,"up")
      MouseMove, 0, % -step, 0, R
    else
      MouseMove, 0, %step%, 0, R
  }
  else if (kind="capture")
  {
    if (arg="screenshot")
      SendInput, #+s
    else
      hyperLaunch("snippingtool.exe")
  }
  else if (kind="clipboard")
  {
    if (arg="history")
      SendInput, #v
    else
      hyperNotice("error.windowsClipboard")
  }
  else if (kind="system")
  {
    if (arg="lock")
      DllCall("LockWorkStation")
    else if (arg="settings")
      hyperLaunch("ms-settings:")
    else if (arg="audioOutput")
      hyperLaunch("ms-settings:sound")
    else if (arg="audioInput")
      hyperLaunch("ms-settings:sound-defaultinputproperties")
    else if (arg="displays")
      hyperLaunch("ms-settings:display")
    else if (arg="focus")
      hyperLaunch("ms-settings:quiethours")
    else if (arg="hyperKeys")
    {
      SplitPath, A_LineFile,, libDir
      hyperLaunch("notepad.exe " . Chr(34) . libDir . "\..\..\hyper\keys.json" . Chr(34))
    }
    else if (arg="activity")
      hyperLaunch("taskmgr.exe")
    else if (arg="reload")
      Reload
    else if (arg="taskview")
      SendInput, #{Tab}
    else if (arg="launcher")
      SendInput, #s
    else if (arg="power")
      showCustomShutdownMenu()
  }
  else if (kind="remote")
  {
    if (arg="escape")
    {
      WinGet, exe, ProcessName, ahk_id %id%
      if (exe="nxplayer.exe" || exe="mstsc.exe" || exe="vncviewer.exe")
        WinMinimize, ahk_id %id%
    }
    else
      hyperNotice("info.windowsHyper")
  }
}
