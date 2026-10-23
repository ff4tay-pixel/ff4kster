'Menu portrait editor (the faces in the status, item and magic menus). See readportraits.bas for the
'format. The editing screen paints straight onto the 32x32 picture; the palette editor changes the
'palette of the same number, which the game also uses for the Pig, Small and Toad pictures.

const pt_undo_depth = 48
const portrait_export_width = 32
const portrait_export_height = 32

dim shared pt_undo_portrait(pt_undo_depth - 1) as Integer
dim shared pt_undo_pixels(pt_undo_depth - 1, 31, 31) as UByte
dim shared pt_undo_count as Integer
dim shared pt_clip(31, 31) as UByte
dim shared pt_clip_available as Boolean
dim shared pt_pal_undo_pal(pt_undo_depth - 1) as Integer
dim shared pt_pal_undo_slot(pt_undo_depth - 1) as Integer
dim shared pt_pal_undo_value(pt_undo_depth - 1) as UInteger
dim shared pt_pal_undo_count as Integer
dim shared pt_fill_x(1023) as Integer
dim shared pt_fill_y(1023) as Integer


function PortraitColor(pal as Integer, index as Integer) as UInteger

 dim v as UInteger

 if index = 0 then return bs_transparent
 v = portrait_palette_raw(pal, index)
 return RGB((v mod 32) * 8, ((v \ 32) mod 32) * 8, ((v \ 1024) mod 32) * 8)

end function


sub DrawPortraitImage(portrait as Integer, x as Integer, y as Integer, zoom as Integer, pal as Integer)

 for row as Integer = 0 to 31
  for col as Integer = 0 to 31
   line (x + col * zoom, y + row * zoom)-step(zoom - 1, zoom - 1), PortraitColor(pal, portrait_gfx(portrait, row, col)), bf
  next
 next

end sub


sub PortraitSaveUndo(portrait as Integer)

 if pt_undo_count = pt_undo_depth then
  for i as Integer = 1 to pt_undo_depth - 1
   pt_undo_portrait(i - 1) = pt_undo_portrait(i)
   for r as Integer = 0 to 31
    for c as Integer = 0 to 31
     pt_undo_pixels(i - 1, r, c) = pt_undo_pixels(i, r, c)
    next
   next
  next
  pt_undo_count -= 1
 end if

 pt_undo_portrait(pt_undo_count) = portrait
 for r as Integer = 0 to 31
  for c as Integer = 0 to 31
   pt_undo_pixels(pt_undo_count, r, c) = portrait_gfx(portrait, r, c)
  next
 next
 pt_undo_count += 1

end sub


function PortraitUndo() as Integer

 'Puts back the last remembered picture and returns its number, or -1 if there is nothing to undo

 dim portrait as Integer

 if pt_undo_count = 0 then return -1

 pt_undo_count -= 1
 portrait = pt_undo_portrait(pt_undo_count)
 for r as Integer = 0 to 31
  for c as Integer = 0 to 31
   portrait_gfx(portrait, r, c) = pt_undo_pixels(pt_undo_count, r, c)
  next
 next

 return portrait

end function


sub PortraitPaint(portrait as Integer, x as Integer, y as Integer, brush as Integer)

 if portrait_gfx(portrait, y, x) <> brush then
  PortraitSaveUndo(portrait)
  portrait_gfx(portrait, y, x) = brush
 end if

end sub


sub PortraitFill(portrait as Integer, x as Integer, y as Integer, brush as Integer)

 'Flood fill of the pixels with the same color as the one under the cursor

 dim old as Integer = portrait_gfx(portrait, y, x)
 dim count as Integer = 0
 dim cx as Integer
 dim cy as Integer
 dim nx as Integer
 dim ny as Integer

 if old = brush then exit sub

 PortraitSaveUndo(portrait)
 portrait_gfx(portrait, y, x) = brush
 pt_fill_x(0) = x
 pt_fill_y(0) = y
 count = 1

 do while count > 0
  count -= 1
  cx = pt_fill_x(count)
  cy = pt_fill_y(count)
  for d as Integer = 0 to 3
   nx = cx
   ny = cy
   select case d
    case 0: nx -= 1
    case 1: nx += 1
    case 2: ny -= 1
    case else: ny += 1
   end select
   if nx >= 0 and nx <= 31 and ny >= 0 and ny <= 31 then
    if portrait_gfx(portrait, ny, nx) = old then
     portrait_gfx(portrait, ny, nx) = brush
     pt_fill_x(count) = nx
     pt_fill_y(count) = ny
     count += 1
    end if
   end if
  next
 loop

