import assert from 'node:assert/strict';
import test from 'node:test';
import { SYNC, analyzeLidWindow, blendLidModel, syncedThreshold, readLidModel } from './lid-sync.mjs';

// A small repeatable random source, so the tests always see the same readings.
function rng(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 2 ** 32); }

// level(t) gives the reading at time t; noise is added on top. present(t) false = no face that frame.
function burst({ level, hz = 30, sec = 30, noise = 0.015, seed = 1, present = () => true }) {
  const r = rng(seed), out = [];
  for (let i = 0; i < sec * hz; i++) {
    const t = i / hz;
    if (!present(t)) continue;
    out.push({ t, v: Math.min(1, Math.max(0, level(t) + (r() - 0.5) * 2 * noise)) });
  }
  return out;
}
// A blink: up over 70 ms, closed 60 ms, back over 130 ms.
const blinkShape = (t, at, open, peak) => {
  const x = t - at;
  if (x < 0 || x > 0.26) return 0;
  const k = x < 0.07 ? x / 0.07 : x < 0.13 ? 1 : 1 - (x - 0.13) / 0.13;
  return (peak - open) * k;
};
const withBlinks = (open, peak, times) => t => open + times.reduce((a, at) => a + blinkShape(t, at, open, peak), 0);
const near = (x, want, tol, what) => assert.ok(Math.abs(x - want) <= tol, `${what}: ${x} not within ${tol} of ${want}`);

test('open eyes with blinks: open range from the steady readings, closed range from the blink peaks', () => {
  const w = analyzeLidWindow(burst({ level: withBlinks(0.12, 0.72, [3, 7.5, 12, 18.2, 24, 27.7]) }), { threshold: 0.58 });
  assert.equal(w.note, null);
  assert.equal(w.blinks, 6);
  near(w.open.lo, 0.105, 0.01, 'open low');
  near(w.open.hi, 0.135, 0.01, 'open high');
  assert.equal(w.closed.from, 'blinks');
  near(w.closed.lo, 0.72, 0.04, 'closed low');
  const model = blendLidModel(null, w, 0);
  near(syncedThreshold(model), (0.135 + 0.72) / 2, 0.03, 'threshold');
});

test('a rest in the burst: the closed range is the steady closed readings, not the way up or down', () => {
  const level = t => (t < 12 ? 0.1 : t < 12.1 ? 0.1 + (t - 12) * 6 : t < 24 ? 0.7 : t < 24.15 ? 0.7 - (t - 24) * 4 : 0.1);
  const w = analyzeLidWindow(burst({ level }), { threshold: 0.58 });
  assert.equal(w.closed.from, 'rest');
  near(w.closed.lo, 0.685, 0.01, 'closed low');
  near(w.closed.hi, 0.715, 0.01, 'closed high');
  near(w.open.hi, 0.115, 0.01, 'open high');
  near(w.closed.sec, 11.3, 0.7, 'closed seconds'); // 12 s, less the half second settling at each end
  assert.equal(syncedThreshold(blendLidModel(null, w, 0)), 0.4);
});

test('eyes open and no blinks: only the open range, and the threshold waits for a closed reading', () => {
  const w = analyzeLidWindow(burst({ level: () => 0.15 }), { threshold: 0.58 });
  assert.ok(w.open);
  assert.equal(w.closed, null);
  assert.equal(syncedThreshold(blendLidModel(null, w, 0)), null);
  // With a closed range remembered from before, it can be placed.
  const model = blendLidModel({ open: null, closed: { lo: 0.66, hi: 0.8, from: 'rest', at: 0 } }, w, 1);
  near(syncedThreshold(model), (0.165 + 0.66) / 2, 0.01, 'threshold');
});

test('eyes closed for the whole burst: only the closed range', () => {
  const w = analyzeLidWindow(burst({ level: () => 0.74 }), { threshold: 0.58 });
  assert.equal(w.open, null);
  assert.equal(w.closed.from, 'rest');
  near(w.closed.lo, 0.725, 0.01, 'closed low');
});

