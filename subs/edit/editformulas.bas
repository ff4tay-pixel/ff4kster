'The Battle Formulas editor: the damage formulas of the commands (Fight, Kick, Dark Wave, Throw), the spell
' damage formula, the Summon Book. The settings of the
' commands live in menucommands and are shown by CommandParametersMenu (ids 1, 15, 6 and 123), the spell
' settings are in the formulas object.

dim shared fml_hub as BlueMenu
dim shared fml_params as CommandParametersMenu
dim shared fml_spells as BlueMenu 'spell damage, 5 rows
dim shared fml_book as BlueMenu 'the Summon Book, 2 columns
dim shared fml_number as BlueNumberInput
dim shared fml_x as Integer 'left edge of the window on the right of the list


function FmlChoiceText(names as String, choice as Integer) as String

 if choice = 0 then return FF4Text("Custom code, not changed")

 return FF4Text(MenuCommand.CodeItem(names, choice))

end function


function FmlPick(px as Integer, py as Integer, names as String, current as Integer) as Integer

 'A pop-up list of the choices in names (separated by |). Returns the number chosen, 0 if cancelled.

 dim pick as BlueMenu
 dim item as String
 dim n as Integer = 1

 pick = BlueMenu(px, py)
 pick.max_rows = 8
 pick.type_ahead = true
 do
  item = MenuCommand.CodeItem(names, n)
  if item = "" then exit do
  pick.AddOption(FF4Text(item))
  n += 1
 loop
 pick.ChangeSelected(Max(1, current))
 pick.UserSelect()
 if pick.cancelled then return 0

 return pick.selected

end function


sub FmlSpellRows()

 'The five rows of the spell damage window.

 dim hits_text as String

 fml_spells.ChangeOption(1, FF4Text("Spell power scale:     ") + FmlChoiceText(BattleFormulas.PowerNames(), formulas.power_choice), 15)
 fml_spells.ChangeOption(2, FF4Text("Summon power scale:    ") + FmlChoiceText(BattleFormulas.SummonNames(), formulas.summon_choice), 15)
 fml_spells.ChangeOption(3, FF4Text("Hits tried per cast:   ") + FmlChoiceText(BattleFormulas.DivisorNames(), formulas.divisor_choice), 15)
 fml_spells.ChangeOption(4, FF4Text("Stat used:             ") + FmlChoiceText(BattleFormulas.StatsNames(), formulas.stats_choice), 15)
 if formulas.hits_known then
  hits_text = FF4Text(str(formulas.fixed_hits))
  if formulas.fixed_hits = 8 then hits_text += FF4Text(", original")
 else
  hits_text = FF4Text("Custom code, not changed")
 end if
 fml_spells.ChangeOption(5, FF4Text("Summon and item hits:  ") + hits_text, 15)

end sub


sub FmlBookRows()

 'The Summon Book window: the summon and how it is aimed, ten times.

 dim id as Integer
 dim aim_text as String

 for i as Integer = 0 to 9
  id = formulas.summon_book(i) and &h7F
  if formulas.summon_book(i) and &h80 then aim_text = "one random target" else aim_text = "all targets"
  fml_book.ChangeOption(i * 2 + 1, FF4Text(Pad(str(i + 1), 2, true) + " ") + Pad(spells(id).name, 8,, FF4Text(" ")), 15)
  fml_book.ChangeOption(i * 2 + 2, FF4Text(Pad(aim_text, 17)), 15)
 next

end sub


sub FmlNote(first_row as Integer, notes as String)

 'Help in a blue window with a title: lines separated by |, first_row is where the top border goes.

 dim shown(1 to 12) as String
 dim rest as String = notes
 dim p as Integer
 dim n as Integer
 dim w as Integer = 7

 do
  p = instr(rest, "|")
  n += 1
  if p = 0 then
   shown(n) = rest
  else
   shown(n) = left(rest, p - 1)
   rest = mid(rest, p + 1)
  end if
  if len(shown(n)) > w then w = len(shown(n))
 loop until p = 0 or n = 12

 BlueBox(fml_x, first_row, w, n)
 WriteText(FF4Text(" Notes "), fml_x + 1, first_row, 14)
 for i as Integer = 1 to n
  WriteText(FF4Text(shown(i)), fml_x + 1, first_row + i, 15)
 next

end sub


dim shared fml_removal as BlueMenu 'what Dispel and Black hole remove, 3 columns
dim shared fs_page as Integer '1 the stat formulas, 2 the statuses of Frog and Mini and the like, 3 the other status modifiers
dim shared fs_x0 as Integer 'where the formula starts on a line
dim shared fs_text(1 to 28, 1 to 14) as String 'the pieces of the formula lines: text, or @ and the field
dim shared fs_pieces(1 to 28) as Integer
dim shared fs_labels(1 to 28) as String
dim shared fs_lines as Integer
dim shared fs_line as Integer 'the line of the cursor
dim shared fs_field as Integer 'the field of the cursor, counted in the fields of the line
dim shared fs_hit_x(1 to 28, 1 to 14) as Integer 'where each piece was drawn, for the mouse
dim shared fs_hit_w(1 to 28, 1 to 14) as Integer


sub FsFill(lines_text() as String, count as Integer)

 'Splits the lines of a page into the label and the pieces.

 dim rest as String
 dim p as Integer

 fs_lines = count
 for i as Integer = 1 to fs_lines
  rest = lines_text(i)
  p = instr(rest, "|")
  fs_labels(i) = left(rest, p - 1)
  rest = mid(rest, p + 1)
  fs_pieces(i) = 0
  do
   p = instr(rest, "|")
   fs_pieces(i) += 1
   if p = 0 then
    fs_text(i, fs_pieces(i)) = rest
   else
    fs_text(i, fs_pieces(i)) = left(rest, p - 1)
    rest = mid(rest, p + 1)
   end if
  loop until p = 0
 next

end sub


