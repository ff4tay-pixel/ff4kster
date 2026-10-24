'After 70 editor: a full screen table of the eight stat bonus combinations the game picks from at random
'for every level up after level 70 (HP, MP and TNL repeat the character's level 69 row). It works like the
'level up editor: the cursor moves from cell to cell, and next to each combination it shows in words what
'the combination does, with the average gain per level up for every stat below the table.
'
'Each combination: five stat flags and an amount (stored 0 to 6, or 7 meaning -1).

const a70_rows = 8
const a70_columns = 6 'five stat flags and the amount
const a70_table_y = 3
const a70_first_row_y = 6
const a70_undo_depth = 64

type A70UndoEntry
 character as Integer
 combo as Integer
 group as Integer
 data as StatLevelUp
end type

dim shared a70_undo(a70_undo_depth - 1) as A70UndoEntry
dim shared a70_undo_count as Integer
dim shared a70_group as Integer
dim shared a70_clip as StatLevelUp
dim shared a70_clip_ready as Boolean


function A70Change(amount as Integer) as Integer

 'The amount as a signed number (7 is stored for -1)

 if amount = 7 then return -1
 return amount

end function


function A70ComboText(combo as StatLevelUp) as String

 'What one combination does, in words the font can draw

 dim result as String
 dim count as Integer

 for s as Integer = 1 to 5
  if combo.stat(s) then
   count += 1
   if count > 1 then result += "  "
   result += StatName(s) + " " + str(A70Change(combo.amount))
  end if
 next

 if count = 0 then return "Nothing is raised"
 if combo.amount = 0 then return "No change, amount is 0"
 return result

end function


function A70AverageText(ch as Integer, s as Integer) as String

 'Average gain of one stat per level up: the eight combinations are equally likely

 dim total as Integer
 dim tenths as Integer

 for i as Integer = 1 to a70_rows
  if characters(ch).after70(i).stat(s) then total += A70Change(characters(ch).after70(i).amount)
 next

 tenths = (abs(total) * 10) \ a70_rows
 return iif(total < 0, "-", "") + str(tenths \ 10) + "." + str(tenths mod 10)

end function


sub A70PushUndo(ch as Integer, combo as Integer)

 if a70_undo_count = a70_undo_depth then
  for i as Integer = 1 to a70_undo_depth - 1
   a70_undo(i - 1) = a70_undo(i)
  next
  a70_undo_count -= 1
 end if

 a70_undo(a70_undo_count).character = ch
 a70_undo(a70_undo_count).combo = combo
 a70_undo(a70_undo_count).group = a70_group
 a70_undo(a70_undo_count).data = characters(ch).after70(combo)
 a70_undo_count += 1

end sub


function A70Undo(byref ch as Integer, byref combo as Integer) as Boolean

 dim group_id as Integer

 if a70_undo_count = 0 then return false

 group_id = a70_undo(a70_undo_count - 1).group
 do while a70_undo_count > 0
  if a70_undo(a70_undo_count - 1).group <> group_id then exit do
  a70_undo_count -= 1
  ch = a70_undo(a70_undo_count).character
  combo = a70_undo(a70_undo_count).combo
  characters(ch).after70(combo) = a70_undo(a70_undo_count).data
 loop

 return true

end function


sub A70SetCell(ch as Integer, combo as Integer, col as Integer, v as Integer)

 'Records the change for undo, then sets a stat flag (col 1 to 5, v 0 or 1) or the amount (col 6, v 0 to 7)

 a70_group += 1
 A70PushUndo(ch, combo)
 if col <= 5 then
  characters(ch).after70(combo).stat(col) = (v <> 0)
 else
  if v < 0 then v = 0
  if v > 7 then v = 7
  characters(ch).after70(combo).amount = v
 end if

end sub


function A70CellValue(ch as Integer, combo as Integer, col as Integer) as Integer

 if col <= 5 then return iif(characters(ch).after70(combo).stat(col), 1, 0)
 return characters(ch).after70(combo).amount

end function


