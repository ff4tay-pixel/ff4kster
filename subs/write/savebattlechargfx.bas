sub SaveBattleCharGfx()

 dim start as UInteger
 dim p0 as UByte
 dim p1 as UByte
 dim p2 as UByte
 dim p3 as UByte
 dim c as UByte

 for s as Integer = 0 to total_battle_char_sheets - 1
  for t as Integer = 0 to 63
   start = battle_char_gfx_base + s * &h800 + t * 32
   for y as Integer = 0 to 7
    p0 = 0
    p1 = 0
    p2 = 0
    p3 = 0
    for x as Integer = 0 to 7
     c = battle_char_gfx(s, t, y, x)
     p0 or= ((c and 1) shl (7 - x))
     p1 or= (((c shr 1) and 1) shl (7 - x))
     p2 or= (((c shr 2) and 1) shl (7 - x))
     p3 or= (((c shr 3) and 1) shl (7 - x))
    next
    WriteByte(start + y * 2, p0)
    WriteByte(start + y * 2 + 1, p1)
    WriteByte(start + 16 + y * 2, p2)
    WriteByte(start + 16 + y * 2 + 1, p3)
   next
  next
 next
 
 for i as Integer = 0 to 15
  for j as Integer = 0 to 15
   WriteByte(battle_palette_table + i * 32 + j * 2, battle_palette_raw(i, j) mod &h100)
   WriteByte(battle_palette_table + i * 32 + j * 2 + 1, battle_palette_raw(i, j) \ &h100)
  next
 next

end sub
