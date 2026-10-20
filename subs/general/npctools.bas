'NPC placements: the editing dialog (shared by Edit NPCs and the map editor) and the helpers the map
'editor uses to edit the placements under its cursor. N edits the NPC on the tile (or offers to add one),
'Shift-Insert adds one and Shift-Delete removes one; when several share a tile a short list asks which.
'The limits are those of Edit NPCs: at most 12 placements per map and the shared room for placements.


function PlacementUnderground(map_index as Integer) as Integer

 if map_index > &h100 then return &h100

 return 0

end function


sub RefreshPlacementMenus(map_index as Integer, p as Placement ptr, edit_placement as BlueMenu, edit_npc as BlueMenu, speech_menu as EventCallMenu)

 dim temp as Integer
 dim underground as Integer = PlacementUnderground(map_index)

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
 temp = p->npc_index + underground
 edit_npc.ChangeOption(1, FF4Text("Sprite:  ") + Pad(npc_sprite_names.ItemAt(npcs(temp).sprite + 1), npc_sprite_names.Width()), 15)
 edit_npc.ChangeOption(2, FF4Text("Visible: " + YesNo(npcs(temp).visible)), 15)
 edit_npc.ChangeOption(3, FF4Text("Speech"), 15)
 speech_menu.SetTo(@npcs(temp).speech, map_index)

end sub


sub EditPlacementDialog(map_index as Integer, p as Placement ptr)

 'The menus for one placement (where it stands, how it moves, which NPC it is) and, below them, the NPC
 ' itself (sprite, visibility, speech). Edit NPCs shows them beside its list; the map editor shows them on
 ' a screen of their own.

 dim edit_placement as BlueMenu
 dim edit_npc as BlueMenu
 dim speech_menu as EventCallMenu
 dim enter_number as BlueNumberInput
 dim select_npc as BlueMenu
 dim facing_menu as BlueMenu
 dim blank as Any ptr = ImageCreate(640, 480, RGB(0, 0, 0))
 dim temp as Integer
 dim underground as Integer = PlacementUnderground(map_index)

 edit_placement.x = 14
 edit_placement.y = 10
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

 RefreshPlacementMenus(map_index, p, edit_placement, edit_npc, speech_menu)
 edit_placement.Display()
 edit_npc.Display()
 speech_menu.Display()

 do

  edit_placement.UserSelect()

  if not edit_placement.cancelled then

   select case edit_placement.selected

    case 1 'X
     enter_number.x = edit_placement.x + 12
     enter_number.y = edit_placement.y
     enter_number.max_value = &hFF
     enter_number.starting_number = p->x
     enter_number.UserSelect()
     p->x = enter_number.number

    case 2 'Y
     enter_number.x = edit_placement.x + 12
     enter_number.y = edit_placement.y + 1
     enter_number.max_value = &hFF
     enter_number.starting_number = p->y
     enter_number.UserSelect()
     p->y = enter_number.number

    case 3 'Speed
     enter_number.x = edit_placement.x + 12
     enter_number.y = edit_placement.y + 2
     enter_number.max_value = 3
     enter_number.starting_number = p->speed
     enter_number.UserSelect()
     p->speed = enter_number.number

    case 4 'Palette
     enter_number.x = edit_placement.x + 12
     enter_number.y = edit_placement.y + 3
     enter_number.max_value = &hFF
     enter_number.starting_number = p->palette_index
     enter_number.UserSelect()
     p->palette_index = enter_number.number

    case 5: p->walks = not p->walks
    case 6: p->intangible = not p->intangible
    case 7: p->turns = not p->turns
    case 8: p->marches = not p->marches

    case 9 'Facing
     facing_menu.ChangeSelected(p->facing + 1)
     facing_menu.UserSelect()
     if not facing_menu.cancelled then p->facing = facing_menu.selected - 1

    case 10 'NPC
     if p->underground then temp = &h100 else temp = 0
     select_npc.ChangeSelected(p->npc_index + temp + 1)
     do
      temp = select_npc.selected - 1
      edit_npc.ChangeOption(1, FF4Text("Sprite:  ") + Pad(npc_sprite_names.ItemAt(npcs(temp).sprite + 1), npc_sprite_names.Width()), 15)
      edit_npc.ChangeOption(2, FF4Text("Visible: " + YesNo(npcs(temp).visible)), 15)
      edit_npc.ChangeOption(3, FF4Text("Speech"), 15)
      speech_menu.SetTo(@npcs(temp).speech, map_index)
      edit_npc.Display()
      put (speech_menu.x * 8, speech_menu.y * 8), blank, pset
      speech_menu.Display()
     loop until select_npc.UserInput()
     p->npc_index = (select_npc.selected - 1) mod &h100
     p->underground = (map_index > &h100)
     RefreshPlacementMenus(map_index, p, edit_placement, edit_npc, speech_menu)
     edit_placement.Display()
     do
      edit_npc.UserSelect()
      if not edit_npc.cancelled then
       temp = p->npc_index
       if p->underground then temp += &h100
       select case edit_npc.selected
        case 1 'Sprite
         npcs(temp).sprite = ListItem(edit_npc.x + 9, edit_npc.y, npc_sprite_names, npcs(temp).sprite + 1) - 1
         edit_npc.ChangeOption(1, FF4Text("Sprite:  ") + Pad(npc_sprite_names.ItemAt(npcs(temp).sprite + 1), npc_sprite_names.Width()), 15)
         edit_npc.Display()
        case 2 'Visible
         npcs(temp).visible = not npcs(temp).visible
         edit_npc.ChangeOption(2, FF4Text("Visible: " + YesNo(npcs(temp).visible)), 15)
         edit_npc.Display()
        case 3 'Speech
         speech_menu.UserSelect()
         speech_menu.Display()
       end select
      end if
     loop until edit_npc.cancelled

   end select

   RefreshPlacementMenus(map_index, p, edit_placement, edit_npc, speech_menu)
   edit_placement.Display()
   edit_npc.Display()
   put (speech_menu.x * 8, speech_menu.y * 8), blank, pset
   speech_menu.Display()

  end if

 loop until edit_placement.cancelled

 ImageDestroy(blank)
 'a draw on the screen itself, so the destroyed image is not left as the drawing target
 pset (0, 0), point(0, 0)

