Tools for us (not in the release). Paths in the scripts point to /home/claude/work; adjust as needed.
- locx.py game.exe out.json: the game's translation tables (block 0 en, 1 pl, 2 cs, 3 de, 4 pt, 5 es, 6 fr, 7 ro, 8 tr, 9 ru, 10 uk, 11 zh, 12 ja, 13 ko)
- gen_tt.py: merge(B, current Tooltips.lua, out) adds the game's new texts to locales/Tooltips.lua (keeps every entry it has)
- pe.py / xref.py: read the exe by address; xref.py finds the code that points at an address (strings, data)
- check.lua: syntax check with Lua 5.0 (build Lua 5.0 from github.com/lua/lua tag v5.0, all .c but ltests.c and linit.c)
- env.lua / load.lua: a loose WoW stand-in that loads the whole addon for quick tests
The Shaman's necklaces (0.135): each has a record (spell key, icon, strength/100, a function that builds its
effects); found from the necklace's name via xref.py, the functions read with objdump -d -M intel.
