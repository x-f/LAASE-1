--[[
@title People.lv HAB
@param a Picture interval, min
@default a 0
@param b ...sec
@default b 10
@param c Movie length, sec
@default c 30
@param d Movie every .. pics
@default d 10
]]--

-- capmode=require("capmode")
propcase=require("propcase")

-- capmode=require("fc_lib")

interval_pictures = a * 60000 + b * 1000
video_duration = c * 1000 -- sekundes
video_every_pics = d


print_screen(2012)

-- *************************************************************

capmode=require("capmode")


require("metering")
require("fast_tv")

function dbg(msg)
  print(msg)
end

function writelog(prefix, msg)
  print('###' .. prefix .. ' ' .. ' ' .. msg)
end

function metering_reset()
  debuglog("MTR", 'reseting')
  
  bvtable={}
  bvtable_sorted={}
  bvtable_len=100
  bvtable_current=0 
  bvtable_ptr=0
  
  -- 60?
  for n = 1, 10 do
   feed_bvtable()
   sleep(500)
  end
end

function timestamp(full)
  hour = get_time("h")
  min = get_time("m")
  sec = get_time("s")
  year = get_time("Y")
  mon = get_time("M")
  day = get_time("D")
  
  result = ""
  if full == true then
    result = (year .. "-" .. mon .. "-" .. day .. " " .. hour .. ":" .. min .. ":" .. sec)
  else
    result = (hour .. ":" .. min .. ":" .. sec)
  end
  
  return result
end

function debuglog(type, data, onscreen)
  
  if onscreen ~= false then
    debugstr = "[" .. timestamp(false) .. "] " .. "[" .. type .. "]" .. data
    print(debugstr)
  end

  -- data = i .. " " .. data;
  debugstr = "[" .. timestamp(false) .. "] " .. "[" .. type .. "]" .. data .. "\n"
  
  log_dir = "A/CHDK/LOGS"
  log_filename = "fc-2"

  log_file = log_dir .. "/" .. log_filename .. ".log"
  logfile = io.open(log_file, "ab")
  logfile:write(debugstr)
  logfile:close()
  
end

function get_envparams()
  t0 = get_temperature(0) -- optical
  t1 = get_temperature(1) -- CCD
  t2 = get_temperature(2) -- battery
  orient = get_orientation_sensor() -- get_prop(219)
  volt = get_vbatt()
  space = get_free_disk_space()
  debuglog("DAT", "data: " .. t0 .. "; " .. t1 .. "; " .. t2 .. "; " .. orient .. "; " .. volt .. "; " .. space, false)
end


function restore()
  play_sound(6)
  -- play_sound(7)

  -- set_backlight(1)
  set_aflock(0);

  debuglog("INF", "** script ended **")
  logfile:close()
end

function TakePicture()
  press("shoot_half")
  repeat sleep(50) until get_shooting() == true
  press("shoot_full")
  release("shoot_full")
  repeat sleep(50) until get_shooting() == false  
  release "shoot_half"

  -- play_sound(5)
end

function TakeMovie()
  -- sleep(200)
  status=capmode.set('VIDEO_STD')
  debuglog("DBG", "VIDEO_STD")
  sleep(500)
  
  press("shoot_half")
	sleep(500) -- give AF a chance
	press("shoot_full")
	release("shoot_full")
	release("shoot_half")
	
	sleep(video_duration)
	
	click("shoot_full")
	sleep(100)
	while get_movie_status() == 5 do
   sleep(500)
   debuglog("DBG", "saving..")
  end
  
  status=capmode.set('P')
  debuglog("DBG", "P")
  sleep(500)
  
end;

-- *************************************************************

sleep(500)

debuglog("INF", '** started **')
play_sound(5)


-- nestrādā uz SX10, A640
-- debuglog('get_focus=' .. get_focus())
-- -- -1, 25535, 65535
-- if get_propset() == 2 then
--  set_prop(6, -1)
-- else
--  set_prop(11, -1)
-- end
-- sleep(500)
-- debuglog('get_focus=' .. get_focus())

