# FF4kster v1.1

IMPORTANT NOTES
---------------

* This editor has only been confirmed to work with roms of FF2US v1.1.
  Usage of this editor with other roms is at your own risk. I may
  eventually add compatibility for other versions in future releases.
  
* This editor is not designed to "play nice" with other editors, patches,
  or external modifications to your rom besides graphics editing. If you
  are able to use other editors or patches or make other changes by means
  other than FF4kster and it happens to be compatible, that's great; but
  if they cause FF4kster to no longer work or to mess up or to mess your
  rom up, too bad; you were warned.
  
* Always back up your rom before making any modifications of any kind
  with this or anything else, especially if you are planning any kind
  of large-scale changes. This editor is currently in active production
  and bugs, big and small, slip by from time to time. Thus, it is useful
  and prudent to always have a "stable" version of your rom to fall back
  on in case it gets horribly messed up.
  
* There are some areas of memory to which this editor allows you to add or
  append data. They are checked when you save: events, triggers, map data,
  every bank of messages, item descriptions, map labels and the spell lists
  show an overflow warning and the ROM is not written if there is too much
  data (the Space Usage entry on the main menu shows how full each one is),
  and NPC placements cannot be added once their area is full. If you see an
  overflow warning, shorten or remove some of that kind of data and save
  again. Even so, always keep a backup of your rom.

ABOUT
-----
The goal of this project is to create an all-in-one comprehensive rom
editor / hacking tool for FF4 (technically FF2us, but for the sake of
convenience and brevity I will henceforth refer to it as FF4).

This editor tends to use config files rather than hard-coded strings for as
many labels as possible. This includes things like element names, status
names, shop names, map names, etc., basically whatever things you need names
or descriptions for that can't be read from the ROM directly (things like
character names and job names will be read directly from the ROM you're
editing and the labels will display as such). Thus, if you change DKnight in
the ROM to DarkKn or something, then all the labels for that job will show
DarkKn rather than DKnight. Likewise, if you decide you want to have a
different elemental scheme, then instead of having to remember "ok whenever I
see 'fire' in the editor that means 'water'", you can just go into the config
file and overwrite the string "fire" with "water", and the editor will display
"water" for you.

In addition, this editor attempts to incorporate as much graphic data from the
ROM as possible. For example, it currently reads the menu and font graphics
from the ROM you're editing. This has a couple of advantages. First of all, if
you changed the font/windows in your hack, the editor will look like that as
well, so it adds to the look/feel/atmosphere. Secondly, if you changed some of
the symbols to something else (like, let's say you took out the Whip weapons
and added in, say, the Book weapons from FF3, so you changed the whip font
symbol to look like the book symbol), then those changes will appear in the
editor (so instead of having to remember "ok whenever I see a whip symbol that
means book", you would just see the book symbol you put in there). Ideally
though, I'd like it to also display things like, the weapon graphic for the
weapon you're editing, with the correct palette (as opposed to the text
description it has there right now).

It already draws the map tiles and tilesets, monster sprites (while editing a
monster's graphics, and in the Formations editor), the characters' battle
sprites (in the Battle Sprites editor) and the animation sequence of a spell
(in the Spells editor), all read from the ROM you are editing, plus a weapon's
sprite (in the Weapons editor).
Armor, item icons and the weapon hit ("slash") graphics are not drawn yet.


INSTALLATION INSTRUCTIONS
-------------------------

* Download the zip file
* Unzip it into a folder of your choice


BUILDING FROM SOURCE
--------------------

FF4kster is a FreeBASIC program. Install the FreeBASIC compiler and make
sure `fbc.exe` is available on PATH. On Windows, FreeBASIC can be installed
with:

  winget install --id FreeBASIC.FreeBASIC

FreeBASIC 1.10.1 was used to build this checkout. From the repository root,
run the reproducible console build script:

  .\build.ps1

To remove the previous canonical executable before building, use:

  .\build.ps1 -Clean

If PowerShell blocks local scripts, allow scripts for the current terminal only
and run the command again:

  Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
  .\build.ps1

The script compiles the single translation unit with the visible console build:

  fbc -x ff4kster-console.exe main.bas

This creates `ff4kster-console.exe` in the repository root. Run it from that same
folder so the program can find the `config` directory:

  .\ff4kster-console.exe

For a windowed build without a visible console, use:

  fbc -s gui -x main.exe main.bas

The console build is recommended for testing because it shows the ROM file
selector and any startup errors.

The program opens a file selector for a compatible FF2US v1.1 ROM. The
current code supports an unheadered ROM of 1 MiB or more (a multiple of 32 KiB, so
extended ROM hacks open too) or the same with a 512-byte header; the local `ff2.smc` test ROM is 1 MiB.
A ROM whose size is not exactly 1 MiB (without header) gets a warning on opening that asks whether to continue.
The editor only reads and writes the original 1 MiB area, so data a hack keeps beyond it is untouched.
The Commands editor writes only the commands you changed, so an unedited hack keeps its own command
code, and command 22 shows "custom routine, not changed" when the ROM has its own code there.
Keep a backup before saving changes.
Successful builds may show non-fatal warnings about mixed Boolean and
non-Boolean operands in menu code.


CONTROLS
--------

  Always:

    ESC:   Cancel / go back a menu
    Enter: Confirm

  In menus:

    Arrows:      Move among menu options
    End:         Jump to bottom option
    Home:        Jump to top option
    Page Up:     Move up one section
    Page Down:   Move down one section
    Slash (/):   Toggle "indexed mode" (puts an index in front of each option)
    Tab:         Alternate between component windows of a "composite" menu (such as
                 element/status or "can equip" menus)
    Shift-Enter: Highlight the current entry; pressing Enter on another
                 entry will then swap the two instead of confirming (only
                 certain menus can do this)
    Ctrl-F:      Find an entry by name
    Ctrl-N:      Jump to the next entry that matches the search
    Ctrl-G:      Go to an entry by its number
    F1:          Show key help for the editor you are in (menus and editing screens)

  In editors that list things (messages, triggers, NPC placements, event
  calls, scripts and so on), Insert adds an entry and Delete removes the
  selected one. Deleting a trigger, an NPC placement or a message asks for
  confirmation first.

  In the lists of spells, weapons, armors, medicines, tools, monsters, shops,
  formations, jobs, commands, actors, spell sets, encounter areas, autobattles
  and solobattles (Ctrl-U works for spells, items, monsters and formations;
  in the encounter list copy and paste copy an area's table choice and its
  formations, and revert / undo restore them):

    Space:       Open a menu of all of the actions below, with the key of each
                 one beside it, so none of the keys has to be learned
    Ctrl-R:      Revert the entry to how it was when the ROM was loaded
    Ctrl-C / V:  Copy and paste an entry (the target keeps its name)
    Ctrl-Z:      Undo the last change made to an entry in this list (up to 40
                 changes; opening an entry, pasting and reverting are each one
                 step; swapping entries is not undoable)
    Ctrl-U:      Show where the entry is used
    Yellow names mark entries that differ from the loaded ROM, and the list
    reopens on the entry you were last on.
  The mouse works in menus: click an entry to select it, click it again to
  open it, right click goes back (Esc) and the wheel moves the cursor. Message
  boxes close on a click. In the map editor a left click paints the selected
  tile (drag to keep painting, one undo step per stroke), a right click picks
  the tile under the pointer, clicking the tile palette chooses a tile, and in
  paste mode a click places the copied area.
  F1 shows key help on every screen: the keys that work everywhere plus the keys of
  the editor you are in (the same text the main menu shows beside its entries). The main menu also lists the keys that matter
  for whichever editor is highlighted, and the map editor, the battle sprite
  editor and the level up editor print their own keys on screen.

  Note that the editor's font cannot draw every symbol (it has no + = ( ) [ ] <
  >), so on-screen help spells those keys out in words.

  In numeric inputs:

    Up:        +1
    Down:      -1
    Page Up:   +10
    Page Down: -10
    Home:      Minimum value
    End:       Maximum value
    X:         Switch between decimal and hexadecimal entry (A-F are accepted
               in hex mode)
    Backspace: Divide current number by 10, rounding down (effectively erases
               last digit)
    0-9 keys:  Multiply the current number by 10 and add the typed digit
               (the first digit replaces the current value, then later digits
               append; this allows you to type out a replacement number)
    
    NOTE - Some things look like numeric inputs but are actually menus (prices
           for example, as you can't just put any arbitrary number as a price)

  In text inputs:

    Letters:   Letters
    Numbers:   Numbers
    Unerscore: Elipsis (three dots "..." as a single symbol)
    Symbols:   If the symbol corresponds to a symbol in the FF4 font (such as
               a dash or colon), that symbol; otherwise a "?"
    Insert:    Insert a special symbol from the FF4 font that doesn't have a
               corresponding ascii symbol (e.g. weapon icons, magic orbs,
               etc); the first one will appear and you can cycle through them
               using the arrows (enter to confirm)
    Backspace: Delete last letter/symbol


USAGE INSTRUCTIONS
------------------

Whenever you run the program, you must first specify the location of an FF4
rom. This is done by navigating to the desired file using the keyboard. 
If there is a rom you edit often, it may be convenient to copy it
into the same folder as FF4kster.

Assuming that nothing goes wrong and the rom loads correctly, you will then
be presented with a menu of different editors for different types of game
objects. You can use those to view and/or change the various game components,
then when you are satisfied with the changes, navigate back to the main menu
and select "Save ROM". The menu changes this entry to "Save ROM !" (and the
window title gets a *) when you leave an editor after really changing
something; opening an editor and leaving it unchanged does not count. If you
choose "Quit" while the editor is marked as modified, you can save, quit
without saving, or cancel and return to the editor. If saving fails (data
that does not fit, a read-only file, or a ROM file that changed on disk),
a box lists every reason, nothing is written, and Quit asks whether you
really want to leave and lose the edits.

If something did go wrong, the usual result is that you will be presented
with a black screen that seems to be doing nothing for a long time. If this
happens, the only solution to my knowledge is to halt the task using
whatever means your operating system provides for doing so.

The main menu groups the editors under yellow headings (Items and magic,
Party, Story and text, World, Battles, Overview); the cursor skips the
headings. The editors are in this order: Features, Spells, Spell Sets,
Weapons, Armors, Medicines, Tools, Shops, Jobs, Characters, Commands, Actors,
Battle Sprites, Portraits, Field Sprites, Messages, Events, Triggers, NPCs, Tilesets, Map Info, Maps,
Monsters, Formations, Encounters, Autobattles, Solobattles and Battle Formulas, followed by
Search Everywhere, Space Usage and Changed Entries. "Edit World Maps" (under World) first lists
the three worlds, like the list of maps, with a picture of the selected one and how
full its data is; Enter edits it. The editor looks and works like the map editor:
the tile palette on the left (8 tiles wide, tile numbers in the same order as in the
map editor), the map on the right (30 by 24 tiles at a time, scrolling), a small map of
the whole world under the palette and a status box at the bottom with the panel, the
tile, the size of the selection, the position, the room left in the ROM and what the
tile under the cursor allows. Tab switches between the map and the palette (the active
panel has the white cursor) and the arrows move the cursor of the active panel. Home,
End, PgUp and PgDn go to the top left, bottom left, top right and bottom right corner
like in the map editor's grids, and Ctrl with an arrow jumps 16 tiles on the map. On the
map: Enter places the palette tile (over the selected block, if there is one), Space
flood fills, R replaces every tile like the one under the cursor in the whole world,
Backspace picks the tile under the cursor into the palette, Shift with the arrows
selects a block, Ctrl-C copies the block, Ctrl-V shows it as a preview that the arrows
move, Enter places and Esc cancels, and Ctrl-Z / Ctrl-Y undo and redo (each world keeps its
own undo, also after you leave it). Ctrl-R reverts the whole world to how the ROM had it (it
asks first and Ctrl-Z brings the edits back). Esc goes back to
the list of worlds. M opens a menu of every action with its key (choosing one does
it as if the key had been pressed). O cycles the overlay: the world's triggers are drawn as yellow frames (the
status box says where the one under the cursor goes), and the encounter zones as dashed lines
with each zone's encounter number (Enc, as in the Encounters editor; the game picks the
random battle by 32 by 32 tile zone: 8 by 8 on the overworld, 4 by 4 underground, 2 by 2 on
the moon). T edits the trigger under the cursor (the same screen as Edit Triggers; on a
tile with none it offers to add one), Insert adds a trigger at the cursor and Delete removes
it. The game has room for 82 world triggers in all and the original ROM already uses them
all, so delete one before adding another. With the mouse a left click on the map paints (drag to keep
painting), a right click picks the tile, a click on the palette chooses a tile, a click
on the small map jumps there and the wheel moves the cursor; in paste mode a click
places the block. The map is shown as stored in the ROM; the game changes a few
overworld tiles while it runs, and the editor does not change that. Each world has a
fixed amount of room in the ROM (16384, 7424 and 7808 bytes); Space Usage lists it too.
If a world does not fit, Save ROM refuses. Edits to the tile graphics, palettes and tile
properties are not part of this editor. A panel beside the menu
shows the keys for the highlighted entry. The CSV export/import and the two ROM
comparison tools described under "Extras" below are still in the program but
are currently hidden from the menu.

FF4kster uses a wide array of config files to help you keep track of
changes that the editor cannot detect directly from the rom itself. To
modify these, simply navigate into the "config" folder and load up the
corresponding .dat file in a text editor. From there the format should
be obvious, but in most cases it is simply the index of the item in
question followed by the label of the item (keep it lined up vertically
with the others and use spaces, not tabs). You can change or delete
existing items, or add new ones (for the lists that aren't already 
complete).

The following is a breakdown of the different kinds of objects that this
editor can modify, some relevant details about how the game stores or
inteprets them, and how to use the corresponding component of the editor:


SPELLS
------

A "spell" in this context refers not only to the player spells (the black and
white spells, the summons, ninja, and twin magic) but also to monster
techniques (big bang, black hole, "counter", explode, etc).

The "palette", "sprites", "sequence", and "effect" parameters affect the
graphics and animation used by the spell. A preview panel on the right of the
Spells screen plays the spell's sequence (the sprite animation) using its
palette and sprites, and updates as you change them. The "effect" is a piece of
the game's own code (screen shakes, flashes, projectiles, the summons), so it
is not shown: for spells whose animation is drawn by the effect the panel says
so. Not all combinations will work together the way one might expect, so it
can still be a case of trial and error.

