Engine_Tapedeck : CroneEngine {
	
	var synTape;
	var buf;
	var bufs;
	var bufSine;
	
	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}
	
	
	alloc {
        var mips=0.0;
        var piped = Pipe.new("lscpu | grep BogoMIPS | awk '{print $2}'", "r"); 
        var oversample=2;
        var n, mu, unit, expandCurve, compressCurve;
        mips = piped.getLine.asFloat;
        piped.close;
        ["BogoMIPS: ",mips].postln;
        if (mips>200,{
            oversample=3;
        });
 
        n = 512*2;
        mu = 255*2;
        unit = Array.fill(n, {|i| i.linlin(0, n-1, -1, 1) });
        compressCurve = unit.collect({ |x|
            x.sign * log(1 + mu * x.abs) / log(1 + mu);
        });
        expandCurve = unit.collect({ |y|
            y.sign / mu * ((1+mu)**(y.abs) - 1);
        });
        context.server.sync;

		buf=Buffer.alloc(context.server,48000*180,2);
		bufSine=Buffer.alloc(context.server,1024*16,1);
        bufSine.sine2([2],[0.5],false);
		context.server.sync;
        bufs = Dictionary.new();
        bufs.put("compress",Buffer.loadCollection(context.server,Signal.newFrom(compressCurve).asWavetableNoWrap));
        bufs.put("expand",Buffer.loadCollection(context.server,Signal.newFrom(expandCurve).asWavetableNoWrap));
        context.server.sync;
		
		// wow and flutter from Stefaan Himpe https://sccode.org/1-5bP
		
		SynthDef(\main, {
			arg preamp=1,amp=1,tape_wet=0,tape_bias=0.5,saturation=0.5,drive=0.5,
			tape_oversample=2,mode=0,sine_drive=0,sine_buf=0,
			dist_wet=0,drivegain=0.5,dist_bias=0,lowgain=0.1,highgain=0.1,
			shelvingfreq=600,dist_oversample=1,tascam=0,
            compress_curve_wet=0,compress_curve_drive=1,bufCompress,
            expand_curve_wet=0,expand_curve_drive=1,bufExpand,
			wowflu=1.0,
			wobble_rpm=33, wobble_amp=0.05, flutter_amp=0.03, flutter_fixedfreq=6, flutter_variationfreq=2,
			hpf=60,hpfqr=0.6,
			lpf=18000,lpfqr=0.6,
			buf;
			var snd,tascam_snd;
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

			snd=snd*preamp;

			snd=SelectX.ar(Lag.kr(sine_drive),[snd,Shaper.ar(sine_buf,snd)]);
			
            // compress curve
            snd=SelectX.ar(Lag.kr(compress_curve_wet),[snd,Shaper.ar(bufCompress,snd*compress_curve_drive)]);

            // expand cruve
            snd=SelectX.ar(Lag.kr(expand_curve_wet),[snd,Shaper.ar(bufExpand,snd*expand_curve_drive)]);

			snd=SelectX.ar(Lag.kr(tape_wet,1),[snd,AnalogTape.ar(snd,tape_bias,saturation,drive,oversample,mode)]);
			
			snd=SelectX.ar(Lag.kr(dist_wet/5,1),[snd,AnalogVintageDistortion.ar(snd,drivegain,dist_bias,lowgain,highgain,shelvingfreq,oversample-1)]);			
			
			snd=RHPF.ar(snd,hpf,hpfqr);
			snd=RLPF.ar(snd,lpf,lpfqr);

			// http://www.endino.com/graphs/MS-16TASCAM.GIF
			tascam_snd=BHiPass.ar(snd,30);
			tascam_snd=BPeakEQ.ar(snd,freq:60,rq:3,db:4);
			tascam_snd=BPeakEQ.ar(tascam_snd,freq:150,rq:1.5,db:4);
			tascam_snd=BPeakEQ.ar(tascam_snd,210,db:3);
			tascam_snd=BPeakEQ.ar(tascam_snd,250,db:-1.5);
			tascam_snd=BPeakEQ.ar(tascam_snd,300,db:3);
			tascam_snd=BPeakEQ.ar(tascam_snd,400,db:-3);
			tascam_snd=BPeakEQ.ar(tascam_snd,7000,db:1);
			tascam_snd=BLowPass.ar(tascam_snd,10000);
			snd = (tascam*tascam_snd)+((1-tascam)*snd);
			
            // reduce stereo spread in the bass
            snd = BHiPass.ar(snd,200)+Pan2.ar(BLowPass.ar(snd[0]+snd[1],200));
            
            snd = snd.tanh; // limit

			Out.ar(0,snd*amp);
		}).send(context.server);

		context.server.sync;

		synTape=Synth.new(\main,[\bufExpand,bufs.at("expand"),\bufCompress,bufs.at("compress"),\buf,buf,\sine_buf,bufSine]);
		
		[\preamp,\compress_curve_wet,\compress_curve_drive,\expand_curve_wet,\expand_curve_drive,\tascam,\sine_drive,\hpf,\hpfqr,\lpf,\lpfqr,\wowflu,\wobble_rpm,\wobble_amp,\flutter_amp,\flutter_fixedfreq,\flutter_variationfreq,\amp,\tape_wet,\tape_bias,\saturation,\drive,\tape_oversample,\mode,\dist_wet,\drivegain,\dist_bias,\lowgain,\highgain,\shelvingfreq,\dist_oversample].do({ arg key;
			this.addCommand(key, "f", { arg msg;
				synTape.set(key,msg[1]);
			});
		});
	}
	
	free {
        bufs.keysValuesDo({ arg buf, val;
            val.free;
        });
		synTape.free;
		buf.free;
		bufSine.free;
	}
	
}
