/*
  LAASE-1
  x-f (x-f@people.lv), 2012-2013

  !! pirms starta jānosaka cutdown taimera vērtību un GPS robežas
  !! pārlikt GPS uz UART, DEBUG=false, GPS_HW_SERIAL=true
    
  TODO
    //WDT
    //cutdown
    blink?
    GPS eco mode?
*/

// GPS pieslēgts vai nu D2 un D3 (SoftwareSerial), vai D0 un D1 (UART)
#define GPS_HW_SERIAL true
#define DEBUG false
 
#include <string.h>
#include <util/crc16.h>
#include <avr/wdt.h>
#include <Wire.h>
#include <TMP102.h> 

// Stalker temperatūras sensors
int tmp102Address = 0x48;

#include <TinyGPS_UBX.h>
TinyGPS gps;
// melns (2, GND), oranžs (3, VCC), dzeltens (5, RX), pelēks (6, TX)
// oranžbalts (GND), oranžs (3V3), zaļibalts (TX), zaļš (RX)
#if !GPS_HW_SERIAL
  #include <SoftwareSerial.h>
  SoftwareSerial GPS_Serial(2, 3);
#endif

#define PIN_radio 6

// LED for GPS status
#define PIN_statusled 15


#include <SdFat.h>
SdFat card;
SdFile file;
char logfile[] = "g-log.csv";

#include <OneWire.h>
#include <DallasTemperature.h>
#define ONE_WIRE_BUS 2
OneWire oneWire(ONE_WIRE_BUS);
DallasTemperature DS18B20(&oneWire);
DeviceAddress ThermometerAddr_out = { 0x28, 0x14, 0x24, 0xBB, 0x03, 0x00, 0x00, 0x9F };
DeviceAddress ThermometerAddr_bat = { 0x28, 0x5A, 0x13, 0xBB, 0x03, 0x00, 0x00, 0x2C };

//#include <Battery.h>
//Battery bat;

#include <AmbientLightSensor.h>
AmbientLightSensor UV_sensor1(A2); // garais uz GND - UV
AmbientLightSensor UV_sensor2(A3); // garais uz GND - violets
#define UV_sensor_max1 512 // ja 0, tad mēra digitāli
#define UV_sensor_max2 16 // ja 0, tad mēra digitāli
// UV (violets) 16, UV (uv) 512


#include <PString.h>
static char datastring[110];
PString str(datastring, sizeof(datastring));
//static char datastring[100];

int count = 0;
byte gps_hour, gps_minute, gps_second;
long gps_lat, gps_lon, gps_alt;
unsigned long gps_fix_age;
boolean gps_has_fix = false;
byte gps_navmode = 99;

int tmp102_temp = 0;
int ds18b20_temp_out = 0;
int ds18b20_temp_bat = 0;
//int bmp085_temp;
//long bmp085_pressure;
int UV_sensor1_value, UV_sensor2_value = 0;

#define PIN_cutdown A0
// cik ilgu laiku pēc ieslēgšanas nostrādāt cutdown'am
#define cutdown_timeout 2 * 60 * 60 * 1000L // 2 stundas - 1000L * 60 * 60 * 2
// cik ilgi cutdown'am darboties
#define cutdown_runtime 45 * 1000L // 30-40 sekundes
unsigned long cutdown_fired; // laiks
byte cutdown_status = 0; // 0 - nekas, 1 - darbojas, 2 - beidzis darboties
// cik reizes no GPS saņemtas koordinātes,
// kas ir aiz noteiktās robežas
byte cutdown_geofence_cnt = 0; 
// cik pozīcijas pēc robežas pārkāpšanas iedarbināt cutdown
byte cutdown_geofence_threshold = 10; 

// milisekundes, kad programma sāka darboties
unsigned long program_started;
unsigned long timestamp_now;



