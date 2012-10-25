// modulis, kas satur konfigurācijas iestatījumus

use system;

// fails ar GPS ierīces BT adresi
gps_cfgfile = system.docdir + "gpsdev.dat";
// GPS logfails
flight_logfile = system.docdir + "flight.log";


// ik pēc cik sekundēm pielogot GPS info
interval_log = 10;
// ik pēc cik sekundēm iepīkstēties par pašreizējo statusu
interval_statusbeep = 5;
// ik pēc cik sekundēm mēģināt nosūtīt SMS
interval_notify = 30;
// SMS adresāti
notify_sms_recipients = ["xxxxxxxx"];
// augstums (metros!), virs kura neizmantot GSM sakarus
notify_alt_limit = 1300; // metri

// skaņas signālu skaļums (0 - 10)
audio_volume = 1;


// log screen, debug?
// altitude limit for messaging

// ************************************************************************
audio_volume = audio_volume * 10;

// telefona atšķirības zīme
if system.os = "Symbian" then
  flight_device_id = "FC-3120";
else
  flight_device_id = "FC-b";
end;

// atkarībā no imei nosaka
//   flight_device_id
//   net.iap