test('a threshold set too high is found out by blinks: closed eyes that never reached it still count as closed', () => {
  // Blinks peak at 0.5 and a rest sits at 0.52, both under the 0.58 threshold.
  const blinks = withBlinks(0.1, 0.5, [2, 5, 8]);
  const level = t => (t >= 14 && t < 26 ? 0.52 : blinks(t));
  const w = analyzeLidWindow(burst({ level }), { threshold: 0.58 });
  assert.equal(w.closed.from, 'rest');
  near(w.closed.lo, 0.505, 0.015, 'closed low');
  near(syncedThreshold(blendLidModel(null, w, 0)), 0.31, 0.02, 'threshold');
});

test('a threshold set too low: open eyes reading above it are still open when blinks show where closed is', () => {
  const w = analyzeLidWindow(burst({ level: withBlinks(0.32, 0.78, [4, 9, 15, 22]) }), { threshold: 0.25 });
  near(w.open.hi, 0.335, 0.01, 'open high');
  assert.equal(w.closed.from, 'blinks');
  near(syncedThreshold(blendLidModel(null, w, 0)), 0.55, 0.03, 'threshold');
});

test('looking down for a few seconds stays in the open range when blinks reach higher', () => {
  const blinks = withBlinks(0.1, 0.72, [2, 6, 21, 26]);
  const level = t => (t >= 9 && t < 17 ? 0.4 : blinks(t));
  const w = analyzeLidWindow(burst({ level }), { threshold: 0.3 });
  near(w.open.hi, 0.41, 0.015, 'open high');
  assert.equal(w.closed.from, 'blinks');
  near(syncedThreshold(blendLidModel(null, w, 0)), 0.565, 0.03, 'threshold');
});

test('readings sitting on the threshold with no blinks are left alone', () => {
  const w = analyzeLidWindow(burst({ level: t => 0.58 + 0.03 * Math.sin(t) }), { threshold: 0.58 });
  assert.equal(w.note, 'unclear');
  assert.equal(w.open, null);
  assert.equal(w.closed, null);
});

test('a single blink is not enough, and a single odd frame is not a blink', () => {
  const one = analyzeLidWindow(burst({ level: withBlinks(0.1, 0.7, [10]) }), { threshold: 0.58 });
  assert.equal(one.blinks, 1);
  assert.equal(one.closed, null);
  const samples = burst({ level: () => 0.1 });
  samples[300].v = 0.9;
  const glitch = analyzeLidWindow(samples, { threshold: 0.58 });
  assert.equal(glitch.closed, null);
});

test('not enough of a face: nothing is concluded', () => {
  const w = analyzeLidWindow(burst({ level: () => 0.1, present: t => t < 6 }), { threshold: 0.58 });
  assert.equal(w.note, 'short');
  near(w.faceSec, 6, 0.2, 'face seconds');
  assert.equal(w.open, null);
  assert.equal(analyzeLidWindow([], {}).note, 'short');
});

test('a face that comes and goes: time out of view is not counted, and the readings still work', () => {
  const w = analyzeLidWindow(burst({ level: withBlinks(0.1, 0.7, [3, 6, 22, 25]), present: t => t < 10 || t > 18 }), { threshold: 0.58 });
  near(w.faceSec, 22, 0.5, 'face seconds');
  assert.equal(w.blinks, 4);
  assert.ok(w.open && w.closed);
});

test('a slow computer (8 readings a second) still reads a rest', () => {
  const level = t => (t >= 10 && t < 20 ? 0.68 : 0.12);
  const w = analyzeLidWindow(burst({ level, hz: 8 }), { threshold: 0.58 });
  near(w.rate, 8, 0.5, 'rate');
  assert.equal(w.closed.from, 'rest');
  assert.equal(syncedThreshold(blendLidModel(null, w, 0)), 0.4);
});

