'Title screen editor (the picture shown before "New Game"). See readtitle.bas for the format. The picture is 256x224
'pixels of 4 bits, 32x28 tiles of 8x8; every tile uses one of 8 palettes of 16 colors. Color 0 of a tile is transparent
'and shows the backdrop, which is color 0 of palette 0. At most 256 different tiles fit in the ROM; Save ROM refuses
'more, so the screen counts them. The editing screen paints straight onto a zoomed part of the picture, with the whole
'picture at actual size beside it. The palette editor changes one of the 8 palettes.

const title_undo_depth = 24
const title_width = 256
const title_height = 224
const title_view_height = 192 'pixels of the zoom window, its width is 256

dim shared title_undo_px(title_undo_depth - 1, 255, 255) as UByte
dim shared title_undo_cellpal(title_undo_depth - 1, 31, 31) as UByte
dim shared title_undo_count as Integer
dim shared title_clip(7, 7) as UByte
dim shared title_clip_pal as Integer
dim shared title_clip_available as Boolean
dim shared title_pal_undo_pal(title_undo_depth - 1) as Integer
dim shared title_pal_undo_slot(title_undo_depth - 1) as Integer
dim shared title_pal_undo_value(title_undo_depth - 1) as UInteger
dim shared title_pal_undo_count as Integer
dim shared title_fill_x(title_width * title_height - 1) as Integer
dim shared title_fill_y(title_width * title_height - 1) as Integer


function TitleSnesColor(v as UInteger) as UInteger

 return RGB((v mod 32) * 8, ((v \ 32) mod 32) * 8, ((v \ 1024) mod 32) * 8)

end function


function TitleColor(pal as Integer, index as Integer) as UInteger

 'What a pixel looks like: color 0 shows the backdrop, the first color of palette 0

 if index = 0 then return TitleSnesColor(title_pal_raw(0, 0))

 return TitleSnesColor(title_pal_raw(pal, index))

end function


sub DrawTitleView(x as Integer, y as Integer, zoom as Integer, ox as Integer, oy as Integer, w as Integer, h as Integer, grid as Boolean)

 'The part of the picture that starts at pixel ox,oy and is w x h pixels, drawn at x,y with every pixel zoom x zoom

 dim pal as Integer
 dim col as UInteger

 for r as Integer = 0 to h - 1
  for c as Integer = 0 to w - 1
   pal = title_cellpal((oy + r) \ 8, (ox + c) \ 8)
   col = TitleColor(pal, title_px(oy + r, ox + c))
   if zoom = 1 then
    pset (x + c, y + r), col
   else
    line (x + c * zoom, y + r * zoom)-step(zoom - 1, zoom - 1), col, bf
   end if
  next
 next

 if grid and zoom >= 4 then
  for r as Integer = 0 to h - 1
   if (oy + r) mod 8 = 0 then line (x, y + r * zoom)-(x + w * zoom - 1, y + r * zoom), RGB(90, 90, 170)
  next
  for c as Integer = 0 to w - 1
   if (ox + c) mod 8 = 0 then line (x + c * zoom, y)-(x + c * zoom, y + h * zoom - 1), RGB(90, 90, 170)
  next
 end if

end sub


sub TitleSaveUndo()

 if title_undo_count = title_undo_depth then
  for i as Integer = 1 to title_undo_depth - 1
   for r as Integer = 0 to 255
    for c as Integer = 0 to 255
     title_undo_px(i - 1, r, c) = title_undo_px(i, r, c)
    next
   next
   for r as Integer = 0 to 31
    for c as Integer = 0 to 31
     title_undo_cellpal(i - 1, r, c) = title_undo_cellpal(i, r, c)
    next
   next
  next
  title_undo_count -= 1
 end if

 for r as Integer = 0 to 255
  for c as Integer = 0 to 255
   title_undo_px(title_undo_count, r, c) = title_px(r, c)
  next
 next
 for r as Integer = 0 to 31
  for c as Integer = 0 to 31
   title_undo_cellpal(title_undo_count, r, c) = title_cellpal(r, c)
  next
 next
 title_undo_count += 1
 title_tiles_stale = true

end sub


