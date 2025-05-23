#NoEnv
#NoTrayIcon
#SingleInstance force

; Use Win+j to toggle the routine
;
; UP, Ctrl+P Alt+p, Shift+Tab, Alt+Shift+Tab to select previous item
; Down, Ctrl+n, Alt+n. Tab, Alt+Tab to select next item
;
; Ctrl+u will clear all search string in textfield
; Ctrl+h or backspace will delete a char
; Ctrl+backspace or Alt+Backspace will delete last keyword in textfield
; enter or Ctrl+j for select
; escape or Ctrl+g for cancel
;
; Ctrl+alt+k to force kill the selected window
; Alt+k      to kill the selected window and quit
; Ctrl+k     to kill the selected window and keep switcher going, so that you
;            can select other window or kill other window
;
; Ctrl+s     to toggle the status of window:minimize, maximize and restore
;            you can press Ctrl+s several times

;----------------------------------------------------------------------
;
; User configuration
;

; Window titles containing any of the listed substrings are filtered out from
; the initial list of windows presented when iswitchw is activated. Can be
; useful for things like  hiding improperly configured tool windows or screen
; capture software during demos.
filters := []

; Set this to true to update the list of windows every time the search is
; updated. This is usually not necessary and creates additional overhead, so
; it is disabled by default.
refreshEveryKeystroke := false

; Only re-filter the possible window matches this often (in ms) at maximum.
; When typing is rapid, no sense in running the search on every keypress.
debounceDuration = 250

; When true, filtered matches are scored and the best matches are presented
; first. This helps account for simple spelling mistakes such as transposed
; letters e.g. googel, vritualbox. When false, title matches are filtered and
; presented in the order given by Windows.
scoreMatches := true

; Split search string on spaces and use each term as an additional
; filter expression.
;
; For example, you are working on an AHK script:
;  - There are two Explorer windows open to ~/scripts and ~/scripts-old.
;  - Two Vim instances editing scripts in each one of those folders.
;  - A browser window open that mentions scripts in the title
;
; This is amongst all the other stuff going on. You bring up iswitchw and
; begin typing 'scrip'. Now, we have several best matches filtered.  But I
; want the Vim windows only. Now I might be able to make a more unique match by
; adding the extension of the file open in Vim: 'scripahk'. Pretty good, but
; really the first thought was process name -- Vim. By breaking on space, we
; can first filter the list for matches on 'scrip' for 'script' and then,
; 'vim' in order to match by Vim amongst the remaining windows.
useMultipleTerms := true

;----------------------------------------------------------------------
;
; Global variables
;
;     allwindows  - windows on desktop
;     windows     - windows in listbox
;     search      - the current search string
;     lastSearch  - previous search string
;     switcher_id - the window ID of the switcher window
;     debounced   - true when its ok to re-filter
;
;----------------------------------------------------------------------

SendMode Input
SetWorkingDir %A_ScriptDir%

AutoTrim, off

