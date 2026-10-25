'Enemy AI editor: a full screen view of one AI, opened from "Edit AI" in the monster editor.
'
'An AI (1 to 254) is a list of pairs. The game goes through the pairs in order and runs the actions of the
'first pair whose conditions are all true. Each pair is a condition set (all its conditions must hold) and
'a script (the actions to do). The screen has two panels, one under the other:
'
'  1 AI SCRIPT   The AI the monster uses, and any other AI to look at: browsing does not change the monster
'                until "use this AI" is chosen.
'  2 PAIRS       Every pair of the AI in the style of the AI box in the monster editor: WHEN and AND lines for
'                its conditions, THEN lines for its actions. Each pair also has a script line and
'                Add lines. Left and Right switch to the previous or next pair.
'
'Tab or 1 2 switch panel (Up at the top of the list goes to panel 1, Down at the end of panel 1 to the list). Sets, conditions and scripts are shared in the ROM: one script can serve many
'AIs. A change goes to every place that uses it; the "used Nx" counts show how many. A new pair starts as condition set 1 and script 1, which already exist.
'The footer shows how full the AI areas of the ROM are.
'
'The font has no + = ( ) [ ] < > characters, so the help text is written around that.

const ai_undo_depth = 120

const ai_max_cond_lines = 2000

'the lines of the condition list (panel 2)
const ai_cl_condition = 1 'a condition of a pair
const ai_cl_addcond = 2 'the line that adds one (selected pair)
const ai_cl_chooser = 3 'the script of the selected pair
const ai_cl_action = 4 'an action of a pair
const ai_cl_addaction = 5 'the line that adds one (selected pair)
const ai_cl_addpair = 6 'the line that adds a pair
const ai_cl_blank = 7 'a gap between two pairs (the cursor skips it)

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

dim shared ai_panel_y(1 to 2) as Integer = {3, 8} 'top border of each panel
dim shared ai_panel_inner(1 to 2) as Integer = {3, 37} 'text rows inside each panel
dim shared ai_cur(1 to 3) as Integer 'cursor row of panel 1; (3) is the action the pair list cursor is on (0 is the script line, the last is the Add row)
dim shared ai_top(1 to 2) as Integer 'first list row shown
dim shared ai_focus as Integer 'the panel the keys act on: 1 the AI, 2 the list of pairs
dim shared ai_list_focus as Integer 'in the list: 2 when the cursor is on a condition line, 3 on a script or action line
dim shared ai_pair as Integer 'the pair that panels 2 and 3 show
dim shared ai_cp as Integer 'panel 2 cursor: the pair (0 for the Add a new pair line) and the condition in it
dim shared ai_ci as Integer
dim shared ai_cl_kind(1 to ai_max_cond_lines) as Integer 'the lines of the list of pairs
dim shared ai_cl_pair(1 to ai_max_cond_lines) as Integer
dim shared ai_cl_item(1 to ai_max_cond_lines) as Integer
dim shared ai_cl_count as Integer
dim shared ai_message as String
dim shared ai_attack as Integer 'the AIs the monster uses (attack and reaction) while editing
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

 dim k as UInteger

 if ai_script_pos < ai_script_count then
  ai_script_pos += 1
  return ai_script_keys(ai_script_pos - 1)
 end if

 do
  k = getkey
 loop while KeyHelpPressed(k)

 return k

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
   label += FF4Text("empty")
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
   label += FF4Text("empty")
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


function AICondMenu() as Integer

 'What to do with the condition under the cursor: 1 another set for the pair, 2 edit the condition, 3 insert a pair after this one, 4 move the pair up, 5 down, 0 cancelled

 dim m as BlueMenu

 m = BlueMenu(ai_dialog_x, ai_dialog_y)
 m.title = "Condition"
 m.AddOption(FF4Text("Change condition set"), 15)
 m.AddOption(FF4Text("Edit current condition"), 15)
 m.AddOption(FF4Text("Insert a pair after this one"), 15)
 m.AddOption(FF4Text("Move pair up"), 15)
 m.AddOption(FF4Text("Move pair down"), 15)
 m.UserSelect()
 if m.cancelled then return 0

 return m.selected

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


'-------- unused slots --------

function AIFreeCondition() as Integer

 for id as Integer = 0 to total_conditions - 1
  if ai_condition_uses(id) = 0 then return id
 next

 return -1

end function


