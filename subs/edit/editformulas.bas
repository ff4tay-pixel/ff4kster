'The Battle Formulas editor: the spell damage formula, the Summon Book, the stats of the party, the statuses, the
' timers and the critical hits. The settings of a command (its formula, its ticks) belong to the command and are in
' the Commands editor, they are not here. All the settings here are in the formulas object.

dim shared fml_hub as BlueMenu
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
dim shared fs_entry as Integer 'the line of the list that the page is
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
 ' Count, PA SA PZ SZ Armor and Shell, T1 to T6 the statuses of a rule of page 2, V1 M2 XD its numbers, U1 to
 ' U11 the statuses of a rule of page 3 and E1 to E10 what it does, PD IS IC SD SE SL SK RG LB LM LV the timers
 ' of poison, HP leak, Regen, sleep and paralyze. The terms are numbered as in BattleFormulas.TermStatOffset.
 ' The pages: 1 the stats of the party, 2 the statuses that weaken a unit, 3 the other adjustments of a status,
 ' 4 Armor and Shell, 5 the timers. A line without a label goes on with the rule above it.

 dim page1(1 to 8) as String = { _
  "Attack multiplier|@S1| / |@D1| plus |@S2| / |@D2| plus |@PL", _
  "Attack power|@S3| / |@D3| plus |@S4| / |@D4| plus weapon attack", _
  "Attack hit rate|@S4| / |@D4| plus weapon hit rate", _
  "Yang's attack power|@YS| x |@YM| plus |@S3| / |@D3| plus |@YP", _
  "Defense multiplier|@S5| / |@D5| x shield multiplier plus |@S6| / |@D6", _
  "Defense|@S7| / |@D7| plus armor plus shield defense", _
  "Magic def multiplier|sum of |@S8| and |@S9| / |@D10| plus |@S11| / |@D11", _
  "Magic defense rate|sum of |@S8| and |@S9| / |@D12| plus armor and shield"}
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
 dim page3(1 to 19) as String = { _
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
  "|its magic defense rate is |@E10"}
 dim page3b(1 to 1) as String = {"Magic def mult is 0|when the target has |@U11"}
 dim page4(1 to 4) as String = { _
  "Protect, Armor|adds |@PA| to the defense of the target", _
  "Shell|adds |@SA| to the magic defense of the target", _
  "Armor, Zeromus|in the Zeromus battle Armor |@PZ", _
  "Shell, Zeromus|in the Zeromus battle Shell |@SZ"}
 dim page5(1 to 9) as String = { _
  "Turn wait, top|@AN|@NU", _
  "|divided by My AGI x |@MU| plus |@AD", _
  "Count, doom|counts down once every |@CT| ticks of the timer loop", _
  "|and when it ends the unit gets |@CS", _
  "Poison|loses max HP / |@PD| every tick, at least 1", _
  "|and waits |@IS| plus |@IC| ticks between its ticks", _
  "HP leak, sap|loses |@SD| HP every |@SE| ticks", _
  "|and lasts WIS plus WIL x |@SL| plus |@SK| ticks", _
  "Sleep, paralyze|last |@LB| minus |@LM| x spirit, divided by |@LV| ticks"}
 dim page6(1 to 8) as String = { _
  "Attacker, hit rate|when the attacker is |@FW1", _
  "|its hit rate is multiplied by |@FM1| / 4", _
  "Target, evasion|when the target is |@FW2", _
  "|its evasion is multiplied by |@FM2| / 4", _
  "Attacker, spell hit|when the attacker is |@FW3", _
  "|its spell hit rate is multiplied by |@FM3| / 4", _
  "Target, magic def|when the |@FU| is |@FW4", _
  "|its magic defense rate is multiplied by |@FM4| / 4"}
 dim page7(1 to 7) as String = { _
  "Attacker, back row|its hit rate is |@RA1", _
  "|ignored with the no back row penalty flag: |@RX1", _
  "|ignored when it is jumping: |@RJ1", _
  "Target, back row|the hit rate against it is |@RA2", _
  "|ignored if the attacker has that flag: |@RX2", _
  "|ignored if the attacker is jumping: |@RJ2", _
  "|and its defense is |@RD"}
 dim page8(1 to 2) as String = { _
  "Critical hit|the damage is multiplied by |@KM| divided by 4", _
  "|then the weapon's critical bonus is added: |@KB"}
 dim joined(1 to 20) as String

 select case fs_page
  case 8
   fs_x0 = 16
   FsFill(page8(), 2)
  case 7
   fs_x0 = 24
   FsFill(page7(), 7)
  case 6
   fs_x0 = 24
   FsFill(page6(), 8)
  case 5
   fs_x0 = 22
   FsFill(page5(), 9)
  case 4
   fs_x0 = 24
   FsFill(page4(), 4)
  case 3
   for i as Integer = 1 to 19
    joined(i) = page3(i)
   next
   joined(20) = page3b(1)
   fs_x0 = 22
   FsFill(joined(), 20)
  case 2
   fs_x0 = 30
   FsFill(page2(), 9)
  case else
   fs_x0 = 24
   FsFill(page1(), 8)
 end select

