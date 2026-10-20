constructor MonsterGfxMenu(starting_x as UByte = 0, starting_y as UByte = 0)

 dim l as List
 
 x = starting_x
 y = starting_y
 main_menu = BlueMenu(x, y)
 
 gfx_menu = BlueMenu(x + 9, y)
 gfx_menu.max_rows = 1
 l = monstergfxnames.KeyList()
 for i as Integer = 1 to l.Length()
  gfx_menu.AddOption(l.ItemAt(i))
 next
 
 size_menu = BlueMenu(x + 9, y + 1)
 size_menu.max_rows = 1
 for i as Integer = 1 to monstersizenames.Length()
  size_menu.AddOption(monstersizenames.ItemAt(i))
 next
 
 special_size_menu = BlueMenu(x + 9, y)

end constructor


sub MonsterGfxMenu.Display()

 main_menu.Display()

end sub


sub MonsterGfxMenu.SetTo(new_index as UByte)

 index = new_index
 gfx_ptr = monsters(index).gfx_ptr1 + monsters(index).gfx_ptr2 * &h100
 size = monsters(index).size
 pal = monsters(index).pal
 UpdateMenu()

end sub


sub MonsterGfxMenu.UpdateMenu()

 main_menu.ChangeOption(1, FF4Text("Pointer: " + Pad(str(gfx_ptr), 5)), 15)
 main_menu.ChangeOption(2, FF4Text("Size:    ") + monstersizenames.ItemAt(size + 1), 15)
 if size >= &h80 and size <= &hBF then
  'A boss takes its palette from its special size entry; the monster's own palette is not used
  main_menu.ChangeOption(3, FF4Text("Boss pal: " + Pad(str(special_sizes(size - &h80 + 1).palette_index), 3)), 15)
 else
  main_menu.ChangeOption(3, FF4Text("Palette: " + Pad(str(pal), 3)), 15)
 end if

end sub