sub FsLayout()

 'The lines of a page. A piece is plain text, or @ and a field: S1 to S11 the stat of a term, D1 to D12 its
 ' divisor, PL the plus 1 of the attack multiplier, YS YM YP Yang's attack, AN NU MU AD the turn wait, CT CS
 ' Count, PA SA PZ SZ Armor and Shell. On page 2 T1 to T6 are the statuses of a rule, V1 the attack power of a
 ' weak attacker, M2 what the attack power of a hurt target is multiplied by and XD its defense.
 ' The terms are numbered as in BattleFormulas.TermStatOffset.

 dim page1(1 to 16) as String = { _
  "Attack multiplier|@S1| / |@D1| plus |@S2| / |@D2| plus |@PL", _
  "Attack power|@S3| / |@D3| plus |@S4| / |@D4| plus weapon attack", _
  "Attack hit rate|@S4| / |@D4| plus weapon hit rate", _
  "Yang's attack power|@YS| x |@YM| plus |@S3| / |@D3| plus |@YP", _
  "Defense multiplier|@S5| / |@D5| x shield multiplier plus |@S6| / |@D6", _
  "Defense|@S7| / |@D7| plus armor plus shield defense", _
  "Magic def multiplier|sum of |@S8| and |@S9| / |@D10| plus |@S11| / |@D11", _
  "Magic defense rate|sum of |@S8| and |@S9| / |@D12| plus armor and shield", _
  "Turn wait, top|@AN|@NU", _
  "divided by|My AGI x |@MU| plus |@AD", _
  "Count, doom|counts down once every |@CT| ticks of the timer loop", _
  "when it ends|the unit gets |@CS", _
  "Protect, Armor|adds |@PA| to the defense of the target", _
  "Shell|adds |@SA| to the magic defense of the target", _
  "Armor, Zeromus|in the Zeromus battle Armor |@PZ", _
  "Shell, Zeromus|in the Zeromus battle Shell |@SZ"}
 dim page2(1 to 9) as String = { _
  "Weak attacker|when the attacker has |@T1", _
  "|its attack power becomes |@V1| and it cannot crit", _
  "Hurt target|when the target has |@T2", _
  "|its attack power is multiplied by |@M2", _
  "|and its defense becomes |@XD", _
  "Defense multiplier is 0|when the target has |@T3", _
  "Magic def multiplier is 0|when the target has |@T4", _
  "Inflicts no status|when the attacker has |@T5", _
  "Uses up no arrows|when the attacker has |@T6"}

 dim page3(1 to 26) as String = { _
  "Attacker hit rate|when the attacker has |@U1", _
  "|its hit rate is |@E1", _
  "Target evasion|when the target has |@U2", _
  "|its evasion is |@E2", _
  "Berserk bonus|when the attacker has |@U3| it adds 50% attack power", _
  "Jump bonus|when the attacker has |@U4", _
  "|its attack power is multiplied by |@E4", _
  "Curse penalty|when the attacker has |@U5", _
  "|its attack power is multiplied by |@E5", _
  "Defense, curse|when the target has |@U6", _
  "|its defense is multiplied by |@E6", _
  "Defense, defend|when the target has |@U7", _
  "|its defense is multiplied by |@E7", _
  "Defense, focus|when the target has |@U8", _
  "|its defense is multiplied by |@E8", _
  "Spell hit rate|when the attacker has |@U9", _
  "|its spell hit rate is |@E9", _
  "Magic defense rate|when the target has |@U10", _
  "|its magic defense rate is |@E10", _
  "Magic def mult is 0|when the target has |@U11", _
  "Poison|loses max HP / |@PD| every tick, at least 1", _
  "|and waits |@IS| plus |@IC| ticks between its ticks", _
  "Sap, HP leak|loses |@SD| HP every |@SE| ticks", _
  "|and lasts WIS plus WIL x |@SL| plus |@SK| ticks", _
  "Regen|heals every |@RG| ticks", _
  "Sleep, paralyze|last |@LB| minus |@LM| x spirit, divided by |@LV| ticks"}

 if fs_page = 3 then
  fs_x0 = 22
  FsFill(page3(), 26)
 elseif fs_page = 2 then
  fs_x0 = 30
  FsFill(page2(), 9)
 else
  fs_x0 = 24
  FsFill(page1(), 16)
 end if

end sub


function FsRow(l as Integer) as Integer

 'The screen row of a formula line. On page 1 the line under "Turn wait, top" is the next row, like a fraction.
 ' On page 2 a line without a label goes on with the rule above it.

 dim y as Integer = 6

 if fs_page >= 2 then
  for i as Integer = 2 to l
   if fs_labels(i) <> "" then y += 2 else y += 1
  next
  return y
 end if

 if l = 10 then return 6 + (l - 1) * 2 - 1
 if l = 11 then return 6 + 9 * 2 + 1
 if l = 12 then return 6 + 9 * 2 + 2
 if l = 13 then return 6 + 9 * 2 + 4
 if l = 14 then return 6 + 9 * 2 + 5
 if l = 15 then return 6 + 9 * 2 + 7
 if l = 16 then return 6 + 9 * 2 + 8

 return 6 + (l - 1) * 2

end function


function FsSetText(mask as Integer) as String

 'The statuses of a mask as a short text.

 dim s as String = FF4Name(StatusList(mask, "persistent"))

 if len(s) > 22 then s = left(s, 19) + "..."

 return s

end function


function FsListSetText(mask as Integer, which_list as Integer) as String

 'The statuses of a mask of one of the four status lists as a short text.

 dim list_names(1 to 4) as String = {"persistent", "temporary", "system", "hidden"}
 dim s as String = FF4Name(StatusList(mask, list_names(which_list)))

 if len(s) > 24 then s = left(s, 21) + "..."

 return s

end function


