"""Simulasi menyeluruh: PLC (program ASLI dari .cxp, interpreter) <-> Modbus slave ASLI firmware ESP32 (modbus_slave.cpp + library 4.1.1)."""
import subprocess, struct
from exec_sim import PLC, load_program, SCAN, HW
BYTE_US=1041.67   # 9600 8N1 = 10 bit/karakter
def crc16(data):
    crc=0xFFFF
    for b in data:
        crc^=b
        for _ in range(8): crc=(crc>>1)^0xA001 if crc&1 else crc>>1
    return crc
class Harness:
    def __init__(s,exe='./mbslave'):
        s.p=subprocess.Popen([exe],stdin=subprocess.PIPE,stdout=subprocess.PIPE,text=True,bufsize=1); s.tx=[]
    def cmd(s,line):
        s.p.stdin.write(line+'\n'); s.p.stdin.flush()
        while True:
            r=s.p.stdout.readline().strip()
            if r.startswith('TX'):
                for tok in r.split()[1:]:
                    t,b=tok.split(':'); s.tx.append((int(t),int(b,16)))
                continue
            return r
    def now(s): return int(s.cmd('NOW').split()[1])
    def state(s): return list(map(int,s.cmd('STATE').replace('cmd=',' ').replace('comfail=',' ').split()[1:]))
    def close(s): s.p.stdin.write('QUIT\n'); s.p.stdin.flush(); s.p.wait(timeout=5)
def omron_request(D):
    """Bentuk frame yang dikirim Easy Master dari kata perintah D1200..D1204 (slave, FC, jumlah byte, data)."""
    sl,fc,n=D[0]&0xFF,D[1]&0xFF,D[2]
    data=b''.join(struct.pack('>H',w) for w in D[3:])[:n]
    f=bytes([sl,fc])+data
    return f+struct.pack('<H',crc16(f))
def expected_len(D):
    fc=D[1]
    return 5+2*D[4] if fc in (3,4) else 8
class RigHW:
    def __init__(s,path,timeout_ms=1000,block_ms=420,lru_bug=True,connected=True,swap_txrx=False):
        s.plc=PLC(load_program(path)); s.h=Harness(); s.t=0; s.hw=_H(s)
        s.timeout=timeout_ms; s.block_us=block_ms*1000; s.lru_bug=lru_bug; s.connected=connected; s.swap=swap_txrx
        s.sensor=[220.0,219.0,1.2,1.1,0]; s.em={'busy':False}; s.stats={'tx':0,'ok':0,'err':0,'stale':0,'timeout':0,'badframe':0}
        s.h.cmd('INIT'); s.next_block=500_000; s.cur_us=0; s.apply_esp_state(); s.log=[]
    def apply_esp_state(s):
        s.h.cmd('SENSOR '+' '.join(str(x) for x in s.sensor))
        # main.cpp memanggil modbusUpdateLRUFail(statusMqttTerhubung); parameter fungsi adalah 'statusFail'
        fail=(0 if s.connected else 1) if not s.lru_bug else (1 if s.connected else 0)
        s.h.cmd(f'LRU {fail}')
    def advance_esp(s,until_us):
        while s.cur_us<until_us:
            nxt=min(until_us,s.next_block)
            s.h.cmd(f'RUN {nxt}'); s.cur_us=max(nxt,s.h.now())
            if nxt==s.next_block and s.cur_us<=s.next_block+5000:
                s.h.cmd(f'JUMP {s.next_block+s.block_us}'); s.cur_us=s.h.now(); s.apply_esp_state(); s.next_block+=1_000_000
            if s.cur_us<nxt: s.cur_us=nxt
    def peripheral(s):
        p=s.plc; now=s.t*1000
        if p.bit('A640.00') and not s.em['busy']:
            D=[p.word(f'D{1200+i}') for i in range(5)]
            s.em.update(busy=True,start=s.t,D=D,req=omron_request(D),n=expected_len(D)); s.stats['tx']+=1
            p.setbit('A640.01',False); p.setbit('A640.02',False)
            s.h.tx=[]    # PLC membuang sisa byte lama saat memulai transaksi baru
            if not s.swap: s.h.cmd('RXAT %d %s'%(now,s.em['req'].hex()))
        s.advance_esp(now+SCAN*1000)
        if not s.em['busy']: s.h.tx=[]; return
        if s.h.tx and max(t for t,_ in s.h.tx)>=0:
            bursts={}
            for t,b in s.h.tx: bursts.setdefault(t,[]).append(b)
            t_w=min(bursts); frame=bytes(bursts[t_w]); done_us=t_w+len(frame)*BYTE_US
            if done_us<=now+SCAN*1000 and (done_us-s.em['start']*1000)/1000<=s.timeout:
                s.h.tx=[]; s.finish(frame)
                return
        if s.t-s.em['start']>=s.timeout:
            p.setword('D1252',0x80); p.setbit('A640.02',True); p.setbit('A640.00',False); s.em['busy']=False; s.stats['err']+=1; s.stats['timeout']+=1
    def finish(s,frame):
        p=s.plc; D=s.em['D']
        ok=len(frame)>=5 and crc16(frame[:-2])==struct.unpack('<H',frame[-2:])[0] and frame[0]==D[0]&0xFF
        if ok and frame[1]==(D[1]&0xFF):
            data=frame[2:-2]
            if D[1] in (3,4): bc=data[0]; words=[struct.unpack('>H',data[1+2*i:3+2*i])[0] for i in range(bc//2)]
            else: bc=len(data); words=[struct.unpack('>H',data[2*i:2*i+2])[0] for i in range(bc//2)]
            for i,w in enumerate([frame[0],frame[1],0,bc]+words): p.setword(f'D{1250+i}',w)
            p.setbit('A640.01',True); s.stats['ok']+=1
        else:
            p.setword('D1252',(frame[2] if ok and len(frame)>2 else 0x81)); p.setbit('A640.02',True); s.stats['err']+=1; s.stats['badframe']+=1
        p.setbit('A640.00',False); s.em['busy']=False
    def step(s,sec):
        for _ in range(int(sec*1000/SCAN)):
            s.plc.scan(s.hw); s.peripheral(); s.t+=SCAN
    def press(s,k,sec=0.3):
        s.hw[k]=True; s.step(sec); s.hw[k]=False; s.step(0.2)
    def close(s): s.h.close()
class _H(dict):
    def __init__(s,rig): super().__init__(); s.rig=rig
    def __setitem__(s,k,v): super().__setitem__(HW.get(k,k),v)
    def __getitem__(s,k): return super().__getitem__(HW.get(k,k))
