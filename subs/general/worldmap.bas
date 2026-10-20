'World map editor: the overworld, the underground and the moon.
'
'Each world is a grid of 16x16 pixel tiles (the world's tileset has 128 of them). The grid is stored
'as one run length compressed ROW per pointer, so the overworld is 256 rows of 256 tiles, the
'underground is 256 rows of 256 and the moon is 64 rows of 64. Pointer tables (16 bit offsets from the
'start of each world's data, bank 16h):
'    overworld   table 168000h  data 168480h   a byte below 80h is a tile; 80h-FFh is tile and 7Fh
'                                              followed by a count minus 1; the tiles 00h, 10h, 20h and 30h
'                                              stand for four tiles (itself, then three in a row at
'                                              70h + 3 * (tile / 16)), so on their own they have to be
'                                              written as a run of one
'    underground table 168200h  data 16C480h   same without the four tile shortcut
'    moon        table 168400h  data 16E180h   same
'(addresses are bank * 10000h + address, as the disassembly writes them). A row has to decode to exactly
'its width (256, 256 and 64) because the game stops reading it there.
'
'The three data blocks have fixed room (the game's linker reserves it): 4000h bytes for the overworld
'(168480h-16C47Fh), 1D00h for the underground and 1E80h for the moon (to the end of bank 16h).
'
'Saving: a world none of whose rows changed is not touched. Otherwise every row is written again, the
'unchanged ones as the original bytes (compressed again if the world would not fit otherwise) and the
'changed ones freshly compressed, with new pointers; if the result is still bigger than the room the
'world is not written and Save ROM refuses.
'
'A map tile is four 8x8 tiles of the world's graphics: the top left is byte T of the world's
'tileset, the top right byte T + 80h, the bottom left T + 100h and the bottom right T + 180h. The
'graphics are 4 bits per pixel, two pixels per byte (low nibble first), 32 bytes per 8x8 tile in row
'order. Each 8x8 tile has a color offset (0, 10h, 20h, 30h) that is added to its pixels to pick from
'the world's 64 colors. The game also changes a few tiles of the overworld while it runs (story
'events); the editor shows the map as stored.
'
'Where things are (bank * 10000h + address): tilesets 148000h (200h each), tile color offsets 148600h (100h
'each), palettes 148900h (80h each), tile properties 148A80h (100h each), graphics 1D8000h (2000h each).

const world_count = 3
const world_view_cols = 30 'tiles of the map that show at once
const world_view_rows = 24

dim shared world_size(2) as Integer
dim shared world_capacity(2) as Integer
dim shared world_tiles(2, 255, 255) as UByte 'world, row, column
dim shared world_orig(2, 255, 255) as UByte 'as loaded, to see which rows changed
dim shared world_raw(2, 255) as String 'the original bytes of each row
dim shared world_palette(2, 63) as UInteger
dim shared world_tile_img(2, 127) as Any ptr
dim shared world_tile_avg(2, 127) as UInteger
dim shared world_loaded as Boolean
dim shared world_built(2) as Boolean

'Undo: every cell change is recorded (where, the old tile, the new tile); an operation is a run of cells
const world_undo_cells = 262144
const world_undo_ops = 400
dim shared wu_pos(world_undo_cells - 1) as UInteger
dim shared wu_val(world_undo_cells - 1) as UShort 'old tile * 128 + new tile
dim shared wu_op_start(world_undo_ops + 1) as Integer
dim shared wu_ops as Integer 'operations recorded
dim shared wu_cur as Integer 'operations applied (what Undo steps back over)
dim shared wu_cells as Integer

'Copied rectangle
dim shared world_clip(255, 255) as UByte
dim shared world_clip_w as Integer
dim shared world_clip_h as Integer

'The editor's state
dim shared wv_world as Integer
dim shared wv_view_x as Integer
dim shared wv_view_y as Integer
dim shared wv_cursor_x as Integer
dim shared wv_cursor_y as Integer
dim shared wv_anchor_x as Integer
dim shared wv_anchor_y as Integer
dim shared wv_selecting as Boolean
dim shared wv_tile as Integer 'the tile Enter paints
dim shared wv_minimap(2) as Any ptr
dim shared wv_minimap_dirty(2) as Boolean


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


function WorldTableStart(w as Integer) as Integer

 select case w
  case 0: return WorldOffset(&h168000)
  case 1: return WorldOffset(&h168200)
 end select

 return WorldOffset(&h168400)

end function


function WorldDataStart(w as Integer) as Integer

 select case w
  case 0: return WorldOffset(&h168480)
  case 1: return WorldOffset(&h16C480)
 end select

 return WorldOffset(&h16E180)

end function


sub ReadWorldMaps()

 'Called once after the ROM is loaded

 dim pointer_value as Integer
 dim row_start(256) as Integer
 dim data_end(2) as Integer

 world_size(0) = 256
 world_size(1) = 256
 world_size(2) = 64
 world_capacity(0) = &h4000
 world_capacity(1) = &h1D00
 world_capacity(2) = &h1E80
 'the end of the last row of each world (the end of what the game's data lists as used)
 data_end(0) = WorldOffset(&h16C354) + 1
 data_end(1) = WorldOffset(&h16E041) + 1
 data_end(2) = WorldOffset(&h16EB53) + 1

 for w as Integer = 0 to 2
  for y as Integer = 0 to world_size(w) - 1
   pointer_value = ByteAt(WorldTableStart(w) + y * 2) + ByteAt(WorldTableStart(w) + y * 2 + 1) * &h100
   row_start(y) = WorldDataStart(w) + pointer_value
   DecodeWorldRow(w, y, row_start(y))
  next
  row_start(world_size(w)) = data_end(w)
  for y as Integer = 0 to world_size(w) - 1
   'rows follow each other in the ROM; if a table ever points backwards keep what we can
   world_raw(w, y) = ""
   if row_start(y + 1) > row_start(y) and row_start(y + 1) - row_start(y) < 1024 then
    for i as Integer = row_start(y) to row_start(y + 1) - 1
     world_raw(w, y) += chr(ByteAt(i))
    next
   end if
   for x as Integer = 0 to world_size(w) - 1
    world_orig(w, y, x) = world_tiles(w, y, x)
   next
  next
 next

 world_loaded = true

