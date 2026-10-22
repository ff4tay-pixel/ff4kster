function MenuCommand.HasParameters(index as UByte) as Boolean

 dim temp as Boolean
 
 select case index
  case 14, 24, 26
   temp = true
  case 8 to 12
   temp = true
  case 16 to 20
   temp = true
  case 22
   temp = true
  case 7, 23
   temp = true
  case 13, 21
   temp = true
 end select

 return temp


end function


function MenuCommand.CanBeCopied(index as UByte) as Boolean

 'Whether command 22 can borrow this command's routine: the game must have one for it
 ' (White, Black, Call and Ninja are run by the spell menu, they have none).

 return index <> 22 and (ByteAt(&h1B57C + (index - 1) * 2) <> 0 or ByteAt(&h1B57D + (index - 1) * 2) <> 0)

end function


function MenuCommand.TargetsCorrectly(index as UByte) as Boolean

 return index = 8 or index = 9 or index = 11 or index = 12 or index = 16 or index = 17 or index = 22

end function


function MenuCommand.DelayText(value as UByte) as String

 'What an entry of the action delay table means (battle/timer_dur.asm, TimerDur_0c): 0 no wait, 1 to 127
 ' a fraction of the unit's turn timer (1 = a whole one), 128 and up that many turns.

 dim result as String

 if value = 0 then
  result = "no wait"
 elseif value = 1 then
  result = "1 turn timer"
 elseif value < 128 then
  result = "1/" + str(value) + " of a turn timer"
 else
  result = str(value - 128) + " x the turn timer"
 end if

 return result

end function


function MenuCommand.BytesAre(offset as UInteger, hex_text as String) as Boolean

 'Whether the ROM holds exactly these bytes (hex text) at offset.

 for i as Integer = 0 to len(hex_text) \ 2 - 1
  if ByteAt(offset + i) <> val("&h" + mid(hex_text, i * 2 + 1, 2)) then return false
 next

 return true

end function


function MenuCommand.ReverseParts(index as UByte) as Integer

 'Boast (18) and Cry (19) raise or lower a stat with a few bytes of code that can be swapped for the
 ' opposite operation (add or subtract, with a cap of 99 or a floor of 0 or 1). Three pieces each.

 if index = 18 or index = 19 then return 3

 return 0

end function


function MenuCommand.ReverseOffset(index as UByte, part as Integer) as UInteger

 if index = 18 then
  select case part
   case 1: return &h1ECCF 'clc or sec
   case 2: return &h1ECD3 'adc or sbc, the amount follows
   case 3: return &h1ECD5 'the cap or the floor
  end select
 else
  select case part
   case 1: return &h1ED0A
   case 2: return &h1ED0E
   case 3: return &h1ED10
  end select
 end if

 return 0

end function


function MenuCommand.ReverseBytes(index as UByte, part as Integer, reversed as Boolean) as String

 'The bytes of the original code (reversed false) or of the reversed one, in hex. Boast: raise with
 ' adc, capped at 99 / lower with sbc, stopping at 0. Cry: lower with sbc, stopping at 1 / raise with
 ' adc, capped at 99.

 if index = 18 then
  select case part
   case 1: if reversed then return "38" else return "18"
   case 2: if reversed then return "E9" else return "69"
   case 3: if reversed then return "B002A900EAEA" else return "C9639002A963"
  end select
 else
  select case part
   case 1: if reversed then return "18" else return "38"
   case 2: if reversed then return "65A9" else return "E5A9"
   case 3: if reversed then return "C9649002A963" else return "F002B002A901"
  end select
 end if

 return ""

end function


sub MenuCommand.ReadReverse(index as UByte)

 dim matches as Boolean

 reverse_known = false
 reversed = false
 if ReverseParts(index) = 0 then exit sub

 for variant as Integer = 0 to 1
  matches = true
  for part as Integer = 1 to ReverseParts(index)
   if not BytesAre(ReverseOffset(index, part), ReverseBytes(index, part, (variant = 1))) then matches = false
  next
  if matches then
   reverse_known = true
   reversed = (variant = 1)
   exit for
  end if
 next

end sub


sub MenuCommand.WriteReverse(index as UByte)

 dim bytes_text as String

 if ReverseParts(index) = 0 or not reverse_known then exit sub

 for part as Integer = 1 to ReverseParts(index)
  bytes_text = ReverseBytes(index, part, reversed)
  for i as Integer = 0 to len(bytes_text) \ 2 - 1
   WriteByte(ReverseOffset(index, part) + i, val("&h" + mid(bytes_text, i * 2 + 1, 2)))
  next
 next

end sub


sub MenuCommand.ReadHalfSteps()

 'The routine that applies an elemental or race multiplier to the damage (ApplyDmgMult in battle/damage.asm)
 ' shifts the multiplier right once before using it, so the half steps x1.5, x2.5 and x3.5 (3, 5 and 7)
 ' act as x1, x2 and x3. The replacement multiplies by the whole value and then halves the 32 bit result:
 ' the same damage for every value the game uses (0, 1, 2, 4, 8) and a real x1.5, x2.5 and x3.5. It is
 ' called by CalcDmg only, so it also applies to spells. It is 3 bytes shorter, the rest are nops.

 halfsteps_on = false
 halfsteps_known = false
 if BytesAre(&h1CC51, "D00564A464A5604AD00546A566A460AA8E3D39A6A48E3F3920B983AE413986A460") then halfsteps_known = true
 if BytesAre(&h1CC51, "AA8E3D39A6A48E3F3920B9834E44396E43396E42396E4139AE413986A460EAEAEA") then
  halfsteps_known = true
  halfsteps_on = true
 end if

end sub


