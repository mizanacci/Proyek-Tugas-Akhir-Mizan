#include "Arduino.h"
uint64_t g_now=0; std::deque<RxByte> g_rx; std::vector<TxByte> g_tx;
HardwareSerial Serial, Serial2;
unsigned long micros(){ g_now+=25; return (unsigned long)g_now; }      // tiap pemanggilan = 25 us waktu CPU
unsigned long millis(){ return (unsigned long)(g_now/1000); }
void delay(unsigned long ms){ g_now+=ms*1000; } void delayMicroseconds(unsigned int us){ g_now+=us; } void yield(){}
void pinMode(int,int){} void digitalWrite(int,int){} void vTaskDelay(int){}
