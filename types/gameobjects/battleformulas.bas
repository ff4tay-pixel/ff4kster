type BattleFormulas

 'The spell damage settings of the Battle Formulas editor and the Summon Book (battle/magic.asm in the disassembly).
 ' Each choice is the number of one of the known byte sequences of the original code (see the
 ' Names / Bytes functions); 0 means the bytes are none of them, which the editor leaves alone.
 power_choice as UByte 'power scale of spells
 summon_choice as UByte 'power scale of summons
 divisor_choice as UByte 'the divisor of the caster's stat that gives the number of tries
 stats_choice as UByte 'which two stats the tries and the hit rate use (black magic, then white)
 hits_known as Boolean 'false if the code that gives items and summons a fixed number of hits is not the original
 fixed_hits as UByte 'the number of hits of summons and spells cast from items
 term_stat(12) as UByte 'the stat terms of the character stat formulas: 1 level, 2 STR ... 6 WIL, 0 custom code
 term_div(12) as UByte 'and what they are divided by: 1 nothing, 2 /2, 3 /4 ... 7 /64, 0 custom code
 plus_known as Boolean 'the plus 1 of the attack multiplier can be switched
 plus_on as Boolean
 buff_known as Boolean 'Armor (protect) and Shell: the numbers they add to the defense and to the magic defense
 protect_add as UByte 'added to the defense of the target by magic effect $0d, 5 in the original
 shell_add as UByte 'added to the magic defense by magic effect $0e, 3 in the original
 back_known as Boolean 'the back row rules of Fight, see BackEffectOffset: whether the code is the original
 back_hit(2) as UByte 'the hit rate of an attacker in the back row (1) and against a target in the back row (2): 1 halved, 2 unchanged, 3 doubled
 back_flag(2) as Boolean 'a unit with the no back row penalty flag (the bow) is not affected
 back_jump(2) as Boolean 'a jumping unit is not affected
 back_def as UByte 'the defense of a target in the back row: 1 x0.5, 2 x1, 3 x2 (original)
 slot_known(4) as Boolean 'the bonus of the unit in the first slot, see SlotUnitOffset: whether the code is the original
 slot_who(4) as UByte 'who gets it: 1 the first slot of both sides (original), 2 the first slot of the party, 3 the whole party, 4 units with a status
 slot_mult(4) as UByte 'the rate is multiplied by this and divided by 4: 5 in the original, 25% more
 slot_free as Boolean 'the free space for the shared routine of the status rules (bank 3, 201D0) is free or has it
 slot_list(4) as UByte 'the status list (1 to 4) that a rule with who = 4 looks at
 slot_mask(4) as UByte 'its statuses
 slot_unit(4) as Boolean 'the unit that the rule looks at: false the attacker, true the target. The original game: the attacker for rules 1, 3 and 4 (4 is probably a mistake), the target for rule 2
 um_known(11) as Boolean 'the other status rules of the damage formulas, see UmLdaOffset: whether the code is the original
 um_list(11) as UByte 'the status byte the rule tests: 1 persistent (status 1), 2 temporary, 3 system, 4 hidden
 um_mask(11) as UByte 'the statuses of that byte that switch the rule on
 um_effect(11) as UByte 'what the rule does: 1 to 3, the order of the names of the effect (0 if the code is not a known one)
 poison_div as UByte 'poison takes the max HP divided by 2 (1), 4, 8 (3, original), 16, 32 or 64 (6) every tick
 poison_known as Boolean
 sap_damage as UByte 'the HP an HP leak takes every tick, 2 in the original
 wait_known as Boolean 'the wait between the ticks of poison: a stat of the character plus a number, in ticks
 wait_stat as UByte '1 level, 2 STR ... 6 WIL, the stat of a character (a monster uses its level plus 10)
 wait_const as UByte 'the number that is added, 20 in the original
 sap_every_known as Boolean 'HP leak takes its HP every this many ticks, 1 in the original
 sap_every as UByte
 sap_len_known as Boolean 'how long HP leak lasts: the sum of the WIS and the WIL of the character times a number plus a number
 sap_len_mult as UByte '2 in the original
 sap_len_const as UByte '30 in the original
 sap_known as Boolean
 sleep_known as Boolean 'sleep and paralyze last (base minus multiplier x spirit) divided by a number, in ticks
 sleep_base as UInteger 'the base, 300 in the original
 sleep_mult as UByte 'the multiplier of the spirit: 1 x1, 2 x2, 3 x4 (original)
 sleep_div as UByte 'the divisor, 6 in the original
 st_known(6) as Boolean 'the statuses (of status 1) that make the damage formulas of Fight and spells change, see below
 st_mask(6) as UByte '1 weak attacker, 2 hurt target, 3 target with no defense multiplier, 4 target with no magic defense
  ' multiplier, 5 attacker that inflicts no status, 6 attacker that uses no arrows: the statuses that trigger it
 st_power as UInteger 'the attack power of a weak attacker, 1 in the original
 st_mult as UByte 'what the attack power of a hurt target is multiplied by: 1 x0.5, 2 x1, 3 x2 (original)
 st_defense_zero as Boolean 'the defense of a hurt target becomes 0 (original) or stays
 dispel_known as Boolean 'Dispel (magic effect $10) removes the status bits that are not kept by two masks
 dispel_s2 as UByte 'the bits of status 2 that Dispel removes: curse 80, float 40, paralyze 20, sleep 10, charm 08, berserk 04
 dispel_s4 as UByte 'and of status 4: hp leak 40, reflect 20, barrier 10, image 0C
 hole_known as Boolean 'Black hole (magic effect $2A) does the same
 hole_s2 as UByte
 hole_s4 as UByte
 hole_speed_known as Boolean 'and sets the speed modifier of the target back to normal
 hole_speed as Boolean
 zeromus_known as Boolean 'false if the check of the Zeromus battle is not the original or switched off
 protect_zeromus as Boolean 'Armor also works in the Zeromus battle (the original game skips it there)
 shell_zeromus as Boolean
 doom_known as Boolean 'Count (doom): the ticks of the timer loop for one step of the count, and what the end of it does
 doom_ticks as UByte 'one step of the count every this many ticks, 2 in the original
 doom_status as UByte 'the status the end of the count gives: 1 dead (original), 2 stone, 3 toad, 4 mini, 5 pig, 6 mute, 7 blind, 8 poison
 yang_known as Boolean 'Yang's attack: level x 2 plus STR / 4 plus 2
 yang_stat as UByte 'the first term, a stat (1 level ... 6 WIL)
 yang_mult as UByte 'times 2 (1, original) or times 1 (2)
 yang_plus as UByte 'the constant that is added
 speed_known as Boolean 'the turn wait: anchor's agility x numerator / (own agility x multiplier plus add)
 speed_anchor as Boolean 'false: the numerator alone (the anchor's agility is not used)
 speed_num as UInteger
 speed_mul as UByte
 speed_add as UInteger
 summon_book(9) as UByte 'the 10 summons the Summon Book can call: the spell, plus 80h for one random target

 declare static function UmLdaOffset(r as Integer) as UInteger
 declare static function UmMaskOffset(r as Integer) as UInteger
 declare static function UmEffectOffset(r as Integer) as UInteger
 declare static function UmKind(r as Integer) as Integer
 declare static function UmUnit(r as Integer) as Integer
 declare static function UmEffectBytes(r as Integer, choice as Integer) as String
 declare static function UmEffectNames(r as Integer) as String
 declare static function PowerNames() as String
 declare static function PowerBytes() as String
 declare static function SummonNames() as String
 declare static function SummonBytes() as String
 declare static function DivisorNames() as String
 declare static function StatsNames() as String
 declare static function TermStatOffset(t as Integer) as UInteger
 declare static function TermShiftOffset(t as Integer) as UInteger
 declare static function TermShiftLength(t as Integer) as Integer
 declare static function TermStatNames() as String
 declare static function TermDivNames(t as Integer) as String

 declare sub ReadFromROM()
 declare sub WriteToROM()

end type
