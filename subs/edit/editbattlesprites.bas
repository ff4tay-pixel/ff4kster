'Battle character sprite editor.
'Each character has a sheet of 64 4bpp tiles (see readbattlechargfx.bas). A pose is six of those
'tiles, picked by CharTileTbl and positioned by CharSpriteOffsetTbl (both in bank 0d), so editing
'one tile changes every pose that uses it. Palettes are the 16 battle character palettes.
'Golbez and Anna (sheets 15 and 16) use a different layout and are not included yet.


const bs_transparent = &hFF282840 'RGB(40, 40, 64): shown where a pixel is color 0
const bs_undo_depth = 32

dim shared battle_palettes(15, 15) as UInteger
dim shared bs_undo_sheet(bs_undo_depth - 1) as Integer
dim shared bs_undo_tile(bs_undo_depth - 1) as Integer
dim shared bs_undo_pixels(bs_undo_depth - 1, 7, 7) as UByte
dim shared bs_undo_count as Integer
dim shared bs_clip(7, 7) as UByte
dim shared bs_clip_available as Boolean
dim shared bs_pal_undo_pal(bs_undo_depth - 1) as Integer
dim shared bs_pal_undo_slot(bs_undo_depth - 1) as Integer
dim shared bs_pal_undo_value(bs_undo_depth - 1) as UInteger
dim shared bs_pal_undo_count as Integer


function BattleSheetName(sheet as Integer) as String

 'Returns the name already encoded for display

 if sheet = 14 then return FF4Text("Frog")
 return npc_sprite_names.ItemAt(sheet + 1)

end function


sub RefreshBattlePalettes()

 'Rebuilds the display colors from the raw SNES color values

 dim v as UInteger

 for i as Integer = 0 to 15
  for j as Integer = 0 to 15
   v = battle_palette_raw(i, j)
   battle_palettes(i, j) = RGB((v mod 32) * 8, ((v \ 32) mod 32) * 8, ((v \ 1024) mod 32) * 8)
  next
 next

end sub


function BattleColor(pal as Integer, index as Integer) as UInteger

 if index = 0 then return bs_transparent
 return battle_palettes(pal, index)

end function


sub DrawBattleTile(sheet as Integer, tile_id as Integer, x as Integer, y as Integer, zoom as Integer, pal as Integer)

 for row as Integer = 0 to 7
  for col as Integer = 0 to 7
   line (x + col * zoom, y + row * zoom)-step(zoom - 1, zoom - 1), BattleColor(pal, battle_char_gfx(sheet, tile_id, row, col)), bf
  next
 next

end sub


sub DrawBattlePose(sheet as Integer, pose as Integer, x as Integer, y as Integer, zoom as Integer, pal as Integer)

 'Draws the pose into a 24x24 pixel area (scaled by zoom) with the top left corner at x, y

 dim position_id as Integer
 dim tile_id as Integer
 dim sx as Integer
 dim sy as Integer

 line (x, y)-step(24 * zoom - 1, 24 * zoom - 1), bs_transparent, bf

 position_id = ByteAt(battle_pose_offset_table + pose)

 for k as Integer = 0 to 5
  tile_id = ByteAt(battle_tile_table + pose * 6 + k)
  if tile_id < 64 then
   sx = ByteAt(battle_sprite_offset_table + position_id * 32 + k * 4)
   sy = ByteAt(battle_sprite_offset_table + position_id * 32 + k * 4 + 1)
   if sx > 127 then sx -= 256
   if sy > 127 then sy -= 256
   sx += 8
   for row as Integer = 0 to 7
    for col as Integer = 0 to 7
     if battle_char_gfx(sheet, tile_id, row, col) <> 0 then
      line (x + (sx + col) * zoom, y + (sy + row) * zoom)-step(zoom - 1, zoom - 1), BattleColor(pal, battle_char_gfx(sheet, tile_id, row, col)), bf
     end if
    next
   next
  end if
 next

end sub


