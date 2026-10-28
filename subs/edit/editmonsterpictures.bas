'Adding a monster picture from a BMP without replacing an existing one, and the screen of the stored pictures
'(Edit Monster Sprites, the two lines after the monsters). The list, the room and the file are in
'subs/general/monsterpictures.bas. A stored picture is used by a monster through MpUse: here ("Use it for a
'monster") or in the Graphics box of the Monsters editor (Pointer, Stored picture).


function MpBmpSize(path as String, byref width_px as Integer, byref height_px as Integer) as Boolean

 'Width and height of a BMP file, read from its header

 dim f as Integer = freefile
 dim raw as String

 if open(path for binary access read as #f) <> 0 then return false
 raw = string(Min(lof(f), 64), 0)
 if lof(f) > 0 then get #f, , raw
 close #f
 if len(raw) < 30 orelse left(raw, 2) <> "BM" then return false

 width_px = BmpS32(raw, 19)
 height_px = abs(BmpS32(raw, 23))

 return true

end function


function MpSizeList() as String

 'The picture sizes the game has, as text lines separated by |

 dim result as String
 dim line_text as String
 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim seen as String = ","

 for s as Integer = 0 to monster_size_count - 1
  MonsterSizeTiles(s, tiles_wide, tiles_high)
  if instr(seen, "," + str(tiles_wide * 8) + "x" + str(tiles_high * 8) + ",") = 0 then
   seen += str(tiles_wide * 8) + "x" + str(tiles_high * 8) + ","
   line_text += Pad(str(tiles_wide * 8) + "x" + str(tiles_high * 8), 8)
   if len(line_text) >= 40 then
    result += line_text + "|"
    line_text = ""
   end if
  end if
 next
 result += line_text

 return result

end function


function MpPickMonster(title as String) as Integer

 'Which monster should use a picture. 0 for none (the first line, or Esc).

 dim names(1 to total_monsters + 1) as String
 dim choice as Integer

 names(1) = "Not now, only store it"
 for i as Integer = 1 to total_monsters
  names(i + 1) = FF4Name(monsters(i).name)
 next
 choice = SmPick(title, names(), total_monsters + 1, 1)
 if choice <= 1 then return 0

 return choice - 1

end function


sub MpUseFor(i as Integer)

 'The Use it for a monster action: pick a monster, say what changes, then change it

 dim m as Integer = MpPickMonster("Use for which monster?")

 if m = 0 then exit sub
 if ConfirmBox(left(FF4Name(monsters(m).name), 20) + " will draw as " + mp_name(i) + ". Pointer, size and palette change. Continue?") then
  MpUse(i, m)
  InfoBox(FF4Name(monsters(m).name) + " now uses " + mp_name(i) + "||Press any key", 4, 20)
 end if

end sub


function MpAskName(default_name as String) as String

 'A name of at most mp_name_length letters; Esc keeps default_name

 dim name_input as BlueTextInput
 dim shot as Any ptr
 dim result as String

 shot = ImageCreate(38 * 8, 8 * 8)
 get (22 * 8, 21 * 8)-(22 * 8 + 38 * 8 - 1, 21 * 8 + 8 * 8 - 1), shot
 BlueBox(22, 21, 36, 1)
 WriteText(FF4Text("Name of the picture, Enter stores it"), 23, 22)
 name_input = BlueTextInput(22, 24, mp_name_length)
 name_input.starting_text = FF4Text(default_name)
 name_input.text = name_input.starting_text
 name_input.UserType()
 result = FF4Name(name_input.text)
 put (22 * 8, 21 * 8), shot, pset
 ImageDestroy(shot)
 if len(trim(result)) = 0 then result = default_name

 return MpCleanName(trim(result))

end function


function MpImportNew() as Boolean

 'Reads a BMP into free room of the ROM and lists it. Returns true if a picture was added.

 dim files(1 to 99) as String
 dim palette_names(1 to total_monster_palettes) as String
 dim colors(15) as UInteger
 dim file_count as Integer
 dim choice as Integer
 dim file_index as Integer
 dim path as String
 dim problem as String
 dim width_px as Integer
 dim height_px as Integer
 dim size_id as Integer
 dim bytes as Integer
 dim offset as Integer
 dim palette_id as Integer
 dim default_palette as Integer
 dim users as Integer
 dim write_colors as Boolean = true
 dim picture_name as String
 dim picture as Integer
 dim monster_index as Integer
 dim message as String
 dim f as String

 f = dir(MonsterSpritePath("*.bmp"))
 do while len(f) > 0 and file_count < 99
  file_count += 1
  files(file_count) = f
  f = dir()
 loop
 if file_count = 0 then
  InfoBox("No BMP file found|Put an indexed BMP in the folder exports/monster_sprites and try again.|It needs 4 or 8 bits per pixel, only colors 0 to 7, and color 0 is transparent.||Press any key", 4, 20)
  return false
 end if
 if mp_count >= mp_max then
  InfoBox("The list of stored pictures is full (" + str(mp_max) + ")|Delete one first||Press any key", 4, 20)
  return false
 end if

 file_index = SmPick("Which BMP?", files(), file_count, 1)
 if file_index = 0 then return false
 path = MonsterSpritePath(files(file_index))

 if not MpBmpSize(path, width_px, height_px) then
  InfoBox(files(file_index) + " is not a BMP file||Press any key", 4, 20)
  return false
 end if
 size_id = MpSizeFor(width_px, height_px)
 if size_id < 0 then
  InfoBox(files(file_index) + " is " + str(width_px) + "x" + str(height_px) + " pixels.|The game only has these sizes, width x height:||" + MpSizeList() + "||Press any key", 4, 14)
  return false
 end if

 bytes = MpBytes(size_id)
 offset = MpFindSpace(bytes)
 if offset = 0 then
  InfoBox("No room for this picture|It needs " + str(bytes) + " bytes in one piece. The longest free run has " + str(MpLargestRun()) + ".|Free in all: " + str(MpFreeBytes()) + " of " + str(MpCapacity()) + " bytes.|Delete a stored picture or use a smaller one.||Press any key", 4, 18)
  return false
 end if

 if not ReadBMPWithPalette(path, width_px, height_px, 8, colors(), problem) then
  InfoBox(files(file_index) + ": " + problem + "||Press any key", 4, 20)
  return false
 end if

 'Which palette the picture's colors go in: any of the game's, the first unused one to begin with
 default_palette = MpUnusedPalette()
 for p as Integer = 0 to total_monster_palettes - 1
  users = MpPaletteUsers(p)
  palette_names(p + 1) = "Palette " + Pad(str(p), 3) + iif(users = 0, "  not used", "  used by " + str(users))
 next
 choice = SmPick("Palette for the picture", palette_names(), total_monster_palettes, iif(default_palette >= 0, default_palette + 1, 1))
 if choice = 0 then return false
 palette_id = choice - 1
 users = MpPaletteUsers(palette_id)
 if users > 0 then
  write_colors = ConfirmBox("Palette " + str(palette_id) + " is used by " + str(users) + " monsters. Replace its colors with the BMP's?")
 end if

 picture_name = MpAskName(left(files(file_index), len(files(file_index)) - 4))

 MpWriteTiles(offset, width_px \ 8, height_px \ 8)
 if write_colors then MpWritePalette(palette_id, colors())
 picture = MpAdd(picture_name, offset, size_id, palette_id)

 message = "Stored " + mp_name(picture) + ": " + str(width_px) + "x" + str(height_px) + " pixels, " + str(bytes) + " bytes|Pointer " + str(mp_ptr(picture)) + ", size " + str(size_id) + ", palette " + str(palette_id)
 if not write_colors then message += "|The colors of palette " + str(palette_id) + " were kept"

 monster_index = MpPickMonster("Use it for which monster?")
 if monster_index > 0 then
  MpUse(picture, monster_index)
  message += "|" + FF4Name(monsters(monster_index).name) + " now uses it"
 else
  message += "|No monster uses it yet. Give it to one with Use it for a monster in|the stored pictures, or with Pointer, Stored picture in Edit Monsters."
 end if
 InfoBox(message + "||Press any key", 4, 20)

 return true

end function


sub MpExport(i as Integer)

 dim start as Integer = MpStart(i)
 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim colors(15) as UInteger
 dim file_name as String = "picture_"
 dim c as String

 for k as Integer = 1 to len(mp_name(i))
  c = mid(mp_name(i), k, 1)
  if (c >= "A" and c <= "Z") or (c >= "a" and c <= "z") or (c >= "0" and c <= "9") then file_name += c else file_name += "_"
 next
 file_name += ".bmp"

 MonsterSizeTiles(mp_size(i), tiles_wide, tiles_high)
 for y as Integer = 0 to tiles_high * 8 - 1
  for x as Integer = 0 to tiles_wide * 8 - 1
   bmp_px(y, x) = MonsterTileColor(start, (y \ 8) * tiles_wide + x \ 8, y mod 8, x mod 8)
  next
 next
 for k as Integer = 0 to 7
  colors(k) = ByteAt(monster_palette_table + mp_pal(i) * 16 + k * 2) + ByteAt(monster_palette_table + mp_pal(i) * 16 + k * 2 + 1) * &h100
 next

 if WriteIndexedBMPColors(MonsterSpritePath(file_name), tiles_wide * 8, tiles_high * 8, colors()) then
  InfoBox("Wrote exports/monster_sprites/" + file_name + "||Press any key", 4, 20)
 else
  InfoBox("Cannot write exports/monster_sprites||Press any key", 4, 20)
 end if

end sub


sub MpActions(i as Integer)

 'The actions on one stored picture

 dim choice as Integer
 dim users as Integer = MpUsers(i)
 dim new_name as String

 SmReset()
 SmAdd("Use it for a monster", "", 0, 1)
 SmAdd("Rename", "", 0, 2)
 SmAdd("Export as BMP", "", 0, 3)
 SmAdd("Delete and free its room", "", 0, 4)
 SmAdd("Back to the list", "Esc", ESC_KEY)
 choice = SmRun(left(mp_name(i), 20))

 select case choice
  case 1
   MpUseFor(i)
  case 2
   new_name = MpAskName(mp_name(i))
   mp_name(i) = new_name
   SaveMonsterPictures()
  case 3
   if ConfirmExport("this picture") then MpExport(i)
  case 4
   if users > 0 then
    InfoBox(mp_name(i) + " is used by " + str(users) + " monsters|Give them another picture first (Graphics box of Edit Monsters)||Press any key", 4, 20)
   elseif ConfirmBox("Delete " + mp_name(i) + "? Its room is freed and the tiles are gone.") then
    MpRemove(i)
   end if
 end select

end sub


sub StoredPictures()

 'The list of pictures added from BMP files, each with its picture beside it

 dim m as BlueMenu
 dim visible(1 to mp_max) as Integer
 dim n as Integer
 dim snapshot as Any ptr = 0
 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim hint_text as String
 dim remember as Integer = 1

 do

  ReadMonsterPictures()
  n = MpListed(visible())
  m.ClearAll()
  m.x = 1
  m.y = 3
  m.max_rows = Min(n + 1, 40)
  m.hint = "Enter opens the actions of this picture: use it for a monster, rename, export, delete."
  for k as Integer = 1 to n
   MonsterSizeTiles(mp_size(visible(k)), tiles_wide, tiles_high)
   m.AddOption(FF4Text(Pad(mp_name(visible(k)), mp_name_length) + " " + Pad(str(tiles_wide * 8) + "x" + str(tiles_high * 8), 8) + Pad(str(mp_ptr(visible(k))), 8) + str(MpUsers(visible(k)))))
   hint_text += "|"
  next
  m.AddOption(FF4Text("Add a picture from a BMP"))
  hint_text += "Enter reads a BMP from exports/monster_sprites into free room of the ROM."
  SetHints(m, mid(hint_text, 2))
  m.ChangeSelected(Max(Min(remember, n + 1), 1))
  hint_text = ""

  do
   screenlock
   line (0, 0)-(639, 463), RGB(0, 0, 0), bf
   WriteText(FF4Text("Stored monster pictures: " + str(n) + " of " + str(mp_max) + ", room " + str(MpFreeBytes()) + " of " + str(MpCapacity()) + " bytes"), 0, 0, 15)
   WriteText(FF4Text("Added without replacing a monster's picture. Enter gives one to a monster."), 0, 1, 14)
   WriteText(FF4Text(Pad("Name", mp_name_length) + " " + Pad("Size", 8) + Pad("Pointer", 8) + "Monsters"), 2, 2, 11)
   m.Display()
   screenunlock
   if m.selected <= n then MonsterSpritePanelShow(mp_ptr(visible(m.selected)), mp_size(visible(m.selected)), mp_pal(visible(m.selected)), snapshot)
  loop until m.UserInput()

  MonsterSpritePanelHide(snapshot)
  remember = m.selected
  if not m.cancelled then
   if m.selected > n then
    MpImportNew()
   else
    MpActions(visible(m.selected))
   end if
  end if

 loop until m.cancelled

 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

end sub
