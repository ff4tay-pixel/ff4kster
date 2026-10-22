function BackEffectOffset(r as Integer) as UInteger

 'The back row in Fight (battle/fight.asm): a unit in the back row, bit 7 of byte 1 of its properties, has its hit
 ' rate halved (lsr), unless it has the no back row penalty flag (bit 5 of that byte, the bow) or is jumping, and
 ' so has the hit rate against a target in the back row (tested with the flag and the jump of the attacker); the
 ' defense of a target in the back row is doubled. r 1 the hit rate of the attacker in the back row, 2 the hit
 ' rate against a target in the back row, 3 the defense (6 bytes: asl, rol).

 select case r
  case 1: return &h1C733
  case 2: return &h1C768
  case 3: return &h1C90D
 end select

 return 0

end function


function BackFlagMaskOffset(r as Integer) as UInteger

 'The operand of the "and #$20" that tests the no back row penalty flag, for rule 1 and 2.

 if r = 1 then return &h1C729

 return &h1C75E

end function


function BackJumpMaskOffset(r as Integer) as UInteger

 'The operand of the "and #$02" that tests the jump status.

 if r = 1 then return &h1C730

 return &h1C765

end function


function SlotUnitOffset(r as Integer) as UInteger

 'The four rates that the unit in the first slot has 25% more of (battle/fight.asm and battle/magic.asm):
 ' 1 the hit rate of an attacker, 2 the evasion of a target, 3 the hit rate of a spell and 4 the magic defense rate
 ' of the target of a spell. Each is "lda $cd" or "lda $ce" (the attacker or the target), "and #$7f", a branch
 ' that skips the rest when that is not 0, then the rate times 5 divided by 4. The game tests the attacker for
 ' rule 4, which looks like a mistake. This is the operand of the lda.

 select case r
  case 1: return &h1C737
  case 2: return &h1C7C0
  case 3: return &h1D0E3
  case 4: return &h1D2BA
 end select

 return 0

end function


function SlotMaskOffset(r as Integer) as UInteger

 return SlotUnitOffset(r) + 2

end function


function SlotMultOffset(r as Integer) as UInteger

 select case r
  case 1: return &h1C742
  case 2: return &h1C7CB
  case 3: return &h1D0EE
  case 4: return &h1D2C5
 end select

 return 0

end function


function BattleFormulas.UmLdaOffset(r as Integer) as UInteger

 'The rules that test a status byte of the attacker ($2683 to $2686) or of the target ($2703 to $2706) with a
 ' lda and an "and #mask" and then change a number. This is the address of the operand of the lda. The
 ' rules: 1 a blind attacker halves its hit rate, 2 a blind target halves its evasion, 3 berserk adds 50% to
 ' the attack power, 4 jump or focus doubles it, 5 curse halves it, 6 a cursed target has half the defense,
 ' 7 defend doubles the defense, 8 focus halves it, 9 and 10 spells: a blind attacker halves the hit rate
 ' and a blind target the magic defense rate, 11 a target with focus has no magic defense multiplier.

 select case r
  case 1: return &h1C717
  case 2: return &h1C7B6
  case 3: return &h1C8C8
  case 4: return &h1C8E8
  case 5: return &h1C8F5
  case 6: return &h1C914
  case 7: return &h1C934
  case 8: return &h1C941
  case 9: return &h1D0D9
  case 10: return &h1D2B0
  case 11: return &h1D2F4
 end select

 return 0

end function


function BattleFormulas.UmMaskOffset(r as Integer) as UInteger

 'The operand of the "and #mask" that follows.

 select case r
  case 1: return &h1C71A
  case 2: return &h1C7B9
  case 3: return &h1C8CB
  case 4: return &h1C8EB
  case 5: return &h1C8F8
  case 6: return &h1C917
  case 7: return &h1C937
  case 8: return &h1C944
  case 9: return &h1D0DC
  case 10: return &h1D2B3
  case 11: return &h1D2F7
 end select

 return 0

