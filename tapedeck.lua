-- tapedeck v1.0.0
-- tape emulator fx
--
-- llllllll.co/t/tapedeck
--
--
--
--    ▼ instructions below ▼
--
-- K2/K3 toggles stages
-- E1/E2/E3 changes parameters
--

counter=0
tape_spin=0
font_level=15
message="drive=0.5"
pcur=1

groups={
  {"tape_wet","saturation","drive"},
  {"dist_wet","lowgain","highgain"},
  {"wowflu","wobble_amp","flutter_amp"},
}

current_monitor_level=0
UI=require 'ui'
loaded_files=0
Needs_Restart=false
Engine_Exists=(util.file_exists('/home/we/.local/share/SuperCollider/Extensions/supercollider-plugins/AnalogTape_scsynth.so') or util.file_exists("/home/we/.local/share/SuperCollider/Extensions/PortedPlugins/AnalogTape_scsynth.so"))
engine.name=Engine_Exists and 'Tapedeck' or nil

function init()
  Needs_Restart=false
  if not Engine_Exists then
    clock.run(function()
      if not Engine_Exists then
        Needs_Restart=true
        Restart_Message=UI.Message.new{"installing tapedeck..."}
        redraw()
        clock.sleep(1)
        os.execute("cd /tmp && wget https://github.com/schollz/tapedeck/releases/download/PortedPlugins/PortedPlugins.tar.gz && tar -xvzf PortedPlugins.tar.gz && rm PortedPlugins.tar.gz && sudo rsync -avrP PortedPlugins /home/we/.local/share/SuperCollider/Extensions/")
      end
      Restart_Message=UI.Message.new{"please restart norns."}
      redraw()
      clock.sleep(1)
      do return end
    end)
    do return end
  end

  current_monitor_level=params:get("monitor_level")
  params:set("monitor_level",-99)

  params:add_control("amp","amp",controlspec.new(0,1,'lin',0.01/1,1,'',0.1/1))
  params:set_action("amp",function(x)
    engine.amp(x)
    msg("amp="..(math.floor(x*10)/10))
  end)
  params:add_separator("tape")
  local ps={
    {"tape_wet","wet",0,100},
    {"tape_bias","bias",50,100},
    {"saturation","sat",80,200},
    {"drive","drive",80,200},
  }
  for _,p in ipairs(ps) do
    params:add_control(p[1],p[2],controlspec.new(0,p[4],'lin',1,p[3],"%",1/p[4]))
    params:set_action(p[1],function(x)
      engine[p[1]](x/100)
      msg(p[2].."="..math.floor(x).."%")
    end)
  end
  params:add_separator("distortion")
  local ps={
    {"dist_wet","wet",0,100},
    {"drivegain","drive",21,100},
    {"dist_bias","bias",22,250},
    {"lowgain","low",5,30},
    {"highgain","high",5,30},
  }
  for _,p in ipairs(ps) do
    params:add_control(p[1],p[2],controlspec.new(0,p[4],'lin',1,p[3],"%",1/p[4]))
    params:set_action(p[1],function(x)
      engine[p[1]](x/100)
      msg(p[2].."="..math.floor(x).."%")
    end)
  end
  params:add_control("shelvingfreq","shelving freq",controlspec.new(20,16000,'exp',10,600,'Hz',10/16000))
  params:set_action("shelvingfreq",function(x)
    engine.shelvingfreq(x)
  end)

  params:add_separator("wow / flutter")
  local ps={
    {"wowflu","wet",0},
    {"wobble_amp","wobble",8},
    {"flutter_amp","flutter",3},
  }
  for _,p in ipairs(ps) do
    params:add_control(p[1],p[2],controlspec.new(0,100,'lin',1,p[3],"%",1/100))
    params:set_action(p[1],function(x)
      engine[p[1]](x/100)
      msg(p[2].."="..math.floor(x).."%")
    end)
  end
  params:add_control("wobble_rpm","wobble rpm",controlspec.new(1,66,'lin',1,33,'rpm',1/66))
  params:set_action("wobble_rpm",function(x)
    engine.wobble_rpm(x)
  end)
  params:add_control("flutter_fixedfreq","flutter freq",controlspec.new(0.1,10,'lin',0.1,6,'Hz',0.1/10))
  params:set_action("flutter_fixedfreq",function(x)
    engine.flutter_fixedfreq(x)
  end)
  params:add_control("flutter_variationfreq","flutter var freq",controlspec.new(0.1,10,'lin',0.1,2,'Hz',0.1/10))
  params:set_action("flutter_variationfreq",function(x)
    engine.flutter_variationfreq(x)
  end)

  params:add_separator("filters")
  params:add_control("lpf","low-pass filter",controlspec.new(100,20000,'exp',100,18000,'Hz',100/18000))
  params:set_action("lpf",function(x)
    engine.lpf(x)
  end)
  params:add_control("lpfqr","low-pass qr",controlspec.new(0.02,1,'lin',0.02,0.7,'',0.02/1))
  params:set_action("lpfqr",function(x)
    engine.hpfqr(x)
  end)
  params:add_control("hpf","high-pass filter",controlspec.new(10,20000,'exp',10,60,'Hz',10/18000))
  params:set_action("hpf",function(x)
    engine.hpf(x)
  end)
  params:add_control("hpfqr","high-pass qr",controlspec.new(0.02,1,'lin',0.02,0.7,'',0.02/1))
  params:set_action("hpfqr",function(x)
    engine.hpfqr(x)
  end)

  params:bang()

  msg("MIX "..ToRomanNumerals(math.random(1,12)),30)

  clock.run(function()
    while true do
      clock.sleep(1/10)
      redraw()
    end
  end)
