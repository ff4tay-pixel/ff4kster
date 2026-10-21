'The messages of the game as the Messages editor sees them.
'
'There are seven banks: 1 (plot messages), 2 (the messages of each map, so a bank 2 message is a map and a number),
'3 (more plot dialogue), 4 (battle messages), 5 (battle alerts), 6 (status names) and 7 (item descriptions).
'Banks 1 to 3 are written in the dialogue encoding (two letters in one byte, /name, /song, /wait codes), banks 4 and
'5 can hold name codes, and 6 and 7 are plain text.
'
'This file gives one way to read, write and compare a message of any bank, the text of a message as plain letters for
'searching and for the list, how full each bank is (the same areas Save ROM checks), where a message is used (the
'events and NPCs that show it) and the renumbering of those uses when messages of a map are inserted, deleted or
'swapped, so that nothing shows the wrong text afterwards.

const msg_bank_count = 7

dim shared msg_orig_1 as List 'the messages as they were when the ROM was loaded
dim shared msg_orig_3 as List
dim shared msg_orig_4 as List
dim shared msg_orig_5 as List
dim shared msg_orig_6 as List
dim shared msg_orig_7 as List
dim shared msg_orig_map(1 to total_maps) as List


sub SnapshotOriginalMessages()

 msg_orig_1 = dialogues_bank1
 msg_orig_3 = dialogues_bank3
 msg_orig_4 = dialogues_battle
 msg_orig_5 = dialogues_alerts
 msg_orig_6 = dialogues_status
 msg_orig_7 = item_descriptions
 for m as Integer = 1 to total_maps
  msg_orig_map(m) = maps(m).dialogues
 next

end sub


function MsgBankName(bank as Integer) as String

 select case bank
  case 1: return "Bank 1"
  case 2: return "Bank 2"
  case 3: return "Bank 3"
  case 4: return "Battle"
  case 5: return "Alerts"
  case 6: return "Statuses"
 end select

 return "Items"

end function


function MsgBankInfo(bank as Integer) as String

 'A short description of what the bank holds

 select case bank
  case 1: return "Most of the plot messages. Events show them."
  case 2: return "The messages of each map, used by its NPCs and events."
  case 3: return "More plot dialogue, shown by events."
  case 4: return "Messages called during battle events."
  case 5: return "Generic messages that can come up in any battle."
  case 6: return "How status effects are named in battle."
  case 7: return "The descriptions of items, weapons and armor."
 end select

 return ""

end function


function MsgIsLarge(bank as Integer) as Boolean

 'Banks 1 to 3 are edited in the large text window, the others in a one line box

 return bank <= 3

end function


function MsgWidth(bank as Integer) as Integer

 'The widest message of a small bank, in letters

 select case bank
  case 4, 5: return 24
  case 6: return 8
 end select

 return 19

end function


function MsgCount(bank as Integer, mp as Integer) as Integer

 select case bank
  case 1: return dialogues_bank1.Length()
  case 2: return maps(mp).dialogues.Length()
  case 3: return dialogues_bank3.Length()
  case 4: return dialogues_battle.Length()
  case 5: return dialogues_alerts.Length()
  case 6: return dialogues_status.Length()
 end select

 return item_descriptions.Length()

end function


function MsgGet(bank as Integer, mp as Integer, i as Integer) as String

 select case bank
  case 1: return dialogues_bank1.ItemAt(i)
  case 2: return maps(mp).dialogues.ItemAt(i)
  case 3: return dialogues_bank3.ItemAt(i)
  case 4: return dialogues_battle.ItemAt(i)
  case 5: return dialogues_alerts.ItemAt(i)
  case 6: return dialogues_status.ItemAt(i)
 end select

 return item_descriptions.ItemAt(i)

end function


sub MsgSet(bank as Integer, mp as Integer, i as Integer, text as String)

 select case bank
  case 1: dialogues_bank1.Assign(i, text)
  case 2: maps(mp).dialogues.Assign(i, text)
  case 3: dialogues_bank3.Assign(i, text)
  case 4: dialogues_battle.Assign(i, text)
  case 5: dialogues_alerts.Assign(i, text)
  case 6: dialogues_status.Assign(i, text)
  case else: item_descriptions.Assign(i, text)
 end select

