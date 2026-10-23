declare sub UpdateMinimap(map_index as UInteger, pg as PlacementGroup, selected_placement as UInteger, minimap_img as Any ptr, minimap_canvas as Any ptr)
declare sub DrawMinimapCursor(cx as Integer, cy as Integer)
declare function FindPlacementAt(cx as Integer, cy as Integer, pg as PlacementGroup) as Integer

sub RefillPlacementList(placement_list as BlueMenu, m as Integer)

 'The list of a map's NPC placements, with the line that adds one at the end

 placement_list.ClearAll()
 for i as Integer = 1 to placement_groups(m).placements.Length()
  placement_list.AddOption(FF4Text("Placement " + Pad(str(i), 2, true)))
 next
 placement_list.AddOption(FF4Text(Pad("-- Add a placement --", 21)))

end sub


function PlacementAdd(m as Integer) as Boolean

 'Adds an empty placement at the end of the map's list. Says so if there is no room: a map has at most 12, and
 ' all maps share a fixed amount of room.

 dim space_after_insert as Integer = PlacementSpace() + 4
 dim p as Placement ptr

 if placement_groups(m).placements.Length() = 0 then space_after_insert += 1

 if placement_groups(m).placements.Length() >= 12 then
  InfoBox("This map already has 12 placements, the most the game allows.||Delete one first.||Press any key")
  return false
 end if
 if space_after_insert >= max_placement_room then
  InfoBox("No room for another placement.||All maps share a fixed amount of room for them|and the original ROM uses it all. Delete one first.||Press any key")
  return false
 end if

 p = callocate(SizeOf(Placement))
 placement_groups(m).placements.Append(p)

 return true

end function


sub EditNPCs()

 dim select_map as BlueMenu
 dim select_placement as BlueMenu
 dim edit_placement as BlueMenu
 dim edit_npc as BlueMenu
 dim speech_menu as EventCallMenu
 dim enter_number as BlueNumberInput
 dim select_npc as BlueMenu
 dim facing_menu as BlueMenu
 dim blank as Any ptr
 dim p as Placement ptr
 dim done as Boolean
 dim a as UInteger
 dim temp as Integer
 dim opened as Boolean
 dim underground as Integer
 dim minimap_img as Any ptr
 dim minimap_canvas as Any ptr

 blank = ImageCreate(640, 480, RGB(0, 0, 0))
 
 select_map.max_rows = 8
 for i as Integer = 1 to total_maps
  select_map.AddOption(Pad(map_names.ItemAt(i), screen_width - 2, , FF4Text(" ")))
 next
 
 select_placement.y = 10
 
 edit_placement.x = 14
 edit_placement.y = select_placement.y
 
 edit_npc.x = edit_placement.x
 edit_npc.y = edit_placement.y + 12
 
 speech_menu = EventCallMenu(edit_placement.x, edit_npc.y + 5)
 
 facing_menu.max_rows = 1
 facing_menu.x = edit_placement.x + 12
 facing_menu.y = edit_placement.y + 8
 for i as Integer = 0 to 3
  facing_menu.AddOption(FF4Text(FacingString(i)))
 next
 
 select_npc.max_rows = 1
 select_npc.x = edit_placement.x + 12
 select_npc.y = edit_placement.y + 9
 for i as Integer = 1 to total_npcs
  select_npc.AddOption(npc_names.ItemAt(i))
 next
 
