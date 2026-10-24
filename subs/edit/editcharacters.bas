sub EditCharacters()

 dim select_character as BlueMenu
 dim levelup_menu as CharacterLevelUpMenu
 dim starting_menu as CharacterStartingMenu
 dim after70_menu as After70Menu
 dim edit_character as BlueMenu
 
 for i as Integer = 1 to total_characters - 1
  select_character.AddOption(character_labels.ItemAt(i))
 next
 
 edit_character.AddOption(FF4Text("Edit starting data"))
 edit_character.AddOption(FF4Text("Edit level up data"))
 edit_character.AddOption(FF4Text("Edit after 70 data"))
 edit_character.x = screen_width - edit_character.options.Width() - 2
 SetHints(edit_character, "Enter edits the data this character starts the game with.|Enter opens the level up editor. Its keys are listed at the bottom.|Enter opens the after 70 data editor.")
 select_character.hint = "Enter opens a menu: starting data, level up data, after 70 data."
 
 starting_menu = CharacterStartingMenu(select_character.options.Width() + 2)
 starting_menu.SetTo(1)
 starting_menu.Display()
 levelup_menu = CharacterLevelUpMenu(select_character.options.Width() + 2, starting_menu.starting_menu.options.Length() + 2)
 levelup_menu.SetTo(1)
 after70_menu = After70Menu(levelup_menu.x + levelup_menu.level_menu.options.Width() + 2, 0) 'its eight boxes are 43 rows tall: from the top they end above the hint line
  
 do
  do
   starting_menu.SetTo(select_character.selected)
   starting_menu.Display()
   levelup_menu.SetTo(select_character.selected)
   levelup_menu.Display()
   after70_menu.SetTo(select_character.selected)
   after70_menu.Display()
  loop until select_character.UserInput()
  if not select_character.cancelled then
   edit_character.UserSelect()
   if not edit_character.cancelled then
    select case edit_character.selected
     case 1
      starting_menu.UserSelect()
      starting_menu.ApplyUpdates(select_character.selected)
     case 2
      EditLevelUps(select_character.selected)
     case 3
      EditAfter70(select_character.selected)
    end select
   end if
  end if
 loop until select_character.cancelled

end sub
