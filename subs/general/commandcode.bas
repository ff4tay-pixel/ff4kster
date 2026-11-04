'Commands with code of their own: a new command (editor 38 to 53) can have its own copy of the routine of Boast or Cry,
'so that its stat, amount, limit, message and targets do not change the original command.
'
'The game runs a command with "jml [$80]" into bank 03 (the pointer table has 16 bit addresses and the bank is always 3),
'and the routine ends with a jump to AddMsg2 in bank 03. The new banks are other banks, so
'
'  - the pointer of the command points at a thunk of 4 bytes in the unused bytes at the end of bank 03 (03:F210, FF in the
'    original ROM): JML to the routine in the new banks,
'  - the routine is written for the new banks by this file (the same bytes as the original with each jump to bank 03 made
'    long and each call (JSR) made a JSL to a thunk of 4 bytes, JSR and RTL, in the same unused bytes; the end of a routine
'    that returns with RTS jumps to an RTS in those bytes).
'
'A routine is recognised when a ROM is opened by building it again from the settings that were read and comparing.
'The first thunk is slot 0 for command 38. The thunk for SelectObj follows the 16 slots.

const cc_area = &h1F410 'file offset (header included) of the unused bytes at the end of bank 03
const cc_slots = 16
const cc_call_at = cc_area + cc_slots * 4
const cc_calls = 6 'thunks after the slots: JSR and RTL for each routine the copies call, and an RTS
const cc_block_size = 72
const cc_owner = 12
const cc_add_msg2 = &h85A6 'AddMsg2 in bank 03
const cc_select_obj = &h8489 'SelectObj in bank 03
const cc_call_select_obj = 0 'the thunks, in the order they are in the unused bytes
const cc_call_magic = 1 'DoMagicAttack after its first three instructions (cd3e)
const cc_call_msg3 = 2
const cc_call_rand = 3
const cc_call_msg2 = 4
const cc_call_rts = 5 'a single RTS: the copies end with a jump to it

dim shared cc_ok as Boolean 'the unused bytes are what this file expects
dim shared cc_block(1 to cc_slots) as Integer 'file offset of the routine of each new command that has its own, 0 if none


function CcSlotOffset(index as Integer) as Integer

 return cc_area + (index - cb_first_extra) * 4

end function


function CcBytesAt(file_offset as Integer, n as Integer) as String

 return mid(ff4rom, file_offset + 1, n)

end function


function CcIsBlank(file_offset as Integer, n as Integer) as Boolean

 for i as Integer = 0 to n - 1
  if ByteAt(file_offset + i) <> &hFF then return false
 next

 return true

end function


function CcCallThunk(n as Integer) as String

 'The thunk of 4 bytes: JSR to a routine of bank 03 and RTL (the last one is RTS and padding)

 dim target as Integer

 select case n
  case cc_call_select_obj: target = cc_select_obj
  case cc_call_magic: target = &hCD3E
  case cc_call_msg3: target = &h85B1
  case cc_call_rand: target = &h8593
  case cc_call_msg2: target = cc_add_msg2
  case else: return chr(&h60) + chr(&hEA) + chr(&hEA) + chr(&hEA)
 end select

 return chr(&h20) + chr(target and &hFF) + chr(target shr 8) + chr(&h6B)

end function


function CcJsl(n as Integer) as String

 'JSL to the thunk n (JSR of the original code)

 dim snes as Integer = MbSnes(cc_call_at + n * 4)

 return chr(&h22) + chr(snes and &hFF) + chr((snes shr 8) and &hFF) + chr(snes shr 16)

end function


function CcJmlRts() as String

 dim snes as Integer = MbSnes(cc_call_at + cc_call_rts * 4)

 return chr(&h5C) + chr(snes and &hFF) + chr((snes shr 8) and &hFF) + chr(snes shr 16)

end function


function CcAvailable() as Boolean

 return cb_state = 1 and cc_ok and FsHasTable()

end function


function CcHex(value as Integer) as String

 return right("0" + hex(value and &hFF), 2)

end function


function CcFromHex(h as String) as String

 dim result as String

 for i as Integer = 0 to len(h) \ 2 - 1
  result += chr(val("&h" + mid(h, i * 2 + 1, 2)))
 next

 return result

end function


