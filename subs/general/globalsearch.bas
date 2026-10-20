sub OpenEntry(kind as String, index as Integer)

 dim saved_help as Integer

 'Opens the editor for a spell/item/monster list already on that entry.

 jump_kind = kind
 jump_index = index
 cls
 saved_help = help_entry
 select case kind
  case "spells": help_entry = 3
  case "weapons": help_entry = 5
  case "armors": help_entry = 6
  case "medicines": help_entry = 7
  case "tools": help_entry = 8
  case "monsters": help_entry = 22
  case "shops": help_entry = 9
  case "formations": help_entry = 23
  case "jobs": help_entry = 10
  case "commands": help_entry = 13
  case "actors": help_entry = 14
  case "spellsets": help_entry = 4
  case "encounters": help_entry = 24
  case "autobattles": help_entry = 25
  case "solobattles": help_entry = 26
 end select
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
  case "commands": EditCommands()
  case "actors": EditActors()
  case "spellsets": EditSpellSets()
  case "encounters": EditEncounters()
  case "autobattles": EditAutoBattles()
  case "solobattles": EditSoloBattles()
 end select
 help_entry = saved_help
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

 dim kinds(1 to 15) as String = {"spells", "weapons", "armors", "medicines", "tools", "monsters", "shops", "formations", "jobs", "commands", "actors", "solobattles", "autobattles", "spellsets", "encounters"}
 dim labels(1 to 15) as String = {"Spell", "Weapon", "Armor", "Medicine", "Tool", "Monster", "Shop", "Formation", "Job", "Command", "Actor", "Solobattle", "Autobattle", "Spell Set", "Encounter"}
 dim result_kind(1 to 300) as String
 dim result_index(1 to 300) as Integer
 dim n as Integer
 dim results as BlueMenu

 for k as Integer = 1 to 15
  for i as Integer = 1 to EntryCount(kinds(k))
   if n < 300 then
    if EntryModified(kinds(k), i) then
     n += 1
     result_kind(n) = kinds(k)
     result_index(n) = i
     results.AddOption(FF4Text(Pad(labels(k), 11)) + EntryName(kinds(k), i))
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
