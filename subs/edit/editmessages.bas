'Messages editor.
'
'The first screen lists the seven banks with how many messages each has and how full its area of the ROM is (Save
'ROM refuses a bank that is over its limit, so the same numbers are kept in view here). Bank 2 asks for a map next,
'because its messages belong to a map. Then comes the list of messages: each line is the number and the start of
'the text, changed messages are yellow, and the selected message is shown on the right as the game would show it.
'
'Enter edits the message (a big text window for banks 1 to 3, a one line box for the others). Space opens a menu
'of everything that can be done with the message: edit, find text, revert it to the loaded ROM, copy and paste,
'undo, where it is used, and for bank 2 add, insert, delete and move. The keys in that menu are shortcuts.
'
'Inserting, deleting or moving a message of a map changes the numbers of the messages after it, so the NPCs of
'the map and the events that belong to it are renumbered along with it (see messagedata.bas), and deleting a
'message that is in use says what uses it first.
'
'The font has no + = ( ) [ ] < > characters, so the help text is written around that.

const msg_label_width = 36
const msg_undo_max = 40

dim shared msg_clip as String
dim shared msg_clip_bank as Integer
dim shared msg_find_text as String
dim shared msg_undo_bank(1 to msg_undo_max) as Integer
dim shared msg_undo_map(1 to msg_undo_max) as Integer
dim shared msg_undo_index(1 to msg_undo_max) as Integer
dim shared msg_undo_text(1 to msg_undo_max) as String
dim shared msg_undo_count as Integer


sub MsgUndoPush(bank as Integer, mp as Integer, i as Integer)

 'Remembers the message as it is now, before it is changed

 if msg_undo_count = msg_undo_max then
  for k as Integer = 1 to msg_undo_max - 1
   msg_undo_bank(k) = msg_undo_bank(k + 1)
   msg_undo_map(k) = msg_undo_map(k + 1)
   msg_undo_index(k) = msg_undo_index(k + 1)
   msg_undo_text(k) = msg_undo_text(k + 1)
  next
  msg_undo_count -= 1
 end if
 msg_undo_count += 1
 msg_undo_bank(msg_undo_count) = bank
 msg_undo_map(msg_undo_count) = mp
 msg_undo_index(msg_undo_count) = i
 msg_undo_text(msg_undo_count) = MsgGet(bank, mp, i)

end sub


sub MsgFillList(lm as BlueMenu ptr, bank as Integer, mp as Integer)

 dim count as Integer = MsgCount(bank, mp)

 lm->ClearAll()
 for i as Integer = 1 to count
  lm->AddOption(MsgLabel(bank, mp, i, msg_label_width), iif(MsgChanged(bank, mp, i), 14, 15))
 next
 if count = 0 then lm->AddOption(FF4Text("- no messages -"), 23)

end sub


sub MsgRefreshRow(lm as BlueMenu ptr, bank as Integer, mp as Integer, i as Integer)

 lm->ChangeOption(i, MsgLabel(bank, mp, i, msg_label_width), iif(MsgChanged(bank, mp, i), 14, 15))

end sub


'-------- drawing --------

