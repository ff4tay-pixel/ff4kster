'Shared helpers for the spell / weapon / armor / medicine / tool / monster list
' editors: modified markers, revert, copy/paste, "where is this used?", and
' jumping to an entry from the global search.
'
' Also used by the shop, formation and job lists.
'
' Keys (in those lists):  Ctrl+R revert   Ctrl+C copy   Ctrl+V paste   Ctrl+U where used

dim shared orig_rows(1 to 16, 0 to 511) as String
dim shared clip_has(1 to 16) as Boolean
dim shared clip_spell as Spell
dim shared clip_weapon as Weapon
dim shared clip_armor as Armor
dim shared clip_medicine as Medicine
dim shared clip_tool as Tool
dim shared clip_monster as Monster
dim shared clip_shop as Shop
dim shared clip_formation as Formation
dim shared clip_job as Job
dim shared clip_command as MenuCommand
dim shared clip_actor as Actor
dim shared clip_text(1 to 16) as String 'copied entries that are kept as a row of text (see EntryRow)
dim shared last_list_pos(1 to 16) as Integer
dim shared jump_kind as String
dim shared jump_index as Integer


function KindIndex(kind as String) as Integer

 select case kind
  case "spells": return 1
  case "weapons": return 2
  case "armors": return 3
  case "medicines": return 4
  case "tools": return 5
  case "monsters": return 6
  case "shops": return 7
  case "formations": return 8
  case "jobs": return 9
  case "commands": return 10
  case "actors": return 11
  case "solobattles": return 12
  case "autobattles": return 13
  case "spellsets": return 14
  case "encounters": return 15
  case "events": return 16
 end select

 return 0

end function


declare function EventUsageLines(id as Integer) as String
declare function BytesToHex(s as String) as String
declare function HexToBytes(h as String) as String


function ListToText(l as List) as String

 'The items of a list as hex, separated by dots (an item is a few bytes, such as a script command)

 dim result as String

 for j as Integer = 1 to l.Length()
  if j > 1 then result += "."
  result += BytesToHex(l.ItemAt(j))
 next

 return result

end function


sub TextToList(l as List, t as String)

 'The list back from ListToText

 dim start as Integer = 1
 dim finish as Integer

 l.Destroy()
 if t = "" then exit sub
 do
  finish = instr(start, t, ".")
  if finish = 0 then
   l.Append(HexToBytes(mid(t, start)))
   exit do
  end if
  l.Append(HexToBytes(mid(t, start, finish - start)))
  start = finish + 1
 loop

end sub


function BytesToHex(s as String) as String

 dim result as String

 for i as Integer = 1 to len(s)
  result += hex(asc(mid(s, i, 1)), 2)
 next

 return result

end function


function HexToBytes(h as String) as String

 dim result as String

 for i as Integer = 1 to len(h) step 2
  result += chr(val("&h" + mid(h, i, 2)))
 next

 return result

end function


function RowField(row as String, n as Integer) as String

 'Field n (1 = first) of a comma separated row

 dim start as Integer = 1
 dim finish as Integer

 for i as Integer = 2 to n
  start = instr(start, row, ",")
  if start = 0 then return ""
  start += 1
 next
 finish = instr(start, row, ",")
 if finish = 0 then return mid(row, start)

 return mid(row, start, finish - start)

end function


function EntryCount(kind as String) as Integer

 select case kind
  case "solobattles": return total_solobattles
  case "autobattles": return total_autobattles
  case "spellsets": return spellsets.Length()
  case "encounters": return total_encounter_tables
  case "events": return total_events
 end select

 return CsvTableSize(kind)

end function


function EncounterRowOf(area as Integer, table_number as Integer) as Integer

 'The row of the encounter table (1-96) that an area uses; areas past the first 84 add 16

 if area > 84 then return table_number + 16 + 1

 return table_number + 1

end function