end sub


function FsRow(l as Integer) as Integer

 'The screen row of a formula line. On page 1 every line has a row of space after it. On the other pages a
 ' line without a label goes on with the rule above it, and a rule has a row of space before it.

 dim y as Integer = 6

 if fs_page >= 2 then
  for i as Integer = 2 to l
   if fs_labels(i) <> "" then y += 2 else y += 1
  next
  return y
 end if

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
  case "LB": if not formulas.sleep_known then return "?" else return str(formulas.sleep_base)
  case "LM": if not formulas.sleep_known then return "?" else return MenuCommand.CodeItem("1|2|4", formulas.sleep_mult)
  case "LV": if not formulas.sleep_known then return "?" else return str(formulas.sleep_div)
  case "M2": if not formulas.st_known(2) then return "?" else return MenuCommand.CodeItem("x0.5|x1|x2", formulas.st_mult)
  case "XD": if not formulas.st_known(2) then return "?" else return iif(formulas.st_defense_zero, "0", "unchanged")
  case "FW1", "FW2", "FW3", "FW4": if not formulas.slot_known(val(mid(code, 3))) then return "?" else return MenuCommand.CodeItem("slot 0 of both sides|slot 0 of the party|the whole party", formulas.slot_who(val(mid(code, 3))))
  case "FM1", "FM2", "FM3", "FM4": if not formulas.slot_known(val(mid(code, 3))) then return "?" else return str(formulas.slot_mult(val(mid(code, 3))))
  case "RA1", "RA2": if not formulas.back_known then return "?" else return MenuCommand.CodeItem("halved, original|unchanged|doubled", formulas.back_hit(val(mid(code, 3))))
  case "RX1", "RX2": if not formulas.back_known then return "?" else return iif(formulas.back_flag(val(mid(code, 3))), "yes", "no")
  case "RJ1", "RJ2": if not formulas.back_known then return "?" else return iif(formulas.back_jump(val(mid(code, 3))), "yes", "no")
  case "RD": if not formulas.back_known then return "?" else return MenuCommand.CodeItem("x0.5|x1|x2", formulas.back_def)
  case "KM": if not formulas.crit_known then return "?" else return str(formulas.crit_mult)
  case "KB": if not formulas.crit_known then return "?" else return iif(formulas.crit_bonus, "yes", "no")
  case "FU": if not formulas.slot_known(4) then return "?" else return iif(formulas.slot_target, "target", "attacker")
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
 dim page_titles(1 to 8) as String = {" Formulas of the stats of the party in battle ", " Statuses that weaken a unit ", " Other adjustments of the statuses ", " Armor and Shell ", " Timers ", " Bonus of the first slot ", " The back row ", " Critical hits of Fight "}
 dim page_heights(1 to 9) as Integer = {17, 22, 33, 10, 17, 13, 11, 7}
 dim page_texts(1 to 8) as String = {"Monsters have stats of their own that are not changed here.", _
  "Each rule is for a set of statuses of the unit: none switches the rule off.", _
  "Each rule is for a set of statuses of the unit: none switches the rule off.", _
  "Spells with these effects add to the defense stats of their target.", _
  "A tick is one pass of the battle loop, its length depends on the battle speed.", _
  "The first slot has these rates multiplied by a number divided by 4.", _
  "The back row rules of Fight, Aim, Jump and Focus. Spells are not affected.", _
  "A critical hit adds to the damage before the defense is taken off."}

 BlueBox(1, 3, 76, page_heights(fs_page))
 WriteText(FF4Text(page_titles(fs_page)), 2, 3, 14)
 WriteText(FF4Text(page_texts(fs_page)), 2, 4, 15)
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
  case "RA1", "RA2"
   n = val(mid(code, 3))
   if formulas.back_known then
    pick = FmlPick(px, py, "halved, original|unchanged|doubled", formulas.back_hit(n))
    if pick > 0 then formulas.back_hit(n) = pick
   end if
  case "RX1", "RX2"
   n = val(mid(code, 3))
   if formulas.back_known then
    pick = FmlPick(px, py, "yes, original|no", iif(formulas.back_flag(n), 1, 2))
    if pick > 0 then formulas.back_flag(n) = (pick = 1)
   end if
  case "RJ1", "RJ2"
   n = val(mid(code, 3))
   if formulas.back_known then
    pick = FmlPick(px, py, "yes, original|no", iif(formulas.back_jump(n), 1, 2))
    if pick > 0 then formulas.back_jump(n) = (pick = 1)
   end if
  case "RD"
   if formulas.back_known then
    pick = FmlPick(px, py, "x0.5|x1|x2, original", formulas.back_def)
    if pick > 0 then formulas.back_def = pick
   end if
  case "FW1", "FW2", "FW3", "FW4"
   n = val(mid(code, 3))
   if formulas.slot_known(n) then
    pick = FmlPick(px, py, "slot 0 of both sides, original|slot 0 of the party|the whole party", formulas.slot_who(n))
    if pick > 0 then formulas.slot_who(n) = pick
   end if
  case "FM1", "FM2", "FM3", "FM4"
   n = val(mid(code, 3))
   if formulas.slot_known(n) then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 0: fml_number.max_value = 10
    fml_number.starting_number = formulas.slot_mult(n)
    fml_number.UserSelect()
    formulas.slot_mult(n) = fml_number.number
   end if
  case "KM"
   if formulas.crit_known then
    fml_number.x = px: fml_number.y = py
    fml_number.min_value = 0: fml_number.max_value = 16
    fml_number.starting_number = formulas.crit_mult
    fml_number.UserSelect()
    formulas.crit_mult = fml_number.number
   end if
  case "KB"
   if formulas.crit_known then
    pick = FmlPick(px, py, "yes, original|no", iif(formulas.crit_bonus, 1, 2))
    if pick > 0 then formulas.crit_bonus = (pick = 1)
   end if
  case "FU"
   if formulas.slot_known(4) then
    pick = FmlPick(px, py, "attacker, original|target", iif(formulas.slot_target, 2, 1))
    if pick > 0 then formulas.slot_target = (pick = 2)
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
    case "RA1", "RA2": message = "Enter picks what happens to the hit rate: halved, unchanged or doubled."
    case "RX1", "RX2": message = "Enter picks if the no back row penalty flag, a bow for example, avoids it."
    case "RJ1", "RJ2": message = "Enter picks if a jumping unit avoids it."
    case "RD": message = "Enter picks what the defense of a target in the back row is multiplied by."
    case "FW1", "FW2", "FW3", "FW4": message = "Enter picks who gets the bonus: slot 0 of both sides, of the party, or all."
    case "FM1", "FM2", "FM3", "FM4": message = "Enter types the number the rate is multiplied by, divided by 4: 5 is 25% more."
    case "KM": message = "Enter types the multiplier, divided by 4: 4 changes nothing, 8 doubles."
    case "KB": message = "Enter picks if the weapon's critical bonus is added, yes in the original."
    case "FU": message = "Enter picks whose slot decides: the attacker, as in the game, or the target."
    case "PD": message = "Enter picks the number that the max HP is divided by, 8 in the original."
    case "SD": message = "Enter types the HP that HP leak takes every tick, 2 in the original."
    case "IS": message = "Enter picks the stat of a character that the wait between ticks starts from."
    case "IC": message = "Enter types the number added to it, 20 in the original. Petrify uses it too."
    case "SE": message = "Enter types after how many ticks HP leak takes its HP, 1 in the original."
    case "SL": message = "Enter types what WIS plus WIL is multiplied by for the length, 2 originally."
    case "SK": message = "Enter types the number added to the length of HP leak, 30 in the original."
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


