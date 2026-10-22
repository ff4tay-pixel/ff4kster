function BattleFormulas.PowerNames() as String

 return "x4, original|x2|x1"

end function


function BattleFormulas.PowerBytes() as String

 'Two shift pairs (asl, rol on the 16 bit power) that make the base attack 4 times the spell power;
 ' a pair that is overwritten with nops does not double it. Hex, one entry per name.

 return "06A926AA06A926AA|06A926AAEAEAEAEA|EAEAEAEAEAEAEAEA"

end function


function BattleFormulas.SummonNames() as String

 return "x8, original|x4|x2|x1"

end function


function BattleFormulas.SummonBytes() as String

 'The same for a summon, which has three pairs.

 return "06A926AA06A926AA06A926AA|06A926AA06A926AAEAEAEAEA|06A926AAEAEAEAEAEAEAEAEA|EAEAEAEAEAEAEAEAEAEAEAEA"

end function


function BattleFormulas.DivisorNames() as String

 return "Stat/2 plus 1|Stat/4 plus 1, original|Stat/8 plus 1|Stat/16 plus 1|Stat/32 plus 1|Stat/64 plus 1"

end function


function BattleFormulas.StatsNames() as String

 return "Black STR, white AGI|Black AGI, white VIT|Black VIT, white WIS|Black WIS, white WIL, original"

end function


function BattleFormulas.TermStatOffset(t as Integer) as UInteger

 'The address in the code of the stat a term reads: the operand of an lda (or adc) of $3965 to $396A, which
 ' hold the level, STR, AGI, VIT, WIS and WIL of the character (UpdateCharStats in battle/equip.asm).
 ' 0 if the term has no stat.

 select case t
  case 1: return &h19E31 'attack multiplier, first term (STR / 8)
  case 2: return &h19E39 'attack multiplier, second term (AGI / 16)
  case 3: return &h19E91 'attack power, strength term (STR / 4)
  case 4: return &h19E48 'level term of the attack % and the attack power (level / 4)
  case 5: return &h19BCD 'defense multiplier, first term (level / 16, times the shield's multiplier)
  case 6: return &h19BDD 'defense multiplier, second term (AGI / 8)
  case 7: return &h19C0F 'defense, stamina term (VIT / 2)
  case 8: return &h19C90 'magic defense multiplier, first stat of the sum (WIS)
  case 9: return &h19C93 'magic defense multiplier, second stat of the sum (WIL)
  case 11: return &h19C9D 'magic defense multiplier, extra term (AGI / 32)
 end select

 return 0

end function


function BattleFormulas.TermShiftOffset(t as Integer) as UInteger

 'The address of the shift that divides a term: a call to one of the Lsr routines (3 bytes, 20 xx 84) or a
 ' lsr (1 byte). Calling nothing (3 nops) is a division by 1. 0 if the term is not divided.

 select case t
  case 1: return &h19E33
  case 2: return &h19E3B
  case 3: return &h19E93
  case 4: return &h19E4A
  case 5: return &h19BCF
  case 6: return &h19BDF
  case 7: return &h19C11
  case 10: return &h19C97 'magic defense multiplier, divisor of the sum (/ 32)
  case 11: return &h19C9F
  case 12: return &h19CA9 'magic defense %, divisor of the same sum (/ 8)
 end select

 return 0

end function


function BattleFormulas.TermShiftLength(t as Integer) as Integer

 if t = 7 then return 1

 return 3

end function


function BattleFormulas.TermStatNames() as String

 return "Level|STR|AGI|VIT|WIS|WIL"

end function


function BattleFormulas.TermDivNames(t as Integer) as String

 if t = 7 then return "/1|/2"

 return "/1|/2|/4|/8|/16|/32|/64"

end function


