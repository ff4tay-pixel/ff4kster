'Monster sprite and palette editor. See monsterspriteio.bas for how a monster's picture is laid out
'(ordinary monsters, bosses with a tile map, 16 color art). The monster's picture is copied into
'ms_px, edited there, and stored straight into the ROM image when the editor is left or another
'monster is chosen, like the BMP import does. Every monster that shares the graphics or the palette
'changes too; the screen says how many do. Sizes are not changed here.

const ms_undo_depth = 24
const ms_max_cells = 1024

dim shared ms_px(191, 191) as UByte 'row, column: the color number of each pixel
dim shared ms_cells(ms_max_cells - 1) as Integer 'tile number of each cell, -1 empty
dim shared ms_tiles_wide as Integer
dim shared ms_tiles_high as Integer
dim shared ms_cell_count as Integer
dim shared ms_palette_id as Integer
dim shared ms_start as Integer
dim shared ms_deep as Boolean
dim shared ms_color_count as Integer
dim shared ms_pal(15) as UInteger 'SNES colors
dim shared ms_undo_px(ms_undo_depth - 1, 191, 191) as UByte
dim shared ms_undo_count as Integer
dim shared ms_pal_undo_slot(ms_undo_depth - 1) as Integer
dim shared ms_pal_undo_value(ms_undo_depth - 1) as UInteger
dim shared ms_pal_undo_count as Integer
dim shared ms_touched(&h30000) as UByte 'tiles already renumbered, by address \ 8
dim shared ms_family_tile(&h30000) as UByte 'tiles used by the monsters whose colors move together, by address \ 8
dim shared ms_fill_x(191 * 191) as Integer
dim shared ms_fill_y(191 * 191) as Integer


declare sub MsCommitPalette()


function MsRomByte(rom as String, offset as Integer) as Integer

 return asc(mid(rom, offset + 1, 1))

end function


function MsTileColor(rom as String, tile_number as Integer, row as Integer, col as Integer) as Integer

 'Same as MonsterTileColor, from any ROM image (the loaded one for reverting)

 dim tile_start as Integer = ms_start + tile_number * MonsterTileBytes(ms_deep)
 dim c as Integer = ((MsRomByte(rom, tile_start + row * 2) shr (7 - col)) and 1) or (((MsRomByte(rom, tile_start + row * 2 + 1) shr (7 - col)) and 1) shl 1)

 if ms_deep then
  c or= (((MsRomByte(rom, tile_start + 16 + row * 2) shr (7 - col)) and 1) shl 2) or (((MsRomByte(rom, tile_start + 16 + row * 2 + 1) shr (7 - col)) and 1) shl 3)
 else
  c or= ((MsRomByte(rom, tile_start + 16 + row) shr (7 - col)) and 1) shl 2
 end if

 return c

end function


function MsColor(c as Integer) as UInteger

 'Screen color of color number c

 dim v as UInteger = ms_pal(c)

 return RGB((v mod 32) * 8, ((v \ 32) mod 32) * 8, ((v \ 1024) mod 32) * 8)

end function


sub MsLoadPalette(rom as String)

 for i as Integer = 0 to ms_color_count - 1
  ms_pal(i) = MsRomByte(rom, monster_palette_table + ms_palette_id * 16 + i * 2) + MsRomByte(rom, monster_palette_table + ms_palette_id * 16 + i * 2 + 1) * &h100
 next

end sub


sub MsLoadPixels(rom as String)

 dim tile_number as Integer

 for y as Integer = 0 to 191
  for x as Integer = 0 to 191
   ms_px(y, x) = 0
  next
 next
 for n as Integer = 0 to ms_cell_count - 1
  tile_number = ms_cells(n)
  if tile_number >= 0 then
   for row as Integer = 0 to 7
    for col as Integer = 0 to 7
     ms_px((n \ ms_tiles_wide) * 8 + row, (n mod ms_tiles_wide) * 8 + col) = MsTileColor(rom, tile_number, row, col)
    next
   next
  end if
 next

end sub


