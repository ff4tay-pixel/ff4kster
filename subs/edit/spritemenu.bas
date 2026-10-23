'The actions menu of the sprite editors (Battle Sprites, Portraits, Monster Sprites).
'
'Every action of those editors has a key, but nobody should have to learn the keys: Enter (Space on the tile sheet
'of the battle sprites) opens a menu with every action, the key of each beside it, and the editor does what the
'entry says. The editors fill the menu with SmAdd (the key an entry stands for, or a number their own code
'handles), run it with SmRun, and then treat an entry that stands for a key as if that key had been pressed.
'
'The font has no + = ( ) [ ] < > characters, so the key names are written as words.

const sm_max = 30

dim shared sm_label(1 to sm_max) as String
dim shared sm_hint(1 to sm_max) as String
dim shared sm_key(1 to sm_max) as UInteger
dim shared sm_special(1 to sm_max) as Integer
dim shared sm_count as Integer


sub SmReset()

 sm_count = 0

end sub


sub SmAdd(label as String, hint as String, key as UInteger = 0, special as Integer = 0)

 if sm_count >= sm_max then exit sub
 sm_count += 1
 sm_label(sm_count) = label
 sm_hint(sm_count) = hint
 sm_key(sm_count) = key
 sm_special(sm_count) = special

end sub


function SmRun(title as String) as Integer

 'Shows the menu at the right of the screen. Returns the entry chosen, 0 if it was cancelled.

 dim m as BlueMenu
 dim label_width as Integer
 dim hint_width as Integer
 dim text_width as Integer

 for i as Integer = 1 to sm_count
  label_width = Max(label_width, len(sm_label(i)))
  hint_width = Max(hint_width, len(sm_hint(i)))
 next
 text_width = Max(label_width + 2 + hint_width, len(title) + 2)
 m = BlueMenu(78 - (text_width + 2), 3)
 m.title = title
 m.min_width = text_width
 for i as Integer = 1 to sm_count
  m.AddOption(FF4Text(sm_label(i) + space(label_width - len(sm_label(i)) + 2) + sm_hint(i)))
 next
 m.UserSelect()
 if m.cancelled then return 0

 return m.selected

end function


function SmPick(title as String, names() as String, count as Integer, current as Integer) as Integer

 'A list to choose one entry from. Returns its number (1 to count), 0 if it was cancelled.

 dim m as BlueMenu
 dim name_width as Integer

 for i as Integer = 1 to count
  name_width = Max(name_width, len(names(i)))
 next
 m = BlueMenu(78 - (Max(name_width, len(title) + 2) + 2), 3)
 m.title = title
 m.min_width = Max(name_width, len(title) + 2)
 m.max_rows = 28
 for i as Integer = 1 to count
  m.AddOption(FF4Text(names(i)))
 next
 m.ChangeSelected(Max(Min(current, count), 1))
 m.UserSelect()
 if m.cancelled then return 0

 return m.selected

end function


function SmNumber(current as Integer, max_value as Integer) as Integer

 'Types a number from 0 to max_value in a small box (Esc gives back the number it started on)

 dim n as BlueNumberInput

 n = BlueNumberInput(60, 24)
 n.min_value = 0
 n.max_value = max_value
 n.starting_number = current
 n.number = current
 n.UserSelect()

 return n.number

end function


const map_key_add_npc = 60001 'Shift-Insert in the map editor
const map_key_remove_npc = 60002 'Shift-Delete in the map editor


function MapActions(map_panel as Boolean, objects as Boolean) as UInteger

 'M in the map editor: a menu of every action with its key. Returns the key the chosen entry stands for (the
 ' editor handles it as if it had been pressed), 0 if cancelled. map_panel is false while the tile palette has the
 ' cursor, objects is true on maps that have triggers and NPC placements.

 SmReset()
 if map_panel then
  SmAdd("Place the tile", "Enter", ENTER_KEY)
  SmAdd("Fill with the tile", "Space", SPACE_KEY)
  SmAdd("Pick the tile under the cursor", "Backspace", BACKSPACE_KEY)
  SmAdd("Replace all of that tile", "R", asc("r"))
  SmAdd("Copy the selected area", "Ctrl-C", 3)
  SmAdd("Paste the copy", "Ctrl-V", 22)
  SmAdd("Undo", "Ctrl-Z", 26)
  SmAdd("Redo", "Ctrl-Y", 25)
  SmAdd("Revert the map to the loaded ROM", "Ctrl-R", 18)
  if objects then
   SmAdd("Edit the trigger here", "T", asc("t"))
   SmAdd("Add a trigger here", "Insert", INSERT_KEY)
   SmAdd("Remove the trigger here", "Delete", DELETE_KEY)
   SmAdd("Edit the NPC here", "N", asc("n"))
   SmAdd("Add an NPC here", "Shift Insert", map_key_add_npc)
   SmAdd("Remove the NPC here", "Shift Delete", map_key_remove_npc)
  end if
  SmAdd("Show or hide NPCs and triggers", "O", asc("o"))
  SmAdd("Go to the tile palette", "Tab", TAB_KEY)
 else
  SmAdd("Show or hide NPCs and triggers", "O", asc("o"))
  SmAdd("Go to the map", "Tab", TAB_KEY)
 end if
 SmAdd("Leave the editor", "Esc", ESC_KEY)

 dim choice as Integer = SmRun("Map")
 if choice = 0 then return 0

 return sm_key(choice)

end function


function WorldActions(map_panel as Boolean) as UInteger

 'M in the world map editor: the same kind of menu (see MapActions).

 SmReset()
 if map_panel then
  SmAdd("Place the tile", "Enter", ENTER_KEY)
  SmAdd("Fill with the tile", "Space", SPACE_KEY)
  SmAdd("Pick the tile under the cursor", "Backspace", BACKSPACE_KEY)
  SmAdd("Replace all of that tile", "R", asc("r"))
  SmAdd("Copy the selected block", "Ctrl-C", 3)
  SmAdd("Paste the copy", "Ctrl-V", 22)
  SmAdd("Undo", "Ctrl-Z", 26)
  SmAdd("Redo", "Ctrl-Y", 25)
  SmAdd("Revert the world to the loaded ROM", "Ctrl-R", 18)
  SmAdd("Edit the trigger here", "T", asc("t"))
  SmAdd("Add a trigger here", "Insert", INSERT_KEY)
  SmAdd("Remove the trigger here", "Delete", DELETE_KEY)
 end if
 SmAdd("Change the overlay", "O", asc("o"))
 if map_panel then
  SmAdd("Go to the tile palette", "Tab", TAB_KEY)
 else
  SmAdd("Go to the map", "Tab", TAB_KEY)
 end if
 SmAdd("Leave the editor", "Esc", ESC_KEY)

 dim choice as Integer = SmRun("World map")
 if choice = 0 then return 0

 return sm_key(choice)

end function
