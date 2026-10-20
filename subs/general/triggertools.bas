'Editing the triggers under the cursor from a map editor screen (the regular map editor and the world
'map editor). T edits the trigger on the tile (or offers to add one), Insert adds one, Delete removes
'one; when several triggers share a tile a short list asks which one. The editing itself is the
'Edit Triggers screen. Limits: the world maps share room for 82 triggers (max_overworld_triggers), all the
'other maps share room for max_triggers.


function TriggerUnderworld(m as Integer) as Boolean

 'Maps whose teleports name maps of the underground set (as Edit Triggers decides it)

 return m > &h100 or m = 253 or m = 254

end function


function PlainName(s as String) as String

 'A name without the {hh} codes FF4Name leaves for characters that have no letter (item icons)

 dim result as String = s
 dim open_pos as Integer = instr(result, "{")

 do while open_pos > 0
  if mid(result, open_pos + 3, 1) = "}" then
   result = left(result, open_pos - 1) + mid(result, open_pos + 4)
  else
   result = left(result, open_pos - 1) + mid(result, open_pos + 1)
  end if
  open_pos = instr(result, "{")
 loop

 return trim(result)

end function


function TriggerSummary(m as Integer, t as Trigger ptr) as String

 'A few words about what a trigger does

 dim destination as String
 dim contents as String

 if t->warp then
  if not TriggerUnderworld(m) then
   destination = map_names.ItemAt(t->new_map + 1)
  elseif t->new_map < 128 then
   destination = map_names.ItemAt(t->new_map + 257)
  elseif t->new_map >= 251 then
   destination = map_names.ItemAt(t->new_map + 1)
  else
   destination = FF4Text("unknown")
  end if
  return "goes to " + PlainName(FF4Name(destination)) + " at " + str(t->new_x) + "," + str(t->new_y)
 elseif t->treasure then
  if t->item then contents = PlainName(FF4Name(item_names.ItemAt(t->contents + 1))) else contents = PriceName(t->contents)
  if t->trapped then return "treasure, " + contents + ", trapped"
  return "treasure, " + contents
 end if

 return "event " + str(t->event)

end function


function TriggersAt(m as Integer, tile_x as Integer, tile_y as Integer, found() as Integer) as Integer

 'How many triggers are on a tile; found(1 to n) get their numbers (at most 63)

 dim count as Integer
 dim t as Trigger ptr

 for i as Integer = 1 to maps(m).triggers.Length()
  t = maps(m).triggers.PointerAt(i)
  if t->x = tile_x and t->y = tile_y and count < 63 then
   count += 1
   found(count) = i
  end if
 next

 return count

end function


function TriggerStatusText(m as Integer, tile_x as Integer, tile_y as Integer) as String

 'For the status line: "Trigger 3: goes to ... at 4,5" (and how many more are on the tile), or ""

 dim found(63) as Integer
 dim n as Integer = TriggersAt(m, tile_x, tile_y, found())
 dim result as String

 if n = 0 then return ""
 result = "Trigger " + str(found(1)) + ": " + TriggerSummary(m, maps(m).triggers.PointerAt(found(1)))
 if n > 1 then result += "  and " + str(n - 1) + " more here"

 return result

end function


function PickTriggerAt(m as Integer, tile_x as Integer, tile_y as Integer) as Integer

 'The number of the trigger to work on: the only one on the tile, or the one chosen from a list.
 ' 0 if there is none, -1 if the list was cancelled.

 dim found(63) as Integer
 dim n as Integer = TriggersAt(m, tile_x, tile_y, found())
 dim choose as BlueMenu

 if n = 0 then return 0
 if n = 1 then return found(1)

 choose.x = 4
 choose.y = 20
 choose.title = "Which trigger?"
 for k as Integer = 1 to n
  choose.AddOption(FF4Text(left("Trigger " + str(found(k)) + ": " + TriggerSummary(m, maps(m).triggers.PointerAt(found(k))), 70)))
 next
 choose.UserSelect()
 if choose.cancelled then return -1

 return found(choose.selected)

end function


sub EditTriggerScreen(m as Integer, index as Integer)

 'The Edit Triggers screen for one trigger. The screen as it was is put back afterwards.

 dim info as TriggerInfoMenu
 dim backdrop as Any ptr = ImageCreate(640, 480)

 get (0, 0)-(639, 479), backdrop
 info = TriggerInfoMenu(12, 10)
 info.t = maps(m).triggers.PointerAt(index)
 info.m = m
 info.underworld = TriggerUnderworld(m)
 cls
 WriteText(FF4Text("Trigger " + str(index) + " of " + FF4Name(map_names.ItemAt(m))), 12, 6, 14)
 info.Display()
 info.UserSelect()
 RecomputeTreasureIndexes()
 put (0, 0), backdrop, pset
 ImageDestroy(backdrop)
 'a draw on the screen itself, so the destroyed image is not left as the drawing target
 pset (0, 0), point(0, 0)

end sub


function AddTriggerAt(m as Integer, tile_x as Integer, tile_y as Integer) as Integer

 'A new trigger on the tile. Returns its number, or 0 if there is no room.

 dim t as Trigger ptr
 dim is_world as Boolean = (m >= 252 and m <= 254)

 if is_world then
  if maps(252).triggers.Length() + maps(253).triggers.Length() + maps(254).triggers.Length() >= max_overworld_triggers then
   InfoBox("The game has room for " + str(max_overworld_triggers) + " world triggers in all.|Delete one first.||Press any key", 20, 20)
   return 0
  end if
 elseif total_triggers >= max_triggers then
  InfoBox("There is no room for more triggers.|The game has room for " + str(max_triggers) + " in all.||Press any key", 20, 20)
  return 0
 end if

 t = callocate(SizeOf(Trigger))
 t->x = tile_x
 t->y = tile_y
 maps(m).triggers.Append(t)
 if not is_world then total_triggers += 1

 return maps(m).triggers.Length()

end function


function TriggerKeyAt(m as Integer, tile_x as Integer, tile_y as Integer, action as Integer) as Boolean

 'action 1 = T (edit, or add if there is none), 2 = Insert (add), 3 = Delete. Returns true if the
 ' triggers may have changed (so the screen should redraw its markers).

 dim index as Integer
 dim found(63) as Integer

 select case action

  case 1
   index = PickTriggerAt(m, tile_x, tile_y)
   if index > 0 then
    EditTriggerScreen(m, index)
    return true
   elseif index = 0 then
    if ConfirmBox("No trigger here. Add one?") then
     index = AddTriggerAt(m, tile_x, tile_y)
     if index > 0 then EditTriggerScreen(m, index)
     return true
    end if
   end if

  case 2
   if TriggersAt(m, tile_x, tile_y, found()) > 0 then
    if not ConfirmBox("There is already a trigger here. Add another?") then return false
   end if
   index = AddTriggerAt(m, tile_x, tile_y)
   if index > 0 then EditTriggerScreen(m, index)
   return true

  case 3
   index = PickTriggerAt(m, tile_x, tile_y)
   if index > 0 then
    if ConfirmBox("Delete this trigger?") then
     maps(m).triggers.Remove(index)
     if m < 252 or m > 254 then total_triggers -= 1
     RecomputeTreasureIndexes()
     return true
    end if
   end if

 end select

 return false

end function
