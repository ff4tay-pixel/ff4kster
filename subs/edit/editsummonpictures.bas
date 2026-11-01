'Summon pictures: the 17 pictures the game draws for the summons (calls), with a preview, an editor, and BMP export
'and import.
'
'A summon does not use the monster table. LoadSummonGfx (btlgfx/magic.asm) reads three tables of bank 0D, indexed by
'the spell number minus 4D: a graphics pointer (a word, the tiles are in the same bank, 3 bits per pixel), a monster
'palette number, and a tile map. The tile map lists, in the order the tiles are stored, the place of each tile on the
'picture's sheet (16 tiles wide); an entry with bit 7 set is a blank cell with no tile data, and FF ends the list. So
'the number of tiles is the number of entries before the FF that have bit 7 clear.
'
'The pointer is shown the way a monster's graphics pointer is written (&h8000 + (tile offset - &h48200) / 8), so it
'can be typed in the Graphics box of Edit Monsters. The summon's tiles do not make a full rectangle, so most fit no
'size of the size table. The preview and the editor draw them through the tile map, blank cells left out.
'
'The editor is the one of the monster sprites (editmonstersprites.bas) with ms_summon set: MsLoadSummon fills its
'cells (tile number of each cell of the picture, -1 for a blank cell), start and palette, and the rest is as for a
'boss. The layout is never changed: only the pixels of the tiles and the palette colors. Cells beyond a summon's own
'tiles (see SummonTileLimit) and blank cells cannot be painted.
'
'Tiles and palettes are shared: the summon's tiles are the tiles of every monster with the same graphics pointer (the
'summons that have an enemy), and the palette is a monster palette. The editor says how many change too
'(SummonSharedText).

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


dim shared summon_cells(255) as Integer 'tile number of each cell of the picture being laid out, -1 for a blank cell


function SummonLayout(index as Integer, byref tiles_wide as Integer, byref tiles_high as Integer) as Boolean

 'Lays the summon's tiles out as its tile map says: fills summon_cells with the tile (its number in the stored order)
 ' of each cell of the picture, cropped to the cells that have a tile. False if the map is not usable.

 dim map_word as Integer
 dim map_at as Integer
 dim entry as Integer
 dim count as Integer
 dim limit as Integer = SummonTileLimit(index)
 dim first_col as Integer = 16
 dim last_col as Integer = -1
 dim first_row as Integer = 16
 dim last_row as Integer = -1
 dim cell as Integer

 map_word = ByteAt(summon_tilemap_ptrs + (index - 1) * 2) + ByteAt(summon_tilemap_ptrs + (index - 1) * 2 + 1) * &h100
 map_at = summon_bank_base + map_word - &h8000

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
 if last_col < 0 then return false

 tiles_wide = last_col - first_col + 1
 tiles_high = last_row - first_row + 1
 for n as Integer = 0 to tiles_wide * tiles_high - 1
  summon_cells(n) = -1
 next

 count = 0
 for n as Integer = 0 to 127
  entry = ByteAt(map_at + n)
  if entry = &hFF then exit for
  if entry < &h80 then
   if count >= limit then exit for
   cell = ((entry shr 4) - first_row) * tiles_wide + (entry and 15) - first_col
   if summon_cells(cell) < 0 then summon_cells(cell) = count
   count += 1
  end if
 next

 return true

end function


function SummonImage(index as Integer) as Any ptr

 'The picture of a summon as the game puts it together (see SummonLayout). Returns 0 if the map is not usable.

 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim start as Integer = summon_bank_base + SummonGfxWord(index) - &h8000
 dim result as Any ptr
 dim pixels as Any ptr
 dim pitch as Integer
 dim color_index as Integer
 dim pal as Integer = ByteAt(summon_palettes + index - 1)

 if pal >= total_monster_palettes then return 0
 if not SummonLayout(index, tiles_wide, tiles_high) then return 0

 result = MonsterNewImage(tiles_wide, tiles_high, pixels, pitch)
 if result = 0 then return 0

 for n as Integer = 0 to tiles_wide * tiles_high - 1
  if summon_cells(n) >= 0 then
   for row as Integer = 0 to 7
    for col as Integer = 0 to 7
     color_index = MonsterTileColor(start, summon_cells(n), row, col)
     if color_index <> 0 then MonsterPutPixel(pixels, pitch, (n mod tiles_wide) * 8 + col, (n \ tiles_wide) * 8 + row, MonsterPaletteColor(pal, color_index))
    next
   next
  end if
 next

 return result

end function


sub SummonPanelShow(index as Integer, byref snapshot as Any ptr)

 'The picture beside the list, in the same panel as the monster sprites

 MonsterSpritePanelDraw(SummonImage(index), "Ptr " + str(SummonMonsterPointer(index)) + " Pal " + str(ByteAt(summon_palettes + index - 1)), snapshot)

end sub


function MsLoadSummon(index as Integer, byref problem as String) as Boolean

 'Loads a summon into the monster sprite editor (see the header)

 dim pal as Integer = ByteAt(summon_palettes + index - 1)

 if pal >= total_monster_palettes then
  problem = "palette " + str(pal) + " does not exist"
  return false
 end if
 if not SummonLayout(index, ms_tiles_wide, ms_tiles_high) then
  problem = "this summon has no usable tile map"
  return false
 end if

 ms_cell_count = ms_tiles_wide * ms_tiles_high
 for n as Integer = 0 to ms_cell_count - 1
  ms_cells(n) = summon_cells(n)
 next
 ms_deep = false
 ms_color_count = 8
 ms_start = summon_bank_base + SummonGfxWord(index) - &h8000
 ms_palette_id = pal

 MsLoadPixels(ff4rom)
 MsLoadPalette(ff4rom, monster_palette_table)
 ms_undo_count = 0
 ms_pal_undo_count = 0

 return true

end function


function SummonSharedText(index as Integer) as String

 'What else changes when this summon's tiles or palette change: monsters with the same graphics pointer or palette and
 ' summons with the same tiles or palette. Empty if nothing.

 dim pointer_value as Integer = SummonMonsterPointer(index)
 dim pal as Integer = ByteAt(summon_palettes + index - 1)
 dim monster_pal as Integer
 dim monster_total as Integer
 dim summon_total as Integer
 dim result as String

 for i as Integer = 1 to total_monsters
  if monsters(i).size < &h40 or monsters(i).size >= &h80 then
   if monsters(i).size >= &h80 then
    monster_pal = special_sizes((monsters(i).size and &h3F) + 1).palette_index
   else
    monster_pal = monsters(i).pal
   end if
   if monsters(i).gfx_ptr1 + monsters(i).gfx_ptr2 * &h100 = pointer_value or monster_pal = pal then monster_total += 1
  end if
 next
 for k as Integer = 1 to summon_count
  if k <> index then
   if SummonGfxWord(k) = SummonGfxWord(index) or ByteAt(summon_palettes + k - 1) = pal then summon_total += 1
  end if
 next

 if monster_total = 1 then
  result = "1 monster"
 elseif monster_total > 1 then
  result = str(monster_total) + " monsters"
 end if
 if summon_total > 0 then
  if len(result) > 0 then result += " and "
  if summon_total = 1 then result += "1 other summon" else result += str(summon_total) + " other summons"
 end if
 if len(result) = 0 then return ""

 return "Shared with " + result + ", they change too"

end function


function SummonImageName(index as Integer) as String

 'summon_NN_Name.bmp, with anything but letters and digits in the name turned into _

 dim plain as String = SummonName(index)
 dim result as String
 dim c as String

 for i as Integer = 1 to len(plain)
  c = mid(plain, i, 1)
  if (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") then result += c else result += "_"
 next

 return "summon_" + Pad(str(index), 2, true, "0") + "_" + result + ".bmp"

end function


function SummonPath(file_name as String) as String

 mkdir system_path + "\exports"
 mkdir system_path + "\exports\summons"

 return system_path + "\exports\summons\" + file_name

end function


function ExportSummonImage(index as Integer) as String

 'Writes the picture the editor shows (the tiles laid out as the tile map says, blank cells empty) as a BMP whose
 ' color table is the summon's palette. Returns a message for the user.

 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim start as Integer = summon_bank_base + SummonGfxWord(index) - &h8000
 dim pal as Integer = ByteAt(summon_palettes + index - 1)
 dim colors(15) as UInteger
 dim file_name as String = SummonImageName(index)

 if pal >= total_monster_palettes then return "Cannot export: palette " + str(pal) + " does not exist"
 if not SummonLayout(index, tiles_wide, tiles_high) then return "Cannot export: this summon has no usable tile map"

 for y as Integer = 0 to tiles_high * 8 - 1
  for x as Integer = 0 to tiles_wide * 8 - 1
   bmp_px(y, x) = 0
  next
 next
 for n as Integer = 0 to tiles_wide * tiles_high - 1
  if summon_cells(n) >= 0 then
   for row as Integer = 0 to 7
    for col as Integer = 0 to 7
     bmp_px((n \ tiles_wide) * 8 + row, (n mod tiles_wide) * 8 + col) = MonsterTileColor(start, summon_cells(n), row, col)
    next
   next
  end if
 next
 for i as Integer = 0 to 7
  colors(i) = ByteAt(monster_palette_table + pal * 16 + i * 2) + ByteAt(monster_palette_table + pal * 16 + i * 2 + 1) * &h100
 next

 if not WriteIndexedBMPColors(SummonPath(file_name), tiles_wide * 8, tiles_high * 8, colors()) then
  return "Cannot write exports/summons|Check that the folder can be written"
 end if

 return "Wrote " + str(tiles_wide * 8) + "x" + str(tiles_high * 8) + " pixels, 8 colors, palette " + str(pal) + "|exports\summons\" + file_name

end function


function ImportSummonImage(index as Integer) as String

 'Reads the BMP of ExportSummonImage back: the pixels of the cells that have a tile go into the tiles, the color table
 ' becomes the palette. Blank cells are ignored. The size must be the exported one. Returns a message for the user.

 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim start as Integer = summon_bank_base + SummonGfxWord(index) - &h8000
 dim pal as Integer = ByteAt(summon_palettes + index - 1)
 dim new_palette(15) as UInteger
 dim file_name as String
 dim prefix as String = "summon_" + Pad(str(index), 2, true, "0")
 dim problem as String
 dim tile_px(63) as UByte
 dim differs as Boolean
 dim written as Integer
 dim message as String
 dim shared_text as String

 if pal >= total_monster_palettes then return "Cannot import: palette " + str(pal) + " does not exist"
 if not SummonLayout(index, tiles_wide, tiles_high) then return "Cannot import: this summon has no usable tile map"

 file_name = dir(SummonPath(prefix + "_*.bmp"))
 if len(file_name) = 0 then file_name = dir(SummonPath(prefix + ".bmp"))
 if len(file_name) = 0 then return "No image for this summon|Looked for exports/summons/" + prefix + "_*.bmp"

 for i as Integer = 0 to 7
  new_palette(i) = ByteAt(monster_palette_table + pal * 16 + i * 2) + ByteAt(monster_palette_table + pal * 16 + i * 2 + 1) * &h100
 next
 if not ReadBMPWithPalette(SummonPath(file_name), tiles_wide * 8, tiles_high * 8, 8, new_palette(), problem) then return file_name + ": " + problem

 for n as Integer = 0 to tiles_wide * tiles_high - 1
  if summon_cells(n) >= 0 then
   differs = false
   for row as Integer = 0 to 7
    for col as Integer = 0 to 7
     tile_px(row * 8 + col) = bmp_px((n \ tiles_wide) * 8 + row, (n mod tiles_wide) * 8 + col)
     if tile_px(row * 8 + col) <> MonsterTileColor(start, summon_cells(n), row, col) then differs = true
    next
   next
   if differs then
    MonsterWriteTile(start, summon_cells(n), tile_px(), false)
    written += 1
   end if
  end if
 next

 for i as Integer = 0 to 7
  WriteByte(monster_palette_table + pal * 16 + i * 2, new_palette(i) mod &h100)
  WriteByte(monster_palette_table + pal * 16 + i * 2 + 1, new_palette(i) \ &h100)
  monster_palettes(pal + 1, i) = RGB((new_palette(i) mod 32) * 8, ((new_palette(i) \ 32) mod 32) * 8, ((new_palette(i) \ 1024) mod 32) * 8)
 next

 message = "Imported " + file_name + "|" + str(written) + " tiles changed, palette " + str(pal) + " stored"
 shared_text = SummonSharedText(index)
 if len(shared_text) > 0 then message += "||" + shared_text

 return message

end function


function SummonActions(index as Integer) as Integer

 'The menu of the list: what to do with this summon's picture. Returns 1 edit, 2 export, 3 import, 0 back.

 dim choice as Integer

 SmReset()
 SmAdd("Edit the picture and palette", "", 0, 1)
 SmAdd("Export as BMP", "", 0, 2)
 SmAdd("Import from BMP", "", 0, 3)
 SmAdd("Back to the list", "Esc", ESC_KEY)
 choice = SmRun(SummonName(index))
 if choice = 0 then return 0
 if sm_special(choice) = 0 then return 0

 return sm_special(choice)

end function


sub SummonPictures()

 dim m as BlueMenu
 dim snapshot as Any ptr = 0
 dim remember as Integer = 1
 dim action as Integer
 dim problem as String

 m.x = 1
 m.y = 5
 m.max_rows = summon_count
 m.hint = "Enter: edit the picture, export or import a BMP. Chocobo, Shiva, Lamu, Jinn, Sylph have no enemy."
 for k as Integer = 1 to summon_count
  m.AddOption(FF4Text(Pad(SummonName(k), 13) + Pad(str(SummonMonsterPointer(k)), 9) + Pad(str(ByteAt(summon_palettes + k - 1)), 9) + str(SummonTileCount(k))))
 next

 do
  m.ChangeSelected(remember)
  do
   screenlock
   line (0, 0)-(639, 463), RGB(0, 0, 0), bf
   WriteText(FF4Text("Summon pictures: the 17 pictures the game draws for the summons"), 0, 0, 15)
   WriteText(FF4Text("Pointer: type it under Manual in Edit Monsters. Enter: actions."), 0, 1, 14)
   WriteText(FF4Text(Pad("Summon", 13) + Pad("Pointer", 9) + Pad("Palette", 9) + "Tiles"), 2, 4, 11)
   m.Display()
   screenunlock
   SummonPanelShow(m.selected, snapshot)
  loop until m.UserInput()

  MonsterSpritePanelHide(snapshot)
  remember = m.selected
  if not m.cancelled then
   action = SummonActions(m.selected)
   select case action
    case 1
     ms_summon = true
     EditMonsterSprite(m.selected)
     ms_summon = false
    case 2
     if ConfirmExport("this summon") then InfoBox(ExportSummonImage(m.selected) + "||Press any key", 4, 20)
    case 3
     if ConfirmBox("Import replaces this summon's tiles and palette. Continue?") then
      InfoBox(ImportSummonImage(m.selected) + "||Press any key", 4, 20)
     end if
   end select
  end if
 loop until m.cancelled

 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

end sub
