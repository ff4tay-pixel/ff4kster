'Where the data of five regions is stored, and moving it to the new banks of an expanded ROM. The regions are the
'text of message banks 1 to 3, the event scripts (4) and the map triggers (5).
'
'The game reads these with "lda long,x" (x is a 16 bit offset from the start of the data, plus a small constant
'for the fields of a trigger). A pointer table of 16 bit offsets (kept where it is) says where each message, event
'or map's triggers start. In the SNES address space the sum of
'the base address and x cannot cross out of the bank the text starts in (10:FFFF + 1 is 11:0000, which is not the
'ROM), so the original text can use at most the 32 KB of one bank.
'
'Moving a region's data to the new banks replaces each of those instructions (BF lo hi bank, 4 bytes) with a
'JSL (22 lo hi bank, the same 4 bytes) to a small routine kept in the new banks:
'
'  php / cpx #$8000 / bcs high / plp / lda long,x (bank k, 8000) / rtl / high: plp / lda long,x (bank k+1, 0000) / rtl
'
'The data starts on a bank boundary (k:8000), x below 8000 reads bank k and x from 8000 on reads bank k+1, so the
'data can be up to 64 KB (offsets up to FFFF). The routine keeps the processor flags, X and Y as the original
'instruction did. An instruction that reads at a distance d from the start of the data (the "minus one" reads of
'message bank 2, the second to fifth byte of a trigger) gets a routine of its own with the thresholds moved by d.
'
'Nothing else changes: the pointer tables and the 16 bit offsets in them stay as they are. The state is kept in the
'ROM itself (the operands of the instructions), so it is read back by MbDetect when a ROM is opened. A ROM where the
'instructions are anything else (another tool moved the text) is left alone: the editor reads and writes the
'original places as it always did.

const mb_banks = 3 'the message banks
const mb_regions = 5 'message banks 1 to 3, events, triggers
const mb_events = 4
const mb_triggers = 5
const mb_text_room = &hFFF0 'bytes in a moved region
const mb_hook_size = 18

dim shared mb_orig_text(1 to mb_regions) as Integer
dim shared mb_orig_limit(1 to mb_regions) as Integer
dim shared mb_state(1 to mb_regions) as Integer '0 in the original place, 1 moved by this editor, 2 unknown (left alone)
dim shared mb_text(1 to mb_regions) as Integer 'file offset where the text starts
dim shared mb_limit(1 to mb_regions) as Integer 'file offset the text must stay below
dim shared mb_code(1 to mb_regions) as Integer 'file offset of the routines of a moved bank

mb_orig_text(1) = &h80600: mb_orig_limit(1) = &h881FF
mb_orig_text(2) = &h88500: mb_orig_limit(2) = &h901FB
mb_orig_text(3) = &h9A900: mb_orig_limit(3) = &h9D3FF
mb_orig_text(4) = &h90400: mb_orig_limit(4) = &h90400 + &h6E00
mb_orig_text(5) = &hA8500: mb_orig_limit(5) = &hA9820

'The distances from the start of the data that the instructions of a region read at, the first one is always 0. A
'region has one routine for each.
dim shared mb_delta_count(1 to mb_regions) as Integer
dim shared mb_delta(1 to mb_regions, 0 to 4) as Integer

mb_delta_count(1) = 1
mb_delta_count(2) = 2: mb_delta(2, 1) = -1
mb_delta_count(3) = 1
mb_delta_count(4) = 1
mb_delta_count(5) = 5
for i as Integer = 1 to 4
 mb_delta(5, i) = i
next


'The instructions that read the data: file offsets (header included) of the BF opcode and the distance they read at.
const mb_site_count = 6 + 9 + 17
dim shared mb_site_bank(1 to mb_site_count) as Integer
dim shared mb_site_at(1 to mb_site_count) as Integer
dim shared mb_site_delta(1 to mb_site_count) as Integer

sub MbAddSites()

 dim n as Integer

 n = 0
 'region, rom offset of the instruction, distance (rom offsets here have no header)
 dim data_text as String = "1,32D0,0;2,31A8,0;2,32C5,0;2,31AE,-1;2,31B6,-1;3,32D7,0;" + _
  "4,5F89,0;4,5FB3,0;4,5FBB,0;4,5FC2,0;4,5FE3,0;4,5FEC,0;4,5FF5,0;4,5FFE,0;4,62D6,0;" + _
  "5,16C3,0;5,1981,0;5,1A42,0;5,16CB,1;5,1987,1;5,1A4B,1;5,1A5C,2;5,1A6F,2;5,1AAC,2;" + _
  "5,1736,3;5,1A64,3;5,1A7A,3;5,1A83,3;5,1AB6,3;5,173C,4;5,1A92,4;5,1ABD,4;"
 dim p as Integer
 dim q as Integer
 dim item as String

 do
  q = instr(data_text, ";")
  if q = 0 then exit do
  item = left(data_text, q - 1)
  data_text = mid(data_text, q + 1)
  n += 1
  p = instr(item, ",")
  mb_site_bank(n) = val(left(item, p - 1))
  item = mid(item, p + 1)
  p = instr(item, ",")
  mb_site_at(n) = valint("&h" + left(item, p - 1)) + &h200
  mb_site_delta(n) = val(mid(item, p + 1))
 loop