sub MsgDraw(lm as BlueMenu ptr, bank as Integer, mp as Integer, message as String)

 dim x0 as Integer = lm->x + lm->WindowWidth() + 2
 dim i as Integer = lm->selected
 dim count as Integer = MsgCount(bank, mp)
 dim text as String
 dim original as String
 dim small_text as BlueTextInput
 dim space_text as String = "Space " + MsgSpaceText(bank)
 dim hint as String
 dim over as Integer = MsgUsed(bank) - MsgRoom(bank)

 screenlock

 BlueBox(0, 0, 78, 1)
 if bank = 2 then
  WriteText(FF4Text("Bank 2   ") + map_names.ItemAt(mp) + FF4Text("   " + str(count) + " messages"), 2, 1, 15)
 else
  WriteText(FF4Text(MsgBankName(bank) + "   " + str(count) + " messages"), 2, 1, 15)
 end if
 WriteText(FF4Text(space_text), 77 - len(space_text), 1, MsgSpaceColor(bank))

 line (x0 * 8, 3 * 8)-(639, 56 * 8 + 7), RGB(0, 0, 0), bf

 if count > 0 then
  text = MsgGet(bank, mp, i)
  if MsgIsLarge(bank) then
   DisplayDialogue(screen_width - 28, 3, text, 9,,, true)
  else
   small_text = BlueTextInput(x0, 3, MsgWidth(bank))
   small_text.extended = (bank = 4 or bank = 5)
   small_text.starting_text = text
   small_text.text = text
   small_text.Display()
   if MsgChanged(bank, mp, i) and MsgOriginal(bank, mp, i, original) then
    WriteText(FF4Text("In the loaded ROM:"), x0, 7, 23)
    WriteText(MsgPreview(bank, original, 30), x0, 8, 23)
   end if
  end if
 end if

 line (0, 57 * 8)-(639, 58 * 8 - 1), RGB(0, 0, 0), bf
 if message <> "" then
  WriteText(FF4Text(left(message, 78)), 1, 57, 12)
 elseif over > 0 then
  WriteText(FF4Text(left("This bank is over its limit by " + str(over) + " bytes: Save ROM will refuse. Shorten some messages.", 78)), 1, 57, 12)
 else
  hint = "Enter edits the message. Space opens the menu of this message."
  if bank = 2 then hint = "Enter edits the message. Space: menu to add, insert, delete, move and more."
  WriteText(FF4Text(hint), 1, 57, 14)
 end if

 screenunlock

end sub


'-------- editing one message --------

sub MsgEdit(lm as BlueMenu ptr, bank as Integer, mp as Integer, i as Integer)

 dim x0 as Integer = lm->x + lm->WindowWidth() + 2
 dim before as String = MsgGet(bank, mp, i)
 dim after as String
 dim big as BlueMessageInput
 dim small_text as BlueTextInput
 dim baseline as String

 if MsgIsLarge(bank) then
  'at the left edge, over the list: the preview of the message is drawn at the right edge and must not cover it
  big = BlueMessageInput(1, 3, before)
  big.h = 44
  baseline = big.Message()
  big.UserType()
  after = big.Message()
  if after = baseline then after = before 'nothing was changed, so the bytes stay as they were
 else
  small_text = BlueTextInput(x0, 3, MsgWidth(bank))
  small_text.cursor = true
  small_text.extended = (bank = 4 or bank = 5)
  small_text.starting_text = before
  small_text.text = before
  small_text.Display()
  small_text.UserType()
  after = small_text.text
 end if

 if after <> before then
  MsgUndoPush(bank, mp, i)
  MsgSet(bank, mp, i, after)
  MsgRefreshRow(lm, bank, mp, i)
 end if

 'the text windows draw over the right side of the screen
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

end sub


'-------- the actions on a message --------

const msg_act_edit = 1
const msg_act_insert = 2
const msg_act_add = 3
const msg_act_delete = 4
const msg_act_up = 5
const msg_act_down = 6
const msg_act_revert = 7
const msg_act_copy = 8
const msg_act_paste = 9
const msg_act_undo = 10
const msg_act_used = 11
const msg_act_find = 12
const msg_act_next = 13


function MsgActionMenu(bank as Integer) as Integer

 'The menu of the selected message. Returns the action chosen, 0 if cancelled.

 dim choice as Integer

 SmReset()
 SmAdd("Edit this message", "Enter", 0, msg_act_edit)
 SmAdd("Find text in this list", "", 0, msg_act_find)
 SmAdd("Find the next match", "", 0, msg_act_next)
 if bank = 2 then
  SmAdd("Add a message at the end", "", 0, msg_act_add)
  SmAdd("Insert a message before this one", "Insert", 0, msg_act_insert)
  SmAdd("Delete this message", "Delete", 0, msg_act_delete)
  SmAdd("Move this message up", "", 0, msg_act_up)
  SmAdd("Move this message down", "", 0, msg_act_down)
 end if
 SmAdd("Copy the text", "Ctrl-C", 0, msg_act_copy)
 SmAdd("Paste over this message", "Ctrl-V", 0, msg_act_paste)
 SmAdd("Revert to the loaded ROM", "Ctrl-R", 0, msg_act_revert)
 SmAdd("Undo the last text change", "Ctrl-Z", 0, msg_act_undo)
 SmAdd("Show where it is used", "Ctrl-U", 0, msg_act_used)
 choice = SmRun("Message")
 if choice = 0 then return 0

 return sm_special(choice)