sub MenuCommand.WriteHalfSteps()

 dim bytes_text as String

 if not halfsteps_known then exit sub

 if halfsteps_on then bytes_text = "AA8E3D39A6A48E3F3920B9834E44396E43396E42396E4139AE413986A460EAEAEA" else bytes_text = "D00564A464A5604AD00546A566A460AA8E3D39A6A48E3F3920B983AE413986A460"
 for i as Integer = 0 to len(bytes_text) \ 2 - 1
  WriteByte(&h1CC51 + i, val("&h" + mid(bytes_text, i * 2 + 1, 2)))
 next

end sub


sub MenuCommand.ReadRecall()

 'Recall picks a random spell and then (Cmd_07 in battle/cmd.asm) does nothing at all if the user has
 ' less MP than the spell costs: that is one branch, beq (F0) in the code, or bra (80) to always go on.
 ' The MP is taken by magic.asm when $355d is not 0. $355d is raised for Recall in ExecCmd
 ' (battle/attack.asm: cmp #$07) and once more in Cmd_07 itself, so removing the cost means changing
 ' that compare to a command number that never occurs (FF) and the inc in Cmd_07 to nops.

 recall_check_known = (ByteAt(&h1ECB1) = &h06 and (ByteAt(&h1ECB0) = &hF0 or ByteAt(&h1ECB0) = &h80))
 recall_needs_mp = (ByteAt(&h1ECB0) = &hF0)

 recall_uses_mp = (ByteAt(&h1B340) = &h07 and ByteAt(&h1ECBC) = &hEE and ByteAt(&h1ECBD) = &h5D and ByteAt(&h1ECBE) = &h35)
 recall_cost_known = recall_uses_mp
 if ByteAt(&h1B340) = &hFF and ByteAt(&h1ECBC) = &hEA and ByteAt(&h1ECBD) = &hEA and ByteAt(&h1ECBE) = &hEA then recall_cost_known = true

end sub


sub MenuCommand.WriteRecall()

 if recall_check_known then
  if recall_needs_mp then WriteByte(&h1ECB0, &hF0) else WriteByte(&h1ECB0, &h80)
 end if

 if recall_cost_known then
  if recall_uses_mp then
   WriteByte(&h1B340, &h07)
   WriteByte(&h1ECBC, &hEE)
   WriteByte(&h1ECBD, &h5D)
   WriteByte(&h1ECBE, &h35)
  else
   WriteByte(&h1B340, &hFF)
   WriteByte(&h1ECBC, &hEA)
   WriteByte(&h1ECBD, &hEA)
   WriteByte(&h1ECBE, &hEA)
  end if
 end if

end sub


sub MenuCommand.ReadThrow()

 'Throw (dart): damage is the item's attack power times one of the user's stats (the level) plus a random
 ' amount, at most 9999 (battle/cmd.asm, Cmd_16). The stat is an address in the code ($2680 + n), the cap
 ' is a 16 bit value that is in the code twice (compare and load).

 throw_known = (ByteAt(&h1E595) = &hAD and ByteAt(&h1E597) = &h26 and ByteAt(&h1E596) >= &h80)
 throw_known = throw_known and ByteAt(&h1E5B4) = &hE0 and ByteAt(&h1E5B9) = &hA2
 throw_known = throw_known and ByteAt(&h1E5B5) = ByteAt(&h1E5BA) and ByteAt(&h1E5B6) = ByteAt(&h1E5BB)
 throw_stat = ByteAt(&h1E596) mod &h80
 throw_cap = ByteAt(&h1E5B5) + ByteAt(&h1E5B6) * &h100

end sub


sub MenuCommand.WriteThrow()

 if not throw_known then exit sub

 WriteByte(&h1E596, &h80 + throw_stat)
 WriteByte(&h1E5B5, throw_cap mod &h100)
 WriteByte(&h1E5B6, throw_cap \ &h100)
 WriteByte(&h1E5BA, throw_cap mod &h100)
 WriteByte(&h1E5BB, throw_cap \ &h100)

end sub


sub MenuCommand.ReadAim()

 'Aim saves the target's evasion and the user's hit rate, sets them to 0 and 255, attacks and puts them
 ' back (battle/cmd.asm). The two bytes are addresses in the code: $2680 + n is the user's property n,
 ' $2700 + n the target's. Each "set" can also be removed (the bytes become nops).

 dim start_at as UInteger = &h1EA36
 dim b(0 to 27) as Integer

 for i as Integer = 0 to 27
  b(i) = ByteAt(start_at + i)
 next

 aim_target_set = (b(9) = &h8D)
 aim_user_set = (b(12) = &h3A)
 aim_target_stat = b(5)
 aim_user_stat = b(1) - &h80

 aim_known = (b(0) = &hAD and b(2) = &h26 and b(3) = &h48 and b(4) = &hAD and b(6) = &h27 and b(7) = &h48)
 aim_known = aim_known and b(8) = &h7B and b(19) = &h68 and b(20) = &h8D and b(22) = &h27
 aim_known = aim_known and b(23) = &h68 and b(24) = &h8D and b(26) = &h26 and b(27) = &h60
 aim_known = aim_known and b(1) >= &h80 and b(5) < &h80 and b(21) = b(5) and b(25) = b(1)
 if aim_target_set then
  aim_known = aim_known and b(10) = b(5) and b(11) = &h27
 else
  aim_known = aim_known and b(9) = &hEA and b(10) = &hEA and b(11) = &hEA
 end if
 if aim_user_set then
  aim_known = aim_known and b(13) = &h8D and b(14) = b(1) and b(15) = &h26
 else
  aim_known = aim_known and b(12) = &hEA and b(13) = &hEA and b(14) = &hEA and b(15) = &hEA
 end if

end sub


