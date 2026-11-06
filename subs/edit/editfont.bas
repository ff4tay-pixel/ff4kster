'The Font and Icons editor: the 256 tiles of 8x8 pixels the game draws its text, icons and window frames from.
'The data is in subs/general/fonttiles.bas. The editor's own letters and windows keep the font that was loaded
'with the ROM until FF4kster is started again, so a mistake never makes the editor unreadable.

const ft_undo_depth = 64
const ft_sheet_x = 8 'top left of the sheet of all tiles, in pixels
const ft_sheet_y = 32
const ft_sheet_zoom = 3
const ft_big_x = 416 'the big tile
const ft_big_y = 32
const ft_big_zoom = 16

dim shared ft_undo_tile(ft_undo_depth - 1) as Integer
dim shared ft_undo_pixels(ft_undo_depth - 1, 7, 7) as UByte
dim shared ft_undo_count as Integer
dim shared ft_clip(7, 7) as UByte
dim shared ft_clip_available as Boolean


function FontTileColor(pal as Integer, c as Integer) as UInteger

 dim v as UInteger = font_pal_raw(pal * 4 + c)

 return RGB((v mod 32) * 8, ((v \ 32) mod 32) * 8, ((v \ 1024) mod 32) * 8)

end function


sub DrawFontTile(t as Integer, x as Integer, y as Integer, zoom as Integer, pal as Integer, gap as Integer = 0)

 for r as Integer = 0 to 7
  for c as Integer = 0 to 7
   line (x + c * zoom, y + r * zoom)-step(zoom - gap - 1, zoom - gap - 1), FontTileColor(pal, font_gfx(t, r, c)), bf
  next
 next

end sub


sub DrawFontText(codes as String, x as Integer, y as Integer, zoom as Integer, pal as Integer)

 'A text in FF4 character codes, drawn with the tiles as they are being edited

 for i as Integer = 1 to len(codes)
  DrawFontTile(asc(mid(codes, i, 1)), x + (i - 1) * 8 * zoom, y, zoom, pal)
 next

end sub


function FontTileChanged(t as Integer) as Boolean

 for r as Integer = 0 to 7
  for c as Integer = 0 to 7
   if font_gfx(t, r, c) <> font_orig(t, r, c) then return true
  next
 next

 return false

end function


function FontChangedCount() as Integer

 dim n as Integer

 for t as Integer = 0 to 255
  if FontTileChanged(t) then n += 1
 next

 return n

end function


function FontTileName(t as Integer) as String

 'The character a tile is, if the editor's text can type it

 for j as Integer = 33 to 126
  if asc(mid(asc2ff4, j, 1)) = t then return "Character " + chr(j)
 next
 if t = &hFF then return "Blank, the space"

 return "Icon, window piece or other"

end function


sub FontSaveUndo(t as Integer)

 if ft_undo_count = ft_undo_depth then
  for i as Integer = 1 to ft_undo_depth - 1
   ft_undo_tile(i - 1) = ft_undo_tile(i)
   for r as Integer = 0 to 7
    for c as Integer = 0 to 7
     ft_undo_pixels(i - 1, r, c) = ft_undo_pixels(i, r, c)
    next
   next
  next
  ft_undo_count -= 1
 end if

 ft_undo_tile(ft_undo_count) = t
 for r as Integer = 0 to 7
  for c as Integer = 0 to 7
   ft_undo_pixels(ft_undo_count, r, c) = font_gfx(t, r, c)
  next
 next
 ft_undo_count += 1

end sub


function FontUndo() as Integer

 'Puts back the last remembered tile and returns its number, -1 if there is nothing to undo

 dim t as Integer

 if ft_undo_count = 0 then return -1

 ft_undo_count -= 1
 t = ft_undo_tile(ft_undo_count)
 for r as Integer = 0 to 7
  for c as Integer = 0 to 7
   font_gfx(t, r, c) = ft_undo_pixels(ft_undo_count, r, c)
  next
 next

 return t

end function


sub FontPaint(t as Integer, x as Integer, y as Integer, brush as Integer)

 if font_gfx(t, y, x) <> brush then
  FontSaveUndo(t)
  font_gfx(t, y, x) = brush
 end if

end sub


sub FontRevertTile(t as Integer)

 FontSaveUndo(t)
 for r as Integer = 0 to 7
  for c as Integer = 0 to 7
   font_gfx(t, r, c) = font_orig(t, r, c)
  next
 next

end sub


