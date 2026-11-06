export const REST_SECONDS = 10;
export const HOURLY_GOAL = 30;

export function createRestCycle(activeClosure = false) {
  const state = { start: null, counted: false, blocked: activeClosure, active: activeClosure, lastSample: null };

  function interrupt() {
    if (state.active) state.blocked = true;
    state.start = null;
    state.lastSample = null;
  }

  function observe({ now, closed, valid, maxGapSec }) {
    if (!valid) { interrupt(); return false; }
    if (state.lastSample != null && now - state.lastSample > maxGapSec) interrupt();
    state.lastSample = now;

    if (!closed) {
      state.start = null;
      state.counted = false;
      state.blocked = false;
      state.active = false;
      return false;
    }

    state.active = true;
    if (state.blocked) return false;
    if (state.start == null) state.start = now;
    if (!state.counted && now - state.start > REST_SECONDS) {
      state.counted = true;
      return true;
    }
    return false;
  }

  return { state, observe, interrupt };
}

export function restBand(count) {
  if (count > 30) return 'Top of the line';
  if (count > 20) return 'Excellent';
  if (count > 10) return 'Great';
  if (count > 1) return 'Good';
  return 'Getting started';
}

export function hourKeyOf(ms) {
  const d = new Date(ms), p2 = n => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p2(d.getMonth() + 1)}-${p2(d.getDate())}T${p2(d.getHours())}`;
}

export function hourStart(key) {
  const [date, h] = key.split('T');
  const [y, m, d] = date.split('-').map(Number);
  return new Date(y, m - 1, d, +h);
}

export function restTotals(data, wall) {
  const today = new Date(wall); today.setHours(0, 0, 0, 0);
  const tomorrow = new Date(today); tomorrow.setDate(tomorrow.getDate() + 1);
  const lastHour = data.recent.filter(t => t > wall - 3600e3 && t <= wall).length;
  const todayCount = Object.entries(data.hours)
    .filter(([key]) => hourStart(key) >= today && hourStart(key) < tomorrow)
    .reduce((sum, [, hour]) => sum + hour.rests, 0);
  return { lastHour, today: todayCount };
}

export function pruneRests(data, wall, keepDays) {
  const oldest = wall - keepDays * 864e5;
  for (const key of Object.keys(data.hours)) {
    if (hourStart(key).getTime() < oldest) delete data.hours[key];
  }
  data.recent = data.recent.filter(t => t > wall - 2 * 3600e3);
}

export function readRests(raw) {
  const empty = { hours: {}, recent: [], activeClosure: false };
  try {
    const data = JSON.parse(raw);
    if (!data || typeof data !== 'object') return empty;
    const hours = Object.fromEntries(Object.entries(data.hours || {}).filter(([key, h]) =>
      /^\d{4}-\d{2}-\d{2}T\d{2}$/.test(key) && h &&
      Number.isInteger(h.rests) && h.rests >= 0 &&
      Number.isFinite(h.presentSec) && h.presentSec >= 0 &&
      Number.isFinite(h.restSec) && h.restSec >= 0));
    const recent = Array.isArray(data.recent) ? data.recent.filter(Number.isFinite) : [];
    return { hours, recent, activeClosure: data.activeClosure === true };
  } catch {
    return empty;
  }
}
