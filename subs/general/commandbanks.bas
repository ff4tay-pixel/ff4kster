'More battle commands: the command tables in the new banks of an expanded ROM.
'
'The game knows 37 battle commands (numbers 00 to 24). Seven tables are indexed by the command number, and each one is
'read by a few "lda long,x" instructions (BF opcode), so a table can be moved by changing the address of those
'instructions and nothing else (the same way as the monster palettes):
'
'  names            5 bytes each   2 instructions (the battle command window, the command name shown in battle)
'  targeting        1 byte         1 instruction  (when a character's commands are loaded)
'  delay            1 byte         1 instruction  (action delay)
'  disabling status 2 bytes        2 instructions (persistent and temporary, the second one reads one byte further)
'  waiting stance   1 byte         2 instructions
'  routine          2 bytes        2 instructions (the pointer to the code in bank 03 that runs the command)
'  animation        2 bytes        2 instructions (the pointer to the code in bank 02 that draws it)
'
'The new tables hold 53 commands, 16 more than the game has. They are one block of 742 bytes in one bank. The first 37 entries
'are copied as they are (the tables of the game are shorter than 37 for some columns: whatever follows them is copied, so
'the game sees the same bytes as before). A new command points at the routine of an existing command, as command 22
'always could, and has its own name, target, delay, disabling statuses and waiting stance. Command numbers 25 to 36
'(editor 26 to 37) are the game's own commands and are shown but not edited.
'
'The state is in the ROM (the addresses of the 12 instructions), read back by CbDetect when a ROM is opened. If the 12
'instructions do not agree (another tool changed them) the tables stay where they were and nothing is added.

const cb_standard = 26 'commands the editor edits in the original game (editor numbers are the command number plus 1)
const cb_game = 37 'commands the game has
const cb_extra = 16
const cb_slots = cb_game + cb_extra
const cb_first_extra = cb_game + 1 'editor number of the first new command
const cb_tables = 7
const cb_sites = 12
const cb_owner = 11

dim shared cb_state as Integer '0 original, 1 moved by this editor, 2 unknown (left alone)
dim shared cb_block as Integer 'file offset of the new tables, when moved
dim shared cb_at(1 to cb_tables) as Integer 'where each table is now (file offset, header included)
dim shared cb_orig(1 to cb_tables) as Integer
dim shared cb_size(1 to cb_tables) as Integer 'bytes per command
dim shared cb_off(1 to cb_tables) as Integer 'start of each table inside the new block
dim shared cb_site(1 to cb_sites) as Integer 'file offset of the BF opcode
dim shared cb_site_table(1 to cb_sites) as Integer
dim shared cb_site_add(1 to cb_sites) as Integer 'bytes after the start of the table that the instruction reads
dim shared cb_block_size as Integer
dim shared cb_rewrite_all as Boolean 'the tables changed place: Save ROM writes every command again
dim shared cb_hook as Boolean 'the game starts a command through a routine in the new banks that also reads the bank of the code
dim shared cb_hook_at as Integer 'file offset of that routine
dim shared cb_bank_at as Integer 'file offset of the table of banks (2 bytes per command: the bank and a zero)
dim shared cb_alias as Boolean 'the number of the animation of a command comes from a table
dim shared cb_alias_at as Integer 'file offset of the routine
dim shared cb_alias_tbl as Integer 'file offset of the table (1 byte per command)
const cb_hook_size = 21
const cb_hook_total = cb_hook_size + cb_slots * 2
'The graphics script of a battle action starts with the command number plus C0, and the script treats E8 and above as other
'orders, so a command number above 27 would be taken for one of them. The instructions that add C0 (7 bytes at 1B34A: PHA,
'CLC, ADC #C0, STA $33C4) become PHA and a call to a routine that adds C0 to the number that a table gives for the command
'(the number of the command whose animation it has).
const cb_alias_site = &h1B34A
const cb_alias_hook_size = 14
const cb_alias_total = cb_alias_hook_size + cb_slots