minimap_img = ImageCreate(128, 128, RGB(0, 0, 0))
 minimap_canvas = ImageCreate(128, 128, RGB(0, 0, 0))
 dim minimap_mode as Boolean = false
 dim minimap_cursor_x as Integer = 0
 dim minimap_cursor_y as Integer = 0
 
 do
   
   do
    RefillPlacementList(select_placement, select_map.selected)
    put (select_placement.x * 8, select_placement.y * 8), blank, pset
    ShowHint("Pick a map. Enter opens its NPC placements, Esc goes back.")
    select_placement.Display()
    UpdateMinimap(select_map.selected, placement_groups(select_map.selected), select_placement.selected, minimap_img, minimap_canvas)
    put (52 * 8, 42 * 8), minimap_img, trans
    if minimap_mode then
     DrawMinimapCursor(minimap_cursor_x, minimap_cursor_y)
    end if
   loop until select_map.UserInput()
   
   if not select_map.cancelled then
    put (52 * 8, 42 * 8), blank, pset

   select_placement.ChangeSelected(1)
   minimap_cursor_x = 0
   minimap_cursor_y = 0
   minimap_mode = false

   do
    
    done = false
    do
     if select_placement.selected <= placement_groups(select_map.selected).placements.Length() then
      if select_map.selected > &h100 then underground = &h100 else underground = 0
      p = placement_groups(select_map.selected).placements.PointerAt(select_placement.selected)
      edit_placement.ChangeOption(1, FF4Text("X:          " + Pad(str(p->x), 3)), 15)
      edit_placement.ChangeOption(2, FF4Text("Y:          " + Pad(str(p->y), 3)), 15)
      edit_placement.ChangeOption(3, FF4Text("Speed:      " + Pad(str(p->speed), 3)), 15)
      edit_placement.ChangeOption(4, FF4Text("Palette:    " + Pad(str(p->palette_index), 3)), 15)
      edit_placement.ChangeOption(5, FF4Text("Walks:      " + YesNo(p->walks)), 15)
      edit_placement.ChangeOption(6, FF4Text("Intangible: " + YesNo(p->intangible)), 15)
      edit_placement.ChangeOption(7, FF4Text("Turns:      " + YesNo(p->turns)), 15)
      edit_placement.ChangeOption(8, FF4Text("Marches:    " + YesNo(p->marches)), 15)
      edit_placement.ChangeOption(9, FF4Text("Facing:     " + Pad(FacingString(p->facing), 5)), 15)
      edit_placement.ChangeOption(10, FF4Text("NPC:        ") + Pad(npc_names.ItemAt(p->npc_index + underground + 1), npc_names.Width()), 15)
      temp = p->npc_index
      if select_map.selected > &h100 then temp += &h100
      edit_npc.ChangeOption(1, FF4Text("Sprite:  ") + Pad(npc_sprite_names.ItemAt(npcs(temp).sprite + 1), npc_sprite_names.Width()), 15)
      edit_npc.ChangeOption(2, FF4Text("Visible: " + YesNo(npcs(temp).visible)), 15)
      edit_npc.ChangeOption(3, FF4Text("Speech"), 15)
      speech_menu.SetTo(@npcs(temp).speech, select_map.selected)
      edit_placement.Display()
      edit_npc.Display()
      put (speech_menu.x * 8, speech_menu.y * 8), blank, pset
      speech_menu.Display()
     end if
     select_placement.Display()
     select_placement.ShowCursor()
     UpdateMinimap(select_map.selected, placement_groups(select_map.selected), select_placement.selected, minimap_img, minimap_canvas)
     put (52 * 8, 42 * 8), minimap_img, trans
     if minimap_mode then
      DrawMinimapCursor(minimap_cursor_x, minimap_cursor_y)
     end if
     if minimap_mode then
      ShowHint("Arrows move the cursor on the minimap. Enter picks the placement there. Tab or Esc leave it.")
     elseif select_placement.selected > placement_groups(select_map.selected).placements.Length() then
      ShowHint("Enter adds a placement to this map and opens it. Space opens a menu.")
     else
      ShowHint("Enter edits this placement. Space opens a menu: add, delete.")
     end if
     a = getkey
     if a = SPACE_KEY then a = ObjectActions("NPC placement", "placement", select_placement.selected <= placement_groups(select_map.selected).placements.Length())
     select case a
      case TAB_KEY
       minimap_mode = not minimap_mode
       if minimap_mode then
        ' Find nearest NPC to center cursor on
        if select_placement.selected <= placement_groups(select_map.selected).placements.Length() then
         p = placement_groups(select_map.selected).placements.PointerAt(select_placement.selected)
         minimap_cursor_x = p->x * 4
         minimap_cursor_y = p->y * 4
        end if
        DrawMinimapCursor(minimap_cursor_x, minimap_cursor_y)
       else
        UpdateMinimap(select_map.selected, placement_groups(select_map.selected), select_placement.selected, minimap_img, minimap_canvas)
        put (52 * 8, 42 * 8), minimap_img, trans
       end if
      case LEFT_KEY
       if minimap_mode then
        if minimap_cursor_x > 0 then minimap_cursor_x -= 1
        DrawMinimapCursor(minimap_cursor_x, minimap_cursor_y)
       else
        done = select_placement.ProcessKey(a)
       end if
      case RIGHT_KEY
       if minimap_mode then
        if minimap_cursor_x < 127 then minimap_cursor_x += 1
        DrawMinimapCursor(minimap_cursor_x, minimap_cursor_y)
       else
        done = select_placement.ProcessKey(a)
       end if
      case UP_KEY
       if minimap_mode then
        if minimap_cursor_y > 0 then minimap_cursor_y -= 1
        DrawMinimapCursor(minimap_cursor_x, minimap_cursor_y)
       else
        done = select_placement.ProcessKey(a)
       end if
      case DOWN_KEY
       if minimap_mode then
        if minimap_cursor_y < 127 then minimap_cursor_y += 1
        DrawMinimapCursor(minimap_cursor_x, minimap_cursor_y)
       else
        done = select_placement.ProcessKey(a)
       end if
      case ENTER_KEY
       if minimap_mode then
        ' Find NPC at cursor position and select it
        dim found_placement as Integer = FindPlacementAt(minimap_cursor_x, minimap_cursor_y, placement_groups(select_map.selected))
        if found_placement > 0 then
         select_placement.ChangeSelected(found_placement)
         minimap_mode = false
         UpdateMinimap(select_map.selected, placement_groups(select_map.selected), select_placement.selected, minimap_img, minimap_canvas)
         put (52 * 8, 42 * 8), minimap_img, trans
        end if
       else
        done = select_placement.ProcessKey(a)
       end if
      case ESC_KEY
       if minimap_mode then
        minimap_mode = false
        UpdateMinimap(select_map.selected, placement_groups(select_map.selected), select_placement.selected, minimap_img, minimap_canvas)
        put (52 * 8, 42 * 8), minimap_img, trans
       else
        done = select_placement.ProcessKey(a)
       end if
      case DELETE_KEY
       if select_placement.selected <= placement_groups(select_map.selected).placements.Length() andalso ConfirmBox("Delete this NPC / placement?") then
        placement_groups(select_map.selected).placements.Remove(select_placement.selected)
        RefillPlacementList(select_placement, select_map.selected)
        if select_placement.selected > select_placement.options.Length() then select_placement.ChangeSelected(select_placement.options.Length())
        put (select_placement.x * 8, select_placement.y * 8), blank, pset
        UpdateMinimap(select_map.selected, placement_groups(select_map.selected), select_placement.selected, minimap_img, minimap_canvas)
        put (52 * 8, 42 * 8), minimap_img, trans
       end if
      case INSERT_KEY
       if PlacementAdd(select_map.selected) then
        RefillPlacementList(select_placement, select_map.selected)
        select_placement.ChangeSelected(placement_groups(select_map.selected).placements.Length())
        UpdateMinimap(select_map.selected, placement_groups(select_map.selected), select_placement.selected, minimap_img, minimap_canvas)
        put (52 * 8, 42 * 8), minimap_img, trans
       end if
      case else
       if not minimap_mode then
        done = select_placement.ProcessKey(a)
       end if
     end select
    loop until done
    
    opened = false
    if not select_placement.cancelled and select_placement.selected > placement_groups(select_map.selected).placements.Length() then
     'the Add a placement line: add one and open it
     opened = true
     if PlacementAdd(select_map.selected) then
      RefillPlacementList(select_placement, select_map.selected)
      select_placement.ChangeSelected(placement_groups(select_map.selected).placements.Length())
      p = placement_groups(select_map.selected).placements.PointerAt(select_placement.selected)
      EditPlacementDialog(select_map.selected, p)
     end if
    end if
    if not select_placement.cancelled and not opened and select_placement.selected <= placement_groups(select_map.selected).placements.Length() then
     
     EditPlacementDialog(select_map.selected, p)
     
    end if
    
   loop until select_placement.cancelled
    
  end if

 loop until select_map.cancelled

 ImageDestroy(minimap_img)
 ImageDestroy(minimap_canvas)
 ShowHint("")

