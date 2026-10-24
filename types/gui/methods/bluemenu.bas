constructor BlueMenu(starting_x as UInteger = 0, starting_y as UInteger = 0)

 x = starting_x
 y = starting_y

end constructor


function BlueMenu.CursorX(h as Boolean = false) as UByte

 dim result as UByte
 
 if h then 
  result = x + ((highlighted - 1) mod columns) * (ItemWidth() + 2) + 1
 else
  result = x + ((selected - 1) mod columns) * (ItemWidth() + 2)
 end if
 
 return result

end function


function BlueMenu.ItemWidth() as UByte

 'Width of one entry: the widest one, unless a larger minimum width is set

 if options.Width() < min_width then return min_width
 return options.Width()

end function


function BlueMenu.CursorY(h as Boolean = false) as UByte

 dim result as UByte
 
 if h then
  result = y + (highlighted - 1) \ columns - top_row + 2
 else
  result = y + (selected - 1) \ columns - top_row + 2
 end if
 
 return result

end function


function BlueMenu.ProcessKey(key_code as UInteger) as Boolean

 dim result as Boolean
 dim temp as Integer

 select case key_code
 case ENTER_KEY
  if swap_enabled and (multikey(SC_LSHIFT) or multikey(SC_RSHIFT)) then
   highlighted = selected
  else
   result = true
   cancelled = false
  end if
 case ESC_KEY
  result = true
  cancelled = true
 case UP_KEY
  if selected > columns then 
   selected -= columns
   if selected <= (top_row - 1) * columns then top_row -= 1
  end if
 case DOWN_KEY
  if selected + columns <= options.Length() then
   selected += columns
   if selected > (top_row + WindowHeight() - 1) * columns then top_row += 1
  end if
 case LEFT_KEY
  if (selected - 1) mod columns > 0 then selected -= 1
 case RIGHT_KEY
  if (selected - 1) mod columns < columns - 1 and selected < options.Length() then selected += 1
 case HOME_KEY
  if top_row > 1 then top_row = 1
  selected = 1
 case END_KEY
  if max_rows > 0 then
   'if top_row < (options.Length() - 1) \ columns + 1 - WindowHeight() + 1 then 
   if top_row + RoundUp(options.Length() / columns) > WindowHeight() then
    top_row = (options.Length() - 1) \ columns + 1 - WindowHeight() + 1
   end if
  end if
  selected = options.Length()
 case PAGEUP_KEY
  if max_rows = 1 then temp = 10 else temp = WindowHeight()
  if top_row > temp then
   top_row -= temp
   selected -= temp * columns
  else
   top_row = 1
   selected = 1
  end if
 case PAGEDOWN_KEY
  if max_rows = 1 then temp = 10 else temp = WindowHeight()
  if WindowHeight() > options.Length() then
   selected = options.Length()
  else
   if top_row + WindowHeight() + temp > RoundUp(options.Length() / columns) then
    top_row = (options.Length() - 1) \ columns + 1 - WindowHeight() + 1
    selected = options.Length()
   else
    top_row += temp
    selected += temp * columns
   end if
  end if
 case F1_KEY
  ShowKeyHelp()
 case 6 'Ctrl+F: find an entry by name
  FindNext(true)
 case 14 'Ctrl+N: find the next match
  FindNext(false)
 case 7 'Ctrl+G: go to an entry by number
  GoToIndex()
 case asc("/")
  indexed_mode = not indexed_mode
  RestoreSnapshot()
  TakeSnapshot()
 case 8, 32 to 126
  if type_ahead then TypeAhead(key_code)
 end select
 
 return result

end function


function BlueMenu.HitItem(cell_x as Integer, cell_y as Integer) as Integer

 'The entry under a screen cell, or 0 if the cell is not on an entry.

 dim item_width as Integer = ItemWidth()
 dim rel_x as Integer = cell_x - x - 1
 dim rel_y as Integer = cell_y - y - 1
 dim column as Integer
 dim item as Integer

 if indexed_mode then item_width += len(str(options.Length())) + 2
 if rel_x < 0 or rel_y < 0 or rel_y >= WindowHeight() then return 0
 if rel_x mod (item_width + 2) >= item_width then return 0
 column = rel_x \ (item_width + 2)
 if column >= columns then return 0
 item = (top_row - 1 + rel_y) * columns + column + 1
 if item > options.Length() then return 0

 return item

end function


