'Spells editor. The list of spells is on the left, every box of the selected spell on the screen with the animation
'preview on the right, and Enter on the list moves the cursor into the boxes (see itemforms.bas).
'
'  1 Name         the name (6 letters for player spells, 8 for the others)
'  2 Information  effect, target, power, hit, delay, MP cost and the switches
'  3 Animation    sound, palette, sprites, sequence and effect; the preview plays them
'  4 Element/status  a set number (shared by everything that uses it) and its flags

const sp_p_name = 1
const sp_p_effect = 2
const sp_p_visual = 3
const sp_p_elidx = 4
const sp_p_elgrid = 5

dim shared sp_list as BlueMenu
dim shared sp_effect as SpellEffectMenu
dim shared sp_visual as SpellVisualMenu
dim shared sp_element as ElementMenu


sub SpShow(s as Integer)

 'Copies spell s to the boxes and draws them

 sp_effect.SetTo(s)
 sp_visual.SetTo(s)
 sp_element.index = spells(s).element_code

 sp_list.Display()
 BlueBox(10, 0, 14, 1)
 WriteText(FF4Text("1 Name: ") + spells(s).name, 11, 1)
 sp_effect.Display()
 sp_element.Display()
 sp_visual.Display()

end sub


sub SpCommit(s as Integer)

 'Stores the boxes in spell s (the name is stored where it is typed)

 spells(s).casting_time = sp_effect.casting_time
 spells(s).target = sp_effect.target
 spells(s).power = sp_effect.power
 spells(s).hit = sp_effect.hit
 spells(s).effect = sp_effect.effect
 spells(s).mp_cost = sp_effect.mp_cost
 spells(s).reflectable = sp_effect.reflectable
 spells(s).boss = sp_effect.boss
 spells(s).impact = sp_effect.impact
 spells(s).damage = sp_effect.damage
 spells(s).sound = sp_visual.sound - 1
 spells(s).colors = sp_visual.colors - 1
 spells(s).sprites = sp_visual.sprites
 spells(s).visual1 = sp_visual.visual1
 spells(s).visual2 = sp_visual.visual2
 spells(s).element_code = sp_element.index

end sub


sub SpAct(s as Integer, panel as Integer, row as Integer, k as UInteger)

 dim name_input as BlueTextInput
 dim name_width as UByte

 select case panel

  case sp_p_name
   name_input = BlueTextInput(16, 0)
   name_input.starting_text = spells(s).name
   if s <= total_player_spells then name_width = 6 else name_width = 8
   name_input.text_width = name_width
   name_input.UserType()
   spells(s).name = Pad(name_input.text, name_width,, FF4Text(" "))
   sp_list.ChangeOption(s, spells(s).name)

  case sp_p_effect: sp_effect.EditField(row)
  case sp_p_visual: sp_visual.EditField(row)
  case sp_p_elidx: sp_element.EditIndex()
  case sp_p_elgrid: elementgrids(sp_element.index).flags(row) = not elementgrids(sp_element.index).flags(row)

 end select

 SpCommit(s)

end sub


function SpHint(s as Integer, panel as Integer, row as Integer) as String

 select case panel
  case sp_p_name: return "Enter types the name."
  case sp_p_effect: return FmEffectHint(row)
  case sp_p_visual
   select case row
    case 1: return "Enter picks the sound effect."
    case 2: return "Enter picks the palette of the animation."
    case 3: return "Enter types the graphics number of the animation."
    case 4: return "Enter picks the sequence, the script of sprites the preview plays."
    case else: return "Enter picks the effect, a routine in the game code the preview cannot play."
   end select
  case sp_p_elidx: return "Enter types the set number, Left Right step it. Same number, shared set."
 end select

 return "Enter or Space switches it. All items with this set number share it."

end function


function SpExtra(s as Integer, panel as Integer, row as Integer, k as UInteger) as Boolean

 'Left and Right step the set number in the one line box

 if panel <> sp_p_elidx then return false
 if k <> LEFT_KEY and k <> RIGHT_KEY then return false

 spells(s).element_code = Max(Min(spells(s).element_code + iif(k = RIGHT_KEY, 1, -1), total_element_grids - 1), 0)

 return true

end function


sub SpInit()

 sp_list = BlueMenu()
 sp_list.swap_enabled = true
 sp_list.max_rows = screen_height - 3 'the bottom row is the hint line
 for i as Integer = 1 to total_spells
  sp_list.AddOption(spells(i).name)
 next

 sp_effect = SpellEffectMenu(10, 3)
 sp_visual = SpellVisualMenu(10, 15)
 sp_element = ElementMenu(10, 22)

 sp_effect.main_menu.title = "2 Information"
 sp_visual.main_menu.title = "3 Animation"
 sp_element.flag_menu.title = "4 Element and status"

 FmClear()
 FmAddLine(10, 1, 1)
 FmAddMenu(@sp_effect.main_menu, 2)
 FmAddMenu(@sp_visual.main_menu, 3)
 FmAddLine(sp_element.x, sp_element.y + 1, 4)
 FmAddMenu(@sp_element.flag_menu, 4)

 fm_show = @SpShow
 fm_act = @SpAct
 fm_hint = @SpHint
 fm_extra = @SpExtra

end sub


sub EditSpells()

 SpInit()
 idle_hook = @SpellAnimTick

 do

  do
   SpShow(sp_list.selected)
  loop until ListInput(sp_list, "spells")

  if not sp_list.cancelled then

   if sp_list.highlighted > 0 then

    swap spells(sp_list.selected), spells(sp_list.highlighted)
    sp_list.options.Exchange(sp_list.selected, sp_list.highlighted)
    sp_list.highlighted = 0

   else

    FormFields(@sp_list, "spells")
    line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf

   end if

  end if

 loop until sp_list.cancelled

 idle_hook = 0
 SpellAnimClose()

end sub
