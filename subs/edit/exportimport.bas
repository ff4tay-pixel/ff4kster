sub ExportImportTables(importing as Boolean)

 'Menu for choosing which tables to export to / import from CSV.

 dim table_menu as BlueMenu
 dim kinds(1 to 8) as String = {"spells", "weapons", "armors", "medicines", "tools", "monsters", "shops", "formations"}
 dim count as Integer
 dim errors as Integer
 dim first_error as String
 dim report as String
 dim total_errors as Integer

 table_menu.x = 24
 table_menu.y = 10
 table_menu.AddOption(FF4Text("All tables"))
 for i as Integer = 1 to 8
  table_menu.AddOption(FF4Text(kinds(i)))
 next

 table_menu.UserSelect()
 if table_menu.cancelled then exit sub

 for i as Integer = 1 to 8
  if table_menu.selected = 1 or table_menu.selected = i + 1 then
   if importing then
    count = ImportCsv(kinds(i), errors, first_error)
    if count < 0 then
     report += "|" + kinds(i) + ": exports/" + kinds(i) + ".csv not found"
    else
     report += "|" + kinds(i) + ": " + str(count) + " rows imported"
     if errors > 0 then report += ", " + str(errors) + " skipped: " + first_error
     if count > 0 then modified = true
    end if
   else
    count = ExportCsv(kinds(i))
    if count = 0 then
     report += "|" + kinds(i) + ": could not write file"
    else
     report += "|" + kinds(i) + ": " + str(count) + " rows to exports/" + kinds(i) + ".csv"
    end if
   end if
  end if
 next

 if importing then
  InfoBox("Import finished" + report + "||Changes are in memory, use Save ROM to keep them.||Press any key")
 else
  InfoBox("Export finished" + report + "||Press any key")
 end if

end sub
