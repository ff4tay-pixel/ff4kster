declare sub UpdateTriggerMinimap(map_index as UInteger, tg as List, selected_trigger as UInteger, minimap_img as Any ptr, minimap_canvas as Any ptr)
declare sub DrawTriggerMinimapCursor(cx as Integer, cy as Integer)
declare function FindTriggerAt(cx as Integer, cy as Integer, tg as List) as Integer

sub RecomputeTreasureIndexes()

 'Every map numbers its chests from where the maps before it stop; call after triggers change

 dim treasures as UByte = 0
 dim t as Trigger ptr

 for i as Integer = 1 to total_maps - 1
  if i = 257 then treasures = 0
  maps(i).treasure_index = treasures
  for j as Integer = 1 to maps(i).triggers.Length()
   t = maps(i).triggers.PointerAt(j)
   if t->treasure then treasures += 1
  next
 next

end sub

sub RefillTriggerList(trigger_list as BlueMenu, m as Integer)

 'The list of a map's triggers, with the line that adds one at the end

 trigger_list.ClearAll()
 for i as Integer = 1 to maps(m).triggers.Length()
  trigger_list.AddOption(FF4Text("Trigger " + Pad(str(i), 2)))
 next
 trigger_list.AddOption(FF4Text("-- Add a trigger --"))

end sub


function TriggerAddAt(m as Integer, position as Integer) as Boolean

 'Adds an empty trigger before position (at the end if position is past the last one). Says so if the game has
 ' no room for it: it has a fixed number of triggers for all maps, and one for the three worlds.

 dim t as Trigger ptr
 dim world as Boolean = (m >= 252 and m <= 254)

 if world then
  if maps(252).triggers.Length() + maps(253).triggers.Length() + maps(254).triggers.Length() >= max_overworld_triggers then
   InfoBox("No room for another trigger.||The game has room for " + str(max_overworld_triggers) + " world triggers in all|and the original ROM uses them all. Delete one first.||Press any key")
   return false
  end if
 elseif total_triggers >= max_triggers then
  InfoBox("No room for another trigger.||The game has room for " + str(max_triggers) + " triggers on the maps in all|and the original ROM uses them all. Delete one first.||Press any key")
  return false
 end if

 t = callocate(SizeOf(Trigger))
 if position > maps(m).triggers.Length() then
  maps(m).triggers.Append(t)
 else
  maps(m).triggers.Insert(position, t)
 end if
 if not world then total_triggers += 1

 return true

end function


sub TriggerRemoveAt(m as Integer, position as Integer)

 maps(m).triggers.Remove(position)
 if m < 252 or m > 254 then total_triggers -= 1

end sub


sub EditTriggers()

 dim select_map as BlueMenu
 dim select_trigger as BlueMenu
 dim edit_trigger as TriggerInfoMenu
 dim t as Trigger ptr
 dim blank as any ptr
 dim done as Boolean
 dim a as UInteger
 dim minimap_img as Any ptr
 dim minimap_canvas as Any ptr
 dim minimap_mode as Boolean = false
 dim minimap_cursor_x as Integer = 0
 dim minimap_cursor_y as Integer = 0
 dim position as Integer

 blank = ImageCreate(640, 480, RGB(0, 0, 0))
 
 minimap_img = ImageCreate(128, 128, RGB(0, 0, 0))
 minimap_canvas = ImageCreate(128, 128, RGB(0, 0, 0))
 
 for i as Integer = 1 to total_maps
  select_map.AddOption(Pad(map_names.ItemAt(i), screen_width - 2, , FF4Text(" ")))
 next
 select_map.max_rows = 8
 
 select_trigger = BlueMenu(0, 10)
 select_trigger.swap_enabled = true
 select_trigger.max_rows = screen_height - select_map.max_rows - 2
 edit_trigger = TriggerInfoMenu(12, 10)
 
