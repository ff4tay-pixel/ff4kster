const map_data_start = &hB8500
const map_data_end = &hD005F 'first byte after the room for map data; the map editor's Room counter uses the same limit

function MapDataBytes() as Integer

 'How many bytes the map data takes up when it is saved (what SaveMapGrids writes)

 dim total as Integer

 for i as Integer = 1 to total_maps - 1
  if not mapgrids(i).no_data then total += mapgrids(i).BytesUsed()
  if i = 251 then i = 256
 next

 return total

end function


sub SaveMapGrids()

 dim start as UInteger
 dim rle as String
 
 'Don't write anything if the maps don't fit: the extra data would overwrite what follows
 if map_data_start + MapDataBytes() > map_data_end then
  WarningMessage(FF4Text("Map data overflow!"))
  exit sub
 end if
 
 start = map_data_start
 for i as Integer = 1 to total_maps - 1
  'if i < 252 or i > 256 then
   if not mapgrids(i).no_data then
    rle = mapgrids(i).RunLengthEncoding()
    for j as Integer = 1 to len(rle)
     WriteByte(start, asc(mid(rle, j, 1)))
     start += 1
    next
   end if
   if i = 251 then i = 256
   WriteByte(&hB8200 + i * 2, (start - iif(i < &h100, &hB8200, &hC0200)) mod &h100)
   WriteByte(&hB8200 + i * 2 + 1, (start - iif(i < &h100, &hB8200, &hC0200)) \ &h100)
  'end if
 next

end sub
