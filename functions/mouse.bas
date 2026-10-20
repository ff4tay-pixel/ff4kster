'Mouse support. The screen is a grid of 8x8 pixel cells; menus work in cells.

dim shared mouse_buttons_before as Integer
dim shared mouse_wheel_before as Integer
dim shared mouse_seen as Boolean
dim shared mouse_pixel_x as Integer 'where the pointer was at the last poll (-1 outside the window)
dim shared mouse_pixel_y as Integer
dim shared mouse_left_held as Boolean


sub PollMouse(byref cell_x as Integer, byref cell_y as Integer, byref left_click as Boolean, byref right_click as Boolean, byref wheel_steps as Integer)

 'Reports the mouse position as a cell (-1 when the pointer is outside the
 ' window), new left / right button presses since the last call, and how far
 ' the wheel turned (positive = away from the user = up).

 dim px as Integer
 dim py as Integer
 dim wheel as Integer
 dim buttons as Integer

 cell_x = -1
 cell_y = -1
 mouse_pixel_x = -1
 mouse_pixel_y = -1
 mouse_left_held = false
 left_click = false
 right_click = false
 wheel_steps = 0

 if getmouse(px, py, wheel, buttons) <> 0 then
  mouse_buttons_before = 0
  return
 end if
 if px < 0 or py < 0 then
  mouse_buttons_before = 0
  return
 end if

 if wheel < 0 then wheel = 0
 if not mouse_seen then
  mouse_seen = true
  mouse_wheel_before = wheel
  mouse_buttons_before = buttons
 end if

 mouse_pixel_x = px
 mouse_pixel_y = py
 mouse_left_held = ((buttons and 1) <> 0)
 cell_x = px \ 8
 cell_y = py \ 8
 left_click = ((buttons and 1) <> 0) and ((mouse_buttons_before and 1) = 0)
 right_click = ((buttons and 2) <> 0) and ((mouse_buttons_before and 2) = 0)
 wheel_steps = wheel - mouse_wheel_before
 mouse_buttons_before = buttons
 mouse_wheel_before = wheel

end sub


function WaitForKeyOrClick() as String

 'Like getkey, but a mouse click also ends the wait (it returns Enter).

 dim k as String
 dim cell_x as Integer
 dim cell_y as Integer
 dim left_click as Boolean
 dim right_click as Boolean
 dim wheel_steps as Integer

 do
  k = inkey
  if k <> "" then return k
  PollMouse(cell_x, cell_y, left_click, right_click, wheel_steps)
  if left_click or right_click then return chr(13)
  sleep 10
 loop

end function
