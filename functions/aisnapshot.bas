'Copies of the monster AI data. The AI lives in global tables (groups, condition sets, conditions, scripts), not
'in the monster entry, so the monster lists' changed marks, Ctrl-R (revert) and Ctrl-Z (undo) use these:
'
'  AISnap                    a copy of all of the tables
'  ai_original               how they were when the ROM was loaded
'  MonsterAIFingerprint(m)   text for everything of the AIs that monster m uses, compared with the loaded ROM
'                            to tell whether the monster was changed
'  AIRestoreGroup, AIRestoreOrphans   put an AI (and the parts it points at) back from a copy

type AISnap

 gc(1 to total_ai_groups) as String 'the condition sets of each group's pairs
 gs(1 to total_ai_groups) as String 'the scripts of each group's pairs
 sets(1 to total_condition_sets) as String
 conds(1 to total_conditions) as AICondition
 hp(1 to total_condition_hps) as UInteger
 scr(1 to total_scripts) as String 'the actions of each script, two bytes each

end type

dim shared ai_original as AISnap


function AIScriptToText(n as Integer) as String

 'The actions of script n as text, two bytes each (the action and its parameter)

 dim result as String
 dim entry as AIScriptEntry ptr

 for j as Integer = 1 to scripts(n).Length()
  entry = scripts(n).PointerAt(j)
  result += chr(entry->function_call) + chr(entry->parameter)
 next

 return result

end function


sub AIScriptFromText(n as Integer, text as String)

 dim entry as AIScriptEntry ptr

 do while scripts(n).Length() > 0
  scripts(n).Remove(1)
 loop

 for j as Integer = 1 to len(text) step 2
  entry = callocate(SizeOf(AIScriptEntry))
  entry->function_call = asc(mid(text, j, 1))
  entry->parameter = asc(mid(text, j + 1, 1))
  scripts(n).Append(entry)
 next

end sub


sub AITakeSnap(byref s as AISnap)

 for i as Integer = 1 to total_ai_groups
  s.gc(i) = aigroupconditions(i)
  s.gs(i) = aigroupscripts(i)
 next
 for i as Integer = 1 to total_condition_sets
  s.sets(i) = conditionsets(i)
 next
 for i as Integer = 1 to total_conditions
  s.conds(i) = conditions(i)
 next
 for i as Integer = 1 to total_condition_hps
  s.hp(i) = conditionhp(i)
 next
 for i as Integer = 1 to total_scripts
  s.scr(i) = AIScriptToText(i)
 next

end sub


sub AIPutSnap(byref s as AISnap)

 'Puts all of the tables back as the copy has them

 for i as Integer = 1 to total_ai_groups
  aigroupconditions(i) = s.gc(i)
  aigroupscripts(i) = s.gs(i)
 next
 for i as Integer = 1 to total_condition_sets
  conditionsets(i) = s.sets(i)
 next
 for i as Integer = 1 to total_conditions
  conditions(i) = s.conds(i)
 next
 for i as Integer = 1 to total_condition_hps
  conditionhp(i) = s.hp(i)
 next
 for i as Integer = 1 to total_scripts
  AIScriptFromText(i, s.scr(i))
 next

end sub


