import json,sys
sys.path.insert(0,'/home/claude/work/mpq'); import dbc
exec(open('rd.py').read())
SP=dbc.spells()
ICON_FIX={'Sand Trap':'Spell_Nature_Earthquake','Hateful Strike':'Ability_Warrior_Decisivestrike','Frost Breath':'Spell_Frost_FrostNova'}
NAME_FIX={'Fire Nova Totem':'Fire Nova','Venoxis Transform':'Snake Form'}
def nm(i):
    n,ic=SP.get(i,('?','INV_Misc_QuestionMark')); n=NAME_FIX.get(n,n)
    if ic in ('Temp',''): ic=ICON_FIX.get(n,'INV_Misc_QuestionMark')
    return n, ic
Z=0x1473a06c0
ALT={('Doomguard Commander','circles'):'Spell_Fire_MeteorStorm',('Tendris Warpwood','line'):'Spell_Nature_Earthquake',
 ('King Gordok','seq'):'Spell_Nature_ThunderClap',('High Priestess Jeklik','lanes'):'Spell_Fire_SealOfFire',
 ('Hakkar the Soulflayer','towers'):'Spell_Shadow_BloodBoil',('Lokholar the Ice Lord','ring'):'Spell_Frost_FrostShock',
 ('Lokholar the Ice Lord','rows'):'Spell_Frost_Stun',('Azuregos','seq'):'Spell_Frost_FrostShock',('Azuregos','waves'):'Spell_Nature_StormReach',
 ('Warchief Rend Blackhand','beam'):'Spell_Fire_Incinerate',('Emperor Dagran Thaurissan','cross'):'Spell_Fire_SoulBurn',
 ('Nefarian','lanes'):'Spell_Fire_SoulBurn',('Princess Huhuran','cone'):'Spell_Nature_Acid_01',('C\'Thun','beam'):'Spell_Holy_MindVision',
 ('Anub\'Rekhan','seq'):'Spell_Nature_Earthquake',('Patchwerk','line'):'Ability_Warrior_PunishingBlow',('Sapphiron','towers'):'Spell_Frost_WindWalkOn',('Azuregos','cone'):'Spell_Frost_WindWalkOn',
 ('Kel\'Thuzad','cross'):'Spell_Frost_FrostWard',('Kel\'Thuzad','seq'):'Spell_Frost_Glacier',('Kel\'Thuzad','circle'):'Spell_Shadow_BlackPlague'}
def val(e,k):
    u=u32(e+k)
    if u==0: return 0
    if u<100000: return u
    return round(f32(e+k),3)