do
   
   do
    RefillTriggerList(select_trigger, select_map.selected)
    select_trigger.ChangeSelected(1)
    put (0, 10 * 8), blank, pset
    ShowHint("Pick a map. Enter opens its triggers, Esc goes back.")
    select_trigger.Display()
    UpdateTriggerMinimap(select_map.selected, maps(select_map.selected).triggers, select_trigger.selected, minimap_img, minimap_canvas)
    put (52 * 8, 42 * 8), minimap_img, trans
    if minimap_mode then
     DrawTriggerMinimapCursor(minimap_cursor_x, minimap_cursor_y)
    end if
   loop until select_map.UserInput()
   
   if not select_map.cancelled then
    put (52 * 8, 42 * 8), blank, pset
    minimap_cursor_x = 0
    minimap_cursor_y = 0
    minimap_mode = false
    
    do
    
     done = false
     do
     
      put (12 * 8, 10 * 8), blank, pset
      if select_trigger.selected <= maps(select_map.selected).triggers.Length() then
       t = maps(select_map.selected).triggers.PointerAt(select_trigger.selected)
       edit_trigger.t = t
       edit_trigger.m = select_map.selected
       if select_map.selected > &h100 or select_map.selected = 253 or select_map.selected = 254 then
        edit_trigger.underworld = true
       else
        edit_trigger.underworld = false
       end if
       edit_trigger.Display()
      end if
      select_trigger.Display()
      select_trigger.ShowCursor()
      UpdateTriggerMinimap(select_map.selected, maps(select_map.selected).triggers, select_trigger.selected, minimap_img, minimap_canvas)
      put (52 * 8, 42 * 8), minimap_img, trans
      if minimap_mode then
       DrawTriggerMinimapCursor(minimap_cursor_x, minimap_cursor_y)
      end if
      if minimap_mode then
       ShowHint("Arrows move on the minimap. Enter picks the trigger there. Tab or Esc leave.")
      elseif select_trigger.selected > maps(select_map.selected).triggers.Length() then
       ShowHint("Enter adds a trigger to this map and opens it. Space opens a menu.")
      else
       ShowHint("Enter edits this trigger. Space: add, delete menu. Shift-Enter twice swaps.")
      end if
      a = getkey
      if a = SPACE_KEY then a = ObjectActions("Trigger", "trigger", select_trigger.selected <= maps(select_map.selected).triggers.Length())

      select case a

       case TAB_KEY
        minimap_mode = not minimap_mode
        if minimap_mode then
         ' Find nearest trigger to center cursor on
         if select_trigger.selected <= maps(select_map.selected).triggers.Length() then
          t = maps(select_map.selected).triggers.PointerAt(select_trigger.selected)
          minimap_cursor_x = t->x * 4
          minimap_cursor_y = t->y * 4
         end if
         DrawTriggerMinimapCursor(minimap_cursor_x, minimap_cursor_y)
        else
         UpdateTriggerMinimap(select_map.selected, maps(select_map.selected).triggers, select_trigger.selected, minimap_img, minimap_canvas)
         put (52 * 8, 42 * 8), minimap_img, trans
        end if
       case LEFT_KEY
        if minimap_mode then
         if minimap_cursor_x > 0 then minimap_cursor_x -= 1
         DrawTriggerMinimapCursor(minimap_cursor_x, minimap_cursor_y)
        else
         done = select_trigger.ProcessKey(a)
        end if
       case RIGHT_KEY
        if minimap_mode then
         if minimap_cursor_x < 127 then minimap_cursor_x += 1
         DrawTriggerMinimapCursor(minimap_cursor_x, minimap_cursor_y)
        else
         done = select_trigger.ProcessKey(a)
        end if
       case UP_KEY
        if minimap_mode then
         if minimap_cursor_y > 0 then minimap_cursor_y -= 1
         DrawTriggerMinimapCursor(minimap_cursor_x, minimap_cursor_y)
        else
         done = select_trigger.ProcessKey(a)
        end if
       case DOWN_KEY
        if minimap_mode then
         if minimap_cursor_y < 127 then minimap_cursor_y += 1
         DrawTriggerMinimapCursor(minimap_cursor_x, minimap_cursor_y)
        else
         done = select_trigger.ProcessKey(a)
        end if
       case ENTER_KEY
        if minimap_mode then
         ' Find trigger at cursor position and select it
         dim found_trigger as Integer = FindTriggerAt(minimap_cursor_x, minimap_cursor_y, maps(select_map.selected).triggers)
         if found_trigger > 0 then
          select_trigger.ChangeSelected(found_trigger)
          minimap_mode = false
          UpdateTriggerMinimap(select_map.selected, maps(select_map.selected).triggers, select_trigger.selected, minimap_img, minimap_canvas)
          put (52 * 8, 42 * 8), minimap_img, trans
         end if
        else
         done = select_trigger.ProcessKey(a)
        end if
       case ESC_KEY
        if minimap_mode then
         minimap_mode = false
         UpdateTriggerMinimap(select_map.selected, maps(select_map.selected).triggers, select_trigger.selected, minimap_img, minimap_canvas)
         put (52 * 8, 42 * 8), minimap_img, trans
        else
         done = select_trigger.ProcessKey(a)
        end if
       case DELETE_KEY
        if select_trigger.selected <= maps(select_map.selected).triggers.Length() andalso ConfirmBox("Delete this trigger?") then
         TriggerRemoveAt(select_map.selected, select_trigger.selected)
         RefillTriggerList(select_trigger, select_map.selected)
         if select_trigger.selected > select_trigger.options.Length() then select_trigger.ChangeSelected(select_trigger.options.Length())
         select_trigger.Display()
         UpdateTriggerMinimap(select_map.selected, maps(select_map.selected).triggers, select_trigger.selected, minimap_img, minimap_canvas)
         put (52 * 8, 42 * 8), minimap_img, trans
        end if

       case INSERT_KEY
        position = select_trigger.selected
        if TriggerAddAt(select_map.selected, position) then
         RefillTriggerList(select_trigger, select_map.selected)
         select_trigger.ChangeSelected(position)
         select_trigger.Display()
         UpdateTriggerMinimap(select_map.selected, maps(select_map.selected).triggers, select_trigger.selected, minimap_img, minimap_canvas)
         put (52 * 8, 42 * 8), minimap_img, trans
        end if

       case else
        if not minimap_mode then
         done = select_trigger.ProcessKey(a)
        end if
     
      end select
     
     loop until done
     
     if not select_trigger.cancelled then
      if select_trigger.highlighted = 0 then
       if select_trigger.selected > maps(select_map.selected).triggers.Length() then
        'the Add a trigger line: add one and open it
        position = select_trigger.selected
        if TriggerAddAt(select_map.selected, position) then
         RefillTriggerList(select_trigger, select_map.selected)
         select_trigger.ChangeSelected(position)
         t = maps(select_map.selected).triggers.PointerAt(position)
         edit_trigger.t = t
         edit_trigger.m = select_map.selected
         edit_trigger.underworld = (select_map.selected > &h100 or select_map.selected = 253 or select_map.selected = 254)
         edit_trigger.UserSelect()
        end if
       else
        edit_trigger.UserSelect()
       end if
      else
       if select_trigger.selected <= maps(select_map.selected).triggers.Length() and select_trigger.highlighted <= maps(select_map.selected).triggers.Length() then
        maps(select_map.selected).triggers.Exchange(select_trigger.selected, select_trigger.highlighted)
       end if
       select_trigger.highlighted = 0
      end if
     end if
    
    loop until select_trigger.cancelled   
    
   end if

  loop until select_map.cancelled

 ImageDestroy(minimap_img)
 ImageDestroy(minimap_canvas)
 ShowHint("")

 RecomputeTreasureIndexes()