function AIReadySet(p as Integer) as Boolean

 'Changes to a shared condition set, script or condition go to every place that uses it
 ' (the "used Nx" counts show how many).

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
 dim attack as Integer
 dim reaction as Integer
 dim is_lunar as Boolean
 dim who as String

 for m as Integer = 1 to total_monsters
  if m = ai_monster then
   attack = ai_attack
   reaction = ai_reaction
   is_lunar = ai_lunar
   who = FF4Text("this one")
  else
   attack = monsters(m).attack_sequence_group + 1
   reaction = iif(monsters(m).has_reaction, monsters(m).reaction_index + 1, 0)
   is_lunar = monsters(m).lunar
   who = AITrim(monsters(m).name)
  end if
  text = ""
  if is_lunar = ai_lunar then
   if attack = ai_index then text = who
   if text = "" and reaction = ai_index then text = who + FF4Text(" reaction")
  end if
  if text <> "" then
   total += 1
   if len(result) < 48 then
    result += iif(len(result) > 0, FF4Text(", "), "") + text
    names += 1
   end if
  end if
 next

 if total = 0 then return FF4Text("no monster, not used")
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


function AIAssigned() as Integer

 'The AI the monster uses now (its attack AI, or its reaction AI while that one is the one being worked on)

 return iif(ai_on_reaction, ai_reaction, ai_attack)

end function


function AIPanelCount(panel as Integer) as Integer

 'The number of the last row of a panel's list. Panel 1 has rows 0 and 1, panel 3 has the chooser line
 ' (row 0), the actions and the Add row. (Panel 2 is a list of its own, see AIBuildCondLines.)

 dim n as Integer

 select case panel
  case 1
   return 1
  case 3
   if ai_pair < 1 then return 0
   if not AIScriptExists(AIScriptId(ai_pair)) then return 0
   n = AIScriptIndex(AIScriptId(ai_pair))
   return scripts(n).Length() + 1
 end select

 return 0

end function


function AIFirstCondition(p as Integer) as String

 'FF4 text of the first condition of pair p

 dim slot as Integer = AIByte(AISetString(AISetId(p)), 1)

 if len(AISetString(AISetId(p))) = 0 or slot >= total_conditions then return FF4Text("no conditions")
 return conditions(slot + 1).TextDescription()

end function


function AIFirstAction(p as Integer) as String

 dim n as Integer
 dim entry as AIScriptEntry ptr

 if not AIScriptExists(AIScriptId(p)) then return FF4Text("no such script")
 n = AIScriptIndex(AIScriptId(p))
 if scripts(n).Length() = 0 then return FF4Text("no actions")
 entry = scripts(n).PointerAt(1)

 return entry->TextDescription()

end function


'-------- the list of conditions (panel 2) --------

sub AIAddCondLine(kind as Integer, p as Integer, item as Integer)

 if ai_cl_count >= ai_max_cond_lines then exit sub
 ai_cl_count += 1
 ai_cl_kind(ai_cl_count) = kind
 ai_cl_pair(ai_cl_count) = p
 ai_cl_item(ai_cl_count) = item

end sub


sub AIBuildCondLines()

 'Every pair in full: its conditions and an Add line, its script line, its actions and an Add line.

 dim n as Integer
 dim m as Integer

 ai_cl_count = 0
 for p as Integer = 1 to len(aigroupconditions(ai_index))
  n = len(AISetString(AISetId(p)))
  for j as Integer = 1 to n
   AIAddCondLine(ai_cl_condition, p, j)
  next
  AIAddCondLine(ai_cl_addcond, p, n + 1)

  m = 0
  if AIScriptExists(AIScriptId(p)) then m = scripts(AIScriptIndex(AIScriptId(p))).Length()
  AIAddCondLine(ai_cl_chooser, p, 0)
  for j as Integer = 1 to m
   AIAddCondLine(ai_cl_action, p, j)
  next
  if AIScriptExists(AIScriptId(p)) then AIAddCondLine(ai_cl_addaction, p, m + 1)
  AIAddCondLine(ai_cl_blank, p, 0)
 next
 AIAddCondLine(ai_cl_addpair, 0, 0)

end sub


function AICondIndex() as Integer

 'The line of the list that the cursor is on. On a condition line it is (ai_cp, ai_ci), on a script or
 ' action line it is the action ai_cur(3) of the pair ai_pair.

 dim on_conditions as Boolean = (ai_list_focus = 2 or ai_pair < 1)

 for i as Integer = 1 to ai_cl_count
  if on_conditions then
   if ai_cl_pair(i) = ai_cp and ai_cl_item(i) = ai_ci and (ai_cl_kind(i) = ai_cl_condition or ai_cl_kind(i) = ai_cl_addcond or ai_cl_kind(i) = ai_cl_addpair) then return i
  else
   if ai_cl_pair(i) = ai_pair and ai_cl_item(i) = ai_cur(3) and ai_cl_kind(i) >= ai_cl_chooser and ai_cl_kind(i) <= ai_cl_addaction then return i
  end if
 next
 for i as Integer = 1 to ai_cl_count
  if ai_cl_pair(i) = ai_pair and ai_cl_pair(i) > 0 then return i
 next

 return ai_cl_count

