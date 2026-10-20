constructor MonsterStatsMenu(starting_x as UByte = 0, starting_y as UByte = 0)

 x = starting_x
 y = starting_y
 main_menu = BlueMenu(x, y)

 indexed_stat_group_menu = BlueMenu(x + 13)
 indexed_stat_group_menu.max_rows = 1
 for i as Integer = 1 to total_stat_groups
  indexed_stat_group_menu.AddOption(FF4Text(Pad(str(i), 3, true) + ": " + Pad(str(stat_groups(i).stat_base), 3, true) + "  x" + Pad(str(stat_groups(i).multiplier), 3) + "  " + Pad(str(stat_groups(i).percentage), 3, true) + "%"))
 next
 
 stat_group_menu = BlueMenu(x + 17)
 stat_group_menu.columns = 3

 indexed_speed_group_menu = BlueMenu(x + 13, y + 3)
 indexed_speed_group_menu.max_rows = 1
 for i as Integer = 1 to total_speed_groups
  indexed_speed_group_menu.AddOption(FF4Text(Pad(str(i), 3, true) + ": " + Pad(str(speed_groups(i).low), 3, true) + " to  " + Pad(str(speed_groups(i).high), 3, true)))
 next
 
 speed_group_menu = BlueMenu(x + 17, y + 3)
 speed_group_menu.columns = 2

end constructor


sub MonsterStatsMenu.Display()

 main_menu.Display()
 
end sub


sub MonsterStatsMenu.SetTo(new_index as UByte)

 index = new_index
 attack = monsters(index).physical_attack_index + 1
 defense = monsters(index).physical_defense_index + 1
 mdef = monsters(index).magical_defense_index + 1
 speed = monsters(index).speed_index + 1
 UpdateMenu()

end sub


sub MonsterStatsMenu.UpdateMenu()

 main_menu.ChangeOption(1, FF4Text("Attack:      ") + indexed_stat_group_menu.options.ItemAt(attack), 15)
 main_menu.ChangeOption(2, FF4Text("Defense:     ") + indexed_stat_group_menu.options.ItemAt(defense), 15)
 main_menu.ChangeOption(3, FF4Text("Mg Defense:  ") + indexed_stat_group_menu.options.ItemAt(mdef), 15)
 main_menu.ChangeOption(4, FF4Text("Speed Index: ") + indexed_speed_group_menu.options.ItemAt(speed), 15)
 if monsters(index).has_spell_power then
  main_menu.ChangeOption(5, FF4Text("Spell Power:  " + Pad(str(monsters(index).spell_power), 3)), 14)
 else
  main_menu.ChangeOption(5, FF4Text("Spell Power:  off"), 23)
 end if

end sub


sub MonsterStatsMenu.Commit()

 monsters(index).physical_attack_index = attack - 1
 monsters(index).physical_defense_index = defense - 1
 monsters(index).magical_defense_index = mdef - 1
 monsters(index).speed_index = speed - 1

end sub


sub MonsterStatsMenu.EditStatGroup(row as Integer)

 'Attack (row 1), Defense (row 2) or Magic defense (row 3): pick the stat group, then edit its numbers

 dim group as Integer = iif(row = 1, attack, iif(row = 2, defense, mdef))
 dim n as BlueNumberInput

 indexed_stat_group_menu.y = y + row - 1
 indexed_stat_group_menu.ChangeSelected(group)
 indexed_stat_group_menu.UserSelect()
 if indexed_stat_group_menu.cancelled then exit sub

 group = indexed_stat_group_menu.selected
 if row = 1 then attack = group
 if row = 2 then defense = group
 if row = 3 then mdef = group
 stat_group_menu.y = indexed_stat_group_menu.y
 n.y = indexed_stat_group_menu.y
 do
  stat_group_menu.ChangeOption(1, FF4Text(" " + Pad(str(stat_groups(group).stat_base), 3, true)), 15)
  stat_group_menu.ChangeOption(2, FF4Text("x" + Pad(str(stat_groups(group).multiplier), 3)), 15)
  stat_group_menu.ChangeOption(3, FF4Text(Pad(str(stat_groups(group).percentage), 3, true) + "%"), 15)
  stat_group_menu.Display()
  stat_group_menu.UserSelect()
  if not stat_group_menu.cancelled then
   select case stat_group_menu.selected
    case 1 'Base
     n.x = x + 18
     n.max_value = 255
     n.starting_number = stat_groups(group).stat_base
     n.UserSelect()
     stat_groups(group).stat_base = n.number
    case 2 'Multiplier
     n.x = x + 24
     n.max_value = 255
     n.starting_number = stat_groups(group).multiplier
     n.UserSelect()
     stat_groups(group).multiplier = n.number
    case 3 'Percentage
     n.x = x + 30
     n.max_value = 99
     n.starting_number = stat_groups(group).percentage
     n.UserSelect()
     stat_groups(group).percentage = n.number
   end select
  end if
 loop until stat_group_menu.cancelled
 indexed_stat_group_menu.ChangeOption(group, FF4Text(Pad(str(group), 3, true) + ": " + Pad(str(stat_groups(group).stat_base), 3, true) + "  x" + Pad(str(stat_groups(group).multiplier), 3) + "  " + Pad(str(stat_groups(group).percentage), 3, true) + "%"))

end sub


sub MonsterStatsMenu.EditField(row as Integer)

 'Edits one row of the box (1 attack, 2 defense, 3 magic defense, 4 speed index, 5 spell power) and stores the result

 dim n as BlueNumberInput

 select case row

  case 1 to 3
   EditStatGroup(row)

  case 5 'Spell power (only some monsters have it; editing it switches it on)
   n = BlueNumberInput(x + 14, y + 4)
   n.starting_number = monsters(index).spell_power
   n.UserSelect()
   monsters(index).spell_power = n.number
   monsters(index).has_spell_power = true

  case 4 'Speed Index
   indexed_speed_group_menu.ChangeSelected(speed)
   indexed_speed_group_menu.UserSelect()
   if not indexed_speed_group_menu.cancelled then
    speed = indexed_speed_group_menu.selected
    n.y = indexed_speed_group_menu.y
    do
     speed_group_menu.ChangeOption(1, FF4Text(" " + Pad(str(speed_groups(speed).low), 3, true) + " to"), 15)
     speed_group_menu.ChangeOption(2, FF4Text(Pad(str(speed_groups(speed).high), 3, true)), 15)
     speed_group_menu.Display()
     speed_group_menu.UserSelect()
     if not speed_group_menu.cancelled then
      select case speed_group_menu.selected
       case 1 'Low
        n.x = x + 18
        n.starting_number = speed_groups(speed).low
        n.UserSelect()
        speed_groups(speed).low = n.number
       case 2 'High
        n.x = x + 26
        n.starting_number = speed_groups(speed).high
        n.UserSelect()
        speed_groups(speed).high = n.number
      end select
     end if
    loop until speed_group_menu.cancelled
    indexed_speed_group_menu.ChangeOption(speed, FF4Text(Pad(str(speed), 3, true) + ": " + Pad(str(speed_groups(speed).low), 3, true) + " to  " + Pad(str(speed_groups(speed).high), 3, true)))
   end if

 end select
 UpdateMenu()
 Display()
 Commit()

end sub


sub MonsterStatsMenu.UserSelect()

 do
  main_menu.UserSelect()
  if not main_menu.cancelled then EditField(main_menu.selected)
 loop until main_menu.cancelled

 Commit()

end sub
