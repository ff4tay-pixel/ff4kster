'Armors editor. Same layout idea as the Weapons editor (see itemforms.bas and editweapons.bas): the list on the
'left, every box of the selected armor on the screen, Enter on the list moves the cursor into the boxes.
'
'  1 Information   name, price, defense, evade, magic defense, magic evade, metallic and description
'  2 Element/status  a set number (shared by everything that uses it) and its flags
'  3 Stats         the bonus and penalty pair and the stats it applies to
'  4 Races         the creature types the armor protects against
'  5 Equip         a set number (shared) and the jobs that can equip it

const ar_p_info = 1
const ar_p_elidx = 2
const ar_p_elgrid = 3
const ar_p_statmod = 4
const ar_p_stat = 5
const ar_p_race = 6
const ar_p_eqidx = 7
const ar_p_eqgrid = 8

dim shared ar_list as BlueMenu
dim shared ar_info as ArmorInformationMenu
dim shared ar_element as ElementMenu
dim shared ar_stat as StatMenu
dim shared ar_race as RaceMenu
dim shared ar_equip as EquipMenu


sub ArShow(a as Integer)

 'Copies armor a to the boxes and draws them

 ar_info.SetTo(a)
 ar_element.index = armors(a).element_code
 ar_equip.index = armors(a).equip_code
 ar_stat.mod_index = armors(a).stat_mod
 for i as Integer = 1 to 5
  ar_stat.flags(i) = armors(a).stat_bonus(i)
 next
 for i as Integer = 1 to total_races
  ar_race.flags(i) = armors(a).races(i)
 next

 ar_list.Display()
 ar_info.Display()
 ar_element.Display()
 WriteText(FF4Text("3 STATS"), ar_stat.x, ar_stat.y - 1, 14)
 ar_stat.Display()
 ar_race.Display()
 ar_equip.Display()

end sub


sub ArCommit(a as Integer)

 'Stores the boxes in armor a

 armors(a).name = ar_info.name
 item_names.Assign(a + total_weapons + 2, ar_info.name)
 ar_list.ChangeOption(a, ar_info.name)
 armors(a).price_code = ar_info.price
 armors(a).metallic = ar_info.metallic
 armors(a).defense = ar_info.defense
 armors(a).evade = ar_info.evade
 armors(a).magic_defense = ar_info.magic_defense
 armors(a).magic_evade = ar_info.magic_evade
 armors(a).part = ar_info.part
 armors(a).description = ar_info.description
 armors(a).element_code = ar_element.index
 armors(a).equip_code = ar_equip.index
 armors(a).stat_mod = ar_stat.mod_index
 for i as Integer = 1 to 5
  armors(a).stat_bonus(i) = ar_stat.flags(i)
 next
 for i as Integer = 1 to total_races
  armors(a).races(i) = ar_race.flags(i)
 next

end sub


sub ArAct(a as Integer, panel as Integer, row as Integer, k as UInteger)

 select case panel
  case ar_p_info: ar_info.EditField(row)
  case ar_p_elidx: ar_element.EditIndex()
  case ar_p_elgrid: elementgrids(ar_element.index).flags(row) = not elementgrids(ar_element.index).flags(row)
  case ar_p_statmod: ar_stat.EditModIndex()
  case ar_p_stat: ar_stat.flags(row) = not ar_stat.flags(row)
  case ar_p_race: ar_race.flags(row) = not ar_race.flags(row)
  case ar_p_eqidx: ar_equip.EditIndex()
  case ar_p_eqgrid: equipcharts(ar_equip.index + 1).flags(row) = not equipcharts(ar_equip.index + 1).flags(row)
 end select

 ArCommit(a)

end sub


