'The field sprite editor. See readfieldsprites.bas for the format. The list of sheets is on the left, with a window
'that shows every frame of the selected sheet, the palette, which NPCs use it and where it is in the ROM. Enter edits
'the sheet: the picture of the whole sheet (frames four to a row) is painted pixel by pixel like the portraits, a
'frame can be flipped, copied and pasted, the palette colors are edited in a second mode and a sheet can be
'exported to and imported from a BMP. Sheets have a fixed size in the ROM, so nothing here changes a size.

declare function FieldUsedText(sheet as Integer) as String


function FieldColor(pal as Integer, index as Integer) as UInteger

 dim v as UInteger

 if index = 0 then return bs_transparent
 v = field_palette_raw(pal, index)
 return RGB((v mod 32) * 8, ((v \ 32) mod 32) * 8, ((v \ 1024) mod 32) * 8)

end function


sub DrawFieldFrame(sheet as Integer, frame as Integer, x as Integer, y as Integer, zoom as Integer, pal as Integer)

 'One 16x16 frame: its four tiles are top left, top right, bottom left, bottom right

 dim tile_index as Integer

 for k as Integer = 0 to 3
  tile_index = frame * 4 + k
  for row as Integer = 0 to 7
   for col as Integer = 0 to 7
    line (x + ((k mod 2) * 8 + col) * zoom, y + ((k \ 2) * 8 + row) * zoom)-step(zoom - 1, zoom - 1), FieldColor(pal, field_sprite_gfx(sheet, tile_index, row, col)), bf
   next
  next
 next

end sub


function FieldSheetUsers(sheet as Integer) as String

 'The NPCs (their numbers in the NPCs editor) that use this sheet

 dim s as String
 dim n as Integer = 0

 for i as Integer = 0 to total_npcs
  if npcs(i).sprite = sheet then
   n += 1
   if n <= 5 then
    if n > 1 then s += ", "
    s += str(i)
   end if
  end if
 next
 if n = 0 then return "none"
 if n > 5 then s += " and " + str(n - 5) + " more"

 return s

end function


sub DrawFieldSpriteScreen(sheet as Integer, pal as Integer)

 dim frames as Integer = FieldSheetTiles(sheet) \ 4
 dim px as Integer
 dim py as Integer

 BlueBox(30, 0, 48, 1)
 WriteText(FF4Text("Sheet " + str(sheet) + "   Palette " + str(pal) + iif(field_palette_pick(sheet) >= 0, ", picked", "")), 32, 1, 15)

 'Every frame, four times as large
 BlueBox(30, 3, 48, 20)
 LuText(" FRAMES ", 31, 3, 14)
 for f as Integer = 0 to frames - 1
  px = 256 + (f mod 4) * 72
  py = 40 + (f \ 4) * 72
  DrawFieldFrame(sheet, f, px, py, 4, pal)
 next

 'Actual size and double size
 BlueBox(30, 24, 48, 7)
 LuText(" REAL SIZE ", 31, 24, 14)
 for f as Integer = 0 to frames - 1
  DrawFieldFrame(sheet, f, 256 + f * 18, 208, 1, pal)
  DrawFieldFrame(sheet, f, 256 + f * 36, 228, 2, pal)
 next

 'Palette
 BlueBox(30, 32, 48, 6)
 LuText(" PALETTE " + str(pal) + " ", 31, 32, 14)
 for i as Integer = 0 to 7
  px = 256 + i * 36
  line (px, 272)-(px + 30, 288), FieldColor(pal, i), bf
  LuText(str(i), (px + 12) \ 8, 37, 15)
 next

 'Where it is
 BlueBox(30, 39, 48, 8)
 LuText(" SHEET ", 31, 39, 14)
 LuText(str(frames) + " frames, " + str(FieldSheetTiles(sheet)) + " tiles, " + str(FieldSheetTiles(sheet) * 24) + " bytes", 32, 41, 15)
 LuText("Starts at file offset " + hex(FieldSheetOffset(sheet) - &h200, 6), 32, 42, 15)
 LuText("NPC numbers: " + FieldSheetUsers(sheet), 32, 43, 15)
 LuText("Maps use it with: " + FieldUsedText(sheet), 32, 45, 15)

 'Keys
 BlueBox(30, 48, 48, 6)
 LuText(" ACTIONS ", 31, 48, 14)
 LuText("Up Down: pick a sheet.   Esc: back.", 32, 50, 15)
 LuText("Enter: edit this sheet.", 32, 51, 15)
 LuText("Palettes are the map's choice: pick one to see.", 32, 52, 15)

end sub


const fe_undo_depth = 48

dim shared fe_undo_sheet(fe_undo_depth - 1) as Integer
dim shared fe_undo_pixels(fe_undo_depth - 1, 31, 7, 7) as UByte
dim shared fe_undo_count as Integer
dim shared fe_clip(15, 15) as UByte
dim shared fe_clip_available as Boolean
dim shared fe_pal_undo_pal(fe_undo_depth - 1) as Integer
dim shared fe_pal_undo_slot(fe_undo_depth - 1) as Integer
dim shared fe_pal_undo_value(fe_undo_depth - 1) as UInteger
dim shared fe_pal_undo_count as Integer
dim shared fe_picks_changed as Boolean
dim shared fe_fill_x(2047) as Integer
dim shared fe_fill_y(2047) as Integer


