'The Free Space screen: expand the ROM to 2 MB or 4 MB and keep track of the blocks of the new banks.
'The logic is in subs/general/freespace.bas.

function FsSizeText(rom_size as Integer) as String

 return str(rom_size) + " bytes, " + str(rom_size \ &h100000) + " MB"

end function


sub DrawFreeSpace()

 dim lines(1 to 12) as String
 dim n as Integer
 dim box_height as Integer
 dim shown as Integer

 n = 0
 n += 1: lines(n) = "ROM size    " + FsSizeText(FsRomSize())
 if not FsExpanded() then
  n += 1: lines(n) = "Not expanded yet: the game uses banks 00-1F."
  n += 1: lines(n) = "Expanding adds empty banks after them."
 elseif FsHasTable() then
  FsLoad()
  n += 1: lines(n) = "New banks   20-" + hex(FsRomSize() \ &h8000 - 1, 2)
  n += 1: lines(n) = "Blocks      " + str(fs_blocks) + " of " + str(fs_max_blocks)
  n += 1: lines(n) = "In use      " + str(FsUsedBytes()) + " bytes, with the " + str(fs_table_size) + " byte table"
  n += 1: lines(n) = "Free        " + str(FsFreeBytes()) + " bytes"
  n += 1: lines(n) = "Biggest     " + str(FsLargestRun(true)) + " bytes in one bank"
 else
  n += 1: lines(n) = "This ROM was extended by another tool."
  n += 1: lines(n) = "Its new banks are not managed here."
 end if

 BlueBox(24, 2, 53, n)
 for i as Integer = 1 to n
  WriteText(FF4Text(lines(i)), 25, 2 + i)
 next

 if FsHasTable() then
  FsLoad()
  shown = Min(fs_blocks, 30)
  box_height = shown + 2
  BlueBox(24, 3 + n + 2, 53, box_height)
  WriteText(FF4Text("Address  Bytes  Owner"), 25, 3 + n + 3, 14)
  for i as Integer = 1 to shown
   WriteText(FF4Text(FsRomOffsetText(fs_start(i)) + "  " + Pad(str(fs_length(i)), 5, true) + "  " + FsOwnerName(fs_owner(i))), 25, 3 + n + 3 + i)
  next
  if fs_blocks > shown then WriteText(FF4Text("... " + str(fs_blocks - shown) + " more"), 25, 3 + n + 4 + shown)
  if fs_blocks = 0 then WriteText(FF4Text("No blocks yet."), 25, 3 + n + 4)
 end if

end sub


sub FsReserveBlock()

 dim size as Integer
 dim biggest as Integer
 dim owner as Integer
 dim where_at as Integer
 dim names(1 to fs_owner_count) as String
 dim n as BlueNumberInput

 biggest = Min(FsLargestRun(true), fs_bank_size)
 if biggest = 0 then
  InfoBox("There is no free room in the new banks.|Expand the ROM to 4 MB for more.||Press any key", 4, 20)
  exit sub
 end if

 BlueBox(2, 19, 60, 3)
 WriteText(FF4Text("How many bytes? 1 to " + str(biggest) + ". Enter accepts, Esc cancels"), 3, 20)
 WriteText(FF4Text("The block stays inside one bank."), 3, 21)
 WriteText(FF4Text("Bytes:"), 3, 22)
 n = BlueNumberInput(10, 22)
 n.min_value = 0
 n.max_value = biggest
 n.starting_number = 0
 n.number = 0
 n.UserSelect()
 size = n.number
 cls
 if size = 0 then exit sub

 for i as Integer = 1 to fs_owner_count
  names(i) = fs_owner_name(i)
 next
 owner = SmPick("Who is it for?", names(), fs_owner_count, 1)
 if owner = 0 then exit sub

 where_at = FsAlloc(size, owner)
 if where_at < 0 then
  InfoBox("No block could be made: the table is full or|there is no room.||Press any key", 4, 20)
 else
  modified = true
  InfoBox("Reserved " + str(size) + " bytes at " + FsRomOffsetText(where_at - fs_header) + ".|The bytes are still empty, all FF.||Save ROM writes the table and the new banks.|Press any key", 4, 20)
 end if

end sub


sub FsReleaseBlock()

 dim names(1 to fs_max_blocks) as String
 dim choice as Integer

 FsLoad()
 if fs_blocks = 0 then exit sub
 for i as Integer = 1 to fs_blocks
  names(i) = FsRomOffsetText(fs_start(i)) + "  " + Pad(str(fs_length(i)), 5, true) + "  " + FsOwnerName(fs_owner(i))
 next
 choice = SmPick("Release which block?", names(), fs_blocks, 1)
 if choice = 0 then exit sub

 if ConfirmBox("Release it and fill it with FF? Its data is lost.") then
  if FsRelease(fs_start(choice) + fs_header) then modified = true
 end if

end sub


sub EditFreeSpace()

 dim m as BlueMenu
 dim ids(1 to 6) as Integer
 dim hints as String
 dim n as Integer
 dim done as Boolean
 dim reason as String

 do
  cls
  DrawFreeSpace()

  m = BlueMenu(2, 3)
  m.title = "Free space"
  m.min_width = 20
  n = 0
  hints = ""
  if FsRomSize() = fs_original_size then
   n += 1: ids(n) = 1: m.AddOption(FF4Text("Expand to 2 MB"))
   hints += "Add 1 MB of empty banks 20-3F to the ROM. Nothing is written until Save ROM.|"
   n += 1: ids(n) = 2: m.AddOption(FF4Text("Expand to 4 MB"))
   hints += "Add 3 MB of empty banks 20-7F to the ROM. Nothing is written until Save ROM.|"
  elseif FsHasTable() and FsRomSize() < &h400000 then
   n += 1: ids(n) = 2: m.AddOption(FF4Text("Expand to 4 MB"))
   hints += "Add banks up to 7F to the ROM. Nothing is written until Save ROM.|"
  end if
  if FsHasTable() then
   n += 1: ids(n) = 3: m.AddOption(FF4Text("Reserve a block"))
   hints += "Claim room in the new banks for a table, so nothing else is put there.|"
   n += 1: ids(n) = 4: m.AddOption(FF4Text("Release a block"))
   hints += "Give a block back and fill it with FF. Whatever uses it loses its data.|"
  end if
  n += 1: ids(n) = 5: m.AddOption(FF4Text("Back"))
  hints += "Return to the main menu."
  SetHints(m, hints)
  m.UserSelect()

  if m.cancelled then
   done = true
  else
   select case ids(m.selected)
    case 1, 2
     if ids(m.selected) = 1 then
      reason = FsExpandTo(&h200000)
     else
      reason = FsExpandTo(&h400000)
     end if
     if reason = "" then
      modified = true
      InfoBox("The ROM is now " + FsSizeText(FsRomSize()) + ".|The new banks are empty, all FF. The header size and|checksum are written by Save ROM.||Press any key", 4, 20)
     else
      InfoBox(reason + "||Press any key", 4, 20)
     end if
    case 3: FsReserveBlock()
    case 4: FsReleaseBlock()
    case else: done = true
   end select
  end if
 loop until done

 cls

end sub