function MsLoad(index as Integer, byref problem as String) as Boolean

 'Reads the monster's picture and palette. False, with the reason, if it can't be edited here.

 dim gfx_ptr as Integer = monsters(index).gfx_ptr1 + monsters(index).gfx_ptr2 * &h100
 dim size as Integer = monsters(index).size

 ms_deep = MonsterIsDeep(gfx_ptr)
 if size >= &h40 and size < &h80 then ms_deep = false
 if ms_deep then ms_color_count = 16 else ms_color_count = 8
 ms_start = MonsterSpriteOffset(gfx_ptr)

 if not MonsterLayout(size, monsters(index).pal, ms_tiles_wide, ms_tiles_high, ms_palette_id, ms_cell_count, problem) then return false
 if ms_tiles_wide > 24 or ms_tiles_high > 24 then
  problem = "this picture is too big for the editor"
  return false
 end if
 if ms_deep and ms_palette_id + 1 >= total_monster_palettes then
  problem = "16 color art needs a following palette"
  return false
 end if
 for n as Integer = 0 to ms_cell_count - 1
  ms_cells(n) = boss_cells(n)
  if ms_cells(n) > ms_max_cells - 1 or (ms_cells(n) >= 0 and ms_start + ms_cells(n) * MonsterTileBytes(ms_deep) + MonsterTileBytes(ms_deep) > len(ff4rom)) then ms_cells(n) = -1
 next

 MsLoadPixels(ff4rom)
 MsLoadPalette(ff4rom)
 ms_undo_count = 0
 ms_pal_undo_count = 0

 return true

end function


sub MsCommit()

 'Stores the picture and palette in the ROM image

 dim tile_px(63) as UByte
 dim done_tile(ms_max_cells - 1) as Boolean

 for n as Integer = 0 to ms_cell_count - 1
  if ms_cells(n) >= 0 then
   if not done_tile(ms_cells(n)) then
    done_tile(ms_cells(n)) = true
    for row as Integer = 0 to 7
     for col as Integer = 0 to 7
      tile_px(row * 8 + col) = ms_px((n \ ms_tiles_wide) * 8 + row, (n mod ms_tiles_wide) * 8 + col)
     next
    next
    MonsterWriteTile(ms_start, ms_cells(n), tile_px(), ms_deep)
   end if
  end if
 next

 MsCommitPalette()

end sub


sub MsCommitPalette()

 for i as Integer = 0 to ms_color_count - 1
  WriteByte(monster_palette_table + ms_palette_id * 16 + i * 2, ms_pal(i) mod &h100)
  WriteByte(monster_palette_table + ms_palette_id * 16 + i * 2 + 1, ms_pal(i) \ &h100)
  monster_palettes(ms_palette_id + 1 + i \ 8, i mod 8) = MsColor(i)
 next

end sub


function MsMonsterTiles(i as Integer, mark as Boolean) as Boolean

 'Marks the tiles of monster i in ms_family_tile (mark = true), or tells whether any of them is marked

 dim gfx_ptr as Integer = monsters(i).gfx_ptr1 + monsters(i).gfx_ptr2 * &h100
 dim deep as Boolean = MonsterIsDeep(gfx_ptr)
 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim palette_id as Integer
 dim cell_count as Integer
 dim problem as String
 dim start as Integer = MonsterSpriteOffset(gfx_ptr)
 dim bytes as Integer = MonsterTileBytes(deep)
 dim address as Integer

 if not MonsterLayout(monsters(i).size, monsters(i).pal, tiles_wide, tiles_high, palette_id, cell_count, problem) then return false
 for n as Integer = 0 to cell_count - 1
  if boss_cells(n) >= 0 and boss_cells(n) < ms_max_cells then
   address = (start + boss_cells(n) * bytes) \ 8
   if address >= 0 and address <= ubound(ms_family_tile) then
    if mark then
     ms_family_tile(address) = 1
    elseif ms_family_tile(address) <> 0 then
     return true
    end if
   end if
  end if
 next

 return false

end function