function FieldSheetCols(sheet as Integer) as Integer

 'The frames of a sheet are shown four to a row

 return Min(FieldSheetTiles(sheet) \ 4, 4)

end function


function FieldSheetWidth(sheet as Integer) as Integer

 return FieldSheetCols(sheet) * 16

end function


function FieldSheetHeight(sheet as Integer) as Integer

 return ((FieldSheetTiles(sheet) \ 4 + FieldSheetCols(sheet) - 1) \ FieldSheetCols(sheet)) * 16

end function


sub FieldPixelPlace(sheet as Integer, x as Integer, y as Integer, byref tile_index as Integer, byref row as Integer, byref col as Integer)

 'Where the pixel x, y of the picture of the whole sheet is stored: which tile, and its row and column

 dim frame as Integer = (y \ 16) * FieldSheetCols(sheet) + x \ 16

 tile_index = frame * 4 + ((y mod 16) \ 8) * 2 + (x mod 16) \ 8
 row = y mod 8
 col = x mod 8

end sub


function FieldGetPixel(sheet as Integer, x as Integer, y as Integer) as Integer

 dim tile_index as Integer
 dim row as Integer
 dim col as Integer

 FieldPixelPlace(sheet, x, y, tile_index, row, col)

 return field_sprite_gfx(sheet, tile_index, row, col)

end function


sub FieldSetPixel(sheet as Integer, x as Integer, y as Integer, c as Integer)

 dim tile_index as Integer
 dim row as Integer
 dim col as Integer

 FieldPixelPlace(sheet, x, y, tile_index, row, col)
 field_sprite_gfx(sheet, tile_index, row, col) = c

end sub


function FieldFrameAt(sheet as Integer, x as Integer, y as Integer) as Integer

 return (y \ 16) * FieldSheetCols(sheet) + x \ 16

end function


sub DrawFieldPicture(sheet as Integer, x as Integer, y as Integer, zoom as Integer, pal as Integer)

 'Every frame of the sheet, four to a row

 dim cols as Integer = FieldSheetCols(sheet)

 for f as Integer = 0 to FieldSheetTiles(sheet) \ 4 - 1
  DrawFieldFrame(sheet, f, x + (f mod cols) * 16 * zoom, y + (f \ cols) * 16 * zoom, zoom, pal)
 next

end sub


sub FieldSaveUndo(sheet as Integer)

 if fe_undo_count = fe_undo_depth then
  for i as Integer = 1 to fe_undo_depth - 1
   fe_undo_sheet(i - 1) = fe_undo_sheet(i)
   for t as Integer = 0 to 31
    for r as Integer = 0 to 7
     for c as Integer = 0 to 7
      fe_undo_pixels(i - 1, t, r, c) = fe_undo_pixels(i, t, r, c)
     next
    next
   next
  next
  fe_undo_count -= 1
 end if

 fe_undo_sheet(fe_undo_count) = sheet
 for t as Integer = 0 to 31
  for r as Integer = 0 to 7
   for c as Integer = 0 to 7
    fe_undo_pixels(fe_undo_count, t, r, c) = field_sprite_gfx(sheet, t, r, c)
   next
  next
 next
 fe_undo_count += 1

end sub


function FieldUndo() as Integer

 'Puts back the last remembered sheet and returns its number, or -1 if there is nothing to undo

 dim sheet as Integer

 if fe_undo_count = 0 then return -1

 fe_undo_count -= 1
 sheet = fe_undo_sheet(fe_undo_count)
 for t as Integer = 0 to 31
  for r as Integer = 0 to 7
   for c as Integer = 0 to 7
    field_sprite_gfx(sheet, t, r, c) = fe_undo_pixels(fe_undo_count, t, r, c)
   next
  next
 next

 return sheet

end function


sub FieldPaint(sheet as Integer, x as Integer, y as Integer, brush as Integer)

 if FieldGetPixel(sheet, x, y) <> brush then
  FieldSaveUndo(sheet)
  FieldSetPixel(sheet, x, y, brush)
 end if

end sub


sub FieldFill(sheet as Integer, x as Integer, y as Integer, brush as Integer)

 'Flood fill of the pixels with the same color as the one under the cursor, inside the picture of the sheet

 dim old as Integer = FieldGetPixel(sheet, x, y)
 dim count as Integer = 0
 dim cx as Integer
 dim cy as Integer
 dim nx as Integer
 dim ny as Integer

 if old = brush then exit sub

 FieldSaveUndo(sheet)
 FieldSetPixel(sheet, x, y, brush)
 fe_fill_x(0) = x
 fe_fill_y(0) = y
 count = 1

 do while count > 0
  count -= 1
  cx = fe_fill_x(count)
  cy = fe_fill_y(count)
  for d as Integer = 0 to 3
   nx = cx
   ny = cy
   select case d
    case 0: nx -= 1
    case 1: nx += 1
    case 2: ny -= 1
    case else: ny += 1
   end select
   if nx >= 0 and nx < FieldSheetWidth(sheet) and ny >= 0 and ny < FieldSheetHeight(sheet) then
    if FieldGetPixel(sheet, nx, ny) = old then
     FieldSetPixel(sheet, nx, ny, brush)
     fe_fill_x(count) = nx
     fe_fill_y(count) = ny
     count += 1
    end if
   end if
  next
 loop

end sub


