'Export and import of monster sprites as images.
'
'One monster is one 4 bits per pixel BMP, exports\monster_sprites\monster_NNN_Name.bmp, as wide as the
'monster's tiles and as high as its tiles. The monster's palette (8 colors, color 0 is the
'transparent one) is the BMP's own color table: entry N is palette color N and a pixel's value is its
'palette index. On import the color table becomes the palette and the pixels keep their values, so an
'image editor must not renumber the colors; a pixel above the last color is rejected. (Older images one
'pixel wider, with the palette as pixels in the top right corner, are still read.)
'
'Zeromus's last form and the Dummy are 4 bits per pixel art with 16 colors (the palette and the one
'after it in the table): their images have 16 colors instead.
'
'  ordinary monsters (size 00-3F)  the tiles in order, row by row
'  bosses (size 80-BF)             the cells of the boss's tile map; empty cells are left blank on export
'                                  and ignored on import. If one tile appears in several cells and the
'                                  cells were edited differently, the first cell wins and the import
'                                  says so.
'  party members used as enemies (size 40-7F) are drawn from the battle sprite sheets: edit them with the
'                                  Battle Sprites editor.
'
'After an import the sprite editor sorts the palette the usual way (1 black, 2 white, the rest from light
'to dark; MsSortPalette), renumbering every monster that shares the tiles or palette.
'
'Importing writes the tiles and the palette straight into the ROM image, so every monster that uses the
'same graphics pointer or the same palette changes too (the message says how many).

const monster_swatch_count = 8
const monster_palette_table = &hE7000 'total_monster_palettes palettes of 8 colors, 2 bytes each


function MonsterImageName(index as Integer) as String

 'monster_NNN_Name.bmp, with anything but letters and digits in the name turned into _

 dim plain as String = FF4Name(monsters(index).name)
 dim result as String
 dim c as String

 for i as Integer = 1 to len(plain)
  c = mid(plain, i, 1)
  if (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") then result += c else result += "_"
 next

 return "monster_" + Pad(str(index), 3, true, "0") + "_" + result + ".bmp"

end function


function MonsterSpritePath(file_name as String) as String

 mkdir system_path + "\exports"
 mkdir system_path + "\exports\monster_sprites"

 return system_path + "\exports\monster_sprites\" + file_name

end function


function MonsterSwatches(gfx_ptr as Integer, size as Integer) as Integer

 'Palette pixels in a monster's image: 16 for 4 bits per pixel art, else 8

 if size < &h40 or size >= &h80 then
  if MonsterIsDeep(gfx_ptr) then return 16
 end if

 return monster_swatch_count

end function


function MonsterLayout(size as Integer, pal as Integer, byref tiles_wide as Integer, byref tiles_high as Integer, byref palette_id as Integer, byref cell_count as Integer, byref problem as String) as Boolean

 'Which tile (boss_cells, -1 = empty) goes in each cell of a monster's image, how many cells wide
 ' and high it is, and which palette it uses.

 if size >= &h80 then
  cell_count = MonsterBossCells((size and &h3F) + 1, tiles_wide, tiles_high, palette_id)
  if cell_count = 0 then
   problem = "this boss has no usable tile map"
   return false
  end if
  return true
 end if

 if size >= &h40 then
  problem = "party members used as enemies are edited in the Battle Sprites editor"
  return false
 end if

 MonsterSizeTiles(size, tiles_wide, tiles_high)
 if tiles_wide = 0 then
  problem = "this monster's size is not in the size table"
  return false
 end if
 if pal < 0 or pal >= total_monster_palettes then
  problem = "palette " + str(pal) + " does not exist"
  return false
 end if

 palette_id = pal
 cell_count = tiles_wide * tiles_high
 for n as Integer = 0 to cell_count - 1
  boss_cells(n) = n
 next

 return true

end function


function MonsterSharedCount(index as Integer, gfx_ptr as Integer, palette_id as Integer, size as Integer) as Integer

 'How many other monsters use the same graphics pointer or palette

 dim count as Integer

 for i as Integer = 1 to total_monsters
  if i <> index then
   if monsters(i).gfx_ptr1 + monsters(i).gfx_ptr2 * &h100 = gfx_ptr and monsters(i).size < &h40 and size < &h40 then
    count += 1
   elseif size < &h80 and monsters(i).size < &h80 and monsters(i).pal = palette_id then
    count += 1
   elseif size >= &h80 and monsters(i).size = size then
    count += 1
   end if
  end if
 next

 return count

end function


function ExportMonsterImage(index as Integer) as String

 'Returns a message for the user

 dim gfx_ptr as Integer = monsters(index).gfx_ptr1 + monsters(index).gfx_ptr2 * &h100
 dim size as Integer = monsters(index).size
 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim palette_id as Integer
 dim cell_count as Integer
 dim problem as String
 dim start as Integer = MonsterSpriteOffset(gfx_ptr)
 dim colors(15) as UInteger
 dim tile_number as Integer
 dim file_name as String = MonsterImageName(index)
 dim swatches as Integer = MonsterSwatches(gfx_ptr, size)
 dim deep as Boolean = (swatches = 16)

 if not MonsterLayout(size, monsters(index).pal, tiles_wide, tiles_high, palette_id, cell_count, problem) then return "Cannot export: " + problem
 if deep and (tiles_high * 8 < 16 or palette_id + 1 >= total_monster_palettes) then return "Cannot export: 16 color art needs an image at least 16 pixels high and a following palette"

 for y as Integer = 0 to tiles_high * 8 - 1
  for x as Integer = 0 to tiles_wide * 8 - 1
   bmp_px(y, x) = 0
  next
 next

 for n as Integer = 0 to cell_count - 1
  tile_number = boss_cells(n)
  if tile_number >= 0 and start + tile_number * MonsterTileBytes(deep) + MonsterTileBytes(deep) <= len(ff4rom) then
   for row as Integer = 0 to 7
    for col as Integer = 0 to 7
     bmp_px((n \ tiles_wide) * 8 + row, (n mod tiles_wide) * 8 + col) = MonsterTileColor(start, tile_number, row, col, deep)
    next
   next
  end if
 next

 for i as Integer = 0 to swatches - 1
  colors(i) = ByteAt(monster_palette_table + palette_id * 16 + i * 2) + ByteAt(monster_palette_table + palette_id * 16 + i * 2 + 1) * &h100
 next

 if not WriteIndexedBMPColors(MonsterSpritePath(file_name), tiles_wide * 8, tiles_high * 8, colors()) then
  return "Cannot write exports/monster_sprites|Check that the folder can be written"
 end if

 return "Wrote " + str(tiles_wide * 8) + "x" + str(tiles_high * 8) + " pixels, " + str(swatches) + " colors, palette " + str(palette_id) + "|exports\monster_sprites\" + file_name

end function


sub MonsterWriteTile(start as Integer, tile_number as Integer, tile_px() as UByte, deep as Boolean)

 'Stores one 8x8 tile as planar data, 3 bits per pixel or 4 if deep (see MonsterTileColor)

 dim plane0 as Integer
 dim plane1 as Integer
 dim plane2 as Integer
 dim plane3 as Integer
 dim c as Integer
 dim tile_start as Integer = start + tile_number * MonsterTileBytes(deep)

 for row as Integer = 0 to 7
  plane0 = 0
  plane1 = 0
  plane2 = 0
  plane3 = 0
  for col as Integer = 0 to 7
   c = tile_px(row * 8 + col)
   plane0 or= (c and 1) shl (7 - col)
   plane1 or= ((c shr 1) and 1) shl (7 - col)
   plane2 or= ((c shr 2) and 1) shl (7 - col)
   plane3 or= ((c shr 3) and 1) shl (7 - col)
  next
  WriteByte(tile_start + row * 2, plane0)
  WriteByte(tile_start + row * 2 + 1, plane1)
  if deep then
   WriteByte(tile_start + 16 + row * 2, plane2)
   WriteByte(tile_start + 16 + row * 2 + 1, plane3)
  else
   WriteByte(tile_start + 16 + row, plane2)
  end if
 next

end sub


function ImportMonsterImage(index as Integer) as String

 'Returns a message for the user

 dim gfx_ptr as Integer = monsters(index).gfx_ptr1 + monsters(index).gfx_ptr2 * &h100
 dim size as Integer = monsters(index).size
 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim palette_id as Integer
 dim cell_count as Integer
 dim problem as String
 dim start as Integer = MonsterSpriteOffset(gfx_ptr)
 dim new_palette(15) as UInteger
 dim file_name as String
 dim tile_number as Integer
 dim chosen(1023) as Integer 'the cell whose pixels a tile takes, or -1
 dim differs as Boolean
 dim differs_from_chosen as Boolean
 dim tile_px(63) as UByte
 dim conflicts as Integer
 dim written as Integer
 dim skipped as Integer
 dim shared_count as Integer
 dim message as String
 dim prefix as String = "monster_" + Pad(str(index), 3, true, "0") + "_"
 dim swatches as Integer = MonsterSwatches(gfx_ptr, size)
 dim deep as Boolean = (swatches = 16)

 if not MonsterLayout(size, monsters(index).pal, tiles_wide, tiles_high, palette_id, cell_count, problem) then return "Cannot import: " + problem
 if deep and (tiles_high * 8 < 16 or palette_id + 1 >= total_monster_palettes) then return "Cannot import: 16 color art needs an image at least 16 pixels high and a following palette"

 file_name = dir(MonsterSpritePath(prefix + "*.bmp"))
 if len(file_name) = 0 then file_name = dir(MonsterSpritePath("monster_" + Pad(str(index), 3, true, "0") + ".bmp"))
 if len(file_name) = 0 then return "No image for this monster|Looked for exports/monster_sprites/" + prefix + "*.bmp"

 for i as Integer = 0 to swatches - 1
  new_palette(i) = ByteAt(monster_palette_table + palette_id * 16 + i * 2) + ByteAt(monster_palette_table + palette_id * 16 + i * 2 + 1) * &h100
 next
 if not ReadBMPWithPalette(MonsterSpritePath(file_name), tiles_wide * 8, tiles_high * 8, swatches, new_palette(), problem) then return file_name + ": " + problem

 for t as Integer = 0 to 1023
  chosen(t) = -1
 next

 'Decide, tile by tile, which cell's pixels to store
 for n as Integer = 0 to cell_count - 1
  tile_number = boss_cells(n)
  if tile_number >= 0 then
   if tile_number > 1023 or start + tile_number * MonsterTileBytes(deep) + MonsterTileBytes(deep) > len(ff4rom) then
    skipped += 1
   else
    differs = false
    for row as Integer = 0 to 7
     for col as Integer = 0 to 7
      if bmp_px((n \ tiles_wide) * 8 + row, (n mod tiles_wide) * 8 + col) <> MonsterTileColor(start, tile_number, row, col, deep) then differs = true
     next
    next
    if differs then
     if chosen(tile_number) < 0 then
      chosen(tile_number) = n
     else
      differs_from_chosen = false
      for row as Integer = 0 to 7
       for col as Integer = 0 to 7
        if bmp_px((n \ tiles_wide) * 8 + row, (n mod tiles_wide) * 8 + col) <> bmp_px((chosen(tile_number) \ tiles_wide) * 8 + row, (chosen(tile_number) mod tiles_wide) * 8 + col) then differs_from_chosen = true
       next
      next
      if differs_from_chosen then conflicts += 1
     end if
    end if
   end if
  end if
 next

 for t as Integer = 0 to 1023
  if chosen(t) >= 0 then
   for row as Integer = 0 to 7
    for col as Integer = 0 to 7
     tile_px(row * 8 + col) = bmp_px((chosen(t) \ tiles_wide) * 8 + row, (chosen(t) mod tiles_wide) * 8 + col)
    next
   next
   MonsterWriteTile(start, t, tile_px(), deep)
   written += 1
  end if
 next

 'The palette (16 color art also stores the next palette)
 for i as Integer = 0 to swatches - 1
  WriteByte(monster_palette_table + palette_id * 16 + i * 2, new_palette(i) mod &h100)
  WriteByte(monster_palette_table + palette_id * 16 + i * 2 + 1, new_palette(i) \ &h100)
  monster_palettes(palette_id + 1 + i \ 8, i mod 8) = RGB((new_palette(i) mod 32) * 8, ((new_palette(i) \ 32) mod 32) * 8, ((new_palette(i) \ 1024) mod 32) * 8)
 next

 message = "Imported " + file_name + "|" + str(written) + " tiles changed, palette " + str(palette_id) + iif(deep, " and the next one", "") + " stored"
 if conflicts > 0 then message += "|" + str(conflicts) + " cells share a tile but were edited differently, the first one was kept"
 if skipped > 0 then message += "|" + str(skipped) + " cells use tiles outside the ROM and were skipped"
 shared_count = MonsterSharedCount(index, gfx_ptr, palette_id, size)
 if shared_count > 0 then message += "||" + str(shared_count) + " other monsters share this graphics or palette and change too"

 return message

end function