sub BattleSpriteSaveUndo(sheet as Integer, tile_id as Integer)

 'Remember the tile as it is now, so the next change can be undone

 if bs_undo_count = bs_undo_depth then
  for i as Integer = 1 to bs_undo_depth - 1
   bs_undo_sheet(i - 1) = bs_undo_sheet(i)
   bs_undo_tile(i - 1) = bs_undo_tile(i)
   for r as Integer = 0 to 7
    for c as Integer = 0 to 7
     bs_undo_pixels(i - 1, r, c) = bs_undo_pixels(i, r, c)
    next
   next
  next
  bs_undo_count -= 1
 end if

 bs_undo_sheet(bs_undo_count) = sheet
 bs_undo_tile(bs_undo_count) = tile_id
 for r as Integer = 0 to 7
  for c as Integer = 0 to 7
   bs_undo_pixels(bs_undo_count, r, c) = battle_char_gfx(sheet, tile_id, r, c)
  next
 next
 bs_undo_count += 1

end sub


sub BattleSpriteUndo(byref sheet as Integer, byref tile_id as Integer)

 if bs_undo_count > 0 then
  bs_undo_count -= 1
  sheet = bs_undo_sheet(bs_undo_count)
  tile_id = bs_undo_tile(bs_undo_count)
  for r as Integer = 0 to 7
   for c as Integer = 0 to 7
    battle_char_gfx(sheet, tile_id, r, c) = bs_undo_pixels(bs_undo_count, r, c)
   next
  next
 end if

end sub


sub BattlePaletteSaveUndo(pal as Integer, slot as Integer)

 if bs_pal_undo_count = bs_undo_depth then
  for i as Integer = 1 to bs_undo_depth - 1
   bs_pal_undo_pal(i - 1) = bs_pal_undo_pal(i)
   bs_pal_undo_slot(i - 1) = bs_pal_undo_slot(i)
   bs_pal_undo_value(i - 1) = bs_pal_undo_value(i)
  next
  bs_pal_undo_count -= 1
 end if
 
 bs_pal_undo_pal(bs_pal_undo_count) = pal
 bs_pal_undo_slot(bs_pal_undo_count) = slot
 bs_pal_undo_value(bs_pal_undo_count) = battle_palette_raw(pal, slot)
 bs_pal_undo_count += 1

end sub


