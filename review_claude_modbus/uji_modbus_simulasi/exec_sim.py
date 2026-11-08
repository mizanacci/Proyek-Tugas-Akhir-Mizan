"""Interpreter mnemonic Omron (subset CP1E) yang menjalankan program ASLI dari file .cxp hasil buatan."""
import re, sys
SCAN=10  # ms

def load_program(path):
    if path.endswith('.cxp'): raise SystemExit('Gunakan file .cxt (teks), bukan .cxp')
    txt=open(path,'rb').read().decode('utf-8-sig').replace('\r\n','\n')
    sec=txt[txt.index('SecName:="LOGIKA_UTAMA"'):txt.index('Sec[1]:=')]
    rungs=[]
    for m in re.finditer(r'Com:="([^"]*)";.*?SL:=\n\$\?St\$Bk\?_#\[\d+\]\n(.*?)\n\$\?St\$Bk\?_#\[\d+\]',sec,re.S):
        lines=[l for l in m.group(2).split('\n') if l and not l.startswith("'")]
        rungs.append((m.group(1),lines))
    return rungs

class Timer:
    def __init__(s,sv): s.sv=sv; s.el=0; s.flag=False

class PLC:
    def __init__(s,rungs):
        s.rungs=rungs; s.w={}; s.t={}; s.prev={}; s.first=True; s.force={}
    # --- memori ---
    @staticmethod
    def key(a):
        m=re.fullmatch(r'(W|D|A|H)?(\d+)(?:\.(\d{2}))?',a); area,num,bit=m.groups()
        return (area or 'C')+num,(int(bit) if bit is not None else None)
    def bit(s,a):
        if a=='P_On': return True
        if a=='P_First_Cycle': return s.first
        m=re.fullmatch(r'T(\d+)',a)
        if m: return s.t[int(m.group(1))].flag if int(m.group(1)) in s.t else False
        if a in s.force: return s.force[a]
        k,b=s.key(a); return bool((s.w.get(k,0)>>b)&1)
    def setbit(s,a,v):
        k,b=s.key(a); x=s.w.get(k,0)
        s.w[k]=(x|(1<<b)) if v else (x&~(1<<b))
    def word(s,a): return s.w.get(s.key(a)[0],0)
    def setword(s,a,v): s.w[s.key(a)[0]]=v&0xFFFF
    def val(s,x):
        if x.startswith('#'): return int(x[1:],16)
        if x.startswith('&'): return int(x[1:])
        return s.word(x)
    @staticmethod
    def nextw(a,i): m=re.fullmatch(r'([A-Z]+)(\d+)',a); return f'{m.group(1)}{int(m.group(2))+i}'
    # --- eksekusi satu rung ---
    def run(s,idx,lines):
        st=[]
        for li,ln in enumerate(lines):
            tok=ln.split(); op=tok[0]
            if op=='ORLD': b=st.pop(); a=st.pop(); st.append(a or b); continue
            if op=='ANDLD': b=st.pop(); a=st.pop(); st.append(a and b); continue
            m=re.fullmatch(r'(LD|AND|OR)(NOT)?(<>|<=|>=|=|<|>)?(?:\((\d+)\))?',op)
            if m and (m.group(1)):
                kind,neg,cmp_=m.group(1),m.group(2),m.group(3)
                if cmp_:
                    a,b=s.val(tok[1]),s.val(tok[2])
                    v={'=':a==b,'<>':a!=b,'<':a<b,'<=':a<=b,'>':a>b,'>=':a>=b}[cmp_]
                else:
                    v=s.bit(tok[1]); v=(not v) if neg else v
                if kind=='LD': st.append(v)
                elif kind=='AND': st[-1]=st[-1] and v
                else: st[-1]=st[-1] or v
                continue
            cond=st[-1] if st else True
            if op=='OUT': s.setbit(tok[1],cond)
            elif op=='SET':
                if cond: s.setbit(tok[1],True)
            elif op=='RSET':
                if cond: s.setbit(tok[1],False)
            elif op=='DIFU(013)':
                k=(idx,li); pulse=cond and not s.prev.get(k,False); s.prev[k]=cond; s.setbit(tok[1],pulse)
            elif op=='TIM':
                n=int(tok[1]); sv=int(tok[2][1:])*100   # BCD 0,1 s
                tm=s.t.setdefault(n,Timer(sv))
                if cond: tm.el+=SCAN; tm.flag=tm.el>=tm.sv
                else: tm.el=0; tm.flag=False
            elif op=='MOV(021)':
                if cond: s.setword(tok[2],s.val(tok[1]))
            elif op=='XFER(070)':
                if cond:
                    n=s.val(tok[1])
                    for i in range(n): s.setword(s.nextw(tok[3],i),s.word(s.nextw(tok[2],i)))
            elif op=='END(001)': return
            else: raise ValueError('instruksi tak dikenal: '+ln)
    def scan(s,inputs):
        for a,v in inputs.items(): s.setbit(a,v)
        for i,(com,lines) in enumerate(s.rungs): s.run(i,lines)
        s.first=False
    def coil(s): return s.bit('100.00')

