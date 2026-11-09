// Sync for the closed threshold: works out, from a short burst of fast eye readings, the range the
// eye-closure signal sits in while the eyes are open and while they are closed, and where the threshold
// should go between the two. No camera or page code here, so it can be tested on its own.

export const SYNC = {
  everySec: 300,        // a burst this often (and when tracking starts)
  retrySec: 60,         // sooner when the last burst barely saw a face
  windowSec: 30,        // length of a burst
  hz: 30,               // eye readings a second during a burst, when the camera and computer keep up
  minFaceSec: 10,       // face in view for less than this: nothing is concluded
  minSamples: 20,
  maxHoleSec: 1.2,      // a longer hole between readings is a break (no face), not time spent at a level
  maxStepSec: 0.25,     // readings further apart than this are too sparse to follow a blink across
  medianHalfSec: 1,     // the local level is the median of the readings within this long either side
  blinkRise: 0.15,      // this far above the local level, and back again, is a blink
  blinkMaxSec: 0.6,
  minBlinks: 2,         // one alone could be a hand or a glitch
  steadyBand: 0.08,     // within this of the local level is a steady reading
  settleSec: 0.5,       // and the local level must not be on the move this long either side
  closedShare: 0.6,     // with blinks: steady readings this far from the open level towards the blink peaks are closed
  minOpenSec: 2,        // steady time needed for an open range
  minClosedSec: 1.5,    // and for a closed range (a rest)
  minGap: 0.1,          // open top and closed bottom nearer than this can't be told apart
  widen: 0.6,           // how far a remembered range edge moves towards a new reading that widens the range
  narrow: 0.2,          // and towards one that narrows it
  blinkWeight: 0.5,     // blink peaks move the closed range by this much of the above
};