end sub


function PortraitColorRole(index as Integer) as String

 'What the color usually is in the portraits, "" if it has no fixed use

 select case index
  case 0: return "transparent"
  case 1: return "white"
  case 2: return "skin"
  case 3: return "skin shadow"
 end select

 return ""

end function


function PortraitColorTag(index as Integer) as String

 select case index
  case 0: return "Clr"
  case 1: return "Wht"
  case 2: return "Skn"
  case 3: return "Shd"
 end select

 return ""

end function


sub PortraitMoveColor(pal as Integer, slot as Integer, other as Integer)

 'Swaps two palette colors and renumbers the pixels of the portraits that use this palette,
 ' so that they look the same. Those are the portraits with the palette's own number.

 dim v as UInteger = portrait_palette_raw(pal, slot)
 dim c as Integer

 portrait_palette_raw(pal, slot) = portrait_palette_raw(pal, other)
 portrait_palette_raw(pal, other) = v

 for p as Integer = 0 to total_portraits - 1
  if PortraitDefaultPalette(p) = pal then
   for r as Integer = 0 to 31
    for col as Integer = 0 to 31
     c = portrait_gfx(p, r, col)
     if c = slot then
      portrait_gfx(p, r, col) = other
     elseif c = other then
      portrait_gfx(p, r, col) = slot
     end if
    next
   next
  end if
 next

 pt_undo_count = 0
 pt_pal_undo_count = 0

end sub


sub DrawPortraitScreen(portrait as Integer, pal as Integer, mode as Integer, pixel_x as Integer, pixel_y as Integer, brush as Integer)

 'mode: 0 = pixel editor, 1 = palette editor (brush is then the selected color)
 'Windows like the rest of the editor: title, picture, preview, all portraits, palette, color details and the keys

 dim px as Integer
 dim py as Integer
 dim own_pal as Integer
 dim v as UInteger
 dim role as String

 screenlock
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 'Title
 BlueBox(0, 0, 78, 1)
 WriteText(FF4Text(PortraitName(portrait) + "   Palette " + str(pal)), 2, 1, 15)
 LuText("Pixel " + str(pixel_x) + "," + str(pixel_y), 66, 1, 14)

 'Large picture
 BlueBox(0, 3, 34, 34)
 LuText(" PICTURE ", 1, 3, 14)
 DrawPortraitImage(portrait, 16, 40, 8, pal)
 if mode = 0 then
  px = 16 + pixel_x * 8
  py = 40 + pixel_y * 8
  line (px - 1, py - 1)-(px + 8, py + 8), RGB(255, 255, 0), b
  line (px, py)-(px + 7, py + 7), RGB(0, 0, 0), b
 end if

 'Actual size, double and triple size
 BlueBox(37, 3, 41, 15)
 LuText(" PREVIEW ", 38, 3, 14)
 DrawPortraitImage(portrait, 320, 40, 1, pal)
 DrawPortraitImage(portrait, 368, 40, 2, pal)
 DrawPortraitImage(portrait, 448, 40, 3, pal)

 'Every portrait
 BlueBox(37, 20, 41, 16)
 LuText(" ALL PORTRAITS ", 38, 20, 14)
 for p as Integer = 0 to total_portraits - 1
  px = 320 + (p mod 8) * 36
  py = 176 + (p \ 8) * 36
  if p = portrait then own_pal = pal else own_pal = PortraitDefaultPalette(p)
  DrawPortraitImage(p, px, py, 1, own_pal)
  if p = portrait then line (px - 2, py - 2)-(px + 33, py + 33), RGB(255, 255, 0), b
 next

 'Palette
 BlueBox(0, 39, 34, 6)
 LuText(" PALETTE " + str(pal) + " ", 1, 39, iif(mode = 1, 21, 14))
 for i as Integer = 0 to 7
  px = 16 + i * 32
  line (px, 328)-(px + 28, 348), PortraitColor(pal, i), bf
  if i = brush then line (px - 2, 326)-(px + 30, 350), RGB(255, 255, 0), b
  LuText(str(i), (px + 12) \ 8, 44, 15)
  if len(PortraitColorTag(i)) > 0 then LuText(PortraitColorTag(i), (px + 4) \ 8, 45, 14)
 next

 'The color the brush is on
 BlueBox(37, 38, 41, 7)
 LuText(" COLOR ", 38, 38, iif(mode = 1, 21, 14))
 v = portrait_palette_raw(pal, brush)
 role = PortraitColorRole(brush)
 LuText("Color " + str(brush) + iif(len(role) > 0, ", " + role, ""), 39, 40, 15)
 if brush = 0 then
  LuText("Transparent, not editable", 39, 41, 23)
 else
  LuText("R " + str(v mod 32) + "   G " + str((v \ 32) mod 32) + "   B " + str((v \ 1024) mod 32), 39, 41, 23)
 end if
 if mode = 1 then LuText("Palette " + str(pal) + " is also used by the Pig, Small and Toad pictures", 39, 43, 14)

 'Keys
 BlueBox(0, 47, 78, 6)
 if mode = 1 then
  LuText(" ACTIONS, PALETTE ", 1, 47, 21)
  LuText("Left Right: pick the color to change.", 2, 49, 15)
  LuText("Enter: the menu to change its red, green and blue, move it, undo and more.", 2, 50, 15)
  LuText("Esc: back to the picture.", 2, 51, 15)
 else
  LuText(" ACTIONS, PICTURE ", 1, 47, 14)
  LuText("Arrows: move.   Space: paint with the brush color.", 2, 49, 15)
  LuText("Enter: the menu of every action, like fill, flip, copy, palette and export.", 2, 50, 15)
  LuText("The menu shows each action's key, so the keys can be learned as you go.", 2, 51, 15)
  LuText("Esc: back to the list.", 2, 52, 15)
 end if
 screenunlock

