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

 for k as Integer = 0 to PoseSpriteCount(pose) - 1
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


function BattleColorRole(index as Integer) as String

 'What the color usually is in the character sprites, "" if it has no fixed use

 select case index
  case 0: return "transparent"
  case 1: return "black"
  case 2: return "white, eyes"
  case 3: return "skin"
  case 4: return "skin shadow"
  case 8: return "eye color"
 end select

 return ""

end function


function BattleColorTag(index as Integer) as String

 select case index
  case 0: return "Tr"
  case 1: return "Bk"
  case 2: return "Wh"
  case 3: return "Sk"
  case 4: return "Sd"
  case 8: return "Ey"
 end select

 return ""

end function


sub BattleMoveColor(pal as Integer, slot as Integer, other as Integer)

 'Swaps two palette colors and renumbers the pixels of the sheet that uses this palette
 ' (the sheet with the same number), so that it looks the same.

 dim v as UInteger = battle_palette_raw(pal, slot)
 dim c as Integer

 battle_palette_raw(pal, slot) = battle_palette_raw(pal, other)
 battle_palette_raw(pal, other) = v

 if pal < total_battle_char_sheets then
  for t as Integer = 0 to 63
   for r as Integer = 0 to 7
    for col as Integer = 0 to 7
     c = battle_char_gfx(pal, t, r, col)
     if c = slot then
      battle_char_gfx(pal, t, r, col) = other
     elseif c = other then
      battle_char_gfx(pal, t, r, col) = slot
     end if
    next
   next
  next
 end if

 bs_undo_count = 0
 bs_pal_undo_count = 0

end sub


