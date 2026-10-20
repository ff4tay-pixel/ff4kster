'Export editor data to CSV files in <editor folder>\exports\.

function ExportPath(file_name as String) as String

 mkdir system_path + "\exports"

 return system_path + "\exports\" + file_name

end function


function GridMask(g as ElementGrid, bits as Integer) as Integer

 dim result as Integer

 for i as Integer = 1 to bits
  if g.flags(i) then result += 2 ^ (i - 1)
 next

 return result

end function


sub SetGridMask(g as ElementGrid, bits as Integer, mask as Integer)

 for i as Integer = 1 to bits
  g.flags(i) = ((mask shr (i - 1)) and 1) <> 0
 next

end sub


function CsvTableSize(kind as String) as Integer

 select case kind
  case "spells": return total_spells
  case "weapons": return total_weapons
  case "armors": return total_armors
  case "medicines": return total_medicines
  case "tools": return total_tools
  case "monsters": return total_monsters
  case "shops": return total_shops
  case "formations": return total_formations
  case "jobs": return total_jobs
  case "commands": return total_commands
  case "actors": return total_actors
 end select

 return 0

end function


function CsvHeader(kind as String) as String

 select case kind
  case "spells"
   return "id,name,casting_time,target,power,hit,boss,effect,damage,element_code,impact,mp_cost,reflectable,colors,sprites,visual1,visual2,sound"
  case "weapons"
   return "id,name,price_code,attack,hit,element_code,equip_code,casts,spell_power,spell_gfx,visual_color,visual_sprite,visual_swing,visual_slash,stat_amount,property_mask,stat_up_mask,races_mask"
  case "armors"
   return "id,name,price_code,metallic,magic_evade,defense,evade,magic_defense,element_code,equip_code,stat_mod,stat_bonus_mask,races_mask"
  case "medicines"
   return "id,name,price_code,casting_time,target,power,boss,hit,impact,damage,effect,element_code,mp_cost,reflectable,visual"
  case "tools"
   return "id,name,price_code"
  case "shops"
   return "id,item1,item2,item3,item4,item5,item6,item7,item8"
  case "formations"
   return "id,mystery_flag1,mystery_flag2,mystery_flag3,back_attack,boss_death,egg1,egg2,egg3,monster_type1,monster_type2,monster_type3," + _
    "mystery_qty,monster_qty1,monster_qty2,monster_qty3,arrangement,no_flee,no_gameover,battle_music,character_battle,auto_battle," + _
    "floating,transparent,mystery_byte,rewards"
  case "monsters"
   return "id,name,boss,level,hp,gil,xp,physical_attack_index,physical_defense_index,magical_defense_index,speed_index,drop_rate,drop_index," + _
    "attack_sequence_group,lunar,has_attack_element,has_resistances,has_weaknesses,has_spell_power,has_race,has_reaction," + _
    "attack_element_mask,resistances_mask,weaknesses_mask,spell_power,races_mask,reaction_index,size,pal,gfx_ptr1,gfx_ptr2"
 end select

 return ""

end function