sub MsMoveColor(slot as Integer, other as Integer)

 'Swaps two palette colors and renumbers the pixels of every monster that uses this palette, so they all
 ' look the same. Many monsters are recolors: they draw the same tiles with another palette. Those
 ' palettes get the same two colors swapped, and so on for everything that shares tiles or a palette
 ' with them, so nothing changes how it looks. The picture being edited is stored first and read back
 ' afterwards.

 dim gfx_ptr as Integer
 dim size as Integer
 dim user_deep as Boolean
 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim palette_id as Integer
 dim cell_count as Integer
 dim problem as String
 dim start as Integer
 dim bytes as Integer
 dim tile_number as Integer
 dim c as Integer
 dim tile_px(63) as UByte
 dim member(total_monsters) as Boolean 'monsters whose tiles are renumbered
 dim palette_of(total_monsters) as Integer
 dim palette_in(total_monster_palettes) as Boolean 'palettes that get the two colors swapped
 dim grew as Boolean
 dim v1 as Integer
 dim v2 as Integer

 MsCommit()
 for i as Integer = 0 to ubound(ms_touched)
  ms_touched(i) = 0
 next

 'The family: monsters using this palette, then any that share their tiles or palettes, and so on
 for i as Integer = 1 to total_monsters
  size = monsters(i).size
  gfx_ptr = monsters(i).gfx_ptr1 + monsters(i).gfx_ptr2 * &h100
  user_deep = MonsterIsDeep(gfx_ptr)
  palette_of(i) = -1
  if (size < &h40 or size >= &h80) and user_deep = ms_deep then
   if MonsterLayout(size, monsters(i).pal, tiles_wide, tiles_high, palette_id, cell_count, problem) then
    palette_of(i) = palette_id
    if palette_id = ms_palette_id then member(i) = true
   end if
  end if
 next
 palette_in(ms_palette_id) = true
 if not ms_deep then
  for i as Integer = 0 to ubound(ms_family_tile)
   ms_family_tile(i) = 0
  next
  for i as Integer = 1 to total_monsters
   if member(i) then MsMonsterTiles(i, true)
  next
  do
   grew = false
   for i as Integer = 1 to total_monsters
    if member(i) then palette_in(palette_of(i)) = true
   next
   for i as Integer = 1 to total_monsters
    if palette_of(i) >= 0 and not member(i) then
     if palette_in(palette_of(i)) or MsMonsterTiles(i, false) then
      member(i) = true
      MsMonsterTiles(i, true)
      grew = true
     end if
    end if
   next
  loop until not grew
  for i as Integer = 1 to total_monsters
   if member(i) then palette_in(palette_of(i)) = true
  next
 end if

 for i as Integer = 1 to total_monsters
  if member(i) then
   size = monsters(i).size
   gfx_ptr = monsters(i).gfx_ptr1 + monsters(i).gfx_ptr2 * &h100
   user_deep = MonsterIsDeep(gfx_ptr)
   if MonsterLayout(size, monsters(i).pal, tiles_wide, tiles_high, palette_id, cell_count, problem) then
    start = MonsterSpriteOffset(gfx_ptr)
    bytes = MonsterTileBytes(user_deep)
    for n as Integer = 0 to cell_count - 1
     tile_number = boss_cells(n)
     if tile_number >= 0 and tile_number < ms_max_cells and start + tile_number * bytes + bytes <= len(ff4rom) then
      if ms_touched((start + tile_number * bytes) \ 8) = 0 then
       ms_touched((start + tile_number * bytes) \ 8) = 1
       for row as Integer = 0 to 7
        for col as Integer = 0 to 7
         c = MonsterTileColor(start, tile_number, row, col, user_deep)
         if c = slot then
          c = other
         elseif c = other then
          c = slot
         end if
         tile_px(row * 8 + col) = c
        next
       next
       MonsterWriteTile(start, tile_number, tile_px(), user_deep)
      end if
     end if
    next
   end if
  end if
 next

 'the other palettes of the family swap the same two colors
 for pid as Integer = 0 to total_monster_palettes - 1
  if palette_in(pid) and pid <> ms_palette_id and not ms_deep then
   v1 = ByteAt(monster_palette_table + pid * 16 + slot * 2) + ByteAt(monster_palette_table + pid * 16 + slot * 2 + 1) * &h100
   v2 = ByteAt(monster_palette_table + pid * 16 + other * 2) + ByteAt(monster_palette_table + pid * 16 + other * 2 + 1) * &h100
   WriteByte(monster_palette_table + pid * 16 + slot * 2, v2 mod &h100)
   WriteByte(monster_palette_table + pid * 16 + slot * 2 + 1, v2 \ &h100)
   WriteByte(monster_palette_table + pid * 16 + other * 2, v1 mod &h100)
   WriteByte(monster_palette_table + pid * 16 + other * 2 + 1, v1 \ &h100)
   monster_palettes(pid + 1, slot) = RGB((v2 mod 32) * 8, ((v2 \ 32) mod 32) * 8, ((v2 \ 1024) mod 32) * 8)
   monster_palettes(pid + 1, other) = RGB((v1 mod 32) * 8, ((v1 \ 32) mod 32) * 8, ((v1 \ 1024) mod 32) * 8)
  end if
 next

 swap ms_pal(slot), ms_pal(other)
 MsCommitPalette()
 MsLoadPixels(ff4rom)
 ms_undo_count = 0
 ms_pal_undo_count = 0

end sub


function MsDeepUser() as Integer

 'A monster with 16 color art that uses this palette as one of its two, or 0. Its tiles number the colors
 ' of both palettes, so this palette cannot be reordered without that art.

 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim palette_id as Integer
 dim cell_count as Integer
 dim problem as String

 for i as Integer = 1 to total_monsters
  if (monsters(i).size < &h40 or monsters(i).size >= &h80) and MonsterIsDeep(monsters(i).gfx_ptr1 + monsters(i).gfx_ptr2 * &h100) then
   if MonsterLayout(monsters(i).size, monsters(i).pal, tiles_wide, tiles_high, palette_id, cell_count, problem) then
    if palette_id = ms_palette_id or palette_id + 1 = ms_palette_id then return i
   end if
  end if
 next

 return 0

end function