declare sub FmlRemovalRows()
declare sub FmlShow(entry as Integer)

const fml_undo_max = 40
dim shared fml_undo_entry(1 to fml_undo_max) as Integer 'the list line that each saved copy is of
dim shared fml_undo_f(1 to fml_undo_max) as BattleFormulas
dim shared fml_undo_count as Integer
dim shared fml_hook_entry as Integer 'the line of the list whose menus are open, 0: the keys are not handled
dim shared fml_in_hook as Boolean


function FmlEntryOf(row as Integer) as Integer

 'The setting group (the entry numbers used everywhere) that a row of the list shows: the rows 1 to 10 are the
 ' groups 5 to 14, and the last row, the critical hits, is group 15.

 if row = 11 then return 15

 return row + 4

end function


function FmlGroupData(entry as Integer, f as BattleFormulas ptr) as String

 'All the settings of a line of the list as one text, to see if they differ from another copy.

 dim s as String

 select case entry
  case 5: s = str(f->power_choice) + "," + str(f->summon_choice) + "," + str(f->divisor_choice) + "," + str(f->stats_choice) + "," + str(f->fixed_hits)
  case 6: s = str(f->protect_add) + "," + str(f->shell_add) + "," + str(f->protect_zeromus) + "," + str(f->shell_zeromus)
  case 7: s = str(f->dispel_s2) + "," + str(f->dispel_s4) + "," + str(f->hole_s2) + "," + str(f->hole_s4) + "," + str(f->hole_speed)
  case 8
   for i as Integer = 0 to 9
    s += str(f->summon_book(i)) + ","
   next
  case 9
   for i as Integer = 1 to 12
    s += str(f->term_stat(i)) + "/" + str(f->term_div(i)) + ","
   next
   s += str(f->plus_on) + "," + str(f->yang_stat) + "," + str(f->yang_mult) + "," + str(f->yang_plus)
  case 15: s = str(f->crit_mult) + "," + str(f->crit_bonus)
  case 10
   for i as Integer = 1 to 4
    s += str(f->slot_who(i)) + "/" + str(f->slot_mult(i)) + ","
   next
   s += str(f->slot_target)
  case 11
   s = str(f->back_hit(1)) + "," + str(f->back_hit(2)) + "," + str(f->back_flag(1)) + "," + str(f->back_flag(2)) + ","
   s += str(f->back_jump(1)) + "," + str(f->back_jump(2)) + "," + str(f->back_def)
  case 12
   for i as Integer = 1 to 6
    s += str(f->st_mask(i)) + ","
   next
   s += str(f->st_power) + "," + str(f->st_mult) + "," + str(f->st_defense_zero)
  case 13
   for i as Integer = 1 to 11
    s += str(f->um_list(i)) + "/" + str(f->um_mask(i)) + "/" + str(f->um_effect(i)) + ","
   next
  case 14
   s = str(f->speed_anchor) + "," + str(f->speed_num) + "," + str(f->speed_mul) + "," + str(f->speed_add) + "," + str(f->doom_ticks) + "," + str(f->doom_status) + ","
   s += str(f->poison_div) + "," + str(f->wait_stat) + "," + str(f->wait_const) + "," + str(f->sap_damage) + "," + str(f->sap_every) + ","
   s += str(f->sap_len_mult) + "," + str(f->sap_len_const) + "," + str(f->sleep_base) + "," + str(f->sleep_mult) + "," + str(f->sleep_div)
 end select

 return s