function FsFieldText(code as String) as String

 'The text of a field. A field that holds custom code says ?.

 dim kind as String = left(code, 1)
 dim n as Integer = val(mid(code, 2))
 dim names as String

 if kind = "T" then
  if not formulas.st_known(n) then return "?"
  return FsSetText(formulas.st_mask(n))
 end if
 if kind = "U" then
  if not formulas.um_known(n) then return "?"
  return FsListSetText(formulas.um_mask(n), formulas.um_list(n))
 end if
 if kind = "E" then
  if not formulas.um_known(n) then return "?"
  return MenuCommand.CodeItem(BattleFormulas.UmEffectNames(n), formulas.um_effect(n))
 end if

 select case left(code, 2)
  case "S1", "S2", "S3", "S4", "S5", "S6", "S7", "S8", "S9"
   n = val(mid(code, 2))
   if formulas.term_stat(n) = 0 then return "?"
   return MenuCommand.CodeItem(BattleFormulas.TermStatNames(), formulas.term_stat(n))
  case "D1", "D2", "D3", "D4", "D5", "D6", "D7", "D8", "D9"
   n = val(mid(code, 2))
   if formulas.term_div(n) = 0 then return "?"
   return MenuCommand.CodeItem("1|2|4|8|16|32|64", formulas.term_div(n))
 end select

 select case code
  case "S10", "S11": if formulas.term_stat(val(mid(code, 2))) = 0 then return "?" else return MenuCommand.CodeItem(BattleFormulas.TermStatNames(), formulas.term_stat(val(mid(code, 2))))
  case "D10", "D11", "D12": if formulas.term_div(val(mid(code, 2))) = 0 then return "?" else return MenuCommand.CodeItem("1|2|4|8|16|32|64", formulas.term_div(val(mid(code, 2))))
  case "PL": if not formulas.plus_known then return "?" else return iif(formulas.plus_on, "1", "0")
  case "YS": if not formulas.yang_known then return "?" else return MenuCommand.CodeItem(BattleFormulas.TermStatNames(), formulas.yang_stat)
  case "YM": if not formulas.yang_known then return "?" else return str(3 - formulas.yang_mult)
  case "YP": if not formulas.yang_known then return "?" else return str(formulas.yang_plus)
  case "AN": if not formulas.speed_known then return "?" else if formulas.speed_anchor then return "Anchor's AGI x " else return "no anchor "
  case "NU": if not formulas.speed_known then return "?" else return str(formulas.speed_num)
  case "MU": if not formulas.speed_known then return "?" else return str(formulas.speed_mul)
  case "AD": if not formulas.speed_known then return "?" else return str(formulas.speed_add)
  case "PA": if not formulas.buff_known then return "?" else return str(formulas.protect_add)
  case "SA": if not formulas.buff_known then return "?" else return str(formulas.shell_add)
  case "PZ": if not formulas.zeromus_known then return "?" else return iif(formulas.protect_zeromus, "works", "does nothing")
  case "SZ": if not formulas.zeromus_known then return "?" else return iif(formulas.shell_zeromus, "works", "does nothing")
  case "V1": if not formulas.st_known(1) then return "?" else return str(formulas.st_power)
  case "PD": if not formulas.poison_known then return "?" else return MenuCommand.CodeItem("2|4|8|16|32|64", formulas.poison_div)
  case "SD": if not formulas.sap_known then return "?" else return str(formulas.sap_damage)
  case "IS": if not formulas.wait_known then return "?" else return MenuCommand.CodeItem(BattleFormulas.TermStatNames(), formulas.wait_stat)
  case "IC": if not formulas.wait_known then return "?" else return str(formulas.wait_const)
  case "SE": if not formulas.sap_every_known then return "?" else return str(formulas.sap_every)
  case "SL": if not formulas.sap_len_known then return "?" else return str(formulas.sap_len_mult)
  case "SK": if not formulas.sap_len_known then return "?" else return str(formulas.sap_len_const)
  case "RG": if not formulas.regen_known then return "?" else return str(formulas.regen_every)
  case "LB": if not formulas.sleep_known then return "?" else return str(formulas.sleep_base)
  case "LM": if not formulas.sleep_known then return "?" else return MenuCommand.CodeItem("1|2|4", formulas.sleep_mult)
  case "LV": if not formulas.sleep_known then return "?" else return str(formulas.sleep_div)
  case "M2": if not formulas.st_known(2) then return "?" else return MenuCommand.CodeItem("x0.5|x1|x2", formulas.st_mult)
  case "XD": if not formulas.st_known(2) then return "?" else return iif(formulas.st_defense_zero, "0", "unchanged")
  case "CT": if not formulas.doom_known then return "?" else return str(formulas.doom_ticks)
  case "CS": if not formulas.doom_known then return "?" else return MenuCommand.CodeItem("Dead|Stone|Toad|Mini|Pig|Mute|Blind|Poison", formulas.doom_status)
 end select

 return "?"

end function


function FsIsTerm(code as String, kind as String) as Boolean

 'Whether a field code is a stat (S) or a divisor (D) of a term, like S1 or D12, and not one like SD or SA.

 return left(code, 1) = kind and mid(code, 2, 1) >= "0" and mid(code, 2, 1) <= "9"

end function


function FsIsField(piece as String) as Boolean

 return left(piece, 1) = "@"

end function


function FsFieldCount(l as Integer) as Integer

 dim n as Integer

 for i as Integer = 1 to fs_pieces(l)
  if FsIsField(fs_text(l, i)) then n += 1
 next

 return n

end function


function FsPieceOfField(l as Integer, f as Integer) as Integer

 'The number of the piece that is the f-th field of line l.

 dim n as Integer

 for i as Integer = 1 to fs_pieces(l)
  if FsIsField(fs_text(l, i)) then
   n += 1
   if n = f then return i
  end if
 next

 return 0

end function


sub FsDraw()

 'Draws all the lines. The fields are yellow, the one under the cursor has a frame.

 dim x as Integer
 dim y as Integer
 dim piece as String
 dim shown as String
 dim field_number as Integer

 if fs_page = 3 then
  BlueBox(1, 3, 76, 43)
  WriteText(FF4Text(" Status modifiers of the damage and the timers "), 2, 3, 14)
  WriteText(FF4Text("Each rule is for a set of statuses of the unit: none switches the rule off."), 2, 4, 15)
 elseif fs_page = 2 then
  BlueBox(1, 3, 76, 22)
  WriteText(FF4Text(" Statuses that change the damage of attacks and spells "), 2, 3, 14)
  WriteText(FF4Text("Each rule is for a set of statuses of the unit: none switches the rule off."), 2, 4, 15)
 else
  BlueBox(1, 3, 76, 29)
  WriteText(FF4Text(" Formulas of the stats of the party in battle "), 2, 3, 14)
  WriteText(FF4Text("Monsters have stats of their own that are not changed here."), 2, 4, 15)
 end if
 for l as Integer = 1 to fs_lines
  y = FsRow(l)
  WriteText(FF4Text(fs_labels(l)), 2, y, 15)
  x = fs_x0
  field_number = 0
  for i as Integer = 1 to fs_pieces(l)
   piece = fs_text(l, i)
   if FsIsField(piece) then
    field_number += 1
    shown = FsFieldText(mid(piece, 2))
    WriteText(FF4Text(shown), x, y, 14)
    fs_hit_x(l, i) = x
    fs_hit_w(l, i) = len(shown)
    if l = fs_line and field_number = fs_field then
     line (x * 8 - 2, y * 8 - 2)-((x + len(shown)) * 8 + 1, y * 8 + 9), RGB(255, 255, 255), b
    end if
    x += len(shown)
   else
    WriteText(FF4Text(piece), x, y, 15)
    fs_hit_x(l, i) = -1
    x += len(piece)
   end if
  next
 next

