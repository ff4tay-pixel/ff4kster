'Enemy AI editor: a full screen view of one AI, opened from "Edit AI" in the monster editor.
'
'An AI (1 to 254) is a list of pairs. The game goes through the pairs in order and runs the actions of the
'first pair whose conditions are all true. Each pair is a condition set (all its conditions must hold) and
'a script (the actions to do). The screen has three panels, one under the other, that each do one job:
'
'  1 WHICH AI    The AI this monster uses (Enter picks it from a list) and its pairs, one line each.
'  2 CONDITIONS  The condition set of the selected pair: pick another set, or change, add and remove its
'                conditions (WHEN, AND).
'  3 ACTIONS     The script of the selected pair: pick another script, or change, add and remove its
'                actions (THEN).
'
'Tab or 1 2 3 switch panel. The selected pair of panel 1 decides what panels 2 and 3 show.
'Sets, conditions and scripts are shared in the ROM: one script can serve many AIs. A change goes to every
'place that uses it; the "used Nx" counts show how many, and key U makes a private copy in an unused slot
'first. A new pair gets its own unused condition set, condition and script, so changing it touches nothing
'else. The footer shows how full the AI areas of the ROM are, so a save that would not fit is seen early.
'
'The font has no + = ( ) [ ] < > characters, so the help text is written around that.

const ai_undo_depth = 120

const ai_dialog_x = 8 'where the first menu of a change dialog opens
const ai_dialog_y = 9

type AIUndoEntry
 kind as Integer 'group, condition set, condition or script
 group as Integer
 id as Integer
 text as String
 cond as AICondition
 hp(1 to total_condition_hps) as UInteger
end type

dim shared ai_panel_y(1 to 3) as Integer = {4, 15, 27} 'top border of each panel
dim shared ai_panel_inner(1 to 3) as Integer = {9, 10, 17} 'text rows inside: the chooser line and the list under it
dim shared ai_cur(1 to 3) as Integer 'cursor row of each panel (0 is the chooser line, the last is the Add row)
dim shared ai_top(1 to 3) as Integer 'first list row shown
dim shared ai_focus as Integer 'the panel the keys act on
dim shared ai_pair as Integer 'the pair that panels 2 and 3 show
dim shared ai_message as String
dim shared ai_attack as Integer 'the monster's attack AI and reaction AI while editing
dim shared ai_reaction as Integer

dim shared ai_index as Integer
dim shared ai_lunar as Boolean
dim shared ai_monster as Integer
dim shared ai_on_reaction as Boolean

dim shared ai_set_uses(255) as Integer
dim shared ai_script_uses(255) as Integer
dim shared ai_condition_uses(255) as Integer

dim shared ai_undo(ai_undo_depth - 1) as AIUndoEntry
dim shared ai_undo_count as Integer
dim shared ai_undo_group as Integer

dim shared ai_clip_kind as Integer
dim shared ai_clip_a as Integer
dim shared ai_clip_b as Integer

dim shared ai_script_keys(255) as UInteger 'keys to feed the editor instead of the keyboard (for testing)
dim shared ai_script_count as Integer
dim shared ai_script_pos as Integer


function AIReadKey() as UInteger

 if ai_script_pos < ai_script_count then
  ai_script_pos += 1
  return ai_script_keys(ai_script_pos - 1)
 end if

 return getkey

end function


function AIByte(s as String, i as Integer) as Integer

 if i < 1 or i > len(s) then return 0
 return asc(mid(s, i, 1))

end function


function AISetId(p as Integer) as Integer

 return AIByte(aigroupconditions(ai_index), p)

end function


function AIScriptId(p as Integer) as Integer

 return AIByte(aigroupscripts(ai_index), p)

end function


function AIScriptIndex(id as Integer) as Integer

 return id + 1 + iif(ai_lunar, &h100, 0)

end function


function AIScriptExists(id as Integer) as Boolean

 return AIScriptIndex(id) <= ubound(scripts)

end function


function AISetString(id as Integer) as String

 if id + 1 > total_condition_sets then return ""
 return conditionsets(id + 1)

end function


function AITrim(s as String) as String

 'Cuts the blank padding off an FF4 text

 dim result as String = s

 do while len(result) > 0
  if asc(right(result, 1)) <> asc(FF4Text(" ")) then exit do
  result = left(result, len(result) - 1)
 loop

 return result

end function


sub AICountUses()

 dim id as Integer

 for i as Integer = 0 to 255
  ai_set_uses(i) = 0
  ai_script_uses(i) = 0
  ai_condition_uses(i) = 0
 next

 for g as Integer = 1 to total_ai_groups
  for j as Integer = 1 to len(aigroupconditions(g))
   ai_set_uses(AIByte(aigroupconditions(g), j)) += 1
   ai_script_uses(AIByte(aigroupscripts(g), j)) += 1
  next
 next

 for s as Integer = 1 to total_condition_sets
  for j as Integer = 1 to len(conditionsets(s))
   ai_condition_uses(AIByte(conditionsets(s), j)) += 1
  next
 next

end sub


'-------- undo --------

sub AIPushUndo(kind as Integer, id as Integer, text as String = "")

 dim e as AIUndoEntry ptr

 if ai_undo_count = ai_undo_depth then
  for i as Integer = 1 to ai_undo_depth - 1
   ai_undo(i - 1) = ai_undo(i)
  next
  ai_undo_count -= 1
 end if

 e = @ai_undo(ai_undo_count)
 e->kind = kind
 e->group = ai_undo_group
 e->id = id
 e->text = text
 if kind = 3 then
  e->cond = conditions(id)
  for i as Integer = 1 to total_condition_hps
   e->hp(i) = conditionhp(i)
  next
 end if
 ai_undo_count += 1

end sub


function AIScriptToText(n as Integer) as String

 dim result as String
 dim entry as AIScriptEntry ptr

 for j as Integer = 1 to scripts(n).Length()
  entry = scripts(n).PointerAt(j)
  result += chr(entry->function_call) + chr(entry->parameter)
 next

 return result