function EntryRow(kind as String, i as Integer) as String

 'A row of text that holds everything about an entry, so it can be compared with the loaded ROM and
 ' put back (ApplyRow). The kinds the CSV export knows use its rows.

 dim result as String
 dim set_pointer as SpellSet ptr
 dim levels as String
 dim spell_ids as String
 dim starting as String
 dim row as Integer

 select case kind

  case "solobattles"
   return str(i) + "," + str(solobattles(i).actor) + "," + str(solobattles(i).formation)

  case "autobattles"
   return str(i) + "," + str(autobattles(i).formation_index) + "," + BytesToHex(autobattles(i).script(0)) + "," + BytesToHex(autobattles(i).script(1)) + "," + BytesToHex(autobattles(i).script(2))

  case "spellsets"
   set_pointer = spellsets.PointerAt(i)
   for j as Integer = 1 to set_pointer->starting_spells.Length()
    starting += chr(asc(set_pointer->starting_spells.ItemAt(j)))
   next
   for j as Integer = 1 to set_pointer->learning_spells.Length()
    levels += chr(asc(set_pointer->learning_levels.ItemAt(j)))
    spell_ids += chr(asc(set_pointer->learning_spells.ItemAt(j)))
   next
   return str(i) + "," + BytesToHex(starting) + "," + BytesToHex(levels) + "," + BytesToHex(spell_ids)

  case "encounters"
   row = EncounterRowOf(i, encounter_tables(i))
   result = str(i) + "," + str(encounter_tables(i))
   for j as Integer = 1 to 8
    if row <= total_encounters then result += "," + str(encounters(row, j)) else result += ",0"
   next
   return result

  case "events"
   return str(i) + "," + str(events(i).map_link) + "," + ListToText(events(i).script) + "," + ListToText(events(i).else_script)

 end select

 'a monster also holds the AIs it uses (they live in tables of their own)
 if kind = "monsters" then return CsvRow(kind, i) + "|" + MonsterAIFingerprint(i)

 return CsvRow(kind, i)

end function


sub ApplyRow(kind as String, i as Integer, row_text as String)

 'Puts an entry back the way a row from EntryRow describes it. Field 1 (the entry number) is ignored,
 ' so a row copied from another entry can be pasted over this one.

 dim set_pointer as SpellSet ptr
 dim starting as String
 dim levels as String
 dim spell_ids as String
 dim row as Integer

 select case kind

  case "solobattles"
   solobattles(i).actor = val(RowField(row_text, 2))
   solobattles(i).formation = val(RowField(row_text, 3))

  case "autobattles"
   autobattles(i).formation_index = val(RowField(row_text, 2))
   autobattles(i).script(0) = HexToBytes(RowField(row_text, 3))
   autobattles(i).script(1) = HexToBytes(RowField(row_text, 4))
   autobattles(i).script(2) = HexToBytes(RowField(row_text, 5))

  case "spellsets"
   set_pointer = spellsets.PointerAt(i)
   starting = HexToBytes(RowField(row_text, 2))
   levels = HexToBytes(RowField(row_text, 3))
   spell_ids = HexToBytes(RowField(row_text, 4))
   set_pointer->starting_spells.Destroy()
   set_pointer->learning_levels.Destroy()
   set_pointer->learning_spells.Destroy()
   for j as Integer = 1 to len(starting)
    set_pointer->starting_spells.Append(mid(starting, j, 1))
   next
   for j as Integer = 1 to len(levels)
    set_pointer->learning_levels.Append(mid(levels, j, 1))
    set_pointer->learning_spells.Append(mid(spell_ids, j, 1))
   next

  case "events"
   events(i).map_link = val(RowField(row_text, 2))
   TextToList(events(i).script, RowField(row_text, 3))
   TextToList(events(i).else_script, RowField(row_text, 4))

  case "encounters"
   encounter_tables(i) = val(RowField(row_text, 2))
   row = EncounterRowOf(i, encounter_tables(i))
   if row <= total_encounters then
    for j as Integer = 1 to 8
     encounters(row, j) = val(RowField(row_text, 2 + j))
    next
   end if

 end select

end sub


function EncounterAreaLabel(i as Integer) as String

 'The name the encounter editor lists an area under

 if i <= 64 then return FF4Text("Overworld section " + str(i) + "/64")
 if i <= 80 then return FF4Text("Underground section " + str(i - 64) + "/16")
 if i <= 84 then return FF4Text(Pad("Moon section " + str(i - 80) + "/4", screen_width - 2))

 return map_names.ItemAt(i - 84)

end function


function IsRowKind(kind as String) as Boolean

 'Kinds that are saved and restored as a row of text rather than as an object

 return kind = "solobattles" or kind = "autobattles" or kind = "spellsets" or kind = "encounters" or kind = "events"

end function


sub SnapshotOriginalRows()

 'Remember how every entry looked when the ROM was loaded.

 dim kinds(1 to 16) as String = {"spells", "weapons", "armors", "medicines", "tools", "monsters", "shops", "formations", "jobs", "commands", "actors", "solobattles", "autobattles", "spellsets", "encounters", "events"}

 for k as Integer = 1 to 16
  for i as Integer = 1 to EntryCount(kinds(k))
   orig_rows(k, i) = EntryRow(kinds(k), i)
  next
 next
 for i as Integer = 1 to total_commands
  orig_menucommands(i) = menucommands(i)
 next
 orig_formulas = formulas
 AITakeSnap(ai_original)

