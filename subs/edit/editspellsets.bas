'Spell Sets editor. The first screen is the list of spell sets with a preview of the selected set; Enter opens the
'set in one screen with two lists side by side:
'
'  1 STARTING SPELLS  The spells a character with this set has from the start (up to 24).
'  2 LEARNED SPELLS   The spells it learns, each at a level (up to 24, kept in level order).
'
'Everything is done on the line the cursor is on: Enter changes it (on the "Add a spell" line at the bottom of
'each list it adds one), Insert (or A) adds, Delete (or D) removes,
'C clears the list, Left and Right change a learned spell's level by one, Ctrl-Z undoes. The ROM has a limited
'amount of room for the lists of all spell sets together, so adding can be refused.
'
'The font has no + = ( ) [ ] < > characters, so the help text is written around that.

const ss_max = 24
const ss_undo_depth = 60

dim shared ss_index as Integer 'the spell set being edited (1 based)
dim shared ss_start(1 to ss_max) as Integer 'starting spells (spell numbers)
dim shared ss_start_n as Integer
dim shared ss_level(1 to ss_max) as Integer 'learned spells: level, spell and a tag that follows the entry when it is sorted
dim shared ss_spell(1 to ss_max) as Integer
dim shared ss_tag(1 to ss_max) as Integer
dim shared ss_learn_n as Integer
dim shared ss_next_tag as Integer
dim shared ss_cur(1 to 2) as Integer 'cursor line of each list
dim shared ss_box as Integer 'the list the keys act on
dim shared ss_undo(0 to ss_undo_depth - 1) as String
dim shared ss_undo_count as Integer


sub SsText(s as String, x as Integer, y as Integer, c as UByte = 15)

 WriteText(FF4Text(s), x, y, c)

end sub


sub SsBand(c0 as Integer, c1 as Integer, y as Integer, c as UInteger)

 'Colors the background of the text row between columns c0 and c1 (the font draws its letters on the box color,
 ' so every pixel of that color is replaced)

 dim width_px as Integer = (c1 - c0 + 1) * 8
 dim img as Any ptr = ImageCreate(width_px, 8)
 dim pitch as Integer
 dim pixels as Any ptr
 dim px as UInteger ptr

 get (c0 * 8, y * 8)-(c0 * 8 + width_px - 1, y * 8 + 7), img
 imageinfo img, , , , pitch, pixels
 for r as Integer = 0 to 7
  px = cast(UInteger ptr, pixels + r * pitch)
  for i as Integer = 0 to width_px - 1
   if (px[i] and &hFFFFFF) = &h000060 then px[i] = c
  next
 next
 put (c0 * 8, y * 8), img, pset
 ImageDestroy(img)

end sub


'-------- the set being edited --------

sub SsLoad()

 dim s as SpellSet ptr = spellsets.PointerAt(ss_index)

 ss_start_n = Min(s->starting_spells.Length(), ss_max)
 for i as Integer = 1 to ss_start_n
  ss_start(i) = asc(s->starting_spells.ItemAt(i))
 next
 ss_learn_n = Min(s->learning_spells.Length(), ss_max)
 for i as Integer = 1 to ss_learn_n
  ss_level(i) = asc(s->learning_levels.ItemAt(i))
  ss_spell(i) = asc(s->learning_spells.ItemAt(i))
  ss_tag(i) = i
 next
 ss_next_tag = ss_learn_n + 1

end sub


sub SsStore()

 'Writes the lists back to the spell set

 dim s as SpellSet ptr = spellsets.PointerAt(ss_index)

 s->starting_spells.Destroy()
 for i as Integer = 1 to ss_start_n
  s->starting_spells.Append(chr(ss_start(i)))
 next
 s->learning_levels.Destroy()
 s->learning_spells.Destroy()
 for i as Integer = 1 to ss_learn_n
  s->learning_levels.Append(chr(ss_level(i)))
  s->learning_spells.Append(chr(ss_spell(i)))
 next

end sub