end sub


function WorldRowChanged(w as Integer, y as Integer) as Boolean

 for x as Integer = 0 to world_size(w) - 1
  if world_tiles(w, y, x) <> world_orig(w, y, x) then return true
 next

 return false

end function


function WorldChanged(w as Integer) as Boolean

 if not world_loaded then return false
 for y as Integer = 0 to world_size(w) - 1
  if WorldRowChanged(w, y) then return true
 next

 return false

end function


function EncodeWorldRow(w as Integer, y as Integer) as String

 'The row in the game's compression: runs of equal tiles, the four tile shortcut on the overworld
 ' where it applies, and a run of one for the tiles whose plain value would be taken as that shortcut.

 dim result as String
 dim x as Integer = 0
 dim width_tiles as Integer = world_size(w)
 dim b as Integer
 dim run_length as Integer
 dim base_tile as Integer
 dim special as Boolean

 do while x < width_tiles
  b = world_tiles(w, y, x) and &h7F
  special = (w = 0 and (b = &h00 or b = &h10 or b = &h20 or b = &h30))
  if special and x + 3 < width_tiles then
   base_tile = (b shr 4) * 3 + &h70
   if world_tiles(w, y, x + 1) = base_tile and world_tiles(w, y, x + 2) = base_tile + 1 and world_tiles(w, y, x + 3) = base_tile + 2 then
    result += chr(b)
    x += 4
    continue do
   end if
  end if
  run_length = 1
  do while x + run_length < width_tiles and run_length < 256
   if (world_tiles(w, y, x + run_length) and &h7F) <> b then exit do
   run_length += 1
  loop
  if run_length > 1 or special then
   result += chr(b or &h80) + chr(run_length - 1)
   x += run_length
  else
   result += chr(b)
   x += 1
  end if
 loop

 return result

end function


function WorldRowData(w as Integer, y as Integer, squeeze as Boolean) as String

 'The bytes a row is saved as: freshly compressed if it changed, else the original bytes. With squeeze,
 ' an unchanged row is compressed again if that makes it shorter (the game's own data has a spare byte
 ' in many rows).

 dim fresh as String

 if WorldRowChanged(w, y) then return EncodeWorldRow(w, y)
 if squeeze then
  fresh = EncodeWorldRow(w, y)
  if len(fresh) < len(world_raw(w, y)) then return fresh
 end if

 return world_raw(w, y)

end function


function WorldDataBytes(w as Integer) as Integer

 'How many bytes the world takes up when saved. Unchanged rows keep their original bytes unless
 ' the world would not fit that way.

 dim total as Integer
 dim squeezed as Integer

 if not world_loaded then return 0
 for y as Integer = 0 to world_size(w) - 1
  total += len(WorldRowData(w, y, false))
 next
 if total <= world_capacity(w) then return total

 for y as Integer = 0 to world_size(w) - 1
  squeezed += len(WorldRowData(w, y, true))
 next

 return squeezed

end function


function WorldNameText(w as Integer) as String

 select case w
  case 0: return "Overworld"
  case 1: return "Underground"
 end select

 return "Moon"

end function


sub SaveWorldMaps()

 'Writes the worlds that were edited. Does nothing for the others, so an unedited ROM stays as it was.

 dim row_text(255) as String
 dim total as Integer
 dim offset as Integer

 if not world_loaded then exit sub

 for w as Integer = 0 to 2
  if WorldChanged(w) then
   total = 0
   for y as Integer = 0 to world_size(w) - 1
    row_text(y) = WorldRowData(w, y, false)
    total += len(row_text(y))
   next
   if total > world_capacity(w) then
    total = 0
    for y as Integer = 0 to world_size(w) - 1
     row_text(y) = WorldRowData(w, y, true)
     total += len(row_text(y))
    next
   end if
   if total > world_capacity(w) then
    WarningMessage(FF4Text(WorldNameText(w) + " map overflow!"))
   else
    offset = 0
    for y as Integer = 0 to world_size(w) - 1
     WriteByte(WorldTableStart(w) + y * 2, offset mod &h100)
     WriteByte(WorldTableStart(w) + y * 2 + 1, offset \ &h100)
     for i as Integer = 1 to len(row_text(y))
      WriteByte(WorldDataStart(w) + offset + i - 1, asc(mid(row_text(y), i, 1)))
     next
     offset += len(row_text(y))
    next
   end if
  end if
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


sub BuildWorldMinimap(w as Integer)

 'A 128x128 picture of the whole world, one pixel per 2 tiles (or 2 pixels per tile on the moon)

 dim pixels as Any ptr
 dim pitch as Integer

 if wv_minimap(w) = 0 then wv_minimap(w) = MonsterNewImage(16, 16, pixels, pitch) else imageinfo wv_minimap(w), , , , pitch, pixels
 if wv_minimap(w) = 0 then exit sub
 for y as Integer = 0 to 127
  for x as Integer = 0 to 127
   MonsterPutPixel(pixels, pitch, x, y, world_tile_avg(w, world_tiles(w, y * world_size(w) \ 128, x * world_size(w) \ 128) and 127))
  next
 next
 wv_minimap_dirty(w) = false