end function


sub FmlGroupCopy(entry as Integer, df as BattleFormulas ptr, sf as BattleFormulas ptr)

 'Copies the settings of a line of the list from one copy to another. The flags that say whether the code is
 ' the original come from the ROM and are not copied.

 select case entry
  case 5
   df->power_choice = sf->power_choice: df->summon_choice = sf->summon_choice: df->divisor_choice = sf->divisor_choice
   df->stats_choice = sf->stats_choice: df->fixed_hits = sf->fixed_hits
  case 6
   df->protect_add = sf->protect_add: df->shell_add = sf->shell_add
   df->protect_zeromus = sf->protect_zeromus: df->shell_zeromus = sf->shell_zeromus
  case 7
   df->dispel_s2 = sf->dispel_s2: df->dispel_s4 = sf->dispel_s4: df->hole_s2 = sf->hole_s2: df->hole_s4 = sf->hole_s4
   df->hole_speed = sf->hole_speed
  case 8
   for i as Integer = 0 to 9
    df->summon_book(i) = sf->summon_book(i)
   next
  case 9
   for i as Integer = 1 to 12
    df->term_stat(i) = sf->term_stat(i): df->term_div(i) = sf->term_div(i)
   next
   df->plus_on = sf->plus_on: df->yang_stat = sf->yang_stat: df->yang_mult = sf->yang_mult: df->yang_plus = sf->yang_plus
  case 15
   df->crit_mult = sf->crit_mult: df->crit_bonus = sf->crit_bonus
  case 10
   for i as Integer = 1 to 4
    df->slot_who(i) = sf->slot_who(i): df->slot_mult(i) = sf->slot_mult(i)
   next
   df->slot_target = sf->slot_target
  case 11
   df->back_hit(1) = sf->back_hit(1): df->back_hit(2) = sf->back_hit(2)
   df->back_flag(1) = sf->back_flag(1): df->back_flag(2) = sf->back_flag(2)
   df->back_jump(1) = sf->back_jump(1): df->back_jump(2) = sf->back_jump(2)
   df->back_def = sf->back_def
  case 12
   for i as Integer = 1 to 6
    df->st_mask(i) = sf->st_mask(i)
   next
   df->st_power = sf->st_power: df->st_mult = sf->st_mult: df->st_defense_zero = sf->st_defense_zero
  case 13
   for i as Integer = 1 to 11
    df->um_list(i) = sf->um_list(i): df->um_mask(i) = sf->um_mask(i): df->um_effect(i) = sf->um_effect(i)
   next
  case 14
   df->speed_anchor = sf->speed_anchor: df->speed_num = sf->speed_num: df->speed_mul = sf->speed_mul: df->speed_add = sf->speed_add
   df->doom_ticks = sf->doom_ticks: df->doom_status = sf->doom_status: df->poison_div = sf->poison_div
   df->wait_stat = sf->wait_stat: df->wait_const = sf->wait_const: df->sap_damage = sf->sap_damage: df->sap_every = sf->sap_every
   df->sap_len_mult = sf->sap_len_mult: df->sap_len_const = sf->sap_len_const:
   df->sleep_base = sf->sleep_base: df->sleep_mult = sf->sleep_mult: df->sleep_div = sf->sleep_div
 end select

end sub


function FmlGroupChanged(entry as Integer) as Boolean

 return FmlGroupData(entry, @formulas) <> FmlGroupData(entry, @orig_formulas)

end function


sub FmlUndoPush(entry as Integer)

 'Saves a copy of a line of the list before something in it changes. Ctrl-Z gives the newest one back. A copy
 ' that is the same as the one before it is not saved.

 dim now_text as String = FmlGroupData(entry, @formulas)

 if fml_undo_count > 0 then
  if fml_undo_entry(fml_undo_count) = entry then
   if FmlGroupData(entry, @fml_undo_f(fml_undo_count)) = now_text then exit sub
  end if
 end if
 if fml_undo_count = fml_undo_max then
  for i as Integer = 2 to fml_undo_max
   fml_undo_entry(i - 1) = fml_undo_entry(i)
   fml_undo_f(i - 1) = fml_undo_f(i)
  next
  fml_undo_count -= 1
 end if
 fml_undo_count += 1
 fml_undo_entry(fml_undo_count) = entry
 fml_undo_f(fml_undo_count) = formulas

