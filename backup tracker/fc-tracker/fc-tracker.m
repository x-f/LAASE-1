// fails, kas atbild par sakariem ar GPS ierīci
// logo GPS datus un tos nosūta uz galveno skriptu
// tiek darbināts kā process no galvenā skripta

use io, time, system, ui, math;
use bigint;
use encoding, msg, sms, gsm;
use device;
use lib_fc as fc;
use lib_gps as gps;
use fc_cfg as fc_cfg;

status = [
  "status": "ok",
  "info": "",
  "data": "",
];

time_started = time.get();

interval_statusbeep = fc_cfg.interval_statusbeep; // ik pēc cik sekundēm iepīkstēties par statusu
interval_log = fc_cfg.interval_log; // ik pēc cik sekundēm pielogot info
interval_notify = fc_cfg.interval_notify; // ik pēc cik sekundēm mēģināt nosūtīt SMS
ts_now = 0;
ts_statusbeep_prev = 0;
ts_log_prev = 0;
ts_notify_prev = 0;

// pēdējās sūtītās SMS ID
sms_id_current = null;

cnt = 0;
// kaunteris, cik reižu dažādu iemeslu dēļ telemetrija nav nosūtīta
telemetry_skipped_cnt = 0;
// cik reizes drīkst nenosūtīt telemetriju, līdz to forsē izdarīt
// 30 min?
telemetry_skip_threshold = 5;
// cik neveiksmīgi mēģinājumi savienoties ar BT GPS
reboot_cnt = 0;
// cik reizes mēģināt savienoties ar BT GPS (* 5 sek), līdz restartēt telefonu
reboot_cnt_threshold = 5;
// cik reizes sākumā noteikti ziņot par pozīciju
// ~stundu no sākuma?
notify_dont_skip_from_start = 5;

// vertikālā ātruma aprēķinam
vspeed = [
  'time': 0,
  'alt': 0
];
notify_gps_lat_prev = 0;
notify_gps_lon_prev = 0;
gps_lat_prev = 0;
gps_lon_prev = 0;


const TITLE = encoding.fromutf8("HAB tracker (bckp)");
const CMD_EXIT = encoding.fromutf8("Apturēt");
const CMD_MUTE = encoding.fromutf8("Apklust");
const CMD_SELECTGPS = encoding.fromutf8("Izvēlēties GPS");
const CMD_ABOUT = "Par..";

// ---------------
// cls();
print "=========================";
fc.log(TITLE + " started");

ui.menu(TITLE, [CMD_EXIT, CMD_MUTE, CMD_SELECTGPS, CMD_ABOUT]);
ui.label(0, TITLE);
ui.label(1, encoding.fromutf8("Iespējas"));
// ui.label(2, "Paslept");


// *****************************************************************

gps_dev = fc.bt_getdev();
fc.log(gps_dev, "dev");
gps_btc = fc.bt_conngps(gps_dev);
fc.log(gps_btc, "btc");