function MsSortPalette() as String

 'Puts the palette in the usual order for monsters: color 0 transparent, 1 the darkest (black), 2 the
 ' lightest (white), and the rest from light to dark. Every monster that uses the palette is renumbered,
 ' so none of them changes how it looks. Returns a message.

 dim brightness(7) as Integer
 dim wanted(7) as Integer 'the color now at each place that should end up there
 dim current(7) as Integer 'which original color sits at each place now
 dim used(7) as Boolean
 dim best as Integer
 dim found as Integer
 dim swaps as Integer
 dim q as Integer

 if ms_deep then return "The 16 color art keeps its palette as it is."
 if MsDeepUser() > 0 then return "Palette not sorted: monster " + str(MsDeepUser()) + " has 16 color art that uses it."

 for i as Integer = 1 to 7
  brightness(i) = 30 * (ms_pal(i) mod 32) + 59 * ((ms_pal(i) \ 32) mod 32) + 11 * ((ms_pal(i) \ 1024) mod 32)
  current(i) = i
 next

 'place 1 takes the darkest, place 2 the lightest, the others the lightest left over
 for place as Integer = 1 to 7
  found = 0
  for i as Integer = 1 to 7
   if not used(i) then
    if found = 0 then
     found = i
    elseif place = 1 and brightness(i) < brightness(found) then
     found = i
    elseif place >= 2 and brightness(i) > brightness(found) then
     found = i
    end if
   end if
  next
  wanted(place) = found
  used(found) = true
 next

 for place as Integer = 1 to 7
  if current(place) <> wanted(place) then
   for q = place + 1 to 7
    if current(q) = wanted(place) then exit for
   next
   MsMoveColor(place, q)
   swap current(place), current(q)
   swaps += 1
  end if
 next

 if swaps = 0 then return "The palette was already in the usual order."
 return "Palette sorted: 1 black, 2 white, the rest from light to dark."

end function


sub MsSaveUndo()

 if ms_undo_count = ms_undo_depth then
  for i as Integer = 1 to ms_undo_depth - 1
   for r as Integer = 0 to ms_tiles_high * 8 - 1
    for c as Integer = 0 to ms_tiles_wide * 8 - 1
     ms_undo_px(i - 1, r, c) = ms_undo_px(i, r, c)
    next
   next
  next
  ms_undo_count -= 1
 end if

 for r as Integer = 0 to ms_tiles_high * 8 - 1
  for c as Integer = 0 to ms_tiles_wide * 8 - 1
   ms_undo_px(ms_undo_count, r, c) = ms_px(r, c)
  next
 next
 ms_undo_count += 1

end sub


sub MsUndo()

 if ms_undo_count = 0 then exit sub

 ms_undo_count -= 1
 for r as Integer = 0 to ms_tiles_high * 8 - 1
  for c as Integer = 0 to ms_tiles_wide * 8 - 1
   ms_px(r, c) = ms_undo_px(ms_undo_count, r, c)
  next
 next

end sub


function MsEditable(x as Integer, y as Integer) as Boolean

 'True for a pixel inside the picture on a cell that has a tile

 if x < 0 or y < 0 or x >= ms_tiles_wide * 8 or y >= ms_tiles_high * 8 then return false

 return ms_cells((y \ 8) * ms_tiles_wide + x \ 8) >= 0

end function


sub MsSetPixel(x as Integer, y as Integer, c as Integer)

 'Sets a pixel, and the same pixel of every other cell that shows the same tile

 dim tile_number as Integer = ms_cells((y \ 8) * ms_tiles_wide + x \ 8)

 for n as Integer = 0 to ms_cell_count - 1
  if ms_cells(n) = tile_number then
   ms_px((n \ ms_tiles_wide) * 8 + (y mod 8), (n mod ms_tiles_wide) * 8 + (x mod 8)) = c
  end if
 next

end sub


sub MsFill(x as Integer, y as Integer, brush as Integer)

 dim old as Integer = ms_px(y, x)
 dim count as Integer
 dim cx as Integer
 dim cy as Integer
 dim nx as Integer
 dim ny as Integer

 if old = brush then exit sub

 MsSaveUndo()
 MsSetPixel(x, y, brush)
 ms_fill_x(0) = x
 ms_fill_y(0) = y
 count = 1
 do while count > 0
  count -= 1
  cx = ms_fill_x(count)
  cy = ms_fill_y(count)
  for d as Integer = 0 to 3
   nx = cx
   ny = cy
   select case d
    case 0: nx -= 1
    case 1: nx += 1
    case 2: ny -= 1
    case else: ny += 1
   end select
   if MsEditable(nx, ny) then
    if ms_px(ny, nx) = old then
     MsSetPixel(nx, ny, brush)
     ms_fill_x(count) = nx
     ms_fill_y(count) = ny
     count += 1
    end if
   end if
  next
 loop

end sub


