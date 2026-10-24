'Monster editor. The monster list is on the left; Enter on a monster moves the cursor into the boxes on the
'right, where every value is edited in place:
'
'  1 Monster   name, boss, level, HP, exp, gil
'  2 Graphics  pointer, size, palette (with a live picture)
'  3 Stats     attack, defense, magic defense, speed index, spell power
'  4 Drops     drop rate, drop index and the four drops
'  5 Extras    attack adds, resistances, weaknesses, races, reaction (switched on and off here)
'  6 AI        the attack AI, the bank (regular or lunar) and the reaction AI (opens the AI editor)
'
'Up and Down walk through all the rows, Tab or 1-6 jump to a box, Enter edits the row, Page Up and Page Down
'move to the previous or next monster, Esc goes back to the list.

const mon_panels = 6

dim shared mon_list as BlueMenu
dim shared mon_info as MonsterInfoMenu
dim shared mon_gfx as MonsterGfxMenu
dim shared mon_stats as MonsterStatsMenu
dim shared mon_drops as MonsterDropMenu
dim shared mon_flags as BlueMenu
dim shared mon_attack_elements as FlagMenu
dim shared mon_resistances as FlagMenu
dim shared mon_weaknesses as FlagMenu
dim shared mon_races as FlagMenu
dim shared mon_panel as Integer 'the box the cursor is in
dim shared mon_ai_row as Integer 'which of the three AI rows: attack AI, bank, reaction AI
dim shared mon_script_keys(255) as UInteger 'keys to feed the editor instead of the keyboard (for testing)
dim shared mon_script_count as Integer
dim shared mon_script_pos as Integer


function MonReadKey() as UInteger

 if mon_script_pos < mon_script_count then
  mon_script_pos += 1
  return mon_script_keys(mon_script_pos - 1)
 end if

 return getkey

end function


sub MonInit()

 mon_list = BlueMenu()
 mon_list.max_rows = screen_height - 3 'the bottom row is the hint line
 for i as Integer = 1 to total_monsters
  mon_list.AddOption(monsters(i).name)
 next

 'Layout: the monster list, then a 36 cell wide column of boxes (so their edges line up),
 ' then the AI column. Each box has a title in its top border.
 mon_info = MonsterInfoMenu(mon_list.options.Width() + 2, 0)
 mon_gfx = MonsterGfxMenu(mon_info.x, 8)
 mon_stats = MonsterStatsMenu(mon_info.x, mon_gfx.y + 5)
 mon_drops = MonsterDropMenu(mon_info.x, mon_stats.y + 7)
 mon_info.main_menu.min_width = 16
 mon_info.main_menu.title = "1 Monster"
 mon_gfx.main_menu.min_width = 16
 mon_gfx.main_menu.title = "2 Graphics"
 mon_stats.main_menu.min_width = 34
 mon_stats.main_menu.title = "3 Stats"
 mon_drops.main_menu.min_width = 21
 mon_drops.main_menu.title = "4 Drops"
 mon_flags = BlueMenu()
 mon_flags.x = mon_info.x + 23
 mon_flags.y = mon_drops.y
 mon_flags.title = "5 Extras"

 mon_flags.AddOption(FF4Text("Adds"))
 mon_flags.AddOption(FF4Text("Resistances"))
 mon_flags.AddOption(FF4Text("Weaknesses"))
 mon_flags.AddOption(FF4Text("Races"))
 mon_flags.AddOption(FF4Text("Reaction"))

 mon_attack_elements = FlagMenu(mon_info.x, mon_flags.y + 8, "status")
 mon_resistances = FlagMenu(mon_info.x, mon_attack_elements.y + 10, "status")
 'Weak and Races have room under the reaction AI box
 mon_weaknesses = FlagMenu(46, 43, "element")
 mon_races = FlagMenu(mon_weaknesses.x + 10, mon_weaknesses.y, "race")
 mon_attack_elements.main_menu.min_width = 10
 mon_attack_elements.main_menu.title = "Adds"
 mon_resistances.main_menu.min_width = 10
 mon_resistances.main_menu.title = "Resist"
 mon_weaknesses.main_menu.min_width = 7
 mon_weaknesses.main_menu.title = "Weak"
 mon_races.main_menu.min_width = 7
 mon_races.main_menu.title = "Races"


end sub


function MonFlagIsOn(m as Integer, row as Integer) as Boolean

 'row of the Extras box: 1 adds, 2 resistances, 3 weaknesses, 4 races, 5 reaction

 select case row
  case 1: return monsters(m).has_attack_element
  case 2: return monsters(m).has_resistances
  case 3: return monsters(m).has_weaknesses
  case 4: return monsters(m).has_race
 end select

 return monsters(m).has_reaction