sub DrawBattleSpriteScreen(sheet as Integer, tile_id as Integer, pose as Integer, pal as Integer, mode as Integer, pixel_x as Integer, pixel_y as Integer, brush as Integer)

 'mode: 0 = tile sheet, 1 = pixel editor, 2 = palette editor (brush is then the selected color)
 'Windows like the rest of the editor: title, tiles, pose, tile, every pose, palette and the keys

 dim tx as Integer
 dim ty as Integer
 dim px as Integer
 dim py as Integer
 dim c as UInteger
 dim v as UInteger

 screenlock
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 'Title
 BlueBox(0, 0, 78, 1)
 WriteText(BattleSheetName(sheet) + FF4Text("   Palette " + str(pal)), 2, 1, 15)
 WriteText(FF4Text("Pose: " + BattlePoseName(pose) + "   Tile " + str(tile_id)), 50, 1, 14)

 'Tile sheet
 BlueBox(0, 3, 34, 34)
 LuText(" TILES ", 1, 3, iif(mode = 0, 14, 23))
 for t as Integer = 0 to 63
  DrawBattleTile(sheet, t, 16 + (t mod 8) * 33, 36 + (t \ 8) * 33, 4, pal)
 next
 tx = 16 + (tile_id mod 8) * 33
 ty = 36 + (tile_id \ 8) * 33
 if mode <> 0 then c = RGB(160, 160, 160) else c = RGB(255, 255, 0)
 line (tx - 2, ty - 2)-(tx + 33, ty + 33), c, b
 line (tx - 1, ty - 1)-(tx + 32, ty + 32), c, b

 'Current pose, large
 BlueBox(36, 3, 20, 20)
 LuText(" POSE ", 37, 3, 14)
 DrawBattlePose(sheet, pose, 304, 36, 6, pal)

 'Tile being edited, large
 BlueBox(58, 3, 20, 20)
 LuText(" TILE " + str(tile_id) + " ", 59, 3, iif(mode = 1, 21, 14))
 for row as Integer = 0 to 7
  for col as Integer = 0 to 7
   line (488 + col * 16, 36 + row * 16)-step(14, 14), BattleColor(pal, battle_char_gfx(sheet, tile_id, row, col)), bf
  next
 next
 if mode = 1 then
  px = 488 + pixel_x * 16
  py = 36 + pixel_y * 16
  line (px - 1, py - 1)-(px + 15, py + 15), RGB(255, 255, 0), b
  line (px, py)-(px + 14, py + 14), RGB(0, 0, 0), b
 end if
 LuText("Pixel " + str(pixel_x) + "," + str(pixel_y), 60, 21, 23)

 'Every pose, small
 BlueBox(36, 24, 42, 16)
 LuText(" ALL POSES ", 37, 24, 14)
 for img as Integer = 0 to image_pose_count - 1
  px = 298 + (img mod 7) * 47
  py = 212 + (img \ 7) * 52
  DrawBattlePose(sheet, ImagePoseId(img), px, py, 2, pal)
  if ImagePoseId(img) = pose then line (px - 1, py - 1)-(px + 48, py + 48), RGB(255, 255, 0), b
 next

 'Palette
 BlueBox(0, 42, 78, 5)
 LuText(" PALETTE " + str(pal) + " ", 1, 42, iif(mode = 2, 21, 14))
 for i as Integer = 0 to 15
  px = 16 + i * 36
  line (px, 348)-(px + 32, 364), BattleColor(pal, i), bf
  if mode <> 0 and i = brush then
   line (px - 2, 346)-(px + 34, 366), RGB(255, 255, 0), b
  end if
  LuText(hex(i), (px + 14) \ 8, 46, 15)
  if len(BattleColorTag(i)) > 0 then LuText(BattleColorTag(i), (px + 10) \ 8, 47, 14)
 next

 'Keys
 BlueBox(0, 49, 78, 7)
 if mode = 2 then
  v = battle_palette_raw(pal, brush)
  LuText(" ACTIONS, PALETTE ", 1, 49, 21)
  LuText("Color " + hex(brush) + iif(brush = 0, ", transparent, not editable", iif(len(BattleColorRole(brush)) > 0, ", " + BattleColorRole(brush), "") + "   R " + str(v mod 32) + "  G " + str((v \ 32) mod 32) + "  B " + str((v \ 1024) mod 32)), 2, 51, 14)
  LuText("Left Right: pick the color to change.", 2, 52, 15)
  LuText("Enter: the menu to change its red, green and blue, move it, undo and more.", 2, 53, 15)
  LuText("Esc: back to the tile sheet.", 2, 54, 15)
 elseif mode = 1 then
  LuText(" ACTIONS, PIXELS ", 1, 49, 21)
  LuText("Arrows: move.   Space: paint with the brush color.", 2, 51, 15)
  LuText("Enter: the menu of every action, like brush color, flip, copy and paste.", 2, 52, 15)
  LuText("Esc: back to the tile sheet.", 2, 53, 15)
 else
  LuText(" ACTIONS, TILES ", 1, 49, 14)
  LuText("Arrows: pick a tile.   Enter: edit the tile.", 2, 51, 15)
  LuText("Space: the menu of every action, like pose, palette, copy and export.", 2, 52, 15)
  LuText("The menu shows each action's key, so the keys can be learned as you go.", 2, 53, 15)
  LuText("Esc: back to the list.", 2, 54, 15)
 end if
 screenunlock

end sub


sub BattleSetChannel(pal as Integer, slot as Integer, shift as Integer, value as Integer)

 'Sets the red (shift 0), green (5) or blue (10) of a palette color to 0 to 31, remembering the old color for undo

 dim raw as Integer

 if value < 0 or value > 31 then exit sub

 BattlePaletteSaveUndo(pal, slot)
 raw = battle_palette_raw(pal, slot) and not (31 shl shift)
 battle_palette_raw(pal, slot) = raw or (value shl shift)
 RefreshBattlePalettes()

end sub


