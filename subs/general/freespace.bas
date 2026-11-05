'Expanding the ROM and the free space manager.
'
'The original game is 1 MB (banks 00-1F of the LoROM). Expanding adds whole banks of FF bytes (2 MB: banks 20-3F,
'4 MB: banks 40-7F) and updates the size byte and the checksum in the header. The new banks are the only space the
'manager hands out: the free bytes inside the original 1 MB are not known to be free, so they are left alone.
'
'Who owns what in the new banks is written into the ROM itself, in the first 0x800 bytes of the first new bank
'(bank 20, offset 8000): "F4KS", a version byte, a count of blocks (2 bytes), one reserved byte, then 8 bytes per
'block: start (3 bytes, offset without the 0x200 header), length (3 bytes), owner (2 bytes). The blocks are kept in
'order of start. The table travels with the ROM. A ROM expanded by other tools has no table: the manager can show
'its new banks but does not hand out space in them.
'
'All offsets in the routines below are file offsets as the rest of the editor uses them (header included) unless
'the name says "rom offset".

const fs_original_size = &h100000 'rom offset where the new banks start
const fs_table_size = &h800
const fs_max_blocks = (fs_table_size - 8) \ 8
const fs_bank_size = &h8000
const fs_header = &h200
const fs_size_byte = &h7FD7 + &h200
const fs_checksum = &h7FDC + &h200
const fs_rom_cap = &h3F0000 'rom offset of banks 7E and 7F, which are RAM to the console: nothing is placed from here on

const fs_owner_reserved = 1
const fs_owner_count = 12

dim shared fs_owner_name(1 to fs_owner_count) as String
fs_owner_name(1) = "Reserved"
fs_owner_name(2) = "Messages"
fs_owner_name(3) = "Events"
fs_owner_name(4) = "Triggers"
fs_owner_name(5) = "Monster AI"
fs_owner_name(6) = "Monster sprites"
fs_owner_name(7) = "Field sprites"
fs_owner_name(8) = "Portraits"
fs_owner_name(9) = "Battle sprites"
fs_owner_name(10) = "Spells"
fs_owner_name(11) = "Commands"
fs_owner_name(12) = "Command code"

dim shared fs_start(1 to fs_max_blocks) as Integer 'rom offsets
dim shared fs_length(1 to fs_max_blocks) as Integer
dim shared fs_owner(1 to fs_max_blocks) as Integer
dim shared fs_blocks as Integer


function FsRomSize() as Integer

 'Bytes of ROM without the header

 return len(ff4rom) - fs_header

end function


function FsExpanded() as Boolean

 return FsRomSize() > fs_original_size

end function


function FsHasTable() as Boolean

 if FsRomSize() < fs_original_size + fs_table_size then return false

 return mid(ff4rom, fs_header + fs_original_size + 1, 4) = "F4KS"

end function


function FsOwnerName(owner as Integer) as String

 if owner >= 1 and owner <= fs_owner_count then return fs_owner_name(owner)

 return "Owner " + str(owner)

end function


function FsRomOffsetText(rom_offset as Integer) as String

 'The SNES address the game uses: bank:address (LoROM)

 return hex(rom_offset \ fs_bank_size, 2) + ":" + hex(&h8000 + rom_offset mod fs_bank_size, 4)

end function


sub FsLoad()

 'Reads the block table from the ROM image into the fs_ arrays

 dim table_at as Integer = fs_header + fs_original_size
 dim p as Integer

 fs_blocks = 0
 if not FsHasTable() then exit sub

 fs_blocks = Min(ByteAt(table_at + 5) + ByteAt(table_at + 6) * &h100, fs_max_blocks)
 for i as Integer = 1 to fs_blocks
  p = table_at + 8 + (i - 1) * 8
  fs_start(i) = ByteAt(p) + ByteAt(p + 1) * &h100 + ByteAt(p + 2) * &h10000
  fs_length(i) = ByteAt(p + 3) + ByteAt(p + 4) * &h100 + ByteAt(p + 5) * &h10000
  fs_owner(i) = ByteAt(p + 6) + ByteAt(p + 7) * &h100
 next

end sub


