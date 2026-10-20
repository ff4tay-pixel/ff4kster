'Monster sprite renderer, used by the Edit Graphics preview and the formation view.
'
'A monster's graphics are described by its size byte, palette and graphics pointer:
'  size 00-3F   an ordinary monster: a block of 3 bits per pixel 8x8 tiles in row-major order. The
'               size number picks the width and height (in tiles) from the game's size table.
'  size 40-7F   a party member used as an enemy: the low 6 bits are the character's battle sprite
'               sheet (the same sheets as the Battle Sprites editor) in its standing pose.
'  size 80-BF   a boss: the low 6 bits pick an entry of the special size table (see
'               SpecialSize). That entry gives the position, the palette, the size and the
'               number of a tile map that says which tile goes in each cell; a cell is empty
'               (FF), or a run of empty cells (FE then a count), or a tile number.
'The graphics pointer P addresses the tile data at &h48200 + (P * 8 mod &h40000) (the offsets
'include the 0x200 header that ff4rom always carries), so pointers below 8000h are valid too.
'Graphics pointers below 8000h are 4 bits per pixel instead (16 colors, 32 bytes per tile, the second
'8 colors come from the next palette): only Zeromus's last form and the Dummy use that.
'Pixel 0 is transparent: the images use RGB(255, 0, 255) for it.
'
'The pixels are written straight into the image's memory. Do not draw into these images with PSET or
'LINE and then destroy them without drawing anything else in between: FreeBASIC keeps a pointer to the
'last image drawn into, and destroying that image leaves it dangling, which crashed the program.

const monster_sprite_base = &h48200
const monster_size_table = &h7015E 'MonsterGfxSize: 43 entries of width, height in tiles (0d/ff5e)
const monster_size_count = 43
const boss_tilemap_ptrs = &h75100 'BossTilemapPtrs: 57 pointers (0e/cf00)
const boss_tilemap_count = 57
const monster_transparent = &hFFFF00FF 'RGB(255, 0, 255)

'Tile numbers of the boss being drawn
dim shared boss_cells(1023) as Integer

function MonsterNewImage(tiles_wide as Integer, tiles_high as Integer, byref pixels as Any ptr, byref pitch as Integer) as Any ptr

 'A transparent image of tiles_wide x tiles_high tiles, with the address and row size of its pixels

 dim result as Any ptr = ImageCreate(tiles_wide * 8, tiles_high * 8, monster_transparent)

 if result <> 0 then imageinfo result, , , , pitch, pixels
 return result

end function


sub MonsterPutPixel(pixels as Any ptr, pitch as Integer, x as Integer, y as Integer, c as UInteger)

 *cast(UInteger ptr, pixels + y * pitch + x * 4) = c

end sub


function MonsterSpriteOffset(gfx_ptr as UInteger) as Integer

 return monster_sprite_base + ((gfx_ptr * 8) mod &h40000)

end function


sub MonsterSizeTiles(size_id as Integer, byref tiles_wide as Integer, byref tiles_high as Integer)

 'Width and height in tiles of a size from the game's size table (0 if there is no such size)

 if size_id >= 0 and size_id < monster_size_count then
  tiles_wide = ByteAt(monster_size_table + size_id * 2)
  tiles_high = ByteAt(monster_size_table + size_id * 2 + 1)
 else
  tiles_wide = 0
  tiles_high = 0
 end if

end sub


function MonsterIsDeep(gfx_ptr as UInteger) as Boolean

 'Graphics pointers below 8000h address 4 bits per pixel art (16 colors, 32 bytes per tile); the
 ' game checks bit 15 of the pointer (btlgfx/ppu.asm, "branch if 3bpp graphics"). Only Zeromus's
 ' last form and the Dummy use it. Everything else is 3 bits per pixel (8 colors, 24 bytes per tile).

 return gfx_ptr < &h8000

end function


function MonsterTileBytes(deep as Boolean) as Integer

 if deep then return 32
 return 24

end function


