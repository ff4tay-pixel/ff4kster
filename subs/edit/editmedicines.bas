'Medicines editor. The list of medicines is on the left, every box of the selected one on the screen, and Enter on
'the list moves the cursor into the boxes (see itemforms.bas).
'
'  1 Information   name, price, picture (a spell's) and description
'  2 Effect        what it does, who it targets, power, hit, delay, MP cost and the switches
'  3 Element/status  a set number (shared by everything that uses it) and its flags

const md_p_info = 1
const md_p_effect = 2
const md_p_elidx = 3
const md_p_elgrid = 4

dim shared md_list as BlueMenu
dim shared md_info as MedicineInformationMenu
dim shared md_effect as SpellEffectMenu
dim shared md_element as ElementMenu


sub MdShow(m as Integer)

 'Copies medicine m to the boxes and draws them

 md_info.SetTo(m)
 md_effect.casting_time = medicines(m).casting_time
 md_effect.target = medicines(m).target
 md_effect.power = medicines(m).power
 md_effect.hit = medicines(m).hit
 md_effect.effect = medicines(m).effect
 md_effect.mp_cost = medicines(m).mp_cost
 md_effect.reflectable = medicines(m).reflectable
 md_effect.boss = medicines(m).boss
 md_effect.impact = medicines(m).impact
 md_effect.damage = medicines(m).damage
 md_element.index = medicines(m).element_code

 md_list.Display()
 md_info.Display()
 md_effect.Display()
 md_element.Display()

end sub


sub MdCommit(m as Integer)

 'Stores the boxes in medicine m

 medicines(m).name = md_info.name
 item_names.Assign(m + total_weapons + total_armors + 2, md_info.name)
 md_list.ChangeOption(m, md_info.name)
 medicines(m).price_code = md_info.price
 medicines(m).visual = md_info.visual
 medicines(m).description = md_info.description
 medicines(m).casting_time = md_effect.casting_time
 medicines(m).target = md_effect.target
 medicines(m).power = md_effect.power
 medicines(m).hit = md_effect.hit
 medicines(m).effect = md_effect.effect
 medicines(m).mp_cost = md_effect.mp_cost
 medicines(m).reflectable = md_effect.reflectable
 medicines(m).boss = md_effect.boss
 medicines(m).impact = md_effect.impact
 medicines(m).damage = md_effect.damage
 medicines(m).element_code = md_element.index

end sub


sub MdAct(m as Integer, panel as Integer, row as Integer, k as UInteger)

 select case panel
  case md_p_info: md_info.EditField(row)
  case md_p_effect: md_effect.EditField(row)
  case md_p_elidx: md_element.EditIndex()
  case md_p_elgrid: elementgrids(md_element.index).flags(row) = not elementgrids(md_element.index).flags(row)
 end select

 MdCommit(m)

end sub


function MdHint(m as Integer, panel as Integer, row as Integer) as String

 select case panel
  case md_p_info
   select case row
    case 1: return "Enter types the name."
    case 2: return "Enter picks the price."
    case 3: return "Enter picks the spell whose picture is shown when it is used."
    case else: return "Enter picks the description text."
   end select
  case md_p_effect: return FmEffectHint(row)
  case md_p_elidx: return "Enter types the set number, Left Right step it. Same number, shared set."
 end select

 return "Enter or Space switches it. All items with this set number share it."

end function


function MdExtra(m as Integer, panel as Integer, row as Integer, k as UInteger) as Boolean

 'Left and Right step the set number in the one line box

 if panel <> md_p_elidx then return false
 if k <> LEFT_KEY and k <> RIGHT_KEY then return false

 medicines(m).element_code = Max(Min(medicines(m).element_code + iif(k = RIGHT_KEY, 1, -1), total_element_grids - 1), 0)

 return true

end function


sub MdInit()

 md_list = BlueMenu()
 md_list.max_rows = screen_height - 3 'the bottom row is the hint line
 for i as Integer = 1 to total_medicines
  md_list.AddOption(medicines(i).name)
 next

 md_info = MedicineInformationMenu(11, 0)
 md_effect = SpellEffectMenu(11, 7)
 md_element = ElementMenu(11, 20)

 md_info.main_menu.title = "1 Information"
 md_effect.main_menu.title = "2 Effect"
 md_element.flag_menu.title = "3 Element and status"

 FmClear()
 FmAddMenu(@md_info.main_menu, 1)
 FmAddMenu(@md_effect.main_menu, 2)
 FmAddLine(md_element.x, md_element.y + 1, 3)
 FmAddMenu(@md_element.flag_menu, 3)

 fm_show = @MdShow
 fm_act = @MdAct
 fm_hint = @MdHint
 fm_extra = @MdExtra

end sub


sub EditMedicines()

 MdInit()

 do until md_list.cancelled

  do
   MdShow(md_list.selected)
  loop until ListInput(md_list, "medicines")

  if not md_list.cancelled then
   FormFields(@md_list, "medicines")
   line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf
  end if

 loop

end sub
