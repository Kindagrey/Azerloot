import json, re, sys
sys.path.insert(0,'/home/claude/work/tt')
LG={'de':3,'fr':6,'es':5,'pt':4}
PH=re.compile(r'\{(\w+)\}|%[sd]')
def luapat(s): return re.sub(r'([\^\$\(\)\%\.\[\]\*\+\-\?])', r'%\1', s)
def unlua(s): return re.sub(r'\\(.)', lambda m: {'n':'\n','t':'\t'}.get(m.group(1), m.group(1)), s)
def lua(x): return '"'+x.replace('\\','\\\\').replace('"','\\"').replace('\n','\\n')+'"'
def parse(path):
    txt=open(path,encoding='utf-8').read(); out={}
    for m in re.finditer(r'^Azerloot_GT\.(\w+) = \{\n(.*?)^\}\n', txt, re.S|re.M):
        lg, body = m.group(1), m.group(2); ex=[]; tp=[]
        exm=re.search(r'^  exact = \{\n(.*?)^  \},\n', body, re.S|re.M)
        for e in re.finditer(r'^    \["((?:[^"\\]|\\.)*)"\] = "((?:[^"\\]|\\.)*)",$', exm.group(1), re.M):
            ex.append((unlua(e.group(1)),unlua(e.group(2))))
        tm=re.search(r'^  tpl = \{\n(.*?)^  \},\n', body, re.S|re.M)
        for e in re.finditer(r'^    \{ "((?:[^"\\]|\\.)*)", \{ (.*?) \}, "((?:[^"\\]|\\.)*)" \},$', tm.group(1), re.M):
            tp.append((unlua(e.group(1)), re.findall(r'"(.*?)"', e.group(2)), unlua(e.group(3))))
        out[lg]=dict(exact=ex,tpl=tp)
    return out,txt
def build(B, lg):
    en=B['0']; tr=B[str(LG[lg])]; exact=[]; tpl=[]; seenx=set(); seent=set()
    for k,e in en.items():
        t=tr.get(k)
        if not isinstance(t,str) or not isinstance(e,str): continue
        e=e.strip(); t=t.strip()
        if t==e or t=='' or e=='': continue
        if not PH.search(e):
            if e not in seenx: seenx.add(e); exact.append((e,t))
            continue
        names=[]; parts=[]; pos=0; n=0
        for m in PH.finditer(e):
            parts.append(luapat(e[pos:m.start()]))
            if m.group(1): names.append(m.group(1))
            else: n+=1; names.append('_%d'%n)
            parts.append('(.-)'); pos=m.end()
        parts.append(luapat(e[pos:]))
        pat='^'+''.join(parts)+'$'
        cnt=[0]
        def r2(m): cnt[0]+=1; return '{_%d}'%cnt[0]
        tt=re.sub(r'%[sd]', r2, t)
        if pat in seent: continue
        if len(re.findall(r'\w', PH.sub('',e)))<2: continue
        seent.add(pat); tpl.append((pat,names,tt))
    return exact,tpl
def merge(B, cur_path, out_path):
    cur,txt=parse(cur_path)
    head=txt[:txt.index('Azerloot_GT.de = {')]
    out=[head.rstrip('\n')]; stats={}
    for lg in ['de','fr','es','pt']:
        ex,tp=build(B,lg); c=cur[lg]
        have=set(k for k,_ in c['exact']); exact=list(c['exact']); addx=0
        for k,v in ex:
            if k not in have: exact.append((k,v)); have.add(k); addx+=1
        havep=set(p for p,_,_ in c['tpl']); newt=[]; addt=0
        for p,n,t in tp:
            if p not in havep: newt.append((p,n,t)); havep.add(p); addt+=1
        pats=newt+list(c['tpl'])
        stats[lg]=(addx,addt)
        out.append('Azerloot_GT.%s = {'%lg); out.append('  exact = {')
        for k,v in exact: out.append('    [%s] = %s,'%(lua(k),lua(v)))
        out.append('  },'); out.append('  tpl = {')
        for p,n,t in pats: out.append('    { %s, { %s }, %s },'%(lua(p),', '.join(lua(x) for x in n),lua(t)))
        out.append('  },'); out.append('}')
    open(out_path,'w',encoding='utf-8').write('\n'.join(out)+'\n')
    return stats
if __name__=='__main__':
    B=json.load(open(sys.argv[1])); print(merge(B, sys.argv[2], sys.argv[3]))
