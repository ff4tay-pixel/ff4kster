'Dialogs for editing one enemy AI condition and one AI script action. The full screen AI editor
'(editai.bas) opens them on top of its own screen. They are the pickers that used to be built into
'the AI column of the monster editor: a menu of the kinds, then menus and number inputs for the
'parameters, each one opening a little to the right and below the one before it. ax and ay say
'where the first menu goes.


function AIEditCondition(conditionindex as Integer, ax as Integer, ay as Integer) as Boolean

 'Changes the kind of condition and its parameters. Returns false if cancelled before anything changed.

 dim condition_types as BlueMenu
 dim units as BlueMenu

 condition_types = BlueMenu(ax, ay)
 condition_types.max_rows = 12
 condition_types.AddOption(FF4Text("unit has status"))
 condition_types.AddOption(FF4Text("unit has low HP"))
 condition_types.AddOption(FF4Text("flag index"))
 condition_types.AddOption(FF4Text("character is defeated"))
 condition_types.AddOption(FF4Text("monster is defeated"))
 condition_types.AddOption(FF4Text("formation index"))
 condition_types.AddOption(FF4Text("all monsters are same type"))
 condition_types.AddOption(FF4Text("unit uses command _07"))
 condition_types.AddOption(FF4Text("unit uses command _08"))
 condition_types.AddOption(FF4Text("unknown"))
 condition_types.AddOption(FF4Text("takes damage"))
 condition_types.AddOption(FF4Text("only monster left"))
 condition_types.AddOption(FF4Text("no condition"))
 condition_types.ChangeSelected(Min(conditions(conditionindex).condition + 1, condition_types.options.Length()))
 condition_types.UserSelect()
 if condition_types.cancelled then return false
 conditions(conditionindex).condition = condition_types.selected - 1
 condition_types.Display()

 units.max_rows = 12
 for i as Integer = 0 to &hFF
  units.AddOption(FF4Text("unit " + str(i)))
 next
 units.ChangeOption(23 + 1, FF4Text("self"))
 units.ChangeOption(25 + 1, FF4Text("a character"))
 
 select case conditions(conditionindex).condition
 
  case 0 'Unit has status
   units.x = condition_types.x + 2
   units.y = condition_types.y + 2
   units.ChangeSelected(conditions(conditionindex).xx + 1)
   units.UserSelect()
   if not units.cancelled then
    units.Display()
    dim status_byte as BlueMenu
    status_byte = BlueMenu(units.x + 2, units.y + 2)
    status_byte.max_rows = 12
    status_byte.AddOption(FF4Text("Persistent statuses"))
    status_byte.AddOption(FF4Text("Temporary statuses"))
    status_byte.AddOption(FF4Text("System statuses"))
    status_byte.AddOption(FF4Text("Hidden statuses"))
    status_byte.ChangeSelected(conditions(conditionindex).yy + 1)
    status_byte.UserSelect()
    if not status_byte.cancelled then
     status_byte.Display()
     dim status_menu as FlagMenu
     select case status_byte.selected
      case 1
       status_menu = FlagMenu(status_byte.x + 2, status_byte.y + 2, "persistent status")
      case 2
       status_menu = FlagMenu(status_byte.x + 2, status_byte.y + 2, "temporary status")
      case 3
       status_menu = FlagMenu(status_byte.x + 2, status_byte.y + 2, "system status")
      case 4
       status_menu = FlagMenu(status_byte.x + 2, status_byte.y + 2, "hidden status")
     end select
     for i as Integer = 1 to 8
      if conditions(conditionindex).zz and 2 ^ (i - 1) then status_menu.SetFlag(i) 'else status_menu.SetFlag(i, false)
     next
     status_menu.UserSelect()
     conditions(conditionindex).xx = units.selected - 1
     conditions(conditionindex).yy = status_byte.selected - 1
     conditions(conditionindex).zz = 0
     for i as integer = 1 to 8
      if status_menu.flags(i) then conditions(conditionindex).zz += 2 ^ (i - 1)
     next
     status_byte.Hide()
    end if
    units.Hide()
   end if
   
  case 1 'Unit has low HP
   units.x = condition_types.x + 2
   units.y = condition_types.y + 2
   units.ChangeSelected(conditions(conditionindex).xx + 1)
   units.UserSelect()
   if not units.cancelled then
    units.Display()
    dim select_hp as BlueMenu
    select_hp = BlueMenu(units.x + 2, units.y + 2)
    select_hp.max_rows = 12
    for i as Integer = 1 to total_condition_hps
     select_hp.AddOption(FF4Text(str(conditionhp(i)) + " HP"))
    next
    select_hp.ChangeSelected(conditions(conditionindex).zz + 1)
    select_hp.UserSelect()
    if not select_hp.cancelled then
     dim change_hp as BlueNumberInput
     change_hp = BlueNumberInput(select_hp.x, select_hp.y)
     change_hp.starting_number = conditionhp(select_hp.selected)
     change_hp.max_value = &hFFFF
     change_hp.UserSelect()
     conditionhp(select_hp.selected) = change_hp.number
     conditions(conditionindex).xx = units.selected - 1
     conditions(conditionindex).yy = 0
     conditions(conditionindex).zz = select_hp.selected - 1
    end if
    units.Hide()
   end if
   
  case 2 'Flag index
   dim flag_type as BlueMenu
   flag_type = BlueMenu(condition_types.x + 2, condition_types.y + 2)
   flag_type.AddOption(FF4Text("Condition flag"))
   flag_type.AddOption(FF4Text("Reaction flag"))
   if conditions(conditionindex).yy > 0 then flag_type.ChangeSelected(2)
   flag_type.UserSelect()
   if not flag_type.cancelled then
    flag_type.Display()
    dim flag_index as BlueNumberInput
    flag_index = BlueNumberInput(flag_type.x + 2, flag_type.y + 2)
    flag_index.starting_number = conditions(conditionindex).zz
    flag_index.UserSelect()
    conditions(conditionindex).xx = 0
    conditions(conditionindex).yy = flag_type.selected - 1
    conditions(conditionindex).zz = flag_index.number
    flag_type.Hide()
   end if
   
  case 3 'Character is defeated
   dim character_index as BlueNumberInput
   character_index = BlueNumberInput(condition_types.x + 2, condition_types.y + 2)
   character_index.starting_number = conditions(conditionindex).xx
   character_index.UserSelect()
   conditions(conditionindex).xx = character_index.number
   conditions(conditionindex).yy = 0
   conditions(conditionindex).zz = 0
   
  case 4 'Monster is defeated
   dim monster_index as BlueNumberInput
   monster_index = BlueNumberInput(condition_types.x + 2, condition_types.y + 2)
   monster_index.starting_number = conditions(conditionindex).xx
   monster_index.UserSelect()
   conditions(conditionindex).xx = monster_index.number
   conditions(conditionindex).yy = 0
   conditions(conditionindex).zz = 0
   
  case 5 'Formation index
   dim select_world as BlueMenu
   select_world = BlueMenu(condition_types.x + 2, condition_types.y + 2)
   select_world.AddOption(FF4Text("Overworld"))
   select_world.AddOption(FF4Text("Underground/Moon"))
   if conditions(conditionindex).yy > 0 then select_world.ChangeSelected(2)
   select_world.UserSelect()
   if not select_world.cancelled then
    select_world.Display()
    dim formation_index as BlueNumberInput
    formation_index = BlueNumberInput(select_world.x + 2, select_world.y + 2)
    formation_index.min_value = 1
    formation_index.max_value = 256
    formation_index.starting_number = conditions(conditionindex).zz + 1
    formation_index.UserSelect()
    conditions(conditionindex).xx = 0
    conditions(conditionindex).yy = select_world.selected - 1
    conditions(conditionindex).zz = formation_index.number - 1
    select_world.Hide()
   end if
   
  case 6, 9, 10, 11
   conditions(conditionindex).xx = 0
   conditions(conditionindex).yy = 0
   conditions(conditionindex).zz = 0
   
  case 7, 8
   units.ChangeOption(1, FF4Text("Any unit"))
   units.x = condition_types.x + 2
   units.y = condition_types.y + 2
   units.ChangeSelected(conditions(conditionindex).xx + 1)
   units.UserSelect()
   if not units.cancelled then
    units.Display()
    dim select_command as BlueMenu
    select_command = BlueMenu(units.x + 2, units.y + 2)
    select_command.max_rows = 12
    for i as Integer = 1 to 256
     select_command.AddOption(FF4Text("Command " + str(i - 1)))
    next
    select_command.ChangeOption(193, menucommands(1).name)
    select_command.ChangeOption(195, FF4Text("magic"))
    select_command.ChangeOption(197, menucommands(5).name)
    select_command.ChangeOption(198, menucommands(6).name)
    select_command.ChangeOption(200, menucommands(8).name)
    select_command.ChangeOption(201, menucommands(9).name)
    select_command.ChangeOption(205, menucommands(13).name)
    select_command.ChangeOption(206, menucommands(14).name)
    select_command.ChangeOption(207, menucommands(15).name)
    select_command.ChangeOption(209, menucommands(17).name)
    select_command.ChangeOption(211, menucommands(19).name)
    select_command.ChangeOption(213, menucommands(21).name)
    select_command.ChangeOption(215, menucommands(23).name)
    select_command.ChangeOption(216, menucommands(24).name)
    select_command.ChangeOption(223, menucommands(7).name)
    select_command.ChangeSelected(conditions(conditionindex).yy + 1)
    select_command.UserSelect()
    if not select_command.cancelled then
     select_command.Display()
     dim elements as FlagMenu
     elements = FlagMenu(select_command.x + 2, select_command.y + 2, "element")
     for i as Integer = 1 to 8
      if conditions(conditionindex).zz and 2 ^ (i - 1) then elements.SetFlag(i)
     next
     elements.UserSelect()
     conditions(conditionindex).xx = units.selected - 1
     conditions(conditionindex).yy = select_command.selected - 1
     conditions(conditionindex).zz = 0
     for i as Integer = 1 to 8
      if elements.flags(i) then conditions(conditionindex).zz += 2 ^ (i - 1)
     next
     select_command.Hide()
    end if
    units.Hide()
   end if
   
 end select

 condition_types.Hide()
 return true