function BlueMenu.MouseCode() as UInteger

 'Turns mouse activity into the key it stands for (0 = nothing happened):
 ' right button = Esc, wheel = Up / Down, clicking an entry selects it and
 ' clicking the selected entry again = Enter. A plain selection returns 1,
 ' which no menu treats as a key, so the caller just redraws.

 dim cell_x as Integer
 dim cell_y as Integer
 dim left_click as Boolean
 dim right_click as Boolean
 dim steps as Integer
 dim item as Integer

 PollMouse(cell_x, cell_y, left_click, right_click, steps)

 if right_click then return ESC_KEY
 if steps > 0 then return UP_KEY
 if steps < 0 then return DOWN_KEY
 if left_click then
  item = HitItem(cell_x, cell_y)
  if item > 0 then
   if item = selected then return ENTER_KEY
   ChangeSelected(item)
   return 1
  end if
 end if

 return 0

end function


function BlueMenu.UserInput() as Boolean
 
 dim result as Boolean
 dim key_code as UInteger
 dim key as String
 dim mouse_code as UInteger
 
 Display()
 ShowCursor()
 do
  key = inkey
  mouse_code = 0
  if key = "" then
   if cast(Any ptr, idle_hook) <> 0 then idle_hook()
   mouse_code = MouseCode()
   if mouse_code = 0 then sleep 10
  end if
 loop while key = "" and mouse_code = 0
 if mouse_code <> 0 then
  key_code = mouse_code
 else
  key_code = asc(right(key, 1))
  if len(key) > 1 then key_code = key_code * &h100 + 255
 end if
 last_key = key_code
 if cast(Any ptr, key_hook) <> 0 then key_hook(key_code)
 result = ProcessKey(key_code)

 return result
 
end function


function BlueMenu.WindowHeight() as UByte
 
 dim result as UByte
 
 if max_rows = 0 then result = options.Length() else result = max_rows
 if result mod columns = 0 then result \= columns else result = result \ columns + 1
 
 return result
 
end function


function BlueMenu.WindowWidth() as UByte

 dim result as UByte
 
 result = (ItemWidth() + 2) * columns - 2
 if indexed_mode then result += len(str(options.Length())) + 2
 
 return result

end function


sub BlueMenu.AddOption(s as String, c as UByte = 15)
 
 options.Append(s)
 colors.Append(str(c))
 
end sub


sub BlueMenu.ChangeOption(index as UInteger, s as String = "", c as Integer = -1)
 
 if len(s) > 0 then options.Assign(index, s)
 if c >= 0 then colors.Assign(index, str(c))
 
end sub


sub BlueMenu.ChangeSelected(index as UInteger)
 
 if index > 0 and options.Length() > 0 then
  if index <= options.Length() then
   selected = index
  else
   selected = options.Length()
  end if
  if max_rows > 0 then
   do while selected <= (top_row - 1) * columns 
    top_row -= 1
   loop
   do while selected > (top_row + WindowHeight() - 1) * columns 
    top_row += 1
   loop
  end if
 end if
  
end sub


sub BlueMenu.ClearAll()
 
 options.Destroy()
 colors.Destroy()
 
end sub


sub BlueMenu.FindNext(new_search as Boolean)

 'Jumps to the next entry (after the cursor, wrapping around) whose name
 ' contains the search text. A new search prompts for the text first.

 dim n as Integer = options.Length()
 dim i as Integer

 if new_search then
  menu_search_text = lcase(PromptLine("Find, Esc cancels:", 20))
 end if
 if menu_search_text = "" or n = 0 then exit sub

 for offset as Integer = 1 to n
  i = (selected - 1 + offset) mod n + 1
  if instr(lcase(FF4Name(options.ItemAt(i))), menu_search_text) > 0 then
   ChangeSelected(i)
   exit sub
  end if
 next

end sub


sub BlueMenu.TypeAhead(key_code as UInteger)

 'Keeps the letters typed in the last 2 seconds and moves to the first entry
 ' that starts with them, or else the first that contains them. Backspace
 ' removes the last letter.

 dim n as Integer = options.Length()
 dim found as Integer = 0

 if timer - typed_time > 2 then typed_text = ""
 typed_time = timer
 if key_code = 8 then
  if len(typed_text) > 0 then typed_text = left(typed_text, len(typed_text) - 1)
 else
  typed_text += lcase(chr(key_code))
 end if
 if typed_text = "" or n = 0 then exit sub

 for i as Integer = 1 to n
  if left(lcase(FF4Name(options.ItemAt(i))), len(typed_text)) = typed_text then
   found = i
   exit for
  end if
 next
 if found = 0 then
  for i as Integer = 1 to n
   if instr(lcase(FF4Name(options.ItemAt(i))), typed_text) > 0 then
    found = i
    exit for
   end if
  next
 end if
 if found > 0 then ChangeSelected(found)

