Azerloot 2.5.0 - the loot book for Azeroth Survivors, by Kindagrey
===================================================================

Every boss drop in every zone, every ring, trinket and amulet at every rarity, each
class's legendary amulets, a build planner, a chronicle of your runs and a wishlist
that ticks itself.
Built for Azeroth Survivors (World of Warcraft 1.12.1 client).


INSTALLATION
------------
Unpack the folder "Azerloot" into your AddOns folder, usually
    C:\Git\wenilla\benilla-config\AddOns
The folder must be named exactly "Azerloot".
Updating: delete the old "Azerloot" folder first, then unpack the new one.


OPENING THE BOOK
----------------
Minimap button, /azl, or a key of your choice (Key Bindings menu).
Right-click on the minimap button (or the gear in the book's top bar): the settings.
Shift-click on the minimap button: the wishlist window and the three warning places can be
dragged where you like, the mouse wheel over a warning makes it larger or smaller;
Shift-click again (or click a warning example) when done.

    /azl              open or close the book
    /azl tracker      wishlist window on/off
    /azl layout       move the wishlist and the warnings (as Shift-click on the minimap button)
    /azl settings     the settings window
    /azl collection   your collected boss pieces
    /azl reset        wishlist window back to its first place


THE CHAPTERS
------------
Title page   Your class's progress, the chapters and a saying. Click "Azerloot" in
             the top bar to come back to it.
Jewelry      Every ring, trinket, basic amulet and class amulet, with its value at
             every rarity.
Loot         Every zone and boss: what each class can take from them and how they
             fight. Every attack is an icon under "Dangers", read from the game's own
             code: its shape, size, warning time and cooldown. Hover an icon for all
             of it, click one to show it on the page; the last icon tells what the
             boss does once wounded. Collection Book: click a piece to mark it
             collected, right-click to put it on your wishlist.
Spells       Every class's spells. With the spell tracker on, spells you pick up in a
             run join the wishlist window and show their upgrades as they grow.
Builds       Up to five builds per class: your class's starting spell, five more
             spells, two rings, two trinkets and an amulet, with your talents as a
             note. Click a "+" to fill a place from a short list, click a part to
             change it ("None" empties it). The battle traits and the strengths and
             weaknesses show what a build is good at. On the left: your class emblem,
             your gear and your run stats.
             "Load into wishlist" puts a build's spells and jewelry on the wishlist
             (wished boss loot stays). When a run begins, the wishlist window offers
             your builds to load with one click. "Share" gives a short code to post
             anywhere, "Import" reads one from another player and asks which of your
             five places it goes into (a taken place is replaced).
Chronicle    Every run you finish, per class: the last 50, your best run pinned on top
             with its star, and your personal bests kept for good. Click a run to read
             it: its numbers, the build you played and what it missed, your spells and
             jewelry at the end, and the boss loot (with "New!" on pieces that run
             added to your collection). "All builds" shows the runs of one build only,
             deleted builds included. Runs you leave with the game's own button are
             not written down.



THE WISHLIST WINDOW
-------------------
What you still need in this run, ticked off as it comes: your spells, your jewelry
and boss loot for your collection, each in its own section.
    Click an entry              open it in the book
    Right-click an entry        mark it found (or collected)
    Shift-right-click           take it off your wishlist
    Click a section heading     fold it away or open it again
    Right-click a heading twice take the whole section off your wishlist
    Click the window's head     pick one of your builds, at any time
The lock (top right) keeps the window in place. Locked during a run, clicks go
through it to the game; its headings still fold. Taking parts of a loaded build off
the wishlist unloads the build ("Load into wishlist" brings it back whole).

Search (top bar): rings, trinkets, amulets, boss loot, bosses, zones and pages.
Settings (gear in the top bar, or a right-click on the minimap button): a window in three
tabs, each setting with a live preview beside it. Book: font, language (English, Deutsch,
Français, Español, Português or Auto) and size. Wishlist: the window on/off, locked, its
size and opacity, the spell tracker, back to its first place. Azerwarn: warnings, the boss
line, the warnings' font, a colour for each of the three warning places, the two sounds. A language takes effect with a reload.


FILES
-----
    Azerloot.toc   what the game loads, in order
    Bindings.xml   the key binding to open the book
    core\          the book itself and its languages (Azerloot.lua, Locale.lua)
    modules\       chapters that live in their own files (Builds.lua, Chronicle.lua)
    locales\       translations: the book's words and the game's own texts
    data\          jewelry, class amulets and every boss's loot
    media\         fonts (with their licences) and textures
    LICENSE.txt    what you may and may not do with Azerloot


Works with the default UI and with SurvivorsDragonUi (round and square minimaps).
Azeroth Survivors Discord: https://discord.gg/CXAvQ6ZTXe by aethus meow meow


COPYRIGHT
---------
Copyright (c) 2026 Kindagrey. All rights reserved. Free to download and use for your own
play; changing it, building on it or publishing copies of it elsewhere needs Kindagrey's
written permission. See LICENSE.txt.
