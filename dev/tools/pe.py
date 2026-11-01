import struct,re
d=open('game.exe','rb').read()
pe=struct.unpack_from('<I',d,0x3c)[0]; n=struct.unpack_from('<H',d,pe+6)[0]; opt=struct.unpack_from('<H',d,pe+20)[0]
BASE=struct.unpack_from('<Q',d,pe+24+24)[0]; o=pe+24+opt; secs=[]
for i in range(n):
    nm=d[o:o+8].rstrip(b'\0').decode(); vs,va,rs,ra=struct.unpack_from('<IIII',d,o+8); secs.append((nm,va,vs,ra,rs)); o+=40
def off(va):
    v=va-BASE
    for nm,sva,vs,ra,rs in secs:
        if sva<=v<sva+max(vs,rs): return ra+v-sva
def va_of(fo):
    for nm,sva,vs,ra,rs in secs:
        if ra<=fo<ra+rs: return BASE+sva+fo-ra
def q(va): return struct.unpack_from('<Q',d,off(va))[0]
def f32(va): return struct.unpack_from('<f',d,off(va))[0]
def u32(va): return struct.unpack_from('<I',d,off(va))[0]
def sstr(va):
    p,l=q(va),q(va+8)
    if BASE<=p<BASE+0x10000000 and 0<l<400:
        o2=off(p)
        if o2 is None: return None
        try: return d[o2:o2+l].decode('utf-8')
        except: return None
def refs(s):
    out=[]
    vas=set(va_of(m.start()) for m in re.finditer(re.escape(s),d))
    rd=[x for x in secs if x[0]=='.rdata'][0]
    for o in range(rd[3],rd[3]+rd[4]-16,8):
        p,l=struct.unpack_from('<QQ',d,o)
        if l==len(s) and p in vas: out.append(va_of(o))
    return out
