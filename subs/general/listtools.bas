'Shared helpers for the spell / weapon / armor / medicine / tool / monster list
' editors: modified markers, revert, copy/paste, "where is this used?", and
' jumping to an entry from the global search.
'
' Keys (in those lists):  Ctrl+R revert   Ctrl+C copy   Ctrl+V paste   Ctrl+U where used

dim shared orig_rows(1 to 6, 0 to 255) as String
dim shared clip_has(1 to 6) as Boolean
dim shared clip_spell as Spell
dim shared clip_weapon as Weapon
dim shared clip_armor as Armor
dim shared clip_medicine as Medicine
dim shared clip_tool as Tool
dim shared clip_monster as Monster
dim shared last_list_pos(1 to 6) as Integer
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
 end select

 return 0

end function


sub SnapshotOriginalRows()

 'Remember how every entry looked when the ROM was loaded.

 dim kinds(1 to 6) as String = {"spells", "weapons", "armors", "medicines", "tools", "monsters"}

 for k as Integer = 1 to 6
  for i as Integer = 1 to CsvTableSize(kinds(k))
   orig_rows(k, i) = CsvRow(kinds(k), i)
  next
 next

end sub


function EntryModified(kind as String, i as Integer) as Boolean

 return CsvRow(kind, i) <> orig_rows(KindIndex(kind), i)

end function


sub RefreshEntryColor(list_menu as BlueMenu, kind as String, i as Integer)

 if i < 1 or i > list_menu.options.Length() then exit sub

 if EntryModified(kind, i) then list_menu.ChangeOption(i, "", 14) else list_menu.ChangeOption(i, "", 15)

end sub


function EntryName(kind as String, i as Integer) as String

 select case kind
  case "spells": return spells(i).name
  case "weapons": return weapons(i).name
  case "armors": return armors(i).name
  case "medicines": return medicines(i).name
  case "tools": return tools(i).name
  case "monsters": return monsters(i).name
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
 end select

end sub


sub RevertEntry(kind as String, i as Integer)

 'Puts one entry back the way it was when the ROM was loaded.

 dim saved_rom as String = ff4rom

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
   monsters(i) = blank_monster
   monsters(i).ReadFromROM(i)
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
 end select
 clip_has(KindIndex(kind)) = true

end sub


function ClipPaste(kind as String, i as Integer) as Boolean

 'Pastes the copied entry over entry i, keeping entry i's own name.

 dim keep_name as String = EntryName(kind, i)

 if not clip_has(KindIndex(kind)) then return false

 select case kind
  case "spells": spells(i) = clip_spell
  case "weapons": weapons(i) = clip_weapon
  case "armors": armors(i) = clip_armor
  case "medicines": medicines(i) = clip_medicine
  case "tools": tools(i) = clip_tool
  case "monsters": monsters(i) = clip_monster
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


function UsageText(kind as String, id as Integer) as String

 'Lists where a monster, item or spell is used (lines separated by "|").

 dim lines as String
 dim count as Integer
 dim shown as Integer
 dim code as Integer
 dim is_item as Boolean
 dim t as Trigger ptr
 dim found(1 to total_formations) as Boolean
 dim row as Integer
 dim inside as Integer
 dim underground as Integer
 dim area_hit as Boolean
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
   lines += "||Random encounters:"
   count = 0
   shown = 0
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


function ListInput(list_menu as BlueMenu, kind as String) as Boolean

 'Drop-in replacement for list_menu.UserInput() in the list editors. Adds modified
 ' markers, remembers the last position, accepts a jump from global search,
 ' and handles revert / copy / paste / where-used keys.

 dim k as Integer = KindIndex(kind)
 dim result as Boolean

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

 result = list_menu.UserInput()
 if result then
  if not list_menu.cancelled then last_list_pos(k) = list_menu.selected
  return true
 end if
 last_list_pos(k) = list_menu.selected

 select case list_menu.last_key
  case 18 'Ctrl+R
   if EntryModified(kind, list_menu.selected) then
    if ConfirmBox("Revert this entry to the loaded ROM?") then
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
  case 22 'Ctrl+V
   if ClipPaste(kind, list_menu.selected) then
    RefreshEntryColor(list_menu, kind, list_menu.selected)
   else
    InfoBox("Nothing copied yet. Use Ctrl+C first.||Press any key")
   end if
  case 21 'Ctrl+U
   ShowUsage(kind, list_menu.selected)
 end select

 return false

end function
