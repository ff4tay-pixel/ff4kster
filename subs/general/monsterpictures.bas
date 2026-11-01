'Stored monster pictures: pictures added to the ROM without replacing a monster's own.
'
'A monster's tiles are found through its graphics pointer (see monstersprite.bas). Besides the tiles the game
'itself uses, the area those pointers reach holds a few runs of unused bytes, filled with FF: the padding at the end
'of three tile banks and two gaps between other tables (mp_region_start / mp_region_end, 5704 bytes together). An
'imported picture is written into the first run of FF bytes that holds it, and gets a graphics pointer there:
'  pointer = &h8000 + (offset - &h48200) \ 8       (3 bits per pixel, the offset is a multiple of 8)
'The game reads the tiles of one picture from one 32K bank, and none of the runs crosses a bank.
'
'The ROM does not say which tiles are an imported picture, so the editor keeps a list in
'config/monsterpictures.dat, one line each: pointer, size, palette and the name (for example
'"40123 7 60 Big slime"). A line whose tiles are not in the ROM being edited (all FF, or outside the runs) is
'kept in the file but not listed. Deleting a picture writes FF over its tiles again, so the room is free.
'
'Only ordinary monsters (sizes 00-3F of the size table) can be added; the size is the first entry of the table
'with the width and height of the picture.

const mp_max = 40
const mp_name_length = 20
const mp_region_count = 5 'the runs in the original banks, three more come with the extra banks
const mp_file = "config/monsterpictures.dat"

dim shared mp_name(1 to mp_max) as String
dim shared mp_ptr(1 to mp_max) as Integer
dim shared mp_size(1 to mp_max) as Integer
dim shared mp_pal(1 to mp_max) as Integer
dim shared mp_present(1 to mp_max) as Boolean 'false: the tiles are not in this ROM (kept in the file only)
dim shared mp_count as Integer


function MpRegionStart(region as Integer) as Integer

 'Editor offsets (file offset + &h200) of the runs of unused FF bytes

 select case region
  case 1: return &h57100 'end of the second tile bank, before the window graphics
  case 2: return &h5FF58 'end of the third tile bank
  case 3: return &h634F8 'end of the fourth tile bank, before the battle animation graphics
  case 4: return &h68440 'between the field sprite palettes and the portrait palettes
  case 5: return &h6EA18 'end of the fifth tile group, before the summon tilemap
  case else: return mg_block + (region - mp_region_count - 1) * &h8000 'the extra banks
 end select

end function


function MpRegionEnd(region as Integer) as Integer

 select case region
  case 1: return &h57200
  case 2: return &h60200
  case 3: return &h638C0
  case 4: return &h688D0
  case 5: return &h6F460
  case else: return mg_block + (region - mp_region_count) * &h8000
 end select

end function


function MpRegionCount() as Integer

 if mg_state = 1 then return mp_region_count + mg_bank_count

 return mp_region_count

end function


function MpCapacity() as Integer

 dim total as Integer

 for r as Integer = 1 to MpRegionCount()
  total += MpRegionEnd(r) - MpRegionStart(r)
 next

 return total

end function


function MpFreeBytes() as Integer

 'Bytes of the runs that are still FF

 dim total as Integer

 for r as Integer = 1 to MpRegionCount()
  for o as Integer = MpRegionStart(r) to MpRegionEnd(r) - 1
   if ByteAt(o) = &hFF then total += 1
  next
 next

 return total

end function


function MpLargestRun() as Integer

 'The longest stretch of FF bytes in one run

 dim best as Integer
 dim current as Integer

 for r as Integer = 1 to MpRegionCount()
  current = 0
  for o as Integer = MpRegionStart(r) to MpRegionEnd(r) - 1
   if ByteAt(o) = &hFF then
    current += 1
    if current > best then best = current
   else
    current = 0
   end if
  next
 next

 return best

end function


function MpSizeFor(width_px as Integer, height_px as Integer) as Integer

 'The first size of the game's size table with this many pixels, -1 if there is none

 dim tiles_wide as Integer
 dim tiles_high as Integer

 if width_px mod 8 <> 0 or height_px mod 8 <> 0 then return -1
 for s as Integer = 0 to monster_size_count - 1
  MonsterSizeTiles(s, tiles_wide, tiles_high)
  if tiles_wide * 8 = width_px and tiles_high * 8 = height_px then return s
 next

 return -1

end function


function MpBytes(size_id as Integer) as Integer

 dim tiles_wide as Integer
 dim tiles_high as Integer

 MonsterSizeTiles(size_id, tiles_wide, tiles_high)

 return tiles_wide * tiles_high * 24

end function


function MpPointerFor(offset as Integer) as Integer

 if mg_state = 1 and offset >= mg_block and offset < mg_block + mg_bank_count * &h8000 then
  return &h8000 + (mg_first_bank + (offset - mg_block) \ &h8000) * &h1000 + ((offset - mg_block) mod &h8000) \ 8
 end if

 return &h8000 + (offset - monster_sprite_base) \ 8