function MonsterPaletteColor(palette_id as Integer, c as Integer) as UInteger

 'The color of color number c. Colors 8-15 (4 bits per pixel art) come from the next palette in the
 ' table: the game loads two palettes (32 bytes) for every monster.

 if c < 8 then return monster_palettes(palette_id + 1, c)
 if palette_id + 2 > total_monster_palettes then return RGB(0, 0, 0)

 return monster_palettes(palette_id + 2, c - 8)

end function


function MonsterTileColor(start as Integer, t as Integer, row as Integer, col as Integer, deep as Boolean = false) as Integer

 'The color number (0-7, or 0-15 if deep) of one pixel of tile t of the graphics starting at start

 dim tile_start as Integer = start + t * MonsterTileBytes(deep)

 if deep then
  return ((ByteAt(tile_start + row * 2) shr (7 - col)) and 1) or (((ByteAt(tile_start + row * 2 + 1) shr (7 - col)) and 1) shl 1) or (((ByteAt(tile_start + 16 + row * 2) shr (7 - col)) and 1) shl 2) or (((ByteAt(tile_start + 16 + row * 2 + 1) shr (7 - col)) and 1) shl 3)
 end if

 return ((ByteAt(tile_start + row * 2) shr (7 - col)) and 1) or (((ByteAt(tile_start + row * 2 + 1) shr (7 - col)) and 1) shl 1) or (((ByteAt(tile_start + 16 + row) shr (7 - col)) and 1) shl 2)

end function


function MonsterRegularImage(gfx_ptr as UInteger, size_id as Integer, pal as Integer) as Any ptr

 'An ordinary monster: a block of tiles in order

 dim deep as Boolean
 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim start as Integer
 dim result as Any ptr
 dim color_index as Integer
 dim pixel_value as UInteger
 dim pixels as Any ptr
 dim pitch as Integer

 start = MonsterSpriteOffset(gfx_ptr)
 MonsterSizeTiles(size_id, tiles_wide, tiles_high)
 if tiles_wide = 0 then return 0
 deep = MonsterIsDeep(gfx_ptr)
 if start + tiles_wide * tiles_high * MonsterTileBytes(deep) > len(ff4rom) then return 0
 if pal < 0 or pal >= total_monster_palettes then return 0

 result = MonsterNewImage(tiles_wide, tiles_high, pixels, pitch)
 if result = 0 then return 0
 for n as Integer = 0 to tiles_wide * tiles_high - 1
  for row as Integer = 0 to 7
   for col as Integer = 0 to 7
    color_index = MonsterTileColor(start, n, row, col, deep)
    if color_index <> 0 then
     pixel_value = MonsterPaletteColor(pal, color_index)
     MonsterPutPixel(pixels, pitch, (n mod tiles_wide) * 8 + col, (n \ tiles_wide) * 8 + row, pixel_value)
    end if
   next
  next
 next

 return result

end function


function MonsterBossCells(special_index as Integer, byref tiles_wide as Integer, byref tiles_high as Integer, byref palette_id as Integer) as Integer

 'Reads a boss's tile map into boss_cells (tile number per cell, -1 for an empty cell). Returns the
 ' number of cells read, or 0 if the entry can't be used.

 dim tilemap_id as Integer
 dim ptr_value as Integer
 dim position as Integer
 dim value as Integer
 dim cell_count as Integer
 dim pixels as Any ptr
 dim pitch as Integer

 palette_id = special_sizes(special_index).palette_index
 tilemap_id = special_sizes(special_index).arrangement_pointer
 MonsterSizeTiles(special_sizes(special_index).size_table_pointer, tiles_wide, tiles_high)
 if tiles_wide = 0 or tiles_wide * tiles_high > 1024 or tilemap_id >= boss_tilemap_count then return 0
 if palette_id >= total_monster_palettes then return 0

 ptr_value = ByteAt(boss_tilemap_ptrs + tilemap_id * 2) + ByteAt(boss_tilemap_ptrs + tilemap_id * 2 + 1) * &h100
 if ptr_value < &h8000 then return 0
 position = ptr_value + &h68200 'bank 0e: ROM offset 0x70000 + (pointer - 0x8000), plus the header
 do while cell_count < tiles_wide * tiles_high
  if position >= len(ff4rom) then exit do
  value = ByteAt(position)
  if value = &hFF then
   boss_cells(cell_count) = -1
   cell_count += 1
   position += 1
  elseif value = &hFE then
   for n as Integer = 1 to ByteAt(position + 1)
    if cell_count < tiles_wide * tiles_high then
     boss_cells(cell_count) = -1
     cell_count += 1
    end if
   next
   position += 2
  else
   boss_cells(cell_count) = value
   cell_count += 1
   position += 1
  end if
 loop

 return cell_count