end sub


sub FsEditField(code as String)

 'Enter on a field: a pop-up list of the choices or a number box.

 dim pick as Integer
 dim n as Integer
 dim px as Integer = 30
 dim py as Integer = FsRow(fs_line) + 1
 dim div_names as String = "1|2|4|8|16|32|64"
 dim status_menu as FlagMenu

 if left(code, 1) = "U" then
  n = val(mid(code, 2))
  if formulas.um_known(n) then
   pick = FmlPick(px, py, "Persistent|Temporary|System|Hidden", formulas.um_list(n))
   if pick > 0 then
    select case pick
     case 1: status_menu = FlagMenu(px, py, "persistent status")
     case 2: status_menu = FlagMenu(px, py, "temporary status")
     case 3: status_menu = FlagMenu(px, py, "system status")
     case else: status_menu = FlagMenu(px, py, "hidden status")
    end select
    if pick = formulas.um_list(n) then
     for i as Integer = 0 to 7
      if formulas.um_mask(n) and 2^i then status_menu.SetFlag(i + 1)
     next
    end if
    status_menu.UserSelect()
    formulas.um_list(n) = pick
    formulas.um_mask(n) = 0
    for i as Integer = 0 to 7
     if status_menu.flags(i + 1) then formulas.um_mask(n) += 2^i
    next
   end if
  end if
  exit sub
 end if
 if left(code, 1) = "E" then
  n = val(mid(code, 2))
  if formulas.um_known(n) then
   pick = FmlPick(px, py, BattleFormulas.UmEffectNames(n), formulas.um_effect(n))
   if pick > 0 then formulas.um_effect(n) = pick
  end if
  exit sub
 end if
 if left(code, 1) = "T" then
  n = val(mid(code, 2))
  if formulas.st_known(n) then
   status_menu = FlagMenu(px, py, "persistent status")
   for i as Integer = 0 to 7
    if formulas.st_mask(n) and 2^i then status_menu.SetFlag(i + 1)
   next
   status_menu.UserSelect()
   formulas.st_mask(n) = 0
   for i as Integer = 0 to 7
    if status_menu.flags(i + 1) then formulas.st_mask(n) += 2^i
   next
  end if
  exit sub
 end if
 if FsIsTerm(code, "S") then
  n = val(mid(code, 2))
  pick = FmlPick(px, py, BattleFormulas.TermStatNames(), formulas.term_stat(n))
  if pick > 0 then formulas.term_stat(n) = pick
  exit sub
 end if
 if FsIsTerm(code, "D") then
  n = val(mid(code, 2))
  if n = 7 then div_names = "1|2"
  pick = FmlPick(px, py, div_names, formulas.term_div(n))
  if pick > 0 then formulas.term_div(n) = pick
  exit sub
 end if

 select case code
  case "PL"
   if formulas.plus_known then
    pick = FmlPick(px, py, "0|1", iif(formulas.plus_on, 2, 1))
    if pick > 0 then formulas.plus_on = (pick = 2)
   end if
  case "YS"
   if formulas.yang_known then
    pick = FmlPick(px, py, BattleFormulas.TermStatNames(), formulas.yang_stat)
    if pick > 0 then formulas.yang_stat = pick
   end if
  case "YM"
   if formulas.yang_known then
    pick = FmlPick(px, py, "2, original|1", formulas.yang_mult)
    if pick > 0 then formulas.yang_mult = pick
   end if
  case "YP"
   if formulas.yang_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 0: fml_number.max_value = 255
    fml_number.starting_number = formulas.yang_plus
    fml_number.UserSelect()
    formulas.yang_plus = fml_number.number
   end if
  case "AN"
   if formulas.speed_known then
    pick = FmlPick(px, py, "Anchor's AGI x|no anchor", iif(formulas.speed_anchor, 1, 2))
    if pick > 0 then formulas.speed_anchor = (pick = 1)
    if formulas.speed_anchor and formulas.speed_num > 255 then formulas.speed_num = 255
   end if
  case "NU"
   if formulas.speed_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 1
    if formulas.speed_anchor then fml_number.max_value = 255 else fml_number.max_value = 65535
    fml_number.starting_number = formulas.speed_num
    fml_number.UserSelect()
    formulas.speed_num = fml_number.number
   end if
  case "MU"
   if formulas.speed_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 1: fml_number.max_value = 255
    fml_number.starting_number = formulas.speed_mul
    fml_number.UserSelect()
    formulas.speed_mul = fml_number.number
   end if
  case "AD"
   if formulas.speed_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 0: fml_number.max_value = 500
    fml_number.starting_number = formulas.speed_add
    fml_number.UserSelect()
    formulas.speed_add = fml_number.number
   end if
  case "PD"
   if formulas.poison_known then
    pick = FmlPick(px, py, "2|4|8, original|16|32|64", formulas.poison_div)
    if pick > 0 then formulas.poison_div = pick
   end if
  case "SD"
   if formulas.sap_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 0: fml_number.max_value = 255
    fml_number.starting_number = formulas.sap_damage
    fml_number.UserSelect()
    formulas.sap_damage = fml_number.number
   end if
  case "IS"
   if formulas.wait_known then
    pick = FmlPick(px, py, BattleFormulas.TermStatNames(), formulas.wait_stat)
    if pick > 0 then formulas.wait_stat = pick
   end if
  case "IC"
   if formulas.wait_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 0: fml_number.max_value = 255
    fml_number.starting_number = formulas.wait_const
    fml_number.UserSelect()
    formulas.wait_const = fml_number.number
   end if
  case "SE"
   if formulas.sap_every_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 1: fml_number.max_value = 255
    fml_number.starting_number = formulas.sap_every
    fml_number.UserSelect()
    formulas.sap_every = fml_number.number
   end if
  case "SL"
   if formulas.sap_len_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 0: fml_number.max_value = 20
    fml_number.starting_number = formulas.sap_len_mult
    fml_number.UserSelect()
    formulas.sap_len_mult = fml_number.number
   end if
  case "SK"
   if formulas.sap_len_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 0: fml_number.max_value = 255
    fml_number.starting_number = formulas.sap_len_const
    fml_number.UserSelect()
    formulas.sap_len_const = fml_number.number
   end if
  case "RG"
   if formulas.regen_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 1: fml_number.max_value = 255
    fml_number.starting_number = formulas.regen_every
    fml_number.UserSelect()
    formulas.regen_every = fml_number.number
   end if
  case "LB"
   if formulas.sleep_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 1: fml_number.max_value = 999
    fml_number.starting_number = formulas.sleep_base
    fml_number.UserSelect()
    formulas.sleep_base = fml_number.number
   end if
  case "LM"
   if formulas.sleep_known then
    pick = FmlPick(px, py, "1|2|4, original", formulas.sleep_mult)
    if pick > 0 then formulas.sleep_mult = pick
   end if
  case "LV"
   if formulas.sleep_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 1: fml_number.max_value = 99
    fml_number.starting_number = formulas.sleep_div
    fml_number.UserSelect()
    formulas.sleep_div = fml_number.number
   end if
  case "V1"
   if formulas.st_known(1) then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 0: fml_number.max_value = 999
    fml_number.starting_number = formulas.st_power
    fml_number.UserSelect()
    formulas.st_power = fml_number.number
   end if
  case "M2"
   if formulas.st_known(2) then
    pick = FmlPick(px, py, "x0.5|x1|x2, original", formulas.st_mult)
    if pick > 0 then formulas.st_mult = pick
   end if
  case "XD"
   if formulas.st_known(2) then
    pick = FmlPick(px, py, "0, original|unchanged", iif(formulas.st_defense_zero, 1, 2))
    if pick > 0 then formulas.st_defense_zero = (pick = 1)
   end if
  case "PA"
   if formulas.buff_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 0: fml_number.max_value = 255
    fml_number.starting_number = formulas.protect_add
    fml_number.UserSelect()
    formulas.protect_add = fml_number.number
   end if
  case "SA"
   if formulas.buff_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 0: fml_number.max_value = 255
    fml_number.starting_number = formulas.shell_add
    fml_number.UserSelect()
    formulas.shell_add = fml_number.number
   end if
  case "PZ"
   if formulas.zeromus_known then
    pick = FmlPick(px, py, "does nothing, original|works", iif(formulas.protect_zeromus, 2, 1))
    if pick > 0 then formulas.protect_zeromus = (pick = 2)
   end if
  case "SZ"
   if formulas.zeromus_known then
    pick = FmlPick(px, py, "does nothing, original|works", iif(formulas.shell_zeromus, 2, 1))
    if pick > 0 then formulas.shell_zeromus = (pick = 2)
   end if
  case "CT"
   if formulas.doom_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 1: fml_number.max_value = 99
    fml_number.starting_number = formulas.doom_ticks
    fml_number.UserSelect()
    formulas.doom_ticks = fml_number.number
   end if
  case "CS"
   if formulas.doom_known then
    pick = FmlPick(px, py, "Dead, original|Stone|Toad|Mini|Pig|Mute|Blind|Poison", formulas.doom_status)
    if pick > 0 then formulas.doom_status = pick
   end if
 end select