end sub


sub PortraitSetChannel(pal as Integer, slot as Integer, shift as Integer, value as Integer)

 'Sets the red (shift 0), green (5) or blue (10) of a palette color to 0 to 31, remembering the old color for undo

 dim raw as Integer

 if value < 0 or value > 31 then exit sub

 if pt_pal_undo_count = pt_undo_depth then
  for i as Integer = 1 to pt_undo_depth - 1
   pt_pal_undo_pal(i - 1) = pt_pal_undo_pal(i)
   pt_pal_undo_slot(i - 1) = pt_pal_undo_slot(i)
   pt_pal_undo_value(i - 1) = pt_pal_undo_value(i)
  next
  pt_pal_undo_count -= 1
 end if
 pt_pal_undo_pal(pt_pal_undo_count) = pal
 pt_pal_undo_slot(pt_pal_undo_count) = slot
 pt_pal_undo_value(pt_pal_undo_count) = portrait_palette_raw(pal, slot)
 pt_pal_undo_count += 1
 raw = portrait_palette_raw(pal, slot) and not (31 shl shift)
 portrait_palette_raw(pal, slot) = raw or (value shl shift)

end sub


function PortraitActions(mode as Integer, byref portrait as Integer, byref pal as Integer, byref brush as Integer, byref slot as Integer) as UInteger

 'The menu of every action of the portrait editor. Returns the key the chosen entry stands for, or 0 if the
 ' editor handled it here (or the menu was cancelled).

 dim choice as Integer
 dim picked as Integer
 dim names(1 to 32) as String
 dim count as Integer

 SmReset()
 if mode = 0 then
  SmAdd("Fill with the brush color", "F", asc("f"))
  SmAdd("Choose the brush color", "0 to 7", 0, 1)
  SmAdd("Flip horizontally", "X", asc("x"))
  SmAdd("Flip vertically", "Y", asc("y"))
  SmAdd("Copy the picture", "Ctrl-C", 3)
  SmAdd("Paste the picture", "Ctrl-V", 22)
  SmAdd("Undo", "Ctrl-Z", 26)
  SmAdd("Revert this portrait", "Ctrl-R", 18)
  SmAdd("Edit the palette colors", "P", asc("p"))
  SmAdd("Choose the palette", "Comma Period", 0, 2)
  SmAdd("Previous portrait", "PgUp", PAGEUP_KEY)
  SmAdd("Next portrait", "PgDn", PAGEDOWN_KEY)
  SmAdd("Go to a portrait", "", 0, 3)
  SmAdd("Export this portrait as BMP", "E", asc("e"))
  SmAdd("Import this portrait from BMP", "I", asc("i"))
  SmAdd("Back to the list", "Esc", ESC_KEY)
  choice = SmRun("Portrait")
 else
  SmAdd("Choose the color", "Left Right", 0, 11)
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
   for i as Integer = 0 to 7
    names(i + 1) = str(i) + " " + PortraitColorTag(i)
   next
   picked = SmPick("Brush color", names(), 8, brush + 1)
   if picked > 0 then brush = picked - 1

  case 2 'palette
   for i as Integer = 0 to 15
    names(i + 1) = "Palette " + str(i)
   next
   picked = SmPick("Palette", names(), 16, pal + 1)
   if picked > 0 then pal = picked - 1

  case 3 'portrait
   for i as Integer = 0 to total_portraits - 1
    names(i + 1) = PortraitName(i)
   next
   picked = SmPick("Portrait", names(), total_portraits, portrait + 1)
   if picked > 0 then
    portrait = picked - 1
    pal = PortraitDefaultPalette(portrait)
   end if

  case 11 'color of the palette
   for i as Integer = 1 to 7
    names(i) = str(i) + " " + PortraitColorTag(i)
   next
   picked = SmPick("Color", names(), 7, slot)
   if picked > 0 then slot = picked

  case 12 to 14 'red, green, blue
   count = (sm_special(choice) - 12) * 5
   picked = SmNumber((portrait_palette_raw(pal, slot) \ (2 ^ count)) mod 32, 31)
   PortraitSetChannel(pal, slot, count, picked)

 end select

 return 0