function SsSnapshot() as String

 dim t as String = chr(ss_start_n)

 for i as Integer = 1 to ss_start_n
  t += chr(ss_start(i))
 next
 t += chr(ss_learn_n)
 for i as Integer = 1 to ss_learn_n
  t += chr(ss_level(i)) + chr(ss_spell(i))
 next

 return t

end function


sub SsRestore(t as String)

 dim p as Integer = 1

 ss_start_n = asc(mid(t, p, 1))
 p += 1
 for i as Integer = 1 to ss_start_n
  ss_start(i) = asc(mid(t, p, 1))
  p += 1
 next
 ss_learn_n = asc(mid(t, p, 1))
 p += 1
 for i as Integer = 1 to ss_learn_n
  ss_level(i) = asc(mid(t, p, 1))
  ss_spell(i) = asc(mid(t, p + 1, 1))
  ss_tag(i) = i
  p += 2
 next
 ss_next_tag = ss_learn_n + 1

end sub


sub SsPush()

 'Remembers the lists as they are, before a change

 if ss_undo_count = ss_undo_depth then
  for i as Integer = 1 to ss_undo_depth - 1
   ss_undo(i - 1) = ss_undo(i)
  next
  ss_undo_count -= 1
 end if
 ss_undo(ss_undo_count) = SsSnapshot()
 ss_undo_count += 1

end sub


function SsUndo() as Boolean

 if ss_undo_count = 0 then return false

 ss_undo_count -= 1
 SsRestore(ss_undo(ss_undo_count))
 SsStore()
 ss_cur(1) = Min(ss_cur(1), ss_start_n + 1)
 ss_cur(2) = Min(ss_cur(2), ss_learn_n + 1)

 return true

end function


sub SsSortLearned()

 'Keeps the learned spells in level order (entries with the same level keep their order)

 dim lv as Integer
 dim sp as Integer
 dim tg as Integer
 dim j as Integer

 for i as Integer = 2 to ss_learn_n
  lv = ss_level(i)
  sp = ss_spell(i)
  tg = ss_tag(i)
  j = i - 1
  while j >= 1 andalso ss_level(j) > lv
   ss_level(j + 1) = ss_level(j)
   ss_spell(j + 1) = ss_spell(j)
   ss_tag(j + 1) = ss_tag(j)
   j -= 1
  wend
  ss_level(j + 1) = lv
  ss_spell(j + 1) = sp
  ss_tag(j + 1) = tg
 next

end sub


function SsFindTag(tg as Integer) as Integer

 for i as Integer = 1 to ss_learn_n
  if ss_tag(i) = tg then return i
 next

 return 1

end function


'-------- asking --------

function SsPickSpell(current as Integer, title as String) as Integer

 'One of the spells a character can have, from a list. Returns its number, 0 if cancelled.

 dim m as BlueMenu

 m = BlueMenu(34, 4)
 m.max_rows = 28
 m.title = title
 for i as Integer = 1 to total_player_spells
  m.AddOption(spells(i).name)
 next
 m.ChangeSelected(Max(Min(current, total_player_spells), 1))
 m.UserSelect()
 if m.cancelled then return 0

 return m.selected

end function


function SsPickLevel(current as Integer, y as Integer) as Integer

 'A level from 2 to 99 (Esc gives back the level it started on)

 dim n as BlueNumberInput

 n = BlueNumberInput(40, Min(Max(y - 1, 3), 26))
 n.min_value = 2
 n.max_value = 99
 n.starting_number = Max(current, 2)
 n.number = n.starting_number
 n.UserSelect()

 return n.number

end function


'-------- drawing --------

