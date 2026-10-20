constructor BlueNumberInput(starting_x as UInteger = 0, starting_y as UInteger = 0)

 x = starting_x
 y = starting_y

end constructor


function BlueNumberInput.UserInput() as Boolean

 dim result as Boolean
 dim a as UInteger

 Display()
 DrawLetter(20, x, y + 1)
 a = getkey
 select case a
  case ESC_KEY
   number = starting_number
   result = true
  case ENTER_KEY
   result = true
  case UP_KEY
   if number < max_value then number += 1
  case DOWN_KEY
   if number > min_value then number -= 1
  case PAGEUP_KEY
   if number + 10 <= max_value then number += 10
  case PAGEDOWN_KEY
   if number >= min_value + 10 then number -= 10
  case HOME_KEY
   number = min_value
  case END_KEY
   number = max_value
  case BACKSPACE_KEY
   if number_hex_mode then number = number \ 16 else number = number \ 10
   if number < min_value then number = min_value
  case asc("x"), asc("X") 'switch between decimal and hexadecimal entry
   number_hex_mode = not number_hex_mode
   input_started = false
  case asc("0") to asc("9")
   if number_hex_mode then
    if input_started then number *= 16 else number = 0
   else
    if input_started then number *= 10 else number = 0
   end if
   number += a - 48
   if number > max_value then number = max_value
   input_started = true
  case asc("a") to asc("f"), asc("A") to asc("F")
   if number_hex_mode then
    if input_started then number *= 16 else number = 0
    number += (a and 7) + 9 '"A" and "a" both give 10
    if number > max_value then number = max_value
    input_started = true
   end if
 end select
 
 return result

end function


sub BlueNumberInput.Display()

 dim shown as String
 dim w as Integer = len(str(max_value))

 BlueBox(x, y, w, 1)
 if number_hex_mode then
  shown = hex(number, len(hex(max_value)))
  if len(shown) + 1 <= w then shown = "$" + shown
  shown = Pad(shown, w, true)
 else
  shown = Pad(str(number), w, true)
 end if
 WriteText(FF4Text(shown), x + 1, y + 1)

end sub


sub BlueNumberInput.Hide()

 dim blank as Any ptr 
 
 blank = ImageCreate((x + len(str(max_value)) + 2) * 8, (y + 1 + 2) * 8, RGB(0, 0, 0))
 put (x * 8, y * 8), blank, pset
 
 ImageDestroy(blank)

end sub


sub BlueNumberInput.UserSelect()

 dim done as Boolean
 dim snapshot as any ptr

 snapshot = ImageCreate(640, 480)
 get (x * 8, y * 8)-((x + len(str(max_value)) + 2) * 8, (y + 1 + 2) * 8 - 1), snapshot
 number = starting_number
 input_started = false

 do until UserInput()
 loop

 put (x * 8, y * 8), snapshot, pset
 ImageDestroy(snapshot)

end sub
