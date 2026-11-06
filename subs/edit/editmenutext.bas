'The Menu Text editor: the names of the equipment slots of the Equip menu and the labels of the Status menu.
'The data and the rules are in subs/general/menutext.bas.

function MtRowText(i as Integer) as String

 return FF4Text(Pad(mt_label(i), 21) + " ") + mt_text(i)

end function


sub MtRefreshRow(m as BlueMenu, i as Integer)

 m.ChangeOption(i, MtRowText(i), iif(mt_text(i) <> mt_orig(i), 14, 15))

end sub


sub MtDrawInfo(i as Integer)

 'The box on the right: where the game shows the text, how long it can be, how it was.

 dim lines(1 to 7) as String
 dim n as Integer

 n += 1: lines(n) = "Shown in the game:"
 n += 1: lines(n) = "  " + mt_where(i)
 n += 1: lines(n) = "Longest text:  " + str(mt_size(i)) + " letters"
 n += 1: lines(n) = "When loaded:   "
 n += 1: lines(n) = "Now:           "
 n += 1: lines(n) = ""
 n += 1: lines(n) = "A shorter text is filled up with spaces."

 BlueBox(37, 4, 41, 8)
 for k as Integer = 1 to 7
  WriteText(FF4Text(Pad(lines(k), 40)), 38, 4 + k)
 next
 WriteText(mt_orig(i), 53, 8, 15)
 WriteText(mt_text(i), 53, 9, iif(mt_text(i) <> mt_orig(i), 14, 15))
 if i <= 2 then
  WriteText(FF4Text(Pad("Also used by the battle menu.", 40)), 38, 11)
 end if

end sub


sub MtRestore(m as BlueMenu, i as Integer)

 mt_text(i) = mt_orig(i)
 MtRefreshRow(m, i)

end sub


sub EditMenuText()

 dim m as BlueMenu
 dim text_input as BlueTextInput
 dim choice as Integer
 dim action as Integer
 dim changed as Integer

 m = BlueMenu(2, 4)
 m.title = "Equip and Status menu texts"
 m.min_width = 34
 m.hint = "Enter types a new text, as long as the old one at most. Space: actions menu."
 for i as Integer = 1 to mt_count
  m.AddOption(MtRowText(i))
  MtRefreshRow(m, i)
 next

 text_input = BlueTextInput(37, 14)

 do
  MtDrawInfo(m.selected)
  m.cancelled = false
  m.UserInput()
  action = 0
  if m.last_key = SPACE_KEY then
   SmReset()
   SmAdd("Type a new text", "Replace this text", 0, 1)
   SmAdd("Restore this text", "Back to the text of the loaded ROM", 0, 2)
   SmAdd("Restore all texts", "Every text on this screen", 0, 3)
   choice = SmRun("This text")
   if choice > 0 then action = sm_special(choice)
  elseif m.last_key = ENTER_KEY and not m.cancelled then
   action = 1
  end if

  select case action
   case 1
    text_input.text_width = mt_size(m.selected)
    text_input.starting_text = mt_text(m.selected)
    ShowHint("Type the new text. Enter keeps it, Esc cancels, Backspace erases.")
    text_input.UserType()
    mt_text(m.selected) = Pad(left(text_input.text, mt_size(m.selected)), mt_size(m.selected),, FF4Text(" "))
    MtRefreshRow(m, m.selected)
   case 2
    MtRestore(m, m.selected)
   case 3
    changed = 0
    for i as Integer = 1 to mt_count
     if mt_text(i) <> mt_orig(i) then changed += 1
    next
    if changed = 0 then
     InfoBox("No text on this screen was changed.||Press any key", 20, 20)
    elseif ConfirmBox("Restore the " + str(changed) + " changed texts?") then
     for i as Integer = 1 to mt_count
      MtRestore(m, i)
     next
    end if
  end select
  ShowHint("")
 loop until m.cancelled

 cls

end sub
