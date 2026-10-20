constructor MapEditorMenu(starting_x as UByte = 0, starting_y as UByte = 0)

 x = starting_x
 y = starting_y
 palette_menu.x = x
 palette_menu.y = y
 for i as Integer = 0 to 7
  for j as Integer = 0 to 15
   palette_menu.options.Assign(i + 1, j + 1, hex(j \ 2) + hex((j mod 2) * 8 + i))
  next
 next
 map_menu.x = x + 18
 map_menu.y = y 
 map_menu.max_columns = 16
 map_menu.max_rows = 16
 controls_visible = true

end constructor


sub MapEditorMenu.Display()

 dim amount as Integer
 
 keyboard_sidebar_enabled = multikey(SC_H)
 HideKeyboardSidebar()
 
 palette_menu.Display()
 map_menu.Display()
 BlueBox(map_menu.x, map_menu.y + map_menu.max_rows * 2 + 2, 6, 1)
 WriteText(FF4Text(Pad(str(map_menu.cursor_x), 2, true) + ", " + Pad(str(map_menu.cursor_y), 2, true)), map_menu.x + 1, map_menu.y + map_menu.max_rows * 2 + 3)
 BlueBox(palette_menu.x, palette_menu.y + palette_menu.rows * 2 + 2, 16, 1)
 amount = &h17B5F - spaceused - mapgrids(map_index).BytesUsed()
 'amount = 0
 if amount < 0 then
  WriteText(FF4Text("Over:      " + Pad(str(abs(amount)), 5, true)), palette_menu.x + 1, palette_menu.y + palette_menu.rows * 2 + 3, 12)
 else
  WriteText(FF4Text("Room:      " + Pad(str(amount), 5, true)), palette_menu.x + 1, palette_menu.y + palette_menu.rows * 2 + 3, 15)
 end if

 BlueBox(0, 52, 53, 2)
 WriteText(FF4Text(Pad("Panel: " + iif(map_menu.active, "Map", "Palette") + "  Tile:" + palette_menu.options.ItemAt(palette_menu.cursor_x + 1, palette_menu.cursor_y + 1) + "  Size:" + str(abs(map_menu.cursor_w) + 1) + "x" + str(abs(map_menu.cursor_h) + 1) + "  Overlay:" + iif(overlay_visible, "On", "Off"), 51)), 1, 53, 15)
 if paste_mode then
  WriteText(FF4Text(Pad("PASTE: arrows move, Enter place, Esc cancel", 51)), 1, 54, 14)
 else
  WriteText(FF4Text(Pad("H toggles the keyboard sidebar", 51)), 1, 54, 15)
 end if

 if controls_visible and keyboard_sidebar_enabled then
  DisplayKeyboardSidebar()
 else
  HideKeyboardSidebar()
 end if

end sub


sub MapEditorMenu.DisplayKeyboardSidebar()

 if sidebar_snapshot = 0 then
  sidebar_snapshot = ImageCreate(26 * 8, 19 * 8, RGB(0, 0, 0))
  get (54 * 8, 38 * 8)-(80 * 8 - 1, 57 * 8 - 1), sidebar_snapshot
 end if
 BlueBox(54, 38, 25, 18)
 WriteText(FF4Text("KEYBOARD"), 55, 39, 15)
 WriteText(FF4Text("J  Jump to map"), 55, 40, 15)
 WriteText(FF4Text("F  Find map name"), 55, 41, 15)
 WriteText(FF4Text("I  Grid details"), 55, 42, 15)
 WriteText(FF4Text("ENTER  Edit map"), 55, 43, 15)
 WriteText(FF4Text("BACKSP  Erase map"), 55, 44, 15)
 WriteText(FF4Text("ESC  Back"), 55, 45, 15)
 WriteText(FF4Text("HOLD H  Show"), 55, 46, 15)
 WriteText(FF4Text("TAB  Map/palette"), 55, 47, 15)
 WriteText(FF4Text("CTRL+C  Copy"), 55, 48, 15)
 WriteText(FF4Text("CTRL+V  Paste preview"), 55, 49, 15)
 WriteText(FF4Text("CTRL+Z  Undo"), 55, 50, 15)
 WriteText(FF4Text("CTRL+Y  Redo"), 55, 51, 15)
 WriteText(FF4Text("R  Replace all tile"), 55, 52, 15)
 WriteText(FF4Text("O  NPC/trigger overlay"), 55, 53, 15)