class ESP32:
    def __init__(s): s.connected=True; s.ireg=[22000,21900,1200,1100,0,0]; s.hreg6=0; s.block=None; s.writes=0
    def blocked_until(s,t):
        return s.block(t) if s.block else t       # waktu paling awal ESP32 bisa menjawab
    def handle(s,cmd):
        sl,fc,_,a,n=cmd
        if fc==4: return [sl,4,0,2*n]+s.ireg[a:a+n]
        if fc==3: return [sl,3,0,2*n]+[s.hreg6]
        if fc==6: s.hreg6=n; s.writes+=1; return [sl,6,0,4,a,n]

class Rig:
    def __init__(s,path,timeout_ms=1000,mode='normal'):
        s.plc=PLC(load_program(path)); s.esp=ESP32(); s.t=0; s.hw={}
        s.timeout=timeout_ms; s.mode=mode; s.em={'busy':False}; s.tx=0; s.ok=0; s.err=0
    def peripheral(s):
        p=s.plc
        if p.bit('A640.00') and not s.em['busy'] and s.mode!='hang':
            s.em.update(busy=True,start=s.t,cmd=[p.word(f'D{1200+i}') for i in range(5)])
            p.setbit('A640.01',False); p.setbit('A640.02',False); s.tx+=1
            ready=s.esp.blocked_until(s.t)+30 if s.esp.connected else None
            s.em['resp_at']=ready
        if s.em['busy']:
            ra=s.em['resp_at']; dl=s.em['start']+s.timeout
            if ra is not None and ra<=dl and s.t>=ra:
                r=s.esp.handle(s.em['cmd'])
                for i,v in enumerate(r): p.setword(f'D{1250+i}',v)
                p.setbit('A640.01',True); p.setbit('A640.00',False); s.em['busy']=False; s.ok+=1
            elif s.t>=dl:
                p.setword('D1252',0x80); p.setbit('A640.02',True); p.setbit('A640.00',False); s.em['busy']=False; s.err+=1
    def step(s,sec):
        for _ in range(int(sec*1000/SCAN)):
            s.plc.scan(s.hw); s.peripheral(); s.t+=SCAN
    def press(s,k,sec=0.3):
        s.hw[k]=True; s.step(sec); s.hw[k]=False; s.step(0.2)
HW={'LOCK':'0.00','UNLOCK':'0.01','NO':'0.02','NC':'0.03','HMI_NO':'W10.00','HMI_NC':'W10.01'}
def mk(path,**kw):
    r=Rig(path,**kw); r.hw=_H(r); return r
class _H(dict):
    def __init__(s,rig): super().__init__(); s.rig=rig
    def __setitem__(s,k,v): super().__setitem__(HW.get(k,k),v)
    def __getitem__(s,k): return super().__getitem__(HW.get(k,k))
