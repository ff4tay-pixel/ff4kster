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
 code_choice(2) as UByte 'Dark Wave and Kick: which known code variant is in the ROM (0 = not one of the known ones)
 extra_delay as UByte 'Charge, Twin, Regen: the entry of the delay table (the 3 hidden ones) used by their second part
 jump_wait as UByte 'Jump: ticks before it leaves
 jump_air as UByte 'Jump: ticks in the air
 behaves_like as UByte 'command 22 only: the command whose routine it runs (0 = none)

 declare static function DelayText(value as UByte) as String
 declare static function CodeRows(index as UByte) as Integer
 declare static function CodeTitle(index as UByte, row as Integer) as String
 declare static function CodeOffset(index as UByte, row as Integer) as UInteger
 declare static function CodeNames(index as UByte, row as Integer) as String
 declare static function CodeBytes(index as UByte, row as Integer) as String
 declare static function CodeItem(s as String, n as Integer) as String
 declare static function CanBeCopied(index as UByte) as Boolean
 declare static function HasParameters(index as UByte) as Boolean
 declare static function TargetsCorrectly(index as UByte) as Boolean
 
 declare sub ReadCode(index as UByte)
 declare sub WriteCode(index as UByte)
 declare sub ReadFromROM(index as UByte)
 declare sub WriteToROM(index as UByte)

end type