sub BattleFormulas.ReadFromROM()

 'The spell damage routine (MagicAttack in battle/magic.asm) works out the number of hits of a spell from
 ' the caster's stat: (stat shifted right by 2) plus 1 tries, each one landing at the spell's hit rate, and the
 ' hits that land multiply the damage. The shift is a call to one of the Lsr routines of the battle code, the
 ' stat is read from the caster's properties ($2697 plus 0 for black magic and 1 for white magic, the
 ' modified WIS and WIL), and the same stat is also in the hit rate. Summons and spells cast from items
 ' always count 8 hits, which is a byte in the code. The base attack is the spell power shifted left 2 (3 for
 ' a summon). The Summon Book picks one of 10 spells from a table. (The number of hits of a spell cast from
 ' a weapon is the weapon's own Power in the Weapons editor, so it is not here.)

 dim wanted as String
 dim found as String
 dim n as Integer

 power_choice = 0
 n = 1
 do
  wanted = MenuCommand.CodeItem(PowerBytes(), n)
  if wanted = "" then exit do
  if MenuCommand.BytesAre(&h1D270, wanted) then
   power_choice = n
   exit do
  end if
  n += 1
 loop

 summon_choice = 0
 n = 1
 do
  wanted = MenuCommand.CodeItem(SummonBytes(), n)
  if wanted = "" then exit do
  if MenuCommand.BytesAre(&h1D262, wanted) then
   summon_choice = n
   exit do
  end if
  n += 1
 loop

 divisor_choice = 0
 if ByteAt(&h1D111) = &hBD and ByteAt(&h1D113) = &h26 and ByteAt(&h1D114) = &h20 and ByteAt(&h1D116) = &h84 and ByteAt(&h1D117) = &h1A then
  if ByteAt(&h1D115) >= &h82 and ByteAt(&h1D115) <= &h87 then divisor_choice = &h87 - ByteAt(&h1D115) + 1
 end if

 stats_choice = 0
 if ByteAt(&h1D0C3) = &hBD and ByteAt(&h1D0C5) = &h26 and ByteAt(&h1D111) = &hBD and ByteAt(&h1D113) = &h26 then
  if ByteAt(&h1D0C4) = ByteAt(&h1D112) and ByteAt(&h1D0C4) >= &h94 and ByteAt(&h1D0C4) <= &h97 then stats_choice = ByteAt(&h1D0C4) - &h93
 end if

 hits_known = (ByteAt(&h1D12E) = &hA9 and ByteAt(&h1D130) = &h8D and ByteAt(&h1D131) = &h51 and ByteAt(&h1D132) = &h35)
 fixed_hits = ByteAt(&h1D12F)


 'the character stat formulas
 dim o as UInteger
 for k as Integer = 1 to 12
  term_stat(k) = 0
  term_div(k) = 0
  o = TermStatOffset(k)
  if o > 0 then
   if ByteAt(o) >= &h65 and ByteAt(o) <= &h6A and ByteAt(o + 1) = &h39 then
    if (k = 9 and ByteAt(o - 1) = &h6D) or (k <> 9 and ByteAt(o - 1) = &hAD) then term_stat(k) = ByteAt(o) - &h65 + 1
   end if
  else
   term_stat(k) = 1
  end if
  o = TermShiftOffset(k)
  if o > 0 then
   if TermShiftLength(k) = 1 then
    if ByteAt(o) = &h4A then term_div(k) = 2
    if ByteAt(o) = &hEA then term_div(k) = 1
   else
    if ByteAt(o) = &h20 and ByteAt(o + 2) = &h84 and ByteAt(o + 1) >= &h82 and ByteAt(o + 1) <= &h87 then term_div(k) = &h87 - ByteAt(o + 1) + 2
    if ByteAt(o) = &hEA and ByteAt(o + 1) = &hEA and ByteAt(o + 2) = &hEA then term_div(k) = 1
   end if
  else
   term_div(k) = 1
  end if
 next
 plus_known = (ByteAt(&h19E41) = &h1A or ByteAt(&h19E41) = &hEA)
 plus_on = (ByteAt(&h19E41) = &h1A)
 'Yang's attack: lda level, asl (x2) or nop, clc, adc strength term, adc #2
 yang_known = (ByteAt(&h19E9F) = &hAD and ByteAt(&h19EA1) = &h39 and ByteAt(&h19EA3) = &h18 and ByteAt(&h19EA4) = &h65)
 yang_known = yang_known and ByteAt(&h19EA5) = &hAA and ByteAt(&h19EA6) = &h69 and (ByteAt(&h19EA2) = &h0A or ByteAt(&h19EA2) = &hEA)
 yang_known = yang_known and ByteAt(&h19EA0) >= &h65 and ByteAt(&h19EA0) <= &h6A
 yang_stat = ByteAt(&h19EA0) - &h65 + 1
 if ByteAt(&h19EA2) = &h0A then yang_mult = 1 else yang_mult = 2
 yang_plus = ByteAt(&h19EA7)

 'The turn wait of every unit (battle/init.asm): the anchor's agility times a numerator (lda $2015,x, tax,
 ' ldx #50) divided by the unit's agility times a multiplier (lda #10) from Mult8. Not using the anchor
 ' replaces the first lda and tax with ldx #1 (and a nop). An addend goes between the multiplication and the
 ' division, which is a call (jsr) to a short routine in free space instead of ldx $e3, stx $3947.
 speed_known = (ByteAt(&h18F8B) = &hA2 and ByteAt(&h18F8E) = &h8E and ByteAt(&h18FAD) = &hA9 and ByteAt(&h18FBE) = &h20)
 speed_anchor = MenuCommand.BytesAre(&h18F84, "BD1520AA")
 if not speed_anchor and not MenuCommand.BytesAre(&h18F84, "A20100EA") then speed_known = false
 speed_num = ByteAt(&h18F8C) + ByteAt(&h18F8D) * &h100
 speed_mul = ByteAt(&h18FAE)
 speed_add = 0
 if MenuCommand.BytesAre(&h18FB9, "A6E38E4739") then
  speed_add = 0
 elseif MenuCommand.BytesAre(&h18FB9, "2040FFEAEA") and MenuCommand.BytesAre(&h20140, "C220A5E31869") and MenuCommand.BytesAre(&h20148, "8D4739A90000E22060") then
  speed_add = ByteAt(&h20146) + ByteAt(&h20147) * &h100
 else
  speed_known = false
 end if

 for i as Integer = 0 to 9
  summon_book(i) = ByteAt(&hA00EC + i)
 next

end sub


sub BattleFormulas.WriteToROM()

 dim wanted as String

 if power_choice > 0 then
  wanted = MenuCommand.CodeItem(PowerBytes(), power_choice)
  for i as Integer = 0 to len(wanted) \ 2 - 1
   WriteByte(&h1D270 + i, val("&h" + mid(wanted, i * 2 + 1, 2)))
  next
 end if

 if summon_choice > 0 then
  wanted = MenuCommand.CodeItem(SummonBytes(), summon_choice)
  for i as Integer = 0 to len(wanted) \ 2 - 1
   WriteByte(&h1D262 + i, val("&h" + mid(wanted, i * 2 + 1, 2)))
  next
 end if

 if divisor_choice > 0 then WriteByte(&h1D115, &h87 - divisor_choice + 1)

 if stats_choice > 0 then
  WriteByte(&h1D0C4, &h93 + stats_choice)
  WriteByte(&h1D112, &h93 + stats_choice)
 end if

 if hits_known then WriteByte(&h1D12F, fixed_hits)


 'the character stat formulas: only the terms that are one of the known choices are written
 dim o as UInteger
 for k as Integer = 1 to 12
  o = TermStatOffset(k)
  if o > 0 and term_stat(k) > 0 then WriteByte(o, &h65 + term_stat(k) - 1)
  o = TermShiftOffset(k)
  if o > 0 and term_div(k) > 0 then
   if TermShiftLength(k) = 1 then
    if term_div(k) = 1 then WriteByte(o, &hEA) else WriteByte(o, &h4A)
   elseif term_div(k) = 1 then
    WriteByte(o, &hEA)
    WriteByte(o + 1, &hEA)
    WriteByte(o + 2, &hEA)
   else
    WriteByte(o, &h20)
    WriteByte(o + 1, &h87 - term_div(k) + 2)
    WriteByte(o + 2, &h84)
   end if
  end if
 next
 if plus_known then
  if plus_on then WriteByte(&h19E41, &h1A) else WriteByte(&h19E41, &hEA)
 end if
 if yang_known then
  WriteByte(&h19EA0, &h65 + yang_stat - 1)
  if yang_mult = 1 then WriteByte(&h19EA2, &h0A) else WriteByte(&h19EA2, &hEA)
  WriteByte(&h19EA7, yang_plus)
 end if
 if speed_known then
  if speed_anchor then
   WriteByte(&h18F84, &hBD): WriteByte(&h18F85, &h15): WriteByte(&h18F86, &h20): WriteByte(&h18F87, &hAA)
  else
   WriteByte(&h18F84, &hA2): WriteByte(&h18F85, &h01): WriteByte(&h18F86, &h00): WriteByte(&h18F87, &hEA)
  end if
  WriteByte(&h18F8C, speed_num mod &h100)
  WriteByte(&h18F8D, speed_num \ &h100)
  WriteByte(&h18FAE, speed_mul)
  for i as Integer = 0 to &h3F
   WriteByte(&h20140 + i, &hFF)
  next
  if speed_add = 0 then
   'the original bytes: ldx $e3, stx $3947
   WriteByte(&h18FB9, &hA6): WriteByte(&h18FBA, &hE3): WriteByte(&h18FBB, &h8E): WriteByte(&h18FBC, &h47): WriteByte(&h18FBD, &h39)
  else
   'jsr to the routine that adds speed_add to the product and stores it as the divisor
   WriteByte(&h18FB9, &h20): WriteByte(&h18FBA, &h40): WriteByte(&h18FBB, &hFF): WriteByte(&h18FBC, &hEA): WriteByte(&h18FBD, &hEA)
   dim routine as String = "C220A5E31869" + hex(speed_add mod &h100, 2) + hex(speed_add \ &h100, 2) + "8D4739A90000E22060"
   for i as Integer = 0 to len(routine) \ 2 - 1
    WriteByte(&h20140 + i, val("&h" + mid(routine, i * 2 + 1, 2)))
   next
  end if
 end if

 for i as Integer = 0 to 9
  WriteByte(&hA00EC + i, summon_book(i))
 next

end sub