function CcBuild(c as MenuCommand, index as Integer) as String

 'The bytes of the routine of a command that has its own copy of Boast (own_kind 18) or Cry (19). "" if it is not one.

 dim head as String
 dim message_part as String
 dim finish as String = CcFromHex("5C") + chr(cc_add_msg2 and &hFF) + chr(cc_add_msg2 shr 8) + chr(3)
 dim first as Integer
 dim last as Integer

 head = CcFromHex("A9") + chr(index - 1) + CcFromHex("8DC834A9108DC734A6A6") 'lda #id, sta $34c8, lda #$10, sta $34c7, ldx $a6
 if c.message(1) = &hFF then
  message_part = CcFromHex("A9FFEAEAEA")
 else
  message_part = CcFromHex("A9") + chr(c.message(1)) + CcFromHex("8DCA34")
 end if

 if c.own_kind = 18 then
  return head + CcFromHex(MenuCommand.ReverseBytes(18, 1, c.reversed)) + CcFromHex("BD") + chr(c.misc_bytes(1)) + CcFromHex("20") + _
   CcFromHex(MenuCommand.ReverseBytes(18, 2, c.reversed)) + chr(c.misc_bytes(2)) + CcFromHex(MenuCommand.ReverseBytes(18, 3, c.reversed, c.reverse_limit)) + _
   CcFromHex("9D") + chr(c.misc_bytes(1)) + CcFromHex("20") + message_part + finish
 end if

 if c.own_kind = 19 then
  if c.cry_allies then
   first = 0
   last = 5
  else
   first = 5
   last = 13
  end if
  return head + CcFromHex("BD") + chr(c.misc_bytes(1)) + CcFromHex("204A85A9A2") + chr(first) + CcFromHex("0086ABA6ABBD4035D0168A") + CcJsl(cc_call_select_obj) + _
   CcFromHex("A6A6") + CcFromHex(MenuCommand.ReverseBytes(19, 1, c.reversed)) + CcFromHex("BD") + chr(c.misc_bytes(2)) + CcFromHex("20") + _
   CcFromHex(MenuCommand.ReverseBytes(19, 2, c.reversed)) + CcFromHex(MenuCommand.ReverseBytes(19, 3, c.reversed, c.reverse_limit)) + _
   CcFromHex("9D") + chr(c.misc_bytes(2)) + CcFromHex("20E6ABA5ABC9") + chr(last) + CcFromHex("D0DB") + message_part + finish
 end if

 'Pray: Rand, fails at the chance or above (message only), else casts the spell
 if c.own_kind = 12 then
  return CcJsl(cc_call_rand) + CcFromHex("C9") + chr(c.success(1)) + CcFromHex("900B") + CcJsl(cc_call_msg2) + message_part + CcFromHex("8009A9") + chr(c.spell(1)) + _
   CcFromHex("8DD226") + CcJsl(cc_call_magic) + CcFromHex("A9") + chr(index - 1) + CcFromHex("8DC834A9108DC734") + CcJmlRts()
 end if

 'Bear: casts the spell, then shows the message
 if c.own_kind = 16 then
  return CcFromHex("A9") + chr(c.spell(1)) + CcFromHex("8DD2269CC433") + CcJsl(cc_call_magic) + CcJsl(cc_call_msg3) + message_part + CcFromHex("A9") + chr(index - 1) + _
   CcFromHex("8DC834A9108DC734") + CcJmlRts()
 end if

 return ""

end function


function CcParse(code as String, index as Integer, byref c as MenuCommand) as Boolean

 'Reads the settings out of the routine and checks that building it again gives the same bytes

 dim t as MenuCommand = c
 dim n as Integer = len(code)

 t.cry_known = true
 t.reverse_known = true

 'Boast
 if n = 36 and asc(mid(code, 14, 1)) = &hBD then
  t.own_kind = 18
  t.reversed = (asc(mid(code, 13, 1)) = &h38)
  t.misc_bytes(1) = asc(mid(code, 15, 1))
  t.misc_bytes(2) = asc(mid(code, 18, 1))
  t.reverse_limit = asc(mid(code, 19 + MenuCommand.ReverseLimitPos(18, t.reversed), 1))
  t.message(1) = asc(mid(code, 29, 1))
  if CcBuild(t, index) = code then
   c = t
   return true
  end if
 end if

 'Cry
 if n = 69 and asc(mid(code, 13, 1)) = &hBD then
  t.own_kind = 19
  t.misc_bytes(1) = asc(mid(code, 14, 1))
  t.cry_allies = (asc(mid(code, 20, 1)) = 0)
  t.reversed = (asc(mid(code, 38, 1)) = &h18)
  t.misc_bytes(2) = asc(mid(code, 40, 1))
  t.reverse_limit = asc(mid(code, 44 + MenuCommand.ReverseLimitPos(19, t.reversed), 1))
  t.message(1) = asc(mid(code, 62, 1))
  if CcBuild(t, index) = code then
   c = t
   return true
  end if
 end if

 'Pray
 if n = 42 then
  t.own_kind = 12
  t.success(1) = asc(mid(code, 6, 1))
  t.message(1) = asc(mid(code, 14, 1))
  t.spell(1) = asc(mid(code, 21, 1))
  if CcBuild(t, index) = code then
   c = t
   return true
  end if
 end if

 'Bear
 if n = 35 then
  t.own_kind = 16
  t.spell(1) = asc(mid(code, 2, 1))
  t.message(1) = asc(mid(code, 18, 1))
  if CcBuild(t, index) = code then
   c = t
   return true
  end if
 end if

 return false

end function


