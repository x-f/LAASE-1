LAASE-1
===
People.lv HAB project.

Developed for Seeedstudio Stalker (3V3, 8 MHz)  

**pins:**
  GPS - D0, D1 / D2, D3
  D18B20 - D4
  NTX2 - D8
  UV1 - A1
  UV2 - A2
  BMP085 - SCL, SDA
  cutdown - A0
  SD
  LED - D5

If using SoftwareSerial, its buffer size must be increased in SoftwareSerial.h:
#define _SS_MAX_RX_BUFF 128 // RX buffer size
