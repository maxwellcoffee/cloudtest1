// Eightfold looper, running on the audio thread so every loop lands on the exact sample.
//
// The mic is always listening. A sound past the trigger records a clip one loop long, plus 10 ms from
// just before it (the lead-in). Every clip becomes a loop of its own, and loops layer on top of each
// other. If you're still sounding when a clip fills, the next clip starts on the very next sample, so a
// long phrase becomes a chain of loops exactly one loop length apart.
//
// Each pass starts the lead-in early and fades in across it, so the moment the sound began lands exactly
// on the cycle start, and it fades out across its last 10 ms. Back-to-back clips from a chain overlap by
// that 10 ms of the same sound, so the fades add up to a seamless join.
//
// All loops share one cycle: a beat one loop length long, with a quiet tick at its start. The first loop
// after a quiet spell starts the delay after the sound began, and that sets where the cycles fall; later
// loops start at the first cycle that begins at least the delay after their sound, so they stay in time.
// Each loop stays for "times to loop" cycles.
//
// "Loops at once" caps how many play at the same moment. When more loops are waiting than that, they
// take turns (whichever played least recently goes first), so some play every second or third cycle.
// When the cap is higher than "times to loop", spare room is filled by playing some loops again from
// the midpoint of the cycle, also in turn.
//
// Sync: plays clicks and records what the mic hears. Just after each counted click it sends the page the
// sound from a third of a beat before the click to 0.6 of a beat after, and the page finds where each tap
// peaks (speaker and mic delays plus your own timing) to set the delay.

class Looper extends AudioWorkletProcessor {
  constructor(options) {
    super();
    const sr = sampleRate;
    this.sr = sr;
    this.params = { loopSec: 1, delaySec: 0.25, repeats: 8, voices: 8, threshold: 0.03, clickGain: 0.35, ...(options.processorOptions?.params || {}) };
    this.armed = !!options.processorOptions?.armed;
    this.ring = new Float32Array(Math.ceil(sr * 0.05)); // the last 50 ms, for the bit before the trigger
    this.rpos = 0;
    this.env = 0;
    this.attack = 1 - Math.exp(-1 / (0.002 * sr));
    this.release = Math.exp(-1 / (0.08 * sr));
    this.frame = 0;
    this.lastPost = 0;
    this.voices = [];   // loops: { id, clip (pre + L long), L, pre, written, firstCycle, endCycle, lastPlayed, lastMid }
    this.plays = [];    // what is sounding: { v, pos, wait (samples before it starts), end (frame it finishes), mid }
    this.rec = null;    // the loop being recorded
    this.grid = null;   // { cycle, cycleStart, Lc, next, half }
    this.nextId = 1;
    this.lead = Math.round(0.01 * sr); // cycle events are handled this early, so passes can start their lead-in
    this.lastClickFrame = -Infinity;
    this.clickPos = -1;
    this.clickAt = -1;                 // frame the next cycle tick sounds
    // The tick: a 4 ms burst of 2.2 kHz that dies away quickly.
    this.click = new Float32Array(Math.round(0.004 * sr));
    for (let n = 0; n < this.click.length; n++) this.click[n] = Math.sin(2 * Math.PI * 2200 * n / sr) * Math.exp(-n / (0.0008 * sr));
    this.port.onmessage = e => this.onMessage(e.data);
    this.sync = null;
    if (options.processorOptions?.sync) this.startSync(options.processorOptions.sync);
  }

  onMessage(m) {
    if (m.type === 'params') Object.assign(this.params, m.params);
    else if (m.type === 'arm') { this.armed = true; this.env = 0; }
    else if (m.type === 'disarm') { this.armed = false; this.clear(); }
    else if (m.type === 'clear') this.clear();
    else if (m.type === 'sync') this.startSync(m);
    else if (m.type === 'extend') this.extend(m.id, m.factor);
    else if (m.type === 'syncCancel') { this.sync = null; this.port.postMessage({ type: 'syncCancelled' }); }
  }