end function


function BattleFormulas.UmEffectOffset(r as Integer) as UInteger

 'The bytes that make the change, 0 if the rule has none that can change: 3 bytes (lsr of the hit rate or the
 ' defense rate) or 6 bytes (a shift of a 16 bit attack power or defense).

 select case r
  case 1: return &h1C71D
  case 2: return &h1C7BC
  case 4: return &h1C8EE
  case 5: return &h1C8FB
  case 6: return &h1C91A
  case 7: return &h1C93A
  case 8: return &h1C947
  case 9: return &h1D0DF
  case 10: return &h1D2B6
 end select

 return 0

end function


function BattleFormulas.UmKind(r as Integer) as Integer

 'What the effect bytes of the rule are: 0 none, 1 the hit rate or the evasion (3 bytes), 2 the attack power
 ' ($3902, 6 bytes), 3 the defense ($3904, 6 bytes).

 select case r
  case 1, 2, 9, 10: return 1
  case 4, 5: return 2
  case 6, 7, 8: return 3
 end select

 return 0

end function


function BattleFormulas.UmUnit(r as Integer) as Integer

 'Whose status the rule tests: 1 the attacker, 2 the target.

 select case r
  case 1, 3, 4, 5, 9: return 1
 end select

 return 2

end function


function BattleFormulas.UmEffectNames(r as Integer) as String

 if UmKind(r) = 1 then return "halved, original|unchanged"

 return "x0.5|x1|x2"

end function


function BattleFormulas.UmEffectBytes(r as Integer, choice as Integer) as String

 'The bytes of an effect in hex: the first is the one that shifts right, then none, then the one that shifts
 ' left (kinds 2 and 3). Which shifts is the original depends on the rule.

 select case UmKind(r)
  case 1
   if choice = 1 then
    select case r
     case 1: return "4EF838"
     case 2: return "4EF938"
     case else: return "4EFA38"
    end select
   end if
   return "EAEAEA"
  case 2
   select case choice
    case 1: return "4E03396E0239"
    case 2: return "EAEAEAEAEAEA"
    case 3: return "0E02392E0339"
   end select
  case 3
   select case choice
    case 1: return "4E05396E0439"
    case 2: return "EAEAEAEAEAEA"
    case 3: return "0E04392E0539"
   end select
 end select

 return ""

