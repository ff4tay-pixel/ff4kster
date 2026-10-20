sub SetMoonFlags(index as UInteger)

 for i as Integer = 1 to 8
  for j as Integer = 1 to 3
   'An empty slot (type FF) is not a monster: indexing the monster list with it would write past its end
   if formations(encounters(encounter_tables(index) + 16 + 1, i) + &h100 + 1).monster_type(j) < total_monsters then monsters(formations(encounters(encounter_tables(index) + 16 + 1, i) + &h100 + 1).monster_type(j) + 1).lunar = true
  next
 next

end sub

sub ReadLunarOverrides()

 'Monsters listed in config/lunar.dat ("<monster number> <label>" per line,
 ' # for comments) are always treated as lunar, for monsters the encounter
 ' tables above don't catch (bosses, etc.).

 dim f as Integer = freefile
 dim temp as String
 dim n as Integer

 if open(system_path + "\config\lunar.dat" for input as #f) <> 0 then exit sub

 do until eof(f)
  line input #f, temp
  temp = trim(temp)
  if temp <> "" and left(temp, 1) <> "#" then
   n = val(temp)
   if n >= 1 and n <= total_monsters then monsters(n).lunar = true
  end if
 loop

 close #f

end sub


sub FlagMoonCreatures()

 dim t as Trigger ptr
 dim e as EventCall ptr
 dim c as CallComponent ptr
 dim entry as String

 for i as Integer = 1 to total_monsters
  monsters(i).lunar = false
 next

 for i as Integer = 431 to 433
  if encounter_tables(i) > 0 then SetMoonFlags(i)
 next
 
 for i as Integer = 444 to 468
  if encounter_tables(i) > 0 then SetMoonFlags(i)
 next

 ReadLunarOverrides()
 
 'for i as Integer = 347 to 349
  'for j as Integer = 1 to maps(i).triggers.Length()
   't = maps(i).triggers.PointerAt(j)
   'if not t->warp and not t->treasure then
    'e = eventcalls.PointerAt(t->event)
    'for k as Integer = 1 to e->components.Length()
     'c = e->components.PointerAt(k)
     'for l as Integer = 1 to events(c->event_reference + 1).script.Length()
      'entry = events(c->event_reference + 1).script.ItemAt(l)
      'if left(entry, 1) = chr(&hEC) then
       'for m as Integer = 1 to 3
        'monsters(formations(asc(mid(entry, 2)) + &h100 + 1).monster_type(m) + 1).lunar = true
       'next
      'end if
     'next
    'next
   'end if
  'next
 'next

 'for i as Integer = 444 to 454
  'SetMoonFlags(i)
 'next
 
 'for i as Integer = 456 to 460
  'SetMoonFlags(i)
 'next
 
 'for i as Integer = 462 to 463
  'SetMoonFlags(i)
 'next
 
 'SetMoonFlags(465)
 
 ''--Debug
 'for i as Integer = 1 to total_monsters
  'if monsters(i).lunar then monsters(i).name = FF4Text("-") + monsters(i).name
 'next

end sub
