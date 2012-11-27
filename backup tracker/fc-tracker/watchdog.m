// simple "watchdog" script to restart "fc-tracker"
// if it suddenly hangs (has happened a couple of times, cause not known)

use files, time, proc, io, system;
use fc_cfg as fc_cfg;
use lib_fc as fc;

time_ping = 0;
rbt_cnt = 0;
cnt = 0;

// -----------------------------
const pipename_ping = "FCPING";
// 
if not proc.runs("fc-tracker") then
  pipe_ping = proc.pipe(pipename_ping, true);
  //proc.run("fc-tracker");
else
  pipe_ping = proc.pipe(pipename_ping);
end;
if (isnative(pipe_ping)) then
  fc.log("pipe open", "WD");
end;
// -----------------------------

do
  // power saving
  sleep(5000);
  
  cnt++;
  if (cnt % 100 = 0) then cls(); end;

  try
    io.print(io.stdout, ".");

    if io.avail(pipe_ping) > 0 then
      time_ping = time.get();
      msg = io.read(pipe_ping, io.avail(pipe_ping));
      io.print(io.stdout, "_");
      //fc.log("got " + " (" + io.avail(pipe_ping) + ")", "WD");
      // "." - a valid ping = got data from the GPS
      if (index(msg, ".") > -1) then
        rbt_cnt = 0;
      end;
    end;
    
    time_now = time.get();
    tdiff = time_now - time_ping;
    
    if (time_ping > 0 and tdiff > 20) then
      proc.show();
      io.println(io.stdout, "");

      fc.log("reboot: " + rbt_cnt);
      if (rbt_cnt >= 2) then
        fc.log("** reboot **");
        sleep(10000);
        system.reboot();
      end;
    
      fc.log("time diff: " + tdiff, "WD");
      //fc.log(time.str(time_ping));
      //fc.log(time.str(time_now));
      fc.log("stopping fc-tracker");
      proc.stop("fc-tracker");
      fc.log("waiting 20 seconds");
      // to close bluetooth connection
      sleep(20000);
      fc.log("starting fc-tracker");
      proc.run("fc-tracker");
      proc.show("fc-tracker");
      
      time_ping = 0;
      rbt_cnt++;
    end;
    
  catch e by 
    fc.log(e, "WD");
  end;
  
until false;