end sub

MbAddSites()


function MbDeltaIndex(b as Integer, delta as Integer) as Integer

 for i as Integer = 0 to mb_delta_count(b) - 1
  if mb_delta(b, i) = delta then return i
 next

 return 0

end function


function MbSnes(file_offset as Integer) as Integer

 'The LoROM address bank:address (as bank * 65536 + address) of a file offset

 dim rom as Integer = file_offset - fs_header

 return (rom \ fs_bank_size) * &h10000 + &h8000 + rom mod fs_bank_size

end function


function MbFileOffset(snes as Integer) as Integer

 'The file offset of a LoROM address, -1 if it is not in the upper half of a bank

 if (snes and &hFFFF) < &h8000 then return -1

 return (snes shr 16) * fs_bank_size + (snes and &h7FFF) + fs_header

end function


function MbOperand(site as Integer) as Integer

 return ByteAt(site + 1) + ByteAt(site + 2) * &h100 + ByteAt(site + 3) * &h10000

end function


function MbHookBytes(text_at as Integer, delta as Integer) as String

 'The 18 bytes of the routine for data at that file offset (on a bank boundary) read at that distance

 dim k as Integer = (text_at - fs_header) \ fs_bank_size
 dim low_window as Integer = k * &h10000 + &h8000 + delta
 dim high_window as Integer = (k + 1) * &h10000 + delta
 dim limit as Integer = &h8000 - delta
 dim result as String

 result = chr(&h08) + chr(&hE0) + chr(limit and &hFF) + chr(limit shr 8) + chr(&hB0) + chr(&h06) + chr(&h28)
 result += chr(&hBF) + chr(low_window and &hFF) + chr((low_window shr 8) and &hFF) + chr(low_window shr 16) + chr(&h6B)
 result += chr(&h28) + chr(&hBF) + chr(high_window and &hFF) + chr((high_window shr 8) and &hFF) + chr(high_window shr 16) + chr(&h6B)

 return result

end function


function MbHookAt(site as Integer, text_at as Integer, delta as Integer) as Boolean

 'True if the JSL at that site goes to one of this editor's routines for data at that place

 dim target as Integer = MbFileOffset(MbOperand(site))

 if ByteAt(site) <> &h22 or target < 0 or target + mb_hook_size > len(ff4rom) then return false

 return mid(ff4rom, target + 1, mb_hook_size) = MbHookBytes(text_at, delta)

end function


sub MbDetect()

 'Works out for each region where its data is, from the instructions in the ROM image. Called when a ROM is opened.

 dim ok as Boolean
 dim text_at as Integer
 dim code_at as Integer
 dim operand as Integer

 for b as Integer = 1 to mb_regions
  mb_state(b) = 0
  mb_text(b) = mb_orig_text(b)
  mb_limit(b) = mb_orig_limit(b)
  mb_code(b) = 0

  'All the sites of the region must be original or all of them must be ours
  ok = true
  for i as Integer = 1 to mb_site_count
   if mb_site_bank(i) = b then
    operand = MbSnes(mb_orig_text(b)) + mb_site_delta(i)
    if ByteAt(mb_site_at(i)) <> &hBF or MbOperand(mb_site_at(i)) <> operand then ok = false
   end if
  next
  if ok then continue for

  'moved by this editor? the first site (distance 0) gives the place of the data through the routine it jumps to
  ok = false
  for i as Integer = 1 to mb_site_count
   if mb_site_bank(i) = b and mb_site_delta(i) = 0 then
    code_at = MbFileOffset(MbOperand(mb_site_at(i)))
    if code_at >= 0 and code_at + mb_hook_size <= len(ff4rom) and ByteAt(mb_site_at(i)) = &h22 then
     'the first BF of the routine holds the start of the data (k:8000)
     text_at = MbFileOffset(ByteAt(code_at + 8) + ByteAt(code_at + 9) * &h100 + ByteAt(code_at + 10) * &h10000)
     if text_at >= 0 and (text_at - fs_header) mod fs_bank_size = 0 and text_at + &h10000 <= len(ff4rom) then ok = true
    end if
    exit for
   end if
  next
  if ok then
   for i as Integer = 1 to mb_site_count
    if mb_site_bank(i) = b then
     ok = ok and MbHookAt(mb_site_at(i), text_at, mb_site_delta(i))
     ok = ok and MbFileOffset(MbOperand(mb_site_at(i))) = code_at + mb_hook_size * MbDeltaIndex(b, mb_site_delta(i))
    end if
   next
  end if

  if ok then
   mb_state(b) = 1
   mb_text(b) = text_at
   mb_limit(b) = text_at + mb_text_room
   mb_code(b) = code_at
  else
   mb_state(b) = 2
  end if
 next

