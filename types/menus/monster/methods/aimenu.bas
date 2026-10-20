constructor AIMenu(starting_x as UByte = 0, starting_y as UByte = 0)

 x = starting_x
 y = starting_y
 index_menu = BlueMenu(x, y)
 index_menu.max_rows = 1
 condition_menu = BlueMenu(x + 4, y + 3)
 condition_menu.max_rows = 5
 set_menu = BlueMenu(x, y + 3)
 set_menu.max_rows = 5
 script_index = BlueMenu(x, condition_menu.y + condition_menu.max_rows + 2)
 script_index.max_rows = 1
 script_menu = BlueMenu(x, script_index.y + 3)
 script_menu.max_rows = 10
 
 'Make the boxes line up: the whole block is ai_header_width cells wide
 index_menu.min_width = ai_header_width - 2
 condition_menu.min_width = ai_header_width - 6
 script_index.min_width = ai_header_width - 2
 script_menu.min_width = ai_header_width - 2
 condition_menu.title = "Conditions"
 script_menu.title = "Actions"
 
 for i as Integer = 1 to total_ai_groups
  index_menu.AddOption(FF4Text("Index: " + str(i)))
 next
 
 for i as Integer = 1 to &h100
  script_index.AddOption(FF4Text("Script: " + str(i)))
 next
 
 condition_types = BlueMenu(x + 4, y)
 condition_types.max_rows = 1
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
 
 script_functions = BlueMenu(x, y)
 script_functions.max_rows = 1
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
 
end constructor


function AIMenu.CurrentCondition() as UByte

 dim result as UByte
 dim total as UInteger
 dim temp as String
 
 for i as Integer = 1 to len(aigroupscripts(index))
  temp += conditionsets(asc(mid(aigroupconditions(index), i, 1)) + 1)
 next
 
 if len(temp) > 0 then result = Min(conditions(asc(mid(temp, condition_menu.selected, 1)) + 1).condition + 1, condition_types.options.Length())
 
 return result

end function


sub AIMenu.Display()
 
 dim header as String
 
 index_menu.ChangeSelected(index)
 index_menu.Display()
 set_menu.Display()
 RefreshConditions()
 RefreshScripts()
 if y > 0 and len(title) > 0 then
  header = title
  if show_bank then
   if lunar then header += "  LUNAR bank" else header += "  Regular bank"
  end if
  WriteText(FF4Text(Pad(header, ai_header_width)), x, y - 1, iif(show_bank and lunar, 12, 14))
 end if
 
end sub


sub AIMenu.Hide()

 index_menu.Hide()
 set_menu.Hide()
 condition_menu.Hide()
 script_index.Hide()
 script_menu.Hide()
 if y > 0 and len(title) > 0 then line (x * 8, (y - 1) * 8)-((x + ai_header_width) * 8 - 1, y * 8 - 1), RGB(0, 0, 0), bf

end sub


sub AIMenu.RefreshConditions()

 dim temp as String
 dim c as String
 dim blank as Any ptr

 condition_menu.Hide()

 set_menu.ClearAll()
 for i as Integer = 1 to len(aigroupconditions(index))
  set_menu.AddOption(FF4Text(Pad(str(asc(mid(aigroupconditions(index), i, 1)) + 1), 2, true)))
 next

 condition_menu.ClearAll()
 if set_menu.options.Length() > 0 then
  temp = conditionsets(asc(mid(aigroupconditions(index), set_menu.selected, 1)) + 1)
  c = FF4Text("IF ")
  for j as Integer = 1 to len(temp)
   c += conditions(asc(mid(temp, j, 1)) + 1).TextDescription()
   condition_menu.AddOption(c)
   c = FF4Text(" AND ")
  next
 end if
 
 set_menu.Display()
 if condition_menu.selected > condition_menu.options.Length() then condition_menu.ChangeSelected(condition_menu.options.Length())
 condition_menu.Display()
 script_index.Display()
 
end sub


sub AIMenu.RefreshScripts()

 dim entry as AIScriptEntry ptr
 dim n as UInteger

 script_menu.Hide()
 
 script_menu.ClearAll()
 if set_menu.options.Length() > 0 then
  script_index.ChangeSelected(asc(mid(aigroupscripts(index), set_menu.selected, 1)) + 1)
  n = script_index.selected
  if lunar then n += &h100
  if n <= ubound(scripts) then
   for i as Integer = 1 to scripts(n).Length()
    entry = scripts(n).PointerAt(i)
    script_menu.AddOption(entry->TextDescription())
   next
   script_menu.AddOption(FF4Text("-- END SCRIPT --"))
  else
   script_menu.AddOption(FF4Text("-- DOES NOT EXIST --"))
  end if
  if script_menu.selected > script_menu.options.Length() then script_menu.ChangeSelected(script_menu.options.Length())
 end if
 
 script_menu.Display()
 script_index.Display()
 
end sub


sub AIMenu.SetTo(new_index as UByte, new_lunar as Boolean = false)

 index = new_index
 lunar = new_lunar
 
end sub
