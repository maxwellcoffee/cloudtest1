# Breathing Dark

A web page, installable as a Mac app, that watches your eyes and your breathing through the webcam. Close
your eyes and dark (brown) noise fades in. A lowpass filter on the noise opens as you breathe in and closes
as you breathe out. A dark noise picture fills the screen and follows the same filter. Open your eyes and it
all fades away.

Live at https://maxwellcoffee.github.io/cloudtest1/eyes-closed-breath/

It started from two p5.js sketches by teamhuman:

- [eyes wide shut v2](https://editor.p5js.org/teamhuman/sketches/v3yvsugT8): eye closure from MediaPipe Face
  Landmarker blendshapes (`eyeBlinkLeft/Right` minus a quarter of `eyeWideLeft/Right`, smoothed, against a
  0.55 threshold, held for a moment before anything fades in).
- [breathe 25 with posture](https://editor.p5js.org/teamhuman/sketches/_JShZY0ze): breathing from shoulder
  movement, normalised by an adaptive min/max window, with breaths counted on an up-swing followed by a
  down-swing.

The page is plain JavaScript with no p5. It uses MediaPipe Tasks Vision 0.10.35 from jsDelivr for the face
and (by default) the pose, TensorFlow.js 4.22.0 with pose-detection 2.1.3 when a MoveNet model is chosen,
Web Audio for the sound and WebGL for the picture.

## Use it as a Mac app

Open the live page, then:

- **Safari** (macOS Sonoma or later): File › Add to Dock.
- **Chrome or Edge**: press **Install as an app** at the bottom of the page, or choose Install from the menu.

It then opens in its own window from the Dock, Launchpad or Applications. After the first launch the page
and the models (about 24 MB) are stored on the Mac, so it also opens offline. Whenever there is a
connection it picks up the latest version from GitHub Pages; every push to the branch Pages deploys from
updates it.

## Run it locally

The camera only works on a secure page, so serve the folder rather than double-clicking the file:

```sh
cd eyes-closed-breath && python3 -m http.server 8000
```

Then open http://localhost:8000.

1. Sit or lie so both shoulders are in the frame. Headphones help.
2. Press **Begin** and allow the camera.
3. Close your eyes. After 0.6 s the noise starts and reaches full level over 2.5 s.
4. If it starts too easily or not at all, drag the marker on the Eyes bar. Close your eyes for a few
   seconds, open them, and put the marker between your open level and how far the faint band reached.

**Preview with eyes open** (or <kbd>P</kbd>) forces the closed state so you can watch and hear the filter
follow your breathing. <kbd>H</kbd> shows the readouts on top of the noise.

## Pose models

The pose model only finds the shoulders so the two windows can be placed; the breath itself comes from the
image inside the windows. Pick one under **Pose model** in the Breath panel; it loads in the background and
takes over when ready. The panel shows the time each frame takes.

| Model | Library | Download | Notes |
| --- | --- | --- | --- |
| MediaPipe Full (default) | MediaPipe Tasks Vision | 9 MB | Good balance |
| MediaPipe Heavy | MediaPipe Tasks Vision | 31 MB | Most accurate, slowest |
| MoveNet Lightning | TensorFlow.js pose-detection | 5 MB | Fastest; the model the original breathing sketch used |
| MoveNet Thunder | TensorFlow.js pose-detection | 13 MB | More accurate MoveNet |

MediaPipe Full is stored for offline use straight away; the others are stored the first time you pick them.

## How the breath is measured

The pose model's shoulder points are guesses at the joint inside the body, and they wander by about as much
as a breath moves. So they are only used to place two windows over the shoulders (the corner brackets in
the camera view). Each camera frame, the picture inside each window is matched against a stored reference
frame to find how far it has moved up or down, to a fraction of a pixel (normalised cross-correlation of the
vertical brightness gradient). The windows are placed again when the shoulders move more than about an
eighth of a shoulder width or the match gets poor. The head is outside both windows, so tilting or turning
it doesn't affect the breath.

### Color outline (checkbox)

**Track the shoulder outline by color**, under the pose model picker, measures the shoulders a second way.
Each window instead reaches a little above the shoulder into the background. The app learns two colors
there, the background and the shoulder, with a running two-cluster k-means that follows changes in the
light. Each pixel gets a score for how much more it looks like shoulder than background. Down each column,
the outline is the row that best splits the column into background above and shoulder below, refined to a
fraction of a row where the score crosses one half. Once found, the search stays within a narrow band
around it, so stripes, furniture or hair further up can't pull it away. A line through the column points
(the dotted line in the camera view), read at a fixed spot, gives the shoulder height.

On a synthetic test (shoulders rising 4 px every 5 s while the head bobbed 10 px every 7 s), the two methods
compared like this:

| Method | Movement recovered | Noise left after a 5 s fit |
| --- | --- | --- |
| Image motion (default) | 3.35 of 4 px | 0.09 px |
| Color outline | 3.92 of 4 px | 0.16 px |

The color outline measures where the edge actually is, so it doesn't drift and needs no reference frame. It
needs the shoulders to stand out from what is behind them. If it can't separate them, the Breath panel says
so.

| Signal | Source | Drives |
| --- | --- | --- |
| Lid signal 0–1 | Face blendshapes, smoothed over 0.15 s | Closed when ≥ threshold (0.55), open again below threshold − 0.08 |
| Eyes closed ≥ hold (0.6 s) | Lid state | Noise fades in (2.5 s); eyes open for 0.3 s fades it out (1 s) |
| Breath 0–1 | Up-down shift of the shoulder windows ÷ shoulder width, adaptive window | Breath trace, breath count |
| Smoothed breath | Breath averaged over the **Breath smoothing** window (1.5 s) | Lowpass cutoff, exponential from **Low cutoff** (110 Hz) on the out-breath to **High cutoff** (900 Hz) on the in-breath; a small level swell; the picture's fine detail, brightness and aperture |
| Exhale floor (off) | Slider, 0–60% up the breath range | Below it the breath is held at the floor before smoothing, so the filter stays at the low cutoff through the less reliable bottom of the out-breath; the sweep from low to high cutoff runs between the floor and the top |
| Resonance (1 dB) | Slider, 0–24 dB | Height of the filter's peak at the cutoff (half of it is taken back off the level); in the picture, detail at the cutoff's scale and a ring at the aperture |

The Lowpass filter panel shows the chosen band on a 20 Hz – 10 kHz scale with the live cutoff. Breath
smoothing is two chained averages, each with a quarter of the window as its time constant. That has the same
delay as a plain average over the window but never cancels a breath outright (a plain 5 s average cancels a
5 s breath completely).

The Eyes panel holds the closed threshold (the marker on the live bar) and the hold before the noise.
Everything else is under **Settings**, saved in the browser: fades, volume, breath sensitivity (the smallest
min/max window), an invert switch for the breath direction and a mirror switch.

## Tips

- If the noise starts while your eyes are open (glasses, a low camera looking up at you, a big smile),
  drag the Eyes marker to the right. If it never starts, drag it left.
- If the shoulder windows keep jumping (grey brackets), try MediaPipe Heavy or MoveNet Thunder.
- If the breath trace barely moves, raise **Breath sensitivity**. Bare shoulders in dim light have little
  texture, so a lamp to one side helps the shoulder windows lock on. If the trace runs backwards, tick
  **Invert breath direction**.
- Corner brackets in amber mean a window is locked on; grey means its match is poor and it will be placed
  again.
- Looking down with your eyes open can look like closed eyes to the face model.
- The tracking runs locally in the browser. Video is never uploaded.
