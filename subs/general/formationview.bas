'Battle formation preview for the formation editor.
'
'A formation names up to three monster types with a quantity (0-3) each, and an arrangement
'(0-255). The arrangement picks one row of the position table (MonsterPos, 0e/9000): eight
'positions, each a byte with the x position in the high nibble and the y position in the low
'nibble. The game fills the slots in order: every monster of the first type, then the second,
'then the third. If two of the types are the same monster their quantities are added together.
'Slot k of the formation is placed at position k of the arrangement.
'
'A monster's top left corner on the 256x224 battle screen is (x * 8 + 16, y * 8) pixels. Bosses
'ignore the arrangement: their position is part of their special size entry, where (as the game's
'code uses it) the high nibble is x and the low nibble is y. In the SpecialSize type those are
'called mystery_amount and x.
'
'ff4rom always carries a 0x200 byte header, so the ROM offset below includes it.

const fv_monster_pos = &h71200 'MonsterPos (0e/9000)
const fv_box_x = 16
const fv_box_y = 22
const fv_field_w = 256
const fv_field_h = 224
const fv_legend_x = 50


sub FormationPreview(index as Integer)

 dim t(2) as Integer
 dim c(2) as Integer
 dim slot_type(7) as Integer
 dim slot_group(7) as Integer
 dim slot_x(7) as Integer
 dim slot_y(7) as Integer
 dim slots as Integer
 dim battlefield as Any ptr
 dim sprite as Any ptr
 dim raw_sheet as Boolean
 dim position_byte as Integer
 dim m as Integer
 dim ss as Integer
 dim tiles_wide as Integer
 dim tiles_high as Integer
 dim line_text as String
 dim origin_x as Integer
 dim origin_y as Integer

 'The monster types and how many of each (duplicates are merged, as the game does)
 for i as Integer = 0 to 2
  t(i) = formations(index).monster_type(i + 1)
  if t(i) >= total_monsters then t(i) = &hFF
  c(i) = formations(index).monster_qty(i + 1)
 next
 for i as Integer = 0 to 1
  if t(i) <> &hFF then
   for j as Integer = i + 1 to 2
    if t(i) = t(j) then
     c(i) += c(j)
     c(j) = 0
     t(j) = &hFF
    end if
   next
  end if
 next
 for i as Integer = 0 to 2
  if t(i) <> &hFF then
   for n as Integer = 1 to c(i)
    if slots < 8 then
     slot_type(slots) = t(i)
     slot_group(slots) = i
     slots += 1
    end if
   next
  end if
 next

 'Where each slot is
 for k as Integer = 0 to slots - 1
  position_byte = ByteAt(fv_monster_pos + formations(index).arrangement * 8 + k)
  slot_x(k) = position_byte shr 4
  slot_y(k) = position_byte and 15
  m = slot_type(k) + 1
  if monsters(m).size >= &h80 then
   ss = (monsters(m).size and &h3F) + 1
   slot_x(k) = special_sizes(ss).mystery_amount
   slot_y(k) = special_sizes(ss).x
  end if
 next

 'The battlefield: a grid every 16 pixels, then the monsters in slot order
 battlefield = ImageCreate(fv_field_w, fv_field_h, RGB(8, 8, 24))
 for g as Integer = 16 to fv_field_w - 1 step 16
  line battlefield, (g, 0)-(g, fv_field_h - 1), RGB(20, 20, 44)
 next
 for g as Integer = 16 to fv_field_h - 1 step 16
  line battlefield, (0, g)-(fv_field_w - 1, g), RGB(20, 20, 44)
 next

 for k as Integer = 0 to slots - 1
  m = slot_type(k) + 1
  origin_x = slot_x(k) * 8 + 16
  origin_y = slot_y(k) * 8
  sprite = MonsterSpriteImage(monsters(m).gfx_ptr1 + monsters(m).gfx_ptr2 * &h100, monsters(m).size, monsters(m).pal, raw_sheet)
  if sprite <> 0 then
   put battlefield, (origin_x, origin_y), sprite, trans
   ImageDestroy(sprite)
  else
   tiles_wide = 2
   tiles_high = 3
   if monsters(m).size < &h40 then MonsterSizeTiles(monsters(m).size, tiles_wide, tiles_high)
   line battlefield, (origin_x, origin_y)-(origin_x + tiles_wide * 8 - 1, origin_y + tiles_high * 8 - 1), RGB(255, 0, 0), b
  end if
 next

 BlueBox(fv_box_x, fv_box_y, fv_field_w \ 8, fv_field_h \ 8)
 WriteText(FF4Text(" Battle formation "), fv_box_x + 1, fv_box_y, 14)
 put ((fv_box_x + 1) * 8, (fv_box_y + 1) * 8), battlefield, pset
 ImageDestroy(battlefield)

 'Slot numbers on the monsters' top left corners
 for k as Integer = 0 to slots - 1
  origin_x = slot_x(k) + 2
  origin_y = slot_y(k)
  if origin_x < fv_field_w \ 8 and origin_y < fv_field_h \ 8 then WriteText(FF4Text(str(k + 1)), fv_box_x + 1 + origin_x, fv_box_y + 1 + origin_y, 14)
 next

 'The list of slots beside it
 BlueBox(fv_legend_x, fv_box_y, 28, 10)
 WriteText(FF4Text(" Monsters "), fv_legend_x + 1, fv_box_y, 14)
 for k as Integer = 0 to 7
  if k < slots then
   m = slot_type(k) + 1
   line_text = FF4Text(str(k + 1) + " ") + monsters(m).name + FF4Text("  x " + Pad(str(slot_x(k)), 2, true) + "  y " + Pad(str(slot_y(k)), 2, true))
   if formations(index).egg(slot_group(k) + 1) then line_text += FF4Text(" egg") else line_text += FF4Text("    ")
  else
   line_text = FF4Text(space(26))
  end if
  WriteText(line_text, fv_legend_x + 1, fv_box_y + 1 + k, 15)
 next
 WriteText(FF4Text(Pad("Arrangement " + str(formations(index).arrangement), 26)), fv_legend_x + 1, fv_box_y + 9, 7)
 WriteText(FF4Text(Pad("Grid squares are 16 pixels", 26)), fv_legend_x + 1, fv_box_y + 10, 7)

end sub
