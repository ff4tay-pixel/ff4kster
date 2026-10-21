'Weapons editor. The list of weapons is on the left and every box of the selected weapon is on the screen at once;
'Enter on the list moves the cursor into the boxes (see itemforms.bas). The boxes, with the key that jumps to
'them:
'
'  1 Information   name, price, attack, hit and description
'  2 Element/status  a set number (shared by everything that uses it) and its flags
'  3 Stats         the bonus and penalty pair and the stats it applies to
'  4 Races         the creature types the weapon is strong against
'  5 Properties    the eight flags of the weapon (named from the disassembly)
'  6 Equip         a set number (shared) and the jobs that can equip it
'  7 Visuals       palette, sprite, swing and slash, with a picture of the sprite
'  8 Casts         the spell the weapon casts, its picture and power

const wp_p_info = 1
const wp_p_elidx = 2
const wp_p_elgrid = 3
const wp_p_statmod = 4
const wp_p_stat = 5
const wp_p_race = 6
const wp_p_props = 7
const wp_p_eqidx = 8
const wp_p_eqgrid = 9
const wp_p_anim = 10
const wp_p_casts = 11

dim shared wp_list as BlueMenu
dim shared wp_info as WeaponInformationMenu
dim shared wp_element as ElementMenu
dim shared wp_stat as StatMenu
dim shared wp_race as RaceMenu
dim shared wp_props as WeaponPropertiesMenu
dim shared wp_equip as EquipMenu
dim shared wp_anim as WeaponAnimationMenu
dim shared wp_casts as CastsMenu


sub WpShow(w as Integer)

 'Copies weapon w to the boxes and draws them

 wp_info.SetTo(w)
 wp_anim.SetTo(w)
 wp_casts.SetTo(w)
 wp_element.index = weapons(w).element_code
 wp_equip.index = weapons(w).equip_code
 wp_stat.mod_index = weapons(w).stat_amount
 for i as Integer = 1 to 5
  wp_stat.flags(i) = weapons(w).stat_up(i)
 next
 for i as Integer = 1 to 8
  wp_race.flags(i) = weapons(w).races(i)
  wp_props.flags(i) = weapons(w).property_flag(i)
 next

 wp_list.Display()
 wp_info.Display()
 wp_element.Display()
 WriteText(FF4Text("3 STATS"), wp_stat.x, wp_stat.y - 1, 14)
 wp_stat.Display()
 wp_race.Display()
 wp_props.Display()
 wp_equip.Display()
 wp_anim.Display()
 wp_casts.Display()

end sub


sub WpCommit(w as Integer)

 'Stores the boxes in weapon w

 weapons(w).name = wp_info.name
 item_names.Assign(w + 1, wp_info.name)
 wp_list.ChangeOption(w, weapons(w).name)
 weapons(w).price_code = wp_info.price
 weapons(w).attack = wp_info.attack
 weapons(w).hit = wp_info.hit
 weapons(w).description = wp_info.description
 weapons(w).element_code = wp_element.index
 weapons(w).stat_amount = wp_stat.mod_index
 for i as Integer = 1 to 5
  weapons(w).stat_up(i) = wp_stat.flags(i)
 next
 for i as Integer = 1 to total_races
  weapons(w).races(i) = wp_race.flags(i)
 next
 for i as Integer = 1 to total_weapon_properties
  weapons(w).property_flag(i) = wp_props.flags(i)
 next
 weapons(w).equip_code = wp_equip.index
 weapons(w).visual_color = wp_anim.colors - 1
 weapons(w).visual_sprite = wp_anim.sprite - 1
 weapons(w).visual_swing = wp_anim.swing - 1
 weapons(w).visual_slash = wp_anim.slash - 1
 weapons(w).casts = wp_casts.casts
 weapons(w).spell_gfx = wp_casts.visual
 weapons(w).spell_power = wp_casts.power

end sub


sub WpAct(w as Integer, panel as Integer, row as Integer, k as UInteger)

 select case panel
  case wp_p_info: wp_info.EditField(row)
  case wp_p_elidx: wp_element.EditIndex()
  case wp_p_elgrid: elementgrids(wp_element.index).flags(row) = not elementgrids(wp_element.index).flags(row)
  case wp_p_statmod: wp_stat.EditModIndex()
  case wp_p_stat: wp_stat.flags(row) = not wp_stat.flags(row)
  case wp_p_race: wp_race.flags(row) = not wp_race.flags(row)
  case wp_p_props: wp_props.flags(row) = not wp_props.flags(row)
  case wp_p_eqidx: wp_equip.EditIndex()
  case wp_p_eqgrid: equipcharts(wp_equip.index + 1).flags(row) = not equipcharts(wp_equip.index + 1).flags(row)
  case wp_p_anim: wp_anim.EditField(row)
  case wp_p_casts: wp_casts.EditField(row)
 end select

 WpCommit(w)

end sub


