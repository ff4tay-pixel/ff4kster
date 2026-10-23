'Shared engine of the Weapons, Armors, Spells and Medicines editors.
'
'Those editors show every box of an entry at once, and Enter on the entry list moves the cursor straight into the
'boxes (no "pick a category" menu in between), the way the Monsters editor does:
'
'  Up Down Left Right  move in the box, and on from the last line to the next box
'  Tab, 1 2 3 ...      jump to the next box, or to the box with that number in its title
'  Enter, Space        change the line: a flag switches, a number or a name is typed, a list is picked from
'  PgUp PgDn           the same line of the previous or next entry
'  Esc                 back to the list of entries
'
'Each editor supplies four routines: draw the entry (copy it to the boxes and display them), change a line, a
'hint for the line, and the keys only some boxes use (Left Right on a set number). The boxes are BlueMenus
'(or one line boxes drawn by their component) that the editor registers with FmAddMenu and FmAddLine.

const fm_max_panels = 14

type FmPanel
 menu as BlueMenu ptr 'the lines of the box, or 0 for a one line box that its component draws
 cx as Integer 'where the cursor arrow goes for a one line box
 cy as Integer
 group as Integer 'the number in the title: the digit key that jumps here
end type

dim shared fm_panel(1 to fm_max_panels) as FmPanel
dim shared fm_count as Integer
dim shared fm_cur as Integer 'the box the cursor is in
dim shared fm_message as String 'shown instead of the hint, set by the editor's routines

dim shared fm_show as sub(entry as Integer)
dim shared fm_act as sub(entry as Integer, panel as Integer, row as Integer, k as UInteger)
dim shared fm_hint as function(entry as Integer, panel as Integer, row as Integer) as String
dim shared fm_extra as function(entry as Integer, panel as Integer, row as Integer, k as UInteger) as Boolean

dim shared fm_script_keys(255) as UInteger 'keys to feed the editor instead of the keyboard (for testing)
dim shared fm_script_count as Integer
dim shared fm_script_pos as Integer


sub FmClear()

 fm_count = 0

end sub


sub FmAddMenu(m as BlueMenu ptr, group as Integer)

 fm_count += 1
 fm_panel(fm_count).menu = m
 fm_panel(fm_count).cx = 0
 fm_panel(fm_count).cy = 0
 fm_panel(fm_count).group = group

end sub


sub FmAddLine(cx as Integer, cy as Integer, group as Integer)

 fm_count += 1
 fm_panel(fm_count).menu = 0
 fm_panel(fm_count).cx = cx
 fm_panel(fm_count).cy = cy
 fm_panel(fm_count).group = group

end sub


function FmReadKey() as UInteger

 'A key, with the idle hook running (spell animations) while waiting

 dim key as String
 dim result as UInteger

 if fm_script_pos < fm_script_count then
  fm_script_pos += 1
  return fm_script_keys(fm_script_pos - 1)
 end if

 do
  do
   key = inkey
   if key = "" then
    if cast(Any ptr, idle_hook) <> 0 then idle_hook()
    sleep 10
   end if
  loop while key = ""

  if len(key) > 1 then result = asc(right(key, 1)) * &h100 + 255 else result = asc(key)
 loop while KeyHelpPressed(result)

 return result

end function


function FmRows(p as Integer) as Integer

 if fm_panel(p).menu = 0 then return 1

 return fm_panel(p).menu->options.Length()

end function


function FmRow(p as Integer) as Integer

 if fm_panel(p).menu = 0 then return 1

 return fm_panel(p).menu->selected

end function


sub FmSetRow(p as Integer, row as Integer)

 if fm_panel(p).menu <> 0 then fm_panel(p).menu->ChangeSelected(row)

end sub


sub FmDrawCursor()

 if fm_panel(fm_cur).menu = 0 then
  DrawLetter(20, fm_panel(fm_cur).cx, fm_panel(fm_cur).cy)
 else
  fm_panel(fm_cur).menu->ShowCursor()
 end if