end sub


sub MapEditorMenu.HideKeyboardSidebar()

 if sidebar_snapshot <> 0 then
  put (54 * 8, 38 * 8), sidebar_snapshot, pset
  ImageDestroy(sidebar_snapshot)
  sidebar_snapshot = 0
 end if

end sub


sub MapEditorMenu.CopySelection()

 dim start_x as Integer
 dim start_y as Integer

 if map_menu.cursor_w < 0 then start_x = map_menu.cursor_x + map_menu.cursor_w else start_x = map_menu.cursor_x
 if map_menu.cursor_h < 0 then start_y = map_menu.cursor_y + map_menu.cursor_h else start_y = map_menu.cursor_y
 copy_width = abs(map_menu.cursor_w) + 1
 copy_height = abs(map_menu.cursor_h) + 1

 for i as Integer = 0 to copy_width - 1
  for j as Integer = 0 to copy_height - 1
   copy_tiles(i, j) = val("&h" + map_menu.options.ItemAt(start_x + i + 1, start_y + j + 1))
  next
 next
 copy_available = true

end sub


sub MapEditorMenu.PasteSelection()

 if copy_available then
  SaveUndo()
  for i as Integer = 0 to copy_width - 1
   for j as Integer = 0 to copy_height - 1
    if map_menu.cursor_x + i < map_menu.Columns() and map_menu.cursor_y + j < map_menu.Rows() then
     map_menu.options.Assign(map_menu.cursor_x + i + 1, map_menu.cursor_y + j + 1, hex(copy_tiles(i, j), 2))
    end if
   next
  next
  map_menu.cursor_w = 0
  map_menu.cursor_h = 0
 end if

end sub


sub MapEditorMenu.BeginPaste()

 if copy_available and map_menu.Columns() > 0 then
  if map_menu.ghost <> 0 then ImageDestroy(map_menu.ghost)
  map_menu.ghost = ImageCreate(copy_width * 16, copy_height * 16, RGB(0, 0, 0))
  for i as Integer = 0 to copy_width - 1
   for j as Integer = 0 to copy_height - 1
    tilesets(map_menu.tileset_index + 1).tiles(copy_tiles(i, j) + 1).Display(i * 2, j * 2, map_menu.ghost, 0)
   next
  next
  map_menu.cursor_w = 0
  map_menu.cursor_h = 0
  paste_mode = true
 end if

end sub


sub MapEditorMenu.EndPaste()

 if map_menu.ghost <> 0 then
  ImageDestroy(map_menu.ghost)
  map_menu.ghost = 0
 end if
 paste_mode = false

end sub


sub MapEditorMenu.RefreshOverlay()

 dim t as Trigger ptr
 dim p as Placement ptr

 map_menu.marker_count = 0
 if overlay_visible and map_number >= 1 and map_number <= total_maps then
  for i as Integer = 1 to maps(map_number).triggers.Length()
   t = maps(map_number).triggers.PointerAt(i)
   if t->x < 32 and t->y < 32 and map_menu.marker_count < 256 then
    map_menu.marker_x(map_menu.marker_count) = t->x
    map_menu.marker_y(map_menu.marker_count) = t->y
    map_menu.marker_color(map_menu.marker_count) = RGB(255, 255, 0)
    map_menu.marker_count += 1
   end if
  next
  for i as Integer = 1 to placement_groups(map_number).placements.Length()
   p = placement_groups(map_number).placements.PointerAt(i)
   if p->x < 32 and p->y < 32 and map_menu.marker_count < 256 then
    map_menu.marker_x(map_menu.marker_count) = p->x
    map_menu.marker_y(map_menu.marker_count) = p->y
    map_menu.marker_color(map_menu.marker_count) = RGB(0, 255, 255)
    map_menu.marker_count += 1
   end if
  next
 end if

