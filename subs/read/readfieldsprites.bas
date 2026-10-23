'Field sprites: the walking sprites of the party and of the NPCs on the maps (the "map sprite graphics" of the
'disassembly, field/gfx/map_sprite_gfx_en.asm). 107 sheets one after another in one bank, 3bpp SNES tiles (24
'bytes each) that the game reads as 16x16 frames of four tiles: top left, top right, bottom left, bottom right.
'The sheets have four sizes: the first 17 (the party, plus Frog, Pig and Mini) have 32 tiles, 8 frames; sheets 17 to
'47 have 16 tiles, 48 to 69 have 8 tiles and 70 to 106 have 4 tiles (field/npc.asm, LoadSpriteGfx). A sheet has no
'palette of its own: 36 palettes of 8 colors follow another table (0d/8000). The party sheets (0 to 13, and 14 to 17
'for the player) are drawn with the palette PlayerPalTbl gives (field/sprite.asm, 15/b2fa, always one of 0 to 3). An
'NPC of any other sheet takes the palette of its placement: the placement's palette (0 to 3) picks one of the two
'palettes that each of the two numbers of the map's NPC palettes stands for, number n being the palettes 13 + 2n
'and 14 + 2n (LoadNPCPal in field/npc.asm). So the same sheet can have other colors on other maps. Palettes 4 to 7
'are loaded for the vehicles. Which sheet an NPC uses is its "sprite" in the NPCs editor
'(npcs(n).sprite, the 512 byte table at 12/f000 that the game calls NPCGfxID is indexed by the NPC number).

const field_gfx_base = &hD8200 'includes the 0x200 header that ff4rom always carries
const field_palette_table = &h68200
const field_party_palette_table = &hAB4FA
const total_field_sheets = 107
const total_field_palettes = 36

dim shared field_sprite_gfx(total_field_sheets - 1, 31, 7, 7) as UByte 'sheet, tile, row, column: color 0-7
dim shared field_palette_raw(total_field_palettes - 1, 7) as UInteger 'SNES colors: 0bbbbbgggggrrrrr
dim shared field_party_palette(17) as UByte 'the palette each of the sheets 0 to 17 is drawn with (PlayerPalTbl)
dim shared field_palette_pick(total_field_sheets - 1) as Integer 'the palette the editor shows a sheet with, -1 until picked


function FieldSheetOffset(sheet as Integer) as UInteger

 'Where a sheet starts in ff4rom

 if sheet < 17 then return field_gfx_base + sheet * &h300
 if sheet < 48 then return field_gfx_base + &h3300 + (sheet - 17) * &h180
 if sheet < 70 then return field_gfx_base + &h6180 + (sheet - 48) * &hC0

 return field_gfx_base + &h7200 + (sheet - 70) * &h60

end function


function FieldSheetTiles(sheet as Integer) as Integer

 if sheet < 17 then return 32
 if sheet < 48 then return 16
 if sheet < 70 then return 8

 return 4

end function


function FieldSheetName(sheet as Integer) as String

 'Returns the name already encoded for display

 return npc_sprite_names.ItemAt(sheet + 1)

end function


sub DecodeFieldSheet(source as String, sheet as Integer)

 'Reads one sheet from a ROM image (ff4rom, or original_rom to revert it)

 dim start as UInteger
 dim p0 as UByte
 dim p1 as UByte
 dim p2 as UByte

 for t as Integer = 0 to FieldSheetTiles(sheet) - 1
  start = FieldSheetOffset(sheet) + t * 24
  for y as Integer = 0 to 7
   p0 = asc(mid(source, start + y * 2 + 1, 1))
   p1 = asc(mid(source, start + y * 2 + 2, 1))
   p2 = asc(mid(source, start + 16 + y + 1, 1))
   for x as Integer = 0 to 7
    field_sprite_gfx(sheet, t, y, x) = ((p0 shr (7 - x)) and 1) or (((p1 shr (7 - x)) and 1) shl 1) or (((p2 shr (7 - x)) and 1) shl 2)
   next
  next
 next

end sub


function FieldPaletteOf(source as String, pal as Integer, slot as Integer) as UInteger

 'One color of a palette in a ROM image

 dim start as UInteger = field_palette_table + pal * 16 + slot * 2

 return asc(mid(source, start + 1, 1)) + asc(mid(source, start + 2, 1)) * &h100

end function


sub ReadFieldPalettePicks()

 'The palette picked for each sheet in the editor, kept in config/fieldpalettes.dat as lines "NNN PP". It is only
 ' what the editor shows a sheet with, nothing in the ROM changes.

 dim temp as String
 dim sheet as Integer
 dim pal as Integer

 for i as Integer = 0 to total_field_sheets - 1
  field_palette_pick(i) = -1
 next

 if dir("config/fieldpalettes.dat") = "" then exit sub

 open "config/fieldpalettes.dat" for input as #1
  do until eof(1)
   line input #1, temp
   sheet = val(left(temp, 3))
   pal = val(mid(temp, 5))
   if len(temp) >= 5 and sheet >= 0 and sheet < total_field_sheets and pal >= 0 and pal < total_field_palettes then field_palette_pick(sheet) = pal
  loop
 close #1

end sub


sub SaveFieldPalettePicks()

 open "config/fieldpalettes.dat" for output as #1
  for i as Integer = 0 to total_field_sheets - 1
   if field_palette_pick(i) >= 0 then print #1, Pad(str(i), 3, true, "0") + " " + str(field_palette_pick(i))
  next
 close #1

end sub


sub ReadFieldSprites()

 for sheet as Integer = 0 to total_field_sheets - 1
  DecodeFieldSheet(ff4rom, sheet)
 next

 for i as Integer = 0 to total_field_palettes - 1
  for j as Integer = 0 to 7
   field_palette_raw(i, j) = FieldPaletteOf(ff4rom, i, j)
  next
 next


 for i as Integer = 0 to 17
  field_party_palette(i) = ByteAt(field_party_palette_table + i)
 next

 ReadFieldPalettePicks()

end sub