end function


declare function ExportPortrait(p as Integer, pal as Integer) as String
declare function ImportOnePortrait(p as Integer) as String


sub EditPortrait(portrait_start as Integer)

 dim key as String
 dim keycode as UInteger
 dim portrait as Integer = portrait_start
 dim pal as Integer = PortraitDefaultPalette(portrait_start)
 dim mode as Integer = 0 '0 = pixel editor, 1 = palette editor
 dim pixel_x as Integer = 16
 dim pixel_y as Integer = 16
 dim brush as Integer = 1
 dim slot as Integer = 1
 dim shift as Integer
 dim channel as Integer
 dim raw as Integer
 dim done as Boolean = false
 dim target as Integer

 pt_undo_count = 0
 pt_pal_undo_count = 0

 do

  DrawPortraitScreen(portrait, pal, mode, pixel_x, pixel_y, iif(mode = 1, slot, brush))

  do
   key = inkey
   if key = "" then sleep 10
  loop while key = ""
  keycode = asc(right(key, 1))
  if len(key) > 1 then keycode = keycode * &h100 + 255

 if KeyHelpPressed(keycode) then keycode = 0

  'Enter opens the menu of every action; the entries that stand for a key are handled as that key
  if keycode = ENTER_KEY then keycode = PortraitActions(mode, portrait, pal, brush, slot)

  if mode = 0 then

   select case keycode
    case ESC_KEY
     done = true
    case LEFT_KEY
     if pixel_x > 0 then pixel_x -= 1
    case RIGHT_KEY
     if pixel_x < 31 then pixel_x += 1
    case UP_KEY
     if pixel_y > 0 then pixel_y -= 1
    case DOWN_KEY
     if pixel_y < 31 then pixel_y += 1
    case HOME_KEY
     pixel_y = 0
    case END_KEY
     pixel_y = 31
    case asc("0") to asc("7")
     brush = keycode - asc("0")
     PortraitPaint(portrait, pixel_x, pixel_y, brush)
    case SPACE_KEY
     PortraitPaint(portrait, pixel_x, pixel_y, brush)
    case asc("f"), asc("F")
     PortraitFill(portrait, pixel_x, pixel_y, brush)
    case asc("e"), asc("E")
     if ConfirmExport("this portrait") then InfoBox(ExportPortrait(portrait, pal) + "||Press any key", 4, 20)
    case asc("i"), asc("I")
     if ConfirmBox("Import replaces this portrait and its palette. Continue?") then
      InfoBox(ImportOnePortrait(portrait) + "||Press any key", 4, 20)
      pt_undo_count = 0
      pt_pal_undo_count = 0
     end if
    case asc("["), asc("-")
     brush = (brush + 7) mod 8
    case asc("]"), asc("="), asc("+")
     brush = (brush + 1) mod 8
    case asc("x"), asc("X") 'Flip horizontally
     PortraitSaveUndo(portrait)
     for r as Integer = 0 to 31
      for c as Integer = 0 to 15
       swap portrait_gfx(portrait, r, c), portrait_gfx(portrait, r, 31 - c)
      next
     next
    case asc("y"), asc("Y") 'Flip vertically
     PortraitSaveUndo(portrait)
     for r as Integer = 0 to 15
      for c as Integer = 0 to 31
       swap portrait_gfx(portrait, r, c), portrait_gfx(portrait, 31 - r, c)
      next
     next
    case 3 'Ctrl-C
     for r as Integer = 0 to 31
      for c as Integer = 0 to 31
       pt_clip(r, c) = portrait_gfx(portrait, r, c)
      next
     next
     pt_clip_available = true
    case 22 'Ctrl-V
     if pt_clip_available then
      PortraitSaveUndo(portrait)
      for r as Integer = 0 to 31
       for c as Integer = 0 to 31
        portrait_gfx(portrait, r, c) = pt_clip(r, c)
       next
      next
     end if
    case 26 'Ctrl-Z
     target = PortraitUndo()
     if target >= 0 then
      if target <> portrait then pal = PortraitDefaultPalette(target)
      portrait = target
     end if
    case asc("p"), asc("P")
     mode = 1
    case asc(",")
     pal = (pal + 15) mod 16
    case asc(".")
     pal = (pal + 1) mod 16
    case PAGEUP_KEY
     portrait = (portrait + total_portraits - 1) mod total_portraits
     pal = PortraitDefaultPalette(portrait)
    case PAGEDOWN_KEY
     portrait = (portrait + 1) mod total_portraits
     pal = PortraitDefaultPalette(portrait)
    case 18 'Ctrl-R
     if ConfirmBox("Revert this portrait to the loaded ROM?") then
      PortraitSaveUndo(portrait)
      DecodePortrait(original_rom, portrait)
     end if
   end select

  else

   select case keycode
    case ESC_KEY
     mode = 0
    case LEFT_KEY
     if slot > 1 then slot -= 1
    case RIGHT_KEY
     if slot < 7 then slot += 1
    case asc("q"), asc("Q"), asc("a"), asc("A"), asc("w"), asc("W"), asc("s"), asc("S"), asc("e"), asc("E"), asc("d"), asc("D")
     select case keycode and &hDF
      case asc("Q"), asc("A"): shift = 0
      case asc("W"), asc("S"): shift = 5
      case else: shift = 10
     end select
     channel = (portrait_palette_raw(pal, slot) \ (2 ^ shift)) mod 32
     select case keycode and &hDF
      case asc("Q"), asc("W"), asc("E"): channel += 1
      case else: channel -= 1
     end select
     PortraitSetChannel(pal, slot, shift, channel)
    case asc("["), asc("]")
     target = slot + iif(keycode = asc("["), -1, 1)
     if target >= 1 and target <= 7 then
      PortraitMoveColor(pal, slot, target)
      slot = target
     end if
    case 26 'Ctrl-Z
     if pt_pal_undo_count > 0 then
      pt_pal_undo_count -= 1
      portrait_palette_raw(pt_pal_undo_pal(pt_pal_undo_count), pt_pal_undo_slot(pt_pal_undo_count)) = pt_pal_undo_value(pt_pal_undo_count)
     end if
    case 18 'Ctrl-R
     if ConfirmBox("Revert this palette to the loaded ROM?") then
      for j as Integer = 0 to 7
       portrait_palette_raw(pal, j) = asc(mid(original_rom, portrait_palette_table + pal * 16 + j * 2 + 1, 1)) + asc(mid(original_rom, portrait_palette_table + pal * 16 + j * 2 + 2, 1)) * &h100
      next
      pt_pal_undo_count = 0
     end if
   end select

  end if

 loop until done