end sub


sub UpdateMinimap(map_index as UInteger, pg as PlacementGroup, selected_placement as UInteger, minimap_img as Any ptr, minimap_canvas as Any ptr)

 dim map_grid as UInteger
 dim tileset_idx as UByte
 dim x as Integer, y as Integer
 dim tile_val as UByte
 dim i as Integer, j as Integer
 dim pg_ptr as Placement ptr
 
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
 ' Simple color coding based on tile properties
 for y = 0 to 31
  for x = 0 to 31
   tile_val = mapgrids(map_grid).tiles(x, y)
   dim t as Tile ptr = @tilesets(tileset_idx + 1).tiles(tile_val + 1)
   
   ' Color based on tile properties
   if t->warp then
    ' Warp tiles - purple
    for j = 0 to 3
     for i = 0 to 3
      pset minimap_img, (x * 4 + i, y * 4 + j), RGB(128, 0, 128)
     next
    next
   elseif t->encounters then
    ' Encounter tiles - green
    for j = 0 to 3
     for i = 0 to 3
      pset minimap_img, (x * 4 + i, y * 4 + j), RGB(0, 128, 0)
     next
    next
   elseif t->triggerable then
    ' Trigger tiles - yellow
    for j = 0 to 3
     for i = 0 to 3
      pset minimap_img, (x * 4 + i, y * 4 + j), RGB(128, 128, 0)
     next
    next
   elseif t->layer_1 or t->layer_2 then
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
 
 ' Draw NPC markers (red dots) at placement positions
 for i = 1 to pg.placements.Length()
  pg_ptr = pg.placements.PointerAt(i)
  x = pg_ptr->x * 4
  y = pg_ptr->y * 4
  ' Draw a 3x3 red square for each NPC
  for j = 0 to 2
   pset minimap_img, (x + j, y), RGB(255, 0, 0)
   pset minimap_img, (x + j, y + 1), RGB(255, 0, 0)
   pset minimap_img, (x + j, y + 2), RGB(255, 0, 0)
  next
 next
 
 ' Draw selected NPC highlight (yellow)
 if pg.placements.Length() > 0 and selected_placement <= pg.placements.Length() then
  pg_ptr = pg.placements.PointerAt(selected_placement)
  x = pg_ptr->x * 4
  y = pg_ptr->y * 4
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


