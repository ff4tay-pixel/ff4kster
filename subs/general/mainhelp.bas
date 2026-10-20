'Key help shown beside the main menu: general keys, then the keys that matter
' for whichever editor is highlighted.

sub HelpLine(lines() as String, byref n as Integer, s as String)

 n += 1
 lines(n) = s

end sub


sub DrawMainHelp(selected as Integer)

 dim x as Integer = 28
 dim y as Integer = 0
 dim w as Integer = 50
 dim lines(1 to 40) as String
 dim n as Integer

 HelpLine(lines(), n, "KEYS IN EVERY MENU")
 HelpLine(lines(), n, "Arrows        Move")
 HelpLine(lines(), n, "Enter         Open / select")
 HelpLine(lines(), n, "Esc           Back / cancel")
 HelpLine(lines(), n, "Home / End    First / last entry")
 HelpLine(lines(), n, "PgUp / PgDn   Page up / down")
 HelpLine(lines(), n, "/             Show entry numbers")
 HelpLine(lines(), n, "Ctrl-F        Find entry by name")
 HelpLine(lines(), n, "Ctrl-N        Find next match")
 HelpLine(lines(), n, "Ctrl-G        Go to entry number")
 HelpLine(lines(), n, "F1            Key help in any menu")
 HelpLine(lines(), n, "X            Hex or decimal in number boxes")
 HelpLine(lines(), n, "Tab           Switch panel two-pane editors")
 HelpLine(lines(), n, "")
 HelpLine(lines(), n, "THIS ENTRY")

 select case selected
  case 1
   HelpLine(lines(), n, "Writes your edits to the ROM file.")
   HelpLine(lines(), n, "A * means there are unsaved edits.")
   HelpLine(lines(), n, "Keep a backup of your ROM.")
  case 2
   HelpLine(lines(), n, "Item ranges: which items are two-handed,")
   HelpLine(lines(), n, "bows, arrows, shields, helmets, etc.")
  case 3, 5 to 8
   HelpLine(lines(), n, "Yellow names are changed since load.")
   HelpLine(lines(), n, "Ctrl-R  Revert entry   Ctrl-U  Where used")
   HelpLine(lines(), n, "Ctrl-C / V  Copy / paste entry")
   HelpLine(lines(), n, "Shift-Enter twice swaps two entries")
   HelpLine(lines(), n, "spells, weapons, armors.")
   HelpLine(lines(), n, "Enter opens the entry's editor.")
  case 4
   HelpLine(lines(), n, "Enter opens the entry's editor.")
  case 9
   HelpLine(lines(), n, "Edit what each shop sells.")
  case 10 to 13
   HelpLine(lines(), n, "Enter opens the entry's editor.")
   HelpLine(lines(), n, "In sub-menus: Tab switches between boxes.")
  case 14
   HelpLine(lines(), n, "Pick a map, then a message.")
   HelpLine(lines(), n, "Shift-Enter marks a message to swap.")
   HelpLine(lines(), n, "Insert adds a message, Delete removes.")
  case 15
   HelpLine(lines(), n, "Tab        Preview / pick the linked map")
   HelpLine(lines(), n, "Shift-Enter marks an event, Insert appends")
   HelpLine(lines(), n, "           its script to the current one")
   HelpLine(lines(), n, "In scripts: Insert / Delete / Backspace")
   HelpLine(lines(), n, "edit commands, Tab switches script.")
  case 16
   HelpLine(lines(), n, "Tab        Toggle the minimap cursor")
   HelpLine(lines(), n, "Insert     Add a trigger")
   HelpLine(lines(), n, "Delete     Remove the trigger")
   HelpLine(lines(), n, "Shift-Enter marks a trigger to swap.")
  case 17
   HelpLine(lines(), n, "Tab        Toggle the minimap cursor")
   HelpLine(lines(), n, "Insert     Add an NPC / placement")
   HelpLine(lines(), n, "Delete     Remove it")
  case 18
   HelpLine(lines(), n, "Tab        Edit the palette")
  case 19
   HelpLine(lines(), n, "Enter opens the map's properties.")
  case 20
   HelpLine(lines(), n, "J  Jump to map number   F  Find map name")
   HelpLine(lines(), n, "I  Grid details         Backspace  Erase map")
   HelpLine(lines(), n, "In the map editor:")
   HelpLine(lines(), n, "Tab          Map / tile palette")
   HelpLine(lines(), n, "Enter        Place tile    Space  Fill")
   HelpLine(lines(), n, "Backspace    Pick tile under cursor")
   HelpLine(lines(), n, "Shift-Arrow  Select an area")
   HelpLine(lines(), n, "Ctrl-C / V   Copy / paste   Ctrl-Z  Undo")
  case 21
   HelpLine(lines(), n, "Enter opens the monster's editor.")
   HelpLine(lines(), n, "Yellow = changed.  Ctrl-R revert, Ctrl-U")
   HelpLine(lines(), n, "where used, Ctrl-C / V copy / paste.")
   HelpLine(lines(), n, "Tab switches between the flag lists and")
   HelpLine(lines(), n, "their details.")
   HelpLine(lines(), n, "In Edit AI: L switches between the regular")
   HelpLine(lines(), n, "and the lunar AI script bank.")
  case 22 to 25
   HelpLine(lines(), n, "Enter opens the entry's editor.")
   HelpLine(lines(), n, "Autobattle scripts: Insert / Delete edit")
   HelpLine(lines(), n, "commands.")
  case 26
   HelpLine(lines(), n, "Writes spells, items, monsters, shops and")
   HelpLine(lines(), n, "formations to exports/NAME.csv.")
  case 27
   HelpLine(lines(), n, "Reads exports/NAME.csv back in. Only")
   HelpLine(lines(), n, "the columns in the file are changed.")
   HelpLine(lines(), n, "Use Save ROM afterwards to keep them.")
  case 28
   HelpLine(lines(), n, "Shows what your edits changed, and writes")
   HelpLine(lines(), n, "exports/rom_diff.txt with offsets.")
  case 29
   HelpLine(lines(), n, "Pick another ROM file; shows every byte")
   HelpLine(lines(), n, "region that differs from your current work.")
  case 30
   HelpLine(lines(), n, "Type part of a spell, item or monster name,")
   HelpLine(lines(), n, "pick a match, and its editor opens on it.")
  case 31
   HelpLine(lines(), n, "Shows how full each fixed ROM area is")
   HelpLine(lines(), n, "events, triggers, text, descriptions.")
   HelpLine(lines(), n, "Over 100% means Save ROM will refuse.")
  case 32
   HelpLine(lines(), n, "Lists every spell, item and monster you")
   HelpLine(lines(), n, "changed since loading; pick one to open it.")
  case 33
   HelpLine(lines(), n, "Edit the in-battle sprite of each character.")
   HelpLine(lines(), n, "Enter edits a tile, PgUp / PgDn changes the")
   HelpLine(lines(), n, "pose preview, , and . change the palette.")
   HelpLine(lines(), n, "Golbez and Anna are not included yet.")
  case else
   HelpLine(lines(), n, "Leave the editor. You are asked to save")
   HelpLine(lines(), n, "if there are unsaved edits.")
 end select

 BlueBox(x, y, w, n)
 for i as Integer = 1 to n
  WriteText(FF4Text(left(lines(i), w - 1)), x + 1, y + i, iif(lines(i) = "KEYS IN EVERY MENU" or lines(i) = "THIS ENTRY", 14, 15))
 next

end sub