sub MenuCommand.WriteAim()

 dim start_at as UInteger = &h1EA36

 if not aim_known then exit sub

 WriteByte(start_at + 1, &h80 + aim_user_stat)
 WriteByte(start_at + 5, aim_target_stat)
 WriteByte(start_at + 21, aim_target_stat)
 WriteByte(start_at + 25, &h80 + aim_user_stat)
 if aim_target_set then
  WriteByte(start_at + 9, &h8D)
  WriteByte(start_at + 10, aim_target_stat)
  WriteByte(start_at + 11, &h27)
 else
  for i as Integer = 9 to 11
   WriteByte(start_at + i, &hEA)
  next
 end if
 if aim_user_set then
  WriteByte(start_at + 12, &h3A)
  WriteByte(start_at + 13, &h8D)
  WriteByte(start_at + 14, &h80 + aim_user_stat)
  WriteByte(start_at + 15, &h26)
 else
  for i as Integer = 12 to 15
   WriteByte(start_at + i, &hEA)
  next
 end if

end sub


#include once "crt/string.bi"

sub MenuCommand.ReadStealChance()

 'The chance of Steal (battle/cmd.asm, Cmd_17): rate = level of the thief + base - (level of the target + 10),
 ' at least 1 and at most 99 (lda #base, adc, sbc, lda #1, cmp #99, lda #99); a random number 0 to 98 must not
 ' be above the rate. A failed steal is caught if another random number is below the level of the target
 ' plus 10 (cmp $272f, or cmp #n with a nop for a fixed chance), and the thief then loses max HP shifted right
 ' by a call to one of the Lsr routines (83 to 87 of the battle code, Lsr_4 in the original).

 steal_known = (ByteAt(&h1E3F0) = &hA9 and ByteAt(&h1E3FB) = &hA9 and ByteAt(&h1E3FF) = &hC9 and ByteAt(&h1E403) = &hA9)
 steal_min = ByteAt(&h1E3FC)
 steal_max = ByteAt(&h1E400)
 if ByteAt(&h1E404) <> steal_max then steal_known = false
 steal_caught_fixed = (ByteAt(&h1E40C) = &hC9)
 steal_caught = 0
 if steal_caught_fixed then
  steal_caught = ByteAt(&h1E40D)
  if ByteAt(&h1E40E) <> &hEA then steal_known = false
 elseif not BytesAre(&h1E40C, "CD2F27") then
  steal_known = false
 end if
 steal_shift = 0
 if ByteAt(&h1E416) = &h20 and ByteAt(&h1E418) = &h84 and ByteAt(&h1E417) >= &h82 and ByteAt(&h1E417) <= &h87 then steal_shift = &h88 - ByteAt(&h1E417)
 if steal_shift = 0 then steal_known = false

end sub


sub MenuCommand.WriteStealChance()

 if not steal_known then exit sub

 WriteByte(&h1E3FC, steal_min)
 WriteByte(&h1E400, steal_max)
 WriteByte(&h1E404, steal_max)
 if steal_caught_fixed then
  WriteByte(&h1E40C, &hC9): WriteByte(&h1E40D, steal_caught): WriteByte(&h1E40E, &hEA)
 else
  WriteByte(&h1E40C, &hCD): WriteByte(&h1E40D, &h2F): WriteByte(&h1E40E, &h27)
 end if
 WriteByte(&h1E417, &h88 - steal_shift)

end sub


function MenuCommand.SameAs(other as MenuCommand) as Boolean

 'Whether every setting of the command is the same as in another copy, which is how the editor knows a command
 ' was not edited and leaves the ROM bytes of it alone (a ROM hack may have changed the code that they are in).

 if name <> other.name then return false

 return memcmp(@target, @other.target, sizeof(MenuCommand) - offsetof(MenuCommand, target)) = 0

end function


function MenuCommand.DelayDescription(index as UByte, value as UByte) as String

 'The delay of a command as the Information screen shows it. The game reads the table only for commands
 ' picked from the command menu (char.asm): Item and the spell menus (White, Black, Call, Ninja) use the
 ' delay of the item or spell, and Jump always waits 4 ticks (TimerDur_0c in timer_dur.asm).

 select case index
  case 2 to 5, 25
   return str(value) + ", not used, the delay of the item or spell applies"
  case 7
   return str(value) + ", not used, Jump waits the ticks of its Parameters"
 end select

 return str(value) + ", " + DelayText(value)

end function


function MenuCommand.CodeRows(index as UByte) as Integer

 'Settings that are not data bytes but small changes to the game's code. Each one is a few bytes
 ' that are replaced by another known sequence of the same length (found with the disassembly,
 ' battle/cmd.asm). Only the known variants can be chosen.

 select case index
  case 6: return 3 'Dark Wave
  case 15: return 2 'Kick
  case 21: return 1 'Peep
  case 23: return 1 'Throw
 end select

 return 0

end function


function MenuCommand.CodeTitle(index as UByte, row as Integer) as String

 select case index
  case 6
   if row = 1 then return "HP the user loses:    "
   if row = 2 then return "Damage to undead:     "
   return "Base damage, both:    "
  case 15
   if row = 1 then return "Attack multiplier:    "
   return "Base damage, both:    "
  case 21
   return "Bosses:               "
  case 23
   return "Random part added:    "
 end select

 return ""

end function


function MenuCommand.CodeOffset(index as UByte, row as Integer) as UInteger

 select case index
  case 6
   if row = 1 then return &h1EBF4
   if row = 2 then return &h1E9A3
   return &h1E93A
  case 15
   if row = 1 then return &h1E924
   return &h1E93A
  case 21
   return &h1E356
  case 23
   return &h1E5A2
 end select

 return 0

end function


