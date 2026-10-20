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

'The main menu has header rows between groups of entries. menu_id maps a row
' to its entry number (1 = Save ROM ... 30 = Quit), 0 for a header row.
const menu_world_map = 31 'Edit World Maps (numbered last so the other entries keep their numbers)
const menu_portraits = 32 'Edit Portraits
const menu_monster_sprites = 33 'Edit Monster Sprites
dim shared menu_id(1 to 60) as Integer
dim shared menu_rows as Integer
dim shared entry_number as Integer

sub AddMainEntry(m as BlueMenu, label as String, explicit_id as Integer = 0)

 'explicit_id puts an entry in the menu where it belongs without renumbering the ones after it

 m.AddOption(FF4Text(label))
 menu_rows += 1
 if explicit_id > 0 then
  menu_id(menu_rows) = explicit_id
 else
  entry_number += 1
  menu_id(menu_rows) = entry_number
 end if

end sub


sub AddMainHeader(m as BlueMenu, label as String)

 m.AddOption(FF4Text("- " + label + " -"), 14)
 menu_rows += 1
 menu_id(menu_rows) = 0

end sub


function MainMenuInput(m as BlueMenu) as Boolean

 'Like m.UserInput(), but the cursor never rests on a header row.

 dim result as Boolean = m.UserInput()

 if not result then
  do while menu_id(m.selected) = 0
   if m.last_key = UP_KEY then
    m.ChangeSelected(m.selected - 1)
   else
    m.ChangeSelected(m.selected + 1)
   end if
  loop
 end if

 return result

end function

'Declare local variables.
dim filename as String
dim editor_menu as BlueMenu
dim save_prompt as BlueMenu
dim choice as Integer

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


'Set up main menu. Yellow header rows group the entries and the cursor skips them.
AddMainEntry(editor_menu, "Save ROM")
AddMainHeader(editor_menu, "Items and magic")
AddMainEntry(editor_menu, "Edit Features")
AddMainEntry(editor_menu, "Edit Spells")
AddMainEntry(editor_menu, "Edit Spell Sets")
AddMainEntry(editor_menu, "Edit Weapons")
AddMainEntry(editor_menu, "Edit Armors")
AddMainEntry(editor_menu, "Edit Medicines")
AddMainEntry(editor_menu, "Edit Tools")
AddMainEntry(editor_menu, "Edit Shops")
AddMainHeader(editor_menu, "Party")
AddMainEntry(editor_menu, "Edit Jobs")
AddMainEntry(editor_menu, "Edit Battle Sprites")
AddMainEntry(editor_menu, "Edit Portraits", menu_portraits)
AddMainEntry(editor_menu, "Edit Characters")
AddMainEntry(editor_menu, "Edit Commands")
AddMainEntry(editor_menu, "Edit Actors")
AddMainHeader(editor_menu, "Story and text")
AddMainEntry(editor_menu, "Edit Messages")
AddMainEntry(editor_menu, "Edit Events")
AddMainEntry(editor_menu, "Edit Triggers")
AddMainEntry(editor_menu, "Edit NPCs")
AddMainHeader(editor_menu, "World")
AddMainEntry(editor_menu, "Edit Tilesets")
AddMainEntry(editor_menu, "Edit Map Info")
AddMainEntry(editor_menu, "Edit Maps")
AddMainEntry(editor_menu, "Edit World Maps", menu_world_map)
AddMainHeader(editor_menu, "Battles")
AddMainEntry(editor_menu, "Edit Monsters")
AddMainEntry(editor_menu, "Edit Monster Sprites", menu_monster_sprites)
AddMainEntry(editor_menu, "Edit Formations")
AddMainEntry(editor_menu, "Edit Encounters")
AddMainEntry(editor_menu, "Edit Autobattles")
AddMainEntry(editor_menu, "Edit Solobattles")
AddMainHeader(editor_menu, "Overview")
AddMainEntry(editor_menu, "Search Everywhere")
AddMainEntry(editor_menu, "Space Usage")
AddMainEntry(editor_menu, "Changed Entries")
AddMainEntry(editor_menu, "Quit")

save_prompt.x = 24
save_prompt.y = 25
save_prompt.AddOption(FF4Text("Save ROM"))
save_prompt.AddOption(FF4Text("Quit without saving"))
save_prompt.AddOption(FF4Text("Cancel"))

'Main menu entries: 1 is Save ROM, then the editors up to the last one before Quit.
const menu_save = 1
const menu_first_editor = 2
const menu_last_editor = 29

'Main menu loop
do

 cls
 windowtitle "FF4kster - " + filename + iif(modified, " *", "")
 editor_menu.cancelled = false
 do
  DrawMainHelp(menu_id(editor_menu.selected))
 loop until MainMenuInput(editor_menu)
 choice = menu_id(editor_menu.selected)

 if not editor_menu.cancelled then

  'Start every editor on a black screen so nothing from the main menu is left behind.
  if (choice >= menu_first_editor and choice <= menu_last_editor) or choice = menu_world_map or choice = menu_portraits or choice = menu_monster_sprites then cls

  help_entry = choice

  select case choice

   case menu_save
    editor_menu.Display()
    SaveROM(filename)

   case 2: EditItemRanges()
   case 3: EditSpells()
   case 4: EditSpellSets()
   case 5: EditWeapons()
   case 6: EditArmors()
   case 7: EditMedicines()
   case 8: EditTools()
   case 9: EditShops()
   case 10: EditJobs()
   case 11: EditBattleSprites()
   case 12: EditCharacters()
   case 13: EditCommands()
   case 14: EditActors()
   case 15: EditMessages()
   case 16: EditEvents()
   case 17: EditTriggers()
   case 18: EditNPCs()
   case 19: EditTilesets()
   case 20: EditMapProperties()
   case 21: EditMaps()
   case 22: EditMonsters()
   case 23: EditFormations()
   case 24: EditEncounters()
   case 25: EditAutoBattles()
   case 26: EditSoloBattles()
   case 27: SearchEverywhere()
   case 28: ShowSpaceUsage()
   case 29: ChangedEntries()
   case menu_world_map: EditWorldMaps()
   case menu_portraits: EditPortraits()
   case menu_monster_sprites: EditMonsterSprites()

   case else
    if not modified then
     exit do
    end if
    save_prompt.ChangeSelected(3)
    save_prompt.UserSelect()
    if not save_prompt.cancelled then
     select case save_prompt.selected
      case 1
       if SaveROM(filename) then
        exit do
       else
        'Saving failed: the reasons were shown. Leave only if the user insists.
        if ConfirmBox("Quit and lose the unsaved edits?") then exit do
       end if
      case 2
       exit do
     end select
    end if

  end select

  help_entry = 0

  'Work out whether anything really changed (opening an editor and leaving does not count).
  if (choice >= menu_first_editor and choice <= menu_last_editor) or choice = menu_world_map or choice = menu_portraits or choice = menu_monster_sprites then
   modified = HasUnsavedEdits()
  end if
  editor_menu.ChangeOption(menu_save, FF4Text(iif(modified, "Save ROM *", "Save ROM")))

 end if

loop
