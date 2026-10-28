'Where SaveLevelups puts each character's level up data, and how many bytes it takes.
'A character starting at level L stores one 5 byte row per level from L to 69, then 8 bytes after level 70.
'The game reads a block through a 16 bit pointer in bank &h0F, so the blocks need not sit together: the
'main area starts at &h7B728 (the original data ends at &h7C5C8, free bytes follow up to &h7C7FF) and two
'more runs of unused FF bytes in the same bank hold the blocks that no longer fit there.

const levelup_areas = 3
const levelup_start = &h7B728
const levelup_room = (&h7C800 - &h7B728) + (&h7D400 - &h7D140) + (&h7B000 - &h7AD92)

dim shared levelup_place(total_characters) as Integer


function LevelupBlockBytes(ch as Integer) as Integer

 'A character's block is only stored when some actor points to it (actors(n).level_link).
 dim used as Boolean = false
 for i as Integer = 1 to total_actors
  if actors(i).level_link = ch then used = true
 next
 if not used then return 0

 if characters(ch).level < 70 then return (70 - characters(ch).level) * 5 + 8
 return 8

end function


function LevelupBytes() as Integer

 dim total as Integer

 for i as Integer = 1 to total_characters
  total += LevelupBlockBytes(i)
 next

 return total

end function


'Fills levelup_place with the ROM address of each character's block. False when the blocks do not fit.
function LevelupLayout() as Boolean

 dim order(total_characters) as Integer
 dim area_next(levelup_areas) as Integer
 dim area_end(levelup_areas) as Integer
 dim placed as Boolean
 dim swap_value as Integer

 for pass as Integer = 1 to 2
  area_next(1) = levelup_start
  area_end(1) = &h7C800
  area_next(2) = &h7D140
  area_end(2) = &h7D400
  area_next(3) = &h7AD92
  area_end(3) = &h7B000
  for i as Integer = 1 to total_characters
   order(i) = i
  next
  if pass = 2 then
   'largest blocks first
   for i as Integer = 1 to total_characters - 1
    for j as Integer = i + 1 to total_characters
     if LevelupBlockBytes(order(j)) > LevelupBlockBytes(order(i)) then
      swap_value = order(i)
      order(i) = order(j)
      order(j) = swap_value
     end if
    next
   next
  end if
  placed = true
  for i as Integer = 1 to total_characters
   dim found as Boolean = false
   if LevelupBlockBytes(order(i)) = 0 then found = true
   for a as Integer = 1 to levelup_areas
    if found then exit for
    if area_next(a) + LevelupBlockBytes(order(i)) <= area_end(a) then
     levelup_place(order(i)) = area_next(a)
     area_next(a) += LevelupBlockBytes(order(i))
     found = true
     exit for
    end if
   next
   if not found then placed = false
  next
  if placed then return true
 next

 return false

end function