end sub


sub MapEditorMenu.ReplaceTile()

 'Replaces every tile matching the one under the cursor with the palette tile,
 'within the selection, or across the whole map if only one tile is selected
 dim old_tile as String
 dim new_tile as String
 dim start_x as Integer
 dim start_y as Integer
 dim end_x as Integer
 dim end_y as Integer

 old_tile = map_menu.options.ItemAt(map_menu.cursor_x + 1, map_menu.cursor_y + 1)
 new_tile = palette_menu.options.ItemAt(palette_menu.cursor_x + 1, palette_menu.cursor_y + 1)
 if old_tile <> new_tile then
  if map_menu.cursor_w = 0 and map_menu.cursor_h = 0 then
   start_x = 0
   start_y = 0
   end_x = map_menu.Columns() - 1
   end_y = map_menu.Rows() - 1
  else
   if map_menu.cursor_w < 0 then start_x = map_menu.cursor_x + map_menu.cursor_w else start_x = map_menu.cursor_x
   if map_menu.cursor_h < 0 then start_y = map_menu.cursor_y + map_menu.cursor_h else start_y = map_menu.cursor_y
   end_x = start_x + abs(map_menu.cursor_w)
   end_y = start_y + abs(map_menu.cursor_h)
  end if
  SaveUndo()
  for i as Integer = start_x to end_x
   for j as Integer = start_y to end_y
    if map_menu.options.ItemAt(i + 1, j + 1) = old_tile then map_menu.options.Assign(i + 1, j + 1, new_tile)
   next
  next
 end if

end sub


sub MapEditorMenu.SetTo(index as UInteger)

 dim underground as Integer
 dim temp as Integer
 dim debug as String
 
 if index > &h100 then underground = &h100 else underground = 0
 map_menu.options.Destroy()
 map_index = maps(index).grid_index + underground + 1
 map_number = index
 undo_count = 0
 redo_count = 0
 EndPaste()
 
 'if index < 252 or index > 256 then
  'open "debug.txt" for output as #1
  spaceused = 0
  for i as Integer = 1 to total_maps
   if i <> maps(index).grid_index + underground + 1 then ' and not mapgrids(maps(i).grid_index + underground + 1).no_data then
    'debug = mapgrids(maps(i).grid_index + underground + 1).RunLengthEncoding()
    temp = mapgrids(i).BytesUsed()
    spaceused += temp
    'print #1, Pad(str(i), 3, true); ": "; Pad(str(temp), 3, true); " = "; Pad(str(spaceused), 6, true); " - ";
    'for j as Integer = 1 to temp
     'print #1, hex(asc(mid(debug, j, 1)), 2); " ";
    'next
    'print #1, ""
   end if
  next
  'close #1
  'print "OK"
  'getkey
  'end
   
  map_menu.tileset_index = maps(index).tileset_index
  map_menu.current_palette = maps(index).map_palette
  palette_menu.tileset_index = map_menu.tileset_index
  palette_menu.current_palette = map_menu.current_palette
  tilesets(map_menu.tileset_index + 1).SetGraphics(map_menu.current_palette)

  for i as Integer = 0 to 31
   for j as Integer = 0 to 31
    if not mapgrids(maps(index).grid_index + underground + 1).no_data then 
     map_menu.options.Assign(j + 1, i + 1, hex(mapgrids(maps(index).grid_index + underground + 1).tiles(j, i), 2))
    end if
   next
  next
  
  map_menu.SetBackgroundMap(maps(index).background + underground + 1)
  RefreshOverlay()

 'end if

end sub


sub MapEditorMenu.SaveUndo()

 PushUndo()
 redo_count = 0

end sub