end function


sub AIScriptFromText(n as Integer, text as String)

 dim entry as AIScriptEntry ptr

 do while scripts(n).Length() > 0
  scripts(n).Remove(1)
 loop

 for j as Integer = 1 to len(text) step 2
  entry = callocate(SizeOf(AIScriptEntry))
  entry->function_call = asc(mid(text, j, 1))
  entry->parameter = asc(mid(text, j + 1, 1))
  scripts(n).Append(entry)
 next

end sub


sub AIPushGroup()

 'Remembers the pairs of the AI being edited (the two strings are kept as one)

 AIPushUndo(1, ai_index, aigroupconditions(ai_index) + chr(&hFF) + aigroupscripts(ai_index))

end sub


sub AIPushSet(id as Integer)

 if id + 1 <= total_condition_sets then AIPushUndo(2, id + 1, conditionsets(id + 1))

end sub


sub AIPushCondition(id as Integer)

 if id + 1 <= total_conditions then AIPushUndo(3, id + 1)

end sub


sub AIPushScript(n as Integer)

 if n <= ubound(scripts) then AIPushUndo(4, n, AIScriptToText(n))

end sub


function AIUndo() as Boolean

 'Undoes the last action (everything it changed). Returns false if there is nothing to undo.

 dim group_id as Integer
 dim cut as Integer

 if ai_undo_count = 0 then return false

 group_id = ai_undo(ai_undo_count - 1).group
 do while ai_undo_count > 0
  if ai_undo(ai_undo_count - 1).group <> group_id then exit do
  ai_undo_count -= 1
  with ai_undo(ai_undo_count)
   select case .kind
    case 1
     'both strings have the same length, so the separator is in the middle
     cut = (len(.text) - 1) \ 2 + 1
     aigroupconditions(.id) = left(.text, cut - 1)
     aigroupscripts(.id) = mid(.text, cut + 1)
    case 2
     conditionsets(.id) = .text
    case 3
     conditions(.id) = .cond
     for i as Integer = 1 to total_condition_hps
      conditionhp(i) = .hp(i)
     next
    case 4
     AIScriptFromText(.id, .text)
   end select
  end with
 loop

 return true

end function


'-------- dialogs --------

sub AINoRoom(what as String)

 InfoBox("There is no unused " + what + " to copy into.||Press any key", 10, 20)

end sub


function AIPickSet(current as Integer) as Integer

 'Choose one of the condition sets from a list. Returns its number (0 based), -1 if cancelled.

 dim m as BlueMenu
 dim label as String
 dim text as String
 dim c as UByte

 m = BlueMenu(2, 6)
 m.max_rows = 28
 m.title = "Choose a condition set. Yellow ones are not used"
 for i as Integer = 1 to total_condition_sets
  label = FF4Text(Pad(str(i), 2, true) + "  ")
  text = conditionsets(i)
  if len(text) = 0 then
   label += FF4Text("(empty)")
  else
   if AIByte(text, 1) < total_conditions then label += conditions(AIByte(text, 1) + 1).TextDescription()
   if len(text) > 1 then label += FF4Text("   and " + str(len(text) - 1) + " more")
  end if
  c = iif(ai_set_uses(i - 1) = 0, 14, 15)
  m.AddOption(left(label, 70), c)
 next
 m.ChangeSelected(current + 1)
 m.UserSelect()
 if m.cancelled then return -1
 return m.selected - 1

end function


function AIPickScript(current as Integer) as Integer

 'Choose one of the scripts of the bank in use from a list. Returns its number (0 based), -1 if cancelled.

 dim m as BlueMenu
 dim label as String
 dim entry as AIScriptEntry ptr
 dim n as Integer
 dim c as UByte

 m = BlueMenu(2, 6)
 m.max_rows = 28
 m.title = "Choose a script. Yellow ones are not used"
 for i as Integer = 0 to iif(ai_lunar, ubound(scripts) - &h100, &h100) - 1
  n = AIScriptIndex(i)
  label = FF4Text(Pad(str(i + 1), 3, true) + "  ")
  if scripts(n).Length() = 0 then
   label += FF4Text("(empty)")
  else
   entry = scripts(n).PointerAt(1)
   label += entry->TextDescription()
   if scripts(n).Length() > 1 then label += FF4Text("   and " + str(scripts(n).Length() - 1) + " more")
  end if
  c = iif(ai_script_uses(i) = 0, 14, 15)
  m.AddOption(left(label, 70), c)
 next
 m.ChangeSelected(current + 1)
 m.UserSelect()
 if m.cancelled then return -1
 return m.selected - 1

end function


function AIPickCondition(current as Integer) as Integer

 'Choose one of the 128 conditions from a list. Returns its number (0 based), -1 if cancelled.

 dim m as BlueMenu
 dim label as String
 dim c as UByte

 m = BlueMenu(2, 6)
 m.max_rows = 28
 m.title = "Choose a condition. Yellow ones are not used"
 for i as Integer = 1 to total_conditions
  label = FF4Text(Pad(str(i), 3, true) + "  ") + conditions(i).TextDescription()
  c = iif(ai_condition_uses(i - 1) = 0, 14, 15)
  m.AddOption(left(label, 70), c)
 next
 m.ChangeSelected(current + 1)
 m.UserSelect()
 if m.cancelled then return -1
 return m.selected - 1

end function


'-------- private copies --------

function AIFreeSet() as Integer

 for id as Integer = 0 to total_condition_sets - 1
  if ai_set_uses(id) = 0 then return id
 next

 return -1

end function


function AIFreeScript() as Integer

 'An unused script number in the bank in use (not 256, the byte the game reads as the end)

 for id as Integer = 0 to iif(ai_lunar, ubound(scripts) - &h100, &h100) - 1
  if id < 255 andalso ai_script_uses(id) = 0 then return id
 next

 return -1

