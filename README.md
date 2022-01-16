# tapedeck

live tape fx (saturation, distortion, wow/flutter).


![moonraker](https://user-images.githubusercontent.com/6550035/149668537-202958bc-c680-4880-a8a2-d104cc9e15dd.png)



this norns engine combines the incredible plugins ported by Mads Kjeldgaard ([portedplugins](https://github.com/madskjeldgaard/portedplugins)) which are ported from [Jatin Chowdhury's ChowDSP-VCV-rack project](https://github.com/jatinchowdhury18/ChowDSP-VCV). it is a tape fx emulator - providing three stages of effects: tape saturation, tape distortion, and then wow/flutter.

https://vimeo.com/666500841

## Requirements

- norns
- portedplugins (see below for install)

## Documentation

see the `PARAMS` menu for all the parameters.

parameters are accessible through the main UI too - 

- K2/K3 toggles between stages (tape, distortion, wow/flutter)
- E1/E2/E3 manipulate parameters for that stage

## Install

install using with

```
;install https://github.com/schollz/tapedeck
```

after installing, make sure you install the plugins with this command in maiden:

```
os.execute("cd /tmp && wget https://github.com/schollz/tapedeck/releases/download/PortedPlugins/PortedPlugins.tar.gz && tar -xvzf PortedPlugins.tar.gz && rm PortedPlugins.tar.gz && sudo rsync -avrP PortedPlugins /usr/share/SuperCollider/Extensions/")
```