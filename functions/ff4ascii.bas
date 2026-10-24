function FF4ToAscii(s as String) as String

 'Converts an FF4 string to readable ASCII for CSV export. Characters with no
 ' unambiguous ASCII equivalent are written as {HH} (hex FF4 code), which
 ' AsciiToFF4 reads back losslessly.

 dim result as String
 dim code as UByte
 dim found as Integer
 dim matches as Integer

 for i as Integer = 1 to len(s)
  code = asc(mid(s, i, 1))
  found = 0
  matches = 0
  for j as Integer = 32 to 126
   if asc(mid(asc2ff4, j, 1)) = code then
    found = j
    matches += 1
   end if
  next
  if matches = 1 and found <> asc("{") then
   result += chr(found)
  else
   result += "{" + hex(code, 2) + "}"
  end if
 next

 return result

end function


function AsciiToFF4(s as String) as String

 'Inverse of FF4ToAscii: plain characters go through the font table and {HH}
 ' escapes become raw FF4 codes.

 dim result as String
 dim i as Integer = 1

 do while i <= len(s)
  if mid(s, i, 1) = "{" and i + 3 <= len(s) then
   if mid(s, i + 3, 1) = "}" then
    result += chr(val("&h" + mid(s, i + 1, 2)))
    i += 4
    continue do
   end if
  end if
  result += mid(asc2ff4, asc(mid(s, i, 1)), 1)
  i += 1
 loop

 return result

end function


function FF4Name(byval s as String) as String

 'ASCII form of an FF4 name with the trailing padding spaces removed.

 dim space_code as String = FF4Text(" ")

 do while len(s) > 0
  if right(s, 1) <> space_code then exit do
  s = left(s, len(s) - 1)
 loop

 return FF4ToAscii(s)

end function


function FF4Trim(byval s as String) as String

 'The FF4 string without its trailing padding spaces, still in FF4 codes.

 dim space_code as String = FF4Text(" ")

 do while len(s) > 0
  if right(s, 1) <> space_code then exit do
  s = left(s, len(s) - 1)
 loop

 return s

end function


function PadFF4Name(ascii_name as String, name_width as Integer) as String

 'Converts typed/imported ASCII to an FF4 name of exactly `name_width` characters.

 dim result as String = left(AsciiToFF4(ascii_name), name_width)

 return result + string(name_width - len(result), asc(FF4Text(" ")))

end function
