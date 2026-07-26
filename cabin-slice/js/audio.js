/** Synthwave / Hotline-ish procedural audio (Web Audio) */
(function (global) {
  let ctx = null;
  let muted = false;
  let bgmNodes = null;
  let bgmTimer = null;
  let bgmWanted = false;

  function ensureCtx() {
    if (!ctx) ctx = new (global.AudioContext || global.webkitAudioContext)();
    if (ctx.state === "suspended") ctx.resume();
    return ctx;
  }

  function setMuted(v) {
    muted = !!v;
    if (muted) stopBgm();
    else if (bgmWanted) startBgm();
  }

  function isMuted() {
    return muted;
  }

  function playTone(kind) {
    if (muted) return;
    try {
      const ac = ensureCtx();
      const o = ac.createOscillator();
      const g = ac.createGain();
      const f = ac.createBiquadFilter();
      o.connect(f);
      f.connect(g);
      g.connect(ac.destination);
      const now = ac.currentTime;
      const table = {
        ok: [660, "triangle", 0.18, 900],
        bad: [140, "sawtooth", 0.28, 400],
        dice: [880, "square", 0.1, 1200],
        ui: [520, "sine", 0.12, 2000],
        face: [220, "sawtooth", 0.35, 600],
      };
      const [freq, type, dur, filt] = table[kind] || table.ui;
      o.type = type;
      o.frequency.setValueAtTime(freq, now);
      if (kind === "bad" || kind === "face") {
        o.frequency.exponentialRampToValueAtTime(freq * 0.55, now + dur);
      }
      f.type = "lowpass";
      f.frequency.value = filt;
      g.gain.setValueAtTime(0.0001, now);
      g.gain.exponentialRampToValueAtTime(0.06, now + 0.02);
      g.gain.exponentialRampToValueAtTime(0.0001, now + dur);
      o.start(now);
      o.stop(now + dur + 0.05);
    } catch {
      /* ignore */
    }
  }

  function midi(n) {
    return 440 * 2 ** ((n - 69) / 12);
  }

  function startBgm() {
    bgmWanted = true;
    if (muted) return;
    stopBgm(false);
    try {
      const ac = ensureCtx();
      const master = ac.createGain();
      master.gain.value = 0.032;
      master.connect(ac.destination);

      const pad = ac.createOscillator();
      const pad2 = ac.createOscillator();
      const padG = ac.createGain();
      const padF = ac.createBiquadFilter();
      pad.type = "triangle";
      pad2.type = "sine";
      pad.frequency.value = midi(48);
      pad2.frequency.value = midi(55);
      padF.type = "lowpass";
      padF.frequency.value = 900;
      padG.gain.value = 0.28;
      pad.connect(padF);
      pad2.connect(padF);
      padF.connect(padG);
      padG.connect(master);

      const bass = ac.createOscillator();
      const bassG = ac.createGain();
      bass.type = "triangle";
      bass.frequency.value = midi(36);
      bassG.gain.value = 0.0001;
      bass.connect(bassG);
      bassG.connect(master);

      const lead = ac.createOscillator();
      const leadG = ac.createGain();
      const leadF = ac.createBiquadFilter();
      lead.type = "triangle";
      leadF.type = "lowpass";
      leadF.frequency.value = 1800;
      leadG.gain.value = 0.0001;
      lead.connect(leadF);
      leadF.connect(leadG);
      leadG.connect(master);

      pad.start();
      pad2.start();
      bass.start();
      lead.start();

      const chord = [45, 48, 52, 55];
      const bassLine = [33, 33, 36, 40, 33, 31, 36, 38];
      const leadLine = [69, 67, 64, 60, 64, 67, 69, 72, 67, 64, 60, 57];
      let step = 0;
      const bpm = 108;
      const stepMs = ((60 / bpm) * 1000) / 2;

      bgmTimer = setInterval(() => {
        if (muted || !ctx) return;
        const t = ctx.currentTime;
        const b = bassLine[step % bassLine.length];
        bass.frequency.setValueAtTime(midi(b), t);
        bassG.gain.cancelScheduledValues(t);
        bassG.gain.setValueAtTime(0.0001, t);
        bassG.gain.exponentialRampToValueAtTime(0.22, t + 0.02);
        bassG.gain.exponentialRampToValueAtTime(0.0001, t + 0.22);

        if (step % 2 === 0) {
          const n = leadLine[(step / 2) % leadLine.length];
          lead.frequency.setValueAtTime(midi(n), t);
          leadG.gain.cancelScheduledValues(t);
          leadG.gain.setValueAtTime(0.0001, t);
          leadG.gain.exponentialRampToValueAtTime(0.12, t + 0.03);
          leadG.gain.exponentialRampToValueAtTime(0.0001, t + 0.35);
        }

        if (step % 16 === 0) {
          const root = chord[0] + (step % 32 === 0 ? 0 : -2);
          pad.frequency.setTargetAtTime(midi(root), t, 0.2);
          pad2.frequency.setTargetAtTime(midi(root) * 1.005, t, 0.2);
        }
        step += 1;
      }, stepMs);

      bgmNodes = { pad, pad2, bass, lead, master, padG, bassG, leadG };
    } catch {
      bgmNodes = null;
    }
  }

  function stopBgm(clearWanted = true) {
    if (clearWanted) bgmWanted = false;
    if (bgmTimer) {
      clearInterval(bgmTimer);
      bgmTimer = null;
    }
    if (bgmNodes) {
      try {
        const { pad, pad2, bass, lead } = bgmNodes;
        [pad, pad2, bass, lead].forEach((o) => {
          try {
            o.stop();
          } catch {
            /* */
          }
        });
      } catch {
        /* */
      }
      bgmNodes = null;
    }
  }

  global.CabinAudio = { setMuted, isMuted, playTone, startBgm, stopBgm };
})(window);