end sub


function CommandChanges(i as Integer) as String

 'What differs in a command since the ROM was loaded, in a few words (empty if nothing). The editors' own
 ' "changed" mark only knows the CSV fields, this one knows every field of a command.

 dim result as String
 dim name_changed as Boolean
 dim stances as Boolean
 dim parameters as Boolean
 dim code as Boolean

 with menucommands(i)
  name_changed = (.name <> orig_menucommands(i).name)
  stances = (.charging_stance <> orig_menucommands(i).charging_stance or .action_stance <> orig_menucommands(i).action_stance)
  stances = stances or .action_stance2 <> orig_menucommands(i).action_stance2 or .action_stance3 <> orig_menucommands(i).action_stance3
  for j as Integer = 1 to 8
   if .spell(j) <> orig_menucommands(i).spell(j) or .success(j) <> orig_menucommands(i).success(j) then parameters = true
   if .misc_bytes(j) <> orig_menucommands(i).misc_bytes(j) then parameters = true
  next
  for j as Integer = 1 to 5
   if .message(j) <> orig_menucommands(i).message(j) then parameters = true
  next
  if .item_consumed <> orig_menucommands(i).item_consumed or .item_effect <> orig_menucommands(i).item_effect then parameters = true
  if .item_visual <> orig_menucommands(i).item_visual or .regen_amount <> orig_menucommands(i).regen_amount then parameters = true
  if .regen_freeze <> orig_menucommands(i).regen_freeze or .disable_actor <> orig_menucommands(i).disable_actor then parameters = true
  if .cover_actor <> orig_menucommands(i).cover_actor or .cover_by_job <> orig_menucommands(i).cover_by_job then parameters = true
  for j as Integer = 1 to 3
   if .code_choice(j) <> orig_menucommands(i).code_choice(j) then code = true
  next
  if .regen_every <> orig_menucommands(i).regen_every or .cry_allies <> orig_menucommands(i).cry_allies then parameters = true
  if .steal_min <> orig_menucommands(i).steal_min or .steal_max <> orig_menucommands(i).steal_max then parameters = true
  if .steal_caught_fixed <> orig_menucommands(i).steal_caught_fixed or .steal_caught <> orig_menucommands(i).steal_caught then parameters = true
  if .steal_shift <> orig_menucommands(i).steal_shift then parameters = true
  if .reversed <> orig_menucommands(i).reversed or .behaves_like <> orig_menucommands(i).behaves_like then code = true
  if .extra_delay <> orig_menucommands(i).extra_delay or .jump_wait <> orig_menucommands(i).jump_wait then code = true
  if .jump_air <> orig_menucommands(i).jump_air or .throw_stat <> orig_menucommands(i).throw_stat then code = true
  if .throw_cap <> orig_menucommands(i).throw_cap or .aim_target_stat <> orig_menucommands(i).aim_target_stat then code = true
  if .aim_user_stat <> orig_menucommands(i).aim_user_stat or .aim_target_set <> orig_menucommands(i).aim_target_set then code = true
  if .aim_user_set <> orig_menucommands(i).aim_user_set then code = true
  if .halfsteps_on <> orig_menucommands(i).halfsteps_on then code = true
  if .recall_needs_mp <> orig_menucommands(i).recall_needs_mp or .recall_uses_mp <> orig_menucommands(i).recall_uses_mp then code = true
  if name_changed then result += ", name"
  if .target_byte <> orig_menucommands(i).target_byte or .target <> orig_menucommands(i).target then result += ", target"
  if .delay <> orig_menucommands(i).delay then result += ", delay"
  if .disabling_persistent <> orig_menucommands(i).disabling_persistent or .disabling_temporary <> orig_menucommands(i).disabling_temporary then result += ", statuses"
  if stances then result += ", stances"
  if parameters then result += ", parameters"
  if code then result += ", code"
 end with

 return mid(result, 3)

end function


function EntryModified(kind as String, i as Integer) as Boolean

 if kind = "commands" then
  if CommandChanges(i) <> "" then return true
 end if

 return EntryRow(kind, i) <> orig_rows(KindIndex(kind), i)

end function


sub RefreshEntryColor(list_menu as BlueMenu, kind as String, i as Integer)

 if i < 1 or i > list_menu.options.Length() then exit sub

 if EntryModified(kind, i) then list_menu.ChangeOption(i, "", 14) else list_menu.ChangeOption(i, "", 15)

