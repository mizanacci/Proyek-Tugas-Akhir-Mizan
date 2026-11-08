import sys
from exec_sim import *
PATH=sys.argv[1] if len(sys.argv)>1 else 'SCADA_CP1E_Mizan.cxt'
res=[]
def check(n,c): res.append(c); print(('PASS ' if c else 'FAIL ')+n)
def new(**kw): return mk(PATH,**kw)

r=new(); p=r.plc
check('S0 program dimuat: 41 rung', len(p.rungs)==41)
r.step(3)
check('S1 power-on: Hot Line = LOCK dan koil OFF', p.bit('W0.00') and not p.coil())
check('S1 ambang batas dimuat (D120..D123)', [p.word(f'D{x}') for x in (120,121,122,123)]==[19800,24200,2000,5000])
check('S1 data IREG tersalin D110..D115', [p.word(f'D{110+i}') for i in range(6)]==[22000,21900,1200,1100,0,0])
check('S1 COMFail NORMAL saat komunikasi sehat', not p.bit('W1.01'))

# ---- Tabel 3.25: sembilan skenario ----
def lock(r):   r.press('LOCK')
def unlock(r): r.press('UNLOCK')
def fresh(state):
    r=new(); r.step(4)
    if state=='UNLOCK': r.press('UNLOCK')
    return r
# 1
r=fresh('LOCK'); r.press('NC'); a=r.plc.coil(); r.press('NO'); b=not r.plc.coil()
check('T1 LOCK + push button -> relay merespons (NC lalu NO)', a and b)
# 2
r=fresh('LOCK'); r.press('HMI_NC'); check('T2 LOCK + HMI -> diabaikan', not r.plc.coil())
# 3
r=fresh('LOCK'); r.esp.hreg6=2; r.step(2.5)
check('T3 LOCK + aplikasi (normal) -> diabaikan', not r.plc.coil())
check('T3 HREG 6 tetap di-acknowledge 0', r.esp.hreg6==0)
# 4
r=fresh('UNLOCK'); r.press('NC'); check('T4 UNLOCK + push button -> diabaikan', not r.plc.coil())
# 5
r=fresh('UNLOCK'); r.press('HMI_NC'); a=r.plc.coil(); r.press('HMI_NO'); b=not r.plc.coil()
check('T5 UNLOCK + HMI (normal) -> relay merespons', a and b)
# 6: tiga variasi (LRU FAIL, COM FAIL, keduanya)
ok6=True
for mode in ('lru','com','both'):
    r=fresh('UNLOCK')
    if mode in('lru','both'): r.esp.ireg[5]=1
    if mode in('com','both'): r.plc.force['W1.01']=True
    r.step(2); r.press('HMI_NC'); ok6&=r.plc.coil(); r.press('HMI_NO'); ok6&=not r.plc.coil()
check('T6 UNLOCK + HMI saat LRUFail/COMFail FAIL -> relay tetap merespons (tidak digerbang)', ok6)
# 7
r=fresh('UNLOCK'); r.step(4); r.esp.hreg6=2; r.step(2.5); a=r.plc.coil(); ack=r.esp.hreg6==0
r.esp.hreg6=1; r.step(2.5); b=not r.plc.coil()
check('T7 UNLOCK + aplikasi (normal) -> relay merespons NC lalu NO', a and b)
check('T7 handshake: HREG 6 kembali 0 dan perintah tidak berulang', ack and r.esp.hreg6==0)
# 8
r=fresh('UNLOCK'); r.esp.ireg[5]=1; r.step(2); r.esp.hreg6=2; r.step(2.5)
check('T8 UNLOCK + aplikasi + LRUFail FAIL -> diabaikan', not r.plc.coil())
check('T8 perintah yang ditolak tetap di-acknowledge', r.esp.hreg6==0)
# 9 (gerbang via force) dan versi nyata (komunikasi putus lalu pulih)
r=fresh('UNLOCK'); r.step(4); r.plc.force['W1.01']=True; r.esp.hreg6=2; r.step(2.5)
check('T9 UNLOCK + aplikasi + COMFail FAIL (Force) -> diabaikan', not r.plc.coil())
r=fresh('UNLOCK'); r.step(4)
r.esp.connected=False; r.step(6); fail=r.plc.bit('W1.01')
r.esp.hreg6=2; r.esp.connected=True; r.step(1.5)
check('T9b COMFail nyata: FAIL setelah komunikasi putus >5 s', fail)
check('T9b perintah tertahan saat putus TIDAK dieksekusi saat komunikasi pulih (penahan 3 s)', not r.plc.coil() and r.esp.hreg6==0)