end function


function AIFreeCondition() as Integer

 for id as Integer = 0 to total_conditions - 1
  if ai_condition_uses(id) = 0 then return id
 next

 return -1

end function


function AIMakeSetPrivate(p as Integer) as Boolean

 'Gives pair p its own copy of its condition set (a no-op if only this pair uses it)

 dim id as Integer = AISetId(p)
 dim new_id as Integer

 if ai_set_uses(id) <= 1 then return true

 new_id = AIFreeSet()
 if new_id < 0 then
  AINoRoom("condition set")
  return false
 end if

 AIPushGroup()
 AIPushSet(new_id)
 conditionsets(new_id + 1) = AISetString(id)
 mid(aigroupconditions(ai_index), p, 1) = chr(new_id)
 ai_set_uses(id) -= 1
 ai_set_uses(new_id) += 1

 return true

end function


function AIMakeScriptPrivate(p as Integer) as Boolean

 dim id as Integer = AIScriptId(p)
 dim new_id as Integer

 if not AIScriptExists(id) then return false
 if ai_script_uses(id) <= 1 then return true

 new_id = AIFreeScript()
 if new_id < 0 then
  AINoRoom("script")
  return false
 end if

 AIPushGroup()
 AIPushScript(AIScriptIndex(new_id))
 AIScriptFromText(AIScriptIndex(new_id), AIScriptToText(AIScriptIndex(id)))
 mid(aigroupscripts(ai_index), p, 1) = chr(new_id)
 ai_script_uses(id) -= 1
 ai_script_uses(new_id) += 1

 return true

end function


function AIMakeConditionPrivate(p as Integer, j as Integer) as Boolean

 'Gives condition j of pair p its own copy (the set is made private first, since the copy changes it)

 dim id as Integer
 dim new_id as Integer

 if not AIMakeSetPrivate(p) then return false
 id = AIByte(AISetString(AISetId(p)), j)
 if id >= total_conditions then return false
 if ai_condition_uses(id) <= 1 then return true

 new_id = AIFreeCondition()
 if new_id < 0 then
  AINoRoom("condition")
  return false
 end if

 AIPushSet(AISetId(p))
 AIPushCondition(new_id)
 conditions(new_id + 1) = conditions(id + 1)
 mid(conditionsets(AISetId(p) + 1), j, 1) = chr(new_id)
 ai_condition_uses(id) -= 1
 ai_condition_uses(new_id) += 1

 return true

end function


function AIReadySet(p as Integer) as Boolean

 'Changes to a shared condition set, script or condition go to every place that uses it
 ' (the "used Nx" counts show how many, and U makes a private copy first).

 return true

end function


function AIReadyScript(p as Integer) as Boolean

 return AIScriptExists(AIScriptId(p))

end function


function AIReadyCondition(p as Integer, j as Integer) as Boolean

 return AIByte(AISetString(AISetId(p)), j) < total_conditions

end function


'-------- drawing --------

function AIUsedBy() as String

 'The monsters that use the AI being shown, as a line of FF4 text

 dim result as String
 dim names as Integer
 dim total as Integer
 dim text as String

 for m as Integer = 1 to total_monsters
  text = ""
  if m = ai_monster then
   text = FF4Text("this one")
  elseif monsters(m).lunar = ai_lunar then
   if monsters(m).attack_sequence_group + 1 = ai_index then text = AITrim(monsters(m).name)
   if text = "" and monsters(m).has_reaction andalso monsters(m).reaction_index + 1 = ai_index then
    text = AITrim(monsters(m).name) + FF4Text(" reaction")
   end if
  end if
  if text <> "" then
   total += 1
   if len(result) < 48 then
    result += iif(len(result) > 0, FF4Text(", "), "") + text
    names += 1
   end if
  end if
 next

 if total = 0 then return FF4Text("no monster (not used)")
 if total > names then result += FF4Text("  and " + str(total - names) + " more")
 return result

end function


function AIAreaName(area as Integer) as String

 select case area
  case 1: return "groups"
  case 2: return "sets"
  case 3: return "scripts"
 end select

 return "moon"

end function


sub AIBand(y as Integer, c as UInteger)

 'Colors the background of a text row that is already drawn: the font draws its letters on the box
 ' color, so every pixel of that color in the row is replaced.

 dim img as Any ptr = ImageCreate(77 * 8 - 8, 8)
 dim pitch as Integer
 dim pixels as Any ptr
 dim px as UInteger ptr

 get (8, y * 8)-(77 * 8 - 1, y * 8 + 7), img
 imageinfo img, , , , pitch, pixels
 for r as Integer = 0 to 7
  px = cast(UInteger ptr, pixels + r * pitch)
  for i as Integer = 0 to 77 * 8 - 9
   if (px[i] and &hFFFFFF) = &h000060 then px[i] = c
  next
 next
 put (8, y * 8), img, pset
 ImageDestroy(img)

end sub


function AIPanelCount(panel as Integer) as Integer

 'The number of the last row of a panel's list, which is its "Add" row (row 0 is the chooser line above the list)

 dim n as Integer

 select case panel
  case 1
   return len(aigroupconditions(ai_index)) + 1
  case 2
   if ai_pair < 1 then return 0
   return len(AISetString(AISetId(ai_pair))) + 1
  case else
   if ai_pair < 1 then return 0
   if not AIScriptExists(AIScriptId(ai_pair)) then return 0
   n = AIScriptIndex(AIScriptId(ai_pair))
   return scripts(n).Length() + 1
 end select

end function


function AIFirstCondition(p as Integer) as String

 'FF4 text of the first condition of pair p

 dim slot as Integer = AIByte(AISetString(AISetId(p)), 1)

 if len(AISetString(AISetId(p))) = 0 or slot >= total_conditions then return FF4Text("(no conditions)")
 return conditions(slot + 1).TextDescription()

end function


