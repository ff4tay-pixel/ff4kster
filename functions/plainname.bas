function PlainName(s as String) as String

 'A name without the {hh} codes FF4Name leaves for characters that have no letter (item icons)

 dim result as String = s
 dim open_pos as Integer = instr(result, "{")

 do while open_pos > 0
  if mid(result, open_pos + 3, 1) = "}" then
   result = left(result, open_pos - 1) + mid(result, open_pos + 4)
  else
   result = left(result, open_pos - 1) + mid(result, open_pos + 1)
  end if
  open_pos = instr(result, "{")
 loop

 return trim(result)

end function