end sub


sub BlueMenu.GoToIndex()

 'Jumps to an entry by its number (the numbers shown with "/").

 dim typed as String

 if options.Length() = 0 then exit sub
 typed = PromptLine("Go to number, 1 to " + str(options.Length()) + ":", 6)
 if typed <> "" then ChangeSelected(Max(1, Min(options.Length(), val(typed))))

end sub


sub BlueMenu.Display()
 
 dim temp as String
 dim item_index as Integer
 dim text_x as Integer
 dim text_y as Integer
 dim menu_image as Any ptr
 dim text_width as Integer
 dim item_width as Integer

 
 if max_rows = 0 then top_row = 1
 
 item_width = ItemWidth()
 if indexed_mode then item_width += len(str(options.Length())) + 2
 text_width = (columns - 1) * (item_width + 2) + item_width
 
 menu_image = ImageCreate((text_width + 2) * 8, (WindowHeight() + 2) * 8, RGB(0, 0, 0))
 BlueBox(0, 0, text_width, WindowHeight(), menu_image)
 if len(title) > 0 then WriteText(FF4Text(" " + left(title, text_width - 2) + " "), 1, 0, 14, menu_image)
 'if debug then print "OK": getkey: end
 
 for i as UByte = 1 to WindowHeight()
  for j as UByte = 1 to columns
   item_index = (top_row + i - 2) * columns + j
   temp = rtrim(options.ItemAt(item_index))
   if indexed_mode then temp = FF4Text(Pad(str(item_index), len(str(options.Length())), true) + ": ") + temp
   temp += FF4Text(space(item_width - len(temp)))
   if j < columns then temp += FF4Text("  ")
   text_x = 0 + (j - 1) * (item_width + 2) + 1
   text_y = 0 + i
   WriteText(temp, text_x, text_y, val(colors.ItemAt(item_index)), menu_image)
  next
 next
 
 put (x * 8, y * 8), menu_image, trans
 ImageDestroy(menu_image)

  
end sub


sub BlueMenu.Hide()

 dim blank as Any ptr 
 
 if snapshot = 0 then
  blank = ImageCreate(Min((WindowWidth() + (len(str(options.Length())) + 2) + 2), screen_width) * 8, (WindowHeight() + 2) * 8, RGB(0, 0, 0))
  put (x * 8, y * 8), blank, pset
  ImageDestroy(blank)
 else
  RestoreSnapshot()
  ImageDestroy(snapshot)
  snapshot = 0
 end if
 
end sub


sub BlueMenu.Remove(index as UInteger = 0)

 if index = 0 then index = selected
 options.Remove(index)
 colors.Remove(index)
 if selected > options.Length() then selected = options.Length()
 if selected = 0 then selected = 1

end sub


sub BlueMenu.RestoreSnapshot()

 put (x * 8, y * 8), snapshot, pset

end sub

sub BlueMenu.ShowCursor()

 dim text as String = hint

 if selected <= hints.Length() then
  if hints.ItemAt(selected) <> "" then text = hints.ItemAt(selected)
 end if
 if text <> "" then
  ShowHint(text)
  hint_shown = true
 end if

 DrawLetter(20, CursorX(), CursorY())
 if highlighted > 0 then
  if CursorY(true) > y and CursorY(true) <= y + WindowHeight() then
   DrawLetter(20, CursorX(true), CursorY(true))
  end if
 end if

end sub


sub BlueMenu.TakeSnapshot()

 if snapshot <> 0 then
  ImageDestroy(snapshot)
  'snapshot = 0
 end if
 snapshot = ImageCreate(Min((WindowWidth() + (len(str(options.Length())) + 2) + 2), screen_width) * 8, (WindowHeight() + 2) * 8, RGB(0, 0, 0))
 get (x * 8, y * 8)-(Min((x + WindowWidth() + (len(str(options.Length())) + 2) + 2), screen_width) * 8 - 1, (y + WindowHeight() + 2) * 8 - 1), snapshot

end sub


sub BlueMenu.UserSelect()

 keyboard_visible = true
 TakeSnapshot()
 do until UserInput()
 loop
 RestoreSnapshot()
 ImageDestroy(snapshot)
 snapshot = 0
 if hint_shown then
  'the menu below shows its own hint again the next time it draws its cursor
  ShowHint("")
  hint_shown = false
 end if
 
end sub