sub FieldFlipFrame(sheet as Integer, frame as Integer, horizontal as Boolean)

 'Mirrors the 16x16 frame, for the walking frames that face the other way

 dim cols as Integer = FieldSheetCols(sheet)
 dim x0 as Integer = (frame mod cols) * 16
 dim y0 as Integer = (frame \ cols) * 16
 dim a as Integer
 dim b as Integer

 FieldSaveUndo(sheet)
 for r as Integer = 0 to 15
  for c as Integer = 0 to 15
   if horizontal then
    if c < 8 then
     a = FieldGetPixel(sheet, x0 + c, y0 + r)
     b = FieldGetPixel(sheet, x0 + 15 - c, y0 + r)
     FieldSetPixel(sheet, x0 + c, y0 + r, b)
     FieldSetPixel(sheet, x0 + 15 - c, y0 + r, a)
    end if
   elseif r < 8 then
    a = FieldGetPixel(sheet, x0 + c, y0 + r)
    b = FieldGetPixel(sheet, x0 + c, y0 + 15 - r)
    FieldSetPixel(sheet, x0 + c, y0 + r, b)
    FieldSetPixel(sheet, x0 + c, y0 + 15 - r, a)
   end if
  next
 next

end sub


sub FieldCopyFrame(sheet as Integer, frame as Integer)

 dim cols as Integer = FieldSheetCols(sheet)

 for r as Integer = 0 to 15
  for c as Integer = 0 to 15
   fe_clip(r, c) = FieldGetPixel(sheet, (frame mod cols) * 16 + c, (frame \ cols) * 16 + r)
  next
 next
 fe_clip_available = true

end sub


sub FieldPasteFrame(sheet as Integer, frame as Integer)

 dim cols as Integer = FieldSheetCols(sheet)

 FieldSaveUndo(sheet)
 for r as Integer = 0 to 15
  for c as Integer = 0 to 15
   FieldSetPixel(sheet, (frame mod cols) * 16 + c, (frame \ cols) * 16 + r, fe_clip(r, c))
  next
 next

end sub


function FieldColorTag(index as Integer) as String

 if index = 0 then return "Clr"

 return ""

end function


sub FieldSetChannel(pal as Integer, slot as Integer, shift as Integer, value as Integer)

 'Sets the red (shift 0), green (5) or blue (10) of a palette color to 0 to 31, remembering the old color for undo

 dim raw as Integer

 if value < 0 or value > 31 then exit sub

 if fe_pal_undo_count = fe_undo_depth then
  for i as Integer = 1 to fe_undo_depth - 1
   fe_pal_undo_pal(i - 1) = fe_pal_undo_pal(i)
   fe_pal_undo_slot(i - 1) = fe_pal_undo_slot(i)
   fe_pal_undo_value(i - 1) = fe_pal_undo_value(i)
  next
  fe_pal_undo_count -= 1
 end if
 fe_pal_undo_pal(fe_pal_undo_count) = pal
 fe_pal_undo_slot(fe_pal_undo_count) = slot
 fe_pal_undo_value(fe_pal_undo_count) = field_palette_raw(pal, slot)
 fe_pal_undo_count += 1
 raw = field_palette_raw(pal, slot) and not (31 shl shift)
 field_palette_raw(pal, slot) = raw or (value shl shift)

end sub


function FieldMapPalette(g as Integer, p as Placement ptr) as Integer

 'The palette an NPC placement of map g is drawn with: its palette 0 to 3 picks one of the two palettes of each of
 ' the two numbers of the map, the number n standing for the palettes 13 + 2n and 14 + 2n

 dim n as Integer

 if p->palette_index < 2 then n = maps(g).npc_palette_12 else n = maps(g).npc_palette_34

 return 13 + n * 2 + (p->palette_index mod 2)

end function


sub FieldCountPalettes(sheet as Integer, counts() as Integer)

 'How many NPC placements on the maps draw the sheet with each palette

 dim p as Placement ptr
 dim npc_number as Integer
 dim pal as Integer

 for i as Integer = 0 to 63
  counts(i) = 0
 next

 for g as Integer = 1 to total_maps
  for j as Integer = 1 to placement_groups(g).placements.Length()
   p = placement_groups(g).placements.PointerAt(j)
   npc_number = p->npc_index
   if g > &h100 then npc_number += &h100
   if npcs(npc_number).sprite = sheet then
    if sheet < 14 then pal = field_party_palette(sheet) else pal = FieldMapPalette(g, p)
    if pal >= 0 and pal < 64 then counts(pal) += 1
   end if
  next
 next

end sub


function FieldUsualPalette(sheet as Integer) as Integer

 'The palette the game draws a sheet with: the party sheets have a palette of their own, an NPC sheet the one that
 ' most of its placements on the maps use (13 if there is none)

 dim counts(63) as Integer
 dim best as Integer = -1

 if sheet < 14 then return field_party_palette(sheet)

 FieldCountPalettes(sheet, counts())
 for i as Integer = 0 to 63
  if counts(i) > 0 then
   if best < 0 then
    best = i
   elseif counts(i) > counts(best) then
    best = i
   end if
  end if
 next
 if best >= 0 then return best
 if sheet < 18 then return field_party_palette(sheet)

 return 13

end function


function FieldViewPalette(sheet as Integer) as Integer

 'The palette the editor shows a sheet with: the one picked for it, or the usual one

 if field_palette_pick(sheet) >= 0 then return field_palette_pick(sheet)

 return FieldUsualPalette(sheet)

end function


