'More shops: a table of 256 shops in the new banks of an expanded ROM.
'
'A shop is 8 item numbers (FF ends the list) in the table at 13:A300 (file offset 0x9A300), and the shop menu finds
'a shop with these instructions (menu/shop.asm, LoadShopList):
'
'  lda $1a00 / asl / asl / asl / rep #$20 / adc #$A300 / sta $5A / sep #$20 / lda #$13 / sta $5C
'
'The multiplication by 8 is done on the 8 bit accumulator, so it overflows for shop 32 and above: the 33rd shop of the
'original table can never be opened (shop 32 would read the table one byte off). Only shops 0 to 31 work.
'
'Moving the table puts a routine of 24 bytes in the new banks in place of those 19 bytes of instructions (a JSL and
'NOPs). The routine does the multiplication on 16 bits, adds the address of the new table and stores the pointer the
'same way, so shops 0 to 255 work. The new table is 0x800 bytes in one bank.
'
'The state is in the ROM (the instruction), read back by SbDetect when a ROM is opened. An instruction that is
'anything else (another tool changed it) is left alone and the table stays where it was.

const sb_site = &hC48E + &h200 'file offset of the AD 00 1A (lda $1a00) of LoadShopList
const sb_site_size = 19
const sb_hook_size = 24
const sb_original_table = &h9A500
const shop_max = 256
const shop_original_count = 33
const sb_table_size = shop_max * 8

dim shared sb_state as Integer '0 original, 1 moved by this editor, 2 unknown (left alone)
dim shared shop_table as Integer = sb_original_table 'where the shops are now
dim shared sb_code as Integer 'file offset of the routine, when moved


function ShopCount() as Integer

 if sb_state = 1 then return shop_max

 return shop_original_count

end function


function SbOriginalBytes() as String

 return chr(&hAD) + chr(&h00) + chr(&h1A) + chr(&h0A) + chr(&h0A) + chr(&h0A) + chr(&hC2) + chr(&h20) + chr(&h69) + chr(&h00) + chr(&hA3) + _
  chr(&h85) + chr(&h5A) + chr(&hE2) + chr(&h20) + chr(&hA9) + chr(&h13) + chr(&h85) + chr(&h5C)

end function


function SbHookBytes(table_at as Integer) as String

 dim snes as Integer = MbSnes(table_at)

 return chr(&hAD) + chr(&h00) + chr(&h1A) + chr(&hC2) + chr(&h20) + chr(&h29) + chr(&hFF) + chr(&h00) + chr(&h0A) + chr(&h0A) + chr(&h0A) + _
  chr(&h18) + chr(&h69) + chr(snes and &hFF) + chr((snes shr 8) and &hFF) + chr(&h85) + chr(&h5A) + chr(&hE2) + chr(&h20) + _
  chr(&hA9) + chr(snes shr 16) + chr(&h85) + chr(&h5C) + chr(&h6B)

end function


sub SbDetect()

 dim target as Integer
 dim table_at as Integer
 dim hook as String

 sb_state = 0
 sb_code = 0
 shop_table = sb_original_table
 if mid(ff4rom, sb_site + 1, sb_site_size) = SbOriginalBytes() then exit sub

 sb_state = 2
 if ByteAt(sb_site) <> &h22 then exit sub
 target = MbFileOffset(MbOperand(sb_site))
 if target < 0 or target + sb_hook_size > len(ff4rom) then exit sub
 hook = mid(ff4rom, target + 1, sb_hook_size)
 table_at = MbFileOffset(asc(mid(hook, 21, 1)) * &h10000 + asc(mid(hook, 14, 1)) + asc(mid(hook, 15, 1)) * &h100)
 if table_at < fs_header + fs_original_size or table_at + sb_table_size > len(ff4rom) then exit sub
 if hook <> SbHookBytes(table_at) then exit sub

 sb_state = 1
 sb_code = target
 shop_table = table_at

end sub


sub SbWriteSite()

 'Puts the instruction and the routine in the ROM image the way the state says

 dim operand as Integer
 dim bytes as String

 if sb_state = 2 then exit sub

 if sb_state = 0 then
  bytes = SbOriginalBytes()
 else
  bytes = SbHookBytes(shop_table)
  for i as Integer = 1 to sb_hook_size
   WriteByte(sb_code + i - 1, asc(mid(bytes, i, 1)))
  next
  operand = MbSnes(sb_code)
  bytes = chr(&h22) + chr(operand and &hFF) + chr((operand shr 8) and &hFF) + chr(operand shr 16)
  bytes += string(sb_site_size - 4, chr(&hEA))
 end if
 for i as Integer = 1 to sb_site_size
  WriteByte(sb_site + i - 1, asc(mid(bytes, i, 1)))
 next

end sub


function SbLocationText() as String

 select case sb_state
  case 0: return "Shops 0 to 31 work in the original table. Moving gives 256 shops."
  case 1: return "256 shops, table at " + hex(MbSnes(shop_table) shr 16, 2) + ":" + hex(MbSnes(shop_table) and &hFFFF, 4) + "."
 end select

 return "The game's shop instruction was changed by another tool."

end function


function SbMove() as String

 'Copies the shops to a new table and makes the game use it. Returns "" when done, otherwise why not.

 dim block_at as Integer
 dim code_at as Integer

 if sb_state = 1 then return "That is already in the new banks."
 if sb_state = 2 then return "The game's shop instruction was changed by another tool."
 if not FsHasTable() then return "Expand the ROM first (Free Space on the main menu)."

 block_at = FsAlloc(sb_table_size, 6)
 if block_at < 0 then return "There is no room for the shops in the new banks."
 code_at = FsAlloc(sb_hook_size, 6)
 if code_at < 0 then
  FsRelease(block_at)
  return "There is no room for the routine in the new banks."
 end if

 for i as Integer = 0 to sb_table_size - 1
  if i < shop_original_count * 8 then
   WriteByte(block_at + i, ByteAt(shop_table + i))
  else
   WriteByte(block_at + i, &hFF)
  end if
 next
 for i as Integer = shop_original_count + 1 to shop_max
  for j as Integer = 1 to 8
   shops(i).wares(j) = &hFF
  next
 next
 'names of the new shops, the way the config reading gives them to a ROM that is opened already moved
 for i as Integer = shop_names.Length() + 1 to shop_max
  shop_names.Append(FF4Text("Shop " + Pad(str(i), 2, true, "0")))
 next
 shop_table = block_at
 sb_code = code_at
 sb_state = 1

 return ""

end function


function SbMoveBack() as String

 'Back to the original table. Refused while a shop after the 33rd has items.

 dim block_at as Integer = shop_table

 if sb_state <> 1 then return "That is not in the new banks."
 for i as Integer = shop_original_count + 1 to shop_max
  if shops(i).wares(1) <> &hFF then return "Shop " + str(i) + " has items. Empty the shops after 33 first."
 next

 for i as Integer = 0 to shop_original_count * 8 - 1
  WriteByte(sb_original_table + i, ByteAt(block_at + i))
 next
 FsRelease(block_at)
 FsRelease(sb_code)
 sb_state = 0
 sb_code = 0
 shop_table = sb_original_table

 return ""

end function
