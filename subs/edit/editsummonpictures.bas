'Summon pictures: a read-only list of the 17 pictures the game draws for the summons (calls).
'
'A summon does not use the monster table. LoadSummonGfx (btlgfx/magic.asm) reads three tables of bank 0D, indexed by
'the spell number minus 4D: a graphics pointer (a word, the tiles are in the same bank, 3 bits per pixel), a monster
'palette number, and a tile map. The tile map lists, in the order the tiles are stored, the place of each tile on the
'picture's sheet; an entry with bit 7 set is a blank cell with no tile data, and FF ends the list. So the number of
'tiles is the number of entries before the FF that have bit 7 clear.
'
'The pointer is shown the way a monster's graphics pointer is written (&h8000 + (tile offset - &h48200) / 8), so it
'can be typed in the Graphics box of Edit Monsters. The summon's tiles do not make a full rectangle, so most fit no size of
'the size table. The preview draws them through the tile map, blank cells left out.

const summon_gfx_ptrs = &h689F0 'file 0d/87f0: 17 words
const summon_palettes = &h7004C 'file 0d/fe4c: 17 bytes
const summon_tilemap_ptrs = &h6F460 'file 0d/f260: 17 words
const summon_bank_base = &h68200 'file 0d/8000 (with the header)
const summon_count = 17

function SummonName(index as Integer) as String

 select case index
  case 1: return "Imp"
  case 2: return "Bomb"
  case 3: return "Cockatrice"
  case 4: return "Mage"
  case 5: return "Chocobo"
  case 6: return "Shiva"
  case 7: return "Lamu"
  case 8: return "Jinn"
  case 9: return "Titan"
  case 10: return "Mist"
  case 11: return "Sylph"
  case 12: return "Odin"
  case 13: return "Leviatan"
  case 14: return "Asura"
  case 15: return "Asura 2"
  case 16: return "Asura 3"
  case else: return "Bahamut"
 end select

end function


function SummonGfxWord(index as Integer) as Integer

 return ByteAt(summon_gfx_ptrs + (index - 1) * 2) + ByteAt(summon_gfx_ptrs + (index - 1) * 2 + 1) * &h100

end function


function SummonMonsterPointer(index as Integer) as Integer

 'The tiles are at summon_bank_base + word - &h8000, which is a multiple of 8 above the monster graphics base

 return &h8000 + (summon_bank_base + SummonGfxWord(index) - &h8000 - monster_sprite_base) \ 8

end function


function SummonTileLimit(index as Integer) as Integer

 'The tiles a summon has of its own: the room up to the next picture in the ROM (24 bytes a tile). Two summons can
 ' share a tile map that lists more tiles than the first one has (Cockatrice and Mage); the rest of its list would
 ' read the next picture's tiles, so it is not part of this picture.

 dim word as Integer = SummonGfxWord(index)
 dim next_word as Integer = word + 128 * 24

 for k as Integer = 1 to summon_count
  if SummonGfxWord(k) > word and SummonGfxWord(k) < next_word then next_word = SummonGfxWord(k)
 next

 return (next_word - word) \ 24

end function


function SummonTileCount(index as Integer) as Integer

 dim map_word as Integer
 dim at as Integer
 dim entry as Integer
 dim total as Integer

 map_word = ByteAt(summon_tilemap_ptrs + (index - 1) * 2) + ByteAt(summon_tilemap_ptrs + (index - 1) * 2 + 1) * &h100
 at = summon_bank_base + map_word - &h8000

 do
  entry = ByteAt(at)
  if entry = &hFF or total >= 128 then exit do
  if entry < &h80 then total += 1
  at += 1
 loop

 return Min(total, SummonTileLimit(index))

end function