end sub


'--- undo ---------------------------------------------------------------------------------

sub WorldDropOldestOp()

 dim removed_cells as Integer = wu_op_start(1)

 for i as Integer = removed_cells to wu_cells - 1
  wu_pos(i - removed_cells) = wu_pos(i)
  wu_val(i - removed_cells) = wu_val(i)
 next
 for k as Integer = 1 to wu_ops
  wu_op_start(k - 1) = wu_op_start(k) - removed_cells
 next
 wu_ops -= 1
 wu_cur = max(wu_cur - 1, 0)
 wu_cells -= removed_cells

end sub


sub WorldBeginOp()

 'Starts a group of changes that Undo takes back together

 if wu_cur < wu_ops then
  wu_ops = wu_cur
  wu_cells = wu_op_start(wu_cur)
 end if
 do while wu_ops >= world_undo_ops - 1 or wu_cells > world_undo_cells - 70000
  if wu_ops = 0 then exit do
  WorldDropOldestOp()
 loop
 wu_op_start(wu_ops) = wu_cells

end sub


sub WorldEndOp()

 if wu_cells = wu_op_start(wu_ops) then exit sub
 wu_ops += 1
 wu_op_start(wu_ops) = wu_cells
 wu_cur = wu_ops

end sub


sub WorldSetTile(w as Integer, x as Integer, y as Integer, tile_number as Integer)

 'Changes one cell and records it (inside WorldBeginOp / WorldEndOp)

 dim old_tile as Integer

 if x < 0 or y < 0 or x >= world_size(w) or y >= world_size(w) then exit sub
 old_tile = world_tiles(w, y, x)
 if old_tile = tile_number then exit sub
 if wu_cells >= world_undo_cells then exit sub
 wu_pos(wu_cells) = (w * 256 + y) * 256 + x
 wu_val(wu_cells) = old_tile * 128 + tile_number
 wu_cells += 1
 world_tiles(w, y, x) = tile_number
 wv_minimap_dirty(w) = true

end sub


function WorldUndo() as Boolean

 dim k as Integer
 dim p as UInteger

 if wu_cur = 0 then return false
 k = wu_cur - 1
 for i as Integer = wu_op_start(k + 1) - 1 to wu_op_start(k) step -1
  p = wu_pos(i)
  world_tiles(p shr 16, (p shr 8) and 255, p and 255) = wu_val(i) \ 128
  wv_minimap_dirty(p shr 16) = true
  wv_world = p shr 16
  wv_cursor_x = p and 255
  wv_cursor_y = (p shr 8) and 255
 next
 wu_cur -= 1

 return true

end function


function WorldRedo() as Boolean

 dim p as UInteger

 if wu_cur >= wu_ops then return false
 for i as Integer = wu_op_start(wu_cur) to wu_op_start(wu_cur + 1) - 1
  p = wu_pos(i)
  world_tiles(p shr 16, (p shr 8) and 255, p and 255) = wu_val(i) and 127
  wv_minimap_dirty(p shr 16) = true
  wv_world = p shr 16
  wv_cursor_x = p and 255
  wv_cursor_y = (p shr 8) and 255
 next
 wu_cur += 1

 return true

end function


'--- editing operations (each one group for Undo) ---------------------------------------------

sub WorldSelectionRect(byref x0 as Integer, byref y0 as Integer, byref x1 as Integer, byref y1 as Integer)

 if wv_selecting then
  x0 = min(wv_anchor_x, wv_cursor_x)
  y0 = min(wv_anchor_y, wv_cursor_y)
  x1 = max(wv_anchor_x, wv_cursor_x)
  y1 = max(wv_anchor_y, wv_cursor_y)
 else
  x0 = wv_cursor_x
  y0 = wv_cursor_y
  x1 = wv_cursor_x
  y1 = wv_cursor_y
 end if

end sub


sub WorldPaintSelection()

 dim x0 as Integer
 dim y0 as Integer
 dim x1 as Integer
 dim y1 as Integer

 WorldSelectionRect(x0, y0, x1, y1)
 WorldBeginOp()
 for y as Integer = y0 to y1
  for x as Integer = x0 to x1
   WorldSetTile(wv_world, x, y, wv_tile)
  next
 next
 WorldEndOp()

end sub


sub WorldFill()

 'Flood fill from the cursor with the chosen tile (4 neighbours)

 dim stack_x(65535) as UByte
 dim stack_y(65535) as UByte
 dim top as Integer
 dim target as Integer = world_tiles(wv_world, wv_cursor_y, wv_cursor_x)
 dim x as Integer
 dim y as Integer
 dim nx as Integer
 dim ny as Integer
 dim limit as Integer = world_size(wv_world) - 1

 if target = wv_tile then exit sub
 WorldBeginOp()
 WorldSetTile(wv_world, wv_cursor_x, wv_cursor_y, wv_tile)
 stack_x(0) = wv_cursor_x
 stack_y(0) = wv_cursor_y
 top = 1
 do while top > 0
  top -= 1
  x = stack_x(top)
  y = stack_y(top)
  for d as Integer = 0 to 3
   nx = x
   ny = y
   select case d
    case 0: nx += 1
    case 1: nx -= 1
    case 2: ny += 1
    case 3: ny -= 1
   end select
   if nx >= 0 and ny >= 0 and nx <= limit and ny <= limit then
    if world_tiles(wv_world, ny, nx) = target and top < 65535 then
     WorldSetTile(wv_world, nx, ny, wv_tile)
     stack_x(top) = nx
     stack_y(top) = ny
     top += 1
    end if
   end if
  next
 loop
 WorldEndOp()

end sub


