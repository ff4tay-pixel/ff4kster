'Where the text of message banks 1 to 3 is stored, and moving it to the new banks of an expanded ROM.
'
'The game reads these three banks with "lda long,x" (x is a 16 bit offset from the start of the text). A pointer
'table of 16 bit offsets (kept where it is) says where each message starts. In the SNES address space the sum of
'the base address and x cannot cross out of the bank the text starts in (10:FFFF + 1 is 11:0000, which is not the
'ROM), so the original text can use at most the 32 KB of one bank.
'
'Moving a bank's text to the new banks replaces each of those instructions (BF lo hi bank, 4 bytes) with a
'JSL (22 lo hi bank, the same 4 bytes) to a small routine kept in the new banks:
'
'  php / cpx #$8000 / bcs high / plp / lda long,x (bank k, 8000) / rtl / high: plp / lda long,x (bank k+1, 0000) / rtl
'
'The text starts on a bank boundary (k:8000), x below 8000 reads bank k and x from 8000 on reads bank k+1, so the
'text can be up to 64 KB (offsets up to FFFF). The routine keeps the processor flags, X and Y as the original
'instruction did. The "text minus one" reads of bank 2 get a second routine with the thresholds moved by one.
'
'Nothing else changes: the pointer tables and the 16 bit offsets in them stay as they are. The state is kept in the
'ROM itself (the operands of the instructions), so it is read back by MbDetect when a ROM is opened. A ROM where the
'instructions are anything else (another tool moved the text) is left alone: the editor reads and writes the
'original places as it always did.

const mb_banks = 3
const mb_text_room = &hFFF0 'bytes of text in a moved bank
const mb_hook_size = 18

dim shared mb_orig_text(1 to mb_banks) as Integer
dim shared mb_orig_limit(1 to mb_banks) as Integer
dim shared mb_state(1 to mb_banks) as Integer '0 in the original place, 1 moved by this editor, 2 unknown (left alone)
dim shared mb_text(1 to mb_banks) as Integer 'file offset where the text starts
dim shared mb_limit(1 to mb_banks) as Integer 'file offset the text must stay below
dim shared mb_code(1 to mb_banks) as Integer 'file offset of the routines of a moved bank

mb_orig_text(1) = &h80600: mb_orig_limit(1) = &h881FF
mb_orig_text(2) = &h88500: mb_orig_limit(2) = &h901FB
mb_orig_text(3) = &h9A900: mb_orig_limit(3) = &h9D3FF


'The instructions that read the text: file offsets (header included) of the BF opcode. A site with minus_one set
'reads one byte before the start.
const mb_site_count = 6
dim shared mb_site_bank(1 to mb_site_count) as Integer
dim shared mb_site_at(1 to mb_site_count) as Integer
dim shared mb_site_prev(1 to mb_site_count) as Boolean

mb_site_bank(1) = 1: mb_site_at(1) = &h32D0 + &h200: mb_site_prev(1) = false
mb_site_bank(2) = 2: mb_site_at(2) = &h31A8 + &h200: mb_site_prev(2) = false
mb_site_bank(3) = 2: mb_site_at(3) = &h32C5 + &h200: mb_site_prev(3) = false
mb_site_bank(4) = 2: mb_site_at(4) = &h31AE + &h200: mb_site_prev(4) = true
mb_site_bank(5) = 2: mb_site_at(5) = &h31B6 + &h200: mb_site_prev(5) = true
mb_site_bank(6) = 3: mb_site_at(6) = &h32D7 + &h200: mb_site_prev(6) = false


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


function MbHookBytes(text_at as Integer, prev as Boolean) as String

 'The 18 bytes of the routine for text at that file offset (on a bank boundary)

 dim k as Integer = (text_at - fs_header) \ fs_bank_size
 dim low_window as Integer = k * &h10000 + &h8000
 dim high_window as Integer = (k + 1) * &h10000
 dim limit as Integer = &h8000
 dim result as String

 if prev then
  low_window -= 1
  high_window -= 1
  limit = &h8001
 end if
 result = chr(&h08) + chr(&hE0) + chr(limit and &hFF) + chr(limit shr 8) + chr(&hB0) + chr(&h06) + chr(&h28)
 result += chr(&hBF) + chr(low_window and &hFF) + chr((low_window shr 8) and &hFF) + chr(low_window shr 16) + chr(&h6B)
 result += chr(&h28) + chr(&hBF) + chr(high_window and &hFF) + chr((high_window shr 8) and &hFF) + chr(high_window shr 16) + chr(&h6B)

 return result

end function


function MbHookAt(site as Integer, text_at as Integer, prev as Boolean) as Boolean

 'True if the JSL at that site goes to one of this editor's routines for text at that place. Sets mb_code.

 dim target as Integer = MbFileOffset(MbOperand(site))
 dim expected as String
 dim found as String

 if ByteAt(site) <> &h22 or target < 0 or target + mb_hook_size > len(ff4rom) then return false
 expected = MbHookBytes(text_at, prev)
 found = mid(ff4rom, target + 1, mb_hook_size)

 return found = expected

end function


