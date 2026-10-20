#include once "common/list.bas"
#include once "common/ui/menu.bas"
#include once "common/dictionary.bas"
#include once "common/table.bas"
#include once "common/keycodes.bas"
#include once "common/scancodes.bas"
#include once "common/functions/pad.bas"
#include once "common/functions/roundup.bas"
#include once "common/functions/minmax.bas"

#include once "consts.bas"
#include once "types.bas"
#include once "globals.bas"
#include once "functions.bas"
#include once "subs.bas"
#include once "methods.bas"

'Declare local variables.
dim filename as String
dim editor_menu as BlueMenu
dim save_prompt as BlueMenu

'Get a filename from the command line.
'filename = command

'For testing purposes however, we will always use the same ROM.
'filename = "roms/test.smc"
'filename = "crisis.smc"

'If no filename is supplied, prompt the user for one.
' (You need to supply a ROM to even use the editor, as it reads its font and
' window graphics from the ROM)
system_path = curdir

'A ROM path may be given on the command line (or dragged onto the exe).
filename = command(1)
if filename <> "" and dir(filename) = "" then
 print "ROM not found: "; filename
 filename = ""
end if

'Otherwise offer the ROM used last time.
if filename = "" then filename = AskLastROM()
if filename = "" then filename = LoadROM()
if filename = "" then end
RememberROM(filename)

'Configure graphic mode.
screen 18, 32

'Read the relevant data from the ROM into memory.
' Only these temporary memory objects will be affected by the editor directly.
' It will not write anything to the actual ROM until you explicitly tell it to save.
ReadData(filename)
disk_rom = original_rom
BuildBaselineROM()
SnapshotOriginalRows()

'Draw the tile overlays
warp_overlay = ImageCreate(16, 16, RGB(255, 0, 255))
trigger_overlay = ImageCreate(16, 16, RGB(255, 0, 255))
chest_overlay = ImageCreate(16, 16, RGB(255, 0, 255))
passage_overlay = ImageCreate(16, 16, RGB(255, 0, 255))

line trigger_overlay, (7, 7)-(8, 8), RGB(255, 0, 0), b
line trigger_overlay, (6, 6)-(9, 9), RGB(0, 0, 0), b

line chest_overlay, (0, 0)-(15, 15), RGB(255, 0, 0), b
line chest_overlay, (1, 1)-(14, 14), RGB(0, 0, 0), b

for i as Integer = 0 to 7
 for j as Integer = 0 to 3
  pset passage_overlay, (j * 4 + (i mod 2) * 2, i * 2), RGB(255, 0, 0)
  pset passage_overlay, (j * 4 + (i mod 2) * 2 + 1, i * 2), RGB(0, 0, 0)
 next
next

circle warp_overlay, (8, 13), 7, RGB(0, 0, 0), 0, 3.14, 4/3
line warp_overlay, (3, 13)-(1, 11), RGB(0, 0, 0)
line warp_overlay, (3, 13)-(5, 11), RGB(0, 0, 0)
circle warp_overlay, (7, 12), 7, RGB(255, 0, 0), 0, 3.14, 4/3
line warp_overlay, (2, 12)-(0, 10), RGB(255, 0, 0)
line warp_overlay, (2, 12)-(4, 10), RGB(255, 0, 0)


'Set up main menu
editor_menu.AddOption(FF4Text("Save ROM"))
editor_menu.AddOption(FF4Text("Edit Features"))
editor_menu.AddOption(FF4Text("Edit Spells"))
editor_menu.AddOption(FF4Text("Edit Spell Sets"))
editor_menu.AddOption(FF4Text("Edit Weapons"))
editor_menu.AddOption(FF4Text("Edit Armors"))
editor_menu.AddOption(FF4Text("Edit Medicines"))
editor_menu.AddOption(FF4Text("Edit Tools"))
editor_menu.AddOption(FF4Text("Edit Shops"))
editor_menu.AddOption(FF4Text("Edit Jobs"))
editor_menu.AddOption(FF4Text("Edit Characters"))
editor_menu.AddOption(FF4Text("Edit Commands"))
editor_menu.AddOption(FF4Text("Edit Actors"))
editor_menu.AddOption(FF4Text("Edit Messages"))
editor_menu.AddOption(FF4Text("Edit Events"))
editor_menu.AddOption(FF4Text("Edit Triggers"))
editor_menu.AddOption(FF4Text("Edit NPCs"))
editor_menu.AddOption(FF4Text("Edit Tilesets"))
editor_menu.AddOption(FF4Text("Edit Map Info"))
editor_menu.AddOption(FF4Text("Edit Maps"))
editor_menu.AddOption(FF4Text("Edit Monsters"))
editor_menu.AddOption(FF4Text("Edit Formations"))
editor_menu.AddOption(FF4Text("Edit Encounters"))
editor_menu.AddOption(FF4Text("Edit Autobattles"))
editor_menu.AddOption(FF4Text("Edit Solobattles"))
editor_menu.AddOption(FF4Text("Export CSV"))
editor_menu.AddOption(FF4Text("Import CSV"))
editor_menu.AddOption(FF4Text("Compare to Original ROM"))
editor_menu.AddOption(FF4Text("Compare with ROM File"))
editor_menu.AddOption(FF4Text("Search Everywhere"))
editor_menu.AddOption(FF4Text("Space Usage"))
editor_menu.AddOption(FF4Text("Changed Entries"))
editor_menu.AddOption(FF4Text("Quit"))