sub MapEditorMenu.PushUndo()

 for history as Integer = max_map_undo - 1 to 1 step -1
  for i as Integer = 0 to 31
   for j as Integer = 0 to 31
    undo_tiles(i, j, history) = undo_tiles(i, j, history - 1)
   next
  next
 next
 for i as Integer = 0 to 31
  for j as Integer = 0 to 31
   undo_tiles(i, j, 0) = val("&h" + map_menu.options.ItemAt(i + 1, j + 1))
  next
 next
 if undo_count < max_map_undo then undo_count += 1

end sub


sub MapEditorMenu.Redo()

 if redo_count > 0 then
  PushUndo()
  for i as Integer = 0 to 31
   for j as Integer = 0 to 31
    map_menu.options.Assign(i + 1, j + 1, hex(redo_tiles(i, j, 0), 2))
   next
  next
  for history as Integer = 0 to max_map_undo - 2
   for i as Integer = 0 to 31
    for j as Integer = 0 to 31
     redo_tiles(i, j, history) = redo_tiles(i, j, history + 1)
    next
   next
  next
  redo_count -= 1
 end if

end sub


sub MapEditorMenu.Undo()

 if undo_count > 0 then
  'Remember the current state so it can be redone
  for history as Integer = max_map_undo - 1 to 1 step -1
   for i as Integer = 0 to 31
    for j as Integer = 0 to 31
     redo_tiles(i, j, history) = redo_tiles(i, j, history - 1)
    next
   next
  next
  for i as Integer = 0 to 31
   for j as Integer = 0 to 31
    redo_tiles(i, j, 0) = val("&h" + map_menu.options.ItemAt(i + 1, j + 1))
   next
  next
  if redo_count < max_map_undo then redo_count += 1
  for i as Integer = 0 to 31
   for j as Integer = 0 to 31
    map_menu.options.Assign(i + 1, j + 1, hex(undo_tiles(i, j, 0), 2))
   next
  next
  for history as Integer = 0 to max_map_undo - 2
   for i as Integer = 0 to 31
    for j as Integer = 0 to 31
     undo_tiles(i, j, history) = undo_tiles(i, j, history + 1)
    next
   next
  next
  undo_count -= 1
 end if

end sub


