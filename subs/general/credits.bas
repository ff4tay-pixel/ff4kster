'The text of the end credits roll. The game keeps it as one run of text codes at file offset 9F36D to 9F7D6 (the
' disassembly's CreditsText, cutscene/text/credits_text_en.asm): the codes of the window font (one code is one
' tile, 42 is A, 0A is a period, FF a space), 01 for the start of the next line, 02 followed by a count for that many
' spaces, and a 00 at the end. A line is drawn on a grid 32 letters wide, two tile rows high, so a line must not be
' wider than 32 letters (a wider one would run into the next row). After the 00 the ROM has FF bytes up to 9F900,
' so the text can grow by that room; the game's code does not know the length, it draws until the 00.
' The roll lasts a fixed time (0A20 frames, EndCredits in cutscene/cutscene.asm); the editor does not change that.
'
' In memory a line is its indent (the 02 count at its start) and its letters; a 02 count in the middle of a line
' (only the first line has one) is turned into that many spaces, which draws the same. Save ROM writes the text only
' when it was changed (or was written once before, so that undoing a change writes the old text back).

const cr_start = &h9F36D + &h200 'file offset of the first code, with the 0x200 header
const cr_room = &h9F900 - &h9F36D 'bytes the text may take, the 00 at the end included
const cr_max_lines = 400
const cr_width = 32 'letters per line
const cr_undo_max = 30

dim shared cr_indent(1 to cr_max_lines) as Integer 'spaces before the line
dim shared cr_text(1 to cr_max_lines) as String 'the letters as window font codes (a period is 0A as in the ROM)
dim shared cr_count as Integer
dim shared cr_orig_pack as String 'the text as loaded, packed
dim shared cr_orig_raw as String 'the bytes of the whole area as loaded
dim shared cr_written as Boolean 'Save ROM wrote the text once
dim shared cr_undo(1 to cr_undo_max) as String
dim shared cr_undo_count as Integer
dim shared cr_ready as Boolean


function CrPack() as String

 'The lines as the ROM stores them, with the 00 at the end.

 dim result as String

 for i as Integer = 1 to cr_count
  if i > 1 then result += chr(1)
  if cr_indent(i) > 0 then result += chr(2) + chr(cr_indent(i))
  result += cr_text(i)
 next

 return result + chr(0)

end function


sub CrUnpack(s as String)

 'Sets the lines from text in the ROM's form.

 dim p as Integer = 1
 dim b as Integer
 dim n as Integer

 cr_count = 1
 cr_indent(1) = 0
 cr_text(1) = ""
 do while p <= len(s)
  b = asc(mid(s, p, 1))
  if b = 0 then exit do
  if b = 1 then
   if cr_count < cr_max_lines then
    cr_count += 1
    cr_indent(cr_count) = 0
    cr_text(cr_count) = ""
   end if
   p += 1
  elseif b = 2 and p < len(s) then
   n = asc(mid(s, p + 1, 1))
   if len(cr_text(cr_count)) = 0 and cr_indent(cr_count) = 0 then
    cr_indent(cr_count) = n
   else
    cr_text(cr_count) += string(n, chr(&hFF))
   end if
   p += 2
  else
   cr_text(cr_count) += chr(b)
   p += 1
  end if
 loop

end sub


function CrBytes() as Integer

 return len(CrPack())

end function


function CrChanged() as Boolean

 return CrPack() <> cr_orig_pack

end function


sub ReadCredits()

 CrUnpack(mid(ff4rom, cr_start + 1, cr_room))
 cr_orig_pack = CrPack()
 cr_orig_raw = mid(ff4rom, cr_start + 1, cr_room)
 cr_undo_count = 0
 cr_written = false
 cr_ready = true

end sub


sub WriteCredits()

 'Called by Save ROM. Text that was never edited is not written; text that was edited and then put back writes the
 ' bytes the ROM had.

 dim s as String

 if not cr_ready then exit sub
 s = CrPack()
 if s = cr_orig_pack then
  if cr_written then
   for i as Integer = 1 to cr_room
    WriteByte(cr_start + i - 1, asc(mid(cr_orig_raw, i, 1)))
   next
  end if
  exit sub
 end if
 if len(s) > cr_room then
  WarningMessage(FF4Text("Credits take " + str(len(s)) + " bytes, only " + str(cr_room) + " fit"))
  exit sub
 end if
 for i as Integer = 1 to cr_room
  if i <= len(s) then
   WriteByte(cr_start + i - 1, asc(mid(s, i, 1)))
  else
   WriteByte(cr_start + i - 1, &hFF)
  end if
 next
 cr_written = true

end sub