end sub


function MsgOriginal(bank as Integer, mp as Integer, i as Integer, byref text as String) as Boolean

 'The message as it was when the ROM was loaded. False if there was no such message (a new one).

 select case bank
  case 1
   if i > msg_orig_1.Length() then return false
   text = msg_orig_1.ItemAt(i)
  case 2
   if i > msg_orig_map(mp).Length() then return false
   text = msg_orig_map(mp).ItemAt(i)
  case 3
   if i > msg_orig_3.Length() then return false
   text = msg_orig_3.ItemAt(i)
  case 4
   if i > msg_orig_4.Length() then return false
   text = msg_orig_4.ItemAt(i)
  case 5
   if i > msg_orig_5.Length() then return false
   text = msg_orig_5.ItemAt(i)
  case 6
   if i > msg_orig_6.Length() then return false
   text = msg_orig_6.ItemAt(i)
  case else
   if i > msg_orig_7.Length() then return false
   text = msg_orig_7.ItemAt(i)
 end select

 return true

end function


function MsgChanged(bank as Integer, mp as Integer, i as Integer) as Boolean

 dim original as String

 if not MsgOriginal(bank, mp, i, original) then return true

 return original <> MsgGet(bank, mp, i)

end function


function MsgMapChanged(mp as Integer) as Boolean

 'True if any message of the map differs from the loaded ROM (or the map has more or fewer messages)

 if maps(mp).dialogues.Length() <> msg_orig_map(mp).Length() then return true
 for i as Integer = 1 to maps(mp).dialogues.Length()
  if MsgChanged(2, mp, i) then return true
 next

 return false

end function


'-------- the text of a message as letters --------

function MsgPlain(bank as Integer, text as String) as String

 'The message as plain letters on one line, with codes left out, for the list and for searching

 dim lines as List
 dim joined as String
 dim ff4 as String

 if MsgIsLarge(bank) then
  lines = ParseDTE(text, false)
  for i as Integer = 1 to lines.Length()
   joined += lines.ItemAt(i) + FF4Text(" ")
  next
  ff4 = joined
 else
  for i as Integer = 1 to len(text)
   if asc(mid(text, i, 1)) = 4 and (bank = 4 or bank = 5) then
    if i < len(text) then
     i += 1
     ff4 += character_names.ItemAt(asc(mid(text, i, 1)) + 1)
    end if
   elseif asc(mid(text, i, 1)) = 6 then
    if i < len(text) then i += 1
   else
    ff4 += mid(text, i, 1)
   end if
  next
 end if

 return PlainName(FF4Name(ff4))

end function


function MsgPreview(bank as Integer, text as String, wd as Integer) as String

 'The start of the message as FF4 text, for a line of the list

 dim plain as String = MsgPlain(bank, text)

 if plain = "" then return FF4Text("- empty -")

 return FF4Text(left(plain, wd))

end function


function MsgLabel(bank as Integer, mp as Integer, i as Integer, wd as Integer) as String

 'The list line of a message: its number and the start of its text

 dim digits as Integer = iif(bank = 2, 2, 3)

 if bank = 6 then
  'the status names are listed under the name of the status they belong to
  return element_names.ItemAt(((i - 1) \ 8 + 1) * 8 + 8 - ((i - 1) mod 8)) + FF4Text("  ") + MsgPreview(bank, MsgGet(bank, mp, i), wd)
 end if

 return FF4Text(Pad(str(i), digits, true, "0") + "  ") + MsgPreview(bank, MsgGet(bank, mp, i), wd)

end function


'-------- how full a bank is --------

function MsgDescribedCount() as Integer

 'The items that have a description (the room for the descriptions shrinks by one byte for each)

 dim described as Integer

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

 return described

end function