end function


function MonsterBossImage(gfx_ptr as UInteger, special_index as Integer) as Any ptr

 'A boss: the special size entry says which tile goes where, and which palette to use

 dim deep as Boolean
 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim start as Integer
 dim result as Any ptr
 dim color_index as Integer
 dim pixel_value as UInteger
 dim cell_tile as Integer
 dim palette_id as Integer
 dim cell_count as Integer
 dim pixels as Any ptr
 dim pitch as Integer

 start = MonsterSpriteOffset(gfx_ptr)
 deep = MonsterIsDeep(gfx_ptr)
 cell_count = MonsterBossCells(special_index, tiles_wide, tiles_high, palette_id)
 if cell_count = 0 then return 0

 result = MonsterNewImage(tiles_wide, tiles_high, pixels, pitch)
 if result = 0 then return 0
 for n as Integer = 0 to cell_count - 1
  cell_tile = boss_cells(n)
  if cell_tile >= 0 and start + cell_tile * MonsterTileBytes(deep) + MonsterTileBytes(deep) <= len(ff4rom) then
   for row as Integer = 0 to 7
    for col as Integer = 0 to 7
     color_index = MonsterTileColor(start, cell_tile, row, col, deep)
     if color_index <> 0 then
      pixel_value = MonsterPaletteColor(palette_id, color_index)
      MonsterPutPixel(pixels, pitch, (n mod tiles_wide) * 8 + col, (n \ tiles_wide) * 8 + row, pixel_value)
     end if
    next
   next
  end if
 next

 return result

end function


function MonsterPartyImage(sheet as Integer, pal as Integer) as Any ptr

 'A party member used as an enemy: the standing pose of their battle sprite (2 tiles wide, 3 tall)

 dim result as Any ptr
 dim color_index as Integer
 dim value as Integer
 dim pixel_value as UInteger
 dim palette_id as Integer
 dim pixels as Any ptr
 dim pitch as Integer

 if sheet < 0 or sheet >= total_battle_char_sheets then return 0
 palette_id = pal
 if palette_id > 15 then palette_id = sheet

 result = MonsterNewImage(2, 3, pixels, pitch)
 if result = 0 then return 0
 for n as Integer = 0 to 5
  for row as Integer = 0 to 7
   for col as Integer = 0 to 7
    color_index = battle_char_gfx(sheet, n, row, col)
    if color_index <> 0 then
     value = battle_palette_raw(palette_id, color_index)
     pixel_value = RGB((value mod 32) * 8, ((value \ 32) mod 32) * 8, ((value \ 1024) mod 32) * 8)
     MonsterPutPixel(pixels, pitch, (n mod 2) * 8 + col, (n \ 2) * 8 + row, pixel_value)
    end if
   next
  next
 next

 return result

end function


function MonsterSpriteImage(gfx_ptr as UInteger, size as UByte, pal as UByte, byref raw_sheet as Boolean) as Any ptr

 'Builds the picture of a monster, or returns 0 if it can't be drawn. raw_sheet is no longer
 ' used (every size can be drawn now) but is kept so the callers did not need to change.

 raw_sheet = false

 if size >= &h80 then return MonsterBossImage(gfx_ptr, (size and &h3F) + 1)
 if size >= &h40 then return MonsterPartyImage(size and &h3F, pal)

 return MonsterRegularImage(gfx_ptr, size, pal)

