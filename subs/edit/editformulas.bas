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

 'Lines of help under the settings, separated by |.

 dim rest as String = notes
 dim p as Integer
 dim row as Integer = first_row

 do
  p = instr(rest, "|")
  if p = 0 then
   WriteText(FF4Text(rest), fml_x + 1, row, 14)
  else
   WriteText(FF4Text(left(rest, p - 1)), fml_x + 1, row, 14)
   rest = mid(rest, p + 1)
   row += 1
  end if
 loop until p = 0

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

 end select

 line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf
 select case entry
  case 1 to 4: WriteText(FF4Text("Enter changes the settings. Esc goes back to the list."), 1, 57, 14)
  case 5: WriteText(FF4Text("Enter changes the setting. A setting of custom code is left alone."), 1, 57, 14)
  case 6: WriteText(FF4Text("Enter picks the summon or switches how it is aimed. Esc goes back."), 1, 57, 14)
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
 end select

end sub


sub EditFormulas()

 'The list of formulas on the left, the settings of the highlighted one on the right.

 cls

 fml_hub = BlueMenu(1, 3)
 fml_hub.AddOption(FF4Text("Fight"))
 fml_hub.AddOption(FF4Text("Kick"))
 fml_hub.AddOption(FF4Text("Dark Wave"))
 fml_hub.AddOption(FF4Text("Throw"))
 fml_hub.AddOption(FF4Text("Spell damage"))
 fml_hub.AddOption(FF4Text("Summon Book"))
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

 WriteText(FF4Text("Battle formulas"), 1, 1, 14)

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
