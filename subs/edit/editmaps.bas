sub EditMaps()

 dim select_map as BlueMenu
 dim edit_map as MapEditorMenu
 dim underground as Integer
 dim done as Boolean
 dim key as String
 dim keycode as UInteger
 'dim spaceused as UInteger
 dim m as MapGrid ptr
 dim really as BlueMenu
 dim blank as Any ptr
 dim jump_to as BlueNumberInput
 dim find_map as BlueTextInput
 dim shared_maps as Integer
 dim shared_names as String
 dim found_map as Integer
 dim candidate as Integer
 dim grid as Integer
 dim changed as Boolean
  
 select_map.swap_enabled = true
 select_map.keyboard_visible = false
 select_map.max_rows = 8
 for i as Integer = 1 to total_maps
  select_map.AddOption(Pad(map_names.ItemAt(i), screen_width - 2,, FF4Text(" ")))
 next
 
 edit_map = MapEditorMenu(0, 10)
 jump_to = BlueNumberInput(30, 47)
 jump_to.min_value = 1
 jump_to.max_value = total_maps
 find_map = BlueTextInput(28, 47, 24)
 
 really.x = 18
 really.y = 50
 really.AddOption(FF4Text("Yes"))
 really.AddOption(FF4Text("No"))
  
 do 
 
  do
   if select_map.selected > &h100 then underground = &h100 else underground = 0
   edit_map.SetTo(select_map.selected)
   edit_map.Display()
  shared_maps = 0
  shared_names = ""
  for i as Integer = 1 to total_maps
   if maps(i).grid_index + iif(i > &h100, &h100, 0) = maps(select_map.selected).grid_index + underground then
    shared_maps += 1
    if i <> select_map.selected then
     if len(shared_names) > 0 then shared_names += ", "
      shared_names += "#" + str(i)
    end if
   end if
  next
  BlueBox(0, 49, 22, 1)
  WriteText(FF4Text("Grid: " + Pad(str(maps(select_map.selected).grid_index + underground), 3, true) + "  Shared: " + str(shared_maps)), 1, 50, 15)
  select_map.Display()
   select_map.ShowCursor()
   do
    key = inkey
    if key = "" then sleep 10
    keycode = asc(right(key, 1))
    if len(key) > 1 then keycode = keycode * &h100 + 255
    select case keycode
     case asc("j"), asc("J")
      jump_to.starting_number = select_map.selected
      jump_to.UserSelect()
      if jump_to.number >= 1 and jump_to.number <= total_maps then select_map.ChangeSelected(jump_to.number)
    case asc("f"), asc("F")
     find_map.ChangeStartingText("")
     find_map.UserType()
     if len(find_map.text) > 0 then
      found_map = 0
      for offset as Integer = 1 to total_maps
        candidate = (select_map.selected + offset - 1) mod total_maps + 1
        if instr(lcase(map_names.ItemAt(candidate)), lcase(find_map.text)) > 0 then
         found_map = candidate
        exit for
       end if
      next
      if found_map > 0 then
       select_map.ChangeSelected(found_map)
      else
       BlueBox(28, 49, 24, 1)
       WriteText(FF4Text("No map matched"), 29, 50, 12)
       getkey
      end if
     end if
      case asc("i"), asc("I")
       BlueBox(8, 20, 64, 3)
      WriteText(FF4Text("Grid " + str(maps(select_map.selected).grid_index + underground) + " shared by map indices:"), 9, 21, 15)
       if len(shared_names) > 0 then
        WriteText(FF4Text(left(shared_names, 62)), 9, 22, 15)
       else
        WriteText(FF4Text("No other maps"), 9, 22, 15)
       end if
       WriteText(FF4Text("Press any key to close"), 9, 23, 15)
       getkey
     case 18 'Ctrl-R: back to the map as the ROM had it
      grid = maps(select_map.selected).grid_index + underground + 1
      if not mapgrids(grid).no_data then
       changed = false
       for i as Integer = 0 to 31
        for j as Integer = 0 to 31
         if mapgrids(grid).tiles(i, j) <> orig_map_tiles(grid, i, j) then changed = true
        next
       next
       if not changed then
        InfoBox("This map has no changes.||Press any key")
       elseif ConfirmBox("Revert this map to the loaded ROM? Maps sharing its grid change too.") then
        for i as Integer = 0 to 31
         for j as Integer = 0 to 31
          mapgrids(grid).tiles(i, j) = orig_map_tiles(grid, i, j)
         next
        next
        'the undo of the edits that were just thrown away no longer fits
        if map_histories(grid) <> 0 then
         map_histories(grid)->undo_count = 0
         map_histories(grid)->redo_count = 0
        end if
        if edit_map.history_index = grid then
         edit_map.hist.undo_count = 0
         edit_map.hist.redo_count = 0
        end if
       end if
      end if
     case BACKSPACE_KEY
      if not mapgrids(maps(select_map.selected).grid_index + underground + 1).no_data then
       BlueBox(18, 47, 29, 1)
       WriteText(FF4Text("Really erase this map's data?"), 19, 48, 15)
       really.ChangeSelected(2)
       really.UserSelect()
       if not really.cancelled and really.selected = 1 then
        mapgrids(maps(select_map.selected).grid_index + underground + 1).no_data = true
       end if
       blank = ImageCreate(31 * 8, 3 * 8, RGB(0, 0, 0))
       put (18 * 8, 47 * 8), blank, pset
       ImageDestroy(blank)
      end if
    end select
    edit_map.map_menu.Animate()
    edit_map.palette_menu.Animate()
   loop while key = ""
   done = select_map.ProcessKey(keycode)
  loop until done
  
  if not select_map.cancelled then
  
   if select_map.highlighted > 0 then
   
    swap maps(select_map.selected), maps(select_map.highlighted)
    swap maps(select_map.selected).grid_index, maps(select_map.highlighted).grid_index
    select_map.highlighted = 0
   
   elseif mapgrids(maps(select_map.selected).grid_index + underground + 1).no_data then
   
    BlueBox(18, 47, 23, 1)
    WriteText(FF4Text("Really create map data?"), 19, 48, 15)
    really.ChangeSelected(2)
    really.UserSelect()
    if not really.cancelled and really.selected = 1 then
     mapgrids(maps(select_map.selected).grid_index + underground + 1).no_data = false
    end if
    blank = ImageCreate(25 * 8, 3 * 8, RGB(0, 0, 0))
    put (18 * 8, 47 * 8), blank, pset
    ImageDestroy(blank)
   
   else
    
    edit_map.UserSelect()
    if edit_map.map_menu.Columns() > 0 then
     if select_map.selected >= &h100 then underground = &h100 else underground = 0
     'm = mapgrids.PointerAt(maps(select_map.selected).grid_index + underground + 1)
     for i as Integer = 0 to 31
      for j as Integer = 0 to 31
       mapgrids(maps(select_map.selected).grid_index + underground + 1).tiles(i, j) = val("&h" + edit_map.map_menu.options.ItemAt(i + 1, j + 1))
      next
     next
    end if
    
   end if
  
  end if
  
 loop until select_map.cancelled

end sub