  // Double or halve how many cycles one loop stays for. Halving never cuts the cycle it is playing.
  extend(id, factor) {
    const v = this.voices.find(x => x.id === id);
    if (!v) return;
    const total = v.endCycle - v.firstCycle + 1;
    const next = factor > 1 ? Math.min(1024, total * 2) : Math.max(1, Math.floor(total / 2));
    v.endCycle = v.firstCycle + next - 1;
    const now = this.grid ? this.grid.cycle : -1;
    if (v.endCycle < now) v.endCycle = now;
  }

  startSync(m) {
    this.clear();
    const sr = this.sr, I = Math.max(1, Math.round(m.interval * sr)), total = m.countIn + m.taps;
    const lead = Math.round(0.6 * sr), before = Math.round(0.35 * I), after = Math.round(0.6 * I);
    this.sync = {
      I, t0: this.frame, next: this.frame + lead, n: 0, countIn: m.countIn, total, before, after, last: -1,
      buf: new Float32Array(lead + (total - 1) * I + after + 2), // everything the mic hears while syncing
      windows: [],                                                // counted clicks whose sound isn't sent yet
    };
  }

  // Every sample while syncing: keep what the mic hears, play the clicks, send each counted click's sound
  // once its window has gone by, and finish after the last one.
  stepSync(t, x) {
    const s = this.sync, i = t - s.t0;
    if (i >= 0 && i < s.buf.length) s.buf[i] = x;
    if (s.n < s.total && t >= s.next) {
      this.clickPos = 0;
      this.port.postMessage({ type: 'syncClick', n: s.n, frame: t, countIn: s.n < s.countIn });
      if (s.n >= s.countIn) s.windows.push({ k: s.n - s.countIn, c: t });
      s.last = t;
      s.n++;
      s.next = t + s.I;
    }
    if (s.windows.length && t >= s.windows[0].c + s.after - 1) {
      const w = s.windows.shift(), a = w.c - s.before - s.t0;
      const wave = s.buf.slice(a, a + s.before + s.after);
      this.port.postMessage({ type: 'syncWave', k: w.k, wave, click: s.before, sampleRate: this.sr }, [wave.buffer]);
    }
    if (s.n >= s.total && !s.windows.length && t >= s.last + s.after - 1) {
      this.sync = null;
      this.env = 0;
      this.port.postMessage({ type: 'syncDone' });
    }
  }

  clear() {
    this.voices = []; this.plays = []; this.rec = null; this.grid = null; this.clickAt = -1;
    this.port.postMessage({ type: 'cleared' });
  }

  // Anything still going after frame T: loops, the recording, or a pass that hasn't finished.
  alive(T) { return this.voices.length > 0 || this.rec !== null || this.plays.some(pl => pl.end > T); }

  startRec(t) {
    const sr = this.sr, p = this.params;
    const L = Math.max(1, Math.round(p.loopSec * sr));
    const D = Math.max(1, Math.round(p.delaySec * sr));
    const N = Math.max(1, Math.round(p.repeats));
    const pre = Math.max(1, Math.min(this.lead, Math.floor(L / 4), this.ring.length - 1));
    const clip = new Float32Array(pre + L);
    // The lead-in: the samples just before this one (the ring already holds this one, at rpos - 1).
    const R = this.ring.length;
    for (let k = 0; k < pre; k++) clip[k] = this.ring[(this.rpos - 1 - pre + k + 2 * R) % R];
    const v = { id: this.nextId++, clip, L, pre, written: pre, lastPlayed: -Infinity, lastMid: -Infinity, plays: 0 };
    const earliest = t + D;
    if (!this.grid || !this.alive(t)) {
      // After a quiet spell this loop sets the cycles: the first one starts exactly the delay after the sound.
      this.grid = { cycle: -1, cycleStart: earliest - L, Lc: L, next: earliest, half: false };
      v.firstCycle = 0;
    } else {
      // Otherwise the first cycle that starts at least the delay after the sound.
      const g = this.grid, nextStart = g.cycleStart + g.Lc;
      v.firstCycle = g.cycle + 1 + Math.max(0, Math.ceil((earliest - nextStart) / g.Lc));
    }
    v.endCycle = v.firstCycle + N - 1;
    this.voices.push(v);
    this.rec = v;
    this.port.postMessage({ type: 'onset', id: v.id, frame: t, firstCycle: v.firstCycle });
  }

