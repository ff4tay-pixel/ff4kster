'Enemy AI editor: a full screen view of one AI, opened from "Edit AI" in the monster editor.
'
'An AI (1 to 254) is a list of pairs. The game goes through the pairs in order and runs the actions of the
'first pair whose conditions are all true. Each pair is a condition set (all its conditions must hold) and
'a script (the actions to do). Everything is shown as one list that the cursor walks line by line:
'
'  PAIR 1   Condition set 12, used 3x   Script 34, used 2x
'     WHEN unit self has 1000 HP or less
'     AND  takes damage
'           Add a condition
'     THEN Cast Fire on single
'     THEN Target self
'           Add an action
'
'The Add rows add a part and open its editor; Esc in the first menu takes the new part away again. A new pair
'gets its own unused condition set, condition and script, so changing it touches nothing else.
'
'Sets, conditions and scripts are shared in the ROM: one script can serve many AIs. A change goes to every place
'that uses it; the "used Nx" counts show how many, and key U makes a private copy in an unused slot first. The footer shows how full the AI areas of the ROM are, so a save that would not fit is seen early.
'
'The font has no + = ( ) [ ] < > characters, so the help text is written around that.

const ai_visible = 38
const ai_box_y = 4
const ai_first_y = 5
const ai_max_lines = 800
const ai_undo_depth = 120

'what a line of the list is
const ai_line_pair = 1 'pair header
const ai_line_condition = 2
const ai_line_action = 3
const ai_line_addcond = 4 'the row that adds a condition
const ai_line_addaction = 5 'the row that adds an action
const ai_line_addpair = 6 'the row that adds a pair
const ai_line_spacer = 7 'blank line between pairs
const ai_line_missing = 8 'the script is not in the lunar bank

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

dim shared ai_line_kind(1 to ai_max_lines) as Integer
dim shared ai_line_pair_of(1 to ai_max_lines) as Integer
dim shared ai_line_item(1 to ai_max_lines) as Integer
dim shared ai_line_count as Integer

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


'-------- the list of lines --------

sub AIAddLine(kind as Integer, p as Integer, item as Integer)

 if ai_line_count >= ai_max_lines then exit sub
 ai_line_count += 1
 ai_line_kind(ai_line_count) = kind
 ai_line_pair_of(ai_line_count) = p
 ai_line_item(ai_line_count) = item

end sub


sub AIBuildLines()

 dim sid as Integer
 dim n as Integer

 ai_line_count = 0
 for p as Integer = 1 to len(aigroupconditions(ai_index))
  sid = AISetId(p)
  if p > 1 then AIAddLine(ai_line_spacer, p, 0)
  AIAddLine(ai_line_pair, p, 0)
  for j as Integer = 1 to len(AISetString(sid))
   AIAddLine(ai_line_condition, p, j)
  next
  AIAddLine(ai_line_addcond, p, len(AISetString(sid)) + 1)
  if AIScriptExists(AIScriptId(p)) then
   n = AIScriptIndex(AIScriptId(p))
   for j as Integer = 1 to scripts(n).Length()
    AIAddLine(ai_line_action, p, j)
   next
   AIAddLine(ai_line_addaction, p, scripts(n).Length() + 1)
  else
   AIAddLine(ai_line_missing, p, 0)
  end if
 next

 AIAddLine(ai_line_spacer, 0, 0)
 AIAddLine(ai_line_addpair, 0, 0)

end sub


function AIFindLine(kind as Integer, p as Integer, item as Integer) as Integer

 'The line number of a pair's header, condition or action; 0 if there is no such line

 for i as Integer = 1 to ai_line_count
  if ai_line_kind(i) = kind and ai_line_pair_of(i) = p and ai_line_item(i) = item then return i
 next

 return 0

end function


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


