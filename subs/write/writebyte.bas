sub WriteByte(index as UInteger, b as UByte)
 
 if cc_red_on then
  'writing the settings of a copy of a routine: only the bytes that are in the copy are written, the rest is not touched
  if index >= cc_red_entry and index < cc_red_entry + 1024 then
   if cc_red_map(index - cc_red_entry) >= 0 then mid(ff4rom, cc_red_block + cc_red_map(index - cc_red_entry) + 1, 1) = chr(b)
  end if
  return
 end if

 mid(ff4rom, index + 1, 1) = chr(b)
 
end sub
