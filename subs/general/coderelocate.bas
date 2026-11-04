'Copying a routine of the game to the new banks.
'
'A command of the game is a routine in bank 03 that was written for that bank. A copy in another bank has to change every
'instruction that depends on the bank it runs in:
'
'  JSR abs   to a routine of bank 03   -> JSL to a thunk of 4 bytes in bank 03 (JSR and RTL), see commandcode.bas
'  JSR abs   to a routine that is part of the copy (a private subroutine) -> JSR to its new address
'  JMP abs   outside the copy          -> JML to the same address in bank 03
'  JMP abs   inside the copy           -> JMP to the new address
'  RTS       at the end of the routine -> JML to an RTS in bank 03 (returns to the caller of the command)
'  branches  recomputed, because the instructions above change size
'
'Everything else is copied as it is: the data bank is not changed by running in another bank, so absolute addresses of RAM
'and the long addresses of tables are the same. The routine is found by following the flow from its first byte (with the
'size of the immediate operands that follows REP and SEP), so unreachable bytes (data in the middle of the code) are not
'copied. Routines that use something that depends on the bank (indirect jumps, PHK, PER, PEA, PLP, XCE, RTI, RTL, BRL) are
'refused.
'
'RelocAnalyze reads a routine and RelocSize says how long the copy is. RelocMap says where a byte of the original is in
'the copy (for the settings of the routine, which are immediate operands of the instructions that stay as they are), and
'RelocEmit writes the copy for a block that starts at an address.

const reloc_window = &h400 'the routine and its private subroutines are within this many bytes of the first byte
const reloc_max = 700

dim shared reloc_entry as Integer 'file offset of the first byte
dim shared reloc_count as Integer
dim shared reloc_error as String
dim shared reloc_size as Integer
dim shared reloc_off(0 to reloc_max) as Integer
dim shared reloc_len(0 to reloc_max) as Integer
dim shared reloc_kind(0 to reloc_max) as Integer '0 copied, 1 JSR out, 2 JSR in, 3 JMP out, 4 JMP in, 5 RTS at the end, 6 branch, 7 RTS of a subroutine
dim shared reloc_target(0 to reloc_max) as Integer 'file offset of the target of a jump, call or branch
dim shared reloc_ctx(0 to reloc_max) as Integer '0 for the routine, the first byte of the subroutine it belongs to
dim shared reloc_stop(0 to reloc_max) as Boolean 'the flow does not go on to the next instruction
dim shared reloc_pos(0 to reloc_max) as Integer 'position in the copy
dim shared reloc_at(0 to reloc_window - 1) as Integer 'instruction number that starts at a byte, -1 none, -2 inside an instruction
dim shared reloc_map(0 to reloc_window - 1) as Integer 'position in the copy of each byte of the original, -1 none
dim shared reloc_order(0 to reloc_max) as Integer
dim shared reloc_lengths as String
reloc_lengths = "222222221M113334" + "2222222213113334" + "324222221M113334" + "2222222213113334" + _
 "122232221M113334" + "2222322213114334" + "123222221M113334" + "2222222213113334" + _
 "223222221M113334" + "2222222213113334" + "X2X222221M113334" + "2222222213113334" + _
 "X22222221M113334" + "2222222213113334" + "X22222221M113334" + "2222322213113334"


function RelocBankBase(file_offset as Integer) as Integer

 'File offset of the start of the bank (header included) that a file offset is in

 return ((file_offset - fs_header) \ fs_bank_size) * fs_bank_size + fs_header

end function


function RelocLength(op as Integer, m as Integer, x as Integer) as Integer

 dim c as String = mid(reloc_lengths, op + 1, 1)

 if c = "M" then
  if m = 1 then return 2 else return 3
 end if
 if c = "X" then
  if x = 1 then return 2 else return 3
 end if

 return val(c)

end function