end sub


function KindTitle(kind as String) as String

 select case kind
  case "spells": return "Spells"
  case "weapons": return "Weapons"
  case "armors": return "Armors"
  case "medicines": return "Medicines"
  case "tools": return "Tools"
  case "monsters": return "Monsters"
  case "shops": return "Shops"
  case "formations": return "Formations"
  case "jobs": return "Jobs"
  case "commands": return "Commands"
  case "actors": return "Actors"
  case "solobattles": return "Solobattles"
  case "autobattles": return "Autobattles"
  case "spellsets": return "Spell Sets"
  case "encounters": return "Encounters"
  case "events": return "Events"
 end select

 return kind

end function


function EntryName(kind as String, i as Integer) as String

 select case kind
  case "spells": return spells(i).name
  case "weapons": return weapons(i).name
  case "armors": return armors(i).name
  case "medicines": return medicines(i).name
  case "tools": return tools(i).name
  case "monsters": return monsters(i).name
  case "shops": return shop_names.ItemAt(i)
  case "formations": return formation_names.ItemAt(i)
  case "jobs": return jobs(i).name
  case "commands": return menucommands(i).name
  case "actors": return actor_names.ItemAt(i)
  case "solobattles": return FF4Text("Solobattle " + Pad(str(i), 2, true))
  case "autobattles": return FF4Text("Autobattle " + str(i))
  case "spellsets": return spellset_names.ItemAt(i)
  case "encounters": return EncounterAreaLabel(i)
  case "events": return Pad(event_names.ItemAt(i), 78, false, FF4Text(" "))
 end select

 return ""

end function


sub SetEntryName(kind as String, i as Integer, new_name as String)

 select case kind
  case "spells": spells(i).name = new_name
  case "weapons": weapons(i).name = new_name: item_names.Assign(i + 1, new_name)
  case "armors": armors(i).name = new_name: item_names.Assign(i + total_weapons + 2, new_name)
  case "medicines": medicines(i).name = new_name: item_names.Assign(i + total_weapons + total_armors + 2, new_name)
  case "tools": tools(i).name = new_name: item_names.Assign(i + total_weapons + total_armors + total_medicines + 2, new_name)
  case "monsters": monsters(i).name = new_name
  case "jobs": jobs(i).name = new_name
  case "commands": menucommands(i).name = new_name
 end select

end sub


sub RevertEntry(kind as String, i as Integer)

 'Puts one entry back the way it was when the ROM was loaded.

 dim saved_rom as String = ff4rom

 if IsRowKind(kind) then
  ApplyRow(kind, i, orig_rows(KindIndex(kind), i))
  exit sub
 end if

 ff4rom = original_rom

 select case kind
  case "spells"
   dim blank_spell as Spell
   spells(i) = blank_spell
   spells(i).ReadFromROM(i)
  case "weapons"
   dim blank_weapon as Weapon
   weapons(i) = blank_weapon
   weapons(i).ReadFromROM(i)
  case "armors"
   dim blank_armor as Armor
   armors(i) = blank_armor
   armors(i).ReadFromROM(i)
  case "medicines"
   dim blank_medicine as Medicine
   medicines(i) = blank_medicine
   medicines(i).ReadFromROM(i)
  case "tools"
   dim blank_tool as Tool
   tools(i) = blank_tool
   tools(i).ReadFromROM(i)
  case "monsters"
   dim blank_monster as Monster
   dim now_attack as Integer = monsters(i).attack_sequence_group + 1
   dim now_reaction as Integer = iif(monsters(i).has_reaction, monsters(i).reaction_index + 1, 0)
   dim now_lunar as Boolean = monsters(i).lunar
   monsters(i) = blank_monster
   monsters(i).ReadFromROM(i)
   'the AIs it uses go back too: the ones it has now and the ones it had when the ROM was loaded
   AIRestoreGroup(ai_original, now_attack, now_lunar)
   AIRestoreGroup(ai_original, now_reaction, now_lunar)
   AIRestoreGroup(ai_original, monsters(i).attack_sequence_group + 1, monsters(i).lunar)
   if monsters(i).has_reaction then AIRestoreGroup(ai_original, monsters(i).reaction_index + 1, monsters(i).lunar)
   AIRestoreOrphans(ai_original)
  case "shops"
   dim blank_shop as Shop
   shops(i) = blank_shop
   shops(i).ReadFromROM(i)
  case "formations"
   dim blank_formation as Formation
   formations(i) = blank_formation
   formations(i).ReadFromROM(i)
  case "jobs"
   dim blank_job as Job
   jobs(i) = blank_job
   jobs(i).ReadFromROM(i)
  case "commands"
   dim blank_command as MenuCommand
   menucommands(i) = blank_command
   menucommands(i).ReadFromROM(i)
  case "actors"
   dim blank_actor as Actor
   actors(i) = blank_actor
   actors(i).ReadFromROM(i)
 end select

 ff4rom = saved_rom
 SetEntryName(kind, i, EntryName(kind, i)) 'refresh the shared item name list

