// modulis, kas satur visas kopīgi izmantojamās funkcijas
// logošana, GPS dati, skaņas signāli, ..

use audio, time, io, system, ui, bt, array, math;
use fc_cfg as fc_cfg;


function log2file(data, file = "")
  logfile = file;
  
  try
    f = io.append(logfile);

    log_string = "[";
    // log_string = log_string + time.str(time.get(), 'hh:mm:ss.ttt');
    log_string = log_string + date();
    log_string = log_string + "]";
    log_string = log_string + " ";
    io.write(f, log_string);

    if (isarray(data)) then
      ka = keys(data);
      for k in ka do
        str = "";
        str = str + k;
        str = str + "=";
        str = str + str(data[k]);
        str = str + ";";
        io.write(f, str);
      end;
    else
      io.write(f, data);
    end;

    io.writeln(f, "");
    io.close(f);
  
  catch e by
    print "ERROR: log2file: " + e;
  end;

end;

function log(data, prefix = "", log2file = true)
  log_string = "[";
  // log_string = log_string + time.str(time.get(), 'hh:mm:ss.ttt');
  log_string = log_string + time.str(time.get(), 'hh:mm:ss');
  log_string = log_string + "]";
  log_string = log_string + " ";
  if (prefix # "") then
    log_string = log_string + prefix + ": ";
  end;
  if isarray(data) then
    ka = keys(data);
    for k in ka do
      log(data[k], k, false);
    end;
  else
    log_string = log_string + data;
  end;

  print log_string;
  
  if log2file then
    log2file(log_string, "screen.log");
  end;
  
end;


function gps_data2str(data)
  result = "";
  
  ka = keys(data);
  for k in ka do
    str = "";
    // str = str + k;
    // str = str + "=";
    d = data[k];
    if k = "date" then
      d = time.str(d, "YYYY-MM-DD");
    elsif k = "time" then
      d = time.str(d, "hh:mm:ss");
    // elsif k = "lat" or k = "lon" then
    //   // pārvērš deg min.dec par deg.dec
    //   d = d[0] + d[1] / 60;
    end;
    str = str + str(d);
    str = str + ";";
    result = result + str;
  end;

  return result;
end;


function telemetry_log(data)
  log2file(gps_data2str(data), fc_cfg.flight_logfile);
end;

function debug_log(data)
  log2file(data, "debug.log");
end;

function print_r(data)
  ka = keys(data);
  for k in ka do
    log(data[k], k, false);
  end;  
end;


function beep(type = null)
  if (fc_cfg.audio_volume > 0) then

    if (type = null) then
      type = "warning";
    end;
  
    // ja nu atskan zvans vai kāda cita telefona skaņa,
    // tad audio.* beigsies ar access denied exception
    try
  
      audio.volume(fc_cfg.audio_volume);
  
      if type = "warning" then
        audio.wait();
        audio.beep(3000, 200);
        audio.wait();
        audio.beep(6000, 400);
      elsif type = "error" then
        audio.wait();
        audio.beep(8000, 200);
        audio.wait();
        audio.beep(3000, 200);
        audio.wait();
        audio.beep(9000, 400);
      else
        audio.wait();
        audio.beep(9000, 200);
      end;
  
    catch e by end;
    
  end;
end;


// function notice(text, type = "warning")
//   if (array.index(["ok", "warning", "error"], type) = -1) then
//     type = "warning";
//   end;
// 
//   notice = "";
//   notice = notice + type + "|";
//   // notice = notice + time.get() + "|";
//   notice = notice + text;
//   return notice;
// end;


// function send2proc(pipe, data = "")
//   if isnative(pipe) then
//     try
//       io.writem(pipe, data);
//     catch e by
//       print "ERROR: send2proc: " + e;
//     end;
//   end;
// end;

// ja atsūta info par kļūdu, nomaina status vērtību,
// lai par to paziņotu ar skaņas signālu
// function receive_proc_msg(data, source = "")
//   result = [
//     "status": "ok",
//     "info": "",
//     // "time": 0,
//     "data": "",
//     "source": source,
//   ];
// 
//   if (index(data, "|") > -1) then
//     message = split(data, "|");
//     result['status'] = message[0];
//     // result['time'] = message[1];
//     result['info'] = message[1];
//     if len(message) > 2 then
//       result['data'] = message[2];
//     end;
//   else
//     // nevajadzētu, bet ja nu..
//     result['status'] = data;
//   end;
// 
//   return result;
// end;

// atlasa no masīva "arr" tos laukus, kas "fields" masīvā,
// atgriež vai nu masīvu, vai stringu
function extractFromArray(array, fields, return_as_string = false)
  res = [];
  
  for i = 0 to len(fields)-1 by 1 do;
    key = fields[i];
    value = array[key];
    if (key = "time" or key = "fix-time") then
      value = time.str(value, "hh:mm:ss");
    end;
    if (key = "speed" or key = "dist") then
      value = math.round(value, 1);
    end;
    if (key = "lat" or key = "lon") then
      value = math.round(value, 7);
    end;
    res[key] = value;
  end;
  
  if (return_as_string) then
    str = "";
    i = 0;
    ka = keys(res);
    for key in ka do
      str = str + key;
      str = str + ": ";
      value = res[key];
      str = str + value;
      if i < len(res)-1 then
        str = str + ", ";
      end;
      i++;
    end;
    res = str;
  end;
  
  return res;
end;

// // visu lauku vērtības, bez key
// function getTelemetryString(array)
//   str = "";
// 
//   i = 0;
//   ka = keys(array);
//   for key in ka do
//     
//     if (key = "date" or key = "sid" or key = "fix-time" or key = "geoid" or key = "pdop" or key = "hdop" or key = "vdop" ) then
//       // šos neko
//     else
//       //str = str + key;
//       //str = str + ": ";
//       value = array[key];
//       if (key = "speed" or key = "dist") then
//         value = math.round(value, 1);
//       end;
//       if (key = "lat" or key = "lon") then
//         value = math.round(value, 7);
//       end;
//       if (key = "time") then
//         value = time.str(array['date'] + array['time'], "hh:mm:ss");
//       end;
//       str = str + value;
//       if i < len(array)-1 then
//         str = str + ";";
//       end;
//       i++;
//     end;
//     
//   end;
//   
//   return str;
// end;

function getTelemetryString(array, fields)
  data = extractFromArray(array, fields);
  str = "";
  i = 0;
  
  keys = keys(data);
  for key in keys do
    value = data[key];
    str = str + value;
    if i < len(keys)-1 then
      str = str + ";";
    end;
    i++;
  end;
  return str;
end;

// function duration_simple($time) {
//   $hours = 0;
//   if ($time > 60 * 60) {
//     $hours = floor($time / 60 / 60);
//     $time = $time - ($hours * 60 * 60);
//   }
// 
//   $minutes = floor($time / 60);
//   $seconds = $time - ($minutes * 60);
//   
//   $hours = str_pad($hours, 2, 0, STR_PAD_LEFT);
//   $minutes = str_pad($minutes, 2, 0, STR_PAD_LEFT);
//   $seconds = str_pad($seconds, 2, 0, STR_PAD_LEFT);
//   
//   $text = $hours . ':' . $minutes . ':' . $seconds;
//   return $text;
// }


// *********************************************************************
// based on airbit's gpsinf.m
// http://www.m-shell.net/forum.aspx?g=posts&t=559

// get GPS BT device adr from file
function bt_getdev() // -> devadr | null
  try
    devfile = fc_cfg.gps_cfgfile;
    f = io.open(devfile);
    dev = io.readm(f);
    io.close(f);
  catch e by
    dev = null;
  end;
  return dev
end;

// ui guided selection of GPS device
function bt_seldev() // -> devadr | null
  ui.busy("Mekleeju GPS..");
  bt.timeout(60000);
  da = [];
  d = bt.scan(false);
  while d # null do
    append(da, d);
    d = bt.scan();
  end;
  // log(da);
  ui.busy();
  // ask user to select devices
  na = [];
  for dev in da do
    // log(dev, "BT");
    append(na, dev['name']);
  end;
  // log(na);
  sel = ui.list(na, false, [], "Select device");
  if sel # null then
    devfile = fc_cfg.gps_cfgfile;
    f = io.create(devfile);
    io.writem(f, da[sel[0]]["adr"]);
    io.close(f);
    return da[sel[0]]["adr"];
  end;
  return null
end;

function bt_conngps(dev) // -> native object bt GPS connection
  // connect GPS device
  if dev = null then
    return null
  end;
  try
    c = bt.chan(dev, 4353);
    if len(c) > 0 then
      bt.timeout(10000);
      s = bt.conn(dev, c[0]);
      if s # null then
        // log("connected: " + keys(c)[0]);
        // gps.info["btdev"] = keys(c)[0];
        return s;
      end;
    end;
  catch e by
    // log("*** could not connect to GPS");
    log(e);
    // bt.stop(s);
    // io.close(s);
    return null;
  end;
end;
