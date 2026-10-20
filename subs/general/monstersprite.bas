'Monster sprite viewer.
'Monster graphics are 3bpp SNES tiles (24 bytes each) stored in the banks starting at
'09/8000. A graphics pointer P (>= &h8000) addresses tile data at &h48200 + (P - &h8000) * 8
'(offsets include the 0x200 header that ff4rom always carries).
'Normal sizes (0-16) are a width x height block of 8x8 tiles in row-major order.
'Other sizes (bosses, party members) use arrangement tables that are not decoded yet,
'so their tiles are shown as a raw sheet.

const monster_sprite_base = &h48200
const monster_sprite_sheet_width = 16
const monster_sprite_sheet_rows = 8

function MonsterSpriteOffset(gfx_ptr as UInteger) as Integer

 if gfx_ptr < &h8000 then return -1
 return monster_sprite_base + (gfx_ptr - &h8000) * 8

end function


function MonsterSpriteImage(gfx_ptr as UInteger, size as UByte, pal as UByte, byref raw_sheet as Boolean) as Any ptr

 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim widths(16) as Integer = {2, 4, 4, 6, 6, 6, 8, 8, 6, 12, 20, 10, 5, 2, 3, 4, 4}
 dim heights(16) as Integer = {2, 4, 6, 4, 6, 8, 6, 8, 12, 6, 18, 6, 3, 3, 3, 3, 2}
 dim start as Integer
 dim tile_start as Integer
 dim result as Any ptr
 dim p0 as UByte
 dim p1 as UByte
 dim p2 as UByte
 dim color_index as Integer
 dim pixel as UInteger

 start = MonsterSpriteOffset(gfx_ptr)
 if start < 0 then return 0

 if size <= 16 then
  tiles_wide = widths(size)
  tiles_high = heights(size)
  raw_sheet = false
 else
  tiles_wide = monster_sprite_sheet_width
  tiles_high = monster_sprite_sheet_rows
  raw_sheet = true
 end if

 if start + tiles_wide * tiles_high * 24 > len(ff4rom) then return 0

 result = ImageCreate(tiles_wide * 8, tiles_high * 8, RGB(0, 0, 0))

 for t as Integer = 0 to tiles_wide * tiles_high - 1
  tile_start = start + t * 24
  for row as Integer = 0 to 7
   p0 = ByteAt(tile_start + row * 2)
   p1 = ByteAt(tile_start + row * 2 + 1)
   p2 = ByteAt(tile_start + 16 + row)
   for col as Integer = 0 to 7
    color_index = ((p0 shr (7 - col)) and 1) or (((p1 shr (7 - col)) and 1) shl 1) or (((p2 shr (7 - col)) and 1) shl 2)
    if color_index = 0 then pixel = RGB(0, 0, 0) else pixel = monster_palettes(pal + 1, color_index)
    pset result, ((t mod tiles_wide) * 8 + col, (t \ tiles_wide) * 8 + row), pixel
   next
  next
 next

 return result

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
 
 if snapshot = 0 then
  snapshot = ImageCreate((monster_panel_w + 2) * 8, (monster_panel_h + 2) * 8, RGB(0, 0, 0))
  get (monster_panel_x * 8, monster_panel_y * 8)-((monster_panel_x + monster_panel_w + 2) * 8 - 1, (monster_panel_y + monster_panel_h + 2) * 8 - 1), snapshot
 end if
 
 BlueBox(monster_panel_x, monster_panel_y, monster_panel_w, monster_panel_h)
 
 sprite = MonsterSpriteImage(gfx_ptr, size, pal, raw_sheet)
 
 if sprite = 0 then
  if gfx_ptr < &h8000 then
   WriteText(FF4Text("No preview: pointer below 8000h"), monster_panel_x + 1, monster_panel_y + 1, 12)
  else
   WriteText(FF4Text("No preview: data is past ROM end"), monster_panel_x + 1, monster_panel_y + 1, 12)
  end if
 else
  info = "Ptr " + str(gfx_ptr) + " Pal " + str(pal)
  if raw_sheet then info += " Raw tiles"
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
    line (area_x + x * zoom, area_y + y * zoom)-step(zoom - 1, zoom - 1), point(x, y, sprite), bf
   next
  next
  ImageDestroy(sprite)
 end if

end sub


sub MonsterSpritePanelHide(byref snapshot as Any ptr)

 if snapshot <> 0 then
  put (monster_panel_x * 8, monster_panel_y * 8), snapshot, pset
  ImageDestroy(snapshot)
  snapshot = 0
 end if

end sub
