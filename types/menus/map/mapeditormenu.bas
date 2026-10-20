type MapEditorMenu

 x as UByte
 y as UByte
 palette_menu as GridMenu
 map_menu as GridMenu
 spaceused as UInteger
 map_index as UInteger
 undo_tiles(31, 31, max_map_undo - 1) as UByte
 undo_count as UByte
 redo_tiles(31, 31, max_map_undo - 1) as UByte
 redo_count as UByte
 overlay_visible as Boolean = true
 paste_mode as Boolean
 map_number as UInteger
 copy_tiles(31, 31) as UByte
 copy_width as UByte
 copy_height as UByte
 copy_available as Boolean
 editing as Boolean 'true while the map itself is being edited
 
 declare constructor(starting_x as UByte = 0, starting_y as UByte = 0)
 
 'declare function BytesUsed()
 
 declare sub Display()
 declare sub CopySelection()
 declare sub PasteSelection()
 declare sub BeginPaste()
 declare sub EndPaste()
 declare sub RefreshOverlay()
 declare sub ReplaceTile()
 declare sub SetTo(map_index as UInteger)
 declare sub PushUndo()
 declare sub SaveUndo()
 declare sub Undo()
 declare sub Redo()
 declare sub UserSelect()

end type