sub SsDrawBoxes(x0 as Integer, w1 as Integer, w2 as Integer, active as Integer, show_cursor as Boolean)

 'The two lists of the set being edited: starting spells at x0, learned spells to the right of it

 dim lx as Integer = x0 + w1 + 2
 dim y as Integer
 dim focused as Boolean
 dim band_color as UInteger

 BlueBox(x0, 3, w1, 24)
 SsText(iif(w1 < 20, " STARTING ", " 1  STARTING SPELLS "), x0 + 1, 3, iif(active = 1, 14, 23))
 BlueBox(lx, 3, w2, 24)
 SsText(iif(w1 < 20, " LEARNED ", " 2  LEARNED SPELLS "), lx + 1, 3, iif(active = 2, 14, 23))

 if ss_start_n = 0 then
  if not show_cursor then SsText("No starting spells.", x0 + 2, 4, 23)
 end if
 for i as Integer = 1 to ss_start_n
  y = 3 + i
  SsText(str(i), x0 + 2, y, 23)
  WriteText(spells(ss_start(i)).name, x0 + 6, y, 15)
 next
 if show_cursor and ss_start_n < ss_max then SsText("Add a spell", x0 + 6, 4 + ss_start_n, 10)

 if ss_learn_n = 0 then
  if not show_cursor then SsText("No learned spells.", lx + 2, 4, 23)
 end if
 for i as Integer = 1 to ss_learn_n
  y = 3 + i
  SsText("Level " + Pad(str(ss_level(i)), 2, true), lx + 2, y, 14)
  WriteText(spells(ss_spell(i)).name, lx + 12, y, 15)
 next
 if show_cursor and ss_learn_n < ss_max then SsText("Add a spell", lx + 12, 4 + ss_learn_n, 10)

 if show_cursor then
  for b as Integer = 1 to 2
   focused = (active = b)
   band_color = iif(focused, RGB(95, 115, 205), RGB(50, 65, 135))
   if b = 1 then
    SsBand(x0 + 1, x0 + w1, 3 + ss_cur(1), band_color)
    if focused then DrawLetter(20, x0, 3 + ss_cur(1))
   else
    SsBand(lx + 1, lx + w2, 3 + ss_cur(2), band_color)
    if focused then DrawLetter(20, lx, 3 + ss_cur(2))
   end if
  next
 end if

end sub


function SsHint() as String

 if ss_box = 1 then
  if ss_cur(1) > ss_start_n then return "Enter adds a starting spell at the end of the list."
  return "Enter: other spell. Insert: add after. Delete: remove. C: clear list."
 end if
 if ss_cur(2) > ss_learn_n then return "Enter adds a learned spell. It goes in level order."
 return "Enter: level and spell. Left Right: level. Insert: add. Delete: remove."

end function


sub SsDrawEdit(message as String)

 dim info as String

 ss_cur(1) = Min(ss_cur(1), Min(ss_start_n + 1, ss_max))
 ss_cur(2) = Min(ss_cur(2), Min(ss_learn_n + 1, ss_max))

 screenlock
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 BlueBox(0, 0, 78, 1)
 WriteText(spellset_names.ItemAt(ss_index), 2, 1, 15)
 SsText(str(ss_start_n) + " starting and " + str(ss_learn_n) + " learned spells", 48, 1, 14)

 SsDrawBoxes(0, 30, 45, ss_box, true)

 BlueBox(0, 29, 78, 1)
 info = SsHint()
 if message <> "" then
  SsText(message, 2, 30, 12)
 else
  SsText(info, 2, 30, 14)
 end if

 BlueBox(0, 32, 78, 6)
 SsText(" KEYS ", 1, 32, 14)
 SsText("Tab or 1 2: other list.  Arrows PgUp PgDn Home End: move.  Esc: back.", 2, 34, 15)
 SsText("Enter: change or add.  Insert or A: add.  Delete or D: remove.  C: clear.", 2, 35, 15)
 SsText("Learned: Left Right or Minus Plus change the level. Kept in level order.", 2, 36, 15)
 SsText("Ctrl-Z: undo.  All spell sets share limited room in the ROM.", 2, 37, 15)
 screenunlock

end sub


'-------- actions --------

