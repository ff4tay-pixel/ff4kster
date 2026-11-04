function ByteAt(index as UInteger) as UByte
 
 if cc_red_on then
  'reading the settings of a copy of a routine: the bytes of the routine are those of the copy
  if index >= cc_red_entry and index < cc_red_entry + 1024 then
   if cc_red_map(index - cc_red_entry) >= 0 then return asc(mid(ff4rom, cc_red_block + cc_red_map(index - cc_red_entry) + 1, 1))
  end if
 end if

 return asc(mid(ff4rom, index + 1, 1))
 
end function
