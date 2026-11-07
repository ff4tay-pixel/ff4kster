'The Credits editor: the lines of the end credits roll, with a picture of the roll in the game's font.
'The data and the rules are in subs/general/credits.bas.

const cr_preview_lines = 20 'lines the picture shows, two tile rows (16 pixels) each
const cr_preview_x = 43 * 8 'pixel position of the picture: inside the box at cell 42
const cr_preview_y = 8 * 8


function CrToInput(s as String) as String

 'The text window types a period as the font's period tile (C1), the credits use tile 0A.

 dim result as String = s

 for i as Integer = 1 to len(result)
  if asc(mid(result, i, 1)) = &h0A then mid(result, i, 1) = chr(&hC1)
 next

 return result

end function


function CrFromInput(s as String) as String

 dim result as String = s

 for i as Integer = 1 to len(result)
  if asc(mid(result, i, 1)) = &hC1 then mid(result, i, 1) = chr(&h0A)
 next
 do while len(result) > 0 and asc(right(result, 1)) = &hFF
  result = left(result, len(result) - 1)
 loop

 return result

end function


function CrRowText(i as Integer) as String

 'Number, then the line placed as it is on the roll (the indent as spaces)

 return FF4Text(Pad(str(i), 3, true) + " ") + string(cr_indent(i), chr(&hFF)) + CrToInput(cr_text(i))

end function


sub CrFillMenu(m as BlueMenu)

 dim keep as Integer = m.selected

 m.ClearAll()
 for i as Integer = 1 to cr_count
  m.AddOption(CrRowText(i))
 next
 m.AddOption(FF4Text("Add a line at the end"), 11)
 m.ChangeSelected(keep)

end sub


sub CrDrawPreview(sel as Integer)

 'The roll as the game draws it: each line on two tile rows (the upper one stays empty), the letters from the
 ' font as it is being edited, the selected line on a blue band.

 dim first as Integer = sel - 9
 dim i as Integer
 dim y as Integer
 dim x as Integer
 dim t as Integer

 line (cr_preview_x, cr_preview_y)-step(255, cr_preview_lines * 16 - 1), RGB(0, 0, 0), bf
 for k as Integer = 0 to cr_preview_lines - 1
  i = first + k
  if i >= 1 and i <= cr_count then
   y = cr_preview_y + k * 16
   if i = sel then line (cr_preview_x, y)-step(255, 15), RGB(0, 0, 110), bf
   for j as Integer = 1 to len(cr_text(i))
    if cr_indent(i) + j <= cr_width then
     t = asc(mid(cr_text(i), j, 1))
     x = cr_preview_x + (cr_indent(i) + j - 1) * 8
     for r as Integer = 0 to 7
      for c as Integer = 0 to 7
       if font_gfx(t, r, c) >= 2 then pset (x + c, y + 8 + r), RGB(255, 255, 255)
      next
     next
    end if
   next
  end if
 next

end sub


sub CrDrawInfo(sel as Integer)

 'The box on the right: what the roll takes of the room it has, and the picture.

 dim bytes as Integer = CrBytes()
 dim over as Boolean = (bytes > cr_room)

 BlueBox(42, 4, 32, 46)
 WriteText(FF4Text(Pad("Lines " + str(cr_count) + "   Bytes " + str(bytes) + " of " + str(cr_room), 32)), 43, 5, iif(over, 12, 15))
 if over then
  WriteText(FF4Text(Pad("Over by " + str(bytes - cr_room) + ". Save ROM refuses.", 32)), 43, 6, 12)
 else
  WriteText(FF4Text(Pad(str(cr_room - bytes) + " bytes free" + iif(CrChanged(), ", text changed", ", as loaded"), 32)), 43, 6, iif(CrChanged(), 14, 15))
 end if
 CrDrawPreview(sel)
 if sel <= cr_count then
  WriteText(FF4Text(Pad("Line " + str(sel) + ": indent " + str(cr_indent(sel)) + ", " + str(len(cr_text(sel))) + " letters", 32)), 43, 48)
 else
  WriteText(FF4Text(Pad("", 32)), 43, 48)
 end if
 WriteText(FF4Text(Pad("The picture shows the roll's font.", 32)), 43, 49)
 WriteText(FF4Text(Pad("A line holds 32 letters at most.", 32)), 43, 50)

end sub


sub CrSaveUndo()

 if cr_undo_count = cr_undo_max then
  for i as Integer = 1 to cr_undo_max - 1
   cr_undo(i) = cr_undo(i + 1)
  next
  cr_undo_count -= 1
 end if
 cr_undo_count += 1
 cr_undo(cr_undo_count) = CrPack()

end sub


function CrUndo() as Boolean

 if cr_undo_count = 0 then return false
 CrUnpack(cr_undo(cr_undo_count))
 cr_undo_count -= 1

 return true

end function


sub CrInsert(at as Integer)

 'An empty line becomes line number `at`

 if cr_count >= cr_max_lines then exit sub
 for i as Integer = cr_count to at step -1
  cr_indent(i + 1) = cr_indent(i)
  cr_text(i + 1) = cr_text(i)
 next
 cr_count += 1
 cr_indent(at) = 0
 cr_text(at) = ""

end sub


sub CrDelete(at as Integer)

 for i as Integer = at to cr_count - 1
  cr_indent(i) = cr_indent(i + 1)
  cr_text(i) = cr_text(i + 1)
 next
 cr_count -= 1