void setup() {
  // watchdog
  wdt_disable();
  wdt_enable(WDTO_8S);
  wdt_reset();

  Serial.begin(9600);
  delay(150);
  resetGPS();
  delay(500);
  
  //#if DEBUG
  //  Serial.println("FC");
  //#endif
  
  //#if !GPS_HW_SERIAL
  //  GPS_Serial.begin(9600);
  //#endif
  
  //delay(1000);
  GPS_setup();
  
  Wire.begin();
  //bmp085Calibration();

  // Dallas temperatūras sensori
  // Start up the library
  DS18B20.begin();
  // set the resolution to 10 bit (good enough?)
  DS18B20.setResolution(ThermometerAddr_bat, 10);
  DS18B20.setResolution(ThermometerAddr_out, 10);

  if (UV_sensor_max1 && UV_sensor_max1 != 2000)
    UV_sensor1.setAnalogMeasurement(UV_sensor_max1);
  if (UV_sensor_max2 && UV_sensor_max2 != 2000)
    UV_sensor2.setAnalogMeasurement(UV_sensor_max2);

  pinMode(PIN_radio, OUTPUT);
  digitalWrite(PIN_radio, HIGH);

  pinMode(PIN_cutdown, OUTPUT);
  digitalWrite(PIN_cutdown, LOW);

  pinMode(PIN_statusled, OUTPUT);
  digitalWrite(PIN_statusled, LOW);


  program_started = millis();

  #if DEBUG
    Serial.println(F("go"));
  #endif
}

