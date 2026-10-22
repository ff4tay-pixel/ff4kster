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

 for i as Integer = 0 to 9
  WriteByte(&hA00EC + i, summon_book(i))
 next

end sub
