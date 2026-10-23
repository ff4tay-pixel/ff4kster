type MapHistory

 'What Ctrl-Z and Ctrl-Y go back to in the map editor, one per map grid so that it survives leaving the map

 undo_tiles(31, 31, max_map_undo - 1) as UByte
 undo_count as UByte
 redo_tiles(31, 31, max_map_undo - 1) as UByte
 redo_count as UByte

end type


type MapEditorMenu

 x as UByte
 y as UByte
 palette_menu as GridMenu
 map_menu as GridMenu
 spaceused as UInteger
 map_index as UInteger
 hist as MapHistory 'undo and redo of the map being edited; kept in map_histories when another map is opened
 history_index as UInteger 'the map grid that hist belongs to (0 = none yet)
 overlay_visible as Boolean = true
 paste_mode as Boolean
 map_number as UInteger
 copy_tiles(31, 31) as UByte
 copy_width as UByte
 copy_height as UByte
 copy_available as Boolean
 editing as Boolean 'true while the map itself is being edited
 drag_paint as Boolean 'the mouse is painting by dragging (one undo step per stroke)
 dragging as Boolean
 
 declare constructor(starting_x as UByte = 0, starting_y as UByte = 0)
 
 'declare function BytesUsed()
 
 declare function MouseCode(byref active_menu as GridMenu ptr) as UInteger

 declare sub Display()
 declare sub CopySelection()
 declare sub PasteSelection()
 declare sub BeginPaste()
 declare sub EndPaste()
 declare sub RefreshOverlay()
 declare sub ReplaceTile()
 declare sub SetTo(map_index as UInteger)
 declare sub StashHistory()
 declare sub RevertToLoaded()
 declare sub PushUndo()
 declare sub SaveUndo()
 declare sub Undo()
 declare sub Redo()
 declare sub UserSelect()

end type
