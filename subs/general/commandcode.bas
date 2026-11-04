'Commands with code of their own: a new command (editor 38 to 53) can have its own copy of the routine of another command,
'so that its settings (the spell, the stat, the messages, the chance ...) do not change the original command.
'
'The game starts a command with a routine in the new banks (commandbanks.bas) that takes the address of the code from the
'table of routines and the bank of the code from a table of banks, so a command can be a routine in any bank. The
'routines of the game are written for bank 03 and call other routines of that bank with JSR and end with RTS. A copy in
'another bank
'
'  - calls them with JSL to a thunk of 4 bytes in the unused bytes at the end of bank 03 (03:F210, FF in the original ROM):
'    JSR to the routine and RTL; the thunks are shared by all the copies and are listed in the order they were needed,
'  - ends with a JML to a thunk that is a single RTS,
'  - and has its jumps and branches adjusted (coderelocate.bas does that for the commands that are copied as they are).
'
'There are two ways to make the copy:
'
'  - Boast, Cry, Pray and Bear are built from their settings (CcBuild): a few dozen bytes each, recognised when a ROM is
'    opened by building the routine again from the settings that were read and comparing.
'  - the others (Steal, so far) are copied from the original routine by coderelocate.bas and their settings are read and
'    written by the editor's usual code for that command: ByteAt and WriteByte are redirected (cc_red_on) to the place of
'    the byte in the copy while that code runs. The block ends with two bytes that say which command the copy is of.
'
'A ROM that was made before the routine that starts commands existed has the pointer of each copy in a slot of 4 bytes (a
'JML) at the start of the unused bytes and the thunks at fixed places after the 16 slots. It is read the old way (cc_legacy)
'and written the new way by Save ROM.

const cc_area = &h1F410 'file offset (header included) of the unused bytes at the end of bank 03
const cc_area_size = 112
const cc_thunks = cc_area_size \ 4
const cc_slots = 16 'the old way
const cc_call_at = cc_area + cc_slots * 4
const cc_calls = 6
const cc_block_size = 72
const cc_owner = 12
const cc_add_msg2 = &h85A6 'AddMsg2 in bank 03
const cc_select_obj = &h8489 'SelectObj in bank 03
const cc_call_select_obj = 0 'the thunks of the old way, in the order they are in the unused bytes
const cc_call_magic = 1 'DoMagicAttack after its first three instructions (cd3e)
const cc_call_msg3 = 2
const cc_call_rand = 3
const cc_call_msg2 = 4
const cc_call_rts = 5 'a single RTS: the copies end with a jump to it
const cc_rts = &h10000 'the "address" of the thunk that is an RTS
const cc_steal_shift_at = &h1E416 'the call of the Lsr routine in Steal (battle/cmd.asm, Cmd_17)

dim shared cc_ok as Boolean 'the unused bytes are what this file expects
dim shared cc_legacy as Boolean 'the copies are reached through slots, see above
dim shared cc_block(1 to cb_extra) as Integer 'file offset of the routine of each new command that has its own, 0 if none
dim shared cc_thunk(0 to cc_thunks - 1) as Integer 'the target of each thunk: -1 not used, an address of bank 03, or cc_rts
dim shared cc_lookup_only as Boolean 'asking for a thunk that is not there is a failure (reading a ROM)
dim shared cc_full as Boolean 'a thunk was needed and the room is used up
dim shared cc_red_shift as Integer 'Steal: the shift of the copy that is being read


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


function CcThunkBytes(target as Integer) as String

 'A thunk of 4 bytes: JSR to a routine of bank 03 and RTL (or a single RTS)

 if target = cc_rts then return chr(&h60) + chr(&hEA) + chr(&hEA) + chr(&hEA)

 return chr(&h20) + chr(target and &hFF) + chr(target shr 8) + chr(&h6B)

end function


function CcThunkSnes(target as Integer) as Integer

 'The address (bank * 65536 + address) of the thunk for a routine, made when it is not there yet. -1 if there is no room.

 for i as Integer = 0 to cc_thunks - 1
  if cc_thunk(i) = target then return MbSnes(cc_area + i * 4)
 next
 if cc_lookup_only then return -1

 for i as Integer = 0 to cc_thunks - 1
  if cc_thunk(i) = -1 then
   cc_thunk(i) = target
   for j as Integer = 1 to 4
    WriteByte(cc_area + i * 4 + j - 1, asc(mid(CcThunkBytes(target), j, 1)))
   next
   return MbSnes(cc_area + i * 4)
  end if
 next

 cc_full = true

 return -1

end function