function CsvRow(kind as String, i as Integer) as String

 'One CSV line (without the line ending) for entry i of the given table.

 dim result as String
 dim m as Integer

 select case kind

  case "spells"
   with spells(i)
    result = str(i) + "," + CsvQuote(FF4Name(.name)) + "," + str(.casting_time) + "," + str(.target) + "," + str(.power) + "," + str(.hit) + "," + _
     str(BoolInt(.boss)) + "," + str(.effect) + "," + str(BoolInt(.damage)) + "," + str(.element_code) + "," + str(BoolInt(.impact)) + "," + _
     str(.mp_cost) + "," + str(BoolInt(.reflectable)) + "," + str(.colors) + "," + str(.sprites) + "," + str(.visual1) + "," + str(.visual2) + "," + str(.sound)
   end with

  case "weapons"
   with weapons(i)
    result = str(i) + "," + CsvQuote(FF4Name(.name)) + "," + str(.price_code) + "," + str(.attack) + "," + str(.hit) + "," + str(.element_code) + "," + _
     str(.equip_code) + "," + str(.casts) + "," + str(.spell_power) + "," + str(.spell_gfx) + "," + str(.visual_color) + "," + str(.visual_sprite) + "," + _
     str(.visual_swing) + "," + str(.visual_slash) + "," + str(.stat_amount)
    m = 0
    for j as Integer = 1 to 9
     if .property_flag(j) then m += 2 ^ (j - 1)
    next
    result += "," + str(m)
    m = 0
    for j as Integer = 1 to 5
     if .stat_up(j) then m += 2 ^ (j - 1)
    next
    result += "," + str(m)
    m = 0
    for j as Integer = 1 to 8
     if .races(j) then m += 2 ^ (j - 1)
    next
    result += "," + str(m)
   end with

  case "armors"
   with armors(i)
    result = str(i) + "," + CsvQuote(FF4Name(.name)) + "," + str(.price_code) + "," + str(BoolInt(.metallic)) + "," + str(.magic_evade) + "," + _
     str(.defense) + "," + str(.evade) + "," + str(.magic_defense) + "," + str(.element_code) + "," + str(.equip_code) + "," + str(.stat_mod)
    m = 0
    for j as Integer = 1 to 5
     if .stat_bonus(j) then m += 2 ^ (j - 1)
    next
    result += "," + str(m)
    m = 0
    for j as Integer = 1 to total_races
     if .races(j) then m += 2 ^ (j - 1)
    next
    result += "," + str(m)
   end with

  case "medicines"
   with medicines(i)
    result = str(i) + "," + CsvQuote(FF4Name(.name)) + "," + str(.price_code) + "," + str(.casting_time) + "," + str(.target) + "," + str(.power) + "," + _
     str(BoolInt(.boss)) + "," + str(.hit) + "," + str(BoolInt(.impact)) + "," + str(BoolInt(.damage)) + "," + str(.effect) + "," + str(.element_code) + "," + _
     str(.mp_cost) + "," + str(BoolInt(.reflectable)) + "," + str(.visual)
   end with

  case "tools"
   result = str(i) + "," + CsvQuote(FF4Name(tools(i).name)) + "," + str(tools(i).price_code)

  case "shops"
   result = str(i)
   for j as Integer = 1 to 8
    result += "," + str(shops(i).wares(j))
   next

  case "formations"
   with formations(i)
    result = str(i) + "," + str(BoolInt(.mystery_flag1)) + "," + str(BoolInt(.mystery_flag2)) + "," + str(BoolInt(.mystery_flag3)) + "," + _
     str(BoolInt(.back_attack)) + "," + str(BoolInt(.boss_death)) + "," + str(BoolInt(.egg(1))) + "," + str(BoolInt(.egg(2))) + "," + str(BoolInt(.egg(3))) + "," + _
     str(.monster_type(1)) + "," + str(.monster_type(2)) + "," + str(.monster_type(3)) + "," + str(.mystery_qty) + "," + _
     str(.monster_qty(1)) + "," + str(.monster_qty(2)) + "," + str(.monster_qty(3)) + "," + str(.arrangement) + "," + _
     str(BoolInt(.no_flee)) + "," + str(BoolInt(.no_gameover)) + "," + str(.battle_music) + "," + str(BoolInt(.character_battle)) + "," + _
     str(BoolInt(.auto_battle)) + "," + str(BoolInt(.floating)) + "," + str(BoolInt(.transparent)) + "," + str(.mystery_byte) + "," + str(BoolInt(.rewards))
   end with

  case "commands"
   with menucommands(i)
    result = str(i) + "," + CsvQuote(FF4Name(.name)) + "," + str(.target) + "," + str(.target_byte) + "," + str(.delay) + "," + _
     str(.disabling_persistent) + "," + str(.disabling_temporary) + "," + str(.charging_stance) + "," + str(.action_stance) + "," + _
     str(.action_stance2) + "," + str(.action_stance3) + "," + str(.item_consumed) + "," + str(.item_effect) + "," + str(.item_visual) + "," + _
     str(.regen_amount) + "," + str(BoolInt(.regen_freeze)) + "," + str(.disable_actor) + "," + str(.cover_actor) + "," + str(BoolInt(.cover_by_job))
    for j as Integer = 0 to 8
     result += "," + str(.spell(j)) + "," + str(.success(j)) + "," + str(.misc_bytes(j))
    next
    for j as Integer = 0 to 5
     result += "," + str(.message(j))
    next
   end with

  case "actors"
   with actors(i)
    result = str(i) + "," + str(.name_index) + "," + str(BoolInt(.load_initial)) + "," + str(BoolInt(.store_shadow)) + "," + str(.load_slot) + "," + _
     str(.store_slot) + "," + str(.level_link) + "," + str(.right_ammo) + "," + str(.left_ammo)
    for j as Integer = 0 to 5
     result += "," + str(.menu_command(j)) + "," + str(.starting_gear(j))
    next
   end with

  case "jobs"
   with jobs(i)
    result = str(i) + "," + CsvQuote(FF4Name(.name)) + "," + str(.white) + "," + str(.black) + "," + str(.summon) + "," + _
     str(.menu_white) + "," + str(.menu_black) + "," + str(.menu_summon)
   end with

  case "monsters"
   with monsters(i)
    result = str(i) + "," + CsvQuote(FF4Name(.name)) + "," + str(BoolInt(.boss)) + "," + str(.level) + "," + str(.hp) + "," + str(.gil) + "," + str(.xp) + "," + _
     str(.physical_attack_index) + "," + str(.physical_defense_index) + "," + str(.magical_defense_index) + "," + str(.speed_index) + "," + _
     str(.drop_rate) + "," + str(.drop_index) + "," + str(.attack_sequence_group) + "," + str(BoolInt(.lunar)) + "," + _
     str(BoolInt(.has_attack_element)) + "," + str(BoolInt(.has_resistances)) + "," + str(BoolInt(.has_weaknesses)) + "," + _
     str(BoolInt(.has_spell_power)) + "," + str(BoolInt(.has_race)) + "," + str(BoolInt(.has_reaction)) + "," + _
     str(GridMask(.attack_element, 24)) + "," + str(GridMask(.resistances, 24)) + "," + str(GridMask(.weaknesses, 8)) + "," + _
     str(.spell_power) + "," + str(GridMask(.races, 8)) + "," + str(.reaction_index) + "," + str(.size) + "," + str(.pal) + "," + _
     str(.gfx_ptr1) + "," + str(.gfx_ptr2)
   end with

 end select

 return result

end function


function ExportCsv(kind as String) as Integer

 'Writes one table to CSV and returns the number of rows written (0 = failure).

 dim f as Integer = freefile
 dim rows as Integer

 if open(ExportPath(kind + ".csv") for output as #f) <> 0 then return 0

 print #f, CsvHeader(kind)
 for i as Integer = 1 to CsvTableSize(kind)
  print #f, CsvRow(kind, i)
  rows += 1
 next

 close #f

 return rows

end function
