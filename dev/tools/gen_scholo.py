import json,re
sets=json.load(open('t05.json')); stats=json.load(open('stats2.json'))
B=json.load(open('locblocks.json'))
T=['damage','cooldown','hp','crit','crit_damage','speed','armor','regen','pickup','gold','area','count','echo','calm_regen','crowd_armor']
FMT={'damage':'+{p}% damage','cooldown':'-{p}% cooldowns','hp':'+{n} max health','crit':'+{p}% critical strike','crit_damage':'+{p}% critical damage',
 'speed':'+{p}% movement speed','armor':'+{p}% damage reduction','regen':'+{d} health per second','pickup':'+{p}% pickup range','gold':'+{p}% gold',
 'area':'+{p}% area of effect','count':'+{n} target to every ability','echo':'{p}% chance for an ability to strike twice',
 'calm_regen':'{p}% max health per second after 3 seconds unhurt','crowd_armor':'+{p}% damage reduction with 5 or more enemies close'}
import math
def pct(v):
    x=v*100
    if x>=9.95: return str(int(math.floor(x+0.5)))   # (the game rounds these to whole numbers)
    s='%.1f'%x
    return s[:-2] if s.endswith('.0') else s
def dec(v):
    s='%.1f'%v
    return s[:-2] if s.endswith('.0') else s
def bonus(stat):
    out=[]
    for t,v in stat:
        f=FMT[T[t]]
        out.append(f.replace('{p}',pct(v)).replace('{n}',str(int(round(v)))).replace('{d}',dec(v)))
    return out
SLOT={1:'Head',3:'Shoulder',5:'Chest',20:'Chest',6:'Waist',7:'Legs',8:'Feet',9:'Wrist',10:'Hands'}
def wslot(w): return {15:'Main Hand',16:'Off Hand',17:'Ranged'}[w['x'][2]]
def lstr(s): return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
def piece(it,slot):
    return '{ name = %s, slot = %s, icon = %s, rarity = "Epic", bonus = { %s } }'%(lstr(it['name']),lstr(slot),lstr(it['icon']),', '.join(lstr(b) for b in bonus(it['base'])))
CLS=['warrior','paladin','hunter','rogue','priest','shaman','mage','warlock','druid']
# pairing by the game's own order of the pieces: head+shoulder, chest+waist, legs+feet, wrist+hands; Gandling the weapon(s)
drops={}
for cls,s in zip(CLS,sets):
    its=sorted(s['items'],key=lambda it:[1,3,5,6,7,8,9,10].index(5 if it['slot']==20 else it['slot']))
    bosses=[]
    for k in range(4):
        bosses.append('      { '+', '.join(piece(it,SLOT[it['slot']]) for it in its[2*k:2*k+2])+' },')
    bosses.append('      { '+', '.join(piece(w,wslot(w)) for w in s['weapons'])+' },')
    drops[cls]='    {\n'+'\n'.join(bosses)+'\n    },\n'
json.dump(drops,open('scholo_drops.json','w'))
# names: every language's name -> English, per class
names={}
for cls,s in zip(CLS,sets):
    m={}
    for it in s['items']+s['weapons']:
        key='t05.%d'%it['id']
        for bi in range(1,14):
            v=B[str(bi)].get(key)
            if v and v!=it['name']: m[v]=it['name']
    names[cls]=m
json.dump(names,open('scholo_names.json','w'),ensure_ascii=False)
bn={}
for bid in [10506,10508,11261,10504,1853]:
    en=B['0']['boss.%d.name'%bid]
    for bi in range(1,14):
        v=B[str(bi)].get('boss.%d.name'%bid)
        if v and v!=en: bn[v]=en
json.dump(bn,open('scholo_bossnames.json','w'),ensure_ascii=False)
print(drops['rogue']); print(len(names['warrior']),len(bn))