end sub


sub ClipCopy(kind as String, i as Integer)

 select case kind
  case "spells": clip_spell = spells(i)
  case "weapons": clip_weapon = weapons(i)
  case "armors": clip_armor = armors(i)
  case "medicines": clip_medicine = medicines(i)
  case "tools": clip_tool = tools(i)
  case "monsters": clip_monster = monsters(i)
  case "shops": clip_shop = shops(i)
  case "formations": clip_formation = formations(i)
  case "jobs": clip_job = jobs(i)
  case "commands": clip_command = menucommands(i)
  case "actors": clip_actor = actors(i)
 end select
 if IsRowKind(kind) then clip_text(KindIndex(kind)) = EntryRow(kind, i)
 clip_has(KindIndex(kind)) = true

end sub


function ClipPaste(kind as String, i as Integer) as Boolean

 'Pastes the copied entry over entry i, keeping entry i's own name.

 dim keep_name as String = EntryName(kind, i)

 if not clip_has(KindIndex(kind)) then return false
 if IsRowKind(kind) then
  ApplyRow(kind, i, clip_text(KindIndex(kind)))
  return true
 end if

 select case kind
  case "spells": spells(i) = clip_spell
  case "weapons": weapons(i) = clip_weapon
  case "armors": armors(i) = clip_armor
  case "medicines": medicines(i) = clip_medicine
  case "tools": tools(i) = clip_tool
  case "monsters": monsters(i) = clip_monster
  case "shops": shops(i) = clip_shop
  case "formations": formations(i) = clip_formation
  case "jobs": jobs(i) = clip_job
  case "commands": menucommands(i) = clip_command
  case "actors": actors(i) = clip_actor
 end select
 SetEntryName(kind, i, keep_name)

 return true

end function


function AreaName(index as Integer) as String

 if index <= 64 then return "Overworld section " + str(index)
 if index <= 80 then return "Underground section " + str(index - 64)
 if index <= 84 then return "Moon section " + str(index - 80)

 return FF4Name(map_names.ItemAt(index - 84))

end function


function EncounterAreasText(found() as Boolean) as String

 'Lists the areas whose random encounter table contains any formation marked in found().

 dim lines as String
 dim count as Integer
 dim shown as Integer
 dim row as Integer
 dim inside as Integer
 dim underground as Integer
 dim area_hit as Boolean
 const max_lines = 14

 lines = "||Random encounters:"
 for index as Integer = 1 to total_encounter_tables
  if index > 84 then inside = 16 else inside = 0
  if index > 84 + &h100 or (index <= 84 and index > 64) then underground = &h100 else underground = 0
  row = encounter_tables(index) + inside + 1
  area_hit = false
  if encounter_tables(index) > 0 and row <= total_encounters then
   for s as Integer = 1 to 8
    if encounters(row, s) + underground + 1 <= total_formations then
     if found(encounters(row, s) + underground + 1) then area_hit = true
    end if
   next
  end if
  if area_hit then
   count += 1
   if shown < max_lines then
    lines += "|  " + AreaName(index)
    shown += 1
   end if
  end if
 next
 if count = 0 then lines += "|  none"
 if count > shown then lines += "|  ...and " + str(count - shown) + " more areas"

 return lines

end function