function MsgUsed(bank as Integer) as Integer

 'Bytes the whole bank takes up when written (each message ends in a 0 byte). Bank 2 is all the maps together.

 dim result as Integer

 if bank = 2 then
  for m as Integer = 1 to total_maps
   for i as Integer = 1 to maps(m).dialogues.Length()
    result += len(maps(m).dialogues.ItemAt(i)) + 1
   next
  next
 else
  for i as Integer = 1 to MsgCount(bank, 0)
   result += len(MsgGet(bank, 0, i)) + 1
  next
 end if

 return result

end function


function MsgRoom(bank as Integer) as Integer

 'Bytes the ROM has for the bank (the same areas as Save ROM and Space Usage)

 select case bank
  case 1: return &h881FF - &h80600
  case 2: return &h901FB - &h88500
  case 3: return &h9D3FF - &h9A900
  case 4: return &h781FF - &h77574
  case 5: return &h7B5FF - &h7B276
  case 6: return &h7B6FF - &h7B640
 end select

 return &h7B1FF - (&h7B000 + MsgDescribedCount())

end function


function MsgSpaceText(bank as Integer) as String

 'For example "12345 of 14000 bytes, 88%"

 dim used as Integer = MsgUsed(bank)
 dim room as Integer = MsgRoom(bank)

 return str(used) + " of " + str(room) + " bytes, " + str(used * 100 \ Max(room, 1)) + "%"

end function


function MsgSpaceColor(bank as Integer) as Integer

 'White, yellow when nearly full, red when over (Save ROM would refuse)

 dim used as Integer = MsgUsed(bank)
 dim room as Integer = MsgRoom(bank)

 if used > room then return 12
 if used * 100 >= room * 95 then return 14

 return 15

end function


'-------- where a message is used --------

function MsgEventUses(bank as Integer, mp as Integer, n as Integer, byref lines as String, max_lines as Integer) as Integer

 'The events that show message n. Adds a line for each to lines (up to max_lines) and returns how many.
 ' Bank 1: Show message, with Yes/No box. Bank 3: from bank 3. Bank 2: starting from the map pointer, in the
 ' events that belong to the map.

 dim count as Integer
 dim part as Integer
 dim entry as String
 dim fc as Integer
 dim xx as Integer
 dim hit as Boolean
 dim l as List
 dim shown as Integer

 for e as Integer = 1 to total_events
  if bank <> 2 or events(e).map_link = mp then
   hit = false
   for part = 0 to 1
    if part = 0 then l = events(e).script else l = events(e).else_script
    for q as Integer = 1 to l.Length()
     entry = l.ItemAt(q)
     if len(entry) >= 2 then
      fc = asc(left(entry, 1))
      xx = asc(mid(entry, 2, 1))
      select case bank
       case 1
        if (fc = &hF0 and xx + 1 = n) or ((fc = &hF1 or fc = &hF8) and xx + &h101 = n) then hit = true
       case 3
        if fc = &hF6 and xx + 1 = n then hit = true
       case 2
        if fc = &hEF and xx + 1 = n then hit = true
      end select
     end if
    next
   next
   if hit then
    count += 1
    if count <= max_lines then lines += "|Event " + str(e) + " " + PlainName(FF4Name(event_names.ItemAt(e)))
   end if
  end if
 next

 return count

end function


function MsgNpcUses(mp as Integer, n as Integer, byref lines as String, max_lines as Integer) as Integer

 'The NPCs placed on the map that speak message n. Adds a line for each and returns how many.

 dim count as Integer
 dim p as Placement ptr
 dim npc_number as Integer

 for j as Integer = 1 to placement_groups(mp).placements.Length()
  p = placement_groups(mp).placements.PointerAt(j)
  npc_number = p->npc_index
  if p->underground then npc_number += &h100
  for q as Integer = 1 to npcs(npc_number).speech.parameters.Length()
   if asc(npcs(npc_number).speech.parameters.ItemAt(q)) + 1 = n then
    count += 1
    if count <= max_lines then lines += "|NPC " + PlainName(FF4Name(npc_names.ItemAt(npc_number + 1))) + " at " + str(p->x) + "," + str(p->y)
    exit for
   end if
  next
 next

 return count

