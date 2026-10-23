sub InfoBox(message as String, x as Integer = 4, y as Integer = 10)

 'Shows a bordered message (lines separated by "|") and waits for a key.

 dim lines(1 to 40) as String
 dim n as Integer
 dim w as Integer
 dim p as Integer
 dim rest as String = message
 dim backdrop as Any ptr

 do
  p = instr(rest, "|")
  n += 1
  if p = 0 then
   lines(n) = rest
  else
   lines(n) = left(rest, p - 1)
   rest = mid(rest, p + 1)
  end if
  if len(lines(n)) > w then w = len(lines(n))
 loop until p = 0 or n = 40

 backdrop = ImageCreate((w + 2) * 8, (n + 2) * 8)
 get (x * 8, y * 8)-((x + w + 2) * 8 - 1, (y + n + 2) * 8 - 1), backdrop
 BlueBox(x, y, w, n)
 for i as Integer = 1 to n
  WriteText(FF4Text(lines(i)), x + 1, y + i)
 next
 WaitForKeyOrClick()
 put (x * 8, y * 8), backdrop, pset
 ImageDestroy(backdrop)

end sub


function PromptLine(prompt_text as String, max_len as Integer = 30) as String

 'Asks the user to type a line of ASCII text. Returns "" if cancelled.

 dim result as String
 dim k as String
 dim w as Integer = Max(len(prompt_text), max_len + 1)
 dim backdrop as Any ptr
 dim x as Integer = 4
 dim y as Integer = 20

 backdrop = ImageCreate((w + 2) * 8, 4 * 8)
 get (x * 8, y * 8)-((x + w + 2) * 8 - 1, (y + 4) * 8 - 1), backdrop

 do
  BlueBox(x, y, w, 2)
  WriteText(FF4Text(prompt_text), x + 1, y + 1)
  WriteText(FF4Text(result + "_" + space(w - len(result) - 1)), x + 1, y + 2)
  do
   k = inkey
   if k = "" then sleep 10
  loop while k = ""
  if len(k) = 1 then
   select case asc(k)
    case 13
     exit do
    case 27
     result = ""
     exit do
    case 8
     if len(result) > 0 then result = left(result, len(result) - 1)
    case 32 to 126
     if len(result) < max_len then result += k
   end select
  end if
 loop

 put (x * 8, y * 8), backdrop, pset
 ImageDestroy(backdrop)

 return result

end function


function ConfirmBox(message as String) as Boolean

 'Yes/No question; defaults to No. Returns true only for Yes.

 dim w as Integer = Max(len(message), 10)
 dim x as Integer = (screen_width - w) \ 2
 dim y as Integer = 20
 dim backdrop as Any ptr
 dim choice as BlueMenu
 dim result as Boolean
 dim saved_hook as sub()

 backdrop = ImageCreate((w + 2) * 8, 7 * 8)
 get (x * 8, y * 8)-((x + w + 2) * 8 - 1, (y + 7) * 8 - 1), backdrop
 BlueBox(x, y, w, 5)
 WriteText(FF4Text(message), x + 1, y + 1)
 choice.x = x + 1
 choice.y = y + 3
 choice.AddOption(FF4Text("No"))
 choice.AddOption(FF4Text("Yes"))
 saved_hook = idle_hook 'an animated preview must not draw over the box
 idle_hook = 0
 choice.UserSelect()
 idle_hook = saved_hook
 result = (not choice.cancelled) and choice.selected = 2

 put (x * 8, y * 8), backdrop, pset
 ImageDestroy(backdrop)

 return result

end function


sub SetHints(target as BlueMenu, texts as String)

 'Gives the lines of a menu their hints (shown on the bottom row while the menu has the cursor): the texts in
 ' order, separated by |, an empty one leaves that line with the menu's own hint.

 dim rest as String = texts
 dim p as Integer

 target.hints.Destroy()
 do
  p = instr(rest, "|")
  if p = 0 then
   target.hints.Append(rest)
  else
   target.hints.Append(left(rest, p - 1))
   rest = mid(rest, p + 1)
  end if
 loop until p = 0

end sub


sub ShowHint(message as String)

 'The bottom line (row 57) says what Enter does on the line the cursor is on. An empty message clears it.

 line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf
 if message <> "" then WriteText(FF4Text(left(message, 78)), 1, 57, 14)

end sub


function ConfirmExport(what as String) as Boolean

 'Every BMP export asks first: it writes into the exports folder and replaces files of the same name.

 return ConfirmBox("Export " + what + " to the exports folder, replacing same names. Continue?")

end function


declare sub FillHelp(lines() as String, byref n as Integer, selected as Integer)
declare sub ShowKeyHelp()


function KeyHelpPressed(key_code as Integer) as Boolean

 'For the loops that read keys themselves (the BlueMenu ones already handle F1): shows the key help when the key
 ' is F1 and says so, so the loop can ignore the key.

 if key_code <> F1_KEY then return false

 ShowKeyHelp()

 return true

end function


sub ShowKeyHelp()

 'F1 in any menu: the keys that work everywhere, plus the keys of the open
 ' editor (the same text the main menu shows beside its entries).

 dim lines(1 to 40) as String
 dim n as Integer
 dim text as String

 FillHelp(lines(), n, help_entry)
 for i as Integer = 1 to n
  text += lines(i) + "|"
 next

 InfoBox(text + "|Press any key", 12, 1)

end sub