-- 
-- debuglog("SET", 'get_prop(QUALITY)=' .. get_prop(propcase.QUALITY))
-- debuglog("SET", 'get_prop(RESOLUTION)=' .. get_prop(propcase.RESOLUTION))
-- -- superfine, L
-- -- jpg quality -1=do not change, 0=super fine, 1=fine, 2=normal, 
-- -- jpg resolution -1=do not change, others are whatever they are in your camera:
-- -- For a570is Digic III: 0,1,2,3,4,6,8 = L,M1,M2,M3,S,Postcard,W
-- -- For s3is   Digic  II: 0,1,2,  4,  8 = L,M1,M2,   S,         W
-- set_prop(propcase.QUALITY, 0) 
-- sleep(200)
-- set_prop(propcase.RESOLUTION, 0) 
-- sleep(200)
-- debuglog("SET", 'get_prop(QUALITY)=' .. get_prop(propcase.QUALITY))
-- debuglog("SET", 'get_prop(RESOLUTION)=' .. get_prop(propcase.RESOLUTION))
-- 
-- -- force manual focus (does this work?)
-- debuglog("SET", 'get_prop(FOCUS_MODE)=' .. get_prop(propcase.FOCUS_MODE))
-- set_prop(propcase.FOCUS_MODE, 1) -- sd850 - ok
-- sleep(200)
-- debuglog("SET", 'get_prop(FOCUS_MODE)=' .. get_prop(propcase.FOCUS_MODE))
-- -- focus to Inf
-- debuglog("SET", 'get_focus=' .. get_focus())
-- set_focus(65535) -- sd850 - fail
-- sleep(200)
-- debuglog("SET", 'get_focus=' .. get_focus())
-- set_aflock(1);
-- 
-- -- IS - shoot only
-- debuglog("SET", 'get_prop(IS_MODE)=' .. get_prop(propcase.IS_MODE))
-- set_prop(propcase.IS_MODE, 1)
-- sleep(200)
-- debuglog("SET", 'get_prop(IS_MODE)=' .. get_prop(propcase.IS_MODE))
-- 
-- -- disable flash
-- debuglog("SET", 'get_prop(FLASH_MODE)=' .. get_prop(propcase.FLASH_MODE))
-- set_prop(propcase.FLASH_MODE, 2)
-- sleep(200)
-- debuglog("SET", 'get_prop(FLASH_MODE)=' .. get_prop(propcase.FLASH_MODE))

--
-- set_backlight(0)

play_sound(5)
sleep(500)
play_sound(5)

debuglog("INF", 'shooting..')
sleep(500)


metering_reset()
sequence_bv=weighted_bv(50, 80)

i = 0

repeat
  i = i + 1
  StartTick = get_tick_count()
  
  focus = get_focus()
  -- if (focus ~= -1 and focus ~= 65535) then
    debuglog("SET", 'get_focus=' .. get_focus() .. ' (1)')
  --   set_focus(65535)
  --   sleep(500)
  --   debuglog("SET", 'get_focus=' .. get_focus() .. ' (2)')
  -- end

  debuglog("INF", "pic: " .. i)
  
  -- TakePicture()
  
  -- ___________________________________________
  -- ik pēc X kadriem nomēra gaismu no jauna
  if (i % 5 == 0) then
    -- metering_reset()

    -- range_lo and range_hi set start and end of range (in %)
    -- for example, weighted_bv(90, 100) returns the average of the highest 10%
    sequence_bv=weighted_bv(50, 80)
  end
  
  -- fast tv shooting
  -- ja pirmais parametrs ir -1, tad katru reizi mēra gaismu
  -- exposure time 1/1000, max iso 100
  -- high altitude should mean slower movements
  fast_tv_shoot(sequence_bv, 957, 418, 0)
  -- min shutter 1/1000, max iso 100
  -- fast_tv_shoot(-1, 1053, 514, 32)
  -- min shutter 1/1000, max iso 100
  -- fast_tv_shoot(-1, 957, 418, 24)
  
  feed_bvtable()
  -- ___________________________________________
  
  sleep(1000)
  
  if (i % video_every_pics == 0) then
    debuglog("DBG", "TakeMovie")
    TakeMovie()
  end;
    
  get_envparams()

  sleep(interval_pictures - (get_tick_count() - StartTick))

until get_shooting() ~= false

restore()