end function


sub AISetCondCursor(i as Integer)

 'Puts the cursor on line i of the list. Landing on another pair makes it the selected one.

 if i < 1 then i = 1
 if i > ai_cl_count then i = ai_cl_count
 ai_cp = ai_cl_pair(i)
 if ai_cp > 0 then ai_pair = ai_cp

 select case ai_cl_kind(i)
  case ai_cl_chooser, ai_cl_action, ai_cl_addaction
   ai_list_focus = 3
   ai_cur(3) = ai_cl_item(i)
   ai_ci = 1
  case else
   ai_list_focus = 2
   ai_ci = ai_cl_item(i)
 end select

end sub


'-------- drawing --------

sub AIDrawPanel1()

 dim y0 as Integer = ai_panel_y(1)
 dim focused as Boolean = (ai_focus = 1)
 dim selected_color as UInteger = iif(focused, RGB(95, 115, 205), RGB(50, 65, 135))
 dim assigned as Integer = AIAssigned()
 dim pair_count as Integer = len(aigroupconditions(ai_index))

 BlueBox(0, y0, 78, ai_panel_inner(1))
 LuText(" 1  AI SCRIPT  ", 1, y0, iif(focused, 14, 23))

 'row 0: the AI that is shown, and whether the monster uses it
 LuText("AI " + str(ai_index) + " of " + str(total_ai_groups), 2, y0 + 1, 14)
 if ai_index = assigned then
  LuText("This monster uses this AI", 18, y0 + 1, 10)
 else
  LuText("Not its AI, it uses AI " + str(assigned), 18, y0 + 1, 14)
 end if
 AIBand(y0 + 1, iif(ai_cur(1) = 0, selected_color, RGB(30, 45, 120)))
 if focused and ai_cur(1) = 0 then DrawLetter(20, 0, y0 + 1)

 'row 1: use the AI shown
 if ai_index = assigned then
  LuText("The AI of this monster has " + str(pair_count) + iif(pair_count = 1, " pair", " pairs") + ", " + iif(ai_lunar, "LUNAR bank", "regular bank"), 2, y0 + 2, 23)
 else
  LuText("Use AI " + str(ai_index) + " for this monster instead of AI " + str(assigned), 2, y0 + 2, 10)
 end if
 if ai_cur(1) = 1 then AIBand(y0 + 2, selected_color)
 if focused and ai_cur(1) = 1 then DrawLetter(20, 0, y0 + 2)

 'row 2: where the AI is used
 LuText("Used by: ", 2, y0 + 3, 23)
 WriteText(left(AIUsedBy(), 66), 12, y0 + 3, 10)

end sub


sub AIDrawCondLine(i as Integer, y as Integer)

 dim p as Integer = ai_cl_pair(i)
 dim j as Integer = ai_cl_item(i)
 dim sid as Integer
 dim slot as Integer
 dim uses as Integer
 dim id as Integer
 dim entry as AIScriptEntry ptr

 select case ai_cl_kind(i)

  case ai_cl_condition
   sid = AISetId(p)
   slot = AIByte(AISetString(sid), j)
   if j = 1 then LuText(str(p), 2, y, 14)
   LuText(iif(j = 1, "WHEN", "AND "), 5, y, 21)
   if slot < total_conditions then
    WriteText(left(conditions(slot + 1).TextDescription(), 31), 11, y, 15)
    if j = 1 and ai_set_uses(sid) > 1 then LuText("shared by " + str(ai_set_uses(sid)) + " pairs", 46, y, 14)
    LuText("cond " + str(slot + 1), 70, y, 22)
   else
    LuText("Unknown condition " + str(slot), 11, y, 12)
   end if

  case ai_cl_addcond
   LuText("Add a condition", 11, y, 10)

  case ai_cl_chooser
   id = AIScriptId(p)
   LuText("Script " + str(id + 1), 8, y, 22)
   if ai_script_uses(id) > 1 then LuText("shared by " + str(ai_script_uses(id)) + " pairs", 60, y, 14)
   if AIScriptExists(id) then
    if scripts(AIScriptIndex(id)).Length() = 0 then LuText("no actions", 18, y, 23)
   else
    LuText("does not exist in the lunar bank", 18, y, 12)
   end if

  case ai_cl_action
   id = AIScriptId(p)
   LuText("THEN", 8, y, 22)
   if AIScriptExists(id) then
    entry = scripts(AIScriptIndex(id)).PointerAt(j)
    WriteText(left(entry->TextDescription(), 52), 14, y, 15)
   end if

  case ai_cl_addaction
   LuText("Add an action", 14, y, 10)

  case ai_cl_addpair
   LuText("Add a pair, it starts as set 1 and script 1", 2, y, 10)

 end select