end function


sub MsgFind(lm as BlueMenu ptr, bank as Integer, mp as Integer, new_search as Boolean, byref message as String)

 'Jumps to the next message of the list (after the cursor, wrapping around) that has the text in it

 dim n as Integer = MsgCount(bank, mp)
 dim i as Integer

 if new_search then msg_find_text = lcase(PromptLine("Find text, Esc cancels:", 30))
 if msg_find_text = "" or n = 0 then exit sub

 for offset as Integer = 1 to n
  i = (lm->selected - 1 + offset) mod n + 1
  if instr(lcase(MsgPlain(bank, MsgGet(bank, mp, i))), msg_find_text) > 0 then
   lm->ChangeSelected(i)
   exit sub
  end if
 next
 message = "No message of this list has that text."

end sub


sub MsgShowUsers(bank as Integer, mp as Integer, i as Integer)

 InfoBox("Where is message " + str(i) + iif(bank = 2, " of " + PlainName(FF4Name(map_names.ItemAt(mp))), "") + " used?" + MsgUsers(bank, mp, i) + "||Press any key", 4, 3)

end sub


sub MsgStructure(lm as BlueMenu ptr, mp as Integer, action as Integer, byref message as String)

 'Add, insert, delete or move a message of a map (bank 2) and renumber what uses the messages

 dim i as Integer = lm->selected
 dim n as Integer = MsgCount(2, mp)
 dim lines as String
 dim uses as Integer
 dim note as String

 if MsgCount(2, mp) = 0 and action <> msg_act_add then i = 1

 select case action

  case msg_act_add
   if n >= 256 then
    message = "A map can have at most 256 messages."
    exit sub
   end if
   maps(mp).dialogues.Append(chr(&h55))
   MsgFillList(lm, 2, mp)
   lm->ChangeSelected(n + 1)

  case msg_act_insert
   if n >= 256 then
    message = "A map can have at most 256 messages."
    exit sub
   end if
   if n = 0 then
    maps(mp).dialogues.Append(chr(&h55))
   else
    maps(mp).dialogues.Insert(i, chr(&h55))
    note = MsgRenumber(mp, 1, i, 0)
   end if
   MsgFillList(lm, 2, mp)
   lm->ChangeSelected(i)

  case msg_act_delete
   if n <= 1 then
    message = "A map keeps at least one message."
    exit sub
   end if
   uses = MsgEventUses(2, mp, i, lines, 12) + MsgNpcUses(mp, i, lines, 12)
   if uses > 0 then
    InfoBox("Message " + str(i) + " is used by:" + lines + "||Press any key", 4, 3)
    if not ConfirmBox("Delete it anyway? What shows it will show the next message.") then exit sub
   elseif not ConfirmBox("Delete this message?") then
    exit sub
   end if
   maps(mp).dialogues.Remove(i)
   note = MsgRenumber(mp, 2, i, 0)
   MsgFillList(lm, 2, mp)
   lm->ChangeSelected(Min(i, n - 1))

  case msg_act_up, msg_act_down
   if (action = msg_act_up and i <= 1) or (action = msg_act_down and i >= n) then
    message = "It cannot move any further."
    exit sub
   end if
   maps(mp).dialogues.Exchange(i, i + iif(action = msg_act_up, -1, 1))
   note = MsgRenumber(mp, 3, i, i + iif(action = msg_act_up, -1, 1))
   MsgFillList(lm, 2, mp)
   lm->ChangeSelected(i + iif(action = msg_act_up, -1, 1))

 end select

 msg_undo_count = 0 'the numbers changed, so the old copies no longer fit
 if note <> "" then InfoBox("The messages after it changed numbers, and the NPCs and events of this map were renumbered along.|" + note + "||Press any key", 4, 3)

end sub