function AIFirstAction(p as Integer) as String

 dim n as Integer
 dim entry as AIScriptEntry ptr

 if not AIScriptExists(AIScriptId(p)) then return FF4Text("(no such script)")
 n = AIScriptIndex(AIScriptId(p))
 if scripts(n).Length() = 0 then return FF4Text("(no actions)")
 entry = scripts(n).PointerAt(1)

 return entry->TextDescription()

end function


sub AIDrawRowA(idx as Integer, y as Integer)

 dim pair_count as Integer = len(aigroupconditions(ai_index))

 if idx = 0 then
  LuText("AI " + str(ai_index) + " of " + str(total_ai_groups), 2, y, 14)
  LuText(iif(ai_on_reaction, "reaction AI", "attack AI") + ", " + str(pair_count) + iif(pair_count = 1, " pair", " pairs"), 18, y, 23)
  LuText("Enter picks the AI from a list", 46, y, 23)
 elseif idx <= pair_count then
  LuText("Pair " + str(idx), 2, y, 15)
  LuText("WHEN", 10, y, 21)
  WriteText(left(AIFirstCondition(idx), 24), 16, y, 15)
  LuText("THEN", 42, y, 22)
  WriteText(left(AIFirstAction(idx), 24), 48, y, 15)
 else
  LuText("Add a new pair of conditions and actions", 2, y, 10)
 end if

end sub


sub AIDrawRowB(idx as Integer, y as Integer)

 dim sid as Integer
 dim slot as Integer
 dim uses as Integer
 dim n as Integer

 if ai_pair < 1 then
  if idx = 0 then LuText("Pick a pair in panel 1 first", 2, y, 12)
  exit sub
 end if

 sid = AISetId(ai_pair)
 n = len(AISetString(sid))
 if idx = 0 then
  uses = ai_set_uses(sid)
  LuText("Condition set " + str(sid + 1) + " of pair " + str(ai_pair), 2, y, 21)
  LuText("used " + str(uses) + "x", 36, y, iif(uses > 1, 14, 23))
  LuText("Enter picks another set", 50, y, 23)
 elseif idx <= n then
  slot = AIByte(AISetString(sid), idx)
  LuText(iif(idx = 1, "WHEN", "AND "), 4, y, 21)
  if slot < total_conditions then
   WriteText(left(conditions(slot + 1).TextDescription(), 52), 10, y, 15)
   uses = ai_condition_uses(slot)
   LuText("used " + str(uses) + "x", 66, y, iif(uses > 1, 14, 23))
  else
   LuText("Unknown condition " + str(slot), 10, y, 12)
  end if
 else
  LuText("Add a condition", 10, y, 10)
 end if

end sub


sub AIDrawRowC(idx as Integer, y as Integer)

 dim id as Integer
 dim uses as Integer
 dim n as Integer
 dim entry as AIScriptEntry ptr

 if ai_pair < 1 then
  if idx = 0 then LuText("Pick a pair in panel 1 first", 2, y, 12)
  exit sub
 end if

 id = AIScriptId(ai_pair)
 if idx = 0 then
  uses = ai_script_uses(id)
  LuText("Script " + str(id + 1) + " of pair " + str(ai_pair), 2, y, 22)
  LuText("used " + str(uses) + "x", 36, y, iif(uses > 1, 14, 23))
  LuText("Enter picks another script", 50, y, 23)
  if not AIScriptExists(id) then LuText("does not exist in the lunar bank", 2, y + 1, 12)
 elseif AIScriptExists(id) then
  n = AIScriptIndex(id)
  if idx <= scripts(n).Length() then
   entry = scripts(n).PointerAt(idx)
   LuText("THEN", 4, y, 22)
   WriteText(left(entry->TextDescription(), 62), 10, y, 15)
  else
   LuText("Add an action", 10, y, 10)
  end if
 end if

end sub


sub AIDrawPanel(panel as Integer)

 dim y0 as Integer = ai_panel_y(panel)
 dim scroll_rows as Integer = ai_panel_inner(panel) - 1
 dim count as Integer = AIPanelCount(panel)
 dim focused as Boolean = (ai_focus = panel)
 dim accent as UByte = iif(panel = 1, 14, iif(panel = 2, 21, 22))
 dim title as String
 dim y as Integer
 dim selected_color as UInteger = iif(focused, RGB(95, 115, 205), RGB(50, 65, 135))

 BlueBox(0, y0, 78, ai_panel_inner(panel))
 select case panel
  case 1: title = " 1  WHICH AI  "
  case 2: title = " 2  CONDITIONS, WHEN  "
  case else: title = " 3  SCRIPT ACTIONS, THEN  "
 end select
 LuText(title, 1, y0, iif(focused, accent, 23))
 if ai_top(panel) > 1 then LuText("more above", 64, y0, 14)
 if ai_top(panel) + scroll_rows - 1 < count then LuText("more below", 64, y0 + ai_panel_inner(panel) + 1, 14)

 'the chooser line (row 0) stays on top
 y = y0 + 1
 select case panel
  case 1: AIDrawRowA(0, y)
  case 2: AIDrawRowB(0, y)
  case else: AIDrawRowC(0, y)
 end select
 AIBand(y, iif(ai_cur(panel) = 0, selected_color, RGB(30, 45, 120)))
 if focused and ai_cur(panel) = 0 then DrawLetter(20, 0, y)

 'the list under it
 for k as Integer = ai_top(panel) to Min(ai_top(panel) + scroll_rows - 1, count)
  y = y0 + 2 + k - ai_top(panel)
  select case panel
   case 1: AIDrawRowA(k, y)
   case 2: AIDrawRowB(k, y)
   case else: AIDrawRowC(k, y)
  end select
  if k = ai_cur(panel) then
   AIBand(y, selected_color)
   if focused then DrawLetter(20, 0, y)
  end if
 next

end sub


