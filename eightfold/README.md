# Eightfold

Say something and hear it back, looped and layered: everything you said in the last eight cycles plays
together, with a quiet tick at the start of each cycle to keep you on track.

Live at https## Use it

1. Press **Start** (or <kbd>Space</kbd>) and allow the microphone. Use headphones: the mic is always
   listening, so speakers would feed the loops back in (or tick **I'm using speakers** to turn on the
   browser's echo cancelling).
2. Say something. A sound louder than the marker on the mic meter is recorded as a loop one loop length long.
3. Keep talking. Each new phrase becomes another loop, layered on the ones already playing. Each loop stays
   for **Times to loop** cycles and then drops out.

<kbd>Esc</kbd> or **Clear loops** removes every loop.

**The cycle.** All loops share one beat, one loop length long; the tick marks its start. The first loop after
a quiet spell starts exactly the delay after you started speaking, and that sets where the cycles fall. Later
loops start at the first cycle that begins at least the delay after their sound, so everything stays in time.

**Loops at once** caps how many loops play at the same moment:

- Below **Times to loop**, loops take turns: each cycle the ones that played least recently go first, so some
  play every second or third cycle and never more than the cap play together.
- Above it, the surplus (loops at once minus times to loop) goes to extra plays from the middle of the cycle:
  each cycle up to that many loops, taking turns, also play again from the halfway point.
- Equal (8 and 8 by default): every loop plays every cycle.

| Control | Range | What it does |
| --- | --- | --- |
| Loop length | 0.01 – 10.00 s (slider or typed, to the hundredth) | How much of each phrase becomes a loop, and the length of the cycle |
| Delay before looping | 0.01 – 2.00 s | Time from when you start speaking to when that loop first plays (later loops wait for the next cycle) |
| Times to loop | 1 – 32, default 8 | How many cycles each loop stays for |
| Loops at once | 1 – 32, default 8 | The most loops playing at the same moment |
| Tick volume | 0 – 100 % | The tick at the start of each cycle (at most five a second) |
| Mic marker | −70 to −6 dB | How loud a sound has to be to start a loop |

The display shows one lane per loop, newest at the top: its waveform (gold while it plays), a line for each
pass that is playing, and how many cycles it has left. Settings are remembered in the browser.

 loop |

Settings are remembered in the browser.

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
trigger and nothing is being recorded, it records a clip of the loop length, including up to 10 ms from just
before the trigger so the start of the sound isn't cut. At each cycle start it picks which loops play (least
recently played first, up to the cap), and at the midpoint it adds extra plays from the surplus. Each pass has
3 ms fades at both ends so the joins don't pop; layers are mixed and pass through a soft ceiling so many
together round off instead of clipping. The mic arrives with noise suppression and automatic gain off (echo
cancelling only with the speakers option), so the loops sound like you.

Tested offline by feeding the worklet tone bursts and logging every pass it started:

- Three phrases with 4 cycles each and 8 at once: three overlapping loops, the later ones starting on the next
  cycle, each staying 4 cycles.
- A phrase every cycle with 8 cycles each and only 2 at once: never more than 2 at once; with 3–4 loops alive
  each played every other cycle, in turn.
- 8 cycles each and 10 at once: exactly two loops per cycle also played from the midpoint, in turn.
- 8 and 8: every loop every cycle, no midpoint plays.

In the page, with a fake microphone speaking four phrases, all four layered, the cap held at 2 when lowered,
and Clear loops emptied everything.