end sub


sub MbWriteSites(b as Integer)

 'Puts the instructions and routines of a region in the ROM image the way its state says. Unknown regions are left alone.

 dim operand as Integer
 dim code_at as Integer
 dim bytes as String

 if mb_state(b) = 2 then exit sub

 if mb_state(b) = 1 then
  for i as Integer = 0 to mb_delta_count(b) - 1
   bytes = MbHookBytes(mb_text(b), mb_delta(b, i))
   for j as Integer = 1 to mb_hook_size
    WriteByte(mb_code(b) + i * mb_hook_size + j - 1, asc(mid(bytes, j, 1)))
   next
  next
 end if

 for i as Integer = 1 to mb_site_count
  if mb_site_bank(i) = b then
   if mb_state(b) = 1 then
    code_at = mb_code(b) + mb_hook_size * MbDeltaIndex(b, mb_site_delta(i))
    operand = MbSnes(code_at)
    WriteByte(mb_site_at(i), &h22)
   else
    operand = MbSnes(mb_orig_text(b)) + mb_site_delta(i)
    WriteByte(mb_site_at(i), &hBF)
   end if
   WriteByte(mb_site_at(i) + 1, operand and &hFF)
   WriteByte(mb_site_at(i) + 2, (operand shr 8) and &hFF)
   WriteByte(mb_site_at(i) + 3, operand shr 16)
  end if
 next

end sub


function MbRegionName(b as Integer) as String

 select case b
  case 1 to 3: return "Message bank " + str(b)
  case mb_events: return "Events"
  case mb_triggers: return "Triggers"
 end select

 return ""

end function


function MbLocationText(b as Integer) as String

 'Where the data of region b is, for the screens

 select case mb_state(b)
  case 0: return "Stored in the original area of the ROM, " + str(mb_orig_limit(b) - mb_orig_text(b)) + " bytes."
  case 1: return "Stored in the new banks at " + hex(MbSnes(mb_text(b)) shr 16, 2) + ":" + hex(MbSnes(mb_text(b)) and &hFFFF, 4) + ", " + str(mb_text_room) + " bytes."
 end select

 return "Stored where another tool put it: the editor leaves this alone."

end function


function MbCanMove(b as Integer) as String

 'Returns "" if region b can be moved to the new banks, otherwise why not

 if mb_state(b) = 1 then return "That is already in the new banks."
 if mb_state(b) = 2 then return "The game's instructions that read it were changed by another tool."
 if not FsHasTable() then return "Expand the ROM first (Free Space on the main menu)."

 return ""

end function


function MbMove(b as Integer) as String

 'Moves region b to a block of the new banks. Returns "" when done, otherwise why not.
 ' The data itself is written by Save ROM.

 dim reason as String = MbCanMove(b)
 dim code_at as Integer
 dim text_at as Integer

 if reason <> "" then return reason

 code_at = FsAlloc(mb_hook_size * mb_delta_count(b), 2)
 if code_at < 0 then return "There is no room for the routines in the new banks."
 text_at = FsAlloc(&h10000, 2, true, true)
 if text_at < 0 then
  FsRelease(code_at)
  return "There is no room for 64 KB in the new banks. Expand to 4 MB or release blocks."
 end if

 mb_state(b) = 1
 mb_text(b) = text_at
 mb_limit(b) = text_at + mb_text_room
 mb_code(b) = code_at

 return ""

end function


function MbMoveBack(b as Integer) as String

 'Puts region b back in the original area and gives its blocks back. Returns "" when done, otherwise why not.
 ' Save ROM refuses if the data does not fit there.

 if mb_state(b) <> 1 then return "That is not in the new banks."

 FsRelease(mb_text(b))
 FsRelease(mb_code(b))
 mb_state(b) = 0
 mb_text(b) = mb_orig_text(b)
 mb_limit(b) = mb_orig_limit(b)
 mb_code(b) = 0

 return ""

end function


function TriggerMax() as Integer

 'How many triggers all the maps together can have: 979 in the original area, more in the new banks

 return (mb_limit(mb_triggers) - mb_text(mb_triggers)) \ 5

end function
