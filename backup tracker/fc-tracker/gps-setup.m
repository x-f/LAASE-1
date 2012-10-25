// fails, kas nodarbojas ar GPS ierīces izvēli
// ja GPS ierīce izvēlēta, mēģina tai pieslēgties,
// ja izdodas – labi (bet to var nomainīt)
// ja neizdodas – meklē visas ierīces un piedāvā sarakstu

use ui, io, encoding, files;
use lib_fc as fc;
use fc_cfg as fc_cfg;

const TITLE = encoding.fromutf8("HAB tracker GPS");
const CMD_EXIT = encoding.fromutf8("Iziet");
const CMD_SELECTGPS = encoding.fromutf8("Izvēlēties GPS");
const CMD_ABOUT = "Par..";


// info par GPS ierīces BT adresi ir ierakstīta failā
// to nolasa un mēģina piekonektēties
// ja nesanāk, meklē visas BT ierīces un piedāvā izvēlēties, 
// kad jaunā ierīce izvēlēta, piekonektējas
// ja izdevies piekonektēties, atslēdzas, lai GPS process varētu to izmantot
function gps_select_device()
  ui.busy(encoding.fromutf8("Savienojos ar GPS.."));
  status = "ok";
  
  dev = fc.bt_getdev();
  if dev # null then
    fc.log(dev, "BT GPS address");
    btc = fc.bt_conngps(dev);
    fc.log(btc, "BT conn");
  end;
  if (dev = null or btc = null) then
    fc.log("Select device", "BT");
    dev = fc.bt_seldev();
    btc = fc.bt_conngps(dev);
  end;
  if (dev # null and btc # null) then
    fc.log("GPS connected", "BT");
    sleep(1000);
    if (btc # null) then
      fc.log("disconnect GPS", "BT");
      io.close(btc);
      btc = null;
    end;
    if (btc = null) then
      fc.log("GPS disconnected", "BT");
      sleep(1000);
    end;
  else
    fc.log("GPS device not selected", "ERROR");
    status = "error";
  end;

  ui.busy();
  if (status = "ok") then
    fc.log("GPS device ok", "BT");
  end;

  fc.beep(status);
end;


ui.menu(TITLE, [CMD_EXIT, CMD_SELECTGPS, CMD_ABOUT]);
ui.label(0, TITLE);
ui.label(1, encoding.fromutf8("Iespējas"));

gps_select_device();

do
  cmd = ui.cmd(20);

  if cmd = CMD_SELECTGPS then
    // dzēš gpsdev.dat failu, lai izvēlētos jaunu ierīci
    if (files.exists(fc_cfg.gps_cfgfile)) then
      files.delete(fc_cfg.gps_cfgfile);
      fc.log("config file deleted");
    end;
    sleep(1000);
    gps_select_device();
  end;

until cmd = CMD_EXIT;
