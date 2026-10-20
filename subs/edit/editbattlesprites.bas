'Battle character sprite editor.
'Each character has a sheet of 64 4bpp tiles (see readbattlechargfx.bas). A pose is six of those
'tiles, picked by CharTileTbl and positioned by CharSpriteOffsetTbl (both in bank 0d), so editing
'one tile changes every pose that uses it. Palettes are the 16 battle character palettes.
'Golbez and Anna (sheets 15 and 16) use a different layout and are not included yet.

const battle_pose_offset_table = &h6FA3C 'sprite position id for each pose
const battle_sprite_offset_table = &h6FA61 'x, y, ?, attributes for the six sprites of a position id
const battle_tile_table = &h6FB61 'six tile numbers for each pose
const battle_palette_table = &hE7F00 '16 palettes of 16 colors
const battle_pose_count = 12

const bs_transparent = &hFF282840 'RGB(40, 40, 64): shown where a pixel is color 0
const bs_undo_depth = 32

dim shared battle_palettes(15, 15) as UInteger
dim shared bs_undo_sheet(bs_undo_depth - 1) as Integer
dim shared bs_undo_tile(bs_undo_depth - 1) as Integer
dim shared bs_undo_pixels(bs_undo_depth - 1, 7, 7) as UByte
dim shared bs_undo_count as Integer
dim shared bs_clip(7, 7) as UByte
dim shared bs_clip_available as Boolean


function BattleSheetName(sheet as Integer) as String

 'Returns the name already encoded for display

 if sheet = 14 then return FF4Text("Frog")
 return npc_sprite_names.ItemAt(sheet + 1)

end function


function BattlePoseName(pose as Integer) as String

 select case pose
  case 0: return "Standing"
  case 1: return "Ready"
  case 2: return "Running"
  case 3: return "Kneeling"
  case 4: return "Right arm up"
  case 5: return "Left arm down"
  case 6: return "Left arm up"
  case 7: return "Hit"
  case 8: return "Victory"
  case 9: return "Dead"
  case 10: return "Chant 1"
  case 11: return "Chant 2"
 end select

 return ""

end function


sub LoadBattlePalettes()

 dim v as UInteger

 for i as Integer = 0 to 15
  for j as Integer = 0 to 15
   v = ByteAt(battle_palette_table + i * 32 + j * 2) + ByteAt(battle_palette_table + i * 32 + j * 2 + 1) * &h100
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


sub DrawBattleSpriteScreen(sheet as Integer, tile_id as Integer, pose as Integer, pal as Integer, pixel_mode as Boolean, pixel_x as Integer, pixel_y as Integer, brush as Integer)

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
 if pixel_mode then c = RGB(160, 160, 160) else c = RGB(255, 255, 0)
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
 if pixel_mode then
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
  if pixel_mode and i = brush then
   line (px - 2, 342)-(px + 29, 366), RGB(255, 255, 0), b
  end if
  WriteText(FF4Text(hex(i)), (px + 10) \ 8, 47, 15)
 next

 if pixel_mode then
  WriteText(FF4Text("Arrows move   0-9 A-F paint a color   Space paint with brush"), 2, 51, 15)
  WriteText(FF4Text("[ ] change brush   X / Y flip   Ctrl-Z undo   Ctrl-C / V copy tile"), 2, 53, 15)
  WriteText(FF4Text("Esc back to the tile sheet"), 2, 55, 15)
 else
  WriteText(FF4Text("Arrows move   Enter edit tile   PgUp / PgDn change pose"), 2, 51, 15)
  WriteText(FF4Text(", . change palette   Ctrl-C / V copy / paste tile   Ctrl-Z undo"), 2, 53, 15)
  WriteText(FF4Text("R revert this sheet to the loaded ROM   Esc back"), 2, 55, 15)
 end if
 screenunlock

end sub


sub EditBattleSheet(sheet as Integer)

 dim key as String
 dim keycode as UInteger
 dim tile_id as Integer = 0
 dim pose as Integer = 0
 dim pal as Integer = sheet
 dim pixel_mode as Boolean = false
 dim pixel_x as Integer = 0
 dim pixel_y as Integer = 0
 dim brush as Integer = 1
 dim temp as UByte
 dim done as Boolean = false
 dim s as Integer
 dim t as Integer

 bs_undo_count = 0

 do

  DrawBattleSpriteScreen(sheet, tile_id, pose, pal, pixel_mode, pixel_x, pixel_y, brush)

  do
   key = inkey
   if key = "" then sleep 10
  loop while key = ""
  keycode = asc(right(key, 1))
  if len(key) > 1 then keycode = keycode * &h100 + 255

  'Keys that work in both modes
  select case keycode
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

  if pixel_mode then

   select case keycode
    case ESC_KEY
     pixel_mode = false
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

  else

   select case keycode
    case ESC_KEY
     done = true
    case LEFT_KEY
     if tile_id mod 8 > 0 then tile_id -= 1
    case RIGHT_KEY
     if tile_id mod 8 < 7 then tile_id += 1
    case UP_KEY
     if tile_id >= 8 then tile_id -= 8
    case DOWN_KEY
     if tile_id < 56 then tile_id += 8
    case ENTER_KEY
     pixel_mode = true
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

 LoadBattlePalettes()

 select_sheet.max_rows = total_battle_char_sheets
 for i as Integer = 0 to total_battle_char_sheets - 1
  select_sheet.AddOption(BattleSheetName(i))
 next

 do

  do
   screenlock
   line (0, 0)-(639, 463), RGB(0, 0, 0), bf
   WriteText(FF4Text("Pick a character, Enter to edit"), 0, 0, 15)
   select_sheet.y = 2
   select_sheet.Display()
   DrawBattlePose(select_sheet.selected - 1, 0, 300, 64, 6, select_sheet.selected - 1)
   screenunlock
  loop until select_sheet.UserInput()

  if not select_sheet.cancelled then EditBattleSheet(select_sheet.selected - 1)

 loop until select_sheet.cancelled

end sub