end function


sub MonSetFlag(m as Integer, row as Integer, value as Boolean)

 select case row
  case 1: monsters(m).has_attack_element = value
  case 2: monsters(m).has_resistances = value
  case 3: monsters(m).has_weaknesses = value
  case 4: monsters(m).has_race = value
  case else: monsters(m).has_reaction = value
 end select

end sub


sub MonDrawAIBox(x as Integer, y as Integer, inner_h as Integer, title as String, index as Integer, lunar_flag as Boolean)

 'A box that sums up an AI: each pair with its first condition and all of its actions, as many as fit.
 ' The editor for it opens from the AI box of the cursor.

 dim row as Integer = y + 3
 dim last_row as Integer = y + inner_h
 dim pair_count as Integer
 dim script_n as Integer
 dim actions as Integer
 dim entry as AIScriptEntry ptr
 dim cut as Boolean

 BlueBox(x, y, 31, inner_h)
 LuText(title, x, y, 14)
 LuText("AI " + str(index), x + 1, y + 1, 15)
 LuText("Bank: " + iif(lunar_flag, "LUNAR, moon monster", "Regular"), x + 1, y + 2, iif(lunar_flag, 12, 23))

 ai_index = index
 ai_lunar = lunar_flag
 pair_count = len(aigroupconditions(index))
 for p as Integer = 1 to pair_count
  if row > last_row then
   cut = true
   exit for
  end if
  LuText(str(p), x + 1, row, 14)
  LuText("WHEN", x + 3, row, 21)
  WriteText(left(AIFirstCondition(p), 20), x + 9, row, 15)
  row += 1

  actions = 0
  if AIScriptExists(AIScriptId(p)) then
   script_n = AIScriptIndex(AIScriptId(p))
   actions = scripts(script_n).Length()
  end if
  if actions = 0 then
   if row <= last_row then LuText("THEN", x + 3, row, 22)
   if row <= last_row then LuText("no actions", x + 9, row, 23)
   row += 1
  else
   for j as Integer = 1 to actions
    if row > last_row then
     cut = true
     exit for
    end if
    entry = scripts(script_n).PointerAt(j)
    LuText("THEN", x + 3, row, 22)
    WriteText(left(entry->TextDescription(), 20), x + 9, row, 15)
    row += 1
   next
  end if
 next
 if row > last_row + 1 then cut = true

 'what did not fit is in the AI editor
 if cut then
  LuText(string(29, " "), x + 1, last_row, 15)
  LuText("more in the AI editor", x + 3, last_row, 23)
 end if

end sub


sub MonShow(m as Integer)

 'Draws every box for monster m

 for row as Integer = 1 to 5
  mon_flags.ChangeOption(row,, iif(MonFlagIsOn(m, row), 14, 23))
 next

 mon_info.SetTo(m)
 mon_gfx.SetTo(m)
 mon_stats.SetTo(m)
 mon_drops.SetTo(m)

 mon_info.Display()
 mon_gfx.Display()
 mon_stats.Display()
 mon_drops.Display()
 mon_flags.Display()

 MonDrawAIBox(46, 0, 25, " 6 ATTACK AI ", monsters(m).attack_sequence_group + 1, monsters(m).lunar)
 MonsterThumbnail(m, 29, 0, 15, 11)

 if monsters(m).has_attack_element then
  for i as Integer = 1 to 24
   mon_attack_elements.SetFlag(i, monsters(m).attack_element.flags(i))
  next
  mon_attack_elements.Display()
 else
  mon_attack_elements.Hide()
 end if

 if monsters(m).has_resistances then
  for i as Integer = 1 to 24
   mon_resistances.SetFlag(i, monsters(m).resistances.flags(i))
  next
  mon_resistances.Display()
 else
  mon_resistances.Hide()
 end if

 if monsters(m).has_weaknesses then
  for i as Integer = 1 to 8
   mon_weaknesses.SetFlag(i, monsters(m).weaknesses.flags(i))
  next
  mon_weaknesses.Display()
 else
  mon_weaknesses.Hide()
 end if

 if monsters(m).has_race then
  for i as Integer = 1 to 8
   mon_races.SetFlag(i, monsters(m).races.flags(i))
  next
  mon_races.Display()
 else
  mon_races.Hide()
 end if

 if monsters(m).has_reaction then
  MonDrawAIBox(46, 27, 14, " REACTION AI ", monsters(m).reaction_index + 1, monsters(m).lunar)
 else
  line (46 * 8, 27 * 8)-(78 * 8 - 1, 43 * 8 - 1), RGB(0, 0, 0), bf
 end if

end sub


