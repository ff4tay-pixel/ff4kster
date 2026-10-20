'Helpers for the event editor: how full the event room is, the hint lines, undo and copy / paste of
'script commands, keys and mouse for the script menus, and where an event is used.

const event_room = &h6E00 'bytes the game has for all the events' scripts

dim shared event_undo(49) as String
dim shared event_undo_count as Integer
dim shared event_redo(49) as String
dim shared event_redo_count as Integer
dim shared event_clip as String 'the script command last copied
dim shared event_clip_has as Boolean


function EventsBytesUsed() as Integer

 dim used as Integer

 for i as Integer = 1 to total_events
  used += events(i).Length()
 next

 return used

end function


function EventRoomTitle(label as String) as String

 'Text for a box's top border: the label and how much room is left for all the events

 dim used as Integer = EventsBytesUsed()

 if used > event_room then return label + "   OVER by " + str(used - event_room) + " bytes!"

 return label + "   Room " + str(event_room - used) + " bytes"

end function


sub DrawEventHints(script_mode as Boolean)

 'Three lines of key hints at the top right (the preview menu is at the top left)

 if script_mode then
  WriteText(FF4Text(Pad("Enter change  Ins add  Del remove", 38)), 40, 0, 15)
  WriteText(FF4Text(Pad("Ctrl-C V copy paste  Ctrl-Z Y undo", 38)), 40, 1, 15)
  WriteText(FF4Text(Pad("Tab else  Shift-Enter swap  Bksp erase", 38)), 40, 2, 15)
 else
  WriteText(FF4Text(Pad("Enter edit  Tab preview map  F1 help", 38)), 40, 0, 15)
  WriteText(FF4Text(Pad("Shift-Enter mark, Enter swap, Ins join", 38)), 40, 1, 15)
  WriteText(FF4Text(Pad("Ctrl-F find  Ctrl-U used  Ctrl-Z undo", 38)), 40, 2, 15)
 end if

end sub


function EventSnapshot(index as Integer) as String

 'The scripts of an event as text, to put back later (ListToText is in the list tools)

 return ListToText(events(index).script) + "|" + ListToText(events(index).else_script)

end function


sub EventRestore(index as Integer, snapshot as String)

 dim bar as Integer = instr(snapshot, "|")

 TextToList(events(index).script, left(snapshot, bar - 1))
 TextToList(events(index).else_script, mid(snapshot, bar + 1))

end sub


sub EventUndoReset()

 event_undo_count = 0
 event_redo_count = 0

end sub


sub EventUndoPush(index as Integer)

 'Call before changing the script

 if event_undo_count = 50 then
  for i as Integer = 1 to 49
   event_undo(i - 1) = event_undo(i)
  next
  event_undo_count = 49
 end if
 event_undo(event_undo_count) = EventSnapshot(index)
 event_undo_count += 1
 event_redo_count = 0

end sub


sub EventUndoDropIfSame(index as Integer)

 'Call after a change that may not have changed anything: forget the step if nothing differs

 if event_undo_count > 0 then
  if event_undo(event_undo_count - 1) = EventSnapshot(index) then event_undo_count -= 1
 end if

end sub


function EventUndo(index as Integer) as Boolean

 if event_undo_count = 0 then return false
 if event_redo_count = 50 then
  for i as Integer = 1 to 49
   event_redo(i - 1) = event_redo(i)
  next
  event_redo_count = 49
 end if
 event_redo(event_redo_count) = EventSnapshot(index)
 event_redo_count += 1
 event_undo_count -= 1
 EventRestore(index, event_undo(event_undo_count))

 return true

end function


function EventRedo(index as Integer) as Boolean

 if event_redo_count = 0 then return false
 if event_undo_count < 50 then
  event_undo(event_undo_count) = EventSnapshot(index)
  event_undo_count += 1
 end if
 event_redo_count -= 1
 EventRestore(index, event_redo(event_redo_count))

 return true

end function


function EventKey(m as BlueMenu ptr) as UInteger

 'Like getkey, but the mouse works too: a click selects, a second click opens, the wheel moves the
 ' cursor and the right button goes back (see BlueMenu.MouseCode)

 dim key as String
 dim code as UInteger

 do
  key = inkey
  if key <> "" then
   code = asc(right(key, 1))
   if len(key) > 1 then code = code * &h100 + 255
   return code
  end if
  code = m->MouseCode()
  if code <> 0 then return code
  sleep 10
 loop

end function


function EventUsageLines(id as Integer) as String

 'Where an event is used, as lines for the usage box: the triggers (through their event calls) and the
 ' NPCs whose speech calls it. Lines are separated by "|".

 dim lines as String
 dim count as Integer
 dim shown as Integer
 dim ec as EventCall ptr
 dim c as CallComponent ptr
 dim t as Trigger ptr
 dim p as Placement ptr
 dim uses_it as Boolean
 dim npc_number as Integer
 const max_lines = 14

 'Triggers: event calls that run this event, and the triggers that use those calls
 for k as Integer = 1 to eventcalls.Length()
  ec = eventcalls.PointerAt(k)
  uses_it = false
  for j as Integer = 1 to ec->components.Length()
   c = ec->components.PointerAt(j)
   if c->event_reference = id then uses_it = true
  next
  if uses_it then
   for m as Integer = 1 to total_maps
    for j as Integer = 1 to maps(m).triggers.Length()
     t = maps(m).triggers.PointerAt(j)
     if not t->warp and not t->treasure and t->event = k then
      count += 1
      if shown < max_lines then
       lines += "|Trigger on " + PlainName(FF4Name(map_names.ItemAt(m))) + " at " + str(t->x) + "," + str(t->y)
       shown += 1
      end if
     end if
    next
   next
  end if
 next

 'NPCs: placements whose NPC speaks with this event
 for m as Integer = 1 to total_maps - 1
  for j as Integer = 1 to placement_groups(m).placements.Length()
   p = placement_groups(m).placements.PointerAt(j)
   npc_number = p->npc_index
   if p->underground then npc_number += &h100
   uses_it = false
   for q as Integer = 1 to npcs(npc_number).speech.components.Length()
    c = npcs(npc_number).speech.components.PointerAt(q)
    if c->event_reference = id then uses_it = true
   next
   if uses_it then
    count += 1
    if shown < max_lines then
     lines += "|NPC " + PlainName(FF4Name(npc_names.ItemAt(npc_number + 1))) + " on " + PlainName(FF4Name(map_names.ItemAt(m))) + " at " + str(p->x) + "," + str(p->y)
     shown += 1
    end if
   end if
  next
 next

 if count = 0 then lines += "|Not called by any trigger or NPC."
 if count > shown then lines += "|...and " + str(count - shown) + " more"

 return lines

end function