The preview plays the sequence on its own, centered on a plain dark background.
The game also mirrors some animations depending on who is casting, and draws
the effect on top, so what you see in battle can differ in position and
orientation from the panel. The panel pauses while a pick list is open. Large
(screen-wide) animations are shown at actual size and may be cropped; small
ones are enlarged.

In addition, there are certain spells which have hard-coded components
(particularly the summons). Thus, if you change one of these with the editor,
the result may or may not be quite what you were expecting.

Even though monster techniques are considered the same kind of object, there
are parameters in other menus that expect a spell that is not a monster
technique, so often the menu provided in those situations will only list the
player spells.

The elemental/status properties of spells refer to a chart of combinations of
elements and statuses. You can edit which entry in the chart the spell is
associated with, and/or you can change what combination of elements and
statuses a particular entry in the chart is associated with. Keep in mind
when you do this that any other spells or items with that element/status
index will likewise be affected. Note also that for "status healing" effects,
the statuses that are lit up are the ones that the effect DOES NOT remove.
The darkened/disabled statuses are the ones it will remove.

How the Spells, Weapons, Armor and Medicines editors work. The list is on the
left and every box of the selected entry is on the screen at once. Enter on the
list moves the cursor straight into the boxes (there is no "pick a category"
menu), and a hint line at the bottom says what Enter does on the line you are
on. The boxes have a number in their title:

    UP, DOWN, LEFT, RIGHT: Move in the box; at its edge the cursor goes on to
                     the next or previous box.
    TAB, 1 2 3 ...:  Next box / jump to the box with that number.
    ENTER, SPACE:    Change the line: a flag is switched on and off (yellow
                     is on), a number or name is typed, anything else is
                     picked from a list. Changes are stored at once.
    LEFT, RIGHT on a set number: step the number of the element/status or
                     equip set (or the stat bonus pair).
    PAGE UP/DOWN:    The same line of the previous / next entry.
    ESC:             Back to the list.

A "set number" (element/status, equip) is shared by everything that has the
same number, so changing the flags under it changes all of them.

Spell boxes. 1 Name (6 letters for the player spells, 8 for monster
techniques). 2 Information: the effect (what it does), target, power, hit
chance, delay (casting time), MP cost, whether it can be reflected, whether it
can hit bosses, and the impact and damage switches. 3 Animation: the sound
effect, the palette, the sprites, the sequence and the effect (see above for
what the last four do). 4 Element/status: the chart entry and its flags.

SPELL SETS
----------

Each spell set has associated with it a set of starting spells and a set of
learned spells. The starting spells are simply a list of spells, but the
learned spells have both a spell and a level at which it is learned.

The list of spell sets shows the starting and learned spells of the selected
set beside it. Enter opens the set in one screen with the two lists side by
side (up to 24 spells each), and everything is done on the line the cursor is
on:

    ENTER:           On a spell: the menu of that line (change the spell, for a
                     learned spell change the level, add a spell after it,
                     remove it, clear the list, undo). On the green "Add a
                     spell" line at the end of each list: add a spell there
                     (a learned spell asks for the level first and then goes
                     in level order).
    TAB:             Switch between the starting and the learned list.
    ARROWS, PAGE UP/DOWN, HOME, END: Move in the list.
    ESC:             Back to the list of sets.

The menu shows a shortcut beside each action, and the shortcuts work on their
own: INSERT or A add, DELETE or D remove, C clear the list (asks first), LEFT
and RIGHT (or MINUS, PLUS) change a learned spell's level by one, CTRL+Z undo
(kept until you leave the set), 1 2 jump to a list.

The ROM has a fixed amount of room for the lists of all spell sets together;
when it is used up, adding says so until you remove a spell from any set.

If you mix spell "colors" (black, white, summon, etc) of learned spells in the
same spell set, it may not work the way you're expecting. Each character can
have up to three separate spell sets. If they learn a white spell, then it
will go into the spell set associated with their "white" magic set regardless
of which set was associated with the learning of that spell. Deciding which
spells are which color is not done by the presence or absence of the
corresponding orb symbol in the name of the spell, but rather by the index of
the spell in the spell list (e.g. the first 24 spells are white no matter
what their names are; this range can also be altered in the Features Editor).
There is a patch available on romhacking.net that modifies the game code to
instead read the name of the spell and only consider spells whose names
start with the white orb symbol to be white for the purposes of assigning
them to spell sets.


FEATURES
--------
The game applies certain properties to a range of item indexes rather than
on an item-by-item basis. Some examples would be, which items are considered
weapons, which are armors, which armors can be equipped in which slot,
which weapons are two-handed, which items can be used in battle, or outside
of battle, etc.

To change a range, select the item in the "from" column and change it to the
item you wish to be the first item with that property, then select the item
in the "to" column and change it to the item you wish to be the last item
with that property.

In addition to the ranges, the game expects there to be two other items with
"key item" status. These are listed below the regular key item range, and
although there is one in the "from" column and one in the "to" column, these
do not define a range, they are simply two individual items that will have
key item status in addition to the items in the key item range.


WEAPONS
-------

When editing who can equip a weapon, there is a chart of different
combinations of jobs. Each weapon has associated with it an entry in this
chart. You can change which chart entry a given weapon is associated with,
and/or you can change the combination of jobs that a particular chart entry
is associated with. If you do this, remember that it will affect all items
with that equip index.

When editing stat bonuses, you can set which stats will get a bonus and which
will get a penalty. Then you can select from a chart of possible
bonus/penalty pairs.

Weapon boxes (keys as in the Spells editor). 1 Information (name, price,
attack, hit percentage, description), 2 Element/status, 3 Stats (the bonus and
penalty pair and the stats it applies to), 4 Races, 5 Properties, 6 Equip (the
set number and who can equip it), 7 Visuals (palette, sprite, swing and slash
used when it attacks) and 8 Casts (the spell it casts when used, with its
power and visual).

The eight properties are the flags of the weapon's first data byte. Their names
come from the disassembly (everything8215/ff4) and are kept in
config/weaponproperties.dat: 1 No Critical, 2 Unknown, 3 Hammer, 4 Unknown, 5
Lit Arrow, 6 No Back Row Penalty, 7 Can Throw, 8 Magnetic. Only two were
checked in the game code: No Back Row Penalty (the damage is not halved from
the back row) and Magnetic (the weapon counts as metal for the Magnet effect).
The disassembly itself calls flags 2 and 4 "Unknown". The hint line says this
when the cursor is on a flag.

A "Weapon sprite" panel at the bottom right of the Weapons screen draws the
weapon's sprite twice, enlarged: as it is held and as it looks at the other end
of its swing. It uses the weapon's own palette and sprite, so it changes as you
move through the weapon list and as you change the Palette or Sprite in the
Visuals box (the Swing and Slash choices do not change the picture). Sprites
are numbered 0 to 25; a sprite or palette number outside that range shows "No
preview" in the panel.


ARMOR
-----

The armor fields are more or less the same as the weapons, but with fewer
properties to edit. Which armors go in which equip slots (Head, Body, etc)
can be changed in the Features Editor.

Boxes (keys as in the Spells editor). 1 Information (name, price, defense,
evade, magic defense, magic evade, whether it is metallic, description), 2
Element/status, 3 Stats, 4 Races and 5 Equip (who can equip it).


MEDICINES
---------

Medicines are the name I've given to items that cannot be equipped but can be
used in battle for some kind of effect.

