import sys; sys.path.insert(0,'.')
from rig_hw import *
P=sys.argv[1] if len(sys.argv)>1 else 'SCADA_CP1E_Mizan.cxt'
def D(r,n): return r.plc.word(n)
print('=== E2: perintah remote dari aplikasi (HREG 6) — firmware apa adanya vs LRUFail diperbaiki ===')
for bug in (True,False):
    r=RigHW(P,timeout_ms=1000,block_ms=420,lru_bug=bug); r.step(4); r.press('UNLOCK'); r.step(4)
    r.h.cmd('CMD 2'); r.step(4); closed=r.plc.coil(); h6=r.h.state()[6]
    r.h.cmd('CMD 1'); r.step(4); opened=not r.plc.coil()
    print(f"  lru_bug={bug}: IREG5 di PLC(D115)={D(r,'D115')} LRUFAIL(W1.00)={r.plc.bit('W1.00')} | CMD NC -> koil tertutup={closed} (HREG6 setelah={h6}) | CMD NO -> koil terbuka={opened} | stat={r.stats}")
    r.close()
print('=== E3: Response Timeout Easy Master vs ESP32 sibuk membaca ADC (420 ms tiap detik), 40 s, firmware diperbaiki ===')
for to in (100,200,300,500,1000,2000):
    r=RigHW(P,timeout_ms=to,block_ms=420,lru_bug=False); com=False
    for _ in range(4000): r.step(0.01); com|=r.plc.bit('W1.01')
    s=r.stats; print(f"  timeout={to:>4} ms: transaksi={s['tx']:>3} sukses={s['ok']:>3} error={s['err']:>3} (timeout={s['timeout']}, frame rusak={s['badframe']}) | COMFail pernah menyala={com} | D110={D(r,'D110')}")
    r.close()
print('=== E4: TX/RX tertukar (tidak ada jawaban) ===')
r=RigHW(P,timeout_ms=1000,lru_bug=False,swap_txrx=True); t0=None; fail=None
for i in range(1000):
    r.step(0.01)
    if fail is None and r.plc.bit('W1.01'): fail=r.t/1000
print(f"  COMFail menyala pada t={fail} s; transaksi={r.stats['tx']} sukses={r.stats['ok']}"); r.close()
print('=== E5: frame cacat langsung ke slave ESP32 ===')
h=Harness(); h.cmd('INIT'); h.cmd('SENSOR 220 219 1.2 1.1 0'); h.cmd('LRU 0')
def ask(label,frame,t0):
    h.tx=[]; h.cmd('RXAT %d %s'%(t0,frame.hex())); h.cmd('RUN %d'%(t0+60000))
    print(f"  {label:<44}-> "+(bytes(b for _,b in h.tx).hex(' ') if h.tx else '(tidak ada jawaban)'))
t=h.now()+10000
good=omron_request([1,4,4,0,6]); bad=good[:-1]+bytes([good[-1]^1])
ask('FC04 0..5 (valid)',good,t); t=h.now()+10000
ask('CRC salah',bad,t); t=h.now()+10000
ask('slave ID 2',omron_request([2,4,4,0,6]),t); t=h.now()+10000
ask('FC04 jumlah 7 (di luar IREG 0-5)',omron_request([1,4,4,0,7]),t); t=h.now()+10000
ask('FC03 HREG 5 (tidak ada)',omron_request([1,3,4,5,1]),t); t=h.now()+10000
ask('FC06 HREG 6 = 0 (ack)',omron_request([1,6,4,6,0]),t)
h.close()
