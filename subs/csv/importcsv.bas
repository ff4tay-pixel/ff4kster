'Import editor data from CSV files produced by ExportCsv (or edited by hand or
' in a spreadsheet). Only the columns present in the file are applied, so a
' file may contain just "id,attack". Changes go into the in-memory objects;
' nothing reaches the ROM until Save ROM.

sub ImportRow(kind as String, id as Integer)

 dim m as Integer

 select case kind

  case "spells"
   with spells(id)
    if CsvHas("name") then .name = PadFF4Name(CsvStr("name", ""), iif(id <= total_player_spells, 6, 8))
    .casting_time = CsvVal("casting_time", .casting_time, 0, &h1F)
    .target = CsvVal("target", .target, 0, 7)
    .power = CsvVal("power", .power)
    .hit = CsvVal("hit", .hit, 0, &h7F)
    .boss = CsvBool("boss", .boss)
    .effect = CsvVal("effect", .effect, 0, &h7F)
    .damage = CsvBool("damage", .damage)
    .element_code = CsvVal("element_code", .element_code, 0, &h7F)
    .impact = CsvBool("impact", .impact)
    .mp_cost = CsvVal("mp_cost", .mp_cost, 0, &h7F)
    .reflectable = CsvBool("reflectable", .reflectable)
    .colors = CsvVal("colors", .colors)
    .sprites = CsvVal("sprites", .sprites)
    .visual1 = CsvVal("visual1", .visual1)
    .visual2 = CsvVal("visual2", .visual2)
    .sound = CsvVal("sound", .sound)
   end with

  case "weapons"
   with weapons(id)
    if CsvHas("name") then
     .name = PadFF4Name(CsvStr("name", ""), 9)
     item_names.Assign(id + 1, .name)
    end if
    .price_code = CsvVal("price_code", .price_code)
    .attack = CsvVal("attack", .attack)
    .hit = CsvVal("hit", .hit, 0, &h7F)
    .element_code = CsvVal("element_code", .element_code)
    .equip_code = CsvVal("equip_code", .equip_code, 0, &h1F)
    .casts = CsvVal("casts", .casts)
    .spell_power = CsvVal("spell_power", .spell_power)
    .spell_gfx = CsvVal("spell_gfx", .spell_gfx)
    .visual_color = CsvVal("visual_color", .visual_color)
    .visual_sprite = CsvVal("visual_sprite", .visual_sprite)
    .visual_swing = CsvVal("visual_swing", .visual_swing)
    .visual_slash = CsvVal("visual_slash", .visual_slash)
    .stat_amount = CsvVal("stat_amount", .stat_amount, 0, 7)
    if CsvHas("property_mask") then
     m = CsvVal("property_mask", 0, 0, &h1FF)
     for j as Integer = 1 to 9
      .property_flag(j) = ((m shr (j - 1)) and 1) <> 0
     next
    end if
    if CsvHas("stat_up_mask") then
     m = CsvVal("stat_up_mask", 0, 0, &h1F)
     for j as Integer = 1 to 5
      .stat_up(j) = ((m shr (j - 1)) and 1) <> 0
     next
    end if
    if CsvHas("races_mask") then
     m = CsvVal("races_mask", 0, 0, &hFF)
     for j as Integer = 1 to 8
      .races(j) = ((m shr (j - 1)) and 1) <> 0
     next
    end if
   end with

  case "armors"
   with armors(id)
    if CsvHas("name") then
     .name = PadFF4Name(CsvStr("name", ""), 9)
     item_names.Assign(id + total_weapons + 2, .name)
    end if
    .price_code = CsvVal("price_code", .price_code)
    .metallic = CsvBool("metallic", .metallic)
    .magic_evade = CsvVal("magic_evade", .magic_evade, 0, &h7F)
    .defense = CsvVal("defense", .defense)
    .evade = CsvVal("evade", .evade)
    .magic_defense = CsvVal("magic_defense", .magic_defense)
    .element_code = CsvVal("element_code", .element_code, 0, &h3F)
    .equip_code = CsvVal("equip_code", .equip_code, 0, &h1F)
    .stat_mod = CsvVal("stat_mod", .stat_mod, 0, 7)
    if CsvHas("stat_bonus_mask") then
     m = CsvVal("stat_bonus_mask", 0, 0, &h1F)
     for j as Integer = 1 to 5
      .stat_bonus(j) = ((m shr (j - 1)) and 1) <> 0
     next
    end if
    if CsvHas("races_mask") then
     m = CsvVal("races_mask", 0, 0, &hFF)
     for j as Integer = 1 to total_races
      .races(j) = ((m shr (j - 1)) and 1) <> 0
     next
    end if
   end with

  case "medicines"
   with medicines(id)
    if CsvHas("name") then
     .name = PadFF4Name(CsvStr("name", ""), 9)
     item_names.Assign(id + total_weapons + total_armors + 2, .name)
    end if
    .price_code = CsvVal("price_code", .price_code)
    .casting_time = CsvVal("casting_time", .casting_time, 0, &h1F)
    .target = CsvVal("target", .target, 0, 7)
    .power = CsvVal("power", .power)
    .boss = CsvBool("boss", .boss)
    .hit = CsvVal("hit", .hit, 0, &h7F)
    .impact = CsvBool("impact", .impact)
    .damage = CsvBool("damage", .damage)
    .effect = CsvVal("effect", .effect, 0, &h7F)
    .element_code = CsvVal("element_code", .element_code, 0, &h7F)
    .mp_cost = CsvVal("mp_cost", .mp_cost, 0, &h7F)
    .reflectable = CsvBool("reflectable", .reflectable)
    .visual = CsvVal("visual", .visual)
   end with

  case "tools"
   with tools(id)
    if CsvHas("name") then
     .name = PadFF4Name(CsvStr("name", ""), 9)
     item_names.Assign(id + total_weapons + total_armors + total_medicines + 2, .name)
    end if
    .price_code = CsvVal("price_code", .price_code)
   end with

  case "monsters"
   with monsters(id)
    if CsvHas("name") then .name = PadFF4Name(CsvStr("name", ""), 8)
    .boss = CsvBool("boss", .boss)
    .level = CsvVal("level", .level, 0, &h7F)
    .hp = CsvVal("hp", .hp, 0, 65535)
    .gil = CsvVal("gil", .gil, 0, 65535)
    .xp = CsvVal("xp", .xp, 0, 65535)
    .physical_attack_index = CsvVal("physical_attack_index", .physical_attack_index)
    .physical_defense_index = CsvVal("physical_defense_index", .physical_defense_index)
    .magical_defense_index = CsvVal("magical_defense_index", .magical_defense_index)
    .speed_index = CsvVal("speed_index", .speed_index)
    .drop_rate = CsvVal("drop_rate", .drop_rate, 0, 3)
    .drop_index = CsvVal("drop_index", .drop_index, 0, &h3F)
    .attack_sequence_group = CsvVal("attack_sequence_group", .attack_sequence_group)
    .lunar = CsvBool("lunar", .lunar)
    .has_attack_element = CsvBool("has_attack_element", .has_attack_element)
    .has_resistances = CsvBool("has_resistances", .has_resistances)
    .has_weaknesses = CsvBool("has_weaknesses", .has_weaknesses)
    .has_spell_power = CsvBool("has_spell_power", .has_spell_power)
    .has_race = CsvBool("has_race", .has_race)
    .has_reaction = CsvBool("has_reaction", .has_reaction)
    if CsvHas("attack_element_mask") then SetGridMask(.attack_element, 24, CsvVal("attack_element_mask", 0, 0, &hFFFFFF))
    if CsvHas("resistances_mask") then SetGridMask(.resistances, 24, CsvVal("resistances_mask", 0, 0, &hFFFFFF))
    if CsvHas("weaknesses_mask") then SetGridMask(.weaknesses, 8, CsvVal("weaknesses_mask", 0, 0, &hFF))
    .spell_power = CsvVal("spell_power", .spell_power)
    if CsvHas("races_mask") then SetGridMask(.races, 8, CsvVal("races_mask", 0, 0, &hFF))
    .reaction_index = CsvVal("reaction_index", .reaction_index)
    .size = CsvVal("size", .size)
    .pal = CsvVal("pal", .pal)
    .gfx_ptr1 = CsvVal("gfx_ptr1", .gfx_ptr1)
    .gfx_ptr2 = CsvVal("gfx_ptr2", .gfx_ptr2)
   end with

 end select