end sub


sub CrSwap(a as Integer, b as Integer)

 swap cr_indent(a), cr_indent(b)
 swap cr_text(a), cr_text(b)

end sub


sub CrTypeLine(m as BlueMenu, text_input as BlueTextInput, at as Integer)

 'Types the letters of a line; the line cannot go past 32 letters with its indent.

 dim room as Integer = Max(cr_width - cr_indent(at), 1)
 dim typed as String

 text_input.text_width = room
 text_input.starting_text = left(CrToInput(cr_text(at)), room)
 ShowHint("Type the line. Enter keeps it, Esc cancels, Backspace erases.")
 text_input.UserType()
 typed = CrFromInput(text_input.text)
 if typed <> cr_text(at) then
  CrSaveUndo()
  cr_text(at) = typed
 end if

end sub


sub EditCredits()

 dim m as BlueMenu
 dim text_input as BlueTextInput
 dim choice as Integer
 dim action as Integer
 dim at as Integer
 dim n as Integer

 m = BlueMenu(2, 4)
 m.title = "End credits"
 m.min_width = 36
 m.max_rows = 44
 CrFillMenu(m)
 text_input = BlueTextInput(2, 52)

 do
  at = m.selected
  CrDrawInfo(at)
  if at > cr_count then
   m.hint = "Enter adds an empty line at the end and types its text. Space: actions menu."
  else
   m.hint = "Enter types the text of this line. Space: actions menu (move, center, add, delete, undo)."
  end if
  m.cancelled = false
  m.UserInput()
  at = m.selected
  action = 0

  if m.last_key = 26 then
   action = 9 'Ctrl-Z
  elseif m.last_key = SPACE_KEY then
   SmReset()
   SmAdd("Type the text", "Replace the letters of this line", 0, 1)
   SmAdd("Center the line", "Indent it to the middle of the roll", 0, 2)
   SmAdd("Set the indent", "Spaces before the line, 0 to 32", 0, 3)
   SmAdd("Add a line above", "An empty line before this one", 0, 4)
   SmAdd("Add a line below", "An empty line after this one", 0, 5)
   SmAdd("Move the line up", "Swap with the line above", 0, 6)
   SmAdd("Move the line down", "Swap with the line below", 0, 7)
   SmAdd("Delete the line", "Remove it from the roll", 0, 8)
   SmAdd("Undo", "Ctrl-Z, the last change", 26, 9)
   SmAdd("Restore all lines", "Back to the roll of the loaded ROM", 0, 10)
   choice = SmRun("Credits line")
   if choice > 0 then action = sm_special(choice)
  elseif m.last_key = ENTER_KEY and not m.cancelled then
   if at > cr_count then action = 11 else action = 1
  end if

  if action >= 1 and action <= 8 and at > cr_count then
   if action <> 4 and action <> 5 then
    InfoBox("That is the Add a line entry.|Choose a line first.||Press any key", 20, 20)
    action = 0
   end if
  end if

  select case action
   case 1
    CrTypeLine(m, text_input, at)
    CrFillMenu(m)
   case 2
    CrSaveUndo()
    cr_indent(at) = Max((cr_width - len(cr_text(at))) \ 2, 0)
    CrFillMenu(m)
   case 3
    n = SmNumber(cr_indent(at), Max(cr_width - len(cr_text(at)), 0))
    if n <> cr_indent(at) then
     CrSaveUndo()
     cr_indent(at) = n
     CrFillMenu(m)
    end if
   case 4, 5
    if cr_count >= cr_max_lines then
     InfoBox("The roll has " + str(cr_max_lines) + " lines, the most there is room for.||Press any key", 20, 20)
    else
     CrSaveUndo()
     if action = 4 then CrInsert(Min(at, cr_count + 1)) else CrInsert(Min(at + 1, cr_count + 1))
     if action = 5 then m.selected = Min(at + 1, cr_count)
     CrFillMenu(m)
    end if
   case 6, 7
    n = iif(action = 6, at - 1, at + 1)
    if n >= 1 and n <= cr_count then
     CrSaveUndo()
     CrSwap(at, n)
     m.selected = n
     CrFillMenu(m)
    end if
   case 8
    if cr_count = 1 then
     InfoBox("The roll needs at least one line.||Press any key", 20, 20)
    elseif ConfirmBox("Delete line " + str(at) + "?") then
     CrSaveUndo()
     CrDelete(at)
     CrFillMenu(m)
    end if
   case 9
    if CrUndo() then
     CrFillMenu(m)
    else
     InfoBox("Nothing to undo.||Press any key", 20, 20)
    end if
   case 10
    if not CrChanged() then
     InfoBox("The roll is the same as in the loaded ROM.||Press any key", 20, 20)
    elseif ConfirmBox("Put back the roll of the loaded ROM?") then
     CrSaveUndo()
     CrUnpack(cr_orig_pack)
     CrFillMenu(m)
    end if
   case 11
    if cr_count >= cr_max_lines then
     InfoBox("The roll has " + str(cr_max_lines) + " lines, the most there is room for.||Press any key", 20, 20)
    else
     CrSaveUndo()
     CrInsert(cr_count + 1)
     CrFillMenu(m)
     m.ChangeSelected(cr_count)
     CrTypeLine(m, text_input, cr_count)
     CrFillMenu(m)
    end if
  end select
  ShowHint("")
 loop until m.cancelled

 cls

end sub