Gui, +LastFound +AlwaysOnTop -Caption +ToolWindow
Gui, Color, black,black
WinSet, Transparent, 225
Gui, Font, s16 cEEE8D5 bold, Consolas
Gui, Margin, 4, 4
Gui, Add, Text,     w100 h30 x6 y8, Search`:
Gui, Add, Edit,     w500 h30 x110 y4 gSearchChange vsearch,
Gui, Add, ListView, w854 h510 x4 y40 -VScroll -HScroll -Hdr -Multi Count10 AltSubmit gListViewClick, index|title|proc

;----------------------------------------------------------------------
;
; Win+j to activate.
;
#j::
Gosub, LAUNCH_SWITCHER
return

LAUNCH_SWITCHER:

search =
lastSearch =
debounced := true
allwindows := Object()

GuiControl, , Edit1
Gui, Show, Center, Window Switcher
WinGet, switcher_id, ID, A
WinSet, AlwaysOnTop, On, ahk_id %switcher_id%
ControlFocus, Edit1, ahk_id %switcher_id%

Loop
{
  Input, input, L1, {enter}{esc}{tab}{backspace}{delete}{up}{down}{left}{right}{home}{end}{F4}{LControl}npgukjhf{LAlt}{LWin}{Capslock}

  ; Enter to select
  if ErrorLevel = EndKey:enter
  {
    ActivateWindow()
    break
  }
  ; LControl+j to select
  ; LAlt+j for down
  else if ErrorLevel = EndKey:j
  {
    if (GetKeyState("LControl", "P") = 1) {
      ActivateWindow()
      break
    } else if (GetKeyState("LAlt", "P") = 1) {
      SelectNext(switcher_id)
      continue
    } else {
      input = j
    }
  }
  ; Esc to dismiss
  else if ErrorLevel = EndKey:escape
  {
    Gui Cancel
    break
  }
  ; Win+f to dismiss
  else if ErrorLevel = EndKey:f
  {
    if (GetKeyState("LWin", "P") = 1) {
      Gui Cancel
      break
    } else {
      input = f
    }
  }
  ; Alt+Capslock to dismiss
  else if ErrorLevel = EndKey:Capslock
  {
    if (GetKeyState("LAlt", "P") = 1) {
      Gui Cancel
      break
    }
    continue
  }
  ; Ctrl+g to dismiss too
  else if ErrorLevel = EndKey:g
  {
    if (GetKeyState("LControl", "P")=1) {
      Gui Cancel
      break
    } else {
      input=g
    }
  }
  else if ErrorLevel = EndKey:LControl
  {
    continue
  }
  else if ErrorLevel = EndKey:LAlt
  {
    continue
  }
  else if ErrorLevel = EndKey:LWin
  {
    continue
  }
  ; (Shift+)Tab for cycling (backward) through list items
  else if ErrorLevel = EndKey:tab
  {
    if (GetKeyState("LShift", "P") = 1) {
      SelectPrevious(switcher_id)
    } else {
      SelectNext(switcher_id)
    }
    continue
  }
  ; LControl/LAlt+Backspace for deleting word backward
  else if ErrorLevel = EndKey:backspace
  {
    DeleteSearchText(switcher_id, 1)
    continue
  }
  ; Ctrl+h for backspace
  else if ErrorLevel = EndKey:h
  {
    if (GetKeyState("LControl", "P") = 1) {
      DeleteSearchText(switcher_id)
      continue
    } else {
      input = h
    }
  }
  else if ErrorLevel = EndKey:delete
  {
    ControlFocus, Edit1, ahk_id %switcher_id%
    keys := AddModifierKeys("{del}")
    ControlSend, Edit1, %keys%, ahk_id %switcher_id%
    continue
  }
  else if ErrorLevel = EndKey:up
  {
    SelectPrevious(switcher_id)
    continue
  }
  else if ErrorLevel = EndKey:down
  {
    SelectNext(switcher_id)
    continue
  }
  ; LControl+p (LAlt+p) for up
  else if ErrorLevel = EndKey:p
  {
    if (GetKeyState("LControl", "P") = 1 || GetKeyState("LAlt", "P") = 1) {
      SelectPrevious(switcher_id)
      continue
    } else {
      input = p
    }
  }
  ; LControl+n (LAlt+n) for down
  else if ErrorLevel = EndKey:n
  {
    if (GetKeyState("LControl", "P") = 1 || GetKeyState("LAlt", "P") = 1) {
      SelectNext(switcher_id)
      continue
    } else {
      input = n
    }
  }
  ; LControl+u to clear the search box
  else if ErrorLevel = EndKey:u
  {
    if (GetKeyState("LControl", "P") = 1) {
      ClearSearchBox()
      continue
    } else {
      input = u
    }
  }
  ; Alt+k for up
  else if ErrorLevel = EndKey:k
  {
    if (GetKeyState("LAlt", "P") = 1) {
      SelectPrevious(switcher_id)
      continue
    } else {
      input = k
    }
  }
  else if ErrorLevel = EndKey:left
  {
    ControlFocus, Edit1, ahk_id %switcher_id%
    keys := AddModifierKeys("{left}")
    ControlSend, Edit1, %keys%, ahk_id %switcherj_id%
    continue
  }
  else if ErrorLevel = EndKey:right
  {
    ControlFocus, Edit1, ahk_id %switcher_id%
    keys := AddModifierKeys("{right}")
    ControlSend, Edit1, %keys%, ahk_id %switcher_id%
    continue
  }
  else if ErrorLevel = EndKey:home
  {
    send % AddModifierKeys("{home}")
    continue
  }
  else if ErrorLevel = EndKey:end
  {
    send % AddModifierKeys("{end}")
    continue
  }
  else if ErrorLevel = EndKey:F4
  {
    if GetKeyState("Alt","P")
      ExitApp
  }

  ControlFocus, Edit1, ahk_id %switcher_id%
  Control, EditPaste, %input%, Edit1, ahk_id %switcher_id%
}

exit

;----------------------------------------------------------------------
;
; Runs whenever Edit control is updated
SearchChange:
  global debounced, debounceDuration
  if (!debounced) {
    return
  }
  debounced := false
  SetTimer, Debounce, -%debounceDuration%

  Gui, Submit, NoHide
  RefreshWindowList()
  return

;----------------------------------------------------------------------
;
; Clear debounce check
Debounce:
  global debounced := true

  Gui, Submit, NoHide
  RefreshWindowList()
  return

;----------------------------------------------------------------------
;
; Handle mouse click events on the listview
;
ListViewClick:
  if (A_GuiControlEvent = "Normal") {
    SendEvent {enter}
  }
  return

;----------------------------------------------------------------------
;
; Checks if user is holding Ctrl and/or Shift, then adds the
; appropriate modifiers to the key parameter before returning the
; result.
;
AddModifierKeys(key)
{
  if GetKeyState("Ctrl","P")
    key := "^" . key

  if GetKeyState("Shift","P")
    key := "+" . key

  return key
}

;----------------------------------------------------------------------
;
; Delete the search text backward.
;
; canDeleteWord [Optional]: set to 1 to check for Ctrl / Alt
;                           key status for word delete.
;
DeleteSearchText(switcher_id, canDeleteWord = 0)
{
  ControlFocus, Edit1, ahk_id %switcher_id%

  if (canDeleteWord = 1 && (GetKeyState("LControl","P") || GetKeyState("LAlt", "P"))) {
    chars = ^{Left}^{Del} ; courtesy of VxE: http://www.autohotkey.com/board/topic/35458-backward-search-delete-a-word-to-the-left/#entry223378
  } else {
    chars = {backspace}
  }

  ControlSend, Edit1, %chars%, ahk_id %switcher_id%
}

;----------------------------------------------------------------------
;
; Clear all text from the search box
;
ClearSearchBox()
{
  global search

  if search =
    return

  search =
  GuiControl, , Edit1
  RefreshWindowList()
}

;----------------------------------------------------------------------
;
; Unoptimized array search, returns index of first occurrence or -1
;
IncludedIn(haystack,needle)
{
  Loop % haystack.MaxIndex()
  {
    item := haystack[a_index]
    StringTrimRight, item, item, 0
    if item =
      continue

    IfInString, needle, %item%
      return %a_index%
  }

  return -1
}

;----------------------------------------------------------------------
;
; Fetch info on all active windows
;
GetAllWindows()
{
  global switcher_id, filters
  windows := Object()

  WinGet, id, list, , , Program Manager
  Loop, %id%
  {
    StringTrimRight, wid, id%a_index%, 0
    WinGetTitle, title, ahk_id %wid%
    StringTrimRight, title, title, 0

    ; FIXME: windows with empty titles?
    if title =
      continue

    ; don't add the switcher window
    if switcher_id = %wid%
      continue

    ; don't add titles which match any of the filters
    if IncludedIn(filters, title) > -1
      continue

    ; replace pipe (|) characters in the window title,
    ; because Gui Add uses it for separating listbox items
    StringReplace, title, title, |, -, all

    procName := GetProcessName(wid)
    windows.Insert({ "id": wid, "title": title, "procName": procName })
  }

  return windows
}

;----------------------------------------------------------------------
;
; Refresh the list of windows according to the search criteria
;
RefreshWindowList()
{
  global allwindows, windows
  global search, lastSearch, refreshEveryKeystroke
  uninitialized := (allwindows.MinIndex() = "")

  if (uninitialized || refreshEveryKeystroke)
    allwindows := GetAllWindows()

  currentSearch := Trim(search)
  if ((currentSearch == lastSearch) && !uninitialized) {
    return
  }

  ; When adding to criteria (ie typing, not erasing), refilter
  ; the existing filtered list. This should be sane since the even if we enter
  ; a new letter at the beginning of the search term, all shown matches should
  ; still contain the previous search term as a 'substring'.
  useExisting := (StrLen(currentSearch) > StrLen(lastSearch))
  lastSearch := currentSearch

  windows := FilterWindowList(useExisting ? windows : allwindows, currentSearch)

  DrawListView(windows)
}

;----------------------------------------------------------------------
;
; Filter window list with given search criteria
;
FilterWindowList(list, criteria)
{
  global scoreMatches, useMultipleTerms
  filteredList := Object(), expressions := Object()
  lastTermInSearch := criteria, doScore := scoreMatches

  ; If useMultipleTerms, do multiple passes with filter expressions
  if (useMultipleTerms) {
    StringSplit, searchTerms, criteria, %A_space%

    Loop, %searchTerms0%
    {
      term := searchTerms%A_index%
      lastTermInSearch := term

      expr := BuildFilterExpression(term)
      expressions.Insert(expr)
    }
  } else if (criteria <> "") {
    expr := BuildFilterExpression(criteria)
    expressions[0] := expr
  }

  atNextWindow:
  For idx, window in list
  {
    ; if there is a search string
    if criteria <>
    {
      title := window.title
      procName := window.procName

      ; don't add the windows not matching the search string
      titleAndProcName = %procName% %title%

      For idx, expr in expressions
      {
        if RegExMatch(titleAndProcName, expr) = 0
          continue atNextWindow
      }
    }

    doScore := scoreMatches && (criteria <> "") && (lastTermInSearch <> "")
    window["score"] := doScore ? StrDiff(lastTermInSearch, titleAndProcName) : 0

    filteredList.Insert(window)
  }

  return (doScore ? SortByScore(filteredList) : filteredList)
}

;----------------------------------------------------------------------
;
; Select the next list item of the list view (able to wrap around)
;
SelectNext(switcher_id)
{
  rowNum := LV_GetNext(0)
  totalNum := LV_GetCount()
  if (rowNum < totalNum) {
    ControlFocus, SysListView321, ahk_id %switcher_id%
    ControlSend, SysListView321, {down}, ahk_id %switcher_id%
  } else {
    LV_Modify(1, "Select") ; select the first row
    LV_Modify(1, "Focus")  ; focus the first row
  }
}

;----------------------------------------------------------------------
;
; Select the previous list item of the list view (able to wrap around)
;
SelectPrevious(switcher_id)
{
  rowNum := LV_GetNext(0)
  totalNum := LV_GetCount()
  if (rowNum < 2) {
    LV_Modify(totalNum, "Select") ; select last line
    LV_Modify(totalNum, "Focus")  ; focus last line
  } else {
    ControlFocus, SysListView321, ahk_id %switcher_id%
    ControlSend, SysListView321, {up}, ahk_id %switcher_id%
  }
}

;----------------------------------------------------------------------
;
; http://stackoverflow.com/questions/2891514/algorithms-for-fuzzy-matching-strings
;
; Matching in the style of Ido/CtrlP
;
; Returns:
;   Regex for provided search term
;
; Example:
;   explr builds the regex /[^e]*e[^x]*x[^p]*p[^l]*l[^r]*r/i
;   which would match explorer
;   or likewise
;   explr ahk
;   which would match Explorer - ~/autohotkey, but not Explorer - Documents
;
; Rules:
;  It is expected that all the letters of the input be in the keyword
;  It is expected that the letters in the input be in the same order in the keyword
;  The list of keywords returned should be presented in a consistent (reproductible) order
;  The algorithm should be case insensitive
;
BuildFilterExpression(term)
{
  expr := "i)"
  Loop, parse, term
  {
    expr .= "[^" . A_LoopField . "]*" . A_LoopField
  }

  return expr
}

;------------------------------------------------------------------------
;
; Perform insertion sort on list, comparing on each item's score property
;
SortByScore(list)
{
  Loop % list.MaxIndex() - 1
  {
    i := A_Index+1
    window := list[i]
    j := i-1

    While j >= 0 and list[j].score > window.score
    {
      list[j+1] := list[j]
      j--
    }

    list[j+1] := window
  }

  return list
}

;----------------------------------------------------------------------
;
; Activate selected window
;
ActivateWindow()
{
  global windows

  Gui Submit
  rowNum:= LV_GetNext(0)
  wid := windows[rowNum].id

  ; In some cases, calling WinMinimize minimizes the window, but it retains its
  ; focus preventing WinActivate from raising window.
  IfWinActive, ahk_id %wid%
  {
    WinGet, state, MinMax, ahk_id %wid%
    if (state = -1)
    {
      WinRestore, ahk_id %wid%
    }
  } else {
    WinActivate, ahk_id %wid%
  }

  LV_Delete()
}

;----------------------------------------------------------------------
;
; Add window list to listview
;
DrawListView(windows)
{
  windowCount := windows.MaxIndex()
  imageListID := IL_Create(windowCount, 1, 1)

  ; Attach the ImageLists to the ListView so that it can later display the icons:
  LV_SetImageList(imageListID, 1)
  LV_Delete()

  iconCount = 0
  removedRows := Array()

  For idx, window in windows
  {
    wid := window.id
    title := window.title

    ; Retrieves an 8-digit hexadecimal number representing extended style of a window.
    WinGet, style, ExStyle, ahk_id %wid%

    ; http://msdn.microsoft.com/en-us/library/windows/desktop/ff700543(v=vs.85).aspx
    ; Forces a top-level window onto the taskbar when the window is visible.
    WS_EX_APPWINDOW = 0x40000
    ; A tool window does not appear in the taskbar or in the dialog that appears when the user presses ALT+TAB.
    WS_EX_TOOLWINDOW = 0x80

    isAppWindow := (style & WS_EX_APPWINDOW)
    isToolWindow := (style & WS_EX_TOOLWINDOW)

    ; http://msdn.microsoft.com/en-us/library/windows/desktop/ms632599(v=vs.85).aspx#owned_windows
    ; An application can use the GetWindow function with the GW_OWNER flag to retrieve a handle to a window's owner.
    GW_OWNER = 4
    ownerHwnd := DllCall("GetWindow", "uint", wid, "uint", GW_OWNER)

    iconNumber =

    if (isAppWindow or ( !ownerHwnd and !isToolWindow ))
    {
      ; http://www.autohotkey.com/docs/misc/SendMessageList.htm
      WM_GETICON := 0x7F

      ; http://msdn.microsoft.com/en-us/library/windows/desktop/ms632625(v=vs.85).aspx
      ICON_BIG := 1
      ICON_SMALL2 := 2
      ICON_SMALL := 0

      SendMessage, WM_GETICON, ICON_BIG, 0, , ahk_id %wid%
      iconHandle := ErrorLevel

      if (iconHandle = 0)
      {
        SendMessage, WM_GETICON, ICON_SMALL2, 0, , ahk_id %wid%
        iconHandle := ErrorLevel

        if (iconHandle = 0)
        {
          SendMessage, WM_GETICON, ICON_SMALL, 0, , ahk_id %wid%
          iconHandle := ErrorLevel

          if (iconHandle = 0)
          {
            ; http://msdn.microsoft.com/en-us/library/windows/desktop/ms633581(v=vs.85).aspx
            ; To write code that is compatible with both 32-bit and 64-bit
            ; versions of Windows, use GetClassLongPtr. When compiling for 32-bit
            ; Windows, GetClassLongPtr is defined as a call to the GetClassLong
            ; function.
            iconHandle := DllCall("GetClassLongPtr", "uint", wid, "int", -14) ; GCL_HICON is -14

            if (iconHandle = 0)
            {
              iconHandle := DllCall("GetClassLongPtr", "uint", wid, "int", -34) ; GCL_HICONSM is -34

              if (iconHandle = 0) {
                iconHandle := DllCall("LoadIcon", "uint", 0, "uint", 32512) ; IDI_APPLICATION is 32512
              }
            }
          }
        }
      }

      if (iconHandle <> 0)
        iconNumber := DllCall("ImageList_ReplaceIcon", UInt, imageListID, Int, -1, UInt, iconHandle) + 1

    } else {
      WinGetClass, Win_Class, ahk_id %wid%
      if Win_Class = #32770 ; fix for displaying control panel related windows (dialog class) that aren't on taskbar
        iconNumber := IL_Add(imageListID, "C:\WINDOWS\system32\shell32.dll", 217) ; generic control panel icon
    }

    if iconNumber > 0
    {
      iconCount+=1
      LV_Add("Icon" . iconNumber, iconCount, window.procName, title)
    } else {
      removedRows.Insert(idx)
    }
  }

  ; Don't draw rows without icons.
  windowCount-=removedRows.MaxIndex()
  For key,rowNum in removedRows
  {
    windows.Remove(rowNum)
  }

  LV_Modify(1, "Select")
  LV_Modify(1, "Focus")

  LV_ModifyCol(1,70)
  LV_ModifyCol(2,140)
  LV_ModifyCol(3,640)
}

;----------------------------------------------------------------------
;
; Get process name for given window id
;
GetProcessName(wid)
{
  WinGet, name, ProcessName, ahk_id %wid%
  StringGetPos, pos, name, .
  if ErrorLevel <> 1
  {
    StringLeft, name, name, %pos%
  }

  return name
}

/*
https://gist.github.com/grey-code/5286786
By Toralf:
Forum thread: http://www.autohotkey.com/board/topic/54987-sift3-super-fast-and-accurate-string-distance-algorithm/#entry345400
Basic idea for SIFT3 code by Siderite Zackwehdex
http://siderite.blogspot.com/2007/04/super-fast-and-accurate-string-distance.html
Took idea to normalize it to longest string from Brad Wood
http://www.bradwood.com/string_compare/
Own work:
- when character only differ in case, LSC is a 0.8 match for this character
- modified code for speed, might lead to different results compared to original code
- optimized for speed (30% faster then original SIFT3 and 13.3 times faster than basic Levenshtein distance)
*/

;----------------------------------------------------------------------
;
; returns a float: between "0.0 = identical" and "1.0 = nothing in common"
;
StrDiff(str1, str2, maxOffset:=5) {
  if (str1 = str2)
    return (str1 == str2 ? 0/1 : 0.2/StrLen(str1))

  if (str1 = "" || str2 = "")
    return (str1 = str2 ? 0/1 : 1/1)

  StringSplit, n, str1
  StringSplit, m, str2

  ni := 1, mi := 1, lcs := 0
  while ((ni <= n0) && (mi <= m0)) {
    if (n%ni% == m%mi%)
      lcs++
    else if (n%ni% = m%mi%)
      lcs += 0.8
    else {
      Loop, % maxOffset {
        oi := ni + A_Index, pi := mi + A_Index
        if ((n%oi% = m%mi%) && (oi <= n0)) {
          ni := oi, lcs += (n%oi% == m%mi% ? 1 : 0.8)
          break
        }
        if ((n%ni% = m%pi%) && (pi <= m0)) {
          mi := pi, lcs += (n%ni% == m%pi% ? 1 : 0.8)
          break
        }
      }
    }

    ni++, mi++
  }

  return ((n0 + m0)/2 - lcs) / (n0 > m0 ? n0 : m0)
}
