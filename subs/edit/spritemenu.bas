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