sub MonsterGfxMenu.UserSelect()

 dim enter_byte as BlueNumberInput
 dim template_menu as BlueMenu
 dim preview as Any ptr 
 dim sprite_snapshot as Any ptr = 0
 dim is_boss as Boolean
 dim old_ptr as UInteger
 dim old_size as UByte
 dim shown_entry as Integer
 dim number_snapshot as Any ptr
 
 enter_byte = BlueNumberInput(main_menu.x + 9)
 
 template_menu = BlueMenu(x + 16, y)
 template_menu.AddOption(FF4Text("Template"))
 template_menu.AddOption(FF4Text("Manual"))

 do
 
  MonsterSpritePanelShow(gfx_ptr, size, pal, sprite_snapshot)
  main_menu.UserSelect()
  
  if not main_menu.cancelled then
  
   select case main_menu.selected
   
    case 1 'Pointer
     template_menu.UserSelect()
     if not template_menu.cancelled then
     
      select case template_menu.selected
       
       case 1
        'The preview follows the highlighted template; Esc puts the old pointer and size back
        old_ptr = gfx_ptr
        old_size = size
        'Start on the template that matches the current pointer and size, if there is one
        for i as Integer = 1 to gfx_menu.options.Length()
         if val(left(monstergfxnames.Lookup(gfx_menu.options.ItemAt(i)), 5)) = gfx_ptr and val(mid(monstergfxnames.Lookup(gfx_menu.options.ItemAt(i)), 7)) = size then
          gfx_menu.ChangeSelected(i)
          exit for
         end if
        next
        shown_entry = gfx_menu.selected
        gfx_menu.cancelled = false
        gfx_menu.TakeSnapshot()
        do
         if gfx_menu.selected <> shown_entry then
          shown_entry = gfx_menu.selected
          gfx_ptr = val(left(monstergfxnames.Lookup(gfx_menu.options.ItemAt(shown_entry)), 5))
          size = val(mid(monstergfxnames.Lookup(gfx_menu.options.ItemAt(shown_entry)), 7))
         end if
         MonsterSpritePanelShow(gfx_ptr, size, pal, sprite_snapshot)
        loop until gfx_menu.UserInput()
        gfx_menu.Hide()
        if gfx_menu.cancelled then
         gfx_ptr = old_ptr
         size = old_size
        end if
       
       case 2
        'The preview follows the number as it is typed
        enter_byte.y = main_menu.y
        enter_byte.max_value = &hFFFF
        enter_byte.starting_number = gfx_ptr
        enter_byte.number = gfx_ptr
        enter_byte.input_started = false
        number_snapshot = ImageCreate(640, 480)
        get (enter_byte.x * 8, enter_byte.y * 8)-((enter_byte.x + len(str(enter_byte.max_value)) + 2) * 8, (enter_byte.y + 1 + 2) * 8 - 1), number_snapshot
        do
         gfx_ptr = enter_byte.number
         MonsterSpritePanelShow(gfx_ptr, size, pal, sprite_snapshot)
        loop until enter_byte.UserInput()
        put (enter_byte.x * 8, enter_byte.y * 8), number_snapshot, pset
        ImageDestroy(number_snapshot)
        enter_byte.max_value = &hFF
        gfx_ptr = enter_byte.number
      
      end select
     
     end if
    
    case 2 'Size
     size_menu.ChangeSelected(size + 1)
     size_menu.UserSelect()
     if not size_menu.cancelled then 
      size = size_menu.selected - 1
      if size >= &h80 and size <= &hBF then
       dim n as BlueNumberInput
       dim ss as UByte
       ss = size - &h80 + 1
       n.x = special_size_menu.x + 15
       special_size_menu.ChangeOption(1, FF4Text("X Position:    " + Pad(str(special_sizes(ss).x), 2)), 15)
       special_size_menu.ChangeOption(2, FF4Text("Mystery Amt:   " + Pad(str(special_sizes(ss).mystery_amount), 2)), 15)
       special_size_menu.ChangeOption(3, FF4Text("Size Table:    " + Pad(str(special_sizes(ss).size_table_pointer), 3)), 15)
       special_size_menu.ChangeOption(4, FF4Text("Mystery Bit 1: " + YesNo(special_sizes(ss).mystery_bit1)), 15)
       special_size_menu.ChangeOption(5, FF4Text("Mystery Bit 2: " + YesNo(special_sizes(ss).mystery_bit2)), 15)
       special_size_menu.ChangeOption(6, FF4Text("Palette:       " + Pad(str(special_sizes(ss).palette_index), 3)), 15)
       special_size_menu.ChangeOption(7, FF4Text("Mystery Byte:  " + Pad(str(special_sizes(ss).mystery_byte), 3)), 15)
       special_size_menu.ChangeOption(8, FF4Text("Arrangement:   " + Pad(str(special_sizes(ss).arrangement_pointer), 3)), 15)
       special_size_menu.TakeSnapshot()
       do
        do until special_size_menu.UserInput()
        loop
        if not special_size_menu.cancelled then
         select case special_size_menu.selected
          case 1 'X Position
           n.y = special_size_menu.y
           n.max_value = 15
           n.starting_number = special_sizes(ss).x
           n.UserSelect()
           special_sizes(ss).x = n.number
          case 2 'Mystery Amount
           n.y = special_size_menu.y + 1
           n.max_value = 15
           n.starting_number = special_sizes(ss).mystery_amount
           n.UserSelect()
           special_sizes(ss).mystery_amount = n.number
          case 3 'Size Table
           n.y = special_size_menu.y + 2
           n.max_value = 255
           n.starting_number = special_sizes(ss).size_table_pointer
           n.UserSelect()
           special_sizes(ss).size_table_pointer = n.number
          case 4 'Mystery Bit 1
           special_sizes(ss).mystery_bit1 = not special_sizes(ss).mystery_bit1
          case 5 'Mystery Bit 2
           special_sizes(ss).mystery_bit2 = not special_sizes(ss).mystery_bit2
          case 6 'Palette
           n.y = special_size_menu.y + 5
           n.max_value = total_monster_palettes - 1
           n.starting_number = special_sizes(ss).palette_index
           n.number = n.starting_number
           preview = ImageCreate(10 * 8, 3 * 8, RGB(0, 0, 0))
           do
            bluebox(0, 0, 8, 1, preview)
            for i as Integer = 0 to 7
             line preview, ((i + 1) * 8, 8)-((i + 2) * 8 - 1, 16 - 1), monster_palettes(n.number + 1, i), bf 
            next
            put ((special_size_menu.x + special_size_menu.options.Width() - 8) * 8, (special_size_menu.y - 3) * 8), preview, pset
           loop until n.UserInput()
           ImageDestroy(preview)
           preview = ImageCreate(10 * 8, 3 * 8, RGB(0, 0, 0))
           put ((special_size_menu.x + special_size_menu.options.Width() - 8) * 8, (special_size_menu.y - 3) * 8), preview, pset
           ImageDestroy(preview)
           special_sizes(ss).palette_index = n.number
          case 7 'Mystery Byte
           n.y = special_size_menu.y + 6
           n.max_value = 255
           n.starting_number = special_sizes(ss).mystery_byte
           n.UserSelect()
           special_sizes(ss).mystery_byte = n.number
          case 8 'Arrangement
           n.y = special_size_menu.y + 7
           n.max_value = 255
           n.starting_number = special_sizes(ss).arrangement_pointer
           n.UserSelect()
           special_sizes(ss).arrangement_pointer = n.number
         end select
         special_size_menu.ChangeOption(1, FF4Text("X Position:    " + Pad(str(special_sizes(ss).x), 2)), 15)
         special_size_menu.ChangeOption(2, FF4Text("Mystery Amt:   " + Pad(str(special_sizes(ss).mystery_amount), 2)), 15)
         special_size_menu.ChangeOption(3, FF4Text("Size Table:    " + Pad(str(special_sizes(ss).size_table_pointer), 3)), 15)
         special_size_menu.ChangeOption(4, FF4Text("Mystery Bit 1: " + YesNo(special_sizes(ss).mystery_bit1)), 15)
         special_size_menu.ChangeOption(5, FF4Text("Mystery Bit 2: " + YesNo(special_sizes(ss).mystery_bit2)), 15)
         special_size_menu.ChangeOption(6, FF4Text("Palette:       " + Pad(str(special_sizes(ss).palette_index), 3)), 15)
         special_size_menu.ChangeOption(7, FF4Text("Mystery Byte:  " + Pad(str(special_sizes(ss).mystery_byte), 3)), 15)
         special_size_menu.ChangeOption(8, FF4Text("Arrangement:   " + Pad(str(special_sizes(ss).arrangement_pointer), 3)), 15)
        end if
       loop until special_size_menu.cancelled
       special_size_menu.Hide()
      end if
     end if
    
    case 3 'Palette
     enter_byte.y = main_menu.y + 2
     enter_byte.max_value = total_monster_palettes - 1
     is_boss = (size >= &h80 and size <= &hBF)
     if is_boss then
      enter_byte.starting_number = special_sizes(size - &h80 + 1).palette_index
     else
      enter_byte.starting_number = pal
     end if
     enter_byte.number = enter_byte.starting_number
     preview = ImageCreate(10 * 8, 3 * 8, RGB(0, 0, 0))
     do
      if is_boss then special_sizes(size - &h80 + 1).palette_index = enter_byte.number
      bluebox(0, 0, 8, 1, preview)
      for i as Integer = 0 to 7
       line preview, ((i + 1) * 8, 8)-((i + 2) * 8 - 1, 16 - 1), monster_palettes(enter_byte.number + 1, i), bf 
      next
      put ((x + main_menu.options.Width() + 2) * 8, (enter_byte.y) * 8), preview, pset
      MonsterSpritePanelShow(gfx_ptr, size, enter_byte.number, sprite_snapshot)
     loop until enter_byte.UserInput()
     ImageDestroy(preview)
     preview = ImageCreate(10 * 8, 3 * 8, RGB(0, 0, 0))
     put ((x + main_menu.options.Width() + 2) * 8, (enter_byte.y) * 8), preview, pset
     ImageDestroy(preview)
     if is_boss then
      special_sizes(size - &h80 + 1).palette_index = enter_byte.number
     else
      pal = enter_byte.number
     end if
   
   end select
   
   UpdateMenu()
   Display()
  
  end if
  
 loop until main_menu.cancelled
 
 MonsterSpritePanelHide(sprite_snapshot)
 
 monsters(index).gfx_ptr1 = gfx_ptr mod &h100
 monsters(index).gfx_ptr2 = gfx_ptr \ &h100
 monsters(index).size = size
 monsters(index).pal = pal

end sub