function BattleActions(mode as Integer, sheet as Integer, byref tile_id as Integer, byref pose as Integer, byref pal as Integer, byref brush as Integer, byref slot as Integer) as UInteger

 'The menu of every action of the battle sprite editor. Returns the key the chosen entry stands for, or 0 if the
 ' editor handled it here (or the menu was cancelled).

 dim choice as Integer
 dim picked as Integer
 dim names(1 to 32) as String
 dim shift as Integer

 SmReset()
 if mode = 0 then
  SmAdd("Edit this tile", "Enter", ENTER_KEY)
  SmAdd("Copy this tile", "Ctrl-C", 3)
  SmAdd("Paste the tile", "Ctrl-V", 22)
  SmAdd("Undo", "Ctrl-Z", 26)
  SmAdd("Revert this whole sheet", "Ctrl-R", 18)
  SmAdd("Edit the palette colors", "P", asc("p"))
  SmAdd("Choose the palette", "Comma Period", 0, 2)
  SmAdd("Choose the pose", "PgUp PgDn", 0, 1)
  SmAdd("Export this character as BMP", "E", asc("e"))
  SmAdd("Import this character from BMP", "I", asc("i"))
  SmAdd("Back to the list", "Esc", ESC_KEY)
  choice = SmRun("Tile sheet")
 elseif mode = 1 then
  SmAdd("Choose the brush color", "0 to 9, A to F", 0, 3)
  SmAdd("Flip the tile horizontally", "X", asc("x"))
  SmAdd("Flip the tile vertically", "Y", asc("y"))
  SmAdd("Copy this tile", "Ctrl-C", 3)
  SmAdd("Paste the tile", "Ctrl-V", 22)
  SmAdd("Undo", "Ctrl-Z", 26)
  SmAdd("Back to the tile sheet", "Esc", ESC_KEY)
  choice = SmRun("Tile " + str(tile_id))
 else
  SmAdd("Choose the color", "Left Right", 0, 11)
  SmAdd("Change its red", "Q A", 0, 12)
  SmAdd("Change its green", "W S", 0, 13)
  SmAdd("Change its blue", "E D", 0, 14)
  SmAdd("Move the color left", "Bracket", asc("["))
  SmAdd("Move the color right", "Bracket", asc("]"))
  SmAdd("Undo", "Ctrl-Z", 26)
  SmAdd("Revert this palette", "Ctrl-R", 18)
  SmAdd("Back to the tile sheet", "Esc", ESC_KEY)
  choice = SmRun("Palette " + str(pal))
 end if
 if choice = 0 then return 0
 if sm_special(choice) = 0 then return sm_key(choice)

 select case sm_special(choice)

  case 1 'pose
   for i as Integer = 0 to image_pose_count - 1
    names(i + 1) = FF4Name(BattlePoseName(ImagePoseId(i)))
   next
   picked = SmPick("Pose", names(), image_pose_count, ImagePoseIndex(pose) + 1)
   if picked > 0 then pose = ImagePoseId(picked - 1)

  case 2 'palette
   for i as Integer = 0 to 15
    names(i + 1) = "Palette " + str(i)
   next
   picked = SmPick("Palette", names(), 16, pal + 1)
   if picked > 0 then pal = picked - 1

  case 3 'brush color
   for i as Integer = 0 to 15
    names(i + 1) = hex(i) + " " + BattleColorTag(i)
   next
   picked = SmPick("Brush color", names(), 16, brush + 1)
   if picked > 0 then brush = picked - 1

  case 11 'color of the palette
   for i as Integer = 1 to 15
    names(i) = hex(i) + " " + BattleColorTag(i)
   next
   picked = SmPick("Color", names(), 15, slot)
   if picked > 0 then slot = picked

  case 12 to 14 'red, green, blue
   shift = (sm_special(choice) - 12) * 5
   picked = SmNumber((battle_palette_raw(pal, slot) \ (2 ^ shift)) mod 32, 31)
   BattleSetChannel(pal, slot, shift, picked)

 end select

 return 0

