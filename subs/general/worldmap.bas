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
const world_view_cols = 32
const world_view_rows = 22
const world_panel_x = 512
const world_picker_y = 352

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

sub DrawWorldView()

 dim w as Integer = wv_world
 dim tile_number as Integer
 dim screen_x as Integer
 dim screen_y as Integer
 dim passability as Integer
 dim extra as Integer
 dim row as Integer
 dim box_x as Integer
 dim box_y as Integer
 dim box_w as Integer
 dim box_h as Integer
 dim x0 as Integer
 dim y0 as Integer
 dim x1 as Integer
 dim y1 as Integer
 dim used as Integer
 dim names(7) as String = {"Walk", "Chocobo", "Black choc fly", "Black choc land", "Hovercraft", "Airship flies", "Walk upper", "Whale flies"}

 if wv_minimap_dirty(w) then BuildWorldMinimap(w)

 screenlock

 for r as Integer = 0 to world_view_rows - 1
  for c as Integer = 0 to world_view_cols - 1
   if wv_view_y + r < world_size(w) and wv_view_x + c < world_size(w) then
    tile_number = world_tiles(w, wv_view_y + r, wv_view_x + c) and 127
    put (c * 16, r * 16), world_tile_img(w, tile_number), pset
   else
    line (c * 16, r * 16)-(c * 16 + 15, r * 16 + 15), RGB(0, 0, 0), bf
   end if
  next
 next

 'The selection (or the cursor)
 WorldSelectionRect(x0, y0, x1, y1)
 screen_x = (x0 - wv_view_x) * 16
 screen_y = (y0 - wv_view_y) * 16
 line (screen_x, screen_y)-(screen_x + (x1 - x0 + 1) * 16 - 1, screen_y + (y1 - y0 + 1) * 16 - 1), RGB(255, 255, 255), b
 line (screen_x + 1, screen_y + 1)-(screen_x + (x1 - x0 + 1) * 16 - 2, screen_y + (y1 - y0 + 1) * 16 - 2), RGB(0, 0, 0), b

 'The tile picker and the area beside it
 line (0, world_picker_y)-(world_panel_x - 1, 479), RGB(0, 0, 96), bf
 for t as Integer = 0 to 127
  put ((t mod 16) * 16, world_picker_y + (t \ 16) * 16), world_tile_img(w, t), pset
 next
 screen_x = (wv_tile mod 16) * 16
 screen_y = world_picker_y + (wv_tile \ 16) * 16
 line (screen_x, screen_y)-(screen_x + 15, screen_y + 15), RGB(255, 255, 255), b
 line (screen_x + 1, screen_y + 1)-(screen_x + 14, screen_y + 14), RGB(0, 0, 0), b

 WriteText(FF4Text("Tile " + hex(wv_tile, 2) + " chosen"), 33, 44, 14)
 WriteText(FF4Text("Enter paints  Bksp picks"), 33, 46, 15)
 WriteText(FF4Text("Space fills  R replaces all"), 33, 47, 15)
 WriteText(FF4Text("Shift arrows select a block"), 33, 48, 15)
 WriteText(FF4Text("Ctrl C V copy paste"), 33, 49, 15)
 WriteText(FF4Text("Ctrl Z Y undo redo"), 33, 50, 15)
 WriteText(FF4Text("Comma Period pick tile"), 33, 51, 15)
 WriteText(FF4Text("Click paints  Right picks"), 33, 52, 15)
 used = WorldDataBytes(w)
 if used > world_capacity(w) then
  WriteText(FF4Text("OVER by " + str(used - world_capacity(w)) + " bytes"), 33, 55, 12)
 else
  WriteText(FF4Text("Data " + str(used) + " of " + str(world_capacity(w))), 33, 55, 15)
 end if
 if WorldChanged(w) then WriteText(FF4Text("Changed"), 33, 56, 10) else WriteText(FF4Text("Unchanged"), 33, 56, 15)

 'The side panel
 line (world_panel_x, 0)-(639, 479), RGB(0, 0, 96), bf
 put (world_panel_x + 8, 8), wv_minimap(w), pset
 box_x = world_panel_x + 8 + wv_view_x * 128 \ world_size(w)
 box_y = 8 + wv_view_y * 128 \ world_size(w)
 box_w = min(world_view_cols, world_size(w)) * 128 \ world_size(w)
 box_h = min(world_view_rows, world_size(w)) * 128 \ world_size(w)
 line (box_x, box_y)-(box_x + box_w - 1, box_y + box_h - 1), RGB(255, 255, 0), b

 WriteText(FF4Text(WorldNameText(w)), 65, 18, 14)
 WriteText(FF4Text("X " + str(wv_cursor_x) + " Y " + str(wv_cursor_y)), 65, 19, 15)
 tile_number = world_tiles(w, wv_cursor_y, wv_cursor_x) and 127
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

 WriteText(FF4Text("Arrows move"), 65, 49, 15)
 WriteText(FF4Text("PgUp PgDn jump"), 65, 50, 15)
 WriteText(FF4Text("Home End jump"), 65, 51, 15)
 WriteText(FF4Text("Tab next world"), 65, 52, 15)
 WriteText(FF4Text("Click the map"), 65, 53, 15)
 WriteText(FF4Text("to jump there"), 65, 54, 15)
 WriteText(FF4Text("Esc leaves"), 65, 55, 15)

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