sub MsDrawPicture(x0 as Integer, y0 as Integer, zoom as Integer)

 dim shade as UInteger

 for y as Integer = 0 to ms_tiles_high * 8 - 1
  for x as Integer = 0 to ms_tiles_wide * 8 - 1
   if not MsEditable(x, y) then
    shade = RGB(70, 20, 20)
   elseif ms_px(y, x) = 0 then
    if ((x + y) and 1) = 0 then shade = RGB(40, 40, 40) else shade = RGB(60, 60, 60)
   else
    shade = MsColor(ms_px(y, x))
   end if
   if zoom = 1 then
    pset (x0 + x, y0 + y), shade
   else
    line (x0 + x * zoom, y0 + y * zoom)-step(zoom - 1, zoom - 1), shade, bf
   end if
  next
 next

end sub


sub MsDrawScreen(index as Integer, mode as Integer, zoom as Integer, cx as Integer, cy as Integer, brush as Integer, picture_x as Integer, picture_y as Integer, message as String)

 'mode 0 = pixels, 1 = palette colors
 'Windows like the rest of the editor: title, picture, preview, palette, brush details and the keys

 dim sx as Integer
 dim sy as Integer
 dim v as UInteger
 dim shared_count as Integer = MonsterSharedCount(index, monsters(index).gfx_ptr1 + monsters(index).gfx_ptr2 * &h100, ms_palette_id, monsters(index).size)

 screenlock
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 'Title
 BlueBox(0, 0, 78, 2)
 WriteText(FF4Text(FF4Name(monsters(index).name) + "   monster " + str(index) + "   " + str(ms_tiles_wide * 8) + "x" + str(ms_tiles_high * 8) + "   palette " + str(ms_palette_id) + iif(ms_deep, " and the next", "")), 2, 1, 15)
 if shared_count > 0 then
  WriteText(FF4Text("Shared with " + str(shared_count) + " other monsters, they change too"), 2, 2, 14)
 end if

 'Picture
 BlueBox(0, 4, 53, 40)
 LuText(" PICTURE ", 1, 4, iif(mode = 0, 14, 23))
 MsDrawPicture(picture_x, picture_y, zoom)
 if mode = 0 then
  sx = picture_x + cx * zoom
  sy = picture_y + cy * zoom
  line (sx - 1, sy - 1)-(sx + zoom, sy + zoom), RGB(255, 255, 0), b
 end if

 'Preview at actual size
 BlueBox(54, 4, 24, 20)
 LuText(" PREVIEW ", 55, 4, 14)
 line (440, 40)-(631, 195), RGB(16, 16, 32), bf
 for y as Integer = 0 to ms_tiles_high * 8 - 1
  for x as Integer = 0 to ms_tiles_wide * 8 - 1
   if MsEditable(x, y) and ms_px(y, x) <> 0 then pset (440 + x, 44 + y), MsColor(ms_px(y, x))
  next
 next

 'Palette
 BlueBox(54, 26, 24, 11)
 LuText(" PALETTE " + str(ms_palette_id) + " ", 55, 26, iif(mode = 1, 21, 14))
 for i as Integer = 0 to ms_color_count - 1
  sx = 440 + (i mod 8) * 24
  sy = 224 + (i \ 8) * 40
  line (sx, sy)-(sx + 20, sy + 20), iif(i = 0, RGB(40, 40, 40), MsColor(i)), bf
  line (sx - 1, sy - 1)-(sx + 21, sy + 21), RGB(100, 100, 100), b
  if i = brush then line (sx - 2, sy - 2)-(sx + 22, sy + 22), RGB(255, 255, 0), b
  LuText(str(i), (sx + 6) \ 8, (sy + 24) \ 8, 15)
 next

 'The pixel and the color the brush is on
 BlueBox(54, 39, 24, 4)
 LuText(" BRUSH ", 55, 39, iif(mode = 1, 21, 14))
 v = ms_pal(brush)
 LuText("Pixel " + str(cx) + "," + str(cy), 55, 40, 15)
 LuText("Color " + str(brush) + iif(brush = 0, ", transparent", ""), 55, 41, 15)
 if brush > 0 then LuText("R " + str(v mod 32) + "  G " + str((v \ 32) mod 32) + "  B " + str((v \ 1024) mod 32), 55, 42, 23)

 'Keys
 BlueBox(0, 46, 78, 10)
 if mode = 1 then
  LuText(" ACTIONS, PALETTE ", 1, 46, 21)
  LuText("Editing color " + str(brush) + iif(brush = 0, ", transparent, not editable", ""), 2, 48, 14)
  LuText("Left Right: pick the color to change.", 2, 49, 15)
  LuText("Enter: the menu to change its red, green and blue, move it, undo and more.", 2, 50, 15)
  LuText("Moving a color moves the pixels of every monster that uses the palette.", 2, 51, 15)
  LuText("Esc: back to the picture.", 2, 52, 15)
 else
  LuText(" ACTIONS, PICTURE ", 1, 46, 14)
  LuText("Arrows: move.  Space: paint with the brush color.  Mouse: drag to paint.", 2, 48, 15)
  LuText("Enter: the menu of every action, like fill, flip, palette and export.", 2, 49, 15)
  LuText("The menu shows each action's key, so the keys can be learned as you go.", 2, 50, 15)
  LuText("PgUp PgDn: other monster.   Esc: store the changes and go back to the list.", 2, 51, 15)
 end if
 if len(message) > 0 then LuText(message, 2, 54, 12)
 screenunlock