end sub


function PortraitPath(file_name as String) as String

 mkdir system_path + "\exports"
 mkdir system_path + "\exports\portraits"

 return system_path + "\exports\portraits\" + file_name

end function


function PortraitFileName(portrait as Integer, pal as Integer) as String

 return "portrait_" + Pad(str(portrait), 2, true, "0") + "_pal_" + Pad(str(pal), 2, true, "0") + ".bmp"

end function


function WritePortraitBMP(path as String, portrait as Integer, pal as Integer) as Boolean

 dim colors(15) as UInteger

 for y as Integer = 0 to portrait_export_height - 1
  for x as Integer = 0 to portrait_export_width - 1
   if x < 32 then bmp_px(y, x) = portrait_gfx(portrait, y, x) else bmp_px(y, x) = 0
  next
 next
 for i as Integer = 0 to 7
  colors(i) = portrait_palette_raw(pal, i)
 next

 return WriteIndexedBMPColors(path, portrait_export_width, portrait_export_height, colors())

end function


function ReadPortraitBMP(path as String, portrait as Integer, pal as Integer, byref problem as String) as Boolean

 dim new_palette(15) as UInteger

 for i as Integer = 0 to 7
  new_palette(i) = portrait_palette_raw(pal, i)
 next
 if not ReadBMPWithPalette(path, portrait_export_width, portrait_export_height, 8, new_palette(), problem) then return false

 for y as Integer = 0 to 31
  for x as Integer = 0 to 31
   portrait_gfx(portrait, y, x) = bmp_px(y, x)
  next
 next
 for i as Integer = 1 to 7
  portrait_palette_raw(pal, i) = new_palette(i)
 next

 return true

