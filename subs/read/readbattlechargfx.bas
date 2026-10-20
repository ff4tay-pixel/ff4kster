'Battle character graphics: 15 sheets of 64 4bpp tiles (32 bytes each) starting at 1a/8000.
'Pixels are held as color indices (0-15) so the sprite editor can change them.

const battle_char_gfx_base = &hD0200 'includes the 0x200 header that ff4rom always carries
const battle_palette_table = &hE7F00 '16 palettes of 16 colors
const battle_pose_offset_table = &h6FA3C 'sprite position id for each pose
const battle_sprite_offset_table = &h6FA61 'x, y, ?, attributes for the six sprites of a position id
const battle_tile_table = &h6FB61 'six tile numbers for each pose
const battle_pose_count = 12

sub DecodeBattleCharGfx(source as String, sheet as Integer, tile_id as Integer)

 dim start as UInteger
 dim p0 as UByte
 dim p1 as UByte
 dim p2 as UByte
 dim p3 as UByte

 start = battle_char_gfx_base + sheet * &h800 + tile_id * 32

 for y as Integer = 0 to 7
  p0 = asc(mid(source, start + y * 2 + 1, 1))
  p1 = asc(mid(source, start + y * 2 + 2, 1))
  p2 = asc(mid(source, start + 16 + y * 2 + 1, 1))
  p3 = asc(mid(source, start + 16 + y * 2 + 2, 1))
  for x as Integer = 0 to 7
   battle_char_gfx(sheet, tile_id, y, x) = ((p0 shr (7 - x)) and 1) or (((p1 shr (7 - x)) and 1) shl 1) or (((p2 shr (7 - x)) and 1) shl 2) or (((p3 shr (7 - x)) and 1) shl 3)
  next
 next

end sub


sub ReadBattleCharGfx()

 for s as Integer = 0 to total_battle_char_sheets - 1
  for t as Integer = 0 to 63
   DecodeBattleCharGfx(ff4rom, s, t)
  next
 next
 
 for i as Integer = 0 to 15
  for j as Integer = 0 to 15
   battle_palette_raw(i, j) = ByteAt(battle_palette_table + i * 32 + j * 2) + ByteAt(battle_palette_table + i * 32 + j * 2 + 1) * &h100
  next
 next

end sub
