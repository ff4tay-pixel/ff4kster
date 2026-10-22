'The Commands editor's two extra screens: the overview of all commands and the names of the internal commands.

function CommandDelayShort(index as Integer, value as Integer) as String

 'The delay of a command in a few letters for the overview (see MenuCommand.DelayDescription).

 select case index
  case 2 to 5, 25
   return "not used"
  case 7
   return "not used"
 end select

 if value = 0 then return "none"
 if value = 1 then return "1 turn"
 if value < 128 then return "1/" + str(value) + " turn"

 return str(value - 128) + " turns"

end function


function CommandActorCount(index as Integer) as Integer

 'How many actors have the command in their command list.

 dim result as Integer

 for a as Integer = 1 to total_actors
  for slot as Integer = 1 to 5
   if actors(a).menu_command(slot) = index - 1 then
    result += 1
    exit for
   end if
  next
 next

 return result

end function


function CommandOverview() as Integer

 'One screen with every command: its target, delay, how many actors have it and what has been changed
 ' since the ROM was loaded (those rows are yellow). Enter returns the command so the editor can go to
 ' it, Esc returns 0.

 dim overview_menu as BlueMenu
 dim shot as Any ptr
 dim result as Integer
 dim line_text as String
 dim target_text as String
 dim changes as String
 dim row_color as UByte

 shot = ImageCreate(640, 480)
 get (0, 0)-(639, 479), shot
 cls

 overview_menu = BlueMenu(1, 5)
 overview_menu.max_rows = 26
 overview_menu.type_ahead = true
 for i as Integer = 1 to total_commands
  target_text = Pad(left(FF4Name(targets.ItemAt(menucommands(i).target + 1)), 12), 12)
  changes = CommandChanges(i)
  if changes = "" then row_color = 15 else row_color = 14
  line_text = FF4Text(Pad(str(i), 2, true) + " ") + menucommands(i).name + FF4Text(" " + target_text + " ")
  line_text += FF4Text(Pad(CommandDelayShort(i, menucommands(i).delay), 9) + " ")
  line_text += FF4Text(Pad(str(CommandActorCount(i)), 3, true) + "   " + left(changes, 40))
  line_text = Pad(line_text, 74,, FF4Text(" ")) 'the same width whatever the rows say, so the header window above fits
  overview_menu.AddOption(line_text, row_color)
 next

 BlueBox(1, 2, overview_menu.WindowWidth(), 1)
 WriteText(FF4Text(" Command overview "), 2, 2, 14)
 WriteText(FF4Text("No Name  Target       Delay     Actors  Changed since the ROM was loaded"), 2, 3, 15)
 WriteText(FF4Text("Yellow rows have changes. Enter goes to that command in the list, Esc closes."), 1, 57, 14)

 overview_menu.UserSelect()
 if not overview_menu.cancelled then result = overview_menu.selected

 line (0, 0)-(639, 479), RGB(0, 0, 0), bf
 put (0, 0), shot, pset
 ImageDestroy(shot)

 return result

end function


sub EditInternalNames()

 'The names the battle shows for the commands the game adds itself: Change row, Defend and the two
 ' internal ones that put a unit back (show) and end covering (off). Five letters each.

 dim names_menu as BlueMenu
 dim name_input as BlueTextInput
 dim labels(1 to 4) as String = {"Change row", "Defend", "Show", "Off, cover"}
 dim shot as Any ptr

 shot = ImageCreate(640, 480)
 get (0, 0)-(639, 479), shot
 cls

 names_menu = BlueMenu(2, 4)
 names_menu.title = "Names of the internal commands"
 names_menu.min_width = 32
 name_input = BlueTextInput(36, 5)
 name_input.text_width = 5
 for k as Integer = 1 to 4
  names_menu.AddOption(FF4Text(Pad(labels(k), 14) + " ") + internal_command_names(k))
 next

 WriteText(FF4Text("Commands 27 to 30 of the game, only the name changes. Enter edits, Esc closes."), 1, 57, 14)

 do
  names_menu.UserSelect()
  if not names_menu.cancelled then
   name_input.y = 4 + names_menu.selected
   name_input.starting_text = internal_command_names(names_menu.selected)
   name_input.UserType()
   internal_command_names(names_menu.selected) = Pad(name_input.text, 5,, FF4Text(" "))
   names_menu.ChangeOption(names_menu.selected, FF4Text(Pad(labels(names_menu.selected), 14) + " ") + internal_command_names(names_menu.selected))
  end if
 loop until names_menu.cancelled

 line (0, 0)-(639, 479), RGB(0, 0, 0), bf
 put (0, 0), shot, pset
 ImageDestroy(shot)

end sub