if (gps_dev # null) then
  fc.log("GPS: got BT address", "ok");
else
  fc.log("GPS: no BT address", "error");
  status['status'] = "error";
end;
if (gps_btc # null) then
  fc.log("GPS: connected BT", "ok");
else
  fc.log("GPS: not connected", "error");
  status['status'] = "error";
end;

sleep(1000);
gps.gps_setup(gps_btc);

fc.beep("ok");
fc.beep("ok");
sleep(5000);


do
  // power saving
  sleep(50);

  try

    ts_now = time.get();
  
    //if (cnt % 1000 = 0) then cls(); end;
    //if (cnt % 1000 = 0) then
    //  gps.gps_setup(gps_btc);
    //end;
  
    //try
      // ui.cmd var izraisīt "exception: access denied" brīdī, kad atnāk SMS atskaite
      cmd = ui.cmd(20);
    // catch e by
    //   fc.log("main loop: " + e, "error");
    // end;
  
    if cmd = CMD_ABOUT then
      ui.msg(encoding.fromutf8(TITLE + " skripts nodrošina People.lv tuvā kosmosa izpētes programmas zondes atrašanās vietas fiksēšanu un komunikācijas ar misijas vadības centru kā rezerves sakaru sistēma.\n\nAutors: x-f\nVersija: 14.03.2012."), CMD_ABOUT);
    end;

    if cmd = CMD_MUTE then
      fc_cfg.audio_volume = 0;
    end;


    //gps_line = null;
    if (gps_dev # null and gps_btc # null) then
      try
        if io.avail(gps_btc) > 0 then
          gps_line = io.readln(gps_btc);
        end;
      catch bt_exc by
        fc.log("GPS connection error: " + bt_exc, "error");
        io.close(gps_btc);
        gps_btc = null;
        status['status'] = "error";
      end;

      if (gps_line # null) then
        gps.decodeNMEA(gps_line, gps.flightlog);
        
        // ja nav signāla (GPS fix quality < 2), ziņo ar warning
        if (gps.flightlog['fixq'] < 2) then
          status['status'] = "warning";
        else
          status['status'] = "ok";
        end;
        
        // fc.log(gps_line);
      end;
      
      /*gpscnt = 0;
      try
        fc.log("avail: " + io.avail(gps_btc));
        while io.avail(gps_btc) > 0 do
          gpscnt++;
          gps_line = io.readln(gps_btc);
          if (gps_line # null) then
            gps.decodeNMEA(gps_line, gps.flightlog);
          else 
            break;
          end;
        end;
        fc.log("gpscnt: " + gpscnt);
        fc.log("avail: " + io.avail(gps_btc));

      catch bt_exc by
        fc.log("GPS connection error: " + bt_exc, "error");
        io.close(gps_btc);
        gps_btc = null;
        status['status'] = "error";
      end;*/
      
    end; // if gps_dev and gps_btc
    //else
    
    gps_lost = false;
    if gps_btc = null then
      gps_lost = true;
      fc.log("bt null");
    end;
    if 
      gps.flightlog['date'] > 0 and 
      //math.abs(time.utc() - gps.flightlog['date'] + gps.flightlog['time']) > 60 
      // :(
      bigint.num(bigint.abs(bigint.sub(time.utc(), gps.flightlog['date'] + gps.flightlog['time']))) > 60
    then
      fc.log("time diff: " + bigint.str(bigint.abs(bigint.sub(time.utc(), gps.flightlog['date'] + gps.flightlog['time']))));
      
      gps_lost = true;
      try io.close(gps_btc); catch tmp_e by end;
      gps_btc = null;
      //sleep(1000);
    end;
    
    if gps_lost then
      gps_btc = fc.bt_conngps(gps_dev);
      fc.log(gps_btc, "btc");
      // sleep(5000);
      
      if gps_btc # null then
        gps.gps_setup(gps_btc);
        sleep(10000); // lai GPS "iesilst"
        reboot_cnt = 0;
      else
        status['status'] = "error";
        // bt.switch?
        // reboot?
        // reboot-cnt > 5
        fc.log("reboot (" + reboot_cnt + "/" + reboot_cnt_threshold + ")");
        if (reboot_cnt > reboot_cnt_threshold) then
          fc.log("** reboot **");
          sleep(10000);
          system.reboot();
        end;
        reboot_cnt++;
      end;
    end;
    // end;


    // logošana
    // + sadabū pārējo info, kas nav GPS
    if ts_now - ts_log_prev >= interval_log then
      ts_log_prev = ts_now;
      
      gps.flightlog['cnt']++;
      // gps.flightlog['met'] = math.round(time.get() - time_started);

      // GSM signal, network
      // battery
      gsm_signal_dbm = -1;
      gsm_signal_bars = -1;
      gsm_reg = -1;
      gsm_cellid = -1;
      gsm_lac = -1;
      gsm_mcc = -1;
      gsm_mnc = -1;
      gsm_name = "-";
      bat_charge = -1;
      try
        gsm_signal_dbm = device.signal()['dbm'];
        gsm_signal_bars = device.signal()['bars'];
      catch dev_e by /*fc.log(dev_e, 1);*/ end;
      try
        gsm_reg = device.netreg();
      catch dev_e by /*fc.log(dev_e, 2);*/ end;
      try
        n = device.netinfo();
        gsm_cellid = n['cellid'];
        gsm_lac = n['lac'];
        gsm_mcc = n['mcc'];
        gsm_mnc = n['mnc'];
        gsm_name = n['name'];
      catch dev_e by /*fc.log(dev_e, 3);*/ end;
      try
        bat_charge = device.battery()['charge'];
      catch dev_e by /*fc.log(dev_e, 4);*/ end;
      
      gps.flightlog['gsm-signal-dbm'] = gsm_signal_dbm;
      gps.flightlog['gsm-signal-bars'] = gsm_signal_bars;
      gps.flightlog['gsm-reg'] = gsm_reg;
      gps.flightlog['gsm-cellid'] = gsm_cellid;
      gps.flightlog['gsm-lac'] = gsm_lac;
      gps.flightlog['gsm-mcc'] = gsm_mcc;
      gps.flightlog['gsm-mnc'] = gsm_mnc;
      gps.flightlog['gsm-name'] = gsm_name;
      gps.flightlog['bat-charge'] = bat_charge;

      // aprēķina vertikālo ātrumu
      // tas ir vidējais ātrums pēdējo x sekunžu laikā
      // if fc.flightlog["fixq"] = 3 then
        //if time.get() - vspeed['time'] > time_to_log then
          if vspeed['time'] > 0 then
            alt_diff = gps.flightlog['alt'] - vspeed['alt'];
            time_diff = time.get() - vspeed['time'];
          
            tmp = alt_diff / time_diff;
            gps.flightlog['vspeed'] = math.round(tmp, 2);
          end;
          vspeed['time'] = time.get();
          vspeed['alt'] = gps.flightlog['alt'];
        //end;
      // end;

      if gps_lat_prev > 0 and gps_lon_prev > 0 then
        gps.flightlog['dist'] += gps.distance(gps_lat_prev, gps_lon_prev, gps.flightlog['lat'], gps.flightlog['lon']);
        gps_lat_prev = gps.flightlog['lat'];
        gps_lon_prev = gps.flightlog['lon'];
      else
        gps_lat_prev = gps.flightlog['lat'];
        gps_lon_prev = gps.flightlog['lon'];
      end;
      
      fc.telemetry_log(gps.flightlog);
      
      cls();
      // fc.log(time.str(gps.flightlog['time'], "hh:mm:ss") + ": " + gps.flightlog['fixq'] + ", " + gps.flightlog['sats']);
      // fc.log(fc.gps_data2str(gps.flightlog));

      log_fields = [
        "cnt",
        "time",
        "lat", "lon", 
        "alt", //"alt-max",
        "speed", "vspeed", 
        "fixq", "sats", "dil",
        "dist",
        // "fix-age",
        "bat-charge",
        "gsm-signal-bars", //"gsm-lac", "gsm-cid"
      ];
      fc.print_r(fc.extractFromArray(gps.flightlog, log_fields));
      
      // fc.log("sys.mem: " + system.mem());
      // fc.log("sys.gc:  " + system.gc());
      system.gc();
    end;


    // SMS
    // dati īsziņā
    if gps.flightlog['time'] > 0
      and ts_now - ts_notify_prev >= interval_notify
      and interval_notify > 0 // on/off
    then
      ts_notify_prev = ts_now;
    
      notify = true;
      
      // izlaist pirmo (tukšo)
      if gps.flightlog['cnt'] > 1 then
        
        // ja koordinātes tagad un iepriekš nav vienādas (+/-)
        // un cnt < X (lai darbotos sākumā)
        if gps.flightlog['cnt'] > notify_dont_skip_from_start then // ap stundu pēc palaišanas
        
          // coords
          // fc.log("lat delta: " + math.round(math.abs(gps.flightlog['lat'] - gps_lat_prev), 2));
          // fc.log("lon delta: " + math.round(math.abs(gps.flightlog['lon'] - gps_lon_prev), 2));
          if 
            math.abs(gps.flightlog['lat'] - notify_gps_lat_prev) < 0.00015 
            or math.abs(gps.flightlog['lon'] - notify_gps_lon_prev) < 0.00015 
          then
            notify = false;
            fc.log("coords not changed (" + telemetry_skipped_cnt + ")");
          end;
          // GSM altitude limit
          if gps.flightlog['alt'] > fc_cfg.notify_alt_limit then
            notify = false;
            fc.log("GSM off");
          end;
        end;

        // telemetrijas piespiedu nosūtīšana ik pēc noteikta reižu skaita
        if notify = false then
          telemetry_skipped_cnt++;
          if telemetry_skipped_cnt >= telemetry_skip_threshold then
            notify = true;
            fc.log("forced sending");
          end;
        end;

        if notify then
          telemetry_skipped_cnt = 0;
          notify_gps_lat_prev = gps.flightlog['lat'];
          notify_gps_lon_prev = gps.flightlog['lon'];
          
          fc.log("sending data..");
          
          // SMS sūtīšana
          gps.flightlog['cnt-tm']++;
          
          tm_fields = [
            "vehicle",
            "cnt-tm",
            "time",
            "lat", "lon", "alt", "speed", "dir",
            "vspeed",

            "fix", "fixq", "sats",

            "cnt",
            "bat-charge",

            // ?
            "dil",
            "pdop", "hdop", "vdop",

            "gsm-signal-dbm",
            "gsm-signal-bars",
            "gsm-reg",
            "gsm-mcc",
            "gsm-mnc",
            "gsm-cellid",
            "gsm-lac",
            "gsm-name",
            "fix-age",
            // ?
            "dist", //"alt-max",
          ];
          sms_txt = fc.getTelemetryString(gps.flightlog, tm_fields);
          
          fc.log(sms_txt);
          sms.send(fc_cfg.notify_sms_recipients, sms_txt);
          //fc.log("SMS queued", "ok");

          // ja pirms tam jau ir sūtīta ziņa, to dzēš, jo veca
          if sms_id_current # null then
            try
              msg.delete(sms_id_current);
            catch sms_e by end;
          end;

          // uzzina nosūtītās ziņas ID
          msgs = msg.scan(msg.draft, msg.msg);
          msg_count = len(msgs);
          if (msg_count > 0) then
            item = msgs[len(msgs)-1];
            sms_id_current = item['id'];
          end;
          
          fc.log("data sent");
        end;
      
      end;

    end;


    // beep, beep
    if ts_now - ts_statusbeep_prev >= interval_statusbeep then
      ts_statusbeep_prev = ts_now;
      fc.beep(status['status']);
    end;


  catch e by
     fc.log("main loop: " + e, "error");
  end;

  cnt++;

until cmd = CMD_EXIT;


if (gps_btc # null) then
  io.close(gps_btc);
end;


tmp = time.get() - time_started;
fc.log("Run time: " + math.round(tmp/60, 2) + " minutes");
// if len(flight_data) > 0 then
  // fc.log("Distance: " + math.round(flight_data["dist"], 2) + " km");
  // fc.log("Max alt: " + math.round(flight_data["alt-max"], 2) + " m");
// end;

fc.log(TITLE + " stopped");