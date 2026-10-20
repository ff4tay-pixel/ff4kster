'How many bytes the monster AI data takes when SaveAIs writes it, and how many the ROM has room for.
'The four areas are written one after the other with fixed starting places (see SaveAIs).

const ai_room_groups = &h5D0 '&h76230 to &h767FF
const ai_room_sets = &h100 '&h76800 to &h768FF
const ai_room_scripts = &h900 '&h76B00 to &h773FF
const ai_room_moon = &h400 '&h738C0 to &h73CBF


function AIBytes(area as Integer) as Integer

 'area 1 = AI groups, 2 = condition sets, 3 = regular scripts, 4 = lunar scripts

 dim result as Integer
 dim entry as AIScriptEntry ptr

 select case area
  case 1
   for i as Integer = 1 to total_ai_groups
    result += len(aigroupconditions(i)) * 2
    if right(aigroupscripts(i), 1) <> chr(&hFF) then result += 1
   next
  case 2
   for i as Integer = 1 to total_condition_sets
    result += len(conditionsets(i)) + 1
   next
  case 3, 4
   for i as Integer = iif(area = 3, 1, &h101) to iif(area = 3, &h100, total_scripts)
    for j as Integer = 1 to scripts(i).Length()
     entry = scripts(i).PointerAt(j)
     result += 1
     if ScriptTakesParameter(entry->function_call) then result += 1
    next
    result += 1
   next
 end select

 return result

end function


function AIRoom(area as Integer) as Integer

 select case area
  case 1: return ai_room_groups
  case 2: return ai_room_sets
  case 3: return ai_room_scripts
 end select

 return ai_room_moon

end function
