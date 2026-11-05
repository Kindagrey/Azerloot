import json,re
def num(v):
    if isinstance(v,bool): return str(v).lower()
    if isinstance(v,int): return str(v)
    if isinstance(v,float):
        if v==int(v): return str(int(v))
        return ('%.3f'%v).rstrip('0').rstrip('.')
    return v
def lstr(s): return '"'+s.replace('\\','\\\\').replace('"','\\"')+'"'
def ab_lua(a):
    parts=['name = '+lstr(a['name']),'icon = '+lstr(a['icon']),'kind = '+lstr(a['kind'])]
    if a['kind'] in ('seq','stance'):
        parts.append('p = { '+', '.join(num(x) for x in a['p'])+' }' if a['p'] else 'p = {  }')
        parts.append('steps = { '+', '.join(ab_lua(s) for s in a['steps'])+' }')
    else:
        parts.append('p = { '+', '.join(num(x) for x in a['p'])+' }' if a['p'] else 'p = {  }')
    if 'cd' in a: parts.append('cd = '+num(a['cd']))
    parts.append('dm = '+num(a['dm']))
    return '{ '+', '.join(parts)+' }'
def boss_lua(rec):
    out='abilities = { '+', '.join(ab_lua(a) for a in rec['abl'])+' }'
    if rec['ph']:
        ph=[]
        for p in rec['ph']:
            if 'adds' in p: ph.append('{ pct = %d, adds = %s }'%(p['pct'],num(p['adds'])))
            else: ph.append('{ pct = %d, a = %s }'%(p['pct'],ab_lua(p['a'])))
        out+=', phases = { '+', '.join(ph)+' }'
    return out
if __name__=='__main__':
    b=json.load(open('bossgen2.json'))
    lua=open('/home/claude/azerloot/data/BossLoot.lua',encoding='utf-8').read()
    bad=0
    for m in re.finditer(r'\{ name = "((?:[^"\\]|\\.)+)", minute = \d+,.*?\n      icon = "[^"]+", (abilities = .*?) \},\n',lua):
        n=m.group(1).replace('\\"','"'); cur=m.group(2)
        if n not in b: continue
        new=boss_lua(b[n])
        if new!=cur:
            bad+=1; print('DIFF',n); print('  cur',cur[:300]); print('  new',new[:300])
    print('bad',bad)