end sub


sub FsHint()

 dim p as Integer = FsPieceOfField(fs_line, fs_field)
 dim code as String = mid(fs_text(fs_line, p), 2)
 dim message as String

 dim kind as String = left(code, 1)

 if (kind = "S" or kind = "D") and not FsIsTerm(code, kind) then kind = ""

 select case kind
  case "S": message = "Enter picks the stat of this term."
  case "T": message = "Enter picks the statuses that switch this rule on, none switches it off."
  case "U": message = "Enter picks a status list and then the statuses that switch this rule on."
  case "E": message = "Enter picks what the rule does to the number."
  case "D": message = "Enter picks the number the stat is divided by."
  case else
   select case code
    case "PL": message = "Enter picks what the attack multiplier adds, 1 in the original."
    case "YS": message = "Enter picks the stat that Yang's attack starts from, level in the original."
    case "YM": message = "Enter picks 2 or 1, the number that Yang's first term is multiplied by."
    case "YP": message = "Enter types the number that is added to Yang's attack."
    case "AN": message = "Enter chooses to use the anchor's agility or only the number. See the notes."
    case "NU": message = "Enter types the number the wait starts from, 50 in the original."
    case "MU": message = "Enter types the number the agility is multiplied by, 10 in the original."
    case "AD": message = "Enter types the number that is added to the divisor, 0 in the original."
    case "PA": message = "Enter types the number that Armor adds to the defense, 5 in the original."
    case "SA": message = "Enter types the number Shell adds to the magic defense, 3 in the original."
    case "PZ": message = "Enter chooses if Armor works in the Zeromus battle, original: does nothing."
    case "SZ": message = "Enter chooses if Shell works in the Zeromus battle, original: does nothing."
    case "PD": message = "Enter picks the number that the max HP is divided by, 8 in the original."
    case "SD": message = "Enter types the HP that HP leak takes every tick, 2 in the original."
    case "IS": message = "Enter picks the stat of a character that the wait between ticks starts from."
    case "IC": message = "Enter types the number added to it, 20 in the original. Petrify uses it too."
    case "SE": message = "Enter types after how many ticks HP leak takes its HP, 1 in the original."
    case "SL": message = "Enter types what WIS plus WIL is multiplied by for the length, 2 in the original."
    case "SK": message = "Enter types the number added to the length of HP leak, 30 in the original."
    case "RG": message = "Enter types after how many ticks Regen heals, 6 in the original."
    case "LB": message = "Enter types the base of the length of sleep and paralyze, 300 in the original."
    case "LM": message = "Enter picks what the spirit is multiplied by, 4 in the original."
    case "LV": message = "Enter types the number the length is divided by, 6 in the original."
    case "V1": message = "Enter types the attack power of an attacker with these statuses, 1 originally."
    case "M2": message = "Enter picks what the attack power of the hurt target is multiplied by."
    case "XD": message = "Enter picks if the defense of the hurt target becomes 0 or stays as it is."
    case "CT": message = "Enter types after how many ticks Count goes down by 1, 2 in the original."
    case "CS": message = "Enter picks the status a unit gets when Count reaches 0, dead originally."
   end select
 end select

 line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf
 WriteText(FF4Text(left(message, 78)), 1, 57, 14)

end sub


