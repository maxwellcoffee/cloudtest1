import assert from 'node:assert/strict';
import test from 'node:test';
import { createRestCycle, restBand, restTotals, hourKeyOf, pruneRests, readRests, HOURLY_GOAL } from './rest-counter.mjs';

process.env.TZ = 'America/Los_Angeles';

function sample(cycle, now, closed = true, valid = true) {
  return cycle.observe({ now, closed, valid, maxGapSec: 1 });
}

function hold(cycle, from, to) {
  let counts = 0;
  for (let t = from; t <= to; t += 0.25) if (sample(cycle, t)) counts++;
  return counts;
}

const hour = (rests, presentSec = 20) => ({ rests, presentSec, restSec: rests * 11 });

test('a closure counts strictly after 10 seconds, once even when held for minutes', () => {
  const cycle = createRestCycle();
  assert.equal(hold(cycle, 0, 9.75), 0);
  assert.equal(sample(cycle, 10), false);
  assert.equal(sample(cycle, 10.001), true);
  assert.equal(hold(cycle, 10.25, 180), 0);
});

test('every observed eye opening ends the closure, including a brief opening', () => {
  const cycle = createRestCycle();
  assert.equal(hold(cycle, 0, 9), 0);
  sample(cycle, 9.1, false);
  assert.equal(hold(cycle, 9.25, 19.25), 0);
  assert.equal(sample(cycle, 19.5), true);
  sample(cycle, 19.6, false);
  assert.equal(hold(cycle, 19.75, 30), 1);
});

test('tracking loss before qualification cancels the closure until an observed open', () => {
  const cycle = createRestCycle();
  hold(cycle, 0, 9);
  sample(cycle, 9.25, true, false);
  assert.equal(hold(cycle, 9.5, 40), 0);
  sample(cycle, 40.25, false);
  assert.equal(hold(cycle, 40.5, 51), 1);
});

test('loss after counting and frozen camera samples cannot duplicate a held closure', () => {
  const counted = createRestCycle();
  assert.equal(hold(counted, 0, 11), 1);
  counted.interrupt();
  assert.equal(hold(counted, 12, 60), 0);
  const frozen = createRestCycle();
  hold(frozen, 0, 9);
  assert.equal(sample(frozen, 30), false);
  assert.equal(hold(frozen, 30.25, 50), 0);
});

test('stop, hidden-tab interruptions and reload require open eyes before a new count', () => {
  for (const before of [5, 12]) {
    const cycle = createRestCycle();
    hold(cycle, 0, before);
    cycle.interrupt();
    const saved = readRests(JSON.stringify({ hours: {}, recent: [], activeClosure: cycle.state.active }));
    const reloaded = createRestCycle(saved.activeClosure);
    assert.equal(hold(reloaded, 0, 20), 0);
    sample(reloaded, 20.25, false);
    assert.equal(hold(reloaded, 20.5, 31), 1);
  }
});

test('rolling hour expires events at exactly 60 minutes, independent of clock-hour boundaries', () => {
  const wall = Date.parse('2026-11-02T15:00:00-08:00');
  const data = { hours: {}, recent: [wall - 3600e3 - 1, wall - 3600e3, wall - 3600e3 + 1, wall, wall + 1] };
  assert.equal(restTotals(data, wall).lastHour, 2);
  assert.equal(restTotals(data, wall + 1).lastHour, 2);
  assert.equal(restTotals(data, wall + 3600e3 + 1).lastHour, 0);
});

test('local day resets at midnight and counts short camera sessions across hour changes', () => {
  const data = { recent: [], hours: {
    '2026-11-01T23': hour(7), '2026-11-02T00': hour(2),
    '2026-11-02T15': hour(3), '2026-11-02T23': hour(4), '2026-11-03T00': hour(1),
  } };
  const wall = Date.parse('2026-11-02T23:59:59.999-08:00');
  pruneRests(data, wall, 400);
  assert.equal(restTotals(data, wall).today, 9);
  assert.equal(restTotals(data, wall + 1).today, 1);
  assert.equal(data.hours['2026-11-02T00'].rests, 2);
  assert.equal(restTotals(readRests(JSON.stringify(data)), wall).today, 9);
});

test('the 25-hour daylight-saving day uses local midnight and actual elapsed rolling time', () => {
  const wall = Date.parse('2026-11-01T23:59:59-08:00');
  const data = { hours: { '2026-11-01T00': hour(2), '2026-11-01T23': hour(3) },
    recent: [Date.parse('2026-11-01T01:30:00-07:00'), Date.parse('2026-11-01T01:30:00-08:00')] };
  assert.equal(restTotals(data, wall).today, 5);
  assert.equal(restTotals(data, Date.parse('2026-11-01T01:45:00-08:00')).lastHour, 1);
  assert.equal(hourKeyOf(wall), '2026-11-01T23');
});

test('pruning retains saved short-session totals and the existing storage shape', () => {
  const wall = Date.parse('2026-11-02T12:00:00-08:00');
  const data = readRests(JSON.stringify({ hours: { '2026-11-02T10': hour(2), '2024-01-01T00': hour(5) }, recent: [wall - 1000], activeClosure: true }));
  pruneRests(data, wall, 400);
  assert.deepEqual(Object.keys(data.hours), ['2026-11-02T10']);
  const restored = readRests(JSON.stringify(data));
  assert.equal(restored.activeClosure, true);
  assert.equal(restored.hours['2026-11-02T10'].rests, 2);
  assert.deepEqual(restored.recent, [wall - 1000]);
});

test('corrupt saved data does not prevent the app from opening', () => {
  for (const raw of [null, 'broken', 'null', '{"hours":{"bad":null},"recent":[1,"oops"]}']) {
    const data = readRests(raw);
    assert.deepEqual(data.hours, {});
    assert.ok(data.recent.every(Number.isFinite));
  }
});

test('bands follow strict above thresholds and the goal is met at 30', () => {
  assert.equal(HOURLY_GOAL, 30);
  for (const [n, label] of [[0, 'Getting started'], [1, 'Getting started'], [2, 'Good'], [10, 'Good'],
    [11, 'Great'], [20, 'Great'], [21, 'Excellent'], [30, 'Excellent'], [31, 'Top of the line']]) {
    assert.equal(restBand(n), label);
  }
});