def ab(e, cd=None):
    k=b(e+0x2d)[0]
    if k==22: o=lambda off: val(e,off)
    elif k==31: o=lambda off: val(e,off-8)
    else: o=lambda off: val(e,off-4)
    def R(name_id, kind, p, dm, **x):
        n,ic=nm(name_id); r={'name':n,'icon':ic,'kind':kind,'p':p,'dm':dm}; r.update(x); return r
    if k==3: return R(o(4) or o(8),'circle',[o(12),o(16)],o(20))
    if k==4: return R(o(4),'bolts',[o(8)],0.45)
    if k==5: return {'name':'Calls for help','icon':'Ability_Warrior_BattleShout','kind':'adds','p':[o(4)],'dm':0}
    if k==6: return R(o(4),'nova',[o(8)],o(12))
    if k==7: return R(o(4),'charge',[],2)
    if k==8: return R(o(4),'cone',[o(8),o(12),o(16)],o(20))
    if k==9: return R(o(4),'line',[o(8),o(12),o(16)],o(20))
    if k==10: return R(o(4),'circles',[o(8),o(12),o(20)],o(24))
    if k==11:
        delay=o(20); follow=max(0,min(o(16) or 0, delay-0.6))
        return R(o(4),'follow',[o(12),round(follow,2),delay,o(28) or 0],o(24))
    if k==12: return R(o(4),'towers',[o(8),o(12),o(16) or 0,o(20)],o(24))
    if k==13: return R(o(4),'ring',[o(8) or 0,o(12),o(16)],o(20))
    if k==14: return R(o(4),'spin',[o(8),o(12)],o(16))
    if k==15: return R(o(4),'beam',[o(8),o(16),o(20)],o(24))
    if k==16: return R(o(4),'cross',[o(8),o(16)],o(20))
    if k==17: return R(o(4),'rows',[o(8),o(16),o(24),o(20)],o(28))
    if k==22:
        sub=u32(e)
        if sub==0: return {'name':'Eggs','icon':'INV_Misc_MonsterSpiderCarapace_01','kind':'eggs','p':[o(24),o(28),o(36)],'dm':0}
        if sub==1: return {'name':'Healing Ward','icon':'Spell_Holy_LayOnHands','kind':'heal_wards','p':[o(24),o(28)],'dm':0}
        if sub==2: return {'name':'Protectors','icon':'Spell_Nature_StoneSkinTotem','kind':'shield_totems','p':[o(24),o(28)],'dm':0}
        raise Exception('object %d'%sub)
    if k==19: return R(o(4),'knock',[o(8),o(16),o(20)],2)
    if k==21: return R(o(4),'vanish' if o(4)==1856 else 'blink',[o(8)],0)
    if k==23: return R(o(4),'shield',[o(8)],0)
    if k==24: return R(o(4),'orbs',[o(8),o(12),o(20)],o(24))
    if k==25: return R(o(4),'tether',[o(8),o(16)],o(20))
    if k==26: return R(o(4),'gaze',[o(8),o(12)],2)
    if k==27: return R(o(4),'waves',[o(8),o(16),o(20)],o(24))
    if k==28: return R(o(4),'burn',[o(8),o(12),o(16)],o(20))
    if k==29: return R(o(4),'lanes',[o(8),o(12),o(16),o(20),o(24)],o(28))
    if k==30: return R(o(4),'bomb',[o(8),o(12)],o(16))
    if k==31: return R(o(16),'meteors',[o(20),o(24),o(32)],o(36))
    if k==33: return R(o(4),'crystals',[o(8),o(12),o(16),o(20),o(24)],0)
    if k==34: return R(o(4),'root',[o(8)],0)
    if k==18:
        p,c=q(e),q(e+8); steps=[ab(p+j*0x30) for j in range(c)]
        first=[t for t in steps if t['kind'] not in ('adds',)]
        h=first[0] if first else steps[0]
        dm=max([t['dm'] for t in steps]+[0])
        return {'name':h['name'],'icon':h['icon'],'kind':'seq','steps':steps,'p':[val(e,16)],'dm':dm}
    if k==32 or k==0:
        p,c=q(e),q(e+8); steps=[]
        for j in range(c):
            t=ab(p+j*0x38); t['cd']=round(f32(p+j*0x38+0x30),2); steps.append(t)
        n,ic=nm(val(e,16))
        return {'name':n,'icon':ic,'kind':'stance','steps':steps,'p':[],'dm':0}
    raise Exception('kind %d'%k)
out={}; stats={}
for z in range(40):
    zv=Z+z*0xf0
    zn=try_str(zv+8)
    if not zn: break
    b0,n=q(zv+0x78),q(zv+0x80)
    for i in range(n):
        bv=b0+i*0x68; name=try_str(bv)
        a0,an=q(bv+16),q(bv+24); abl=[]
        for k in range(an):
            e=a0+k*0x38; x=ab(e); x['cd']=round(f32(e+0x30),2); abl.append(x)
        p0,pn=q(bv+48),q(bv+56); phs=[]
        for k in range(pn):
            e=p0+k*0x48; pct=int(round(f32(e+0x40)*100)); x=ab(e+0x10)
            if x['kind']=='adds': phs.append({'pct':pct,'adds':x['p'][0]})
            else: phs.append({'pct':pct,'a':x})
        phs.sort(key=lambda x:-x['pct'])
        # an icon twice on one boss's row: the later attack gets its own
        used=set()
        for x in abl:
            if x['icon'] in used:
                alt=ALT.get((name,x['kind']))
                assert alt, (name,x['kind'],x['icon'])
                x['icon']=alt
            used.add(x['icon'])
        out[name]={'abl':abl,'ph':phs}
        stats[name]=dict(minute=u32(bv+0x4c) if False else None, hp=f32(bv+0x54), hit=f32(bv+0x58), speed=round(f32(bv+0x5c),2), yell=try_str(bv+0x20))
json.dump(out,open('bossgen2.json','w'),indent=0)
json.dump(stats,open('stats2.json','w'),indent=0)
for b in ["Hogger","Mr. Smite","Edwin VanCleef","Ossirian the Unscarred","C'Thun","Kel'Thuzad"]:
    print(b, json.dumps(out[b])[:1500]); print()
