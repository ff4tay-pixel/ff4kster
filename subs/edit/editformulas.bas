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


dim shared fs_text(1 to 16, 1 to 14) as String 'the pieces of the formula lines: text, or @ and the field
dim shared fs_pieces(1 to 16) as Integer
dim shared fs_labels(1 to 16) as String
dim shared fs_lines as Integer
dim shared fs_line as Integer 'the line of the cursor
dim shared fs_field as Integer 'the field of the cursor, counted in the fields of the line
dim shared fs_hit_x(1 to 16, 1 to 14) as Integer 'where each piece was drawn, for the mouse
dim shared fs_hit_w(1 to 16, 1 to 14) as Integer


sub FsLayout()

 'The lines of the character stat formulas. A piece is plain text, or @ and a field: S1 to S11 the stat of a
 ' term, D1 to D12 its divisor, PL the plus 1 of the attack multiplier, YS YM YP Yang's attack, AN NU MU AD
 ' the turn wait. The terms are numbered as in BattleFormulas.TermStatOffset.

 dim lines_text(1 to 16) as String = { _
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
 dim rest as String
 dim p as Integer

 fs_lines = 16
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


function FsRow(l as Integer) as Integer

 'The screen row of a formula line. The line under "Turn wait, top" is the next row, like a fraction.

 if l = 10 then return 6 + (l - 1) * 2 - 1
 if l = 11 then return 6 + 9 * 2 + 1
 if l = 12 then return 6 + 9 * 2 + 2
 if l = 13 then return 6 + 9 * 2 + 4
 if l = 14 then return 6 + 9 * 2 + 5
 if l = 15 then return 6 + 9 * 2 + 7
 if l = 16 then return 6 + 9 * 2 + 8

 return 6 + (l - 1) * 2

end function


function FsFieldText(code as String) as String

 'The text of a field. A field that holds custom code says ?.

 dim kind as String = left(code, 1)
 dim n as Integer = val(mid(code, 2))
 dim names as String

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
  case "CT": if not formulas.doom_known then return "?" else return str(formulas.doom_ticks)
  case "CS": if not formulas.doom_known then return "?" else return MenuCommand.CodeItem("Dead|Stone|Toad|Mini|Pig|Mute|Blind|Poison", formulas.doom_status)
 end select

 return "?"

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

 BlueBox(1, 3, 76, 29)
 WriteText(FF4Text(" Formulas of the stats of the party in battle "), 2, 3, 14)
 WriteText(FF4Text("Monsters have stats of their own that are not changed here."), 2, 4, 15)
 for l as Integer = 1 to fs_lines
  y = FsRow(l)
  WriteText(FF4Text(fs_labels(l)), 2, y, 15)
  x = 24
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

 if left(code, 1) = "S" then
  n = val(mid(code, 2))
  pick = FmlPick(px, py, BattleFormulas.TermStatNames(), formulas.term_stat(n))
  if pick > 0 then formulas.term_stat(n) = pick
  exit sub
 end if
 if left(code, 1) = "D" then
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

 select case left(code, 1)
  case "S": message = "Enter picks the stat of this term."
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
    case "CT": message = "Enter types after how many ticks Count goes down by 1, 2 in the original."
    case "CS": message = "Enter picks the status a unit gets when Count reaches 0, dead originally."
   end select
 end select

 line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf
 WriteText(FF4Text(left(message, 78)), 1, 57, 14)

end sub


sub FsNotes()

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


sub EditStatFormulas()

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

  case 7
   FmlNote(3, "The formulas of the stats of the party in battle:|attack multiplier, attack power, attack hit rate,|Yang's attack, defense multiplier, defense, magic|defense multiplier and rate,|two timers: the turn wait and Count, also|called doom, and what Armor and Shell add.||Enter opens them as formulas on one screen, with|the numbers and stats you can change in yellow.")

 end select

 line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf
 select case entry
  case 1 to 4: WriteText(FF4Text("Enter changes the settings. Esc goes back to the list."), 1, 57, 14)
  case 5: WriteText(FF4Text("Enter changes the setting. A setting of custom code is left alone."), 1, 57, 14)
  case 6: WriteText(FF4Text("Enter picks the summon or switches how it is aimed. Esc goes back."), 1, 57, 14)
  case 7: WriteText(FF4Text("Enter opens the formulas of the stats of the party, the turn wait and Count."), 1, 57, 14)
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
  case 7: EditStatFormulas(): FmlShow(7)
 end select

end sub


sub EditFormulas()

 'The list of formulas on the left, the settings of the highlighted one on the right.

 cls

 fml_hub = BlueMenu(1, 3)
 fml_hub.title = "Battle formulas"
 fml_hub.min_width = 17
 fml_hub.AddOption(FF4Text("Fight"))
 fml_hub.AddOption(FF4Text("Kick"))
 fml_hub.AddOption(FF4Text("Dark Wave"))
 fml_hub.AddOption(FF4Text("Throw"))
 fml_hub.AddOption(FF4Text("Spell damage"))
 fml_hub.AddOption(FF4Text("Summon Book"))
 fml_hub.AddOption(FF4Text("Stats and timers"))
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
