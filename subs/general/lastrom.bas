'Remembers the ROM used last time (in lastrom.cfg next to the editor).

function AskLastROM() as String

 dim f as Integer = freefile
 dim path as String
 dim k as Integer

 if open(system_path + "\lastrom.cfg" for input as #f) <> 0 then return ""
 if not eof(f) then line input #f, path
 close #f

 path = trim(path)
 if path = "" then return ""
 if dir(path) = "" then return ""

 print "Last ROM: "; path
 print
 print "Enter = open it    Esc = choose another ROM"
 do
  k = getkey
  if k = 13 then return path
 loop until k = 27
 cls

 return ""

end function


sub RememberROM(path as String)

 dim f as Integer = freefile
 dim full as String = path

 if instr(full, ":") = 0 then full = curdir + "\" + path

 if open(system_path + "\lastrom.cfg" for output as #f) = 0 then
  print #f, full
  close #f
 end if

end sub
