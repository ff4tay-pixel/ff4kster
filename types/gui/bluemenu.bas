type BlueMenu
 
 x as UInteger = 0
 y as UInteger = 0
 options as List
 colors as List
 cancelled as Boolean = false
 selected as UInteger = 1
 max_rows as UInteger = 0
 top_row as UInteger = 1
 columns as UByte = 1
 indexed_mode as Boolean = false
 swap_enabled as Boolean = false
 highlighted as UInteger = 0
 snapshot as Any ptr
 debug as Boolean = false
 keyboard_visible as Boolean = true
 last_key as UInteger
 marked as Boolean
 title as String 'plain text shown in the top border of the box
 min_width as UByte = 0 'makes the box at least this wide, so boxes can line up
 type_ahead as Boolean = false 'typing letters jumps to the entry that starts with (or contains) them
 typed_text as String
 typed_time as Double

 declare constructor(starting_x as UInteger = 0, starting_y as UInteger = 0)
 
 declare function CursorX(h as Boolean = false) as UByte
 declare function CursorY(h as Boolean = false) as UByte
 declare function HitItem(cell_x as Integer, cell_y as Integer) as Integer
 declare function ItemWidth() as UByte
 declare function MouseCode() as UInteger
 declare function ProcessKey(key_code as UInteger) as Boolean
 declare function UserInput() as Boolean
 declare function WindowHeight() as UByte
 declare function WindowWidth() as UByte
 
 declare sub AddOption(s as String, c as UByte = 15)
 declare sub ChangeOption(index as UInteger, s as String = "", c as Integer = -1)
 declare sub ChangeSelected(index as UInteger)
 declare sub ClearAll()
 declare sub FindNext(new_search as Boolean)
 declare sub GoToIndex()
 declare sub TypeAhead(key_code as UInteger)
 declare sub Display()
 declare sub Hide()
 declare sub Remove(index as UInteger = 0)
 declare sub RestoreSnapshot()
 declare sub ShowCursor()
 declare sub TakeSnapshot()
 declare sub UserSelect()
 
end type