end sub


function FmlUndo() as Integer

 'Gives back the newest saved copy that is not the same as the settings now. Returns the line of the list it was
 ' of, 0 if there was nothing to undo.

 dim entry as Integer
 dim n as Integer

 do while fml_undo_count > 0
  n = fml_undo_count
  entry = fml_undo_entry(n)
  fml_undo_count -= 1
  if FmlGroupData(entry, @fml_undo_f(n)) <> FmlGroupData(entry, @formulas) then
   FmlGroupCopy(entry, @formulas, @fml_undo_f(n))
   return entry
  end if
 loop

 return 0

end function


sub FmlRefresh(entry as Integer)

 'Draws the open menus of a line of the list again after undo or revert changed its settings.

 select case entry
  case 5: FmlSpellRows(): fml_spells.Display()
  case 7: FmlRemovalRows(): fml_removal.Display()
  case 8: FmlBookRows(): fml_book.Display()
 end select

end sub


sub FmlDoUndo()

 dim entry as Integer = FmlUndo()

 if entry = 0 then
  InfoBox("There is nothing to undo.||Press any key")
 else
  FmlRefresh(entry)
 end if

end sub


sub FmlDoRevert(entry as Integer)

 'Ctrl-R: puts a line of the list back the way it was when the ROM was loaded, after asking.

 if not FmlGroupChanged(entry) then
  InfoBox("This line has no changes.||Press any key")
  exit sub
 end if
 if ConfirmBox("Revert this line to the loaded ROM?") then
  FmlUndoPush(entry)
  FmlGroupCopy(entry, @formulas, @orig_formulas)
  FmlRefresh(entry)
 end if

end sub


function FmlActionKey() as UInteger

 'Space opens a menu of the actions on the line of the list, so that no key has to be learned. Returns the key
 ' the chosen entry stands for, 0 if cancelled.

 dim m as BlueMenu

 m = BlueMenu(40, 3)
 m.title = "This line"
 m.min_width = 34
 m.AddOption(FF4Text("Revert to the loaded ROM   Ctrl-R"))
 m.AddOption(FF4Text("Undo the last change        Ctrl-Z"))
 m.UserSelect()
 if m.cancelled then return 0
 if m.selected = 1 then return 18

 return 26

end function


sub FmlKeyHook(key as UInteger)

 'Called by every menu with each key. While the menus of a line of the list are open Enter saves a copy for
 ' Ctrl-Z, and Ctrl-R and Ctrl-Z revert and undo there as in the lists of the other editors.

 if fml_hook_entry = 0 or fml_in_hook then exit sub

 fml_in_hook = true 'the boxes that revert and undo open send keys to the hook too
 select case key
  case ENTER_KEY
   FmlUndoPush(fml_hook_entry)
  case 18
   FmlDoRevert(fml_hook_entry)
  case 26
   FmlDoUndo()
 end select
 fml_in_hook = false

end sub


sub FsNotes1()

 BlueBox(1, 23, 76, 5)
 WriteText(FF4Text(" Notes "), 2, 23, 14)
 WriteText(FF4Text("Ctrl-R reverts this page to the loaded ROM, Ctrl-Z undoes, Space shows both."), 2, 28, 15)
 WriteText(FF4Text("Arrows move between the yellow fields, Enter changes one, Esc goes back."), 2, 24, 15)
 WriteText(FF4Text("The level term of attack power and hit rate is one term, and so is the"), 2, 25, 15)
 WriteText(FF4Text("strength term of attack power and Yang's attack: changing it on one"), 2, 26, 15)
 WriteText(FF4Text("line changes the other."), 2, 27, 15)

end sub


sub FsNotes2()

 BlueBox(1, 27, 76, 11)
 WriteText(FF4Text(" Notes "), 2, 27, 14)
 WriteText(FF4Text("Ctrl-R reverts this page to the loaded ROM, Ctrl-Z undoes, Space shows both."), 2, 37, 15)
 WriteText(FF4Text("In the original game Frog and Mini do all of these, and only Frog makes a"), 2, 28, 15)
 WriteText(FF4Text("spell ignore the magic defense multiplier. Pig changes no damage in the"), 2, 29, 15)
 WriteText(FF4Text("original game, but it can be given any rule, like any other status."), 2, 30, 15)
 WriteText(FF4Text("A unit with any of the statuses you pick gets the rule, so a poisoned"), 2, 32, 15)
 WriteText(FF4Text("target can take double damage instead of a mini one."), 2, 33, 15)
 WriteText(FF4Text("Which statuses stop a unit from using commands is set in the Commands"), 2, 35, 15)
 WriteText(FF4Text("editor, under Information."), 2, 36, 15)

end sub