sub MonOpenAI(m as Integer, on_reaction as Boolean)

 'The full screen AI editor for monster m (on its reaction AI if on_reaction)

 dim attack_ai as Integer = monsters(m).attack_sequence_group + 1
 dim reaction_ai as Integer = 0
 dim ai_lunar_flag as Boolean = monsters(m).lunar

 if monsters(m).has_reaction then reaction_ai = monsters(m).reaction_index + 1
 EditMonsterAI(attack_ai, reaction_ai, ai_lunar_flag, m, on_reaction)
 monsters(m).lunar = ai_lunar_flag
 monsters(m).attack_sequence_group = attack_ai - 1
 if reaction_ai > 0 then monsters(m).reaction_index = reaction_ai - 1

 'the AI editor clears the screen
 cls
 mon_list.Display()

end sub


sub MonEditExtra(m as Integer, row as Integer)

 'Enter on a row of the Extras box: switches the extra on if it is off, then edits its details

 if not MonFlagIsOn(m, row) then
  MonSetFlag(m, row, true)
  MonShow(m)
 end if

 select case row

  case 1
   mon_attack_elements.UserSelect()
   for i as Integer = 1 to 24
    monsters(m).attack_element.flags(i) = mon_attack_elements.flags(i)
   next

  case 2
   mon_resistances.UserSelect()
   for i as Integer = 1 to 24
    monsters(m).resistances.flags(i) = mon_resistances.flags(i)
   next

  case 3
   mon_weaknesses.UserSelect()
   for i as Integer = 1 to 8
    monsters(m).weaknesses.flags(i) = mon_weaknesses.flags(i)
   next

  case 4
   mon_races.UserSelect()
   for i as Integer = 1 to 8
    monsters(m).races.flags(i) = mon_races.flags(i)
   next

  case 5
   MonOpenAI(m, true)

 end select

end sub


function MonPanelMenu(panel as Integer) as BlueMenu ptr

 select case panel
  case 1: return @mon_info.main_menu
  case 2: return @mon_gfx.main_menu
  case 3: return @mon_stats.main_menu
  case 4: return @mon_drops.main_menu
 end select

 return @mon_flags

end function


function MonPanelRows(panel as Integer) as Integer

 if panel = 6 then return 3
 return MonPanelMenu(panel)->options.Length()

end function


function MonCursorRow(panel as Integer) as Integer

 if panel = 6 then return mon_ai_row
 return MonPanelMenu(panel)->selected

end function


sub MonSetCursorRow(panel as Integer, row as Integer)

 if panel = 6 then
  mon_ai_row = row
 else
  MonPanelMenu(panel)->ChangeSelected(row)
 end if

end sub


sub MonDrawCursor()

 'The arrow beside the row being edited

 dim menu_ptr as BlueMenu ptr

 if mon_panel = 6 then
  DrawLetter(20, 45, iif(mon_ai_row = 1, 1, iif(mon_ai_row = 2, 2, 28)))
 else
  menu_ptr = MonPanelMenu(mon_panel)
  menu_ptr->ShowCursor()
 end if

end sub


function MonHint(m as Integer) as String

 'What Enter does on the row the cursor is on

 dim row as Integer = MonCursorRow(mon_panel)

 select case mon_panel
  case 1
   select case row
    case 1: return "Enter types the name. Up Down move, Tab or 1 to 6 jump to a box."
    case 2: return "Enter or Space switches Boss on and off."
    case else: return "Enter types a number."
   end select
  case 2
   select case row
    case 1: return "Enter picks the graphics from a template or by number, with a live picture."
    case 2: return "Enter picks the size. Bosses also get their special size settings."
    case else: return "Enter types the palette number, the picture follows."
   end select
  case 3
   if row <= 3 then return "Enter picks a stat group, then edits its base, multiplier and percentage."
   if row = 4 then return "Enter picks a speed group, then edits its range."
   if monsters(m).has_spell_power then return "Enter types the spell power. Space or Delete switches it off."
   return "Enter or Space gives this monster a spell power. It is off now."
  case 4
   if row <= 2 then return "Enter types a number. The index decides which four drops are used."
   return "Enter picks the item. The drops belong to the drop index, shared by monsters."
  case 5
   if MonFlagIsOn(m, row) then return "Enter edits the details. Space or Delete switches it off. Yellow is on."
   return "Enter or Space switches it on and edits it. Yellow is on."
  case else
   if mon_ai_row = 1 then return "Enter opens the AI editor for the attack AI of this monster."
   if mon_ai_row = 2 then return "Enter or Space switches the AI bank. Moon monsters use LUNAR. L does it from any box."
   if monsters(m).has_reaction then return "Enter opens the AI editor on the reaction AI of this monster."
   return "No reaction AI. Switch Reaction on in box 5 to give this monster one."
 end select