function AIHint() as String

 'One line that says what the keys do on the line the cursor is on

 dim idx as Integer = ai_cur(ai_focus)
 dim count as Integer = AIPanelCount(ai_focus)

 select case ai_focus
  case 1
   if idx = 0 then return "Enter picks which AI this monster uses. N P step to the next or last AI."
   if idx < count then return "Enter goes to its conditions. Insert adds a pair after it. Delete removes it."
   return "Enter adds a pair. The first pair whose conditions are all true runs."
  case 2
   if ai_pair < 1 then return "This AI has no pairs. Add one in panel 1."
   if idx = 0 then return "Enter picks a condition set for this pair from a list."
   if idx < count then return "Enter changes this condition. S picks another one. Insert adds one."
   return "Enter adds a condition. All the conditions of a set must be true."
  case else
   if ai_pair < 1 then return "This AI has no pairs. Add one in panel 1."
   if idx = 0 then return "Enter picks a script for this pair from a list."
   if idx < count then return "Enter changes this action. Insert adds one after it."
   return "Enter adds an action. The actions run in order, top to bottom."
 end select

end function


sub AIDraw(message as String)

 dim info as String
 dim space_text as String
 dim over as Boolean
 dim title as String
 dim footer_y as Integer = 46
 dim uses as Integer

 screenlock
 line (0, 0)-(639, 479), RGB(0, 0, 0), bf

 'Title: whose AI, and which monsters use it
 BlueBox(0, 0, 78, 2)
 WriteText(FF4Text("Monster: ") + AITrim(monsters(ai_monster).name), 1, 1, 15)
 title = iif(ai_on_reaction, "Reaction AI ", "Attack AI ") + str(ai_index) + " of " + str(total_ai_groups) + "   " + iif(ai_lunar, "LUNAR bank", "Regular bank")
 LuText(title, 38, 1, iif(ai_lunar, 12, 14))
 LuText("Used by: ", 0, 2, 23)
 WriteText(left(AIUsedBy(), 66), 10, 2, 10)

 for panel as Integer = 1 to 3
  AIDrawPanel(panel)
 next

 'Footer: what the line does, how shared it is, how much room is left, and the keys
 BlueBox(0, footer_y, 78, 9)
 info = AIHint()
 if ai_pair > 0 then
  if ai_focus = 2 then
   uses = ai_set_uses(AISetId(ai_pair))
   if uses > 1 and ai_cur(2) = 0 then info = "This set is used by " + str(uses) + " pairs, a change reaches all of them. U copies it."
   if ai_cur(2) >= 1 and ai_cur(2) < AIPanelCount(2) then
    uses = ai_condition_uses(AIByte(AISetString(AISetId(ai_pair)), ai_cur(2)))
    if uses > 1 then info = "This condition is used by " + str(uses) + " places, a change reaches all. U copies it."
   end if
  elseif ai_focus = 3 then
   uses = ai_script_uses(AIScriptId(ai_pair))
   if uses > 1 and ai_cur(3) < AIPanelCount(3) then info = "This script is used by " + str(uses) + " pairs, a change reaches all of them. U copies it."
  end if
 end if
 if message <> "" then info = message
 LuText(info, 0, footer_y + 1, 14)

 space_text = "AI room used:"
 for area as Integer = 1 to 4
  space_text += " " + AIAreaName(area) + " " + str(AIBytes(area)) + "/" + str(AIRoom(area))
  if AIBytes(area) > AIRoom(area) then over = true
 next
 LuText(space_text, 0, footer_y + 2, iif(over, 12, 23))
 if over then LuText("Over the limit: Save ROM will refuse to save until there is less AI data.", 0, footer_y + 3, 12)

 LuText("Tab or 1 2 3: switch panel.  Arrows PgUp PgDn Home End: move.", 0, footer_y + 5, 23)
 LuText("Enter: choose or change.  Insert: add.  Delete: remove.  U: own copy.", 0, footer_y + 6, 23)
 LuText("N P: other AI.  G: go to AI.  L: bank.  R: reaction AI.  S: other condition.", 0, footer_y + 7, 23)
 LuText("Ctrl-C Ctrl-V: copy, paste.  Ctrl-Z: undo.  Esc: back to the monsters.", 0, footer_y + 8, 23)
 screenunlock

end sub


'-------- editing --------

sub AIInsertPair(after_p as Integer, set_id as Integer, script_id as Integer)

 AIPushGroup()
 aigroupconditions(ai_index) = left(aigroupconditions(ai_index), after_p) + chr(set_id) + mid(aigroupconditions(ai_index), after_p + 1)
 aigroupscripts(ai_index) = left(aigroupscripts(ai_index), after_p) + chr(script_id) + mid(aigroupscripts(ai_index), after_p + 1)

end sub


function AINewPair(after_p as Integer) as Boolean

 'A new pair with its own condition set (one "no condition", which is always true), its own condition
 ' and its own script (one "Do nothing"), all in unused slots, so editing it touches nothing else

 dim set_id as Integer = AIFreeSet()
 dim cond_id as Integer = AIFreeCondition()
 dim script_id as Integer = AIFreeScript()

 if set_id < 0 or cond_id < 0 or script_id < 0 then
  AINoRoom("condition set, condition or script left")
  return false
 end if

 AIPushCondition(cond_id)
 AIPushSet(set_id)
 AIPushScript(AIScriptIndex(script_id))
 conditions(cond_id + 1).condition = 12
 conditions(cond_id + 1).xx = 0
 conditions(cond_id + 1).yy = 0
 conditions(cond_id + 1).zz = 0
 conditionsets(set_id + 1) = chr(cond_id)
 AIScriptFromText(AIScriptIndex(script_id), chr(&hE1) + chr(0))
 AIInsertPair(after_p, set_id, script_id)

 return true

end function


function AIInsertAction(p as Integer, place as Integer, function_call as Integer, parameter as Integer) as Boolean

 'Puts an action at position place of pair p's script

 dim entry as AIScriptEntry ptr
 dim n as Integer

 if not AIReadyScript(p) then return false

 n = AIScriptIndex(AIScriptId(p))
 AIPushScript(n)
 entry = callocate(SizeOf(AIScriptEntry))
 entry->function_call = function_call
 entry->parameter = parameter
 scripts(n).Insert(place, entry)

 return true