end sub


sub AIDrawPanel2()

 dim y0 as Integer = ai_panel_y(2)
 dim inner as Integer = ai_panel_inner(2)
 dim focused as Boolean = (ai_focus = 2)
 dim selected_color as UInteger = iif(focused, RGB(95, 115, 205), RGB(50, 65, 135))
 dim cur_line as Integer = AICondIndex()
 dim y as Integer
 dim pair_count as Integer = len(aigroupconditions(ai_index))

 BlueBox(0, y0, 78, inner)
 LuText(" 2  PAIRS: conditions WHEN, actions THEN ", 1, y0, iif(focused, 21, 23))
 if pair_count > 0 and ai_pair > 0 then LuText("pair " + str(ai_pair) + " of " + str(pair_count) + ", Left Right switch", 44, y0, iif(focused, 21, 23))
 if ai_top(2) > 1 then LuText("more above", 66, y0 + 1, 14)
 if ai_top(2) + inner - 1 < ai_cl_count then LuText("more below", 66, y0 + inner, 14)

 for i as Integer = ai_top(2) to Min(ai_top(2) + inner - 1, ai_cl_count)
  y = y0 + 1 + i - ai_top(2)
  AIDrawCondLine(i, y)
  if i = cur_line then
   AIBand(y, selected_color)
   if focused then DrawLetter(20, 0, y)
  end if
 next

end sub


function AIHint() as String

 'One line that says what the keys do on the line the cursor is on

 if ai_focus = 1 then
  if ai_cur(1) = 0 then return "Enter lists every AI to look at. Looking does not change this monster."
  if ai_index = AIAssigned() then return "This is the AI this monster uses. Left Right or N P look at others."
  return "Enter makes this monster use AI " + str(ai_index) + ". A does the same from anywhere."
 end if

 select case ai_cl_kind(AICondIndex())
  case ai_cl_condition: return "Enter: menu. Insert: add condition. S: change set. Comma Period: move pair."
  case ai_cl_addcond: return "Enter adds a condition. All the conditions of a pair must be true."
  case ai_cl_chooser: return "Enter picks a script for this pair from a list."
  case ai_cl_action: return "Enter changes this action. Insert adds, Delete removes, Comma Period move."
  case ai_cl_addaction: return "Enter adds an action. The actions run in order, top to bottom."
  case ai_cl_addpair: return "Enter adds a pair, conditions, then actions to run. Starts as set 1, script 1."
 end select

 return ""

end function


sub AIDraw(message as String)

 dim info as String
 dim space_text as String
 dim over as Boolean
 dim title as String
 dim footer_y as Integer = 47
 dim uses as Integer
 dim slot as Integer
 dim line_index as Integer

 screenlock
 line (0, 0)-(639, 479), RGB(0, 0, 0), bf

 'Title: whose AI, and the bank
 BlueBox(0, 0, 78, 1)
 WriteText(FF4Text("Monster: ") + AITrim(monsters(ai_monster).name), 1, 1, 15)
 title = iif(ai_on_reaction, "Its reaction AI is ", "Its attack AI is ") + str(AIAssigned()) + "   " + iif(ai_lunar, "LUNAR bank", "Regular bank") + ", L switches"
 LuText(title, 26, 1, iif(ai_lunar, 12, 14))

 AIDrawPanel1()
 AIDrawPanel2()

 'Footer: what the line does, how shared it is, how much room is left, and the keys
 BlueBox(0, footer_y, 78, 5)
 info = AIHint()
 if ai_pair > 0 and ai_focus = 2 then
  line_index = AICondIndex()
  select case ai_cl_kind(line_index)
   case ai_cl_condition
    uses = ai_set_uses(AISetId(ai_pair))
    slot = AIByte(AISetString(AISetId(ai_pair)), ai_cl_item(line_index))
    if uses > 1 then info = "Set used by " + str(uses) + " pairs: a change reaches all."
    if ai_condition_uses(slot) > 1 and uses <= 1 then info = "Condition used by " + str(ai_condition_uses(slot)) + " places: a change reaches all."
   case ai_cl_chooser, ai_cl_action
    uses = ai_script_uses(AIScriptId(ai_pair))
    if uses > 1 then info = "Script used by " + str(uses) + " pairs: a change reaches all."
  end select
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

 LuText("Tab or 1 2: panel. Arrows: move. Enter: change or add. Space: menu. Esc: back", 0, footer_y + 4, 23)
 LuText("L: other bank.  R: reaction AI.  Ctrl-R: revert.  Ctrl-C Ctrl-V: copy and paste.", 0, footer_y + 5, 23)
 screenunlock

end sub