function TitleUndo() as Boolean

 'Puts back the last remembered picture. False if there is nothing to undo.

 if title_undo_count = 0 then return false

 title_undo_count -= 1
 for r as Integer = 0 to 255
  for c as Integer = 0 to 255
   title_px(r, c) = title_undo_px(title_undo_count, r, c)
  next
 next
 for r as Integer = 0 to 31
  for c as Integer = 0 to 31
   title_cellpal(r, c) = title_undo_cellpal(title_undo_count, r, c)
  next
 next
 title_tiles_stale = true

 return true

end function


sub TitlePaint(x as Integer, y as Integer, brush as Integer)

 if title_px(y, x) <> brush then
  TitleSaveUndo()
  title_px(y, x) = brush
 end if

end sub


sub TitleFill(x as Integer, y as Integer, brush as Integer)

 'Flood fill of the connected pixels with the same color number, in tiles that use the same palette as this one

 dim old as Integer = title_px(y, x)
 dim pal as Integer = title_cellpal(y \ 8, x \ 8)
 dim count as Integer = 0
 dim cx as Integer
 dim cy as Integer
 dim nx as Integer
 dim ny as Integer

 if old = brush then exit sub

 TitleSaveUndo()
 title_px(y, x) = brush
 title_fill_x(0) = x
 title_fill_y(0) = y
 count = 1

 do while count > 0
  count -= 1
  cx = title_fill_x(count)
  cy = title_fill_y(count)
  for d as Integer = 0 to 3
   nx = cx
   ny = cy
   select case d
    case 0: nx -= 1
    case 1: nx += 1
    case 2: ny -= 1
    case else: ny += 1
   end select
   if nx >= 0 and nx < title_width and ny >= 0 and ny < title_height then
    if title_px(ny, nx) = old and title_cellpal(ny \ 8, nx \ 8) = pal then
     title_px(ny, nx) = brush
     title_fill_x(count) = nx
     title_fill_y(count) = ny
     count += 1
    end if
   end if
  next
 loop

end sub


sub TitleSetTilePalette(x as Integer, y as Integer, pal as Integer)

 if pal < 0 or pal > 7 then exit sub
 if title_cellpal(y \ 8, x \ 8) = pal then exit sub

 TitleSaveUndo()
 title_cellpal(y \ 8, x \ 8) = pal

end sub


function TitleColorRole(pal as Integer, index as Integer) as String

 if index = 0 then
  if pal = 0 then return "backdrop of the whole screen"
  return "transparent, shows the backdrop"
 end if

 return ""

end function


function TitlePaletteUse(pal as Integer) as Integer

 'How many of the 896 tiles on the screen use the palette

 dim n as Integer

 for r as Integer = 0 to title_rows - 1
  for c as Integer = 0 to 31
   if title_cellpal(r, c) = pal then n += 1
  next
 next

 return n

end function


sub TitleMoveColor(pal as Integer, slot as Integer, other as Integer)

 'Swaps two palette colors and renumbers the pixels of the tiles that use the palette, so they look the same

 dim v as UInteger = title_pal_raw(pal, slot)
 dim c as Integer

 title_pal_raw(pal, slot) = title_pal_raw(pal, other)
 title_pal_raw(pal, other) = v

 for r as Integer = 0 to 255
  for col as Integer = 0 to 255
   if title_cellpal(r \ 8, col \ 8) = pal then
    c = title_px(r, col)
    if c = slot then
     title_px(r, col) = other
    elseif c = other then
     title_px(r, col) = slot
    end if
   end if
  next
 next

 title_undo_count = 0
 title_pal_undo_count = 0
 title_tiles_stale = true

end sub


sub TitleSetChannel(pal as Integer, slot as Integer, shift as Integer, value as Integer)

 'Sets the red (shift 0), green (5) or blue (10) of a palette color to 0 to 31, remembering the old color for undo

 dim raw as Integer

 if value < 0 or value > 31 then exit sub

 if title_pal_undo_count = title_undo_depth then
  for i as Integer = 1 to title_undo_depth - 1
   title_pal_undo_pal(i - 1) = title_pal_undo_pal(i)
   title_pal_undo_slot(i - 1) = title_pal_undo_slot(i)
   title_pal_undo_value(i - 1) = title_pal_undo_value(i)
  next
  title_pal_undo_count -= 1
 end if
 title_pal_undo_pal(title_pal_undo_count) = pal
 title_pal_undo_slot(title_pal_undo_count) = slot
 title_pal_undo_value(title_pal_undo_count) = title_pal_raw(pal, slot)
 title_pal_undo_count += 1
 raw = title_pal_raw(pal, slot) and not (31 shl shift)
 title_pal_raw(pal, slot) = raw or (value shl shift)