cb_orig(1) = &h7A9C6: cb_size(1) = 5 'names
cb_orig(2) = &h9FFC3: cb_size(2) = 1 'targeting
cb_orig(3) = &hA0089: cb_size(3) = 1 'delay
cb_orig(4) = &h9FF19: cb_size(4) = 2 'disabling statuses
cb_orig(5) = &hB7E60: cb_size(5) = 1 'waiting stance
cb_orig(6) = &h1B57C: cb_size(6) = 2 'routine
cb_orig(7) = &h1424B: cb_size(7) = 2 'animation
for t as Integer = 1 to cb_tables
 cb_at(t) = cb_orig(t)
 cb_off(t) = cb_block_size
 cb_block_size += cb_slots * cb_size(t)
next

cb_site(1) = &h11F41: cb_site_table(1) = 1: cb_site_add(1) = 0
cb_site(2) = &h14D51: cb_site_table(2) = 1: cb_site_add(2) = 0
cb_site(3) = &h18DB3: cb_site_table(3) = 2: cb_site_add(3) = 0
cb_site(4) = &h1A1A2: cb_site_table(4) = 3: cb_site_add(4) = 0
cb_site(5) = &h1A4AC: cb_site_table(5) = 4: cb_site_add(5) = 0
cb_site(6) = &h1A4B2: cb_site_table(6) = 4: cb_site_add(6) = 1
cb_site(7) = &hF326: cb_site_table(7) = 5: cb_site_add(7) = 0
cb_site(8) = &h13401: cb_site_table(8) = 5: cb_site_add(8) = 0
cb_site(9) = &h1B360: cb_site_table(9) = 6: cb_site_add(9) = 0
cb_site(10) = &h1B366: cb_site_table(10) = 6: cb_site_add(10) = 1
cb_site(11) = &h1423C: cb_site_table(11) = 7: cb_site_add(11) = 0
cb_site(12) = &h14242: cb_site_table(12) = 7: cb_site_add(12) = 1


declare sub CbReadNewCommands()
declare sub CcClearAll()


function CommandCount() as Integer

 if cb_state = 1 then return cb_slots

 return cb_standard

end function


function CbIsGameCommand(index as Integer) as Boolean

 'The commands between the 26 and the new ones: the game uses them itself (change row, defend, ...)

 return index > cb_standard and index <= cb_game

end function


function CbIsNew(index as Integer) as Boolean

 return index >= cb_first_extra and index <= cb_slots

end function


function CbGameName(index as Integer) as String

 'Names for the commands that the game has no name for (they are never shown in the game's menus)

 select case index
  case 31: return FF4Text("Jump2")
  case 32: return FF4Text("Focs2")
  case 33: return FF4Text("Twin2")
  case 34: return FF4Text("Pass ")
  case 35: return FF4Text("EndRg")
  case 36: return FF4Text("Unusd")
  case 37: return FF4Text("Run  ")
 end select

 return ""

end function


function CbDefaultName(index as Integer) as String

 return FF4Text("Cmd" + Pad(str(index - cb_game), 2, true, "0"))

end function


function CbAliasBytes() as String

 dim t as Integer = MbSnes(cb_alias_tbl)

 return chr(&hDA) + chr(&hAA) + chr(&hBF) + chr(t and &hFF) + chr((t shr 8) and &hFF) + chr(t shr 16) + chr(&h18) + chr(&h69) + chr(&hC0) + _
  chr(&h8D) + chr(&hC4) + chr(&h33) + chr(&hFA) + chr(&h6B)

end function


function CbAliasValue(index as Integer) as Integer

 'The command whose animation the command has: itself, or for a new command the command that it copies

 if index <= cb_game then return index - 1
 if menucommands(index).own_kind > 0 then return menucommands(index).own_kind - 1
 if menucommands(index).behaves_like > 0 then return menucommands(index).behaves_like - 1

 return &h21 'does nothing

end function


