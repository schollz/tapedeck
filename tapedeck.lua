-- tapedeck v2.1.0
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

musicutil=require("musicutil")
counter=0
tape_spin_=0.25
tape_spin=0
font_level=15
message="drive=0.5"
pcur=1

groups={
  {"preamp0","preamp0","preamp0"},
  {"toggle1","hpf1","lpf1"},
  {"toggle2","thresh2","drive2"},
  {"toggle3","sine_drive_wet3","compress_curve_wet3"},
  {"toggle4","tape_bias4","drive4"},
  {"toggle5","drivegain5","dist_bias5"},
  {"toggle6","wobble_amp6","flutter_amp6"},
  {"toggle7","depth7","freq7"},
  {"toggle8","gap8","speed8"},
  {"toggle9","depth9","amount9"},
  {"toggle10","wet10","predelay10"},
  {"db11","db11","db11"},
}
stages_toggled=0

current_monitor_level=0

-- check for requirements
installer_=include("lib/installer")
installer=installer_:init{requirements={"Fverb","Chew","Degrade","Tape"},zip="https://github.com/schollz/tapedeck/releases/download/portedplugins2/PortedPlugins.tar.gz"}
engine.name=installer:ready() and 'Tapedeck' or nil

function init()
  if not installer:ready() then 
    do return end 
  end

  current_monitor_level=params:get("monitor_level")
  params:set("monitor_level",-99)

  local params_menu={
    {stage=0,id="preamp",name="preamp",min=-96,max=24,exp=false,div=0.1,default=0,formatter=function(param) local v=param:get()>0 and "+" or "";return string.format("%s%2.1f dB",v,param:get()) end},
    -- filter
    {stage=1,id="toggle",name="filter",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=1,id="tascam",name="tascam-esque",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "yes" or "no" end},
    {stage=1,id="lpf",name="lpf",min=10,max=135,exp=false,div=0.1,default=135,val=function(x) return musicutil.note_num_to_freq(x) end,formatter=function(param) return math.floor(musicutil.note_num_to_freq(math.floor(param:get()))).." Hz"end},
    {stage=1,id="lpfqr",name="lpf qr",min=0.01,max=1,exp=false,div=0.01,default=0.71},
    {stage=1,id="hpf",name="hpf",min=1,max=60,exp=false,div=0.1,default=10,val=function(x) return musicutil.note_num_to_freq(x) end,formatter=function(param) return math.floor(musicutil.note_num_to_freq(math.floor(param:get()))).." Hz"end},
    {stage=1,id="hpfqr",name="hpf qr",min=0.01,max=1,exp=false,div=0.01,default=0.71},
    -- compression
    {stage=2,id="toggle",name="compression",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=2,id="drive",name="drive",min=-12,max=64,exp=false,div=0.1,default=1,formatter=function(param) local v=param:get()>0 and "+" or "";return string.format("%s%2.1f dB",v,param:get()) end},
    {stage=2,id="thresh",name="thresh",min=-96,max=24,exp=false,div=0.1,default=-6,formatter=function(param) local v=param:get()>0 and "+" or "";return string.format("%s%2.1f dB",v,param:get()) end},
    {stage=2,id="slopeBelow",name="slopeBelow",min=-96,max=24,exp=false,div=0.1,default=0,formatter=function(param) local v=param:get()>0 and "+" or "";return string.format("%s%2.1f dB",v,param:get()) end},
    {stage=2,id="slopeAbove",name="slopeAbove",min=-96,max=24,exp=false,div=0.1,default=-12,formatter=function(param) local v=param:get()>0 and "+" or "";return string.format("%s%2.1f dB",v,param:get()) end},
    {stage=2,id="clampTime",name="clampTime",min=0.001,max=1,exp=false,div=0.001,default=0.002,unit="s"},
    {stage=2,id="relaxTime",name="relaxTime",min=0.001,max=1,exp=false,div=0.001,default=0.01,unit="s"},
    -- color
    {stage=3,id="toggle",name="color",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=3,id="sine_drive_wet",name="sinoid wet",min=0,max=1,exp=false,div=0.01,default=0,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=3,id="sine_drive",name="sinoid drive",min=0,max=2,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=3,id="compress_curve_wet",name="compress wet",min=0,max=1,exp=false,div=0.01,default=0,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=3,id="compress_curve_drive",name="compress drive",min=0,max=2,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=3,id="expand_curve_wet",name="expand wet",min=0,max=1,exp=false,div=0.01,default=0,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=3,id="expand_curve_drive",name="expand drive",min=0,max=2,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    -- tape
    {stage=4,id="toggle",name="tape",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=4,id="tape_wet",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=4,id="tape_bias",name="bias",min=0,max=2,exp=false,div=0.01,default=0.9,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=4,id="saturation",name="saturation",min=0,max=2,exp=false,div=0.01,default=0.8,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=4,id="drive",name="drive",min=0,max=2,exp=false,div=0.01,default=0.9,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    -- distortion
    {stage=5,id="toggle",name="distortion",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=5,id="dist_wet",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=5,id="drivegain",name="drive",min=0,max=1,exp=false,div=0.01,default=0.05,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=5,id="dist_bias",name="bias",min=0,max=1,exp=false,div=0.01,default=0.2,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=5,id="lowgain",name="low gain",min=0,max=1,exp=false,div=0.01,default=0.1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=5,id="highgain",name="high gain",min=0,max=1,exp=false,div=0.01,default=0.1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=5,id="shelvingfreq",name="shelf",min=100,max=1000,exp=false,div=10,default=600,unit="Hz"},
    -- wobble
    {stage=6,id="toggle",name="wow/flutter",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=6,id="wowflu",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=6,id="wobble_amp",name="wobble",min=0,max=1,exp=false,div=0.01,default=0.05,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=6,id="wobble_rpm",name="speed",min=1,max=90,exp=false,div=1,default=33,unit="rpm"},
    {stage=6,id="flutter_amp",name="flutter",min=0,max=1,exp=false,div=0.01,default=0.03,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=6,id="flutter_fixedfreq",name="flutter fixed",min=0.1,max=30,exp=false,div=0.1,default=6,unit="Hz"},
    {stage=6,id="flutter_variationfreq",name="flutter variation",min=0.1,max=10,exp=false,div=0.1,default=2,unit="Hz"},
    -- chew
    {stage=7,id="toggle",name="chew",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=7,id="wet",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=7,id="depth",name="depth",min=0,max=1,exp=false,div=0.01,default=0.15,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=7,id="freq",name="freq",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=7,id="variance",name="variance",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    -- loss
    {stage=8,id="toggle",name="loss",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=8,id="wet",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=8,id="gap",name="gap",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=8,id="thick",name="thick",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=8,id="space",name="space",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=8,id="speed",name="speed",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    -- degrade
    {stage=9,id="toggle",name="degrade",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=9,id="wet",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=9,id="depth",name="depth",min=0,max=1,exp=false,div=0.01,default=0.2,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=9,id="amount",name="amount",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=9,id="variance",name="variance",min=0,max=1,exp=false,div=0.01,default=0.1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    -- reverb
    {stage=10,id="toggle",name="reverb",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=10,id="wet",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=10,id="predelay",name="predelay",min=10,max=250,exp=false,div=5,default=60,formatter=function(param) return string.format("%d ms",util.round(param:get())) end},
    -- final
    {stage=11,id="db",name="final",min=-96,max=16,exp=false,div=0.1,default=0,response=1,formatter=function(param) local v=param:get()>0 and "+" or "";return string.format("%s%2.1f dB",v,param:get()) end},
  }
  for _,pram in ipairs(params_menu) do
    local id=pram.id..pram.stage
    -- if pram.id=="toggle" then
    --   params:add_separator(pram.name)
    -- end
    local name=pram.name
    if pram.id=="toggle" or pram.stage==0 or pram.stage==10 then
      name=string.upper(name).." >"
    end
    params:add{
      type="control",
      id=id,
      name=name,
      controlspec=controlspec.new(pram.min,pram.max,pram.exp and "exp" or "lin",pram.div,pram.default,pram.unit or "",pram.div/(pram.max-pram.min)),
      formatter=pram.formatter,
    }
    params:set_action(id,function(x)
      if pram.id=="toggle" then
        engine.toggle(pram.stage,x)
        -- update the hiding/showing in the menu
        for stage=1,9 do
          if params:get("toggle"..stage)==1 then
            stages_toggled=stages_toggled+1
          end
          for _,p in ipairs(params_menu) do
            if p.stage==stage then
              if params:get("toggle"..p.stage)==0 and p.id~="toggle" then
                params:hide(p.id..p.stage)
              else
                params:show(p.id..p.stage)
              end
            end
          end
        end
        _menu.rebuild_params()
      else
        engine.set(pram.stage,pram.id,pram.val and pram.val(x) or x)
      end
    end)
  end

  params:bang()

  msg("TAPEDECK v2.1.0",30)

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
  if not installer:ready() then 
    installer:key(k,z)
    do return end 
  end
  if k>1 and z==1 then
    pcur=util.clamp(pcur+(k*2-5),1,#groups)
    msg(get_name(groups[pcur][1]))
  end
end

function enc(k,d)
  if not installer:ready() then 
    do return end 
  end
  if k>1 and params:get_raw(groups[pcur][1])==0 then
    params:set(groups[pcur][1],1)
  end
  local id=groups[pcur][k]
  params:delta(id,d)
  msg(get_name(id).." "..params:string(id))
end

function get_name(id)
  local name=params.params[params.lookup[id]].name
  name=string.lower(name)
  name=name:gsub('%>','')
  name=string.gsub(name,'^%s*(.-)%s*$','%1')
  return name
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
  if not installer:ready() then 
    installer:redraw()
    do return end 
  end
  screen.clear()
  screen.aa(1)
  counter=counter+1
  tape_spin=tape_spin+tape_spin_
  if tape_spin>=4.5 or tape_spin<=0 then
    tape_spin_=tape_spin_*-1
  end
  tape_spin=params:get_raw(groups[pcur][1])==0 and 0 or tape_spin
  local tape_color=params:get_raw(groups[pcur][1])==0 and 5 or 15
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
    screen.aa(1)
    screen.font_face(1)
    screen.font_size(8)
    screen.move(64,20)
    screen.level(font_level>15 and 15 or font_level)
    screen.text_center(message)
  end

  screen.update()

  for ii,i in ipairs({10,12,14,18,25,30,40,50,66}) do
    if ii-1<stages_toggled then
      screen.aa(1)
      local y=(counter+i)%64
      screen.move(0,y)
      screen.line(128,y)
      screen.blend_mode(math.random(1,10))
      screen.level(1)
      screen.stroke()
    end
  end
  screen.update()
end

