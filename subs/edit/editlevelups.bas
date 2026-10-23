'Level up editor: a full screen table with one row per level and a cursor that moves from cell to
'cell, so any value can be reached and changed directly. Next to each level's gains it shows the
'character's total stats after that level up, worked out the way the game does it:
'
'  Row L is used when the character goes from level L to L + 1.
'  Stats:    each flagged stat gets + the amount (a stored amount of 7 means -1), at most 99, at least 1.
'  HP, MP:   the listed bonus, plus a random 0 to bonus / 8 on top, at most 9999 HP and 999 MP.
'            The totals show the smallest result; the footer also shows the largest.
'  EXP:      TNL is the experience for that one level; the total is added up from the character's
'            starting threshold (the TNL in the starting data).
'
'The font has no + = ( ) [ ] < > characters, so the help text is written around that.

const lu_visible_rows = 40
const lu_table_y = 3
const lu_first_row_y = 6
const lu_columns = 9 'five stat flags, amount, HP, MP, TNL
const lu_undo_depth = 160
const lu_max_tnl = 524287 '19 bits

dim shared lu_col_off(1 to 9) as Integer = {3, 7, 11, 15, 19, 24, 27, 31, 34}
dim shared lu_col_w(1 to 9) as Integer = {3, 3, 3, 3, 3, 2, 3, 2, 6}

dim shared lu_stat_total(70, 5) as Integer
dim shared lu_hp_min(70) as Integer
dim shared lu_hp_max(70) as Integer
dim shared lu_mp_min(70) as Integer
dim shared lu_mp_max(70) as Integer
dim shared lu_exp_total(70) as Integer

type LuUndoEntry
 character as Integer
 level as Integer
 group as Integer
 data as LevelUpBonus
end type

dim shared lu_undo(lu_undo_depth - 1) as LuUndoEntry
dim shared lu_undo_count as Integer
dim shared lu_group as Integer
dim shared lu_clip as LevelUpBonus
dim shared lu_clip_ready as Boolean


dim shared lu_script(255) as UInteger 'keys to feed the editor instead of the keyboard (for testing)
dim shared lu_script_count as Integer
dim shared lu_script_pos as Integer


function LuReadKey() as UInteger

 dim k as UInteger

 if lu_script_pos < lu_script_count then
  lu_script_pos += 1
  return lu_script(lu_script_pos - 1)
 end if

 do
  k = getkey
 loop while KeyHelpPressed(k)

 return k

end function


function LuConfirm(message as String) as Boolean

 'A scripted test answers yes by itself; otherwise ask

 if lu_script_count > 0 then return true
 return ConfirmBox(message)

end function


function LuFirstLevel(ch as Integer) as Integer

 'The first level that has level up data (the level the character starts at)

 if characters(ch).level < 1 then return 1
 return characters(ch).level

end function


sub LuRecalc(ch as Integer)

 'Works out every total for one character

 dim stats(1 to 5) as Integer
 dim hp_low as Integer = characters(ch).max_hp
 dim hp_high as Integer = characters(ch).max_hp
 dim mp_low as Integer = characters(ch).max_mp
 dim mp_high as Integer = characters(ch).max_mp
 dim exp_sum as Integer = characters(ch).tnl
 dim bonus as Integer

 for s as Integer = 1 to 5
  stats(s) = characters(ch).stat(s)
 next

 for lv as Integer = LuFirstLevel(ch) to 69
  with characters(ch).levelup(lv)
   for s as Integer = 1 to 5
    if .stat_bonus.stat(s) then
     if .stat_bonus.amount = 7 then
      stats(s) -= 1
      if stats(s) < 1 then stats(s) = 1
     else
      stats(s) += .stat_bonus.amount
      if stats(s) > 99 then stats(s) = 99
     end if
    end if
    lu_stat_total(lv, s) = stats(s)
   next
   bonus = .hp_bonus
   hp_low += bonus
   hp_high += bonus + bonus \ 8
   if hp_low > 9999 then hp_low = 9999
   if hp_high > 9999 then hp_high = 9999
   bonus = .mp_bonus
   mp_low += bonus
   mp_high += bonus + bonus \ 8
   if mp_low > 999 then mp_low = 999
   if mp_high > 999 then mp_high = 999
   exp_sum += .tnl
  end with
  lu_hp_min(lv) = hp_low
  lu_hp_max(lv) = hp_high
  lu_mp_min(lv) = mp_low
  lu_mp_max(lv) = mp_high
  lu_exp_total(lv) = exp_sum
 next

