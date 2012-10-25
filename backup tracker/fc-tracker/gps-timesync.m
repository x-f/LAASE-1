/*
  Set phone time from GPS satellites
  based on http://www.m-shell.net/forum.aspx?g=posts&t=628
*/

use time, math, io, ui, encoding;

use lib_fc as fc;
use lib_gps as gps;
use fc_cfg as fc_cfg;


gps_dev = fc.bt_getdev();
fc.log(gps_dev, "dev");
gps_btc = fc.bt_conngps(gps_dev);
fc.log(gps_btc, "btc");

if (gps_dev # null) then
  fc.log("GPS: got BT address", "ok");
else
  fc.log("GPS: no BT address", "error");
end;
if (gps_btc # null) then
  fc.log("GPS: connected BT", "ok");
  fc.beep("ok");
else
  fc.log("GPS: not connected", "error");
end;

const TITLE = encoding.fromutf8("GPS time sync");
const CMD_EXIT = encoding.fromutf8("Apturēt");
ui.menu(TITLE, [CMD_EXIT]);
ui.label(0, TITLE);
ui.label(1, encoding.fromutf8("Iespējas"));

delta = 0;
deviation = 0;

cnt = 0;
do
  sleep(50);
  
  try

    cmd = ui.cmd(20);

    if (gps_dev # null and gps_btc # null) then
      try
        if io.avail(gps_btc) > 0 then
          gps_line = io.readln(gps_btc);
        end;
      catch bt_exc by
        fc.log("GPS connection error: " + bt_exc, "error");
        io.close(gps_btc);
        gps_btc = null;
      end;

      if (gps_line # null) then
        gps.decodeNMEA(gps_line, gps.flightlog);
      end;

      if (cnt % 100 = 0) then
        phone_utc = time.utc();
        print "phone UTC: " + time.str(phone_utc);

        if (gps.flightlog['fixq'] > 0) then
          // ..
          gps_utc = gps.flightlog['date'] + gps.flightlog['time'];
          //fc.log(gps.flightlog['date']);
          //fc.log(gps.flightlog['time']);

          delta = gps_utc - phone_utc;
          print "GPS UTC: " + time.str(gps_utc) + " (" + gps.flightlog['sats'] + ")";

          //if math.abs(delta) > math.abs(deviation) then
          //  deviation = delta // remember highest deviation
          //end;

          //print "deviation: " + deviation;
          print "delta: " + delta;
          print "actual time: ", time.str(time.get()+delta);

          //print "sats: ", gps.flightlog['sats'], "\n";
          print "";

        end;
      end;

    end;
    
  catch e by
     fc.log("main loop: " + e, "error");
  end;

  cnt++;

until (cmd = CMD_EXIT) or (gps.flightlog['sats'] > 3);


if gps.flightlog['sats'] > 3 then
  time.set(time.get()+delta);

  print "New time set at:", time.str(time.utc());
  //print "Deviation was:", str(deviation, 0, 4), " sec"
  print "Delta was:", str(delta, 0, 4), " sec"
end;


if (gps_btc # null) then
  io.close(gps_btc);
end;

fc.beep("ok");