end sub


sub FmDrawHint(entry as Integer)

 'The bottom line says what Enter does on the line the cursor is on

 dim text as String = fm_message

 if text = "" then text = fm_hint(entry, fm_cur, FmRow(fm_cur))
 line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf
 WriteText(FF4Text(left(text, 78)), 1, 57, 14)

end sub


sub FmMove(k as UInteger)

 'Arrow keys, Home and End: inside the box, and on to the next or previous box at its edges

 dim m as BlueMenu ptr = fm_panel(fm_cur).menu
 dim n as Integer = FmRows(fm_cur)
 dim row as Integer = FmRow(fm_cur)
 dim columns as Integer = 1

 if m <> 0 then columns = m->columns

 select case k

  case UP_KEY
   if m <> 0 andalso row > columns then
    m->ProcessKey(k)
   else
    fm_cur = iif(fm_cur = 1, fm_count, fm_cur - 1)
    FmSetRow(fm_cur, FmRows(fm_cur))
   end if

  case DOWN_KEY
   if m <> 0 andalso row + columns <= n then
    m->ProcessKey(k)
   else
    fm_cur = fm_cur mod fm_count + 1
    FmSetRow(fm_cur, 1)
   end if

  case LEFT_KEY, RIGHT_KEY
   if m <> 0 then m->ProcessKey(k)

  case HOME_KEY
   FmSetRow(fm_cur, 1)

  case END_KEY
   FmSetRow(fm_cur, n)

 end select

end sub


sub FormFields(entries as BlueMenu ptr, kind as String, first_panel as Integer = 1)

 'The cursor in the boxes of the selected entry of the list. Returns when Esc is pressed.

 dim k as UInteger
 dim done as Boolean
 dim entry as Integer
 dim row as Integer
 dim target as Integer

 fm_cur = first_panel
 fm_message = ""

 do

  entry = entries->selected
  screenlock
  fm_show(entry)
  FmDrawCursor()
  FmDrawHint(entry)
  screenunlock
  fm_message = ""
  k = FmReadKey()
  row = FmRow(fm_cur)

  if fm_extra(entry, fm_cur, row, k) then
   'a key only this box uses

  else

   select case k

    case ESC_KEY
     done = true

    case TAB_KEY
     fm_cur = fm_cur mod fm_count + 1
    case asc("1") to asc("9")
     for p as Integer = 1 to fm_count
      if fm_panel(p).group = k - asc("0") then
       fm_cur = p
       exit for
      end if
     next

    case UP_KEY, DOWN_KEY, LEFT_KEY, RIGHT_KEY, HOME_KEY, END_KEY
     FmMove(k)

    case PAGEUP_KEY, PAGEDOWN_KEY
     'the same line of the previous or next entry
     target = entries->selected + iif(k = PAGEUP_KEY, -1, 1)
     if target >= 1 and target <= entries->options.Length() then
      UndoPush(kind, target)
      entries->ChangeSelected(target)
     end if

    case ENTER_KEY, SPACE_KEY
     fm_act(entry, fm_cur, row, k)

   end select

  end if

 loop until done

end sub


'-------- helpers the editors share --------

function FmFlagHint(on_text as String) as String

 return "Enter or Space switches it on and off. Yellow is on. " + on_text

end function


function FmEffectHint(row as Integer) as String

 'The hint for a line of the effect box that spells and medicines share

 select case row
  case 1: return "Enter picks what the effect does."
  case 2: return "Enter picks who it targets."
  case 3: return "Enter types the power the effect's formula uses."
  case 4: return "Enter types the hit chance."
  case 5: return "Enter types the casting delay."
  case 6: return "Enter types the MP cost."
  case 7: return "Enter or Space switches whether Reflect bounces it."
  case 8: return "Enter or Space switches whether it hits bosses."
  case 9: return "Enter or Space switches Impact."
 end select

 return "Enter or Space switches Damage."

end function