function UsageText(kind as String, id as Integer) as String

 'Lists where a monster, item or spell is used (lines separated by "|").

 dim lines as String
 dim count as Integer
 dim shown as Integer
 dim code as Integer
 dim is_item as Boolean
 dim t as Trigger ptr
 dim found(1 to total_formations) as Boolean
 dim desc as String
 const max_lines = 14

 select case kind

  case "monsters"
   for k as Integer = 1 to total_formations
    for j as Integer = 1 to 3
     if formations(k).monster_type(j) + 1 = id and formations(k).monster_qty(j) > 0 then
      found(k) = true
      count += 1
      if shown < max_lines then
       desc = ""
       for q as Integer = 1 to 3
        if formations(k).monster_type(q) + 1 <= total_monsters and formations(k).monster_qty(q) > 0 then
         if desc <> "" then desc += ", "
         desc += str(formations(k).monster_qty(q)) + " " + trim(FF4Name(monsters(formations(k).monster_type(q) + 1).name))
        end if
       next
       lines += "|Formation " + str(k) + ": " + desc
       shown += 1
      end if
      exit for
     end if
    next
   next
   if count = 0 then lines += "|Not used in any formation."
   if count > shown then lines += "|...and " + str(count - shown) + " more formations"
   lines += EncounterAreasText(found())

  case "weapons", "armors", "medicines", "tools"
   select case kind
    case "weapons": code = id
    case "armors": code = id + total_weapons + 1
    case "medicines": code = id + total_weapons + total_armors + 1
    case "tools": code = id + total_weapons + total_armors + total_medicines + 1
   end select
   for s as Integer = 1 to total_shops
    for w as Integer = 1 to 8
     if shops(s).wares(w) = code then
      count += 1
      if shown < max_lines then
       lines += "|Shop: " + FF4Name(shop_names.ItemAt(s))
       shown += 1
      end if
      exit for
     end if
    next
   next
   if count = 0 then lines += "|Not sold in any shop."
   lines += "||Treasure chests:"
   count = 0
   shown = 0
   for m as Integer = 1 to total_maps
    for j as Integer = 1 to maps(m).triggers.Length()
     t = maps(m).triggers.PointerAt(j)
     if t->treasure and t->item and t->contents = code then
      count += 1
      if shown < 12 then
       lines += "|  " + FF4Name(map_names.ItemAt(m)) + " at " + str(t->x) + "," + str(t->y)
       shown += 1
      end if
     end if
    next
   next
   if count = 0 then lines += "|  none"
   if count > shown then lines += "|  ...and " + str(count - shown) + " more"

  case "formations"
   found(id) = true
   lines += EncounterAreasText(found())
   lines += "||Trapped chests that start this battle:"
   for m as Integer = 1 to total_maps
    for j as Integer = 1 to maps(m).triggers.Length()
     t = maps(m).triggers.PointerAt(j)
     if t->treasure and t->trapped and ChestFormation(m, t->formation) = id then
      count += 1
      if shown < 12 then
       lines += "|  " + FF4Name(map_names.ItemAt(m)) + " at " + str(t->x) + "," + str(t->y)
       shown += 1
      end if
     end if
    next
   next
   if count = 0 then lines += "|  none"
   if count > shown then lines += "|  ...and " + str(count - shown) + " more"
   lines += "||Battles started by events are not listed."

  case "shops", "jobs", "commands", "actors", "solobattles", "autobattles", "spellsets", "encounters"
   lines += "|Usage is not tracked for this kind of entry."

  case "events"
   lines += EventUsageLines(id)

  case "spells"
   for w as Integer = 1 to total_weapons
    if weapons(w).casts = id then
     count += 1
     if shown < max_lines then
      lines += "|Cast by weapon: " + FF4Name(weapons(w).name)
      shown += 1
     end if
    end if
   next
   if count = 0 then lines += "|No weapon casts this spell."
   if count > shown then lines += "|...and " + str(count - shown) + " more"

 end select

 return "Where is " + FF4Name(EntryName(kind, id)) + " used?|" + lines

end function


sub ShowUsage(kind as String, id as Integer)

 InfoBox(UsageText(kind, id) + "||Press any key", 4, 3)

end sub


'Undo: before an entry is opened for editing (Enter), pasted over or reverted, a
' copy of it goes on a small stack. Ctrl+Z in a list restores the newest copy
' made in that list. A copy whose entry ended up unchanged is dropped.
const undo_max = 40
dim shared undo_kind(1 to undo_max) as String
dim shared undo_index(1 to undo_max) as Integer
dim shared undo_spell(1 to undo_max) as Spell
dim shared undo_weapon(1 to undo_max) as Weapon
dim shared undo_armor(1 to undo_max) as Armor
dim shared undo_medicine(1 to undo_max) as Medicine
dim shared undo_tool(1 to undo_max) as Tool
dim shared undo_monster(1 to undo_max) as Monster
dim shared undo_ai(1 to undo_max) as AISnap 'the AI tables as they were when a monster was put on the stack
dim shared undo_shop(1 to undo_max) as Shop
dim shared undo_formation(1 to undo_max) as Formation
dim shared undo_job(1 to undo_max) as Job
dim shared undo_command(1 to undo_max) as MenuCommand
dim shared undo_actor(1 to undo_max) as Actor
dim shared undo_text(1 to undo_max) as String 'the row of an entry kept as text
dim shared undo_count as Integer
dim shared undo_pending as Boolean 'the newest copy has not been checked for a real change yet
dim shared undo_pending_row as String