sub DrawFontScreen(t as Integer, pal as Integer, mode as Integer, px as Integer, py as Integer, brush as Integer)

 'mode: 0 = choosing a tile on the sheet, 1 = editing the pixels of the tile

 dim x as Integer
 dim y as Integer
 dim changed as Integer = FontChangedCount()

 screenlock
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 'Title
 BlueBox(0, 0, 78, 1)
 WriteText(FF4Text("Tile " + str(t) + ", code " + hex(t, 2) + "   " + FontTileName(t)), 2, 1, 15)
 if mode = 1 then LuText("Pixel " + str(px) + "," + str(py), 54, 1, 14)
 LuText(str(changed) + " changed", 66, 1, iif(changed > 0, 14, 15))

 'The sheet of all 256 tiles
 BlueBox(0, 3, 48, 48)
 LuText(" ALL TILES ", 1, 3, iif(mode = 0, 21, 14))
 for i as Integer = 0 to 255
  x = ft_sheet_x + (i mod 16) * 8 * ft_sheet_zoom
  y = ft_sheet_y + (i \ 16) * 8 * ft_sheet_zoom
  DrawFontTile(i, x, y, ft_sheet_zoom, pal)
  if FontTileChanged(i) then line (x, y)-step(2, 2), RGB(255, 255, 0), bf
 next
 x = ft_sheet_x + (t mod 16) * 8 * ft_sheet_zoom
 y = ft_sheet_y + (t \ 16) * 8 * ft_sheet_zoom
 line (x - 1, y - 1)-(x + 24, y + 24), RGB(255, 255, 0), b
 line (x - 2, y - 2)-(x + 25, y + 25), RGB(0, 0, 0), b

 'The tile, big
 BlueBox(50, 3, 28, 16)
 LuText(" TILE ", 50, 3, iif(mode = 1, 21, 14))
 DrawFontTile(t, ft_big_x, ft_big_y, ft_big_zoom, pal, 1)
 if mode = 1 then
  x = ft_big_x + px * ft_big_zoom
  y = ft_big_y + py * ft_big_zoom
  line (x - 1, y - 1)-(x + ft_big_zoom - 1, y + ft_big_zoom - 1), RGB(255, 255, 0), b
  line (x, y)-(x + ft_big_zoom - 2, y + ft_big_zoom - 2), RGB(0, 0, 0), b
 end if
 for i as Integer = 0 to 3
  x = 560
  y = 40 + i * 28
  line (x, y)-(x + 23, y + 23), FontTileColor(pal, i), bf
  if i = brush then line (x - 2, y - 2)-(x + 25, y + 25), RGB(255, 255, 0), b
  LuText(str(i), 73, (48 + i * 28) \ 8, 15)
 next

 'Previews with the palette
 BlueBox(50, 21, 28, 11)
 LuText(" PREVIEW, PALETTE " + str(pal) + " ", 50, 21, 14)
 DrawFontTile(t, 416, 176, 1, pal)
 DrawFontTile(t, 432, 176, 2, pal)
 DrawFontTile(t, 456, 176, 3, pal)
 DrawFontTile(t, 488, 176, 4, pal)
 DrawFontText(FF4Text("ABCDEFGHIJKLMN"), 408, 216, 2, pal)
 DrawFontText(FF4Text("abcdefghijklmn"), 408, 232, 2, pal)
 DrawFontText(FF4Text("0123456789 !?%"), 408, 248, 2, pal)

 'Notes
 BlueBox(50, 34, 28, 17)
 LuText(" NOTES ", 50, 34, 14)
 LuText("Menus, battle windows and", 51, 36, 15)
 LuText("dialogues draw their text,", 51, 37, 15)
 LuText("icons and window frames", 51, 38, 15)
 LuText("from these tiles.", 51, 39, 15)
 LuText("A yellow dot marks a", 51, 41, 15)
 LuText("changed tile.", 51, 42, 15)
 LuText("The palette is for the", 51, 44, 15)
 LuText("preview only.", 51, 45, 15)
 LuText("This editor keeps its own", 51, 47, 15)
 LuText("font until it restarts.", 51, 48, 15)

 'Keys
 BlueBox(0, 53, 78, 2)
 if mode = 0 then
  LuText(" ACTIONS, ALL TILES ", 1, 53, 21)
  LuText("Arrows: choose a tile.  Tab: edit its pixels.  Esc: back to the main menu.", 2, 54, 15)
  LuText("Enter: the menu of every action, like flip, copy, revert and BMP export.", 2, 55, 15)
 else
  LuText(" ACTIONS, PIXELS ", 1, 53, 21)
  LuText("Arrows: move.  Space: paint.  0 to 3: color.  Tab: choose a tile.  Esc: back.", 2, 54, 15)
  LuText("Enter: the menu of every action, like flip, copy, revert and BMP export.", 2, 55, 15)
 end if
 screenunlock