function WpPropertyHint(row as Integer) as String

 'What the eight flags are. The names come from the disassembly (everything8215/ff4); of them the
 ' effect of "No Back Row Penalty" and "Magnetic" was read in the game code.

 select case row
  case 1: return "No Critical: the weapon never scores critical hits (named in the disassembly)."
  case 3: return "Hammer: named in the disassembly, its effect is not known."
  case 5: return "Lit Arrow: named in the disassembly, its effect is not known."
  case 6: return "No Back Row Penalty: not halved from the back row, like bows and spears."
  case 7: return "Can Throw: the weapon can be thrown (name from the disassembly)."
  case 8: return "Magnetic: counts as metal, so the Magnet effect attracts the wearer."
 end select

 return "Unknown flag: the disassembly does not name it. Switch it on to find out."

end function


function WpHint(w as Integer, panel as Integer, row as Integer) as string

 select case panel
  case wp_p_info
   select case row
    case 1: return "Enter types the name."
    case 2: return "Enter picks the price."
    case 3: return "Enter types the attack power."
    case 4: return "Enter types the hit percentage."
    case else: return "Enter picks the description text."
   end select
  case wp_p_elidx: return "Enter types the set number, Left Right step it. Same number, shared set."
  case wp_p_elgrid: return "Enter or Space switches it. All items with this set number share it."
  case wp_p_statmod: return "Enter picks the bonus and penalty, Left Right step it."
  case wp_p_stat: return "Enter or Space switches the stat: green gets the bonus, red the penalty."
  case wp_p_race: return "Enter or Space switches the creature type the weapon is strong against."
  case wp_p_props: return WpPropertyHint(row)
  case wp_p_eqidx: return "Enter types the set number, Left Right step it. Same number, shared set."
  case wp_p_eqgrid: return "Enter or Space switches a job. All items with this set number share it."
  case wp_p_anim: return "Enter picks the palette, sprite, swing or slash. The picture shows the sprite."
  case else
   select case row
    case 1: return "Enter picks the spell the weapon casts when it is used as an item."
    case 2: return "Enter picks the spell whose picture is shown when it casts."
    case else: return "Enter types the power (how many hits) of the weapon spell."
   end select
 end select

end function


function WpExtra(w as Integer, panel as Integer, row as Integer, k as UInteger) as Boolean

 'Left and Right step a set number (or the stat modifier) in the one line boxes

 dim step_by as Integer

 if k <> LEFT_KEY and k <> RIGHT_KEY then return false
 step_by = iif(k = RIGHT_KEY, 1, -1)

 select case panel
  case wp_p_elidx
   weapons(w).element_code = Max(Min(weapons(w).element_code + step_by, total_element_grids - 1), 0)
  case wp_p_statmod
   weapons(w).stat_amount = Max(Min(weapons(w).stat_amount + step_by, 7), 0)
  case wp_p_eqidx
   weapons(w).equip_code = Max(Min(weapons(w).equip_code + step_by, total_equip_charts - 1), 0)
  case else
   return false
 end select

 return true

end function


sub WpInit()

 wp_list = BlueMenu()
 wp_list.swap_enabled = true
 wp_list.max_rows = screen_height - 3 'the bottom row is the hint line
 for i as Integer = 1 to total_weapons
  wp_list.AddOption(weapons(i).name)
 next

 'Layout: the list, then the boxes in three columns
 wp_info = WeaponInformationMenu(11, 0)
 wp_element = ElementMenu(11, 8)
 wp_stat = StatMenu(54, 2)
 wp_race = RaceMenu(64, 1)
 wp_props = WeaponPropertiesMenu(54, 12)
 wp_equip = EquipMenu(11, 23)
 wp_anim = WeaponAnimationMenu(40, 23)
 wp_casts = CastsMenu(40, 30)

 wp_info.main_menu.title = "1 Information"
 wp_element.flag_menu.title = "2 Element and status"
 wp_race.flag_menu.min_width = 12
 wp_race.flag_menu.title = "4 Races"
 wp_props.flag_menu.title = "5 Properties"
 wp_equip.flag_menu.title = "6 Equip"
 wp_anim.main_menu.title = "7 Visuals"
 wp_casts.main_menu.title = "8 Casts"

 FmClear()
 FmAddMenu(@wp_info.main_menu, 1)
 FmAddLine(wp_element.x, wp_element.y + 1, 2)
 FmAddMenu(@wp_element.flag_menu, 2)
 FmAddLine(wp_stat.x, wp_stat.y + 8, 3)
 FmAddMenu(@wp_stat.flag_menu, 3)
 FmAddMenu(@wp_race.flag_menu, 4)
 FmAddMenu(@wp_props.flag_menu, 5)
 FmAddLine(wp_equip.x, wp_equip.y + 1, 6)
 FmAddMenu(@wp_equip.flag_menu, 6)
 FmAddMenu(@wp_anim.main_menu, 7)
 FmAddMenu(@wp_casts.main_menu, 8)

 fm_show = @WpShow
 fm_act = @WpAct
 fm_hint = @WpHint
 fm_extra = @WpExtra

end sub


sub EditWeapons()

 WpInit()

 do until wp_list.cancelled

  do
   WpShow(wp_list.selected)
  loop until ListInput(wp_list, "weapons")

  if not wp_list.cancelled then

   if wp_list.highlighted > 0 then

    swap weapons(wp_list.highlighted), weapons(wp_list.selected)
    wp_list.options.Exchange(wp_list.highlighted, wp_list.selected)
    wp_list.highlighted = 0

   else

    FormFields(@wp_list, "weapons")
    line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf

   end if

  end if

 loop

end sub