function CbHookBytes() as String

 'The routine that starts a command: pointer from the table, bank from the table of banks, then JML [$80]

 dim p as Integer = MbSnes(cb_at(6))
 dim q as Integer = MbSnes(cb_at(6) + 1)
 dim b as Integer = MbSnes(cb_bank_at)

 return chr(&hBF) + chr(p and &hFF) + chr((p shr 8) and &hFF) + chr(p shr 16) + chr(&h85) + chr(&h80) + _
  chr(&hBF) + chr(q and &hFF) + chr((q shr 8) and &hFF) + chr(q shr 16) + chr(&h85) + chr(&h81) + _
  chr(&hBF) + chr(b and &hFF) + chr((b shr 8) and &hFF) + chr(b shr 16) + chr(&h85) + chr(&h82) + chr(&hDC) + chr(&h80) + chr(&h00)

end function


sub CbDetect()

 dim operand as Integer
 dim file_at as Integer
 dim candidate as Integer
 dim n_orig as Integer
 dim n_new as Integer
 dim base_at as Integer = -1
 dim agree as Boolean = true

 dim hooked as Boolean = (ByteAt(cb_site(9)) = &h5C)
 dim needed as Integer = cb_sites

 cb_state = 0
 cb_block = 0
 cb_hook = false
 cb_hook_at = 0
 cb_bank_at = 0
 cb_alias = false
 cb_alias_at = 0
 cb_alias_tbl = 0
 cb_rewrite_all = false
 for t as Integer = 1 to cb_tables
  cb_at(t) = cb_orig(t)
 next
 if hooked then needed = cb_sites - 2

 for s as Integer = 1 to cb_sites
  if hooked and (s = 9 or s = 10) then continue for
  if ByteAt(cb_site(s)) <> &hBF then
   cb_state = 2
   exit sub
  end if
  file_at = MbFileOffset(MbOperand(cb_site(s)))
  if file_at = cb_orig(cb_site_table(s)) + cb_site_add(s) then
   n_orig += 1
  else
   n_new += 1
   candidate = file_at - cb_site_add(s) - cb_off(cb_site_table(s))
   if base_at < 0 then base_at = candidate
   if candidate <> base_at then agree = false
  end if
 next

 if n_orig = cb_sites then exit sub

 if n_new = needed and agree and base_at >= fs_header + fs_original_size and base_at + cb_block_size <= len(ff4rom) then
  cb_state = 1
  cb_block = base_at
  for t as Integer = 1 to cb_tables
   cb_at(t) = base_at + cb_off(t)
  next
  if hooked then
   'the routine must be exactly what this file writes
   dim target as Integer = MbFileOffset(MbOperand(cb_site(9)))
   dim bank_operand as Integer
   cb_state = 2
   if target >= fs_header + fs_original_size and target + cb_hook_size <= len(ff4rom) then
    bank_operand = ByteAt(target + 13) + ByteAt(target + 14) * &h100 + ByteAt(target + 15) * &h10000
    cb_bank_at = MbFileOffset(bank_operand)
    if cb_bank_at >= fs_header + fs_original_size and cb_bank_at + cb_slots * 2 <= len(ff4rom) and mid(ff4rom, target + 1, cb_hook_size) = CbHookBytes() then
     cb_state = 1
     cb_hook = true
     cb_hook_at = target
    end if
   end if
  end if
  if cb_state = 1 and ByteAt(cb_alias_site) = &h48 and ByteAt(cb_alias_site + 1) = &h22 then
   'the routine that gives the number of the animation
   dim a_target as Integer = MbFileOffset(MbOperand(cb_alias_site + 1))
   if a_target >= fs_header + fs_original_size and a_target + cb_alias_hook_size <= len(ff4rom) then
    cb_alias_tbl = MbFileOffset(ByteAt(a_target + 3) + ByteAt(a_target + 4) * &h100 + ByteAt(a_target + 5) * &h10000)
    if cb_alias_tbl >= fs_header + fs_original_size and cb_alias_tbl + cb_slots <= len(ff4rom) and mid(ff4rom, a_target + 1, cb_alias_hook_size) = CbAliasBytes() then
     cb_alias = true
     cb_alias_at = a_target
    else
     cb_alias_tbl = 0
    end if
   end if
  end if
 else
  cb_state = 2
 end if

end sub


