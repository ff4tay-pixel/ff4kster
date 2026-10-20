'Editing the triggers under the cursor from a map editor screen (the regular map editor and the world
'map editor). T edits the trigger on the tile (or offers to add one), Insert adds one, Delete removes
'one; when several triggers share a tile a short list asks which one. The editing itself is the
'Edit Triggers screen. Limits: the world maps share room for 82 triggers (max_overworld_triggers), all the
'other maps share room for max_triggers.


declare function PickWorldSpot(w as Integer, byref spot_x as Integer, byref spot_y as Integer) as Boolean


function TriggerGoesToWorld(t as Trigger ptr) as Boolean

 'A teleport to the overworld, the underground or the moon (destination 251-253). For these the game
 ' reads the whole byte that holds new_x and the facing as the X position, and ignores the facing.

 return t->warp and t->new_map >= 251 and t->new_map <= 253

end function


function TriggerUnderworld(m as Integer) as Boolean

 'Maps whose teleports name maps of the underground set (as Edit Triggers decides it)

 return m > &h100 or m = 253 or m = 254

end function


function TeleportDestinationIndex(underworld as Boolean, new_map as Integer) as Integer

 'The number in the map list (and in maps()) of the map a teleport goes to

 if underworld and new_map < 128 then return new_map + 257

 return new_map + 1

end function


function PickTeleportSpot(map_index as Integer, byref spot_x as Integer, byref spot_y as Integer) as Boolean

 'Shows the map a teleport goes to and lets the user move a cursor to where the party should arrive.
 ' Arrows move, Enter (or clicking the cursor tile again) chooses, Esc or a right click cancels. Returns
 ' true if a spot was chosen. False too if the map cannot be shown (a map with no data), in which case
 ' the caller keeps the numbers. The three worlds are shown by PickWorldSpot.

 dim em as MapEditorMenu
 dim backdrop as Any ptr
 dim underground as Integer
 dim key as String
 dim key_code as UInteger
 dim done as Boolean
 dim chosen as Boolean
 dim moved as Boolean
 dim cell_x as Integer
 dim cell_y as Integer
 dim left_click as Boolean
 dim right_click as Boolean
 dim wheel_steps as Integer
 dim tile_x as Integer
 dim tile_y as Integer

 if map_index < 1 or map_index > total_maps then return false
 if map_index >= 252 and map_index <= 256 then return false
 if map_index > &h100 then underground = &h100
 if mapgrids(maps(map_index).grid_index + underground + 1).no_data then return false

 backdrop = ImageCreate(640, 480)
 get (0, 0)-(639, 479), backdrop

 em = MapEditorMenu(0, 3)
 em.SetTo(map_index)
 em.map_menu.x = 4
 em.map_menu.y = 4
 em.map_menu.active = true
 em.map_menu.cursor_x = min(spot_x, 31)
 em.map_menu.cursor_y = min(spot_y, 31)
 em.map_menu.ProcessKey(0) 'brings the cursor into view
 cls

 do
  em.map_menu.Display()
  BlueBox(4, 40, 70, 2)
  WriteText(FF4Text(Pad("Teleport to " + FF4Name(map_names.ItemAt(map_index)) + ", X " + str(em.map_menu.cursor_x) + "  Y " + str(em.map_menu.cursor_y), 68)), 5, 41, 15)
  WriteText(FF4Text(Pad("Arrows move, Enter chooses, Esc cancels.  Yellow: triggers, cyan: NPCs", 68)), 5, 42, 14)
  moved = false
  do
   key = inkey
   key_code = 0
   if key <> "" then
    key_code = asc(right(key, 1))
    if len(key) > 1 then key_code = key_code * &h100 + 255
   else
    PollMouse(cell_x, cell_y, left_click, right_click, wheel_steps)
    if right_click then
     key_code = ESC_KEY
    elseif wheel_steps > 0 then
     key_code = UP_KEY
    elseif wheel_steps < 0 then
     key_code = DOWN_KEY
    elseif left_click and em.map_menu.HitTile(mouse_pixel_x, mouse_pixel_y, tile_x, tile_y) then
     if tile_x = em.map_menu.cursor_x and tile_y = em.map_menu.cursor_y then
      key_code = ENTER_KEY
     else
      em.map_menu.cursor_x = tile_x
      em.map_menu.cursor_y = tile_y
      moved = true
     end if
    end if
   end if
   em.map_menu.Animate()
   if key_code = 0 and not moved then sleep 10
  loop while key_code = 0 and not moved
  select case key_code
   case ENTER_KEY
    chosen = true
    done = true
   case ESC_KEY
    done = true
   case UP_KEY, DOWN_KEY, LEFT_KEY, RIGHT_KEY, HOME_KEY, END_KEY, PAGEUP_KEY, PAGEDOWN_KEY
    em.map_menu.cursor_w = 0
    em.map_menu.cursor_h = 0
    em.map_menu.ProcessKey(key_code)
  end select
 loop until done

 if chosen then
  spot_x = em.map_menu.cursor_x
  spot_y = em.map_menu.cursor_y
 end if

 put (0, 0), backdrop, pset
 ImageDestroy(backdrop)
 'a draw on the screen itself, so the destroyed image is not left as the drawing target
 pset (0, 0), point(0, 0)

 return chosen

end function


function PickDestinationSpot(t as Trigger ptr, underworld as Boolean) as Boolean

 'Lets the user pick, on the map the teleport goes to, where the party arrives; sets new_x and new_y

 dim spot_x as Integer = t->new_x
 dim spot_y as Integer = t->new_y

 if TriggerGoesToWorld(t) then
  spot_x = t->new_x + t->facing * 64
  if PickWorldSpot(t->new_map - 251, spot_x, spot_y) then
   t->new_x = spot_x and 63
   t->facing = spot_x shr 6
   t->new_y = spot_y
   return true
  end if
  return false
 end if

 if PickTeleportSpot(TeleportDestinationIndex(underworld, t->new_map), spot_x, spot_y) then
  t->new_x = min(spot_x, 63)
  t->new_y = spot_y
  return true
 end if

 return false

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
  if TriggerGoesToWorld(t) then return "goes to " + PlainName(FF4Name(destination)) + " at " + str(t->new_x + t->facing * 64) + "," + str(t->new_y)
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
