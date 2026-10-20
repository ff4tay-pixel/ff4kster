sub SearchEverywhere()

 'Find a spell, item or monster by name and open its editor on that entry.

 dim query as String
 dim kinds(1 to 6) as String = {"spells", "weapons", "armors", "medicines", "tools", "monsters"}
 dim labels(1 to 6) as String = {"Spell", "Weapon", "Armor", "Medicine", "Tool", "Monster"}
 dim result_kind(1 to 300) as String
 dim result_index(1 to 300) as Integer
 dim n as Integer
 dim results as BlueMenu

 query = lcase(PromptLine("Search spells, items, monsters:", 20))
 if query = "" then exit sub

 for k as Integer = 1 to 6
  for i as Integer = 1 to CsvTableSize(kinds(k))
   if instr(lcase(FF4Name(EntryName(kinds(k), i))), query) > 0 and n < 300 then
    n += 1
    result_kind(n) = kinds(k)
    result_index(n) = i
    results.AddOption(FF4Text(Pad(labels(k), 9)) + EntryName(kinds(k), i))
   end if
  next
 next

 if n = 0 then
  InfoBox("No matches.||Press any key")
  exit sub
 end if

 results.x = 20
 results.y = 4
 results.max_rows = 30
 results.UserSelect()
 if results.cancelled then exit sub

 jump_kind = result_kind(results.selected)
 jump_index = result_index(results.selected)
 modified = true
 cls
 select case jump_kind
  case "spells": EditSpells()
  case "weapons": EditWeapons()
  case "armors": EditArmors()
  case "medicines": EditMedicines()
  case "tools": EditTools()
  case "monsters": EditMonsters()
 end select
 jump_kind = ""

end sub
