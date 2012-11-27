use math, time, io;
use lib_fc as fc;
use fc_cfg as fc_cfg;

/*
  $GPRMC,092114,A,5708.8861,N,02450.1931,E,0.0,0.0,031211,6.1,E*7A
  $GPGGA,092114,5708.8861,N,02450.1931,E,1,05,11.1,109.9,M,24.0,M,,*7A
  $GPGSA,A,3,03,,06,,,16,,,,,29,30,11.2,11.1,1.0*3A
  $GPGSV,3,1,12,03,31,289,42,05,13,035,00,06,46,284,48,07,11,344,00*7F
  $PGRME,18.5,M,23.5,M,29.9,M*14
  $PGRMM,WGS 84*06
*/

function gps_setup(gps_btc)
  if (gps_btc # null) then
    // SiRFStar III - disable GPGSV
    io.writeln(gps_btc, "$PSRF103,3,0,0,1*27");
    // Nemerix - 
    // io.writeln(gps_btc, "$PNMRX103,GLL,0,GSV,0,VTG,0,ZDA,0*27");
    io.writeln(gps_btc, "$PNMRX108,RMC,GGA,GSA*27");
    fc.log("gps setup");
  end;
end;


// http://www.movable-type.co.uk/scripts/latlong.html
function distance(lat1, lon1, lat2, lon2)
  if (lat1 = lat2 and lon1 = lon2) then
    return 0; // otherwise it will give "NAN"
  end;
  
  // degrees to radians
  pi80 = math.pi / 180;
  lat1 = lat1 * pi80;
  lon1 = lon1 * pi80;
  lat2 = lat2 * pi80;
  lon2 = lon2 * pi80;

  R = 6371; // mean radius of Earth in km
  d = math.acos(math.sin(lat1) * math.sin(lat2) + math.cos(lat1) * math.cos(lat2) * math.cos(lon2 - lon1)) * R;
  d = math.round(d, 3);
  return d;
end;

// *********************************************************************

// based on airbit's gpsinf gps.mm
// http://www.m-shell.net/forum.aspx?g=posts&t=559

/* gps.mm
   Global Positioning System
   Some base functions and data
   $Id$
   $Log$
*/

flightlog = [
  "vehicle": fc_cfg.flight_device_id, // device ID
  // "sid": 0, // run count, session id, ++ on every start
  // "met": 0, // mission elapsed time
  "cnt": 0, // counter
  "cnt-tm": 0, // counter, how many times telemetry has been attempted to send
  "date": 0, // date
  "time": 0, // UTC time of last update
  "lat": 0, // latitude, negative value = south
  "lon": 0, // longitude, negative value = west
  "alt": 0, // altitude, meters, above mean sea level
  "speed": 0, // speed over the ground in km/h
  "dir": 0, // direction
  "vspeed": 0, // last minute's mean vertical speed in m/s 
  
  "fix": 0, // fix - true, false
  "fixq": 0, // fix quality, 1 - no, 2 - 2D, 3 - 3D
  "sats": 0, // number of satellites being tracked
  "fix-time": 0, // time when fix acquired
  "fix-age": 0, // time in seconds since fix acquired

  "dist": 0, // distance calculation
  "alt-max": 0, // max altitude, meters, above mean sea level
  "dil": 0, // horizontal dilution of position
  "pdop": 0, // position dilution of precision
  "hdop": 0, // horizontal dilution of precision
  "vdop": 0, // vertical dilution of precision
  "geoid": 0, // Height of geoid (mean sea level) above WGS84 ellipsoid
  
  "gsm-signal-dbm": 0, // GSM: signal strength
  "gsm-signal-bars": 0, // GSM: signal strength
  "gsm-reg": 0, // GSM: network registration status
  "gsm-mcc": 0, // GSM: mobile contry code
  "gsm-mnc": 0, // GSM: mobile network code
  "gsm-cellid": 0, // GSM: cell ID
  "gsm-lac": 0, // GSM: location area code
  "gsm-name": "", // GSM: net name
  
  "bat-charge": 0, // battery charge
];

function decodeNMEA(s, flightlog)
  /* decode NMEA position sentences
     into a flightlog array
     in:
       s: string NMEA sentence
     out:
       flightlog: updated flightlog array
  */

  // a NMEA sentence has to start with $
  if s = "" or substr(s, 0, 1) # "$" then
    fc.log("sentence fail");
    return;
  end;
  pa = split(s, ",");
  
  // distance
  //lat_prev = 0;
  //lon_prev = 0;
  
  // fc.log(pa[0]);
  case pa[0]

    in "$GPGGA": // essential fix data which provide 3D location and accuracy data
      flightlog["time"] = math.trunc(time.num(pa[1], "hms"));
      if pa[2] # "" then
        // distance
        //lat_prev = flightlog["lat"];
        // pārvērš deg min.dec par deg.dec
        flightlog["lat"] = num(substr(pa[2], 0, 2)) + num(substr(pa[2], 2)) / 60;
        if pa[3] = "S" then flightlog["lat"] = -flightlog["lat"]; end;
      end;
      if pa[4] # "" then
        // distance
        //lon_prev = flightlog["lon"];
        // pārvērš deg min.dec par deg.dec
        flightlog["lon"] = num(substr(pa[4], 0, 3)) + num(substr(pa[4], 3)) / 60;
        if pa[5] = "W" then flightlog["lon"] = -flightlog["lon"]; end;
      end;
      if pa[9] # "" then 
        flightlog["alt"] = num(pa[9]);
        if (flightlog["alt"] > flightlog["alt-max"]) then
          flightlog["alt-max"] = flightlog["alt"];
        end;
      end;
      if pa[8] # "" then flightlog["dil"] = num(pa[8]) end;
      if pa[7] # "" then flightlog["sats"] = num(pa[7]) end;
      if pa[11] # "" then flightlog["geoid"] = num(pa[11]) end;

      // if pa[4] # "" and pa[5] # "" and lat_prev > 0 and lon_prev > 0 then
      //   // distance calculation
      //   flightlog['dist'] += distance(lat_prev, lon_prev, flightlog['lat'], flightlog['lon']);
      // end;

    in "$GPRMC": // essential gps pvt (position, velocity, time) data
      flightlog["time"] = math.trunc(time.num(pa[1], "hms"));
      if pa[9] # "" then
        flightlog["date"] = time.num(substr(pa[9],0,2) + "." + substr(pa[9],2,2) + ".20" + substr(pa[9],4,2),"DMY");
      end;

      if pa[2] = "A" then
        if pa[3] # "" then
          // pārvērš deg min.dec par deg.dec
          flightlog["lat"] = num(substr(pa[3], 0, 2)) + num(substr(pa[3], 2)) / 60;
          if pa[4] = "S" then flightlog["lat"] = -flightlog["lat"]; end;
        end;
        if pa[5] # "" then
          // pārvērš deg min.dec par deg.dec
          flightlog["lon"] = num(substr(pa[5], 0, 3)) + num(substr(pa[5], 3)) / 60;
          if pa[6] = "W" then flightlog["lon"] = -flightlog["lon"]; end;
        end;
        if pa[8] # "" then flightlog["dir"] = math.round(num(pa[8]), 0) end;
        if pa[7] # "" then flightlog["speed"] = num(pa[7]) * 1.852 end; // knots to km/h

        flightlog['fix'] = 1;
        // now - fix-time = age
        if flightlog['fix-time'] = 0 then
          flightlog['fix-time'] = time.get();
        else
          flightlog['fix-age'] = math.round(time.get() - flightlog['fix-time'], 1);
        end;
      else
        // 
        flightlog['fix'] = 0;
        flightlog['fix-time'] = 0;
        flightlog['fix-age'] = 0;
      end;

    in "$GPGSA": // GPS DOP and active satellites
      if pa[2] # "" then flightlog["fixq"] = num(pa[2]) end;
      if pa[15] # "" then flightlog["pdop"] = pa[15] end;
      if pa[16] # "" then flightlog["hdop"] = pa[16] end;
      if pa[17] # "" then 
        // šādi tāpēc, ka pēc vdop ir checksumma
        // vdop vērtība var nebūt, bet checksumma būs vienmēr
        tmp = substr(pa[17], 0, index(pa[17], "*"));
        if tmp # "" then flightlog["vdop"] = tmp; end;
      end;

  else
    // fc.log(pa[0]);
  end;
  
end;
