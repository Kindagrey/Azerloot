import re
def unlua(s):
    return re.sub(r'\\(.)', lambda m: {'n':'\n','t':'\t'}.get(m.group(1), m.group(1)), s)
def parse(path):
    txt=open(path,encoding='utf-8').read()
    out={}
    for m in re.finditer(r'^Azerloot_TT\.(\w+) = \{\n(.*?)^\}\n', txt, re.S|re.M):
        lg, body = m.group(1), m.group(2)
        ex={}; tp=[]
        exm=re.search(r'^  exact = \{\n(.*?)^  \},\n', body, re.S|re.M)
        for e in re.finditer(r'^    \["((?:[^"\\]|\\.)*)"\] = "((?:[^"\\]|\\.)*)",$', exm.group(1), re.M):
            ex[unlua(e.group(1))]=unlua(e.group(2))
        tm=re.search(r'^  tpl = \{\n(.*?)^  \},\n', body, re.S|re.M)
        for e in re.finditer(r'^    \{ "((?:[^"\\]|\\.)*)", \{ (.*?) \}, "((?:[^"\\]|\\.)*)" \},$', tm.group(1), re.M):
            tp.append((unlua(e.group(1)), re.findall(r'"(.*?)"', e.group(2)), unlua(e.group(3))))
        lab=re.search(r'^  labels = (.*)$', body, re.M).group(1)
        out[lg]=dict(exact=ex,tpl=tp,labels=lab)
    return out,txt
if __name__=='__main__':
    o,_=parse('/home/claude/azerloot/locales/Tooltips.lua')
    for lg,v in o.items(): print(lg,len(v['exact']),len(v['tpl']))