end function


function AIEditScriptEntry(entry as AIScriptEntry ptr, ax as Integer, ay as Integer) as Boolean

 'Changes the kind of action and its parameter. Returns false if cancelled.

 dim script_functions as BlueMenu
 dim confirm as Boolean = false
 dim p as UByte

 script_functions = BlueMenu(ax, ay)
 script_functions.max_rows = 12
 script_functions.type_ahead = true
 script_functions.AddOption(FF4Text("Cast a single-targeted spell"))
 script_functions.AddOption(FF4Text("Cast a group-targeted spell"))
 script_functions.AddOption(FF4Text("Use a monster technique"))
 script_functions.AddOption(FF4Text("Use a menu command"))
 script_functions.AddOption(FF4Text("Do nothing"))
 script_functions.AddOption(FF4Text("Change race"))
 script_functions.AddOption(FF4Text("Change attack"))
 script_functions.AddOption(FF4Text("Change defense"))
 script_functions.AddOption(FF4Text("Change magic defense"))
 script_functions.AddOption(FF4Text("Modify speed"))
 script_functions.AddOption(FF4Text("Set resistances"))
 script_functions.AddOption(FF4Text("Set spell power"))
 script_functions.AddOption(FF4Text("Set weakness"))
 script_functions.AddOption(FF4Text("Set sprite"))
 script_functions.AddOption(FF4Text("Show message"))
 script_functions.AddOption(FF4Text("Next action, show message"))
 script_functions.AddOption(FF4Text("Change music"))
 script_functions.AddOption(FF4Text("Set condition flag"))
 script_functions.AddOption(FF4Text("Set reaction"))
 script_functions.AddOption(FF4Text("Unknown _F6"))
 script_functions.AddOption(FF4Text("Darken screen"))
 script_functions.AddOption(FF4Text("Debug display"))
 script_functions.AddOption(FF4Text("Target"))
 script_functions.AddOption(FF4Text("Unknown _FA"))
 script_functions.AddOption(FF4Text("Chain into"))
 script_functions.AddOption(FF4Text("End chain"))
 script_functions.AddOption(FF4Text("Start a chain"))
 script_functions.AddOption(FF4Text("Wait"))
 script_functions.ChangeSelected(entry->FunctionToIndex())
 script_functions.UserSelect()
 if script_functions.cancelled then return false
 script_functions.Display()
 p = entry->parameter

 select case script_functions.selected

  case 1 'Cast a single-targeted spell
   dim pmenu as BlueMenu
   pmenu = BlueMenu(script_functions.x + 2, script_functions.y + 2)
   pmenu.max_rows = 12
   pmenu.type_ahead = true
   for i as Integer = 1 to &h30
    pmenu.AddOption(spells(i).name)
   next
   pmenu.ChangeSelected(entry->function_call)
   pmenu.UserSelect()
   if not pmenu.cancelled then
    confirm = true
    p = pmenu.selected
   end if

  case 2 'Cast a group-targeted spell
   dim pmenu as BlueMenu
   pmenu = BlueMenu(script_functions.x + 2, script_functions.y + 2)
   pmenu.max_rows = 12
   pmenu.type_ahead = true
   for i as Integer = &h1 to &h2E
    pmenu.AddOption(spells(i).name)
   next
   pmenu.ChangeSelected(entry->function_call - &h30)
   pmenu.UserSelect()
   if not pmenu.cancelled then
    confirm = true
    p = pmenu.selected - 1
   end if

  case 3 'Use a monster technique
   dim pmenu as BlueMenu
   pmenu = BlueMenu(script_functions.x + 2, script_functions.y + 2)
   pmenu.max_rows = 12
   pmenu.type_ahead = true
   for i as Integer = &h5F to &hBF
    pmenu.AddOption(spells(i).name)
   next
   pmenu.ChangeSelected(entry->function_call - &h5E)
   pmenu.UserSelect()
   if not pmenu.cancelled then
    confirm = true
    p = pmenu.selected - 1
   end if

  case 4 'Use a menu command
   dim pmenu as BlueMenu
   pmenu = BlueMenu(script_functions.x + 2, script_functions.y + 2)
   pmenu.max_rows = 12
   pmenu.type_ahead = true
   for i as Integer = 1 to &h27
    if i <= total_commands then
     pmenu.AddOption(menucommands(i).name)
    else
     pmenu.AddOption(FF4Text("Unknown"))
    end if
   next
   pmenu.ChangeSelected(entry->function_call - &hBF)
   pmenu.UserSelect()
   if not pmenu.cancelled then
    confirm = true
    p = pmenu.selected - 1
   end if
  
  case 5 'Do nothing
   confirm = true
   p = 0
   
  case 6 'Change race
   dim pmenu as FlagMenu
   pmenu = FlagMenu(script_functions.x + 2, script_functions.y + 2, "race")
   for i as Integer = 1 to 8
    if entry->parameter and 2 ^ (i - 1) then pmenu.SetFlag(i)
   next
   pmenu.UserSelect()
   confirm = true
   p = 0
   for i as Integer = 1 to 8
    if pmenu.flags(i) then p += 2 ^ (i - 1)
   next
  
  case 7 'Change attack
   dim pmenu as BlueMenu
   pmenu = BlueMenu(script_functions.x + 2, script_functions.y + 2)
   pmenu.max_rows = 12
   for i as Integer = 1 to total_stat_groups
    pmenu.AddOption(FF4Text(str(stat_groups(i).percentage) + "% " + str(stat_groups(i).stat_base) + " x" + str(stat_groups(i).multiplier)))
   next
   pmenu.ChangeSelected(entry->parameter + 1)
   pmenu.UserSelect()
   if not pmenu.cancelled then
    confirm = true
    p = pmenu.selected - 1
   end if
  
  case 8 'Change defense
   dim pmenu as BlueMenu
   pmenu = BlueMenu(script_functions.x + 2, script_functions.y + 2)
   pmenu.max_rows = 12
   for i as Integer = 1 to total_stat_groups
    pmenu.AddOption(FF4Text(str(stat_groups(i).percentage) + "% " + str(stat_groups(i).stat_base) + " x" + str(stat_groups(i).multiplier)))
   next
   pmenu.ChangeSelected(entry->parameter + 1)
   pmenu.UserSelect()
   if not pmenu.cancelled then
    confirm = true
    p = pmenu.selected - 1
   end if
  
  case 9 'Change magic defense
   dim pmenu as BlueMenu
   pmenu = BlueMenu(script_functions.x + 2, script_functions.y + 2)
   pmenu.max_rows = 12
   for i as Integer = 1 to total_stat_groups
    pmenu.AddOption(FF4Text(str(stat_groups(i).percentage) + "% " + str(stat_groups(i).stat_base) + " x" + str(stat_groups(i).multiplier)))
   next
   pmenu.ChangeSelected(entry->parameter + 1)
   pmenu.UserSelect()
   if not pmenu.cancelled then
    confirm = true
    p = pmenu.selected - 1
   end if
  
  case 10 'Modify speed
   dim pmenu as BlueNumberInput
   pmenu = BlueNumberInput(script_functions.x + 2, script_functions.y + 2)
   pmenu.starting_number = entry->parameter
   pmenu.number = pmenu.starting_number
   pmenu.UserSelect()
   confirm = true
   p = pmenu.number

  case 11 'Set resistances
   dim pmenu as FlagMenu
   pmenu = FlagMenu(script_functions.x + 2, script_functions.y + 2, "element")
   for i as Integer = 1 to 8
    if entry->parameter and 2 ^ (i - 1) then pmenu.SetFlag(i)
   next
   pmenu.UserSelect()
   confirm = true
   p = 0
   for i as Integer = 1 to 8
    if pmenu.flags(i) then p += 2 ^ (i - 1)
   next
  
  case 12 'Set spell power
   dim pmenu as BlueNumberInput
   pmenu = BlueNumberInput(script_functions.x + 2, script_functions.y + 2)
   pmenu.starting_number = entry->parameter
   pmenu.number = pmenu.starting_number
   pmenu.UserSelect()
   confirm = true
   p = pmenu.number
   
  case 13 'Set weakness
   dim pmenu as FlagMenu
   pmenu = FlagMenu(script_functions.x + 2, script_functions.y + 2, "element")
   for i as Integer = 1 to 8
    if entry->parameter and 2 ^ (i - 1) then pmenu.SetFlag(i)
   next
   pmenu.UserSelect()
   confirm = true
   p = 0
   for i as Integer = 1 to 8
    if pmenu.flags(i) then p += 2 ^ (i - 1)
   next

  case 14 'Set sprite
   dim pmenu as BlueNumberInput
   pmenu = BlueNumberInput(script_functions.x + 2, script_functions.y + 2)
   pmenu.starting_number = entry->parameter
   pmenu.number = pmenu.starting_number
   pmenu.UserSelect()
   confirm = true
   p = pmenu.number
   
  case 15 'Show message
   dim pmenu as BlueMenu
   pmenu = BlueMenu(script_functions.x + 2, script_functions.y + 2)
   pmenu.max_rows = 12
   for i as Integer = 1 to dialogues_battle.Length()
    pmenu.AddOption(dialogues_battle.ItemAt(i))
   next
   pmenu.ChangeSelected(entry->parameter + 1)
   pmenu.UserSelect()
   if not pmenu.cancelled then
    confirm = true
    p = pmenu.selected - 1
   end if
  
  case 16 'Next action, show message
   dim pmenu as BlueMenu
   pmenu = BlueMenu(script_functions.x + 2, script_functions.y + 2)
   pmenu.max_rows = 12
   for i as Integer = 1 to dialogues_battle.Length()
    pmenu.AddOption(dialogues_battle.ItemAt(i))
   next
   pmenu.ChangeSelected(entry->parameter + 1)
   pmenu.UserSelect()
   if not pmenu.cancelled then
    confirm = true
    p = pmenu.selected - 1
   end if

  case 17 'Change music
   dim pmenu as BlueMenu
   pmenu = BlueMenu(script_functions.x + 2, script_functions.y + 2)
   pmenu.max_rows = 12
   for i as Integer = 1 to total_songs
    pmenu.AddOption(song_names.ItemAt(i))
   next
   pmenu.ChangeSelected(entry->parameter + 1)
   pmenu.UserSelect()
   if not pmenu.cancelled then
    confirm = true
    p = pmenu.selected - 1
   end if

  case 18 'Set condition flag
   dim pmenu as BlueNumberInput
   pmenu = BlueNumberInput(script_functions.x + 2, script_functions.y + 2)
   pmenu.starting_number = entry->parameter
   pmenu.number = pmenu.starting_number
   pmenu.UserSelect()
   confirm = true
   p = pmenu.number
   
  case 19 'Set reaction
   dim pmenu as BlueNumberInput
   pmenu = BlueNumberInput(script_functions.x + 2, script_functions.y + 2)
   pmenu.starting_number = entry->parameter
   pmenu.number = pmenu.starting_number
   pmenu.UserSelect()
   confirm = true
   p = pmenu.number
   
  case 20 'Unknown _F6
   dim pmenu as BlueNumberInput
   pmenu = BlueNumberInput(script_functions.x + 2, script_functions.y + 2)
   pmenu.starting_number = entry->parameter
   pmenu.number = pmenu.starting_number
   pmenu.UserSelect()
   confirm = true
   p = pmenu.number
   
  case 21 'Unknown _F7
   dim pmenu as BlueNumberInput
   pmenu = BlueNumberInput(script_functions.x + 2, script_functions.y + 2)
   pmenu.starting_number = entry->parameter
   pmenu.number = pmenu.starting_number
   pmenu.UserSelect()
   confirm = true
   p = pmenu.number
   
  case 22 'Unknown _F8
   dim pmenu as BlueNumberInput
   pmenu = BlueNumberInput(script_functions.x + 2, script_functions.y + 2)
   pmenu.starting_number = entry->parameter
   pmenu.number = pmenu.starting_number
   pmenu.UserSelect()
   confirm = true
   p = pmenu.number
   
  case 23 'Target
   dim pmenu as BlueMenu
   pmenu = BlueMenu(script_functions.x + 2, script_functions.y + 2)
   pmenu.max_rows = 12
   for i as Integer = 0 to &h15
    if i > 0 and i <= total_actors then
     pmenu.AddOption(actor_names.ItemAt(i))
    else
     pmenu.AddOption(FF4Text("Unknown"))
    end if
   next
   pmenu.AddOption(FF4Text("self"))
   pmenu.AddOption(FF4Text("all monsters"))
   pmenu.AddOption(FF4Text("all other monsters"))
   pmenu.AddOption(FF4Text("all Type 1 monsters"))
   pmenu.AddOption(FF4Text("all Type 2 monsters"))
   pmenu.AddOption(FF4Text("all Type 3 monsters"))
   pmenu.AddOption(FF4Text("all front row characters"))
   pmenu.AddOption(FF4Text("all back row characters"))
   pmenu.AddOption(FF4Text("a stunned monster"))
   pmenu.AddOption(FF4Text("an asleep monster"))
   pmenu.AddOption(FF4Text("a charmed monster"))
   pmenu.AddOption(FF4Text("a critical monster"))
   pmenu.AddOption(FF4Text("random monster or character"))
   pmenu.AddOption(FF4Text("random other monster or character"))
   pmenu.AddOption(FF4Text("random monster"))
   pmenu.AddOption(FF4Text("random other monster"))
   pmenu.AddOption(FF4Text("random front row character"))
   pmenu.AddOption(FF4Text("random back row character"))
   pmenu.AddOption(FF4Text("all characters"))
   pmenu.AddOption(FF4Text("all KO monsters"))
   pmenu.ChangeSelected(entry->parameter + 1)
   pmenu.UserSelect()
   if not pmenu.cancelled then
    confirm = true
    p = pmenu.selected - 1
   end if
   
  case else
   confirm = true

 end select

 script_functions.Hide()
 if confirm then entry->IndexToFunction(script_functions.selected, p)
 return confirm

end function
