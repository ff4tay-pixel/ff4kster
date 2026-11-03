sub SaveTitle()

 'Writes the title screen if it differs from what the ROM image holds now. A picture that is the same is not
 ' written, so an unedited game keeps its original tile order. Needs at most 256 different tiles.

 dim same_picture as Boolean = true
 dim same_palette as Boolean = true
 dim count as Integer
 dim cell as Integer
 dim p0 as UByte
 dim p1 as UByte
 dim p2 as UByte
 dim p3 as UByte
 dim c as UByte
 dim start as UInteger

 DecodeTitle(ff4rom, title_cmp_px(), title_cmp_cellpal(), title_cmp_pal())

 for y as Integer = 0 to 255
  for x as Integer = 0 to 255
   if title_px(y, x) <> title_cmp_px(y, x) then same_picture = false
  next
 next
 for y as Integer = 0 to 31
  for x as Integer = 0 to 31
   if title_cellpal(y, x) <> title_cmp_cellpal(y, x) then same_picture = false
  next
 next
 for p as Integer = 0 to 7
  for i as Integer = 0 to 15
   if title_pal_raw(p, i) <> title_cmp_pal(p, i) then same_palette = false
  next
 next

 if not same_picture then
  count = TitleBuildTiles()
  if count > title_max_tiles then
   WarningMessage("Title screen: " + str(count) + " different tiles, only " + str(title_max_tiles) + " fit")
   same_picture = true
  end if
 end if

 if not same_picture then
  for k as Integer = 0 to title_max_tiles - 1
   start = title_gfx_base + k * 32
   for y as Integer = 0 to 7
    p0 = 0
    p1 = 0
    p2 = 0
    p3 = 0
    if k < count then
     cell = title_tile_cell(k)
     for x as Integer = 0 to 7
      c = title_px((cell \ 32) * 8 + y, (cell mod 32) * 8 + x)
      p0 or= ((c and 1) shl (7 - x))
      p1 or= (((c shr 1) and 1) shl (7 - x))
      p2 or= (((c shr 2) and 1) shl (7 - x))
      p3 or= (((c shr 3) and 1) shl (7 - x))
     next
    end if
    WriteByte(start + y * 2, p0)
    WriteByte(start + y * 2 + 1, p1)
    WriteByte(start + 16 + y * 2, p2)
    WriteByte(start + 16 + y * 2 + 1, p3)
   next
  next
  for cell = 0 to 1023
   c = title_cellpal(cell \ 32, cell mod 32)
   WriteByte(title_map_base + cell * 2, title_cell_tile(cell) and &hFF)
   WriteByte(title_map_base + cell * 2 + 1, (title_cell_tile(cell) \ &h100) + c * 4)
  next
 end if

 if not same_palette then
  for p as Integer = 0 to 7
   for i as Integer = 0 to 15
    WriteByte(title_pal_base + p * 32 + i * 2, title_pal_raw(p, i) mod &h100)
    WriteByte(title_pal_base + p * 32 + i * 2 + 1, title_pal_raw(p, i) \ &h100)
   next
  next
 end if

end sub
