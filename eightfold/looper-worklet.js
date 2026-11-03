// Eightfold looper, running on the audio thread so every loop lands on the exact sample.
//
// The mic is always listening. A sound past the trigger records a clip one loop long (plus a few
// milliseconds from just before, so the start isn't cut). Every clip becomes a loop of its own, and
// loops layer on top of each other.
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
    this.voices = [];   // loops: { id, clip, L, written, firstCycle, endCycle, lastPlayed, lastMid, peaksSent }
    this.plays = [];    // what is sounding: { v, pos, mid }
    this.rec = null;    // the loop being recorded
    this.grid = null;   // { cycle, cycleStart, Lc, next, half }
    this.nextId = 1;
    this.lastClickFrame = -Infinity;
    this.clickPos = -1;
    // The tick: a 4 ms burst of 2.2 kHz that dies away quickly.
    this.click = new Float32Array(Math.round(0.004 * sr));
    for (let n = 0; n < this.click.length; n++) this.click[n] = Math.sin(2 * Math.PI * 2200 * n / sr) * Math.exp(-n / (0.0008 * sr));
    this.port.onmessage = e => this.onMessage(e.data);
  }

  onMessage(m) {
    if (m.type === 'params') Object.assign(this.params, m.params);
    else if (m.type === 'arm') { this.armed = true; this.env = 0; }
    else if (m.type === 'disarm') { this.armed = false; this.clear(); }
    else if (m.type === 'clear') this.clear();
  }

  clear() {
    this.voices = []; this.plays = []; this.rec = null; this.grid = null;
    this.port.postMessage({ type: 'cleared' });
  }

  alive() { return this.voices.length > 0 || this.plays.length > 0 || this.rec !== null; }

  startRec(t) {
    const sr = this.sr, p = this.params;
    const L = Math.max(1, Math.round(p.loopSec * sr));
    const D = Math.max(1, Math.round(p.delaySec * sr));
    const N = Math.max(1, Math.round(p.repeats));
    const pre = Math.min(Math.round(0.01 * sr), Math.floor(L / 4), this.ring.length);
    const clip = new Float32Array(L);
    for (let k = 0; k < pre; k++) clip[k] = this.ring[(this.rpos - pre + k + this.ring.length) % this.ring.length];
    const v = { id: this.nextId++, clip, L, written: pre, lastPlayed: -Infinity, lastMid: -Infinity, peaksSent: false, plays: 0 };
    const earliest = t + D;
    if (!this.grid || !this.alive()) {
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
      const a = Math.floor(i * v.L / n), b = Math.max(a + 1, Math.floor((i + 1) * v.L / n));
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

  onGrid(t) {
    const g = this.grid, p = this.params;
    const cap = Math.max(1, Math.round(p.voices));
    if (!g.half) {
      // Start of a cycle.
      g.cycle++;
      g.cycleStart = t;
      g.Lc = Math.max(1, Math.round(p.loopSec * this.sr)); // a new loop length takes effect from here
      this.voices = this.voices.filter(v => v.endCycle >= g.cycle || v === this.rec);
      if (!this.alive()) { this.grid = null; this.port.postMessage({ type: 'quiet', frame: t }); return; }
      const due = this.voices.filter(v => v.firstCycle <= g.cycle && g.cycle <= v.endCycle);
      for (const v of this.pick(due, cap - this.plays.length, 'lastPlayed')) {
        this.plays.push({ v, pos: 0, mid: false });
        v.lastPlayed = g.cycle;
        v.plays++;
        this.port.postMessage({ type: 'play', id: v.id, frame: t, mid: false, cycle: g.cycle });
      }
      // The tick, never closer than 0.2 s apart so tiny loops don't buzz.
      if (t - this.lastClickFrame >= 0.2 * this.sr) { this.clickPos = 0; this.lastClickFrame = t; }
      const fill = Math.round(p.voices) > Math.round(p.repeats);
      if (fill) { g.next = t + Math.max(1, Math.floor(g.Lc / 2)); g.half = true; }
      else g.next = t + g.Lc;
    } else {
      // Midpoint of a cycle: with room to spare, some loops play again from here.
      const due = this.voices.filter(v => v.firstCycle <= g.cycle && g.cycle <= v.endCycle && v.written > 0
        && !this.plays.some(pl => pl.v === v && pl.mid));
      // At most the surplus (loops at once minus times to loop), and never past the cap.
      const surplus = cap - Math.max(1, Math.round(p.repeats));
      for (const v of this.pick(due, Math.min(cap - this.plays.length, surplus), 'lastMid')) {
        this.plays.push({ v, pos: 0, mid: true });
        v.lastMid = g.cycle;
        this.port.postMessage({ type: 'play', id: v.id, frame: t, mid: true, cycle: g.cycle });
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

      // Recording: one loop at a time; the next can start as soon as this one is full.
      if (this.armed) {
        if (this.rec) {
          this.rec.clip[this.rec.written++] = x;
          if (this.rec.written >= this.rec.L) this.finishRec();
        } else if (this.env > this.params.threshold) {
          this.startRec(t);
        }
      }

      if (this.grid && t >= this.grid.next) this.onGrid(t);

      // Mix everything that is sounding. Short fades at both ends of each pass so the joins don't pop.
      let y = 0;
      for (let k = this.plays.length - 1; k >= 0; k--) {
        const pl = this.plays[k], v = pl.v, pos = pl.pos, L = v.L;
        const f = Math.max(1, Math.min(Math.round(0.003 * this.sr), Math.floor(L / 8)));
        const gfade = pos < f ? 0.5 - 0.5 * Math.cos(Math.PI * pos / f) : pos >= L - f ? 0.5 - 0.5 * Math.cos(Math.PI * (L - pos) / f) : 1;
        y += (pos < v.written ? v.clip[pos] : 0) * gfade;
        if (++pl.pos >= L) this.plays.splice(k, 1);
      }
      y *= 0.8;
      if (this.clickPos >= 0) {
        y += this.click[this.clickPos] * this.params.clickGain * 0.25;
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
        type: 'tick', env: this.env, frame: this.frame,
        recording: this.rec ? { id: this.rec.id, frac: this.rec.written / this.rec.L } : null,
        cycle: g ? g.cycle : null, phase: g && g.cycle >= 0 ? Math.min(1, (this.frame - g.cycleStart) / g.Lc) : 0,
        playing: this.plays.length,
        voices: this.voices.map(v => ({
          id: v.id,
          left: g ? Math.max(0, v.endCycle - Math.max(g.cycle, v.firstCycle) + 1) : 0, // cycles left, this one included
          waiting: !g || g.cycle < v.firstCycle,
          heads: this.plays.filter(pl => pl.v === v).map(pl => pl.pos / v.L),
        })),
      });
    }
    return true;
  }
}

registerProcessor('eightfold-looper', Looper);
