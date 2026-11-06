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

To save power, **Only track breathing while my eyes are closed** (on by default) runs the body tracking only
while your eyes are closed, the noise is fading, or in Preview, and the eyes are checked 3 times a second
(**Eye checks per second** in the Eyes panel).

**Power-saving hibernate** (Eyes panel, on by default) saves battery when you're away. After 5 minutes with
no face in view, the camera turns off (its light goes out), the face and body models stop, the page redraws
only a few times a second, and the screen is allowed to sleep. Every 10 minutes the camera comes back on for
10 seconds and only the face model runs, a few checks a second, looking for you. If it finds your face,
everything picks up where it left off; if not, it sleeps for another 10 minutes. Moving the mouse, pressing a
key, or this window coming back into view looks straight away instead of waiting for the next check, and
checks wait while the window is hidden. Closed eyes still count as a face in view, so it never hibernates
while you rest. Unticking the box while it hibernates turns the camera straight back on.

**Continuous noise** (Noise panel, off by default) keeps the noise playing the whole time tracking runs.
With your eyes closed the filter follows your breath as usual. With them open, or when your breath isn't
being tracked (no face, breath lost, or tracking paused to save power), the filter glides down to the low
cutoff over 2.5 s and rests there, and glides back up when your eyes close. The full-screen picture still
appears only with your eyes closed.

**Preview with eyes open** (or <kbd>P</kbd>) plays the noise and moves the filter with your breathing while
the page stays in view, so you can watch the breath graph and adjust the sliders as you listen. The
full-screen picture only appears when your eyes are really closed. <kbd>H</kbd> shows the readouts on top of
the picture.

## Rests and progress

A rest counts once when your eyes stay continuously closed for **longer than 10 seconds**. Exactly 10
seconds does not count. Every observed eye opening ends the closure. Tracking loss, a frozen camera,
stopping, hiding the page or reloading cannot complete a rest or count the same held closure twice; open
your eyes in view before starting another rest after an interruption. Preview by itself does not count.

The **Rests** panel shows the rolling last 60 minutes and **Today**, from midnight in this computer's local
time zone. A rest belongs to the hour and day when it qualifies. The rolling hour is elapsed time, not a
clock-hour bucket. The hourly goal is **30**. The labels follow the requested strict “above” thresholds:

| Rests in the last 60 minutes | Label |
| --- | --- |
| 0–1 | Getting started |
| 2–10 | Good |
| 11–20 | Great |
| 21–30 | Excellent |
| 31+ | Top of the line |

At exactly 30 the goal is reached and the label remains Excellent. The live timer shows a closure's
progress; the 7-day comparison and existing charts remain available.

Every clock hour is saved with its rests, the minutes your face was in front of the camera and the minutes
spent resting. **All rests remain in the rolling-hour and daily totals**, including sessions under 10
minutes. Only hours with more than 10 minutes at the computer appear in charts and averages; the 7-day
average appears after 3 of those hours. Existing saved data is retained, but hours discarded by an older
version cannot be recovered. Data is saved in this browser on this computer (about 400 days are kept),
without changing your settings. The page reports when browser storage cannot save. **Clear saved rests**
at the bottom of the progress view deletes it after a second click.

Run the counter checks with `node --test rest-counter.test.mjs` from this folder.

**Show progress** opens the charts, scoped by a range row (24 hours, 7 days, 30 days, All):

- Four figures: the last 60 minutes against your 7-day average, the 7-day average, today's rests, and your
  best hour.
- **Rests per hour**: a bar for each hour at the computer, with the 7-day average as a dashed line and the
  current hour in gold once it passes 10 minutes. Hover or use the arrow keys for each hour's details.
- **Average rests per hour, by day**: the trend of your daily average.
- **Show as a table**: every hour in the range with its rests, minutes at the computer and minutes resting.

## Breath history

Click the breath graph to open the full history. It fills the screen with five lines, each a stretch of time
read left to right with the oldest at the top. Pick how long each line is (30 s, 1 min, 2 min or 5 min) at the
top. Scroll up to go back through the session (up to two hours, ten samples a second). It follows the newest
line while you're at the bottom; **Back to now** returns there.

With **Only track breathing while my eyes are closed** on, breath is only recorded with your eyes closed.
**Skip eyes-open gaps** (on by default) joins those stretches end to end so the lines read as continuous
breathing, with a dashed line and the length of each gap where one was left out. Turn it off to see real
time instead: lines start on the minute and gaps are labelled "eyes open" or "breath lost". Shaded stretches
are where your eyes were closed, and ticks along the bottom mark counted breaths. When tracking picks up
again, the breath line starts from your actual breath rather than from where it was before the pause.
Press Escape or Close to return; the noise picture still covers the view when your eyes close.

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

