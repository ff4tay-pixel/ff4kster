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
 getkey
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

 backdrop = ImageCreate((w + 2) * 8, 7 * 8)
 get (x * 8, y * 8)-((x + w + 2) * 8 - 1, (y + 7) * 8 - 1), backdrop
 BlueBox(x, y, w, 5)
 WriteText(FF4Text(message), x + 1, y + 1)
 choice.x = x + 1
 choice.y = y + 3
 choice.AddOption(FF4Text("No"))
 choice.AddOption(FF4Text("Yes"))
 choice.UserSelect()
 result = (not choice.cancelled) and choice.selected = 2

 put (x * 8, y * 8), backdrop, pset
 ImageDestroy(backdrop)

 return result

end function


sub ShowKeyHelp()

 'F1 in any menu.

 InfoBox("KEYS IN EVERY MENU|" + _
  "Arrows        Move|" + _
  "Enter         Open / select|" + _
  "Esc           Back / cancel|" + _
  "Home / End    First / last entry|" + _
  "PgUp / PgDn   Page up / down|" + _
  "/             Show entry numbers|" + _
  "Ctrl-F        Find entry by name|" + _
  "Ctrl-N        Find next match|" + _
  "Ctrl-G        Go to entry number|" + _
  "F1            This help||" + _
  "SPELL / ITEM / MONSTER LISTS|" + _
  "Yellow names  Changed since load|" + _
  "Ctrl-R        Revert entry to loaded ROM|" + _
  "Ctrl-C / V    Copy / paste entry|" + _
  "Ctrl-U        Where is this used?|" + _
  "Shift-Enter   Swap two entries||" + _
  "Press any key", 15, 8)

end sub


sub DrawBreadcrumb(text as String)

 'Where-am-I line at the bottom of the screen.

 line (12 * 8, 59 * 8)-(79 * 8 + 7, 59 * 8 + 7), RGB(0, 0, 0), bf
 WriteText(FF4Text(left(text, 66)), 12, 59, 11)

end sub
