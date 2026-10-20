'World map viewer: the overworld, the underground and the moon.
'
'Each world is a grid of 16x16 pixel tiles (the world's tileset has 128 of them). The grid is stored
'as one run length compressed ROW per pointer, so the overworld is 256 rows of 256 tiles, the
'underground is 256 rows of 256 and the moon is 64 rows of 64. Pointer tables (16 bit offsets from the
'start of each world's data, bank 16h):
'    overworld   table 168000h  data 168480h   a byte below 80h is a tile; 80h-FFh is tile and 7Fh
'                                              followed by a count minus 1; the tiles 00h, 10h, 20h and 30h
'                                              stand for four tiles (itself, then three in a row at
'                                              70h + 3 * (tile / 16))
'    underground table 168200h  data 16C480h   same without the four tile shortcut
'    moon        table 168400h  data 16E180h   same
'(addresses are bank * 10000h + address, as the disassembly writes them)
'
'A map tile is four 8x8 tiles of the world's graphics: the top left is byte T of the world's
'tileset, the top right byte T + 80h, the bottom left T + 100h and the bottom right T + 180h. The
'graphics are 4 bits per pixel, two pixels per byte (low nibble first), 32 bytes per 8x8 tile in row
'order. Each 8x8 tile has a color offset (0, 10h, 20h, 30h) that is added to its pixels to pick from
'the world's 64 colors. The game also changes a few tiles of the overworld while it runs (story
'events); this viewer shows the map as stored.
'
'Where things are (bank * 10000h + address): tilesets 148000h (200h each), tile color offsets 148600h (100h
'each), palettes 148900h (80h each), tile properties 148A80h (100h each), graphics 1D8000h (2000h each).

const world_count = 3
const world_view_cols = 32
const world_view_rows = 27
const world_panel_x = 512
const world_loaded_rows = 256

dim shared world_size(2) as Integer
dim shared world_tiles(2, 255, 255) as UByte 'world, row, column
dim shared world_palette(2, 63) as UInteger
dim shared world_tile_img(2, 127) as Any ptr
dim shared world_tile_avg(2, 127) as UInteger
dim shared world_loaded as Boolean
dim shared world_built(2) as Boolean


function WorldOffset(address as UInteger) as Integer

 'ROM image offset (header included) of a bank * 10000h + address value

 return (address shr 16) * &h8000 + (address and &h7FFF) + &h200

end function


sub DecodeWorldRow(w as Integer, y as Integer, start as Integer)

 dim read_pos as Integer = start
 dim x as Integer = 0
 dim width_tiles as Integer = world_size(w)
 dim b as Integer
 dim count as Integer
 dim base_tile as Integer

 do while x < width_tiles and read_pos < len(ff4rom) - 1
  b = ByteAt(read_pos)
  read_pos += 1
  if b >= &h80 then
   count = ByteAt(read_pos) + 1
   read_pos += 1
   for k as Integer = 1 to count
    if x < width_tiles then world_tiles(w, y, x) = b and &h7F
    x += 1
   next
  elseif w = 0 and (b = &h00 or b = &h10 or b = &h20 or b = &h30) then
   base_tile = (b shr 4) * 3 + &h70
   if x < width_tiles then world_tiles(w, y, x) = b
   if x + 1 < width_tiles then world_tiles(w, y, x + 1) = base_tile
   if x + 2 < width_tiles then world_tiles(w, y, x + 2) = base_tile + 1
   if x + 3 < width_tiles then world_tiles(w, y, x + 3) = base_tile + 2
   x += 4
  else
   world_tiles(w, y, x) = b
   x += 1
  end if
 loop

end sub


sub ReadWorldMaps()

 dim table_start(2) as Integer
 dim data_start(2) as Integer
 dim row_count(2) as Integer
 dim pointer_value as Integer

 world_size(0) = 256
 world_size(1) = 256
 world_size(2) = 64
 table_start(0) = WorldOffset(&h168000)
 table_start(1) = WorldOffset(&h168200)
 table_start(2) = WorldOffset(&h168400)
 data_start(0) = WorldOffset(&h168480)
 data_start(1) = WorldOffset(&h16C480)
 data_start(2) = WorldOffset(&h16E180)
 row_count(0) = 256
 row_count(1) = 256
 row_count(2) = 64

 for w as Integer = 0 to 2
  for y as Integer = 0 to row_count(w) - 1
   pointer_value = ByteAt(table_start(w) + y * 2) + ByteAt(table_start(w) + y * 2 + 1) * &h100
   DecodeWorldRow(w, y, data_start(w) + pointer_value)
  next
 next

end sub


sub BuildWorldTiles(w as Integer)

 'Draws the 128 map tiles of one world into images, and works out each tile's average color

 dim tileset_start as Integer = WorldOffset(&h148000) + w * &h200
 dim offsets_start as Integer = WorldOffset(&h148600) + w * &h100
 dim palette_start as Integer = WorldOffset(&h148900) + w * &h80
 dim graphics_start as Integer = WorldOffset(&h1D8000) + w * &h2000
 dim sub_tile as Integer
 dim color_index as Integer
 dim b as Integer
 dim nibble as Integer
 dim pixel_value as UInteger
 dim pixels as Any ptr
 dim pitch as Integer
 dim red as Integer
 dim green as Integer
 dim blue as Integer
 dim px as Integer
 dim py as Integer
 dim word as Integer

 for i as Integer = 0 to 63
  word = ByteAt(palette_start + i * 2) + ByteAt(palette_start + i * 2 + 1) * &h100
  world_palette(w, i) = RGB((word mod 32) * 8, ((word \ 32) mod 32) * 8, ((word \ 1024) mod 32) * 8)
 next

 for t as Integer = 0 to 127
  if world_tile_img(w, t) <> 0 then ImageDestroy(world_tile_img(w, t))
  world_tile_img(w, t) = MonsterNewImage(2, 2, pixels, pitch)
  red = 0
  green = 0
  blue = 0
  for quarter as Integer = 0 to 3
   sub_tile = ByteAt(tileset_start + t + (quarter \ 2) * &h100 + (quarter mod 2) * &h80)
   for y as Integer = 0 to 7
    for x as Integer = 0 to 7
     b = ByteAt(graphics_start + sub_tile * 32 + y * 4 + x \ 2)
     if x mod 2 = 0 then nibble = b and 15 else nibble = b \ 16
     color_index = nibble + ByteAt(offsets_start + sub_tile)
     if color_index > 63 then pixel_value = RGB(0, 0, 0) else pixel_value = world_palette(w, color_index)
     px = (quarter mod 2) * 8 + x
     py = (quarter \ 2) * 8 + y
     MonsterPutPixel(pixels, pitch, px, py, pixel_value)
     red += (pixel_value shr 16) and 255
     green += (pixel_value shr 8) and 255
     blue += pixel_value and 255
    next
   next
  next
  world_tile_avg(w, t) = RGB(red \ 256, green \ 256, blue \ 256)
 next

 world_built(w) = true

end sub


function WorldName(w as Integer) as String

 select case w
  case 0: return "Overworld"
  case 1: return "Underground"
 end select

 return "Moon"

end function


function WorldMinimap(w as Integer, view_x as Integer, view_y as Integer) as Any ptr

 'A 128x128 picture of the whole world, one pixel per 2 tiles (or 2 pixels per tile on the moon)

 dim pixels as Any ptr
 dim pitch as Integer
 dim result as Any ptr = MonsterNewImage(16, 16, pixels, pitch)

 if result = 0 then return 0
 for y as Integer = 0 to 127
  for x as Integer = 0 to 127
   MonsterPutPixel(pixels, pitch, x, y, world_tile_avg(w, world_tiles(w, y * world_size(w) \ 128, x * world_size(w) \ 128) and 127))
  next
 next

 return result

end function


sub DrawWorldView(w as Integer, view_x as Integer, view_y as Integer, cursor_x as Integer, cursor_y as Integer, minimap as Any ptr)

 dim tile_number as Integer
 dim screen_x as Integer
 dim screen_y as Integer
 dim passability as Integer
 dim extra as Integer
 dim row as Integer = 20
 dim box_x as Integer
 dim box_y as Integer
 dim box_w as Integer
 dim box_h as Integer
 dim names(7) as String = {"Walk", "Chocobo", "Black choc fly", "Black choc land", "Hovercraft", "Airship flies", "Walk upper", "Whale flies"}

 screenlock

 for r as Integer = 0 to world_view_rows - 1
  for c as Integer = 0 to world_view_cols - 1
   if view_y + r < world_size(w) and view_x + c < world_size(w) then
    tile_number = world_tiles(w, view_y + r, view_x + c) and 127
    put (c * 16, r * 16), world_tile_img(w, tile_number), pset
   else
    line (c * 16, r * 16)-(c * 16 + 15, r * 16 + 15), RGB(0, 0, 0), bf
   end if
  next
 next

 'The cursor
 screen_x = (cursor_x - view_x) * 16
 screen_y = (cursor_y - view_y) * 16
 line (screen_x, screen_y)-(screen_x + 15, screen_y + 15), RGB(255, 255, 255), b
 line (screen_x + 1, screen_y + 1)-(screen_x + 14, screen_y + 14), RGB(0, 0, 0), b

 'The side panel
 line (world_panel_x, 0)-(639, 479), RGB(0, 0, 96), bf
 put (world_panel_x + 8, 8), minimap, pset
 box_x = world_panel_x + 8 + view_x * 128 \ world_size(w)
 box_y = 8 + view_y * 128 \ world_size(w)
 box_w = min(world_view_cols, world_size(w)) * 128 \ world_size(w)
 box_h = min(world_view_rows, world_size(w)) * 128 \ world_size(w)
 line (box_x, box_y)-(box_x + box_w - 1, box_y + box_h - 1), RGB(255, 255, 0), b

 WriteText(FF4Text(WorldName(w)), 65, 18, 14)
 WriteText(FF4Text("X " + str(cursor_x) + " Y " + str(cursor_y)), 65, 19, 15)
 tile_number = world_tiles(w, cursor_y, cursor_x) and 127
 WriteText(FF4Text("Tile " + hex(tile_number, 2)), 65, 20, 15)
 passability = ByteAt(WorldOffset(&h148A80) + w * &h100 + tile_number * 2)
 extra = ByteAt(WorldOffset(&h148A80) + w * &h100 + tile_number * 2 + 1)
 row = 22
 for i as Integer = 0 to 7
  if (passability and (1 shl i)) <> 0 then
   WriteText(FF4Text(names(i)), 65, row, 12)
   row += 1
  end if
 next
 if (extra and &h08) <> 0 then WriteText(FF4Text("Hides feet"), 65, row, 10): row += 1
 if (extra and &h10) <> 0 then WriteText(FF4Text("Airship lands"), 65, row, 10): row += 1
 if (extra and &h40) <> 0 then WriteText(FF4Text("Random battles"), 65, row, 10): row += 1
 if (extra and &h80) <> 0 then WriteText(FF4Text("Trigger tile"), 65, row, 10): row += 1

 WriteText(FF4Text("Arrows move"), 65, 48, 15)
 WriteText(FF4Text("PgUp PgDn jump"), 65, 49, 15)
 WriteText(FF4Text("Home End jump"), 65, 50, 15)
 WriteText(FF4Text("Tab next world"), 65, 51, 15)
 WriteText(FF4Text("Click the map"), 65, 52, 15)
 WriteText(FF4Text("to jump there"), 65, 53, 15)
 WriteText(FF4Text("Esc leaves"), 65, 54, 15)

 screenunlock

end sub


sub ViewWorldMaps()

 'Phase 1: look around the three worlds. Nothing here changes the ROM.

 dim w as Integer = 0
 dim view_x as Integer
 dim view_y as Integer
 dim cursor_x as Integer
 dim cursor_y as Integer
 dim minimap(2) as Any ptr
 dim key as String
 dim key_code as UInteger
 dim done as Boolean
 dim cell_x as Integer
 dim cell_y as Integer
 dim left_click as Boolean
 dim right_click as Boolean
 dim wheel_steps as Integer
 dim redraw as Boolean = true
 dim mx as Integer
 dim my as Integer
 dim limit as Integer

 if not world_loaded then
  ReadWorldMaps()
  world_loaded = true
 end if
 for i as Integer = 0 to 2
  if not world_built(i) then BuildWorldTiles(i)
  minimap(i) = WorldMinimap(i, 0, 0)
 next

 cls
 do
  if redraw then
   limit = world_size(w) - 1
   if cursor_x < 0 then cursor_x = 0
   if cursor_y < 0 then cursor_y = 0
   if cursor_x > limit then cursor_x = limit
   if cursor_y > limit then cursor_y = limit
   if cursor_x < view_x then view_x = cursor_x
   if cursor_y < view_y then view_y = cursor_y
   if cursor_x >= view_x + world_view_cols then view_x = cursor_x - world_view_cols + 1
   if cursor_y >= view_y + world_view_rows then view_y = cursor_y - world_view_rows + 1
   if view_x < 0 then view_x = 0
   if view_y < 0 then view_y = 0
   if view_x + world_view_cols > world_size(w) and world_size(w) >= world_view_cols then view_x = world_size(w) - world_view_cols
   if view_y + world_view_rows > world_size(w) and world_size(w) >= world_view_rows then view_y = world_size(w) - world_view_rows
   DrawWorldView(w, view_x, view_y, cursor_x, cursor_y, minimap(w))
   redraw = false
  end if

  key = inkey
  if key <> "" then
   key_code = asc(right(key, 1))
   if len(key) > 1 then key_code = key_code * &h100 + 255
   redraw = true
   select case key_code
    case ESC_KEY: done = true
    case UP_KEY: cursor_y -= 1
    case DOWN_KEY: cursor_y += 1
    case LEFT_KEY: cursor_x -= 1
    case RIGHT_KEY: cursor_x += 1
    case PAGEUP_KEY: cursor_y -= 16
    case PAGEDOWN_KEY: cursor_y += 16
    case HOME_KEY: cursor_x -= 16
    case END_KEY: cursor_x += 16
    case TAB_KEY
     w = (w + 1) mod world_count
     view_x = 0
     view_y = 0
     cursor_x = world_size(w) \ 2
     cursor_y = world_size(w) \ 2
    case else: redraw = false
   end select
  else
   PollMouse(cell_x, cell_y, left_click, right_click, wheel_steps)
   if right_click then
    done = true
   elseif wheel_steps <> 0 then
    cursor_y -= sgn(wheel_steps) * 3
    redraw = true
   elseif left_click and mouse_pixel_x >= 0 then
    mx = mouse_pixel_x
    my = mouse_pixel_y
    if mx < world_view_cols * 16 and my < world_view_rows * 16 then
     cursor_x = view_x + mx \ 16
     cursor_y = view_y + my \ 16
     redraw = true
    elseif mx >= world_panel_x + 8 and mx < world_panel_x + 136 and my >= 8 and my < 136 then
     cursor_x = (mx - world_panel_x - 8) * world_size(w) \ 128
     cursor_y = (my - 8) * world_size(w) \ 128
     view_x = cursor_x - world_view_cols \ 2
     view_y = cursor_y - world_view_rows \ 2
     redraw = true
    end if
   end if
   if not redraw then sleep 10
  end if
 loop until done

 for i as Integer = 0 to 2
  if minimap(i) <> 0 then ImageDestroy(minimap(i))
 next
 'End with a draw on the screen itself so no destroyed image stays the drawing target
 pset (0, 0), point(0, 0)
 cls

end sub
