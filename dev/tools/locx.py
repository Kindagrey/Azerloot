import re, json, sys
d=open(sys.argv[1],'rb').read()
blocks={}
for m in re.finditer(rb'\{\r?\n  "game\.title"', d):
    i=m.start(); j=d.find(b'\n}', i)
    try: obj=json.loads(d[i:j+2].decode('utf-8','replace'))
    except Exception: obj=None
    blocks[len(blocks)]=obj
json.dump(blocks, open(sys.argv[2],'w'), ensure_ascii=False)
print({k:(len(v) if v else None) for k,v in blocks.items()})