void loop() {
  // watchdog
  wdt_reset();
  
  timestamp_now = millis();
  

  if (count % 15 == 0) {
    //#if DEBUG
    //  Serial.println(F("checkNAV"));
    //#endif
    //GPS_checkNAV();
    //if (gps_navmode != 6) {
      //#if DEBUG
      //  Serial.print(F("navmode: ")); Serial.println(gps_navmode, DEC);
      //#endif
      Serial.flush();
      //resetGPS();
      delay(500);
      GPS_setup();
      Serial.flush();
      //GPS_checkNAV();
    //}
    //GPS_poll();
  }
    
  GPS_poll();
  //GPS_poll_send();
  read_sensors();
  //GPS_poll_recv();

  gps.crack_time(&gps_hour, &gps_minute, &gps_second, &gps_fix_age);
  gps.get_position(&gps_lat, &gps_lon, &gps_fix_age);
  gps_alt = gps.altitude();
  gps_has_fix = gps.has_fix();


  // statusa LEDs
  //  - ja nav GPS fix, deg
  //  - ja ir GPS fix, iemirgojas
  if (gps_has_fix) {
    for (int i = 0; i < 3; i++) {
      digitalWrite(PIN_statusled, HIGH);
      delay(100);
      digitalWrite(PIN_statusled, LOW);
      delay(50);
    }
  } else {
    digitalWrite(PIN_statusled, HIGH);
  }
  
  
  // cutdown
  boolean cutdown_activate = false;
  // taimeris kopš palaišanas
  if (timestamp_now - program_started > cutdown_timeout) {
    cutdown_activate = true;
  }
  // GPS robežas
  // nostrādā virs noteikta augstuma?
  if (gps_has_fix && gps_alt/100 > 20000) {
    if ((gps_lat > 5709000 || gps_lon > 2455555)) {
      //Serial.print("crossed: "); Serial.println(cutdown_geofence_threshold, DEC);
      if (cutdown_geofence_cnt++ >= cutdown_geofence_threshold) {
        //Serial.println("crossed, cutdown");
        cutdown_activate = true;
      }
    } else {
      //Serial.println("clear");
      cutdown_geofence_cnt = 0;
    }
  }


  char time[8];
  sprintf(time, "%02d:%02d:%02d", gps_hour, gps_minute, gps_second);

  str.begin();
  str.print(F("$$LAASE,"));
  str.print(count);
  str.print(",");
  str.print(time);
  str.print(",");

  str.print(gps_lat/100000.0, 5);
  //str.print(gps_lat, DEC);
  str.print(",");
  str.print(gps_lon/100000.0, 5);
  //str.print(gps_lon, DEC);
  str.print(",");
  str.print(gps_alt/100.0, 0);
  str.print(",");

  str.print(gps.speed()/100, DEC); // km/h
  str.print(",");
  //str.print(gps.course()/100, DEC); // minor
  //str.print(","); // minor

  //str.print(gps.fix_quality(), DEC);
  //str.print(",");
  str.print(gps.sats(), DEC);
  str.print(",");
  //str.print(gps_navmode, DEC);
  //str.print(",");
  //str.print(gps_fix_age, DEC); // minor
  //str.print(","); // minor
  //str.print(gps_has_fix, DEC);
  //str.print(cutdown_status, DEC);
  //str.print(",");

  //str.print(tmp102_temp, DEC); // minor
  //str.print(","); // minor
  str.print(ds18b20_temp_out, DEC);
  str.print(",");
  str.print(ds18b20_temp_bat, DEC);
  str.print(",");
  //str.print(bmp085_temp, DEC);
  //str.print(",");
  //str.print(bmp085_pressure, DEC);
  //str.print(",");
  str.print(UV_sensor1_value, DEC);
  str.print(",");
  str.print(UV_sensor2_value, DEC);
  //str.print(",");

  //str.print(bat.getVoltage());
  //str.print(","); // minor
  //str.print(freeRam(), DEC); // minor


  //sprintf(datastring, "%d,%02d:%02d:%02d,%ld,%ld,%ld,%d,%d,%d,%d,%d,%d,%ld", count, gps_hour, gps_minute, gps_second, gps_lat, gps_lon, gps_alt/100, gps.speed()*1.852/100, gps.fix_quality(), gps.sats(), gps_navmode, gps_fix_age, bmp085_temp, bmp085_pressure);

  unsigned int CHECKSUM = gps_CRC16_checksum(datastring);  // Calculates the checksum for this datastring
  char checksum_str[6];
  sprintf(checksum_str, "*%04X\n", CHECKSUM);
  //strcat(datastring, checksum_str);

  // preamble for dl-fldigi to better lock 
  rtty_txbyte(0x80);
  rtty_txbyte(0x80);
  rtty_txbyte(0x80);
  rtty_txstring("$");
  rtty_txstring(datastring);
  rtty_txstring(checksum_str);


  // pārējā info, ko nav nepieciešams sūtīt uz zemi
  
  //str.print(gps.speed()/100, DEC); // km/h
  //str.print(",");
  str.print(gps.course()/100, DEC); // minor
  str.print(","); // minor

  str.print(gps.fix_quality(), DEC);
  str.print(",");
  str.print(gps_navmode, DEC);
  str.print(",");
  //str.print(gps_fix_age, DEC); // minor
  //str.print(","); // minor
  //str.print(gps_has_fix, DEC);
  //str.print(",");
  str.print(cutdown_status, DEC);
  str.print(",");

  str.print(tmp102_temp, DEC); // minor
  //str.print(","); // minor
  //str.print(bmp085_temp, DEC);
  //str.print(",");
  //str.print(UV_sensor2_value, DEC);
  //str.print(","); // minor
  //str.print(freeRam(), DEC); // minor


  telemetry_log();
  
  #if DEBUG
    //Serial.print(datastring);
  #endif
  
  
  //delay(1000);
  count++;
  
    // cutdown
  if (cutdown_status == 0 && cutdown_activate) {
    //Serial.println("cutdown..");
    //Serial.print(ts_now); Serial.print("-"); Serial.print(program_started); Serial.print("="); Serial.println(ts_now - program_started);
    cutdown_status = 1;
    cutdown_fired = timestamp_now;
    digitalWrite(PIN_cutdown, HIGH);
  }
  if (cutdown_status == 1 && (timestamp_now - cutdown_fired > cutdown_runtime)) {
    //Serial.println("..done");
    //Serial.print(ts_now); Serial.print("-"); Serial.print(cutdown_fired); Serial.print("="); Serial.println(ts_now - cutdown_fired);
    cutdown_status = 2;
    digitalWrite(PIN_cutdown, LOW);
  }

}

//-------------------------------------------

boolean telemetry_log() {
  
  // citādi ir kartes inicializācijas kļūme
  //delay(200);
  
  byte chipSelect = 10;
  
  if (!card.init(SPI_HALF_SPEED, chipSelect)) {
    #if (DEBUG)
      Serial.println(F("init error"));
    #endif
    return false;
  }

  if (!file.open(logfile, O_RDWR | O_CREAT | O_AT_END)) {
    #if (DEBUG)
      Serial.println(F("file error"));
    #endif
    return false;
  }
  file.print(datastring);
  file.println();
  file.close(); 
}

//int freeRam() {
//  extern int __heap_start, *__brkval; 
//  int v; 
//  return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval); 
//}