end sub


sub MsSetChannel(slot as Integer, shift as Integer, value as Integer)

 'Sets the red (shift 0), green (5) or blue (10) of a palette color to 0 to 31, remembering the old color for undo

 dim raw as Integer

 if value < 0 or value > 31 then exit sub

 if ms_pal_undo_count = ms_undo_depth then
  for i as Integer = 1 to ms_undo_depth - 1
   ms_pal_undo_slot(i - 1) = ms_pal_undo_slot(i)
   ms_pal_undo_value(i - 1) = ms_pal_undo_value(i)
  next
  ms_pal_undo_count -= 1
 end if
 ms_pal_undo_slot(ms_pal_undo_count) = slot
 ms_pal_undo_value(ms_pal_undo_count) = ms_pal(slot)
 ms_pal_undo_count += 1
 raw = ms_pal(slot) and not (31 shl shift)
 ms_pal(slot) = raw or (value shl shift)

end sub


function MonsterSpriteActions(mode as Integer, byref brush as Integer) as UInteger

 'The menu of every action of the monster sprite editor. Returns the key the chosen entry stands for, or 0 if
 ' the editor handled it here (or the menu was cancelled).

 dim choice as Integer
 dim picked as Integer
 dim names(1 to 32) as String
 dim shift as Integer

 SmReset()
 if mode = 0 then
  SmAdd("Fill with the brush color", "F", asc("f"))
  SmAdd("Choose the brush color", "0 to 9", 0, 1)
  SmAdd("Flip horizontally", "X", asc("x"))
  SmAdd("Flip vertically", "Y", asc("y"))
  SmAdd("Undo", "Ctrl-Z", 26)
  SmAdd("Revert this picture", "Ctrl-R", 18)
  SmAdd("Edit the palette colors", "P", asc("p"))
  SmAdd("Sort the palette", "O", asc("o"))
  SmAdd("Previous monster", "PgUp", PAGEUP_KEY)
  SmAdd("Next monster", "PgDn", PAGEDOWN_KEY)
  SmAdd("Export this monster as BMP", "E", asc("e"))
  SmAdd("Import this monster from BMP", "I", asc("i"))
  SmAdd("Back to the list", "Esc", ESC_KEY)
  choice = SmRun("Monster sprite")
 else
  SmAdd("Choose the color", "Left Right", 0, 11)
  SmAdd("Change its red", "Q A", 0, 12)
  SmAdd("Change its green", "W S", 0, 13)
  SmAdd("Change its blue", "E D", 0, 14)
  SmAdd("Move the color left", "Bracket", asc("["))
  SmAdd("Move the color right", "Bracket", asc("]"))
  SmAdd("Undo", "Ctrl-Z", 26)
  SmAdd("Revert this palette", "Ctrl-R", 18)
  SmAdd("Back to the picture", "Esc", ESC_KEY)
  choice = SmRun("Palette " + str(ms_palette_id))
 end if
 if choice = 0 then return 0
 if sm_special(choice) = 0 then return sm_key(choice)

 select case sm_special(choice)

  case 1 'brush color
   for i as Integer = 0 to ms_color_count - 1
    names(i + 1) = str(i)
   next
   picked = SmPick("Brush color", names(), ms_color_count, brush + 1)
   if picked > 0 then brush = picked - 1

  case 11 'color of the palette
   for i as Integer = 1 to ms_color_count - 1
    names(i) = str(i)
   next
   picked = SmPick("Color", names(), ms_color_count - 1, brush)
   if picked > 0 then brush = picked

  case 12 to 14 'red, green, blue
   shift = (sm_special(choice) - 12) * 5
   picked = SmNumber((ms_pal(brush) \ (2 ^ shift)) mod 32, 31)
   MsSetChannel(brush, shift, picked)

 end select

 return 0

end function