sub MsgDoAction(lm as BlueMenu ptr, bank as Integer, mp as Integer, action as Integer, byref message as String)

 dim i as Integer = lm->selected
 dim count as Integer = MsgCount(bank, mp)
 dim original as String
 dim undone_bank as Integer
 dim undone_map as Integer
 dim undone_index as Integer

 if count = 0 and action <> msg_act_add and action <> msg_act_insert then exit sub

 select case action

  case msg_act_edit
   MsgEdit(lm, bank, mp, i)

  case msg_act_find
   MsgFind(lm, bank, mp, true, message)
  case msg_act_next
   MsgFind(lm, bank, mp, false, message)

  case msg_act_add, msg_act_insert, msg_act_delete, msg_act_up, msg_act_down
   if bank = 2 then MsgStructure(lm, mp, action, message)

  case msg_act_copy
   msg_clip = MsgGet(bank, mp, i)
   msg_clip_bank = bank
   message = "Copied. Space then Paste over another message."

  case msg_act_paste
   if msg_clip_bank = 0 then
    message = "Nothing copied yet."
   elseif MsgIsLarge(msg_clip_bank) <> MsgIsLarge(bank) or (not MsgIsLarge(bank) and msg_clip_bank <> bank) then
    message = "That text is from a bank with a different format."
   elseif MsgChanged(bank, mp, i) andalso not ConfirmBox("Paste over your changes to this message?") then
    'declined
   elseif msg_clip <> MsgGet(bank, mp, i) then
    MsgUndoPush(bank, mp, i)
    MsgSet(bank, mp, i, msg_clip)
    MsgRefreshRow(lm, bank, mp, i)
   end if

  case msg_act_revert
   if not MsgOriginal(bank, mp, i, original) then
    message = "This message is new: there is nothing to revert to."
   elseif original = MsgGet(bank, mp, i) then
    message = "This message has no changes."
   elseif ConfirmBox("Put this message back as in the loaded ROM?") then
    MsgUndoPush(bank, mp, i)
    MsgSet(bank, mp, i, original)
    MsgRefreshRow(lm, bank, mp, i)
   end if

  case msg_act_undo
   if msg_undo_count = 0 then
    message = "Nothing to undo."
   else
    undone_bank = msg_undo_bank(msg_undo_count)
    undone_map = msg_undo_map(msg_undo_count)
    undone_index = msg_undo_index(msg_undo_count)
    if undone_bank = bank and (bank <> 2 or undone_map = mp) and undone_index <= count then
     MsgSet(bank, mp, undone_index, msg_undo_text(msg_undo_count))
     msg_undo_count -= 1
     MsgRefreshRow(lm, bank, mp, undone_index)
     lm->ChangeSelected(undone_index)
    else
     message = "The last change was in another list."
    end if
   end if

  case msg_act_used
   MsgShowUsers(bank, mp, i)

 end select

end sub


'-------- the list of messages --------

sub MsgEditList(bank as Integer, mp as Integer, start_index as Integer = 1)

 dim lm as BlueMenu
 dim done as Boolean
 dim message as String
 dim action as Integer

 lm = BlueMenu(0, 3)
 lm.max_rows = screen_height - 6
 MsgFillList(@lm, bank, mp)
 lm.ChangeSelected(Max(Min(start_index, Max(MsgCount(bank, mp), 1)), 1))
 msg_undo_count = 0
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 do

  MsgDraw(@lm, bank, mp, message)
  message = ""
  action = 0

  if lm.UserInput() then
   if lm.cancelled then
    done = true
   elseif MsgCount(bank, mp) > 0 then
    action = msg_act_edit
   elseif bank = 2 then
    action = msg_act_add
   end if
  else
   select case lm.last_key
    case SPACE_KEY: action = MsgActionMenu(bank)
    case INSERT_KEY: action = msg_act_insert
    case DELETE_KEY: action = msg_act_delete
    case 3: action = msg_act_copy
    case 22: action = msg_act_paste
    case 18: action = msg_act_revert
    case 26: action = msg_act_undo
    case 21: action = msg_act_used
   end select
  end if

  if action <> 0 then MsgDoAction(@lm, bank, mp, action, message)

 loop until done

 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

end sub


'-------- picking a bank and a map --------