'-------- editing --------

sub AIInsertPair(after_p as Integer, set_id as Integer, script_id as Integer)

 AIPushGroup()
 aigroupconditions(ai_index) = left(aigroupconditions(ai_index), after_p) + chr(set_id) + mid(aigroupconditions(ai_index), after_p + 1)
 aigroupscripts(ai_index) = left(aigroupscripts(ai_index), after_p) + chr(script_id) + mid(aigroupscripts(ai_index), after_p + 1)

end sub


function AINewPair(after_p as Integer) as Boolean

 'A new place in the AI for a pair made of condition set 1 and script 1, which already exist. Nothing new is
 ' created; the set and the script are changed afterwards (S, and the Script line), and a change to them
 ' reaches everything else that uses them.

 AIInsertPair(after_p, 0, 0)

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

 'Adds a condition in an unused slot (starting as "no condition") and opens its editor at once. With no unused
 ' slot left it adds one picked from the existing conditions.

 dim slot as Integer = AIFreeCondition()

 if slot < 0 then
  'every condition is in use: use one that exists (it is then shared), picked from the list
  InfoBox("There is no unused condition left, so pick an existing one.||Press any key", 10, 20)
  slot = AIPickCondition(0)
  if slot < 0 then return false
  return AIInsertCondition(p, place, slot)
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
 m.title = iif(ai_on_reaction, "Look at which reaction AI. Yellow ones are not used", "Look at which AI. Yellow ones are not used")
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

 'Looks at another AI. The AI of the monster stays as it is until it is told to use this one.

 ai_index = new_index
 ai_cp = iif(len(aigroupconditions(new_index)) > 0, 1, 0)
 ai_ci = 1
 ai_pair = ai_cp
 ai_cur(1) = 0
 ai_cur(3) = 0
 ai_list_focus = 2
 for panel as Integer = 1 to 2
  ai_top(panel) = 1
 next
 ai_undo_count = 0

end sub


sub AIAssign()

 'The monster uses the AI that is shown

 if ai_on_reaction then ai_reaction = ai_index else ai_attack = ai_index
 ai_message = "This monster now uses AI " + str(ai_index) + " as its " + iif(ai_on_reaction, "reaction", "attack") + " AI."

end sub


sub AIChangePair(delta as Integer)

 dim pair_count as Integer = len(aigroupconditions(ai_index))
 dim target as Integer = ai_pair + delta

 if pair_count < 1 then exit sub
 if target < 1 then target = 1
 if target > pair_count then target = pair_count
 ai_pair = target
 ai_cp = target
 ai_ci = 1
 ai_list_focus = 2

end sub


sub AIMoveCursor(k as UInteger)

 dim v as Integer

 if ai_focus = 1 then
  if k = DOWN_KEY and ai_cur(1) = 1 then
   ai_focus = 2
  else
   v = ai_cur(1)
   if k = UP_KEY or k = HOME_KEY then v -= 1
   if k = DOWN_KEY or k = END_KEY then v += 1
   ai_cur(1) = Max(Min(v, 1), 0)
  end if
  exit sub
 end if

 v = AICondIndex()
 if v = 1 and (k = UP_KEY or k = PAGEUP_KEY) then
  ai_focus = 1
  ai_cur(1) = 1
  exit sub
 end if
 select case k
  case UP_KEY: v -= 1
  case DOWN_KEY: v += 1
  case PAGEUP_KEY: v -= ai_panel_inner(2) - 1
  case PAGEDOWN_KEY: v += ai_panel_inner(2) - 1
  case HOME_KEY: v = 1
  case END_KEY: v = ai_cl_count
 end select
 if v < 1 then v = 1
 if v > ai_cl_count then v = ai_cl_count
 if ai_cl_kind(v) = ai_cl_blank then
  if k = UP_KEY or k = PAGEUP_KEY or k = HOME_KEY then v -= 1 else v += 1
 end if
 AISetCondCursor(v)

end sub


sub AIMovePair(delta as Integer)

 'Moves the selected pair up or down: the order of the pairs is the order the game tries them

 dim p as Integer = ai_pair
 dim q as Integer = p + delta
 dim a as String
 dim b as String

 if p < 1 or q < 1 or q > len(aigroupconditions(ai_index)) then exit sub

 AIPushGroup()
 a = mid(aigroupconditions(ai_index), p, 1)
 b = mid(aigroupscripts(ai_index), p, 1)
 mid(aigroupconditions(ai_index), p, 1) = mid(aigroupconditions(ai_index), q, 1)
 mid(aigroupscripts(ai_index), p, 1) = mid(aigroupscripts(ai_index), q, 1)
 mid(aigroupconditions(ai_index), q, 1) = a
 mid(aigroupscripts(ai_index), q, 1) = b
 ai_pair = q
 ai_cp = q