sub AIDrawLine(i as Integer, y as Integer, selected as Boolean)

 dim p as Integer = ai_line_pair_of(i)
 dim j as Integer = ai_line_item(i)
 dim sid as Integer
 dim uses as Integer
 dim slot as Integer
 dim entry as AIScriptEntry ptr
 dim kind as Integer = ai_line_kind(i)

 select case kind

  case ai_line_pair
   sid = AISetId(p)
   LuText("PAIR " + str(p), 2, y, 14)
   uses = ai_set_uses(sid)
   LuText("Condition set " + str(sid + 1) + ", used " + str(uses) + "x", 14, y, iif(uses > 1, 14, 23))
   uses = ai_script_uses(AIScriptId(p))
   LuText("Script " + str(AIScriptId(p) + 1) + ", used " + str(uses) + "x", 44, y, iif(uses > 1, 14, 23))

  case ai_line_condition
   slot = AIByte(AISetString(AISetId(p)), j)
   LuText(iif(j = 1, "WHEN", "AND "), 4, y, 21)
   if slot < total_conditions then
    WriteText(left(conditions(slot + 1).TextDescription(), 52), 10, y, 15)
    uses = ai_condition_uses(slot)
    LuText("used " + str(uses) + "x", 66, y, iif(uses > 1, 14, 23))
   else
    LuText("Unknown condition " + str(slot), 10, y, 12)
   end if

  case ai_line_addcond
   LuText("Add a condition", 10, y, 10)

  case ai_line_action
   entry = scripts(AIScriptIndex(AIScriptId(p))).PointerAt(j)
   LuText("THEN", 4, y, 22)
   WriteText(left(entry->TextDescription(), 62), 10, y, 15)

  case ai_line_addaction
   LuText("Add an action", 10, y, 10)

  case ai_line_addpair
   LuText("Add a new pair of conditions and actions", 2, y, 10)

  case ai_line_missing
   LuText("Script " + str(AIScriptId(p) + 1) + " does not exist in the lunar bank. Choose another script.", 4, y, 12)

 end select

 'the selected line and the pair headings get a colored band behind the text
 if selected then
  AIBand(y, RGB(95, 115, 205))
 elseif kind = ai_line_pair then
  AIBand(y, RGB(30, 45, 120))
 end if

end sub


function AIHint(kind as Integer) as String

 'One line that says what the keys do on the kind of line the cursor is on

 select case kind
  case ai_line_pair: return "Enter changes the set or script of this pair. Insert adds a pair after it."
  case ai_line_condition: return "Enter changes this condition. S picks another one. Insert adds one."
  case ai_line_addcond: return "Enter adds a condition. All of a pair's conditions must be true."
  case ai_line_action: return "Enter changes this action. Insert adds one after it."
  case ai_line_addaction: return "Enter adds an action. The actions run in order, top to bottom."
  case ai_line_addpair: return "Enter adds a pair. The first pair whose conditions are true runs."
  case ai_line_missing: return "Press Enter on the pair line to choose a script that exists."
 end select

 return ""

end function


sub AIDraw(cur as Integer, top as Integer, message as String)

 dim p as Integer = ai_line_pair_of(cur)
 dim slot as Integer
 dim uses as Integer
 dim footer_y as Integer = ai_box_y + ai_visible + 2
 dim info as String
 dim space_text as String
 dim over as Boolean
 dim title as String

 screenlock
 line (0, 0)-(639, 479), RGB(0, 0, 0), bf

 'Title: whose AI, and which monsters use it
 BlueBox(0, 0, 78, 2)
 WriteText(FF4Text("Monster: ") + AITrim(monsters(ai_monster).name), 1, 1, 15)
 title = iif(ai_on_reaction, "Reaction AI ", "Attack AI ") + str(ai_index) + " of " + str(total_ai_groups) + "   " + iif(ai_lunar, "LUNAR bank", "Regular bank")
 LuText(title, 38, 1, iif(ai_lunar, 12, 14))
 LuText("Used by: ", 0, 2, 23)
 WriteText(left(AIUsedBy(), 66), 10, 2, 10)

 'The list
 BlueBox(0, ai_box_y, 78, ai_visible)
 for i as Integer = top to Min(top + ai_visible - 1, ai_line_count)
  AIDrawLine(i, ai_first_y + i - top, i = cur)
 next
 if top > 1 then LuText("more above", 66, ai_box_y, 14)
 if top + ai_visible - 1 < ai_line_count then LuText("more below", 66, ai_box_y + ai_visible + 1, 14)
 DrawLetter(20, 0, ai_first_y + cur - top)

 'Footer: what the line does, how shared it is, how much room is left, and the keys
 BlueBox(0, footer_y, 78, 8)
 info = AIHint(ai_line_kind(cur))
 select case ai_line_kind(cur)
  case ai_line_condition
   slot = AIByte(AISetString(AISetId(p)), ai_line_item(cur))
   uses = ai_condition_uses(slot)
   if uses > 1 then info = "Used by " + str(uses) + " places, a change reaches all of them. U copies it first."
  case ai_line_action
   uses = ai_script_uses(AIScriptId(p))
   if uses > 1 then info = "This script is used by " + str(uses) + " pairs, a change reaches all of them. U copies it."
  case ai_line_pair
   if ai_set_uses(AISetId(p)) > 1 or ai_script_uses(AIScriptId(p)) > 1 then info = "This pair shares its set or script with others. U gives it its own copies."
 end select
 if message <> "" then info = message
 LuText(info, 0, footer_y + 1, 14)

 space_text = "AI room used:"
 for area as Integer = 1 to 4
  space_text += " " + AIAreaName(area) + " " + str(AIBytes(area)) + "/" + str(AIRoom(area))
  if AIBytes(area) > AIRoom(area) then over = true
 next
 LuText(space_text, 0, footer_y + 2, iif(over, 12, 23))
 if over then LuText("Over the limit: Save ROM will refuse to save until there is less AI data.", 0, footer_y + 3, 12)

 LuText("Arrows PgUp PgDn Home End: move.  Enter: change or add.  Insert: add.", 0, footer_y + 5, 23)
 LuText("Delete: remove.  U: own copy of shared parts.  Ctrl-C Ctrl-V: copy, paste.", 0, footer_y + 6, 23)
 LuText("N P: other AI.  G: go to AI.  L: bank.  R: reaction AI.  Ctrl-Z: undo.  Esc: back.", 0, footer_y + 7, 23)
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