end sub


function FontPath(file_name as String) as String

 mkdir system_path + "\exports"
 mkdir system_path + "\exports\font"

 return system_path + "\exports\font\" + file_name

end function


function ExportFontSheet(pal as Integer) as String

 'The 256 tiles as a 128x128 BMP in reading order, with the window palette that the editor shows

 dim colors(15) as UInteger

 for t as Integer = 0 to 255
  for r as Integer = 0 to 7
   for c as Integer = 0 to 7
    bmp_px((t \ 16) * 8 + r, (t mod 16) * 8 + c) = font_gfx(t, r, c)
   next
  next
 next
 for i as Integer = 0 to 3
  colors(i) = font_pal_raw(pal * 4 + i)
 next
 if WriteIndexedBMPColors(FontPath("font.bmp"), 128, 128, colors()) then return "Wrote font.bmp|to exports/font"

 return "Export failed|Check that exports/font can be written"

end function


function ImportFontSheet() as String

 dim new_palette(15) as UInteger
 dim problem as String

 if dir(FontPath("font.bmp")) = "" then return "No font.bmp found|in exports/font"
 if not ReadBMPWithPalette(FontPath("font.bmp"), 128, 128, 4, new_palette(), problem) then return "Import failed|" + problem

 for t as Integer = 0 to 255
  for r as Integer = 0 to 7
   for c as Integer = 0 to 7
    font_gfx(t, r, c) = bmp_px((t \ 16) * 8 + r, (t mod 16) * 8 + c)
   next
  next
 next
 ft_undo_count = 0

 return "Read font.bmp|The colors of its table are not used, a pixel is its color number 0 to 3"

end function


function FontActions(mode as Integer, byref t as Integer, byref pal as Integer, byref brush as Integer) as UInteger

 'The menu of every action of the font editor. Returns the key the chosen entry stands for, or 0 if the
 ' editor handled it here (or the menu was cancelled).

 dim choice as Integer
 dim picked as Integer
 dim names(1 to 4) as String

 SmReset()
 if mode = 0 then
  SmAdd("Edit the pixels of this tile", "Tab", 9)
 else
  SmAdd("Choose another tile", "Tab", 9)
 end if
 SmAdd("Go to a tile by number", "", 0, 1)
 SmAdd("Choose the brush color", "0 to 3", 0, 2)
 SmAdd("Flip horizontally", "X", asc("x"))
 SmAdd("Flip vertically", "Y", asc("y"))
 SmAdd("Clear the tile", "Delete", DELETE_KEY)
 SmAdd("Copy the tile", "Ctrl-C", 3)
 SmAdd("Paste the tile", "Ctrl-V", 22)
 SmAdd("Undo", "Ctrl-Z", 26)
 SmAdd("Revert this tile", "Ctrl-R", 18)
 SmAdd("Revert all tiles", "", 0, 3)
 SmAdd("Choose the preview palette", "Comma Period", 0, 4)
 SmAdd("Export all tiles as BMP", "E", asc("e"))
 SmAdd("Import all tiles from BMP", "I", asc("i"))
 SmAdd("Back to the main menu", "Esc", ESC_KEY)
 choice = SmRun("Tile " + str(t))
 if choice = 0 then return 0
 if sm_special(choice) = 0 then return sm_key(choice)

 select case sm_special(choice)
  case 1
   picked = SmNumber(t, 255)
   t = picked
  case 2
   for i as Integer = 0 to 3
    names(i + 1) = str(i)
   next
   picked = SmPick("Brush color", names(), 4, brush + 1)
   if picked > 0 then brush = picked - 1
  case 3
   if FontChangedCount() = 0 then
    InfoBox("No tile was changed.||Press any key", 20, 20)
   elseif ConfirmBox("Revert the " + str(FontChangedCount()) + " changed tiles to the loaded ROM?") then
    for i as Integer = 0 to 255
     for r as Integer = 0 to 7
      for c as Integer = 0 to 7
       font_gfx(i, r, c) = font_orig(i, r, c)
      next
     next
    next
    ft_undo_count = 0
   end if
  case 4
   for i as Integer = 0 to 3
    names(i + 1) = "Palette " + str(i)
   next
   picked = SmPick("Preview palette", names(), 4, pal + 1)
   if picked > 0 then pal = picked - 1
 end select

 return 0

