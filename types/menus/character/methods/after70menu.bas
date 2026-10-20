constructor After70Menu(starting_x as UByte = 0, starting_y as UByte = 0)

 x = starting_x
 y = starting_y
 stat_menu(1) = StatUpMenu(x, y + 3)
 stat_menu(2) = StatUpMenu(x + 5, y + 3)
 stat_menu(3) = StatUpMenu(x, y + 13)
 stat_menu(4) = StatUpMenu(x + 5, y + 13)
 stat_menu(5) = StatUpMenu(x, y + 23)
 stat_menu(6) = StatUpMenu(x + 5, y + 23)
 stat_menu(7) = StatUpMenu(x, y + 33)
 stat_menu(8) = StatUpMenu(x + 5, y + 33)

end constructor


sub After70Menu.Display()

 BlueBox(x, y, 8, 1)
 WriteText(FF4Text("After 70"), x + 1, y + 1)
 for i as Integer = 1 to 8
  stat_menu(i).Display()
 next

end sub


sub After70Menu.SetTo(index as UByte)

 for i as Integer = 1 to 8
  stat_menu(i).SetTo(characters(index).after70(i))
 next

end sub
