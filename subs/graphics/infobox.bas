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
