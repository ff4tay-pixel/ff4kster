'More room for monster pictures: three extra picture banks in the new banks of an expanded ROM.
'
'A monster's graphics pointer (two bytes) says where its tiles are: bit 15 is set for 3 bits per pixel, bits 12 to 14
'pick a bank (the game adds them to bank 09, so 09 to 10), and the low 12 bits times 8 are the offset in that bank.
'Only banks 09 to 0C hold monster pictures, and they are full. Banks 0D to 10 hold other data, apart from a few
'runs of FF bytes the stored pictures use (monsterpictures.bas).
'
'Moving makes the game read pointer banks 5, 6 and 7 from three new banks instead of 0E, 0F and 10 (nothing
'uses those three as pictures). The seven bytes in LoadMonsterGfx that shift the bank bits and add 09
'(4A 4A 4A 4A 18 69 09: lsr four times, clc, adc #$09) become a JSL to a 16 byte routine in the new banks:
'
'  lsr x4 / cmp #5 / bcs high / clc / adc #$09 / rtl / high: clc / adc #(new bank - 5) / rtl   (and three NOPs)
'
'Banks 0 to 4 keep working as before, so nothing already in the ROM moves and the stored pictures in bank 0D
'(index 4) stay where they are. The new room is 96 KB, in three banks that start on a bank boundary.
'
'The state is in the ROM (the bytes of the instruction), read back by MgDetect when a ROM is opened. If those bytes
'are anything else (another tool changed them) the editor leaves them alone.

const mg_site = &h11014 + &h200 + 2 'file offset of the 4A 4A 4A 4A 18 69 09 in LoadMonsterGfx
const mg_hook_size = 16
const mg_first_bank = 5 'pointer banks 5 to 7 move
const mg_bank_count = 3

dim shared mg_state as Integer '0 original, 1 moved by this editor, 2 unknown (left alone)
dim shared mg_block as Integer 'file offset of the three new banks (a bank boundary), when moved
dim shared mg_code as Integer 'file offset of the routine, when moved


function MgOriginalBytes() as String

 return chr(&h4A) + chr(&h4A) + chr(&h4A) + chr(&h4A) + chr(&h18) + chr(&h69) + chr(&h09)

end function


function MgHookBytes(new_bank as Integer) as String

 return chr(&h4A) + chr(&h4A) + chr(&h4A) + chr(&h4A) + chr(&hC9) + chr(mg_first_bank) + chr(&hB0) + chr(&h04) + _
  chr(&h18) + chr(&h69) + chr(&h09) + chr(&h6B) + chr(&h18) + chr(&h69) + chr(new_bank - mg_first_bank) + chr(&h6B)

end function


sub MgDetect()

 'Reads from the ROM image where the extra picture banks are

 dim target as Integer
 dim new_bank as Integer

 mg_state = 0
 mg_block = 0
 mg_code = 0

 if mid(ff4rom, mg_site + 1, 7) = MgOriginalBytes() then exit sub

 mg_state = 2
 if ByteAt(mg_site) <> &h22 or ByteAt(mg_site + 4) <> &hEA or ByteAt(mg_site + 5) <> &hEA or ByteAt(mg_site + 6) <> &hEA then exit sub
 target = MbFileOffset(MbOperand(mg_site - 0))
 if target < 0 or target + mg_hook_size > len(ff4rom) then exit sub
 new_bank = ByteAt(target + 14) + mg_first_bank
 if mid(ff4rom, target + 1, mg_hook_size) <> MgHookBytes(new_bank) then exit sub
 if (new_bank + mg_bank_count) * fs_bank_size + fs_header > len(ff4rom) then exit sub

 mg_state = 1
 mg_block = new_bank * fs_bank_size + fs_header
 mg_code = target

end sub


sub MgWriteSite()

 'Puts the instruction and the routine in the ROM image the way the state says

 dim operand as Integer
 dim bytes as String

 if mg_state = 2 then exit sub

 if mg_state = 0 then
  bytes = MgOriginalBytes()
 else
  bytes = MgHookBytes((mg_block - fs_header) \ fs_bank_size)
  for i as Integer = 1 to mg_hook_size
   WriteByte(mg_code + i - 1, asc(mid(bytes, i, 1)))
  next
  operand = MbSnes(mg_code)
  bytes = chr(&h22) + chr(operand and &hFF) + chr((operand shr 8) and &hFF) + chr(operand shr 16) + chr(&hEA) + chr(&hEA) + chr(&hEA)
 end if
 for i as Integer = 1 to 7
  WriteByte(mg_site + i - 1, asc(mid(bytes, i, 1)))
 next

end sub


function MgLocationText() as String

 select case mg_state
  case 0: return "Pictures only in the original banks. Moving adds 96 KB of room in the new banks."
  case 1: return "Three extra picture banks at " + hex((mg_block - fs_header) \ fs_bank_size, 2) + " to " + hex((mg_block - fs_header) \ fs_bank_size + 2, 2) + ", 96 KB."
 end select

 return "The game's picture bank instruction was changed by another tool."

end function


function MgPointerBank(gfx_ptr as Integer) as Integer

 return (gfx_ptr shr 12) and 7

end function


function MgUsers() as Integer

 'Monsters whose graphics pointer is in one of the extra banks

 dim total as Integer

 for m as Integer = 1 to total_monsters
  if MgPointerBank(monsters(m).gfx_ptr1 + monsters(m).gfx_ptr2 * &h100) >= mg_first_bank then total += 1
 next

 return total

end function


function MgMove() as String

 'Moves banks 5 to 7 of the monster pictures to the new banks. Returns "" when done, otherwise why not.

 dim code_at as Integer
 dim block_at as Integer

 if mg_state = 1 then return "That is already in the new banks."
 if mg_state = 2 then return "The game's picture bank instruction was changed by another tool."
 if not FsHasTable() then return "Expand the ROM first (Free Space on the main menu)."
 if MgUsers() > 0 then return str(MgUsers()) + " monsters use picture bank 5, 6 or 7 of the original ROM. Point them elsewhere first."

 code_at = FsAlloc(mg_hook_size, 6)
 if code_at < 0 then return "There is no room for the routine in the new banks."
 block_at = FsAlloc(mg_bank_count * fs_bank_size, 6, true, true)
 if block_at < 0 then
  FsRelease(code_at)
  return "There is no room for 96 KB in the new banks. Expand to 4 MB or release blocks."
 end if

 mg_state = 1
 mg_block = block_at
 mg_code = code_at

 return ""

end function


function MgMoveBack() as String

 'Back to the original banks. Refused while a monster or a stored picture uses the extra banks.

 if mg_state <> 1 then return "That is not in the new banks."
 if MgUsers() > 0 then return str(MgUsers()) + " monsters use the extra picture banks. Point them elsewhere first."

 FsRelease(mg_block)
 FsRelease(mg_code)
 mg_state = 0
 mg_block = 0
 mg_code = 0

 return ""

end function
