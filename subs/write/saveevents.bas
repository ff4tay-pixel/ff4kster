sub SaveEvents()

 dim offset as UInteger
 dim total_space as UInteger
 
 for i as Integer = 1 to total_events
  total_space += events(i).Length()
 next
 
 if total_space > mb_limit(mb_events) - mb_text(mb_events) then 
 
  WarningMessage(FF4Text("Events overflow!"))
  
 else
 
  offset = mb_text(mb_events)
  
  for i as Integer = 1 to total_events
   WriteByte(&h90202 + (i - 1) * 2, (offset - mb_text(mb_events)) mod &h100)
   WriteByte(&h90202 + (i - 1) * 2 + 1, (offset - mb_text(mb_events)) \ &h100)
   events(i).WriteToROM(i, offset)
   offset += events(i).Length()
  next
  
 end if

end sub