sub CbWriteSite()

 'The addresses of the 12 instructions, the way the state says

 dim operand as Integer

 if cb_state = 2 then exit sub

 for s as Integer = 1 to cb_sites
  if cb_hook and (s = 9 or s = 10) then continue for
  operand = MbSnes(cb_at(cb_site_table(s)) + cb_site_add(s))
  WriteByte(cb_site(s) + 1, operand and &hFF)
  WriteByte(cb_site(s) + 2, (operand shr 8) and &hFF)
  WriteByte(cb_site(s) + 3, operand shr 16)
 next

 'the start of a command: the original instructions, or a jump to the routine
 if cb_hook then
  dim code as String = CbHookBytes()
  for i as Integer = 1 to cb_hook_size
   WriteByte(cb_hook_at + i - 1, asc(mid(code, i, 1)))
  next
  operand = MbSnes(cb_hook_at)
  WriteByte(cb_site(9), &h5C)
  WriteByte(cb_site(9) + 1, operand and &hFF)
  WriteByte(cb_site(9) + 2, (operand shr 8) and &hFF)
  WriteByte(cb_site(9) + 3, operand shr 16)
  for i as Integer = 4 to 18
   WriteByte(cb_site(9) + i, &hEA)
  next
 else
  for i as Integer = 0 to 18
   WriteByte(cb_site(9) + i, val("&h" + mid("BF7CB3038580BF7DB30385" + "81A9038582DC8000", i * 2 + 1, 2)))
  next
  for s as Integer = 9 to 10
   operand = MbSnes(cb_at(6) + cb_site_add(s))
   WriteByte(cb_site(s) + 1, operand and &hFF)
   WriteByte(cb_site(s) + 2, (operand shr 8) and &hFF)
   WriteByte(cb_site(s) + 3, operand shr 16)
  next
 end if

 'the number of the animation of a command
 if cb_alias then
  dim alias_code as String = CbAliasBytes()
  for i as Integer = 1 to cb_alias_hook_size
   WriteByte(cb_alias_at + i - 1, asc(mid(alias_code, i, 1)))
  next
  for i as Integer = 1 to cb_slots
   WriteByte(cb_alias_tbl + i - 1, CbAliasValue(i))
  next
  operand = MbSnes(cb_alias_at)
  WriteByte(cb_alias_site, &h48)
  WriteByte(cb_alias_site + 1, &h22)
  WriteByte(cb_alias_site + 2, operand and &hFF)
  WriteByte(cb_alias_site + 3, (operand shr 8) and &hFF)
  WriteByte(cb_alias_site + 4, operand shr 16)
  WriteByte(cb_alias_site + 5, &hEA)
  WriteByte(cb_alias_site + 6, &hEA)
 else
  for i as Integer = 0 to 6
   WriteByte(cb_alias_site + i, val("&h" + mid("4818" + "69C08DC433", i * 2 + 1, 2)))
  next
 end if

end sub


function CbInstallAlias() as String

 'Puts the routine and the table in the new banks and the call of it

 dim block_at as Integer

 if cb_state <> 1 then return "The command tables are not in the new banks."
 if cb_alias then return ""
 if ByteAt(cb_alias_site) <> &h48 or ByteAt(cb_alias_site + 1) <> &h18 or ByteAt(cb_alias_site + 2) <> &h69 or ByteAt(cb_alias_site + 3) <> &hC0 then return "The start of the commands was changed by another tool."
 block_at = FsAlloc(cb_alias_total, cb_owner)
 if block_at < 0 then return "There is no room for the animation routine in the new banks."
 cb_alias_at = block_at
 cb_alias_tbl = block_at + cb_alias_hook_size
 cb_alias = true
 CbWriteSite()

 return ""

end function


function CbInstallHook() as String

 'Puts the routine that starts a command in the new banks (127 bytes with the table of banks) and the jump to it

 dim block_at as Integer

 if cb_state <> 1 then return "The command tables are not in the new banks."
 if cb_hook then return ""
 block_at = FsAlloc(cb_hook_total, cb_owner)
 if block_at < 0 then return "There is no room for the command routine in the new banks."
 cb_hook_at = block_at
 cb_bank_at = block_at + cb_hook_size
 for i as Integer = 0 to cb_slots - 1
  WriteByte(cb_bank_at + i * 2, 3)
  WriteByte(cb_bank_at + i * 2 + 1, 0)
 next
 cb_hook = true
 CbWriteSite()

 return ""

