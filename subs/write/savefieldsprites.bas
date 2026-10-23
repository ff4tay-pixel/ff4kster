sub SaveFieldSprites()

 dim start as UInteger
 dim p0 as UByte
 dim p1 as UByte
 dim p2 as UByte
 dim c as UByte

 for sheet as Integer = 0 to total_field_sheets - 1
  for t as Integer = 0 to FieldSheetTiles(sheet) - 1
   start = FieldSheetOffset(sheet) + t * 24
   for y as Integer = 0 to 7
    p0 = 0
    p1 = 0
    p2 = 0
    for x as Integer = 0 to 7
     c = field_sprite_gfx(sheet, t, y, x)
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

 for i as Integer = 0 to total_field_palettes - 1
  for j as Integer = 0 to 7
   WriteByte(field_palette_table + i * 16 + j * 2, field_palette_raw(i, j) mod &h100)
   WriteByte(field_palette_table + i * 16 + j * 2 + 1, field_palette_raw(i, j) \ &h100)
  next
 next

end sub
