'Menu portrait editor (the faces in the status, item and magic menus). See readportraits.bas for the
'format. The editing screen paints straight onto the 32x32 picture; the palette editor changes the
'palette of the same number, which the game also uses for the Pig, Small and Toad pictures.

const pt_undo_depth = 48
const portrait_export_width = 32 + image_strip
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


sub DrawPortraitScreen(portrait as Integer, pal as Integer, mode as Integer, pixel_x as Integer, pixel_y as Integer, brush as Integer)

 'mode: 0 = pixel editor, 1 = palette editor (brush is then the selected color)

 dim px as Integer
 dim py as Integer
 dim own_pal as Integer
 dim v as UInteger

 screenlock
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 WriteText(FF4Text(PortraitName(portrait) + "   Palette " + str(pal) + "   Pixel " + str(pixel_x) + "," + str(pixel_y)), 2, 2, 15)

 'Large picture
 DrawPortraitImage(portrait, 16, 48, 8, pal)
 if mode = 0 then
  px = 16 + pixel_x * 8
  py = 48 + pixel_y * 8
  line (px - 1, py - 1)-(px + 8, py + 8), RGB(255, 255, 0), b
  line (px, py)-(px + 7, py + 7), RGB(0, 0, 0), b
 end if

 'Actual size, double and triple size
 WriteText(FF4Text("Preview"), 40, 5, 14)
 DrawPortraitImage(portrait, 320, 48, 1, pal)
 DrawPortraitImage(portrait, 368, 48, 2, pal)
 DrawPortraitImage(portrait, 448, 48, 3, pal)

 'Every portrait
 WriteText(FF4Text("All portraits"), 40, 17, 14)
 for p as Integer = 0 to total_portraits - 1
  px = 320 + (p mod 8) * 36
  py = 152 + (p \ 8) * 36
  if p = portrait then own_pal = pal else own_pal = PortraitDefaultPalette(p)
  DrawPortraitImage(p, px, py, 1, own_pal)
  if p = portrait then line (px - 2, py - 2)-(px + 33, py + 33), RGB(255, 255, 0), b
 next

 'Palette
 for i as Integer = 0 to 7
  px = 16 + i * 34
  line (px, 320)-(px + 30, 340), PortraitColor(pal, i), bf
  if i = brush then line (px - 2, 318)-(px + 32, 342), RGB(255, 255, 0), b
  WriteText(FF4Text(str(i)), (px + 12) \ 8, 43, 15)
 next

 if mode = 1 then
  v = portrait_palette_raw(pal, brush)
  WriteText(FF4Text("Editing palette " + str(pal) + ", color " + str(brush) + IIf(brush = 0, ", transparent, not editable", "   R " + str(v mod 32) + "  G " + str((v \ 32) mod 32) + "  B " + str((v \ 1024) mod 32))), 2, 46, 14)
  WriteText(FF4Text("Left Right pick a color. Q A red, W S green, E D blue: up and down"), 2, 49, 15)
  WriteText(FF4Text("Palette " + str(pal) + " is also used by the Pig, Small and Toad pictures"), 2, 51, 15)
  WriteText(FF4Text("Ctrl-Z undo   Ctrl-R revert this palette to the loaded ROM"), 2, 53, 15)
  WriteText(FF4Text("Esc back to the picture"), 2, 55, 15)
 else
  WriteText(FF4Text("Arrows move   0-7 paint a color   Space paint with brush   F fill"), 2, 48, 15)
  WriteText(FF4Text("Comma Period change palette   P edit the palette colors"), 2, 50, 15)
  WriteText(FF4Text("X Y flip   Ctrl-C Ctrl-V copy picture   Ctrl-Z undo   R revert"), 2, 52, 15)
  WriteText(FF4Text("PgUp PgDn other portrait   Home End first last row   Esc back"), 2, 54, 15)
 end if
 screenunlock

