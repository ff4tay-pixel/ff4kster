constructor MedicineInformationMenu(starting_x as UByte = 0, starting_y as UByte = 0)

 x = starting_x
 y = starting_y
 
 main_menu = BlueMenu(x, y)

end constructor


sub MedicineInformationMenu.Display()

 dim temp as String

 main_menu.ChangeOption(1, FF4Text("Name:        ") + name, 15)
 main_menu.ChangeOption(2, FF4Text("Price:       " + PriceName(price)), 15)
 main_menu.ChangeOption(3, FF4Text("Visual:      ") + spells(visual).name, 15)
 if description + 1 <= item_descriptions.Length() then
  temp = item_descriptions.ItemAt(description + 1)
 else
  temp = FF4Text("N/A")
 end if
 main_menu.ChangeOption(4, FF4Text("Description: ") + Pad(temp, 19,, FF4Text(" ")), 15)
 
 main_menu.Display()

end sub


sub MedicineInformationMenu.SetTo(index as UByte)

 name = medicines(index).name
 price = medicines(index).price_code
 visual = medicines(index).visual
 description = medicines(index).description

end sub


sub MedicineInformationMenu.EditField(row as Integer)

 'Edits one row of the box (1 name, 2 price, 3 visual, 4 description) and shows the box again

 dim spellmenu as BlueMenu

 select case row

  case 1 'Name
   dim t as BlueTextInput
   t = BlueTextInput(x + 13, y)
   t.starting_text = name
   t.text_width = 9
   t.UserType()
   name = Pad(t.text, 9,, FF4Text(" "))

  case 2 'Price
   dim price_list as List
   for i as Integer = 0 to &hFF
    price_list.Append(FF4Text(PriceName(&hFF - i)))
   next
   price = &h100 - ListItem(x + 13, y + 1, price_list, &h100 - price)
   price_list.Destroy()

  case 3 'Visual
   spellmenu.max_rows = 1
   for i as Integer = 1 to total_spells
    spellmenu.AddOption(spells(i - 1).name)
   next
   spellmenu.x = x + 13
   spellmenu.y = y + 2
   spellmenu.ChangeSelected(visual + 1)
   spellmenu.UserSelect()
   if not spellmenu.cancelled then visual = spellmenu.selected - 1

  case 4 'Description
   if description + 1 <= item_descriptions.Length() then description = ListItem(x + 13, y + 3, item_descriptions, description + 1) - 1

 end select

 Display()

end sub


sub MedicineInformationMenu.UserSelect()

 main_menu.cancelled = false

 do until main_menu.cancelled
  main_menu.UserSelect()
  if not main_menu.cancelled then EditField(main_menu.selected)
 loop

end sub