end function


function MpStart(i as Integer) as Integer

 return MonsterSpriteOffset(mp_ptr(i))

end function


function MpOverlaps(start as Integer, bytes as Integer) as Boolean

 'True if the bytes lie over the tiles of a stored picture

 for i as Integer = 1 to mp_count
  if mp_present(i) then
   if start < MpStart(i) + MpBytes(mp_size(i)) and MpStart(i) < start + bytes then return true
  end if
 next

 return false

end function


function MpFindSpace(bytes as Integer) as Integer

 'The offset of the first run of FF bytes that holds bytes (a multiple of 8 from the graphics base), 0 if none does

 dim position as Integer
 dim blocked as Integer

 for r as Integer = 1 to MpRegionCount()
  position = MpRegionStart(r)
  do while position + bytes <= MpRegionEnd(r)
   blocked = -1
   for o as Integer = position to position + bytes - 1
    if ByteAt(o) <> &hFF then blocked = o
   next
   if blocked < 0 and not MpOverlaps(position, bytes) then return position
   if blocked < 0 then
    position += 8
   else
    position = blocked + 1 + ((8 - (blocked + 1 - monster_sprite_base) mod 8) mod 8)
   end if
  loop
 next

 return 0

end function


function MpInRegion(start as Integer, bytes as Integer) as Boolean

 for r as Integer = 1 to MpRegionCount()
  if start >= MpRegionStart(r) and start + bytes <= MpRegionEnd(r) then return true
 next

 return false

end function


function MpHasData(start as Integer, bytes as Integer) as Boolean

 for o as Integer = start to start + bytes - 1
  if ByteAt(o) <> &hFF then return true
 next

 return false

end function


function MpUsers(i as Integer) as Integer

 'How many monsters draw with this picture

 dim count as Integer

 for m as Integer = 1 to total_monsters
  if monsters(m).gfx_ptr1 + monsters(m).gfx_ptr2 * &h100 = mp_ptr(i) and monsters(m).size < &h40 then count += 1
 next

 return count

end function


function MpPaletteUsers(palette_id as Integer) as Integer

 'How many monsters use a palette (16 color art also uses the one after it, a boss the palette of its size entry)

 dim count as Integer
 dim gfx_ptr as Integer

 for m as Integer = 1 to total_monsters
  gfx_ptr = monsters(m).gfx_ptr1 + monsters(m).gfx_ptr2 * &h100
  if monsters(m).size >= &h80 then
   if special_sizes(monsters(m).size - &h80 + 1).palette_index = palette_id then count += 1
  elseif monsters(m).size < &h40 then
   if monsters(m).pal = palette_id then
    count += 1
   elseif MonsterIsDeep(gfx_ptr) and monsters(m).pal + 1 = palette_id then
    count += 1
   end if
  end if
 next

 return count

end function


function MpUnusedPalette() as Integer

 'The first palette no monster uses, -1 if there is none

 for p as Integer = 0 to total_monster_palettes - 1
  if MpPaletteUsers(p) = 0 then return p
 next

 return -1

end function


sub MpWritePalette(palette_id as Integer, colors() as UInteger)

 'Stores eight SNES colors as palette palette_id

 for i as Integer = 0 to 7
  WriteByte(monster_palette_table + palette_id * 16 + i * 2, colors(i) mod &h100)
  WriteByte(monster_palette_table + palette_id * 16 + i * 2 + 1, colors(i) \ &h100)
  monster_palettes(palette_id + 1, i) = RGB((colors(i) mod 32) * 8, ((colors(i) \ 32) mod 32) * 8, ((colors(i) \ 1024) mod 32) * 8)
 next

end sub


sub MpWriteTiles(start as Integer, tiles_wide as Integer, tiles_high as Integer)

 'Stores the picture in bmp_px (colors 0 to 7) as 3 bits per pixel tiles in row order

 dim tile_px(63) as UByte

 for t as Integer = 0 to tiles_wide * tiles_high - 1
  for row as Integer = 0 to 7
   for col as Integer = 0 to 7
    tile_px(row * 8 + col) = bmp_px((t \ tiles_wide) * 8 + row, (t mod tiles_wide) * 8 + col)
   next
  next
  MonsterWriteTile(start, t, tile_px(), false)
 next

end sub


