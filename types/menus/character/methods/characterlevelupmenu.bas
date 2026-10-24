constructor CharacterLevelUpMenu(starting_x as UByte = 0, starting_y as UByte = 0)

 x = starting_x
 y = starting_y
 level_menu = BlueMenu(x, y + 3)
 level_menu.max_rows = screen_height - y - 6 'the box ends above the hint line

end constructor


sub CharacterLevelUpMenu.Display()

 BlueBox(x, y, level_menu.options.Width(), 1)
 WriteText(FF4Text("Lv  Stat Bonuses                 MHP  MMP  TNL"), x + 1, y + 1)
 level_menu.Display()

end sub


sub CharacterLevelUpMenu.SetTo(index as UByte)

 dim temp as String
 dim c as UByte

 character_id = index

 level_menu.ClearAll()
 for i as Integer = 1 to 69

  'level_menu.AddOption(FF4Text(Pad(str(i), 2, true, "0") + ":"))
  'for j as Integer = 1 to 5
   'if characters(index).levelup(i).stat_bonus.stat(j) then c = 14 else c = 0
   'level_menu.AddOption(FF4Text(StatName(j)), c)
  'next
  'if characters(index).levelup(i).stat_bonus.amount = 7 then
   'level_menu.AddOption(FF4Text("-1"))
  'else
   'level_menu.AddOption(FF4Text(" " + str(characters(index).levelup(i).stat_bonus.amount)))
  'end if
  'level_menu.AddOption(FF4Text(Pad(str(characters(index).levelup(i).hp_bonus), 3, true)))
  'level_menu.AddOption(FF4Text(Pad(str(characters(index).levelup(i).mp_bonus), 3, true)))
  'level_menu.AddOption(FF4Text(Pad(str(characters(index).levelup(i).tnl), 6, true)))
    
  temp = Pad(str(i), 2, true, "0") + ": "
  for j as Integer = 1 to 5
   if characters(index).levelup(i).stat_bonus.stat(j) then 
    temp += StatName(j) + "  "
   else
    temp += space(5)
   end if
  next
  if characters(index).levelup(i).stat_bonus.amount = 7 then
   temp += "-1"
  else
   temp += " " + str(characters(index).levelup(i).stat_bonus.amount)
  end if
  temp += "  " + Pad(str(characters(index).levelup(i).hp_bonus), 3, true)
  temp += "  " + Pad(str(characters(index).levelup(i).mp_bonus), 3, true)
  temp += "  " + Pad(str(characters(index).levelup(i).tnl), 6, true)
  level_menu.AddOption(FF4Text(temp))
 next

end sub


sub CharacterLevelUpMenu.UserSelect()

 'The level up table is edited in its own full screen editor (see editlevelups.bas)

 EditLevelUps(character_id)

end sub