end function


function AIInsertCondition(p as Integer, place as Integer, slot as Integer) as Boolean

 'Puts a reference to condition slot at position place of pair p's condition set

 if not AIReadySet(p) then return false

 AIPushSet(AISetId(p))
 conditionsets(AISetId(p) + 1) = left(conditionsets(AISetId(p) + 1), place - 1) + chr(slot) + mid(conditionsets(AISetId(p) + 1), place)

 return true

end function


function AIAddNewAction(p as Integer, place as Integer) as Boolean

 'Adds an action and opens its editor at once; cancelling the editor takes it away again

 dim entry as AIScriptEntry ptr
 dim n as Integer

 if not AIInsertAction(p, place, &hE1, 0) then return false

 n = AIScriptIndex(AIScriptId(p))
 entry = scripts(n).PointerAt(place)
 if not AIEditScriptEntry(entry, ai_dialog_x, ai_dialog_y) then
  AIUndo()
  return false
 end if

 return true

end function


function AIAddNewCondition(p as Integer, place as Integer) as Boolean

 'Adds a condition in an unused slot (starting as "no condition") and opens its editor at once

 dim slot as Integer = AIFreeCondition()

 if slot < 0 then
  AINoRoom("condition")
  return false
 end if

 if not AIReadySet(p) then return false

 AIPushCondition(slot)
 conditions(slot + 1).condition = 12
 conditions(slot + 1).xx = 0
 conditions(slot + 1).yy = 0
 conditions(slot + 1).zz = 0
 if not AIInsertCondition(p, place, slot) then return false
 if not AIEditCondition(slot + 1, ai_dialog_x, ai_dialog_y) then
  AIUndo()
  return false
 end if

 return true

end function


function AIPickAI() as Integer

 'Choose which AI the monster uses from a list of all of them. Returns 1 to 254, 0 if cancelled.

 dim m as BlueMenu
 dim users(1 to total_ai_groups) as Integer
 dim names(1 to total_ai_groups) as String
 dim label as String
 dim index as Integer
 dim is_lunar as Boolean
 dim name_text as String
 dim pair_count as Integer
 dim reaction as Integer

 for mm as Integer = 1 to total_monsters
  if mm = ai_monster then
   index = ai_attack
   is_lunar = ai_lunar
   name_text = FF4Text("this monster")
  else
   index = monsters(mm).attack_sequence_group + 1
   is_lunar = monsters(mm).lunar
   name_text = AITrim(monsters(mm).name)
  end if
  if index >= 1 and index <= total_ai_groups and is_lunar = ai_lunar then
   users(index) += 1
   if len(names(index)) < 36 then names(index) += iif(len(names(index)) > 0, FF4Text(", "), "") + name_text
  end if

  'the reaction AI counts as use too
  if mm = ai_monster then
   reaction = ai_reaction
  elseif monsters(mm).has_reaction then
   reaction = monsters(mm).reaction_index + 1
  else
   reaction = 0
  end if
  if reaction >= 1 and reaction <= total_ai_groups and is_lunar = ai_lunar and reaction <> index then
   users(reaction) += 1
   if len(names(reaction)) < 36 then names(reaction) += iif(len(names(reaction)) > 0, FF4Text(", "), "") + name_text + FF4Text(" reaction")
  end if
 next

 m = BlueMenu(2, 6)
 m.max_rows = 28
 m.title = iif(ai_on_reaction, "Pick the reaction AI. Yellow ones are not used", "Pick the AI of this monster. Yellow ones are not used")
 for i as Integer = 1 to total_ai_groups
  pair_count = len(aigroupconditions(i))
  label = FF4Text(Pad(str(i), 3, true) + "  ")
  if users(i) = 0 then
   label += FF4Text("no monster")
  else
   label += names(i)
   if users(i) > 1 and len(names(i)) >= 36 then label += FF4Text("  and more")
  end if
  m.AddOption(left(label, 62) + FF4Text(Pad(str(pair_count) + iif(pair_count = 1, " pair", " pairs"), 8, true)), iif(users(i) = 0, 14, 15))
 next
 m.ChangeSelected(ai_index)
 m.UserSelect()
 if m.cancelled then return 0

 return m.selected

end function


sub AIChangeAI(new_index as Integer)

 'Shows another AI (and makes it the one the monster uses). A new undo history starts.

 ai_index = new_index
 if ai_on_reaction then ai_reaction = new_index else ai_attack = new_index
 ai_cur(1) = iif(len(aigroupconditions(new_index)) > 0, 1, 0)
 ai_cur(2) = 0
 ai_cur(3) = 0
 for panel as Integer = 1 to 3
  ai_top(panel) = 1
 next
 ai_pair = 0
 ai_undo_count = 0

end sub


sub AIMoveCursor(k as UInteger)

 dim count as Integer = AIPanelCount(ai_focus)
 dim scroll_rows as Integer = ai_panel_inner(ai_focus) - 1
 dim v as Integer = ai_cur(ai_focus)

 select case k
  case UP_KEY: v -= 1
  case DOWN_KEY: v += 1
  case PAGEUP_KEY: v -= scroll_rows - 1
  case PAGEDOWN_KEY: v += scroll_rows - 1
  case HOME_KEY: v = 0
  case END_KEY: v = count
 end select

 if v < 0 then v = 0
 if v > count then v = count
 ai_cur(ai_focus) = v

end sub