Boxes (keys as in the Spells editor). 1 Information (name, price, visual and
description), 2 Effect (the same lines as a spell's Information) and 3
Element/status.


TOOLS
-----

Tools are the name I've given to items that can neither be equipped nor used
in battle. They only have a use on the menu screen, if indeed they have a use
at all. Some are only plot items such as the package given to you by King
Baron.

Fields. Name, price and description.


SHOPS
-----

Here you can edit the contents of the game's shops. The names of the shops
are not stored in the rom, but there is a config file which you can use to
change the names of the shops for your own conveneince.

There is no limitation on the types of items that can appear in a shop. Any
shop can have any combination of items. The only limitation is that there is
a maximum of eight different items that can be for sale in the same shop.


JOBS
----

Here you can edit the names of the jobs and which spell sets they are
associated with. Chaning the name of a job here will change its name in all
the menus in the other editor components.

Characters can have different spell sets in battle and out of battle if
desired, and the names of the spell colors (black, white, call) can be
changed as well. Changing the name of a spell color will change it for
all characters, and will not change the name of the corresponding menu
command in battle.

Fields. "Edit name" changes the job's name. "Edit spell set links" chooses the
black, white and call spell set the job uses in battle and in the menu. "Edit
spell set names" renames the spell sets themselves.


MONSTER SPRITES
---------------

"Edit Monster Sprites" (in the Battles group, after Edit Monsters) edits a
monster's picture and palette in the editor. Pick a monster and press Enter.
The screen shows the picture large with a cursor, the picture at actual size
and the palette (8 colors, 16 for Zeromus's last form and the Dummy; color 0 is
transparent). The size of a monster is not changed here (Edit Graphics in the
monster editor does that). Party members used as enemies are edited in the
Battle Sprites editor. Bosses show their tile map cells; cells that are empty in
the map are dark red and cannot be painted, and a tile used in several cells
changes in all of them. Esc stores the picture and palette straight into the ROM
image, like the BMP import, so every monster sharing the graphics or palette
changes too (the screen says how many) and Ctrl-R revert in the monster list
does not undo it, but Ctrl-R in the sprite editor does.

Every action has a menu, so no key has to be learned: Enter opens a menu of all the actions with the key of
each one beside it, and Space paints. The keys below are shortcuts for the same
actions.

    Arrows:         Move the cursor      Home / End: first / last row
    ENTER:          The menu of every action
    0 - 9:          Paint with that color (and make it the brush)
    SPACE:          Paint with the brush
    [ or Minus / ] or Plus:  Previous / next brush color
    F:              Fill
    X / Y:          Flip horizontally / vertically (plain monsters only)
    Ctrl-Z:         Undo       Ctrl-R: Revert the picture to the loaded ROM
    P:              Edit the palette colors (Left Right pick a color, Q A red,
                    W S green, E D blue, Ctrl-Z undo, Ctrl-R revert, Esc back).
                    Bracket keys move the color left or right in the palette
                    and renumber the pixels of every monster that uses the
                    palette, so they all look the same. Recolors (monsters
                    that draw the same tiles with another palette) get the
                    same two colors swapped in their palettes.
    O:              Sort the palette the usual way for monsters: color 0
                    transparent, 1 black (the darkest), 2 white (the lightest)
                    and the rest from light to dark. All monsters that use the
                    palette, and their recolors, are renumbered so none of
                    them changes. Not done for 16 color art, nor for a palette
                    that 16 color art uses.
    E / I:          Export / import the picture as a BMP, see below
    PgUp / PgDn:    Previous / next monster
    Mouse:          Click and drag paint, right click picks the color under the
                    pointer, click a palette swatch to choose the brush

E writes exports/monster_sprites/monster_NNN_Name.bmp and I reads it back. The
BMP is as wide and high as the monster's tiles and its own color table is the
monster's palette: entry N is color N (color 0 is the transparent one) and a
pixel's value is its color number. On import the color table becomes the palette
and the pixels keep their values, so edit the picture in an image editor that
keeps the BMP indexed (4 or 8 bits per pixel) and does not renumber the colors.
A pixel above the last color (7, or 15 for the 16 color art) is rejected. Older
images one pixel wider, with the palette as pixels in the top right corner, are
still read. Bosses export their tile map cells (empty cells stay blank); if one
tile appears in several cells and they were edited differently, the first cell
wins and the import says so. Importing also changes every monster that shares
the graphics or palette. After an import the palette is sorted the usual way
(the same as the O key: 1 black, 2 white, the rest from light to dark), so the
color numbers in your image do not have to follow that order; the message says
if the palette was sorted or left alone. Zeromus's last form and the Dummy have 16 color art
(the game checks the graphics pointer: below 8000h means 4 bits per pixel, using
the palette and the one after it): their images have 16 colors and importing
also rewrites the following palette.

PORTRAITS
---------

"Edit Portraits" (in the Party group, after Edit Battle Sprites) edits the 17
faces the game shows in the status, item, magic and equip menus: Cecil, Kain,
Rydia and the others, plus the Pig, Small and Toad pictures. Pick a portrait
and press Enter. Each portrait is 32x32 pixels with 8 colors (color 0 is
transparent). The screen shows the picture large with a cursor, the picture at
three sizes, every portrait small, and the palette.

Every action has a menu, so no key has to be learned: Enter opens a menu of all the actions with the key of
each one beside it, and Space paints. The keys below are shortcuts for the same
actions.

    Arrows:         Move the cursor
    0 - 7:          Paint with that color (and make it the brush)
    ENTER:          The menu of every action
    SPACE:          Paint with the brush
    [ or Minus / ] or Plus:  Previous / next brush color
    F:              Fill the area of the cursor's color with the brush
    X / Y:          Flip horizontally / vertically
    Ctrl-C / V:     Copy / paste the whole picture
    Ctrl-Z:         Undo
    Ctrl-R:         Revert this portrait to the loaded ROM
    , and .:        Look at the picture with another palette
    P:              Edit the palette colors (Left Right pick a color, Q A red,
                    W S green, E D blue, Ctrl-Z undo, Ctrl-R revert, Esc back)
    [ and ] in the palette editor:  Move the color left or right in the
                    palette; the pixels follow, so the picture looks the same
                    (the portraits that use the palette are renumbered; undo
                    history is cleared).
    PAGE UP/DOWN:   Other portrait
    HOME / END:     Cursor to the first / last row
    ESC:            Back

The game uses the palette with the same number as the portrait, and the Pig,
Small and Toad pictures take the palette of whoever was transformed, so changing
palette 3 recolors every picture shown with it. The editor starts each portrait
with its own palette number (Pig 14, Small and Toad 15).

Palette colors have usual meanings, shown as short tags under the palette and
named on the "Editing palette" line. Portraits: 0 transparent, 1 white, 2 skin,
3 skin shadow (the other colors are free: hair, clothes, ...). Keep these
numbers when you recolor or reorder, because the game does not care but your
own images, and the next person using the palette, will.

The last two list entries export and import portraits as BMP files,
portrait_NN_pal_PP.bmp in exports\portraits, one per portrait. Each asks for
all portraits or just one. While editing a portrait, E exports it and I imports
it (with the palette shown, and PP in the file name tells which palette to set). They are 32x32 indexed images
whose own color table is the palette: entry N is color N and a pixel's value is
its color number, so your image editor must not renumber the colors (move a
color with the bracket keys in the palette editor instead). A pixel above color
7 is rejected. Import also sets palette PP (colors 1 to 7), so several files
that name the same palette must agree on its colors. Older 33x32 files that
store the palette as pixels in the top right corner are still read. Like
everything else it only changes the in-memory data until Save ROM.


FIELD SPRITES
-------------

"Edit Field Sprites" (in the Party group, after Edit Portraits) edits the walking
sprites of the party and of the NPCs on the maps. The list holds the 107 sheets,
named as in config\npcsprites.dat, and the window next to it shows every frame of the
selected sheet four times as large, at real size and double size, the palette, the
size of the sheet (8, 4, 2 or 1 frames of 16x16) and where it starts in the ROM.
"NPC numbers" are the NPCs of the NPCs editor whose sprite is this sheet; the same
sheet is used by many NPCs. The sizes are fixed in the ROM (the bank is full), so
only the pixels and the palette colors change, never the number of frames.

Enter on a sheet opens the editor: the picture of the whole sheet, with its frames
four to a row, is painted pixel by pixel. Arrows move, 0 to 7 paint with that color,
Space paints with the brush color, F fills, X and Y flip the frame under the cursor
(a left facing frame from a right facing one), Ctrl-C and Ctrl-V copy and paste a frame
(to another sheet too), Ctrl-Z undoes, Ctrl-R reverts the sheet, PgUp and PgDn change
sheet, P edits the palette colors (Q A, W S, E D change red, green and blue of the
color picked with Left and Right) and Comma and Period change the palette. Enter
opens a menu with every action and its key. E and I export and import the sheet.

A sheet has no palette of its own. There are 36 palettes of 8 colors. The game
draws the party sheets (0 to 13) with the palette of a fixed table, 0 to 3. Any
other sheet takes its palette from the NPC placement on the map: a placement has
a palette 0 to 3 that picks one of the two palettes of each of the two numbers in
the map's NPC palettes (Edit Map Info), so the same sheet can have other colors on
other maps. The window shows which palettes the maps use a sheet with ("Maps use
it with: 14 x5, 13 x4" is palette 14 on 5 placements and 13 on 4) and the editor
starts with the one used most. You can pick any other palette for a sheet (Comma
and Period, or the Choose the palette menu entry, which also shows how many
placements use each palette), the editor remembers the choice for next time in
config\fieldpalettes.dat (lines "NNN PP", delete one to forget it) and "Use the
palette of the maps" goes back to the usual one. The choice only changes what you
see and what a BMP export uses, nothing in the ROM. Changing a palette color
changes every sprite that is drawn with that palette, and color 0 is always
transparent. The palette editor can also rearrange the colors: the bracket keys
move the picked color left or right, and the menu entry "Swap it with another
color" swaps it with any other. A swap keeps every sprite looking the same by
renumbering its pixels, and because a sheet can be drawn with several palettes
the same two colors are swapped in all the palettes that belong together (it asks
first and says how many palettes and sheets it touches, often most of the NPC
ones) and clears undo.

The last two list entries export and import BMP files, field_NNN_pal_PP.bmp in
exports\fieldsprites, for all sheets or one. The picture is the sheet with its frames
four to a row (64x32 for a sheet of 8 frames) and the color table of the BMP is the
palette: entry N is color N and a pixel's value is its color number, so your image
editor must not renumber the colors. Import also sets the colors 1 to 7 of palette
PP. Like everything else it only changes the in-memory data until Save ROM.


BATTLE SPRITES
--------------

This editor (in the main menu right after Edit Jobs) edits the sprites the
characters use in battle: Cecil, Kain, Rydia and the others, plus the frog. Pick
a character and press Enter. The screen shows the character's 64 tiles on the
left, the selected pose large in the middle and all thirteen poses (the Special pose included) small below it,
so you can see every pose change as you edit. A tile can be shared by several
poses (the head and body tiles are used by up to five), so changing one tile
changes each pose that uses it.

Every action has a menu, so no key has to be learned: Space on the tile sheet,
and Enter while editing a tile or the palette, opens a menu of all the actions
with the key of each one beside it. The keys below are shortcuts for the same
actions.

On the tile sheet:

    ARROWS:        Move among the tiles.
    ENTER:         Edit the selected tile pixel by pixel.
    SPACE:         The menu of every action.
    PAGE UP/DOWN:  Change the pose shown in the middle.
    , and .:       Change which palette is used to display the sprite.
    P:             Edit the palette's colors.
    [ and ] in the palette editor:  Move the color left or right in the
                   palette; the sheet's pixels follow, so the sprite looks the
                   same (undo history is cleared).
    CTRL+C / V:    Copy and paste a whole tile.
    CTRL+Z:        Undo.
    CTRL+R:        Revert the whole sheet to the loaded ROM.

Editing a tile:

    ARROWS:        Move.
    0-9, A-F:      Paint with that palette color.
    SPACE:         Paint with the current brush.
    ENTER:         The menu of every action.
    [ or -, ] or =: Previous / next brush color.
    X / Y:         Flip the tile horizontally / vertically.
    CTRL+C / V / Z: Copy, paste, undo.

Editing the palette: ENTER opens the menu (choose the color, change its red,
green or blue, move it, undo, revert). LEFT/RIGHT pick a color, Q/A raise/lower red, W/S green and
E/D blue (each channel has 32 levels, as on the SNES), CTRL+Z undoes and CTRL+R
reverts the palette. Color 0 is transparent in the game and cannot be edited.
The battle sprite graphics are stored uncompressed in fixed-size blocks, so
there is no risk of running out of room. The characters' palettes may be used
by other parts of the game as well, so recoloring one can change it elsewhere.
Golbez and Anna, whose sprites use a different layout, and the tiny Mini and
Toad forms are not included.

Palette colors have usual meanings, shown as two letter tags under the palette
and named on the "Editing palette" line: 0 transparent (Tr), 1 black (Bk), 2
white for the eyes (Wh), 3 skin (Sk), 4 skin shadow (Sd), 8 eye color (Ey). The
other colors are free (hair, armor, ...). Keep these numbers when you recolor,
reorder colors or import an image, so that the characters stay consistent.

Export and import. The last two entries of the character list write and read
one BMP per character (each asks for all characters or just one; in the tile
sheet, E exports the character being edited and I imports it) in the `exports/battle_sprites` folder next to the editor,
named `poses_NN_pal_PP.bmp` (NN is the character sheet, PP the palette). Each is
a 112x48 image with 4 bits per pixel, so it opens in any editor that supports
indexed color (Aseprite, GIMP, GraphicsGale, ...). The poses are packed together
in the order the game uses them:

    Row 1:  Standing, Ready, Running, Kneeling, Right arm up, Left arm down,
            Left arm up (16x24 pixels each)
    Row 2:  Hit, Victory, Dead (24 wide), Chant 1, Chant 2, Special (24 wide)

The one tile that no pose uses sits in the empty corner under the Special pose.
The palette is the image's own color table: entry N is the palette's color N
and a sprite pixel's value is its palette color number. On import the table
becomes the palette and the pixels keep their values, so your image editor must
not renumber the colors (to reorder them, use the bracket keys in the palette
editor instead). A pixel above color 15 is rejected. Older 113x48 files that
store the palette as the 16 pixels in the top right corner are still read; there
every other pixel takes the number of the palette pixel of the same color.
Colors are rounded to the SNES's 32 levels per channel. Images may
be 4 or 8 bits per pixel and uncompressed. Each bad file is skipped with a
message and the others still import; import only changes the in-memory data, so
use Save ROM to keep it.

Because poses share tiles, importing can find a tile that was drawn differently
in two poses. The pose you changed wins; if two poses changed it differently,
the first one in the list above wins and you are told which tile it was.


CHARACTERS
----------

A character basically consists of a set of starting data and a set of levelup
data. It is also associated with an inital "actor". An actor is what you
might intuitively think of as a character in the game; it has a name, battle
menu, starting equipment, and a link back to its associated character (the
starting stats and levelups).

The starting data also has the critical hit rate (a percentage, 0 to 99) and the
critical hit bonus (0 to 255) of the character. A critical hit is a random number
below the rate, and it adds the bonus to the damage. Equipment changes them in
battle (a bow triples the rate). A game that is already saved keeps the values it has.

The levelups from the character's starting level to level 70 each consist of
a set of stats which will increase, the amount by which they will each
increase, a Max HP bonus, a Max MP bonus, and an increase in the amount of
experience the character needs to advance to the next level (henceforth
referred to as TNL).

"Edit level up data" opens a full screen table with one row per level, from the
character's starting level to 69. Instead of stepping through the values in a
fixed order, the cursor moves from cell to cell, so any value can be reached
directly. The columns are the five stat flags, the amount (-1 to 6), the HP
bonus, the MP bonus and the TNL.

    ARROWS, TAB:       Move between cells (Tab wraps to the next row).
    PAGE UP/DOWN:      Move a page. HOME / END: first / last level.
    G:                 Go to a level number.
    N / P:             Switch to the next / previous character.
    ENTER:             Toggle a stat flag, cycle the amount, or edit a number.
    0-9:               Type a number (stat: 1 on, 0 off; amount: 0-6). ENTER or
                       any movement key accepts it, ESC cancels it.
    MINUS / PLUS:      Change by 1 (stat: off / on).
    COMMA / PERIOD:    Change by 10, or by 100 for the TNL.
    SPACE:             Toggle a stat flag.
    D:                 Copy this cell from the row above.
    F:                 Fill this cell's value down the rest of the table.
    CTRL+C / CTRL+V:   Copy and paste a whole row.
    CTRL+Z:            Undo the last action (a fill or a paste counts as one).
    ESC:               Back to the character list.

Beside each level's gains the table shows the character's total stats, HP, MP
and experience after that level up, worked out the way the game does it. A row
is used when the character goes from that level to the next. Each flagged stat
gets the amount added (a stored amount of "-1" subtracts 1), never above 99 or
below 1. HP and MP get the listed bonus plus a random 0 to 1/8 of that bonus,
never above 9999 HP or 999 MP, so the HP and MP columns show the smallest
possible total and the footer for the selected row shows the full range. The
experience total starts from the "TNL" in the character's starting data (the
experience already needed for their starting level) and adds each level's TNL.

After level 70, the character's HP, MP, and TNL bonuses will be identical to
those of their final levelup. Their stat bonuses, instead of being fixed,
will be randomly selected from a group of eight stat bonus combinations, each
of which has a set of stats to increase and an amount by which to increase
them.

"Edit after 70 data" opens a full screen table of those eight combinations, one
per row, with the five stat flags and the amount (-1 to 6). A column in words
says what each combination does, and below the table you see the average gain
of every stat per level up (the eight combinations are equally likely) and the
HP, MP and TNL bonuses that are repeated from level 69.

    ARROWS, TAB:       Move between cells (Tab wraps to the next row).
    HOME / END:        First / last combination.
    ENTER, SPACE:      Toggle a stat flag, or cycle the amount.
    0-6:               Set the amount (stat: 1 on, 0 off).
    MINUS / PLUS:      Change by 1 (stat: off / on).
    D:                 Copy this cell from the row above.
    N / P:             Switch to the next / previous character.
    CTRL+C / CTRL+V:   Copy and paste a whole combination.
    CTRL+Z:            Undo the last action.
    ESC:               Back to the character list.


COMMANDS
--------

You can change the name of any command, but you can only change the
parameters of certain commands. The more that gets discovered and posted
about the locations of various features of the commands, the more I will be
able to expand this component of the editor.

The command editor has three parts. Ranges sets the item ranges that three
of the commands (the ones that need a particular kind of weapon) are limited
to. Information has the command's name, target, delay index, the persistent
and temporary statuses that disable it, and the waiting and acting stances.
Parameters shows the details that go with the command if it has any that can
be edited (for example base values, multipliers and the stats and elements
involved). Fight, Kick, Dark Wave and Throw have their damage formulas
here, and Regen the ticks between its heals; the Battle Formulas editor is for
what is not one command's own (spells, the stats of the party, statuses,
and timers).

The menu you get with Enter on a command also has two entries that are about
all commands. "Overview of all commands" is one screen with every command: its
target, its delay, how many actors have it in their command list and what has
changed since the ROM was loaded (name, target, delay, statuses, stances,
parameters or code settings). Rows with changes are yellow, typing letters
jumps to a command, and Enter closes the overview and goes to that command in
the list. The Commands list marks a command as changed for any of these changes,
not only the name, target and delay. "Internal command names" edits the four
names after the 26 commands, which the battle shows for Change row, Defend and
two commands the game uses itself (Chang, Parry, Show and Off in the original).

The delay index on the Information screen is how long a unit waits after
choosing the command before it acts, and the screen says what the value means:
0 is no wait, 1 to 127 is 1/value of the unit's turn timer (1 is a whole turn
timer, 2 is half, and so on), and 128 and up is the value minus 128 whole turn
timers. The game reads this only for commands chosen from the command menu.
Item and the spell commands (White, Black, Call, Ninja) use the delay of the
item or spell instead, and Jump always waits the ticks set on its Parameters
screen, so the screen shows their value as not used.

Recall has two switches next to its message, both found in the battle code.
"Needs the spell's MP" is the game's own check: Recall picks a random spell and
does nothing at all, without a message, when the user has less MP than that
spell costs. "Takes the spell's MP" is whether the MP is taken after the cast.
With the check off but the cost on, the spell fails with the game's "not enough
MP" message when the MP is short. With both off, Recall is free. Either one is
shown as custom code, not changed, if other changes have altered those bytes.