function RelocAnalyze(entry as Integer) as Boolean

 'Follows the routine from its first byte. False (and reloc_error) if it cannot be copied.

 dim stack_off(0 to 255) as Integer
 dim stack_m(0 to 255) as Integer
 dim stack_x(0 to 255) as Integer
 dim stack_ctx(0 to 255) as Integer
 dim sp as Integer
 dim off as Integer
 dim m as Integer
 dim x as Integer
 dim ctx as Integer
 dim op as Integer
 dim length as Integer
 dim rel as Integer
 dim target as Integer
 dim addr as Integer
 dim n as Integer
 dim imm as Integer
 dim bank_base as Integer

 reloc_entry = entry
 reloc_count = 0
 reloc_error = ""
 reloc_size = 0
 bank_base = RelocBankBase(entry)
 for i as Integer = 0 to reloc_window - 1
  reloc_at(i) = -1
  reloc_map(i) = -1
 next

 stack_off(0) = entry: stack_m(0) = 1: stack_x(0) = 0: stack_ctx(0) = 0
 sp = 1

 do while sp > 0
  sp -= 1
  off = stack_off(sp): m = stack_m(sp): x = stack_x(sp): ctx = stack_ctx(sp)

  do
   rel = off - entry
   if rel < 0 or rel >= reloc_window - 4 then
    reloc_error = "The routine goes outside its own area."
    return false
   end if
   if reloc_at(rel) <> -1 then
    if reloc_at(rel) = -2 then
     reloc_error = "A jump lands inside an instruction."
     return false
    end if
    if reloc_ctx(reloc_at(rel)) <> ctx then
     reloc_error = "A part of the routine is used by the routine and by a subroutine."
     return false
    end if
    exit do
   end if

   if reloc_count >= reloc_max then
    reloc_error = "The routine is too long."
    return false
   end if
   op = ByteAt(off)
   length = RelocLength(op, m, x)
   n = reloc_count
   reloc_count += 1
   reloc_off(n) = off
   reloc_len(n) = length
   reloc_kind(n) = 0
   reloc_target(n) = 0
   reloc_ctx(n) = ctx
   reloc_stop(n) = false
   for j as Integer = 0 to length - 1
    if rel + j >= reloc_window or reloc_at(rel + j) <> -1 then
     reloc_error = "Instructions overlap."
     return false
    end if
    if j = 0 then reloc_at(rel) = n else reloc_at(rel + j) = -2
   next

   select case op
    case &h10, &h30, &h50, &h70, &h90, &hB0, &hD0, &hF0, &h80
     target = off + 2 + ByteAt(off + 1)
     if ByteAt(off + 1) >= &h80 then target -= &h100
     reloc_kind(n) = 6
     reloc_target(n) = target
     if sp > 250 then
      reloc_error = "Too many branches."
      return false
     end if
     stack_off(sp) = target: stack_m(sp) = m: stack_x(sp) = x: stack_ctx(sp) = ctx
     sp += 1
     if op = &h80 then reloc_stop(n) = true
    case &h4C
     addr = ByteAt(off + 1) + ByteAt(off + 2) * &h100
     if addr < &h8000 then
      reloc_error = "A jump to an address outside the ROM."
      return false
     end if
     target = bank_base + addr - &h8000
     reloc_stop(n) = true
     reloc_target(n) = target
     if target >= entry and target < entry + reloc_window - 4 then
      reloc_kind(n) = 4
      stack_off(sp) = target: stack_m(sp) = m: stack_x(sp) = x: stack_ctx(sp) = ctx
      sp += 1
     else
      reloc_kind(n) = 3
     end if
    case &h20
     addr = ByteAt(off + 1) + ByteAt(off + 2) * &h100
     if addr < &h8000 then
      reloc_error = "A call to an address outside the ROM."
      return false
     end if
     target = bank_base + addr - &h8000
     reloc_target(n) = target
     if target >= entry and target < entry + reloc_window - 4 then
      reloc_kind(n) = 2
      stack_off(sp) = target: stack_m(sp) = m: stack_x(sp) = x: stack_ctx(sp) = target
      sp += 1
     else
      reloc_kind(n) = 1
     end if
    case &h60
     reloc_stop(n) = true
     if ctx = 0 then reloc_kind(n) = 5 else reloc_kind(n) = 7
    case &h5C
     reloc_stop(n) = true
    case &h6B, &h40, &h6C, &h7C, &hDC, &hFC, &h4B, &h62, &hF4, &h28, &hFB, &h82
     reloc_error = "The routine uses an instruction that depends on the bank (" + hex(op, 2) + " at " + hex(off, 5) + ")."
     return false
    case &hC2
     imm = ByteAt(off + 1)
     if (imm and &h20) <> 0 then m = 0
     if (imm and &h10) <> 0 then x = 0
    case &hE2
     imm = ByteAt(off + 1)
     if (imm and &h20) <> 0 then m = 1
     if (imm and &h10) <> 0 then x = 1
   end select

   if reloc_stop(n) then exit do
   off += length
  loop
 loop

 'the layout: in the order of the original, the size of each instruction in the copy
 for i as Integer = 0 to reloc_count - 1
  reloc_order(i) = i
 next
 for i as Integer = 1 to reloc_count - 1
  n = reloc_order(i)
  dim j as Integer = i - 1
  do while j >= 0
   if reloc_off(reloc_order(j)) <= reloc_off(n) then exit do
   reloc_order(j + 1) = reloc_order(j)
   j -= 1
  loop
  reloc_order(j + 1) = n
 next

 dim at_pos as Integer = 0
 dim previous as Integer = -1
 for i as Integer = 0 to reloc_count - 1
  n = reloc_order(i)
  if previous >= 0 then
   if not reloc_stop(previous) and reloc_off(previous) + reloc_len(previous) <> reloc_off(n) then
    reloc_error = "The flow of the routine runs into something that is not code."
    return false
   end if
  end if
  reloc_pos(n) = at_pos
  select case reloc_kind(n)
   case 1, 3, 5
    length = 4
   case 2, 4
    length = 3
   case else
    length = reloc_len(n)
  end select
  rel = reloc_off(n) - entry
  if reloc_kind(n) = 0 or reloc_kind(n) = 6 or reloc_kind(n) = 7 then
   for j as Integer = 0 to reloc_len(n) - 1
    reloc_map(rel + j) = at_pos + j
   next
  else
   reloc_map(rel) = at_pos
  end if
  at_pos += length
  previous = n
 next
 reloc_size = at_pos

 'the branches
 for i as Integer = 0 to reloc_count - 1
  if reloc_kind(i) = 6 then
   target = reloc_pos(reloc_at(reloc_target(i) - entry)) - (reloc_pos(i) + 2)
   if target < -128 or target > 127 then
    reloc_error = "A branch is too far in the copy."
    return false
   end if
  end if
 next

 return true