sub EditMonsterSprite(index_start as Integer)

 dim index as Integer = index_start
 dim problem as String
 dim message as String
 dim key as String
 dim keycode as UInteger
 dim zoom as Integer
 dim picture_x as Integer = 16
 dim picture_y as Integer = 40
 dim cx as Integer
 dim cy as Integer
 dim brush as Integer = 1
 dim mode as Integer
 dim done as Boolean
 dim shift as Integer
 dim channel as Integer
 dim raw as Integer
 dim direction as Integer
 dim loaded as Boolean
 dim mx as Integer
 dim my as Integer
 dim lc as Boolean
 dim rc as Boolean
 dim wheel as Integer
 dim px as Integer
 dim py as Integer
 dim moved as Boolean
 dim size_ok as Boolean
 dim direction_slot as Integer

 loaded = MsLoad(index, problem)

 do
  if not loaded then
   message = problem
   ms_tiles_wide = 2
   ms_tiles_high = 2
   ms_cell_count = 0
  else
   message = ""
  end if

  if loaded then
   zoom = 400 \ (ms_tiles_wide * 8)
   if 320 \ (ms_tiles_high * 8) < zoom then zoom = 320 \ (ms_tiles_high * 8)
   if zoom > 12 then zoom = 12
   if zoom < 1 then zoom = 1
   cx = 0
   cy = 0
   mode = 0
   if brush >= ms_color_count then brush = 1
  end if

  do

   if loaded then
    MsDrawScreen(index, mode, zoom, cx, cy, brush, picture_x, picture_y, message)
   else
    screenlock
    line (0, 0)-(639, 463), RGB(0, 0, 0), bf
    WriteText(FF4Text(FF4Name(monsters(index).name) + "   monster " + str(index)), 2, 1, 15)
    WriteText(FF4Text("Cannot edit here: " + problem), 2, 3, 12)
    WriteText(FF4Text("PgUp PgDn other monster   Esc leaves"), 2, 5, 15)
    screenunlock
   end if

   direction = 0
   do
    key = inkey
    PollMouse(mx, my, lc, rc, wheel)
    moved = false
    if loaded and mx >= 0 then
     if mode = 0 and (lc or rc or mouse_left_held) then
      px = (mouse_pixel_x - picture_x) \ zoom
      py = (mouse_pixel_y - picture_y) \ zoom
      if mouse_pixel_x >= picture_x and mouse_pixel_y >= picture_y and MsEditable(px, py) then
       cx = px
       cy = py
       if rc then
        brush = ms_px(py, px)
       elseif ms_px(py, px) <> brush then
        if lc then MsSaveUndo()
        MsSetPixel(px, py, brush)
       end if
       moved = true
      end if
     end if
     if lc then
      for i as Integer = 0 to ms_color_count - 1
       if mouse_pixel_x >= 440 + (i mod 8) * 24 and mouse_pixel_x <= 460 + (i mod 8) * 24 and mouse_pixel_y >= 224 + (i \ 8) * 40 and mouse_pixel_y <= 244 + (i \ 8) * 40 then
        brush = i
        moved = true
       end if
      next
     end if
    end if
    if key = "" then sleep 10
   loop while key = "" and not moved

   if key <> "" then
    keycode = asc(right(key, 1))
    if len(key) > 1 then keycode = keycode * &h100 + 255
   else
    keycode = 0
   end if

  if KeyHelpPressed(keycode) then keycode = 0

   'Enter opens the menu of every action; the entries that stand for a key are handled as that key
   if keycode = ENTER_KEY and loaded then keycode = MonsterSpriteActions(mode, brush)

   if keycode = PAGEUP_KEY then
    direction = -1
   elseif keycode = PAGEDOWN_KEY then
    direction = 1
   elseif keycode = ESC_KEY and (mode = 0 or not loaded) then
    done = true
   elseif not loaded then
    'nothing else to do
   elseif mode = 0 then
    message = ""
    select case keycode
     case LEFT_KEY
      if cx > 0 then cx -= 1
     case RIGHT_KEY
      if cx < ms_tiles_wide * 8 - 1 then cx += 1
     case UP_KEY
      if cy > 0 then cy -= 1
     case DOWN_KEY
      if cy < ms_tiles_high * 8 - 1 then cy += 1
     case HOME_KEY
      cy = 0
     case END_KEY
      cy = ms_tiles_high * 8 - 1
     case asc("0") to asc("9")
      if keycode - asc("0") < ms_color_count then
       brush = keycode - asc("0")
       if MsEditable(cx, cy) and ms_px(cy, cx) <> brush then
        MsSaveUndo()
        MsSetPixel(cx, cy, brush)
       end if
      end if
     case SPACE_KEY
      if MsEditable(cx, cy) and ms_px(cy, cx) <> brush then
       MsSaveUndo()
       MsSetPixel(cx, cy, brush)
      end if
     case asc("f"), asc("F")
      if MsEditable(cx, cy) then MsFill(cx, cy, brush)
     case asc("-"), asc("[")
      brush = (brush + ms_color_count - 1) mod ms_color_count
     case asc("="), asc("]"), asc("+")
      brush = (brush + 1) mod ms_color_count
     case asc("x"), asc("X"), asc("y"), asc("Y")
      size_ok = (monsters(index).size < &h40)
      if not size_ok then
       message = "Flipping is only for plain monsters, not bosses"
      else
       MsSaveUndo()
       if keycode = asc("x") or keycode = asc("X") then
        for r as Integer = 0 to ms_tiles_high * 8 - 1
         for c as Integer = 0 to ms_tiles_wide * 4 - 1
          swap ms_px(r, c), ms_px(r, ms_tiles_wide * 8 - 1 - c)
         next
        next
       else
        for r as Integer = 0 to ms_tiles_high * 4 - 1
         for c as Integer = 0 to ms_tiles_wide * 8 - 1
          swap ms_px(r, c), ms_px(ms_tiles_high * 8 - 1 - r, c)
         next
        next
       end if
      end if
     case 26 'Ctrl-Z
      MsUndo()
     case 18 'Ctrl-R
      if ConfirmBox("Revert this picture to the loaded ROM?") then
       MsSaveUndo()
       MsLoadPixels(original_rom)
      end if
     case asc("e"), asc("E")
      MsCommit()
      if ConfirmExport("this monster") then InfoBox(ExportMonsterImage(index) + "||Press any key", 4, 20)
     case asc("i"), asc("I")
      if ConfirmBox("Import replaces this monster's tiles and palette. Continue?") then
       message = ImportMonsterImage(index)
       loaded = MsLoad(index, problem)
       if loaded then message += "||" + MsSortPalette()
       InfoBox(message + "||Press any key", 4, 20)
       message = ""
      end if
     case asc("o"), asc("O")
      if ConfirmBox("Sort the palette: 1 black, 2 white, the rest light to dark?") then
       message = MsSortPalette()
      end if
     case asc("p"), asc("P")
      mode = 1
      if brush = 0 then brush = 1
    end select
   else
    select case keycode
     case ESC_KEY
      mode = 0
     case LEFT_KEY
      if brush > 1 then brush -= 1
     case RIGHT_KEY
      if brush < ms_color_count - 1 then brush += 1
     case asc("q"), asc("Q"), asc("a"), asc("A"), asc("w"), asc("W"), asc("s"), asc("S"), asc("e"), asc("E"), asc("d"), asc("D")
      select case keycode and &hDF
       case asc("Q"), asc("A"): shift = 0
       case asc("W"), asc("S"): shift = 5
       case else: shift = 10
      end select
      channel = (ms_pal(brush) \ (2 ^ shift)) mod 32
      select case keycode and &hDF
       case asc("Q"), asc("W"), asc("E"): channel += 1
       case else: channel -= 1
      end select
      MsSetChannel(brush, shift, channel)
     case 26 'Ctrl-Z
      if ms_pal_undo_count > 0 then
       ms_pal_undo_count -= 1
       ms_pal(ms_pal_undo_slot(ms_pal_undo_count)) = ms_pal_undo_value(ms_pal_undo_count)
      end if
     case asc("["), asc("]")
      direction_slot = brush + iif(keycode = asc("["), -1, 1)
      if direction_slot >= 1 and direction_slot < ms_color_count then
       MsMoveColor(brush, direction_slot)
       brush = direction_slot
      end if
     case 18 'Ctrl-R
      if ConfirmBox("Revert this palette to the loaded ROM?") then
       MsLoadPalette(original_rom)
       ms_pal_undo_count = 0
      end if
    end select
   end if

  loop until done or direction <> 0

  if loaded then MsCommit()
  if direction <> 0 then
   index += direction
   if index < 1 then index = total_monsters
   if index > total_monsters then index = 1
   loaded = MsLoad(index, problem)
   if not loaded and len(problem) = 0 then problem = "unknown"
  end if

 loop until done

 'a draw on the screen itself, so no stale drawing target is left
 pset (0, 0), point(0, 0)

end sub


sub EditMonsterSprites()

 dim select_monster as BlueMenu

 select_monster.max_rows = screen_height - 3
 for i as Integer = 1 to total_monsters
  select_monster.AddOption(monsters(i).name)
 next

 do

  do
   screenlock
   line (0, 0)-(639, 463), RGB(0, 0, 0), bf
   WriteText(FF4Text("Pick a monster, Enter to edit its sprite and palette"), 0, 0, 15)
   select_monster.y = 2
   select_monster.Display()
   MonsterThumbnail(select_monster.selected, 20, 2, 20, 20)
   screenunlock
  loop until select_monster.UserInput()

  if not select_monster.cancelled then EditMonsterSprite(select_monster.selected)

 loop until select_monster.cancelled

end sub
