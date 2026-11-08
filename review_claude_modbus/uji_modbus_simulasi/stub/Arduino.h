#pragma once
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include <stdarg.h>
#include <math.h>
#include <deque>
#include <vector>
#ifndef ESP32
#define ESP32 1
#endif
#define OUTPUT 1
#define INPUT 0
#define LOW 0
#define HIGH 1
#define SERIAL_8N1 0x800001c
#define F(x) x
#define PROGMEM
#define pgm_read_word(p) (*(p))
#define pgm_read_byte(p) (*(p))
#define highByte(w) ((uint8_t)((w)>>8))
#define lowByte(w) ((uint8_t)((w)&0xFF))
#define bitRead(v,b) (((v)>>(b))&1)
#define bitSet(v,b) ((v)|=(1UL<<(b)))
#define bitClear(v,b) ((v)&=~(1UL<<(b)))
#define constrain(amt,low,high) ((amt)<(low)?(low):((amt)>(high)?(high):(amt)))
typedef bool boolean;
extern uint64_t g_now;                       // waktu simulasi (us)
unsigned long micros(); unsigned long millis();
void delay(unsigned long ms); void delayMicroseconds(unsigned int us); void yield();
void pinMode(int,int); void digitalWrite(int,int);
void vTaskDelay(int);
class Print { public:
  virtual size_t write(uint8_t)=0;
  virtual size_t write(const uint8_t* p,size_t n){size_t k=0;for(;k<n;k++)write(p[k]);return k;}
  size_t print(const char* s){return write((const uint8_t*)s,strlen(s));}
  size_t println(const char* s=""){print(s);return write('\n');}
  size_t println(long v){char b[32];snprintf(b,32,"%ld",v);return println(b);}
  size_t print(long v){char b[32];snprintf(b,32,"%ld",v);return print(b);}
  size_t printf(const char* f,...){char b[256];va_list a;va_start(a,f);vsnprintf(b,256,f,a);va_end(a);return print(b);}
};
class Stream : public Print { public:
  virtual int available()=0; virtual int read()=0; virtual int peek(){return -1;} virtual void flush(){}
};
struct RxByte { uint64_t t; uint8_t b; };
struct TxByte { uint64_t t; uint8_t b; };
extern std::deque<RxByte> g_rx; extern std::vector<TxByte> g_tx;
class HardwareSerial : public Stream { public:
  unsigned long _baud=0;
  void begin(unsigned long baud, uint32_t cfg=SERIAL_8N1, int rx=-1, int tx=-1){ _baud=baud; }
  unsigned long baudRate(){ return _baud; }
  int available() override { int n=0; for(auto& e:g_rx){ if(e.t<=g_now) n++; else break; } return n; }
  int read() override { if(g_rx.empty()||g_rx.front().t>g_now) return -1; uint8_t b=g_rx.front().b; g_rx.pop_front(); return b; }
  size_t write(uint8_t b) override { g_tx.push_back({g_now,b}); return 1; }
  void flush() override {}
};
extern HardwareSerial Serial, Serial2;
