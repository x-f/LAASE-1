/*
  nolasa X īsziņas ar telemetriju (pārbauda pēc īsziņas sākumteksta)
  nosūta uz serveri
  ja izdevies nosūtīt, 
    ieraksta logfailā
    pārvieto uz arhīva mapi
  iemieg uz X sekundēm
  atkārto ciklu
*/

use sms, msg, ui, encoding, net, proc;
use xflib as lib;
use xf_cfg as cfg;

// max SMS, cik vienā reizē nosūtīt serverim
smscnt = cfg.smscnt;
// ik pēc cik ilga laika (sekundēs)  atkārtot ciklu
sleep_sec = cfg.sleep_sec;

// 
sms_id_file = cfg.lastsmsfile;
sms_id_last = 0;

const CMD_EXIT = encoding.fromutf8("Apturēt");
// const CMD_SCANSMS = encoding.fromutf8("Skenēt saņemtās SMS");
const CMD_ABOUT = "Par..";



net.iap(false);

// ---------------

// cls();
print "=========================";
lib.log("People.lv HAB TM RT started");

ui.menu("People.lv HAB TM RT", [CMD_EXIT, CMD_ABOUT]);
ui.label(0, "People.lv HAB TM RT");

// ---------------
// noskaidro ID folderim, uz kuru pārvietot apstrādātās īsziņas
sms_archive_id = 0;
for m in msg.scan(msg.local, msg.folder) do
  if lower(m["descr2"]) = "my folders" then
    for n in msg.scan(m["id"], msg.folder) do
      if lower(n["descr2"]) = "fc-archive" then
        sms_archive_id = n["id"];
      end;
    end;
  end;
end;

if sms_archive_id = 0 then
  lib.log("Archive folder not found!");
  ui.msg(encoding.fromutf8("SMS arhīva mape \"FC-archive\" nav atrasta!"), encoding.fromutf8("Kļūda"));
else

  // nolasa pēdējās apstrādātās SMS ID
  try
    f = io.open(sms_id_file);
    sms_id_last = io.readm(f);
    io.close(f);
  catch e by
    f = io.append(sms_id_file);
    io.writem(f, sms_id_last);
    io.close(f);
  end;

do

  sms_buffer = [];
  
  try
    cmd = ui.cmd(20);

    if cmd = CMD_ABOUT then
      ui.msg(encoding.fromutf8("Pārsūta People.lv HAB telemetrijas īsziņas uz serveri.\n\nAutors: x-f\nVersija: 14.10.2012."), CMD_ABOUT);
    end;

    if cmd # CMD_EXIT then
      // power saving
      sleep(sleep_sec * 1000);
      lib.log("processing..");
    end;

    for sms_id in sms.inbox() do
      // lai vēlreiz nepārbaudītu tās īsziņas, kas jau ir reiz pārbaudītas,
      // jo sms_id ir pēc kārtas
      if (sms_id > sms_id_last) then
        item = sms.get(sms_id);
        sms_txt = item["text"];
        
        if lib.validate_sms(sms_txt) then
          lib.log("sms_id: " + sms_id);
          append(sms_buffer, [sms_id, sms_txt]);
          if len(sms_buffer) >= smscnt then break; end;
        end;
      end;
    end;

    if len(sms_buffer) > 0 then
      lib.log("sms buffer: " + len(sms_buffer));
      
      data = [];
      for item in sms_buffer do
        //sms_id = item[0];
        sms_txt = item[1];
        //lib.log(sms_id, "upl");
        append(data, ["data[]": sms_txt]);
      end;
      
      lib.log("uploading..");
      if lib.upload_telemetry(data) then
        lib.log("TM uploaded");
        for item in sms_buffer do
          sms_id = item[0];
          sms_txt = item[1];
        
          lib.log_sms(sms_txt);
          lib.archive_sms(sms_id, sms_archive_id);
          lib.log("archived " + sms_id);
          
          sms_id_last = sms_id;
          // piefiksē failā, ja nu nepieciešams pēc restarta
          f = io.open(sms_id_file, true);
          io.writem(f, sms_id_last);
          io.close(f);
        end;
      else
        lib.log("TM not uploaded");
      end;
      
      lib.log("---");
    end;
   
  catch e by
    lib.log("main loop: " + e, "error");
  end;

until cmd = CMD_EXIT;

end;

lib.log("People.lv HAB TM RT stopped");