sub FsNotes3()

 BlueBox(1, 38, 76, 8)
 WriteText(FF4Text(" Notes "), 2, 38, 14)
 WriteText(FF4Text("Ctrl-R reverts this page to the loaded ROM, Ctrl-Z undoes, Space shows both."), 2, 45, 15)
 WriteText(FF4Text("Each rule tests the statuses of the attacker or of the target. Pick the"), 2, 39, 15)
 WriteText(FF4Text("list first, persistent, temporary, system or hidden, then its statuses, so"), 2, 40, 15)
 WriteText(FF4Text("that Sleep can halve the attack power. None switches a rule off."), 2, 41, 15)
 WriteText(FF4Text("Berserk adds 50% to the attack power, which cannot change, but its"), 2, 43, 15)
 WriteText(FF4Text("statuses can. Barrier, Image and the back row are not here."), 2, 44, 15)

end sub


sub FsNotes4()

 BlueBox(1, 15, 76, 6)
 WriteText(FF4Text(" Notes "), 2, 15, 14)
 WriteText(FF4Text("Ctrl-R reverts this page to the loaded ROM, Ctrl-Z undoes, Space shows both."), 2, 21, 15)
 WriteText(FF4Text("Armor and Shell add their number every time they are cast, up to 255."), 2, 16, 15)
 WriteText(FF4Text("The original game makes them do nothing in the Zeromus battle."), 2, 17, 15)
 WriteText(FF4Text("Every spell that has the same effect in the Spells editor does the same,"), 2, 19, 15)
 WriteText(FF4Text("and so does the Brace command, which casts Armor."), 2, 20, 15)

end sub


sub FsNotes5()

 BlueBox(1, 22, 76, 14)
 WriteText(FF4Text(" Notes "), 2, 22, 14)
 WriteText(FF4Text("Ctrl-R reverts this page to the loaded ROM, Ctrl-Z undoes, Space shows both."), 2, 36, 15)
 WriteText(FF4Text("The turn wait is for every unit, monsters too: a unit waits the top line"), 2, 23, 15)
 WriteText(FF4Text("divided by the line below it. The anchor is the actor that Cover disables"), 2, 24, 15)
 WriteText(FF4Text("if present, else the actor that covers, else the first party member. Both"), 2, 25, 15)
 WriteText(FF4Text("are set under Cover in the Commands editor."), 2, 26, 15)
 WriteText(FF4Text("Count starts from the Power of the spell, set in the Spells editor, and"), 2, 28, 15)
 WriteText(FF4Text("goes down by 1 each step. The other timers, such as poison, stop and sap,"), 2, 29, 15)
 WriteText(FF4Text("go down by 1 on every tick, so with 2 Count is half as fast as they are."), 2, 30, 15)
 WriteText(FF4Text("Poison takes the max HP divided by a number every tick, at least 1."), 2, 32, 15)
 WriteText(FF4Text("Sleep and Paralyze last the base minus the multiplier times the target's"), 2, 33, 15)
 WriteText(FF4Text("spirit, divided by a number. Petrify uses the wait of poison, and monsters"), 2, 34, 15)
 WriteText(FF4Text("use their level plus 10 instead of the stats."), 2, 35, 15)

end sub


sub FsNotes6()

 BlueBox(1, 18, 76, 9)
 WriteText(FF4Text(" Notes "), 2, 18, 14)
 WriteText(FF4Text("In the original game the unit in the first slot, the first party member"), 2, 19, 15)
 WriteText(FF4Text("and also the first monster, has 25% more of these rates: the rate is"), 2, 20, 15)
 WriteText(FF4Text("multiplied by 5 and divided by 4. Any number from 0 to 10 can be used:"), 2, 21, 15)
 WriteText(FF4Text("4 is no bonus, 8 is double and 3 is 25% less."), 2, 22, 15)
 WriteText(FF4Text("The magic defense rate checks the slot of the attacker in the original"), 2, 23, 15)
 WriteText(FF4Text("game, which looks like a mistake: switch it to the target to give the"), 2, 24, 15)
 WriteText(FF4Text("bonus to the unit that is attacked."), 2, 25, 15)
 WriteText(FF4Text("Ctrl-R reverts this page, Ctrl-Z undoes, Space shows both."), 2, 26, 15)

end sub


sub FsNotes7()

 BlueBox(1, 16, 76, 8)
 WriteText(FF4Text(" Notes "), 2, 16, 14)
 WriteText(FF4Text("In the original game a unit in the back row has its hit rate halved when it"), 2, 17, 15)
 WriteText(FF4Text("attacks, and a target in the back row halves the hit rate against it and has"), 2, 18, 15)
 WriteText(FF4Text("its defense doubled. A unit with the no back row penalty flag, which a bow"), 2, 19, 15)
 WriteText(FF4Text("gives, or a jumping unit is not affected. The hit rate can also be doubled."), 2, 20, 15)
 WriteText(FF4Text("The rules are for Fight, Aim, Jump and Focus, spells ignore the back row."), 2, 22, 15)
 WriteText(FF4Text("Ctrl-R reverts this page, Ctrl-Z undoes, Space shows both."), 2, 23, 15)

end sub


