function SpaceLine(label as String, used as Integer, capacity as Integer) as String

 dim pct as Integer
 dim note as String

 if capacity > 0 then pct = used * 100 \ capacity
 if used > capacity then note = "  OVER BY " + str(used - capacity) + "!" else note = "  " + str(capacity - used) + " free"

 return Pad(label, 18) + Pad(str(used), 6, true) + " / " + Pad(str(capacity), 6, true) + "  " + Pad(str(pct), 3, true) + "%" + note

end function


function ListBytes(l as List, count as Integer) as Integer

 'Bytes a list of strings takes up when written out (each ends in a 0 byte).

 dim result as Integer

 for i as Integer = 1 to count
  result += len(l.ItemAt(i)) + 1
 next

 return result

end function


function SpaceUsageText() as String

 'How full each fixed-size ROM area is, before Save ROM finds out the hard way.

 dim used as Integer
 dim lines as String
 dim described as Integer

 for i as Integer = 1 to total_events
  used += events(i).Length()
 next
 lines += SpaceLine("Events", used, &h6E00) + "|"

 used = 0
 for i as Integer = 1 to total_maps
  if i < 252 or i > 254 then used += maps(i).triggers.Length() * 5
 next
 lines += SpaceLine("Triggers", used, &hA9820 - &hA8500) + "|"

 lines += SpaceLine("Map messages", ListBytes(dialogues_bank1, total_dialogues_bank1), &h881FF - &h80600) + "|"

 used = 0
 for i as Integer = 1 to total_maps
  for j as Integer = 1 to maps(i).dialogues.Length()
   used += len(maps(i).dialogues.ItemAt(j)) + 1
  next
 next
 lines += SpaceLine("Map dialogue", used, &h901FB - &h88500) + "|"

 lines += SpaceLine("Bank 3 text", ListBytes(dialogues_bank3, total_dialogues_bank3), &h9D3FF - &h9A900) + "|"
 lines += SpaceLine("Battle messages", ListBytes(dialogues_battle, total_dialogues_battle), &h781FF - &h77574) + "|"
 lines += SpaceLine("Battle alerts", ListBytes(dialogues_alerts, total_dialogues_alerts), &h7B5FF - &h7B276) + "|"
 lines += SpaceLine("Status names", ListBytes(dialogues_status, total_dialogues_status), &h7B6FF - &h7B640) + "|"
 lines += SpaceLine("Map labels", ListBytes(map_labels, total_map_labels), &hA9E7F - &hA9820) + "|"
 lines += SpaceLine("Map data", MapDataBytes(), map_data_end - map_data_start) + "|"
 for w as Integer = 0 to 2
  lines += SpaceLine(WorldNameText(w) + " map", WorldDataBytes(w), world_capacity(w)) + "|"
 next

 for i as Integer = 1 to total_weapons
  if i >= descriptions_start and i < descriptions_end then described += 1
 next
 for i as Integer = 1 to total_armors
  if i + total_weapons + 2 > descriptions_start and i + total_weapons + 2 <= descriptions_end then described += 1
 next
 for i as Integer = 1 to total_medicines
  if i + total_weapons + total_armors + 2 > descriptions_start and i + total_weapons + total_armors + 2 <= descriptions_end then described += 1
 next
 for i as Integer = 1 to total_tools
  if i + total_weapons + total_armors + total_medicines + 2 > descriptions_start and i + total_weapons + total_armors + total_medicines + 2 <= descriptions_end then described += 1
 next
 lines += SpaceLine("Item descriptions", ListBytes(item_descriptions, total_descriptions), &h7B1FF - (&h7B000 + described))

 return lines

end function


sub ShowSpaceUsage()

 InfoBox("SPACE USED IN FIXED ROM AREAS||" + SpaceUsageText() + "||Over 100% means Save ROM will refuse to save.|Press any key", 2, 12)

end sub