end function


function ExportPortrait(p as Integer, pal as Integer) as String

 'One portrait, with the palette the editor is showing. Returns a message for the user

 if WritePortraitBMP(PortraitPath(PortraitFileName(p, pal)), p, pal) then return "Wrote " + PortraitFileName(p, pal) + "|to exports\portraits"

 return "Export failed|Check that exports\portraits can be written"

end function


function ExportPortraits() as String

 dim written as Integer
 dim failed as Integer

 for p as Integer = 0 to total_portraits - 1
  if WritePortraitBMP(PortraitPath(PortraitFileName(p, PortraitDefaultPalette(p))), p, PortraitDefaultPalette(p)) then written += 1 else failed += 1
 next

 if failed > 0 then return "Export had " + str(failed) + " error(s)|Check that exports\portraits can be written"
 return "Wrote " + str(written) + " portrait images|to exports\portraits"

end function


function ImportPortraitImage(p as Integer, byref report as String) as Integer

 'Reads portrait_NN_pal_*.bmp of portrait p. Returns 1 if it was read, 0 if there is no such file, -1 if it
 ' could not be read. Problems are added to report.

 dim number as Integer
 dim name_found as String
 dim pal as Integer = PortraitDefaultPalette(p)
 dim problem as String

 name_found = dir(PortraitPath("portrait_" + Pad(str(p), 2, true, "0") + "_pal_*.bmp"))
 if len(name_found) = 0 then return 0

 if len(name_found) >= 18 then
  number = val(mid(name_found, 17, 2))
  if number >= 0 and number <= 15 and mid(name_found, 17, 2) = Pad(str(number), 2, true, "0") then pal = number
 end if
 if ReadPortraitBMP(PortraitPath(name_found), p, pal, problem) then return 1
 report += "|" + name_found + ": " + problem

 return -1