function CcCallTarget(n as Integer) as Integer

 select case n
  case cc_call_select_obj: return cc_select_obj
  case cc_call_magic: return &hCD3E
  case cc_call_msg3: return &h85B1
  case cc_call_rand: return &h8593
  case cc_call_msg2: return cc_add_msg2
 end select

 return cc_rts

end function


function CcCallThunk(n as Integer) as String

 return CcThunkBytes(CcCallTarget(n))

end function


function CcCallSnes(n as Integer) as Integer

 'Where the thunk is: fixed for the old way, the list of thunks for the new way

 if cc_legacy then return MbSnes(cc_call_at + n * 4)

 return CcThunkSnes(CcCallTarget(n))

end function


function CcJsl(n as Integer) as String

 'JSL to the thunk n (JSR of the original code)

 dim snes as Integer = CcCallSnes(n)

 if snes < 0 then return string(4, chr(0))

 return chr(&h22) + chr(snes and &hFF) + chr((snes shr 8) and &hFF) + chr(snes shr 16)

end function


function CcJmlRts() as String

 dim snes as Integer = CcCallSnes(cc_call_rts)

 if snes < 0 then return string(4, chr(0))

 return chr(&h5C) + chr(snes and &hFF) + chr((snes shr 8) and &hFF) + chr(snes shr 16)

end function


function CcAvailable() as Boolean

 return cb_state = 1 and cc_ok and cb_hook and FsHasTable()

end function


function CcFromHex(h as String) as String

 dim result as String

 for i as Integer = 0 to len(h) \ 2 - 1
  result += chr(val("&h" + mid(h, i * 2 + 1, 2)))
 next

 return result

end function


function CcBuild(c as MenuCommand, index as Integer) as String

 'The bytes of the routine of a command that has its own copy of Boast (own_kind 18), Cry (19), Pray (12) or Bear (16).
 ' "" if it is not one of them.

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


'--- the commands that are copied as they are -------------------------------------------------------------

function CcIsCopied(kind as Integer) as Boolean

 'Jump, Recall, Sing, Aim, Throw and Steal

 return kind = 7 or kind = 8 or kind = 9 or kind = 13 or kind = 23 or kind = 24

end function


function CcSourceEntry(kind as Integer) as Integer

 'File offset of the routine of the original command (the pointer is a 16 bit address of bank 03)

 dim p as Integer = ByteAt(cb_orig(6) + (kind - 1) * 2) + ByteAt(cb_orig(6) + (kind - 1) * 2 + 1) * &h100

 if p < &h8000 then return 0

 return MbFileOffset(3 * &h10000 + p)

end function


dim shared cc_analysed as Integer 'the command whose routine reloc_* describes


function CcPrepare(kind as Integer) as Boolean

 'Reads the routine of the original command (once). False if it cannot be copied.

 if cc_analysed = kind then return true
 cc_analysed = 0
 if CcSourceEntry(kind) = 0 then return false
 if not RelocAnalyze(CcSourceEntry(kind)) then return false
 cc_analysed = kind

 return true

end function


function CcCopyOK(kind as Integer) as Boolean

 return CcIsCopied(kind) and CcPrepare(kind)

end function


function CcCopySize(kind as Integer) as Integer

 'Bytes of the copy and the two bytes that say what it is a copy of

 if not CcPrepare(kind) then return 0

 return reloc_size + 2

end function


sub CcRedirect(kind as Integer, block as Integer)

 'ByteAt and WriteByte act on the copy at that place of the new banks until CcRedirectOff

 for i as Integer = 0 to reloc_window - 1
  cc_red_map(i) = reloc_map(i)
 next
 cc_red_entry = reloc_entry
 cc_red_block = block
 cc_red_on = true

end sub


sub CcRedirectOff()

 cc_red_on = false

end sub


function CcShiftOverride(shift as Integer) as Integer

 'The routine that Steal calls to shift the max HP of a thief that is caught (Lsr_1 to Lsr_5 are at 8487 to 8483)

 return &h8400 + (&h88 - shift)

end function


function CcBuildCopy(c as MenuCommand, index as Integer, block as Integer) as String

 'The copy of the routine of the command c.own_kind, without the settings

 dim snes as Integer = MbSnes(block)

 if not CcPrepare(c.own_kind) then return ""
 reloc_over_n = 0
 if c.own_kind = 24 and c.steal_known and c.steal_shift > 0 then
  reloc_over_at(0) = cc_steal_shift_at
  reloc_over_to(0) = CcShiftOverride(c.steal_shift)
  reloc_over_n = 1
 end if

 return RelocEmit(snes, c.own_kind - 1, index - 1) + chr(c.own_kind) + chr(&hA5)