sub A70Draw(ch as Integer, row as Integer, col as Integer)

 dim y as Integer
 dim c as UByte
 dim stat_line as String
 dim last_row as LevelUpBonus
 dim footer_y as Integer = a70_table_y + a70_rows + 5

 'The after 70 rows reuse the last level up row, level 69
 last_row = characters(ch).levelup(69)

 screenlock
 line (0, 0)-(639, 479), RGB(0, 0, 0), bf

 BlueBox(0, 0, 78, 1)
 WriteText(character_labels.ItemAt(ch) + FF4Text("  After level 70"), 1, 1, 15)

 'Table
 BlueBox(0, a70_table_y, 78, a70_rows + 2)
 LuText("EIGHT COMBINATIONS, ONE IS PICKED AT RANDOM FOR EVERY LEVEL UP", 3, a70_table_y + 1, 14)
 LuText("#", 0, a70_table_y + 2, 15)
 for s as Integer = 1 to 5
  LuText(StatName(s), lu_col_off(s), a70_table_y + 2, 15)
 next
 LuText("Amt", 23, a70_table_y + 2, 15)
 LuText("WHAT IT DOES", 29, a70_table_y + 2, 10)

 for r as Integer = 1 to a70_rows
  y = a70_first_row_y + r - 1
  LuText(str(r), 0, y, 15)
  for s as Integer = 1 to 5
   if characters(ch).after70(r).stat(s) then LuText(StatName(s), lu_col_off(s), y, 15)
  next
  LuText(LuAmountText(characters(ch).after70(r).amount), lu_col_off(6), y, 15)
  LuText(A70ComboText(characters(ch).after70(r)), 29, y, 10)
 next

 'The cell the cursor is on
 y = a70_first_row_y + row - 1
 DrawLetter(20, 0, y)
 if col <= 5 then
  LuText(StatName(col), lu_col_off(col), y, 14)
  if not characters(ch).after70(row).stat(col) then LuText("---", lu_col_off(col), y, 14)
 else
  LuText(LuAmountText(characters(ch).after70(row).amount), lu_col_off(6), y, 14)
 end if

 'Summary
 BlueBox(0, footer_y, 78, 12)
 LuText("AVERAGE GAIN PER LEVEL UP", 0, footer_y + 1, 14)
 stat_line = ""
 for s as Integer = 1 to 5
  stat_line += StatName(s) + " " + A70AverageText(ch, s) + "   "
 next
 LuText(stat_line, 0, footer_y + 2, 10)
 LuText("Stats stop at 99 and never go below 1.", 0, footer_y + 3, 15)
 LuText("SAME AS THE LAST LEVEL UP, LEVEL 69", 0, footer_y + 5, 14)
 LuText("HP bonus " + str(last_row.hp_bonus) + "   MP bonus " + str(last_row.mp_bonus) + "   TNL " + str(last_row.tnl), 0, footer_y + 6, 10)
 LuText("Edit those in the level up data.", 0, footer_y + 7, 15)
 LuText("Arrows and Tab move. Enter or Space toggles a stat. 0 to 6 sets the amount.", 0, footer_y + 8, 14)
 LuText("Minus Plus: amount. D copies the cell from above. N P other character.", 0, footer_y + 9, 14)
 LuText("Ctrl-C Ctrl-V copy a combination. Ctrl-Z undo. Esc back.", 0, footer_y + 10, 14)
 screenunlock

end sub


sub EditAfter70(start_character as Integer)

 dim ch as Integer = start_character
 dim row as Integer = 1
 dim col as Integer = 1
 dim k as UInteger
 dim done as Boolean
 dim last_character as Integer = total_characters - 1

 a70_undo_count = 0

 do
  A70Draw(ch, row, col)
  k = LuReadKey()

  select case k

   case ESC_KEY
    done = true

   case UP_KEY
    if row > 1 then row -= 1
   case DOWN_KEY
    if row < a70_rows then row += 1
   case LEFT_KEY
    if col > 1 then col -= 1
   case RIGHT_KEY
    if col < a70_columns then col += 1
   case HOME_KEY
    row = 1
   case END_KEY
    row = a70_rows
   case TAB_KEY
    if col < a70_columns then
     col += 1
    elseif row < a70_rows then
     col = 1
     row += 1
    end if

   case asc("n"), asc("N")
    if ch < last_character then ch += 1
   case asc("p"), asc("P")
    if ch > 1 then ch -= 1

   case asc("0") to asc("6")
    if col = 6 then
     A70SetCell(ch, row, col, k - asc("0"))
    elseif k <= asc("1") then
     A70SetCell(ch, row, col, k - asc("0"))
    end if

   case ENTER_KEY, SPACE_KEY
    if col <= 5 then
     A70SetCell(ch, row, col, 1 - A70CellValue(ch, row, col))
    else
     'cycle -1, 0 ... 6
     if A70CellValue(ch, row, col) = 6 then
      A70SetCell(ch, row, col, 7)
     elseif A70CellValue(ch, row, col) = 7 then
      A70SetCell(ch, row, col, 0)
     else
      A70SetCell(ch, row, col, A70CellValue(ch, row, col) + 1)
     end if
    end if

   case asc("-"), asc("="), asc("+"), asc(","), asc(".")
    if col <= 5 then
     A70SetCell(ch, row, col, iif(k = asc("-") or k = asc(","), 0, 1))
    else
     A70SetCell(ch, row, col, LuStepAmount(A70CellValue(ch, row, col), iif(k = asc("-") or k = asc(","), -1, 1)))
    end if

   case asc("d"), asc("D")
    if row > 1 then A70SetCell(ch, row, col, A70CellValue(ch, row - 1, col))

   case 3 'Ctrl-C
    a70_clip = characters(ch).after70(row)
    a70_clip_ready = true
   case 22 'Ctrl-V
    if a70_clip_ready then
     a70_group += 1
     A70PushUndo(ch, row)
     characters(ch).after70(row) = a70_clip
    end if
   case 26 'Ctrl-Z
    A70Undo(ch, row)

  end select

 loop until done

 cls

end sub
