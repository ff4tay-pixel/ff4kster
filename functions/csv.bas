'Minimal CSV support for the export/import tools.

dim shared csv_cols() as String
dim shared csv_ncols as Integer
dim shared csv_cells() as String
dim shared csv_ncells as Integer

function CsvQuote(s as String) as String

 dim result as String

 if instr(s, ",") > 0 or instr(s, chr(34)) > 0 then
  for i as Integer = 1 to len(s)
   if mid(s, i, 1) = chr(34) then result += chr(34)
   result += mid(s, i, 1)
  next
  return chr(34) + result + chr(34)
 end if

 return s

end function


sub CsvParse(line_text as String, cells() as String, byref n as Integer)

 'Splits one CSV line into cells(0 to n - 1), honoring double quotes.

 dim current as String
 dim quoted as Boolean
 dim c as String
 dim i as Integer = 1

 n = 0
 redim cells(0 to 63)
 do
  if i > len(line_text) then
   if n > ubound(cells) then redim preserve cells(0 to n + 63)
   cells(n) = current
   n += 1
   exit do
  end if
  c = mid(line_text, i, 1)
  if quoted then
   if c = chr(34) then
    if mid(line_text, i + 1, 1) = chr(34) then
     current += chr(34)
     i += 1
    else
     quoted = false
    end if
   else
    current += c
   end if
  elseif c = chr(34) then
   quoted = true
  elseif c = "," then
   if n > ubound(cells) then redim preserve cells(0 to n + 63)
   cells(n) = current
   n += 1
   current = ""
  else
   current += c
  end if
  i += 1
 loop

end sub


function CsvColumn(column_name as String) as Integer

 for i as Integer = 0 to csv_ncols - 1
  if csv_cols(i) = column_name then return i
 next

 return -1

end function


function CsvHas(column_name as String) as Boolean

 dim c as Integer = CsvColumn(column_name)

 if c < 0 then return false
 if c >= csv_ncells then return false

 return trim(csv_cells(c)) <> ""

end function


function CsvStr(column_name as String, current as String) as String

 'Raw cell text (not trimmed, since names may start with a space).

 if CsvHas(column_name) then return csv_cells(CsvColumn(column_name))

 return current

end function


function CsvVal(column_name as String, current as Integer, lo as Integer = 0, hi as Integer = 255) as Integer

 'Returns the numeric value of the named column in the current row, or
 ' `current` if the column is absent/blank. Accepts decimal, &hFF and 0xFF.

 dim s as String
 dim v as Integer

 if not CsvHas(column_name) then return current

 s = lcase(trim(csv_cells(CsvColumn(column_name))))
 if left(s, 2) = "0x" then s = "&h" + mid(s, 3)
 v = clng(val(s))
 if v < lo then v = lo
 if v > hi then v = hi

 return v

end function


function CsvBool(column_name as String, current as Boolean) as Boolean

 dim s as String

 if not CsvHas(column_name) then return current

 s = lcase(trim(csv_cells(CsvColumn(column_name))))
 if s = "true" or s = "yes" or s = "y" then return true
 if s = "false" or s = "no" or s = "n" then return false

 return CsvVal(column_name, iif(current, 1, 0), 0, 1) <> 0

end function


function BoolInt(b as Boolean) as Integer

 if b then return 1

 return 0

end function