end function


function CcReadCopy(byref c as MenuCommand, index as Integer, block as Integer) as Boolean

 'Whether the block is a copy of a command that is copied as it is; reads its settings if it is

 dim kind as Integer
 dim size as Integer
 dim t as MenuCommand
 dim saved as MenuCommand = c
 dim thunk_at as Integer
 dim shift as Integer
 dim at_ as Integer

 for k as Integer = 7 to 24
  if CcIsCopied(k) then
   size = CcCopySize(k)
   if size > 0 and block + size <= len(ff4rom) then
    if ByteAt(block + size - 2) = k and ByteAt(block + size - 1) = &hA5 then kind = k
   end if
  end if
 next
 if kind = 0 then return false
 CcPrepare(kind)

 'the thunk that Steal calls to shift the max HP of the thief
 shift = 0
 at_ = -1
 if kind = 24 then at_ = RelocMapOffset(cc_steal_shift_at)
 if at_ >= 0 then
  thunk_at = MbFileOffset(ByteAt(block + at_ + 1) + ByteAt(block + at_ + 2) * &h100 + ByteAt(block + at_ + 3) * &h10000)
  if thunk_at >= cc_area and thunk_at < cc_area + cc_area_size then
   if ByteAt(thunk_at) = &h20 and ByteAt(thunk_at + 2) = &h84 then shift = &h88 - ByteAt(thunk_at + 1)
  end if
 end if
 cc_red_shift = shift

 CcRedirect(kind, block)
 t.ReadFromROM(kind)
 CcRedirectOff()

 c = t
 c.name = saved.name
 c.target_byte = saved.target_byte
 c.target = saved.target
 c.delay = saved.delay
 c.disabling_persistent = saved.disabling_persistent
 c.disabling_temporary = saved.disabling_temporary
 c.charging_stance = saved.charging_stance
 c.action_stance = &hFF
 c.action_stance2 = &hFF
 c.action_stance3 = &hFF
 c.own_kind = kind
 if kind = 24 then
  c.steal_shift = shift
  if shift = 0 then c.steal_known = false
 end if

 return true

end function


'--- reading ----------------------------------------------------------------------------------------------

function CcReadLegacy(byref c as MenuCommand, index as Integer) as Boolean

 dim thunk as String
 dim target as Integer
 dim slot as Integer
 dim code as String
 dim lengths(1 to 4) as Integer = {35, 36, 42, 69}

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


function CcReadNew(byref c as MenuCommand, index as Integer) as Boolean

 dim p as Integer = ByteAt(cb_at(6) + (index - 1) * 2) + ByteAt(cb_at(6) + (index - 1) * 2 + 1) * &h100
 dim bank as Integer = ByteAt(cb_bank_at + (index - 1) * 2)
 dim block as Integer
 dim code as String
 dim lengths(1 to 4) as Integer = {35, 36, 42, 69}
 dim found as Boolean

 if bank = 3 or p < &h8000 then return false
 block = MbFileOffset(bank * &h10000 + p)
 if block < fs_header + fs_original_size or block + cc_block_size > len(ff4rom) then return false

 cc_lookup_only = true
 for n as Integer = 1 to 4
  code = CcBytesAt(block, lengths(n))
  if CcParse(code, index, c) then
   found = true
   exit for
  end if
 next
 cc_lookup_only = false
 if not found then found = CcReadCopy(c, index, block)

 if found then
  cc_block(index - cb_first_extra + 1) = block
  c.behaves_like = 0
  c.behaves_known = true
 end if

 return found

end function


function CcRead(byref c as MenuCommand, index as Integer) as Boolean

 'Whether the command has its own routine; fills in its settings if it does.

 if not CbIsNew(index) or not cc_ok then return false
 if cb_state <> 1 then return false

 if cc_legacy then return CcReadLegacy(c, index)

 return CcReadNew(c, index)

end function


