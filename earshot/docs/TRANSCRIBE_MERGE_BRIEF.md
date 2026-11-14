# Brief: bring Earshot's companion features into the Transcribe watch app

Paste everything below the line into a Claude Code session started in
`~/Documents/Transcribe` on your Mac.

---

You are working in my existing, working Apple Watch app in this folder
(bundle ID `com.maxwelljosephson.transcribewatch`, watch code in `watch/`,
TestFlight upload script `watch/testflight.sh`). It records on the watch,
transcribes with **Microsoft speech-to-text**, and has a **Copy screen**
(Copy All Transcripts plus a By day list, shared through the watch share sheet
because watchOS has no clipboard) with **timestamps removed** from the
transcript and exported text. Keep all of that working exactly as it is,
including the recent fixes for the Microsoft 400 error.

Goal: add the "AI companion" features from **Earshot**, a reference
implementation in a public repo:

```
git clone --branch claude/beautiful-hypatia-m7ctpu https://github.com/maxwellcoffee/cloudtest1 /tmp/earshot-ref
```

Read `/tmp/earshot-ref/earshot/README.md`, `docs/CONTRACTS.md` and
`docs/FEATURES.md` first. Earshot has:

- a watchOS app (`Watch/`) with a durable store-and-forward upload queue,
  interruption recovery, privacy pause, bookmarks (Mark / Double Tap),
  Ask / Do / Note requests and an Inbox of questions from the Mac, answered by
  tap, dictation or "Say it";
- a macOS companion (`Mac/`) with:
  - an HTTP server the watch pairs with (6-digit code) and a SQLite store with full-text search;
  - Claude-powered insights (tasks, two-way promises, goals, decisions);
  - well-timed questions with a value-of-information gate, quiet hours and conversation/meeting avoidance;
  - daily digests and weekly reviews, memory chat with citations, and local redaction before cloud AI;
  - an agent that creates reminders, events, notes and Mail drafts, runs Shortcuts/AppleScript and optionally uses Claude computer use, with approvals sent to the watch;
  - a read-only MCP memory endpoint and Markdown/JSON export.

How to merge:

1. Survey my app first: how audio is captured, where Microsoft transcription
   runs (watch, iPhone or Mac), how transcripts are stored, and the Copy screen.
   Write a short plan and show it to me before large changes.
2. Keep my capture → Microsoft transcription path as the source of transcripts.
   Feed the finished transcript text (not audio) to the Earshot Mac companion.
   The simplest join is to POST each finished transcript entry to the Mac's
   server, which then needs one new route that stores text utterances directly
   without running its own transcription. Alternatively, run Earshot's Mac
   transcription on uploaded audio and keep Microsoft as one engine option.
   Pick whichever fits my code better and explain why.
3. Add the watch-side pieces that make the companion useful: pairing with the
   Mac, the Inbox of prompts with quick answers, Ask / Do / Note, and
   bookmarks. Reuse my existing UI style. Keep the Copy screen and the
   timestamp-free transcript.
4. Add the Earshot Mac app as a new target (XcodeGen `project.yml` in the
   reference repo), or as a separate project if mixing is risky.
5. Build both in Xcode. Fix every error. Run the watch app in the simulator and
   tap through the Copy screen, the Inbox and pairing.
6. Bump the build number and push to TestFlight with
   `zsh ~/Documents/Transcribe/watch/testflight.sh --new`.
7. Tell me what changed, what you tested, and anything left that needs my
   Apple Developer account or a real watch.

Constraints: no secrets in code (use the Keychain or Xcode build settings for
the Microsoft and Anthropic keys); keep the bundle ID; don't break the existing
TestFlight setup; plain HTTP to the Mac only on a trusted network (or use an
HTTPS tunnel URL).