function FieldUsedText(sheet as Integer) as String

 'The palettes the game draws the sheet with, most used first

 dim counts(63) as Integer
 dim best as Integer
 dim s as String

 if sheet < 14 then return "palette " + str(field_party_palette(sheet)) + " (party)"

 FieldCountPalettes(sheet, counts())
 for n as Integer = 1 to 4
  best = -1
  for i as Integer = 0 to 63
   if counts(i) > 0 then
    if best < 0 then
     best = i
    elseif counts(i) > counts(best) then
     best = i
    end if
   end if
  next
  if best < 0 then exit for
  if n > 1 then s += ", "
  s += str(best) + " x" + str(counts(best))
  counts(best) = 0
 next
 if s = "" then return "no NPC on the maps"

 return s

end function


sub FieldRememberPalette(sheet as Integer, pal as Integer)

 'Keeps the palette picked for a sheet; it is written to config/fieldpalettes.dat when the editor is left

 if field_palette_pick(sheet) <> pal then
  field_palette_pick(sheet) = pal
  fe_picks_changed = true
 end if

end sub


function FieldPalettePlace(pal as Integer) as String

 'Who the palette is for, as far as the game code says

 if pal <= 3 then return "the party"
 if pal <= 7 then return "vehicles"
 if pal >= 13 and pal <= 30 then return "the NPCs"

 return "other uses"

end function


sub DrawFieldEditScreen(sheet as Integer, pal as Integer, mode as Integer, pixel_x as Integer, pixel_y as Integer, brush as Integer)

 'mode: 0 = pixel editor, 1 = palette editor (brush is then the selected color)

 dim cols as Integer = FieldSheetCols(sheet)
 dim px as Integer
 dim py as Integer
 dim v as UInteger
 dim frame as Integer = FieldFrameAt(sheet, pixel_x, pixel_y)

 screenlock
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 'Title
 BlueBox(0, 0, 78, 1)
 WriteText(FF4Text("Sheet " + str(sheet) + "  ") + FieldSheetName(sheet) + FF4Text("   Palette " + str(pal) + iif(field_palette_pick(sheet) >= 0, ", picked", "")), 2, 1, 15)
 LuText("Pixel " + str(pixel_x) + "," + str(pixel_y) + "  Frame " + str(frame), 56, 1, 14)

 'The picture of the whole sheet, eight times as large
 BlueBox(0, 3, 67, 34)
 LuText(" PICTURE ", 1, 3, 14)
 DrawFieldPicture(sheet, 16, 40, 8, pal)
 for f as Integer = 0 to FieldSheetTiles(sheet) \ 4 - 1
  px = 16 + (f mod cols) * 128
  py = 40 + (f \ cols) * 128
  line (px, py)-(px + 127, py + 127), RGB(90, 90, 140), b
  line (px + 64, py)-(px + 64, py + 127), RGB(50, 50, 90)
  line (px, py + 64)-(px + 127, py + 64), RGB(50, 50, 90)
 next
 if mode = 0 then
  px = 16 + pixel_x * 8
  py = 40 + pixel_y * 8
  line (px - 1, py - 1)-(px + 8, py + 8), RGB(255, 255, 0), b
  line (px, py)-(px + 7, py + 7), RGB(0, 0, 0), b
 end if

 'Actual size, and the frame under the cursor large
 BlueBox(68, 3, 10, 34)
 LuText(" PREVIEW ", 69, 3, 14)
 DrawFieldPicture(sheet, 552, 40, 1, pal)
 LuText("Frame " + str(frame), 69, 10, 15)
 DrawFieldFrame(sheet, frame, 552, 96, 2, pal)

 'Palette
 BlueBox(0, 39, 34, 6)
 LuText(" PALETTE " + str(pal) + " ", 1, 39, iif(mode = 1, 21, 14))
 for i as Integer = 0 to 7
  px = 16 + i * 32
  line (px, 328)-(px + 28, 348), FieldColor(pal, i), bf
  if i = brush then line (px - 2, 326)-(px + 30, 350), RGB(255, 255, 0), b
  LuText(str(i), (px + 12) \ 8, 44, 15)
  if len(FieldColorTag(i)) > 0 then LuText(FieldColorTag(i), (px + 4) \ 8, 45, 14)
 next

 'The color the brush is on
 BlueBox(37, 39, 41, 6)
 LuText(" COLOR ", 38, 39, iif(mode = 1, 21, 14))
 v = field_palette_raw(pal, brush)
 LuText("Color " + str(brush), 39, 41, 15)
 if brush = 0 then
  LuText("Transparent, not editable", 39, 42, 23)
 else
  LuText("R " + str(v mod 32) + "   G " + str((v \ 32) mod 32) + "   B " + str((v \ 1024) mod 32), 39, 42, 23)
 end if
 LuText("Maps: " + FieldUsedText(sheet), 39, 43, 14)
 LuText("Palette " + str(pal) + " is for " + FieldPalettePlace(pal) + ", shared.", 39, 44, 14)

 'Keys
 BlueBox(0, 47, 78, 6)
 if mode = 1 then
  LuText(" ACTIONS, PALETTE ", 1, 47, 21)
  LuText("Left Right: pick the color to change.", 2, 49, 15)
  LuText("Enter: the menu to change its red, green and blue, undo and more.", 2, 50, 15)
  LuText("Bracket keys: move the color, the pixels of the sheets using it follow.", 2, 51, 15)
  LuText("Esc: back to the picture.", 2, 52, 15)
 else
  LuText(" ACTIONS, PICTURE ", 1, 47, 14)
  LuText("Arrows: move.   Space: paint with the brush color.", 2, 49, 15)
  LuText("Enter: the menu of every action: fill, flip, copy, palette, export.", 2, 50, 15)
  LuText("The menu shows each action's key, so the keys can be learned as you go.", 2, 51, 15)
  LuText("Esc: back to the list.", 2, 52, 15)
 end if
 screenunlock