sub EditMonsterAI(byref attack_index as Integer, byref reaction_index as Integer, byref lunar_flag as Boolean, monster_number as Integer, start_on_reaction as Boolean = false)

 dim cur as Integer = 1
 dim top as Integer = 1
 dim k as UInteger
 dim done as Boolean
 dim message as String
 dim kind as Integer
 dim p as Integer
 dim j as Integer
 dim v as Integer
 dim slot as Integer
 dim n as Integer
 dim go_text as String
 dim want_kind as Integer
 dim want_pair as Integer
 dim want_item as Integer
 dim entry as AIScriptEntry ptr
 dim choice_menu as BlueMenu
 dim target as Integer
 dim pair_count as Integer
 dim direction as Integer

 ai_monster = monster_number
 ai_lunar = lunar_flag
 ai_on_reaction = start_on_reaction and reaction_index > 0
 ai_index = iif(ai_on_reaction, reaction_index, attack_index)
 ai_undo_count = 0
 ai_clip_kind = 0

 do
  AICountUses()
  AIBuildLines()

  'put the cursor on what the last action was about
  if want_kind > 0 then
   target = AIFindLine(want_kind, want_pair, want_item)
   if target = 0 then target = AIFindLine(ai_line_pair, want_pair, 0)
   if target > 0 then cur = target
   want_kind = 0
  end if
  if cur > ai_line_count then cur = ai_line_count
  if cur < 1 then cur = 1
  do while ai_line_kind(cur) = ai_line_spacer and cur < ai_line_count
   cur += 1
  loop
  if cur < top then top = cur
  if cur > top + ai_visible - 1 then top = cur - ai_visible + 1
  if top < 1 then top = 1

  kind = ai_line_kind(cur)
  p = ai_line_pair_of(cur)
  j = ai_line_item(cur)
  pair_count = len(aigroupconditions(ai_index))

  AIDraw(cur, top, message)
  message = ""
  k = AIReadKey()
  ai_undo_group += 1

  select case k

   case ESC_KEY
    done = true

   case UP_KEY, DOWN_KEY, PAGEUP_KEY, PAGEDOWN_KEY, HOME_KEY, END_KEY
    direction = iif(k = UP_KEY or k = PAGEUP_KEY or k = HOME_KEY, -1, 1)
    select case k
     case UP_KEY, DOWN_KEY
      cur += direction
     case PAGEUP_KEY, PAGEDOWN_KEY
      cur += direction * (ai_visible - 1)
     case HOME_KEY
      cur = 1
     case END_KEY
      cur = ai_line_count
    end select
    if cur < 1 then cur = 1
    if cur > ai_line_count then cur = ai_line_count
    'the blank lines between the pairs are skipped
    do while ai_line_kind(cur) = ai_line_spacer
     if cur + direction < 1 or cur + direction > ai_line_count then
      direction = -direction
     end if
     cur += direction
    loop

   case asc("n"), asc("N"), asc("p"), asc("P"), asc("g"), asc("G"), asc("l"), asc("L"), asc("r"), asc("R")
    'moving to another AI or bank starts a new undo history
    select case k
     case asc("n"), asc("N")
      if ai_index < total_ai_groups then ai_index += 1
     case asc("p"), asc("P")
      if ai_index > 1 then ai_index -= 1
     case asc("g"), asc("G")
      go_text = PromptLine("Go to AI number, 1 to " + str(total_ai_groups) + ":", 3)
      v = val(go_text)
      if go_text <> "" and v >= 1 and v <= total_ai_groups then ai_index = v
     case asc("l"), asc("L")
      ai_lunar = not ai_lunar
     case else
      if reaction_index > 0 then
       if ai_on_reaction then reaction_index = ai_index else attack_index = ai_index
       ai_on_reaction = not ai_on_reaction
       ai_index = iif(ai_on_reaction, reaction_index, attack_index)
      else
       message = "This monster has no reaction AI (turn it on in the monster's extras)."
      end if
    end select
    if ai_on_reaction then reaction_index = ai_index else attack_index = ai_index
    cur = 1
    top = 1
    ai_undo_count = 0

   case ENTER_KEY, asc("s"), asc("S")
    select case kind

     case ai_line_pair
      if k = ENTER_KEY then
       choice_menu = BlueMenu(ai_dialog_x, ai_dialog_y)
       choice_menu.AddOption(FF4Text("Choose another condition set"))
       choice_menu.AddOption(FF4Text("Choose another script"))
       choice_menu.UserSelect()
       if not choice_menu.cancelled then
        if choice_menu.selected = 1 then
         v = AIPickSet(AISetId(p))
         if v >= 0 and v <> AISetId(p) then
          AIPushGroup()
          mid(aigroupconditions(ai_index), p, 1) = chr(v)
         end if
        else
         v = AIPickScript(AIScriptId(p))
         if v >= 0 and v <> AIScriptId(p) then
          AIPushGroup()
          mid(aigroupscripts(ai_index), p, 1) = chr(v)
         end if
        end if
       end if
      end if
      want_kind = ai_line_pair
      want_pair = p

     case ai_line_condition
      slot = AIByte(AISetString(AISetId(p)), j)
      if k = ENTER_KEY then
       if AIReadyCondition(p, j) then
        AIPushCondition(slot)
        if not AIEditCondition(slot + 1, ai_dialog_x, ai_dialog_y) then ai_undo_count -= 1
       end if
      else
       v = AIPickCondition(slot)
       if v >= 0 and v <> slot then
        AIPushSet(AISetId(p))
        mid(conditionsets(AISetId(p) + 1), j, 1) = chr(v)
       end if
      end if
      want_kind = ai_line_condition
      want_pair = p
      want_item = j

     case ai_line_addcond
      if k = ENTER_KEY then
       if AIAddNewCondition(p, j) then message = "Condition added."
      end if
      want_kind = ai_line_condition
      want_pair = p
      want_item = j

     case ai_line_action
      if k = ENTER_KEY then
       if AIReadyScript(p) then
        n = AIScriptIndex(AIScriptId(p))
        AIPushScript(n)
        entry = scripts(n).PointerAt(j)
        if not AIEditScriptEntry(entry, ai_dialog_x, ai_dialog_y) then ai_undo_count -= 1
       end if
      end if
      want_kind = ai_line_action
      want_pair = p
      want_item = j

     case ai_line_addaction
      if k = ENTER_KEY then
       if AIAddNewAction(p, j) then message = "Action added."
      end if
      want_kind = ai_line_action
      want_pair = p
      want_item = j

     case ai_line_addpair
      if k = ENTER_KEY then
       if AINewPair(pair_count) then
        message = "Pair added. Enter on its lines changes them."
        want_kind = ai_line_condition
        want_pair = pair_count + 1
        want_item = 1
       end if
      end if

    end select

   case INSERT_KEY
    select case kind

     case ai_line_pair, ai_line_addpair
      v = iif(kind = ai_line_pair, p, pair_count)
      if AINewPair(v) then
       want_kind = ai_line_condition
       want_pair = v + 1
       want_item = 1
      end if

     case ai_line_condition, ai_line_addcond
      v = iif(kind = ai_line_condition, j + 1, j)
      if AIAddNewCondition(p, v) then
       want_kind = ai_line_condition
       want_pair = p
       want_item = v
      end if

     case ai_line_action, ai_line_addaction
      v = iif(kind = ai_line_action, j + 1, j)
      if AIAddNewAction(p, v) then
       want_kind = ai_line_action
       want_pair = p
       want_item = v
      end if

    end select

   case DELETE_KEY
    select case kind

     case ai_line_pair
      if pair_count > 1 then
       if ConfirmBox("Delete this pair of conditions and actions?") then
        AIPushGroup()
        aigroupconditions(ai_index) = left(aigroupconditions(ai_index), p - 1) + mid(aigroupconditions(ai_index), p + 1)
        aigroupscripts(ai_index) = left(aigroupscripts(ai_index), p - 1) + mid(aigroupscripts(ai_index), p + 1)
        want_kind = ai_line_pair
        want_pair = Max(p - 1, 1)
       end if
      else
       message = "An AI needs at least one pair."
      end if

     case ai_line_condition
      if len(AISetString(AISetId(p))) > 1 then
       AIPushSet(AISetId(p))
       conditionsets(AISetId(p) + 1) = left(conditionsets(AISetId(p) + 1), j - 1) + mid(conditionsets(AISetId(p) + 1), j + 1)
       want_kind = ai_line_condition
       want_pair = p
       want_item = Max(j - 1, 1)
      else
       message = "A pair needs at least one condition (use No condition for always)."
      end if

     case ai_line_action
      if AIReadyScript(p) then
       n = AIScriptIndex(AIScriptId(p))
       AIPushScript(n)
       scripts(n).Remove(j)
      end if
      want_kind = ai_line_action
      want_pair = p
      want_item = Max(j - 1, 1)

    end select

   case asc("u"), asc("U")
    'private copies of what this line shares
    select case kind
     case ai_line_pair
      if AIMakeSetPrivate(p) and AIMakeScriptPrivate(p) then message = "This pair now has its own set and script."
     case ai_line_condition
      if AIMakeConditionPrivate(p, j) then message = "This condition is now its own copy."
     case ai_line_action, ai_line_addaction
      if AIMakeScriptPrivate(p) then message = "This pair now has its own script."
    end select
    want_kind = kind
    want_pair = p
    want_item = j

   case 3 'Ctrl-C
    select case kind
     case ai_line_pair
      ai_clip_kind = 1
      ai_clip_a = AISetId(p)
      ai_clip_b = AIScriptId(p)
      message = "Copied the pair."
     case ai_line_condition
      ai_clip_kind = 2
      ai_clip_a = AIByte(AISetString(AISetId(p)), j)
      message = "Copied the condition."
     case ai_line_action
      entry = scripts(AIScriptIndex(AIScriptId(p))).PointerAt(j)
      ai_clip_kind = 3
      ai_clip_a = entry->function_call
      ai_clip_b = entry->parameter
      message = "Copied the action."
    end select

   case 22 'Ctrl-V
    select case ai_clip_kind
     case 1
      v = iif(kind = ai_line_addpair, pair_count, p)
      AIInsertPair(v, ai_clip_a, ai_clip_b)
      want_kind = ai_line_pair
      want_pair = v + 1
     case 2
      if kind = ai_line_condition or kind = ai_line_addcond then
       v = iif(kind = ai_line_condition, j + 1, j)
       if AIInsertCondition(p, v, ai_clip_a) then
        want_kind = ai_line_condition
        want_pair = p
        want_item = v
       end if
      else
       message = "Select a condition line to paste a condition."
      end if
     case 3
      if kind = ai_line_action or kind = ai_line_addaction then
       v = iif(kind = ai_line_action, j + 1, j)
       if AIInsertAction(p, v, ai_clip_a, ai_clip_b) then
        want_kind = ai_line_action
        want_pair = p
        want_item = v
       end if
      else
       message = "Select an action line to paste an action."
      end if
     case else
      message = "Nothing copied yet."
    end select

   case 26 'Ctrl-Z
    if not AIUndo() then message = "Nothing to undo."

  end select

 loop until done

 if ai_on_reaction then reaction_index = ai_index else attack_index = ai_index
 lunar_flag = ai_lunar
 cls

end sub
