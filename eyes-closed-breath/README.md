# Breathing Dark

A single web page that watches your eyes and your breathing through the webcam. Close your eyes and dark
(brown) noise fades in. A lowpass filter on the noise opens as you breathe in and closes as you breathe out.
A dark noise picture fills the screen and follows the same filter. Open your eyes and it all fades away.

It combines two p5.js sketches by teamhuman:

- [eyes wide shut v2](https://editor.p5js.org/teamhuman/sketches/v3yvsugT8): eye closure from MediaPipe Face
  Landmarker blendshapes (`eyeBlinkLeft/Right` minus a quarter of `eyeWideLeft/Right`, smoothed, against a
  0.55 threshold, held for a while before anything fades in).
- [breathe 25 with posture](https://editor.p5js.org/teamhuman/sketches/_JShZY0ze): breath from the gap between
  the nose and the shoulder midline, normalised by an adaptive min/max window, with breaths counted on an
  up-swing followed by a down-swing.

The page is plain JavaScript with no p5. It uses MediaPipe Tasks Vision 0.10.35 from jsDelivr for both the
face and the pose models, Web Audio for the sound and WebGL for the picture.

## Run it

The camera only works on a secure page, so serve the folder rather than double-clicking the file:

```sh
cd eyes-closed-breath && python3 -m http.server 8000
```

Then open http://localhost:8000 in Chrome, Edge, Firefox or Safari. Any https host (GitHub Pages, Netlify)
works too. The first load downloads about 20 MB of models.

1. Sit so your head and both shoulders are in the frame. Headphones help.
2. Press **Begin** and allow the camera.
3. Close your eyes. After 1.5 s the noise starts and reaches full level over 5 s.

**Preview with eyes open** (or <kbd>P</kbd>) forces the closed state so you can watch and hear the filter
follow your breathing. <kbd>H</kbd> shows the readouts on top of the noise.

## How it maps

| Signal | Source | Drives |
| --- | --- | --- |
| Lid signal 0–1 | Face blendshapes, smoothed over 0.15 s | Closed when ≥ threshold (0.55), open again below threshold − 0.08 |
| Eyes closed ≥ hold (1.5 s) | Lid state | Noise fades in (5 s); eyes open for 0.3 s fades it out (1 s) |
| Breath 0–1 | (shoulder midline y − nose tip y) ÷ shoulder width, adaptive window | Lowpass cutoff, exponential from 110 Hz (out-breath) to 900 Hz (in-breath); a small level swell; the picture's fine detail, brightness and aperture |

Every value above is a slider under **Settings** (saved in the browser), plus breath sensitivity (the
smallest min/max window), an invert switch for the breath direction and a mirror switch.

## Tips

- If the noise starts while your eyes are open (glasses, a low camera looking down at you, a big smile),
  raise **Closed threshold**. If it never starts, lower it.
- If the breath trace barely moves, raise **Breath sensitivity** or breathe a little more into the chest and
  shoulders. If it jitters, lower it. The window settles over the first few breaths.
- When the shoulders leave the frame the filter settles at a resting position instead of guessing.
- The tracking runs locally in the browser tab. Video is never uploaded.