sub UndoStore(slot as Integer, kind as String, i as Integer)

 select case kind
  case "spells": undo_spell(slot) = spells(i)
  case "weapons": undo_weapon(slot) = weapons(i)
  case "armors": undo_armor(slot) = armors(i)
  case "medicines": undo_medicine(slot) = medicines(i)
  case "tools": undo_tool(slot) = tools(i)
  case "monsters"
   undo_monster(slot) = monsters(i)
   AITakeSnap(undo_ai(slot))
  case "shops": undo_shop(slot) = shops(i)
  case "formations": undo_formation(slot) = formations(i)
  case "jobs": undo_job(slot) = jobs(i)
  case "commands": undo_command(slot) = menucommands(i)
  case "actors": undo_actor(slot) = actors(i)
  case "solobattles", "autobattles", "spellsets", "encounters", "events": undo_text(slot) = EntryRow(kind, i)
 end select

end sub


sub UndoLoad(slot as Integer, kind as String, i as Integer)

 select case kind
  case "spells": spells(i) = undo_spell(slot)
  case "weapons": weapons(i) = undo_weapon(slot)
  case "armors": armors(i) = undo_armor(slot)
  case "medicines": medicines(i) = undo_medicine(slot)
  case "tools": tools(i) = undo_tool(slot)
  case "monsters"
   monsters(i) = undo_monster(slot)
   AIPutSnap(undo_ai(slot))
  case "shops": shops(i) = undo_shop(slot)
  case "formations": formations(i) = undo_formation(slot)
  case "jobs": jobs(i) = undo_job(slot)
  case "commands": menucommands(i) = undo_command(slot)
  case "actors": actors(i) = undo_actor(slot)
  case "solobattles", "autobattles", "spellsets", "encounters", "events": ApplyRow(kind, i, undo_text(slot))
 end select

end sub


sub UndoMove(to_slot as Integer, from_slot as Integer)

 'Copies one stack slot onto another (only the part its kind uses).

 undo_kind(to_slot) = undo_kind(from_slot)
 undo_index(to_slot) = undo_index(from_slot)
 select case undo_kind(from_slot)
  case "spells": undo_spell(to_slot) = undo_spell(from_slot)
  case "weapons": undo_weapon(to_slot) = undo_weapon(from_slot)
  case "armors": undo_armor(to_slot) = undo_armor(from_slot)
  case "medicines": undo_medicine(to_slot) = undo_medicine(from_slot)
  case "tools": undo_tool(to_slot) = undo_tool(from_slot)
  case "monsters"
   undo_monster(to_slot) = undo_monster(from_slot)
   undo_ai(to_slot) = undo_ai(from_slot)
  case "shops": undo_shop(to_slot) = undo_shop(from_slot)
  case "formations": undo_formation(to_slot) = undo_formation(from_slot)
  case "jobs": undo_job(to_slot) = undo_job(from_slot)
  case "commands": undo_command(to_slot) = undo_command(from_slot)
  case "actors": undo_actor(to_slot) = undo_actor(from_slot)
  case "solobattles", "autobattles", "spellsets", "encounters", "events": undo_text(to_slot) = undo_text(from_slot)
 end select

end sub


sub UndoRemove(slot as Integer)

 for n as Integer = slot to undo_count - 1
  UndoMove(n, n + 1)
 next
 undo_count -= 1

end sub


sub UndoSettle()

 'Drops the newest copy if the entry it was taken from did not change.

 if not undo_pending then exit sub
 undo_pending = false
 if undo_count < 1 then exit sub
 if EntryRow(undo_kind(undo_count), undo_index(undo_count)) = undo_pending_row then undo_count -= 1

end sub


sub UndoPush(kind as String, i as Integer)

 UndoSettle()
 if undo_count = undo_max then UndoRemove(1)
 undo_count += 1
 undo_kind(undo_count) = kind
 undo_index(undo_count) = i
 UndoStore(undo_count, kind, i)
 undo_pending = true
 undo_pending_row = EntryRow(kind, i)

end sub


function UndoPop(kind as String, byref i as Integer) as Boolean

 'Restores the newest saved copy of an entry of this kind. i receives its index.

 UndoSettle()
 for n as Integer = undo_count to 1 step -1
  if undo_kind(n) = kind then
   i = undo_index(n)
   UndoLoad(n, kind, i)
   UndoRemove(n)
   SetEntryName(kind, i, EntryName(kind, i)) 'refresh the shared item name list
   return true
  end if
 next

 return false