# ---- Uji tambahan ----
r=fresh('LOCK'); r.hw['LOCK']=True; r.hw['UNLOCK']=True; r.step(0.3); r.hw['LOCK']=False; r.hw['UNLOCK']=False
check('X1 LOCK dan UNLOCK bersamaan -> LOCK menang', r.plc.bit('W0.00'))
r=fresh('UNLOCK'); r.hw['HMI_NC']=True; r.hw['HMI_NO']=True; r.step(0.3)
check('X2 perintah NC dan NO bersamaan -> buka menang', not r.plc.coil())
r=fresh('UNLOCK'); r.step(4); r.esp.hreg6=3; r.step(2.5)
check('X3 nilai HREG 6 tidak valid (3) -> diabaikan dan di-acknowledge', not r.plc.coil() and r.esp.hreg6==0)
r=fresh('UNLOCK'); r.step(4); w0=r.esp.writes
for v in (2,1,2): r.esp.hreg6=v; r.step(2.5)
check('X4 jumlah penulisan acknowledge = jumlah perintah (3)', r.esp.writes-w0==3)
# watchdog 5 s
r=fresh('LOCK'); r.step(3); r.esp.connected=False; t0=r.t; fail=None
for i in range(1200):
    r.step(0.01)
    if fail is None and r.plc.bit('W1.01'): fail=(r.t-t0)/1000
check(f'X5 watchdog COMFail menyala {fail:.2f} s setelah putus (<= 5 s)', fail is not None and 4.3<=fail<=5.1)
r.esp.connected=True; r.step(1.5)
check('X5 pemulihan COMFail ke NORMAL', not r.plc.bit('W1.01'))
# Easy Master macet
r=fresh('LOCK'); r.step(2); r.mode='hang'; r.step(8)
check('X6 Easy Master macet: sequencer tidak deadlock dan COMFail menyala', r.plc.bit('W1.01') and r.plc.word('D100') in (0,1,2))
r.mode='normal'; r.step(4)
check('X6 pulih otomatis saat Easy Master normal lagi', not r.plc.bit('W1.01'))
# ESP32 sibuk membaca ADC (tidak menjawab 300 ms tiap detik), timeout Easy Master 200 ms
r=new(timeout_ms=200); r.esp.block=lambda t:(t if (t%1000)<700 else t-(t%1000)+1000)
r.step(2); r.press('UNLOCK'); mx=False
for i in range(3000):
    r.step(0.01); mx|=r.plc.bit('W1.01')
r.esp.hreg6=2; r.step(6)
check(f'X7 ESP32 sibuk ADC 300 ms/s: COMFail tidak pernah menyala (sukses {r.ok}, error {r.err})', not mx and r.err>0)
check('X7 perintah remote tetap tereksekusi dan di-acknowledge', r.plc.coil() and r.esp.hreg6==0)
# kualitas & ambang
r=fresh('LOCK'); r.esp.ireg[4]=0b0101; r.step(2)
check('X8 bitmask kualitas IREG 4 -> W5.00 dan W5.02 = 1', r.plc.bit('W5.00') and r.plc.bit('W5.02') and not r.plc.bit('W5.01') and not r.plc.bit('W5.03'))
r.esp.ireg[3]=1999; r.step(2); a=r.plc.bit('W3.05')
r.esp.ireg[3]=2000; r.step(2); b=r.plc.bit('W3.05'); c=r.plc.word('D131')
r.esp.ireg[3]=800; r.step(2)
check('X9 Arus Gangguan: 1,999 A normal; 2,000 A gangguan; D131 mengikuti; kembali 0', (not a) and b and c==2000 and r.plc.word('D131')==0 and not r.plc.bit('W3.05'))
r.esp.ireg[0]=19000; r.step(2); lo=r.plc.bit('W3.06'); r.esp.ireg[0]=25000; r.step(2); hi=r.plc.bit('W3.06'); r.esp.ireg[0]=22000; r.step(2)
check('X10 tegangan sumber di luar 198-242 V -> V_ABNORMAL', lo and hi and not r.plc.bit('W3.06'))
r=fresh('LOCK'); r.esp.ireg[1]=21900; r.step(4); a=r.plc.bit('W3.07')   # koil OFF tetapi beban bertegangan
r.press('NC'); r.step(2.5); b=r.plc.bit('W3.07')                        # koil ON dan beban bertegangan
r.esp.ireg[1]=0; r.step(3); c=r.plc.bit('W3.07')                        # koil ON tetapi beban 0 V
check('X11 Status LBS SUSPECT: koil OFF+beban hidup (ya), koil ON+beban hidup (tidak), koil ON+beban 0 V (ya)', a and (not b) and c)
# ---- bit baru untuk HMI ----
r=fresh('LOCK'); ok=True
for act in ('init','unlock','lock','both'):
    if act=='unlock': r.press('UNLOCK')
    if act=='lock': r.press('LOCK')
    if act=='both':
        r.hw['LOCK']=True; r.hw['UNLOCK']=True; r.step(0.3); r.hw['LOCK']=False; r.hw['UNLOCK']=False; r.step(0.2)
    ok&=(r.plc.bit('W0.01')==(not r.plc.bit('W0.00')))
check('X12 HOT_UNLOCK (W0.01) selalu kebalikan HOT_LOCK (W0.00) pada semua kondisi', ok)
r=fresh('LOCK'); vals={}
for amp in (0,1,1999,2000,3500):
    r.esp.ireg[3]=amp; r.step(2); vals[amp]=r.plc.bit('W3.04')
check('X13 ARUS_NORMAL: 0 A tidak, 1 mA ya, 1,999 A ya, 2,000 A tidak, 3,5 A tidak', vals=={0:False,1:True,1999:True,2000:False,3500:False})
print('\nRINGKASAN:',sum(res),'/',len(res),'lulus  |  file:',PATH.split('/')[-1])