end function


sub CbRemoveHook()

 if not cb_hook then exit sub
 FsRelease(cb_hook_at)
 cb_hook = false
 cb_hook_at = 0
 cb_bank_at = 0

end sub


sub CbRemoveAlias()

 if not cb_alias then exit sub
 FsRelease(cb_alias_at)
 cb_alias = false
 cb_alias_at = 0
 cb_alias_tbl = 0

end sub


function CbLocationText() as String

 select case cb_state
  case 0: return "The game has 37 battle commands. Moving the tables gives room for 16 more."
  case 1: return "53 battle commands, tables at " + hex(MbSnes(cb_block) shr 16, 2) + ":" + hex(MbSnes(cb_block) and &hFFFF, 4) + "."
 end select

 return "The game's command tables were changed by another tool."

end function


function CbMove() as String

 'Copies the tables to a longer block and makes the game use it. Returns "" when done, otherwise why not.

 dim block_at as Integer
 dim entry as Integer
 dim from_at as Integer
 dim name_text as String

 if cb_state = 1 then return "That is already in the new banks."
 if cb_state = 2 then return "The game's command tables were changed by another tool."
 if not FsHasTable() then return "Expand the ROM first (Free Space on the main menu)."

 block_at = FsAlloc(cb_block_size, cb_owner)
 if block_at < 0 then return "There is no room for the command tables in the new banks."

 for t as Integer = 1 to cb_tables
  for e as Integer = 0 to cb_slots - 1
   for j as Integer = 0 to cb_size(t) - 1
    if e < cb_game then
     WriteByte(block_at + cb_off(t) + e * cb_size(t) + j, ByteAt(cb_orig(t) + e * cb_size(t) + j))
    else
     'a new command: the name, then the settings of Fight and the routine of "do nothing" (command 21h)
     select case t
      case 1
       name_text = CbDefaultName(e + 1)
       WriteByte(block_at + cb_off(t) + e * cb_size(t) + j, asc(mid(name_text, j + 1, 1)))
      case 6, 7
       WriteByte(block_at + cb_off(t) + e * cb_size(t) + j, ByteAt(cb_orig(t) + &h21 * 2 + j))
      case 5
       WriteByte(block_at + cb_off(t) + e * cb_size(t) + j, ByteAt(cb_orig(t)))
      case else
       WriteByte(block_at + cb_off(t) + e * cb_size(t) + j, 0)
     end select
    end if
   next
  next
 next

 cb_block = block_at
 for t as Integer = 1 to cb_tables
  cb_at(t) = block_at + cb_off(t)
 next
 cb_state = 1
 name_text = CbInstallHook()
 if name_text = "" then name_text = CbInstallAlias()
 if name_text <> "" then
  cb_state = 0
  for t as Integer = 1 to cb_tables
   cb_at(t) = cb_orig(t)
  next
  FsRelease(block_at)
  cb_block = 0
  return name_text
 end if
 cb_rewrite_all = true
 CbReadNewCommands()

 return ""

end function


function CbMoveBack() as String

 'Back to the original tables. Refused while a character has one of the new commands.

 dim block_at as Integer = cb_block

 if cb_state <> 1 then return "That is not in the new banks."
 for i as Integer = 1 to total_actors
  for k as Integer = 1 to 5
   if actors(i).menu_command(k) >= cb_game and actors(i).menu_command(k) < &hFF then return "A character uses one of the new commands. Take it out of the command list first."
  next
 next

 CcClearAll()
 CbRemoveAlias()
 CbRemoveHook()
 for t as Integer = 1 to cb_tables
  cb_at(t) = cb_orig(t)
 next
 cb_state = 0
 cb_rewrite_all = true
 FsRelease(block_at)
 cb_block = 0

 return ""

end function


sub CbReadNewCommands()

 'The commands after the 26 have just appeared: read them

 for i as Integer = cb_standard + 1 to cb_slots
  menucommands(i).name = ""
  menucommands(i).ReadFromROM(i)
  orig_menucommands(i) = menucommands(i)
 next

end sub