end

function cleanup()
  params:set("monitor_level",current_monitor_level)
end

function ToRomanNumerals(s)
  local map={
    I=1,
    V=5,
    X=10,
    L=50,
    C=100,
    D=500,
    M=1000,
  }
  local numbers={1,5,10,50,100,500,1000}
  local chars={"I","V","X","L","C","D","M"}

  --s = tostring(s)
  s=tonumber(s)
  if not s or s~=s then error"Unable to convert to number" end
  if s==math.huge then error"Unable to convert infinity" end
  s=math.floor(s)
  if s<=0 then return s end
  local ret=""
  for i=#numbers,1,-1 do
    local num=numbers[i]
    while s-num>=0 and s>0 do
      ret=ret..chars[i]
      s=s-num
    end
    --for j = i - 1, 1, -1 do
    for j=1,i-1 do
      local n2=numbers[j]
      if s-(num-n2)>=0 and s<num and s>0 and num-n2~=n2 then
        ret=ret..chars[j]..chars[i]
        s=s-(num-n2)
        break
      end
    end
  end
  return ret
end

function key(k,z)
  if k>1 and z==1 then
    pcur=util.clamp(pcur+(k*2-5),1,3)
    if pcur==1 then
      msg("tape fx")
    elseif pcur==2 then
      msg("dist fx")
    elseif pcur==3 then
      msg("wow/flu")
    end
  end
end

function enc(k,d)
  local name=groups[pcur][k]
  params:delta(name,d)
end

function msg(s,l)
  message=s
  font_level=l or 15
end

function rect(x1,y1,x2,y2,l)
  screen.level(l or 15)
  screen.rect(x1,y1,x2-x1+1,y2-y1+1)
  screen.fill()
end

function erase(x,y)
  screen.level(0)
  screen.pixel(x,y)
  screen.fill()
end

function circle(x,y,r,l)
  screen.level(l)
  screen.circle(x,y,r)
  screen.fill()
end

function redraw()
  if Needs_Restart then
    screen.clear()
    screen.level(15)
    Restart_Message:redraw()
    screen.update()
    return
  end
  screen.clear()
  screen.aa(1)
  counter=counter+1
  tape_spin=tape_spin+(counter%math.random(1,4)==0 and 1 or 0)
  if tape_spin==5 then
    tape_spin=0
  end
  local tape_color=15
  local band_color=9
  local bot_color=6
  local ring_color=12
  local magnet_color=2
  local magnet_inner=0
  local window_color=10
  local inner_tape_dark=0
  local inner_tape_light=4
  local very_bottom=13
  rect(21,3,109,59,tape_color)
  rect(21,3,22,4,0)
  rect(23,5,24,6,0)
  rect(21,58,22,59,0)
  rect(23,56,24,57,0)
  rect(106,5,107,6,0)
  rect(108,3,109,4,0)
  rect(106,56,107,57,0)
  rect(108,58,109,59,0)
  rect(25,9,105,23,0)
  rect(25,9,26,10,tape_color)
  rect(104,9,105,10,tape_color)
  rect(25,24,105,25,band_color)
  rect(25,26,105,46,bot_color)
  rect(36,26,94,40,ring_color)
  rect(36,26,37,27,bot_color)
  rect(36,39,37,40,bot_color)
  rect(93,26,94,27,bot_color)
  rect(93,39,94,40,bot_color)
  rect(38,28,47,38,magnet_color)
  rect(38,28,39,29,ring_color)
  rect(46,28,47,29,ring_color)
  rect(38,36,39,38,ring_color)
  rect(46,36,47,38,ring_color)
  rect(80,28,90,38,magnet_color)
  rect(80,28,82,29,ring_color)
  rect(89,28,90,29,ring_color)
  rect(80,36,82,38,ring_color)
  rect(89,36,90,38,ring_color)
  rect(38,34-tape_spin,39,35-tape_spin,magnet_inner)
  rect(40+tape_spin,28,41+tape_spin,29,magnet_inner)
  rect(46,30+tape_spin,47,31+tape_spin,magnet_inner)
  rect(44-tape_spin,36,45-tape_spin,38,magnet_inner)

  rect(80,34-tape_spin,82,35-tape_spin,magnet_inner)
  rect(83+tape_spin,28,84+tape_spin,29,magnet_inner)
  rect(89,30+tape_spin,90,31+tape_spin,magnet_inner)
  rect(87-tape_spin,36,88-tape_spin,38,magnet_inner)

  rect(53,28,75,33,window_color)
  rect(55,34,56,35,window_color)
  rect(59,34,60,35,window_color)
  rect(63,34,66,35,window_color)
  rect(68,34,69,35,window_color)
  rect(72,34,73,35,window_color)

  rect(61,28,69,33,inner_tape_dark)
  rect(70,28,71,33,inner_tape_light)
  rect(72,28,75,33,window_color-1)

  rect(36,49,92,57,very_bottom)
  rect(33,56,35,57,very_bottom)
  rect(93,56,94,57,very_bottom)
  rect(36,49,37,50,tape_color)
  rect(91,49,92,50,tape_color)

  rect(40,53,43,55,magnet_color)
  rect(51,53,52,55,magnet_color)
  rect(76,53,77,55,magnet_color)
  rect(85,53,87,55,magnet_color)
  rect(61,51,62,52,magnet_color)
  rect(66,51,67,52,magnet_color)

  if font_level>0 then
    font_level=font_level-1
    screen.aa(0)
    screen.font_face(15)
    screen.font_size(11)
    screen.move(64,21)
    screen.level(font_level>15 and 15 or font_level)
    screen.text_center(message)
  end

  screen.update()
end