end function


'Live preview panel used while editing a monster's graphics. Draws a fixed box on the right
'side of the screen without waiting for a key. The pixels underneath are kept in snapshot
'(pass the same variable each time) and put back by MonsterSpritePanelHide.
const monster_panel_x = 47
const monster_panel_y = 2
const monster_panel_w = 30
const monster_panel_h = 20

sub MonsterSpritePanelShow(gfx_ptr as UInteger, size as UByte, pal as UByte, byref snapshot as Any ptr)

 dim sprite as Any ptr
 dim raw_sheet as Boolean
 dim sprite_w as Integer
 dim sprite_h as Integer
 dim zoom as Integer
 dim area_x as Integer
 dim area_y as Integer
 dim area_w as Integer = monster_panel_w * 8
 dim area_h as Integer = (monster_panel_h - 1) * 8
 dim info as String
 dim pixel_color as UInteger
 
 if snapshot = 0 then
  snapshot = ImageCreate((monster_panel_w + 2) * 8, (monster_panel_h + 2) * 8, RGB(0, 0, 0))
  get (monster_panel_x * 8, monster_panel_y * 8)-((monster_panel_x + monster_panel_w + 2) * 8 - 1, (monster_panel_y + monster_panel_h + 2) * 8 - 1), snapshot
 end if
 
 BlueBox(monster_panel_x, monster_panel_y, monster_panel_w, monster_panel_h)
 
 sprite = MonsterSpriteImage(gfx_ptr, size, pal, raw_sheet)
 
 line ((monster_panel_x + 1) * 8, (monster_panel_y + 1) * 8)-((monster_panel_x + monster_panel_w + 1) * 8 - 1, (monster_panel_y + monster_panel_h + 1) * 8 - 1), RGB(16, 16, 32), bf
 
 if sprite = 0 then
  WriteText(FF4Text("No preview for this monster"), monster_panel_x + 1, monster_panel_y + 1, 12)
 else
  if size >= &h80 then info = "Ptr " + str(gfx_ptr) + " Pal " + str(special_sizes((size and &h3F) + 1).palette_index) else info = "Ptr " + str(gfx_ptr) + " Pal " + str(pal)
  WriteText(FF4Text(left(info, monster_panel_w)), monster_panel_x + 1, monster_panel_y + 1, 15)
  imageinfo sprite, sprite_w, sprite_h
  zoom = 6
  if area_w \ sprite_w < zoom then zoom = area_w \ sprite_w
  if area_h \ sprite_h < zoom then zoom = area_h \ sprite_h
  if zoom < 1 then zoom = 1
  area_x = (monster_panel_x + 1) * 8 + (area_w - sprite_w * zoom) \ 2
  area_y = (monster_panel_y + 2) * 8 + (area_h - sprite_h * zoom) \ 2
  for y as Integer = 0 to sprite_h - 1
   for x as Integer = 0 to sprite_w - 1
    pixel_color = point(x, y, sprite)
    if pixel_color <> monster_transparent then line (area_x + x * zoom, area_y + y * zoom)-step(zoom - 1, zoom - 1), pixel_color, bf
   next
  next
  ImageDestroy(sprite)
 end if

 'Finish with a draw on the screen itself (the same pixel, so nothing changes). Without it FreeBASIC
 ' keeps pointing at the destroyed sprite image as its drawing target, and the next menu that builds
 ' an image corrupts it (the template menu drew as a thin strip).
 pset (monster_panel_x * 8, monster_panel_y * 8), point(monster_panel_x * 8, monster_panel_y * 8)

end sub


sub MonsterSpritePanelHide(byref snapshot as Any ptr)

 if snapshot <> 0 then
  put (monster_panel_x * 8, monster_panel_y * 8), snapshot, pset
  ImageDestroy(snapshot)
  snapshot = 0
 end if

end sub