end sub


function LuAmountText(amount as Integer) as String

 if amount = 7 then return "-1"
 return " " + str(amount)

end function


function LuCellValue(ch as Integer, lv as Integer, col as Integer) as Integer

 select case col
  case 1 to 5: return iif(characters(ch).levelup(lv).stat_bonus.stat(col), 1, 0)
  case 6: return characters(ch).levelup(lv).stat_bonus.amount
  case 7: return characters(ch).levelup(lv).hp_bonus
  case 8: return characters(ch).levelup(lv).mp_bonus
  case else: return characters(ch).levelup(lv).tnl
 end select

end function


function LuMaxValue(col as Integer) as Integer

 select case col
  case 1 to 5: return 1
  case 6: return 7
  case 7: return 255
  case 8: return 31
  case else: return lu_max_tnl
 end select

end function


sub LuSetCell(ch as Integer, lv as Integer, col as Integer, v as Integer)

 if v < 0 then v = 0
 if v > LuMaxValue(col) then v = LuMaxValue(col)

 select case col
  case 1 to 5: characters(ch).levelup(lv).stat_bonus.stat(col) = (v <> 0)
  case 6: characters(ch).levelup(lv).stat_bonus.amount = v
  case 7: characters(ch).levelup(lv).hp_bonus = v
  case 8: characters(ch).levelup(lv).mp_bonus = v
  case else: characters(ch).levelup(lv).tnl = v
 end select

end sub


sub LuPushUndo(ch as Integer, lv as Integer)

 'Remembers the row as it is now, as part of the current action

 if lu_undo_count = lu_undo_depth then
  for i as Integer = 1 to lu_undo_depth - 1
   lu_undo(i - 1) = lu_undo(i)
  next
  lu_undo_count -= 1
 end if

 lu_undo(lu_undo_count).character = ch
 lu_undo(lu_undo_count).level = lv
 lu_undo(lu_undo_count).group = lu_group
 lu_undo(lu_undo_count).data = characters(ch).levelup(lv)
 lu_undo_count += 1

end sub


function LuUndo(byref ch as Integer, byref lv as Integer) as Boolean

 'Undoes the last action (every row it changed). Returns false if there is nothing to undo.

 dim group_id as Integer

 if lu_undo_count = 0 then return false

 group_id = lu_undo(lu_undo_count - 1).group
 do while lu_undo_count > 0
  if lu_undo(lu_undo_count - 1).group <> group_id then exit do
  lu_undo_count -= 1
  ch = lu_undo(lu_undo_count).character
  lv = lu_undo(lu_undo_count).level
  characters(ch).levelup(lv) = lu_undo(lu_undo_count).data
 loop

 return true

end function


function LuStepAmount(amount as Integer, direction as Integer) as Integer

 'The amount runs -1, 0, 1 ... 6, stored as 7, 0, 1 ... 6

 dim shown as Integer = iif(amount = 7, -1, amount) + direction

 if shown < -1 then shown = -1
 if shown > 6 then shown = 6
 return iif(shown = -1, 7, shown)

end function


sub LuText(s as String, offset as Integer, y as Integer, c as UByte = 15)

 WriteText(FF4Text(s), 1 + offset, y, c)

end sub


sub LuDrawCell(ch as Integer, lv as Integer, col as Integer, y as Integer, c as UByte, replacement as String = "")

 'Draws one editable cell, or the text being typed into it

 dim s as String

 if replacement <> "" then
  s = Pad(replacement, lu_col_w(col), true)
 else
  select case col
   case 1 to 5: s = StatName(col)
   case 6: s = LuAmountText(characters(ch).levelup(lv).stat_bonus.amount)
   case 7: s = Pad(str(characters(ch).levelup(lv).hp_bonus), 3, true)
   case 8: s = Pad(str(characters(ch).levelup(lv).mp_bonus), 2, true)
   case else: s = Pad(str(characters(ch).levelup(lv).tnl), 6, true)
  end select
 end if
 LuText(s, lu_col_off(col), y, c)

