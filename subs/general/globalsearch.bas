sub OpenEntry(kind as String, index as Integer)

 'Opens the editor for a spell/item/monster list already on that entry.

 jump_kind = kind
 jump_index = index
 cls
 select case kind
  case "spells": EditSpells()
  case "weapons": EditWeapons()
  case "armors": EditArmors()
  case "medicines": EditMedicines()
  case "tools": EditTools()
  case "monsters": EditMonsters()
  case "shops": EditShops()
  case "formations": EditFormations()
  case "jobs": EditJobs()
 end select
 jump_kind = ""

end sub


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

 OpenEntry(result_kind(results.selected), result_index(results.selected))

end sub


sub ChangedEntries()

 'Everything that differs from the ROM as it was loaded; pick one to open it.

 dim kinds(1 to 9) as String = {"spells", "weapons", "armors", "medicines", "tools", "monsters", "shops", "formations", "jobs"}
 dim labels(1 to 9) as String = {"Spell", "Weapon", "Armor", "Medicine", "Tool", "Monster", "Shop", "Formation", "Job"}
 dim result_kind(1 to 300) as String
 dim result_index(1 to 300) as Integer
 dim n as Integer
 dim results as BlueMenu

 for k as Integer = 1 to 9
  for i as Integer = 1 to CsvTableSize(kinds(k))
   if n < 300 then
    if EntryModified(kinds(k), i) then
     n += 1
     result_kind(n) = kinds(k)
     result_index(n) = i
     results.AddOption(FF4Text(Pad(labels(k), 9)) + EntryName(kinds(k), i))
    end if
   end if
  next
 next

 if n = 0 then
  InfoBox("Nothing has been changed since the ROM was loaded.||Press any key")
  exit sub
 end if

 results.x = 20
 results.y = 4
 results.max_rows = 30
 results.UserSelect()
 if results.cancelled then exit sub

 OpenEntry(result_kind(results.selected), result_index(results.selected))

end sub