end sub


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
    case SPACE_KEY, ENTER_KEY
     PortraitPaint(portrait, pixel_x, pixel_y, brush)
    case asc("f"), asc("F")
     PortraitFill(portrait, pixel_x, pixel_y, brush)
    case asc("["), asc("-")
     brush = (brush + 7) mod 8
    case asc("]")
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
    case asc("r"), asc("R")
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
     if channel >= 0 and channel <= 31 then
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
      portrait_palette_raw(pal, slot) = raw or (channel shl shift)
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
  bmp_px(i, portrait_export_width - 1) = i
  colors(i) = portrait_palette_raw(pal, i)
 next

 return WriteIndexedBMPColors(path, portrait_export_width, portrait_export_height, colors())

end function


function ReadPortraitBMP(path as String, portrait as Integer, pal as Integer, byref problem as String) as Boolean

 dim new_palette(15) as UInteger

 if not ReadIndexedBMP(path, portrait_export_width, portrait_export_height, problem) then return false
 if not ResolveSwatchPalette(portrait_export_width, portrait_export_height, new_palette(), problem, 8) then return false

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


function ExportPortraits() as String

 dim written as Integer
 dim failed as Integer

 for p as Integer = 0 to total_portraits - 1
  if WritePortraitBMP(PortraitPath(PortraitFileName(p, PortraitDefaultPalette(p))), p, PortraitDefaultPalette(p)) then written += 1 else failed += 1
 next

 if failed > 0 then return "Export had " + str(failed) + " error(s)|Check that exports\portraits can be written"
 return "Wrote " + str(written) + " portrait images|to exports\portraits"

end function


function ImportPortraits() as String

 dim number as Integer
 dim images_read as Integer
 dim name_found as String
 dim pal as Integer
 dim problem as String
 dim report as String

 for p as Integer = 0 to total_portraits - 1
  name_found = dir(PortraitPath("portrait_" + Pad(str(p), 2, true, "0") + "_pal_*.bmp"))
  if len(name_found) > 0 then
   pal = PortraitDefaultPalette(p)
   if len(name_found) >= 18 then
    number = val(mid(name_found, 16, 2))
    if number >= 0 and number <= 15 and mid(name_found, 16, 2) = Pad(str(number), 2, true, "0") then pal = number
   end if
   problem = ""
   if ReadPortraitBMP(PortraitPath(name_found), p, pal, problem) then
    images_read += 1
   else
    report += "|" + name_found + ": " + problem
   end if
  end if
 next

 if images_read = 0 and len(report) = 0 then return "No portrait_NN_pal_PP.bmp files found|in exports\portraits"
 return "Read " + str(images_read) + " portrait image(s)" + report

end function


sub EditPortraits()

 dim select_portrait as BlueMenu

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
      WriteText(FF4Text("Writes one BMP per portrait, portrait_NN_pal_PP.bmp,"), 37, 8, 15)
      WriteText(FF4Text("33x32. The 8 palette colors are the top right pixels,"), 37, 9, 15)
      WriteText(FF4Text("top to bottom."), 37, 10, 15)
     case else
      WriteText(FF4Text("Reads every portrait_NN_pal_PP.bmp. The top right"), 37, 8, 15)
      WriteText(FF4Text("pixels set the colors of palette PP, which other"), 37, 9, 15)
      WriteText(FF4Text("portraits of the same character share."), 37, 10, 15)
    end select
   end if
   screenunlock
  loop until select_portrait.UserInput()

  if not select_portrait.cancelled then
   if select_portrait.selected <= total_portraits then
    EditPortrait(select_portrait.selected - 1)
   elseif select_portrait.selected = total_portraits + 1 then
    InfoBox(ExportPortraits() + "||Press any key", 4, 20)
   else
    if ConfirmBox("Import replaces the current portraits and palettes. Continue?") then
     InfoBox(ImportPortraits() + "||Press any key", 4, 20)
    end if
   end if
  end if

 loop until select_portrait.cancelled

end sub