function MenuCommand.CodeNames(index as UByte, row as Integer) as String

 'The choices, separated by |. The first one that matches the ROM is shown, the order matches CodeBytes.

 select case index
  case 6
   if row = 1 then return "1/2 of max HP|1/4 of max HP|1/8 of max HP, original|1/16 of max HP|1/32 of max HP|1/64 of max HP|None"
   if row = 2 then return "Full damage|Half damage|Quarter damage, original"
   return "x0.25|x0.5, original|x1|x1.5|x2|x3|x4|x8"
  case 15
   if row = 1 then return "Half, original|Full|Double"
   return "x0.25|x0.5, original|x1|x1.5|x2|x3|x4|x8"
  case 21
   return "Cannot be peeked at, original|Can be peeked at"
  case 23
   return "0 to 98, original|None|0 to 255"
 end select

 return ""

end function


function MenuCommand.CodeBytes(index as UByte, row as Integer) as String

 'The bytes of each choice in hex, separated by |. Dark Wave cost: a call to a routine that shifts the
 ' 16 bit value right by N (Lsr_N in the disassembly) or "lda #0". Damage to undead: two shift pairs
 ' (lsr/ror) of which the choices keep two, one or none. Kick: lsr, nothing or asl on the multiplier.
 ' Base damage: the shared half of multiplier x power (lsr/ror), nothing, or doubled (asl/rol), used by
 ' both commands, so it is the same bytes on both screens. The other multipliers call a routine in free space
 ' (see CodeRegion).
 ' Peep: the branch that skips bosses (bpl) or an always taken branch (bra).

 select case index
  case 6
   if row = 1 then return "208784|208684|208584|208484|208384|208284|A90000"
   if row = 2 then return "EAEAEAEAEAEAEAEA|46CA66C9EAEAEAEA|46CA66C946CA66C9"
   return "2000FFEA@20100=46E466E346E466E360|46E466E3|EAEAEAEA|2000FFEA@20100=A6E38E3D394E3E396E3D3918A5E36D3D3985E3A5E46D3E3985E49006A2FFFF86E36060|06E326E4|2000FFEA@20100=A6E38E3D3906E326E49006A2FFFF86E36018A5E36D3D3985E3A5E46D3E3985E49006A2FFFF86E36060|2000FFEA@20100=06E326E49006A2FFFF86E36006E326E49006A2FFFF86E36060|2000FFEA@20100=06E326E49006A2FFFF86E36006E326E49006A2FFFF86E36006E326E49006A2FFFF86E36060"
  case 15
   if row = 1 then return "46DF|EAEA|06DF"
   return "2000FFEA@20100=46E466E346E466E360|46E466E3|EAEAEAEA|2000FFEA@20100=A6E38E3D394E3E396E3D3918A5E36D3D3985E3A5E46D3E3985E49006A2FFFF86E36060|06E326E4|2000FFEA@20100=A6E38E3D3906E326E49006A2FFFF86E36018A5E36D3D3985E3A5E46D3E3985E49006A2FFFF86E36060|2000FFEA@20100=06E326E49006A2FFFF86E36006E326E49006A2FFFF86E36060|2000FFEA@20100=06E326E49006A2FFFF86E36006E326E49006A2FFFF86E36006E326E49006A2FFFF86E36060"
  case 21
   return "1003|8003"
  case 23
   return "208B85|A900EA|209385"
 end select

 return ""

end function


function MenuCommand.CodeRegion(index as UByte, row as Integer) as UInteger

 'Where the routine of a choice lives (&h40 bytes of unused space at the end of the battle code bank, 0 if
 ' the row has none). The base damage of Kick and Dark Wave, for the multipliers that need more than the
 ' 4 bytes of the original code: the 4 bytes become a call (jsr) to a short routine that scales the damage.

 if (index = 6 and row = 3) or (index = 15 and row = 2) then return &h20100

 return 0

end function


function MenuCommand.CodeItemMatches(offset as UInteger, item as String) as Boolean

 'Whether the ROM has this choice at offset. A choice is the bytes at offset, optionally followed by @ and
 ' the offset of its routine, = and the bytes of the routine.

 dim at_sign as Integer = instr(item, "@")
 dim equals as Integer = instr(item, "=")

 if at_sign = 0 then return BytesAre(offset, item)
 if not BytesAre(offset, left(item, at_sign - 1)) then return false

 return BytesAre(val("&h" + mid(item, at_sign + 1, equals - at_sign - 1)), mid(item, equals + 1))

end function


function MenuCommand.CodeItem(s as String, n as Integer) as String

 'The n-th (from 1) part of s when it is split at |.

 dim start as Integer = 1
 dim finish as Integer

 for i as Integer = 2 to n
  start = instr(start, s, "|")
  if start = 0 then return ""
  start += 1
 next
 finish = instr(start, s, "|")
 if finish = 0 then return mid(s, start)

 return mid(s, start, finish - start)

end function


sub MenuCommand.ReadCode(index as UByte)

 dim names as String
 dim wanted as String
 dim n as Integer
 dim bytes_text as String

 for row as Integer = 1 to CodeRows(index)
  code_choice(row) = 0
  bytes_text = CodeBytes(index, row)
  n = 1
  do
   wanted = CodeItem(bytes_text, n)
   if wanted = "" then exit do
   if CodeItemMatches(CodeOffset(index, row), wanted) then
    code_choice(row) = n
    exit do
   end if
   n += 1
  loop
 next

end sub


sub MenuCommand.WriteCode(index as UByte)

 dim wanted as String

 for row as Integer = 1 to CodeRows(index)
  if code_choice(row) > 0 then
   wanted = CodeItem(CodeBytes(index, row), code_choice(row))
   if CodeRegion(index, row) > 0 then
    for i as Integer = 0 to &h3F
     WriteByte(CodeRegion(index, row) + i, &hFF)
    next
   end if
   if instr(wanted, "@") > 0 then
    for i as Integer = 0 to (len(wanted) - instr(wanted, "=")) \ 2 - 1
     WriteByte(val("&h" + mid(wanted, instr(wanted, "@") + 1, instr(wanted, "=") - instr(wanted, "@") - 1)) + i, val("&h" + mid(wanted, instr(wanted, "=") + 1 + i * 2, 2)))
    next
    wanted = left(wanted, instr(wanted, "@") - 1)
   end if
   for i as Integer = 0 to len(wanted) \ 2 - 1
    WriteByte(CodeOffset(index, row) + i, val("&h" + mid(wanted, i * 2 + 1, 2)))
   next
  end if
 next