end sub


function ImportCsv(kind as String, byref errors as Integer, byref first_error as String) as Integer

 'Applies a CSV file to the in-memory objects. Returns the number of rows
 ' applied, or -1 if the file could not be opened.

 dim f as Integer = freefile
 dim line_text as String
 dim rows as Integer
 dim id as Integer
 dim line_no as Integer

 errors = 0
 first_error = ""
 if open(ExportPath(kind + ".csv") for input as #f) <> 0 then return -1

 if not eof(f) then
  line input #f, line_text
  CsvParse(line_text, csv_cols(), csv_ncols)
  for i as Integer = 0 to csv_ncols - 1
   csv_cols(i) = lcase(trim(csv_cols(i)))
  next
  line_no = 1
 end if

 if CsvColumn("id") < 0 then
  close #f
  errors = 1
  first_error = "No id column"
  return 0
 end if

 do until eof(f)
  line input #f, line_text
  line_no += 1
  if trim(line_text) = "" then continue do
  CsvParse(line_text, csv_cells(), csv_ncells)
  id = CsvVal("id", 0, 0, 100000)
  if id < 1 or id > CsvTableSize(kind) then
   errors += 1
   if first_error = "" then first_error = "Line " + str(line_no) + ": bad id"
  else
   ImportRow(kind, id)
   rows += 1
  end if
 loop

 close #f

 return rows

end function
