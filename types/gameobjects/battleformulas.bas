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
