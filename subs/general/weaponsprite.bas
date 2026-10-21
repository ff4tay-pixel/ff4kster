'Weapon sprite preview for the weapon editor's Visuals menu.
'
'A weapon's visuals are four bytes: palette, sprite, slash and swing. The sprite is a number
'from 0 to 25 that picks 8 tiles of 3 bits per pixel graphics (WeaponGfx, 1c/d900); sprite N
'starts at tile 4 * N. The 8 tiles are two 16x16 pictures, each made of four tiles
'(top left, top right, bottom left, bottom right): the weapon as it is held and as it looks
'at the other end of the swing. The palette is one of the 64 animation palettes (8 colors,
'color 0 transparent), the same list the spells use.
'
'ff4rom always carries a 0x200 byte header, so the ROM offset below includes it.

const ws_gfx = &hE5B00 'WeaponGfx (1c/d900)
const ws_sprite_count = 26
const ws_box_x = 50
const ws_box_y = 36
const ws_box_w = 27
const ws_box_h = 14
const ws_zoom = 6


sub WeaponSpritePanel(palette_id as Integer, sprite_id as Integer)

 'Draws the weapon's two sprite frames, enlarged, in a box to the right of the Visuals menu

 dim colors(7) as UInteger
 dim v as Integer
 dim base_address as Integer
 dim tile_start as Integer
 dim p0 as UByte
 dim p1 as UByte
 dim p2 as UByte
 dim color_index as Integer
 dim frame_x as Integer
 dim frame_y as Integer
 dim valid as Boolean

 BlueBox(ws_box_x, ws_box_y, ws_box_w, ws_box_h)
 WriteText(FF4Text(" Weapon sprite "), ws_box_x + 1, ws_box_y, 14)
 line ((ws_box_x + 1) * 8, (ws_box_y + 1) * 8)-((ws_box_x + ws_box_w + 1) * 8 - 1, (ws_box_y + ws_box_h + 1) * 8 - 1), RGB(16, 16, 32), bf

 valid = (sprite_id >= 0 and sprite_id < ws_sprite_count and palette_id >= 0 and palette_id < 64)
 if valid then valid = (ws_gfx + (sprite_id * 4 + 8) * 24 <= len(ff4rom))

 if not valid then
  WriteText(FF4Text("No preview for this sprite"), ws_box_x + 1, ws_box_y + 7, 7)
  exit sub
 end if

 for i as Integer = 0 to 7
  v = ByteAt(sa_palettes + palette_id * 16 + i * 2) + ByteAt(sa_palettes + palette_id * 16 + i * 2 + 1) * &h100
  colors(i) = RGB((v and 31) * 8, ((v shr 5) and 31) * 8, ((v shr 10) and 31) * 8)
 next

 for frame as Integer = 0 to 1
  base_address = ws_gfx + (sprite_id * 4 + frame * 4) * 24
  frame_x = (ws_box_x + 1) * 8 + 8 + frame * (16 * ws_zoom + 8)
  frame_y = (ws_box_y + 1) * 8 + 8
  for t as Integer = 0 to 3
   tile_start = base_address + t * 24
   for row as Integer = 0 to 7
    p0 = ByteAt(tile_start + row * 2)
    p1 = ByteAt(tile_start + row * 2 + 1)
    p2 = ByteAt(tile_start + 16 + row)
    for col as Integer = 0 to 7
     color_index = ((p0 shr (7 - col)) and 1) or (((p1 shr (7 - col)) and 1) shl 1) or (((p2 shr (7 - col)) and 1) shl 2)
     if color_index <> 0 then
      line (frame_x + ((t mod 2) * 8 + col) * ws_zoom, frame_y + ((t \ 2) * 8 + row) * ws_zoom)-step(ws_zoom - 1, ws_zoom - 1), colors(color_index), bf
     end if
    next
   next
  next
 next

end sub