sub WorldReplaceAll()

 dim target as Integer = world_tiles(wv_world, wv_cursor_y, wv_cursor_x)

 if target = wv_tile then exit sub
 WorldBeginOp()
 for y as Integer = 0 to world_size(wv_world) - 1
  for x as Integer = 0 to world_size(wv_world) - 1
   if world_tiles(wv_world, y, x) = target then WorldSetTile(wv_world, x, y, wv_tile)
  next
 next
 WorldEndOp()

end sub


sub WorldCopySelection()

 dim x0 as Integer
 dim y0 as Integer
 dim x1 as Integer
 dim y1 as Integer

 WorldSelectionRect(x0, y0, x1, y1)
 world_clip_w = x1 - x0 + 1
 world_clip_h = y1 - y0 + 1
 for y as Integer = 0 to world_clip_h - 1
  for x as Integer = 0 to world_clip_w - 1
   world_clip(y, x) = world_tiles(wv_world, y0 + y, x0 + x)
  next
 next

end sub


sub WorldPasteAtCursor()

 dim x0 as Integer
 dim y0 as Integer
 dim x1 as Integer
 dim y1 as Integer

 if world_clip_w = 0 then exit sub
 WorldSelectionRect(x0, y0, x1, y1)
 WorldBeginOp()
 for y as Integer = 0 to world_clip_h - 1
  for x as Integer = 0 to world_clip_w - 1
   WorldSetTile(wv_world, x0 + x, y0 + y, world_clip(y, x))
  next
 next
 WorldEndOp()

end sub


'--- the screen -------------------------------------------------------------------------------
'The layout and keys follow the regular map editor: the tile palette on the left, the map on the right,
'a status box at the bottom, Tab switches between the two panels, Shift with the arrows selects a block,
'Enter places, Space fills, R replaces, Backspace picks, Ctrl-C / Ctrl-V copy and paste (paste shows a
'preview that Enter places and Esc cancels), Ctrl-Z / Ctrl-Y undo and redo, Esc leaves. A list of the
'three worlds comes first, like the list of maps.

const world_map_box_x = 18 'cells
const world_pal_px = 8 'pixel position of the first palette tile
const world_pal_py = 8
const world_map_px = world_map_box_x * 8 + 8 'pixel position of the first map tile
const world_map_py = 8
const world_mini_box_y = 34 'cells
const world_mini_px = 8
const world_mini_py = world_mini_box_y * 8 + 8

dim shared wv_pal_x as Integer 'palette cursor, 8 columns by 16 rows (tile = row \ 2 * 16 + row mod 2 * 8 + column)
dim shared wv_pal_y as Integer
dim shared wv_map_active as Boolean = true 'Tab switches between the map and the palette
dim shared wv_paste_mode as Boolean
dim shared wv_overlay as Integer = 3 'O cycles: 3 triggers and encounter zones, 1 triggers, 2 zones, 0 none

'Random battles: the game cuts each world into zones of 32 x 32 tiles and picks the encounter (a group
'of 8 formations, the numbers in the Encounters editor) by zone. The overworld has 8 x 8 zones, the
'underground 4 x 4 (its first 128 x 128 tiles) and the moon 2 x 2. The Encounters editor lists them as
'areas 1-64, 65-80 and 81-84 in rows from the top left.


function WorldPaletteTile() as Integer

 return (wv_pal_y \ 2) * 16 + (wv_pal_y mod 2) * 8 + wv_pal_x

end function


sub WorldPickTile(tile_number as Integer)

 'Puts the palette cursor on a tile

 wv_pal_x = tile_number mod 8
 wv_pal_y = (tile_number \ 16) * 2 + (tile_number mod 16) \ 8
 wv_tile = tile_number

end sub


sub DrawWorldCursor(px as Integer, py as Integer, tiles_wide as Integer, tiles_high as Integer, active as Boolean)

 'The map editor's cursor: a black / white / white / black frame around the tile (gray if the panel is not active)

 dim c as UInteger
 dim w_px as Integer = tiles_wide * 16
 dim h_px as Integer = tiles_high * 16

 if active then c = RGB(255, 255, 255) else c = RGB(127, 127, 127)
 line (px - 4, py - 4)-(px + w_px + 3, py + h_px + 3), RGB(0, 0, 0), b
 line (px - 3, py - 3)-(px + w_px + 2, py + h_px + 2), c, b
 line (px - 2, py - 2)-(px + w_px + 1, py + h_px + 1), c, b
 line (px - 1, py - 1)-(px + w_px, py + h_px), RGB(0, 0, 0), b

end sub


function WorldZoneArea(w as Integer, tile_x as Integer, tile_y as Integer) as Integer

 'The number of the encounter area (as the Encounters editor lists it) a tile is in, or 0 if none

 select case w
  case 0: return (tile_y \ 32) * 8 + tile_x \ 32 + 1
  case 1
   if tile_x < 128 and tile_y < 128 then return 64 + (tile_y \ 32) * 4 + tile_x \ 32 + 1
  case 2
   if tile_x < 64 and tile_y < 64 then return 80 + (tile_y \ 32) * 2 + tile_x \ 32 + 1
 end select

 return 0

end function


function WorldZoneExtent(w as Integer) as Integer

 'How many tiles across the zones cover

 select case w
  case 0: return 256
  case 1: return 128
 end select

 return 64

end function