sub SsAddStarting(byref message as String)

 dim v as Integer
 dim place as Integer

 if ss_start_n >= ss_max then
  message = "A spell set holds at most " + str(ss_max) + " starting spells."
  exit sub
 end if
 if not RoomForStartingSpells() then
  message = "No room left in the ROM for more starting spells. Remove one first."
  exit sub
 end if

 v = SsPickSpell(0, "Add a starting spell")
 if v = 0 then exit sub

 SsPush()
 place = Min(ss_cur(1), ss_start_n) + 1 'after the cursor line, or at the end from the Add line
 for i as Integer = ss_start_n to place step -1
  ss_start(i + 1) = ss_start(i)
 next
 ss_start_n += 1
 ss_start(place) = v
 ss_cur(1) = place
 SsStore()

end sub


sub SsAddLearned(byref message as String)

 dim lv as Integer
 dim v as Integer
 dim place as Integer

 if ss_learn_n >= ss_max then
  message = "A spell set holds at most " + str(ss_max) + " learned spells."
  exit sub
 end if
 if not RoomForLearningSpells() then
  message = "No room left in the ROM for more learned spells. Remove one first."
  exit sub
 end if

 lv = iif(ss_learn_n > 0, ss_level(Min(ss_cur(2), ss_learn_n)), 2)
 lv = SsPickLevel(lv, 3 + ss_cur(2))
 v = SsPickSpell(0, "Learned at level " + str(lv))
 if v = 0 then exit sub

 SsPush()
 ss_learn_n += 1
 ss_level(ss_learn_n) = lv
 ss_spell(ss_learn_n) = v
 ss_tag(ss_learn_n) = ss_next_tag
 place = ss_next_tag
 ss_next_tag += 1
 SsSortLearned()
 ss_cur(2) = SsFindTag(place)
 SsStore()

end sub


sub SsEditStarting(byref message as String)

 dim v as Integer

 if ss_cur(1) > ss_start_n then
  SsAddStarting(message)
  exit sub
 end if

 v = SsPickSpell(ss_start(ss_cur(1)), "Change starting spell " + str(ss_cur(1)))
 if v = 0 or v = ss_start(ss_cur(1)) then exit sub

 SsPush()
 ss_start(ss_cur(1)) = v
 SsStore()

end sub


sub SsEditLearned(byref message as String)

 dim lv as Integer
 dim v as Integer
 dim place as Integer

 if ss_cur(2) > ss_learn_n then
  SsAddLearned(message)
  exit sub
 end if

 lv = SsPickLevel(ss_level(ss_cur(2)), 3 + ss_cur(2))
 v = SsPickSpell(ss_spell(ss_cur(2)), "Learned at level " + str(lv))
 if v = 0 then exit sub
 if lv = ss_level(ss_cur(2)) and v = ss_spell(ss_cur(2)) then exit sub

 SsPush()
 place = ss_tag(ss_cur(2))
 ss_level(ss_cur(2)) = lv
 ss_spell(ss_cur(2)) = v
 SsSortLearned()
 ss_cur(2) = SsFindTag(place)
 SsStore()

end sub


sub SsChangeLevel(delta as Integer)

 dim lv as Integer
 dim place as Integer

 if ss_cur(2) > ss_learn_n then exit sub
 lv = ss_level(ss_cur(2)) + delta
 if lv < 2 or lv > 99 then exit sub

 SsPush()
 place = ss_tag(ss_cur(2))
 ss_level(ss_cur(2)) = lv
 SsSortLearned()
 ss_cur(2) = SsFindTag(place)
 SsStore()

end sub


sub SsDelete(byref message as String)

 if ss_box = 1 then
  if ss_cur(1) > ss_start_n then exit sub
  SsPush()
  message = ""
  for i as Integer = ss_cur(1) to ss_start_n - 1
   ss_start(i) = ss_start(i + 1)
  next
  ss_start_n -= 1
  ss_cur(1) = Min(ss_cur(1), ss_start_n + 1)
 else
  if ss_cur(2) > ss_learn_n then exit sub
  SsPush()
  for i as Integer = ss_cur(2) to ss_learn_n - 1
   ss_level(i) = ss_level(i + 1)
   ss_spell(i) = ss_spell(i + 1)
   ss_tag(i) = ss_tag(i + 1)
  next
  ss_learn_n -= 1
  ss_cur(2) = Min(ss_cur(2), ss_learn_n + 1)
 end if
 SsStore()

