'Export and import of battle character sprites and palettes.
'
'Each character is one 4 bits per pixel BMP, exports\battle_sprites\poses_NN_pal_PP.bmp (112x48). The palette is
'the BMP's own color table: entry N is palette color N and a pixel's value is its palette index. The
'palette number PP is kept in the file name. (Older 113x48 files, with the palette as the 16 pixels in
'the top right corner, are still read.) The poses are packed with no gaps:
'
'    row 1 (7 poses of 16x24):  Standing, Ready, Running, Kneeling, Right arm up, Left arm down,
'                               Left arm up
'    row 2:  Hit (x 0), Victory (16), Dead (32, 24 wide), Chant 1 (56), Chant 2 (72),
'            Special (88, 24 wide). The tile no pose uses sits in Special's empty bottom left corner.
'
'On import the color table defines palette PP and the pixels keep their values, so an image editor must
'not renumber the colors (the palette editor can reorder them: bracket keys). A pixel above color 15
'is rejected. For an older file with palette pixels, every other pixel takes the index of the palette
'pixel with the same color and a pixel of any other color is rejected.
'
'Poses share tiles (the head tiles are used by five poses). If the same tile was edited
'differently in two poses, the first pose (in list order) wins and the import says so.

const image_strip = 1 'columns on the right that hold the palette pixels (monster images, and older pose images)
const pose_image_width = 112 'the palette is the BMP's own color table
const pose_image_height = 48
const extra_tile_x = 88 'where the tile that no pose uses is placed (at most one)
const extra_tile_y = 40
const max_extra_tiles = 1
const max_pose_uses = 12
const special_pose_id = &h24 'the Golbez-style special pose, which no normal pose shares tiles with
const image_pose_count = 13 'poses 0-11 and the special pose

dim shared bmp_px(191, 191) as UByte 'scratch image, row then column (big enough for the largest monster)
dim shared bmp_table(255) as UInteger 'color table of the BMP last read, as RGB
dim shared bmp_table_count as Integer


function BattlePoseName(pose as Integer) as String

 select case pose
  case 0: return "Standing"
  case 1: return "Ready"
  case 2: return "Running"
  case 3: return "Kneeling"
  case 4: return "Right arm up"
  case 5: return "Left arm down"
  case 6: return "Left arm up"
  case 7: return "Hit"
  case 8: return "Victory"
  case 9: return "Dead"
  case 10: return "Chant 1"
  case 11: return "Chant 2"
  case special_pose_id: return "Special"
 end select

 return ""

end function


function BattleSpritePath(file_name as String) as String

 mkdir system_path + "\exports"
 mkdir system_path + "\exports\battle_sprites"

 return system_path + "\exports\battle_sprites\" + file_name

end function


function BmpU16Text(v as Integer) as String

 return chr(v and 255) + chr((v shr 8) and 255)

end function


function BmpU32Text(v as LongInt) as String

 return chr(v and 255) + chr((v shr 8) and 255) + chr((v shr 16) and 255) + chr((v shr 24) and 255)

end function


function BmpU32(s as String, p as Integer) as LongInt

 return asc(mid(s, p, 1)) + asc(mid(s, p + 1, 1)) * &h100 + asc(mid(s, p + 2, 1)) * &h10000 + cast(LongInt, asc(mid(s, p + 3, 1))) * &h1000000

end function


function BmpS32(s as String, p as Integer) as LongInt

 dim v as LongInt = BmpU32(s, p)

 if v >= &h80000000ll then v -= &h100000000ll
 return v

end function


sub PutPaletteSwatches(width_px as Integer)

 'The top right 16 pixels of the image, top to bottom, show palette colors 0-15

 for i as Integer = 0 to 15
  bmp_px(i, width_px - 1) = i
 next

end sub