end function


function RelocMapOffset(old_offset as Integer) as Integer

 'Where a byte of the original is in the copy, -1 if it is not there as it was

 dim rel as Integer = old_offset - reloc_entry

 if rel < 0 or rel >= reloc_window then return -1

 return reloc_map(rel)

end function

declare function CcThunkSnes(target as Integer) as Integer

dim shared reloc_over_at(0 to 3) as Integer 'calls whose target is another one (the settings that pick a routine)
dim shared reloc_over_to(0 to 3) as Integer
dim shared reloc_over_n as Integer


function RelocEmit(base_snes as Integer, old_id as Integer, new_id as Integer) as String

 'The copy, for a block that starts at the address base_snes (bank * 65536 + address, as MbSnes gives it)

 dim result as String
 dim n as Integer
 dim op as Integer
 dim target16 as Integer
 dim snes as Integer
 dim new_target as Integer
 dim wanted as Integer
 dim bank_base as Integer = RelocBankBase(reloc_entry)
 dim bank as Integer = (bank_base - fs_header) \ fs_bank_size

 for i as Integer = 0 to reloc_count - 1
  n = reloc_order(i)
  op = ByteAt(reloc_off(n))
  select case reloc_kind(n)
   case 0, 7
    for j as Integer = 0 to reloc_len(n) - 1
     result += chr(ByteAt(reloc_off(n) + j))
    next
    'lda #command, sta $34c8: the number that the banner takes the name of
    if op = &hA9 and reloc_len(n) = 2 and ByteAt(reloc_off(n) + 1) = old_id and ByteAt(reloc_off(n) + 2) = &h8D and ByteAt(reloc_off(n) + 3) = &hC8 and ByteAt(reloc_off(n) + 4) = &h34 then
     result = left(result, len(result) - 1) + chr(new_id)
    end if
   case 1
    target16 = &h8000 + reloc_target(n) - bank_base
    for k as Integer = 0 to reloc_over_n - 1
     if reloc_over_at(k) = reloc_off(n) then target16 = reloc_over_to(k)
    next
    snes = CcThunkSnes(target16)
    if snes < 0 then return ""
    result += chr(&h22) + chr(snes and &hFF) + chr((snes shr 8) and &hFF) + chr(snes shr 16)
   case 2
    new_target = (base_snes and &hFFFF) + reloc_pos(reloc_at(reloc_target(n) - reloc_entry))
    result += chr(&h20) + chr(new_target and &hFF) + chr(new_target shr 8)
   case 3
    target16 = &h8000 + reloc_target(n) - bank_base
    result += chr(&h5C) + chr(target16 and &hFF) + chr(target16 shr 8) + chr(bank)
   case 4
    new_target = (base_snes and &hFFFF) + reloc_pos(reloc_at(reloc_target(n) - reloc_entry))
    result += chr(&h4C) + chr(new_target and &hFF) + chr(new_target shr 8)
   case 5
    snes = CcThunkSnes(&h10000)
    if snes < 0 then return ""
    result += chr(&h5C) + chr(snes and &hFF) + chr((snes shr 8) and &hFF) + chr(snes shr 16)
   case 6
    wanted = reloc_pos(reloc_at(reloc_target(n) - reloc_entry)) - (reloc_pos(n) + 2)
    result += chr(op) + chr(wanted and &hFF)
  end select
 next

 return result

end function