function WorldTriggerText(w as Integer, tile_x as Integer, tile_y as Integer) as String

 'A few words about the trigger on a tile, or "" if there is none

 dim t as Trigger ptr
 dim destination as String

 for i as Integer = 1 to maps(252 + w).triggers.Length()
  t = maps(252 + w).triggers.PointerAt(i)
  if t->x = tile_x and t->y = tile_y then
   if t->warp then
    if w = 0 then
     destination = map_names.ItemAt(t->new_map + 1)
    elseif t->new_map < 128 then
     destination = map_names.ItemAt(t->new_map + 257)
    elseif t->new_map >= 251 then
     destination = map_names.ItemAt(t->new_map + 1)
    else
     destination = FF4Text("unknown")
    end if
    return "Trigger: goes to " + trim(FF4Name(destination)) + " at " + str(t->new_x) + "," + str(t->new_y)
   elseif t->treasure then
    return "Trigger: treasure"
   end if
   return "Trigger: event " + str(t->event)
  end if
 next

 return ""

end function


sub DrawWorldOverlays()

 'Triggers (yellow frames, like the map editor's) and the encounter zones (dashed lines, each
 ' zone labelled with its encounter number). Drawn inside the map box.

 dim w as Integer = wv_world
 dim t as Trigger ptr
 dim px as Integer
 dim py as Integer
 dim extent as Integer = WorldZoneExtent(w)
 dim area as Integer
 dim label_x as Integer
 dim label_y as Integer
 dim right_edge as Integer
 dim bottom_edge as Integer

 if (wv_overlay and 2) <> 0 then
  right_edge = world_map_px + min(extent - wv_view_x, world_view_cols) * 16
  bottom_edge = world_map_py + min(extent - wv_view_y, world_view_rows) * 16
  for g as Integer = 0 to extent step 32
   if g >= wv_view_x and g <= wv_view_x + world_view_cols then
    px = world_map_px + (g - wv_view_x) * 16
    line (px, world_map_py)-(px, bottom_edge - 1), RGB(255, 128, 0), , &hF0F0
   end if
   if g >= wv_view_y and g <= wv_view_y + world_view_rows then
    py = world_map_py + (g - wv_view_y) * 16
    line (world_map_px, py)-(right_edge - 1, py), RGB(255, 128, 0), , &hF0F0
   end if
  next
  for zone_y as Integer = 0 to extent - 32 step 32
   for zone_x as Integer = 0 to extent - 32 step 32
    area = WorldZoneArea(w, zone_x, zone_y)
    if area > 0 then
     'put the label in the part of the zone that is on screen
     label_x = max(zone_x, wv_view_x)
     label_y = max(zone_y, wv_view_y)
     if label_x + 3 < min(zone_x + 32, wv_view_x + world_view_cols) and label_y < min(zone_y + 32, wv_view_y + world_view_rows) then
      WriteText(FF4Text("Enc " + Pad(str(encounter_tables(area)), 2, true)), (world_map_px + (label_x - wv_view_x) * 16) \ 8 + 1, (world_map_py + (label_y - wv_view_y) * 16) \ 8 + 1, 14)
     end if
    end if
   next
  next
 end if

 if (wv_overlay and 1) <> 0 then
  for i as Integer = 1 to maps(252 + w).triggers.Length()
   t = maps(252 + w).triggers.PointerAt(i)
   if t->x >= wv_view_x and t->x < wv_view_x + world_view_cols and t->y >= wv_view_y and t->y < wv_view_y + world_view_rows then
    px = world_map_px + (t->x - wv_view_x) * 16
    py = world_map_py + (t->y - wv_view_y) * 16
    line (px, py)-(px + 15, py + 15), RGB(0, 0, 0), b
    line (px + 1, py + 1)-(px + 14, py + 14), RGB(255, 255, 0), b
    line (px + 2, py + 2)-(px + 13, py + 13), RGB(255, 255, 0), b
   end if
  next
 end if

end sub


function WorldFlagsText(w as Integer, tile_number as Integer) as String

 'What the tile allows, in a few words

 dim names(7) as String = {"Walk", "Chocobo", "Black chocobo flies", "Black chocobo lands", "Hovercraft", "Airship flies", "Walk upper level", "Whale flies"}
 dim result as String
 dim passability as Integer = ByteAt(WorldOffset(&h148A80) + w * &h100 + tile_number * 2)
 dim extra as Integer = ByteAt(WorldOffset(&h148A80) + w * &h100 + tile_number * 2 + 1)

 for i as Integer = 0 to 7
  if (passability and (1 shl i)) <> 0 then result += names(i) + ", "
 next
 if (extra and &h08) <> 0 then result += "Hides feet, "
 if (extra and &h10) <> 0 then result += "Airship lands, "
 if (extra and &h40) <> 0 then result += "Random battles, "
 if (extra and &h80) <> 0 then result += "Trigger tile, "
 if len(result) = 0 then return "Nothing can cross"

 return left(result, len(result) - 2)

end function


function WorldOverlayName() as String

 select case wv_overlay
  case 3: return "All"
  case 1: return "Triggers"
  case 2: return "Zones"
 end select

 return "Off"

end function


sub DrawWorldEditor()

 dim w as Integer = wv_world
 dim tile_number as Integer
 dim px as Integer
 dim py as Integer
 dim x0 as Integer
 dim y0 as Integer
 dim x1 as Integer
 dim y1 as Integer
 dim used as Integer
 dim box_x as Integer
 dim box_y as Integer
 dim box_w as Integer
 dim box_h as Integer
 dim status as String
 dim info_line as String
 dim clip_x as Integer
 dim clip_y as Integer

 if wv_minimap_dirty(w) then BuildWorldMinimap(w)

 screenlock

 'The tile palette
 BlueBox(0, 0, 16, 32)
 for t as Integer = 0 to 127
  put (world_pal_px + (t mod 8) * 16, world_pal_py + ((t \ 16) * 2 + (t mod 16) \ 8) * 16), world_tile_img(w, t), pset
 next
 DrawWorldCursor(world_pal_px + wv_pal_x * 16, world_pal_py + wv_pal_y * 16, 1, 1, not wv_map_active)

 'The map
 BlueBox(world_map_box_x, 0, world_view_cols * 2, world_view_rows * 2)
 for r as Integer = 0 to world_view_rows - 1
  for c as Integer = 0 to world_view_cols - 1
   if wv_view_y + r < world_size(w) and wv_view_x + c < world_size(w) then
    tile_number = world_tiles(w, wv_view_y + r, wv_view_x + c) and 127
    put (world_map_px + c * 16, world_map_py + r * 16), world_tile_img(w, tile_number), pset
   else
    line (world_map_px + c * 16, world_map_py + r * 16)-step(15, 15), RGB(0, 0, 0), bf
   end if
  next
 next
 view screen (world_map_px - 4, world_map_py - 4)-(world_map_px + world_view_cols * 16 + 3, world_map_py + world_view_rows * 16 + 3)
 DrawWorldOverlays()
 if wv_paste_mode then
  'preview of what Enter would place
  for y as Integer = 0 to world_clip_h - 1
   for x as Integer = 0 to world_clip_w - 1
    clip_x = wv_cursor_x + x - wv_view_x
    clip_y = wv_cursor_y + y - wv_view_y
    if clip_x >= 0 and clip_y >= 0 and clip_x < world_view_cols and clip_y < world_view_rows and wv_cursor_x + x < world_size(w) and wv_cursor_y + y < world_size(w) then
     put (world_map_px + clip_x * 16, world_map_py + clip_y * 16), world_tile_img(w, world_clip(y, x) and 127), alpha, 160
    end if
   next
  next
  DrawWorldCursor(world_map_px + (wv_cursor_x - wv_view_x) * 16, world_map_py + (wv_cursor_y - wv_view_y) * 16, min(world_clip_w, world_view_cols), min(world_clip_h, world_view_rows), true)
 else
  WorldSelectionRect(x0, y0, x1, y1)
  DrawWorldCursor(world_map_px + (x0 - wv_view_x) * 16, world_map_py + (y0 - wv_view_y) * 16, x1 - x0 + 1, y1 - y0 + 1, wv_map_active)
 end if
 view screen

 'The whole world
 BlueBox(0, world_mini_box_y, 16, 16)
 put (world_mini_px, world_mini_py), wv_minimap(w), pset
 box_x = world_mini_px + wv_view_x * 128 \ world_size(w)
 box_y = world_mini_py + wv_view_y * 128 \ world_size(w)
 box_w = min(world_view_cols, world_size(w)) * 128 \ world_size(w)
 box_h = min(world_view_rows, world_size(w)) * 128 \ world_size(w)
 line (box_x, box_y)-(box_x + box_w - 1, box_y + box_h - 1), RGB(255, 255, 0), b

 'The status box
 used = WorldDataBytes(w)
 WorldSelectionRect(x0, y0, x1, y1)
 status = "Panel:" + iif(wv_map_active, "Map", "Palette") + "  Tile:" + hex(wv_tile, 2) + "  Size:" + str(x1 - x0 + 1) + "x" + str(y1 - y0 + 1) + "  X " + str(wv_cursor_x) + " Y " + str(wv_cursor_y) + "  Overlay:" + WorldOverlayName()
 BlueBox(0, 52, 76, 3)
 WriteText(FF4Text(Pad(left(status, 58), 58)), 1, 53, 15)
 if used > world_capacity(w) then
  WriteText(FF4Text(Pad("Over by " + str(used - world_capacity(w)) + " bytes", 17, true)), 60, 53, 12)
 else
  WriteText(FF4Text(Pad("Room " + str(world_capacity(w) - used) + " bytes", 17, true)), 60, 53, 15)
 end if
 if wv_paste_mode then
  WriteText(FF4Text(Pad("PASTE: arrows move, Enter place, Esc cancel", 74)), 1, 54, 14)
 else
  WriteText(FF4Text(Pad("Tab panel  Enter place  Space fill  R replace  O overlay  Esc back", 74)), 1, 54, 15)
 end if
 tile_number = world_tiles(w, wv_cursor_y, wv_cursor_x) and 127
 info_line = ""
 if (wv_overlay and 1) <> 0 then info_line = WorldTriggerText(w, wv_cursor_x, wv_cursor_y)
 if info_line <> "" then
  if (wv_overlay and 2) <> 0 and WorldZoneArea(w, wv_cursor_x, wv_cursor_y) > 0 then info_line += ".  Enc " + str(encounter_tables(WorldZoneArea(w, wv_cursor_x, wv_cursor_y)))
  WriteText(FF4Text(Pad(left(info_line, 74), 74)), 1, 55, 14)
 else
  info_line = WorldNameText(w) + " " + hex(tile_number, 2) + ": " + WorldFlagsText(w, tile_number)
  if (wv_overlay and 2) <> 0 and WorldZoneArea(w, wv_cursor_x, wv_cursor_y) > 0 then info_line = "Enc " + str(encounter_tables(WorldZoneArea(w, wv_cursor_x, wv_cursor_y))) + ". " + info_line
  WriteText(FF4Text(Pad(left(info_line, 74), 74)), 1, 55, 10)
 end if

 screenunlock

end sub


sub WorldKeepCursorInView()

 dim limit as Integer = world_size(wv_world) - 1

 if wv_cursor_x < 0 then wv_cursor_x = 0
 if wv_cursor_y < 0 then wv_cursor_y = 0
 if wv_cursor_x > limit then wv_cursor_x = limit
 if wv_cursor_y > limit then wv_cursor_y = limit
 if wv_cursor_x < wv_view_x then wv_view_x = wv_cursor_x
 if wv_cursor_y < wv_view_y then wv_view_y = wv_cursor_y
 if wv_cursor_x >= wv_view_x + world_view_cols then wv_view_x = wv_cursor_x - world_view_cols + 1
 if wv_cursor_y >= wv_view_y + world_view_rows then wv_view_y = wv_cursor_y - world_view_rows + 1
 if wv_view_x + world_view_cols > world_size(wv_world) and world_size(wv_world) >= world_view_cols then wv_view_x = world_size(wv_world) - world_view_cols
 if wv_view_y + world_view_rows > world_size(wv_world) and world_size(wv_world) >= world_view_rows then wv_view_y = world_size(wv_world) - world_view_rows
 if wv_view_x < 0 then wv_view_x = 0
 if wv_view_y < 0 then wv_view_y = 0

end sub


sub WorldMoveCursor(key_code as UInteger, shift_held as Boolean, ctrl_held as Boolean)

 'Arrows and the corner keys move the cursor of whichever panel is active, like the map editor's grids:
 ' Home is the top left, End the bottom left, PgUp the top right, PgDn the bottom right. On the map,
 ' Shift selects a block and Ctrl jumps 16 tiles.

 dim last_x as Integer
 dim last_y as Integer
 dim step_size as Integer = 1

 if not wv_map_active then
  select case key_code
   case UP_KEY: if wv_pal_y > 0 then wv_pal_y -= 1
   case DOWN_KEY: if wv_pal_y < 15 then wv_pal_y += 1
   case LEFT_KEY: if wv_pal_x > 0 then wv_pal_x -= 1
   case RIGHT_KEY: if wv_pal_x < 7 then wv_pal_x += 1
   case HOME_KEY: wv_pal_x = 0: wv_pal_y = 0
   case END_KEY: wv_pal_x = 0: wv_pal_y = 15
   case PAGEUP_KEY: wv_pal_x = 7: wv_pal_y = 0
   case PAGEDOWN_KEY: wv_pal_x = 7: wv_pal_y = 15
  end select
  wv_tile = WorldPaletteTile()
  exit sub
 end if

 last_x = world_size(wv_world) - 1
 last_y = world_size(wv_world) - 1
 if shift_held and not wv_selecting and not wv_paste_mode then
  wv_selecting = true
  wv_anchor_x = wv_cursor_x
  wv_anchor_y = wv_cursor_y
 elseif not shift_held or wv_paste_mode then
  wv_selecting = false
 end if
 if ctrl_held then step_size = 16
 select case key_code
  case UP_KEY: wv_cursor_y -= step_size
  case DOWN_KEY: wv_cursor_y += step_size
  case LEFT_KEY: wv_cursor_x -= step_size
  case RIGHT_KEY: wv_cursor_x += step_size
  case HOME_KEY: wv_cursor_x = 0: wv_cursor_y = 0
  case END_KEY: wv_cursor_x = 0: wv_cursor_y = last_y
  case PAGEUP_KEY: wv_cursor_x = last_x: wv_cursor_y = 0
  case PAGEDOWN_KEY: wv_cursor_x = last_x: wv_cursor_y = last_y
 end select

end sub


sub WorldSwitchToMap()

 wv_map_active = true

end sub


sub EditOneWorld(w as Integer)

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
 dim shift_held as Boolean
 dim ctrl_held as Boolean
 dim painting as Boolean
 dim last_paint_x as Integer = -1
 dim last_paint_y as Integer = -1
 dim tile_x as Integer
 dim tile_y as Integer
 dim act_on_map as Boolean

 wv_world = w
 wv_view_x = 0
 wv_view_y = 0
 wv_cursor_x = world_size(w) \ 2
 wv_cursor_y = world_size(w) \ 2
 wv_selecting = false
 wv_paste_mode = false
 wv_map_active = true
 WorldPickTile(world_tiles(w, wv_cursor_y, wv_cursor_x) and 127)

 'Undo covers this visit to the world
 wu_ops = 0
 wu_cur = 0
 wu_cells = 0
 wu_op_start(0) = 0

 cls
 do
  if redraw then
   WorldKeepCursorInView()
   DrawWorldEditor()
   redraw = false
  end if

  key = inkey
  key_code = 0
  if key <> "" then
   key_code = asc(right(key, 1))
   if len(key) > 1 then key_code = key_code * &h100 + 255
  else
   PollMouse(cell_x, cell_y, left_click, right_click, wheel_steps)
   mx = mouse_pixel_x
   my = mouse_pixel_y
   if not mouse_left_held and painting then
    WorldEndOp()
    painting = false
    last_paint_x = -1
   end if
   tile_x = wv_view_x + (mx - world_map_px) \ 16
   tile_y = wv_view_y + (my - world_map_py) \ 16
   act_on_map = (mx >= world_map_px and my >= world_map_py and mx < world_map_px + world_view_cols * 16 and my < world_map_py + world_view_rows * 16 and tile_x < world_size(w) and tile_y < world_size(w))
   if right_click then
    if wv_paste_mode then
     key_code = ESC_KEY
    elseif act_on_map then
     WorldSwitchToMap()
     wv_selecting = false
     wv_cursor_x = tile_x
     wv_cursor_y = tile_y
     key_code = BACKSPACE_KEY
    end if
   elseif wheel_steps > 0 then
    key_code = UP_KEY
   elseif wheel_steps < 0 then
    key_code = DOWN_KEY
   elseif left_click and mx >= 0 then
    if act_on_map then
     WorldSwitchToMap()
     wv_selecting = false
     wv_cursor_x = tile_x
     wv_cursor_y = tile_y
     if wv_paste_mode then
      key_code = ENTER_KEY
     else
      WorldBeginOp()
      painting = true
      WorldSetTile(w, tile_x, tile_y, wv_tile)
      last_paint_x = tile_x
      last_paint_y = tile_y
      redraw = true
     end if
    elseif mx >= world_pal_px and my >= world_pal_py and mx < world_pal_px + 128 and my < world_pal_py + 256 then
     wv_pal_x = (mx - world_pal_px) \ 16
     wv_pal_y = (my - world_pal_py) \ 16
     wv_tile = WorldPaletteTile()
     redraw = true
    elseif mx >= world_mini_px and mx < world_mini_px + 128 and my >= world_mini_py and my < world_mini_py + 128 then
     wv_cursor_x = (mx - world_mini_px) * world_size(w) \ 128
     wv_cursor_y = (my - world_mini_py) * world_size(w) \ 128
     wv_view_x = wv_cursor_x - world_view_cols \ 2
     wv_view_y = wv_cursor_y - world_view_rows \ 2
     wv_selecting = false
     redraw = true
    end if
   elseif painting and mouse_left_held and act_on_map then
    if tile_x <> last_paint_x or tile_y <> last_paint_y then
     wv_cursor_x = tile_x
     wv_cursor_y = tile_y
     WorldSetTile(w, tile_x, tile_y, wv_tile)
     last_paint_x = tile_x
     last_paint_y = tile_y
     redraw = true
    end if
   end if
   if key_code = 0 and not redraw then sleep 10
  end if

  if key_code <> 0 then
   shift_held = multikey(SC_LSHIFT) or multikey(SC_RSHIFT)
   ctrl_held = multikey(SC_CONTROL)
   redraw = true
   if wv_paste_mode then
    select case key_code
     case ENTER_KEY
      WorldPasteAtCursor()
      wv_paste_mode = false
     case ESC_KEY
      wv_paste_mode = false
     case UP_KEY, DOWN_KEY, LEFT_KEY, RIGHT_KEY, HOME_KEY, END_KEY, PAGEUP_KEY, PAGEDOWN_KEY
      WorldMoveCursor(key_code, false, ctrl_held)
     case else
      redraw = false
    end select
   else
    select case key_code
     case ESC_KEY: done = true
     case UP_KEY, DOWN_KEY, LEFT_KEY, RIGHT_KEY, HOME_KEY, END_KEY, PAGEUP_KEY, PAGEDOWN_KEY
      WorldMoveCursor(key_code, shift_held, ctrl_held)
     case TAB_KEY
      wv_map_active = not wv_map_active
      wv_selecting = false
     case ENTER_KEY
      if wv_map_active then WorldPaintSelection()
     case BACKSPACE_KEY
      if wv_map_active then WorldPickTile(world_tiles(w, wv_cursor_y, wv_cursor_x) and 127)
     case SPACE_KEY
      if wv_map_active then WorldFill()
     case asc("r"), asc("R")
      if wv_map_active then WorldReplaceAll()
     case asc("o"), asc("O")
      wv_overlay = (wv_overlay + 3) mod 4
     case 3
      if wv_map_active then WorldCopySelection()
     case 22
      if wv_map_active and world_clip_w > 0 then
       wv_paste_mode = true
       wv_selecting = false
      end if
     case 26
      if not WorldUndo() then redraw = false
     case 25
      if not WorldRedo() then redraw = false
     case else
      redraw = false
    end select
   end if
  end if
 loop until done

 if painting then WorldEndOp()
 'End with a draw on the screen itself so no destroyed image stays the drawing target
 pset (0, 0), point(0, 0)
 cls

end sub


sub DrawWorldListPreview(w as Integer)

 dim used as Integer = WorldDataBytes(w)

 if wv_minimap_dirty(w) then BuildWorldMinimap(w)
 screenlock
 BlueBox(0, 8, 16, 16)
 put (8, 8 * 8 + 8), wv_minimap(w), pset
 line (20 * 8, 9 * 8)-(78 * 8, 24 * 8), RGB(0, 0, 0), bf
 WriteText(FF4Text(WorldNameText(w) + ", " + str(world_size(w)) + " by " + str(world_size(w)) + " tiles"), 20, 9, 14)
 if used > world_capacity(w) then
  WriteText(FF4Text("Map data " + str(used) + " of " + str(world_capacity(w)) + " bytes, over by " + str(used - world_capacity(w))), 20, 11, 12)
 else
  WriteText(FF4Text("Map data " + str(used) + " of " + str(world_capacity(w)) + " bytes, room " + str(world_capacity(w) - used)), 20, 11, 15)
 end if
 if WorldChanged(w) then WriteText(FF4Text("Edited since the ROM was loaded"), 20, 12, 10) else WriteText(FF4Text("Not edited"), 20, 12, 15)
 WriteText(FF4Text("Enter edits this world, Esc goes back"), 20, 14, 15)
 screenunlock

end sub


sub EditWorldMaps()

 'The list of worlds, like the list of maps; Enter opens the editor for the one selected

 dim select_world as BlueMenu

 if not world_loaded then ReadWorldMaps()
 for i as Integer = 0 to 2
  if not world_built(i) then BuildWorldTiles(i)
  BuildWorldMinimap(i)
 next

 select_world.AddOption(FF4Text("Overworld"))
 select_world.AddOption(FF4Text("Underground"))
 select_world.AddOption(FF4Text("Moon"))
 select_world.min_width = 16
 select_world.title = "Worlds"

 cls
 do
  do
   DrawWorldListPreview(select_world.selected - 1)
  loop until select_world.UserInput()
  if not select_world.cancelled then
   EditOneWorld(select_world.selected - 1)
   cls
  end if
 loop until select_world.cancelled

 'End with a draw on the screen itself so no destroyed image stays the drawing target
 pset (0, 0), point(0, 0)
 cls

end sub
