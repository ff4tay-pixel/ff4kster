'Spell animation preview: plays the "sequence" part of a spell's animation (the sprite script
'that the spell's Sequence field points at) in a panel on the Spells screen.
'
'A spell's four animation bytes (AnimProp, 4 bytes each) are: palette, graphics, sequence (script),
'effect. The effect is a routine in the game's code (screen shakes, flashes, projectiles flying
'across the screen), so it is not shown. Only the sequence is played, centered in the panel.
'
'  graphics   A window of 128 tiles of the tile map (16 tiles wide), starting at tile row 2 * id.
'             Each map entry is a 14 bit number into the 3bpp animation tile graphics plus flip bits.
'  palette    8 colors; color 0 is transparent.
'  script     byte 0: frame size id (high nibble) and repeat count - 1 (low nibble)
'             byte 1: bit 7 = don't mirror, bits 3-4 = speed, bits 0-2 = frame group
'             then commands until FF: 00-7F show frame, 88 xx palette effect (ignored),
'             other commands with bit 3 set are palette effects (ignored),
'             the rest move the sprite: bits 4-6 = direction, bits 0-2 = distance - 1
'  frame      a grid of 16x16 sprites (width x height from the size table), row by row: 00-1E is a
'             sprite number (bit 5 = h-flip, bit 6 = v-flip), 1F is empty, and a byte with bit 7 set
'             is followed by a count and repeats that sprite. FF ends the frame.
'
'ff4rom always carries a 0x200 byte header, so every ROM offset below includes it.

const sa_gfx = &h638C0 'AnimGfx: 3bpp tiles, 24 bytes each (0c/b6c0)
const sa_tilemap = &h675C0 'AnimTiles: 16 bit entries (0c/f3c0)
const sa_palettes = &h74D00 'AnimPal: 8 colors, 16 bytes each (0e/cb00)
const sa_script_ptrs = &h7D7E0 'AnimScriptPtrs (0f/d5e0)
const sa_frame_ptrs = &h7DFE0 'AnimFramePtrs (0f/dde0)
const sa_size_table = &h7013E 'frame sizes, 2 bytes each: width, height in sprites
const sa_speed_table = &h701D9 'tick mask for each of the four speeds
const sa_bank_0f = &h70200 'add to a bank 0f pointer (8000-FFFF) to get the ROM offset

const sa_script_count = 79
const sa_frame_count = 361
const sa_max_ticks = 4096
const sa_hold_ticks = 40 'pause on the last frame before looping

'Panel position (in text cells): a box with a caption row and the stage below it. It sits to the
'right of the Spells screen's menus, below the Effect and Sequence boxes.
const sa_box_x = 45
const sa_box_y = 23
const sa_box_w = 32
const sa_box_h = 25
const sa_stage_px = 46 * 8
const sa_stage_py = 25 * 8
const sa_stage_area_w = 256
const sa_stage_area_h = 192

dim shared sa_enabled as Boolean
dim shared sa_valid as Boolean
dim shared sa_palette_id as Integer = -1
dim shared sa_gfx_id as Integer = -1
dim shared sa_script_id as Integer = -1
dim shared sa_effect_id as Integer = -1
dim shared sa_tiles(127, 7, 7) as UByte
dim shared sa_colors(7) as UInteger
dim shared sa_cells_w as Integer
dim shared sa_cells_h as Integer
dim shared sa_group as Integer
dim shared sa_mirror as Boolean
dim shared sa_ticks as Integer
dim shared sa_tick_frame(sa_max_ticks - 1) as UByte
dim shared sa_tick_x(sa_max_ticks - 1) as Short
dim shared sa_tick_y(sa_max_ticks - 1) as Short
dim shared sa_frame_images(127) as Any ptr
dim shared sa_stage as Any ptr
dim shared sa_scaled as Any ptr
dim shared sa_stage_w as Integer
dim shared sa_stage_h as Integer
dim shared sa_zoom as Integer
dim shared sa_start as Double
dim shared sa_last_tick as Integer = -1


sub SaFreeImages()

 for i as Integer = 0 to 127
  if sa_frame_images(i) <> 0 then
   ImageDestroy(sa_frame_images(i))
   sa_frame_images(i) = 0
  end if
 next
 if sa_stage <> 0 then
  ImageDestroy(sa_stage)
  sa_stage = 0
 end if
 if sa_scaled <> 0 then
  ImageDestroy(sa_scaled)
  sa_scaled = 0
 end if

end sub


function SaWord(offset as Integer) as Integer

 return ByteAt(offset) + ByteAt(offset + 1) * &h100

end function


sub SaLoadTiles(gfx as Integer)

 'Decodes the 128 tiles of a graphics set (fewer for the last three sets) into sa_tiles

 dim entry as Integer
 dim tile_number as Integer
 dim start as Integer
 dim p0 as UByte
 dim p1 as UByte
 dim p2 as UByte
 dim count as Integer = 128
 dim sx as Integer
 dim sy as Integer

 select case gfx
  case &h15: count = &h60
  case &h16: count = &h40
  case &h17: count = &h20
 end select

 for k as Integer = 0 to 127
  for y as Integer = 0 to 7
   for x as Integer = 0 to 7
    sa_tiles(k, y, x) = 0
   next
  next
  if k < count then
   entry = SaWord(sa_tilemap + (gfx * 32 + k) * 2)
   tile_number = entry and &h3FFF
   start = sa_gfx + tile_number * 24
   if start + 24 <= len(ff4rom) then
    for y as Integer = 0 to 7
     p0 = ByteAt(start + y * 2)
     p1 = ByteAt(start + y * 2 + 1)
     p2 = ByteAt(start + 16 + y)
     for x as Integer = 0 to 7
      sy = y
      sx = x
      if entry and &h4000 then sx = 7 - x
      if entry and &h8000 then sy = 7 - y
      sa_tiles(k, sy, sx) = ((p0 shr (7 - x)) and 1) or (((p1 shr (7 - x)) and 1) shl 1) or (((p2 shr (7 - x)) and 1) shl 2)
     next
    next
   end if
  end if
 next

end sub


function SaBuildTimeline(script as Integer) as Boolean

 'Plays the script on paper: one entry per 60 Hz tick with the frame to show and how far the
 ' sprite has moved. Returns false if the script can't be read.

 dim ptr_value as Integer
 dim start as Integer
 dim b0 as Integer
 dim b1 as Integer
 dim size_id as Integer
 dim repeats as Integer
 dim mask as Integer
 dim cmd as Integer
 dim position as Integer
 dim tick as Integer
 dim move_x as Integer
 dim move_y as Integer
 dim dir_index as Integer
 dim distance as Integer
 dim dx as Integer
 dim dy as Integer
 dim script_commands(511) as UByte
 dim command_count as Integer
 dim mirror_dir(7) as Integer = {2, 1, 0, 4, 3, 7, 6, 5}
 dim dir_x(7) as Integer = {-1, 0, 1, -1, 1, -1, 0, 1}
 dim dir_y(7) as Integer = {1, 1, 1, 0, 0, -1, -1, -1}

 if script < 0 or script >= sa_script_count then return false
 ptr_value = SaWord(sa_script_ptrs + script * 2)
 if ptr_value < &h8000 then return false
 start = ptr_value + sa_bank_0f

 b0 = ByteAt(start)
 b1 = ByteAt(start + 1)
 size_id = b0 \ 16
 repeats = (b0 and 15) + 1
 mask = ByteAt(sa_speed_table + ((b1 shr 3) and 3))
 sa_cells_w = ByteAt(sa_size_table + size_id * 2)
 sa_cells_h = ByteAt(sa_size_table + size_id * 2 + 1)
 sa_group = b1 and 7
 sa_mirror = ((b1 and &h80) = 0)

 position = start + 2
 do
  cmd = ByteAt(position)
  if cmd = &hFF then exit do
  script_commands(command_count) = cmd
  command_count += 1
  if cmd = &h88 then
   position += 2
   script_commands(command_count) = &h88 'placeholder for the ignored parameter
   command_count += 1
  else
   position += 1
  end if
  if command_count > 500 then return false
 loop

 for pass as Integer = 1 to repeats
  position = 0
  do while position < command_count
   cmd = script_commands(position)
   if cmd < &h80 then
    do
     if tick >= sa_max_ticks then
      sa_ticks = tick
      return true
     end if
     tick += 1
     sa_tick_frame(tick - 1) = cmd
     sa_tick_x(tick - 1) = move_x
     sa_tick_y(tick - 1) = move_y
     if (tick and mask) = 0 then exit do
    loop
    position += 1
   elseif cmd = &h88 then
    position += 2
   elseif (cmd and 8) <> 0 then
    position += 1
   else
    dir_index = (cmd shr 4) and 7
    distance = (cmd and 7) + 1
    if sa_mirror then dir_index = mirror_dir(dir_index)
    move_x += dir_x(dir_index) * distance
    move_y += dir_y(dir_index) * distance
    position += 1
   end if
  loop

  'The game spends one more tick between passes, still showing the last frame
  if pass < repeats and tick > 0 and tick < sa_max_ticks then
   tick += 1
   sa_tick_frame(tick - 1) = sa_tick_frame(tick - 2)
   sa_tick_x(tick - 1) = sa_tick_x(tick - 2)
   sa_tick_y(tick - 1) = sa_tick_y(tick - 2)
  end if
 next

 sa_ticks = tick

 return (tick > 0)

end function


function SaFrameImage(frame as Integer) as Any ptr

 'Builds (once) the picture of one frame: a grid of 16x16 sprites

 dim image as Any ptr
 dim frame_index as Integer
 dim ptr_value as Integer
 dim position as Integer
 dim cells(511) as UByte
 dim cell_count as Integer
 dim total as Integer
 dim b as Integer
 dim repeat_count as Integer
 dim sprite as Integer
 dim hflip as Boolean
 dim vflip as Boolean
 dim cx as Integer
 dim cy as Integer
 dim base_tile as Integer
 dim sx as Integer
 dim sy as Integer
 dim v as Integer

 if sa_frame_images(frame) <> 0 then return sa_frame_images(frame)

 total = sa_cells_w * sa_cells_h
 image = ImageCreate(sa_cells_w * 16, sa_cells_h * 16, RGB(255, 0, 255))

 frame_index = sa_group * 128 + frame
 if frame_index < sa_frame_count and total <= 512 then
  ptr_value = SaWord(sa_frame_ptrs + frame_index * 2)
  if ptr_value >= &h8000 then
   position = ptr_value + sa_bank_0f
   do while cell_count < total
    b = ByteAt(position)
    if b = &hFF then
     exit do
    elseif b < &h80 then
     cells(cell_count) = b
     cell_count += 1
     position += 1
    else
     repeat_count = ByteAt(position + 1)
     if repeat_count = 0 then repeat_count = 256
     for r as Integer = 1 to repeat_count
      if cell_count < total then
       cells(cell_count) = b
       cell_count += 1
      end if
     next
     position += 2
    end if
   loop
  end if
 end if

 for n as Integer = 0 to cell_count - 1
  sprite = cells(n) and &h1F
  if sprite <> &h1F then
   hflip = ((cells(n) and &h20) <> 0)
   vflip = ((cells(n) and &h40) <> 0)
   cy = (n \ sa_cells_w) * 16
   cx = (n mod sa_cells_w) * 16
   if sa_mirror then
    cx = (sa_cells_w - 1 - (n mod sa_cells_w)) * 16
    hflip = not hflip
   end if
   base_tile = (sprite \ 8) * 32 + (sprite mod 8) * 2
   for y as Integer = 0 to 15
    for x as Integer = 0 to 15
     sx = iif(hflip, 15 - x, x)
     sy = iif(vflip, 15 - y, y)
     v = sa_tiles(base_tile + (sy \ 8) * 16 + sx \ 8, sy mod 8, sx mod 8)
     if v <> 0 then pset image, (cx + x, cy + y), sa_colors(v)
    next
   next
  end if
 next

 sa_frame_images(frame) = image

 return image

end function


sub SaDrawBox()

 dim caption as String

 BlueBox(sa_box_x, sa_box_y, sa_box_w, sa_box_h)
 if sa_effect_id > 0 and sa_effect_id <> &hFF then caption = "Sequence only, effect not shown" else caption = "Sequence preview"
 WriteText(FF4Text(Pad(caption, sa_box_w)), sa_box_x + 1, sa_box_y + 1, 15)

end sub


sub SaDrawTick(n as Integer)

 dim image as Any ptr
 dim x as Integer
 dim y as Integer
 dim src_row as ULong ptr
 dim dst_row as ULong ptr
 dim src_pixels as Any ptr
 dim dst_pixels as Any ptr
 dim src_pitch as Integer
 dim dst_pitch as Integer
 dim color_value as ULong

 line sa_stage, (0, 0)-(sa_stage_w - 1, sa_stage_h - 1), RGB(16, 16, 32), bf

 image = SaFrameImage(sa_tick_frame(n))
 x = sa_stage_w \ 2 + sa_tick_x(n) - sa_cells_w * 8
 y = sa_stage_h \ 2 + sa_tick_y(n) - sa_cells_h * 8
 put sa_stage, (x, y), image, trans

 imageinfo sa_stage, , , , src_pitch, src_pixels
 imageinfo sa_scaled, , , , dst_pitch, dst_pixels
 for sy as Integer = 0 to sa_stage_h - 1
  src_row = cast(ULong ptr, src_pixels + sy * src_pitch)
  for zy as Integer = 0 to sa_zoom - 1
   dst_row = cast(ULong ptr, dst_pixels + (sy * sa_zoom + zy) * dst_pitch)
   for sx as Integer = 0 to sa_stage_w - 1
    color_value = src_row[sx]
    for zx as Integer = 0 to sa_zoom - 1
     dst_row[sx * sa_zoom + zx] = color_value
    next
   next
  next
 next

 put (sa_stage_px, sa_stage_py), sa_scaled, pset

end sub


sub SpellAnimShow()

 'Draws the panel (box, caption and the first frame) for the animation that is loaded

 dim blank as Any ptr

 SaDrawBox()

 if sa_valid then
  SaDrawTick(0)
 else
  blank = ImageCreate(sa_stage_area_w, sa_stage_area_h, RGB(16, 16, 32))
  put (sa_stage_px, sa_stage_py), blank, pset
  ImageDestroy(blank)
  if sa_effect_id > 0 and sa_effect_id <> &hFF then
   WriteText(FF4Text("Nothing to show: this animation"), sa_box_x + 2, sa_box_y + 11, 7)
   WriteText(FF4Text("is drawn by its effect"), sa_box_x + 6, sa_box_y + 13, 7)
  else
   WriteText(FF4Text("No animation"), sa_box_x + 11, sa_box_y + 12, 7)
  end if
 end if

end sub


sub SpellAnimSet(palette_id as Integer, gfx_id as Integer, script_id as Integer, effect_id as Integer)

 'Loads the animation described by a spell's four animation bytes and starts playing it.
 ' Does nothing if it is already the loaded animation.

 dim v as Integer

 if sa_enabled and palette_id = sa_palette_id and gfx_id = sa_gfx_id and script_id = sa_script_id and effect_id = sa_effect_id then exit sub

 sa_enabled = true
 sa_palette_id = palette_id
 sa_gfx_id = gfx_id
 sa_script_id = script_id
 sa_effect_id = effect_id
 SaFreeImages()
 sa_valid = false
 sa_ticks = 0

 if script_id >= 0 and script_id < sa_script_count and gfx_id >= 0 and gfx_id <= &h17 and palette_id >= 0 and palette_id < 64 then
  for i as Integer = 0 to 7
   v = SaWord(sa_palettes + palette_id * 16 + i * 2)
   sa_colors(i) = RGB((v and 31) * 8, ((v shr 5) and 31) * 8, ((v shr 10) and 31) * 8)
  next
  if SaBuildTimeline(script_id) then
   SaLoadTiles(gfx_id)
   if sa_cells_w * 16 > 128 or sa_cells_h * 16 > 96 then sa_zoom = 1 else sa_zoom = 2
   sa_stage_w = sa_stage_area_w \ sa_zoom
   sa_stage_h = sa_stage_area_h \ sa_zoom
   sa_stage = ImageCreate(sa_stage_w, sa_stage_h)
   sa_scaled = ImageCreate(sa_stage_w * sa_zoom, sa_stage_h * sa_zoom)
   sa_valid = true
  end if
 end if

 sa_start = timer
 sa_last_tick = 0
 SpellAnimShow()

end sub


sub SpellAnimTick()

 'Called while a menu is waiting for a key: moves the animation on to the current tick

 dim n as Integer

 if not sa_enabled or not sa_valid then exit sub

 n = int((timer - sa_start) * 60) mod (sa_ticks + sa_hold_ticks)
 if n >= sa_ticks then n = sa_ticks - 1
 if n = sa_last_tick then exit sub

 SaDrawTick(n)
 sa_last_tick = n

end sub


sub SpellAnimClose()

 SaFreeImages()
 sa_enabled = false
 sa_valid = false
 sa_palette_id = -1
 sa_gfx_id = -1
 sa_script_id = -1
 sa_effect_id = -1

end sub
