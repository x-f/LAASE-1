use files, msg, ui, encoding;
use net, io;
use xflib as lib;
use xf_cfg as cfg;


buffer_file = cfg.bufferfile;


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

	// pārbauda failu
	if files.exists(buffer_file) then

		try
			f = io.open(buffer_file);
			sms_buffer = io.readm(f);
			io.close(f);
			
			// augšuplādē uz servera
			if len(sms_buffer) > 0 then
				lib.log("sms buffer: " + len(sms_buffer));
				
				data = [];
				for item in sms_buffer do
					sms_txt = item[1];
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
					end;
					
					files.delete(buffer_file);

				else
					lib.log("TM not uploaded");
				end;
				
				lib.log("---");
			end;    
			
		catch e by
			lib.log("main: " + e, "error");
		end;

	else
		lib.log("no buffer file");
	end;
	
end;