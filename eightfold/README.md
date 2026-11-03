# Eightfold

Say something and hear it back, looped: eight times by default, with a quiet tick at the start of each loop
to keep you on track.

Live at https://maxwellcoffee.github.io/cloudtest1/eightfold/

## Use it

1. Press **Start** (or <kbd>Space</kbd>) and allow the microphone. Headphones work best.
2. Say something. A sound louder than the marker on the mic meter starts a loop.
3. It records one loop's worth, then, after the delay, plays it back the chosen number of times. The mic is
   paused while it loops (so the playback can't set itself off through the speakers), then it listens again.

<kbd>Esc</kbd> or **Skip loop** stops the current loop and listens again.

| Control | Range | What it does |
| --- | --- | --- |
| Loop length | 0.01 – 10.00 s (slider or typed, to the hundredth) | How much of what you say becomes the loop |
| Delay before looping | 0.01 – 2.00 s | Time from when you start speaking to when the loop starts playing. Shorter than the loop, and playback follows just behind your voice |
| Times to loop | 1 – 32, default 8 | How many times the loop plays |
| Tick volume | 0 – 100 % | The tick at the start of each loop (at most five a second, so very short loops don't buzz) |
| Mic marker | −70 to −6 dB | How loud a sound has to be to start a loop |

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
so loops start on the exact sample. It follows the mic level (2 ms attack, 80 ms release) and, when it passes
the trigger, starts recording a clip of the loop length, including up to 10 ms from just before the trigger so
the start of the sound isn't cut. Playback starts the delay after the trigger; if that's before the clip has
finished recording, the first pass reads just behind the recording. Each pass has 3 ms fades at both ends
so the joins don't pop, and a 4 ms, 2.2 kHz tick at its start. The mic arrives with echo cancelling, noise
suppression and automatic gain turned off, so the loop sounds like you.

Tested offline by feeding the worklet tone bursts and checking the output sample by sample: with a 1.00 s loop
and 0.25 s delay the loop started 0.25 s after the sound and repeated every 1.00 s, eight times, with a tick
at each start; a sound during the loop didn't retrigger it; the next sound afterwards did. 0.30 s loops with
a 1.00 s delay, 0.01 s loops and 10.00 s loops with a 2.00 s delay behaved the same way.