end sub


sub UpdateTriggerMinimap(map_index as UInteger, tg as List, selected_trigger as UInteger, minimap_img as Any ptr, minimap_canvas as Any ptr)

 dim map_grid as UInteger
 dim tileset_idx as UByte
 dim x as Integer, y as Integer
 dim tile_val as UByte
 dim i as Integer, j as Integer
 dim t_ptr as Trigger ptr
 
 if map_index > &h100 then
  map_grid = maps(map_index).grid_index + &h100 + 1
 else
  map_grid = maps(map_index).grid_index + 1
 end if
 
 if mapgrids(map_grid).no_data then exit sub
 
 tileset_idx = maps(map_index).tileset_index
 
 ' Clear minimap
 for y = 0 to 127
  for x = 0 to 127
   pset minimap_img, (x, y), RGB(0, 0, 0)
  next
 next
 
 ' Draw map tiles at 4x4 pixels per tile (32x32 tiles -> 128x128)
 for y = 0 to 31
  for x = 0 to 31
   tile_val = mapgrids(map_grid).tiles(x, y)
   dim tl as Tile ptr = @tilesets(tileset_idx + 1).tiles(tile_val + 1)
   
   ' Color based on tile properties
   if tl->warp then
    ' Warp tiles - purple
    for j = 0 to 3
     for i = 0 to 3
      pset minimap_img, (x * 4 + i, y * 4 + j), RGB(128, 0, 128)
     next
    next
   elseif tl->encounters then
    ' Encounter tiles - green
    for j = 0 to 3
     for i = 0 to 3
      pset minimap_img, (x * 4 + i, y * 4 + j), RGB(0, 128, 0)
     next
    next
   elseif tl->triggerable then
    ' Trigger tiles - yellow
    for j = 0 to 3
     for i = 0 to 3
      pset minimap_img, (x * 4 + i, y * 4 + j), RGB(128, 128, 0)
     next
    next
   elseif tl->layer_1 or tl->layer_2 then
    ' Walkable layers - light gray
    for j = 0 to 3
     for i = 0 to 3
      pset minimap_img, (x * 4 + i, y * 4 + j), RGB(100, 100, 100)
     next
    next
   else
    ' Default - dark gray
    for j = 0 to 3
     for i = 0 to 3
      pset minimap_img, (x * 4 + i, y * 4 + j), RGB(40, 40, 40)
     next
    next
   end if
  next
 next
 
 ' Draw trigger markers (blue dots) at trigger positions
 for i = 1 to tg.Length()
  t_ptr = tg.PointerAt(i)
  x = t_ptr->x * 4
  y = t_ptr->y * 4
  ' Draw a 3x3 blue square for each trigger
  for j = 0 to 2
   pset minimap_img, (x + j, y), RGB(0, 0, 255)
   pset minimap_img, (x + j, y + 1), RGB(0, 0, 255)
   pset minimap_img, (x + j, y + 2), RGB(0, 0, 255)
  next
 next
 
 ' Draw selected trigger highlight (yellow)
 if tg.Length() > 0 and selected_trigger <= tg.Length() then
  t_ptr = tg.PointerAt(selected_trigger)
  x = t_ptr->x * 4
  y = t_ptr->y * 4
  for j = 0 to 3
   pset minimap_img, (x + j, y), RGB(255, 255, 0)
   pset minimap_img, (x + j, y + 1), RGB(255, 255, 0)
   pset minimap_img, (x + j, y + 2), RGB(255, 255, 0)
   pset minimap_img, (x + j, y + 3), RGB(255, 255, 0)
  next
 end if
 
 ' Add border
 for x = 0 to 127
  pset minimap_img, (x, 0), RGB(100, 100, 100)
  pset minimap_img, (x, 127), RGB(100, 100, 100)
 next
 for y = 0 to 127
  pset minimap_img, (0, y), RGB(100, 100, 100)
  pset minimap_img, (127, y), RGB(100, 100, 100)
 next

