
void GPS_setup() {
  #if !GPS_HW_SERIAL
    GPS_Serial.begin(9600);
    //GPS_Serial.print("$PUBX,41,1,0007,0003,4800,0*13\r\n"); 
    //GPS_Serial.begin(4800);
    //GPS_Serial.flush();
  #else
    Serial.begin(9600);
  #endif

  delay(500);
  
  // izslēdz visus GPS NMEA teikumus uBlox GPS modulim
  // ZDA, GLL, VTG, GSV, GSA, GGA, RMC
  // https://github.com/thecraag/craag-hab/blob/master/CRAAG1/code/CRAAG1c/CRAAG1c.ino
  // Turning off all GPS NMEA strings apart on the uBlox module
  // Taken from Project Swift (rather than the old way of sending ascii text)
  uint8_t setNMEAoff[] = {0xB5, 0x62, 0x06, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00, 0xD0, 0x08, 0x00, 0x00, 0x80, 0x25, 0x00, 0x00, 0x07, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0xA0, 0xA9};
  sendUBX(setNMEAoff, sizeof(setNMEAoff)/sizeof(uint8_t));
  
  delay(500);
  
  // airborne
  // ..
  // Set the navigation mode (Airborne, 1G)
  //Serial.print("Setting uBlox nav mode: ");
  uint8_t setNav[] = {0xB5, 0x62, 0x06, 0x24, 0x24, 0x00, 0xFF, 0xFF, 0x06, 0x03, 0x00, 0x00, 0x00, 0x00, 0x10, 0x27, 0x00, 0x00, 0x05, 0x00, 0xFA, 0x00, 0xFA, 0x00, 0x64, 0x00, 0x2C, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x16, 0xDC};
  sendUBX(setNav, sizeof(setNav)/sizeof(uint8_t));
  //getUBX_ACK(setNav);

  //uint8_t setEco[] = {0xB5, 0x62, 0x06, 0x11, 0x02, 0x00, 0x08, 0x04, 0x25, 0x95};
  //uint8_t setEco[] = {0xB5, 0x62, 0x06, 0x11, 0x02, 0x00, 0x00, 0x04, 0x1D, 0x85};
  //uint8_t setEco[] = {0xB5, 0x62, 0x06, 0x11, 0x02, 0x00, 0x08, 0x01, 0x22, 0x92};
  //sendUBX(setEco, sizeof(setEco)/sizeof(uint8_t));
  //getUBX_ACK(setEco);

  #if DEBUG
    Serial.println("GPS setup done");
  #endif
}

boolean GPS_poll() {
  //Poll GPS
  #if !GPS_HW_SERIAL
    GPS_Serial.println("$PUBX,00*33");
  #else
    Serial.println("$PUBX,00*33");
  #endif
    delay(300);
    unsigned long starttime = millis();
    while (true) {
      #if !GPS_HW_SERIAL
      if (GPS_Serial.available()) {
        char c = GPS_Serial.read();
      #else
      if (Serial.available()) {
        char c = Serial.read();
      #endif
        if (gps.encode(c))
          return true;
      }
      // 
      if (millis() - starttime > 1000) {
        #if DEBUG
          Serial.println("timeout");
        #endif
        break;
      }
    }
  return false;
}

// http://ukhas.org.uk/guides:falcom_fsa03#sample_code
// Send a byte array of UBX protocol to the GPS
void sendUBX(uint8_t *MSG, uint8_t len) {
  for(int i=0; i<len; i++) {
    #if !GPS_HW_SERIAL
      GPS_Serial.write(MSG[i]);
    #else
      Serial.write(MSG[i]);
    #endif
  }
}
 
// Calculate expected UBX ACK packet and parse UBX response from GPS
boolean getUBX_ACK(uint8_t *MSG) {
  uint8_t b;
  uint8_t ackByteID = 0;
  uint8_t ackPacket[10];
  unsigned long startTime = millis();
  //if (DEBUG)
  //  Serial.print("ACK: ");
 
  // Construct the expected ACK packet    
  ackPacket[0] = 0xB5;  // header
  ackPacket[1] = 0x62;  // header
  ackPacket[2] = 0x05;  // class
  ackPacket[3] = 0x01;  // id
  ackPacket[4] = 0x02;  // length
  ackPacket[5] = 0x00;
  ackPacket[6] = MSG[2];  // ACK class
  ackPacket[7] = MSG[3];  // ACK id
  ackPacket[8] = 0;    // CK_A
  ackPacket[9] = 0;    // CK_B
 
  // Calculate the checksums
  for (uint8_t i=2; i<8; i++) {
    ackPacket[8] = ackPacket[8] + ackPacket[i];
    ackPacket[9] = ackPacket[9] + ackPacket[8];
  }
 
  while (1) {
 
    // Test for success
    if (ackByteID > 9) {
      // All packets in order!
      //if (DEBUG)
      //  Serial.println(" OK");
      return true;
    }
 
    // Timeout if no valid response in 3 seconds
    if (millis() - startTime > 3000) { 
      //if (DEBUG)
      //  Serial.println(" FAIL");
      return false;
    }
 
    // Make sure data is available to read
      #if !GPS_HW_SERIAL
      if (GPS_Serial.available()) {
        b = GPS_Serial.read();
      #else
      if (Serial.available()) {
        b = Serial.read();
      #endif   
        // Check that bytes arrive in sequence as per expected ACK packet
        if (b == ackPacket[ackByteID]) { 
          ackByteID++;
          //if (DEBUG)
          //  Serial.print(b, HEX);
        } else {
          ackByteID = 0;  // Reset and look again, invalid order
        }
      }
    
  }
}

//Function to poll the NAV5 status of a Ublox GPS module (5/6)
//Sends a UBX command (requires the function sendUBX()) and waits 3 seconds
// for a reply from the module. The then isolates the byte which contains 
// the information regarding the NAV5 mode,
// 0 = Pedestrian mode (default, will not work above 12km)
// 6 = Airborne 1G (works up to 50km altitude)
//Adapted by jcoxon from getUBX_ACK() from the example code on UKHAS wiki
// http://wiki.ukhas.org.uk/guides:falcom_fsa03

boolean GPS_checkNAV(){
  uint8_t b, bytePos = 0;
  uint8_t getNAV5[] = { 0xB5, 0x62, 0x06, 0x24, 0x00, 0x00, 0x2A, 0x84 }; //Poll NAV5 status
 
  #if !GPS_HW_SERIAL
    GPS_Serial.flush();
  #else
    Serial.flush();
  #endif
  
  unsigned long startTime = millis();
  sendUBX(getNAV5, sizeof(getNAV5)/sizeof(uint8_t));
 
  while (1) {
    // Make sure data is available to read
      #if !GPS_HW_SERIAL
      if (GPS_Serial.available()) {
        b = GPS_Serial.read();
      #else
      if (Serial.available()) {
        b = Serial.read();
      #endif
        if(bytePos == 8){
          gps_navmode = b;
          return true;
        }
   
        bytePos++;
      }
    
    // Timeout if no valid response in 3 seconds
    if (millis() - startTime > 3000) {
      gps_navmode = 0;
      return false;
    }
  }
}