end function


function ImportOnePortrait(p as Integer) as String

 dim report as String

 select case ImportPortraitImage(p, report)
  case 0
   return "No portrait_" + Pad(str(p), 2, true, "0") + "_pal_PP.bmp found|in exports\portraits"
  case 1
   return "Read the portrait image" + report
 end select

 return "Import failed" + report

end function


function ImportPortraits() as String

 dim images_read as Integer
 dim report as String

 for p as Integer = 0 to total_portraits - 1
  if ImportPortraitImage(p, report) = 1 then images_read += 1
 next

 if images_read = 0 and len(report) = 0 then return "No portrait_NN_pal_PP.bmp files found|in exports\portraits"
 return "Read " + str(images_read) + " portrait image(s)" + report

end function


function PickPortrait(title as String) as Integer

 'All portraits (0) or one of them (its number plus 1). Returns -1 if cancelled.

 dim m as BlueMenu

 m = BlueMenu(4, 6)
 m.max_rows = 20
 m.title = title
 m.AddOption(FF4Text("All portraits"))
 for i as Integer = 0 to total_portraits - 1
  m.AddOption(FF4Text(PortraitName(i)))
 next
 m.UserSelect()
 if m.cancelled then return -1

 return m.selected - 1

end function


sub EditPortraits()

 dim select_portrait as BlueMenu
 dim which as Integer

 select_portrait.max_rows = total_portraits + 2
 for i as Integer = 0 to total_portraits - 1
  select_portrait.AddOption(FF4Text(PortraitName(i)))
 next
 select_portrait.AddOption(FF4Text("Export portraits"))
 select_portrait.AddOption(FF4Text("Import portraits"))

 do

  do
   screenlock
   line (0, 0)-(639, 463), RGB(0, 0, 0), bf
   WriteText(FF4Text("Pick a portrait, Enter to edit"), 0, 0, 15)
   select_portrait.y = 2
   select_portrait.Display()
   if select_portrait.selected <= total_portraits then
    DrawPortraitImage(select_portrait.selected - 1, 300, 64, 6, PortraitDefaultPalette(select_portrait.selected - 1))
   else
    select case select_portrait.selected - total_portraits
     case 1
      WriteText(FF4Text("Enter asks for all portraits or just one."), 37, 7, 15)
      WriteText(FF4Text("Writes one BMP per portrait, portrait_NN_pal_PP.bmp,"), 37, 8, 15)
      WriteText(FF4Text("32x32. The palette is the BMP's own color table,"), 37, 9, 15)
      WriteText(FF4Text("colors 0 to 7."), 37, 10, 15)
     case else
      WriteText(FF4Text("Enter asks for all portraits or just one."), 37, 7, 15)
      WriteText(FF4Text("Reads portrait_NN_pal_PP.bmp. Its color table"), 37, 8, 15)
      WriteText(FF4Text("sets the colors of palette PP, which other"), 37, 9, 15)
      WriteText(FF4Text("portraits of the same character share."), 37, 10, 15)
    end select
   end if
   screenunlock
  loop until select_portrait.UserInput()

  if not select_portrait.cancelled then
   if select_portrait.selected <= total_portraits then
    EditPortrait(select_portrait.selected - 1)
   elseif select_portrait.selected = total_portraits + 1 then
    which = PickPortrait("Export which portrait?")
    if which = 0 then
     if ConfirmExport("all portraits") then InfoBox(ExportPortraits() + "||Press any key", 4, 20)
    elseif which > 0 then
     if ConfirmExport("that portrait") then InfoBox(ExportPortrait(which - 1, PortraitDefaultPalette(which - 1)) + "||Press any key", 4, 20)
    end if
   else
    which = PickPortrait("Import which portrait?")
    if which >= 0 then
     if ConfirmBox("Import replaces the current portraits and palettes. Continue?") then
      if which = 0 then
       InfoBox(ImportPortraits() + "||Press any key", 4, 20)
      else
       InfoBox(ImportOnePortrait(which - 1) + "||Press any key", 4, 20)
      end if
     end if
    end if
   end if
  end if

 loop until select_portrait.cancelled

end sub
