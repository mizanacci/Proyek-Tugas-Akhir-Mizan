// Menjalankan modbus_slave.cpp ASLI (firmware) + library modbus-esp8266 4.1.1 di komputer.
#include "Arduino.h"
#include "modbus_slave.cpp"
#include <string>
#include <sstream>
#include <iostream>
static std::vector<uint8_t> fromHex(const std::string& s){ std::vector<uint8_t> v; for(size_t i=0;i+1<s.size();i+=2) v.push_back((uint8_t)strtol(s.substr(i,2).c_str(),0,16)); return v; }
static void flushTx(){ if(g_tx.empty()) return; printf("TX"); for(auto&x:g_tx) printf(" %llu:%02X",(unsigned long long)x.t,x.b); printf("\n"); g_tx.clear(); }
int main(){
  setvbuf(stdout,NULL,_IOLBF,0);
  std::string line;
  while(std::getline(std::cin,line)){
    std::istringstream is(line); std::string c; is>>c;
    if(c=="INIT"){ Serial2.begin(MODBUS_BAUDRATE,MODBUS_SERIAL_CONFIG,PIN_MODBUS_RX2,PIN_MODBUS_TX2); modbusSlaveInit(); printf("OK baud=%lu\n",Serial2.baudRate()); }
    else if(c=="SENSOR"){ HasilSensor h; int m; is>>h.tegangan_sumber>>h.tegangan_beban>>h.arus_sumber>>h.arus_beban>>m; h.bitmask_kualitas=m; modbusUpdateHasilSensor(h); printf("OK\n"); }
    else if(c=="LRU"){ int v; is>>v; modbusUpdateLRUFail(v!=0); printf("OK\n"); }
    else if(c=="CMD"){ int v; is>>v; modbusTulisPerintahRemote(v); printf("OK\n"); }
    else if(c=="RXAT"){ // RXAT <us_mulai> <hex> : byte tiba tiap 1041.67 us (9600 8N1)
      unsigned long long t0; std::string h; is>>t0>>h; auto v=fromHex(h); for(size_t i=0;i<v.size();i++) g_rx.push_back({t0+(uint64_t)((i+1)*1041.67),v[i]}); printf("OK\n"); }
    else if(c=="RUN"){ unsigned long long until; is>>until; while(g_now<until){ modbusSlaveTask(); flushTx(); if(g_now<until) g_now+=5000; } if(g_now<until) g_now=until; flushTx(); printf("OK %llu\n",(unsigned long long)g_now); }
    else if(c=="JUMP"){ unsigned long long t; is>>t; if(t>g_now) g_now=t; printf("OK\n"); }   // firmware 'sibuk' (tak memanggil task)
    else if(c=="NOW"){ printf("NOW %llu\n",(unsigned long long)g_now); }
    else if(c=="STATE"){ bool cf=modbusEstimasiComFailLokal(); unsigned long idle=modbusBacaRegisterCommand(); printf("STATE"); for(int i=0;i<6;i++) printf(" %u",mb.Ireg(i)); printf(" %u cmd=%lu comfail=%d\n",mb.Hreg(REG_CMD_REMOTE),idle,(int)cf); }
    else if(c=="QUIT") break;
  }
}
