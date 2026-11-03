'Title screen (the picture shown at "Press A"): a 32x32 tile background, mode 1 BG1, 4 bits per pixel.
'The game loads (field/title_en.asm, ShowTitle) the graphics from 08/c000 (256 tiles of 32 bytes, 0x2000), the tilemap
'from 08/e000 (32x32 entries of 2 bytes, 0x800) and the palettes from 08/e800 (8 palettes of 16 colors, 0x100).
'A tilemap entry holds the tile number (low 10 bits), the palette (bits 10-12) and flip / priority bits. The original
'uses no flips and no priority, so the editor keeps one color number per pixel plus a palette number per 8x8 tile;
'saving finds the different tiles again. Only the top 28 tile rows (224 lines) show on the screen.
'Color 0 of every tile is transparent: the screen shows the backdrop, which is color 0 of palette 0.

const title_gfx_base = &h44200 'includes the 0x200 header that ff4rom always carries
const title_map_base = &h46200
const title_pal_base = &h46A00
const title_max_tiles = 256
const title_rows = 28 'tile rows that show on the screen


sub DecodeTitle(source as String, px() as UByte, cellpal() as UByte, pal() as UInteger)

 dim entry as Integer
 dim tile_no as Integer
 dim start as Integer
 dim b0 as UByte
 dim b1 as UByte
 dim b2 as UByte
 dim b3 as UByte
 dim c as Integer
 dim dx as Integer
 dim dy as Integer

 for cell as Integer = 0 to 1023
  entry = asc(mid(source, title_map_base + cell * 2 + 1, 1)) + asc(mid(source, title_map_base + cell * 2 + 2, 1)) * &h100
  tile_no = entry and &hFF
  start = title_gfx_base + tile_no * 32
  cellpal(cell \ 32, cell mod 32) = (entry shr 10) and 7
  for y as Integer = 0 to 7
   b0 = asc(mid(source, start + y * 2 + 1, 1))
   b1 = asc(mid(source, start + y * 2 + 2, 1))
   b2 = asc(mid(source, start + 16 + y * 2 + 1, 1))
   b3 = asc(mid(source, start + 16 + y * 2 + 2, 1))
   for x as Integer = 0 to 7
    c = ((b0 shr (7 - x)) and 1) or (((b1 shr (7 - x)) and 1) shl 1) or (((b2 shr (7 - x)) and 1) shl 2) or (((b3 shr (7 - x)) and 1) shl 3)
    dx = x
    dy = y
    if (entry and &h4000) <> 0 then dx = 7 - x
    if (entry and &h8000) <> 0 then dy = 7 - y
    px((cell \ 32) * 8 + dy, (cell mod 32) * 8 + dx) = c
   next
  next
 next

 for p as Integer = 0 to 7
  for i as Integer = 0 to 15
   pal(p, i) = asc(mid(source, title_pal_base + p * 32 + i * 2 + 1, 1)) + asc(mid(source, title_pal_base + p * 32 + i * 2 + 2, 1)) * &h100
  next
 next

end sub


sub ReadTitle()

 DecodeTitle(ff4rom, title_px(), title_cellpal(), title_pal_raw())
 title_tiles_stale = true

end sub


function TitleTileHash(cell as Integer) as UInteger

 dim h as UInteger = 2166136261

 for y as Integer = 0 to 7
  for x as Integer = 0 to 7
   h = (h xor title_px((cell \ 32) * 8 + y, (cell mod 32) * 8 + x)) * 16777619
  next
 next

 return h

end function


function TitleSameTile(a as Integer, b as Integer) as Boolean

 for y as Integer = 0 to 7
  for x as Integer = 0 to 7
   if title_px((a \ 32) * 8 + y, (a mod 32) * 8 + x) <> title_px((b \ 32) * 8 + y, (b mod 32) * 8 + x) then return false
  next
 next

 return true

end function


function TitleBuildTiles() as Integer

 'Finds the different tiles of the picture, in order of first appearance. Fills title_tile_cell (the first cell
 ' of each different tile) and title_cell_tile (the tile of each cell). Returns how many there are.

 dim hashes(1023) as UInteger
 dim count as Integer = 0
 dim found as Integer

 for cell as Integer = 0 to 1023
  hashes(cell) = TitleTileHash(cell)
  found = -1
  for k as Integer = 0 to count - 1
   if hashes(title_tile_cell(k)) = hashes(cell) then
    if TitleSameTile(title_tile_cell(k), cell) then
     found = k
     exit for
    end if
   end if
  next
  if found < 0 then
   found = count
   title_tile_cell(count) = cell
   count += 1
  end if
  title_cell_tile(cell) = found
 next

 return count

end function


function TitleTileCount() as Integer

 'Different tiles in the picture now (cached until the picture changes)

 if title_tiles_stale then
  title_tiles_used = TitleBuildTiles()
  title_tiles_stale = false
 end if

 return title_tiles_used

end function