end sub


function FieldSwapColors(sheet as Integer, pal as Integer, a as Integer, b as Integer) as Boolean

 'Swaps two colors of a palette without changing how anything looks: the pixels of every sheet that is drawn with
 ' the palette are renumbered, and since such a sheet may be drawn with other palettes too (an NPC sheet has the
 ' colors the map gives it), the same two colors are swapped in those palettes and so on, until the palettes and
 ' the sheets that belong together are all done. Party sheets are drawn by the table, the others by the NPC
 ' placements on the maps. The sheet being edited and its palette always count. Asks first. Returns true if done.

 dim used(total_field_sheets - 1, 63) as Boolean
 dim in_pal(63) as Boolean
 dim in_sheet(total_field_sheets - 1) as Boolean
 dim counts(63) as Integer
 dim changed as Boolean
 dim pal_count as Integer
 dim sheet_count as Integer
 dim v as UInteger
 dim c as Integer

 if a = b or a < 1 or b < 1 or a > 7 or b > 7 then return false

 for s as Integer = 0 to total_field_sheets - 1
  if s <= 17 then used(s, field_party_palette(s)) = true
  if s >= 14 then
   FieldCountPalettes(s, counts())
   for p as Integer = 0 to 63
    if counts(p) > 0 then used(s, p) = true
   next
  end if
 next

 in_pal(pal) = true
 in_sheet(sheet) = true
 do
  changed = false
  for s as Integer = 0 to total_field_sheets - 1
   for p as Integer = 0 to 63
    if used(s, p) then
     if in_sheet(s) and not in_pal(p) then
      in_pal(p) = true
      changed = true
     elseif in_pal(p) and not in_sheet(s) then
      in_sheet(s) = true
      changed = true
     end if
    end if
   next
  next
 loop while changed

 for p as Integer = 0 to total_field_palettes - 1
  if in_pal(p) then pal_count += 1
 next
 for s as Integer = 0 to total_field_sheets - 1
  if in_sheet(s) then sheet_count += 1
 next
 if not ConfirmBox("Swap colors " + str(a) + " and " + str(b) + " in " + str(pal_count) + " palette(s), renumbering " + str(sheet_count) + " sheet(s)? Clears undo.") then return false

 for p as Integer = 0 to total_field_palettes - 1
  if in_pal(p) then
   v = field_palette_raw(p, a)
   field_palette_raw(p, a) = field_palette_raw(p, b)
   field_palette_raw(p, b) = v
  end if
 next
 for s as Integer = 0 to total_field_sheets - 1
  if in_sheet(s) then
   for t as Integer = 0 to FieldSheetTiles(s) - 1
    for r as Integer = 0 to 7
     for col as Integer = 0 to 7
      c = field_sprite_gfx(s, t, r, col)
      if c = a then
       field_sprite_gfx(s, t, r, col) = b
      elseif c = b then
       field_sprite_gfx(s, t, r, col) = a
      end if
     next
    next
   next
  end if
 next
 fe_undo_count = 0
 fe_pal_undo_count = 0

 return true

end function