end sub


sub DrawTitleScreen(mode as Integer, cx as Integer, cy as Integer, vx as Integer, vy as Integer, zoom as Integer, grid as Boolean, pal as Integer, brush as Integer)

 'mode: 0 = pixel editor, 1 = palette editor (pal is then the palette being edited, brush the selected color)

 dim view_w as Integer = title_width \ zoom
 dim view_h as Integer = title_view_height \ zoom
 dim px as Integer
 dim py as Integer
 dim v as UInteger
 dim role as String
 dim tiles as Integer = TitleTileCount()

 screenlock
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 'Title
 BlueBox(0, 0, 78, 1)
 WriteText(FF4Text("Title Screen   Tile " + str(cx \ 8) + "," + str(cy \ 8) + "   Palette " + str(pal)), 2, 1, 15)
 LuText("Pixel " + str(cx) + "," + str(cy), 66, 1, 14)

 'Zoomed part of the picture
 BlueBox(0, 3, 34, 27)
 LuText(" PICTURE, ZOOM " + str(zoom) + " ", 1, 3, 14)
 DrawTitleView(16, 40, zoom, vx, vy, view_w, view_h, grid)
 if mode = 0 then
  px = 16 + (cx - vx) * zoom
  py = 40 + (cy - vy) * zoom
  line (px - 1, py - 1)-(px + zoom, py + zoom), RGB(255, 255, 0), b
  line (px, py)-(px + zoom - 1, py + zoom - 1), RGB(0, 0, 0), b
 end if

 'The whole picture at actual size
 BlueBox(37, 3, 41, 30)
 LuText(" WHOLE PICTURE ", 38, 3, 14)
 DrawTitleView(320, 40, 1, 0, 0, title_width, title_height, false)
 line (320 + vx - 1, 40 + vy - 1)-(320 + vx + view_w, 40 + vy + view_h), RGB(255, 255, 0), b
 px = 320 + cx
 py = 40 + cy
 pset (px, py), RGB(255, 0, 0)

 'The 16 colors of the palette
 BlueBox(0, 32, 34, 6)
 LuText(" PALETTE " + str(pal) + " ", 1, 32, iif(mode = 1, 21, 14))
 for i as Integer = 0 to 15
  px = 16 + i * 16
  line (px, 264)-(px + 14, 282), TitleColor(pal, i), bf
  if i = brush then line (px - 1, 262)-(px + 15, 284), RGB(255, 255, 0), b
  LuText(str(i), (px + 4) \ 8 - 1, 36 + (i mod 2), iif(i = brush, 14, 15))
 next

 'Details
 BlueBox(37, 35, 41, 5)
 LuText(iif(mode = 1, " COLOR ", " BRUSH "), 38, 35, iif(mode = 1, 21, 14))
 v = title_pal_raw(pal, brush)
 role = TitleColorRole(pal, brush)
 LuText("Color " + str(brush) + iif(len(role) > 0, ", " + role, ""), 39, 37, 15)
 if brush = 0 and pal <> 0 then
  LuText("Not editable here: edit color 0 of palette 0", 39, 38, 23)
 else
  LuText("R " + str(v mod 32) + "   G " + str((v \ 32) mod 32) + "   B " + str((v \ 1024) mod 32), 39, 38, 23)
 end if
 LuText("Tiles used " + str(tiles) + " of " + str(title_max_tiles), 39, 40, iif(tiles > title_max_tiles, 12, 15))
 if tiles > title_max_tiles then LuText("Save ROM refuses", 62, 40, 12)

 'Keys
 BlueBox(0, 42, 78, 9)
 if mode = 1 then
  LuText(" ACTIONS, PALETTE " + str(pal) + " ", 1, 42, 21)
  LuText("Left Right: pick the color to change.   Comma Period: pick the palette.", 2, 44, 15)
  LuText("Enter: the menu to change its red, green and blue, move it, undo and more.", 2, 45, 15)
  LuText("Palette " + str(pal) + " is used by " + str(TitlePaletteUse(pal)) + " of the 896 tiles of the screen.", 2, 46, 15)
  LuText("Color 0 of palette 0 is the backdrop. Esc: back to the picture.", 2, 47, 15)
 else
  LuText(" ACTIONS, PICTURE ", 1, 42, 14)
  LuText("Arrows: move a pixel.   Home End PgUp PgDn: move a whole tile.", 2, 44, 15)
  LuText("Space: paint with the brush color.   0 to 9: choose a color and paint.", 2, 45, 15)
  LuText("Enter: the menu of every action, like fill, tile palette, zoom and export.", 2, 46, 15)
  LuText("The menu shows each action's key, so the keys can be learned as you go.", 2, 47, 15)
  LuText("Each 8x8 tile has one palette. Esc: back to the main menu.", 2, 48, 15)
 end if
 screenunlock