function WriteIndexedBMPColors(path as String, width_px as Integer, height_px as Integer, colors() as UInteger) as Boolean

 'Writes the top left width_px x height_px part of bmp_px as a 4 bits per pixel BMP
 ' whose color table is colors(0 to 15), each a 15 bit SNES color.

 dim bmp_data as String
 dim v as UInteger
 dim f as Integer = freefile
 dim row_bytes as Integer = ((width_px * 4 + 31) \ 32) * 4 'BMP rows are padded to 4 bytes
 dim pad_bytes as Integer = row_bytes - (width_px + 1) \ 2
 dim data_size as Integer = row_bytes * height_px

 bmp_data = "BM" + BmpU32Text(118 + data_size) + BmpU32Text(0) + BmpU32Text(118)
 bmp_data += BmpU32Text(40) + BmpU32Text(width_px) + BmpU32Text(height_px) + BmpU16Text(1) + BmpU16Text(4)
 bmp_data += BmpU32Text(0) + BmpU32Text(data_size) + BmpU32Text(2835) + BmpU32Text(2835) + BmpU32Text(16) + BmpU32Text(16)

 for i as Integer = 0 to 15
  v = colors(i)
  bmp_data += chr(((v \ 1024) mod 32) * 8) + chr(((v \ 32) mod 32) * 8) + chr((v mod 32) * 8) + chr(0)
 next

 for y as Integer = height_px - 1 to 0 step -1
  for x as Integer = 0 to width_px - 2 step 2
   bmp_data += chr(bmp_px(y, x) * 16 + bmp_px(y, x + 1))
  next
  if width_px mod 2 = 1 then bmp_data += chr(bmp_px(y, width_px - 1) * 16)
  if pad_bytes > 0 then bmp_data += string(pad_bytes, chr(0))
 next

 if len(dir(path)) > 0 then kill path
 if open(path for binary access write as #f) <> 0 then return false
 put #f, , bmp_data
 close #f

 return true

end function


function WriteIndexedBMP(path as String, width_px as Integer, height_px as Integer, pal as Integer) as Boolean

 'Same, with battle palette pal as the color table.

 dim colors(15) as UInteger

 for i as Integer = 0 to 15
  colors(i) = battle_palette_raw(pal, i)
 next

 return WriteIndexedBMPColors(path, width_px, height_px, colors())

end function


function ReadIndexedBMP(path as String, width_px as Integer, height_px as Integer, byref problem as String) as Boolean

 'Reads a 4 or 8 bits per pixel BMP of exactly width_px x height_px into bmp_px (raw color table
 ' indices) and its color table into bmp_table. Then ResolveSwatchPalette must be called.

 dim f as Integer = freefile
 dim raw as String
 dim data_offset as Integer
 dim header_size as Integer
 dim file_width as LongInt
 dim file_height as LongInt
 dim bpp as Integer
 dim colors_used as Integer
 dim table_start as Integer
 dim row_bytes as Integer
 dim file_row as Integer
 dim index as Integer
 
 if open(path for binary access read as #f) <> 0 then
  problem = "cannot open"
  return false
 end if
 raw = string(lof(f), 0)
 if lof(f) > 0 then get #f, , raw
 close #f
 
 if len(raw) < 54 orelse left(raw, 2) <> "BM" then
  problem = "not a BMP file"
  return false
 end if
 
 data_offset = BmpU32(raw, 11)
 header_size = BmpU32(raw, 15)
 file_width = BmpS32(raw, 19)
 file_height = BmpS32(raw, 23)
 bpp = asc(mid(raw, 29, 1)) + asc(mid(raw, 30, 1)) * &h100
 
 if header_size < 40 then
  problem = "unsupported BMP header"
  return false
 end if
 if BmpU32(raw, 31) <> 0 then
  problem = "compressed BMP (save it uncompressed)"
  return false
 end if
 if bpp <> 4 and bpp <> 8 then
  problem = "needs an indexed image (4 or 8 bits per pixel), not " + str(bpp)
  return false
 end if
 if file_width <> width_px or abs(file_height) <> height_px then
  problem = "must be " + str(width_px) + "x" + str(height_px) + " pixels, not " + str(file_width) + "x" + str(abs(file_height))
  return false
 end if
 
 colors_used = BmpU32(raw, 47)
 if colors_used = 0 or colors_used > 2 ^ bpp then colors_used = 2 ^ bpp
 table_start = 15 + header_size
 if table_start + colors_used * 4 - 1 > len(raw) then
  problem = "color table is cut off"
  return false
 end if
 
 row_bytes = ((width_px * bpp + 31) \ 32) * 4
 if data_offset + row_bytes * height_px > len(raw) then
  problem = "image data is cut off"
  return false
 end if
 
 bmp_table_count = colors_used
 for i as Integer = 0 to colors_used - 1
  bmp_table(i) = RGB(asc(mid(raw, table_start + i * 4 + 2, 1)), asc(mid(raw, table_start + i * 4 + 1, 1)), asc(mid(raw, table_start + i * 4, 1)))
 next
 
 for y as Integer = 0 to height_px - 1
  if file_height > 0 then file_row = height_px - 1 - y else file_row = y
  for x as Integer = 0 to width_px - 1
   if bpp = 4 then
    index = asc(mid(raw, data_offset + file_row * row_bytes + x \ 2 + 1, 1))
    if x mod 2 = 0 then index = index \ 16 else index = index mod 16
   else
    index = asc(mid(raw, data_offset + file_row * row_bytes + x + 1, 1))
   end if
   if index >= colors_used then
    problem = "pixel " + str(x) + "," + str(y) + " uses color " + str(index) + ", which is not in the color table"
    return false
   end if
   bmp_px(y, x) = index
  next
 next
 
 return true

end function


function BmpColorToSnes(c as UInteger) as UInteger

 dim r as Integer = (((c shr 16) and 255) + 4) \ 8
 dim g as Integer = (((c shr 8) and 255) + 4) \ 8
 dim b as Integer = ((c and 255) + 4) \ 8

 if r > 31 then r = 31
 if g > 31 then g = 31
 if b > 31 then b = 31

 return r + g * 32 + b * 1024

end function


function ResolveSwatchPalette(width_px as Integer, height_px as Integer, new_palette() as UInteger, byref problem as String, swatch_count as Integer = 16) as Boolean

 'Turns the raw indices in bmp_px into palette indices using the 16 swatch pixels in the top right
 ' corner (top to bottom), and builds the palette from those pixels' colors.

 dim index_map(255) as Integer
 dim swatch(15) as UInteger
 dim index as Integer
 dim found as Integer
 dim c as UInteger
 dim r as Integer
 dim g as Integer
 dim b as Integer
 
 for i as Integer = 0 to 255
  index_map(i) = -1
 next
 
 for y as Integer = 0 to swatch_count - 1
  index = bmp_px(y, width_px - 1)
  swatch(y) = bmp_table(index) and &hFFFFFF
  if index_map(index) = -1 then index_map(index) = y
  r = (((swatch(y) shr 16) and 255) + 4) \ 8
  g = (((swatch(y) shr 8) and 255) + 4) \ 8
  b = ((swatch(y) and 255) + 4) \ 8
  if r > 31 then r = 31
  if g > 31 then g = 31
  if b > 31 then b = 31
  new_palette(y) = r + g * 32 + b * 1024
 next
 
 for y as Integer = 0 to height_px - 1
  for x as Integer = 0 to width_px - 1 - image_strip
   index = bmp_px(y, x)
   if index_map(index) >= 0 then
    bmp_px(y, x) = index_map(index)
   else
    c = bmp_table(index) and &hFFFFFF
    found = -1
    for i as Integer = 0 to swatch_count - 1
     if swatch(i) = c then
      found = i
      exit for
     end if
    next
    if found < 0 then
     problem = "pixel " + str(x) + "," + str(y) + " is a color that is not one of the " + str(swatch_count) + " palette pixels"
     return false
    end if
    bmp_px(y, x) = found
   end if
  next
 next
 
 return true

end function


function ReadBMPWithPalette(path as String, width_px as Integer, height_px as Integer, color_count as Integer, new_palette() as UInteger, byref problem as String) as Boolean

 'Reads an indexed BMP of width_px x height_px into bmp_px. Its own color table is the palette, so pixel
 ' values are palette color numbers (at most color_count of them). new_palette keeps its value for a color
 ' that the table does not have. An older image that is image_strip pixels wider and holds the
 ' palette as pixels in its top right corner is read as well.

 dim first_problem as String

 if ReadIndexedBMP(path, width_px, height_px, problem) then
  for y as Integer = 0 to height_px - 1
   for x as Integer = 0 to width_px - 1
    if bmp_px(y, x) >= color_count then
     problem = "pixel " + str(x) + "," + str(y) + " uses color " + str(bmp_px(y, x)) + ", but only colors 0 to " + str(color_count - 1) + " exist"
     return false
    end if
   next
  next
  for i as Integer = 0 to min(color_count, bmp_table_count) - 1
   new_palette(i) = BmpColorToSnes(bmp_table(i))
  next
  return true
 end if

 if left(problem, 7) <> "must be" then return false
 first_problem = problem
 problem = ""
 if not ReadIndexedBMP(path, width_px + image_strip, height_px, problem) then
  problem = first_problem
  return false
 end if

 return ResolveSwatchPalette(width_px + image_strip, height_px, new_palette(), problem, color_count)

end function


function ImagePoseId(image_pose as Integer) as Integer

 'The game's pose number for each of the poses shown in the pose image

 if image_pose = image_pose_count - 1 then return special_pose_id
 return image_pose

end function


function ImagePoseIndex(pose as Integer) as Integer

 'Position of a game pose among the poses shown in the editor and in the pose image

 if pose = special_pose_id then return image_pose_count - 1
 return pose

end function


function PoseSpriteCount(pose as Integer) as Integer

 if pose = special_pose_id then return 8
 return 6

end function


sub PoseImageOrigin(pose as Integer, byref ox as Integer, byref oy as Integer)

 'Top left corner of a pose in the pose image. Poses are packed: seven 16 wide poses on the first
 ' row, then Hit, Victory, Dead (24 wide), Chant 1, Chant 2 and Special (24 wide) on the second.

 oy = 0
 select case pose
  case 0 to 6: ox = pose * 16
  case 7: ox = 0
  case 8: ox = 16
  case 9: ox = 32
  case 10: ox = 56
  case 11: ox = 72
  case else: ox = 88
 end select
 if pose >= 7 then oy = 24

end sub


sub PoseSpritePosition(pose as Integer, k as Integer, byref x as Integer, byref y as Integer)

 'Top left corner of sprite k of a pose, relative to the pose's cell. Poses that reach to
 ' the left of the cell origin (Dead and Special are 24 pixels wide) are shifted right so all of it is inside.

 dim position_id as Integer = ByteAt(battle_pose_offset_table + pose)
 dim left_most as Integer = 0
 dim sprite_x as Integer

 for j as Integer = 0 to PoseSpriteCount(pose) - 1
  if ByteAt(battle_tile_table + pose * 6 + j) < 64 then
   sprite_x = ByteAt(battle_sprite_offset_table + position_id * 32 + j * 4)
   if sprite_x > 127 then sprite_x -= 256
   if sprite_x < left_most then left_most = sprite_x
  end if
 next

 x = ByteAt(battle_sprite_offset_table + position_id * 32 + k * 4)
 y = ByteAt(battle_sprite_offset_table + position_id * 32 + k * 4 + 1)
 if x > 127 then x -= 256
 if y > 127 then y -= 256
 x -= left_most

end sub


sub PoseExtraTiles(extras() as Integer, byref extra_count as Integer, used() as Boolean)

 'Tiles of a sheet that none of the poses use, in order

 dim tile_id as Integer
 dim pose_id as Integer

 for t as Integer = 0 to 63
  used(t) = false
 next
 for img as Integer = 0 to image_pose_count - 1
  pose_id = ImagePoseId(img)
  for k as Integer = 0 to PoseSpriteCount(pose_id) - 1
   tile_id = ByteAt(battle_tile_table + pose_id * 6 + k)
   if tile_id < 64 then used(tile_id) = true
  next
 next

 extra_count = 0
 for t as Integer = 0 to 63
  if not used(t) then
   extras(extra_count) = t
   extra_count += 1
  end if
 next

end sub


function WriteBattlePosesBMP(path as String, sheet as Integer, pal as Integer) as Boolean

 dim tile_id as Integer
 dim pose_id as Integer
 dim sx as Integer
 dim sy as Integer
 dim ox as Integer
 dim oy as Integer
 dim extras(63) as Integer
 dim extra_count as Integer
 dim used(63) as Boolean

 for y as Integer = 0 to pose_image_height - 1
  for x as Integer = 0 to pose_image_width - 1
   bmp_px(y, x) = 0
  next
 next

 for img as Integer = 0 to image_pose_count - 1
  pose_id = ImagePoseId(img)
  for k as Integer = 0 to PoseSpriteCount(pose_id) - 1
   tile_id = ByteAt(battle_tile_table + pose_id * 6 + k)
   if tile_id < 64 then
    PoseImageOrigin(pose_id, ox, oy)
    PoseSpritePosition(pose_id, k, sx, sy)
    for y as Integer = 0 to 7
     for x as Integer = 0 to 7
      bmp_px(oy + sy + y, ox + sx + x) = battle_char_gfx(sheet, tile_id, y, x)
     next
    next
   end if
  next
 next

 PoseExtraTiles(extras(), extra_count, used())
 for n as Integer = 0 to min(extra_count, max_extra_tiles) - 1
  for y as Integer = 0 to 7
   for x as Integer = 0 to 7
    bmp_px(extra_tile_y + y, extra_tile_x + x) = battle_char_gfx(sheet, extras(n), y, x)
   next
  next
 next

 return WriteIndexedBMP(path, pose_image_width, pose_image_height, pal)

end function


function ReadBattlePosesBMP(path as String, sheet as Integer, pal as Integer, byref problem as String) as Boolean

 'Splits a pose image back into tiles. A tile that appears in several poses takes the version
 ' that differs from the current tile; if poses disagree, the first one wins and problem says so.

 dim new_palette(15) as UInteger
 dim use_count(63) as Integer
 dim use_pose(63, max_pose_uses - 1) as Integer
 dim use_sprite(63, max_pose_uses - 1) as Integer
 dim new_tiles(63, 7, 7) as UByte
 dim touched(63) as Boolean
 dim tile_id as Integer
 dim pose_id as Integer
 dim sx as Integer
 dim sy as Integer
 dim ox as Integer
 dim oy as Integer
 dim chosen_pose(63) as Integer
 dim chosen as Boolean
 dim differs_from_current as Boolean
 dim differs_from_chosen as Boolean
 dim cand_x as Integer
 dim cand_y as Integer
 dim chosen_x as Integer
 dim chosen_y as Integer
 dim extras(63) as Integer
 dim extra_count as Integer
 dim used(63) as Boolean
 dim conflicts as String
 dim conflict_count as Integer

 for i as Integer = 0 to 15
  new_palette(i) = battle_palette_raw(pal, i)
 next
 if not ReadBMPWithPalette(path, pose_image_width, pose_image_height, 16, new_palette(), problem) then return false

 for img as Integer = 0 to image_pose_count - 1
  pose_id = ImagePoseId(img)
  for k as Integer = 0 to PoseSpriteCount(pose_id) - 1
   tile_id = ByteAt(battle_tile_table + pose_id * 6 + k)
   if tile_id < 64 andalso use_count(tile_id) < max_pose_uses then
    use_pose(tile_id, use_count(tile_id)) = pose_id
    use_sprite(tile_id, use_count(tile_id)) = k
    use_count(tile_id) += 1
   end if
  next
 next

 for t as Integer = 0 to 63
  if use_count(t) > 0 then
   chosen = false
   for u as Integer = 0 to use_count(t) - 1
    PoseSpritePosition(use_pose(t, u), use_sprite(t, u), sx, sy)
    PoseImageOrigin(use_pose(t, u), ox, oy)
    cand_x = ox + sx
    cand_y = oy + sy
    differs_from_current = false
    for y as Integer = 0 to 7
     for x as Integer = 0 to 7
      if bmp_px(cand_y + y, cand_x + x) <> battle_char_gfx(sheet, t, y, x) then differs_from_current = true
     next
    next
    if differs_from_current then
     if not chosen then
      chosen = true
      chosen_x = cand_x
      chosen_y = cand_y
      chosen_pose(t) = use_pose(t, u)
     else
      differs_from_chosen = false
      for y as Integer = 0 to 7
       for x as Integer = 0 to 7
        if bmp_px(cand_y + y, cand_x + x) <> bmp_px(chosen_y + y, chosen_x + x) then differs_from_chosen = true
       next
      next
      if differs_from_chosen then
       conflict_count += 1
       if conflict_count <= 4 then conflicts += "|tile " + hex(t, 2) + ": " + BattlePoseName(chosen_pose(t)) + " and " + BattlePoseName(use_pose(t, u)) + " differ; kept " + BattlePoseName(chosen_pose(t))
      end if
     end if
    end if
   next
   if chosen then
    touched(t) = true
    for y as Integer = 0 to 7
     for x as Integer = 0 to 7
      new_tiles(t, y, x) = bmp_px(chosen_y + y, chosen_x + x)
     next
    next
   end if
  end if
 next

 PoseExtraTiles(extras(), extra_count, used())
 for n as Integer = 0 to min(extra_count, max_extra_tiles) - 1
  touched(extras(n)) = true
  for y as Integer = 0 to 7
   for x as Integer = 0 to 7
    new_tiles(extras(n), y, x) = bmp_px(extra_tile_y + y, extra_tile_x + x)
   next
  next
 next

 for t as Integer = 0 to 63
  if touched(t) then
   for y as Integer = 0 to 7
    for x as Integer = 0 to 7
     battle_char_gfx(sheet, t, y, x) = new_tiles(t, y, x)
    next
   next
  end if
 next
 for i as Integer = 0 to 15
  battle_palette_raw(pal, i) = new_palette(i)
 next

 if conflict_count > 4 then conflicts += "|... and " + str(conflict_count - 4) + " more tile conflicts"
 problem = conflicts

 return true

end function


function ExportBattleSprites() as String

 'Returns a message for the user

 dim written as Integer
 dim failed as Integer
 dim file_name as String
 for s as Integer = 0 to total_battle_char_sheets - 1
  file_name = "poses_" + Pad(str(s), 2, true, "0") + "_pal_" + Pad(str(s), 2, true, "0") + ".bmp"
  if WriteBattlePosesBMP(BattleSpritePath(file_name), s, s) then written += 1 else failed += 1
 next

 if failed > 0 then return "Export had " + str(failed) + " error(s)|Check that exports\battle_sprites can be written"
 return "Wrote " + str(written) + " pose images|to exports\battle_sprites"

end function


function ImportBattleSprites() as String

 'Returns a message for the user

 dim number as Integer
 dim sheets_read as Integer
 dim name_found as String
 dim pal as Integer
 dim problem as String
 dim report as String
 dim ok as Boolean

 for s as Integer = 0 to total_battle_char_sheets - 1
  name_found = dir(BattleSpritePath("poses_" + Pad(str(s), 2, true, "0") + "_pal_*.bmp"))
  if len(name_found) > 0 then
   pal = s
   if len(name_found) >= 15 then
    number = val(mid(name_found, 14, 2))
    if number >= 0 and number <= 15 and mid(name_found, 14, 2) = Pad(str(number), 2, true, "0") then pal = number
   end if
   problem = ""
   if ReadBattlePosesBMP(BattleSpritePath(name_found), s, pal, problem) then
    sheets_read += 1
    if len(problem) > 0 then report += "|" + name_found + ":" + problem
   else
    report += "|" + name_found + ": " + problem
   end if
  end if
 next

 if sheets_read = 0 and report = "" then return "Nothing to import|Looked in exports\battle_sprites"

 return "Imported " + str(sheets_read) + " pose images (sprites and palettes)" + report

end function