end sub


sub LuDraw(ch as Integer, row as Integer, col as Integer, top as Integer, typing as Boolean, typed as String)

 dim first_level as Integer = LuFirstLevel(ch)
 dim rows_total as Integer = 70 - first_level
 dim visible as Integer = rows_total
 dim y as Integer
 dim lv as Integer
 dim selected_level as Integer
 dim footer_y as Integer
 dim stat_line as String
 dim c as UByte

 if visible > lu_visible_rows then visible = lu_visible_rows
 selected_level = first_level + row

 screenlock
 line (0, 0)-(639, 479), RGB(0, 0, 0), bf

 'Title: who, and the stats they start with
 BlueBox(0, 0, 78, 1)
 stat_line = "  Starts at Lv " + str(characters(ch).level) + ":"
 for s as Integer = 1 to 5
  stat_line += " " + StatName(s) + " " + str(characters(ch).stat(s))
 next
 stat_line += "  HP " + str(characters(ch).max_hp) + " MP " + str(characters(ch).max_mp)
 WriteText(character_labels.ItemAt(ch) + FF4Text(stat_line), 1, 1, 15)

 'Table frame and headings
 BlueBox(0, lu_table_y, 78, visible + 2)
 LuText("LEVEL UP GAIN", 3, lu_table_y + 1, 14)
 LuText("TOTAL AFTER THE LEVEL UP", 41, lu_table_y + 1, 10)
 LuText("Lv", 0, lu_table_y + 2, 15)
 for s as Integer = 1 to 5
  LuText(StatName(s), lu_col_off(s), lu_table_y + 2, 15)
  LuText(StatName(s), 41 + (s - 1) * 4, lu_table_y + 2, 10)
 next
 LuText("Amt", 23, lu_table_y + 2, 15)
 LuText("HP", 27, lu_table_y + 2, 15)
 LuText("MP", 31, lu_table_y + 2, 15)
 LuText("TNL", 34, lu_table_y + 2, 15)
 LuText("HP", 62, lu_table_y + 2, 10)
 LuText("MP", 67, lu_table_y + 2, 10)
 LuText("EXP", 72, lu_table_y + 2, 10)

 'One row per level
 for r as Integer = top to top + visible - 1
  lv = first_level + r
  y = lu_first_row_y + r - top
  LuText(Pad(str(lv), 2, true, "0"), 0, y, 15)
  for s as Integer = 1 to 5
   if characters(ch).levelup(lv).stat_bonus.stat(s) then LuDrawCell(ch, lv, s, y, 15)
  next
  for k as Integer = 6 to lu_columns
   LuDrawCell(ch, lv, k, y, 15)
  next
  for s as Integer = 1 to 5
   LuText(Pad(str(lu_stat_total(lv, s)), 2, true), 41 + (s - 1) * 4, y, 10)
  next
  LuText(Pad(str(lu_hp_min(lv)), 4, true), 61, y, 10)
  LuText(Pad(str(lu_mp_min(lv)), 3, true), 66, y, 10)
  LuText(Pad(str(lu_exp_total(lv)), 8, true), 70, y, 10)
 next

 'The cell the cursor is on
 y = lu_first_row_y + row - top
 DrawLetter(20, 0, y)
 if typing then
  LuDrawCell(ch, selected_level, col, y, 12, typed + "_")
 else
  LuDrawCell(ch, selected_level, col, y, 14)
 end if

 'Footer: what the selected row means
 footer_y = lu_table_y + visible + 3
 BlueBox(0, footer_y, 78, 8)
 LuText("Level " + str(selected_level) + " to " + str(selected_level + 1) + ":  needs " + str(characters(ch).levelup(selected_level).tnl) + " EXP, " + str(lu_exp_total(selected_level)) + " EXP in all", 0, footer_y + 1, 14)
 stat_line = "Stats after:"
 for s as Integer = 1 to 5
  stat_line += "  " + StatName(s) + " " + str(lu_stat_total(selected_level, s))
 next
 LuText(stat_line, 0, footer_y + 2, 10)
 LuText("HP after: " + str(lu_hp_min(selected_level)) + " to " + str(lu_hp_max(selected_level)) + "    MP after: " + str(lu_mp_min(selected_level)) + " to " + str(lu_mp_max(selected_level)) + "    Limits: stats 99, HP 9999, MP 999", 0, footer_y + 3, 10)
 LuText("HP and MP gains get a random 0 to 1/8 of the bonus added on top.", 0, footer_y + 4, 15)
 LuText("Arrows move. PgUp PgDn Home End jump. G go to level. N P other character.", 0, footer_y + 5, 14)
 LuText("Enter toggles a stat or edits a number. Type digits to enter a number.", 0, footer_y + 6, 14)
 LuText("Minus Plus: 1. Comma Period: 10, or 100 for TNL. Space toggles a stat.", 0, footer_y + 7, 14)
 LuText("D cell from above. F fill down. Ctrl-C Ctrl-V row. Ctrl-Z undo. Esc back.", 0, footer_y + 8, 14)
 screenunlock