function FieldActions(mode as Integer, byref sheet as Integer, byref pal as Integer, byref brush as Integer, byref slot as Integer) as UInteger

 'The menu of every action of the field sprite editor. Returns the key the chosen entry stands for, or 0 if the
 ' editor handled it here (or the menu was cancelled).

 dim choice as Integer
 dim picked as Integer
 dim names(1 to 110) as String
 dim count as Integer
 dim counts(63) as Integer

 SmReset()
 if mode = 0 then
  SmAdd("Fill with the brush color", "F", asc("f"))
  SmAdd("Choose the brush color", "0 to 7", 0, 1)
  SmAdd("Flip the frame horizontally", "X", asc("x"))
  SmAdd("Flip the frame vertically", "Y", asc("y"))
  SmAdd("Copy the frame", "Ctrl-C", 3)
  SmAdd("Paste the frame", "Ctrl-V", 22)
  SmAdd("Undo", "Ctrl-Z", 26)
  SmAdd("Revert this sheet", "Ctrl-R", 18)
  SmAdd("Edit the palette colors", "P", asc("p"))
  SmAdd("Choose the palette", "Comma Period", 0, 2)
  SmAdd("Use the palette of the maps", "", 0, 4)
  SmAdd("Previous sheet", "PgUp", PAGEUP_KEY)
  SmAdd("Next sheet", "PgDn", PAGEDOWN_KEY)
  SmAdd("Go to a sheet", "", 0, 3)
  SmAdd("Export this sheet as BMP", "E", asc("e"))
  SmAdd("Import this sheet from BMP", "I", asc("i"))
  SmAdd("Back to the list", "Esc", ESC_KEY)
  choice = SmRun("Sheet " + str(sheet))
 else
  SmAdd("Choose the color", "Left Right", 0, 11)
  SmAdd("Change its red", "Q A", 0, 12)
  SmAdd("Change its green", "W S", 0, 13)
  SmAdd("Change its blue", "E D", 0, 14)
  SmAdd("Move the color left", "Bracket", asc("["))
  SmAdd("Move the color right", "Bracket", asc("]"))
  SmAdd("Swap it with another color", "", 0, 15)
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
    names(i + 1) = str(i) + " " + FieldColorTag(i)
   next
   picked = SmPick("Brush color", names(), 8, brush + 1)
   if picked > 0 then brush = picked - 1

  case 2 'palette
   FieldCountPalettes(sheet, counts())
   for i as Integer = 0 to total_field_palettes - 1
    names(i + 1) = "Palette " + str(i) + "  " + FieldPalettePlace(i)
    if counts(i) > 0 then names(i + 1) += "  " + str(counts(i)) + "x"
   next
   picked = SmPick("Palette", names(), total_field_palettes, pal + 1)
   if picked > 0 then
    pal = picked - 1
    FieldRememberPalette(sheet, pal)
   end if

  case 3 'sheet
   for i as Integer = 0 to total_field_sheets - 1
    names(i + 1) = Pad(str(i), 3) + " " + FF4Name(FieldSheetName(i))
   next
   picked = SmPick("Sheet", names(), total_field_sheets, sheet + 1)
   if picked > 0 then
    sheet = picked - 1
    pal = FieldViewPalette(sheet)
   end if

  case 4 'the palette of the maps
   field_palette_pick(sheet) = -1
   fe_picks_changed = true
   pal = FieldViewPalette(sheet)

  case 11 'color of the palette
   for i as Integer = 1 to 7
    names(i) = str(i)
   next
   picked = SmPick("Color", names(), 7, slot)
   if picked > 0 then slot = picked

  case 15 'swap with another color
   for i as Integer = 1 to 7
    names(i) = str(i)
    if i = slot then names(i) += " (this color)"
   next
   picked = SmPick("Swap color " + str(slot) + " with", names(), 7, slot)
   if picked > 0 and picked <> slot then
    if FieldSwapColors(sheet, pal, slot, picked) then slot = picked
   end if

  case 12 to 14 'red, green, blue
   count = (sm_special(choice) - 12) * 5
   picked = SmNumber((field_palette_raw(pal, slot) \ (2 ^ count)) mod 32, 31)
   FieldSetChannel(pal, slot, count, picked)

 end select

 return 0

end function


declare function ExportFieldSheet(sheet as Integer, pal as Integer) as String
declare function ImportOneFieldSheet(sheet as Integer) as String


sub EditFieldSheet(sheet_start as Integer)

 dim key as String
 dim keycode as UInteger
 dim sheet as Integer = sheet_start
 dim pal as Integer = FieldViewPalette(sheet_start)
 dim mode as Integer = 0 '0 = pixel editor, 1 = palette editor
 dim pixel_x as Integer = 0
 dim pixel_y as Integer = 0
 dim brush as Integer = 1
 dim slot as Integer = 1
 dim shift as Integer
 dim channel as Integer
 dim done as Boolean = false
 dim target as Integer

 fe_undo_count = 0
 fe_pal_undo_count = 0

 do

  pixel_x = Min(pixel_x, FieldSheetWidth(sheet) - 1)
  pixel_y = Min(pixel_y, FieldSheetHeight(sheet) - 1)
  DrawFieldEditScreen(sheet, pal, mode, pixel_x, pixel_y, iif(mode = 1, slot, brush))

  do
   key = inkey
   if key = "" then sleep 10
  loop while key = ""
  keycode = asc(right(key, 1))
  if len(key) > 1 then keycode = keycode * &h100 + 255

 if KeyHelpPressed(keycode) then keycode = 0

  'Enter opens the menu of every action; the entries that stand for a key are handled as that key
  if keycode = ENTER_KEY then keycode = FieldActions(mode, sheet, pal, brush, slot)

  if mode = 0 then

   select case keycode
    case ESC_KEY
     done = true
    case LEFT_KEY
     if pixel_x > 0 then pixel_x -= 1
    case RIGHT_KEY
     if pixel_x < FieldSheetWidth(sheet) - 1 then pixel_x += 1
    case UP_KEY
     if pixel_y > 0 then pixel_y -= 1
    case DOWN_KEY
     if pixel_y < FieldSheetHeight(sheet) - 1 then pixel_y += 1
    case HOME_KEY
     pixel_y = 0
    case END_KEY
     pixel_y = FieldSheetHeight(sheet) - 1
    case asc("0") to asc("7")
     brush = keycode - asc("0")
     FieldPaint(sheet, pixel_x, pixel_y, brush)
    case SPACE_KEY
     FieldPaint(sheet, pixel_x, pixel_y, brush)
    case asc("f"), asc("F")
     FieldFill(sheet, pixel_x, pixel_y, brush)
    case asc("e"), asc("E")
     if ConfirmExport("this sheet") then InfoBox(ExportFieldSheet(sheet, pal) + "||Press any key", 4, 20)
    case asc("i"), asc("I")
     if ConfirmBox("Import replaces this sheet and the colors of palette " + str(pal) + ". Continue?") then
      InfoBox(ImportOneFieldSheet(sheet) + "||Press any key", 4, 20)
      fe_undo_count = 0
      fe_pal_undo_count = 0
     end if
    case asc("["), asc("-")
     brush = (brush + 7) mod 8
    case asc("]"), asc("="), asc("+")
     brush = (brush + 1) mod 8
    case asc("x"), asc("X") 'Flip the frame horizontally
     FieldFlipFrame(sheet, FieldFrameAt(sheet, pixel_x, pixel_y), true)
    case asc("y"), asc("Y") 'Flip the frame vertically
     FieldFlipFrame(sheet, FieldFrameAt(sheet, pixel_x, pixel_y), false)
    case 3 'Ctrl-C
     FieldCopyFrame(sheet, FieldFrameAt(sheet, pixel_x, pixel_y))
    case 22 'Ctrl-V
     if fe_clip_available then FieldPasteFrame(sheet, FieldFrameAt(sheet, pixel_x, pixel_y))
    case 26 'Ctrl-Z
     target = FieldUndo()
     if target >= 0 then
      if target <> sheet then pal = FieldViewPalette(target)
      sheet = target
     end if
    case asc("p"), asc("P")
     mode = 1
    case asc(",")
     pal = (pal + total_field_palettes - 1) mod total_field_palettes
     FieldRememberPalette(sheet, pal)
    case asc(".")
     pal = (pal + 1) mod total_field_palettes
     FieldRememberPalette(sheet, pal)
    case PAGEUP_KEY
     sheet = (sheet + total_field_sheets - 1) mod total_field_sheets
     pal = FieldViewPalette(sheet)
    case PAGEDOWN_KEY
     sheet = (sheet + 1) mod total_field_sheets
     pal = FieldViewPalette(sheet)
    case 18 'Ctrl-R
     if ConfirmBox("Revert this sheet to the loaded ROM?") then
      FieldSaveUndo(sheet)
      DecodeFieldSheet(original_rom, sheet)
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
     channel = (field_palette_raw(pal, slot) \ (2 ^ shift)) mod 32
     select case keycode and &hDF
      case asc("Q"), asc("W"), asc("E"): channel += 1
      case else: channel -= 1
     end select
     FieldSetChannel(pal, slot, shift, channel)
    case asc("["), asc("]")
     target = slot + iif(keycode = asc("["), -1, 1)
     if target >= 1 and target <= 7 then
      if FieldSwapColors(sheet, pal, slot, target) then slot = target
     end if
    case 26 'Ctrl-Z
     if fe_pal_undo_count > 0 then
      fe_pal_undo_count -= 1
      field_palette_raw(fe_pal_undo_pal(fe_pal_undo_count), fe_pal_undo_slot(fe_pal_undo_count)) = fe_pal_undo_value(fe_pal_undo_count)
     end if
    case 18 'Ctrl-R
     if ConfirmBox("Revert this palette to the loaded ROM?") then
      for j as Integer = 0 to 7
       field_palette_raw(pal, j) = FieldPaletteOf(original_rom, pal, j)
      next
      fe_pal_undo_count = 0
     end if
   end select

  end if

 loop until done

 cls