sub FsNotes2()

 BlueBox(1, 27, 76, 9)
 WriteText(FF4Text(" Notes "), 2, 27, 14)
 WriteText(FF4Text("In the original game Frog and Mini do all of these, and only Frog makes a"), 2, 28, 15)
 WriteText(FF4Text("spell ignore the magic defense multiplier. Pig changes no damage in the"), 2, 29, 15)
 WriteText(FF4Text("original game, but it can be given any rule, like any other status."), 2, 30, 15)
 WriteText(FF4Text("A unit with any of the statuses you pick gets the rule, so a poisoned"), 2, 32, 15)
 WriteText(FF4Text("target can take double damage instead of a mini one."), 2, 33, 15)
 WriteText(FF4Text("Which statuses stop a unit from using commands is set in the Commands"), 2, 35, 15)
 WriteText(FF4Text("editor, under Information."), 2, 36, 15)

end sub


sub FsNotes3()

 BlueBox(1, 48, 76, 7)
 WriteText(FF4Text(" Notes "), 2, 48, 14)
 WriteText(FF4Text("Each rule tests the statuses of the attacker or of the target. Pick the"), 2, 49, 15)
 WriteText(FF4Text("list first, persistent, temporary, system or hidden, then its statuses, so"), 2, 50, 15)
 WriteText(FF4Text("that Sleep can halve the attack power. None switches a rule off."), 2, 51, 15)
 WriteText(FF4Text("Berserk adds 50% to the attack power, which cannot change, but its"), 2, 52, 15)
 WriteText(FF4Text("statuses can. Barrier, Image and the back row are not here."), 2, 53, 15)
 WriteText(FF4Text("A tick is a pass of the battle loop, its length depends on the battle speed."), 2, 54, 15)
 WriteText(FF4Text("Petrify uses the wait of poison. Monsters use their level plus 10."), 2, 55, 15)

end sub


sub FsNotes()

 if fs_page = 3 then
  FsNotes3()
  exit sub
 end if
 if fs_page = 2 then
  FsNotes2()
  exit sub
 end if

 BlueBox(1, 34, 76, 15)
 WriteText(FF4Text(" Notes "), 2, 34, 14)
 WriteText(FF4Text("Arrows move between the yellow fields, Enter changes one, Esc goes back."), 2, 35, 15)
 WriteText(FF4Text("The level and strength terms are shared by the lines that show them."), 2, 36, 15)
 WriteText(FF4Text("The turn wait is for every unit, monsters too: a unit waits the top line"), 2, 38, 15)
 WriteText(FF4Text("divided by the line below it. The anchor is the actor that Cover disables"), 2, 39, 15)
 WriteText(FF4Text("if present, else the actor that covers, else the first party member. Both"), 2, 40, 15)
 WriteText(FF4Text("are set under Cover in the Commands editor."), 2, 41, 15)
 WriteText(FF4Text("Count starts from the Power of the spell, set in the Spells editor, and"), 2, 43, 15)
 WriteText(FF4Text("goes down by 1 each step. The other timers, such as poison, stop and sap,"), 2, 44, 15)
 WriteText(FF4Text("go down by 1 on every tick, so with 2 Count is half as fast as they are."), 2, 45, 15)
 WriteText(FF4Text("The time of a tick depends on the battle speed."), 2, 46, 15)
 WriteText(FF4Text("Armor and Shell add their number every time they are cast, up to 255. The"), 2, 47, 15)
 WriteText(FF4Text("original game makes them do nothing in the Zeromus battle."), 2, 48, 15)

end sub


sub EditStatFormulas(page as Integer = 1)

 'The formulas of the stats of the party on one screen: the fields in yellow are the ones that can be
 ' changed. Left and Right move along a line, Up and Down between lines, Enter changes the field.

 dim shot as Any ptr
 dim key as String
 dim code as UInteger
 dim done as Boolean
 dim mouse_x as Integer
 dim mouse_y as Integer
 dim left_click as Boolean
 dim right_click as Boolean
 dim wheel as Integer
 dim hit_line as Integer
 dim hit_field as Integer

 shot = ImageCreate(640, 480)
 get (0, 0)-(639, 479), shot
 cls

 fs_page = page
 FsLayout()
 fs_line = 1
 fs_field = 1

 do until done
  FsDraw()
  FsHint()
  FsNotes()
  do
   key = inkey
   if key = "" then
    PollMouse(mouse_x, mouse_y, left_click, right_click, wheel)
    if right_click then
     code = ESC_KEY
    elseif left_click then
     hit_line = 0
     for l as Integer = 1 to fs_lines
      for i as Integer = 1 to fs_pieces(l)
       if fs_hit_x(l, i) >= 0 and mouse_y = FsRow(l) then
        if mouse_x >= fs_hit_x(l, i) and mouse_x < fs_hit_x(l, i) + fs_hit_w(l, i) then
         hit_line = l
         hit_field = 0
         for j as Integer = 1 to i
          if FsIsField(fs_text(l, j)) then hit_field += 1
         next
        end if
       end if
      next
     next
     if hit_line > 0 then
      if hit_line = fs_line and hit_field = fs_field then
       code = ENTER_KEY
      else
       fs_line = hit_line
       fs_field = hit_field
       code = 1
      end if
     end if
    elseif wheel > 0 then
     code = UP_KEY
    elseif wheel < 0 then
     code = DOWN_KEY
    else
     sleep 10
    end if
   else
    code = asc(right(key, 1))
    if len(key) > 1 then code = code * &h100 + 255
   end if
  loop until key <> "" or code <> 0 and (left_click or right_click or wheel <> 0)

  select case code
   case ESC_KEY
    done = true
   case ENTER_KEY
    FsEditField(mid(fs_text(fs_line, FsPieceOfField(fs_line, fs_field)), 2))
   case UP_KEY
    if fs_line > 1 then fs_line -= 1
    if fs_field > FsFieldCount(fs_line) then fs_field = FsFieldCount(fs_line)
   case DOWN_KEY
    if fs_line < fs_lines then fs_line += 1
    if fs_field > FsFieldCount(fs_line) then fs_field = FsFieldCount(fs_line)
   case LEFT_KEY
    if fs_field > 1 then fs_field -= 1
   case RIGHT_KEY
    if fs_field < FsFieldCount(fs_line) then fs_field += 1
  end select
  code = 0
 loop

 line (0, 0)-(639, 479), RGB(0, 0, 0), bf
 put (0, 0), shot, pset
 ImageDestroy(shot)

end sub