end sub


sub DrawTriggerMinimapCursor(cx as Integer, cy as Integer)

 ' Draw a white crosshair cursor on the minimap at screen position (52*8 + cx, 2*8 + cy)
 dim screen_x as Integer = 52 * 8 + cx
 dim screen_y as Integer = 42 * 8 + cy
 
 ' Draw crosshair
 line (screen_x - 4, screen_y)-(screen_x + 4, screen_y), RGB(255, 255, 255)
 line (screen_x, screen_y - 4)-(screen_x, screen_y + 4), RGB(255, 255, 255)
 ' Draw center dot
 pset (screen_x, screen_y), RGB(255, 255, 255)

end sub


function FindTriggerAt(cx as Integer, cy as Integer, tg as List) as Integer

 dim result as Integer = 0
 dim i as Integer
 dim t_ptr as Trigger ptr
 
 ' Convert minimap coordinates (4x scale) back to tile coordinates
 dim tile_x as Integer = cx \ 4
 dim tile_y as Integer = cy \ 4
 
 ' Check each trigger to see if it's at this position
 for i = 1 to tg.Length()
  t_ptr = tg.PointerAt(i)
  if t_ptr->x = tile_x and t_ptr->y = tile_y then
   result = i
   exit for
  end if
 next
 
 return result

end function