end sub


function PlacementsAt(m as Integer, tile_x as Integer, tile_y as Integer, found() as Integer) as Integer

 'How many placements stand on a tile; found(1 to n) get their numbers (at most 63)

 dim count as Integer
 dim p as Placement ptr

 for i as Integer = 1 to placement_groups(m).placements.Length()
  p = placement_groups(m).placements.PointerAt(i)
  if p->x = tile_x and p->y = tile_y and count < 63 then
   count += 1
   found(count) = i
  end if
 next

 return count

end function


function PlacementSummary(m as Integer, p as Placement ptr) as String

 return PlainName(FF4Name(npc_names.ItemAt(p->npc_index + PlacementUnderground(m) + 1)))

end function


function PlacementStatusText(m as Integer, tile_x as Integer, tile_y as Integer) as String

 'For the status line: "NPC 2: name" (and how many more are on the tile), or ""

 dim found(63) as Integer
 dim n as Integer = PlacementsAt(m, tile_x, tile_y, found())
 dim result as String

 if n = 0 then return ""
 result = "NPC " + str(found(1)) + ": " + PlacementSummary(m, placement_groups(m).placements.PointerAt(found(1)))
 if n > 1 then result += "  and " + str(n - 1) + " more here"

 return result

end function


function PickPlacementAt(m as Integer, tile_x as Integer, tile_y as Integer) as Integer

 'The number of the placement to work on: the only one on the tile, or the one chosen from a list.
 ' 0 if there is none, -1 if the list was cancelled.

 dim found(63) as Integer
 dim n as Integer = PlacementsAt(m, tile_x, tile_y, found())
 dim choose as BlueMenu

 if n = 0 then return 0
 if n = 1 then return found(1)

 choose.x = 4
 choose.y = 20
 choose.title = "Which NPC?"
 for k as Integer = 1 to n
  choose.AddOption(FF4Text(left("NPC " + str(found(k)) + ": " + PlacementSummary(m, placement_groups(m).placements.PointerAt(found(k))), 70)))
 next
 choose.UserSelect()
 if choose.cancelled then return -1

 return found(choose.selected)

end function


sub EditPlacementScreen(m as Integer, index as Integer)

 'The NPC editing screen for one placement. The screen as it was is put back afterwards.

 dim backdrop as Any ptr = ImageCreate(640, 480)

 get (0, 0)-(639, 479), backdrop
 cls
 WriteText(FF4Text("NPC " + str(index) + " of " + FF4Name(map_names.ItemAt(m))), 14, 6, 14)
 EditPlacementDialog(m, placement_groups(m).placements.PointerAt(index))
 put (0, 0), backdrop, pset
 ImageDestroy(backdrop)
 pset (0, 0), point(0, 0)

end sub


function AddPlacementAt(m as Integer, tile_x as Integer, tile_y as Integer) as Integer

 'A new placement on the tile. Returns its number, or 0 if there is no room.

 dim p as Placement ptr
 dim space_after_insert as Integer = PlacementSpace() + 4

 if placement_groups(m).placements.Length() = 0 then space_after_insert += 1
 if placement_groups(m).placements.Length() >= 12 then
  InfoBox("A map can have at most 12 NPC placements.||Press any key", 20, 20)
  return 0
 end if
 if space_after_insert >= max_placement_room then
  InfoBox("There is no room for more NPC placements.|Delete one on any map first.||Press any key", 20, 20)
  return 0
 end if

 p = callocate(SizeOf(Placement))
 p->x = tile_x
 p->y = tile_y
 p->underground = (m > &h100)
 placement_groups(m).placements.Append(p)

 return placement_groups(m).placements.Length()

end function


function PlacementKeyAt(m as Integer, tile_x as Integer, tile_y as Integer, action as Integer) as Boolean

 'action 1 = N (edit, or add if there is none), 2 = Shift-Insert (add), 3 = Shift-Delete. Returns true if
 ' the placements may have changed (so the screen should redraw its markers).

 dim index as Integer
 dim found(63) as Integer

 select case action

  case 1
   index = PickPlacementAt(m, tile_x, tile_y)
   if index > 0 then
    EditPlacementScreen(m, index)
    return true
   elseif index = 0 then
    if ConfirmBox("No NPC here. Add one?") then
     index = AddPlacementAt(m, tile_x, tile_y)
     if index > 0 then EditPlacementScreen(m, index)
     return true
    end if
   end if

  case 2
   if PlacementsAt(m, tile_x, tile_y, found()) > 0 then
    if not ConfirmBox("There is already an NPC here. Add another?") then return false
   end if
   index = AddPlacementAt(m, tile_x, tile_y)
   if index > 0 then EditPlacementScreen(m, index)
   return true

  case 3
   index = PickPlacementAt(m, tile_x, tile_y)
   if index > 0 then
    if ConfirmBox("Delete this NPC / placement?") then
     placement_groups(m).placements.Remove(index)
     return true
    end if
   end if

 end select

 return false

end function