end sub


function TitleActions(mode as Integer, byref cx as Integer, byref cy as Integer, byref pal as Integer, byref brush as Integer, byref slot as Integer) as UInteger

 'The menu of every action of the title screen editor. Returns the key the chosen entry stands for, or 0 if the
 ' editor handled it here (or the menu was cancelled).

 dim choice as Integer
 dim picked as Integer
 dim names(1 to 32) as String
 dim count as Integer

 SmReset()
 if mode = 0 then
  SmAdd("Fill with the brush color", "F", asc("f"))
  SmAdd("Choose the brush color", "0 to 9", 0, 1)
  SmAdd("Choose the palette of this tile", "Comma Period", 0, 2)
  SmAdd("Copy this tile", "Ctrl-C", 3)
  SmAdd("Paste the tile here", "Ctrl-V", 22)
  SmAdd("Undo", "Ctrl-Z", 26)
  SmAdd("Revert the picture", "Ctrl-R", 18)
  SmAdd("Edit the palette colors", "P", asc("p"))
  SmAdd("Zoom in or out", "Z", asc("z"))
  SmAdd("Show or hide the tile grid", "G", asc("g"))
  SmAdd("Go to a tile", "", 0, 3)
  SmAdd("Export the picture as BMP", "E", asc("e"))
  SmAdd("Import the picture from BMP", "I", asc("i"))
  SmAdd("Back to the main menu", "Esc", ESC_KEY)
  choice = SmRun("Title screen")
 else
  SmAdd("Choose the color", "Left Right", 0, 11)
  SmAdd("Choose the palette", "Comma Period", 0, 2)
  SmAdd("Change its red", "Q A", 0, 12)
  SmAdd("Change its green", "W S", 0, 13)
  SmAdd("Change its blue", "E D", 0, 14)
  SmAdd("Move the color left", "Bracket", asc("["))
  SmAdd("Move the color right", "Bracket", asc("]"))
  SmAdd("Undo", "Ctrl-Z", 26)
  SmAdd("Revert this palette", "Ctrl-R", 18)
  SmAdd("Back to the picture", "Esc", ESC_KEY)
  choice = SmRun("Palette " + str(pal))
 end if
 if choice = 0 then return 0
 if sm_special(choice) = 0 then return sm_key(choice)

 select case sm_special(choice)

  case 1 'brush color
   for i as Integer = 0 to 15
    names(i + 1) = str(i) + iif(i = 0, " transparent", "")
   next
   picked = SmPick("Brush color", names(), 16, brush + 1)
   if picked > 0 then brush = picked - 1

  case 2 'palette
   for i as Integer = 0 to 7
    names(i + 1) = "Palette " + str(i) + iif(i = 0, " backdrop", "")
   next
   picked = SmPick("Palette", names(), 8, pal + 1)
   if picked > 0 then
    if mode = 0 then
     TitleSetTilePalette(cx, cy, picked - 1)
    else
     pal = picked - 1
     if pal <> 0 and slot = 0 then slot = 1
    end if
   end if

  case 3 'go to a tile
   cx = SmNumber(cx \ 8, 31) * 8
   cy = SmNumber(cy \ 8, title_rows - 1) * 8

  case 11 'color of the palette
   for i as Integer = 0 to 15
    names(i + 1) = str(i) + iif(i = 0, iif(pal = 0, " backdrop", " transparent"), "")
   next
   picked = SmPick("Color", names(), 16, slot + 1)
   if picked > 0 then
    slot = picked - 1
    if pal <> 0 and slot = 0 then slot = 1
   end if

  case 12 to 14 'red, green, blue
   count = (sm_special(choice) - 12) * 5
   picked = SmNumber((title_pal_raw(pal, slot) \ (2 ^ count)) mod 32, 31)
   TitleSetChannel(pal, slot, count, picked)

 end select

 return 0