function FmlRemovalMask(row as Integer, byref status_byte as Integer) as Integer

 'The bits of a status that a row of the Dispel and Black hole window stands for. Row 1 is the title row.
 ' status_byte is 2 or 4 for the status the bits belong to, 0 for the speed.

 select case row
  case 2: status_byte = 2: return &h80 'curse
  case 3: status_byte = 2: return &h40 'float
  case 4: status_byte = 2: return &h20 'paralyze
  case 5: status_byte = 2: return &h10 'sleep
  case 6: status_byte = 2: return &h08 'charm
  case 7: status_byte = 2: return &h04 'berserk
  case 8: status_byte = 4: return &h40 'hp leak (sap)
  case 9: status_byte = 4: return &h20 'reflect
  case 10: status_byte = 4: return &h10 'barrier
  case 11: status_byte = 4: return &h0C 'image
 end select
 status_byte = 0

 return 0

end function


function FmlRemovalCell(row as Integer, column as Integer) as String

 'The text of a cell: removes, keeps, or ? when the code is not the original or the known variants.

 dim status_byte as Integer
 dim mask as Integer = FmlRemovalMask(row, status_byte)
 dim removed as Integer

 if column = 1 then
  if status_byte = 0 and row = 12 then return "Speed"
  select case row
   case 2: return "Curse"
   case 3: return "Float"
   case 4: return "Paralyze"
   case 5: return "Sleep"
   case 6: return "Charm"
   case 7: return "Berserk"
   case 8: return "HP leak, sap"
   case 9: return "Reflect, Wall"
   case 10: return "Barrier"
   case 11: return "Image, Blink"
  end select
 end if

 if row = 12 then
  if column = 2 then return "cannot"
  if not formulas.hole_speed_known then return "?"
  if formulas.hole_speed then return "resets to normal" else return "keeps"
 end if

 if column = 2 then
  if not formulas.dispel_known then return "?"
  if status_byte = 2 then removed = formulas.dispel_s2 and mask else removed = formulas.dispel_s4 and mask
 else
  if not formulas.hole_known then return "?"
  if status_byte = 2 then removed = formulas.hole_s2 and mask else removed = formulas.hole_s4 and mask
 end if

 if removed <> 0 then return "removes"

 return "keeps"

end function


sub FmlRemovalRows()

 'The 12 rows of 3 cells: a title row, 10 statuses and the speed.

 dim text_cell as String
 dim cell_color as Integer

 fml_removal.ChangeOption(1, FF4Text("Status"), 14)
 fml_removal.ChangeOption(2, FF4Text("Dispel"), 14)
 fml_removal.ChangeOption(3, FF4Text("Black Hole"), 14)
 for r as Integer = 2 to 12
  for c as Integer = 1 to 3
   if c = 1 then
    text_cell = FmlRemovalCell(r, 1)
   else
    text_cell = FmlRemovalCell(r, c)
   end if
   cell_color = 15
   if c > 1 and (text_cell = "removes" or text_cell = "resets to normal") then cell_color = 14
   fml_removal.ChangeOption((r - 1) * 3 + c, FF4Text(text_cell), cell_color)
  next
 next

end sub


sub FmlEditRemoval()

 'Enter on a cell of the Dispel or Black hole column switches removes and keeps.

 dim row as Integer
 dim column as Integer
 dim status_byte as Integer
 dim mask as Integer

 do
  fml_removal.UserSelect()
  if fml_removal.cancelled then exit do
  row = (fml_removal.selected - 1) \ 3 + 1
  column = (fml_removal.selected - 1) mod 3 + 1
  if row >= 2 and column >= 2 then
   mask = FmlRemovalMask(row, status_byte)
   if row = 12 then
    if column = 3 and formulas.hole_speed_known then formulas.hole_speed = not formulas.hole_speed
   elseif column = 2 and formulas.dispel_known then
    if status_byte = 2 then formulas.dispel_s2 = formulas.dispel_s2 xor mask else formulas.dispel_s4 = formulas.dispel_s4 xor mask
   elseif column = 3 and formulas.hole_known then
    if status_byte = 2 then formulas.hole_s2 = formulas.hole_s2 xor mask else formulas.hole_s4 = formulas.hole_s4 xor mask
   end if
  end if
  FmlRemovalRows()
 loop

end sub


sub FmlShow(entry as Integer)

 'Draws the settings of one line of the list in the window on its right.

 line (fml_x * 8 - 8, 3 * 8)-(639, 56 * 8 - 1), RGB(0, 0, 0), bf

 select case entry
  case 1 to 4
   select case entry
    case 1: fml_params.SetTo(1)
    case 2: fml_params.SetTo(15)
    case 3: fml_params.SetTo(6)
    case 4: fml_params.SetTo(123)
   end select
   fml_params.Display()
   select case entry
    case 2
     FmlNote(8, "Kick halves the user's attack multiplier before the|damage formula. Dark Wave does not.")
    case 3
     FmlNote(9, "Dark Wave hurts the user, the HP loss is a fraction of|its max HP. The attacker's weapon gives the damage.")
    case 4
     FmlNote(9, "Throw does the item's attack power times a stat of the|user plus a random part, up to the damage cap.")
   end select

  case 5
   FmlSpellRows()
   fml_spells.Display()
   FmlNote(11, "Base damage is the spell power times the power scale|plus a random part of up to half of that. It is then|multiplied by the hits that land. Each cast tries the|number of hits shown, from the caster's stat, and a try|lands at the spell's hit rate. Summons and spells cast|from items skip the tries and always count the number|of hits set on the last line. A spell cast from a weapon|counts the weapon's Power, in the Weapons editor.")

  case 6
   FmlBookRows()
   fml_book.Display()
   FmlNote(16, "The Summon Book item calls one of these ten at random.|Enter on a name picks the summon, Enter on its right|side switches between all targets and one random target.")

  case 10
   FmlNote(3, "More statuses that change the formulas of the game:|a blind attacker or target, berserk, jump, curse, defend,|focus, for attacks and spells, and the damage of poison|and HP leak and the length of sleep and paralyze.||Enter opens them as rules with fields you can change.|Each rule can have statuses of any of the four lists.")

  case 9
   FmlNote(3, "The statuses that change the damage:|a weak attacker (Toad and Mini do 1 attack power),|a hurt target (Toad and Mini take double damage and|have no defense), no defense multiplier, spells that|ignore magic defense, attackers that inflict no status|or use no arrows.||Enter opens them as rules with fields you can change.|Each rule can have any statuses of the list.")

  case 8
   FmlRemovalRows()
   fml_removal.Display()
   FmlNote(18, "Dispel and Black Hole take statuses off their target.|Enter on removes or keeps switches it, in the column of|the effect. Black Hole also puts the speed back to|normal, which ends haste and slow. Every spell with|the Dispel effect or the Black Hole effect in the|Spells editor does this. Black Hole is used by the|monster spells Disrupt and Blk.Hole. The petrify,|hide, cover and low HP bits are not offered.")

  case 7
   FmlNote(3, "The formulas of the stats of the party in battle:|attack multiplier, attack power, attack hit rate,|Yang's attack, defense multiplier, defense, magic|defense multiplier and rate,|two timers: the turn wait and Count, also|called doom, and what Armor and Shell add.||Enter opens them as formulas on one screen, with|the numbers and stats you can change in yellow.")

 end select

 line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf
 select case entry
  case 1 to 4: WriteText(FF4Text("Enter changes the settings. Esc goes back to the list."), 1, 57, 14)
  case 5: WriteText(FF4Text("Enter changes the setting. A setting of custom code is left alone."), 1, 57, 14)
  case 6: WriteText(FF4Text("Enter picks the summon or switches how it is aimed. Esc goes back."), 1, 57, 14)
  case 7: WriteText(FF4Text("Enter opens the formulas of the stats of the party, the turn wait and Count."), 1, 57, 14)
  case 8: WriteText(FF4Text("Enter switches what the effect removes. Esc goes back."), 1, 57, 14)
  case 9: WriteText(FF4Text("Enter opens the statuses that change the damage, with rules you can change."), 1, 57, 14)
  case 10: WriteText(FF4Text("Enter opens more status rules and the poison, HP leak and sleep numbers."), 1, 57, 14)
 end select