sub FsNotes8()

 BlueBox(1, 11, 76, 11)
 WriteText(FF4Text(" Notes "), 2, 11, 14)
 WriteText(FF4Text("The critical hit rate and bonus belong to the character, they are set"), 2, 12, 15)
 WriteText(FF4Text("in Characters, Edit starting data, not in the weapon. A bow triples the rate"), 2, 13, 15)
 WriteText(FF4Text("and adds the arrow attack to the bonus, two weapons double the rate."), 2, 14, 15)
 WriteText(FF4Text("Fight picks a number from 0 to 98, the hit is critical if it is below the"), 2, 15, 15)
 WriteText(FF4Text("rate. In the original game the bonus is added to the damage before the"), 2, 16, 15)
 WriteText(FF4Text("defense is taken off. Here the damage can first be multiplied: 4 divided by"), 2, 17, 15)
 WriteText(FF4Text("4 changes nothing, 8 doubles it. The bonus can be left out. The damage"), 2, 18, 15)
 WriteText(FF4Text("still stops at 9999. A Frog or a Mini never scores a critical hit. Jump"), 2, 19, 15)
 WriteText(FF4Text("and Kick use the same code. Ctrl-R reverts, Ctrl-Z undoes."), 2, 20, 15)

end sub


sub FsNotes()

 select case fs_page
  case 8: FsNotes8()
  case 7: FsNotes7()
  case 6: FsNotes6()
  case 2: FsNotes2()
  case 3: FsNotes3()
  case 4: FsNotes4()
  case 5: FsNotes5()
  case else: FsNotes1()
 end select

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
 dim entry_of_page(1 to 8) as Integer = {9, 12, 13, 6, 14, 10, 11, 15}
 fs_entry = entry_of_page(page)
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
    FmlUndoPush(fs_entry)
    FsEditField(mid(fs_text(fs_line, FsPieceOfField(fs_line, fs_field)), 2))
   case 18
    FmlDoRevert(fs_entry)
   case 26
    FmlDoUndo()
   case SPACE_KEY
    code = FmlActionKey()
    if code = 18 then FmlDoRevert(fs_entry)
    if code = 26 then FmlDoUndo()
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

 'Draws the settings of one line of the list in the window on its right. The lines are numbered 5 to 15 (1 to
 ' 4 were the commands, which are in the Commands editor now): 5 to 8 spells (damage, Armor and Shell, Dispel and
 ' Black Hole, the Summon Book), 9 the stats of the party, 10 and 11 the first slot and the back row, 12 and 13
 ' the statuses, 14 the timers, 15 the critical hits.

 line (fml_x * 8 - 8, 3 * 8)-(639, 56 * 8 - 1), RGB(0, 0, 0), bf

 select case entry
  case 5
   FmlSpellRows()
   fml_spells.Display()
   FmlNote(11, "Base damage is the spell power times the power scale|plus a random part of up to half of that. It is then|multiplied by the hits that land. Each cast tries the|number of hits shown, from the caster's stat, and a try|lands at the spell's hit rate. Summons and spells cast|from items skip the tries and always count the number|of hits set on the last line. A spell cast from a weapon|counts the weapon's Power, in the Weapons editor.")

  case 6
   FmlNote(3, "What the spells Armor and Shell add to the defense and|the magic defense of their target, and whether they|work in the Zeromus battle.||Enter opens them as lines with fields you can change.")

  case 7
   FmlRemovalRows()
   fml_removal.Display()
   FmlNote(18, "Dispel and Black Hole take statuses off their target.|Enter on removes or keeps switches it, in the column of|the effect. Black Hole also puts the speed back to|normal, which ends haste and slow. Every spell with|the Dispel effect or the Black Hole effect in the|Spells editor does this. Black Hole is used by the|monster spells Disrupt and Blk.Hole. The petrify,|hide, cover and low HP bits are not offered.")

  case 8
   FmlBookRows()
   fml_book.Display()
   FmlNote(16, "The Summon Book item calls one of these ten at random.|Enter on a name picks the summon, Enter on its right|side switches between all targets and one random target.")

  case 9
   FmlNote(3, "The formulas of the stats of the party in battle:|attack multiplier, attack power, attack hit rate,|Yang's attack, defense multiplier, defense, magic|defense multiplier and magic defense rate.||Enter opens them as formulas on one screen, with|the numbers and stats you can change in yellow.")

  case 10
   FmlNote(3, "The bonus of the unit in the first slot: in the original|game it has 25% more hit rate when it attacks, 25% more|evasion when it is attacked, and 25% more magic defense|rate. The first slot is the first party member and also|the first monster.||Enter opens them as rules with fields you can change.")

  case 11
   FmlNote(3, "The back row: in the original game a unit in the back|row has its hit rate halved when it attacks, a target in|the back row halves the hit rate against it, and doubles|its defense. A unit with the no back row penalty flag,|a bow for example, or a jumping unit is not affected.||Enter opens them as rules with fields you can change.")

  case 12
   FmlNote(3, "The statuses that weaken a unit: a weak attacker|(Frog and Mini do 1 attack power), a hurt target|(they take double damage and have no defense), no|defense multiplier, spells that ignore magic defense,|attackers that inflict no status or use no arrows.||Enter opens them as rules with fields you can change.|Each rule can have any statuses of the list.")

  case 13
   FmlNote(3, "The other places where a status changes a number:|a blind attacker or target, berserk, jump, curse,|defend and focus, for attacks and for spells.||Enter opens them as rules with fields you can change.|Each rule can have statuses of any of the four lists.")

  case 15
   FmlNote(3, "The critical hits of Fight, Jump and Kick: in the|original game the weapon's critical bonus is added to|the damage. The damage can be multiplied first, and|the bonus can be left out.||Enter opens them as a line with fields you can change.")

  case 14
   FmlNote(3, "The timers of the battle: the turn wait of every unit,|Count, also called doom, poison, HP leak and|the length of sleep and paralyze.||Enter opens them as lines with fields you can change.")

 end select

 line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf
 select case entry
  case 5: WriteText(FF4Text("Enter changes the setting. A setting of custom code is left alone."), 1, 57, 14)
  case 6: WriteText(FF4Text("Enter opens the numbers that Armor and Shell add."), 1, 57, 14)
  case 7: WriteText(FF4Text("Enter switches what the effect removes. Esc goes back."), 1, 57, 14)
  case 8: WriteText(FF4Text("Enter picks the summon or switches how it is aimed. Esc goes back."), 1, 57, 14)
  case 9: WriteText(FF4Text("Enter opens the formulas of the stats of the party."), 1, 57, 14)
  case 10: WriteText(FF4Text("Enter opens the bonus of the first slot, with rules you can change."), 1, 57, 14)
  case 11: WriteText(FF4Text("Enter opens the rules of the back row, with fields you can change."), 1, 57, 14)
  case 12: WriteText(FF4Text("Enter opens the statuses that weaken a unit, with rules you can change."), 1, 57, 14)
  case 13: WriteText(FF4Text("Enter opens the other status rules, with fields you can change."), 1, 57, 14)
  case 14: WriteText(FF4Text("Enter opens the timers, with fields you can change."), 1, 57, 14)
  case 15: WriteText(FF4Text("Enter opens the critical hit damage, with fields you can change."), 1, 57, 14)
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
  case 5: fml_hook_entry = 5: FmlEditSpells()
  case 6: EditStatFormulas(4): FmlShow(6)
  case 7: fml_hook_entry = 7: FmlEditRemoval()
  case 8: fml_hook_entry = 8: FmlEditBook()
  case 9: EditStatFormulas(1): FmlShow(9)
  case 10: EditStatFormulas(6): FmlShow(10)
  case 11: EditStatFormulas(7): FmlShow(11)
  case 12: EditStatFormulas(2): FmlShow(12)
  case 13: EditStatFormulas(3): FmlShow(13)
  case 14: EditStatFormulas(5): FmlShow(14)
  case 15: EditStatFormulas(8): FmlShow(15)
 end select

 fml_hook_entry = 0