sub DrawBattleSpriteScreen(sheet as Integer, tile_id as Integer, pose as Integer, pal as Integer, mode as Integer, pixel_x as Integer, pixel_y as Integer, brush as Integer)

 'mode: 0 = tile sheet, 1 = pixel editor, 2 = palette editor (brush is then the selected color)

 dim tx as Integer
 dim ty as Integer
 dim px as Integer
 dim py as Integer
 dim c as UInteger

 screenlock
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 WriteText(BattleSheetName(sheet) + FF4Text("   Palette " + str(pal)), 2, 2, 15)
 WriteText(FF4Text("Tiles"), 2, 6, 14)
 WriteText(FF4Text("Pose: " + BattlePoseName(pose)), 37, 6, 14)
 WriteText(FF4Text("Tile " + str(tile_id)), 57, 6, 14)

 'Tile sheet
 for t as Integer = 0 to 63
  DrawBattleTile(sheet, t, 16 + (t mod 8) * 33, 64 + (t \ 8) * 33, 4, pal)
 next
 tx = 16 + (tile_id mod 8) * 33
 ty = 64 + (tile_id \ 8) * 33
 if mode <> 0 then c = RGB(160, 160, 160) else c = RGB(255, 255, 0)
 line (tx - 2, ty - 2)-(tx + 33, ty + 33), c, b
 line (tx - 1, ty - 1)-(tx + 32, ty + 32), c, b

 'Current pose, large
 DrawBattlePose(sheet, pose, 300, 64, 6, pal)

 'Tile being edited, large
 for row as Integer = 0 to 7
  for col as Integer = 0 to 7
   line (460 + col * 20, 64 + row * 20)-step(18, 18), BattleColor(pal, battle_char_gfx(sheet, tile_id, row, col)), bf
  next
 next
 if mode = 1 then
  px = 460 + pixel_x * 20
  py = 64 + pixel_y * 20
  line (px - 1, py - 1)-(px + 19, py + 19), RGB(255, 255, 0), b
  line (px, py)-(px + 18, py + 18), RGB(0, 0, 0), b
 end if

 'Every pose, small
 for p as Integer = 0 to battle_pose_count - 1
  px = 300 + (p mod 6) * 52
  py = 240 + (p \ 6) * 56
  DrawBattlePose(sheet, p, px, py, 2, pal)
  if p = pose then line (px - 2, py - 2)-(px + 49, py + 49), RGB(255, 255, 0), b
 next

 'Palette
 for i as Integer = 0 to 15
  px = 16 + i * 30
  line (px, 344)-(px + 27, 364), BattleColor(pal, i), bf
  if mode <> 0 and i = brush then
   line (px - 2, 342)-(px + 29, 366), RGB(255, 255, 0), b
  end if
  WriteText(FF4Text(hex(i)), (px + 10) \ 8, 47, 15)
 next

 if mode = 2 then
  WriteText(FF4Text("Editing palette " + str(pal) + ", color " + hex(brush) + IIf(brush = 0, " (transparent, not editable)", "   R " + str((battle_palette_raw(pal, brush) mod 32)) + "  G " + str((battle_palette_raw(pal, brush) \ 32) mod 32) + "  B " + str((battle_palette_raw(pal, brush) \ 1024) mod 32))), 2, 49, 14)
  WriteText(FF4Text("Left / Right pick a color   Q / A red + -   W / S green + -   E / D blue + -"), 2, 51, 15)
  WriteText(FF4Text("Ctrl-Z undo   Ctrl-R revert this palette to the loaded ROM"), 2, 53, 15)
  WriteText(FF4Text("Esc back to the tile sheet"), 2, 55, 15)
 elseif mode = 1 then
  WriteText(FF4Text("Arrows move   0-9 A-F paint a color   Space paint with brush"), 2, 51, 15)
  WriteText(FF4Text("[ ] change brush   X / Y flip   Ctrl-Z undo   Ctrl-C / V copy tile"), 2, 53, 15)
  WriteText(FF4Text("Esc back to the tile sheet"), 2, 55, 15)
 else
  WriteText(FF4Text("Arrows move   Enter edit tile   PgUp / PgDn change pose"), 2, 51, 15)
  WriteText(FF4Text(", . change palette   P edit palette colors   Ctrl-C / V copy / paste tile"), 2, 53, 15)
  WriteText(FF4Text("Ctrl-Z undo   R revert this sheet to the loaded ROM   Esc back"), 2, 55, 15)
 end if
 screenunlock

end sub