function ArHint(a as Integer, panel as Integer, row as Integer) as String

 select case panel
  case ar_p_info
   select case row
    case 1: return "Enter types the name."
    case 2: return "Enter picks the price."
    case 3: return "Enter types the defense."
    case 4: return "Enter types the evade."
    case 5: return "Enter types the magic defense."
    case 6: return "Enter types the magic evade."
    case 7: return "Enter or Space switches Metallic: metal armor is attracted by Magnet."
    case else: return "Enter picks the description text."
   end select
  case ar_p_elidx: return "Enter types the set number, Left Right step it. Same number, shared set."
  case ar_p_elgrid: return "Enter or Space switches it. All items with this set number share it."
  case ar_p_statmod: return "Enter picks the bonus and penalty, Left Right step it."
  case ar_p_stat: return "Enter or Space switches the stat: green gets the bonus, red the penalty."
  case ar_p_race: return "Enter or Space switches the creature type the armor protects against."
  case ar_p_eqidx: return "Enter types the set number, Left Right step it. Same number, shared set."
 end select

 return "Enter or Space switches a job. All items with this set number share it."

end function


function ArExtra(a as Integer, panel as Integer, row as Integer, k as UInteger) as Boolean

 'Left and Right step a set number (or the stat modifier) in the one line boxes

 dim step_by as Integer

 if k <> LEFT_KEY and k <> RIGHT_KEY then return false
 step_by = iif(k = RIGHT_KEY, 1, -1)

 select case panel
  case ar_p_elidx
   armors(a).element_code = Max(Min(armors(a).element_code + step_by, total_element_grids - 1), 0)
  case ar_p_statmod
   armors(a).stat_mod = Max(Min(armors(a).stat_mod + step_by, 7), 0)
  case ar_p_eqidx
   armors(a).equip_code = Max(Min(armors(a).equip_code + step_by, total_equip_charts - 1), 0)
  case else
   return false
 end select

 return true

end function


sub ArInit()

 ar_list = BlueMenu()
 ar_list.swap_enabled = true
 ar_list.max_rows = screen_height - 3 'the bottom row is the hint line
 for i as Integer = 1 to total_armors
  ar_list.AddOption(armors(i).name)
 next

 ar_info = ArmorInformationMenu(11, 0)
 ar_element = ElementMenu(11, 11)
 ar_stat = StatMenu(48, 2)
 ar_race = RaceMenu(58, 1)
 ar_equip = EquipMenu(11, 25)

 ar_info.main_menu.title = "1 Information"
 ar_element.flag_menu.title = "2 Element and status"
 ar_race.flag_menu.min_width = 12
 ar_race.flag_menu.title = "4 Races"
 ar_equip.flag_menu.title = "5 Equip"

 FmClear()
 FmAddMenu(@ar_info.main_menu, 1)
 FmAddLine(ar_element.x, ar_element.y + 1, 2)
 FmAddMenu(@ar_element.flag_menu, 2)
 FmAddLine(ar_stat.x, ar_stat.y + 8, 3)
 FmAddMenu(@ar_stat.flag_menu, 3)
 FmAddMenu(@ar_race.flag_menu, 4)
 FmAddLine(ar_equip.x, ar_equip.y + 1, 5)
 FmAddMenu(@ar_equip.flag_menu, 5)

 fm_show = @ArShow
 fm_act = @ArAct
 fm_hint = @ArHint
 fm_extra = @ArExtra

end sub


sub EditArmors()

 ArInit()

 do until ar_list.cancelled

  do
   ArShow(ar_list.selected)
  loop until ListInput(ar_list, "armors")

  if not ar_list.cancelled then

   if ar_list.highlighted > 0 then

    swap armors(ar_list.selected), armors(ar_list.highlighted)
    item_names.Exchange(ar_list.selected + total_weapons + 2, ar_list.highlighted + total_weapons + 2)
    ar_list.options.Exchange(ar_list.selected, ar_list.highlighted)
    ar_list.highlighted = 0

   else

    FormFields(@ar_list, "armors")
    line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf

   end if

  end if

 loop

end sub
