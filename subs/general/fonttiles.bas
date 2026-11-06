'The font and the icons of the game: 256 tiles of 8x8 pixels, 2bpp SNES tiles (16 bytes each, 0x1000 in all), at
' file offset 0x57000 (the disassembly's WindowGfx, bank 0A, 0xF000; the first 0x380 bytes are named the menu
' window graphics there, the rest is the same block). One tile number is one character code of the game's text:
' letters, digits, punctuation, the item and magic icons that item names start with, the window frame pieces, the
' cursor. The menus, the battle windows and the dialogues all draw their text from it.
' The window palette (WindowPal, 0D/87D0) has four palettes of four colors, 0 black, 1 the blue of the windows,
' 2 and 3 the shadow and the letters. The editor only shows it, the colors are not edited here.

const font_gfx_base = &h57200 'with the 0x200 header
const font_palette_table = &h689D0 'with the 0x200 header

dim shared font_gfx(255, 7, 7) as UByte 'tile, row, column: color 0-3
dim shared font_orig(255, 7, 7) as UByte 'the tiles as loaded
dim shared font_pal_raw(15) as UInteger 'the window palette as SNES colors


sub DecodeFontTile(source as String, t as Integer, dest(any, any, any) as UByte)

 dim p0 as UByte
 dim p1 as UByte

 for y as Integer = 0 to 7
  p0 = asc(mid(source, font_gfx_base + t * 16 + y * 2 + 1, 1))
  p1 = asc(mid(source, font_gfx_base + t * 16 + y * 2 + 2, 1))
  for x as Integer = 0 to 7
   dest(t, y, x) = ((p0 shr (7 - x)) and 1) or (((p1 shr (7 - x)) and 1) shl 1)
  next
 next

end sub


sub ReadFontTiles()

 for t as Integer = 0 to 255
  DecodeFontTile(ff4rom, t, font_gfx())
  DecodeFontTile(ff4rom, t, font_orig())
 next
 for i as Integer = 0 to 15
  font_pal_raw(i) = ByteAt(font_palette_table + i * 2) + ByteAt(font_palette_table + i * 2 + 1) * &h100
 next

end sub


sub SaveFontTiles()

 'Called by Save ROM. Tiles that were not edited write the bytes the ROM already has.

 dim p0 as UByte
 dim p1 as UByte
 dim c as UByte

 for t as Integer = 0 to 255
  for y as Integer = 0 to 7
   p0 = 0
   p1 = 0
   for x as Integer = 0 to 7
    c = font_gfx(t, y, x)
    p0 or= ((c and 1) shl (7 - x))
    p1 or= (((c shr 1) and 1) shl (7 - x))
   next
   WriteByte(font_gfx_base + t * 16 + y * 2, p0)
   WriteByte(font_gfx_base + t * 16 + y * 2 + 1, p1)
  next
 next

end sub