Jump and Throw have the message shown when they fail. Jump also has the ticks
it waits before leaving and the ticks it stays in the air (4 each in the
original game; a tick is the game's smallest timer step).

Fight has the elemental multipliers (extra weak, weak, immune, resists), the
race multipliers (hurts race, resists race) and the two stats used to work out
the chance of adding a status: the attacker's stat minus the target's stat. A
multiplier of x1 is the normal damage. Aim, Jump (when it lands) and Focus (its
attack) run the same routine, so these apply to them as well. Kick, Dark Wave
and spells have their own formulas.

Only the multipliers x0, x0.5, x1, x2, x3 and x4 work in the original game: its
damage routine shifts the stored number right before using it, so x1.5, x2.5
and x3.5 act as x1, x2 and x3. The "Half steps" line on the Fight screen
replaces that routine with one that multiplies by the whole stored number and
then halves the result. For every multiplier the game uses (x0, x0.5, x1, x2,
x4) the damage is exactly the same as before, and x1.5, x2.5 and x3.5 become
real. The routine is shared by every attack and spell, so it changes the damage
code for all of them, but nothing in the game uses a half step by itself, so
nothing changes until you pick one. With Half steps off the picker offers only
the six working multipliers, and a half step already in the ROM is shown as
"acts as" the whole step it really does.

The "Attacker is cured of" line on the Fight screen is the list of temporary
statuses that the attacker loses when its attack hits. In the original game
that is Charm only: a charmed unit that attacks is cured by the blow (nothing
happens if the attack misses). Enter opens the list of the eight temporary
statuses (Calcify 1 and 2, Berserk, Charm, Sleep, Stun, Float, Curse); the ones
shown in yellow are removed. Pick none to make Fight cure nothing. Like the
multipliers, Aim, Jump (when it lands) and Focus run the same routine, so they
cure the same statuses. Only the one byte of the game's code that holds the
list changes. The line says custom code, not changed, if other changes have
altered that code.

Dark Wave: the HP the user loses (1/2 to 1/64 of max HP, or none; the
original is 1/8) and the damage to undead targets (full, half, or the original
quarter). Kick: the attack multiplier used (half, the original, full, or
double). Both have "Base damage, both": Kick and Dark Wave work out damage
with the same instructions (attack multiplier times attack power, divided by
2, plus a random amount), and this setting scales that part: x0.25, x0.5
(original), x1, x1.5, x2, x3, x4 or x8. It changes both commands, so the two
screens always show the same choice. The original code has room for only x0.5,
x1 and x2. For the others the editor writes a short routine of its own into
the unused bytes at the end of the battle code bank and makes the damage
calculation call it, and the result stops at 65535. Choosing x0.5, x1 or x2
again puts the original code back and clears the routine.

Throw (dart): on its Parameters screen, under the failure message, the damage is the thrown item's attack power times one of the
user's stats (the level in the original game) plus a random amount, at most
9999. You can pick the stat, whether the random amount is 0 to 98 (original),
none or 0 to 255, and the largest damage (1 to 9999).

Steal (Sneak) has the base chance, the stat of the user that is added and the stat
of the target that is taken off, which item of the monster is stolen, and its three
messages. The chance is the sum in percent, at least the lowest chance (1) and at
most the highest chance (99); both can be changed. When a steal fails the monster
may catch the thief: the chance is the target's level plus 10, or a fixed
percentage, and a caught thief loses 1/2, 1/4, 1/8, 1/16 (original), 1/32 or 1/64
of its max HP. The four rows of the chance show custom code, not changed, if other
changes have altered those bytes.

Charge, Twin and Regen have one more value each, which is an entry of the
game's action delay table that the Information screen does not list because
no command number points to it: Charge's wait before the attack, Twin's wait
for the second cast and how long Regen lasts. A value of 0 means no wait, 1 to
127 means 1/value of the unit's turn timer (1 is a whole one) and 128 and up
means that many turns after subtracting 128 (the original Regen is 138, ten
turns).

Peep has a code setting too: it skips bosses, and the setting lets it work on
them.

Aim works by saving one stat of the target and one of the user, setting the
target's to 0 and the user's to 255 for the attack and restoring them
afterwards. In the original game they are the target's evasion (listed as
Physical defense rate) and the user's hit rate. The Aim screen lets you pick
which stat each side uses (the same list as Cry and Steal) and whether it is
set at all or left alone.

Boast (Bluff) and Cry have an "Effect" line that reverses them. Boast raises a
stat by its amount up to 99; reversed it lowers it and stops at 0. Cry lowers
a stat by half the user's and stops at 1; reversed it raises it by that
amount up to 99. If other changes have altered that code the line says
"custom code, not changed" and leaves it alone.

Cry also has a "Works on" line: all enemies (the original game) or all allies. Cry
goes through the units on its own and ignores the target set for the command, so
this line is the only way to change who it works on. With all allies it lowers
the chosen stat of every party member present, the user included, by half the
user's stat. Boast always works on its user, whatever its target is.

