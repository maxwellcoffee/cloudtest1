# Voice capture field guide

A researched catalog of 272 devices and apps that capture context with voice and AI (pendants, recorders,
glasses, rings, watches, earbuds, meeting notetakers, voice-note and dictation apps, voice assistants,
professional scribes and lifelogging tools), including 30 products announced or rumored for the next few
months. From that evidence it recommends two feature sets: the best overall one, and the most minimal one
for an always-running Apple Watch app. It then compares the minimal set with Earshot (PR #3).

Research date: 16 November 2026.

## The minimal always-on Apple Watch app

Eight parts, in build order, plus two that are cut first if time runs short:

1. **One-tap start from the foreground** (a Session, or a press-and-hold Memo). Starts from a complication,
   a Smart Stack widget, a Control or Double Tap, behind a preflight check, with a consent reminder and a
   start cue.
2. **Capture gated on speech**, written to encrypted 2-minute ADTS segments that survive a crash.
3. **Delivery ledger**: a segment is deleted from the watch only after the iPhone confirms it, with sync
   states the wearer can see.
4. **Interruption handling**: honest gaps, one-tap resume, and a dead-man's-switch notification that fires
   even if the app dies.
5. **Timed Pause that asks before resuming** (an unanswered prompt becomes Stop), and a Stop that turns the
   mic off.
6. **Discard the last 5 or 15 minutes, or the whole Session**, applied before transcription or any cloud use.
7. **Guards for battery, storage and taking the watch off**, with measured hours left.
8. **Status on the wrist**: a recording screen that stands in for the watch face, plus complication and
   Smart Stack states.
9. *(cut first)* A moment bookmark on Double Tap.
10. *(cut first)* An evening recap on the wrist, if the iPhone pipeline is ready.

The watch stays a thin recorder. watchOS has no speech recognition or on-device LLM, and capture can't start
or resume without a tap in the foreground. Transcription, wearer-vs-others separation and summaries run on
the iPhone.

## The best overall feature set

- **Core (16):** the capture items above, plus a verifiable record (full transcript, wearer vs others,
  summaries citing the transcript, a short audio window), search and Ask over history that answers
  "not recorded" for gaps, action items sent to Reminders and Calendar with approval, retention set by
  jurisdiction and consent, third-party AI only after opt-in and through one logged exit point, a
  user-owned vault with an exit guarantee based on exported files, and read-only MCP access in v1.x.
- **Differentiators (7):** covering the watches Apple's Siri Recap leaves out, a consent kit and bystander
  rights, start prompts from context and pause zones, commitment tracking with rare nudges, briefs before
  meetings, filtering out media and splitting the day into conversations, and an unmetered local tier.
- **Later (9):** Ask from the wrist, outbound follow-ups with undo, Session mode in the EEA/UK/Germany,
  a Mac companion, phone-call capture, consented voiceprints, place and health context, templates and team
  modes, and instant replay on watches without Live Rewind.

## Against Earshot

Of the 10 minimal items, Earshot (commit `e36b1b5`) has 3 built, 6 partly built, and 1 missing (discard).
The biggest changes: write ADTS instead of `.m4a` so a crash doesn't lose the open segment, add a
dead-man's-switch notification, ask before resuming after a timed pause, stop on charging, add a discard
control, and add complications. See `data/earshot-comparison.json` or the page.

## Coverage and caveats

- 126 products were fact-checked twice against current sources (85 with high confidence, 40 medium, 1 low).
  This covered every wearable, recorder, ring, watch and earbud, every Apple Watch app, every lifelogging
  platform, and everything upcoming, rumored, in beta or discontinued. The 40 upcoming, beta and rumored
  items also got a skeptic pass that tried to disprove their status and date.
- The other 146 are shipping software (meeting notetakers, scribes, dictation tools, assistants, voice-note
  apps and glasses). The research sweep found and sourced them, but they were not re-checked, because the
  run reached the account's usage limit. Each catalog record says which group it is in.
- A feature counts only when a source confirms it. Prices and dates change quickly.

## Files

- `data/catalog.json`: the 272 products (status, timing, price, platforms, 23 feature flags, sources,
  verification notes).
- `data/stats.json`: counts by category, status and feature.
- `data/recommendation.json`: both feature sets, the Watch architecture, exclusions, market gaps, risks.
- `data/panel.json`: the three independent design proposals and the 27 critique items the final version
  fixed.
- `data/watch-technical.md`, `data/watch-apps.md`: the watchOS constraints brief and the Watch app market
  brief.
- `data/earshot-comparison.json`: the minimal set checked against Earshot's watch code.
- `site/build.py` + `site/template.html` write `site/index.html`. `site/import_run.py` splits a research-run
  output into the data files.

```sh
cd voice-capture-research/site
python3 import_run.py <workflow-output.json>   # only when re-running the research
python3 build.py                               # needs: pip install markdown
```