function CcRead(byref c as MenuCommand, index as Integer) as Boolean

 'Whether the command has its own routine; fills in its settings if it does.

 dim thunk as String
 dim target as Integer
 dim slot as Integer
 dim code as String
 dim lengths(1 to 4) as Integer = {35, 36, 42, 69}

 if not CbIsNew(index) or not cc_ok then return false
 if cb_state <> 1 then return false

 slot = CcSlotOffset(index)
 thunk = CcBytesAt(slot, 4)
 if asc(mid(thunk, 1, 1)) <> &h5C then return false
 if ByteAt(cb_at(6) + (index - 1) * 2) <> (MbSnes(slot) and &hFF) or ByteAt(cb_at(6) + (index - 1) * 2 + 1) <> ((MbSnes(slot) shr 8) and &hFF) then return false
 target = MbFileOffset(asc(mid(thunk, 2, 1)) + asc(mid(thunk, 3, 1)) * &h100 + asc(mid(thunk, 4, 1)) * &h10000)
 if target < fs_header + fs_original_size or target + cc_block_size > len(ff4rom) then return false

 for n as Integer = 1 to 4
  code = CcBytesAt(target, lengths(n))
  if CcParse(code, index, c) then
   cc_block(index - cb_first_extra + 1) = target
   c.behaves_like = 0
   c.behaves_known = true
   return true
  end if
 next

 return false

end function


sub CcDetect()

 'Whether the unused bytes of bank 03 can be used, and forgets the blocks of the last ROM

 cc_ok = true
 for k as Integer = 1 to cc_slots
  cc_block(k) = 0
  if not CcIsBlank(cc_area + (k - 1) * 4, 4) then
   if ByteAt(cc_area + (k - 1) * 4) <> &h5C then cc_ok = false
  end if
 next
 for n as Integer = 0 to cc_calls - 1
  if not CcIsBlank(cc_call_at + n * 4, 4) then
   if CcBytesAt(cc_call_at + n * 4, 4) <> CcCallThunk(n) then cc_ok = false
  end if
 next

end sub


function CcNeedBlock(index as Integer) as Boolean

 'Makes sure the new command has a block for its routine. False if there is no room.

 dim k as Integer = index - cb_first_extra + 1

 if cc_block(k) > 0 then return true
 cc_block(k) = FsAlloc(cc_block_size, cc_owner)
 if cc_block(k) < 0 then
  cc_block(k) = 0
  return false
 end if

 return true

end function


sub CcRelease(index as Integer)

 'The command has no routine of its own any more

 dim k as Integer = index - cb_first_extra + 1

 if cc_block(k) > 0 then FsRelease(cc_block(k))
 cc_block(k) = 0

end sub


sub CcWrite(c as MenuCommand, index as Integer)

 'Writes the routine, its thunk and the pointers of the command

 dim k as Integer = index - cb_first_extra + 1
 dim code as String = CcBuild(c, index)
 dim snes as Integer
 dim slot as Integer = CcSlotOffset(index)

 if cc_block(k) <= 0 or code = "" then exit sub

 for i as Integer = 0 to cc_block_size - 1
  if i < len(code) then WriteByte(cc_block(k) + i, asc(mid(code, i + 1, 1))) else WriteByte(cc_block(k) + i, &hFF)
 next
 snes = MbSnes(cc_block(k))
 WriteByte(slot, &h5C)
 WriteByte(slot + 1, snes and &hFF)
 WriteByte(slot + 2, (snes shr 8) and &hFF)
 WriteByte(slot + 3, snes shr 16)
 for n as Integer = 0 to cc_calls - 1
  for i as Integer = 1 to 4
   WriteByte(cc_call_at + n * 4 + i - 1, asc(mid(CcCallThunk(n), i, 1)))
  next
 next
 snes = MbSnes(slot)
 WriteByte(cb_at(6) + (index - 1) * 2, snes and &hFF)
 WriteByte(cb_at(6) + (index - 1) * 2 + 1, (snes shr 8) and &hFF)
 'the animation of the command it is a copy of
 WriteByte(cb_at(7) + (index - 1) * 2, ByteAt(cb_at(7) + (c.own_kind - 1) * 2))
 WriteByte(cb_at(7) + (index - 1) * 2 + 1, ByteAt(cb_at(7) + (c.own_kind - 1) * 2 + 1))

end sub


sub CcWipeSlot(index as Integer)

 'No routine of its own: the thunk goes back to FF (when the unused bytes are the ones this file knows)

 if not cc_ok or not CbIsNew(index) then exit sub

 for i as Integer = 0 to 3
  WriteByte(CcSlotOffset(index) + i, &hFF)
 next

end sub


sub CcClearAll()

 'Every new command goes (moving the tables back)

 for index as Integer = cb_first_extra to cb_slots
  CcRelease(index)
  CcWipeSlot(index)
 next
 if cc_ok then
  for i as Integer = 0 to cc_calls * 4 - 1
   WriteByte(cc_call_at + i, &hFF)
  next
 end if

end sub