end function


declare function ExportTitle() as String
declare function ImportTitle() as String


sub EditTitleScreen()

 dim key as String
 dim keycode as UInteger
 dim mode as Integer = 0 '0 = pixel editor, 1 = palette editor
 dim cx as Integer = 0
 dim cy as Integer = 0
 dim vx as Integer = 0
 dim vy as Integer = 0
 dim zoom as Integer = 8
 dim grid as Boolean = true
 dim pal as Integer = title_cellpal(0, 0)
 dim brush as Integer = 1
 dim slot as Integer = 1
 dim shift as Integer
 dim channel as Integer
 dim target as Integer
 dim done as Boolean = false
 dim view_w as Integer
 dim view_h as Integer

 title_undo_count = 0
 title_pal_undo_count = 0

 do

  view_w = title_width \ zoom
  view_h = title_view_height \ zoom
  if cx < vx then vx = cx
  if cx >= vx + view_w then vx = cx - view_w + 1
  if cy < vy then vy = cy
  if cy >= vy + view_h then vy = cy - view_h + 1
  if vx > title_width - view_w then vx = title_width - view_w
  if vy > title_height - view_h then vy = title_height - view_h
  if vx < 0 then vx = 0
  if vy < 0 then vy = 0

  if mode = 0 then pal = title_cellpal(cy \ 8, cx \ 8)
  DrawTitleScreen(mode, cx, cy, vx, vy, zoom, grid, pal, iif(mode = 1, slot, brush))

  do
   key = inkey
   if key = "" then sleep 10
  loop while key = ""
  keycode = asc(right(key, 1))
  if len(key) > 1 then keycode = keycode * &h100 + 255

  if KeyHelpPressed(keycode) then keycode = 0

  'Enter opens the menu of every action; the entries that stand for a key are handled as that key
  if keycode = ENTER_KEY then keycode = TitleActions(mode, cx, cy, pal, brush, slot)

  if mode = 0 then

   select case keycode
    case ESC_KEY
     done = true
    case LEFT_KEY
     if cx > 0 then cx -= 1
    case RIGHT_KEY
     if cx < title_width - 1 then cx += 1
    case UP_KEY
     if cy > 0 then cy -= 1
    case DOWN_KEY
     if cy < title_height - 1 then cy += 1
    case HOME_KEY
     cx = Max(cx - 8, 0)
    case END_KEY
     cx = Min(cx + 8, title_width - 1)
    case PAGEUP_KEY
     cy = Max(cy - 8, 0)
    case PAGEDOWN_KEY
     cy = Min(cy + 8, title_height - 1)
    case asc("0") to asc("9")
     brush = keycode - asc("0")
     TitlePaint(cx, cy, brush)
    case SPACE_KEY
     TitlePaint(cx, cy, brush)
    case asc("f"), asc("F")
     TitleFill(cx, cy, brush)
    case asc("["), asc("-")
     brush = (brush + 15) mod 16
    case asc("]"), asc("="), asc("+")
     brush = (brush + 1) mod 16
    case asc("z"), asc("Z")
     if zoom = 8 then zoom = 4 else zoom = 8
    case asc("g"), asc("G")
     grid = not grid
    case asc(",")
     TitleSetTilePalette(cx, cy, (title_cellpal(cy \ 8, cx \ 8) + 7) mod 8)
    case asc(".")
     TitleSetTilePalette(cx, cy, (title_cellpal(cy \ 8, cx \ 8) + 1) mod 8)
    case asc("p"), asc("P")
     mode = 1
     if pal <> 0 and slot = 0 then slot = 1
    case asc("e"), asc("E")
     if ConfirmExport("the title screen") then InfoBox(ExportTitle() + "||Press any key", 4, 20)
    case asc("i"), asc("I")
     if ConfirmBox("Import replaces the whole picture and its palettes. Continue?") then
      InfoBox(ImportTitle() + "||Press any key", 4, 20)
      title_pal_undo_count = 0
     end if
    case 3 'Ctrl-C
     for r as Integer = 0 to 7
      for c as Integer = 0 to 7
       title_clip(r, c) = title_px((cy \ 8) * 8 + r, (cx \ 8) * 8 + c)
      next
     next
     title_clip_pal = title_cellpal(cy \ 8, cx \ 8)
     title_clip_available = true
    case 22 'Ctrl-V
     if title_clip_available then
      TitleSaveUndo()
      for r as Integer = 0 to 7
       for c as Integer = 0 to 7
        title_px((cy \ 8) * 8 + r, (cx \ 8) * 8 + c) = title_clip(r, c)
       next
      next
      title_cellpal(cy \ 8, cx \ 8) = title_clip_pal
     end if
    case 26 'Ctrl-Z
     TitleUndo()
    case 18 'Ctrl-R
     if ConfirmBox("Revert the picture to the loaded ROM? The palettes stay.") then
      TitleSaveUndo()
      DecodeTitle(original_rom, title_px(), title_cellpal(), title_cmp_pal())
     end if
   end select

  else

   select case keycode
    case ESC_KEY
     mode = 0
    case LEFT_KEY
     if slot > iif(pal = 0, 0, 1) then slot -= 1
    case RIGHT_KEY
     if slot < 15 then slot += 1
    case asc(",")
     pal = (pal + 7) mod 8
     if pal <> 0 and slot = 0 then slot = 1
    case asc(".")
     pal = (pal + 1) mod 8
    case asc("q"), asc("Q"), asc("a"), asc("A"), asc("w"), asc("W"), asc("s"), asc("S"), asc("e"), asc("E"), asc("d"), asc("D")
     if slot > 0 or pal = 0 then
      select case keycode and &hDF
       case asc("Q"), asc("A"): shift = 0
       case asc("W"), asc("S"): shift = 5
       case else: shift = 10
      end select
      channel = (title_pal_raw(pal, slot) \ (2 ^ shift)) mod 32
      select case keycode and &hDF
       case asc("Q"), asc("W"), asc("E"): channel += 1
       case else: channel -= 1
      end select
      TitleSetChannel(pal, slot, shift, channel)
     end if
    case asc("["), asc("]")
     target = slot + iif(keycode = asc("["), -1, 1)
     if target >= 1 and target <= 15 and slot >= 1 then
      TitleMoveColor(pal, slot, target)
      slot = target
     end if
    case 26 'Ctrl-Z
     if title_pal_undo_count > 0 then
      title_pal_undo_count -= 1
      title_pal_raw(title_pal_undo_pal(title_pal_undo_count), title_pal_undo_slot(title_pal_undo_count)) = title_pal_undo_value(title_pal_undo_count)
     end if
    case 18 'Ctrl-R
     if ConfirmBox("Revert this palette to the loaded ROM?") then
      for j as Integer = 0 to 15
       title_pal_raw(pal, j) = asc(mid(original_rom, title_pal_base + pal * 32 + j * 2 + 1, 1)) + asc(mid(original_rom, title_pal_base + pal * 32 + j * 2 + 2, 1)) * &h100
      next
      title_pal_undo_count = 0
     end if
   end select

  end if

 loop until done

 cls