end sub


sub AIMoveAction(delta as Integer)

 'Moves the action under the cursor up or down in its script (the actions run in order)

 dim idx as Integer = ai_cur(3)
 dim target as Integer = idx + delta
 dim sn as Integer
 dim first as AIScriptEntry ptr
 dim second as AIScriptEntry ptr
 dim f as Integer
 dim v as Integer

 if ai_pair < 1 or not AIReadyScript(ai_pair) then exit sub
 sn = AIScriptIndex(AIScriptId(ai_pair))
 if idx < 1 or target < 1 or target > scripts(sn).Length() then exit sub

 AIPushScript(sn)
 first = scripts(sn).PointerAt(idx)
 second = scripts(sn).PointerAt(target)
 f = first->function_call
 v = first->parameter
 first->function_call = second->function_call
 first->parameter = second->parameter
 second->function_call = f
 second->parameter = v
 ai_cur(3) = target

end sub


sub AIKeyAI(k as UInteger)

 'Keys in panel 1: which AI is shown, and whether the monster uses it

 dim v as Integer

 select case k

  case ENTER_KEY
   if ai_cur(1) = 0 then
    v = AIPickAI()
    if v > 0 and v <> ai_index then AIChangeAI(v)
   elseif ai_index <> AIAssigned() then
    AIAssign()
   end if

 end select

end sub


sub AIKeyConditions(k as UInteger)

 'Keys in panel 2: the conditions of the pairs. The selected pair shows all of its conditions.

 dim pair_count as Integer = len(aigroupconditions(ai_index))
 dim p as Integer = ai_cp
 dim j as Integer = ai_ci
 dim n as Integer
 dim slot as Integer
 dim v as Integer

 'the Add a new pair line
 if p = 0 then
  if k = ENTER_KEY or k = INSERT_KEY then
   if AINewPair(pair_count) then
    ai_cp = pair_count + 1
    ai_ci = 1
    ai_pair = ai_cp
    ai_list_focus = 2
    ai_message = "Pair added as set 1 and script 1. S changes the set, the Script line the script."
   end if
  elseif k = 22 and ai_clip_kind = 1 then
   AIInsertPair(pair_count, ai_clip_a, ai_clip_b)
  end if
  exit sub
 end if

 n = len(AISetString(AISetId(p)))

 select case k

  case ENTER_KEY
   if j <= n then
    slot = AIByte(AISetString(AISetId(p)), j)
    select case AICondMenu()
     case 1
      v = AIPickSet(AISetId(p))
      if v >= 0 and v <> AISetId(p) then
       AIPushGroup()
       mid(aigroupconditions(ai_index), p, 1) = chr(v)
       ai_ci = 1
      end if
     case 2
      if AIReadyCondition(p, j) then
       AIPushCondition(slot)
       if not AIEditCondition(slot + 1, ai_dialog_x, ai_dialog_y) then ai_undo_count -= 1
      end if
     case 3
      if AINewPair(p) then
       ai_cp = p + 1
       ai_pair = ai_cp
       ai_ci = 1
       ai_list_focus = 2
       ai_message = "Pair inserted as set 1 and script 1. S changes the set, the Script line the script."
      end if
     case 4
      AIMovePair(-1)
     case 5
      AIMovePair(1)
    end select
   elseif AIAddNewCondition(p, n + 1) then
    ai_ci = n + 1
    ai_message = "Condition added."
   end if

  case INSERT_KEY
   v = iif(j <= n, j + 1, n + 1)
   if AIAddNewCondition(p, v) then ai_ci = v

  case DELETE_KEY
   if j <= n then
    if n = 1 then
     ai_message = "A pair needs at least one condition. D deletes the whole pair."
    else
     AIPushSet(AISetId(p))
     conditionsets(AISetId(p) + 1) = left(conditionsets(AISetId(p) + 1), j - 1) + mid(conditionsets(AISetId(p) + 1), j + 1)
     ai_ci = Max(Min(j, n - 1), 1)
    end if
   end if

  case asc("d"), asc("D")
   if pair_count = 1 then
    ai_message = "An AI needs at least one pair."
   elseif ConfirmBox("Delete this pair of conditions and actions?") then
    AIPushGroup()
    aigroupconditions(ai_index) = left(aigroupconditions(ai_index), p - 1) + mid(aigroupconditions(ai_index), p + 1)
    aigroupscripts(ai_index) = left(aigroupscripts(ai_index), p - 1) + mid(aigroupscripts(ai_index), p + 1)
    ai_pair = Max(p - 1, 1)
    ai_cp = ai_pair
    ai_ci = 1
   end if

  case asc("s"), asc("S")
   'another condition set for this pair, from a list
   v = AIPickSet(AISetId(p))
   if v >= 0 and v <> AISetId(p) then
    AIPushGroup()
    mid(aigroupconditions(ai_index), p, 1) = chr(v)
    ai_ci = 1
   end if

  case 3 'Ctrl-C
   if j <= n then
    ai_clip_kind = 2
    ai_clip_a = AIByte(AISetString(AISetId(p)), j)
    ai_message = "Copied the condition."
   end if

  case 22 'Ctrl-V
   if ai_clip_kind = 2 then
    v = iif(j <= n, j + 1, n + 1)
    if AIInsertCondition(p, v, ai_clip_a) then ai_ci = v
   else
    ai_message = "Copy a condition first, Ctrl-C on a condition."
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
  ai_message = "This AI has no pairs. Add one at the end of the list."
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
    ai_message = "Copy an action first, Ctrl-C on an action."
   end if

 end select