end sub


sub MenuCommand.ReadFromROM(index as UByte)

 dim start as UInteger
 dim total as UInteger
 
 start = &h7A9C6 + (index - 1) * 5
 for i as Integer = 0 to 4
  name += chr(ByteAt(start + i))
 next
 
 target_byte = ByteAt(&h9FFC3 + index - 1)
 target = (target_byte \ &h10) mod 8
 
 delay = ByteAt(&hA0089 + index - 1)
 
 disabling_persistent = ByteAt(&h9FF19 + (index - 1) * 2)
 disabling_temporary = ByteAt(&h9FF19 + (index - 1) * 2  + 1)
 
 charging_stance = ByteAt(&hB7E60 + (index - 1))
 ReadCode(index)
 if index = 8 then ReadRecall()
 if index = 1 then ReadHalfSteps()
 action_stance = &hFF
 action_stance2 = &hFF
 action_stance3 = &hFF
 
 select case index
 
  case 1 'Fight
   misc_bytes(1) = ByteAt(&h1C864) 'Elemental multiplier - extra weak
   misc_bytes(2) = ByteAt(&h1C873) 'Elemental multiplier - weak
   misc_bytes(3) = ByteAt(&h1C882) 'Elemental multiplier - immune
   misc_bytes(4) = ByteAt(&h1C891) 'Elemental multiplier - resist
   misc_bytes(5) = ByteAt(&h1C8A6) 'Racial multiplier - weak
   misc_bytes(6) = ByteAt(&h1C8B9) 'Racial multiplier - resist
   misc_bytes(7) = ByteAt(&h1CA43) 'Caster bonus stat for determining status infliction chance
   misc_bytes(8) = ByteAt(&h1CA46) 'Target penalty stat for determining status infliction chance
   
  case 2 'Item
   action_stance = ByteAt(&h149B3)
   
  case 3 'White
   action_stance = ByteAt(&h148D4)
   
  case 4 'Black
   action_stance = ByteAt(&h148E1)
   
  case 5 'Call
   action_stance = ByteAt(&h1491A)
   
  case 6 'Dark Wave
   action_stance = ByteAt(&h14A5F)
   
  case 7 'Jump
   action_stance = ByteAt(&h14828)
   action_stance2 = ByteAt(&h14833)
   action_stance3 = ByteAt(&h146CD)
   jump_wait = ByteAt(&h1A19D)
   jump_air = ByteAt(&h1EB6D)
   message(1) = ByteAt(&h1EB62) 'Failure message
   
  case 8 'Recall
   action_stance = ByteAt(&h148E1)
   start = &h1EC22
   total = 0
   for i as Integer = 0 to 7
    success(i + 1) = ByteAt(start + i * 8) - total
    total += success(i + 1)
   next
   start = &h1EC26
   for i as Integer = 0 to 7
    spell(i + 1) = ByteAt(start + i * 8)
   next
   message(1) = ByteAt(&h1EC62)
  
  case 9 'Sing
   action_stance = ByteAt(&h148C7)
   spell(1) = ByteAt(&h1EB1D)
   spell(2) = ByteAt(&h1EB2A)
   spell(3) = ByteAt(&h1EB37)
   spell(4) = ByteAt(&h1EB40)
   spell(5) = ByteAt(&h1EB0D)
   misc_bytes(1) = ByteAt(&h1EB01)
   misc_bytes(2) = ByteAt(&h1EB04)
   message(1) = ByteAt(&h1EB18)
   message(2) = ByteAt(&h1EB25)
   message(3) = ByteAt(&h1EB32)
   message(4) = ByteAt(&h1EB3B)
   message(5) = ByteAt(&h1EB08)
  
  case 10 'Hide
   action_stance = ByteAt(&h147CB)
   misc_bytes(1) = ByteAt(&h1AD57) 'Auto-hide actor
   
  case 11 'Split
   action_stance = ByteAt(&h149B3)
   item_consumed = ByteAt(&h1E4E8)
   item_effect = ByteAt(&h1E532)
   item_visual = ByteAt(&h1E53D)
   message(1) = ByteAt(&h1E4F9)
   
  case 12 'Pray
   action_stance = ByteAt(&h149F3)
   success(1) = ByteAt(&h1EA56)
   spell(1) = ByteAt(&h1EA64)
   message(1) = ByteAt(&h1EA5D)
  
  case 13 'Aim
   action_stance = ByteAt(&h14A8A)
   ReadAim()
  
  case 14 'Charge
   message(1) = ByteAt(&h1EA1E)
   extra_delay = ByteAt(&hA0089 + &h1F)
   
  case 15 'Kick
   action_stance = ByteAt(&h1451D)
   
  case 16 'Bear
   spell(1) = ByteAt(&h1E897)
   message(1) = ByteAt(&h1E8A5)
   
  case 17 'Twin
   spell(1) = ByteAt(&h1E793) 'Normally Flare
   spell(2) = ByteAt(&h1E797) 'Normally Comet
   spell(3) = ByteAt(&h1E77C) 'Normally Double Meteor
   success(1) = ByteAt(&h1E783) 'Chance it will fail outright (x or higher)
   success(2) = ByteAt(&h1E78F) 'Chance it will be spell 2 (less than x)
   misc_bytes(1) = ByteAt(&h1E774) 'FuSoYa
   misc_bytes(2) = ByteAt(&h1E778) 'Golbez
   message(1) = ByteAt(&h1E6DC) 'Cancel message
   message(2) = ByteAt(&h1E787) 'Failure message
   extra_delay = ByteAt(&hA0089 + &h20)
   
  case 18 'Boast
   action_stance = ByteAt(&h149AB)
   misc_bytes(1) = ByteAt(&h1ECD1) 'Stat
   misc_bytes(2) = ByteAt(&h1ECD4) 'Amount
   ReadReverse(index)
   message(1) = ByteAt(&h1ECDF)
   
  case 19 'Cry
   action_stance = ByteAt(&h149AB)
   misc_bytes(1) = ByteAt(&h1ECF3) 'Read stat
   misc_bytes(2) = ByteAt(&h1ED0C) 'Write stat
   ReadReverse(index)
   message(1) = ByteAt(&h1ED22) 'Message
   
  case 20 'Cover
   action_stance = ByteAt(&h149F3)
   disable_actor = ByteAt(&h18F62)
   cover_actor = ByteAt(&h18F66)
   if ByteAt(&h38D5D) = 0 then cover_by_job = false else cover_by_job = true
   
  case 21 'Peep
   action_stance = ByteAt(&h149AB)
   
  case 22 'Unused in the original game; the editor can make it run another command's routine
   behaves_like = 0
   behaves_known = (ByteAt(&h1B57C + (index - 1) * 2) = 0 and ByteAt(&h1B57D + (index - 1) * 2) = 0)
   for i as Integer = 1 to 26
    if CanBeCopied(i) and ByteAt(&h1B57C + (index - 1) * 2) = ByteAt(&h1B57C + (i - 1) * 2) and ByteAt(&h1B57D + (index - 1) * 2) = ByteAt(&h1B57D + (i - 1) * 2) then
     behaves_like = i
     behaves_known = true
     exit for
    end if
   next

  case 23 'Throw
   action_stance = ByteAt(&h1434C)
   message(1) = ByteAt(&h1E56D) 'Failure message
   ReadThrow()

  case 24 'Steal
   action_stance = ByteAt(&h149F3)
   misc_bytes(1) = ByteAt(&h1E3F1) 'Base
   misc_bytes(2) = ByteAt(&h1E3F3) 'Bonus stat
   misc_bytes(3) = ByteAt(&h1E3F7) 'Penalty stat
   misc_bytes(4) = ByteAt(&h1E457) 'Slot
   ReadStealChance()
   message(1) = ByteAt(&h1E433) 'Damaged by enemy
   message(2) = ByteAt(&h1E43A) 'Couldn't steal
   message(3) = ByteAt(&h1E4CA) 'Stole item
   
  case 25 'Ninja
   action_stance = ByteAt(&h148E1)
   
  case 26 'Regen
   action_stance = ByteAt(&h149AB)
   regen_amount = ByteAt(&h1E5FE)
   extra_delay = ByteAt(&hA0089 + &h22)
   if ByteAt(&h1E616) = 1 and ByteAt(&h1E624) = 0 then
    regen_freeze = false
   else
    regen_freeze = true
   end if
   message(1) = ByteAt(&h1E633)
 
 end select