  finishRec() {
    const v = this.rec;
    this.rec = null;
    // A small picture of the clip for the display: peak level in 200 slices.
    const n = 200, peaks = new Float32Array(n);
    for (let i = 0; i < n; i++) {
      const a = v.pre + Math.floor(i * v.L / n), b = Math.max(a + 1, v.pre + Math.floor((i + 1) * v.L / n));
      let m = 0;
      for (let k = a; k < b; k++) m = Math.max(m, Math.abs(v.clip[k]));
      peaks[i] = m;
    }
    this.port.postMessage({ type: 'clip', id: v.id, peaks }, [peaks.buffer]);
  }

  // Fairness: whoever played least recently goes first; on a tie, the older loop.
  pick(candidates, room, key) {
    candidates.sort((a, b) => (a[key] - b[key]) || (a.id - b.id));
    return candidates.slice(0, Math.max(0, room));
  }

  // A pass of loop v whose sound begins at frame T: it starts the lead-in early (now, or a little later).
  startPass(v, t, T, mid) {
    const s0 = T - v.pre - t;
    this.plays.push({ v, pos: s0 < 0 ? -s0 : 0, wait: Math.max(0, s0), end: T + v.L, mid });
  }

  // Handled `lead` samples before the event at T = g.next, so passes can start their lead-in in time.
  onGrid(t) {
    const g = this.grid, p = this.params, T = g.next;
    const cap = Math.max(1, Math.round(p.voices));
    const sounding = () => this.plays.filter(pl => pl.end > T).length; // passes that carry on past T
    if (!g.half) {
      // Start of a cycle.
      g.cycle++;
      g.cycleStart = T;
      g.Lc = Math.max(1, Math.round(p.loopSec * this.sr)); // a new loop length takes effect from here
      this.voices = this.voices.filter(v => v.endCycle >= g.cycle || v === this.rec);
      if (!this.alive(T)) { this.grid = null; this.port.postMessage({ type: 'quiet', frame: T }); return; }
      const due = this.voices.filter(v => v.firstCycle <= g.cycle && g.cycle <= v.endCycle);
      for (const v of this.pick(due, cap - sounding(), 'lastPlayed')) {
        this.startPass(v, t, T, false);
        v.lastPlayed = g.cycle;
        v.plays++;
        this.port.postMessage({ type: 'play', id: v.id, frame: T, mid: false, cycle: g.cycle });
      }
      // The tick, never closer than 0.2 s apart so tiny loops don't buzz.
      if (T - this.lastClickFrame >= 0.2 * this.sr) { this.clickAt = T; this.lastClickFrame = T; }
      const fill = Math.round(p.voices) > Math.round(p.repeats);
      if (fill) { g.next = T + Math.max(1, Math.floor(g.Lc / 2)); g.half = true; }
      else g.next = T + g.Lc;
    } else {
      // Midpoint of a cycle: with room to spare, some loops play again from here.
      const due = this.voices.filter(v => v.firstCycle <= g.cycle && g.cycle <= v.endCycle && v.written > v.pre
        && !this.plays.some(pl => pl.v === v && pl.mid && pl.end > T));
      // At most the surplus (loops at once minus times to loop), and never past the cap.
      const surplus = cap - Math.max(1, Math.round(p.repeats));
      for (const v of this.pick(due, Math.min(cap - sounding(), surplus), 'lastMid')) {
        this.startPass(v, t, T, true);
        v.lastMid = g.cycle;
        this.port.postMessage({ type: 'play', id: v.id, frame: T, mid: true, cycle: g.cycle });
      }
      g.next = g.cycleStart + g.Lc;
      g.half = false;
    }
  }