end sub


sub FmlEditSpells()

 dim pick as Integer

 do
  fml_spells.UserSelect()
  if fml_spells.cancelled then exit do
  select case fml_spells.selected
   case 1
    pick = FmlPick(fml_x + 24, 3, BattleFormulas.PowerNames(), formulas.power_choice)
    if pick > 0 then formulas.power_choice = pick
   case 2
    pick = FmlPick(fml_x + 24, 4, BattleFormulas.SummonNames(), formulas.summon_choice)
    if pick > 0 then formulas.summon_choice = pick
   case 3
    pick = FmlPick(fml_x + 24, 5, BattleFormulas.DivisorNames(), formulas.divisor_choice)
    if pick > 0 then formulas.divisor_choice = pick
   case 4
    pick = FmlPick(fml_x + 24, 6, BattleFormulas.StatsNames(), formulas.stats_choice)
    if pick > 0 then formulas.stats_choice = pick
   case 5
    if formulas.hits_known then
     fml_number.x = fml_x + 24
     fml_number.y = 7
     fml_number.min_value = 1
     fml_number.max_value = 99
     fml_number.starting_number = formulas.fixed_hits
     fml_number.UserSelect()
     formulas.fixed_hits = fml_number.number
    end if
  end select
  FmlSpellRows()
 loop

end sub


sub FmlEditBook()

 dim spell_pick as BlueMenu
 dim item as Integer
 dim id as Integer

 spell_pick = BlueMenu(fml_x + 6, 4)
 spell_pick.max_rows = 12
 spell_pick.type_ahead = true
 for i as Integer = 0 to &h7F
  spell_pick.AddOption(spells(i).name)
 next

 do
  fml_book.UserSelect()
  if fml_book.cancelled then exit do
  item = (fml_book.selected - 1) \ 2
  if fml_book.selected mod 2 = 1 then
   spell_pick.y = 4 + item
   spell_pick.top_row = 1
   spell_pick.ChangeSelected((formulas.summon_book(item) and &h7F) + 1)
   spell_pick.UserSelect()
   if not spell_pick.cancelled then
    id = spell_pick.selected - 1
    formulas.summon_book(item) = (formulas.summon_book(item) and &h80) or id
   end if
  else
   formulas.summon_book(item) = formulas.summon_book(item) xor &h80
  end if
  FmlBookRows()
 loop

end sub


sub FmlEdit(entry as Integer)

 'Enter on a line of the list: change its settings until Esc.

 select case entry
  case 1: fml_params.SetTo(1): fml_params.UserSelect()
  case 2: fml_params.SetTo(15): fml_params.UserSelect()
  case 3: fml_params.SetTo(6): fml_params.UserSelect()
  case 4: fml_params.SetTo(123): fml_params.UserSelect()
  case 5: FmlEditSpells()
  case 6: FmlEditBook()
  case 7: EditStatFormulas(1): FmlShow(7)
  case 9: EditStatFormulas(2): FmlShow(9)
  case 10: EditStatFormulas(3): FmlShow(10)
  case 8: FmlEditRemoval()
 end select

end sub


sub EditFormulas()

 'The list of formulas on the left, the settings of the highlighted one on the right.

 cls

 fml_hub = BlueMenu(1, 3)
 fml_hub.title = "Battle formulas"
 fml_hub.min_width = 19
 fml_hub.AddOption(FF4Text("Fight"))
 fml_hub.AddOption(FF4Text("Kick"))
 fml_hub.AddOption(FF4Text("Dark Wave"))
 fml_hub.AddOption(FF4Text("Throw"))
 fml_hub.AddOption(FF4Text("Spell damage"))
 fml_hub.AddOption(FF4Text("Summon Book"))
 fml_hub.AddOption(FF4Text("Stats and timers"))
 fml_hub.AddOption(FF4Text("Dispel, Black Hole"))
 fml_hub.AddOption(FF4Text("Status and damage"))
 fml_hub.AddOption(FF4Text("Status modifiers"))
 fml_x = fml_hub.WindowWidth() + 4

 fml_params = CommandParametersMenu(fml_x, 3)

 fml_spells = BlueMenu(fml_x, 3)
 for i as Integer = 1 to 5
  fml_spells.AddOption(FF4Text("."))
 next

 fml_book = BlueMenu(fml_x, 3)
 fml_book.columns = 2
 for i as Integer = 1 to 20
  fml_book.AddOption(FF4Text("."))
 next

 fml_removal = BlueMenu(fml_x, 3)
 fml_removal.columns = 3
 for i as Integer = 1 to 36
  fml_removal.AddOption(FF4Text("."))
 next

 fml_number = BlueNumberInput(fml_x + 24, 3)


 do
  FmlShow(fml_hub.selected)
  fml_hub.cancelled = false
  if fml_hub.UserInput() then
   if fml_hub.cancelled then exit do
   FmlEdit(fml_hub.selected)
  end if
 loop

 cls

end sub
