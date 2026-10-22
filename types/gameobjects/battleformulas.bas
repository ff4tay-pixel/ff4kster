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
 summon_book(9) as UByte 'the 10 summons the Summon Book can call: the spell, plus 80h for one random target

 declare static function PowerNames() as String
 declare static function PowerBytes() as String
 declare static function SummonNames() as String
 declare static function SummonBytes() as String
 declare static function DivisorNames() as String
 declare static function StatsNames() as String

 declare sub ReadFromROM()
 declare sub WriteToROM()

end type
