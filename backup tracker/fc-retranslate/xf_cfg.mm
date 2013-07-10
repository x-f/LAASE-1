
use system;

bufferfile = system.docdir + "sms-buffer.txt";
logfile = system.docdir + "telemetry.log";
lastsmsfile = system.docdir + "lastsms.dat";

notify_server_url = "http://space.people.lv/tracker/data/post/telemetry";

// max SMS, cik vienā reizē nosūtīt serverim
smscnt = 3;

// ik pēc cik ilga laika (sekundēs)  atkārtot ciklu
sleep_sec = 10;
