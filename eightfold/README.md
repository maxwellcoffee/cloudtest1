# Eightfold

Say something and hear it back, looped and layered: everything you said in the last eight cycles plays
together, with a quiet tick at the start of each cycle to keep you on track.

Live at https://maxwellcoffee.github.io/cloudtest1/eightfold/

## Use it

1. Press **Start** (or <kbd>Space</kbd>) and allow the microphone. Use headphones: the mic is always
   listening, so speakers would feed the loops back in (or tick **I'm using speakers** to turn on the
   browser's echo cancelling).
2. Press **Sync** once (see below) so what you sing on the click comes back on the click.
3. Say something. A sound louder than the marker on the mic meter is recorded as a loop one loop length long.
4. Keep talking. Each new phrase becomes another loop, layered on the ones already playing. Each loop stays
   for **Times to loop** cycles and then drops out.

<kbd>Esc</kbd> or **Clear loops** removes every loop.

**The cycle.** All loops share one beat, one loop length long; the tick marks its start. The first loop after
a quiet spell starts exactly the delay after you started speaking, and that sets where the cycles fall. Later
loops start at the first cycle that begins at least the delay after their sound, so everything stays in time.
If you keep sounding past the end of a loop, the next loop starts on the very next sample, so a long phrase
becomes a chain of loops exactly one loop length apart, and they join up seamlessly when played back.

**Loops at once** caps how many loops play at the same moment:

- Below **Times to loop**, loops take turns: each cycle the ones that played least recently go first, so some
  play every second or third cycle and never more than the cap play together.
- Above it, the surplus (loops at once minus times to loop) goes to extra plays from the middle of the cycle:
  each cycle up to that many loops, taking turns, also play again from the halfway point.
- Equal (8 and 8 by default): every loop plays every cycle.

| Control | Range | What it does |
| --- | --- | --- |
| Loop length | 0.01 – 10.00 s (slider or typed, to the hundredth) | How much of each phrase becomes a loop, and the length of the cycle |
| Delay before looping | 0.01 – 2.00 s (Sync can set it higher for long loops) | Time from when you start speaking to when that loop first plays (later loops wait for the next cycle) |
| Times to loop | 1 – 32, default 8 | How many cycles each loop stays for |
| Loops at once | 1 – 32, default 8 | The most loops playing at the same moment |
| Tick volume | 0 – 100 % | The tick at the start of each cycle (at most five a second) |
| Mic marker | −70 to −6 dB | How loud a sound has to be to start a loop |

Settings are remembered in the browser.

### Sync

**Sync** plays clicks: three to find the beat, then eight that count. Make a short, sharp sound right on each
one (a clap, a tap on the desk, or "ta"). Each of the eight shows up as its own wave, from a third of a beat
before its click to 0.6 of a beat after, with a line at the click and a line where your sound peaks.

When it's done, Eightfold averages the peak times of the taps that gave a clean reading and leaves out the
rest, saying why on each row:

- **too quiet**: the loudest point is under half the trigger level on the mic meter.
- **unclear**: the peak isn't at least 5 times the background level.
- **cut off**: the peak is at the very edge of the window.
- **two sounds**: a second sound at least half as loud, separate from the first (a double tap or an echo).
- **off the rest**: more than 35 ms (or three times the usual spread) from the middle reading.

It needs at least four clean readings. The average is how long after a click your sound peaks: the speaker
delay, your own timing and the mic delay together. A dashed line marks it on every wave, and the delay is set
to the loop length minus it.

Why that works: the first sound you make starts the cycle, and the ticks begin the delay later. When you then
sing on the ticks you hear, each sound arrives exactly one loop length after the one before, which is exactly
where the next loop in a chain begins, so every loop starts on your sound and plays it back on the tick.

The sync follows the loop length: change the length and the delay is recalculated. Moving the delay yourself
ends the sync. Nothing is recorded while syncing, and starting a sync clears the loops.

### The loops display

One row per loop, placed by age. The top row is what's coming next: the loop being recorded, or one waiting
for its first cycle. Below it is the loop in its first cycle, then its second, and so on. Every loop moves down
one row per cycle, the newest is always on top, and a new loop never pushes the others around. The panel keeps
one row per cycle a loop lasts, so its height only changes with **Times to loop**, or when a loop is doubled
past it.

Each row shows the waveform (gold while it plays, with a line for each pass that is sounding) and how many
cycles it has left. **×2** doubles how many cycles that loop stays for (up to 1024). **½** halves it, but never
cuts the cycle it is playing.

## Use it as a Mac app

Open the live page, then in Safari choose **File › Add to Dock**, or in Chrome press **Install as an app** at
the bottom of the page (or Install from the menu). It opens in its own window, works offline, and picks up
new versions from GitHub Pages whenever it's online.

## Run it locally

The microphone only works on a secure page, so serve the folder:

```sh
cd eightfold && python3 -m http.server 8000
```

Then open http://localhost:8000.

## How it works

Everything that touches sound runs in an AudioWorklet (`looper-worklet.js`) on the browser's audio thread,
so loops start on the exact sample. It follows the mic level (2 ms attack, 80 ms release); when it passes the
trigger and nothing is being recorded, it records a clip of the loop length starting at that sample, plus a
10 ms lead-in from just before it. Cycle events are handled 10 ms early: each pass starts its lead-in then and
fades in across it, so the moment the sound began lands exactly on the tick, and it fades out across its last
10 ms. Back-to-back clips of a chain overlap by that same 10 ms of sound, so the two fades add up to an
unbroken join.

At each cycle start it picks which loops play (least recently played first, up to the cap), and at the
midpoint it adds extra plays from the surplus. Layers are mixed and pass through a soft ceiling so many
together round off instead of clipping. The mic arrives with noise suppression and automatic gain off (echo
cancelling only with the speakers option), so the loops sound like you.

Sync runs on the same thread: it plays the clicks and keeps everything the mic hears, and once each counted
click's window has gone by it sends that stretch to the page. The page finds the loudest 8 ms (an RMS level,
smooth enough to ride over the cycles of a voice), then the loudest sample within it, which is the peak.

Tested offline by feeding the worklet tone bursts and logging every pass it started:

- Four phrases, 8 cycles each, 8 at once: four overlapping loops, the later ones starting on the next
  cycle, each staying 8 cycles.
- The same with only 2 at once: never more than 2 at once, loops taking turns.
- 8 cycles each and 10 at once: two loops per cycle also played from the midpoint, in turn.
- A 0.05 s loop with a 20 ms sound: a chain of clips exactly 0.05 s apart.
- Sync, with clap-like taps planned at known offsets: each window arrived centred on its click, and the clap
  peaks were found within 0.5 ms of where they were placed. A tap at under a third of the trigger level read as
  too quiet, a double tap as two sounds, and a tap 400 ms late was left out as off the rest. Averaging the
  other five gave 123 ms (±8 ms) and a delay of 0.877 s.
- Singing on the clicks, 120 ms late, with the synced delay of 0.88 s: every sound played back within 0.1 ms
  of the tick, both as one continuous chain and as separate phrases. With a 0.25 s delay the chain landed
  370 ms off the tick.
- A steady tone through a chain of clips: the same level all the way through, with no dip at the joins.

In the page, with a fake microphone speaking four phrases: the loops panel kept the same height throughout
and each loop moved down exactly one row per cycle; ×2 took a loop from 8 to 16 cycles and grew the panel,
½ took it back; the sync panel showed the clicks and hits, set the delay from the result, kept it in step
with the loop length, and dropped the sync when the delay was moved by hand. A real sync run against the
looping speech phrases showed long smeared sounds as unclear and left the delay unchanged.