sub EditBattleSheet(sheet as Integer)

 dim key as String
 dim keycode as UInteger
 dim tile_id as Integer = 0
 dim pose as Integer = 0
 dim pal as Integer = sheet
 dim mode as Integer = 0 '0 = tile sheet, 1 = pixel editor, 2 = palette editor
 dim slot as Integer = 1
 dim raw as Integer
 dim channel as Integer
 dim shift as Integer
 dim pixel_x as Integer = 0
 dim pixel_y as Integer = 0
 dim brush as Integer = 1
 dim temp as UByte
 dim done as Boolean = false
 dim s as Integer
 dim t as Integer

 bs_undo_count = 0
 bs_pal_undo_count = 0

 do

  DrawBattleSpriteScreen(sheet, tile_id, pose, pal, mode, pixel_x, pixel_y, iif(mode = 2, slot, brush))

  do
   key = inkey
   if key = "" then sleep 10
  loop while key = ""
  keycode = asc(right(key, 1))
  if len(key) > 1 then keycode = keycode * &h100 + 255

  'Tile keys that work in the tile sheet and the pixel editor (the palette editor has its own)
  select case iif(mode = 2, 0, keycode)
   case 3 'Ctrl-C
    for r as Integer = 0 to 7
     for c as Integer = 0 to 7
      bs_clip(r, c) = battle_char_gfx(sheet, tile_id, r, c)
     next
    next
    bs_clip_available = true
    keycode = 0
   case 22 'Ctrl-V
    if bs_clip_available then
     BattleSpriteSaveUndo(sheet, tile_id)
     for r as Integer = 0 to 7
      for c as Integer = 0 to 7
       battle_char_gfx(sheet, tile_id, r, c) = bs_clip(r, c)
      next
     next
    end if
    keycode = 0
   case 26 'Ctrl-Z
    s = sheet
    t = tile_id
    BattleSpriteUndo(s, t)
    if s = sheet then tile_id = t
    keycode = 0
  end select

  if mode = 1 then

   select case keycode
    case ESC_KEY
     mode = 0
    case LEFT_KEY
     if pixel_x > 0 then pixel_x -= 1
    case RIGHT_KEY
     if pixel_x < 7 then pixel_x += 1
    case UP_KEY
     if pixel_y > 0 then pixel_y -= 1
    case DOWN_KEY
     if pixel_y < 7 then pixel_y += 1
    case asc("0") to asc("9"), asc("a") to asc("f"), asc("A") to asc("F")
     if keycode <= asc("9") then brush = keycode - asc("0") else brush = (keycode and &hDF) - asc("A") + 10
     if battle_char_gfx(sheet, tile_id, pixel_y, pixel_x) <> brush then
      BattleSpriteSaveUndo(sheet, tile_id)
      battle_char_gfx(sheet, tile_id, pixel_y, pixel_x) = brush
     end if
    case SPACE_KEY, ENTER_KEY
     if battle_char_gfx(sheet, tile_id, pixel_y, pixel_x) <> brush then
      BattleSpriteSaveUndo(sheet, tile_id)
      battle_char_gfx(sheet, tile_id, pixel_y, pixel_x) = brush
     end if
    case asc("[")
     brush = (brush + 15) mod 16
    case asc("]")
     brush = (brush + 1) mod 16
    case asc("x"), asc("X") 'Flip horizontally
     BattleSpriteSaveUndo(sheet, tile_id)
     for r as Integer = 0 to 7
      for c as Integer = 0 to 3
       swap battle_char_gfx(sheet, tile_id, r, c), battle_char_gfx(sheet, tile_id, r, 7 - c)
      next
     next
    case asc("y"), asc("Y") 'Flip vertically
     BattleSpriteSaveUndo(sheet, tile_id)
     for r as Integer = 0 to 3
      for c as Integer = 0 to 7
       swap battle_char_gfx(sheet, tile_id, r, c), battle_char_gfx(sheet, tile_id, 7 - r, c)
      next
     next
   end select

  elseif mode = 2 then

   select case keycode
    case ESC_KEY
     mode = 0
    case LEFT_KEY
     if slot > 1 then slot -= 1
    case RIGHT_KEY
     if slot < 15 then slot += 1
    case asc("q"), asc("Q"), asc("a"), asc("A"), asc("w"), asc("W"), asc("s"), asc("S"), asc("e"), asc("E"), asc("d"), asc("D")
     select case keycode and &hDF
      case asc("Q"), asc("A"): shift = 0
      case asc("W"), asc("S"): shift = 5
      case else: shift = 10
     end select
     channel = (battle_palette_raw(pal, slot) \ (2 ^ shift)) mod 32
     select case keycode and &hDF
      case asc("Q"), asc("W"), asc("E"): channel += 1
      case else: channel -= 1
     end select
     if channel >= 0 and channel <= 31 then
      BattlePaletteSaveUndo(pal, slot)
      raw = battle_palette_raw(pal, slot) and not (31 shl shift)
      battle_palette_raw(pal, slot) = raw or (channel shl shift)
      RefreshBattlePalettes()
     end if
    case 26 'Ctrl-Z
     if bs_pal_undo_count > 0 then
      bs_pal_undo_count -= 1
      battle_palette_raw(bs_pal_undo_pal(bs_pal_undo_count), bs_pal_undo_slot(bs_pal_undo_count)) = bs_pal_undo_value(bs_pal_undo_count)
      RefreshBattlePalettes()
     end if
    case 18 'Ctrl-R
     if ConfirmBox("Revert this palette to the loaded ROM?") then
      for j as Integer = 0 to 15
       battle_palette_raw(pal, j) = asc(mid(original_rom, battle_palette_table + pal * 32 + j * 2 + 1, 1)) + asc(mid(original_rom, battle_palette_table + pal * 32 + j * 2 + 2, 1)) * &h100
      next
      RefreshBattlePalettes()
      bs_pal_undo_count = 0
     end if
   end select

  else

   select case keycode
    case ESC_KEY
     done = true
    case asc("p"), asc("P")
     mode = 2
    case LEFT_KEY
     if tile_id mod 8 > 0 then tile_id -= 1
    case RIGHT_KEY
     if tile_id mod 8 < 7 then tile_id += 1
    case UP_KEY
     if tile_id >= 8 then tile_id -= 8
    case DOWN_KEY
     if tile_id < 56 then tile_id += 8
    case ENTER_KEY
     mode = 1
    case PAGEUP_KEY
     pose = (pose + battle_pose_count - 1) mod battle_pose_count
    case PAGEDOWN_KEY
     pose = (pose + 1) mod battle_pose_count
    case asc(",")
     pal = (pal + 15) mod 16
    case asc(".")
     pal = (pal + 1) mod 16
    case asc("r"), asc("R")
     if ConfirmBox("Revert this whole sheet to the loaded ROM?") then
      for i as Integer = 0 to 63
       DecodeBattleCharGfx(original_rom, sheet, i)
      next
      bs_undo_count = 0
     end if
   end select

  end if

 loop until done