function MpSortColors(colors() as UInteger, width_px as Integer, height_px as Integer) as Boolean

 'The usual order for a monster palette (as MsSortPalette): color 0 transparent, 1 the darkest, 2 the lightest and the
 ' rest from light to dark. Renumbers the pixels in bmp_px to match, so the picture looks the same.
 ' Returns true if the order changed.

 dim brightness(7) as Integer
 dim wanted(7) as Integer
 dim remap(7) as Integer
 dim used(7) as Boolean
 dim sorted(7) as UInteger
 dim found as Integer
 dim changed as Boolean

 for i as Integer = 1 to 7
  brightness(i) = 30 * (colors(i) mod 32) + 59 * ((colors(i) \ 32) mod 32) + 11 * ((colors(i) \ 1024) mod 32)
 next
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
  remap(found) = place
  if found <> place then changed = true
 next
 if not changed then return false

 sorted(0) = colors(0)
 for place as Integer = 1 to 7
  sorted(place) = colors(wanted(place))
 next
 for i as Integer = 0 to 7
  colors(i) = sorted(i)
 next
 for y as Integer = 0 to height_px - 1
  for x as Integer = 0 to width_px - 1
   if bmp_px(y, x) > 0 then bmp_px(y, x) = remap(bmp_px(y, x))
  next
 next

 return true

end function


function MpCleanName(plain as String) as String

 'At most mp_name_length letters the font can draw (anything else becomes _)

 dim result as String
 dim c as String

 for i as Integer = 1 to len(plain)
  c = mid(plain, i, 1)
  if instr("+=()[]<>;*&""\|", c) > 0 or asc(c) < 32 or asc(c) > 126 then c = "_"
  result += c
 next
 result = left(result, mp_name_length)
 if len(result) = 0 then result = "Picture"

 return result

end function


sub SaveMonsterPictures()

 open mp_file for output as #1
  for i as Integer = 1 to mp_count
   print #1, str(mp_ptr(i)) + " " + str(mp_size(i)) + " " + str(mp_pal(i)) + " " + mp_name(i)
  next
 close #1

end sub


sub ReadMonsterPictures()

 'Reads the list and marks the pictures whose tiles are in this ROM

 dim temp as String
 dim first_space as Integer
 dim second_space as Integer
 dim third_space as Integer
 dim start as Integer

 mp_count = 0
 if dir(mp_file) = "" then exit sub

 open mp_file for input as #1
  do until eof(1)
   line input #1, temp
   first_space = instr(temp, " ")
   second_space = instr(first_space + 1, temp, " ")
   third_space = instr(second_space + 1, temp, " ")
   if first_space > 0 and second_space > 0 and third_space > 0 and mp_count < mp_max then
    mp_count += 1
    mp_ptr(mp_count) = val(left(temp, first_space - 1))
    mp_size(mp_count) = val(mid(temp, first_space + 1, second_space - first_space - 1))
    mp_pal(mp_count) = val(mid(temp, second_space + 1, third_space - second_space - 1))
    mp_name(mp_count) = MpCleanName(mid(temp, third_space + 1))
    mp_present(mp_count) = false
    if mp_ptr(mp_count) >= &h8000 and mp_size(mp_count) >= 0 and mp_size(mp_count) < monster_size_count then
     start = MpStart(mp_count)
     if MpInRegion(start, MpBytes(mp_size(mp_count))) then mp_present(mp_count) = MpHasData(start, MpBytes(mp_size(mp_count)))
    end if
   end if
  loop
 close #1

end sub


function MpAdd(plain_name as String, offset as Integer, size_id as Integer, palette_id as Integer) as Integer

 'Lists a picture whose tiles are already written. Returns its number, 0 if the list is full.

 if mp_count >= mp_max then return 0

 mp_count += 1
 mp_name(mp_count) = MpCleanName(plain_name)
 mp_ptr(mp_count) = MpPointerFor(offset)
 mp_size(mp_count) = size_id
 mp_pal(mp_count) = palette_id
 mp_present(mp_count) = true
 SaveMonsterPictures()

 return mp_count

end function


sub MpRemove(i as Integer)

 'Writes FF over the tiles again and takes the picture off the list

 dim start as Integer = MpStart(i)

 for o as Integer = start to start + MpBytes(mp_size(i)) - 1
  WriteByte(o, &hFF)
 next
 for j as Integer = i to mp_count - 1
  mp_name(j) = mp_name(j + 1)
  mp_ptr(j) = mp_ptr(j + 1)
  mp_size(j) = mp_size(j + 1)
  mp_pal(j) = mp_pal(j + 1)
  mp_present(j) = mp_present(j + 1)
 next
 mp_count -= 1
 SaveMonsterPictures()

end sub


function MpListed(visible() as Integer) as Integer

 'The numbers of the pictures that are in this ROM, in visible(1 to n). Returns n.

 dim n as Integer

 for i as Integer = 1 to mp_count
  if mp_present(i) then
   n += 1
   visible(n) = i
  end if
 next

 return n

end function


sub MpUse(i as Integer, monster_index as Integer)

 'Makes a monster draw with a stored picture (the monster keeps everything else)

 monsters(monster_index).gfx_ptr1 = mp_ptr(i) mod &h100
 monsters(monster_index).gfx_ptr2 = mp_ptr(i) \ &h100
 monsters(monster_index).size = mp_size(i)
 monsters(monster_index).pal = mp_pal(i)

end sub
