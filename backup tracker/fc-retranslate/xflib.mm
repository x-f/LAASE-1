use time, io, net, msg;
use xf_cfg as cfg;
use abhttp2 as http;


function log2file(data, file = "")

  logfile = file;
  
  try
    f = io.append(logfile);

    log_string = "[";
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

function log(data, prefix = "")
  log_string = "[";
  log_string = log_string + time.str(time.get(), 'hh:mm:ss');
  log_string = log_string + "]";
  log_string = log_string + " ";
  if (prefix # "") then
    log_string = log_string + prefix + ": ";
  end;
  if isarray(data) then
    ka = keys(data);
    for k in ka do
      log(data[k], k);
    end;
  else
    log_string = log_string + data;
  end;

  print log_string;
  log2file(log_string, "screen.log");
end;



function validate_sms(sms_txt)
  if (len(sms_txt) > 5 
    and (substr(sms_txt, 0, 3) = "FC;" or substr(sms_txt, 0, 5) = "FC-b;")
    ) then
    return true;
  end;
  return false;
end;

function log_sms(sms_txt)
  log2file(sms_txt, cfg.logfile);
end;

//function upload_telemetry(sms_txt)
function upload_telemetry(data)
  // nosūta uz serveri
  uploaded = false;
  
  try
    // try 10 seconds
    net.timeout(10000);

    //params = ["data": sms_txt];
    params = data;
    conn:http.Socket = http.request(cfg.notify_server_url, http.POST, params, null, true);
    if conn.handleResponse() = 200 then
      log("server notified");
      uploaded = true;
    end;
    conn.close();

  catch net_e by
    log(net_e);
    // io.close(conn.stream);
  end;
  
  //uploaded = true;
  return uploaded;
end;

function archive_sms(sms_id, sms_archive_id)
  // pārvieto sms uz arhīva folderi no inbox'a
  msg.move(sms_id, sms_archive_id);
end;


function send2proc(pipe, data = "")
  if isnative(pipe) then
    try
      io.writem(pipe, data);
    catch e by
      print "ERROR: send2proc: " + e;
    end;
  end;
end;