save_prompt.x = 24
save_prompt.y = 25
save_prompt.AddOption(FF4Text("Save ROM"))
save_prompt.AddOption(FF4Text("Quit without saving"))
save_prompt.AddOption(FF4Text("Cancel"))

'Main menu loop
do

 cls
 windowtitle "FF4kster - " + filename + iif(modified, " *", "")
 editor_menu.cancelled = false
 do
  DrawMainHelp(editor_menu.selected)
 loop until editor_menu.UserInput()

 if not editor_menu.cancelled then

  if (editor_menu.selected >= 2 and editor_menu.selected <= 25) or editor_menu.selected = 30 or editor_menu.selected = 32 then
   modified = true
   editor_menu.ChangeOption(1, FF4Text("Save ROM *"))
  end if

  'Start every editor on a black screen so nothing from the main menu is left behind.
  if editor_menu.selected >= 2 and editor_menu.selected <= 32 then cls
  if editor_menu.selected >= 2 and editor_menu.selected <= 32 then DrawBreadcrumb("Main menu > " + FF4Name(editor_menu.options.ItemAt(editor_menu.selected)))

  select case editor_menu.selected

   case 1 'Save
    if SafeToSave(filename) then SaveData(filename) else warning = true
    editor_menu.Display()
    if warning then
     warning = false
     BlueBox(20, 1, 11, 1)
     WriteText(FF4Text("Save failed"), 21, 2)
     getkey
    else
      modified = false
      editor_menu.ChangeOption(1, FF4Text("Save ROM"))
     if last_backup_name <> "" then
      InfoBox("Data saved|Backup: " + last_backup_name + "||Press any key", 4, 1)
     else
      InfoBox("Data saved||Press any key", 20, 1)
     end if
    end if

   case 2: EditItemRanges()
   case 3: EditSpells()
   case 4: EditSpellSets()
   case 5: EditWeapons()
   case 6: EditArmors()
   case 7: EditMedicines()
   case 8: EditTools()
   case 9: EditShops()
   case 10: EditJobs()
   case 11: EditCharacters()
   case 12: EditCommands()
   case 13: EditActors()
   case 14: EditMessages()
   case 15: EditEvents()
   case 16: EditTriggers()
   case 17: EditNPCs()
   case 18: EditTilesets()
   case 19: EditMapProperties()
   case 20: EditMaps()
   case 21: EditMonsters()
   case 22: EditFormations()
   case 23: EditEncounters()
   case 24: EditAutoBattles()
   case 25: EditSoloBattles()
   case 26: ExportImportTables(false)
   case 27: ExportImportTables(true)
   case 28: CompareWithOriginal()
   case 29: CompareWithFile()
   case 30: SearchEverywhere()
   case 31: ShowSpaceUsage()
   case 32: ChangedEntries()

   case else
    if not modified then
     exit do
    end if
    save_prompt.ChangeSelected(3)
    save_prompt.UserSelect()
    if not save_prompt.cancelled then
     select case save_prompt.selected
      case 1
       if SafeToSave(filename) then SaveData(filename) else warning = true
       if warning then
        warning = false
        BlueBox(20, 1, 11, 1)
        WriteText(FF4Text("Save failed"), 21, 2)
        getkey
       else
        modified = false
        exit do
       end if
      case 2
       exit do
     end select
    end if

  end select

 end if

loop