  process(inputs, outputs) {
    const input = inputs[0], out = outputs[0];
    const a = input && input[0], b = input && input[1];
    const n = out[0].length;
    for (let i = 0; i < n; i++) {
      const t = this.frame + i;
      const x = a ? (b ? (a[i] + b[i]) * 0.5 : a[i]) : 0;
      const ax = Math.abs(x);
      this.env = ax > this.env ? this.env + (ax - this.env) * this.attack : this.env * this.release;
      this.ring[this.rpos] = x;
      this.rpos = (this.rpos + 1) % this.ring.length;

      if (this.sync) this.stepSync(t, x);
      // Recording: one loop at a time; the next can start on the sample after this one is full.
      if (this.armed && !this.sync) {
        if (!this.rec && this.env > this.params.threshold) this.startRec(t);
        if (this.rec) {
          this.rec.clip[this.rec.written++] = x; // this sample is the clip's first beat when it just started
          if (this.rec.written >= this.rec.clip.length) this.finishRec();
        }
      }

      while (this.grid && t >= this.grid.next - this.lead) this.onGrid(t);

      // Mix everything that is sounding. Each pass fades in over its lead-in and out over its last
      // lead-in's worth, so the joins don't pop and a chain of clips joins up seamlessly.
      let y = 0;
      for (let k = this.plays.length - 1; k >= 0; k--) {
        const pl = this.plays[k];
        if (pl.wait > 0) { pl.wait--; continue; }
        const v = pl.v, pos = pl.pos, n = v.clip.length, f = v.pre;
        const gfade = pos < f ? 0.5 - 0.5 * Math.cos(Math.PI * (pos + 0.5) / f)
          : pos >= n - f ? 0.5 - 0.5 * Math.cos(Math.PI * (n - pos - 0.5) / f) : 1;
        y += (pos < v.written ? v.clip[pos] : 0) * gfade;
        if (++pl.pos >= n) this.plays.splice(k, 1);
      }
      y *= 0.8;
      if (t === this.clickAt) { this.clickPos = 0; this.clickAt = -1; }
      if (this.clickPos >= 0) {
        y += this.click[this.clickPos] * (this.sync ? Math.max(this.params.clickGain, 0.6) : this.params.clickGain) * 0.25;
        if (++this.clickPos >= this.click.length) this.clickPos = -1;
      }
      // Soft ceiling, so many layers together round off instead of clipping.
      const ay = Math.abs(y);
      if (ay > 0.8) y = Math.sign(y) * (0.8 + 0.2 * Math.tanh((ay - 0.8) / 0.2));
      for (let c = 0; c < out.length; c++) out[c][i] = y;
    }
    this.frame += n;

    // About 30 updates a second for the display.
    if (this.frame - this.lastPost > this.sr / 30) {
      this.lastPost = this.frame;
      const g = this.grid;
      this.port.postMessage({
        type: 'tick', env: this.env, frame: this.frame, syncing: !!this.sync,
        recording: this.rec ? { id: this.rec.id, frac: (this.rec.written - this.rec.pre) / this.rec.L } : null,
        cycle: g ? g.cycle : null, phase: g && g.cycle >= 0 ? Math.min(1, Math.max(0, (this.frame - g.cycleStart) / g.Lc)) : 0,
        playing: this.plays.length,
        voices: this.voices.map(v => ({
          id: v.id, firstCycle: v.firstCycle, total: v.endCycle - v.firstCycle + 1,
          left: g ? Math.max(0, v.endCycle - Math.max(g.cycle, v.firstCycle) + 1) : 0, // cycles left, this one included
          waiting: !g || g.cycle < v.firstCycle,
          heads: this.plays.filter(pl => pl.v === v && pl.wait === 0).map(pl => Math.min(1, Math.max(0, (pl.pos - v.pre) / v.L))),
        })),
      });
    }
    return true;
  }
}

registerProcessor('eightfold-looper', Looper);