sub FsStore()

 'Writes the fs_ arrays back as the block table

 dim table_at as Integer = fs_header + fs_original_size
 dim p as Integer

 WriteByte(table_at, asc("F"))
 WriteByte(table_at + 1, asc("4"))
 WriteByte(table_at + 2, asc("K"))
 WriteByte(table_at + 3, asc("S"))
 WriteByte(table_at + 4, 1)
 WriteByte(table_at + 5, fs_blocks mod &h100)
 WriteByte(table_at + 6, fs_blocks \ &h100)
 WriteByte(table_at + 7, 0)
 for i as Integer = 1 to fs_max_blocks
  p = table_at + 8 + (i - 1) * 8
  if i <= fs_blocks then
   WriteByte(p, fs_start(i) and &hFF)
   WriteByte(p + 1, (fs_start(i) shr 8) and &hFF)
   WriteByte(p + 2, (fs_start(i) shr 16) and &hFF)
   WriteByte(p + 3, fs_length(i) and &hFF)
   WriteByte(p + 4, (fs_length(i) shr 8) and &hFF)
   WriteByte(p + 5, (fs_length(i) shr 16) and &hFF)
   WriteByte(p + 6, fs_owner(i) and &hFF)
   WriteByte(p + 7, (fs_owner(i) shr 8) and &hFF)
  else
   for j as Integer = 0 to 7
    WriteByte(p + j, 0)
   next
  end if
 next

end sub


function FsUsableStart() as Integer

 'Rom offset of the first byte the manager can hand out (after its own table)

 return fs_original_size + fs_table_size

end function


function FsGapStart(g as Integer) as Integer

 'Gap g (0 to fs_blocks) is the space before block g + 1; the last one runs to the end of the ROM.

 if g = 0 then return FsUsableStart()

 return fs_start(g) + fs_length(g)

end function


function FsGapEnd(g as Integer) as Integer

 dim result as Integer

 if g >= fs_blocks then result = Min(FsRomSize(), fs_rom_cap) else result = fs_start(g + 1)
 if result < FsGapStart(g) then result = FsGapStart(g)

 return result

end function


function FsFreeBytes() as Integer

 dim total as Integer

 if not FsHasTable() then return 0
 FsLoad()
 for g as Integer = 0 to fs_blocks
  total += FsGapEnd(g) - FsGapStart(g)
 next

 return total

end function


function FsUsedBytes() as Integer

 'Bytes in blocks, plus the table itself

 dim total as Integer

 if not FsHasTable() then return 0
 FsLoad()
 total = fs_table_size
 for i as Integer = 1 to fs_blocks
  total += fs_length(i)
 next

 return total

end function


function FsGapFit(g as Integer, size as Integer, cross_banks as Boolean, align_bank as Boolean = false) as Integer

 'Where a block of that size fits in gap g, -1 if it does not. Unless cross_banks is true the block must not cross
 ' a bank boundary: a 16-bit pointer inside the game's code only reaches within one bank.

 dim s as Integer = FsGapStart(g)

 if align_bank and s mod fs_bank_size <> 0 then s = (s \ fs_bank_size + 1) * fs_bank_size
 if not cross_banks and size <= fs_bank_size and s mod fs_bank_size + size > fs_bank_size then
  s = (s \ fs_bank_size + 1) * fs_bank_size
 end if
 if s + size <= FsGapEnd(g) then return s

 return -1

end function


function FsLargestRun(within_bank as Boolean) as Integer

 'The biggest block FsAlloc could give right now (within_bank: one that stays inside a bank)

 dim best as Integer
 dim s as Integer
 dim e as Integer
 dim room as Integer

 if not FsHasTable() then return 0
 FsLoad()
 for g as Integer = 0 to fs_blocks
  s = FsGapStart(g)
  e = FsGapEnd(g)
  if within_bank then
   'cut the gap at bank boundaries and take the biggest piece
   do while s < e
    room = Min(e, (s \ fs_bank_size + 1) * fs_bank_size) - s
    best = Max(best, room)
    s += room
   loop
  else
   best = Max(best, e - s)
  end if
 next

 return best

end function


function FsAlloc(size as Integer, owner as Integer, cross_banks as Boolean = false, align_bank as Boolean = false) as Integer

 'Claims the first place of that size (starting on a bank boundary with align_bank). Returns the file offset (header included) or -1 when there is no room, no
 ' table, or the table is full. The bytes are left as they are (FF in a fresh bank).

 dim s as Integer

 if size <= 0 or not FsHasTable() then return -1
 FsLoad()
 if fs_blocks >= fs_max_blocks then return -1

 for g as Integer = 0 to fs_blocks
  s = FsGapFit(g, size, cross_banks, align_bank)
  if s >= 0 then
   'insert as block g + 1
   for i as Integer = fs_blocks to g + 1 step -1
    fs_start(i + 1) = fs_start(i)
    fs_length(i + 1) = fs_length(i)
    fs_owner(i + 1) = fs_owner(i)
   next
   fs_start(g + 1) = s
   fs_length(g + 1) = size
   fs_owner(g + 1) = owner
   fs_blocks += 1
   FsStore()
   return s + fs_header
  end if
 next

 return -1

end function


function FsFindBlock(file_offset as Integer) as Integer

 'The block that starts at that file offset, 0 if none (needs FsLoad first)

 for i as Integer = 1 to fs_blocks
  if fs_start(i) + fs_header = file_offset then return i
 next

 return 0

end function


