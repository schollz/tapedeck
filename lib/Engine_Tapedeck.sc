Engine_Tapedeck : CroneEngine {
	
	var synTape;
	var buf;
	
	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}
	
	
	alloc {
        var mips=0.0;
        var piped = Pipe.new("lscpu | grep BogoMIPS | awk '{print $2}'", "r"); 
        var oversample=2;
        mips = piped.getLine.asFloat;
        piped.close;
        ["BogoMIPS: ",mips].postln;
        if (mips>200,{
            oversample=3;
        });
		
		buf=Buffer.alloc(context.server,48000*180,2);
		
		context.server.sync;
		
		// wow and flutter from Stefaan Himpe https://sccode.org/1-5bP
		
		synTape={
			arg amp=0.5,tape_wet=0,tape_bias=0.5,saturation=0.5,drive=0.5,
			tape_oversample=2,mode=0,
			dist_wet=0,drivegain=0.5,dist_bias=0,lowgain=0.1,highgain=0.1,
			shelvingfreq=600,dist_oversample=1,
			wowflu=1.0,
			wobble_rpm=33, wobble_amp=0.05, flutter_amp=0.03, flutter_fixedfreq=6, flutter_variationfreq=2,
			hpf=60,hpfqr=0.6,
			lpf=18000,lpfqr=0.6,
			buf;
			var snd;
			var pw,pr,sndr,rate,switch;
			var wow = wobble_amp*SinOsc.kr(wobble_rpm/60,mul:0.1);
			var flutter = flutter_amp*SinOsc.kr(flutter_fixedfreq+LFNoise2.kr(flutter_variationfreq),mul:0.02);
			rate= 1 + (wowflu * (wow+flutter));		
			snd=SoundIn.ar([0,1]);
			
			// write to tape and read from
			pw=Phasor.ar(0, BufRateScale.kr(buf), 0, BufFrames.kr(buf));
			pr=DelayL.ar(Phasor.ar(0, BufRateScale.kr(buf)*rate, 0, BufFrames.kr(buf)),0.2,0.2);
			BufWr.ar(snd,buf,pw);
			sndr=BufRd.ar(2,buf,pr,interpolation:4);
			switch=Lag.kr(wowflu>0,1);
			snd=SelectX.ar(switch,[snd,sndr]);
			
			snd=snd*amp;
			
			snd=SelectX.ar(Lag.kr(tape_wet,1),[snd,AnalogTape.ar(snd,tape_bias,saturation,drive,oversample,mode)]);
			
			snd=SelectX.ar(Lag.kr(dist_wet/5,1),[snd,AnalogVintageDistortion.ar(snd,drivegain,dist_bias,lowgain,highgain,shelvingfreq,oversample-1)]);			
			
			snd=RHPF.ar(snd,hpf,hpfqr);
			snd=RLPF.ar(snd,lpf,lpfqr);
			
			Out.ar(0,snd);
		}.play(context.server,[\buf,buf]);
		
		[\hpf,\hpfqr,\lpf,\lpfqr,\wowflu,\wobble_rpm,\wobble_amp,\flutter_amp,\flutter_fixedfreq,\flutter_variationfreq,\amp,\tape_wet,\tape_bias,\saturation,\drive,\tape_oversample,\mode,\dist_wet,\drivegain,\dist_bias,\lowgain,\highgain,\shelvingfreq,\dist_oversample].do({ arg key;
			this.addCommand(key, "f", { arg msg;
				synTape.set(key,msg[1]);
			});
		});
	}
	
	free {
		synTape.free;
		buf.free;
	}
	
}
