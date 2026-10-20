Azerloot 2.1.0 - the loot book for Azeroth Survivors, by Kindagrey
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

    /azl              open or close the book
    /azl tracker      wishlist window on/off
    /azl minimap      minimap button on/off
    /azl collection   your collected boss pieces
    /azl reset        wishlist window back to its first place


THE CHAPTERS
------------
Title page   Your class's progress, the chapters and a saying. Click "Azerloot" in
             the top bar to come back to it.
Jewelry      Every ring, trinket, basic amulet and class amulet, with its value at
             every rarity.
Loot         Every zone and boss: how they fight and what each class can take from
             them. Collection Book: click a piece to mark it collected, right-click to
             put it on your wishlist.
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

Search (top bar): rings, trinkets, amulets, boss loot, bosses, zones and pages.
Settings (gear in the top bar): language (English, Deutsch, Français, Español,
Português or Auto), font (easier-to-read fonts, e.g. for dyslexia), spell tracker,
wishlist window, minimap button, wishlist opacity and book size.


FILES
-----
    Azerloot.toc   what the game loads, in order
    Bindings.xml   the key binding to open the book
    core\          the book itself and its languages (Azerloot.lua, Locale.lua)
    modules\       chapters that live in their own files (Builds.lua, Chronicle.lua)
    locales\       translations: the book's words and the game's own texts
    data\          jewelry, class amulets and every boss's loot
    media\         fonts (with their licences) and textures


Works with the default UI and with SurvivorsDragonUi (round and square minimaps).
Azeroth Survivors Discord: https://discord.gg/CXAvQ6ZTXe by aethus meow meow
