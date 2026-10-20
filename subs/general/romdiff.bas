'Compare the ROM as it would be saved right now against the ROM as it would
' have been saved with no edits (baseline_rom, built at startup), so the report
' shows only your edits. Saving also re-lays-out some data (events, text, ...),
' so the difference from the original file is reported as a separate count.

type DiffRegion
 start as UInteger
 length as UInteger
end type

function DiffLabel(offset as UInteger) as String

 select case offset
  case &h71A00 to &h7210F: return "Monster names"
  case &h72200 to &h723BF: return "Monster gil"
  case &h723C0 to &h7257F: return "Monster XP"
  case &h728A0 to &h72A5F: return "Monster stat pointers"
  case &h72A60 to &h73FFF: return "Monster stats"
  case &h74742 to &h74995: return "Encounter tables"
  case &h74996 to &h74CFF: return "Encounters"
  case &h78200 to &h7855F: return "Weapon names"
  case &h78560 to &h7882F: return "Armor names"
  case &h78830 to &h789CD: return "Medicine names"
  case &h789CE to &h78B05: return "Tool names"
  case &h78B06 to &h790FD: return "Spell names"
  case &h79270 to &h792FF: return "Weapon spell power"
  case &h79300 to &h795FF: return "Weapon stats"
  case &h79600 to &h7987F: return "Armor stats"
  case &h79880 to &h79993: return "Medicine stats"
  case &h799A6 to &h79E1F: return "Spell stats"
  case &h7A010 to &h7A18F: return "Weapon visuals"
  case &h7A250 to &h7A54F: return "Spell visuals"
  case &h7A550 to &h7A64F: return "Spell sounds"
  case &h7A650 to &h7A74F: return "Item prices"
  case &h7A910 to &h7A96F: return "Character names"
  case &h7B000 to &h7B1FF: return "Item descriptions"
  case &h7CC00 to &h7CF7F: return "Monster graphics"
 end select

 return "(other)"

end function


sub BuildBaselineROM()

 'Called once after loading: records the ROM image Save ROM would produce
 ' from the unedited data, then restores the working image.

 ApplyDataToROM()
 baseline_rom = ff4rom
 ff4rom = original_rom
 warning = false

end sub


function BuildDiffReport() as String

 dim saved_warning as Boolean = warning
 dim saved_rom as String = ff4rom
 dim saved_applied as String
 static regions(0 to 99999) as DiffRegion
 dim n as Integer
 dim changed as UInteger
 dim header as Integer = &h200
 dim last_changed as Integer = -100
 dim f as Integer = freefile
 dim report as String
 dim label as String
 dim labels(0 to 63) as String
 dim label_bytes(0 to 63) as UInteger
 dim nlabels as Integer
 dim found as Boolean

 'Build the image that Save ROM would write, then restore the working copy.
 ApplyDataToROM()
 saved_applied = ff4rom

 for i as Integer = header to len(baseline_rom) - 1
  if asc(mid(ff4rom, i + 1, 1)) <> asc(mid(baseline_rom, i + 1, 1)) then
   changed += 1
   if i - last_changed > 4 or n = 0 then
    if n < 99999 then
     regions(n).start = i
     regions(n).length = 1
     n += 1
    end if
   else
    regions(n - 1).length = i - regions(n - 1).start + 1
   end if
   last_changed = i
   label = DiffLabel(i)
   found = false
   for j as Integer = 0 to nlabels - 1
    if labels(j) = label then
     label_bytes(j) += 1
     found = true
     exit for
    end if
   next
   if not found and nlabels < 64 then
    labels(nlabels) = label
    label_bytes(nlabels) = 1
    nlabels += 1
   end if
  end if
 next

 'Full report to disk
 report = ExportPath("rom_diff.txt")
 if open(report for output as #f) = 0 then
  print #f, "ROM diff: edits made this session (vs. what Save ROM wrote for the unedited data)"
  print #f, "Offsets are file offsets as used by the editor (add header size -0x200 for headerless ROM offsets)."
  print #f, str(changed) + " bytes changed in " + str(n) + " regions"
  print #f,
  print #f, "Summary by table:"
  for j as Integer = 0 to nlabels - 1
   print #f, "  " + labels(j) + ": " + str(label_bytes(j)) + " bytes"
  next
  print #f,
  print #f, "Regions (file offset / headerless offset, length, table):"
  for j as Integer = 0 to n - 1
   print #f, hex(regions(j).start, 6) + " / " + hex(regions(j).start - header, 6) + "  " + str(regions(j).length) + " bytes  " + DiffLabel(regions(j).start)
   'show old -> new bytes for short regions
   if regions(j).length <= 16 then
    dim old_bytes as String
    dim new_bytes as String
    old_bytes = ""
    new_bytes = ""
    for b as Integer = 0 to regions(j).length - 1
     old_bytes += hex(asc(mid(baseline_rom, regions(j).start + b + 1, 1)), 2) + " "
     new_bytes += hex(asc(mid(ff4rom, regions(j).start + b + 1, 1)), 2) + " "
    next
    print #f, "    " + old_bytes + "-> " + new_bytes
   end if
  next
  close #f
 end if

 'Restore the working ROM image and warning state.
 ff4rom = saved_rom
 warning = saved_warning

 dim summary as String
 dim vs_file as UInteger
 for i as Integer = header to len(original_rom) - 1
  if asc(mid(saved_applied, i + 1, 1)) <> asc(mid(original_rom, i + 1, 1)) then vs_file += 1
 next
 if changed = 0 then
  summary = "No edits since the ROM was loaded."
 else
  summary = str(changed) + " bytes changed in " + str(n) + " regions:|"
  for j as Integer = 0 to Min(nlabels - 1, 30)
   summary += "|" + labels(j) + ": " + str(label_bytes(j))
  next
  summary += "||Full report: exports/rom_diff.txt"
 end if
 summary += "||Saving would change " + str(vs_file) + " bytes vs. the ROM file as loaded"
 summary += "|This includes data the editor re-lays-out on each save."

 return summary

end function


sub CompareWithOriginal()

 InfoBox(BuildDiffReport() + "||Press any key")

end sub
