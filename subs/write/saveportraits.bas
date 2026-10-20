sub SavePortraits()

 dim start as UInteger
 dim p0 as UByte
 dim p1 as UByte
 dim p2 as UByte
 dim c as UByte

 for p as Integer = 0 to total_portraits - 1
  for t as Integer = 0 to 15
   start = portrait_gfx_base + p * portrait_bytes + t * 24
   for y as Integer = 0 to 7
    p0 = 0
    p1 = 0
    p2 = 0
    for x as Integer = 0 to 7
     c = portrait_gfx(p, (t \ 4) * 8 + y, (t mod 4) * 8 + x)
     p0 or= ((c and 1) shl (7 - x))
     p1 or= (((c shr 1) and 1) shl (7 - x))
     p2 or= (((c shr 2) and 1) shl (7 - x))
    next
    WriteByte(start + y * 2, p0)
    WriteByte(start + y * 2 + 1, p1)
    WriteByte(start + 16 + y, p2)
   next
  next
 next

 for i as Integer = 0 to 15
  for j as Integer = 0 to 7
   WriteByte(portrait_palette_table + i * 16 + j * 2, portrait_palette_raw(i, j) mod &h100)
   WriteByte(portrait_palette_table + i * 16 + j * 2 + 1, portrait_palette_raw(i, j) \ &h100)
  next
 next

end sub
