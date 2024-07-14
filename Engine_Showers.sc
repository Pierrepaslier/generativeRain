Engine_Showers : CroneEngine {
  var <synth;
  var oscPort = 10111;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    SynthDef(\Showers, {
      arg out, rain = 0.7, thunder = 0.7;
      var noise1, noise2, verb1, verb2, sig;
      var thunderEnv, thunderDetect, highFreqContent;

      // Rain sound (unchanged)
      noise1 = PinkNoise.ar(0.08 + LFNoise1.kr(0.3, 0.02)) + LPF.ar(Dust2.ar(LFNoise1.kr(0.2).range(40, 50)), 7000);
      noise1 = HPF.ar(noise1, 400);
      verb1 = tanh(3 * GVerb.ar(noise1, 250, 100, 0.25, drylevel: 0.3)) * rain * Line.kr(0, rain, 10);

      // Thunder sound (modified)
      noise2 = PinkNoise.ar(LFNoise1.kr(3).clip(0, 1) * LFNoise1.kr(2).clip(0, 1) ** 1.8);
      noise2 = LPF.ar(10 * HPF.ar(noise2, 20), LFNoise1.kr(1).exprange(100, 2500)).tanh;
      
      // Create an envelope for thunder
      thunderEnv = EnvGen.kr(Env.perc(0.05, 5, 1, -4), gate: Impulse.kr(0.2) * (thunder > 0.2));
      verb2 = GVerb.ar(noise2, 270, 30, 0.7, drylevel: 0.5) * thunder * thunderEnv;
      
      // Detect high frequency content
      highFreqContent = HPF.ar(verb2, 1000);
      highFreqContent = (Amplitude.kr(highFreqContent) > 0.05) * (thunder > 0.2);

      // Detect when thunder is audible with significant high frequency content
      thunderDetect = (thunder > 0.2) * (thunderEnv > 0.5) * highFreqContent;
      SendTrig.kr(Changed.kr(thunderDetect), 0, thunder);

      sig = Mix.new([verb1, verb2]);
      sig = Limiter.ar(sig);

      Out.ar(out, sig);
    }).add;

    context.server.sync;

    synth = Synth.new(\Showers, [
      \out, context.out_b.index],
      context.xg);

    this.addCommand("rain", "f", {|msg|
      synth.set(\rain, msg[1]);
    });

    this.addCommand("thunder", "f", {|msg|
      synth.set(\thunder, msg[1]);
    });

    // Add OSCFunc to listen for the trigger
    OSCFunc({ |msg|
      var thunderValue = msg[3];
      if (thunderValue > 0.2) {
        NetAddr("localhost", oscPort).sendMsg("/thunder", thunderValue);
        ("Thunder detected, value: " ++ thunderValue).postln;
      }
    }, '/tr', context.server.addr);
  }

  free {
    synth.free;
  }
}