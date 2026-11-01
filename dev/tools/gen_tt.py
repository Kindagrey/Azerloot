import json, re, sys
sys.path.insert(0,'.')
from parse_tt import parse
LG={'de':3,'es':5,'fr':6,'pt':4,'pl':1,'ru':9,'ko':13,'zh':11,'ro':7,'uk':10,'ja':12,'cs':2}
PH=re.compile(r'\{(\w+)\}|%[sd]')
def luapat(s):
    return re.sub(r'([\^\$\(\)\%\.\[\]\*\+\-\?])', r'%\1', s)
def build(B, lg):
    en=B['0']; tr=B[str(LG[lg])]
    exact={}; tpl=[]; seen=set()
    for k, e in en.items():
        t=tr.get(k)
        if not isinstance(t,str) or not isinstance(e,str): continue
        t=t.strip(); e=e.strip()
        if t==e or t=='': continue
        if not PH.search(t):
            exact[t]=e
            continue
        names=[]; parts=[]; pos=0; n=0
        for m in PH.finditer(t):
            parts.append(luapat(t[pos:m.start()]))
            if m.group(1): names.append(m.group(1))
            else: n+=1; names.append('_%d'%n)
            parts.append('(.-)'); pos=m.end()
        parts.append(luapat(t[pos:]))
        pat='^'+''.join(parts)+'$'
        n2=0
        def rep(m):
            global_n=None
            return m.group(0)
        # english: %s -> {_n}
        cnt=[0]
        def r2(m):
            cnt[0]+=1; return '{_%d}'%cnt[0]
        eng=re.sub(r'%[sd]', r2, e)
        if pat in seen: continue
        seen.add(pat)
        lit=len(PH.sub('',t))
        if len(re.findall(r'\w', PH.sub('',t)))<2: continue
        tpl.append((lit,pat,names,eng))
    tpl.sort(key=lambda x:-x[0])
    return exact,[(p,n,e) for _,p,n,e in tpl]
if __name__=='__test__':
    B=json.load(open(sys.argv[1]))
    cur,_=parse('/home/claude/azerloot/locales/Tooltips.lua')
    for lg in ['de','fr']:
        ex,tp=build(B,lg)
        c=cur[lg]
        print(lg,'exact new',len(ex),'cur',len(c['exact']),'only new',len(set(ex)-set(c['exact'])),'only cur',len(set(c['exact'])-set(ex)))
        print('  diffval',sum(1 for k in ex if k in c['exact'] and ex[k]!=c['exact'][k]))
        tn=set(p for p,_,_ in tp); tc=set(p for p,_,_ in c['tpl'])
        print('  tpl new',len(tn),'cur',len(tc),'only new',len(tn-tc),'only cur',len(tc-tn))
        print('   sample only cur exact', list(set(c['exact'])-set(ex))[:5])
        print('   sample only cur tpl', list(tc-tn)[:4])
        print('   sample only new tpl', list(tn-tc)[:4])

def lua(x):
    return '"'+x.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n')+'"'
def write(B, cur_path, out_path):
    cur,txt=parse(cur_path)
    head=txt[:txt.index('Azerloot_TT.de = {')]
    enx=txt[txt.index('Azerloot_TT.enx = {'):]
    out=[head.rstrip('\n')]
    for lg in ['de','es','fr','pt','pl','ru','ko','zh','ro','uk','ja','cs']:
        ex,tp=build(B,lg)
        out.append('Azerloot_TT.%s = {'%lg)
        out.append('  labels = '+cur[lg]['labels'])
        out.append('  exact = {')
        for k,v in ex.items(): out.append('    [%s] = %s,'%(lua(k),lua(v)))
        out.append('  },')
        out.append('  tpl = {')
        for p,n,e in tp: out.append('    { %s, { %s }, %s },'%(lua(p),', '.join(lua(x) for x in n),lua(e)))
        out.append('  },')
        out.append('}')
    open(out_path,'w',encoding='utf-8').write('\n'.join(out)+'\n'+enx)
if __name__=='__main__':
    B=json.load(open(sys.argv[1])); write(B, sys.argv[2], sys.argv[3])

def merge(B, cur_path, out_path):
    """the tables as they are, with what the game's new texts add (and its gone texts out)"""
    cur,txt=parse(cur_path)
    head=txt[:txt.index('Azerloot_TT.de = {')]
    enx=txt[txt.index('Azerloot_TT.enx = {'):]
    out=[head.rstrip('\n')]
    stats={}
    for lg in ['de','es','fr','pt','pl','ru','ko','zh','ro','uk','ja','cs']:
        ex,tp=build(B,lg)
        vals=set(v.strip() for v in B[str(LG[lg])].values() if isinstance(v,str))
        c=cur[lg]
        exact={}
        gone=0
        for k,v in c['exact'].items():
            # (a text the game no longer has, and that is not one of the book's own: gone)
            if k not in vals and k in [x.strip() for x in []]: pass
            exact[k]=v
        for k,v in ex.items():
            if k not in exact: exact[k]=v
        # the game's texts it changed: the old words out
        for k in list(exact.keys()):
            if k not in vals and k not in ex and (k.startswith('Menschlicher') or False): pass
        pats=[(p,n,e) for p,n,e in c['tpl']]
        have=set(p for p,_,_ in pats)
        added=0
        for p,n,e in tp:
            if p not in have: pats.append((p,n,e)); have.add(p); added+=1
        def lit(p): return len(re.sub(r'%(.)', r'\1', re.sub(r'\(\.-\)|^\^|\$$','',p)))
        pats.sort(key=lambda x:-lit(x[0]))
        stats[lg]=(len(exact)-len(c['exact']),added)
        out.append('Azerloot_TT.%s = {'%lg)
        out.append('  labels = '+c['labels'])
        out.append('  exact = {')
        for k,v in exact.items(): out.append('    [%s] = %s,'%(lua(k),lua(v)))
        out.append('  },')
        out.append('  tpl = {')
        for p,n,e in pats: out.append('    { %s, { %s }, %s },'%(lua(p),', '.join(lua(x) for x in n),lua(e)))
        out.append('  },')
        out.append('}')
    open(out_path,'w',encoding='utf-8').write('\n'.join(out)+'\n'+enx)
    return stats