function SummonImage(index as Integer) as Any ptr

 'The picture of a summon as the game puts it together: the tile map gives the cell of each tile on a sheet 16 tiles
 ' wide (an entry with bit 7 set is a blank cell and takes no tile), and the tiles come in the order of the list.
 ' Returns 0 if the map is not usable. The picture is cropped to the cells that have a tile.

 dim map_word as Integer
 dim map_at as Integer
 dim entry as Integer
 dim count as Integer
 dim first_col as Integer = 16
 dim last_col as Integer = -1
 dim first_row as Integer = 16
 dim last_row as Integer = -1
 dim start as Integer
 dim result as Any ptr
 dim pixels as Any ptr
 dim pitch as Integer
 dim color_index as Integer
 dim pal as Integer
 dim limit as Integer

 map_word = ByteAt(summon_tilemap_ptrs + (index - 1) * 2) + ByteAt(summon_tilemap_ptrs + (index - 1) * 2 + 1) * &h100
 map_at = summon_bank_base + map_word - &h8000
 start = summon_bank_base + SummonGfxWord(index) - &h8000
 pal = ByteAt(summon_palettes + index - 1)
 if pal >= total_monster_palettes then return 0

 limit = SummonTileLimit(index)
 for n as Integer = 0 to 127
  entry = ByteAt(map_at + n)
  if entry = &hFF then exit for
  if entry < &h80 then
   if count >= limit then exit for
   count += 1
   first_col = Min(first_col, entry and 15)
   last_col = Max(last_col, entry and 15)
   first_row = Min(first_row, entry shr 4)
   last_row = Max(last_row, entry shr 4)
  end if
 next
 if last_col < 0 then return 0
 count = 0

 result = MonsterNewImage(last_col - first_col + 1, last_row - first_row + 1, pixels, pitch)
 if result = 0 then return 0

 for n as Integer = 0 to 127
  entry = ByteAt(map_at + n)
  if entry = &hFF then exit for
  if entry < &h80 then
   if count >= limit then exit for
   for row as Integer = 0 to 7
    for col as Integer = 0 to 7
     color_index = MonsterTileColor(start, count, row, col)
     if color_index <> 0 then MonsterPutPixel(pixels, pitch, ((entry and 15) - first_col) * 8 + col, ((entry shr 4) - first_row) * 8 + row, MonsterPaletteColor(pal, color_index))
    next
   next
   count += 1
  end if
 next

 return result

end function


sub SummonPanelShow(index as Integer, byref snapshot as Any ptr)

 'The picture beside the list, in the same panel as the monster sprites

 MonsterSpritePanelDraw(SummonImage(index), "Ptr " + str(SummonMonsterPointer(index)) + " Pal " + str(ByteAt(summon_palettes + index - 1)), snapshot)

end sub


sub SummonPictures()

 dim m as BlueMenu
 dim snapshot as Any ptr = 0

 m.x = 1
 m.y = 5
 m.max_rows = summon_count
 m.hint = "Read only. Chocobo, Shiva, Lamu, Jinn and Sylph have no enemy. Esc goes back."
 for k as Integer = 1 to summon_count
  m.AddOption(FF4Text(Pad(SummonName(k), 13) + Pad(str(SummonMonsterPointer(k)), 9) + Pad(str(ByteAt(summon_palettes + k - 1)), 9) + str(SummonTileCount(k))))
 next

 do
  screenlock
  line (0, 0)-(639, 463), RGB(0, 0, 0), bf
  WriteText(FF4Text("Summon pictures: the 17 pictures the game draws for the summons"), 0, 0, 15)
  WriteText(FF4Text("Pointer: type it under Manual in Edit Monsters. Read only."), 0, 1, 14)
  WriteText(FF4Text(Pad("Summon", 13) + Pad("Pointer", 9) + Pad("Palette", 9) + "Tiles"), 2, 4, 11)
  m.Display()
  screenunlock
  SummonPanelShow(m.selected, snapshot)
 loop until m.UserInput() andalso m.cancelled

 MonsterSpritePanelHide(snapshot)
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

end sub
