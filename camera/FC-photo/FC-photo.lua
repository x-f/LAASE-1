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

-- Made for Canon IXUS 860IS / SD850. Maybe works on different models, too.
-- LAASE-1 high altitude balloon project
-- http://space.people.lv/
-- x-f, 2012

-- to do:
-- decide on params - ISO, exposure compensation, ..


capmode=require("capmode")
propcase=require("propcase")


interval_pictures = a * 60000 + b * 1000
video_duration = c * 1000 -- sekundes
video_every_pics = d


print_screen(2013)

-- *************************************************************

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
    debugstr = "[" .. timestamp(false) .. "] " .. "[" .. type .. "] " .. data
    print(debugstr)
  end

  -- data = i .. " " .. data;
  debugstr = "[" .. timestamp(false) .. "] " .. "[" .. type .. "] " .. data .. "\n"
  
  log_dir = "A/CHDK/LOGS"
  log_filename = "fc-3"

  log_file = log_dir .. "/" .. log_filename .. ".log"
  logfile = io.open(log_file, "ab")
  logfile:write(debugstr)
  logfile:close()
  
end

-- ******************************

function get_envparams()
  t0 = get_temperature(0) -- optical
  t1 = get_temperature(1) -- CCD
  t2 = get_temperature(2) -- battery
  orient = get_orientation_sensor() -- get_prop(219)
  volt = get_vbatt()
  space = get_free_disk_space()
  debuglog("DAT", "data: " .. t0 .. "; " .. t1 .. "; " .. t2 .. "; " .. orient .. "; " .. volt .. "; " .. space, false)
end

-- just take a picture, nothing fancy
function TakePicture()
  press("shoot_half")
  repeat sleep(50) until get_shooting() == true
  press("shoot_full")
  release("shoot_full")
  repeat sleep(50) until get_shooting() == false  
  release "shoot_half"

  -- play_sound(5)
end

-- take a movie for X seconds
-- 1. switch to video mode
-- 2. record a video
-- 3. wait for it to save to disk
-- 4. switch back to P mode
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

  -- record
  sleep(video_duration)

  click("shoot_full")
  sleep(100)
  while get_movie_status() == 5 do
    sleep(500)
    debuglog("DBG", "saving..")
  end
  debuglog("GET", 'get_focus=' .. get_focus() .. ' (3)')

  status=capmode.set('P')
  debuglog("DBG", "P")
  sleep(500)
  
end;

function setup_camera()
  
  debuglog("SET", 'get_prop(QUALITY)=' .. get_prop(propcase.QUALITY))
  debuglog("SET", 'get_prop(RESOLUTION)=' .. get_prop(propcase.RESOLUTION))
  -- superfine, L
  -- jpg quality -1=do not change, 0=super fine, 1=fine, 2=normal, 
  -- jpg resolution -1=do not change, others are whatever they are in your camera:
  -- For a570is Digic III: 0,1,2,3,4,6,8 = L,M1,M2,M3,S,Postcard,W
  -- For s3is   Digic  II: 0,1,2,  4,  8 = L,M1,M2,   S,         W
  set_prop(propcase.QUALITY, 0) 
  sleep(200)
  set_prop(propcase.RESOLUTION, 0) 
  sleep(200)
  debuglog("SET", 'get_prop(QUALITY)=' .. get_prop(propcase.QUALITY))
  debuglog("SET", 'get_prop(RESOLUTION)=' .. get_prop(propcase.RESOLUTION))

  -- force manual focus (does this work?)
  debuglog("SET", 'get_prop(FOCUS_MODE)=' .. get_prop(propcase.FOCUS_MODE))
  set_prop(propcase.FOCUS_MODE, 1) -- sd850 - ok
  sleep(200)
  debuglog("SET", 'get_prop(FOCUS_MODE)=' .. get_prop(propcase.FOCUS_MODE))
  -- focus to Inf
  debuglog("SET", 'get_focus=' .. get_focus())
  set_focus(65535) -- sd850 - fail
  sleep(200)
  debuglog("SET", 'get_focus=' .. get_focus())
  -- focus lock
  set_aflock(1);

  -- IS - shoot only
  debuglog("SET", 'get_prop(IS_MODE)=' .. get_prop(propcase.IS_MODE))
  set_prop(propcase.IS_MODE, 1)
  sleep(200)
  debuglog("SET", 'get_prop(IS_MODE)=' .. get_prop(propcase.IS_MODE))

  -- disable flash
  debuglog("SET", 'get_prop(FLASH_MODE)=' .. get_prop(propcase.FLASH_MODE))
  set_prop(propcase.FLASH_MODE, 2)
  sleep(200)
  debuglog("SET", 'get_prop(FLASH_MODE)=' .. get_prop(propcase.FLASH_MODE))

  -- backlight off
  -- doesn't stay off anyway
  set_backlight(0)
end


function restore()
  play_sound(6)
  -- play_sound(7)

  set_backlight(1)
  set_aflock(0);

  debuglog("INF", "** script ended **")
  logfile:close()
end

-- *************************************************************
-- *************************************************************

sleep(500)

debuglog("INF", '** started **')
play_sound(5)


debuglog("INF", 'setup_camera')
setup_camera()
debuglog("INF", 'all set up')

play_sound(5)
sleep(500)
play_sound(5)

debuglog("INF", 'shooting..')
sleep(500)


i = 0

repeat
  i = i + 1
  StartTick = get_tick_count()
  
  -- if (focus ~= -1 and focus ~= 65535) then
  if (i % 3 == 0) then
    focus = get_focus()
    debuglog("SET", 'get_focus=' .. focus .. ' (1)')
    set_focus(65535)
    sleep(500)
    debuglog("SET", 'get_focus=' .. get_focus() .. ' (2)')
  end

  debuglog("INF", "pic: " .. i)
    
  -- ___________________________________________
  
  TakePicture()
  
  -- doesn't stay off anyway
  -- set_backlight(0)
  
  sleep(1000)
  
  if (i % video_every_pics == 0) then
    debuglog("DBG", "TakeMovie")
    TakeMovie()
  end;
  
  -- log temps etc.
  get_envparams()

  sleep(interval_pictures - (get_tick_count() - StartTick))

until get_shooting() ~= false


restore()