sub CcDetect()

 'Whether the unused bytes of bank 03 can be used, and forgets the blocks of the last ROM

 dim thunk as String

 cc_ok = true
 cc_legacy = not cb_hook
 cc_full = false
 cc_analysed = 0
 cc_lookup_only = false
 cc_red_on = false
 for k as Integer = 1 to cb_extra
  cc_block(k) = 0
 next
 for i as Integer = 0 to cc_thunks - 1
  cc_thunk(i) = -1
 next

 if cc_legacy then
  for k as Integer = 1 to cc_slots
   if not CcIsBlank(cc_area + (k - 1) * 4, 4) then
    if ByteAt(cc_area + (k - 1) * 4) <> &h5C then cc_ok = false
   end if
  next
  for n as Integer = 0 to cc_calls - 1
   if not CcIsBlank(cc_call_at + n * 4, 4) then
    if CcBytesAt(cc_call_at + n * 4, 4) <> CcCallThunk(n) then cc_ok = false
   end if
  next
  exit sub
 end if

 for i as Integer = 0 to cc_thunks - 1
  if not CcIsBlank(cc_area + i * 4, 4) then
   thunk = CcBytesAt(cc_area + i * 4, 4)
   if thunk = CcThunkBytes(cc_rts) then
    cc_thunk(i) = cc_rts
   elseif asc(mid(thunk, 1, 1)) = &h20 and asc(mid(thunk, 4, 1)) = &h6B and asc(mid(thunk, 3, 1)) >= &h80 then
    cc_thunk(i) = asc(mid(thunk, 2, 1)) + asc(mid(thunk, 3, 1)) * &h100
   else
    cc_ok = false
   end if
  end if
 next

end sub


sub CcSaveStart()

 'Save ROM: a ROM with the old way is changed to the new way, so the unused bytes are cleared and each copy writes its thunks again

 if not cc_legacy then exit sub
 if not cc_ok or cb_state <> 1 or not cb_hook then exit sub

 for i as Integer = 0 to cc_area_size - 1
  WriteByte(cc_area + i, &hFF)
 next
 cc_legacy = false

end sub


'--- writing ----------------------------------------------------------------------------------------------

function CcNeedBlock(index as Integer, size as Integer = cc_block_size) as Boolean

 'Makes sure the new command has a block of that size for its routine. False if there is no room.

 dim k as Integer = index - cb_first_extra + 1
 dim b as Integer

 if cc_block(k) > 0 then
  FsLoad()
  b = FsFindBlock(cc_block(k))
  if b > 0 then
   if fs_length(b) >= size then return true
  end if
  FsRelease(cc_block(k))
  cc_block(k) = 0
 end if
 cc_block(k) = FsAlloc(size, cc_owner)
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

 'Writes the routine and the pointers of the command

 dim k as Integer = index - cb_first_extra + 1
 dim code as String
 dim snes as Integer
 dim tmp as MenuCommand

 if cc_block(k) <= 0 then exit sub

 cc_full = false
 if CcCopyOK(c.own_kind) then
  code = CcBuildCopy(c, index, cc_block(k))
 else
  code = CcBuild(c, index)
 end if
 if code = "" or cc_full then exit sub

 for i as Integer = 0 to len(code) - 1
  WriteByte(cc_block(k) + i, asc(mid(code, i + 1, 1)))
 next
 if CcCopyOK(c.own_kind) then
  'the settings go into the copy
  tmp = c
  CcRedirect(c.own_kind, cc_block(k))
  tmp.WriteToROM(c.own_kind)
  CcRedirectOff()
 end if

 snes = MbSnes(cc_block(k))
 WriteByte(cb_at(6) + (index - 1) * 2, snes and &hFF)
 WriteByte(cb_at(6) + (index - 1) * 2 + 1, (snes shr 8) and &hFF)
 WriteByte(cb_bank_at + (index - 1) * 2, snes shr 16)
 'the animation of the command it is a copy of
 WriteByte(cb_at(7) + (index - 1) * 2, ByteAt(cb_at(7) + (c.own_kind - 1) * 2))
 WriteByte(cb_at(7) + (index - 1) * 2 + 1, ByteAt(cb_at(7) + (c.own_kind - 1) * 2 + 1))

end sub


sub CcWipeSlot(index as Integer)

 'No routine of its own: the command starts in bank 03 again (and the old way's slot is cleared)

 if not CbIsNew(index) then exit sub

 if cb_hook then
  WriteByte(cb_bank_at + (index - 1) * 2, 3)
 end if
 if cc_legacy and cc_ok then
  for i as Integer = 0 to 3
   WriteByte(CcSlotOffset(index) + i, &hFF)
  next
 end if

end sub


sub CcClearAll()

 'Every new command goes (moving the tables back)

 for index as Integer = cb_first_extra to cb_slots
  CcRelease(index)
  CcWipeSlot(index)
 next
 if cc_ok then
  for i as Integer = 0 to cc_area_size - 1
   WriteByte(cc_area + i, &hFF)
  next
  for i as Integer = 0 to cc_thunks - 1
   cc_thunk(i) = -1
  next
 end if

end sub
