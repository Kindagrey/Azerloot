import numpy as np, sys
exec(open('pe.py').read())
tx=[x for x in secs if x[0]=='.text'][0]
ra,rs,sva=tx[3],tx[4],tx[1]
arr=np.frombuffer(d,dtype=np.uint8,count=rs,offset=ra)
# int32 at every byte offset
b=arr.astype(np.int64)
disp=(b[:-3] | (b[1:-2]<<8) | (b[2:-1]<<16) | (b[3:]<<24))
disp=np.where(disp>=2**31, disp-2**32, disp)
pos=np.arange(len(disp))
nextva=BASE+sva+pos+4
def find(target):
    idx=np.nonzero(nextva+disp==target)[0]
    return [BASE+sva+int(i) for i in idx]
if __name__=='__main__':
    for t in sys.argv[1:]:
        print(t,[hex(x) for x in find(int(t,16))])
