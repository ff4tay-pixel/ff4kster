const ai_header_width = 34 'room for the header line above the AI boxes

type AIMenu

 x as UByte
 y as UByte
 index as UInteger
 lunar as Boolean
 title as String 'header line drawn on the row above the menu (needs y > 0)
 show_bank as Boolean 'also show which AI script bank is in use, and the L key hint
 index_menu as BlueMenu
 condition_menu as BlueMenu
 set_menu as BlueMenu
 script_index as BlueMenu
 script_menu as BlueMenu
 condition_types as BlueMenu
 script_functions as BlueMenu
 condition_set_list as List
 
 declare constructor(starting_x as UByte = 0, starting_y as UByte = 0)
 
 declare function CurrentCondition() as UByte
 declare function ReadKey() as UInteger
 
 declare sub Display()
 declare sub Hide()
 declare sub RefreshConditions()
 declare sub RefreshScripts()
 declare sub SetTo(new_index as UByte, new_lunar as Boolean = false)
 declare sub UserSelect()

end type
