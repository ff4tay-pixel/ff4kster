type CommandParametersMenu

 x as UByte
 y as UByte
 id as UByte
 item_menu as BlueMenu
 spell_menu as BlueMenu
 success_input as BlueNumberInput
 slot_menu as BlueMenu
 multiplier_menu as BlueMenu
 whole_menu as BlueMenu 'the multipliers that work without half steps
 whole_values(6) as UByte
 stat_menu as BlueMenu
 message_menu as BlueMenu
 actor_menu as BlueMenu
 fight_menu as BlueMenu
 recall_menu as BlueMenu
 sing_menu as BlueMenu
 hide_menu as BlueMenu
 split_menu as BlueMenu
 pray_menu as BlueMenu
 charge_menu as BlueMenu
 bear_menu as BlueMenu
 twin_menu as BlueMenu
 boast_menu as BlueMenu
 cry_menu as BlueMenu
 cover_menu as BlueMenu
 steal_menu as BlueMenu
 regen_menu as BlueMenu
 clone_menu as BlueMenu
 aim_menu as BlueMenu 'Aim: which stats it changes
 code_menu as BlueMenu 'Dark Wave and Kick: the code settings
 code_choice_menu as BlueMenu
 fail_menu as BlueMenu 'Jump and Throw: the message when the action fails, Throw also has its damage formula here
 source_menu as BlueMenu
 share_menu as BlueMenu 'shared settings or own settings, asked after the routine is picked
 source_ids(60) as UByte

 declare constructor(starting_x as UByte = 0, starting_y as UByte = 0)
 
 declare function MultiplierText(value as Integer) as String
 declare sub Display()
 declare function Kind() as Integer
 declare function OwnPossible(k as Integer) as Boolean
 declare sub PickRoutine()
 declare sub PickMessage(byref msg as UByte, px as Integer, py as Integer, allow_none as Boolean = true)
 declare sub EditAlertText(number as Integer)
 declare function FlagKind(stat as Integer) as String
 declare function FlagText(list_kind as String, flag_value as Integer) as String
 declare function PickFlags(list_kind as String, flag_value as Integer, px as Integer, py as Integer) as Integer
 declare sub SetTo(index as UByte)
 declare sub EditThrowRow(row as Integer)
 declare sub UserSelect()

end type