end sub


sub EditBattleSprites()

 dim select_sheet as BlueMenu

 RefreshBattlePalettes()

 select_sheet.max_rows = total_battle_char_sheets + 2
 for i as Integer = 0 to total_battle_char_sheets - 1
  select_sheet.AddOption(BattleSheetName(i))
 next
 select_sheet.AddOption(FF4Text("Export poses + palettes"))
 select_sheet.AddOption(FF4Text("Import poses + palettes"))

 do

  do
   screenlock
   line (0, 0)-(639, 463), RGB(0, 0, 0), bf
   WriteText(FF4Text("Pick a character, Enter to edit"), 0, 0, 15)
   select_sheet.y = 2
   select_sheet.Display()
   if select_sheet.selected <= total_battle_char_sheets then
    DrawBattlePose(select_sheet.selected - 1, 0, 300, 64, 6, select_sheet.selected - 1)
   else
    select case select_sheet.selected - total_battle_char_sheets
     case 1
      WriteText(FF4Text("Writes one BMP per character with all the poses, in"), 37, 8, 15)
      WriteText(FF4Text("16x24 cells (poses_NN_pal_PP.bmp), plus any tiles no"), 37, 9, 15)
      WriteText(FF4Text("pose uses on a strip below. The 16 palette colors are"), 37, 10, 15)
      WriteText(FF4Text("the top right pixels, top to bottom."), 37, 11, 15)
     case else
      WriteText(FF4Text("Reads every poses_NN_pal_PP.bmp and splits the poses"), 37, 8, 15)
      WriteText(FF4Text("back into tiles. Tiles shared by several poses take"), 37, 9, 15)
      WriteText(FF4Text("the pose you changed; if two differ, the first pose"), 37, 10, 15)
      WriteText(FF4Text("wins and you are told. The top right pixels set the palette."), 37, 11, 15)
    end select
   end if
   screenunlock
  loop until select_sheet.UserInput()

  if not select_sheet.cancelled then
   if select_sheet.selected <= total_battle_char_sheets then
    EditBattleSheet(select_sheet.selected - 1)
   elseif select_sheet.selected = total_battle_char_sheets + 1 then
    InfoBox(ExportBattleSprites() + "||Press any key", 4, 20)
   else
    if ConfirmBox("Import replaces the current sprites and palettes. Continue?") then
     InfoBox(ImportBattleSprites() + "||Press any key", 4, 20)
     RefreshBattlePalettes()
    end if
   end if
  end if

 loop until select_sheet.cancelled

end sub
