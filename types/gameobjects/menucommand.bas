type MenuCommand

 name as String
 target as UByte
 target_byte as UByte
 delay as UByte
 disabling_persistent as UByte
 disabling_temporary as UByte
 charging_stance as UByte
 action_stance as UByte
 action_stance2 as UByte
 action_stance3 as UByte
 spell(8) as UByte
 success(8) as UByte
 message(5) as UByte
 item_consumed as UByte
 item_effect as UByte
 item_visual as UByte
 regen_amount as UByte
 regen_freeze as Boolean
 disable_actor as UByte
 cover_actor as UByte
 cover_by_job as Boolean
 misc_bytes(8) as UByte
 code_choice(3) as UByte 'Dark Wave and Kick: which known code variant is in the ROM (0 = not one of the known ones)
 extra_delay as UByte 'Charge, Twin, Regen: the entry of the delay table (the 3 hidden ones) used by their second part
 jump_wait as UByte 'Jump: ticks before it leaves
 jump_air as UByte 'Jump: ticks in the air
 reversed as Boolean 'Boast raises or lowers, Cry lowers or raises: the code is the reversed variant
 reverse_known as Boolean 'false if those bytes are not one of the two known variants
 aim_known as Boolean 'false if the Aim code is not one of the known variants
 aim_target_stat as UByte 'byte of the target properties that Aim changes (the game sets it to 0)
 aim_user_stat as UByte 'byte of the user properties that Aim changes (the game sets it to 255)
 aim_target_set as Boolean
 aim_user_set as Boolean
 throw_known as Boolean 'false if the Throw damage code is not the original
 throw_stat as UByte 'byte of the user's properties the item power is multiplied by (the level)
 throw_cap as UInteger 'largest damage a thrown item does
 recall_check_known as Boolean 'Recall: false if the MP check code is not the original or the known variant
 recall_cost_known as Boolean 'Recall: same for the code that makes it spend MP
 recall_needs_mp as Boolean 'Recall does nothing if the user has less MP than the spell costs
 recall_uses_mp as Boolean 'Recall takes the spell's MP
 halfsteps_known as Boolean 'Fight: false if the damage multiplier routine is not the original or the half step one
 halfsteps_on as Boolean 'Fight: the damage multiplier routine understands half steps (x1.5, x2.5, x3.5)
 behaves_known as Boolean 'command 22 only: false if its jump table entry is a routine of the ROM that is none of the commands'
 steal_known as Boolean 'Steal: false if the chance code is not the original (the lowest and highest chance, being caught)
 steal_min as UByte 'Steal: the lowest chance, 1 in the original
 steal_max as UByte 'Steal: the highest chance, 99 in the original
 steal_caught_fixed as Boolean 'Steal: a failed steal is caught at a fixed chance and not at the level of the target plus 10
 steal_caught as UByte 'Steal: that fixed chance
 steal_shift as UByte 'Steal: a thief that is caught loses its max HP divided by 2 to this power, 4 (1/16) in the original
 behaves_like as UByte 'command 22 only: the command whose routine it runs (0 = none)

 declare static function ReverseParts(index as UByte) as Integer
 declare static function ReverseOffset(index as UByte, part as Integer) as UInteger
 declare static function ReverseBytes(index as UByte, part as Integer, reversed as Boolean) as String
 declare static function BytesAre(offset as UInteger, hex_text as String) as Boolean
 declare static function DelayDescription(index as UByte, value as UByte) as String
 declare static function DelayText(value as UByte) as String
 declare static function CodeRows(index as UByte) as Integer
 declare static function CodeTitle(index as UByte, row as Integer) as String
 declare static function CodeOffset(index as UByte, row as Integer) as UInteger
 declare static function CodeNames(index as UByte, row as Integer) as String
 declare static function CodeBytes(index as UByte, row as Integer) as String
 declare static function CodeItem(s as String, n as Integer) as String
 declare static function CodeItemMatches(offset as UInteger, item as String) as Boolean
 declare static function CodeRegion(index as UByte, row as Integer) as UInteger
 declare static function CanBeCopied(index as UByte) as Boolean
 declare static function HasParameters(index as UByte) as Boolean
 declare static function TargetsCorrectly(index as UByte) as Boolean
 
 declare sub ReadHalfSteps()
 declare sub WriteHalfSteps()
 declare sub ReadRecall()
 declare sub WriteRecall()
 declare sub ReadThrow()
 declare sub ReadStealChance()
 declare sub WriteStealChance()
 declare sub WriteThrow()
 declare sub ReadAim()
 declare sub WriteAim()
 declare sub ReadReverse(index as UByte)
 declare sub WriteReverse(index as UByte)
 declare function SameAs(other as MenuCommand) as Boolean
 declare sub ReadCode(index as UByte)
 declare sub WriteCode(index as UByte)
 declare sub ReadFromROM(index as UByte)
 declare sub WriteToROM(index as UByte)

end type