end sub


sub SsClear()

 if ss_box = 1 then
  if ss_start_n = 0 then exit sub
  if not ConfirmBox("Remove all " + str(ss_start_n) + " starting spells of this set?") then exit sub
  SsPush()
  ss_start_n = 0
  ss_cur(1) = 1
 else
  if ss_learn_n = 0 then exit sub
  if not ConfirmBox("Remove all " + str(ss_learn_n) + " learned spells of this set?") then exit sub
  SsPush()
  ss_learn_n = 0
  ss_cur(2) = 1
 end if
 SsStore()

end sub


sub SsMove(k as UInteger)

 dim n as Integer = iif(ss_box = 1, ss_start_n, ss_learn_n)
 dim v as Integer = ss_cur(ss_box)

 if n < ss_max then n += 1 'the Add a spell line below the last one

 select case k
  case UP_KEY: v -= 1
  case DOWN_KEY: v += 1
  case PAGEUP_KEY: v -= 10
  case PAGEDOWN_KEY: v += 10
  case HOME_KEY: v = 1
  case END_KEY: v = n
 end select
 ss_cur(ss_box) = Max(Min(v, n), 1)

end sub


sub EditSpellSetEntries(index as Integer)

 'One spell set in one screen, see the header of this file

 dim k as UInteger
 dim done as Boolean
 dim message as String

 ss_index = index
 SsLoad()
 ss_cur(1) = 1
 ss_cur(2) = 1
 ss_box = iif(ss_start_n = 0 and ss_learn_n > 0, 2, 1)
 ss_undo_count = 0

 do

  SsDrawEdit(message)
  message = ""
  k = getkey

  select case k

   case ESC_KEY
    done = true

   case TAB_KEY
    ss_box = 3 - ss_box
   case asc("1")
    ss_box = 1
   case asc("2")
    ss_box = 2

   case UP_KEY, DOWN_KEY, PAGEUP_KEY, PAGEDOWN_KEY, HOME_KEY, END_KEY
    SsMove(k)

   case LEFT_KEY, asc("-")
    if ss_box = 2 then SsChangeLevel(-1)
   case RIGHT_KEY, asc("+"), asc("=")
    if ss_box = 2 then
     SsChangeLevel(1)
    elseif k = RIGHT_KEY then
     ss_box = 2
    end if

   case ENTER_KEY
    if ss_box = 1 then SsEditStarting(message) else SsEditLearned(message)

   case INSERT_KEY, asc("a"), asc("A")
    if ss_box = 1 then SsAddStarting(message) else SsAddLearned(message)

   case DELETE_KEY, asc("d"), asc("D")
    SsDelete(message)

   case asc("c"), asc("C")
    SsClear()

   case 26 'Ctrl-Z
    if not SsUndo() then message = "Nothing to undo."

  end select

 loop until done

 SsStore()

end sub


sub EditSpellSets()

 dim select_spellset as BlueMenu
 dim x0 as Integer

 for i as Integer = 1 to spellsets.Length()
  select_spellset.AddOption(spellset_names.ItemAt(i))
 next
 x0 = select_spellset.options.Width() + 4

 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 do

  do
   ss_index = select_spellset.selected
   SsLoad()
   SsDrawBoxes(x0, 14, 22, 0, false)
   SsText("Enter edits the selected set", x0, 29, 23)
   SsText("Ctrl-C Ctrl-V copy a set, Ctrl-Z undo", x0, 30, 23)
  loop until ListInput(select_spellset, "spellsets")

  if not select_spellset.cancelled then
   EditSpellSetEntries(select_spellset.selected)
   line (0, 0)-(639, 463), RGB(0, 0, 0), bf 'nothing of the edit screen stays behind
  end if

 loop until select_spellset.cancelled

end sub