end sub


sub EditFormulas()

 'The list of formulas on the left, the settings of the highlighted one on the right.

 dim key as UInteger

 cls

 key_hook = @FmlKeyHook
 BlueBox(1, 18, 19, 3)
 WriteText(FF4Text(" Keys "), 2, 18, 14)
 WriteText(FF4Text("Space: menu"), 2, 19, 15)
 WriteText(FF4Text("Ctrl-R: revert"), 2, 20, 15)
 WriteText(FF4Text("Ctrl-Z: undo"), 2, 21, 15)
 fml_hub = BlueMenu(1, 3)
 fml_hub.title = "Battle formulas"
 fml_hub.min_width = 19
 fml_hub.AddOption(FF4Text("Spell damage"))
 fml_hub.AddOption(FF4Text("Armor and Shell"))
 fml_hub.AddOption(FF4Text("Dispel, Black Hole"))
 fml_hub.AddOption(FF4Text("Summon Book"))
 fml_hub.AddOption(FF4Text("Party stats"))
 fml_hub.AddOption(FF4Text("First slot bonus"))
 fml_hub.AddOption(FF4Text("Back row"))
 fml_hub.AddOption(FF4Text("Weakening statuses"))
 fml_hub.AddOption(FF4Text("Status adjustments"))
 fml_hub.AddOption(FF4Text("Timers"))
 fml_hub.AddOption(FF4Text("Critical hits"))
 fml_x = fml_hub.WindowWidth() + 4

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
  FmlShow(FmlEntryOf(fml_hub.selected))
  for i as Integer = 1 to 11
   if FmlGroupChanged(FmlEntryOf(i)) then fml_hub.ChangeOption(i, "", 14) else fml_hub.ChangeOption(i, "", 15)
  next
  fml_hub.cancelled = false
  if fml_hub.UserInput() then
   if fml_hub.cancelled then exit do
   FmlEdit(FmlEntryOf(fml_hub.selected))
  else
   key = fml_hub.last_key
   if key = SPACE_KEY then key = FmlActionKey()
   if key = 18 then FmlDoRevert(FmlEntryOf(fml_hub.selected))
   if key = 26 then FmlDoUndo()
  end if
 loop

 key_hook = 0
 fml_hook_entry = 0
 cls

end sub