end sub


function FieldPath(file_name as String) as String

 mkdir system_path + "\exports"
 mkdir system_path + "\exports\fieldsprites"

 return system_path + "\exports\fieldsprites\" + file_name

end function


function FieldFileName(sheet as Integer, pal as Integer) as String

 return "field_" + Pad(str(sheet), 3, true, "0") + "_pal_" + Pad(str(pal), 2, true, "0") + ".bmp"

end function


function WriteFieldBMP(path as String, sheet as Integer, pal as Integer) as Boolean

 dim colors(15) as UInteger

 for y as Integer = 0 to FieldSheetHeight(sheet) - 1
  for x as Integer = 0 to FieldSheetWidth(sheet) - 1
   bmp_px(y, x) = FieldGetPixel(sheet, x, y)
  next
 next
 for i as Integer = 0 to 7
  colors(i) = field_palette_raw(pal, i)
 next

 return WriteIndexedBMPColors(path, FieldSheetWidth(sheet), FieldSheetHeight(sheet), colors())

end function


function ReadFieldBMP(path as String, sheet as Integer, pal as Integer, byref problem as String) as Boolean

 dim new_palette(15) as UInteger

 for i as Integer = 0 to 7
  new_palette(i) = field_palette_raw(pal, i)
 next
 if not ReadBMPWithPalette(path, FieldSheetWidth(sheet), FieldSheetHeight(sheet), 8, new_palette(), problem) then return false

 for y as Integer = 0 to FieldSheetHeight(sheet) - 1
  for x as Integer = 0 to FieldSheetWidth(sheet) - 1
   FieldSetPixel(sheet, x, y, bmp_px(y, x))
  next
 next
 for i as Integer = 1 to 7
  field_palette_raw(pal, i) = new_palette(i)
 next

 return true

end function


function ExportFieldSheet(sheet as Integer, pal as Integer) as String

 'One sheet, with the palette the editor is showing. Returns a message for the user

 if WriteFieldBMP(FieldPath(FieldFileName(sheet, pal)), sheet, pal) then return "Wrote " + FieldFileName(sheet, pal) + "|to exports\fieldsprites"

 return "Export failed|Check that exports\fieldsprites can be written"

end function


function ExportFieldSheets() as String

 dim written as Integer
 dim failed as Integer

 for s as Integer = 0 to total_field_sheets - 1
  if WriteFieldBMP(FieldPath(FieldFileName(s, FieldViewPalette(s))), s, FieldViewPalette(s)) then written += 1 else failed += 1
 next

 if failed > 0 then return "Export had " + str(failed) + " error(s)|Check that exports\fieldsprites can be written"
 return "Wrote " + str(written) + " sheet images|to exports\fieldsprites"

end function


