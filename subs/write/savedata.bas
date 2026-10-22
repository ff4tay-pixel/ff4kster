declare sub SaveWorldMaps()

dim shared disk_rom as String 'what the ROM file contained when last read or written

function SafeToSave(filename as String) as Boolean

 'Returns false if the ROM file changed on disk since this editor loaded or
 ' last saved it and the user chooses not to overwrite it.

 dim a as Integer = freefile
 dim raw as String
 dim current as String

 if open(filename for binary access read as #a) <> 0 then return true
 raw = string(lof(a), 0)
 if lof(a) > 0 then get #a, , raw
 close #a

 if RomSizeKind(len(raw)) = 1 then current = string(&h200, 0) + raw else current = raw
 if current = disk_rom then return true

 return ConfirmBox("The ROM file changed on disk. Overwrite it?")

end function


function CopyFile(source as String, destination as String) as Boolean

 'Copies a file byte for byte. Returns true on success.

 dim a as Integer = freefile
 dim file_bytes as String

 if open(source for binary access read as #a) <> 0 then return false
 file_bytes = string(lof(a), 0)
 if lof(a) > 0 then get #a, , file_bytes
 close #a

 if open(destination for binary access write as #a) <> 0 then return false
 if len(file_bytes) > 0 then put #a, , file_bytes
 close #a

 return true

end function


function BackupName(filename as String) as String

 'The name of a new backup of the ROM file: <rom>.<date>-<time>.bak

 return filename + "." + mid(date, 7, 4) + left(date, 2) + mid(date, 4, 2) + "-" + left(time, 2) + mid(time, 4, 2) + mid(time, 7, 2) + ".bak"

end function


sub ApplyDataToROM()

 dim start as UInteger
 dim temp as UByte
 dim rewards as UByte

 'Write the memory objects to the ROM image
 
 'Save item ranges
 SaveItemRanges()

 for i as Integer = 1 to total_element_grids
  elementgrids(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_equip_charts
  equipcharts(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_shops
  shops(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_weapons
  weapons(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_armors
  armors(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_medicines
  medicines(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_tools
  tools(i).WriteToROM(i)
 next
 
 WriteByte(&h14D9C, total_player_spells + 1)
 WriteByte(&h14DA1, total_player_spells + 1)
 WriteByte(&h12743, total_player_spells + 1)
 start = &h8906 + total_player_spells * 6
 WriteByte(&h14DB0, start mod &h100)
 WriteByte(&h14DB1, start \ &h100)
 for i as Integer = total_spells to 1 step -1
  spells(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_commands
  'a command that was not edited is not written: a ROM hack may have changed the code that some of its bytes are in
  if not menucommands(i).SameAs(orig_menucommands(i)) then menucommands(i).WriteToROM(i)
 next
 formulas.WriteToROM()
 for k as Integer = 1 to 4
  for j as Integer = 0 to 4
   WriteByte(&h7A9C6 + (total_commands + k - 1) * 5 + j, asc(mid(internal_command_names(k), j + 1, 1)))
  next
 next
 
 for i as Integer = 1 to total_jobs
  jobs(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_characters - 1
  characters(i).WriteToROM(i)
 next

 for i as Integer = 1 to total_actors
  actors(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_npcs
  npcs(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_maps
  placement_groups(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_tilesets
  tilesets(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_maps
  if i < 252 or i > 256 then maps(i).WriteToROM(i)
 next
 SaveMapGrids()
 SaveWorldMaps()
 
 for i as Integer = 1 to total_stat_groups
  stat_groups(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_speed_groups
  speed_groups(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_special_sizes
  special_sizes(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_item_drops
  item_drops(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_monsters
  monsters(i).WriteToROM(i)
 next
 
 temp = 0
 rewards = 0
 for i as Integer = 1 to total_formations
  formations(i).WriteToROM(i)
  if temp < 6 and formations(i).battle_music = 4 then
   WriteByte(&hA0069 + temp * 2, (i - 1) mod &h100)
   WriteByte(&hA0069 + temp * 2 + 1, (i - 1) \ &h100)
   temp += 1
  end if
  if rewards < 12 and formations(i).rewards = false then
   WriteByte(&h9FF00 + rewards * 2, (i - 1) mod &h100)
   WriteByte(&h9FF00 + rewards * 2 + 1, (i - 1) \ &h100)
   rewards += 1
  end if
 next
 for i as Integer = temp to 5
  WriteByte(&hA0069 + i * 2, 0)
  WriteByte(&hA0069 + i * 2 + 1, 2)
 next
 for i as Integer = rewards to 11
  WriteByte(&h9FF00 + i * 2, 0)
  WriteByte(&h9FF00 + i * 2 + 1, 2)
 next
  
 for i as Integer = 1 to total_autobattles
  autobattles(i).WriteToROM(i)
 next
 
 for i as Integer = 1 to total_solobattles
  solobattles(i).WriteToROM(i)
 next
 
 'Write odds and ends
 WriteByte(&h6611, solobattle_actor)
 WriteByte(&h6654, solobattle_actor)
 WriteByte(&h67B8, jobchange_actor)
 WriteByte(&h67BC, jobchange_job)

 'Write character names
 for i as Integer = 1 to total_characters
  for j as Integer = 0 to 5
   WriteByte(&h7A910 + (i - 1) * 6 + j, asc(mid(character_names.ItemAt(i), j + 1, 1)))
  next
 next
 
 'Write encounters
 for i as Integer = 1 to total_encounters
  for j as Integer = 1 to 8
   WriteByte(&h74996 + (i - 1) * 8 + j - 1, encounters(i, j))
  next
 next
 
 'Write map encounter relationships
 for i as Integer = 1 to total_encounter_tables
  WriteByte(&h74742 + i - 1, encounter_tables(i))
 next 
 
 'FF-terminated lists are more complicated to write
 SaveSpellSets()
 SaveEvents()
 SaveEventCalls()
 SaveTriggers()
 SaveLevelups()
 SaveDialogues()
 SaveAIs()
 
 SaveSpellColorNames()
 SaveBattleCharGfx()
 SavePortraits()

end sub


sub SaveData(filename as String)

 'Write the memory objects to the ROM image
 ApplyDataToROM()

 'Write the ROM image to the actual file.
 if not warning then
  'Keep a copy of the file as it was before the first save of this session.
  if not backup_done then
   if dir(filename) <> "" then
    last_backup_name = BackupName(filename)
    if CopyFile(filename, last_backup_name) then
     backup_done = true
    else
     last_backup_name = ""
    end if
   end if
  end if
  if open(filename for binary access write as #1) <> 0 then
   warning = true
   if save_problems <> "" then save_problems += "|"
   save_problems += "Could not write " + filename + "|(read-only, or open in another program?)"
  else
   dim temp as String
   temp = ff4rom
   if unheadered then temp = mid(ff4rom, &h200 + 1)
   put #1, , temp
   close #1
   disk_rom = ff4rom
   saved_image = ff4rom
  end if
 end if

end sub


function SaveROM(filename as String) as Boolean

 'Save ROM from the menu: checks the file, writes it, and tells the user what
 ' happened, listing every problem found. Returns true if the file was written.
 ' After a failure the ROM image in memory is put back as it was, so nothing
 ' half-applied is kept.

 dim before as String = ff4rom

 save_problems = ""
 warning = false
 defer_warnings = true

 if SafeToSave(filename) then
  SaveData(filename)
 else
  warning = true
  save_problems = "Not saved: the ROM file changed on disk|and you chose not to overwrite it."
 end if
 defer_warnings = false

 if warning then
  warning = false
  ff4rom = before
  InfoBox("SAVE FAILED, nothing was written.||" + save_problems + "||Press any key", 4, 1)
  return false
 end if

 modified = false
 if last_backup_name <> "" then
  InfoBox("Data saved|Backup: " + last_backup_name + "||Press any key", 4, 1)
 else
  InfoBox("Data saved||Press any key", 20, 1)
 end if

 return true

end function
