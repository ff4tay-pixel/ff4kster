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
 um_known(11) as Boolean 'the other status rules of the damage formulas, see UmLdaOffset: whether the code is the original
 um_list(11) as UByte 'the status byte the rule tests: 1 persistent (status 1), 2 temporary, 3 system, 4 hidden
 um_mask(11) as UByte 'the statuses of that byte that switch the rule on
 um_effect(11) as UByte 'what the rule does: 1 to 3, the order of the names of the effect (0 if the code is not a known one)
 poison_div as UByte 'poison takes the max HP divided by 2 (1), 4, 8 (3, original), 16, 32 or 64 (6) every tick
 poison_known as Boolean
 sap_damage as UByte 'the HP an HP leak takes every tick, 2 in the original
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