test('remembered ranges widen quickly and narrow slowly', () => {
  let m = blendLidModel(null, { open: { lo: 0.05, hi: 0.2 }, closed: { lo: 0.66, hi: 0.8, from: 'rest' } }, 0);
  assert.equal(syncedThreshold(m), 0.43);
  m = blendLidModel(m, { open: { lo: 0.05, hi: 0.45 }, closed: null }, 1);     // looking down
  near(m.open.hi, 0.2 + 0.25 * SYNC.widen, 1e-9, 'open high widened');
  const wide = m.open.hi;
  m = blendLidModel(m, { open: { lo: 0.05, hi: 0.2 }, closed: null }, 2);      // back to looking ahead
  near(m.open.hi, wide - (wide - 0.2) * SYNC.narrow, 1e-9, 'open high narrowed');
  assert.equal(m.closed.lo, 0.66);
  // Blink peaks move a closed range that came from a rest by half as much.
  const before = m.closed.lo;
  m = blendLidModel(m, { open: null, closed: { lo: 0.56, hi: 0.7, from: 'blinks' } }, 3);
  near(m.closed.lo, before - 0.1 * SYNC.widen * SYNC.blinkWeight, 1e-9, 'closed low');
  assert.equal(m.closed.from, 'rest');
});

test('ranges too close together give no threshold, and the result stays inside the limits', () => {
  assert.equal(syncedThreshold({ open: { lo: 0.3, hi: 0.5 }, closed: { lo: 0.55, hi: 0.7 } }), null);
  assert.equal(syncedThreshold({ open: { lo: 0, hi: 0.01 }, closed: { lo: 0.12, hi: 0.2 } }), 0.1);
  assert.equal(syncedThreshold(null), null);
});

test('stored ranges are checked when read back', () => {
  assert.deepEqual(readLidModel('not json'), { open: null, closed: null });
  assert.deepEqual(readLidModel('{"open":{"lo":0.4,"hi":0.2},"closed":{"lo":0.6,"hi":0.8,"from":"rest"}}'),
    { open: null, closed: { lo: 0.6, hi: 0.8, from: 'rest' } });
  assert.deepEqual(readLidModel(null), { open: null, closed: null });
});

test('eyes closing slowly: the way down is not counted as open', () => {
  const level = t => (t < 8 ? 0.1 : t < 14 ? 0.1 + (t - 8) / 6 * 0.6 : 0.7);
  const w = analyzeLidWindow(burst({ level }), { threshold: 0.58 });
  assert.ok(w.open.hi < 0.2, `open high ${w.open.hi}`);
  assert.ok(w.closed.lo > 0.62, `closed low ${w.closed.lo}`);
});

test('two steady levels on the same side of the threshold, and no blinks: nothing is learned', () => {
  // Open at 0.23, then a rest that reads 0.57 under a threshold of 0.58. Closed, or looking down? It can't say.
  const level = t => (t >= 6 && t < 22 ? 0.57 : 0.23);
  const w = analyzeLidWindow(burst({ level }), { threshold: 0.58 });
  assert.equal(w.note, 'twoLevels');
  assert.equal(w.open, null);
  assert.equal(w.closed, null);
  near(w.levels[0], 0.23, 0.02, 'lower level');
  near(w.levels[1], 0.57, 0.02, 'upper level');
  // The same burst with a threshold between the two reads as open and closed.
  const ok = analyzeLidWindow(burst({ level }), { threshold: 0.45 });
  assert.equal(ok.note, null);
  near(syncedThreshold(blendLidModel(null, ok, 0)), 0.4, 0.03, 'threshold');
  // And with blinks reaching the upper level, the high threshold no longer matters.
  const blinking = t => level(t) + (t < 6 || t >= 22 ? [2, 4, 24, 27].reduce((a, at) => a + blinkShape(t, at, 0.23, 0.57), 0) : 0);
  const b = analyzeLidWindow(burst({ level: blinking }), { threshold: 0.58 });
  assert.equal(b.note, null);
  assert.equal(b.closed.from, 'rest');
  near(syncedThreshold(blendLidModel(null, b, 0)), 0.4, 0.03, 'threshold with blinks');
});

test('a very slow computer (one or two readings a second) still reads a rest, and its time in view counts', () => {
  const level = t => (t >= 6 && t < 22 ? 0.57 : 0.23);
  const w = analyzeLidWindow(burst({ level, hz: 1.5 }), { threshold: 0.45 });
  assert.equal(w.note, null);
  near(w.faceSec, 30, 1.5, 'time in view');
  assert.equal(w.closed.from, 'rest');
  near(w.open.hi, 0.24, 0.02, 'open high');
  near(w.closed.lo, 0.56, 0.02, 'closed low');
});