function FsRelease(file_offset as Integer) as Boolean

 'Gives a block back and fills it with FF again. Returns false if no block starts there.

 dim b as Integer

 FsLoad()
 b = FsFindBlock(file_offset)
 if b = 0 then return false

 for i as Integer = 0 to fs_length(b) - 1
  WriteByte(file_offset + i, &hFF)
 next
 for i as Integer = b to fs_blocks - 1
  fs_start(i) = fs_start(i + 1)
  fs_length(i) = fs_length(i + 1)
  fs_owner(i) = fs_owner(i + 1)
 next
 fs_blocks -= 1
 FsStore()

 return true

end function


function FsAdopt(file_offset as Integer, size as Integer, owner as Integer) as Boolean

 'Registers a block of data that is in the ROM but is not in the table (it was lost from it), when no other block is
 ' in the way. False if it overlaps one or the table is full. True when it is registered.

 dim s as Integer = file_offset - fs_header
 dim g as Integer

 FsLoad()
 if FsFindBlock(file_offset) > 0 then return true
 if fs_blocks >= fs_max_blocks then return false
 for i as Integer = 1 to fs_blocks
  if s < fs_start(i) + fs_length(i) and s + size > fs_start(i) then return false
 next

 g = 0
 for i as Integer = 1 to fs_blocks
  if fs_start(i) < s then g = i
 next
 for i as Integer = fs_blocks to g + 1 step -1
  fs_start(i + 1) = fs_start(i)
  fs_length(i + 1) = fs_length(i)
  fs_owner(i + 1) = fs_owner(i)
 next
 fs_start(g + 1) = s
 fs_length(g + 1) = size
 fs_owner(g + 1) = owner
 fs_blocks += 1
 FsStore()

 return true

end function


function FsResize(file_offset as Integer, new_size as Integer) as Boolean

 'Changes the length of a block in place when the space after it is free (or it shrinks). A shrunk tail is filled
 ' with FF. Returns false if it does not fit; the caller then allocates elsewhere and copies.

 dim b as Integer
 dim limit as Integer

 FsLoad()
 b = FsFindBlock(file_offset)
 if b = 0 or new_size <= 0 then return false

 limit = FsGapEnd(b) 'the space after block b runs to the start of the next one
 if fs_start(b) + new_size > limit then return false
 if (fs_start(b) mod fs_bank_size) + new_size > fs_bank_size and fs_length(b) <= fs_bank_size then return false

 for i as Integer = new_size to fs_length(b) - 1
  WriteByte(file_offset + i, &hFF)
 next
 fs_length(b) = new_size
 FsStore()

 return true

end function


function FsChecksumOK(size as Integer) as Boolean

 'The checksum can only be worked out for sizes that are a power of two

 return size > 0 and (size and (size - 1)) = 0

end function


sub FsFixChecksum()

 'Writes the header checksum of an expanded ROM that this editor expanded (the one with the table). The unexpanded
 ' game is left as it is so an unedited save stays byte for byte the same.

 dim total as UInteger
 dim sum as UInteger

 if not FsHasTable() or not FsChecksumOK(FsRomSize()) then exit sub

 WriteByte(fs_checksum, &hFF)
 WriteByte(fs_checksum + 1, &hFF)
 WriteByte(fs_checksum + 2, 0)
 WriteByte(fs_checksum + 3, 0)
 for i as Integer = fs_header + 1 to len(ff4rom)
  total += asc(mid(ff4rom, i, 1))
 next
 sum = total and &hFFFF
 WriteByte(fs_checksum, (sum xor &hFFFF) and &hFF)
 WriteByte(fs_checksum + 1, ((sum xor &hFFFF) shr 8) and &hFF)
 WriteByte(fs_checksum + 2, sum and &hFF)
 WriteByte(fs_checksum + 3, (sum shr 8) and &hFF)

end sub


function FsExpandTo(new_rom_size as Integer) as String

 'Expands the ROM image in memory to 2 MB or 4 MB. Returns "" when done, otherwise the reason it was not.
 ' Nothing is written to the file until Save ROM.

 dim size_code as Integer

 if new_rom_size <> &h200000 and new_rom_size <> &h400000 then return "Only 2 MB and 4 MB are supported."
 if FsRomSize() >= new_rom_size then return "The ROM is already that big or bigger."
 if FsRomSize() <> fs_original_size and not FsHasTable() then return "This ROM was extended by another tool, so its layout is not known."

 if new_rom_size = &h200000 then size_code = &h0B else size_code = &h0C

 ff4rom += string(fs_header + new_rom_size - len(ff4rom), chr(&hFF))
 WriteByte(fs_size_byte, size_code)
 if not FsHasTable() then
  fs_blocks = 0
  for i as Integer = 0 to fs_table_size - 1
   WriteByte(fs_header + fs_original_size + i, 0)
  next
  FsStore()
 end if

 return ""

end function