end sub


sub EditLevelUps(start_character as Integer)

 dim ch as Integer = start_character
 dim row as Integer = 0
 dim col as Integer = 1
 dim top as Integer = 0
 dim typing as Boolean
 dim typed as String
 dim k as UInteger
 dim done as Boolean
 dim first_level as Integer
 dim rows_total as Integer
 dim visible as Integer
 dim lv as Integer
 dim v as Integer
 dim step_size as Integer
 dim go_text as String
 dim last_character as Integer = total_characters - 1
 dim fill_value as Integer
 dim count as Integer

 lu_undo_count = 0

 do

  first_level = LuFirstLevel(ch)
  rows_total = 70 - first_level
  visible = rows_total
  if visible > lu_visible_rows then visible = lu_visible_rows
  if row > rows_total - 1 then row = rows_total - 1
  if row < 0 then row = 0
  if row < top then top = row
  if row > top + visible - 1 then top = row - visible + 1
  if top < 0 then top = 0

  if rows_total <= 0 then
   cls
   InfoBox("This character starts at level 70 or higher,|so there is no level up data to edit.||Press any key", 10, 20)
   exit do
  end if

  lv = first_level + row
  LuRecalc(ch)
  LuDraw(ch, row, col, top, typing, typed)
  k = LuReadKey()

  'Anything that is not part of typing a number accepts the number first
  if typing then
   select case k
    case asc("0") to asc("9"), BACKSPACE_KEY, ENTER_KEY, ESC_KEY
    case else
     if typed <> "" then
      lu_group += 1
      LuPushUndo(ch, lv)
      LuSetCell(ch, lv, col, val(typed))
     end if
     typing = false
     typed = ""
   end select
  end if

  select case k

   case ESC_KEY
    if typing then
     typing = false
     typed = ""
    else
     done = true
    end if

   case UP_KEY
    if row > 0 then row -= 1
   case DOWN_KEY
    if row < rows_total - 1 then row += 1
   case LEFT_KEY
    if col > 1 then col -= 1
   case RIGHT_KEY
    if col < lu_columns then col += 1
   case PAGEUP_KEY
    row -= visible - 1
    if row < 0 then row = 0
   case PAGEDOWN_KEY
    row += visible - 1
    if row > rows_total - 1 then row = rows_total - 1
   case HOME_KEY
    row = 0
   case END_KEY
    row = rows_total - 1
   case TAB_KEY
    if col < lu_columns then
     col += 1
    elseif row < rows_total - 1 then
     col = 1
     row += 1
    end if

   case asc("g"), asc("G")
    go_text = PromptLine("Go to level, " + str(first_level) + " to 69:", 3)
    if go_text <> "" then
     row = val(go_text) - first_level
     if row < 0 then row = 0
     if row > rows_total - 1 then row = rows_total - 1
    end if

   case asc("n"), asc("N")
    if ch < last_character then
     ch += 1
     row = 0
     top = 0
    end if
   case asc("p"), asc("P")
    if ch > 1 then
     ch -= 1
     row = 0
     top = 0
    end if

   case asc("0") to asc("9")
    if col <= 5 then
     'a stat flag: 1 turns it on, 0 off
     if k <= asc("1") then
      lu_group += 1
      LuPushUndo(ch, lv)
      LuSetCell(ch, lv, col, k - asc("0"))
     end if
    elseif col = 6 then
     if k <= asc("6") then
      lu_group += 1
      LuPushUndo(ch, lv)
      LuSetCell(ch, lv, col, k - asc("0"))
     end if
    else
     if not typing then
      typing = true
      typed = ""
     end if
     if len(typed) < 6 then typed += chr(k)
    end if

   case BACKSPACE_KEY
    if typing and len(typed) > 0 then typed = left(typed, len(typed) - 1)

   case ENTER_KEY
    if typing then
     if typed <> "" then
      lu_group += 1
      LuPushUndo(ch, lv)
      LuSetCell(ch, lv, col, val(typed))
     end if
     typing = false
     typed = ""
     if row < rows_total - 1 then row += 1
    elseif col <= 5 then
     lu_group += 1
     LuPushUndo(ch, lv)
     LuSetCell(ch, lv, col, 1 - LuCellValue(ch, lv, col))
    elseif col = 6 then
     lu_group += 1
     LuPushUndo(ch, lv)
     v = LuCellValue(ch, lv, col)
     if v = 6 then
      LuSetCell(ch, lv, col, 7)
     elseif v = 7 then
      LuSetCell(ch, lv, col, 0)
     else
      LuSetCell(ch, lv, col, v + 1)
     end if
    else
     typing = true
     typed = str(LuCellValue(ch, lv, col))
    end if

   case SPACE_KEY
    if col <= 5 then
     lu_group += 1
     LuPushUndo(ch, lv)
     LuSetCell(ch, lv, col, 1 - LuCellValue(ch, lv, col))
    end if

   case asc("-"), asc("="), asc("+"), asc(","), asc(".")
    lu_group += 1
    LuPushUndo(ch, lv)
    if k = asc("-") or k = asc("+") or k = asc("=") then step_size = 1 else step_size = iif(col = lu_columns, 100, 10)
    if k = asc("-") or k = asc(",") then step_size = -step_size
    select case col
     case 1 to 5
      LuSetCell(ch, lv, col, iif(step_size > 0, 1, 0))
     case 6
      LuSetCell(ch, lv, col, LuStepAmount(LuCellValue(ch, lv, col), sgn(step_size)))
     case else
      LuSetCell(ch, lv, col, LuCellValue(ch, lv, col) + step_size)
    end select

   case asc("d"), asc("D")
    if row > 0 then
     lu_group += 1
     LuPushUndo(ch, lv)
     LuSetCell(ch, lv, col, LuCellValue(ch, lv - 1, col))
    end if

   case asc("f"), asc("F")
    count = rows_total - 1 - row
    if count > 0 then
     if LuConfirm("Copy this value into the " + str(count) + " rows below?") then
      fill_value = LuCellValue(ch, lv, col)
      lu_group += 1
      for r as Integer = row + 1 to rows_total - 1
       LuPushUndo(ch, first_level + r)
       LuSetCell(ch, first_level + r, col, fill_value)
      next
     end if
    end if

   case 3 'Ctrl-C
    lu_clip = characters(ch).levelup(lv)
    lu_clip_ready = true
   case 22 'Ctrl-V
    if lu_clip_ready then
     lu_group += 1
     LuPushUndo(ch, lv)
     characters(ch).levelup(lv) = lu_clip
    end if
   case 26 'Ctrl-Z
    if LuUndo(ch, lv) then
     row = lv - LuFirstLevel(ch)
    end if

  end select

 loop until done

 cls

end sub
