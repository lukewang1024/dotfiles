; Native action/data adapter. Rust owns every menu window and parent stack.
hyperJson(value)
{
  text := StrReplace(value, "\", "\\")
  text := StrReplace(text, Chr(34), "\" . Chr(34))
  text := StrReplace(text, "`r", "\r")
  text := StrReplace(text, "`n", "\n")
  text := StrReplace(text, "`t", "\t")
  return Chr(34) . text . Chr(34)
}

hyperRustCommand(command)
{
  global hyperRustPending
  pending := hyperRustPending
  path := pending.dir . "\command-" . pending.command . ".json"
  file := FileOpen(path . ".tmp", "w", "UTF-8-RAW")
  file.Write(command), file.Close()
  FileMove, % path . ".tmp", %path%, 1
  pending.command += 1
}

hyperRustShow(rows, title, quick := false, continuous := false)
{
  global hyperRustPending, hyperRustTimer, hyperTarget, hyperData
  push := IsObject(hyperRustPending)
  if !push
  {
    EnvGet, dataDir, XDG_STATE_HOME
    if (dataDir="")
      EnvGet, dataDir, LOCALAPPDATA
    rid := DllCall("GetCurrentProcessId") . "-" . A_TickCount
    dir := dataDir . "\hyper-palette\requests\" . rid
    FileCreateDir, %dir%
    if !hyperTarget
      hyperTarget := WinExist("A")
    hyperRustPending := {dir:dir,rid:rid,command:0,event:0,page:0,items:{},target:hyperTarget,started:A_TickCount}
  }
  pending := hyperRustPending
  pending.page += 1
  page := "page-" . pending.page
  items := ""
  for index, row in rows
  {
    id := page . "-" . index
    pending.items[id] := row[3]
    navigate := RegExMatch(row[3], "^(menu|role|mode)\.") ? true : false
    label := row[2]
    if (hyperData.i18n.en.HasKey(row[3]) && SubStr(row[3],1,5)!="role.")
      label := hyperText(row[3])
    items .= (index=1 ? "" : ",") . "{""id"":" . hyperJson(id) . ",""title"":" . hyperJson(label)
      . ",""shortcut"":" . hyperJson(row[1]) . ",""keywords"":" . hyperJson(hyperKeywords(row[3]))
      . ",""navigate"":" . (navigate ? "true" : "false") . ",""keep_open"":" . ((navigate || continuous) ? "true" : "false") . "}"
  }
  title := hyperText((continuous ? "mode." : "menu.") . title)
  request := "{""request_id"":" . hyperJson(pending.rid) . ",""root"":" . hyperJson(page)
    . ",""menus"":{" . hyperJson(page) . ":{""title"":" . hyperJson(title) . ",""quick"":" . (quick ? "true" : "false") . ",""items"": [" . items . "]}}}"
  hyperRustCommand("{""type"":" . hyperJson(push ? "push" : "show") . ",""request"":" . request . "}")
  if push
    return
  command := "pythonw.exe -B """ . A_ScriptDir . "\..\hyper\palette_bridge.py"" --session-dir """ . pending.dir . """"
  Run, %command%,, Hide UseErrorLevel, pid
  if (ErrorLevel="ERROR")
  {
    hyperRustPending := ""
    MsgBox, 48, Hyper Palette, Hyper Palette bridge failed to start.
    return
  }
  pending.pid := pid
  hyperRustTimer := Func("hyperRustPoll")
  SetTimer, % hyperRustTimer, 30
}

hyperRustPoll()
{
  global hyperRustPending, hyperRustTimer, hyperTarget
  pending := hyperRustPending
  if !IsObject(pending)
    return
  path := pending.dir . "\event-" . pending.event . ".txt"
  if !FileExist(path)
  {
    Process, Exist, % pending.pid
    if (ErrorLevel || A_TickCount-pending.started<1000)
      return
    text := "error"
  }
  else
  {
    FileRead, text, % "*P65001 " . path
    FileDelete, %path%
    pending.event += 1
  }
  parts := StrSplit(text,"`n","`r")
  if (parts[1]="shown")
    return
  keep := parts[3]="1"
  action := parts[1]="action" && pending.items.HasKey(parts[2]) ? pending.items[parts[2]] : ""
  if !keep
  {
    SetTimer, % hyperRustTimer, Off
    hyperRustPending := ""
    ; Only remove the now-empty, uniquely owned session directory.
    FileRemoveDir, % pending.dir
    if (action!="" || parts[2]="escape")
      WinActivate, % "ahk_id " . pending.target
  }
  if (parts[1]="error")
    MsgBox, 48, Hyper Palette, Hyper Palette failed. Check hyper-palette host.log.
  if (action!="")
  {
    hyperTarget := pending.target
    hyperRun(action)
  }
  if !IsObject(hyperRustPending)
    hyperTarget := 0
}