end function


function EntryActionKey() as UInteger

 'Space in a list opens a menu of the actions on the entry, so none of them needs a key to be learned. Returns the
 ' key the chosen entry stands for (the list handles it as if it had been pressed), 0 if cancelled.

 dim m as BlueMenu
 dim labels(1 to 5) as String = {"Revert to the loaded ROM", "Copy this entry", "Paste over this entry", "Undo the last change", "Show where it is used"}
 dim hints(1 to 5) as String = {"Ctrl-R", "Ctrl-C", "Ctrl-V", "Ctrl-Z", "Ctrl-U"}
 dim keys(1 to 5) as UInteger = {18, 3, 22, 26, 21}
 dim label_width as Integer
 dim text_width as Integer

 for i as Integer = 1 to 5
  label_width = Max(label_width, len(labels(i)))
 next
 text_width = label_width + 2 + 6
 m = BlueMenu(78 - (text_width + 2), 3)
 m.title = "This entry"
 m.min_width = text_width
 for i as Integer = 1 to 5
  m.AddOption(FF4Text(labels(i) + space(label_width - len(labels(i)) + 2) + hints(i)))
 next
 m.UserSelect()
 if m.cancelled then return 0

 return keys(m.selected)

end function


function ListInput(list_menu as BlueMenu, kind as String) as Boolean

 'Drop-in replacement for list_menu.UserInput() in the list editors. Adds modified
 ' markers, remembers the last position, accepts a jump from global search,
 ' and handles revert / copy / paste / where-used keys.

 dim k as Integer = KindIndex(kind)
 dim result as Boolean
 dim undone as Integer
 dim key as UInteger

 if not list_menu.marked then
  list_menu.marked = true
  for i as Integer = 1 to list_menu.options.Length()
   RefreshEntryColor(list_menu, kind, i)
  next
  if jump_kind = kind and jump_index >= 1 then
   list_menu.ChangeSelected(jump_index)
  elseif last_list_pos(k) >= 1 then
   list_menu.ChangeSelected(last_list_pos(k))
  end if
  jump_kind = ""
 end if

 for i as Integer = 1 to list_menu.options.Length()
  RefreshEntryColor(list_menu, kind, i)
 next

 UndoSettle()
 result = list_menu.UserInput()
 if result then
  if not list_menu.cancelled then
   last_list_pos(k) = list_menu.selected
   if list_menu.highlighted = 0 then UndoPush(kind, list_menu.selected)
  end if
  return true
 end if
 last_list_pos(k) = list_menu.selected

 key = list_menu.last_key
 if key = SPACE_KEY then key = EntryActionKey()

 select case key
  case 18 'Ctrl+R
   if EntryModified(kind, list_menu.selected) then
    if ConfirmBox("Revert this entry to the loaded ROM?") then
     UndoPush(kind, list_menu.selected)
     RevertEntry(kind, list_menu.selected)
     list_menu.ChangeOption(list_menu.selected, EntryName(kind, list_menu.selected))
     RefreshEntryColor(list_menu, kind, list_menu.selected)
    end if
   else
    InfoBox("This entry has no changes.||Press any key")
   end if
  case 3 'Ctrl+C
   ClipCopy(kind, list_menu.selected)
   InfoBox("Copied " + FF4Name(EntryName(kind, list_menu.selected)) + ".|Ctrl+V on another entry pastes it|(that entry keeps its own name).||Press any key")
  case 26 'Ctrl+Z
   if UndoPop(kind, undone) then
    list_menu.ChangeOption(undone, EntryName(kind, undone))
    RefreshEntryColor(list_menu, kind, undone)
    list_menu.ChangeSelected(undone)
   else
    InfoBox("Nothing to undo in this list.||Press any key")
   end if
  case 22 'Ctrl+V
   if clip_has(k) andalso EntryModified(kind, list_menu.selected) andalso not ConfirmBox("Paste over your edits to this entry?") then
    'declined
   elseif clip_has(k) then
    UndoPush(kind, list_menu.selected)
    ClipPaste(kind, list_menu.selected)
    RefreshEntryColor(list_menu, kind, list_menu.selected)
   else
    InfoBox("Nothing copied yet. Use Ctrl+C first.||Press any key")
   end if
  case 21 'Ctrl+U
   ShowUsage(kind, list_menu.selected)
 end select

 return false

end function
