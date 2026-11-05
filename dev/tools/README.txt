Tools for us (not in the release). Paths in the scripts point to /home/claude/work; adjust as needed.
- locx.py game.exe out.json: the game's translation tables (block 0 en, 1 pl, 2 cs, 3 de, 4 pt, 5 es, 6 fr, 7 ro, 8 tr, 9 ru, 10 uk, 11 zh, 12 ja, 13 ko)
- gen_tt.py: merge(B, current Tooltips.lua, out) adds the game's new texts to locales/Tooltips.lua (keeps every entry it has)
- pe.py / xref.py: read the exe by address; xref.py finds the code that points at an address (strings, data)
- check.lua: syntax check with Lua 5.0 (build Lua 5.0 from github.com/lua/lua tag v5.0, all .c but ltests.c and linit.c)
- env.lua / load.lua: a loose WoW stand-in that loads the whole addon for quick tests
The Shaman's necklaces (0.135): each has a record (spell key, icon, strength/100, a function that builds its
effects); found from the necklace's name via xref.py, the functions read with objdump -d -M intel.
0.140 (Scholomance): gen_boss3.py reads the boss table (Z = the zone table's address, found by the
"Elwynn Forest"/"Duskwood" string refs; the Scholomance bosses are scripted and have no abilities
there); gen_scholo.py builds the Tier 0.5 zone's drops, names and set bonuses from t05.json (the
item table found by the item ids 21999.. as u32) and the loc; dbc.py/storm.py read Spell.dbc and
ItemDisplayInfo.dbc from patch.MPQ (StormLib built from github.com/ladislav-zezula/StormLib with the
bundled libs; patch.MPQ = the five parts of G:\AzerothSurvivors\split joined); gen_gt.py merges the
loc into locales/GameText.lua as gen_tt.py does for Tooltips.lua.