sub MapEditorMenu.UserSelect()

 dim key as String
 dim keycode as UInteger
 dim done as Boolean
 dim active_menu as GridMenu ptr
 dim sidebar_state as Boolean
 
 if map_menu.Columns() > 0 then

  controls_visible = true

  palette_menu.active = false
  map_menu.active = true
  active_menu = @map_menu
  
  do
   
   Display()
   sidebar_state = keyboard_sidebar_enabled
   do
    if multikey(SC_H) <> sidebar_state then
     Display()
     sidebar_state = keyboard_sidebar_enabled
    end if
    key = inkey
    if key = "" then sleep 10
    keycode = asc(right(key, 1))
    if len(key) > 1 then keycode = keycode * &h100 + 255
    map_menu.Animate()
    palette_menu.Animate()
   loop while key = ""
  controls_visible = false
  HideKeyboardSidebar()
  if paste_mode then
   select case keycode
    case ENTER_KEY
     PasteSelection()
     EndPaste()
    case ESC_KEY
     EndPaste()
    case UP_KEY, DOWN_KEY, LEFT_KEY, RIGHT_KEY, HOME_KEY, END_KEY, PAGEUP_KEY, PAGEDOWN_KEY
     map_menu.ProcessKey(keycode)
   end select
  else
  select case keycode
    case asc("r"), asc("R")
     if active_menu = @map_menu then ReplaceTile()
    case asc("o"), asc("O")
     overlay_visible = not overlay_visible
     RefreshOverlay()
    case 25
     if active_menu = @map_menu then Redo()
    case TAB_KEY
     if active_menu = @map_menu then
      active_menu = @palette_menu
      palette_menu.active = true
      map_menu.active = false
     else
      active_menu = @map_menu
      palette_menu.active = false
      map_menu.active = true
     end if
    case ENTER_KEY
     if active_menu = @map_menu then
      SaveUndo()
      for i as Integer = 0 to map_menu.cursor_w step sgn(map_menu.cursor_w)
       for j as Integer = 0 to map_menu.cursor_h step sgn(map_menu.cursor_h)
        map_menu.options.Assign(map_menu.cursor_x + i + 1, map_menu.cursor_y + j + 1, palette_menu.options.ItemAt(palette_menu.cursor_x + 1, palette_menu.cursor_y + 1))
        if map_menu.cursor_h = 0 then exit for
       next
       if map_menu.cursor_w = 0 then exit for
      next
     end if
    case BACKSPACE_KEY
     if active_menu = @map_menu then
      palette_menu.cursor_x = val("&h" + right(map_menu.options.ItemAt(map_menu.cursor_x + 1, map_menu.cursor_y + 1), 1)) mod 8
      palette_menu.cursor_y = val("&h" + left(map_menu.options.ItemAt(map_menu.cursor_x + 1, map_menu.cursor_y + 1), 1)) * 2 + val("&h" + right(map_menu.options.ItemAt(map_menu.cursor_x + 1, map_menu.cursor_y + 1), 1)) \ 8
     end if
    case SPACE_KEY
     if active_menu = @map_menu then
      SaveUndo()
      map_menu.FloodFill(map_menu.cursor_x + 1, map_menu.cursor_y + 1, palette_menu.options.ItemAt(palette_menu.cursor_x + 1, palette_menu.cursor_y + 1))
     end if
    case 3
     if active_menu = @map_menu then CopySelection()
    case 22
     if active_menu = @map_menu then BeginPaste()
    case 26
     if active_menu = @map_menu then Undo()
    case DOWN_KEY
     if active_menu = @map_menu then
      if multikey(SC_LSHIFT) or multikey(SC_RSHIFT) then
       if abs(map_menu.cursor_h) < map_menu.max_rows - 1 then
        if map_menu.cursor_y < map_menu.Rows() - 1 then map_menu.cursor_h -= 1
        map_menu.ProcessKey(keycode)
       end if
      else
       map_menu.cursor_w = 0
       map_menu.cursor_h = 0
       map_menu.ProcessKey(keycode)
      end if
     else
      active_menu->ProcessKey(keycode)
     end if
    case RIGHT_KEY
     if active_menu = @map_menu then
      if multikey(SC_LSHIFT) or multikey(SC_RSHIFT) then
       if abs(map_menu.cursor_w) < map_menu.max_columns - 1 then
        if map_menu.cursor_x < map_menu.Columns() - 1 then map_menu.cursor_w -= 1
        map_menu.ProcessKey(keycode)
       end if
      else
       map_menu.cursor_w = 0
       map_menu.cursor_h = 0
       map_menu.ProcessKey(keycode)
      end if
     else
      active_menu->ProcessKey(keycode)
     end if
    case UP_KEY
     if active_menu = @map_menu then
      if multikey(SC_LSHIFT) or multikey(SC_RSHIFT) then
       if abs(map_menu.cursor_h) < map_menu.max_rows - 1 then
        if map_menu.cursor_y > 0 then map_menu.cursor_h += 1
        map_menu.ProcessKey(keycode)
       end if
      else
       map_menu.cursor_w = 0
       map_menu.cursor_h = 0
       map_menu.ProcessKey(keycode)
      end if
     else
      active_menu->ProcessKey(keycode)
     end if
    case LEFT_KEY
     if active_menu = @map_menu then
      if multikey(SC_LSHIFT) or multikey(SC_RSHIFT) then
       if abs(map_menu.cursor_w) < map_menu.max_columns - 1 then
        if map_menu.cursor_x > 0 then map_menu.cursor_w += 1
        map_menu.ProcessKey(keycode)
       end if
      else
       map_menu.cursor_w = 0
       map_menu.cursor_h = 0
       map_menu.ProcessKey(keycode)
      end if     
     else
      active_menu->ProcessKey(keycode)
     end if
    case else
     done = active_menu->ProcessKey(keycode)
   end select
  end if

  loop until done
  
  active_menu->active = false
  
 end if

end sub
