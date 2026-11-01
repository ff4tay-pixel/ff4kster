'More room for monster palettes: a table of 256 palettes in the new banks of an expanded ROM.
'
'A monster's palette is a number (one byte) that the game multiplies by 16 to find 8 colors in the table at 1C:EE00
'(file offset 0xE6E00). The table has room for 240 palettes before the next table (the battle character palettes)
'starts, and the editor knows 240 of them. The byte allows 256. The game reads a palette with one instruction,
'"lda long,x" (BF 00 EE 1C at 02:916B), so moving the table only changes the address of that instruction. The new
'table is 0x1010 bytes: 256 palettes and the 16 bytes that the 16 color pictures read after the last one.
'
'The state is in the ROM (the instruction's address), read back by PbDetect when a ROM is opened. An instruction
'that points anywhere else (another tool moved the table) is left alone. monster_palette_table is the file offset
'of the table the editor reads and writes (palette edits are written straight into the ROM image).

const pb_site = &h1116B + &h200 'file offset of the BF opcode of the instruction in LoadMonsterPal
const pb_original_table = &hE7000
const pb_original_count = 240
const pb_table_size = &h1010

dim shared pb_state as Integer '0 original, 1 moved by this editor, 2 unknown (left alone)
dim shared monster_palette_table as Integer = pb_original_table 'where the palettes are now
dim shared monster_palette_table_loaded as Integer = pb_original_table 'where they were when the ROM was opened


function MonsterPaletteCount() as Integer

 if pb_state = 1 then return monster_palette_max

 return pb_original_count

end function


sub PbDetect()

 dim file_at as Integer

 pb_state = 0
 monster_palette_table = pb_original_table
 if ByteAt(pb_site) <> &hBF then
  pb_state = 2
 else
  file_at = MbFileOffset(MbOperand(pb_site))
  if file_at = pb_original_table then
   pb_state = 0
  elseif file_at >= fs_header + fs_original_size and file_at + pb_table_size <= len(ff4rom) then
   pb_state = 1
   monster_palette_table = file_at
  else
   pb_state = 2
  end if
 end if
 monster_palette_table_loaded = monster_palette_table

end sub


sub PbWriteSite()

 'The instruction's address, the way the state says

 dim operand as Integer

 if pb_state = 2 then exit sub

 operand = MbSnes(monster_palette_table)
 WriteByte(pb_site, &hBF)
 WriteByte(pb_site + 1, operand and &hFF)
 WriteByte(pb_site + 2, (operand shr 8) and &hFF)
 WriteByte(pb_site + 3, operand shr 16)

end sub


function PbLocationText() as String

 select case pb_state
  case 0: return "Room for " + str(pb_original_count) + " palettes in the original table. Moving gives " + str(monster_palette_max) + "."
  case 1: return str(monster_palette_max) + " palettes, table at " + hex(MbSnes(monster_palette_table) shr 16, 2) + ":" + hex(MbSnes(monster_palette_table) and &hFFFF, 4) + "."
 end select

 return "The game's palette instruction was changed by another tool."

end function