end sub


function AIActions() as UInteger

 'Space: a menu of what can be done on the line the cursor is on, with the key of each. Returns the key the
 ' chosen entry stands for (the loop handles it as if it had been pressed), 0 if cancelled.

 dim kind as Integer
 dim choice as Integer

 SmReset()

 if ai_focus = 1 then
  if ai_cur(1) = 0 then
   SmAdd("List every AI to look at", "Enter", ENTER_KEY)
  elseif ai_index <> AIAssigned() then
   SmAdd("Use this AI for the monster", "Enter", ENTER_KEY)
  end if
 else
  kind = ai_cl_kind(AICondIndex())
  select case kind
   case ai_cl_condition
    SmAdd("Menu of this condition", "Enter", ENTER_KEY)
    SmAdd("Change condition set", "S", asc("s"))
    SmAdd("Add a condition", "Insert", INSERT_KEY)
    SmAdd("Delete this condition", "Delete", DELETE_KEY)
    SmAdd("Delete the whole pair", "D", asc("d"))
    SmAdd("Move pair up", "Comma", asc(","))
    SmAdd("Move pair down", "Period", asc("."))
    SmAdd("Copy the condition", "Ctrl-C", 3)
    SmAdd("Paste a condition", "Ctrl-V", 22)
   case ai_cl_addcond
    SmAdd("Add a condition", "Enter", ENTER_KEY)
    SmAdd("Paste a condition", "Ctrl-V", 22)
   case ai_cl_chooser
    SmAdd("Pick another script", "Enter", ENTER_KEY)
   case ai_cl_action
    SmAdd("Change this action", "Enter", ENTER_KEY)
    SmAdd("Add an action", "Insert", INSERT_KEY)
    SmAdd("Delete this action", "Delete", DELETE_KEY)
    SmAdd("Move action up", "Comma", asc(","))
    SmAdd("Move action down", "Period", asc("."))
    SmAdd("Copy the action", "Ctrl-C", 3)
    SmAdd("Paste an action", "Ctrl-V", 22)
   case ai_cl_addaction
    SmAdd("Add an action", "Enter", ENTER_KEY)
    SmAdd("Paste an action", "Ctrl-V", 22)
   case ai_cl_addpair
    SmAdd("Add a pair", "Enter", ENTER_KEY)
    if ai_clip_kind = 1 then SmAdd("Paste a pair", "Ctrl-V", 22)
  end select
 end if

 if ai_index <> AIAssigned() then SmAdd("Make the monster use AI " + str(ai_index), "A", asc("a"))
 if ai_index > 1 then SmAdd("Look at the previous AI", "P", asc("p"))
 if ai_index < total_ai_groups then SmAdd("Look at the next AI", "N", asc("n"))
 SmAdd("Look at an AI by number", "G", asc("g"))
 SmAdd("Switch regular and lunar bank", "L", asc("l"))
 if ai_reaction > 0 then SmAdd(iif(ai_on_reaction, "Switch to the attack AI", "Switch to the reaction AI"), "R", asc("r"))
 SmAdd("Undo", "Ctrl-Z", 26)
 SmAdd("Revert this AI to the loaded ROM", "Ctrl-R", 18)
 SmAdd("Back to the monster", "Esc", ESC_KEY)

 choice = SmRun("AI")
 if choice = 0 then return 0

 return sm_key(choice)

end function


