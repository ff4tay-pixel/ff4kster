sub SaveTriggers()

 dim t as Trigger ptr
 dim start as UInteger
 dim address as UInteger
 dim finish as UInteger
 dim temp as UInteger
 dim total_overworld_triggers as UInteger
 
 'The game has 256 chest switches for the maps up to 256 and 256 more for the ones after
 dim chests as Integer
 for i as Integer = 1 to total_maps - 1
  if i = 257 then chests = 0
  for j as Integer = 1 to maps(i).triggers.Length()
   t = maps(i).triggers.PointerAt(j)
   if t->treasure then chests += 1
  next
  if chests > 256 then
   WarningMessage(FF4Text("Too many chests! 256 per half of the maps."))
   exit for
  end if
 next

 start = &hA8200
 address = mb_text(mb_triggers)
 total_overworld_triggers = 0
 
 for i as Integer = 1 to total_maps
  if address >= mb_limit(mb_triggers) then
   WarningMessage(FF4Text("Triggers Overflow!"))
   exit for
  else
   temp = address - mb_text(mb_triggers)
   WriteByte(start, temp mod &h100)
   WriteByte(start + 1, temp \ &h100)
   start += 2
   if i = 252 then
    for j as Integer = 1 to maps(i).triggers.Length()
     t = maps(i).triggers.PointerAt(j)
     t->WriteToROM(&hD0066 + (j - 1) * 5)
    next
    total_overworld_triggers += maps(i).triggers.Length()
   elseif i = 253 then
    for j as Integer = 1 to maps(i).triggers.Length()
     t = maps(i).triggers.PointerAt(j)
     t->WriteToROM(&hD0066 + maps(252).triggers.Length() * 5 + (j - 1) * 5)
    next
    WriteByte(&hD0062, (total_overworld_triggers * 5) mod &h100)
    WriteByte(&hD0063, (total_overworld_triggers * 5) \ &h100)
    total_overworld_triggers += maps(i).triggers.Length()
   elseif i = 254 then
    for j as Integer = &hD01DD to &hD01FF
     WriteByte(j, 0)
    next
    for j as Integer = 1 to maps(i).triggers.Length()
     t = maps(i).triggers.PointerAt(j)
     t->WriteToROM(&hD0066 + maps(252).triggers.Length() * 5 + maps(253).triggers.Length() * 5 + (j - 1) * 5)
    next
    WriteByte(&hD0064, (total_overworld_triggers * 5) mod &h100)
    WriteByte(&hD0065, (total_overworld_triggers * 5) \ &h100)
    total_overworld_triggers += maps(i).triggers.Length()
   else
    'The game takes the first few triggers of a map as its treasure chests (as many as the map's chest numbers
    ' say), so the chests are written first, whatever place they have in the editor's list.
    for pass as Integer = 1 to 2
     for j as Integer = 1 to maps(i).triggers.Length()
      t = maps(i).triggers.PointerAt(j)
      if (pass = 1) = t->treasure then
       t->WriteToROM(address)
       address += 5
      end if
     next
    next
   end if
  end if
 next

 if address > mb_limit(mb_triggers) then WarningMessage(FF4Text("Triggers Overflow!"))

end sub
