'Backups of the ROM file. The first Save ROM of a session copies the ROM to <rom>.<date>-<time>.bak
'(see BackupName in savedata.bas). These two tools of the main menu list those files, newest first:
'
'  Restore from backup  replaces the ROM file with the chosen backup. The ROM as it is now is copied to a
'                       new backup first, so a restore can be undone with a restore. The editor then
'                       starts again (its data is read from the file only at start up).
'  Delete backups       deletes one backup or all of them.

const max_backups = 500

dim shared backup_names(1 to max_backups) as String 'file names without the folder, newest first
dim shared backup_count as Integer


function BackupFolder(path as String) as String

 'The folder part of a path, with its closing slash ("" for a plain file name)

 dim cut as Integer

 for i as Integer = len(path) to 1 step -1
  if mid(path, i, 1) = "\" or mid(path, i, 1) = "/" then
   cut = i
   exit for
  end if
 next

 return left(path, cut)

end function


function BackupBase(path as String) as String

 return mid(path, len(BackupFolder(path)) + 1)

end function


function BackupSize(full_name as String) as Integer

 'Size of a file in bytes (0 if it cannot be opened)

 dim a as Integer = freefile
 dim result as Integer

 if open(full_name for binary access read as #a) <> 0 then return 0
 result = lof(a)
 close #a

 return result

end function


function IsBackupStamp(s as String) as Boolean

 'YYYYMMDD-HHMMSS

 if len(s) <> 15 then return false
 if mid(s, 9, 1) <> "-" then return false
 for i as Integer = 1 to 15
  if i <> 9 and (asc(mid(s, i, 1)) < asc("0") or asc(mid(s, i, 1)) > asc("9")) then return false
 next

 return true

end function


sub FindBackups(path as String)

 'Fills backup_names with the backups of this ROM, newest first

 dim rom_name as String = BackupBase(path)
 dim folder as String = BackupFolder(path)
 dim f as String
 dim stamp as String

 backup_count = 0
 f = dir(folder + rom_name + ".*.bak")
 do while f <> ""
  stamp = mid(f, len(rom_name) + 2, 15)
  if len(f) = len(rom_name) + 1 + 15 + 4 and lcase(left(f, len(rom_name) + 1)) = lcase(rom_name + ".") and IsBackupStamp(stamp) and backup_count < max_backups then
   backup_count += 1
   backup_names(backup_count) = f
  end if
  f = dir()
 loop

 'the stamp is year first, so sorting the names sorts by date
 for i as Integer = 1 to backup_count - 1
  for j as Integer = i + 1 to backup_count
   if backup_names(j) > backup_names(i) then swap backup_names(i), backup_names(j)
  next
 next

end sub


function BackupLabel(path as String, i as Integer) as String

 'Date, time and size of backup i

 dim rom_name as String = BackupBase(path)
 dim s as String = mid(backup_names(i), len(rom_name) + 2, 15)

 return left(s, 4) + "-" + mid(s, 5, 2) + "-" + mid(s, 7, 2) + "  " + mid(s, 10, 2) + ":" + mid(s, 12, 2) + ":" + mid(s, 14, 2) + "  " + str(BackupSize(BackupFolder(path) + backup_names(i)) \ 1024) + " KB"

end function


function PickBackup(path as String, title as String, first_option as String) as Integer

 'A list of the backups. Returns the number picked (1 to backup_count), 0 for first_option (if given) and
 ' -1 if cancelled.

 dim m as BlueMenu

 m = BlueMenu(4, 4)
 m.max_rows = 30
 m.title = title
 if first_option <> "" then m.AddOption(FF4Text(first_option), 14)
 for i as Integer = 1 to backup_count
  m.AddOption(FF4Text(BackupLabel(path, i)))
 next
 m.UserSelect()
 if m.cancelled then return -1

 return m.selected - iif(first_option <> "", 1, 0)

end function


function RestoreFromBackup(path as String, has_edits as Boolean) as Boolean

 'Returns true if the ROM file was replaced; the caller must then start the editor again

 dim choice as Integer
 dim safety as String
 dim folder as String = BackupFolder(path)

 cls
 FindBackups(path)
 if backup_count = 0 then
  InfoBox("There are no backups of this ROM.||Save ROM makes one the first time you save in a|session: " + BackupBase(path) + ".date-time.bak||Press any key", 4, 20)
  return false
 end if

 choice = PickBackup(path, "Restore the ROM from a backup, newest first. Esc cancels", "")
 if choice < 1 then return false

 if has_edits then
  if not ConfirmBox("Replace the ROM with this backup? Unsaved edits are lost.") then return false
 else
  if not ConfirmBox("Replace the ROM file with this backup?") then return false
 end if

 'keep the ROM as it is now, so the restore can be undone
 if dir(path) <> "" then
  safety = BackupName(path)
  if not CopyFile(path, safety) then
   InfoBox("The ROM as it is now could not be copied first,|so nothing was changed.||Press any key", 4, 20)
   return false
  end if
 end if

 if not CopyFile(folder + backup_names(choice), path) then
  InfoBox("The ROM file could not be written (read-only, or open|in another program?).|" + iif(safety <> "", "The ROM as it was is saved in " + safety + ".", "") + "||Press any key", 4, 20)
  return false
 end if

 return true

end function


sub DeleteBackups(path as String)

 dim choice as Integer
 dim total_kb as Integer
 dim folder as String = BackupFolder(path)

 do
  cls
  FindBackups(path)
  if backup_count = 0 then
   InfoBox("There are no backups of this ROM.||Press any key", 4, 20)
   exit do
  end if

  total_kb = 0
  for i as Integer = 1 to backup_count
   total_kb += BackupSize(folder + backup_names(i)) \ 1024
  next

  choice = PickBackup(path, "Delete backups. Esc goes back", "Delete all " + str(backup_count) + " backups, " + str(total_kb) + " KB")
  if choice < 0 then exit do

  if choice = 0 then
   if ConfirmBox("Delete all " + str(backup_count) + " backups? This cannot be undone.") then
    for i as Integer = 1 to backup_count
     kill folder + backup_names(i)
    next
   end if
  else
   if ConfirmBox("Delete this backup? This cannot be undone.") then kill folder + backup_names(choice)
  end if
 loop

 cls

end sub
