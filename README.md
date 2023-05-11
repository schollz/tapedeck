# tapedeck

live tape fx (saturation, distortion, wow/flutter).

![tapedeck](https://user-images.githubusercontent.com/6550035/149668537-202958bc-c680-4880-a8a2-d104cc9e15dd.png)

this is a tape deck emulator - providing 12 ordered stages of effects: 

1) preamp
2) filtering / tascam emulation
3) compression
4) color / waveshaping
5) tape emulation
6) tape distortion
7) wow / flutter
8) chew
9) loss
10) degradation
11) reverb
12) output amp

this script is built off the shoulders of many extraordinary feats of ingenuity - this norns engine combines the incredible plugins ported by Mads Kjeldgaard (@madskjeldgaard) ([portedplugins](https://github.com/madskjeldgaard/portedplugins)) which are ported from [Jatin Chowdhury's ChowDSP-VCV-rack project](https://github.com/jatinchowdhury18/ChowDSP-VCV). the key here is Jatin Chowdhury's [open-source code for physical modeling of tape machines](https://github.com/jatinchowdhury18/AnalogTapeModel), which is beautifully detailed [in this paper](dafx2019.bcu.ac.uk/papers/DAFx2019_paper_3.pdf). the reverb is an implementation from [jpcima](https://github.com/jpcima/fverb) of Jon Dattorro's stereo variant of the reverberator ([Journal of the Audio Engineering Society, 1997](https://ccrma.stanford.edu/~dattorro/EffectDesignPart1.pdf)).

a demo (best used with headphones, tape fx begin around 10 seconds):

https://vimeo.com/666500841

## Requirements

- norns

## Documentation

see the `PARAMS` menu for all the parameters.

parameters are accessible through the main UI too - 

- K2/K3 toggles between stages (tape, distortion, wow/flutter)
- E1/E2/E3 manipulate parameters for that stage

***some notes:***

_note 1:_ when starting this script it will turn your monitor down all the way to only hear the incoming sound through the tapedeck. when you exit the script, the monitor will be returned to you previous setting.

_note 2:_ the "dist fx" (stage 2) has a lot of gain - you can either adjust the input levels (via the MIXER screen) or the wet/drive level of the effect to manipulate the effect of this gain.

_note 3:_ the "wow / flutter" (stage 3), when activated (i.e. non-zero) will act on a delayed buffer of the live input - expect a latency of 100-200 ms when this is activated.

## Install

the tapedeck engine will automatically installed the first time you run.

```
;install https://github.com/schollz/tapedeck
```

