'The texts of the Equip and Status menus: the five equipment slots (RHand ... Arms) and the labels of the Status
' screen (Ability, Str. ... Mag Def%). In the ROM each is a run of letters inside the menu's text table (a position,
' the letters, an end mark), so a text can be replaced by another one of at most the same length: a shorter text
' is filled up with spaces, nothing around it moves. The game reads them from file offset 0D9C1 to 0DAA8 (the
' disassembly calls them EQUIP_SLOT1_STR ... MAG_EVADE_STR, menu/menu_data.asm).
' The battle menu keeps its own copy of the two hand names (RLHandText, btlgfx/btlgfx_data.asm): ten bytes per
' line, five spaces then the name, in four lines of the table. Those are written together with RHand and LHand.

const mt_count = 17

dim shared mt_label(1 to mt_count) as String 'what the text is
dim shared mt_where(1 to mt_count) as String 'where the game shows it
dim shared mt_offset(1 to mt_count) as Integer 'file offset of the first letter (with the 0x200 header)
dim shared mt_size(1 to mt_count) as Integer 'number of letters, the longest the text can be
dim shared mt_text(1 to mt_count) as String 'the text as FF4 codes
dim shared mt_orig(1 to mt_count) as String 'the text when the ROM was loaded
dim shared mt_ready as Boolean


sub MtDefine(n as Integer, label as String, where_shown as String, offset as Integer, size as Integer)

 mt_label(n) = label
 mt_where(n) = where_shown
 mt_offset(n) = offset + &h200
 mt_size(n) = size

end sub


sub ReadMenuText()

 MtDefine(1, "Equip, 1st slot", "Equip menu, the right hand", &hD9C1, 5)
 MtDefine(2, "Equip, 2nd slot", "Equip menu, the left hand", &hD9C9, 5)
 MtDefine(3, "Equip, 3rd slot", "Equip menu, the head", &hD9D1, 4)
 MtDefine(4, "Equip, 4th slot", "Equip menu, the body", &hD9D8, 4)
 MtDefine(5, "Equip, 5th slot", "Equip menu, the arms", &hD9DF, 4)
 MtDefine(6, "Status, abilities", "Status menu, over the five stats", &hDA41, 7)
 MtDefine(7, "Status, strength", "Status menu, first stat", &hDA4B, 4)
 MtDefine(8, "Status, agility", "Status menu, second stat", &hDA52, 5)
 MtDefine(9, "Status, vitality", "Status menu, third stat", &hDA5A, 4)
 MtDefine(10, "Status, wisdom", "Status menu, fourth stat", &hDA61, 4)
 MtDefine(11, "Status, will", "Status menu, fifth stat", &hDA68, 4)
 MtDefine(12, "Status, attack", "Status menu, the attack power", &hDA6F, 6)
 MtDefine(13, "Status, attack %", "Status menu, the chance to hit", &hDA78, 7)
 MtDefine(14, "Status, defense", "Status menu, the defense", &hDA82, 7)
 MtDefine(15, "Status, defense %", "Status menu, the chance to dodge", &hDA8C, 8)
 MtDefine(16, "Status, magic defense", "Status menu, the magic defense", &hDA97, 7)
 MtDefine(17, "Status, magic def. %", "Status menu, the chance to resist", &hDAA1, 8)

 for i as Integer = 1 to mt_count
  mt_text(i) = mid(ff4rom, mt_offset(i) + 1, mt_size(i))
  mt_orig(i) = mt_text(i)
 next
 mt_ready = true

end sub


function MtCopyOffset(n as Integer, copy as Integer) as Integer

 'The offsets of the copies of a text that the battle menu has: two lines for each hand. 0 for no copy.

 select case n
  case 1
   if copy = 1 then return &hB7F20 + &h200
   if copy = 2 then return &hB7F34 + &h200
  case 2
   if copy = 1 then return &hB7F16 + &h200
   if copy = 2 then return &hB7F3E + &h200
 end select

 return 0

end function


sub WriteMenuText()

 'Called by Save ROM. A text that was not edited writes the bytes the ROM already has.

 dim at as Integer

 if not mt_ready then exit sub

 for i as Integer = 1 to mt_count
  for j as Integer = 1 to mt_size(i)
   WriteByte(mt_offset(i) + j - 1, asc(mid(mt_text(i), j, 1)))
  next
  for c as Integer = 1 to 2
   at = MtCopyOffset(i, c)
   if at > 0 then
    for j as Integer = 1 to mt_size(i)
     WriteByte(at + j - 1, asc(mid(mt_text(i), j, 1)))
    next
   end if
  next
 next

end sub