sub EditMonsterAI(byref attack_index as Integer, byref reaction_index as Integer, byref lunar_flag as Boolean, monster_number as Integer, start_on_reaction as Boolean = false)

 dim k as UInteger
 dim done as Boolean
 dim go_text as String
 dim v as Integer
 dim pair_count as Integer
 dim count as Integer
 dim line_index as Integer

 ai_monster = monster_number
 ai_lunar = lunar_flag
 ai_attack = attack_index
 ai_reaction = reaction_index
 ai_on_reaction = start_on_reaction and reaction_index > 0
 ai_undo_count = 0
 ai_clip_kind = 0
 ai_focus = 2
 ai_pair = 0
 ai_message = ""
 AIChangeAI(AIAssigned())
 ai_list_focus = 3
 ai_cur(3) = iif(AIPanelCount(3) >= 1, 1, 0)

 do
  AICountUses()

  'the pair that the list is about
  pair_count = len(aigroupconditions(ai_index))
  if ai_pair > pair_count then ai_pair = pair_count
  if ai_pair < 1 and pair_count >= 1 then ai_pair = 1
  if ai_cp > pair_count then ai_cp = pair_count
  if ai_cp > 0 then ai_pair = ai_cp

  count = AIPanelCount(3)
  if ai_cur(3) > count then ai_cur(3) = count
  if ai_cur(3) < 0 then ai_cur(3) = 0

  AIBuildCondLines()
  line_index = AICondIndex()
  if line_index < ai_top(2) then ai_top(2) = line_index
  if line_index > ai_top(2) + ai_panel_inner(2) - 1 then ai_top(2) = line_index - ai_panel_inner(2) + 1
  if ai_top(2) < 1 then ai_top(2) = 1
  if ai_cur(1) > 1 then ai_cur(1) = 1

  AIDraw(ai_message)
  ai_message = ""
  k = AIReadKey()
  if k = SPACE_KEY then k = AIActions()
  ai_undo_group += 1

  select case k

   case ESC_KEY
    done = true

   case TAB_KEY
    ai_focus = 3 - ai_focus
   case asc("1")
    ai_focus = 1
   case asc("2"), asc("3")
    ai_focus = 2

   case UP_KEY, DOWN_KEY, PAGEUP_KEY, PAGEDOWN_KEY, HOME_KEY, END_KEY
    AIMoveCursor(k)

   case LEFT_KEY, RIGHT_KEY
    'panel 1: look at the previous or next AI; the others: the previous or next pair
    if ai_focus = 1 then
     if k = RIGHT_KEY and ai_index < total_ai_groups then AIChangeAI(ai_index + 1)
     if k = LEFT_KEY and ai_index > 1 then AIChangeAI(ai_index - 1)
    else
     AIChangePair(iif(k = RIGHT_KEY, 1, -1))
    end if

   case asc(","), asc(".")
    if ai_focus = 2 then
     if ai_cl_kind(AICondIndex()) = ai_cl_action then
      AIMoveAction(iif(k = asc(","), -1, 1))
     elseif ai_cl_kind(AICondIndex()) <> ai_cl_addpair then
      AIMovePair(iif(k = asc(","), -1, 1))
     end if
    end if

   case asc("n"), asc("N")
    if ai_index < total_ai_groups then AIChangeAI(ai_index + 1)
   case asc("p"), asc("P")
    if ai_index > 1 then AIChangeAI(ai_index - 1)
   case asc("g"), asc("G")
    go_text = PromptLine("Look at AI number, 1 to " + str(total_ai_groups) + ":", 3)
    v = val(go_text)
    if go_text <> "" and v >= 1 and v <= total_ai_groups then AIChangeAI(v)
   case asc("a"), asc("A")
    if ai_index <> AIAssigned() then
     AIAssign()
    else
     ai_message = "This monster already uses AI " + str(ai_index) + "."
    end if
   case asc("l"), asc("L")
    ai_lunar = not ai_lunar
    AIChangeAI(ai_index)
    ai_message = "Now working on the " + iif(ai_lunar, "LUNAR", "regular") + " bank of this monster."
   case asc("r"), asc("R")
    if ai_reaction > 0 then
     ai_on_reaction = not ai_on_reaction
     AIChangeAI(AIAssigned())
    else
     ai_message = "This monster has no reaction AI, turn it on in the monster's extras."
    end if

   case 26 'Ctrl-Z
    if not AIUndo() then ai_message = "Nothing to undo."

   case 18 'Ctrl-R
    if ConfirmBox("Put AI " + str(ai_index) + " and its parts back as in the loaded ROM?") then
     AIRestoreGroup(ai_original, ai_index, ai_lunar)
     AIRestoreOrphans(ai_original)
     ai_undo_count = 0
     AIChangeAI(ai_index)
     ai_message = "AI " + str(ai_index) + " is back as in the loaded ROM."
    end if

   case else
    if ai_focus = 1 then
     AIKeyAI(k)
    elseif ai_list_focus = 2 then
     AIKeyConditions(k)
    else
     AIKeyActions(k)
    end if

  end select

 loop until done

 attack_index = ai_attack
 reaction_index = ai_reaction
 lunar_flag = ai_lunar
 cls

end sub