end function


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

 if KeyHelpPressed(keycode) then keycode = 0

  'The menu of every action: Space on the tile sheet, Enter in the other two screens. The entries that stand
  ' for a key are handled as that key.
  if (mode = 0 and keycode = SPACE_KEY) or (mode <> 0 and keycode = ENTER_KEY) then
   keycode = BattleActions(mode, sheet, tile_id, pose, pal, brush, slot)
  end if

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
    case SPACE_KEY
     if battle_char_gfx(sheet, tile_id, pixel_y, pixel_x) <> brush then
      BattleSpriteSaveUndo(sheet, tile_id)
      battle_char_gfx(sheet, tile_id, pixel_y, pixel_x) = brush
     end if
    case asc("["), asc("-")
     brush = (brush + 15) mod 16
    case asc("]"), asc("="), asc("+")
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
     BattleSetChannel(pal, slot, shift, channel)
    case asc("["), asc("]")
     s = slot + iif(keycode = asc("["), -1, 1)
     if s >= 1 and s <= 15 then
      BattleMoveColor(pal, slot, s)
      RefreshBattlePalettes()
      slot = s
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
    case asc("e"), asc("E")
     if ConfirmExport("this character") then InfoBox(ExportBattleSheet(sheet, pal) + "||Press any key", 4, 20)
    case asc("i"), asc("I")
     if ConfirmBox("Import replaces the sprites and palette of this character. Continue?") then
      InfoBox(ImportOneBattleSheet(sheet) + "||Press any key", 4, 20)
      RefreshBattlePalettes()
      bs_undo_count = 0
      bs_pal_undo_count = 0
     end if
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
     pose = ImagePoseId((ImagePoseIndex(pose) + image_pose_count - 1) mod image_pose_count)
    case PAGEDOWN_KEY
     pose = ImagePoseId((ImagePoseIndex(pose) + 1) mod image_pose_count)
    case asc(",")
     pal = (pal + 15) mod 16
    case asc(".")
     pal = (pal + 1) mod 16
    case 18 'Ctrl-R
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


function PickBattleSheet(title as String) as Integer

 'All characters (0) or one of them (its number plus 1). Returns -1 if cancelled.

 dim m as BlueMenu

 m = BlueMenu(4, 6)
 m.max_rows = 20
 m.title = title
 m.AddOption(FF4Text("All characters"))
 for i as Integer = 0 to total_battle_char_sheets - 1
  m.AddOption(BattleSheetName(i))
 next
 m.UserSelect()
 if m.cancelled then return -1

 return m.selected - 1

end function


sub EditBattleSprites()

 dim select_sheet as BlueMenu
 dim which as Integer

 RefreshBattlePalettes()

 select_sheet.max_rows = total_battle_char_sheets + 2
 for i as Integer = 0 to total_battle_char_sheets - 1
  select_sheet.AddOption(BattleSheetName(i))
 next
 select_sheet.AddOption(FF4Text("Export poses and palettes"))
 select_sheet.AddOption(FF4Text("Import poses and palettes"))

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
      WriteText(FF4Text("Enter asks for all characters or just one. Writes a BMP"), 37, 8, 15)
      WriteText(FF4Text("per character with all the poses packed together,"), 37, 9, 15)
      WriteText(FF4Text("poses_NN_pal_PP.bmp, 112x48. The palette is the BMP's"), 37, 10, 15)
      WriteText(FF4Text("own color table."), 37, 11, 15)
     case else
      WriteText(FF4Text("Enter asks for all characters or just one. Reads"), 37, 7, 15)
      WriteText(FF4Text("poses_NN_pal_PP.bmp and splits the poses"), 37, 8, 15)
      WriteText(FF4Text("back into tiles. Tiles shared by several poses take"), 37, 9, 15)
      WriteText(FF4Text("the pose you changed. If two differ, the first pose"), 37, 10, 15)
      WriteText(FF4Text("wins and you are told. The color table sets the palette."), 37, 11, 15)
    end select
   end if
   screenunlock
  loop until select_sheet.UserInput()

  if not select_sheet.cancelled then
   if select_sheet.selected <= total_battle_char_sheets then
    EditBattleSheet(select_sheet.selected - 1)
   elseif select_sheet.selected = total_battle_char_sheets + 1 then
    which = PickBattleSheet("Export which character?")
    if which = 0 then
     if ConfirmExport("all characters") then InfoBox(ExportBattleSprites() + "||Press any key", 4, 20)
    elseif which > 0 then
     if ConfirmExport("that character") then InfoBox(ExportBattleSheet(which - 1, which - 1) + "||Press any key", 4, 20)
    end if
   else
    which = PickBattleSheet("Import which character?")
    if which >= 0 then
     if ConfirmBox("Import replaces the current sprites and palettes. Continue?") then
      if which = 0 then
       InfoBox(ImportBattleSprites() + "||Press any key", 4, 20)
      else
       InfoBox(ImportOneBattleSheet(which - 1) + "||Press any key", 4, 20)
      end if
      RefreshBattlePalettes()
     end if
    end if
   end if
  end if

 loop until select_sheet.cancelled

end sub