end sub


function TitlePath(file_name as String) as String

 mkdir system_path + "\exports"
 mkdir system_path + "\exports\title"

 return system_path + "\exports\title\" + file_name

end function


function WriteTitleBMP(path as String) as Boolean

 'An 8 bits per pixel BMP, 256x224. Each pixel's number is its palette times 16 plus its color, so a tile's palette
 ' is part of the image and the color table holds the 8 palettes in order (the palette 0 backdrop shows in the
 ' transparent color of the other palettes, as it does in the game).

 dim bmp_data as String
 dim row_text as String
 dim v as UInteger
 dim f as Integer = freefile
 dim data_size as Integer = title_width * title_height

 bmp_data = "BM" + BmpU32Text(1078 + data_size) + BmpU32Text(0) + BmpU32Text(1078)
 bmp_data += BmpU32Text(40) + BmpU32Text(title_width) + BmpU32Text(title_height) + BmpU16Text(1) + BmpU16Text(8)
 bmp_data += BmpU32Text(0) + BmpU32Text(data_size) + BmpU32Text(2835) + BmpU32Text(2835) + BmpU32Text(256) + BmpU32Text(256)

 for i as Integer = 0 to 255
  if i < 128 then
   if i mod 16 = 0 then v = title_pal_raw(0, 0) else v = title_pal_raw(i \ 16, i mod 16)
  else
   v = 0
  end if
  bmp_data += chr(((v \ 1024) mod 32) * 8) + chr(((v \ 32) mod 32) * 8) + chr((v mod 32) * 8) + chr(0)
 next

 for y as Integer = title_height - 1 to 0 step -1
  row_text = ""
  for x as Integer = 0 to title_width - 1
   row_text += chr(title_cellpal(y \ 8, x \ 8) * 16 + title_px(y, x))
  next
  bmp_data += row_text
 next

 if len(dir(path)) > 0 then kill path
 if open(path for binary access write as #f) <> 0 then return false
 put #f, , bmp_data
 close #f

 return true

end function


function ReadTitleBMP(path as String, byref problem as String) as Boolean

 'Reads titlescreen.bmp. Pixel numbers 0 to 127 are palette times 16 plus color; a tile takes the palette of its
 ' first pixel that is not color 0. The color table gives the colors of the palettes; color 0 of palettes 1 to 7
 ' is never shown, so it is left as it is.

 dim group as Integer
 dim other as Integer
 dim v as Integer
 dim new_cell(31, 31) as Integer

 if not ReadIndexedBMP(path, title_width, title_height, problem) then return false

 for tr as Integer = 0 to title_rows - 1
  for tc as Integer = 0 to 31
   group = -1
   for y as Integer = 0 to 7
    for x as Integer = 0 to 7
     v = bmp_px(tr * 8 + y, tc * 8 + x)
     if v > 127 then
      problem = "pixel " + str(tc * 8 + x) + "," + str(tr * 8 + y) + " uses color " + str(v) + ", but only 0 to 127 exist (8 palettes of 16)"
      return false
     end if
     if v mod 16 <> 0 then
      other = v \ 16
      if group < 0 then
       group = other
      elseif group <> other then
       problem = "tile " + str(tc) + "," + str(tr) + " mixes colors of palettes " + str(group) + " and " + str(other) + ": one tile has one palette"
       return false
      end if
     end if
    next
   next
   if group < 0 then group = title_cellpal(tr, tc)
   new_cell(tr, tc) = group
  next
 next

 TitleSaveUndo()
 for tr as Integer = 0 to title_rows - 1
  for tc as Integer = 0 to 31
   title_cellpal(tr, tc) = new_cell(tr, tc)
   for y as Integer = 0 to 7
    for x as Integer = 0 to 7
     title_px(tr * 8 + y, tc * 8 + x) = bmp_px(tr * 8 + y, tc * 8 + x) mod 16
    next
   next
  next
 next
 for p as Integer = 0 to 7
  for i as Integer = 0 to 15
   if p * 16 + i < bmp_table_count and (i > 0 or p = 0) then title_pal_raw(p, i) = BmpColorToSnes(bmp_table(p * 16 + i))
  next
 next

 return true

end function


function ExportTitle() as String

 if WriteTitleBMP(TitlePath("titlescreen.bmp")) then return "Wrote titlescreen.bmp|to exports/title"

 return "Export failed|Check that exports/title can be written"

end function


function ImportTitle() as String

 dim problem as String

 if len(dir(TitlePath("titlescreen.bmp"))) = 0 then return "No titlescreen.bmp found|in exports/title"
 if ReadTitleBMP(TitlePath("titlescreen.bmp"), problem) then return "Read titlescreen.bmp"

 return "Import failed|titlescreen.bmp: " + problem

end function