function AIGroupFingerprint(g as Integer, is_lunar as Boolean) as String

 'Everything that AI group g does: its pairs, and the condition sets, conditions and scripts they use

 dim result as String
 dim set_text as String
 dim set_id as Integer
 dim cond_id as Integer
 dim script_n as Integer

 if g < 1 or g > total_ai_groups then return ""

 result = aigroupconditions(g) + "/" + aigroupscripts(g)
 for j as Integer = 1 to len(aigroupconditions(g))
  set_id = asc(mid(aigroupconditions(g), j, 1))
  if set_id + 1 <= total_condition_sets then
   set_text = conditionsets(set_id + 1)
   result += "|" + set_text
   for q as Integer = 1 to len(set_text)
    cond_id = asc(mid(set_text, q, 1))
    if cond_id < total_conditions then
     result += "," + chr(conditions(cond_id + 1).condition) + chr(conditions(cond_id + 1).xx) + chr(conditions(cond_id + 1).yy) + chr(conditions(cond_id + 1).zz)
     if conditions(cond_id + 1).condition = 1 and conditions(cond_id + 1).zz + 1 <= total_condition_hps then result += str(conditionhp(conditions(cond_id + 1).zz + 1))
    end if
   next
  end if
  script_n = asc(mid(aigroupscripts(g), j, 1)) + 1 + iif(is_lunar, &h100, 0)
  if script_n <= total_scripts then result += ">" + AIScriptToText(script_n)
 next

 return result

end function


function MonsterAIFingerprint(m as Integer) as String

 'The AIs monster m uses (attack, and reaction if it has one), in the bank it uses

 dim result as String

 result = AIGroupFingerprint(monsters(m).attack_sequence_group + 1, monsters(m).lunar)
 if monsters(m).has_reaction then result += "#" + AIGroupFingerprint(monsters(m).reaction_index + 1, monsters(m).lunar)

 return result

end function


sub AIRestoreGroup(byref src as AISnap, g as Integer, is_lunar as Boolean)

 'AI group g, its condition sets, conditions and scripts, as the copy has them

 dim set_id as Integer
 dim cond_id as Integer
 dim script_n as Integer

 if g < 1 or g > total_ai_groups then exit sub

 aigroupconditions(g) = src.gc(g)
 aigroupscripts(g) = src.gs(g)
 for j as Integer = 1 to len(src.gc(g))
  set_id = asc(mid(src.gc(g), j, 1))
  if set_id + 1 <= total_condition_sets then
   conditionsets(set_id + 1) = src.sets(set_id + 1)
   for q as Integer = 1 to len(src.sets(set_id + 1))
    cond_id = asc(mid(src.sets(set_id + 1), q, 1))
    if cond_id < total_conditions then
     conditions(cond_id + 1) = src.conds(cond_id + 1)
     if src.conds(cond_id + 1).condition = 1 and src.conds(cond_id + 1).zz + 1 <= total_condition_hps then conditionhp(src.conds(cond_id + 1).zz + 1) = src.hp(src.conds(cond_id + 1).zz + 1)
    end if
   next
  end if
  script_n = asc(mid(src.gs(g), j, 1)) + 1 + iif(is_lunar, &h100, 0)
  if script_n <= total_scripts then AIScriptFromText(script_n, src.scr(script_n))
 next

end sub


sub AIRestoreOrphans(byref src as AISnap)

 'Condition sets, conditions and scripts that no AI uses any more (a pair that was added and is gone again
 ' leaves them behind) go back to what the copy has, so a reverted AI leaves nothing changed behind

 dim set_used(255) as Boolean
 dim cond_used(255) as Boolean
 dim script_used(255) as Boolean
 dim id as Integer

 for g as Integer = 1 to total_ai_groups
  for j as Integer = 1 to len(aigroupconditions(g))
   set_used(asc(mid(aigroupconditions(g), j, 1))) = true
   script_used(asc(mid(aigroupscripts(g), j, 1))) = true
  next
 next
 for s as Integer = 1 to total_condition_sets
  if set_used(s - 1) then
   for j as Integer = 1 to len(conditionsets(s))
    cond_used(asc(mid(conditionsets(s), j, 1))) = true
   next
  end if
 next

 for s as Integer = 1 to total_condition_sets
  if not set_used(s - 1) then conditionsets(s) = src.sets(s)
 next
 for c as Integer = 1 to total_conditions
  if not cond_used(c - 1) then conditions(c) = src.conds(c)
 next
 for n as Integer = 1 to total_scripts
  id = (n - 1) mod &h100
  if not script_used(id) then AIScriptFromText(n, src.scr(n))
 next

end sub