sub AIKeyPairs(k as UInteger)

 'Keys in panel 1: the pairs of the AI

 dim pair_count as Integer = len(aigroupconditions(ai_index))
 dim idx as Integer = ai_cur(1)
 dim v as Integer

 select case k

  case ENTER_KEY
   if idx = 0 then
    v = AIPickAI()
    if v > 0 and v <> ai_index then AIChangeAI(v)
   elseif idx <= pair_count then
    ai_focus = 2
   elseif AINewPair(pair_count) then
    ai_cur(1) = pair_count + 1
    ai_message = "Pair added. Its conditions are in panel 2 and its actions in panel 3."
   end if

  case INSERT_KEY
   v = iif(idx >= 1 and idx <= pair_count, idx, iif(idx = 0, 0, pair_count))
   if AINewPair(v) then ai_cur(1) = v + 1

  case DELETE_KEY
   if idx >= 1 and idx <= pair_count then
    if pair_count = 1 then
     ai_message = "An AI needs at least one pair."
    elseif ConfirmBox("Delete this pair of conditions and actions?") then
     AIPushGroup()
     aigroupconditions(ai_index) = left(aigroupconditions(ai_index), idx - 1) + mid(aigroupconditions(ai_index), idx + 1)
     aigroupscripts(ai_index) = left(aigroupscripts(ai_index), idx - 1) + mid(aigroupscripts(ai_index), idx + 1)
     ai_cur(1) = Max(idx - 1, 1)
    end if
   end if

  case asc("u"), asc("U")
   if idx >= 1 and idx <= pair_count then
    if AIMakeSetPrivate(idx) and AIMakeScriptPrivate(idx) then ai_message = "This pair now has its own condition set and script."
   end if

  case 3 'Ctrl-C
   if idx >= 1 and idx <= pair_count then
    ai_clip_kind = 1
    ai_clip_a = AISetId(idx)
    ai_clip_b = AIScriptId(idx)
    ai_message = "Copied the pair."
   end if

  case 22 'Ctrl-V
   if ai_clip_kind = 1 then
    v = iif(idx >= 1 and idx <= pair_count, idx, iif(idx = 0, 0, pair_count))
    AIInsertPair(v, ai_clip_a, ai_clip_b)
    ai_cur(1) = v + 1
   else
    ai_message = "Copy a pair first (Ctrl-C on a pair in this panel)."
   end if

 end select

end sub


sub AIKeyConditions(k as UInteger)

 'Keys in panel 2: the conditions of the selected pair

 dim p as Integer = ai_pair
 dim idx as Integer = ai_cur(2)
 dim n as Integer
 dim slot as Integer
 dim v as Integer

 if p < 1 then
  ai_message = "This AI has no pairs. Add one in panel 1."
  exit sub
 end if
 n = len(AISetString(AISetId(p)))

 select case k

  case ENTER_KEY, asc("s"), asc("S")
   if idx = 0 then
    if k = ENTER_KEY then
     v = AIPickSet(AISetId(p))
     if v >= 0 and v <> AISetId(p) then
      AIPushGroup()
      mid(aigroupconditions(ai_index), p, 1) = chr(v)
      ai_cur(2) = 0
     end if
    end if
   elseif idx <= n then
    slot = AIByte(AISetString(AISetId(p)), idx)
    if k = ENTER_KEY then
     if AIReadyCondition(p, idx) then
      AIPushCondition(slot)
      if not AIEditCondition(slot + 1, ai_dialog_x, ai_dialog_y) then ai_undo_count -= 1
     end if
    else
     v = AIPickCondition(slot)
     if v >= 0 and v <> slot then
      AIPushSet(AISetId(p))
      mid(conditionsets(AISetId(p) + 1), idx, 1) = chr(v)
     end if
    end if
   elseif k = ENTER_KEY then
    if AIAddNewCondition(p, n + 1) then
     ai_cur(2) = n + 1
     ai_message = "Condition added."
    end if
   end if

  case INSERT_KEY
   v = iif(idx = 0, 1, iif(idx <= n, idx + 1, n + 1))
   if AIAddNewCondition(p, v) then ai_cur(2) = v

  case DELETE_KEY
   if idx >= 1 and idx <= n then
    if n = 1 then
     ai_message = "A pair needs at least one condition (use No condition for always)."
    else
     AIPushSet(AISetId(p))
     conditionsets(AISetId(p) + 1) = left(conditionsets(AISetId(p) + 1), idx - 1) + mid(conditionsets(AISetId(p) + 1), idx + 1)
     ai_cur(2) = Max(Min(idx, n - 1), 1)
    end if
   end if

  case asc("u"), asc("U")
   if idx = 0 then
    if AIMakeSetPrivate(p) then ai_message = "This pair now has its own condition set."
   elseif idx <= n then
    if AIMakeConditionPrivate(p, idx) then ai_message = "This condition is now its own copy."
   end if

  case 3 'Ctrl-C
   if idx >= 1 and idx <= n then
    ai_clip_kind = 2
    ai_clip_a = AIByte(AISetString(AISetId(p)), idx)
    ai_message = "Copied the condition."
   end if

  case 22 'Ctrl-V
   if ai_clip_kind = 2 then
    v = iif(idx = 0, 1, iif(idx <= n, idx + 1, n + 1))
    if AIInsertCondition(p, v, ai_clip_a) then ai_cur(2) = v
   else
    ai_message = "Copy a condition first (Ctrl-C on a condition in this panel)."
   end if

 end select

end sub


