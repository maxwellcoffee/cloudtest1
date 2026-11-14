# Earshot

Earshot is a personal "second memory": an Apple Watch app that records your day
continuously, and a Mac companion that transcribes it, keeps a searchable
archive, and uses Claude to pull out what matters (tasks, promises you made,
goals, ideas, people, decisions). Now and then it asks you a well-timed question
on your wrist ("You told Sam you'd send the deck Friday. Want a reminder?"), and
with your approval it can act on the Mac: create reminders and events, write
notes, draft emails, run Shortcuts, or hand a task to an agent that can operate
the computer.

Everything stays on your Mac except the text snippets you choose to send to the
Claude API. There is no Earshot server and no account.

> **Personal-use project.** Earshot records the people around you. Read
> [Consent and the law](#consent-and-the-law) before you wear it. It is built
> for installing on your own devices from Xcode, not for the App Store.

---

## Contents

- [Features](#features)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Setup](#setup)
- [How it behaves](#how-it-behaves)
- [Limitations](#limitations)
- [Network and security](#network-and-security)
- [Consent and the law](#consent-and-the-law)
- [Privacy design](#privacy-design)
- [Testing without a watch](#testing-without-a-watch)
- [Troubleshooting](#troubleshooting)
- [Project layout](#project-layout)
- [Roadmap](#roadmap)

---

## Features

The MVP in this repository:

**On the wrist (watchOS app)**
- Continuous recording in short AAC segments (2 minutes by default), started
  from the app and kept alive in the background.
- Store-and-forward upload: segments queue on the watch and upload oldest-first
  whenever the Mac is reachable, so going out of range loses nothing.
- Privacy pause, a "remember this moment" bookmark, silence skipping, and an
  automatic stop at low battery (10% by default).
- Questions, nudges, approvals, answers and digest notices from the Mac, with
  haptics scaled to priority. Answer by tapping a choice, dictating or
  scribbling, "just say it" (the Mac reads your spoken answer from the
  transcript), snoozing (asks again in 2 hours) or dismissing.
- Ask, Do and Note from the wrist: ask your memory a question, give the Mac
  agent a task, or save a note ("parking spot 4C").
- A Today glance: headline, words and minutes recorded, open tasks,
  highlights and what's next.
- A battery forecast while recording ("≈ 5 h 20 m left at this rate"),
  measured from the actual drain, with a tip to pause during quiet stretches
  when the battery would not last until the evening.

**On the Mac (macOS app)**
- A local HTTP server for the watch, with 6-digit pairing codes that rotate
  every 10 minutes and a revocable token per device.
- Transcription with Apple SpeechAnalyzer (macOS 26, on-device), Apple Speech
  (SFSpeechRecognizer), or any Whisper-compatible API.
- A SQLite archive with full-text search (FTS5) over every utterance.
- A main window with Today (live transcript timeline by segment, insights,
  bookmarks), Ask, Inbox, Goals, Digests, Agent, Devices and Settings, plus a
  menu bar extra with status and quick actions.
- Desk mode: turn on **Use this Mac's microphone** in Devices to record with
  the Mac's microphone when you're not wearing the watch. Drop audio files on
  the Today view to import them.
- Export everything (Settings > Data): a folder of plain files you can read
  without Earshot, with one Markdown transcript per day, insights, goals,
  prompts and actions as JSON, digests as Markdown, and a README describing
  every file.
- A personal-memory MCP server (Settings > Integrations, off by default): Claude
  and other MCP clients can search your transcripts, read a day's transcript,
  list open tasks, promises and questions, read goals and digests, and ask your
  memory a question. Every tool is read-only, and clients need their own token.

**AI (Claude, or Apple's on-device model)**
- Insights extracted from new speech every 15 minutes (once there are at
  least 120 new words): tasks, commitments, events, ideas, goals, people,
  facts, decisions, open questions, highlights and mood.
- Proactive questions with a strict budget: at most 6 a day, at least 75
  minutes apart, never during quiet hours (21:00-08:00), never mid-conversation
  and never during a calendar meeting. All of these are configurable. Every
  question must say which decision or action it unlocks; questions that unlock
  nothing are dropped.
- Promises tracked in both directions: "You promised: ..." and "Promised to
  you: ...", with the other person attached.
- Redaction before the cloud (Settings > Data > Privacy, on by default):
  e-mail addresses, phone numbers, payment-card numbers, IBANs and account
  numbers, US Social Security numbers and one-time codes are replaced with
  placeholders such as `[email]` before text goes to Claude. Your stored
  transcripts keep the original text.
- Goal tracking with check-ins and progress notes.
- A daily digest (summary, highlights, commitments, open loops, goal progress,
  patterns, one reflection question, suggestions for tomorrow) after 21:00, and
  a weekly review on Sundays.
- Memory chat: ask anything about your archive and get an answer with
  citations to the exact moments.

**Actions and the agent**
- Proposed actions land in the Inbox: reminders, calendar events, notes
  (Markdown in `~/Documents/Earshot Notes`, optionally Apple Notes too), email
  drafts (opened in Mail, never sent), opening links and apps, running
  Shortcuts, AppleScript, and free-form agent tasks.
- Every action has a risk level. Low-risk actions (notes) run automatically by
  default; medium-risk ones can be set to auto-run; everything else waits for
  your approval.
- An agent that uses Claude tool use with Mac tools (reminders, events, notes,
  email drafts, links, apps, Shortcuts, AppleScript, memory search, today's
  summary, upcoming events) and, if you turn it on, Claude's computer use
  toolset to see and operate the screen. Medium- and high-risk steps ask for
  approval, on the watch when the task came from the watch. Runs stop after 40
  steps or when you cancel.

---

## Architecture

```
 Apple Watch (watchOS 10+)                                   Mac (macOS 14+)
+-------------------------------+                +---------------------------------------------+
| Recorder: AAC segments        |  HTTP over LAN |  HTTP server :8737  (Network.framework,     |
| silence ratio, pause,         |  (or https     |  Bonjour _earshot._tcp, bearer tokens)      |
| bookmarks, low-battery stop   |   tunnel)      |        |                                    |
|                               |                |        v                                    |
| On-disk upload queue  --------+--------------->|  Ingest pipeline -> Audio/<day>/<id>.m4a    |
|  (store-and-forward,          | POST segments  |        |                                    |
|   oldest first)               |                |        v                                    |
|                               |                |  Transcription                              |
|                               |                |   SpeechAnalyzer (macOS 26, on-device)      |
|                               |                |   SFSpeechRecognizer | Whisper-compatible   |
|                               |                |        |                                    |
|                               |                |        v                                    |
|                               |                |  SQLite + FTS5 archive                      |
|                               |                |   segments, utterances, insights, goals,    |
|                               |                |   prompts, actions, digests, chat           |
|                               |                |        |                                    |
|                               |                |        v                                    |
|                               |                |  Claude (or Apple on-device model)          |
|                               |                |   insights - goal notes - digests           |
|                               |                |   question scheduler (budget, quiet hours,  |
|                               |                |     conversation, calendar)                 |
|                               |                |   memory chat with citations                |
|                               |                |   agent: Mac tools + computer use toolset   |
|                               |                |        |               |                    |
|                               |                |        |               v                    |
|                               |                |        |      Actions: Reminders, Calendar, |
|                               |                |        |      Notes, Mail drafts, Shortcuts,|
|                               |                |        |      AppleScript, apps, links      |
|                               |  POST sync     |        v                                    |
| Prompts, approvals, answers,  |<---------------+  Prompts / approvals / answers / Today      |
| Today glance                  |  POST answers, |                                             |
| Ask / Do / Note               |---requests,--->|  Memory chat (Ask), agent (Do), notes       |
+-------------------------------+   bookmarks    +---------------------------------------------+
```

The watch always initiates: it uploads segments and calls `sync` periodically,
which reports its status (battery, queue, recording state) and returns pending
prompts, the Today snapshot and the recording settings (the Mac is the single
place you edit them).

**HTTP API** (all JSON, dates as seconds since 1970; every `/api/v1` endpoint
except `hello` and `pair` needs `Authorization: Bearer <token>` with the token
issued at pairing):

| Method | Path | Body | Response |
|---|---|---|---|
| GET  | `/api/v1/hello`     | none | `ServerHello` |
| POST | `/api/v1/pair`      | `PairRequest` (code, device name/kind) | `PairResponse` (token) |
| POST | `/api/v1/segments`  | raw `audio/mp4` + `X-Earshot-*` headers | `SegmentAck` |
| POST | `/api/v1/sync`      | `WatchStatusReport` | `SyncResponse` |
| POST | `/api/v1/answers`   | `PromptAnswer` | `OKResponse` |
| POST | `/api/v1/requests`  | `WatchRequest` (ask / command / note) | `WatchRequestAck` |
| POST | `/api/v1/bookmarks` | `Bookmark` | `OKResponse` |
| POST | `/mcp`              | JSON-RPC 2.0 (MCP) | JSON-RPC (only while enabled in Settings > Integrations; needs the MCP token) |

The types live in [`Shared/EarshotProtocol.swift`](Shared/EarshotProtocol.swift);
the module APIs are in [`docs/CONTRACTS.md`](docs/CONTRACTS.md).

---

## Requirements

- **Mac:** macOS 14 Sonoma or later. macOS 26 or later is recommended: it adds
  SpeechAnalyzer (fast, on-device transcription) and Apple's on-device
  language model as a private alternative to Claude. On macOS 14 and 15
  Earshot uses SFSpeechRecognizer or a Whisper-compatible API.
- **Xcode 26 or later** (the project uses the macOS 26 / watchOS 26 SDKs while
  deploying back to macOS 14 / watchOS 10).
- **Apple Watch** on watchOS 10 or later, paired with an iPhone (Xcode installs
  watch apps through the paired iPhone).
- **An Anthropic API key** from console.anthropic.com, unless you only use the
  on-device model (macOS 26 with Apple Intelligence).
- **An Apple Developer account.** A free account works for installing on your
  own devices; apps signed with a free account expire after 7 days, and you
  re-run them from Xcode. No iCloud, HealthKit or other special capabilities are
  needed.
- **Homebrew** (optional), used by the bootstrap script to install
  [XcodeGen](https://github.com/yonaskolb/XcodeGen).

---

## Setup

### 1. Generate the project

```sh
git clone <this repo> earshot-src
cd earshot-src/earshot      # the folder that holds project.yml and scripts/
scripts/bootstrap.sh YOURTEAMID
```

The script checks Xcode, installs XcodeGen with Homebrew if it's missing,
writes `Config/Local.xcconfig` with your team, runs `xcodegen generate` and
opens `Earshot.xcodeproj`. Run `scripts/bootstrap.sh --help` for options.

The Xcode project is generated from [`project.yml`](project.yml) and is not
committed. Change settings in `project.yml` and re-run `xcodegen generate`
(edits made in Xcode's build settings are lost on regeneration).

### 2. Set your signing team

`DEVELOPMENT_TEAM` is empty in `project.yml`. Your team ID (Xcode > Settings >
Accounts, or developer.apple.com/account > Membership) goes in
`Config/Local.xcconfig`, which is git-ignored:

```
DEVELOPMENT_TEAM = ABCDE12345
// Only if the default com.example.earshot.* bundle IDs can't be registered:
EARSHOT_BUNDLE_ID_PREFIX = com.yourname.earshot
```

`scripts/bootstrap.sh YOURTEAMID com.yourname.earshot` writes both. You can
also pick the team in each target's Signing & Capabilities tab, but that
choice is lost the next time the project is generated.

### 3. Run the Mac app

Select the **Earshot** scheme and **My Mac**, then Run (Cmd-R). The server
starts on port 8737. On first launch an onboarding sheet walks you through
consent, your Anthropic API key, permissions and pairing the watch; the steps
below cover the same ground and where to change things later.

### 4. Add your API key

In Earshot's **Settings > AI**, paste your Anthropic API key (it's stored in
the Keychain, which is the durable option). Earshot also reads
`ANTHROPIC_API_KEY` from its environment when the Keychain has no key, for
example from the scheme's Run environment variables, but `xcodegen generate`
rewrites the shared scheme and drops that setting. The default model is
`claude-opus-5-5` for both background analysis and foreground work (agent,
digests, memory chat); both are configurable. On macOS 26 with Apple
Intelligence you can choose the on-device model instead.

Also fill in **Settings > You > About you** (name, a few lines about yourself,
life goals). Every prompt uses it, and it is what makes questions personal
rather than generic.

### 5. Grant permissions

macOS asks the first time each feature is used, and the Settings screen has
buttons to request them up front:

| Permission | Needed for |
|---|---|
| Speech Recognition | Apple transcription engines |
| Calendars and Reminders (full access) | not interrupting meetings; creating events and reminders |
| Microphone | desk mode only |
| Automation (Apple Events) | Mail drafts, Apple Notes, AppleScript actions (asked per app) |
| Files and Folders (Documents) | Markdown notes in `~/Documents/Earshot Notes` (the default notes folder) |
| Local Network | the watch reaching the server |
| Accessibility, Screen Recording | computer use only (off by default) |

If the macOS firewall is on, allow incoming connections for Earshot when asked
(System Settings > Network > Firewall).

### 6. Install the watch app

1. Enable Developer Mode on the iPhone (Settings > Privacy & Security >
   Developer Mode) and on the watch (Settings > Privacy & Security > Developer
   Mode), and connect the iPhone to the Mac once so Xcode can prepare both.
2. Select the **EarshotWatch** scheme and your Apple Watch as the destination,
   then Run. The first install can take a while.

### 7. Pair

1. On the Mac, open **Devices**: it shows this Mac's IP addresses, the port
   and the current pairing code (it changes every 10 minutes).
2. Open Earshot on the watch, go to its settings, and enter the Mac's address
   (for example `http://192.168.1.20:8737`, or an `https://` URL if you use a
   tunnel) and the pairing code.
3. The watch appears under Devices with its battery, queue and last-seen time.

### 8. Start recording

Start recording **with the app open on your wrist**: watchOS only lets an app
begin recording in the foreground. After that you can lower your wrist and
recording continues. Segments upload whenever the Mac is reachable, appear in
Today as they are transcribed, and feed the insights, questions and digests.

---

## How it behaves

- **Segments.** Audio is cut into segments (120 s by default, set on the Mac
  and pushed to the watch on every sync). Each upload carries its start time,
  duration, levels, speech ratio and the reason it ended (rotation, stop,
  pause, voice answer, interruption, low battery).
- **Silence.** The watch measures how much of each segment is above the
  silence threshold (-45 dBFS by default). With silence skipping on, silent
  segments are not transcribed (speech ratio under 2%).
- **Transcription** runs one segment at a time on the Mac and survives
  restarts: pending segments are picked up again at launch.
- **Insights** are extracted every 15 minutes when there is enough new speech.
  Proposed actions go to the Inbox; low-risk ones run automatically if allowed.
- **Questions** are queued by the AI. A scheduler checks every minute and
  releases at most one, highest priority first, only when the budget allows
  (daily cap, minimum gap, quiet hours, conversation, meetings). Answers to your own requests, approvals and digests
  are delivered right away and don't count against the budget.
- **"Just say it" answers.** Choose it on the watch and speak; the recorder
  closes the segment early so the answer reaches the Mac quickly, and the Mac
  reads your reply from the transcript.
- **Digests** are generated after 21:00 each day and as a weekly review on
  Sundays, and the watch gets a notice.
- **Retention.** Raw audio is deleted after 7 days (configurable; 0 deletes it
  right after transcription). Transcripts and insights are kept until you
  delete them.

---

## Limitations

Earshot works within what watchOS allows a personal app to do. Be aware of:

- **Recording must start in the foreground.** If watchOS stops the session,
  open the app and start again.
- **Calls, Siri and other audio interruptions** stop recording until you reopen
  the app and start again.
- **Battery.** Continuous microphone use drains a watch in hours, not days.
  Use privacy pause when you don't need recording, charge during the day,
  leave silence skipping on, and rely on the automatic stop at low battery.
- **Reachability.** The watch has to reach the Mac's address:
  - on the same Wi-Fi network as the Mac, or
  - through its paired iPhone (over Bluetooth the iPhone carries the watch's
    traffic, so the iPhone must be on the Mac's network), or
  - through an HTTPS tunnel URL that forwards to the Mac's port 8737.

  Away from all of these, segments queue on the watch (using its storage) and
  upload when the Mac is reachable again.
- **The Mac must be awake** to receive and transcribe. Prevent automatic sleep
  while plugged in if you want near-real-time questions.
- **Plain HTTP on the LAN** (see below). Use it on trusted networks only.
- **App Store.** Apple review would very likely reject continuous background
  recording of this kind. Earshot is meant for personal installs from Xcode.

---

## Network and security

The Mac server speaks plain HTTP/1.1 on port 8737 on all network interfaces
and advertises itself over Bonjour as `_earshot._tcp`. Every `/api/v1` request
except `hello` and `pair` needs the bearer token issued at pairing; unpair a
device in Devices to revoke it. `/mcp` (off by default) uses its own token from
Settings > Integrations instead. Requests with an `Origin` header that is not
`localhost` are rejected with 403, so a web page from another site cannot call
the server through your browser (DNS-rebinding protection).

The watch's App Transport Security settings (in `project.yml`) set both
`NSAllowsLocalNetworking` and `NSAllowsArbitraryLoads`. On current OS versions
Apple ignores the arbitrary-loads key when the local-networking key is present,
so in practice:

- plain `http://` is allowed to IP addresses, `.local` names and single-label
  host names (your Mac on the LAN);
- anything else, such as a tunnel, must be `https://`.

The trade-off: on the LAN, audio, transcripts and the bearer token travel
unencrypted. Anyone on the same network who can capture traffic could read
them or reuse the token. Use Earshot on networks you trust (home, not café
Wi-Fi), or put the Mac behind a TLS tunnel and enter its `https://` URL on the
watch.

The same applies to the MCP server: it shares the port, so while it is on it
is reachable from your network, not only from this Mac. A client on another
machine sends the MCP token and receives your memory over plain HTTP. Rotate
the token in Settings > Integrations to cut every client off at once.

The Mac app's own ATS settings set only `NSAllowsLocalNetworking`, so the
Whisper-compatible engine can use a self-hosted server by IP address or
`.local` name over `http://` (for example `http://127.0.0.1:8080/v1`). Any
other transcription endpoint must use `https://`.

The Mac app is **not sandboxed**: it automates other apps (Apple Events,
`shortcuts`, `osascript`, computer use) and runs a server. It is built with the
hardened runtime and only the entitlements it needs (Apple Events, audio input,
calendars). Automation runs only through the action and approval flow
described above; review proposed actions before approving them.

---

## Consent and the law

Earshot records everyone within earshot, not just you. **This is not legal
advice; check the rules where you live and work.**

- **United States.** Many states allow recording a conversation you take part
  in (one-party consent), but several require everyone's consent, including
  California, Florida, Illinois, Maryland, Massachusetts, Montana, New
  Hampshire, Pennsylvania and Washington. Recording conversations you are not
  part of can be illegal everywhere.
- **EU, UK and similar regimes (GDPR).** Other people's voices and transcripts
  are personal data. Purely personal use may fall under the household
  exemption; using it at work or in public-facing settings generally does not.
  Employers, schools, clinics, courts and many venues forbid recording.

In practice: tell people you're recording, pause when anyone asks (privacy
pause on the watch), don't wear it where recording is prohibited, and use
"forget" to delete anything that should not have been captured.

---

## Privacy design

- **Local-first.** Audio, transcripts, insights, goals, digests and chat
  history live on your Mac in `~/Library/Application Support/Earshot`
  (`earshot.sqlite` plus `Audio/<day>/<segment>.m4a`). The watch sends
  directly to your Mac over your network; there is no Earshot cloud service.
- **What leaves the Mac.**
  - With the Claude backend, **text only** goes to the Anthropic API: transcript
    excerpts, your profile text, goals and related insights needed for each
    task. Audio is never sent to Claude.
  - **Redaction** (on by default, Settings > Data > Privacy) replaces e-mail
    addresses, phone, card, IBAN and account numbers, US Social Security
    numbers and one-time codes with placeholders on the Mac before that text
    is sent. Names and other details are still sent, and agent tasks are sent
    as written because the agent needs real addresses to act.
  - If you enable **computer use**, the agent sends screenshots of your screen
    to Claude while it works. It is off by default.
  - The **Whisper-compatible** engine uploads audio to the endpoint you
    configure. Apple Speech runs on-device when the language supports it and may
    otherwise use Apple's servers. SpeechAnalyzer (macOS 26) is on-device.
  - If you turn on the **MCP server**, the AI app you connect can read your
    transcripts, open loops, goals and digests, and that app may send them to
    its own provider. Across the LAN this traffic is plain HTTP.
- **On-device option.** On macOS 26 with Apple Intelligence, choose Apple's
  on-device model so analysis never leaves the Mac. Combined with
  SpeechAnalyzer, nothing leaves the Mac at all.
- **Retention.** Raw audio is deleted after a configurable number of days
  (default 7, or immediately after transcription). Transcripts stay until you
  delete them.
- **Forget and erase.** Forget a time range to delete those transcripts, or
  erase all data from Settings.
- **Export.** Settings > Data > Export Everything writes your whole archive as
  plain Markdown and JSON files to a folder you choose.
- **Secrets.** API keys are stored in the Keychain. Each watch gets its own
  random token, revocable from Devices.

---

## Testing without a watch

- **Desk mode.** Turn on **Use this Mac's microphone** in Devices (or use
  Earshot > Toggle Mac Microphone, Shift-Cmd-M, or **Use Mac Microphone** in
  the menu bar extra). Recording starts right away: the Mac records AAC
  segments of the same length through the same pipeline as the watch.
- **Drag and drop.** Drop audio files onto the Today view to import them as
  segments.
- **Smoke test the server.** With the Mac app running, take the pairing code
  from Devices and any `.m4a` recording (QuickTime Player or Voice Memos):

  ```sh
  scripts/smoke-test-server.sh 123456 ~/Desktop/sample.m4a
  # another machine, or reuse the printed token:
  EARSHOT_TOKEN=<token> scripts/smoke-test-server.sh - sample.m4a http://192.168.1.20:8737
  ```

  It calls `hello`, pairs (device kind `import`), uploads the file with
  `X-Earshot-*` headers, syncs a status report and adds a bookmark, printing
  each response. The segment then shows up in Today once transcribed.
- **Unit tests.** Cmd-U in Xcode, or:

  ```sh
  xcodebuild test -project Earshot.xcodeproj -scheme Earshot -destination 'platform=macOS'
  ```

  They cover the pure logic: `JSONValue` and `Schema`, `DateParsing`,
  `AppSettings` quiet hours and tolerant decoding, the wire protocol
  (`SegmentMeta` headers, JSON date encoding), Claude request bodies, the HTTP
  parser, utterance assembly and the question policy. Tests run inside the Mac
  app (hosted tests), so the app launches during the run.
- **Watch build check** (simulator, so no signing is needed):

  ```sh
  xcodebuild build -project Earshot.xcodeproj -scheme EarshotWatch -destination 'generic/platform=watchOS Simulator'
  ```

---

## Troubleshooting

**"Signing for ... requires a development team"** - add your team to
`Config/Local.xcconfig` (or run `scripts/bootstrap.sh YOURTEAMID`) and
regenerate.

**"Failed to register bundle identifier" / identifier not available** - the
`com.example.earshot.*` IDs may already be taken. Set
`EARSHOT_BUNDLE_ID_PREFIX = com.yourname.earshot` in `Config/Local.xcconfig`
and regenerate.

**Unit tests fail to load ("different Team IDs" or library validation)** - the
hardened runtime only loads a test bundle signed by the same team as the app.
Set a development team instead of building unsigned.

**The watch can't reach the Mac**
- Use the IP shown in Devices; it changes if the Mac changes networks or
  its DHCP lease does.
- Make sure the watch (or its iPhone) is on the same network as the Mac. Guest
  networks and "client isolation" block device-to-device traffic.
- Allow incoming connections for Earshot in the macOS firewall.
- Check the Mac answers locally: `curl http://127.0.0.1:8737/api/v1/hello`.
- If another app uses port 8737, change the port in Settings > Recording >
  Server, restart Earshot, and update the address on the watch.
- Keep the Mac awake.

**Pairing fails** - the code rotates every 10 minutes; use the one currently
shown. A watch that gets 401 errors after you unpaired it needs to pair again.

**Nothing is transcribed**
- Grant Speech Recognition in System Settings > Privacy & Security.
- On macOS 26 the first SpeechAnalyzer run downloads the speech model for your
  language; give it a minute on a good connection.
- Check the transcription language in Settings (default `en-US`).
- Very quiet segments are skipped as silent; set a lower (more negative)
  silence threshold if speech is being missed.
- For the Whisper engine, check the base URL, model and API key. An error
  saying the App Transport Security policy requires a secure connection means
  the endpoint uses `http://` with a host name that is not local; use
  `https://` (plain HTTP works only for IP addresses, `.local` names and
  single-label host names).

**Claude errors** - check the API key and model names in Settings > AI. Rate
limits, overloads and dropped connections are retried automatically with
backoff.

**Reminders or events aren't created** - grant full access to Calendars and
Reminders in System Settings > Privacy & Security.

**Permissions keep resetting after rebuilding** - unsigned builds get a new
code identity each time, so macOS forgets automation, accessibility and
screen-recording grants. Signing with your team keeps them stable.

**Recording stopped on the watch** - a call, Siri or another app's audio
interrupted it, or the battery reached the stop level. Open the app and start
again.

**My Info.plist / entitlements edits disappeared** - XcodeGen regenerates
`Mac/Info.plist`, `Watch/Info.plist` and `Mac/Earshot.entitlements` from
`project.yml`. Edit `project.yml` instead.

---

## Project layout

```
project.yml                 XcodeGen spec (targets Earshot, EarshotWatch, EarshotTests)
Config/Signing.xcconfig     includes the git-ignored Config/Local.xcconfig
Shared/EarshotProtocol.swift  wire protocol, compiled into both apps
Mac/                        macOS app
  Core/                     app model, settings, data model, ingest pipeline, desk mode
  Server/                   HTTP server, pairing, API router, MCP memory server
  Storage/                  SQLite database with FTS5, Export Everything
  Transcription/            SpeechAnalyzer, SFSpeechRecognizer, Whisper-compatible
  AI/                       Claude client, LLM service, redaction, insights, questions, digests, memory chat
  Agent/                    calendar, actions, approvals, computer control, agent loop
  Views/                    SwiftUI views
  Support/                  JSON tree, logging, dates, paths, network info
Watch/                      watchOS app (recorder, upload queue, prompts, settings)
MacTests/                   XCTest unit tests
docs/CONTRACTS.md           module APIs shared by all of the above
docs/FEATURES.md            feature research and roadmap
docs/RESEARCH.md            market and platform research notes
scripts/bootstrap.sh        set up and generate the project
scripts/smoke-test-server.sh  exercise the Mac server with curl
```

Swift 5 language mode, no third-party packages; only system frameworks and
SQLite from the SDK.

---

## Roadmap

The MVP covers capture, transcription, search, insights, proactive questions,
digests, goals, memory chat and approved actions. The wider research behind
Earshot (100 candidate features across wearables, apps, Apple platform
constraints, coaching science and research prototypes, prioritised MVP / Next /
Later) is in [docs/FEATURES.md](docs/FEATURES.md).
