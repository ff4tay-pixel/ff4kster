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


sub CbDetect()

 dim operand as Integer
 dim file_at as Integer
 dim candidate as Integer
 dim n_orig as Integer
 dim n_new as Integer
 dim base_at as Integer = -1
 dim agree as Boolean = true

 cb_state = 0
 cb_block = 0
 cb_rewrite_all = false
 for t as Integer = 1 to cb_tables
  cb_at(t) = cb_orig(t)
 next

 for s as Integer = 1 to cb_sites
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

 if n_new = cb_sites and agree and base_at >= fs_header + fs_original_size and base_at + cb_block_size <= len(ff4rom) then
  cb_state = 1
  cb_block = base_at
  for t as Integer = 1 to cb_tables
   cb_at(t) = base_at + cb_off(t)
  next
 else
  cb_state = 2
 end if

end sub


sub CbWriteSite()

 'The addresses of the 12 instructions, the way the state says

 dim operand as Integer

 if cb_state = 2 then exit sub

 for s as Integer = 1 to cb_sites
  operand = MbSnes(cb_at(cb_site_table(s)) + cb_site_add(s))
  WriteByte(cb_site(s) + 1, operand and &hFF)
  WriteByte(cb_site(s) + 2, (operand shr 8) and &hFF)
  WriteByte(cb_site(s) + 3, operand shr 16)
 next

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