end function


function MsgUsers(bank as Integer, mp as Integer, n as Integer) as String

 'Where message n is used, as lines for the usage box separated by "|"

 dim lines as String
 dim count as Integer
 dim shown_limit as Integer = 12

 if bank > 3 then
  return "|The game itself uses this text: battle events, monster AI, commands or the item screens, which this list does not follow."
 end if

 count = MsgEventUses(bank, mp, n, lines, shown_limit)
 if bank = 2 then count += MsgNpcUses(mp, n, lines, shown_limit)
 if count = 0 then lines += "|Not shown by any event" + iif(bank = 2, " or NPC of this map.", ".")
 if count > shown_limit then lines += "|...and " + str(count - shown_limit) + " more"

 return lines

end function


'-------- renumbering the uses of a map's messages --------

function MsgNewNumber(op as Integer, a as Integer, b as Integer, v as Integer) as Integer

 'Where message v goes when message a is inserted before (op 1), deleted (op 2) or swapped with b (op 3)

 select case op
  case 1
   if v >= a then return Min(v + 1, 256)
  case 2
   if v > a then return v - 1
  case 3
   if v = a then return b
   if v = b then return a
 end select

 return v

end function


function MsgRenumber(mp as Integer, op as Integer, a as Integer, b as Integer) as String

 'After messages of the map were inserted, deleted or swapped, point the NPCs of the map and the events that
 ' belong to it at the messages they showed before. Returns a note for NPCs that are also placed on other maps
 ' (their messages there are not changed along), empty if there is nothing to say.

 dim p as Placement ptr
 dim npc_number as Integer
 dim seen(0 to total_npcs) as Boolean
 dim v as Integer
 dim nv as Integer
 dim note as String
 dim part as Integer
 dim l as List
 dim entry as String
 dim shared_maps as Integer

 for j as Integer = 1 to placement_groups(mp).placements.Length()
  p = placement_groups(mp).placements.PointerAt(j)
  npc_number = p->npc_index
  if p->underground then npc_number += &h100
  if not seen(npc_number) then
   seen(npc_number) = true
   for q as Integer = 1 to npcs(npc_number).speech.parameters.Length()
    v = asc(npcs(npc_number).speech.parameters.ItemAt(q)) + 1
    nv = MsgNewNumber(op, a, b, v)
    if nv <> v then npcs(npc_number).speech.parameters.Assign(q, chr(nv - 1))
   next
   'the same NPC on another map keeps its numbers, which are now off there
   shared_maps = 0
   for m as Integer = 1 to total_maps - 1
    if m <> mp then
     for k as Integer = 1 to placement_groups(m).placements.Length()
      p = placement_groups(m).placements.PointerAt(k)
      if p->npc_index + iif(p->underground, &h100, 0) = npc_number then
       shared_maps += 1
       exit for
      end if
     next
    end if
   next
   if shared_maps > 0 and npcs(npc_number).speech.parameters.Length() > 0 then
    note += "|NPC " + PlainName(FF4Name(npc_names.ItemAt(npc_number + 1))) + " is also on " + str(shared_maps) + " other map" + iif(shared_maps > 1, "s", "") + ": check what it says there."
   end if
  end if
 next

 for e as Integer = 1 to total_events
  if events(e).map_link = mp then
   for part = 0 to 1
    if part = 0 then l = events(e).script else l = events(e).else_script
    for q as Integer = 1 to l.Length()
     entry = l.ItemAt(q)
     if len(entry) >= 2 then
      if asc(left(entry, 1)) = &hEF then
       v = asc(mid(entry, 2, 1)) + 1
       nv = MsgNewNumber(op, a, b, v)
       if nv <> v then
        mid(entry, 2, 1) = chr(nv - 1)
        if part = 0 then events(e).script.Assign(q, entry) else events(e).else_script.Assign(q, entry)
       end if
      end if
     end if
    next
   next
  end if
 next

 return note

end function