Command 22 (named "Dummy") is not used by the original game. Its Parameters
screen has "Behaves like": pick another command and 22 runs that command's
routine and animation in battle, so you can give it its own name, target,
delay, disabling statuses and wait stance (they start as a copy of the chosen
command's). Give it to an actor in the Actors editor to use it. Two limits
come from the game code: the routine's parameters are shared, so a change to
Sing's spells also changes this command, and the banner shown during the
action still carries the original command's name. White, Black, Call and
Ninja cannot be chosen because the spell menu runs them, not a routine. Type
a few letters in the list to jump to a command.

Commands such as Sing and Fight have "If" lines that test one byte of the
battle properties of the unit that uses the command (128 bytes each, the list
is in the order of those bytes). Their names come from the disassembly
(everything8215/ff4, the battle code and its RAM map): bytes the game reads are
named after what it does with them ("Base critical hit rate", "Action type
flags", "Action data pointer", ...), and the others are listed as "Unused byte
NNh" because nothing in the game uses them.


BATTLE FORMULAS
---------------

This editor has the formulas and numbers the battle uses that are not the
settings of one command (those are in the Commands editor, under Parameters). The list on the left
has a line for each group, in this order: the spells (Spell damage, Armor and Shell, Dispel and Black Hole, the
Summon Book); the stats of the party (Party stats, First slot bonus, Back row); the statuses (Weakening
statuses, Status adjustments); the Timers; and the Battle start. The settings of the highlighted
line are shown on the right, and Enter on a line changes them (Esc goes back).
A line of the list that has changes is yellow. Ctrl-R puts the highlighted line
(or the line whose menus or page are open) back the way it was when the ROM was
loaded, after asking, Ctrl-Z undoes the last change, and Space opens a menu with
both, so no key has to be learned. Most of
them are not data bytes but small pieces of the game's code: the editor swaps
a few bytes for another known sequence of the same length (found in the battle
code of the disassembly, everything8215/ff4), and offers only those known
sequences. If other changes have altered those bytes the setting says custom
code, not changed, and the editor leaves it alone until you pick one of the
choices. Nothing here changes the game until you pick something other than the
original choice, and nothing is written until Save ROM.

Spell damage: the base damage of a spell is its power times 4 (times 8 for a
summon) plus a random part of up to half of that. It is multiplied by the hits
that land: each cast tries a number of hits, (the caster's stat divided by 4)
plus 1, and each try lands at the spell's hit rate. The stat is Wisdom for
black magic and summons and Will for white magic. Summons and spells cast from
items skip the tries and always count 8 hits. The settings are the power scale
of spells (x4, x2 or x1) and of summons (x8, x4, x2 or x1), the divisor of the
stat for the tries (2 to 64), which two stats are used (black magic, then
white magic: Strength and Agility, Agility and Vitality, Vitality and Wisdom, or
Wisdom and Will, the original), which is also the stat of the hit rate, and
the number of hits of summons and spells cast from items. The base damage, the
random part and the damage cap are shared with the other formulas.

Armor and Shell: Armor (also called Protect) adds a number to the defense of the
target and Shell adds one to its magic defense, 5 and 3 in the original game.
Each cast adds them again, up to 255, and the numbers can be changed (0 to 255).
Any spell given the same effect in the Spells editor does the same, and so does
the Brace command, which casts Armor. The game makes both do nothing in the
final battle with Zeromus (battle number 01B7); the two Zeromus lines switch that
off, so they work there too.

Effect 29: the game has two copies of the Count (doom) effect, 28 and 29, and
effect 29 is never used. The last line of the Armor and Shell page turns it into
an effect that works like Armor: it raises or lowers one stat of its target by a
number (0 to 255, stopping at 255 or 0), for the rest of the battle. The stats
are the attack multiplier, hit rate, attack power, magic def multiplier, magic
def rate, magic defense, defense multiplier, defense rate, defense, critical
rate, critical bonus and the modified strength, agility, vitality, wisdom and
will. Give a spell effect 29 in the Spells editor, where the
effect is then named Change a stat. The routine goes in free space at the end of
bank 3 (1FEE3 to 1FEFA) and the effect's entry of the jump table points at it;
switching it off puts both back.

Dispel and Black Hole: two spell effects that take statuses off their target.
The window lists the statuses with a column for each effect, and Enter on a
cell switches removes and keeps. The statuses are curse, float, paralyze, sleep,
charm, berserk, HP leak (sap), reflect (Wall), barrier and image (Blink). The
original Dispel removes berserk, HP leak, reflect, barrier and image, and the
original Black Hole removes float, berserk, reflect, barrier and image. Black
Hole also puts the speed of the target back to normal, which ends haste and
slow, and that can be switched off. Every spell that has the effect in the
Spells editor does it (Disrupt and Blk.Hole use Black Hole). The petrify, hide,
cover and low HP bits are not offered. A cell shows ? if other changes have
altered the code of the effect.

Summon Book: the item of that name calls one of ten summons at random. Each
has its summon and whether it hits all targets or one random target.

A spell cast from a weapon also skips the tries and counts a fixed number of
hits: the weapon's Power, which is in the Casts box of the Weapons editor.


Party stats: how the game works out the stats of the party members when a
battle starts (monsters have stats of their own that are stored with them and
are not changed here). Enter opens one screen with the formulas written out,
for example "Attack multiplier: STR / 8 plus AGI / 16 plus 1", where the fields
in yellow can be changed: move with the arrows (or click), Enter picks another
stat (level, STR, AGI, VIT, WIS or WIL), another divisor (1, 2, 4, 8, 16, 32 or
64) or another number. The formulas are the attack multiplier, the attack
power, the attack hit rate, Yang's attack power (level x 2 plus STR / 4 plus 2,
Yang is special in the game), the defense multiplier (level / 16 times the
shield's multiplier plus AGI / 8), the defense (VIT / 2), the magic defense
multiplier (the sum of WIS and WIL / 32 plus AGI / 32) and the magic defense
rate (the sum / 8). The terms are added to the weapon and armor values. The
level term of the attack hit rate and attack power is one term, and so is the
strength term of the attack power and Yang's attack, so changing it on one
line changes the other. A field shows ? when other changes have altered that
code, and it is left alone.

First slot bonus: in the original game the unit in the first slot has 25% more of
four rates: the hit rate when it attacks, the evasion when it is attacked, the
hit rate of its spells and the magic defense rate. The first slot is the first
party member and also the first monster (the game ignores which side it is on).
Each rate is multiplied by 5 and divided by 4; the number can be changed from 0
to 10 (4 is no bonus, 8 is double), and so can who gets it: slot 0 of both
sides, only slot 0 of the party, or every member of the party. The magic defense
rate looks at the slot of the attacker in the original game, probably by mistake.
Each rule can look at the attacker or at the target (the attacker for the hit
rates, the target for the evasion in the original game), whatever is looked at,
the same rate is changed: the attacker's hit rate, the target's evasion, the
attacker's spell hit rate or the target's magic defense rate.
The last rule can instead change the magic defense itself, the base that is taken
off the damage (a 16 bit number), which needs a second short routine of its own in
the free space at the end of bank 3 (file offset 1FF80); it is put back to the
original code when the rule is set back to the magic defense rate.

Instead of the slot, each of the four rules can be for the units that have some
status: pick "with a status", then the status list (persistent, temporary,
system or hidden) and the statuses; a unit with any of them gets the bonus (for
example a unit that is Charging), the attacker or the target as chosen for the
rule. With no status chosen the rule is switched off.
This needs a short routine of its own in the free space at the end of bank 3 (file
offset 1FFD0), shared by the four rules; the original code is put back when no rule
uses a status, and a ROM that already uses that space cannot use the option.

Back row: in the original game a unit in the back row has its hit rate halved
when it attacks, and a target in the back row halves the hit rate against it and
has its defense doubled. A unit with the no back row penalty flag (which a bow
gives) or a jumping unit is not affected. The page has a field for each part:
the hit rate of the attacker and the hit rate against the target can be halved,
unchanged or doubled, the defense of the target x0.5, x1 or x2, and the two
exceptions (the flag and jumping) can be switched off for each of the two hit
rate rules. They are for Fight, Aim, Jump and Focus; spells ignore the back row.

Weakening statuses: the statuses that change the damage formulas, written as rules
with the statuses in yellow. In the original game Toad and Mini do all of
these: an attacker with them does 1 attack power and cannot crit, inflicts no
status and uses up no arrows; a target with them takes double the attack power
and has no defense and no defense multiplier. In spells Toad alone makes the
magic defense multiplier of a target 0 (focus does too). Pig changes no
damage in the original game. Each rule has a set of statuses, any of Poison,
Blind, Mute, Pig, Mini, Toad, Stone and Dead, so a poisoned target can take
double damage instead of a mini one, or a pig can be a weak attacker; none
switches a rule off. The attack power of a weak attacker (1) can be changed,
and so can what the attack power of a hurt target is multiplied by (x0.5, x1
or x2) and whether its defense becomes 0. Which statuses stop a unit from using
commands is under Information in the Commands editor, and which spells a Toad
or a Pig can cast is built into the game and not changed here.

Status adjustments: the other places where a status changes the numbers, written as
rules like the ones of Weakening statuses, but each rule can have statuses of any
of the four status lists (persistent, temporary, system and hidden): the status
byte of the rule is changed together with the statuses. The rules are, in the
original game: a blind attacker has its hit rate halved and a blind target its
evasion; berserk adds 50% to the attack power (the 50% is built into the game,
the statuses can change); jump or focus doubles the attack power of the
attacker; curse halves the attack power of the attacker and the defense of the
target; defend doubles and focus halves the defense of the target; in spells a
blind attacker has its hit rate halved and a blind target its magic defense rate,
and a target with focus ignores its magic defense multiplier. The hit rate and
evasion rules can be halved or unchanged, the others x0.5, x1 or x2. Barrier and
Image, which block hits, and the back row, which is not a status, are not here.

Timers: the timers of the battle, on one screen. A tick is one pass of the
battle loop, how long it lasts depends on the battle speed.

The turn wait is how long every unit, monsters too, waits between its actions.
The game works it out as the anchor's agility times 50, divided by the unit's
own agility times 10 (Cecil's agility, in the usual party). The anchor is the
actor that Cover disables if present, else the actor that covers, else the
first party member (both are set under Cover in the Commands editor). The
screen shows it as the top line, and "divided by My AGI x 10 plus 0" below it.
Each number can be changed, "Anchor's AGI x" can be switched to "no anchor" so
that the top line is only a number, and the number added after the
multiplication can be set. For example 750 divided by (My AGI x 1 plus 32) is
a wait that depends on the unit's own agility only. A bigger top number or a
smaller bottom makes everyone slower. Adding a number needs a small routine
that the editor puts in the unused bytes at the end of the battle code bank,
which it clears again when the number is 0.

Count (Doom, the spell that kills after a countdown): the spell's Power, in the
Spells editor, is the number it counts down from. The game steps it down once
every 2 ticks of its timer loop, while poison, stop, sap and the other timers
step on every tick, so Count is half as fast as they are. "Count, doom counts
down once every 2 ticks" changes that 2 (1 is as
fast as the other timers, 99 is very slow); a tick is as long as the battle
speed makes it. "when it ends the unit gets Dead" is the status a unit gets
when its Count reaches 0: dead in the original, or stone, toad, mini, pig, mute,
blind or poison.

Poison, HP leak, and sleep and paralyze: poison takes the max HP divided
by 8 every tick (2 to 64, at least 1 HP) and waits the VIT of a character plus 20
ticks between its ticks (a monster uses its level plus 10 plus 20; petrify uses
the same wait), and both the stat and the 20 can be changed. HP leak takes 2 HP
every tick (the HP and the number of ticks can be changed) and lasts the sum of
the WIS and the WIL of a character times 2 plus 30 ticks (both numbers can be
changed). Sleep and paralyze last (300 minus 4 times
the spirit of the target) divided by 6 ticks, and the 300, the 4 (1, 2 or 4) and
the 6 can be changed.

Battle start: how a battle begins. The game averages one stat of the characters
present and of the monsters present (the level in the original game) and each
side rolls a number that gets it a point if it is below the average (the party
rolls 0 to 99, the monsters 0 to 98). The side with more points wins: the party
gets a first strike, the monsters a surprise attack, and with equal points the
battle starts normally. The winner waits 1 tick before its first action and the
other side waits twice as long as usual. After a surprise a second roll, from 0
to the party's average, can make it a back attack when it is below half the
monster average; a back attack also turns the party around (front row to back,
back to front). A formation can force a back attack (Formations editor), which
waits like a surprise. The roll is not made in a boss battle, when running is not
allowed (a formation flag) or in a battle on the moon. Everything can be changed:
the stat averaged for each side (level, strength, agility, vitality, wisdom or
will), how high the party rolls, whether winning does anything for the party and
for the monsters, when a surprise becomes a back attack (never, below half the
monster average, below it, below twice it, always), the ticks the winner waits,
whether the other side waits twice as long or the normal time, how the waiting
goes in a forced back attack (like a surprise, normal, like a first strike) and
which battles skip the roll. All of these are changes of single bytes in the
battle code, and no routine is needed.


ACTORS
------

An actor has a list of battle commands. It also has a list of starting
equipment. It is possible to assign items to actors' starting equipment that
they would not normally be able to equip, but if you do this, they will not
be able to put it back on if they take it off.

In addition to your regular party of five members that you are familiar with,
there is also something known as a "shadow party", also with a capacity of
five members, where people that leave your party but will be returning go when
they leave. When an actor is added to your party, it can either be loaded
from a particular character's starting data, or it can load current data from
a particular slot in the shadow party.

Likewise, when an actor is removed from your party, it can discard its
character data completely, or it can save it in a particular shadow slot, to
be loaded later by another actor.

Each actor also has a link to a set of levelups associated with a character.
You can change what character a given actor levels up as, but be careful
when changing this, because if there are any characters whose levelup data
is not linked to by any actor when you save the rom, that levelup data will
be gone and will not be recoverable by the editor the next time the rom is
loaded.

There is a certain actor (default = Edge) whose "black" spell set outside
of battle will have the text "Black" replaced with another string of text
(default = "Ninja"). The actor this applies to can be changed, as well as
the string of text that will replace it.

Fields. An actor's editor is split into Edit Commands, Edit Equipment, Edit
Load/Save (which character slot it loads from or which shadow slot it saves to),
Edit Name, Edit Special Set (the Ninja rename) and Edit Job Change (the job a
character returns with).


MESSAGES
--------
There are several banks of messages in the rom. Bank 1 is quite large and
contains most of the plot messages. Bank 3 is considerably smaller and
contains most of the rest of the plot dialogue. Bank 2 is divided among
the various locations in the game. Each location has an associated set
of messages which its NPCs and sometimes certain events can utilize. The
battle messages are called during in-battle events, and the battle alerts
are more generic messages that could come up in any battle. You can also
change the display of status effect names during battle, and the item
descriptions.

The first screen lists the banks with how many messages each has and how full
its area of the ROM is (yellow when nearly full, red when over the limit: Save
ROM refuses a bank that is over, so the same numbers are shown here). Bank 2
asks for a map next. The list of messages shows each message's number and the
start of its text, so messages can be told apart; yellow ones differ from the
ROM as it was loaded. The selected message is shown on the right as the game
displays it, and the space used by the whole bank is always in the title.

    ENTER:   Edit the message.
    SPACE:   The menu of the message, with the key of each action beside it:
             edit, find text in the list (the whole text, not only the start
             shown), find the next match, copy and paste the text (between
             banks of the same kind), revert it to the loaded ROM, undo the
             last text change (Ctrl-Z, up to 40 changes) and show where it is
             used (the events and, in bank 2, the NPCs that show it). For bank
             2 also add a message at the end, insert one before this one,
             delete this one and move it up or down.
    CTRL+R, CTRL+C, CTRL+V, CTRL+Z, CTRL+U, INSERT, DELETE: shortcuts for those.
    ESC:     Back.

Inserting, deleting or moving a bank 2 message changes the numbers of the
messages after it, so the NPCs placed on the map and the events that belong to
it are renumbered along with it and keep showing the same text. An NPC that is
also placed on another map keeps its numbers there, and the editor says which
ones to check. Deleting a message that is used says what uses it first; those
then show the next message. Searching (Search Everywhere on the main menu) also
finds messages by their text, and Changed Entries lists the changed messages.
Item descriptions and battle messages are used by parts of the game that are
not followed, so their "where used" says so.

When editing messages from Banks 1, 2, or 3, there is a large text editing
window you can use to enter or edit the text. However, the underlying text
represented in the box is not always identical to how it is displayed in the
preview on the side; several special codes are used to get certain kinds of
symbols or other effects:

    Certain letter pairs: The text encoding always uses dual-character 
                          encoding whenever possible. Thus if you type "th" it
                          will not result in a 't' followed by an 'h' in the
                          rom but rather the single-byte code for the letter
                          pair 'th'. This shouldn't affect your normal typing
                          in any way; you can just type normal letters the way
                          you expect them to appear and the editor will covert
                          it automatically.

    End of line: Even if you press enter to go down to the next line in the
                 text input box, that will not create a new line character in
                 the text encoding. To do this, use the slash character '/'.

    Names: If you simply type out a name like "Cecil" or "Yang" then if the
           player changes that character's name, the dialogue will not be
           affected in your message. If you want to refer to a character's name,
           use "/name##" where the # symbols are replaced with the digits 
           comprising the name index you're looking for (so for "Cecil" you
           would type "/name00" or for "Yang", "/name06"). In the "insert menu"
           you can select "Name" to bring up a list of names. Selecting one will
           also insert the code for that name into the text (though you can
           still type it out manually if you prefer). The previews in the
           message editor (but not the previews in other editors, such as the
           event editor) will pad the name out to six letters using spaces.
           This is to assist with spacing and alignment for the situation where
           the player renamed the character, and its name may be longer than
           you were expecting when you were composing the message.

    Songs: There is a special character reserved in the text ecoding for causing
           the game to change to a different track of music when it displays the
           dialogue. To achieve this effect in the multiline text input, type
           "/song##" with the # symbols replaced with the digits for the index
           of the song you wish to play. As with names, the "insert menu"
           contains an option which will bring up a list of the songs in the
           game that you can choose one from and it will insert the appropriate
           code into the text for you.

    Delay: You can cause the game to ignore user input for a certain amount of
           time to prevent them from prematurely advancing the text (you can see
           this effect in messages such as "Karate Man Yang joined!" or "Cecil 
           became a Paladin!"). To insert wait time, type "/wait###", replacing
           the # symbols with a number representing the amount of time you wish
           to force the user to wait.

    Unknown codes: There are some characters that exist in the font but their
                   use is currently unknown (Hex codes 0A to 20). In the
                   unlikely event that you wish to type one of these characters,
                   type "/chr##", replacing the # symbols with the decimal
                   representation of the index of the symbol you want (so, a
                   number between 10 and 32).

    Slash: Since many of these codes use the slash symbol '/', if you need the
           text to have an actual slash character in there, this can be achieved
           by typing "/slash". So for example if you want your message to say
           "4/10" then you would type "4/slash10"
         
All of these codes can by typed manually, but most of them can also be 
accessed via a sub menu which appears when you press INSERT while editing, or
when you press ESC and choose "Insert a code". ESC in the text window opens a
small menu: Done (keep the text), Insert a code, Discard my changes (put the
text back as it was when the window opened) or Keep typing.

Bank 2 messages belong to a map: pick the map, then the message. Bank 2
messages and the other banks are checked for space when you save; if a bank has
too much text the editor shows an overflow warning ("Bank 1 overflow!" and so
on) and does not write the ROM, so shorten some messages first. The title of
the message list shows the space used and turns red as soon as a bank is over,
and the Space Usage entry on the main menu shows how full each bank is.


EVENTS
------

This component allows you to edit the scripts for particular events (but not
when or how they are initiated; that is handled by the trigger editor and
npc editor). First, select an event. Then your cursor will move to the script
and you will be able to scroll through and read it, or edit it. To remove a
particular item from the script, move your cursor to it and press the DELETE
key. To insert a new item into the script, press the INSERT key; it will move
the script from the point of the cursor down and insert a new blank script
item that you can then edit. To edit a script item, move your cursor to it
and press the ENTER key.

If the script contains a conditional "yes/no" entry, there will be an extra
script box handling the "no" scenario. You can toggle between editing these
scripts with the TAB key.

In addition, you can completely clear out an entire script by pressing the
BACKSPACE key (it asks first).

Changes to a script can be undone and redone while you stay in that event:
CTRL-Z undoes the last change (a deleted, inserted, edited, swapped, pasted
or erased command) and CTRL-Y redoes it. CTRL-C copies the selected command
and CTRL-V pastes it before the selected command, in the same event or in
another one. The mouse works in the script boxes as in the other menus (a click
selects, a second click edits, the wheel moves, the right button goes back).
Hints for the keys are shown at the top right of the screen, and the top border
of the lists shows how much room is left for all the events together.

The event list itself has a few extra keys:

    TAB:                Choose which map the event is previewed as (this only
                        affects what the editor shows, such as bank 2
                        messages and placement names).
    SHIFT-ENTER, ENTER: Mark an event, then ENTER on another event swaps the
                        two.
    SHIFT-ENTER, INSERT: Mark an event, then INSERT on another event appends
                        the marked event's script (and its "no" script) to
                        the end of the selected event's script, replacing the
                        selected script's final item.

The event list also has the tools of the other lists: events that differ from
the loaded ROM are yellow, CTRL-R reverts the event, CTRL-C / CTRL-V copy and
paste a whole event over another, CTRL-Z undoes a change to an event (including
a swap or an append), and CTRL-U shows where the event is used: the triggers
(through their event calls) and the NPCs whose speech calls it. Changed Entries
lists the changed events too. The list shows eight events at a time.

There is only a certain amount of space in the rom set aside for event
scripts. The editor checks it when you save: if the events are too long it
shows "Events overflow!" and does not write the ROM, so remove or shorten
some scripts and save again. The Space Usage entry on the main menu shows how
full the event area is while you work.


TRIGGERS
--------

Each map has a list of triggers associated with it. In the editor, first
select a map, then you can edit the triggers associated with it. You can edit
a particular trigger with ENTER. The last line of the list is "Add a trigger":
ENTER on it adds a trigger and opens it. SPACE opens a menu with Edit, Add,
Delete (it asks first) and Pick on the minimap, and INSERT and DELETE do the
same as keys. If the game has no room for another trigger the editor says so.

There are three types of triggers:

* Treasures: A treasure will add its contents to your inventory when you
             investigate it (e.g. chests, pots, etc).

* Teleporters: A teleporter will transport you to a different location when
               you step on it (e.g. stairs, doors, etc).

* Events: An event trigger will cause an event to occur when you step on it.
          Depending on the status of various plot flags, different events may
          be launced by the same trigger at different points in the game. In
          addition, each trigger may or may not be associated with a list of
          "bank 2" messages (messages associated with particular maps) which
          are accessed by specific events (default config file calls them
          "show first message", "show second message", "show third message").
          In the event call menu (NPC speech, event triggers) press TAB to
          reach the list of messages: Enter changes which message a slot uses,
          and E opens the text of the selected message for editing (the same
          screen as the Messages editor). The text belongs to the map, so
          everything on that map that uses the message shows the change.
          In the editor, use the TAB key to alternate between editing event
          calls, flag settings, and messages. When editing event calls, you
          can use the INSERT and DELETE keys to add or remove event calls
          respectively.

Note that if you wish to put a trigger somewhere, the map tile at that
trigger's coordinates must be one that can launch that kind of trigger.

Press SHIFT-ENTER and then ENTER on another trigger to swap the order of two
triggers. The trigger editor checks the space available when you save: if there
are too many triggers it shows "Triggers Overflow!" and does not write the rom.
The Space Usage entry on the main menu shows how full the trigger area is.

An overview of the map is drawn in the bottom right, one 4x4 square per tile:
purple tiles are warp tiles, green tiles can start random battles, yellow
tiles can launch triggers, light gray tiles are walkable and dark gray ones are
not. Each trigger is a blue square and the selected trigger is yellow. Press
TAB to switch to a crosshair that you move around the overview with the arrow
keys; ENTER selects the trigger under it, and ESC or TAB returns to the list.
This makes it easy to find which trigger is where on the map.


NPCS
----

NPCs are other characters or miscellaneous interactable objects associated
with a particular map.

As with the trigger editor, first select a map, then you can edit the NPC
placements for that map. ENTER edits a placement; the last line of the list is
"Add a placement", and ENTER on it adds one and opens it. SPACE opens a
menu with Edit, Add, Delete (it asks first) and Pick on the minimap, and INSERT
and DELETE do the same as keys. If the map already has 12 placements, or the
game has no room left for another, the editor says so.

The NPC editor checks whether there is room to spare before allowing you to
add a new NPC placement, so it cannot bleed into other data when you save.

The same kind of overview map is drawn in the bottom right of the NPC editor,
with each placement shown as a red square and the selected one in yellow. Press
TAB to move a crosshair around it with the arrow keys and press ENTER to select
the placement under it.

Fields. A trigger has a type, an X and a Y. Treasures have their contents,
whether they are trapped and the battle that starts if they are. Teleporters
have a destination map, the destination coordinates and the direction the
party faces on arrival. After you choose a new destination map, the editor shows that
map (with its triggers and NPCs marked) so you can move a cursor to where the party
should arrive and press Enter; "Pick the spot on the map" in the parameters does the
same later, and X and Y can still be typed. A teleport to the overworld, the underground
or the moon shows that world map instead (with its triggers framed in yellow); for these
the game uses the whole byte as the X position (0 to 255) and ignores the facing, so the
trigger editor shows X that way and the facing as "not used". Events have the event call (which event runs, with its
parameters), the flag settings and the list of messages described above.


TILESETS
--------

Tilesets are the collections of tiles that maps are composed of. Besides
their graphics, these tiles have various properties which affect their
behavior in some way (e.g. damages party when stepped on, can encounter
random battles, do you walk under or over it, etc).

To edit a tile, simply select a tileset in the menu at the left, and press
ENTER. You will then be able to select a tile and press ENTER again to edit
its properties. The properties are all basic YES/NO flags which can be
toggled with ENTER. When done editing, press ESC.

While selecting a tileset, you can change the current color palette index
by pressing TAB. This will allow you to change which of the game's preset
color combinations for maps the editor will preview the tileset with. This
can be useful for getting a gist of what a map will look like before 
committing to a certain color palette in the Map Info editor, but also
the default palette index 0 has a lot of black and thus some tiles from
other tilesets are not visible under this palette.

Fields. A tile has these yes/no properties: Layer 1, Layer 2, Bridge Layer,
Save Point, Closed Door, Damage Floor, Walk Behind, Bottom Half, Warp, Talk
Over, Encounters and Triggerable, plus a few bits whose purpose is not known
(shown as "Byte 1 Bit 5", "Byte 1 Bit 6", "Byte 1 Bit 7" and "Byte 2 Bit 1").


MAP INFO
--------

Each map has a set of properties that define certain features about it.

Simply select the map whose properties you would like to edit, then navigate
the appropriate menus. Sometimes the "NPC Index" of a map is different from the
map index itself. In such a situation, the NPC placements for that map in the
NPC editor will appear on a different map (the map specified by the NPC Index;
if the map has the "underground" flag set, then add 256 to find the actual map).

Fields. "Edit information" has the map's name, grid index, whether it is
underground, music, whether it is warpable and exitable, magnetic, the
encounter rate, and a mystery flag. "Edit graphics" has the battle background,
tileset, border tile, tile palette, the two NPC palettes and the NPC index.
"Edit background" has the background layer, vertical and horizontal scrolling,
move direction and speed, whether it is translucent, and another mystery flag.


MAPS
----

Each map consists of a grid of 32x32 map tiles. Highlighting a map will
display a preview of its tileset on the left and a 16x16 tile section of
the map itself in the middle. Pressing Enter will switch to map editing
mode, where the following controls apply:

    J: Jump directly to a map index from 1 to 384.
    F: Search map names and jump to the next matching map.
    I: Show the indices of other maps sharing the selected grid.
    CTRL+R: Revert the selected map to how it was when the ROM was loaded (it
            asks first; maps that share the grid change too).

    TAB: Switch between the map editor and the tile selector.
    ARROWS: Move the cursor.
    M: Open a menu of every action of the map editor with its key beside it;
       choosing one does it as if you had pressed the key. It is the way to
       find the keys below, and the only list of them on screen.
  
The following controls only apply to the map editor itself, not the tile
selector:

    SHIFT + ARROWS: Expand the cursor to highlight a rectangular section
                    instead of just a single tile.
    HOME: Scroll to the top left corner of the map.
    END: Scroll to the bottom left corner of the map.
    PAGE UP: Scroll to the top right corner of the map.
    PAGE DOWN: Scroll to the bottom right corner of the map.
    ENTER: Fill the highlighted tile or section with the currently selected
           tile.
    SPACE: Flood fill with the currently selected tile, starting at the
           highlighted tile.
    BACKSPACE: Change the selected tile to the highlighted one (much like
               the "dropper" feature of many image editors).
    CTRL+C: Copy the selected rectangle.
    CTRL+V: Paste the copied rectangle. A translucent preview of it follows
            the cursor; move it with the arrows, press ENTER to place it or
            ESC to cancel.
    CTRL+Z: Undo, up to ten paint, fill or paste operations. Each map keeps
            its own undo, also after you leave the map and open it again.
    CTRL+R: Revert the whole map to how it was when the ROM was loaded. It
            asks first and Ctrl-Z brings the edits back.
    CTRL+Y: Redo.
    R:      Replace every tile that matches the one under the cursor with the
            tile selected in the tile selector. With a rectangle selected it
            only replaces inside the rectangle; otherwise it covers the whole
            map. Can be undone.
    O:      Show or hide an overlay of the map's triggers (yellow squares) and
            NPC placements (cyan squares) on the map.
    T:      Edit the trigger on the tile under the cursor (the same screen as
            Edit Triggers); if there is none it offers to add one. When several
            triggers share the tile a short list asks which one.
    INSERT: Add a trigger at the cursor and open it for editing.
    DELETE: Remove the trigger on the tile (after a confirmation).
    The game shares a fixed amount of room between the triggers of all maps
    (979), and the original ROM uses all of it, so delete one before adding.
    N:      Edit the NPC placement standing on the tile under the cursor (the
            same menus as Edit NPCs: position, speed, palette, walking, facing,
            which NPC, and that NPC's sprite, visibility and speech); if there is
            none it offers to add one. When several stand on the tile a short
            list asks which one.
    SHIFT+INSERT: Add an NPC placement at the cursor and open it.
    SHIFT+DELETE: Remove the NPC placement on the tile (after a confirmation).
    A map can have at most 12 placements, and all maps share a fixed amount of
    room for them; the editor tells you when there is no room.

The four lines at the bottom of the screen show the current panel, tile and
selection size, whether the overlay is on, a reminder of the main keys, the
trigger under the cursor (what it does) or the keys that edit triggers, and the
NPC under the cursor or the keys that edit NPCs.
The map selector shows the selected grid index and how many map entries share
it. Press `I` to open the shared map-index list when needed.

Note that certain maps share the same tile arrangements. This can be viewed
and modified in the "Map Info" editor, under the label "Grid Index". If two
maps share a grid index, editing one will cause the same changes in the other.

In addition, some maps do not contain tile data. These cannot be edited;
The editor will simply display a blank box with the message "No data".
With certain exceptions (mainly the overworld maps), you can press ENTER
on such a map to assign it some map data. Likewise, if you press BACKSPACE
in the map selection menu while a map with data is selected, you will be
presented with the option to remove its data (this will also remove the
data for any other maps with that grid index).

The map editor will display at the bottom the current (x, y) coordinates
of the cursor within the map. This can be useful for cross-referencing
with the locations of other things such as triggers and npcs. It also
displays the amount of space remaining for map data in total. If this
number is displayed in red, it means there is more map data to store than
room to store it in the rom, so you must delete or simplify some maps to
reduce it down before saving. If you try to save while it is red, the editor
shows "Map data overflow!" and does not write the rom. This number is not
updated as you edit; it is only updated when you go back to the map selection menu.


MONSTERS
--------

The monster list is on the left (the usual list keys work: yellow names are
changed, Ctrl-R, Ctrl-C / V, Ctrl-U, Ctrl-Z). A monster counts as changed when
its AI was changed too, and Ctrl-R puts the AIs it uses (attack and reaction)
back as in the loaded ROM, with the condition sets, conditions and scripts
they use. Ctrl-Z undoes the last editing session of a monster, AI included.
Pasting a monster (Ctrl-V) copies its values but not its AI. Select a monster
and press Enter
to edit it: the cursor moves into the boxes on the right and every value is
edited in place, with no menu in between. A line at the bottom of the screen
says what Enter does on the row the cursor is on.

    1 Monster    Name, Boss, Level, HP, Exp and Gil.
    2 Graphics   Pointer, Size and Palette, with a live picture of the monster.
    3 Stats      Attack, Defense, Magic defense, Speed index and Spell Power
                 (grey "off" until the monster has one; Enter types it, Space
                 or Delete switches it off).
    4 Drops      Drop rate, Index and the four drops (common, uncommon, rare,
                 mythic).
    5 Extras     Adds, Resistances, Weaknesses, Races and Reaction: the
                 extra data that only some monsters have. A yellow row is on,
                 a grey row is off.
    6 AI         The attack AI, the bank it is read from (Regular or LUNAR,
                 for the monster) and the reaction AI. Each pair shows its
                 first condition and all of its actions, as many as fit
                 ("more in the AI editor" says when something did not). Enter on an AI opens the AI editor; Enter or
                 Space on the Bank row switches the bank.

    UP, DOWN:        Move through all the rows; at the end of a box the cursor
                     goes on to the next one.
    TAB, 1-6:        Next box / jump to box 1-6.
    HOME / END:      First / last row of the box.
    ENTER:           Edit the row. In Extras it switches the extra on if it is
                     off and edits its details (the status, element or race
                     grid, the spell power, or the reaction AI).
    SPACE:           Switch Boss on / off, or an extra or the Spell Power
                     on / off.
    DELETE:          Switch an extra or the Spell Power off.
    L:               Switch the AI bank of the monster, Regular or LUNAR.
    PAGE UP/DOWN:    The same row of the previous / next monster.
    ESC:             Back to the monster list.

Monsters have some properties that are stored in unusual ways that require a
little explanation.

* Combat stats: Physical attack, physical defense, and magic defense all take
                their values from a list of possible stat combinations. Each
                entry in the list contains a multiplier, a base, and a
                percentage. When editing one of the monster's combat stats,
                first select a stat combination from the list, then you will
                be given the opportunity to change the values in that list
                entry. If you do change them, they will likewise change for
                anything that uses that entry. All three stats use the same
                list. Speed also uses a list, but it is a different list
                from the others, and each entry only contains two numbers:
                a lower bound, and an upper bound.
                
* Item drops: Each monster has associated with it a number which represents an
              index in the list of item drop tables. You can edit which index
              item drop table corresponds to the monster, and you can also edit
              the details of the table associated with that index. Note however
              that changing the table for an index will affect all monsters
              that have that item drop table index.
              
* Graphics: The Graphics box shows a live preview of the monster's sprite in
            the monster's palette that updates as you change the pointer, size
            or palette (also while you move through the pointer templates or type
            a pointer number; Esc puts the old pointer back). It draws all three kinds of monster: ordinary monsters
            (a block of tiles, sized from the size list), bosses (the "special
            sizes", which have their own tile layout, palette and position, so
            the preview follows the special size menu as you edit it) and party
            members used as enemies (drawn from their battle sprite).
            A boss does not use the monster's own palette: the game takes the
            palette from the boss's special size entry (checked in the game
            code), so for a boss the menu shows "Boss pal" and editing it
            changes that entry. Zeromus's last form and the Dummy are 16 color
            art and also use the palette after the chosen one.

* Sprite: the monster list shows the selected monster's picture above the
            Stats box. Pictures are edited, exported and imported in "Edit
            Monster Sprites" (see MONSTER SPRITES).

* Extras: There are certain kinds of data which some monsters have and others do
          not (the Spell Power in the Stats box is one of them). Switch them
          on and off in the Extras box. Pressing Enter on one edits its
          details; the grids (Adds, Resist, Weak, Races) appear while the
          extra is on.

* AIs: Enter on the AI box opens a full screen editor for the monster's AI (see
       ENEMY AI below). The AI box only sums it up.

The monsters screen is organized in three groups. The monster list is on the
left. Next to it is a column of titled boxes of equal width: the monster's
name and basic data, its graphics, combat stats (with the Spell Power),
drops and the Extras, and below those the Adds and Resist grids for the extras
that are on. The AI is in the column on the right: the attack AI at the top,
with the bank it uses ("Regular" or "LUNAR"), and the reaction AI below it when
the monster has one; under that are the Weak and Races grids.

Monsters that appear in certain lunar maps use a different set of scripts
than monsters in the other areas. For the most part, the monster editor
displays this correctly, however there is a known bug where some lunar
monsters (particularly the lunar bosses) are displaying "regular" scripts
instead of lunar ones. A fix for this is being worked on.


ENEMY AI
--------

An AI (1 to 254) is a list of pairs. The game goes through the pairs in order
and carries out the actions of the first pair whose conditions are all true.
Each pair is a condition set (all of its conditions must hold) and a script (the
actions to carry out). Enter on the AI box of the monster editor opens a full
screen editor with two panels, one under the other:

    1 AI SCRIPT     The AI this monster uses, and a way to look at any other
                    AI. Looking does not change the monster: it keeps its AI
                    until you choose "Use AI N for this monster". Enter on
                    the first line lists all 254 AIs (it shows which monsters
                    use each one, and yellow ones are unused).
    2 PAIRS         Every pair of the AI in full, in the same style as the AI
                    box of the monster editor, with a blank line between pairs:
                    WHEN and AND lines for its conditions, indented THEN
                    lines for its actions. Every pair also has
                    an "Add a condition" line, a "Script N" line
                    (how many places use it; Enter on it picks another script)
                    and an "Add an action" line.

The title shows the monster, the AI it uses and the bank. Monsters that appear
on the moon use a different bank of scripts (shown as LUNAR). The panel you
work in has the bright title and cursor, and a line below the panels says what
the keys do on the line the cursor is on. Moving the cursor onto another pair
selects it.

    TAB, 1 2:        Switch between the panels. Up at the top of the list also
                     goes to panel 1, Down at its end goes to the list.
    UP, DOWN, PAGE UP/DOWN, HOME, END: Move in the panel.
    LEFT, RIGHT:     In panel 1 look at the previous / next AI. In the list
                     go to the previous / next pair.
    N / P, G:        Look at the next / previous AI, or at an AI by number.
    A:               Make the monster use the AI that is shown (the same as
                     Enter on the "Use AI" line of panel 1).
    SPACE:           Menu of every action on the line the cursor is on (and
                     of the AI itself: other AI, bank, undo, revert), with the
                     key of each beside it. The keys below are shortcuts.
    ENTER:           Change the line. On a condition a small menu offers
                     "Change condition set" (the set number
                     is shown as "set N" on the pair's first line, and every
                     condition line shows its condition number as "cond N"),
                     "Edit current condition" (its kind and parameters),
                     "Insert a pair after this one", "Move pair up" and
                     "Move pair down". On an
                     action it opens the action (its kind and parameters). On an Add line it
                     adds a new part and opens it at once (ESC in its first
                     menu takes it away again). On the Script line it
                     picks another script from a list.
    INSERT:          Add after this line: a condition or an action. When no
                     unused condition is left a new one is picked from the
                     existing ones. On the "Add a pair" line it adds a pair
                     to the AI that starts as condition set 1 and script 1
                     (nothing new is created; change them afterwards with S
                     and the Script line, which reaches everything that uses
                     them). The Enter menu of a condition can insert a pair
                     after the selected one in the same way.
    COMMA, PERIOD:   Move the pair (on a condition line) or the action (on
                     an action line) up or down. Pairs run in this order.
    DELETE:          Remove the condition or action (a pair keeps at least one
                     condition).
    D:               On a condition: delete the whole pair (an AI keeps at least one).
    S:               On a condition: change the condition set of the pair (the
                     "set N" on its first line), from a list.
    CTRL+C / CTRL+V: Copy a condition or an action and paste it after the
                     cursor line (a condition on a condition line, an action on an
                     action line). Copying works
                     across AIs.
    CTRL+Z:          Undo the last action (kept until you change AI or bank).
    CTRL+R:          Put the AI shown, and the condition sets, conditions and
                     scripts it uses, back as in the loaded ROM.
    L:               Switch between the regular and the lunar script bank.
    R:               Switch between the attack AI and the reaction AI of the
                     monster (when it has a reaction).
    ESC:             Back to the monster editor.

Conditions, condition sets and scripts are shared in the ROM: one script can
serve many pairs and many AIs. The number after "used" counts the places that
use it (yellow when it is more than one), and a change to a shared item changes
all of them. To make only this pair behave differently, point it at another
condition set or script instead (S, or the Script line).

The footer shows how full the four AI areas of the ROM are (groups, condition
sets, regular scripts and lunar scripts). Over the limit, Save ROM refuses to
write and names the area; Space Usage lists them too.


FORMATIONS
----------

A formation is a battle with a particular group of monsters. There are
256 "regular" formations and an additional 256 "underground/moon"
encounters. Events that reference a particular monster formation only
allow an index up to 256; on "regular" maps this will be the index
specified, but on "underground/moon" maps it will be that index + 256.
Since there is no way for an event to "know" the nature of the map the
player is on when it executes, the formation display in the event editor
previews both formations.

The editor draws the formation on a battlefield (the 256x224 pixel battle screen,
with a faint grid every 16 pixels) below the formation's details, so you can see
where each enemy stands. It updates as you change the monsters, quantities and
arrangement. Each monster is numbered with its slot, and a list beside the
battlefield gives every slot's monster and grid position. The game fills the
slots in order: all the monsters of the first type, then the second, then the
third, and if two types are the same monster their quantities are added. Slot
number N takes position N of the formation's arrangement, which gives up to eight
positions (a monster's top left corner is at x * 8 + 16, y * 8 pixels). Bosses
ignore the arrangement and stand where their special size entry says. The
picture shows the sprites and positions only: back attacks, floating monsters
and the battle background are not drawn, and a monster flagged as being in an
egg is drawn as itself and marked "egg" in the list.

Fields. Each formation has its arrangement, battle music, whether it is an
auto battle, a back attack, a "versus player" battle, whether the monsters are
transparent or floating, whether the party can flee or can lose, whether it
gives rewards, whether defeating the boss ends the battle, and two parameters
whose purpose is not known ("Mystery Amount" and "Mystery Byte"), plus the
monsters in it.


ENCOUNTERS
----------

An encounter table is a set of eight formations that a particular map 
randomizes between when a random battle is initiated on that map. The
eight slots each have different probabilities associated with them that
indicate the chance that a given random battle will select that 
formation.

Upper-world maps can only select from among "regular" formations while
underground or lunar maps can only select from among "underground/moon"
formations.

In addition to the regular "inner" maps, there are encounter tables for
different sections of the overworld maps (earth, underground, moon).
Each section is a 32x32 tile region of the respective map.

Changing the details of a particular table will change it for all maps 
that use that encounter table index.


AUTOBATTLES
-----------

Autobattles are scripted battle sequences where the game takes control
of the characters without allowing the player to input commands.

Each autobattle has a formation which it applies to (whenever that 
formation is encountered, the autobattle script will take over), as well
as a script to execute.

When editing the script, use Enter to change a script entry, Insert to
add one at the current cursor position, or Delete to remove the currently
selected entry. The last line of the script is "-- Add --": Enter on it adds
a command at the end. Space opens a menu with all of these and Undo, and
Ctrl-Z undoes the last change to the script (Insert, Delete or a change).

Some autobattles have two scripts: one each for two different actors.
Which ones have two and which have one seem to be hard-coded and thus
cannot be changed at the moment.


SOLOBATTLES
-----------

There are some battles which hide certain actors, or hide all but
certain actors.

Each solobattle has a formation which it is associated with, as well as
an actor. Whenever this formation is encountered, it will hide all actors
except the one specified, unless the one specified is the "Non-solo"
actor. In that case, only that actor will be hidden, and the rest will be
visible/playable as normal.


CONFIG FILES
------------

Labels that the ROM does not contain are read from the files in the `config`
folder (next to the program). They are plain text, one entry per line. Every
line starts with the entry's number and the label starts at a fixed column, so
keep the columns lined up with the existing lines, use spaces and not tabs,
and save the file as plain text. You can change a label, delete a line (the
editor then shows a default like "Map 012"), or add lines for numbers that
are not listed yet. Changes are read when the editor starts. The "From" column
below says whether the first number on a line starts at 0 or at 1, and "Label
at" is the column the label starts in (counting the first character as 1).

  File                  What it names                            From  Label at
  actors.dat            Actors (the party members)               1     5
  battlebgs.dat         Battle backgrounds                       1     4
  characters.dat        Characters (starting data / levelups)    1     5
  effects.dat           Spell animation "effects"                0     6
  elements.dat          Elements and statuses                    1     4
  events.dat            Events                                   1     5
  flags.dat             Plot flags                               0     5
  maps.dat              Maps                                     1     5
  monstersizes.dat      Monster sprite sizes                     0     5
  npcs.dat              NPCs                                     0     5
  npcsprites.dat        NPC sprites                              0     5
  palettes.dat          Spell and weapon animation palettes      0     5
  poses.dat             Battle poses                             1     4
  races.dat             Races (monster / weapon)                 1     3
  sequences.dat         Spell animation "sequences"              0     6
  shop.dat              Shops                                    1     after the colon
  slashes.dat           Weapon slash animations                  0     5
  songs.dat             Songs                                    1     4
  soundeffects.dat      Sound effects                            0     5
  spelleffects.dat      What a spell does (its effect)           0     5
  spellsets.dat         Spell sets                               1     5
  stances.dat           Battle stances                           1     4
  swings.dat            Weapon swing animations                  0     5
  targets.dat           Target types                             0     3
  tilesets.dat          Tilesets                                 1     4
  visualfx.dat          Visual effects (medicines, weapon casts) 0     5
  weaponproperties.dat  Weapon property flags (1 to 8)           1     3
  weaponsprites.dat     Weapon sprites                           0     5

Three files are different:

  font.dat                  Which FF4 character each typed character becomes.
                            Each line is the typed character, a space and the
                            FF4 character code in hex (for example "A 42").
                            Characters that are not listed become "?".
  monstergfxpointers.dat    The "Template" list in the monster graphics editor.
                            Each line is a pointer, a slash and a size code
                            ("32768/0") followed by a label that starts at
                            column 11.
  lunar.dat                 Monsters that are always treated as lunar, so the
                            monster editor uses their lunar AI scripts. Each
                            line is a monster number and a label; lines that
                            start with # are ignored.


ACKNOWLEDGEMENTS
----------------

Many thanks to everyone on the Slick Productions forum for posting their
research and discoveries about the internal workings of the game (without
which this project would not have been possible), as well as for helping me
test and debug the editor. I would also like to particularly thank those
that have made active contributions toward this end.

Known contributors, sources, and/or testers include but are not limited to
the following (as much as I don't like naming names, I feel these people
deserve specific mention):

avalanche  
avaquizzer  
Bond697  
chillyfeez  
Deathlike2  
Displacer  
Dragonsbrethren  
Edea  
Entroper  
Grimoire LD  
JCE3000GT  
LordGaramonde  
Paladin  
Phoenix  
vivify93  
Vehek  
Yousei  
Zozma  
Zyrthofar  
...and whoever wrote the "Tower of Bab-Il Docs"

VERSION HISTORY
---------------
* 1.1
    - Added Field Sprites editor: the 107 walking sprite sheets of the party and the NPCs (pixels, frame flip and copy, 36 palettes with colors that can be rearranged, a palette pick per sheet kept in config/fieldpalettes.dat, BMP export and import); the palette number in the file names of Portraits imports is read correctly
    - Added Battle Formulas editor: spell damage (power scale, hits from the stat, stats used, summon and item hits) and the Summon Book
    - Battle Formulas: character stat formulas (attack multiplier, attack power, defense multiplier, defense, magic defense multiplier and %), the Armor and Shell numbers, what Dispel and Black Hole remove, the bonus of the first slot or of units with a status, the back row, the statuses that weaken a unit and the other status adjustments, and the timers (turn wait, Count, poison, HP leak, sleep)
    - Battle Formulas: the start of the battle (who is surprised or strikes first, back attacks, waiting)
    - Battle Formulas: spell effect 29, the unused copy of Count, can raise or lower a stat of its target like Armor, including the modified strength, agility, vitality, wisdom and will
    - Commands: overview of all commands with what changed, and the names of the four internal commands
    - Commands: the unused command 22 can "Behave like" another command (runs its routine and animation)
    - Commands: Fight's multipliers can use half steps (x1.5, x2.5, x3.5), which the original damage code ignored
    - Commands: Fight has the list of temporary statuses that its attack cures in the attacker (Charm in the original)
    - Commands: Dark Wave and Kick have code settings (HP cost, damage to undead, Kick multiplier, shared base damage) and Peep has one (bosses)
    - Commands: Aim can use any stat of the target and the user, Boast and Cry can be reversed (raise or lower)
    - Commands: Regen has the ticks between its heals, Cry can work on the allies instead of the enemies
    - Commands: Jump has its wait and air time, Charge, Twin and Regen have the delay of their second part
    - Commands: Jump and Throw have a Parameters screen with their failure message, Throw also with its damage formula (stat, random part, cap)
    - Commands: Recall can skip its MP check and its MP cost
    - Commands: Steal has its lowest and highest chance, the chance of being caught and what a caught thief loses
    - Characters: the starting data has the critical hit rate and bonus
    - Extended ROMs (2 MiB hacks and the like) open and save without changing a byte you did not edit: the size check accepts any whole-bank size, a ROM that is not 1 MiB gets a warning, and the Commands editor leaves unedited commands alone, protects the custom routine of command 22 and writes the commands again after an undo
    - Enemy AI editor: Space opens a menu of the actions on the cursor line, the menus for an action, spell, technique or command find an entry by typing its name, and less is on the screen (usage counts only when a set or script is shared, one row title, two lines of key help)
    - Triggers, NPCs and autobattle scripts: an "Add" line at the end of the list, a Space menu with add, delete and the rest, a hint on the bottom row, and a message when the game has no room; autobattle scripts have Ctrl-Z; deleting a condition or parameter of an event command asks first
    - Maps: Ctrl-R reverts a map to the loaded ROM (in the list and in the map editor), and the undo of a map is kept after leaving it
    - World Maps: Ctrl-R reverts a world to the loaded ROM, and the undo of each world is kept after leaving it
    - Maps and World Maps: M opens a menu of every action with its key, like the sprite editors' Enter menu
    - Battle Sprites, Portraits, Field Sprites: Ctrl-R reverts (as in Monster Sprites and the lists); all four sprite editors step the brush color with [ or Minus and ] or Plus and list their actions in the same order, with Previous / Next for the item (Portraits and Field Sprites keep Go to)
    - Battle Sprites, Monster Sprites, Portraits, Field Sprites: every BMP export asks for confirmation first, like the imports
    - Lists: the Space menu only offers "Show where it is used" for the lists that track it; the key help no longer says Medicines and Tools can swap entries
    - Hints on the bottom row now say what Enter does in Tools, Shops, Jobs, Commands, Actors, Characters, Formations, Encounters, Autobattles, Solobattles, Map Info, Tilesets and Features (each menu and, where the lines differ, each line)
    - F1 also works on the editing screens (sprite and portrait editors, maps, world maps, tile properties, battle formulas, level ups, the AI editor and the item forms), not only in menus
    - Main menu: under Party the data editors (Characters, Commands, Actors) come before the picture editors (Battle Sprites, Portraits, Field Sprites); the key help for Features names what it edits
    - Messages editor: the text window opens at the left edge so the message preview does not cover it
    - The ROM font cannot draw some characters: messages, help, hints and config labels no longer use them (they showed as ?), the Save ROM marker is now ! instead of *, and hints longer than 78 characters were shortened so the bottom row no longer cuts them
    - Fixed windows drawn over each other in Triggers, NPCs, Formations and Characters
* 1.0
    - Enemy AI editor: one list of pairs in the style of the monster editor's AI box (WHEN, AND and
      THEN lines, a blank line between pairs, the set and condition numbers and how many places use them),
      Enter on a condition opens a menu (change the condition set, edit the condition, insert a pair, move the
      pair), pairs can be added and moved, a new pair starts as set 1 and script 1, and the sharing of sets
      and scripts is said on screen (private copies were removed)
    - Commands: the unknown bytes in the If lists are named from the disassembly (or shown as unused bytes)
    - Messages editor: the list shows the start of each message, changed ones are yellow, the space of the
      bank is always shown, a menu (Space) has find text, add, insert, delete, move, copy, revert, undo and
      where used, inserting, deleting and moving bank 2 messages renumbers the NPCs and events that use
      them, Esc in the text window has a menu (done, insert a code, discard), and Search Everywhere finds
      messages by text
    - Menus instead of shortcuts: every action of the sprite editors has an actions menu (Enter, Space on
      the battle sprite tile sheet), the entry lists have one too (Space: revert, copy, paste, undo, where
      used), and the Spell Sets editor opens a menu on a spell; the keys still work
    - Spells, Weapons, Armors and Medicines editors: every box of the entry is on the screen and the cursor
      moves straight into them (Enter, Space, Tab, 1 2 3, PgUp PgDn) instead of the pick a category menus;
      weapon properties named from the disassembly
    - Spell Sets editor: one screen with the starting and learned lists side by side, edited in place
      instead of the Add / Edit / Delete / Clear menus
    - Battle sprites and portraits: export and import can be done for one character or portrait (the list
      asks, and E / I work while editing)
    - Battle Sprites, Portraits and Monster Sprites screens redrawn in blue windows like the rest of the
      editor (picture, preview, palette, color details and an actions window)
* 0.9
    - Edit Monster Sprites: pixel and palette editor for the monsters' pictures, colors can be moved with their pixels,
      BMP export / import moved there from the monster editor, which shows the picture of the selected monster
    - Fixed the battle of a chest on the underground and moon maps: the game adds 32 to the
      chest's battle number on maps numbered 256 and up and uses only 5 bits, so the Battle
      list now shows those 32 formations and the used-by list of a formation agrees
    - Fixed the cursor in the message list of event calls (NPC speech, event triggers): it
      jumped back to the first message, so the other messages could not be reached
    - Edit World Maps: edit the overworld, underground and moon (paint, fill, replace,
      copy / paste, undo, mouse painting); saved into the fixed room the game gives
      each world, with a space check; O shows triggers and encounter zones over the map;
      Edit Events has key hints, a room gauge, undo / redo, copy / paste of commands and events, used-by, changed marks and mouse; the text of a speech message can be edited from the speech menu (E); T / Insert / Delete edit the world triggers from the map; teleport triggers pick
      their arrival spot on a picture of the destination map; NPC placements can be
      edited from the map editor too (N, Shift-Insert, Shift-Delete); the regular map editor
      has the same keys for the triggers of the map
    - Revert, copy / paste, undo and changed marks for solobattles, autobattles, spell
      sets and encounter areas; Changed Entries lists commands, actors and those too
    - Edit Graphics shows and edits the palette a boss really uses
    - Monster graphics pointers below 8000h are drawn as 4 bits per pixel (fixes the
      Zeromus and Dummy previews)
    - Monster sprite export and import (E and I in Edit Monster Sprites)
    - Mouse support in menus, message boxes and the map editor
    - Ctrl-Z undo in the entry lists; command and actor lists get the changed marks,
      revert and copy / paste; F1 shows the keys of the editor you are in
    - Main menu grouped under headings; confirmation before deleting an event
      call entry or an AI condition/script pair, and before pasting over an
      edited list entry
    - Removed unused experimental files (common/old, common/new, old tileset editors)
    - Shop, formation and job lists now have the changed-entry colors, revert,
      copy / paste and (formations) where-used keys; Changed Entries covers them
    - Save ROM lists every problem at once when it fails; the modified mark
      now reflects real changes only
    - Added Portraits editor (menu faces, 32x32, palette editor, BMP export and import)
    - Added Battle Sprites editor (after Edit Jobs)
       - Tile editor with live pose previews, copy/paste, undo
       - Palette editor
       - Export and import of each character's poses as one indexed BMP
         with the palette stored in the image
    - Spell editor plays the spell's animation sequence in a preview panel
    - Monster editor shows a live sprite preview while editing graphics
    - Weapon editor shows the weapon's sprite in its palette
    - Formation editor draws the battle formation: where each enemy stands,
      with slot numbers and a position list
    - The monster graphics preview now draws bosses and party-member enemies,
      and pointers below 8000h
    - Fixed a memory bug when marking lunar monsters (empty formation slots
      wrote past the end of the monster list), which could crash the editor
    - Monsters screen reorganized: aligned, titled boxes and a clearer AI
      column with a bank header
    - Enemy AI editor rewritten as a full screen editor with three panels
      (the AI script to look at or use, the conditions of its pairs, the
      actions under them) with insert/delete, private copies on request,
      copy/paste, undo, a list of the monsters that use the AI and a
      room check (Save ROM refuses AI data that does not fit)
    - Monster editor: the cursor moves straight into the boxes (no Edit menu),
      every value is edited in place, extras are switched on and off with
      Space, a hint line says what Enter does, the AI is summed up pair by pair
    - Level up editor rewritten as a full screen table with free cell
      navigation, direct number entry, copy/fill/paste, undo, character
      switching and per-level total stats, HP, MP and EXP
    - Map editor: paste preview, redo, replace-all-tile, NPC and trigger
      overlay, fixed a swapped selection limit, removed the H key sidebar
    - Main menu: key help panel no longer leaves part of a taller box behind
    - CSV export/import and the two ROM comparisons are hidden from the menu
    - Removed the breadcrumb line
    - Help text no longer uses symbols the font cannot draw
    - Save ROM now refuses to write map data that does not fit (the check
      had been switched off), and Space Usage shows the map data
    - README documents the config files, the fields of each editor, the
      overview maps, the shared keys and which areas are checked for space

* 0.8
    - Added safeguard to prevent overflow in:
       - triggers
       - map data
    - Added special size editor to monster editor
    - Added palette preview to monster editor
    - Cleaned up event editor
       - Sub-menus now expand while selecting item
       - Preview map moved to top and no longer disappears
       - Underground formations and NPCs now preview correctly
    - Added "party dead / flag check event instructions" patch
       compatibility
    - Solobattle and trigger editors now preview formation details
    - Added components to actor editor
       - Which character job changes upon return and to what job
    - Added "6-letter spells" feature to feature editor
    - Formation editor can now toggle rewards, and whether the fanfare
       is played after a battle with "no change" music
    - Fixed bug in map background display
    - Map editor now previews available space for map data
    - Added "Extra 1" and "Extra 2" jobs
       - They can have equips and in-battle spell sets but not in-menu
    - Added loading information display to initial rom load routine
    - Glitch worlds can be made into real worlds and vice versa

* 0.7
    - Added safeguard to prevent overflow in:
       - events
       - all text areas
       - learned spells
    - Added Tileset Editor
    - Tiles now read from rom rather than from image files
    - Animated tiles now animate
    - Map editor previews map backgrounds
    - Cleaned up several monster editor glitches

* 0.6
    - Fixed underground NPCs being named as above-ground counterparts
    - Fixed bug with starting level when changing actor level links
    - Cover can now be indexed by job rather than actor
    - Added targeting type to command editor (only affects cursor for some)
    - Map treasure indexes now calculated correctly
    - Added item description editing
    - Fixed descriptions of spell codes 00-30 & 31-5E in monster AIs
    - Jobs can now have separate spell sets in and out of battle 
    - Added solobattle editor
    - Added many parameters to commands
    - Added encounter rates to map info editor
    - Added a file selector instead of typing the rom filename
    - Fixed bug causing end of Bank 2 to be read incorrectly
    - Bank 2 messages can now be added or deleted
    - Many indexes can now be swapped (shift-enter, enter)
    - Included mystery flag in spell editor
    - Map editor now displays coordinates of cursor
    - Corrected message and npc placement references in event editor
    - Fixed error in "You" placement movement descriptions
    - Event editor now previews bank 2 (you can change/set the map)
    - Event editor now previews placement names
    - Added visual effects config file
    - Spell color names (black/white/call) can now be changed
    - "Special" set name (Ninja) can now be renamed/reassigned
    
* 0.5
    - Added parameters to several commands
    - Added spells usable outside of battle to features editor
    - Changed actor names are now correct in battle
    - Added config file for spell graphic "sequences" and "effects"
    - Fixed encounter range for trapped chests
    - Added auto-battle script editor
    - Added map editor
    - Capped Max MP levelup gains to prevent bleeding into TNL gains
    - Fixed error with actor levelup links causing distorted levelup data

* 0.4
    - Fixed bug causing bows to be better in dominant hand
    - Changed name of "Item Range" editor to "Features" editor
    - Added white spell range to features editor
    - Added bow and arrow ranges to features editor
    - Added equip slot ranges to features editor
    - Fixed window alignment error in map info editor
    - Added config file for battle backgrounds
    - Removed extra junk name from map names
    - Fixed bug causing game to freeze when changing characters with R
    - Fixed bug causing warp/exit to be disabled for all maps
    - Added "warpable" flag to Map Info editor
    - Added "exitable" flag to Map Info editor
    - Fixed bug causing Golbez to fail to appear in scripted battle
    - Added Monster editor
    - Added Formation editor
    - Added Encounter editor
    - Added editing of Cover details to command editor

* 0.3
    - Added Page Up / Page Down functionality to menus
    - Added index toggle function to menus
    - Added safeguard to prevent saving if Bank 1 text overflows
    - Fixed a minor bug with interpreting the "/slash" code in message input
    - Fixed bug with character experience cap
    - Added Map Info editor
    - Added Item Ranges editor, including two-handedness and key item status

* 0.2
    - Fixed bugs with saving of NPCs
    - Fixed navigation errors with event calls / npc speeches
    - Added insert/delete functionality to event call / npc speech message parameters
    - Improved message preview display
    - Added previews for bank 2 messages in event call / npc speech parameters
    - Fixed bug causing underground NPCs to be previewed as upperworld counterparts
    - Fixed a minor mistake in reading spell sets
    - Fixed bug relating to saving equip indexes
    - Fixed bug relating to editing element indexes
    - Added config file for NPC sprites
    - Added config file for NPC names
    - Added message editor
    - Added support for unheadered v1.1 roms

## CSV export/import, ROM diff, and menu search

- **Export CSV / Import CSV** (currently hidden from the main menu; the code is still in the program): spells, weapons, armors, medicines, tools and monsters go to/from `exports/<table>.csv` (next to the editor). Edit them in a spreadsheet and import them back; only the columns present are applied, so a file with just `id,attack` works. Names use `{HH}` for characters with no ASCII equivalent. Imports change the in-memory data only; use Save ROM to keep them.
- **Compare to Original ROM** (currently hidden from the main menu): shows which tables your edits changed and writes `exports/rom_diff.txt` with offsets and old/new bytes. Edits are measured against what Save ROM would write for the unedited data (Save also re-lays-out some data, which is reported as a separate count).
- **In any menu:** Ctrl+F finds an entry by name, Ctrl+N jumps to the next match, Ctrl+G goes to an entry by number.
- **Typing in the AI action menus:** in the list of action kinds and in the spell, technique and command pickers, just type (for example "chain i") and the cursor jumps to the first entry that starts with those letters, or else contains them. Backspace removes a letter; the typing starts over after two seconds.

## Safety and navigation extras

- **Automatic backup:** the first Save ROM of a session copies the ROM file to `<rom>.<date>-<time>.bak` before writing.
- **Restore from Backup** (main menu, under Save ROM) lists the backups of the open ROM, newest first, with date, time and size. Pick one and confirm: the ROM file is replaced with it and FF4kster starts again to load it. The ROM as it is now is copied to a new backup first, so a restore can itself be undone by restoring that backup. Edits you have not saved are lost.
- **Delete Backups** (main menu) deletes one backup, or all of them (the first entry shows how many and how much space they take). Deleted backups cannot be brought back.
- **Command line / last ROM:** `ff4kster-console.exe path	oom.smc` (or drag a ROM onto the exe) skips the file selector. Without an argument the editor offers the ROM used last time (`lastrom.cfg`).
- **Window title** shows the ROM name and a `*` when there are unsaved edits.
- **Entry lists (spells, items, monsters, shops, formations, jobs, commands, actors, spell sets, encounter areas, autobattles, solobattles):** names that differ from the loaded ROM are yellow. Ctrl-R reverts an entry, Ctrl-C / Ctrl-V copy and paste an entry (the target keeps its name), Ctrl-Z undoes the last change to an entry, Ctrl-U shows where it is used (formations and encounter areas, shops and chests, weapons that cast a spell; for a formation, the areas that use it and trapped chests). Shops and jobs have no usage list. The editor reopens on the entry you were last on.
- **Search Everywhere** (main menu) finds a spell, item or monster by name and opens its editor on it.
- **Compare with ROM File** (currently hidden from the main menu) diffs your current work against another ROM file.
- **F1** shows key help in any menu. Deleting triggers, NPCs and messages asks for confirmation.
- **Space Usage** (main menu) shows how full each fixed ROM area is (events, triggers, map data, text banks, item descriptions, monster AI); over 100% means Save ROM will refuse.
- **Changed Entries** (main menu) lists every spell, item, monster, shop, formation, job, command, actor, spell set, encounter area, autobattle and solobattle changed since loading and opens the one you pick.
- **Number boxes:** press X to switch between decimal and hexadecimal entry (A-F are accepted in hex mode).
- **Saving** asks before overwriting a ROM file that changed on disk since it was loaded or last saved.
- **CSV** now also covers shops and formations.
