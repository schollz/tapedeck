-- tapedeck v2.0.0
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
Engine_Exists=(util.file_exists('/home/we/.local/share/SuperCollider/Extensions/supercollider-plugins/AnalogDegrade_scsynth.so') or util.file_exists("/home/we/.local/share/SuperCollider/Extensions/PortedPlugins/AnalogTape_scsynth.so"))
engine.name=Engine_Exists and 'Tapedeck' or nil

function init()
  Needs_Restart=false
  -- if not Engine_Exists then
  --   clock.run(function()
  --     if not Engine_Exists then
  --       Needs_Restart=true
  --       Restart_Message=UI.Message.new{"installing tapedeck..."}
  --       redraw()
  --       clock.sleep(1)
  --       -- TODO: update this URL
  --       os.execute("cd /tmp && wget https://github.com/schollz/tapedeck/releases/download/PortedPlugins/PortedPlugins.tar.gz && tar -xvzf PortedPlugins.tar.gz && rm PortedPlugins.tar.gz && sudo rsync -avrP PortedPlugins /home/we/.local/share/SuperCollider/Extensions/")
  --     end
  --     Restart_Message=UI.Message.new{"please restart norns."}
  --     redraw()
  --     clock.sleep(1)
  --     do return end
  --   end)
  --   do return end
  -- end

  current_monitor_level=params:get("monitor_level")
  params:set("monitor_level",-99)

  local params_menu={
    {stage=0,id="preamp",name="preamp",min=-96,max=24,exp=false,div=0.1,default=0,unit="db"},
    -- filter
    {stage=1,id="toggle",name="filter",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=1,id="tascam",name="tascam-esque",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "yes" or "no" end},
    {stage=1,id="lpf",name="lpf",min=10,max=135,exp=false,div=0.5,default=135,val=function(x) return musicutil.note_num_to_freq(x) end,formatter=function(param) return musicutil.note_num_to_name(math.floor(param:get()),true)end},
    {stage=1,id="lpfqr",name="lpf qr",min=0.01,max=1,exp=false,div=0.01,default=0.71},
    {stage=1,id="hpf",name="hpf",min=1,max=60,exp=false,div=0.5,default=10,val=function(x) return musicutil.note_num_to_freq(x) end,formatter=function(param) return musicutil.note_num_to_name(math.floor(param:get()),true)end},
    {stage=1,id="hpfqr",name="hpf qr",min=0.01,max=1,exp=false,div=0.01,default=0.71},
    -- color
    {stage=2,id="toggle",name="color",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=2,id="sine_drive_wet",name="sinoid wet",min=0,max=1,exp=false,div=0.01,default=0,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=2,id="sine_drive",name="sinoid drive",min=0,max=2,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=2,id="compress_curve_wet",name="compress wet",min=0,max=1,exp=false,div=0.01,default=0,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=2,id="compress_curve_drive",name="compress drive",min=0,max=2,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=2,id="expand_curve_wet",name="expand wet",min=0,max=1,exp=false,div=0.01,default=0,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=2,id="expand_curve_drive",name="expand drive",min=0,max=2,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    -- tape
    {stage=3,id="toggle",name="tape",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=3,id="tape_wet",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=3,id="tape_bias",name="bias",min=0,max=2,exp=false,div=0.01,default=0.9,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=3,id="saturation",name="saturation",min=0,max=2,exp=false,div=0.01,default=0.8,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=3,id="drive",name="drive",min=0,max=2,exp=false,div=0.01,default=0.9,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    -- distortion
    {stage=4,id="toggle",name="distortion",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=4,id="dist_wet",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=4,id="drivegain",name="drive",min=0,max=1,exp=false,div=0.01,default=0.05,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=4,id="dist_bias",name="bias",min=0,max=1,exp=false,div=0.01,default=0.2,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=4,id="lowgain",name="low gain",min=0,max=1,exp=false,div=0.01,default=0.1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=4,id="highgain",name="high gain",min=0,max=1,exp=false,div=0.01,default=0.1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=4,id="shelvingfreq",name="shelf",min=100,max=1000,exp=false,div=10,default=600,unit="Hz"},
    -- wobble
    {stage=5,id="toggle",name="wow/flutter",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=5,id="wowflu",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=5,id="wobble_amp",name="wobble",min=0,max=1,exp=false,div=0.01,default=0.05,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=5,id="wobble_rpm",name="wobble rpm",min=1,max=90,exp=false,div=1,default=33,unit="Hz"},
    {stage=5,id="flutter_amp",name="flutter",min=0,max=1,exp=false,div=0.01,default=0.03,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=5,id="flutter_fixedfreq",name="flutter fixed",min=0.1,max=30,exp=false,div=0.1,default=6,unit="Hz"},
    {stage=5,id="flutter_variationfreq",name="flutter variation",min=0.1,max=10,exp=false,div=0.1,default=2,unit="Hz"},
    -- chew
    {stage=6,id="toggle",name="chew",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=6,id="wet",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=6,id="depth",name="depth",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=6,id="freq",name="freq",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=6,id="variance",name="variance",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    -- loss
    {stage=7,id="toggle",name="loss",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=7,id="wet",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=7,id="gap",name="gap",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=7,id="thick",name="thick",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=7,id="space",name="space",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=7,id="speed",name="speed",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    -- degrade
    {stage=8,id="toggle",name="degrade",min=0,max=1,exp=false,div=1,default=0,response=1,formatter=function(param) return param:get()==1 and "ON" or "OFF" end},
    {stage=8,id="wet",name="wet",min=0,max=1,exp=false,div=0.01,default=1,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=8,id="depth",name="depth",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=8,id="amount",name="amount",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    {stage=8,id="variance",name="variance",min=0,max=1,exp=false,div=0.01,default=0.5,formatter=function(param) return string.format("%d%%",util.round(100*param:get())) end},
    -- final
    {stage=9,id="db",name="final",min=-96,max=12,exp=false,div=0.1,default=0,response=1,unit="dB"},
  }
  for _,pram in ipairs(params_menu) do
    local id=pram.id..pram.stage
    -- if pram.id=="toggle" then
    --   params:add_separator(pram.name)
    -- end
    local name=pram.name
    if pram.id=="toggle" or pram.stage==0 or pram.stage==9 then
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
        for stage=1,8 do
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
