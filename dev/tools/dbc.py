import struct, os
D=os.path.dirname(os.path.abspath(__file__))
def load(path):
    d=open(path,'rb').read()
    assert d[:4]==b'WDBC'
    n,f,rs,ss=struct.unpack_from('<IIII',d,4)
    recs=d[20:20+n*rs]; strs=d[20+n*rs:20+n*rs+ss]
    return n,f,rs,recs,strs
def cstr(strs,o):
    e=strs.find(b'\0',o); return strs[o:e].decode('utf-8','replace')
def spells():
    n,f,rs,recs,strs=load(D+'/Spell.dbc')
    ni,fi,ri,reci,stri=load(D+'/SpellIcon.dbc')
    icons={}
    for i in range(ni):
        id_,so=struct.unpack_from('<II',reci,i*ri)
        p=cstr(stri,so); icons[id_]=p.split('\\')[-1]
    out={}
    for i in range(n):
        r=recs[i*rs:(i+1)*rs]
        id_=struct.unpack_from('<I',r,0)[0]
        icon=struct.unpack_from('<I',r,117*4)[0]
        name=cstr(strs,struct.unpack_from('<I',r,120*4)[0])
        out[id_]=(name,icons.get(icon,''))
    return out
if __name__=='__main__':
    S=spells(); print(len(S)); 
    for i in [845,17364,8017,16038,331,1535,23881,1856]: print(i,S.get(i))