function ImportFieldImage(sheet as Integer, byref report as String) as Integer

 'Reads field_NNN_pal_*.bmp of the sheet. Returns 1 if it was read, 0 if there is no such file, -1 if it
 ' could not be read. Problems are added to report.

 dim number as Integer
 dim name_found as String
 dim pal as Integer = FieldViewPalette(sheet)
 dim problem as String

 name_found = dir(FieldPath("field_" + Pad(str(sheet), 3, true, "0") + "_pal_*.bmp"))
 if len(name_found) = 0 then return 0

 if len(name_found) >= 20 then
  number = val(mid(name_found, 15, 2))
  if number >= 0 and number < total_field_palettes and mid(name_found, 15, 2) = Pad(str(number), 2, true, "0") then pal = number
 end if
 if ReadFieldBMP(FieldPath(name_found), sheet, pal, problem) then return 1
 report += "|" + name_found + ": " + problem

 return -1

end function


function ImportOneFieldSheet(sheet as Integer) as String

 dim report as String

 select case ImportFieldImage(sheet, report)
  case 0
   return "No field_" + Pad(str(sheet), 3, true, "0") + "_pal_PP.bmp found|in exports\fieldsprites"
  case 1
   return "Read the sheet image" + report
 end select

 return "Import failed" + report

end function


function ImportFieldSheets() as String

 dim images_read as Integer
 dim report as String

 for s as Integer = 0 to total_field_sheets - 1
  if ImportFieldImage(s, report) = 1 then images_read += 1
 next

 if images_read = 0 and len(report) = 0 then return "No field_NNN_pal_PP.bmp files found|in exports\fieldsprites"
 return "Read " + str(images_read) + " sheet image(s)" + report

end function


function PickFieldSheet(title as String) as Integer

 'All sheets (0) or one of them (its number plus 1). Returns -1 if cancelled.

 dim m as BlueMenu

 m = BlueMenu(4, 6)
 m.max_rows = 28
 m.title = title
 m.AddOption(FF4Text("All sheets"))
 for i as Integer = 0 to total_field_sheets - 1
  m.AddOption(FF4Text(Pad(str(i), 3) + " ") + FieldSheetName(i))
 next
 m.UserSelect()
 if m.cancelled then return -1

 return m.selected - 1

end function


sub EditFieldSprites()

 dim sheet_list as BlueMenu
 dim last_sheet as Integer = -1
 dim which as Integer

 sheet_list.max_rows = 50
 for i as Integer = 0 to total_field_sheets - 1
  sheet_list.AddOption(FF4Text(Pad(str(i), 3) + " ") + FieldSheetName(i))
 next
 sheet_list.AddOption(FF4Text("Export sheets"))
 sheet_list.AddOption(FF4Text("Import sheets"))
 sheet_list.y = 2

 do

  do
   screenlock
   line (0, 0)-(639, 463), RGB(0, 0, 0), bf
   WriteText(FF4Text("Pick a sheet, Enter to edit"), 0, 0, 15)
   sheet_list.Display()
   if sheet_list.selected <= total_field_sheets then
    DrawFieldSpriteScreen(sheet_list.selected - 1, FieldViewPalette(sheet_list.selected - 1))
   else
    BlueBox(30, 3, 48, 12)
    if sheet_list.selected = total_field_sheets + 1 then
     LuText(" EXPORT ", 31, 3, 14)
     LuText("Enter asks for all sheets or just one.", 32, 5, 15)
     LuText("Writes one BMP per sheet, field_NNN_pal_PP.bmp, in", 32, 6, 15)
     LuText("exports\fieldsprites. The picture is the sheet, four", 32, 7, 15)
     LuText("frames to a row. The color table of the BMP is the", 32, 8, 15)
     LuText("palette, colors 0 to 7.", 32, 9, 15)
    else
     LuText(" IMPORT ", 31, 3, 14)
     LuText("Enter asks for all sheets or just one.", 32, 5, 15)
     LuText("Reads field_NNN_pal_PP.bmp. Its color table sets the", 32, 6, 15)
     LuText("colors of palette PP, which other sprites share.", 32, 7, 15)
     LuText("Keep the color numbers and the size of the sheet.", 32, 8, 15)
    end if
   end if
   screenunlock
  loop until sheet_list.UserInput()

  if not sheet_list.cancelled then
   if sheet_list.selected <= total_field_sheets then
    EditFieldSheet(sheet_list.selected - 1)
   elseif sheet_list.selected = total_field_sheets + 1 then
    which = PickFieldSheet("Export which sheet?")
    if which = 0 then
     if ConfirmExport("all sheets") then InfoBox(ExportFieldSheets() + "||Press any key", 4, 20)
    elseif which > 0 then
     if ConfirmExport("that sheet") then InfoBox(ExportFieldSheet(which - 1, FieldViewPalette(which - 1)) + "||Press any key", 4, 20)
    end if
   else
    which = PickFieldSheet("Import which sheet?")
    if which >= 0 then
     if ConfirmBox("Import replaces the current sheets and palette colors. Continue?") then
      if which = 0 then
       InfoBox(ImportFieldSheets() + "||Press any key", 4, 20)
      else
       InfoBox(ImportOneFieldSheet(which - 1) + "||Press any key", 4, 20)
      end if
     end if
    end if
   end if
   cls
  end if

 loop until sheet_list.cancelled

 if fe_picks_changed then
  SaveFieldPalettePicks()
  fe_picks_changed = false
 end if

 cls

end sub