sub AIKeyActions(k as UInteger)

 'Keys in panel 3: the actions of the selected pair's script

 dim p as Integer = ai_pair
 dim idx as Integer = ai_cur(3)
 dim n as Integer
 dim sn as Integer
 dim v as Integer
 dim entry as AIScriptEntry ptr

 if p < 1 then
  ai_message = "This AI has no pairs. Add one in panel 1."
  exit sub
 end if

 if AIScriptExists(AIScriptId(p)) then
  sn = AIScriptIndex(AIScriptId(p))
  n = scripts(sn).Length()
 else
  n = -1
 end if

 select case k

  case ENTER_KEY
   if idx = 0 then
    v = AIPickScript(AIScriptId(p))
    if v >= 0 and v <> AIScriptId(p) then
     AIPushGroup()
     mid(aigroupscripts(ai_index), p, 1) = chr(v)
     ai_cur(3) = 0
    end if
   elseif n >= 0 and idx <= n then
    if AIReadyScript(p) then
     AIPushScript(sn)
     entry = scripts(sn).PointerAt(idx)
     if not AIEditScriptEntry(entry, ai_dialog_x, ai_dialog_y) then ai_undo_count -= 1
    end if
   elseif n >= 0 then
    if AIAddNewAction(p, n + 1) then
     ai_cur(3) = n + 1
     ai_message = "Action added."
    end if
   end if

  case INSERT_KEY
   if n >= 0 then
    v = iif(idx = 0, 1, iif(idx <= n, idx + 1, n + 1))
    if AIAddNewAction(p, v) then ai_cur(3) = v
   end if

  case DELETE_KEY
   if idx >= 1 and idx <= n then
    if AIReadyScript(p) then
     AIPushScript(sn)
     scripts(sn).Remove(idx)
     ai_cur(3) = Max(Min(idx, n - 1), 1)
    end if
   end if

  case asc("u"), asc("U")
   if n >= 0 then
    if AIMakeScriptPrivate(p) then ai_message = "This pair now has its own script."
   end if

  case 3 'Ctrl-C
   if idx >= 1 and idx <= n then
    entry = scripts(sn).PointerAt(idx)
    ai_clip_kind = 3
    ai_clip_a = entry->function_call
    ai_clip_b = entry->parameter
    ai_message = "Copied the action."
   end if

  case 22 'Ctrl-V
   if ai_clip_kind = 3 and n >= 0 then
    v = iif(idx = 0, 1, iif(idx <= n, idx + 1, n + 1))
    if AIInsertAction(p, v, ai_clip_a, ai_clip_b) then ai_cur(3) = v
   elseif n >= 0 then
    ai_message = "Copy an action first (Ctrl-C on an action in this panel)."
   end if

 end select

end sub


sub EditMonsterAI(byref attack_index as Integer, byref reaction_index as Integer, byref lunar_flag as Boolean, monster_number as Integer, start_on_reaction as Boolean = false)

 dim k as UInteger
 dim done as Boolean
 dim go_text as String
 dim v as Integer
 dim pair_count as Integer
 dim last_pair as Integer
 dim last_ai as Integer
 dim count as Integer
 dim scroll_rows as Integer

 ai_monster = monster_number
 ai_lunar = lunar_flag
 ai_attack = attack_index
 ai_reaction = reaction_index
 ai_on_reaction = start_on_reaction and reaction_index > 0
 ai_index = iif(ai_on_reaction, reaction_index, attack_index)
 ai_undo_count = 0
 ai_clip_kind = 0
 ai_focus = 1
 ai_pair = 0
 ai_message = ""
 AIChangeAI(ai_index)

 do
  AICountUses()

  'the pair the other two panels show follows the cursor of panel 1
  pair_count = len(aigroupconditions(ai_index))
  if ai_cur(1) >= 1 and ai_cur(1) <= pair_count then ai_pair = ai_cur(1)
  if ai_pair > pair_count then ai_pair = pair_count
  if ai_pair < 1 and pair_count >= 1 then ai_pair = 1
  if last_pair <> ai_pair or last_ai <> ai_index then
   ai_cur(2) = 0
   ai_cur(3) = 0
   ai_top(2) = 1
   ai_top(3) = 1
   last_pair = ai_pair
   last_ai = ai_index
  end if

  for panel as Integer = 1 to 3
   count = AIPanelCount(panel)
   scroll_rows = ai_panel_inner(panel) - 1
   if ai_cur(panel) > count then ai_cur(panel) = count
   if ai_cur(panel) < 0 then ai_cur(panel) = 0
   if ai_cur(panel) >= 1 then
    if ai_cur(panel) < ai_top(panel) then ai_top(panel) = ai_cur(panel)
    if ai_cur(panel) > ai_top(panel) + scroll_rows - 1 then ai_top(panel) = ai_cur(panel) - scroll_rows + 1
   end if
   if ai_top(panel) < 1 then ai_top(panel) = 1
  next

  AIDraw(ai_message)
  ai_message = ""
  k = AIReadKey()
  ai_undo_group += 1

  select case k

   case ESC_KEY
    done = true

   case TAB_KEY
    ai_focus = ai_focus mod 3 + 1
   case asc("1"), asc("2"), asc("3")
    ai_focus = k - asc("0")

   case UP_KEY, DOWN_KEY, PAGEUP_KEY, PAGEDOWN_KEY, HOME_KEY, END_KEY
    AIMoveCursor(k)

   case asc("n"), asc("N")
    if ai_index < total_ai_groups then AIChangeAI(ai_index + 1)
   case asc("p"), asc("P")
    if ai_index > 1 then AIChangeAI(ai_index - 1)
   case asc("g"), asc("G")
    go_text = PromptLine("Go to AI number, 1 to " + str(total_ai_groups) + ":", 3)
    v = val(go_text)
    if go_text <> "" and v >= 1 and v <= total_ai_groups then AIChangeAI(v)
   case asc("l"), asc("L")
    ai_lunar = not ai_lunar
    AIChangeAI(ai_index)
   case asc("r"), asc("R")
    if ai_reaction > 0 then
     ai_on_reaction = not ai_on_reaction
     AIChangeAI(iif(ai_on_reaction, ai_reaction, ai_attack))
    else
     ai_message = "This monster has no reaction AI (turn it on in the monster's extras)."
    end if

   case 26 'Ctrl-Z
    if not AIUndo() then ai_message = "Nothing to undo."

   case else
    select case ai_focus
     case 1: AIKeyPairs(k)
     case 2: AIKeyConditions(k)
     case else: AIKeyActions(k)
    end select

  end select

 loop until done

 attack_index = ai_attack
 reaction_index = ai_reaction
 lunar_flag = ai_lunar
 cls

end sub