Pick a source under **Breath from** in the Breath panel. A line under the graph shows how steady the
current source is: jitter (frame-to-frame noise, in pixels), breath swing (how far the breath moved the
measurement over the last 10 s), and for the outline, how many shoulders were found. Switch sources and
color methods while breathing normally and keep the one with the lowest jitter for the largest swing.

### Shoulder movement (default)

The pose model's shoulder points are guesses at the joint inside the body, and they wander by about as much
as a breath moves. So they are only used to place two windows over the shoulders (the corner brackets in
the camera view). Each camera frame, the picture inside each window is matched against a stored reference
frame to find how far it has moved up or down, to a fraction of a pixel (normalised cross-correlation of the
vertical brightness gradient). The windows are placed again when the shoulders move more than about an
eighth of a shoulder width or the match gets poor. The head is outside both windows, so tilting or turning
it doesn't affect the breath.

### Shoulder outline by color

Each window reaches a little above the shoulder into the background. A color method scores every pixel
for how much more it looks like shoulder than background. Down each column, the outline is the row that best
splits the column into background above and shoulder below, refined to a fraction of a row. Once found, it
is only searched for in a narrow band around where it was, so stripes, furniture or hair further up can't
pull it away. Every outline point from **both shoulders** then votes on one shared shift since the windows
were placed (the median), so the two shoulders are always measured together. If only one shoulder's outline
is found for a second, both windows are placed again to pick up the other. The shoulder's colors are first
learned from the upper chest between the shoulders, which is reliably you even when a shoulder point is
off.

| Color method | How it tells shoulder from background |
| --- | --- |
| Color, ignoring brightness | One learned color per side (running two-cluster k-means) in an opponent-color space with brightness at a third of the weight, so shadows and exposure changes matter less |
| Color histograms | A 1000-bin color histogram per side, for patterned backgrounds or clothes |
| Color spread (Gaussian) | Each side's color and how it varies (mean and covariance), compared by likelihood |
| Sharpest color change (default) | The steepest step from background color towards shoulder color in each column, with sub-pixel peak fitting |
| Neural person mask | MediaPipe's selfie segmenter (250 KB) draws the person/background split; it ignores color |
| Vote | Runs the four color methods together and takes the median of their answers |

On a synthetic test (shoulders rising 4 px every 5 s while the head bobbed 10 px every 7 s), shoulder
movement recovered 3.35 of the 4 px and the color outline 3.92 px, both with R² 0.99 against the 5 s breath.
In a headless browser every color method found both shoulders; sharpest color change was the steadiest
there.

### Pulse in your face (camera PPG, experimental)

The skin of the forehead and cheeks (the boxes in the camera view, which brighten on each detected beat)
changes color very slightly with every heartbeat. Its average color goes through the POS method (Wang et
al., 2017), which separates the pulse from lighting changes; beats are the peaks, and the time between beats
gives the heart rate. Heart rate rises as you breathe in and falls as you breathe out (respiratory sinus
arrhythmia), and that slow swing is used as the breath. A pulse whose beats vary by more than 15% is treated
as not found. On a synthetic 30 fps face (62 bpm swinging ±6 bpm with 5 s breaths, camera noise and lighting
drift) it read the heart rate within 1 bpm and followed the breath with a correlation of 0.88, about 1.8 s
behind. It needs your face still and evenly lit, works best with slow relaxed breathing (which makes the
swing larger), and always lags the breath by a beat or two.

| Signal | Source | Drives |
| --- | --- | --- |
| Lid signal 0–1 | Face blendshapes, smoothed over 0.15 s | Closed when ≥ threshold (0.55), open again below threshold − 0.08 |
| Eyes closed ≥ hold (0.6 s) | Lid state | Noise fades in (2.5 s); eyes open for 0.3 s fades it out (1 s) |
| Breath 0–1 | The chosen source (shoulder shift ÷ shoulder width, or heart-rate swing), adaptive window | Breath trace, breath count |
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

## Sound

Brown noise, made even: its sub-audible drift below 20 Hz is removed, it is set by its average level rather
than its loudest moment, and rare outlier peaks are rounded off. It runs through two lowpass filters, a
small swell with the breath, the level control, and a smooth soft clipper (in place of a compressor), so the
output never hits a hard edge. The audio uses the browser's larger "playback" buffers, which avoids the
dropouts (heard as small clicks) that can happen while the face and pose models keep the computer busy.

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