end sub


sub MenuCommand.WriteToROM(index as UByte)

 dim start as UInteger
 dim total as UInteger
 
 start = &h7A9C6 + (index - 1) * 5
 for i as Integer = 0 to 4
  WriteByte(start + i, asc(mid(name, i + 1, 1)))
 next
 
 target_byte = target_byte mod &h10 + target * &h10 + (target_byte \ &h80) * &h80
 WriteByte(&h9FFC3 + index - 1, target_byte)
 WriteByte(&hA0089 + index - 1, delay)
 WriteByte(&h9FF19 + (index - 1) * 2, disabling_persistent)
 WriteByte(&h9FF19 + (index - 1) * 2 + 1, disabling_temporary) 
 WriteByte(&hB7E60 + (index - 1), charging_stance)
 WriteCode(index)
 if index = 8 then WriteRecall()
 if index = 1 then WriteHalfSteps()
 
 select case index
 
  case 1 'Fight
   WriteByte(&h1C864, misc_bytes(1))
   WriteByte(&h1C873, misc_bytes(2))
   WriteByte(&h1C882, misc_bytes(3))
   WriteByte(&h1C891, misc_bytes(4))
   WriteByte(&h1C8A6, misc_bytes(5))
   WriteByte(&h1C8B9, misc_bytes(6))
   WriteByte(&h1CA43, misc_bytes(7))
   WriteByte(&h1CA46, misc_bytes(8))
   
  case 2 'Item
   WriteByte(&h149B3, action_stance)
   
  case 3 'White
   WriteByte(&h148D4, action_stance)
   
  case 4 'Black
   WriteByte(&h148E1, action_stance)
   
  case 5 'Call
   WriteByte(&h1491A, action_stance)
   
  case 6 'Dark Wave
   WriteByte(&h14A5F, action_stance)
  
  case 7 'Jump
   WriteByte(&h14828, action_stance)
   WriteByte(&h14833, action_stance2)
   WriteByte(&h146CD, action_stance3)
   WriteByte(&h1EB62, message(1))
   WriteByte(&h1A19D, jump_wait)
   WriteByte(&h1EB6D, jump_air)
 
  case 8 'Recall
   start = &h1EC22
   total = 0
   for i as Integer = 0 to 7
    WriteByte(start + i * 8, success(i + 1) + total)
    total += success(i + 1)
   next
   start = &h1EC26
   for i as Integer = 0 to 7
    WriteByte(start + i * 8, spell(i + 1))
   next
   WriteByte(&h1EC62, message(1))
   if message(1) = &hFF then
    WriteByte(&h1EC63, &hEA)
    WriteByte(&h1EC64, &hEA)
    WriteByte(&h1EC65, &hEA)
   else
    WriteByte(&h1EC63, &h8D)
    WriteByte(&h1EC64, &hCA)
    WriteByte(&h1EC65, &h34)
   end if
   WriteByte(&h148E1, action_stance)
  
  case 9 'Sing
   WriteByte(&h1EB1D, spell(1))
   WriteByte(&h1EB2A, spell(2))
   WriteByte(&h1EB37, spell(3))
   WriteByte(&h1EB40, spell(4))
   WriteByte(&h1EB0D, spell(5))
   WriteByte(&h1EB01, misc_bytes(1))
   WriteByte(&h1EB04, misc_bytes(2))
   WriteByte(&h1EB18, message(1))
   if message(1) = &hFF then
    WriteByte(&h1EB19, &hEA)
    WriteByte(&h1EB1A, &hEA)
    WriteByte(&h1EB1B, &hEA)
   else
    WriteByte(&h1EB19, &h8D)
    WriteByte(&h1EB1A, &hCA)
    WriteByte(&h1EB1B, &h34)
   end if
   WriteByte(&h1EB25, message(2))
   if message(2) = &hFF then
    WriteByte(&h1EB26, &hEA)
    WriteByte(&h1EB27, &hEA)
    WriteByte(&h1EB28, &hEA)
   else
    WriteByte(&h1EB26, &h8D)
    WriteByte(&h1EB27, &hCA)
    WriteByte(&h1EB28, &h34)
   end if
   WriteByte(&h1EB32, message(3))
   if message(3) = &hFF then
    WriteByte(&h1EB33, &hEA)
    WriteByte(&h1EB34, &hEA)
    WriteByte(&h1EB35, &hEA)
   else
    WriteByte(&h1EB33, &h8D)
    WriteByte(&h1EB34, &hCA)
    WriteByte(&h1EB35, &h34)
   end if
   WriteByte(&h1EB3B, message(4))
   if message(4) = &hFF then
    WriteByte(&h1EB3C, &hEA)
    WriteByte(&h1EB3D, &hEA)
    WriteByte(&h1EB3E, &hEA)
   else
    WriteByte(&h1EB3C, &h8D)
    WriteByte(&h1EB3D, &hCA)
    WriteByte(&h1EB3E, &h34)
   end if
   WriteByte(&h1EB08, message(5))
   if message(5) = &hFF then
    WriteByte(&h1EB09, &hEA)
    WriteByte(&h1EB0A, &hEA)
    WriteByte(&h1EB0B, &hEA)
   else
    WriteByte(&h1EB09, &h8D)
    WriteByte(&h1EB0A, &hCA)
    WriteByte(&h1EB0B, &h34)
   end if
   WriteByte(&h148C7, action_stance)
   
  case 10 'Hide
   WriteByte(&h1AD57, misc_bytes(1))
   WriteByte(&h1A608, misc_bytes(1))
   WriteByte(&h147CB, action_stance)
   
  case 11 'Split
   WriteByte(&h1E4E8, item_consumed)
   WriteByte(&h1E532, item_effect)
   WriteByte(&h1E53D, item_visual)
   WriteByte(&h1E4F9, message(1))
   if message(1) = &hFF then
    WriteByte(&h1E4FA, &hEA)
    WriteByte(&h1E4FB, &hEA)
    WriteByte(&h1E4FC, &hEA)
   else
    WriteByte(&h1E4FA, &h8D)
    WriteByte(&h1E4FB, &hCA)
    WriteByte(&h1E4FC, &h34)
   end if
   WriteByte(&h149B3, action_stance)
   
  case 12 'Pray
   WriteByte(&h1EA56, success(1))
   WriteByte(&h1EA64, spell(1))
   WriteByte(&h1EA5D, message(1))
   if message(1) = &hFF then
    WriteByte(&h1EA5E, &hEA)
    WriteByte(&h1EA5F, &hEA)
    WriteByte(&h1EA60, &hEA)
   else
    WriteByte(&h1EA5E, &h8D)
    WriteByte(&h1EA5F, &hCA)
    WriteByte(&h1EA60, &h34)
   end if
   WriteByte(&h149F3, action_stance)
  
  case 13 'Aim
   WriteByte(&h14A8A, action_stance)
   WriteAim()
   
  case 14 'Charge
   WriteByte(&hA0089 + &h1F, extra_delay)
   WriteByte(&h1EA1E, message(1))
   if message(1) = &hFF then
    WriteByte(&h1EA1F, &hEA)
    WriteByte(&h1EA20, &hEA)
    WriteByte(&h1EA21, &hEA)
   else
    WriteByte(&h1EA1F, &h8D)
    WriteByte(&h1EA20, &hCA)
    WriteByte(&h1EA21, &h34)
   end if
   
  case 15
   WriteByte(&h1451D, action_stance)
   
  case 16 'Bear
   WriteByte(&h1E897, spell(1))
   WriteByte(&h1E8A5, message(1))
   if message(1) = &hFF then
    WriteByte(&h1E8A6, &hEA)
    WriteByte(&h1E8A7, &hEA)
    WriteByte(&h1E8A8, &hEA)
   else
    WriteByte(&h1E8A6, &h8D)
    WriteByte(&h1E8A7, &hCA)
    WriteByte(&h1E8A8, &h34)
   end if
   
  case 17 'Twin
   WriteByte(&h1E793, spell(1))
   WriteByte(&h1E797, spell(2))
   WriteByte(&h1E77C, spell(3))
   WriteByte(&h1E783, success(1))
   WriteByte(&h1E78F, success(2))
   WriteByte(&h1E774, misc_bytes(1))
   WriteByte(&h1E778, misc_bytes(2))
   WriteByte(&h1E6DC, message(1))
   if message(1) = &hFF then
    WriteByte(&h1E6DD, &hEA)
    WriteByte(&h1E6DE, &hEA)
    WriteByte(&h1E6DF, &hEA)
   else
    WriteByte(&h1E6DD, &h8D)
    WriteByte(&h1E6DE, &hCA)
    WriteByte(&h1E6DF, &h34)
   end if
   WriteByte(&h1E787, message(2))
   WriteByte(&hA0089 + &h20, extra_delay)
   if message(2) = &hFF then
    WriteByte(&h1E788, &hEA)
    WriteByte(&h1E789, &hEA)
    WriteByte(&h1E78A, &hEA)
   else
    WriteByte(&h1E788, &h8D)
    WriteByte(&h1E789, &hCA)
    WriteByte(&h1E78A, &h34)
   end if
   
  case 18 'Boast
   WriteByte(&h1ECD1, misc_bytes(1))
   WriteByte(&h1ECDC, misc_bytes(1))
   WriteByte(&h1ECD4, misc_bytes(2))
   WriteReverse(index)
   WriteByte(&h1ECDF, message(1))
   if message(1) = &hFF then
    WriteByte(&h1ECE0, &hEA)
    WriteByte(&h1ECE1, &hEA)
    WriteByte(&h1ECE2, &hEA)
   else
    WriteByte(&h1ECE0, &h8D)
    WriteByte(&h1ECE1, &hCA)
    WriteByte(&h1ECE2, &h34)
   end if
   WriteByte(&h149AB, action_stance)
   
  case 19 'Cry
   WriteByte(&h1ECF3, misc_bytes(1))
   WriteByte(&h1ED0C, misc_bytes(2))
   WriteByte(&h1ED17, misc_bytes(2))
   WriteReverse(index)
   WriteByte(&h1ED22, message(1))
   if message(1) = &hFF then
    WriteByte(&h1ED23, &hEA)
    WriteByte(&h1ED24, &hEA)
    WriteByte(&h1ED25, &hEA)
   else
    WriteByte(&h1ED23, &h8D)
    WriteByte(&h1ED24, &hCA)
    WriteByte(&h1ED25, &h34)
   end if
   WriteByte(&h149AB, action_stance)
   
  case 20 'Cover
   WriteByte(&h18F62, disable_actor)
   WriteByte(&h18F66, cover_actor)
   if cover_by_job then WriteByte(&h38D5D, 1) else WriteByte(&h38D5D, 0)
   WriteByte(&h149F3, action_stance)
   
  case 21 'Peep
   WriteByte(&h149AB, action_stance)
  
  case 22 'Runs the routine (and plays the animation) of the command it behaves like
   for i as Integer = 0 to 1
    if not behaves_known then exit for
    if behaves_like = 0 then
     WriteByte(&h1B57C + (index - 1) * 2 + i, 0)
     WriteByte(&h1424B + (index - 1) * 2 + i, ByteAt(&h1424B + &h1D * 2 + i)) 'the "no animation" routine
    else
     WriteByte(&h1B57C + (index - 1) * 2 + i, ByteAt(&h1B57C + (behaves_like - 1) * 2 + i))
     WriteByte(&h1424B + (index - 1) * 2 + i, ByteAt(&h1424B + (behaves_like - 1) * 2 + i))
    end if
   next

  case 23 'Throw
   WriteByte(&h1434C, action_stance)
   WriteByte(&h1E56D, message(1))
   WriteThrow()
   
  case 24 'Steal
   WriteByte(&h1E3F1, misc_bytes(1)) 'Base
   WriteByte(&h1E3F3, misc_bytes(2)) 'Bonus stat
   WriteByte(&h1E3F7, misc_bytes(3)) 'Penalty stat
   WriteByte(&h1E457, misc_bytes(4)) 'Slot
   WriteStealChance()
   WriteByte(&h1E433, message(1)) 'Damaged by enemy
   if message(1) = &hFF then
    WriteByte(&h1E434, &hEA)
    WriteByte(&h1E435, &hEA)
    WriteByte(&h1E436, &hEA)
   else
    WriteByte(&h1E434, &h8D)
    WriteByte(&h1E435, &hCA)
    WriteByte(&h1E436, &h34)
   end if
   WriteByte(&h1E43A, message(2)) 'Couldn't steal
   if message(2) = &hFF then
    WriteByte(&h1E43B, &hEA)
    WriteByte(&h1E43C, &hEA)
    WriteByte(&h1E43D, &hEA)
   else
    WriteByte(&h1E43B, &h8D)
    WriteByte(&h1E43C, &hCA)
    WriteByte(&h1E43D, &h34)
   end if
   WriteByte(&h1E4CA, message(3)) 'Stole item
   if message(3) = &hFF then
    WriteByte(&h1E4CB, &hEA)
    WriteByte(&h1E4CC, &hEA)
    WriteByte(&h1E4CD, &hEA)
   else
    WriteByte(&h1E4CB, &h8D)
    WriteByte(&h1E4CC, &hCA)
    WriteByte(&h1E4CD, &h34)
   end if
   WriteByte(&h149F3, action_stance)
   
  case 25
   WriteByte(&h148E1, action_stance)
   
  case 26 'Regen
   WriteByte(&h1E5FE, regen_amount)
   WriteByte(&hA0089 + &h22, extra_delay)
   if regen_freeze then
    WriteByte(&h1E616, &h0C)
    WriteByte(&h1E624, &h08)
   else
    WriteByte(&h1E616, 1)
    WriteByte(&h1E624, 0)
   end if
   WriteByte(&h1E633, message(1))
   if message(1) = &hFF then
    WriteByte(&h1E634, &hEA)
    WriteByte(&h1E635, &hEA)
    WriteByte(&h1E636, &hEA)
   else
    WriteByte(&h1E634, &h8D)
    WriteByte(&h1E635, &hCA)
    WriteByte(&h1E636, &h34)
   end if
   WriteByte(&h149AB, action_stance)
 
 end select

end sub
