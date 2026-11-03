// Eightfold looper, running on the audio thread so every loop lands on the exact sample.
//
// listening: watch the mic level. When it rises past the trigger, start recording a clip of the
//            loop length (plus a few milliseconds from just before, so the start of the sound isn't cut).
// active:    keep recording until the clip is full; after the delay (counted from when the sound
//            started) play the clip back to back the chosen number of times, with a quiet tick at the
//            start of each loop. The first pass can start while the clip is still recording: it reads
//            behind the recording by the delay, so it never runs ahead of it.
// cooldown:  a short pause after the last loop, then listen again. The mic is ignored while looping,
//            so the playback can't set itself off through the speakers.

class Looper extends AudioWorkletProcessor {
  constructor(options) {
    super();
    const sr = sampleRate;
    this.sr = sr;
    this.params = { loopSec: 1, delaySec: 0.25, repeats: 8, threshold: 0.03, clickGain: 0.35, ...(options.processorOptions?.params || {}) };
    this.ring = new Float32Array(Math.ceil(sr * 0.05)); // the last 50 ms, for the bit before the trigger
    this.rpos = 0;
    this.clip = new Float32Array(Math.ceil(sr * 10.05) + 16);
    this.state = options.processorOptions?.armed ? 'listening' : 'idle';
    this.env = 0;
    this.attack = 1 - Math.exp(-1 / (0.002 * sr));
    this.release = Math.exp(-1 / (0.08 * sr));
    this.frame = 0;
    this.lastPost = 0;
    this.lastClickFrame = -Infinity;
    // The tick: a 4 ms burst of 2.2 kHz that dies away quickly.
    this.click = new Float32Array(Math.round(0.004 * sr));
    for (let n = 0; n < this.click.length; n++) this.click[n] = Math.sin(2 * Math.PI * 2200 * n / sr) * Math.exp(-n / (0.0008 * sr));
    this.port.onmessage = e => this.onMessage(e.data);
  }

  onMessage(m) {
    if (m.type === 'params') Object.assign(this.params, m.params);
    else if (m.type === 'arm') { this.state = 'listening'; this.env = 0; }
    else if (m.type === 'disarm') { this.state = 'idle'; }
    else if (m.type === 'cancel' && this.state === 'active') this.finish();
  }

  startCapture() {
    const sr = this.sr, p = this.params;
    this.L = Math.max(1, Math.round(p.loopSec * sr));
    this.D = Math.max(1, Math.round(p.delaySec * sr));
    this.repeats = Math.max(1, Math.round(p.repeats));
    // A little from before the trigger (up to 10 ms, never more than a quarter of the loop).
    const pre = Math.min(Math.round(0.01 * sr), Math.floor(this.L / 4), this.ring.length);
    for (let k = 0; k < pre; k++) this.clip[k] = this.ring[(this.rpos - pre + k + this.ring.length) % this.ring.length];
    this.written = pre;
    this.wait = this.D;          // samples until playback starts
    this.pos = 0;                // position in the clip during playback
    this.rep = 0;
    this.fade = Math.max(1, Math.min(Math.round(0.003 * sr), Math.floor(this.L / 8)));
    this.clipSent = false;
    this.state = 'active';
    this.port.postMessage({ type: 'onset', frame: this.frame, L: this.L, D: this.D, repeats: this.repeats });
  }

  finish() {
    this.state = 'cooldown';
    this.cool = Math.round(0.25 * this.sr);
    this.port.postMessage({ type: 'done', frame: this.frame });
  }

  sendClip() {
    // A small picture of the clip for the waveform: peak level in 400 slices.
    const n = 400, peaks = new Float32Array(n), L = this.L;
    for (let i = 0; i < n; i++) {
      const a = Math.floor(i * L / n), b = Math.max(a + 1, Math.floor((i + 1) * L / n));
      let m = 0;
      for (let k = a; k < b; k++) m = Math.max(m, Math.abs(this.clip[k]));
      peaks[i] = m;
    }
    this.port.postMessage({ type: 'clip', peaks }, [peaks.buffer]);
    this.clipSent = true;
  }

  process(inputs, outputs) {
    const input = inputs[0], out = outputs[0];
    const a = input && input[0], b = input && input[1];
    const n = out[0].length;
    for (let i = 0; i < n; i++) {
      const x = a ? (b ? (a[i] + b[i]) * 0.5 : a[i]) : 0;
      const ax = Math.abs(x);
      this.env = ax > this.env ? this.env + (ax - this.env) * this.attack : this.env * this.release;
      this.ring[this.rpos] = x;
      this.rpos = (this.rpos + 1) % this.ring.length;
      let y = 0;

      if (this.state === 'listening') {
        if (this.env > this.params.threshold) this.startCapture();
      } else if (this.state === 'active') {
        if (this.written < this.L) {
          this.clip[this.written++] = x;
          if (this.written === this.L) this.sendClip();
        }
        if (this.wait > 0) {
          this.wait--;
        } else {
          const p = this.pos, L = this.L, f = this.fade;
          // Short fades at both ends of each pass so the joins don't pop.
          const g = p < f ? 0.5 - 0.5 * Math.cos(Math.PI * p / f) : p >= L - f ? 0.5 - 0.5 * Math.cos(Math.PI * (L - p) / f) : 1;
          y = (p < this.written ? this.clip[p] : 0) * g;
          if (p === 0) {
            // A tick at the start of each loop, but never closer than 0.2 s apart (so tiny loops don't buzz).
            this.tickOn = this.frame + i - this.lastClickFrame >= 0.2 * this.sr;
            if (this.tickOn) this.lastClickFrame = this.frame + i;
          }
          if (this.tickOn && p < this.click.length) y += this.click[p] * this.params.clickGain * 0.25;
          this.pos++;
          if (this.pos >= L) {
            this.pos = 0;
            this.rep++;
            this.port.postMessage({ type: 'rep', rep: this.rep, frame: this.frame + i });
            if (this.rep >= Math.max(1, Math.round(this.params.repeats))) { this.finish(); }
          }
        }
      } else if (this.state === 'cooldown') {
        if (--this.cool <= 0) { this.state = 'listening'; this.env = 0; }
      }
      y = y > 1 ? 1 : y < -1 ? -1 : y;
      for (let c = 0; c < out.length; c++) out[c][i] = y;
    }
    this.frame += n;
    // About 30 updates a second for the meter and the progress display.
    if (this.frame - this.lastPost > this.sr / 30) {
      this.lastPost = this.frame;
      const playing = this.state === 'active' && this.wait <= 0;
      this.port.postMessage({
        type: 'tick', env: this.env, state: this.state, frame: this.frame,
        rep: this.state === 'active' ? this.rep : 0, repeats: this.repeats || Math.round(this.params.repeats),
        pos: playing ? this.pos / this.L : 0, rec: this.state === 'active' ? Math.min(1, this.written / this.L) : 0,
        waiting: this.state === 'active' && this.wait > 0,
      });
    }
    return true;
  }
}

registerProcessor('eightfold-looper', Looper);