end function


sub EditFont()

 dim key as String
 dim keycode as UInteger
 dim t as Integer
 dim pal as Integer
 dim mode as Integer
 dim px as Integer
 dim py as Integer
 dim brush as Integer = 3
 dim done as Boolean
 dim target as Integer

 ft_undo_count = 0
 t = 33 'the letter A is a good first tile to look at
 for i as Integer = 0 to 255
  if i = asc(mid(asc2ff4, asc("A"), 1)) then t = i
 next

 do

  DrawFontScreen(t, pal, mode, px, py, brush)

  do
   key = inkey
   if key = "" then sleep 10
  loop while key = ""
  keycode = asc(right(key, 1))
  if len(key) > 1 then keycode = keycode * &h100 + 255

  if KeyHelpPressed(keycode) then keycode = 0

  if keycode = ENTER_KEY then keycode = FontActions(mode, t, pal, brush)

  select case keycode
   case ESC_KEY
    done = true
   case 9 'Tab
    mode = 1 - mode
   case LEFT_KEY
    if mode = 0 then
     if t > 0 then t -= 1
    elseif px > 0 then
     px -= 1
    end if
   case RIGHT_KEY
    if mode = 0 then
     if t < 255 then t += 1
    elseif px < 7 then
     px += 1
    end if
   case UP_KEY
    if mode = 0 then
     if t >= 16 then t -= 16
    elseif py > 0 then
     py -= 1
    end if
   case DOWN_KEY
    if mode = 0 then
     if t < 240 then t += 16
    elseif py < 7 then
     py += 1
    end if
   case PAGEUP_KEY
    t = (t + 255) mod 256
   case PAGEDOWN_KEY
    t = (t + 1) mod 256
   case HOME_KEY
    t = 0
   case END_KEY
    t = 255
   case asc("0") to asc("3")
    brush = keycode - asc("0")
    if mode = 1 then FontPaint(t, px, py, brush)
   case SPACE_KEY
    if mode = 1 then FontPaint(t, px, py, brush)
   case asc(",")
    pal = (pal + 3) mod 4
   case asc(".")
    pal = (pal + 1) mod 4
   case asc("x"), asc("X")
    FontSaveUndo(t)
    for r as Integer = 0 to 7
     for c as Integer = 0 to 3
      swap font_gfx(t, r, c), font_gfx(t, r, 7 - c)
     next
    next
   case asc("y"), asc("Y")
    FontSaveUndo(t)
    for r as Integer = 0 to 3
     for c as Integer = 0 to 7
      swap font_gfx(t, r, c), font_gfx(t, 7 - r, c)
     next
    next
   case DELETE_KEY
    if ConfirmBox("Clear tile " + str(t) + " to color 0?") then
     FontSaveUndo(t)
     for r as Integer = 0 to 7
      for c as Integer = 0 to 7
       font_gfx(t, r, c) = 0
      next
     next
    end if
   case 3 'Ctrl-C
    for r as Integer = 0 to 7
     for c as Integer = 0 to 7
      ft_clip(r, c) = font_gfx(t, r, c)
     next
    next
    ft_clip_available = true
   case 22 'Ctrl-V
    if ft_clip_available then
     FontSaveUndo(t)
     for r as Integer = 0 to 7
      for c as Integer = 0 to 7
       font_gfx(t, r, c) = ft_clip(r, c)
      next
     next
    end if
   case 26 'Ctrl-Z
    target = FontUndo()
    if target >= 0 then t = target
   case 18 'Ctrl-R
    if FontTileChanged(t) then
     if ConfirmBox("Revert tile " + str(t) + " to the loaded ROM?") then FontRevertTile(t)
    else
     InfoBox("This tile was not changed.||Press any key", 20, 20)
    end if
   case asc("e"), asc("E")
    if ConfirmExport("all 256 tiles") then InfoBox(ExportFontSheet(pal) + "||Press any key", 4, 20)
   case asc("i"), asc("I")
    if ConfirmBox("Import replaces all 256 tiles. Continue?") then InfoBox(ImportFontSheet() + "||Press any key", 4, 20)
  end select

 loop until done

 cls

end sub