sub DrawMinimapCursor(cx as Integer, cy as Integer)

 ' Draw a white crosshair cursor on the minimap at screen position (52*8 + cx, 2*8 + cy)
 dim screen_x as Integer = 52 * 8 + cx
 dim screen_y as Integer = 42 * 8 + cy
 
 ' Draw crosshair
 line (screen_x - 4, screen_y)-(screen_x + 4, screen_y), RGB(255, 255, 255)
 line (screen_x, screen_y - 4)-(screen_x, screen_y + 4), RGB(255, 255, 255)
 ' Draw center dot
 pset (screen_x, screen_y), RGB(255, 255, 255)

end sub


function FindPlacementAt(cx as Integer, cy as Integer, pg as PlacementGroup) as Integer

 dim result as Integer = 0
 dim i as Integer
 dim pg_ptr as Placement ptr
 dim px as Integer, py as Integer
 
 ' Convert minimap coordinates (4x scale) back to tile coordinates
 dim tile_x as Integer = cx \ 4
 dim tile_y as Integer = cy \ 4
 
 ' Check each placement to see if it's at this position
 for i = 1 to pg.placements.Length()
  pg_ptr = pg.placements.PointerAt(i)
  if pg_ptr->x = tile_x and pg_ptr->y = tile_y then
   result = i
   exit for
  end if
 next
 
 return result

end function
