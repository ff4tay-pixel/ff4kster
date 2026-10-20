'Menu portraits (the faces in the status, item and magic menus): 17 images of 32x32 pixels,
'4x4 tiles in reading order, 3bpp SNES tiles (24 bytes each, 0x180 per portrait), at 1d/d3c0.
'Eight color palettes follow another table (16 palettes of 8 colors at 0d/86d0). The menu uses the
'palette with the same number as the character's portrait; Pig, Small and Toad borrow the palette
'of whoever is transformed.

const portrait_gfx_base = &hED5C0 'includes the 0x200 header that ff4rom always carries
const portrait_palette_table = &h688D0
const total_portraits = 17
const portrait_bytes = &h180


function PortraitName(portrait as Integer) as String

 select case portrait
  case 0: return "Cecil Dark Knight"
  case 1: return "Kain"
  case 2: return "Rydia Child"
  case 3: return "Tellah"
  case 4: return "Edward"
  case 5: return "Rosa"
  case 6: return "Yang"
  case 7: return "Palom"
  case 8: return "Porom"
  case 9: return "Cecil Paladin"
  case 10: return "Cid"
  case 11: return "Rydia Adult"
  case 12: return "Edge"
  case 13: return "FuSoYa"
  case 14: return "Pig"
  case 15: return "Small"
  case 16: return "Toad"
 end select

 return ""

end function


function PortraitDefaultPalette(portrait as Integer) as Integer

 if portrait > 15 then return 15
 return portrait

end function


sub DecodePortrait(source as String, portrait as Integer)

 dim start as UInteger
 dim p0 as UByte
 dim p1 as UByte
 dim p2 as UByte

 for t as Integer = 0 to 15
  start = portrait_gfx_base + portrait * portrait_bytes + t * 24
  for y as Integer = 0 to 7
   p0 = asc(mid(source, start + y * 2 + 1, 1))
   p1 = asc(mid(source, start + y * 2 + 2, 1))
   p2 = asc(mid(source, start + 16 + y + 1, 1))
   for x as Integer = 0 to 7
    portrait_gfx(portrait, (t \ 4) * 8 + y, (t mod 4) * 8 + x) = ((p0 shr (7 - x)) and 1) or (((p1 shr (7 - x)) and 1) shl 1) or (((p2 shr (7 - x)) and 1) shl 2)
   next
  next
 next

end sub


sub ReadPortraits()

 for p as Integer = 0 to total_portraits - 1
  DecodePortrait(ff4rom, p)
 next

 for i as Integer = 0 to 15
  for j as Integer = 0 to 7
   portrait_palette_raw(i, j) = ByteAt(portrait_palette_table + i * 16 + j * 2) + ByteAt(portrait_palette_table + i * 16 + j * 2 + 1) * &h100
  next
 next

end sub
