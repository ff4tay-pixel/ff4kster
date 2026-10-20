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


function ExportCsv(kind as String) as Integer

 'Writes one table to CSV and returns the number of rows written (0 = failure).

 dim f as Integer = freefile
 dim path as String = ExportPath(kind + ".csv")
 dim rows as Integer
 dim m as Integer

 if open(path for output as #f) <> 0 then return 0

 select case kind

  case "spells"
   print #f, "id,name,casting_time,target,power,hit,boss,effect,damage,element_code,impact,mp_cost,reflectable,colors,sprites,visual1,visual2,sound"
   for i as Integer = 1 to total_spells
    with spells(i)
     print #f, str(i) + "," + CsvQuote(FF4Name(.name)) + "," + str(.casting_time) + "," + str(.target) + "," + str(.power) + "," + str(.hit) + "," + _
      str(BoolInt(.boss)) + "," + str(.effect) + "," + str(BoolInt(.damage)) + "," + str(.element_code) + "," + str(BoolInt(.impact)) + "," + _
      str(.mp_cost) + "," + str(BoolInt(.reflectable)) + "," + str(.colors) + "," + str(.sprites) + "," + str(.visual1) + "," + str(.visual2) + "," + str(.sound)
    end with
    rows += 1
   next

  case "weapons"
   print #f, "id,name,price_code,attack,hit,element_code,equip_code,casts,spell_power,spell_gfx,visual_color,visual_sprite,visual_swing,visual_slash,stat_amount,property_mask,stat_up_mask,races_mask"
   for i as Integer = 1 to total_weapons
    with weapons(i)
     print #f, str(i) + "," + CsvQuote(FF4Name(.name)) + "," + str(.price_code) + "," + str(.attack) + "," + str(.hit) + "," + str(.element_code) + "," + _
      str(.equip_code) + "," + str(.casts) + "," + str(.spell_power) + "," + str(.spell_gfx) + "," + str(.visual_color) + "," + str(.visual_sprite) + "," + _
      str(.visual_swing) + "," + str(.visual_slash) + "," + str(.stat_amount);
     m = 0
     for j as Integer = 1 to 9
      if .property_flag(j) then m += 2 ^ (j - 1)
     next
     print #f, "," + str(m);
     m = 0
     for j as Integer = 1 to 5
      if .stat_up(j) then m += 2 ^ (j - 1)
     next
     print #f, "," + str(m);
     m = 0
     for j as Integer = 1 to 8
      if .races(j) then m += 2 ^ (j - 1)
     next
     print #f, "," + str(m)
    end with
    rows += 1
   next

  case "armors"
   print #f, "id,name,price_code,metallic,magic_evade,defense,evade,magic_defense,element_code,equip_code,stat_mod,stat_bonus_mask,races_mask"
   for i as Integer = 1 to total_armors
    with armors(i)
     print #f, str(i) + "," + CsvQuote(FF4Name(.name)) + "," + str(.price_code) + "," + str(BoolInt(.metallic)) + "," + str(.magic_evade) + "," + _
      str(.defense) + "," + str(.evade) + "," + str(.magic_defense) + "," + str(.element_code) + "," + str(.equip_code) + "," + str(.stat_mod);
     m = 0
     for j as Integer = 1 to 5
      if .stat_bonus(j) then m += 2 ^ (j - 1)
     next
     print #f, "," + str(m);
     m = 0
     for j as Integer = 1 to total_races
      if .races(j) then m += 2 ^ (j - 1)
     next
     print #f, "," + str(m)
    end with
    rows += 1
   next

  case "medicines"
   print #f, "id,name,price_code,casting_time,target,power,boss,hit,impact,damage,effect,element_code,mp_cost,reflectable,visual"
   for i as Integer = 1 to total_medicines
    with medicines(i)
     print #f, str(i) + "," + CsvQuote(FF4Name(.name)) + "," + str(.price_code) + "," + str(.casting_time) + "," + str(.target) + "," + str(.power) + "," + _
      str(BoolInt(.boss)) + "," + str(.hit) + "," + str(BoolInt(.impact)) + "," + str(BoolInt(.damage)) + "," + str(.effect) + "," + str(.element_code) + "," + _
      str(.mp_cost) + "," + str(BoolInt(.reflectable)) + "," + str(.visual)
    end with
    rows += 1
   next

  case "tools"
   print #f, "id,name,price_code"
   for i as Integer = 1 to total_tools
    print #f, str(i) + "," + CsvQuote(FF4Name(tools(i).name)) + "," + str(tools(i).price_code)
    rows += 1
   next

  case "monsters"
   print #f, "id,name,boss,level,hp,gil,xp,physical_attack_index,physical_defense_index,magical_defense_index,speed_index,drop_rate,drop_index," + _
    "attack_sequence_group,lunar,has_attack_element,has_resistances,has_weaknesses,has_spell_power,has_race,has_reaction," + _
    "attack_element_mask,resistances_mask,weaknesses_mask,spell_power,races_mask,reaction_index,size,pal,gfx_ptr1,gfx_ptr2"
   for i as Integer = 1 to total_monsters
    with monsters(i)
     print #f, str(i) + "," + CsvQuote(FF4Name(.name)) + "," + str(BoolInt(.boss)) + "," + str(.level) + "," + str(.hp) + "," + str(.gil) + "," + str(.xp) + "," + _
      str(.physical_attack_index) + "," + str(.physical_defense_index) + "," + str(.magical_defense_index) + "," + str(.speed_index) + "," + _
      str(.drop_rate) + "," + str(.drop_index) + "," + str(.attack_sequence_group) + "," + str(BoolInt(.lunar)) + "," + _
      str(BoolInt(.has_attack_element)) + "," + str(BoolInt(.has_resistances)) + "," + str(BoolInt(.has_weaknesses)) + "," + _
      str(BoolInt(.has_spell_power)) + "," + str(BoolInt(.has_race)) + "," + str(BoolInt(.has_reaction)) + "," + _
      str(GridMask(.attack_element, 24)) + "," + str(GridMask(.resistances, 24)) + "," + str(GridMask(.weaknesses, 8)) + "," + _
      str(.spell_power) + "," + str(GridMask(.races, 8)) + "," + str(.reaction_index) + "," + str(.size) + "," + str(.pal) + "," + _
      str(.gfx_ptr1) + "," + str(.gfx_ptr2)
    end with
    rows += 1
   next

 end select

 close #f

 return rows

end function