sub EditWorldMaps()

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
 dim painting as Boolean
 dim last_paint_x as Integer = -1
 dim last_paint_y as Integer = -1
 dim tile_x as Integer
 dim tile_y as Integer

 if not world_loaded then ReadWorldMaps()
 for i as Integer = 0 to 2
  if not world_built(i) then BuildWorldTiles(i)
  BuildWorldMinimap(i)
 next

 'Undo only covers this visit
 wu_ops = 0
 wu_cur = 0
 wu_cells = 0
 wu_op_start(0) = 0
 wv_selecting = false

 cls
 do
  if redraw then
   WorldKeepCursorInView()
   DrawWorldView()
   redraw = false
  end if

  key = inkey
  if key <> "" then
   key_code = asc(right(key, 1))
   if len(key) > 1 then key_code = key_code * &h100 + 255
   shift_held = multikey(SC_LSHIFT) or multikey(SC_RSHIFT)
   redraw = true
   select case key_code
    case ESC_KEY: done = true
    case UP_KEY, DOWN_KEY, LEFT_KEY, RIGHT_KEY, PAGEUP_KEY, PAGEDOWN_KEY, HOME_KEY, END_KEY
     if shift_held and not wv_selecting then
      wv_selecting = true
      wv_anchor_x = wv_cursor_x
      wv_anchor_y = wv_cursor_y
     elseif not shift_held then
      wv_selecting = false
     end if
     select case key_code
      case UP_KEY: wv_cursor_y -= 1
      case DOWN_KEY: wv_cursor_y += 1
      case LEFT_KEY: wv_cursor_x -= 1
      case RIGHT_KEY: wv_cursor_x += 1
      case PAGEUP_KEY: wv_cursor_y -= 16
      case PAGEDOWN_KEY: wv_cursor_y += 16
      case HOME_KEY: wv_cursor_x -= 16
      case END_KEY: wv_cursor_x += 16
     end select
    case TAB_KEY
     wv_world = (wv_world + 1) mod world_count
     wv_view_x = 0
     wv_view_y = 0
     wv_cursor_x = world_size(wv_world) \ 2
     wv_cursor_y = world_size(wv_world) \ 2
     wv_selecting = false
    case ENTER_KEY: WorldPaintSelection()
    case BACKSPACE_KEY: wv_tile = world_tiles(wv_world, wv_cursor_y, wv_cursor_x) and 127
    case SPACE_KEY: WorldFill()
    case asc("r"), asc("R"): WorldReplaceAll()
    case asc(","): wv_tile = (wv_tile + 127) mod 128
    case asc("."): wv_tile = (wv_tile + 1) mod 128
    case asc("["): wv_tile = (wv_tile + 112) mod 128
    case asc("]"): wv_tile = (wv_tile + 16) mod 128
    case 3: WorldCopySelection()
    case 22: WorldPasteAtCursor()
    case 26: if not WorldUndo() then redraw = false
    case 25: if not WorldRedo() then redraw = false
    case else: redraw = false
   end select
  else
   PollMouse(cell_x, cell_y, left_click, right_click, wheel_steps)
   mx = mouse_pixel_x
   my = mouse_pixel_y
   if not mouse_left_held and painting then
    WorldEndOp()
    painting = false
    last_paint_x = -1
   end if
   if right_click then
    if mx >= 0 and mx < world_view_cols * 16 and my < world_view_rows * 16 then
     tile_x = wv_view_x + mx \ 16
     tile_y = wv_view_y + my \ 16
     if tile_x < world_size(wv_world) and tile_y < world_size(wv_world) then
      wv_tile = world_tiles(wv_world, tile_y, tile_x) and 127
      redraw = true
     end if
    end if
   elseif wheel_steps <> 0 then
    wv_cursor_y -= sgn(wheel_steps) * 3
    wv_selecting = false
    redraw = true
   elseif left_click and mx >= 0 then
    if mx < world_view_cols * 16 and my < world_view_rows * 16 then
     tile_x = wv_view_x + mx \ 16
     tile_y = wv_view_y + my \ 16
     if tile_x < world_size(wv_world) and tile_y < world_size(wv_world) then
      wv_cursor_x = tile_x
      wv_cursor_y = tile_y
      wv_selecting = false
      WorldBeginOp()
      painting = true
      WorldSetTile(wv_world, tile_x, tile_y, wv_tile)
      last_paint_x = tile_x
      last_paint_y = tile_y
      redraw = true
     end if
    elseif mx < 256 and my >= world_picker_y and my < world_picker_y + 128 then
     wv_tile = ((my - world_picker_y) \ 16) * 16 + mx \ 16
     redraw = true
    elseif mx >= world_panel_x + 8 and mx < world_panel_x + 136 and my >= 8 and my < 136 then
     wv_cursor_x = (mx - world_panel_x - 8) * world_size(wv_world) \ 128
     wv_cursor_y = (my - 8) * world_size(wv_world) \ 128
     wv_view_x = wv_cursor_x - world_view_cols \ 2
     wv_view_y = wv_cursor_y - world_view_rows \ 2
     wv_selecting = false
     redraw = true
    end if
   elseif painting and mouse_left_held and mx >= 0 and mx < world_view_cols * 16 and my < world_view_rows * 16 then
    tile_x = wv_view_x + mx \ 16
    tile_y = wv_view_y + my \ 16
    if (tile_x <> last_paint_x or tile_y <> last_paint_y) and tile_x < world_size(wv_world) and tile_y < world_size(wv_world) then
     wv_cursor_x = tile_x
     wv_cursor_y = tile_y
     WorldSetTile(wv_world, tile_x, tile_y, wv_tile)
     last_paint_x = tile_x
     last_paint_y = tile_y
     redraw = true
    end if
   end if
   if not redraw then sleep 10
  end if
 loop until done

 if painting then WorldEndOp()
 'End with a draw on the screen itself so no destroyed image stays the drawing target
 pset (0, 0), point(0, 0)
 cls

end sub