end function


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
 'The statuses that change the damage (battle/fight.asm, battle/magic.asm). Each rule is a test of the status 1
 ' byte of the attacker ($2683) or the target ($2703) with an "and #mask": the original has toad plus mini ($30)
 ' for every rule of Fight and toad ($20) for the magic defense multiplier. Pig does nothing in the original.
 ' 1: an attacker with it does 1 attack power (ldx #1) and no crits. 2: a target with it takes the attack power
 ' times 2 (asl, rol) and has no defense (clr_ax, stx $3904). 3: it has no defense multiplier. 4: spells ignore
 ' the magic defense multiplier of a target with it (the same code also ignores it for focus). 5: an attacker with
 ' it inflicts no status. 6: an attacker with it uses no arrow.
 for k as Integer = 1 to 6
  st_known(k) = false
 next
 st_mask(1) = ByteAt(&h1C951): st_known(1) = (ByteAt(&h1C950) = &h29 and ByteAt(&h1C954) = &hA2)
 st_mask(2) = ByteAt(&h1C961): st_known(2) = (ByteAt(&h1C960) = &h29)
 st_mask(3) = ByteAt(&h1C7EE): st_known(3) = (ByteAt(&h1C7ED) = &h29 and ByteAt(&h1C7F1) = &h9C)
 st_mask(4) = ByteAt(&h1D2F0): st_known(4) = (ByteAt(&h1D2EF) = &h29)
 st_mask(5) = ByteAt(&h1CAA3): st_known(5) = (ByteAt(&h1CAA2) = &h29)
 st_mask(6) = ByteAt(&h1CB28): st_known(6) = (ByteAt(&h1CB27) = &h29)
 st_power = ByteAt(&h1C955) + ByteAt(&h1C956) * &h100
 st_mult = 0
 if MenuCommand.BytesAre(&h1C964, "4E03396E0239") then st_mult = 1
 if MenuCommand.BytesAre(&h1C964, "EAEAEAEAEAEA") then st_mult = 2
 if MenuCommand.BytesAre(&h1C964, "0E02392E0339") then st_mult = 3
 if st_mult = 0 then st_known(2) = false
 st_defense_zero = MenuCommand.BytesAre(&h1C96A, "7BAA8E0439")
 if not st_defense_zero and not MenuCommand.BytesAre(&h1C96A, "EAEAEAEAEA") then st_known(2) = false


 'The back row, see BackEffectOffset.
 back_known = true
 for r as Integer = 1 to 2
  if ByteAt(BackFlagMaskOffset(r) - 1) <> &h29 or ByteAt(BackJumpMaskOffset(r) - 1) <> &h29 then back_known = false
  back_flag(r) = (ByteAt(BackFlagMaskOffset(r)) = &h20)
  back_jump(r) = (ByteAt(BackJumpMaskOffset(r)) = &h02)
  if ByteAt(BackFlagMaskOffset(r)) <> &h20 and ByteAt(BackFlagMaskOffset(r)) <> &h00 then back_known = false
  if ByteAt(BackJumpMaskOffset(r)) <> &h02 and ByteAt(BackJumpMaskOffset(r)) <> &h00 then back_known = false
 next
 back_hit(1) = 0
 back_hit(2) = 0
 for r as Integer = 1 to 2
  if MenuCommand.BytesAre(BackEffectOffset(r), "4EF838") then back_hit(r) = 1
  if MenuCommand.BytesAre(BackEffectOffset(r), "EAEAEA") then back_hit(r) = 2
  if MenuCommand.BytesAre(BackEffectOffset(r), "0EF838") then back_hit(r) = 3
  if back_hit(r) = 0 then back_known = false
 next
 back_def = 0
 if MenuCommand.BytesAre(BackEffectOffset(3), "4E05396E0439") then back_def = 1
 if MenuCommand.BytesAre(BackEffectOffset(3), "EAEAEAEAEAEA") then back_def = 2
 if MenuCommand.BytesAre(BackEffectOffset(3), "0E04392E0539") then back_def = 3
 if back_def = 0 then back_known = false

 'The bonus of the first slot, see SlotUnitOffset. The mask says who: 7F the unit number without the monster bit
 ' (slot 0 of the party and of the monsters), FF only the party slot 0, 80 any member of the party.
 for r as Integer = 1 to 4
  slot_known(r) = (ByteAt(SlotMaskOffset(r) - 1) = &h29 and ByteAt(SlotMultOffset(r) - 1) = &hA9)
  slot_who(r) = 0
  select case ByteAt(SlotMaskOffset(r))
   case &h7F: slot_who(r) = 1
   case &hFF: slot_who(r) = 2
   case &h80: slot_who(r) = 3
  end select
  if slot_who(r) = 0 then slot_known(r) = false
  slot_mult(r) = ByteAt(SlotMultOffset(r))
 next
 if ByteAt(SlotUnitOffset(2)) <> &hCE then slot_known(2) = false
 if ByteAt(SlotUnitOffset(1)) <> &hCD or ByteAt(SlotUnitOffset(3)) <> &hCD then slot_known(1) = false: slot_known(3) = false
 slot_target = (ByteAt(SlotUnitOffset(4)) = &hCE)
 if ByteAt(SlotUnitOffset(4)) <> &hCD and ByteAt(SlotUnitOffset(4)) <> &hCE then slot_known(4) = false

 'The other status rules, see UmLdaOffset. The lda picks the byte (list 1 to 4), the mask the statuses.
 dim unit_base as Integer
 dim lda_offset as UInteger
 dim effect_offset as UInteger
 dim effect_text as String
 for r as Integer = 1 to 11
  um_known(r) = false
  um_list(r) = 0
  um_mask(r) = 0
  um_effect(r) = 0
  lda_offset = UmLdaOffset(r)
  if UmUnit(r) = 1 then unit_base = &h83 else unit_base = &h03
  if ByteAt(lda_offset - 1) = &hAD and ByteAt(UmMaskOffset(r) - 1) = &h29 and ByteAt(lda_offset) >= unit_base and ByteAt(lda_offset) <= unit_base + 3 and ByteAt(lda_offset + 1) = iif(UmUnit(r) = 1, &h26, &h27) then
   um_known(r) = true
   um_list(r) = ByteAt(lda_offset) - unit_base + 1
   um_mask(r) = ByteAt(UmMaskOffset(r))
   effect_offset = UmEffectOffset(r)
   if effect_offset > 0 then
    for c as Integer = 1 to iif(UmKind(r) = 1, 2, 3)
     effect_text = UmEffectBytes(r, c)
     if effect_text <> "" and MenuCommand.BytesAre(effect_offset, effect_text) then um_effect(r) = c
    next
    if um_effect(r) = 0 then um_known(r) = false
   end if
  end if
 next

 'poison: the max HP is divided by a call to one of the Lsr routines, sap: 2 HP, sleep and paralyze: see below
 poison_known = (ByteAt(&h1AB2F) = &hBD and ByteAt(&h1AB32) = &h20 and ByteAt(&h1AB34) = &h84 and ByteAt(&h1AB33) >= &h82 and ByteAt(&h1AB33) <= &h87)
 poison_div = &h87 - ByteAt(&h1AB33) + 1
 'The wait between two ticks of poison (and of petrify, which uses the same routine, TimerDur_06 in
 ' battle/timer_dur.asm) is the VIT of a character plus 20, or the level plus 10 plus 20 of a monster, in ticks
 ' of the battle loop at normal speed. The VIT is the operand of a lda of the unit ($2016,x), the 20 an adc #imm.
 wait_known = (ByteAt(&h1A117) = &hBD and ByteAt(&h1A119) = &h20 and ByteAt(&h1A11A) = &h18 and ByteAt(&h1A11B) = &h69)
 wait_stat = 0
 select case ByteAt(&h1A118)
  case &h02: wait_stat = 1
  case &h14: wait_stat = 2
  case &h15: wait_stat = 3
  case &h16: wait_stat = 4
  case &h17: wait_stat = 5
  case &h18: wait_stat = 6
 end select
 if wait_stat = 0 then wait_known = false
 wait_const = ByteAt(&h1A11C)
 'HP leak is taken by SapRegenEffect (battle/timer.asm), called once for every tick of the battle loop: a counter
 ' is compared with 1. Regen is taken when another counter, that is compared with 5 after it is raised, has
 ' counted 6 passes. How long HP leak lasts is TimerDur_09: (WIS plus WIL) x 2 plus 30 for a character.
 sap_every_known = (ByteAt(&h1AC15) = &hC9)
 sap_every = ByteAt(&h1AC16)
 regen_known = (ByteAt(&h1ACA6) = &hC9)
 regen_every = ByteAt(&h1ACA7) + 1
 sap_len_known = (ByteAt(&h1A15D) = &hA9 and ByteAt(&h1A16F) = &h69)
 sap_len_mult = ByteAt(&h1A15E)
 sap_len_const = ByteAt(&h1A170)
 sap_known = (ByteAt(&h1AC54) = &hA9 and ByteAt(&h1AC56) = &h9D)
 sap_damage = ByteAt(&h1AC55)
 sleep_known = (ByteAt(&h1A0E1) = &hA9 and ByteAt(&h1A0E7) = &hA9 and ByteAt(&h1A0FC) = &hA2 and ByteAt(&h1A0E0) = &h38)
 sleep_base = ByteAt(&h1A0E2) + ByteAt(&h1A0E8) * &h100
 sleep_div = ByteAt(&h1A0FD)
 sleep_mult = 0
 if MenuCommand.BytesAre(&h1A0DC, "EAEAEAEA") then sleep_mult = 1
 if MenuCommand.BytesAre(&h1A0DC, "06ADEAEA") then sleep_mult = 2
 if MenuCommand.BytesAre(&h1A0DC, "06AD06AD") then sleep_mult = 3
 if sleep_mult = 0 then sleep_known = false

 'Dispel (magic effect $10) and Black hole ($2A) work on a copy of the status bytes of the target: each does
 ' "and #mask" on status 2 ($2704) and on status 4 ($2706), so the bits that are 0 in the mask are removed.
 ' Only the bits that make sense to remove are offered: status 2 without the petrify bits, status 4 without
 ' hide, cover and low hp. Black hole also sets the speed modifier ($273b) to 10h, normal speed.
 dispel_known = (ByteAt(&h1DAC0) = &h29 and ByteAt(&h1DADC) = &h29)
 dispel_s2 = &hFF - ByteAt(&h1DAC1)
 dispel_s4 = &hFF - ByteAt(&h1DADD)
 if (dispel_s2 and &h03) <> 0 or (dispel_s4 and &h83) <> 0 then dispel_known = false
 hole_known = (ByteAt(&h1DFB3) = &h29 and ByteAt(&h1DFBB) = &h29)
 hole_s2 = &hFF - ByteAt(&h1DFB4)
 hole_s4 = &hFF - ByteAt(&h1DFBC)
 if (hole_s2 and &h03) <> 0 or (hole_s4 and &h83) <> 0 then hole_known = false
 hole_speed_known = MenuCommand.BytesAre(&h1DFC0, "A9108D3B27") or MenuCommand.BytesAre(&h1DFC0, "EAEAEAEAEA")
 hole_speed = MenuCommand.BytesAre(&h1DFC0, "A9108D3B27")

 'Armor (magic effect $0d) adds a number to the defense of the target ($272a, 255 at most) and Shell (effect $0e)
 ' to its magic defense base ($2724): adc #imm in the code of battle/magic.asm.
 buff_known = (ByteAt(&h1DA66) = &hAD and ByteAt(&h1DA68) = &h27 and ByteAt(&h1DA69) = &h69 and ByteAt(&h1DA8A) = &hAD and ByteAt(&h1DA8C) = &h27 and ByteAt(&h1DA8D) = &h69)
 protect_add = ByteAt(&h1DA6A)
 'Both effects skip the battle with the number $01B7, Zeromus: after lda $1801 a bne (D0 0D) jumps over the
 ' addition. Two nops make it work there.
 zeromus_known = (ByteAt(&h1DA60) = &hAD and ByteAt(&h1DA62) = &h18 and ByteAt(&h1DA65) = &h18 and ByteAt(&h1DA84) = &hAD and ByteAt(&h1DA86) = &h18 and ByteAt(&h1DA89) = &h18)
 zeromus_known = zeromus_known and ((ByteAt(&h1DA63) = &hD0 and ByteAt(&h1DA64) = &h0D) or (ByteAt(&h1DA63) = &hEA and ByteAt(&h1DA64) = &hEA))
 zeromus_known = zeromus_known and ((ByteAt(&h1DA87) = &hD0 and ByteAt(&h1DA88) = &h0D) or (ByteAt(&h1DA87) = &hEA and ByteAt(&h1DA88) = &hEA))
 protect_zeromus = (ByteAt(&h1DA63) = &hEA)
 shell_zeromus = (ByteAt(&h1DA87) = &hEA)
 shell_add = ByteAt(&h1DA8E)

 'Count (doom, magic effect $1c in battle/magic.asm): the spell's power is the starting count and the timer
 ' loop (battle/battle.asm) steps the count down once every "extra doom counter" ticks, a counter of 2 per
 ' unit that is set when the battle starts and again every time it reaches 0. Both are an immediate in the
 ' code. When the count reaches 0 TimerEffect_06 (battle/timer.asm) gives the unit status 1 bit $80, dead.
 doom_known = (ByteAt(&h184BE) = &hA9 and ByteAt(&h19911) = &hA9 and ByteAt(&h19913) = 0 and ByteAt(&h184BF) = ByteAt(&h19912))
 doom_known = doom_known and ByteAt(&h1AC02) = &h09
 doom_ticks = ByteAt(&h184BF)
 doom_status = 0
 for c as Integer = 1 to 8
  if ByteAt(&h1AC03) = (&h80 shr (c - 1)) then doom_status = c
 next
 if doom_status = 0 then doom_known = false

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

 'the back row
 if back_known then
  dim back_text as String
  for r as Integer = 1 to 2
   select case back_hit(r)
    case 1: back_text = "4EF838"
    case 2: back_text = "EAEAEA"
    case else: back_text = "0EF838"
   end select
   for i as Integer = 0 to 2
    WriteByte(BackEffectOffset(r) + i, val("&h" + mid(back_text, i * 2 + 1, 2)))
   next
   if back_flag(r) then WriteByte(BackFlagMaskOffset(r), &h20) else WriteByte(BackFlagMaskOffset(r), &h00)
   if back_jump(r) then WriteByte(BackJumpMaskOffset(r), &h02) else WriteByte(BackJumpMaskOffset(r), &h00)
  next
  select case back_def
   case 1: back_text = "4E05396E0439"
   case 2: back_text = "EAEAEAEAEAEA"
   case else: back_text = "0E04392E0539"
  end select
  for i as Integer = 0 to 5
   WriteByte(BackEffectOffset(3) + i, val("&h" + mid(back_text, i * 2 + 1, 2)))
  next
 end if

 'the bonus of the first slot
 for r as Integer = 1 to 4
  if slot_known(r) then
   select case slot_who(r)
    case 1: WriteByte(SlotMaskOffset(r), &h7F)
    case 2: WriteByte(SlotMaskOffset(r), &hFF)
    case else: WriteByte(SlotMaskOffset(r), &h80)
   end select
   WriteByte(SlotMultOffset(r), slot_mult(r))
  end if
 next
 if slot_known(4) then
  if slot_target then WriteByte(SlotUnitOffset(4), &hCE) else WriteByte(SlotUnitOffset(4), &hCD)
 end if

 'the other status rules
 for r as Integer = 1 to 11
  if um_known(r) then
   if UmUnit(r) = 1 then WriteByte(UmLdaOffset(r), &h83 + um_list(r) - 1) else WriteByte(UmLdaOffset(r), &h03 + um_list(r) - 1)
   WriteByte(UmMaskOffset(r), um_mask(r))
   if UmEffectOffset(r) > 0 then
    dim effect_text as String = UmEffectBytes(r, um_effect(r))
    for i as Integer = 0 to len(effect_text) \ 2 - 1
     WriteByte(UmEffectOffset(r) + i, val("&h" + mid(effect_text, i * 2 + 1, 2)))
    next
   end if
  end if
 next
 if poison_known then WriteByte(&h1AB33, &h87 - poison_div + 1)
 if sap_known then WriteByte(&h1AC55, sap_damage)
 if wait_known then
  select case wait_stat
   case 1: WriteByte(&h1A118, &h02)
   case else: WriteByte(&h1A118, &h14 + wait_stat - 2)
  end select
  WriteByte(&h1A11C, wait_const)
 end if
 if sap_every_known then WriteByte(&h1AC16, sap_every)
 if regen_known then WriteByte(&h1ACA7, regen_every - 1)
 if sap_len_known then
  WriteByte(&h1A15E, sap_len_mult)
  WriteByte(&h1A170, sap_len_const)
 end if
 if sleep_known then
  WriteByte(&h1A0E2, sleep_base mod &h100)
  WriteByte(&h1A0E8, sleep_base \ &h100)
  WriteByte(&h1A0FD, sleep_div)
  select case sleep_mult
   case 1: WriteByte(&h1A0DC, &hEA): WriteByte(&h1A0DD, &hEA): WriteByte(&h1A0DE, &hEA): WriteByte(&h1A0DF, &hEA)
   case 2: WriteByte(&h1A0DC, &h06): WriteByte(&h1A0DD, &hAD): WriteByte(&h1A0DE, &hEA): WriteByte(&h1A0DF, &hEA)
   case else: WriteByte(&h1A0DC, &h06): WriteByte(&h1A0DD, &hAD): WriteByte(&h1A0DE, &h06): WriteByte(&h1A0DF, &hAD)
  end select
 end if

 'the statuses that change the damage
 dim mask_offsets(1 to 6) as UInteger = {&h1C951, &h1C961, &h1C7EE, &h1D2F0, &h1CAA3, &h1CB28}
 for k as Integer = 1 to 6
  if st_known(k) then WriteByte(mask_offsets(k), st_mask(k))
 next
 if st_known(1) then
  WriteByte(&h1C955, st_power mod &h100)
  WriteByte(&h1C956, st_power \ &h100)
 end if
 if st_known(2) then
  dim mult_text as String
  select case st_mult
   case 1: mult_text = "4E03396E0239"
   case 2: mult_text = "EAEAEAEAEAEA"
   case else: mult_text = "0E02392E0339"
  end select
  for i as Integer = 0 to 5
   WriteByte(&h1C964 + i, val("&h" + mid(mult_text, i * 2 + 1, 2)))
  next
  if st_defense_zero then
   WriteByte(&h1C96A, &h7B): WriteByte(&h1C96B, &hAA): WriteByte(&h1C96C, &h8E): WriteByte(&h1C96D, &h04): WriteByte(&h1C96E, &h39)
  else
   for i as Integer = 0 to 4
    WriteByte(&h1C96A + i, &hEA)
   next
  end if
 end if
 if dispel_known then
  WriteByte(&h1DAC1, &hFF - dispel_s2)
  WriteByte(&h1DADD, &hFF - dispel_s4)
 end if
 if hole_known then
  WriteByte(&h1DFB4, &hFF - hole_s2)
  WriteByte(&h1DFBC, &hFF - hole_s4)
 end if
 if hole_speed_known then
  if hole_speed then
   WriteByte(&h1DFC0, &hA9): WriteByte(&h1DFC1, &h10): WriteByte(&h1DFC2, &h8D): WriteByte(&h1DFC3, &h3B): WriteByte(&h1DFC4, &h27)
  else
   for i as Integer = 0 to 4
    WriteByte(&h1DFC0 + i, &hEA)
   next
  end if
 end if
 if buff_known then
  WriteByte(&h1DA6A, protect_add)
  WriteByte(&h1DA8E, shell_add)
 end if
 if zeromus_known then
  if protect_zeromus then
   WriteByte(&h1DA63, &hEA): WriteByte(&h1DA64, &hEA)
  else
   WriteByte(&h1DA63, &hD0): WriteByte(&h1DA64, &h0D)
  end if
  if shell_zeromus then
   WriteByte(&h1DA87, &hEA): WriteByte(&h1DA88, &hEA)
  else
   WriteByte(&h1DA87, &hD0): WriteByte(&h1DA88, &h0D)
  end if
 end if
 if doom_known then
  WriteByte(&h184BF, doom_ticks)
  WriteByte(&h19912, doom_ticks)
  WriteByte(&h1AC03, &h80 shr (doom_status - 1))
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