function MsgBankLine(bank as Integer) as String

 dim count as Integer
 dim used as Integer = MsgUsed(bank)
 dim room as Integer = MsgRoom(bank)

 if bank = 2 then
  for m as Integer = 1 to total_maps
   count += maps(m).dialogues.Length()
  next
 else
  count = MsgCount(bank, 0)
 end if

 return FF4Text(Pad(MsgBankName(bank), 9) + Pad(str(count), 5, true) + " messages   " + Pad(str(used), 6, true) + " of " + Pad(str(room), 6, true) + " bytes  " + Pad(str(used * 100 \ Max(room, 1)), 3, true) + "%")

end function


function MsgPickBank(byref bank as Integer) as Boolean

 'The banks with how full each is. Returns false if cancelled.

 dim picker as BlueMenu
 dim chosen as Boolean

 picker = BlueMenu(0, 3)
 for b as Integer = 1 to msg_bank_count
  picker.AddOption(MsgBankLine(b), MsgSpaceColor(b))
 next
 picker.ChangeSelected(bank)
 picker.title = "Pick a bank"

 'the screen is cleared once: clearing it for every key makes it blink
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 do
  screenlock
  BlueBox(0, 0, 78, 1)
  WriteText(FF4Text("MESSAGES"), 2, 1, 15)
  WriteText(FF4Text("Yellow: nearly full. Red: over the limit, Save ROM would refuse."), 12, 1, 23)
  line (0, (3 + msg_bank_count + 3) * 8)-(639, (3 + msg_bank_count + 5) * 8 - 1), RGB(0, 0, 0), bf
  WriteText(FF4Text(MsgBankInfo(picker.selected)), 1, 3 + msg_bank_count + 3, 14)
  if picker.selected = 2 then WriteText(FF4Text("Pick a map next: the messages of a bank 2 list belong to that map."), 1, 3 + msg_bank_count + 4, 23)
  screenunlock
 loop until picker.UserInput()

 chosen = not picker.cancelled
 bank = picker.selected

 return chosen

end function


function MsgPickMap(byref mp as Integer) as Boolean

 'The maps with their number of messages. Returns false if cancelled.

 dim picker as BlueMenu
 dim chosen as Boolean
 dim space_text as String

 picker = BlueMenu(0, 3)
 picker.max_rows = screen_height - 6
 for m as Integer = 1 to total_maps
  picker.AddOption(FF4Text(Pad(str(m), 3, true, "0") + "  ") + Pad(map_names.ItemAt(m), 26,, FF4Text(" ")) + FF4Text(Pad(str(maps(m).dialogues.Length()), 3, true) + " messages"), iif(MsgMapChanged(m), 14, iif(maps(m).dialogues.Length() = 0, 23, 15)))
 next
 picker.ChangeSelected(Max(Min(mp, total_maps), 1))
 space_text = "Space " + MsgSpaceText(2)

 'the screen is cleared once: clearing it for every key makes the list blink
 line (0, 0)-(639, 463), RGB(0, 0, 0), bf

 do
  screenlock
  BlueBox(0, 0, 78, 1)
  WriteText(FF4Text("Bank 2: pick a map"), 2, 1, 15)
  WriteText(FF4Text(space_text), 77 - len(space_text), 1, MsgSpaceColor(2))
  WriteText(FF4Text("Yellow maps have changed messages."), 46, 5, 23)
  screenunlock
 loop until picker.UserInput()

 chosen = not picker.cancelled
 mp = picker.selected

 return chosen

end function


sub MsgOpenAt(code as Integer)

 'Opens the list of messages on one message: code is (bank * 1000 + map) * 1000 + number (from the search)

 dim bank as Integer = code \ 1000000
 dim mp as Integer = (code \ 1000) mod 1000
 dim i as Integer = code mod 1000

 if bank < 1 or bank > msg_bank_count then exit sub
 if bank = 2 and (mp < 1 or mp > total_maps) then exit sub
 MsgEditList(bank, mp, i)

end sub


sub EditMessages()

 dim bank as Integer = 1
 dim mp as Integer = 1

 if jump_kind = "messages" then
  MsgOpenAt(jump_index)
  jump_kind = ""
 end if

 do

  if not MsgPickBank(bank) then exit do

  if bank = 2 then
   do
    if not MsgPickMap(mp) then exit do
    MsgEditList(2, mp)
   loop
  else
   MsgEditList(bank, 0)
  end if

 loop

 cls

end sub
