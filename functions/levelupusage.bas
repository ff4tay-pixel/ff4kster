'How many bytes the level up data takes when SaveLevelups writes it, and how many the ROM has room for.
'A character starting at level L stores one 5 byte row per level from L to 69, then 8 bytes after level 70.
'The data starts at &h7B728; the original ends at &h7C5C8 and the free bytes after it run to &h7C7FF.

const levelup_room = &h7C800 - &h7B728


function LevelupBytes() as Integer

 dim total as Integer

 for i as Integer = 1 to total_characters
  if characters(i).level < 70 then total += (70 - characters(i).level) * 5
  total += 8
 next

 return total

end function