const median = sorted => {
  const n = sorted.length;
  return n ? (n % 2 ? sorted[(n - 1) / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2) : NaN;
};
const quantile = (sorted, q) => {
  if (!sorted.length) return NaN;
  const pos = (sorted.length - 1) * q, i = Math.floor(pos), f = pos - i;
  return i + 1 < sorted.length ? sorted[i] + (sorted[i + 1] - sorted[i]) * f : sorted[i];
};
const asc = (a, b) => a - b;

// samples: [{ t (seconds), v (0..1 eye-closure reading) }] in time order, only frames where a face was found.
// threshold: the current closed threshold, used to sort steady readings when there are no blinks to go by.
// Returns { faceSec, samples, rate, blinks, open: {lo, hi, sec} | null, closed: {lo, hi, from, sec?, blinks?} | null, note }
// where note is null when it went fine, or 'short' (not enough of a face), 'unclear' (one level, sitting on the
// threshold) or 'twoLevels' (two steady levels on the same side of the threshold and no blinks to say which is closed;
// levels then holds the two).
export function analyzeLidWindow(samples, { threshold = 0.5, opts = SYNC } = {}) {
  const n = samples.length;
  const out = { faceSec: 0, samples: n, rate: 0, blinks: 0, open: null, closed: null, note: null, split: null };
  if (n < 2) { out.note = 'short'; return out; }

  // How long each reading stands for.
  const steps = [];
  for (let i = 1; i < n; i++) steps.push(samples[i].t - samples[i - 1].t);
  const typical = median(steps.filter(s => s <= opts.maxHoleSec).sort(asc)) || opts.maxStepSec;
  const dur = samples.map((_, i) => (i + 1 < n && steps[i] <= opts.maxHoleSec ? steps[i] : typical));
  out.faceSec = dur.reduce((a, b) => a + b, 0);
  out.rate = out.faceSec > 0 ? n / out.faceSec : 0;
  if (n < opts.minSamples || out.faceSec < opts.minFaceSec) { out.note = 'short'; return out; }

  // The local level: a running median. A blink is too short to move it; a rest moves it, edges intact.
  const base = new Array(n);
  let a = 0, b = 0;
  for (let i = 0; i < n; i++) {
    while (samples[a].t < samples[i].t - opts.medianHalfSec) a++;
    while (b < n && samples[b].t <= samples[i].t + opts.medianHalfSec) b++;
    const win = [];
    for (let j = a; j < b; j++) win.push(samples[j].v);
    base[i] = median(win.sort(asc));
  }

  // Blinks: short runs well above the local level that come back down to where they started.
  const used = new Uint8Array(n); // 1 = part of a rise (or right next to one), so not a steady reading
  const blinks = [];
  for (let i = 0; i < n; i++) {
    if (samples[i].v - base[i] < opts.blinkRise) continue;
    let j = i;
    while (j + 1 < n && steps[j] <= opts.maxStepSec && samples[j + 1].v - base[j + 1] >= opts.blinkRise) j++;
    for (let k = Math.max(0, i - 1); k <= Math.min(n - 1, j + 1); k++) used[k] = 1;
    const bracketed = i > 0 && j + 1 < n && steps[i - 1] <= opts.maxStepSec && steps[j] <= opts.maxStepSec;
    const length = samples[j].t - samples[i].t + typical;
    if (bracketed && length <= opts.blinkMaxSec && Math.abs(base[i - 1] - base[j + 1]) <= opts.steadyBand) {
      let peak = 0;
      for (let k = i; k <= j; k++) peak = Math.max(peak, samples[k].v);
      blinks.push({ t: samples[i].t, peak, from: base[i - 1] });
    }
    i = j;
  }
  out.blinks = blinks.length;
  const peaks = blinks.map(x => x.peak).sort(asc);
  const haveBlinks = blinks.length >= opts.minBlinks;

  // Where open ends and closed begins for the steady readings.
  let split = threshold;
  if (haveBlinks) {
    const from = median(blinks.map(x => x.from).sort(asc));
    split = from + opts.closedShare * (median(peaks) - from);
  }
  out.split = split;

  // Steady readings: near the local level, and the level itself not on its way up or down.
  const low = [], high = [], lowAt = [], highAt = [];
  let lowSec = 0, highSec = 0;
  let before = 0, after = 0;
  for (let i = 0; i < n; i++) {
    while (samples[before].t < samples[i].t - opts.settleSec) before++;
    while (after + 1 < n && samples[after + 1].t <= samples[i].t + opts.settleSec) after++;
    if (used[i] || Math.abs(samples[i].v - base[i]) > opts.steadyBand) continue;
    if (Math.abs(base[after] - base[before]) > opts.steadyBand) continue;
    if (samples[i].v < split) { low.push(samples[i].v); lowSec += dur[i]; lowAt.push({ v: samples[i].v, d: dur[i] }); }
    else { high.push(samples[i].v); highSec += dur[i]; highAt.push({ v: samples[i].v, d: dur[i] }); }
  }
  low.sort(asc); high.sort(asc);
  // Without blinks the split is only the current threshold. Two steady levels on one side of it (open and looking
  // down? open and closed under a threshold set too high?) can't be told apart, and learning the pair as one wide
  // range would spoil what is remembered. Leave it for a burst with blinks in it.
  if (!haveBlinks) {
    const two = twoLevels(lowAt, opts) || twoLevels(highAt, opts);
    if (two) { out.note = 'twoLevels'; out.levels = two; return out; }
  }
  let open = lowSec >= opts.minOpenSec ? { lo: quantile(low, 0.05), hi: quantile(low, 0.95), sec: lowSec } : null;
  let rest = highSec >= opts.minClosedSec ? { lo: quantile(high, 0.05), hi: quantile(high, 0.95), sec: highSec, from: 'rest' } : null;
  // One group of readings cut in two by the split is neither: leave it for a burst with blinks in it.
  if (open && rest && rest.lo - open.hi < opts.minGap) { open = rest = null; out.note = 'unclear'; }

  out.open = open;
  out.closed = rest || (haveBlinks ? { lo: median(peaks), hi: peaks[peaks.length - 1], from: 'blinks', blinks: blinks.length } : null);
  if (out.open && out.closed && out.closed.lo - out.open.hi < opts.minGap && out.closed.from === 'blinks') out.closed = null;
  return out;
}

// Two groups of readings with a clear hole between them, each lasting long enough to be a level of its own.
function twoLevels(at, opts) {
  if (at.length < 2) return null;
  const s = at.slice().sort((x, y) => x.v - y.v);
  let k = 1;
  for (let i = 2; i < s.length; i++) if (s[i].v - s[i - 1].v > s[k].v - s[k - 1].v) k = i;
  if (s[k].v - s[k - 1].v < opts.blinkRise) return null;
  const sec = part => part.reduce((sum, x) => sum + x.d, 0);
  const below = s.slice(0, k), above = s.slice(k);
  if (sec(below) < opts.minClosedSec || sec(above) < opts.minClosedSec) return null;
  return [median(below.map(x => x.v)), median(above.map(x => x.v))];
}

// The remembered ranges, moved towards what a burst found. An edge next to the gap between open and closed
// follows quickly when the range grows and slowly when it shrinks, so one calm burst doesn't forget that
// looking down reads higher.
export function blendLidModel(model, found, at = Date.now(), opts = SYNC) {
  const next = { open: model?.open ?? null, closed: model?.closed ?? null };
  const mix = (old, val, k) => old + (val - old) * k;
  if (found.open) {
    const o = next.open, f = found.open;
    next.open = o ? { lo: mix(o.lo, f.lo, 0.5), hi: mix(o.hi, f.hi, f.hi > o.hi ? opts.widen : opts.narrow), at }
      : { lo: f.lo, hi: f.hi, at };
  }
  if (found.closed) {
    const c = next.closed, f = found.closed;
    const w = f.from === 'blinks' && c?.from === 'rest' ? opts.blinkWeight : 1;
    next.closed = c ? { lo: mix(c.lo, f.lo, w * (f.lo < c.lo ? opts.widen : opts.narrow)), hi: mix(c.hi, f.hi, w * 0.5), from: w < 1 ? c.from : f.from, at }
      : { lo: f.lo, hi: f.hi, from: f.from, at };
  }
  return next;
}

// Halfway between the top of the open range and the bottom of the closed range, or null when one of them
// isn't known yet or they are too close to separate.
export function syncedThreshold(model, { min = 0.1, max = 0.95, opts = SYNC } = {}) {
  if (!model?.open || !model?.closed) return null;
  if (model.closed.lo - model.open.hi < opts.minGap) return null;
  const mid = (model.open.hi + model.closed.lo) / 2;
  return Math.min(max, Math.max(min, Math.round(mid * 100) / 100));
}

export function readLidModel(raw) {
  try {
    const m = typeof raw === 'string' ? JSON.parse(raw) : raw;
    const ok = r => r && [r.lo, r.hi].every(x => Number.isFinite(x) && x >= 0 && x <= 1) && r.lo <= r.hi;
    return { open: ok(m?.open) ? m.open : null, closed: ok(m?.closed) ? m.closed : null };
  } catch { return { open: null, closed: null }; }
}
