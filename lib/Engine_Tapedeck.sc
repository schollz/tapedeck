Engine_Tapedeck : CroneEngine {
	
	var bufs;
	var bus;
	var bufSine;
	var syns;
	var params;
	var stageNames;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}
	
	
	alloc {
		var stages=10;
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

		bufs.put("wobble",Buffer.alloc(context.server,48000*180,2));
		bufSine=Buffer.alloc(context.server,1024*16,1);
        bufSine.sine2([2],[0.5],false);
		context.server.sync;
		syns = Dictionary.new();
        bufs = Dictionary.new();
        bus = Dictionary.new();
		params = Dictionary.new();
        bufs.put("compress",Buffer.loadCollection(context.server,Signal.newFrom(compressCurve).asWavetableNoWrap));
        bufs.put("expand",Buffer.loadCollection(context.server,Signal.newFrom(expandCurve).asWavetableNoWrap));
        context.server.sync;
		
		// preamp -> filters -> color -> tape -> distortion ->
		// chew -> degrade -> wow/flutter -> loss -> outgain
		stageNames = [
			"preamp",		// 0
			"filters",		// 1
			"color",		// 2
			"tape",			// 3
			"distortion",	// 4
			"wobble",		// 5
			"chew",			// 6
			"loss",			// 7
			"degrade",		// 8
			"final"			// 9
		];

		SynthDef("passthrough", {
			arg in,out;
			Out.ar(out,In.ar(in,2));
		}).send(context.server);

		SynthDef("preamp", {
			arg in,out;
			var snd=SoundIn.ar([0,1]);

			snd=snd*\preamp.kr(1).dbamp;

			snd = snd * EnvGen.ar(Env.adsr(1,1,1,1),\mainenv.kr(1),doneAction:2);
			Out.ar(out,snd);
		}).send(context.server);

		SynthDef("filters", {
			arg in,out,tascam=0;
			var tascam_snd;
			var snd=In.ar(in,2);

			snd=RHPF.ar(snd,\hpf.kr(10),\hpfqr.kr(1));

			snd=RLPF.ar(snd,\lpf.kr(20000),\lpfqr.kr(1));

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

			snd = snd * EnvGen.ar(Env.adsr(1,1,1,1),\mainenv.kr(1),doneAction:2);
			Out.ar(out,snd);
		}).send(context.server);


		SynthDef("color", {
			arg in,out,bufSine,bufCompress,bufExpand;
			var snd=In.ar(in,2);

			// sine drive
			snd=SelectX.ar(Lag.kr(\sine_drive_wet.kr(0)),[snd,Shaper.ar(bufSine,snd*\sine_drive.kr(1))]);
			
            // compress curve
            snd=SelectX.ar(Lag.kr(\compress_curve_wet.kr(0)),[snd,Shaper.ar(bufCompress,snd*\compress_curve_drive.kr(1))]);

            // expand curve
            snd=SelectX.ar(Lag.kr(\expand_curve_wet.kr(0)),[snd,Shaper.ar(bufExpand,snd*\expand_curve_drive.kr(1))]);

			snd = snd * EnvGen.ar(Env.adsr(1,1,1,1),\mainenv.kr(1),doneAction:2);
			Out.ar(out,snd);
		}).send(context.server);

		SynthDef("tape",{
			arg in,out;
			var snd=In.ar(in,2);

			snd=SelectX.ar(Lag.kr(\tape_wet.kr(0),1),[snd,AnalogTape.ar(snd,\tape_bias.kr(0),\saturation.kr(0),\drive.kr(0),oversample,0)]);

			snd = snd * EnvGen.ar(Env.adsr(1,1,1,1),\mainenv.kr(1),doneAction:2);
			Out.ar(out,snd);
		}).send(context.server);
		
		SynthDef("distortion",{
			arg in,out;
			var snd=In.ar(in,2);

			snd=SelectX.ar(Lag.kr(\dist_wet.kr(0)/5,1),[snd,AnalogVintageDistortion.ar(snd,
				\drivegain.kr(0),\dist_bias.kr(0),\lowgain.kr(0),\highgain.kr(0),\shelvingfreq.kr(0),oversample-1)]);			

			snd = snd * EnvGen.ar(Env.adsr(1,1,1,1),\mainenv.kr(1),doneAction:2);
			Out.ar(out,snd);
		}).send(context.server);

		SynthDef("wobble",{
			arg in,out,buf,
			wowflu=1.0,
			wobble_rpm=33, wobble_amp=0.05, flutter_amp=0.03, flutter_fixedfreq=6, flutter_variationfreq=2;
			
			var snd=In.ar(in,2);
			// wow and flutter from Stefaan Himpe https://sccode.org/1-5bP
			var pw,pr,sndr,rate,switch_wobble;
			var wow = wobble_amp*SinOsc.kr(wobble_rpm/60,mul:0.1);
			var flutter = flutter_amp*SinOsc.kr(flutter_fixedfreq+LFNoise2.kr(flutter_variationfreq),mul:0.02);
			rate= 1 + (wowflu * (wow+flutter));		
			// write to tape and read from
			pw=Phasor.ar(0, BufRateScale.ir(buf), 0, BufFrames.ir(buf));
			pr=DelayL.ar(Phasor.ar(0, BufRateScale.ir(buf)*rate, 0, BufFrames.ir(buf)),0.2,0.2);
			BufWr.ar(snd,buf,pw);
			sndr=BufRd.ar(2,buf,pr,interpolation:4);
			switch_wobble=Lag.kr(wowflu>0,1);
			snd=SelectX.ar(\wet.kr(0),[snd,sndr]);

			snd = snd * EnvGen.ar(Env.adsr(1,1,1,1),\mainenv.kr(1),doneAction:2);
			Out.ar(out,snd);
		}).send(context.server);

		SynthDef("chew", {
			arg in,out;
			var snd;

			snd = SelectX.ar(\wet.kr(0),[
				snd,
				AnalogChew.ar(snd,\depth.kr(0.5),\freq.kr(0.5),\variance.kr(0.5)),
			]);

			snd = snd * EnvGen.ar(Env.adsr(1,1,1,1),\mainenv.kr(1),doneAction:2);
			Out.ar(out,snd);
		}).send(context.server);

		SynthDef("loss", {
			arg in,out;
			var snd;

			snd = SelectX.ar(\wet.kr(0),[
				snd,
				AnalogLoss.ar(snd,\gap.kr(0.5),\thick.kr(0.5),\space.kr(0.5),\speed.kr(1))
			]);

			snd = snd * EnvGen.ar(Env.adsr(1,1,1,1),\mainenv.kr(1),doneAction:2);
			Out.ar(out,snd);
		}).send(context.server);

		SynthDef("degrade", {
			arg in,out;
			var snd;

			snd = SelectX.ar(\wet.kr(0),[
				snd,
				AnalogDegrade.ar(snd,\depth.kr(0.5),\amount.kr(0.5),\variance.kr(0.5),\envelope.kr(0.5))
			]);

			snd = snd * EnvGen.ar(Env.adsr(1,1,1,1),\mainenv.kr(1),doneAction:2);
			Out.ar(out,snd);
		}).send(context.server);

		SynthDef("final", {
			arg in,out;
			
            // reduce stereo spread in the bass
            snd = BHiPass.ar(snd,200)+Pan2.ar(BLowPass.ar(snd[0]+snd[1],200));
            
            snd = snd.tanh; // limit

			snd = snd * EnvGen.ar(Env.adsr(1,1,1,1),\mainenv.kr(1),doneAction:2);
			Out.ar(0,snd*\amp.kr(1));
		}).send(context.server);


		// setup the buses 
		context.server.sync;
		stages.do({arg i;
			params.put(i,Dictionary.new());
			bus.put(i,Bus.audio(context.server,2));
		});
		context.server.sync;

		syns.put(0,Synth.head(context.server,\in_gain,[\out,bus.at(0)]));
		context.server.sync;
		(stages-2).do({arg i;
			syns.put(i+1,Synth.after(syns.at(i+1),\passthrough,[\in,bus.at(i),\out,bus.at(i+1)]));
			context.server.sync;
		});
		syns.put(stages-1,Synth.after(syns.at(stages-2),\final,[\in,bus.at(stages-2),\out,0]));
		context.server.sync;


		synTape=Synth.new(\main,[\bufExpand,bufs.at("expand"),\bufCompress,bufs.at("compress"),\buf,buf,\sine_buf,bufSine]);
		
		this.addCommand("toggle","ii",{ arg msg;
			var stage=msg[1];
			var on=msg[2]>0;
			if (stage>0,{
				var synthName="passthrough";
				var args=[\in,bus.at(stage-1),\out,bus.at(stage)];
				if (on,{
					synthName=stageNames[stage];
					params.at(stage).keysValuesDo({
						arg key,val;
						args=args.addAll(key.asSymbol,val);
					});
					switch(synthName.asString,
						"wobble",{ args=args.addAll(\buf,\bufs.at("wobble")); }
						// TODO add all the others here too
					);
				});
				syns.at(stage).set(\mainenv,0);
				syns.put(stage,Synth.after(syns.at(stage-1),synthName,args));
			});
		});	

		this.addCommand("set","isf",{ arg msg;
			var stage=msg[1];
			var param=msg[2];
			var value=msg[3];
			if (params.at(stage).isNil,{
				params.put(stage,Dictionary.new());
			});
			params.at(stage).put(param,value);
			syns.at(stage).set(param,value);
		});
	}
	
	free {
        bufs.keysValuesDo({ arg key, val;
            val.free;
        });
        syns.keysValuesDo({ arg key, val;
            val.free;
        });
        bus.keysValuesDo({ arg key, val;
            val.free;
        });
	}
	
}