end function


sub MonDrawHint(m as Integer, message as String)

 line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf
 WriteText(FF4Text(left(iif(message <> "", message, MonHint(m)), 78)), 1, 57, 14)

end sub


sub MonFields()

 'The cursor in the boxes. Returns when Esc is pressed.

 dim k as UInteger
 dim done as Boolean
 dim m as Integer
 dim row as Integer
 dim rows as Integer
 dim message as String

 mon_panel = 1
 mon_ai_row = 1
 for p as Integer = 1 to 5
  MonSetCursorRow(p, 1)
 next

 do
  m = mon_list.selected
  MonShow(m)
  MonDrawCursor()
  MonDrawHint(m, message)
  message = ""
  k = MonReadKey()
  row = MonCursorRow(mon_panel)
  rows = MonPanelRows(mon_panel)

  select case k

   case ESC_KEY
    done = true

   case asc("l"), asc("L")
    'the regular or the lunar AI bank, from any box
    monsters(m).lunar = not monsters(m).lunar
    message = "AI bank: " + iif(monsters(m).lunar, "LUNAR", "regular") + "."
   case TAB_KEY
    mon_panel = mon_panel mod mon_panels + 1
   case asc("1") to asc("6")
    mon_panel = k - asc("0")

   case UP_KEY
    if row > 1 then
     MonSetCursorRow(mon_panel, row - 1)
    else
     mon_panel = iif(mon_panel = 1, mon_panels, mon_panel - 1)
     MonSetCursorRow(mon_panel, MonPanelRows(mon_panel))
    end if
   case DOWN_KEY
    if row < rows then
     MonSetCursorRow(mon_panel, row + 1)
    else
     mon_panel = mon_panel mod mon_panels + 1
     MonSetCursorRow(mon_panel, 1)
    end if
   case HOME_KEY
    MonSetCursorRow(mon_panel, 1)
   case END_KEY
    MonSetCursorRow(mon_panel, rows)

   case PAGEUP_KEY, PAGEDOWN_KEY
    'the same row of the previous or next monster
    if k = PAGEUP_KEY and mon_list.selected > 1 then
     UndoPush("monsters", mon_list.selected - 1)
     mon_list.ChangeSelected(mon_list.selected - 1)
    elseif k = PAGEDOWN_KEY and mon_list.selected < mon_list.options.Length() then
     UndoPush("monsters", mon_list.selected + 1)
     mon_list.ChangeSelected(mon_list.selected + 1)
    end if

   case ENTER_KEY, SPACE_KEY, DELETE_KEY
    select case mon_panel

     case 1
      if k = SPACE_KEY and row = 2 then
       monsters(m).boss = not monsters(m).boss
      elseif k = ENTER_KEY then
       mon_info.SetTo(m)
       mon_info.EditField(row)
       mon_list.ChangeOption(m, monsters(m).name)
      end if

     case 2
      if k = ENTER_KEY then
       mon_gfx.SetTo(m)
       mon_gfx.EditField(row)
      end if

     case 3
      if k = ENTER_KEY then
       mon_stats.SetTo(m)
       mon_stats.EditField(row)
      elseif row = 5 and k = SPACE_KEY then
       monsters(m).has_spell_power = not monsters(m).has_spell_power
      elseif row = 5 and monsters(m).has_spell_power then
       monsters(m).has_spell_power = false
      end if

     case 4
      if k = ENTER_KEY then
       mon_drops.SetTo(m)
       mon_drops.EditField(row)
      end if

     case 5
      if k = ENTER_KEY then
       MonEditExtra(m, row)
      elseif k = SPACE_KEY then
       MonSetFlag(m, row, not MonFlagIsOn(m, row))
      elseif MonFlagIsOn(m, row) then
       MonSetFlag(m, row, false)
      end if

     case else
      if mon_ai_row = 2 then
       if k = ENTER_KEY or k = SPACE_KEY then monsters(m).lunar = not monsters(m).lunar
      elseif k = ENTER_KEY then
       if mon_ai_row = 1 then
        MonOpenAI(m, false)
       elseif monsters(m).has_reaction then
        MonOpenAI(m, true)
       else
        message = "This monster has no reaction AI. Switch Reaction on in box 5 first."
       end if
      end if

    end select

  end select

 loop until done

end sub


sub EditMonsters()

 MonInit()

 do

  do
   MonShow(mon_list.selected)
  loop until ListInput(mon_list, "monsters")

  if not mon_list.cancelled then
   MonFields()
   mon_list.Display()
  end if

 loop until mon_list.cancelled

end sub