sub MbDetect()

 'Works out for each bank where its text is, from the instructions in the ROM image. Called when a ROM is opened.

 dim ok as Boolean
 dim site as Integer
 dim text_at as Integer
 dim code_at as Integer
 dim operand as Integer

 for b as Integer = 1 to mb_banks
  mb_state(b) = 0
  mb_text(b) = mb_orig_text(b)
  mb_limit(b) = mb_orig_limit(b)
  mb_code(b) = 0

  'All the sites of the bank must be original or all of them must be ours
  ok = true
  for i as Integer = 1 to mb_site_count
   if mb_site_bank(i) = b then
    operand = MbSnes(mb_orig_text(b))
    if mb_site_prev(i) then operand -= 1
    if ByteAt(mb_site_at(i)) <> &hBF or MbOperand(mb_site_at(i)) <> operand then ok = false
   end if
  next
  if ok then continue for

  'moved by this editor? the first site gives the place of the text through the routine it jumps to
  ok = false
  for i as Integer = 1 to mb_site_count
   if mb_site_bank(i) = b and not mb_site_prev(i) then
    code_at = MbFileOffset(MbOperand(mb_site_at(i)))
    if code_at >= 0 and code_at + mb_hook_size <= len(ff4rom) and ByteAt(mb_site_at(i)) = &h22 then
     'the first BF of the routine holds the start of the text (k:8000)
     text_at = MbFileOffset(ByteAt(code_at + 8) + ByteAt(code_at + 9) * &h100 + ByteAt(code_at + 10) * &h10000)
     if text_at >= 0 and (text_at - fs_header) mod fs_bank_size = 0 and text_at + &h10000 <= len(ff4rom) then ok = true
    end if
    exit for
   end if
  next
  if ok then
   for i as Integer = 1 to mb_site_count
    if mb_site_bank(i) = b then
     if mb_site_prev(i) then
      ok = ok and MbHookAt(mb_site_at(i), text_at, true) and MbFileOffset(MbOperand(mb_site_at(i))) = code_at + mb_hook_size
     else
      ok = ok and MbHookAt(mb_site_at(i), text_at, false) and MbFileOffset(MbOperand(mb_site_at(i))) = code_at
     end if
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

 'Puts the instructions and routines of a bank in the ROM image the way its state says. Unknown banks are left alone.

 dim operand as Integer
 dim code_at as Integer

 if mb_state(b) = 2 then exit sub

 if mb_state(b) = 1 then
  for i as Integer = 0 to 1
   for j as Integer = 1 to mb_hook_size
    WriteByte(mb_code(b) + i * mb_hook_size + j - 1, asc(mid(MbHookBytes(mb_text(b), i = 1), j, 1)))
   next
  next
 end if

 for i as Integer = 1 to mb_site_count
  if mb_site_bank(i) = b then
   if mb_state(b) = 1 then
    code_at = mb_code(b)
    if mb_site_prev(i) then code_at += mb_hook_size
    operand = MbSnes(code_at)
    WriteByte(mb_site_at(i), &h22)
   else
    operand = MbSnes(mb_orig_text(b))
    if mb_site_prev(i) then operand -= 1
    WriteByte(mb_site_at(i), &hBF)
   end if
   WriteByte(mb_site_at(i) + 1, operand and &hFF)
   WriteByte(mb_site_at(i) + 2, (operand shr 8) and &hFF)
   WriteByte(mb_site_at(i) + 3, operand shr 16)
  end if
 next

end sub


function MbLocationText(b as Integer) as String

 'Where the text of bank b is, for the screens

 select case mb_state(b)
  case 0: return "Stored in the original area of the ROM, " + str(mb_orig_limit(b) - mb_orig_text(b)) + " bytes."
  case 1: return "Stored in the new banks at " + hex(MbSnes(mb_text(b)) shr 16, 2) + ":" + hex(MbSnes(mb_text(b)) and &hFFFF, 4) + ", " + str(mb_text_room) + " bytes."
 end select

 return "Stored where another tool put it: the editor leaves this alone."

end function


function MbCanMove(b as Integer) as String

 'Returns "" if bank b can be moved to the new banks, otherwise why not

 if mb_state(b) = 1 then return "That bank is already in the new banks."
 if mb_state(b) = 2 then return "The game's text instructions for that bank were changed by another tool."
 if not FsHasTable() then return "Expand the ROM first (Free Space on the main menu)."

 return ""

end function


function MbMove(b as Integer) as String

 'Moves the text of bank b to a block of the new banks. Returns "" when done, otherwise why not.
 ' The text itself is written by Save ROM.

 dim reason as String = MbCanMove(b)
 dim code_at as Integer
 dim text_at as Integer

 if reason <> "" then return reason

 code_at = FsAlloc(mb_hook_size * 2, 2)
 if code_at < 0 then return "There is no room for the routines in the new banks."
 text_at = FsAlloc(&h10000, 2, true, true)
 if text_at < 0 then
  FsRelease(code_at)
  return "There is no room for 64 KB of text in the new banks. Expand to 4 MB or release blocks."
 end if

 mb_state(b) = 1
 mb_text(b) = text_at
 mb_limit(b) = text_at + mb_text_room
 mb_code(b) = code_at

 return ""

end function


function MbMoveBack(b as Integer) as String

 'Puts the text of bank b back in the original area and gives its blocks back. Returns "" when done, otherwise why not.
 ' Save ROM refuses if the messages do not fit there.

 if mb_state(b) <> 1 then return "That bank is not in the new banks."

 FsRelease(mb_text(b))
 FsRelease(mb_code(b))
 mb_state(b) = 0
 mb_text(b) = mb_orig_text(b)
 mb_limit(b) = mb_orig_limit(b)
 mb_code(b) = 0

 return ""

end function
