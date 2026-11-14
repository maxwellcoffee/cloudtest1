# Earshot — 100 features for an always-listening Apple Watch + Mac AI companion

Generated from the research sweep (wearables, software apps, Apple platform constraints, user needs & coaching science, research prototypes).
Priority: **MVP** = in or near the first working app, **Next** = the following release, **Later** = longer-term.
Scores are 1–5: value to the user, novelty, feasibility on watchOS/macOS today.

## Capture

### 1. One-tap Day Session with speech-only encoder  `MVP` · value 5 · novelty 2 · feasibility 4 — ✅ built: Partly: one tap starts all-day capture into 16 kHz AAC chunks; near-silent chunks are dropped on the watch. No speech-only encoder yet.

Start one capture in the morning with a single tap. It keeps running wrist-down with the orange mic indicator, but only speech is ever encoded and stored, so a full day costs tens of MB and little radio time.

*How it works:* The session is started in the foreground by the user (AVAudioSession .record, AVAudioEngine input tap at 16 kHz mono), which is the only sanctioned keep-alive. The engine is never stopped during silence, because a stopped recording cannot be restarted from the background (forum 750432). A two-stage gate runs on the tap: an RMS/zero-crossing pre-gate, then a small quantized Core ML VAD with 300 ms pre-roll and 500 ms hangover. Silent buffers are dropped in RAM. AVAudioConverter writes AAC at 24-32 kbps into 2-minute chunk files, each with a JSON sidecar of wall-clock speech intervals. No HKWorkoutSession or extended-runtime keep-alive is used (guidelines 2.5.1 and 2.5.4).

*Inspired by:* Bee founders' VAD-ASR-LLM pipeline; Apple DTS/WWDR forum guidance; Granola's Watch background recording

### 2. Chunk ledger: nothing is deleted until the Mac confirms  `MVP` · value 5 · novelty 2 · feasibility 5 — ✅ built: Built: chunks wait in an on-disk queue and are deleted only after the Mac acknowledges them; the watch shows queued count and last sync.

Each 2-minute chunk shows its stage (Saved, On iPhone, On Mac, Transcribed), and the complication shows how many minutes are still pending. A failed upload can never wipe out a day.

*How it works:* The watch keeps a SQLite ledger of chunk IDs, SHA-256 hashes and sidecars. The primary path is WCSession.transferFile to the iPhone companion, watching outstandingFileTransfers and retrying on failure. The iPhone forwards chunks to the Mac over the Network framework (Bonjour plus TLS on the LAN), or to a CloudKit private-database CKAsset when away from home. Fallback: a background URLSession from the watch over Wi-Fi or LTE. The watch itself can't use Bonjour or sockets (TN3135). The Mac verifies hashes and sends ACKs back through applicationContext, and only ACKed chunks are purged. A Repair action re-requests missing IDs. Background refreshes stay within the budget of 4 per hour.

*Inspired by:* Omi's lost ~11 h Watch recording; Granola's sync states and 'Waiting to sync' list; DTS note that background transfers can be deferred

### 3. Interruption catcher with one-tap resume and honest gaps  `MVP` · value 5 · novelty 3 · feasibility 4 — ✅ built: Built: calls and Siri close the chunk with a reason, a notification asks you to reopen, and recording resumes when the app is opened.

When a phone call, Siri or another audio app stops capture, the watch taps once ('Capture stopped at 2:14, tap to resume') and the complication turns into a Resume button. The Mac timeline marks the gap, so no summary invents what was said during it.

*How it works:* The app observes AVAudioSession.interruptionNotification and route changes. On .began it finalizes the chunk with gap_start and a reason. On .ended it posts a .timeSensitive notification with a foreground Resume action; tapping it brings the app frontmost, so the restart is user-initiated, as watchOS requires. WidgetCenter switches the complication to a red Resume state, and WKHapticType.retry plays once. Summaries receive explicit [GAP 14:14-14:31 phone call] tokens with an instruction never to bridge them.

*Inspired by:* Apple forum 750432 (no background resume); Granola can't resume interrupted recordings; Fieldy review: no alert on disconnect

### 4. Capture profiles with an honest battery forecast  `MVP` · value 5 · novelty 2 · feasibility 4 — ✅ built: Partly: the Record page shows an estimate of battery hours left at the current drain and a tip when it will not last the evening. No capture profiles yet.

Choose All-day light, Meeting (full fidelity) or Voice notes only. The watch shows the estimated capture hours left, measured on your own watch, and drops to a lighter profile at low battery instead of dying at 6 pm.

*How it works:* Each profile sets the VAD threshold, hangover, bitrate (16-32 kbps) and transfer batching. With WKInterfaceDevice.isBatteryMonitoringEnabled on, the app samples batteryLevel every 5 minutes to learn the drain rate of each profile on this device. An accessoryCircular complication shows projected hours left. Below a user-set threshold the app steps down to voice-notes-only with one haptic. Onboarding states that Series 12 is rated at 24 h for all use and shows the user's own measured rates, not vendor claims.

*Inspired by:* Battery complaints about Limitless, Humane and Rabbit; Bee and Fieldy market on battery life

### 5. Press-and-hold voice notes and ask mode  `MVP` · value 5 · novelty 2 · feasibility 5 — ✅ built: Partly: Ask, Do and Note from the wrist through dictation. No press-and-hold capture.

Hold the in-app button, or Double Tap, to dictate a thought, task or question tagged #idea, #task, #journal or #ask. A haptic tick confirms, and the cleaned-up text comes back to your wrist so you can check it.

*How it works:* If a Day Session is running, the note uses that engine; otherwise the button starts a recording in the foreground. The note goes out at high priority via WCSession.sendMessageData, falling back to transferFile. Transcription runs on the iPhone (SpeechTranscriber, iOS 26) or the Mac, never on the watch, which has no Speech APIs. Tags come from a spoken prefix or a picker. An on-device AFM @Generable router sends the note to Notes, Reminders or a Claude query, and the result returns as a notification.

*Inspired by:* Pebble Index 01, Sandbar Stream, Plaud, Just Press Record, Monologue Notes

### 6. Wrist bookmarks that teach the app what matters  `MVP` · value 4 · novelty 3 · feasibility 5 — ✅ built: Built: a Mark button (and Double Tap on watchOS 11+) bookmarks the moment; bookmarked moments are weighted in analysis.

Double Tap during a conversation drops a 'this matters' bookmark. The whole surrounding conversation, not a fixed 30 seconds, gets a title, is exempt from auto-expiry and is quoted verbatim in the recap.

*How it works:* A bookmark is a wall-clock timestamp, plus an optional 3-second spoken tag taken from the running engine, written to the sidecar and sent via transferUserInfo. WKHapticType.click confirms it. Triggers are .handGestureShortcut(.primaryAction) or a complication. On the Mac, the bookmark expands to topic boundaries, found where sentence-embedding similarity drops, combined with diarization turns. In a later release, bookmark history trains an on-device Create ML salience classifier that ranks search results, recap items and retention.

*Inspired by:* Plaud's press-to-highlight; jock.pl: only ~10% of 10 GB of Limitless audio was valuable

### 7. Rewind for any watch, plus keep the last 2 minutes  `Next` · value 4 · novelty 3 · feasibility 3

A complication tap shows the last 30-60 seconds as text on your wrist within a few seconds. It works on Series 9 and Ultra 2 and later, not only Series 12, and in more languages than English. A second tap keeps the previous 2 minutes and whatever follows.

*How it works:* A 120-second ring buffer of PCM audio (~3.8 MB at 16 kHz mono) lives only in RAM, fed by the input tap, and is never written to disk unless kept. On request, the last 30-60 seconds are AAC-encoded and sent via WCSession.sendMessageData. The iPhone transcribes them (SpeechTranscriber, or WhisperKit for other languages) and returns text with numbers and addresses highlighted by NSDataDetector. Unsaved text is deleted after 30 seconds, matching Apple's norm, and an on-screen indicator shows while it's active. Entry points are a complication, Double Tap, or a Shortcut on the Ultra Action button, never the Crown double-press Apple uses for Live Rewind. If the iPhone is unreachable, the watch shows 'queued'.

*Inspired by:* Apple Live Rewind (15 s, Series 12/Ultra 4 only, English only)

### 8. Meeting-aware Smart Stack starter  `Next` · value 4 · novelty 3 · feasibility 4

Two minutes before a calendar event with attendees, or when you arrive at a saved place, a Smart Stack card asks 'Record Design review? 4 people'. One tap starts a full-fidelity segment tagged to that event.

*How it works:* The card is a relevance widget (watchOS 26 date and location relevance), built on the iPhone from EventKit events that have attendees. Button(intent:) runs a StartCaptureIntent with openAppWhenRun, because recording has to start in the foreground. The event identifier goes into the sidecar, so the Mac knows the attendees for speaker naming and picks the right summary template.

*Inspired by:* Granola Apple Watch app; Siri Recap time/location schedules; Fathom/Granola calendar-driven notes

### 9. Bot-free Mac call capture with consent helper  `Next` · value 5 · novelty 2 · feasibility 4

The Mac detects Zoom, Meet, Teams and Slack calls and records them without a bot joining. You choose notify, manual or auto recording, and one click posts a disclosure line into the meeting chat.

*How it works:* Calls are detected from NSWorkspace running apps plus mic-in-use state. Per-app audio is captured with Core Audio process taps (CATapDescription and AudioHardwareCreateProcessTap into an aggregate device; macOS 14.2+; requires NSAudioCaptureUsageDescription, a system-audio permission rather than Screen Recording), alongside the Mac mic. After approval, the disclosure text is placed in the meeting chat via Accessibility or AppleScript. Call transcripts go into the same timeline as the watch audio.

*Inspired by:* Plaud bot-free desktop capture (Mar 2026 beta); Otter botless Mac capture; Granola

### 10. Battery glide path to bedtime  `Next` · value 4 · novelty 4 · feasibility 4

Tell the app 'I need my watch until 10:30 pm', or let it learn when you usually charge. It plans the day's capture to arrive with about 15% left, shows 'on track' or '40 min short', and lowers fidelity gradually.

*How it works:* A controller on the watch uses the learned drain rate of each profile (#4) and EventKit, so upcoming meetings keep their full-fidelity budget. It turns knobs in this order: raise the VAD threshold, cut bitrate from 32 to 16 kbps, batch transfers into fewer radio wakes, keep only the RAM ring buffer between events, and finally keep only near-field (wearer) speech. The Mac fits a drain curve for each user and syncs the coefficients back via applicationContext.

*Inspired by:* original

### 11. Desk-mode handoff to the Mac mic  `Later` · value 3 · novelty 5 · feasibility 3 — ✅ built: Partly: the Mac microphone can record into the same pipeline (desk mode). No automatic handoff from the watch.

When you sit down at your unlocked Mac, the Mac takes over room capture and the watch goes nearly idle, saving hours of battery on desk-heavy days. When you walk away, the watch picks encoding back up with no gap.

*How it works:* The Mac detects presence from an unlocked session plus recent input (CGEventSourceSecondsSinceLastEventType). It signals the iPhone on the LAN, which relays to the watch with WCSession.sendMessage. The watch keeps AVAudioEngine running, because it cannot restart from the background, but stops encoding and transfers and keeps only the RAM ring. The Mac records with AVCaptureDevice. Clock offsets in both sidecars let the merge trim any overlap. The watch takes back over when the Mac has been idle for more than 3 minutes or the lid closes.

*Inspired by:* original

### 12. Motion-fused VAD that ignores sleeve rub and wind  `Later` · value 3 · novelty 4 · feasibility 3

The watch learns to tell speech from a sleeve brushing the mic, typing, or wind while you walk, so battery and Mac processing go only to real voices.

*How it works:* During capture, CMMotionManager samples the accelerometer at about 25 Hz. Frames are rejected before the Core ML VAD runs when broadband mic bursts line up with sharp wrist acceleration, show high spectral flatness, and have no pitch track in the 80-300 Hz voice band. CMMotionActivity states (walking, cycling) shift the thresholds and turn on a wind high-pass filter. Chunks where the Mac's ASR finds no words become negative examples, and the Mac fits a per-user threshold and sends it back.

*Inspired by:* original

## Understanding

### 13. On-Mac transcription engine  `MVP` · value 5 · novelty 2 · feasibility 5 — ✅ built: Built: Apple SpeechAnalyzer on macOS 26, Apple Speech on older macOS, or any Whisper-compatible API.

All watch audio is transcribed privately on your Mac, or on your iPhone when the Mac is away, with word-level timestamps and fast enough to clear a whole day in minutes. Cloud transcription is off by default.

*How it works:* The primary engine is SpeechAnalyzer/SpeechTranscriber (macOS 26, long-form preset with .audioTimeRange), with models managed by AssetInventory. It isn't available on watchOS, so transcription always happens off the wrist. WhisperKit (large-v3 turbo) is the fallback for unsupported languages and for vocabulary prompting, since SpeechAnalyzer lacks custom vocabulary. Reference speeds: a MacStories test transcribed 34 minutes in 45 s, and Argmax's earnings22 benchmark shows SpeechTranscriber at WER 14.0 and 70x real time. Jobs run in a background XPC service with progress shown in the ledger.

*Inspired by:* Yap (SpeechAnalyzer), MacWhisper 14, Argmax benchmarks

### 14. Me-vs-others voice enrollment and diarization  `MVP` · value 5 · novelty 2 · feasibility 4

A 60-second voice enrollment means transcripts reliably say 'You' versus everyone else from the first day. Recurring voices you choose to name get labels, and you fix a wrong label by dragging the segment onto the right person.

*How it works:* Enrollment embeds read-aloud prompts with Argmax SpeakerKit (pyannote community-1) or FluidAudio, and stores the centroid under a Keychain-protected key. For each conversation, offline diarization (pyannote plus VBx) is aligned to SpeechTranscriber's audioTimeRange runs. Clusters are matched to profiles by cosine similarity with an abstain threshold, so an unknown voice stays 'Speaker 3' instead of being guessed. Corrections update centroids with a capped running mean. Lasting profiles for other people require their consent (#80).

*Inspired by:* Weak diarization at Limitless, Bee, Pocket and Granola; Apple does none

### 15. Media, liveness and scene filter  `MVP` · value 5 · novelty 3 · feasibility 4

TV dialogue, podcasts, songs and videos are labeled 'media you heard' and kept out of your facts and to-dos. Transcripts also get scene tags (car, cafe, laughter, music) that make them easier to search.

*How it works:* Each chunk is analyzed on the Mac with SoundAnalysis SNClassifySoundRequest(classifierIdentifier: .version1) for music, singing, laughter and vehicles, and with ShazamKit to match catalogued songs. Liveness checks look for turn-taking with the wearer, broadcast-style loudness compression (low crest factor) and near-field wearer energy. Segments scored as media are excluded from commitment and fact extraction and appear only as an optional 'Watched/heard' line in the recap.

*Inspired by:* Verge's Bee review (TV and songs treated as conversation); Fieldy pulled tasks from podcasts

### 16. Multilingual router with per-speaker model choice  `Next` · value 5 · novelty 3 · feasibility 4

Spanish, German, Hindi and mixed-language conversations are transcribed in their own languages, with optional side-by-side translation. If one person's accent trips up the default model, their turns go to whichever model does best for them.

*How it works:* On the Mac, WhisperKit language ID runs on the first 5 s and is re-checked every few seconds to catch code-switching. Routing: SpeechTranscriber for the locales it supports (only a few can be allocated at once), FluidAudio Parakeet TDT v3 for 25 European languages (ANE-only; Swift 5.10, so it lives in its own non-Swift-6 module), and WhisperKit for everything else. For each opt-in voice profile, the app tracks correction rates per model and pins that speaker to the best one. Translation uses Apple's Translation framework, and the original text is always kept for exact quotes.

*Inspired by:* Apple Audio Intelligence is English-only and not in the EU; Plaud's 112 languages; MacWhisper 14

### 17. Names from context, confirmed with one tap  `Next` · value 4 · novelty 4 · feasibility 4

The app works out who 'Speaker 2' is from what was said ('Thanks, Priya'), the calendar invite and your contacts, then asks once at a quiet moment: 'Was the second voice at lunch Priya Shah?'

*How it works:* Evidence is combined on the Mac: vocatives and self-introductions pulled out by an AFM @Generable schema over windows that fit its 4K context, EventKit attendees of overlapping events, CNContactStore for spelling, and meeting-app participant names via the Accessibility API for tapped calls. Each voice cluster gets a score. The app asks only when its confidence is above 0.7 and the voice has appeared in at least 2 conversations, using a passive notification with Yes / No / Someone else.

*Inspired by:* Fireflies/Otter map speakers to meeting participants; inferring names from in-person speech is new

### 18. Auto-harvested personal lexicon with respelling  `Next` · value 4 · novelty 3 · feasibility 4

Coworkers' names, product codenames and street names are spelled correctly within the first week, and each correction you make also fixes older transcripts.

*How it works:* Terms are harvested from Contacts, EventKit titles and attendees, Spotlight recent file names (NSMetadataQuery) and your edits. WhisperKit is biased with a decoder prompt holding the top relevant terms. SpeechTranscriber has no custom vocabulary, so a post-ASR pass matches low-confidence tokens against the lexicon by phonetic distance (Double Metaphone plus edit distance). A correction triggers a background respell across history and the search index. The lexicon syncs to the iPhone for Rewind text.

*Inspired by:* Wispr Flow / Superwhisper dictionaries; Argmax note that SpeechAnalyzer lacks custom vocabulary

### 19. Time anchoring and cross-conversation entity resolution  `Next` · value 4 · novelty 3 · feasibility 4

'Let's do it next Tuesday', said on a Thursday, resolves to the right date even if it is processed on Sunday, and 'she'll handle it' resolves to the actual person. Every extracted item shows the original sentence and when it was said.

*How it works:* Each chunk carries an absolute wall-clock time from its sidecar. NSDataDetector plus an AFM date normalizer resolve relative dates against when the words were spoken, and flag vague ones like 'end of the month' for confirmation. One claude-haiku-5-5 coreference pass per episode, over pseudonymized text (#73), builds an entity table mapping mentions to Contacts and Calendar IDs. Every output object carries source_span_ids so the UI can cite it.

*Inspired by:* Rosebud recalls topics better than dates; AI-scribe RCT pronoun errors

### 20. Addressee detection: who was that sentence for?  `Later` · value 4 · novelty 5 · feasibility 3

Tells apart a sentence said to a colleague ('I'll send it Friday'), to yourself ('ugh, call the dentist') and to the assistant ('remind me to...'). Actions go to the right place without a wake word, and private musings never become fake promises.

*How it works:* For each utterance by the wearer, the app gathers features: second-person pronouns and vocatives, imperatives, whether another speaker replied within 3 s, and prosody (self-talk tends to be quieter, with a narrower pitch range). An AFM @Generable enum classifies it as {toPerson(name), toSelf, toAssistant, unclear}. Unclear cases go to claude-haiku-5-5 with 2 minutes of context. Routing: toAssistant goes to the action inbox, toPerson to the promise ledger, and toSelf to a private note.

*Inspired by:* original

## Memory & Recall

### 21. Offline hybrid search that still works in month three  `MVP` · value 5 · novelty 2 · feasibility 5 — ✅ built: Partly: local SQLite full-text search over every utterance. No embeddings yet.

'What did the contractor say about the deck, sometime in August, at the house' finds the exact passage even when the wording differs. Filter by person, place, date, language or scene, fully offline.

*How it works:* Search combines SQLite FTS5 (BM25) with on-device embeddings (NLContextualEmbedding or a small Core ML encoder) stored in sqlite-vec, merged by reciprocal-rank fusion. Facets include speaker ID, place, EventKit event, scene label and bookmark. An AFM @Generable query parser turns natural phrasing into filters such as date range, person and place. Results open on the cited span with a playable clip while the audio is still kept. Spans are also indexed in Core Spotlight.

*Inspired by:* jock.pl after 6 months of Limitless: 'fancy transcription service with a mediocre search'; Rewind's 'where did I see it' search

### 22. Chat with your memory on the Mac, with citations  `MVP` · value 5 · novelty 2 · feasibility 5 — ✅ built: Built: the Ask tab answers from your transcripts with time-stamped quotes.

Ask anything about your days and get answers that cite the conversation, speaker, timestamp and audio clip. You can scope a question to a person, project or week, and if nothing was recorded at that time, it says so instead of guessing.

*How it works:* Spans retrieved by #21 and pseudonymized by #73 go to claude-opus-5-5 via POST /v1/messages (anthropic-version 2026-10-21, streaming, effort low or medium, no temperature parameters). The response is a structured output {answer, span_ids}, and an answer with no supporting span becomes 'not found / not recorded'. A capture-coverage table tells 'never said' apart from 'not captured'. The client handles stop_reason 'refusal' and opts into the server-side fallback beta.

*Inspired by:* Limitless/Omi 'Ask', Granola/Otter chat

### 23. Ask My Day from the wrist  `Next` · value 5 · novelty 2 · feasibility 4 — ✅ built: Built: ask from the wrist and the answer comes back as a prompt on the watch.

Raise your wrist and ask 'What did Priya say about the launch date?' You get a two-line answer with the speaker, time and place, plus an Open on Mac link.

*How it works:* The question comes from watch dictation or an App Intent exposed to Siri. It goes to the iPhone with WCSession.sendMessage, which wakes the iPhone app. The iPhone relays it to the Mac over the LAN, or queries an encrypted copy of the index synced through CloudKit (CKRecord.encryptedValues) when the Mac is away. The top 8 spans go to claude-haiku-5-5 with a strict schema {answer, span_ids}. On OS 27 the iPhone can call Claude through ClaudeForFoundationModels with App Attest, so no API key ships in the app. Handoff (NSUserActivity) opens the exact span on the Mac. Target latency is under 4 s.

*Inspired by:* Limitless/Omi Ask; Siri Recap keeps no transcript to query

### 24. Verbatim verification view with proof clips  `Next` · value 4 · novelty 3 · feasibility 5

For 'did I really say 6 pm?' moments, the app shows the exact transcript with low-confidence words and uncertain speaker labels highlighted, plays the audio with one click, and can re-transcribe the passage with a bigger model and show the diff. Uncertain names, numbers and negations can't become facts until confirmed.

*How it works:* The app stores word timestamps and confidences (SpeechTranscriber attributes or WhisperKit token log-probs) along with diarization posteriors, and renders them as an AttributedString heatmap. AVAudioPlayer plays from the clicked word. Critical spans (NLTagger names, NSDataDetector dates and numbers, not/never) with low confidence are re-run through a second model (Parakeet or Whisper large-v3) and combined ROVER-style. Where the models disagree, the span is wrapped in <uncertain> tags in extraction prompts. Audio is kept for a user-set verification window, 30 days by default.

*Inspired by:* Criticism of Bee and Apple for discarding audio; UCLA AI-scribe RCT; MacWhisper 14 editor

### 25. Living fact cards with contradiction detection  `Next` · value 4 · novelty 4 · feasibility 4

An editable list of what the app knows about you and the people in your life, each fact with its source quote, date and confidence. When 'Sam lives in Austin' conflicts with 'Sam just moved to Denver', the app asks which is true instead of quietly keeping both.

*How it works:* Facts are stored as bitemporal triples (subject, predicate, object, valid_from, recorded_at, span_id, confidence), extracted with Claude structured outputs. When a fact is added, a claude-haiku-5-5 judge labels it {same, update, contradiction, compatible}. An update closes the old fact's validity window and keeps the history. A contradiction opens a Mac review card with both quotes. Unconfirmed facts lose confidence with about a 180-day half-life and drop out of proactive features. At most one confirmation request per day goes to the watch.

*Inspired by:* original; grounded in Friend forgetting the user's name and Bee's user-confirmed facts

### 26. Life scrubber timeline  `Next` · value 4 · novelty 3 · feasibility 4

A zoomable Mac timeline, from a whole year down to a minute, with lanes for conversations by person, calendar, places, workouts and capture coverage. Gaps show their cause, so an incomplete day never looks complete.

*How it works:* Built with SwiftUI Canvas and semantic zoom. Lanes come from diarized segments, EKEventStore, iPhone CLVisit places (with points of interest from MKLocalSearch), HealthKit workouts relayed from the iPhone, and the sync ledger's coverage and interruption reasons. Waveforms are drawn with AVAudioFile and vDSP. J/K/L keys scrub. Blocks are indexed with CSSearchableItem so Spotlight can find 'lunch with Dana'.

*Inspired by:* Rewind timeline (capture shut down Dec 2025); Screenpipe timeline

### 27. Recommendations ledger  `Next` · value 4 · novelty 4 · feasibility 5

Every book, show, restaurant, app or doctor someone recommends goes into a 'To try' list with who recommended it and their exact words. Later you can ask 'who told me about that podcast?', and after you try something the app offers to help you thank them.

*How it works:* Each night an on-device AFM @Generable classifier flags candidate spans, and claude-haiku-5-5 extracts {category, name, recommender_speaker_id, quote_span}. Items heard from media (per #15) go to a separate list. Enrichment sends only the item's name, never personal context, to MKLocalSearch or MusicKit. Items sync to an EventKit Reminders list 'To try' with a deep link back to the span.

*Inspired by:* original

### 28. Where did I put it?  `Later` · value 3 · novelty 4 · feasibility 5

Say 'passport's in the blue folder in the closet' or 'parked on level 3, B7', and later ask your wrist 'where's my passport?'

*How it works:* An AFM @Generable classifier tags placement statements in the wearer's own speech as {object, location, time}. They're stored as fact triples, with newer placements replacing older ones. Retrieval goes through Ask My Day (#23). Parking-type statements also save the iPhone's CLLocation at that moment and expire after 48 hours.

*Inspired by:* original

### 29. Place memory: 'last time you were here'  `Later` · value 3 · novelty 5 · feasibility 4

Conversations are tagged with real places. When you return somewhere a meaningful conversation happened, a Smart Stack card quietly surfaces it: 'Last time here with Dana: she recommended the khao soi.'

*How it works:* The iPhone tags segments using CLVisit and CLMonitor, and MKLocalSearch resolves the point of interest. CLMonitor CircularGeographicCondition watches the 20 most meaningful places, rotated over time. On arrival, the iPhone sends context via transferUserInfo and reloads a relevance widget, with no haptic. claude-haiku-5-5 writes the one-line recap from cited spans. Home, medical places and user-excluded places never trigger.

*Inspired by:* original

## Summaries & Insights

### 30. Evidence-linked daily recap and morning brief  `MVP` · value 5 · novelty 2 · feasibility 5 — ✅ built: Built: daily digest (summary, highlights, promises, goals, patterns, a reflection question, suggestions) and a weekly review, also sent to the watch.

At wind-down time, the Mac (and a short watch version) lists the day's key conversations, decisions, open loops and people seen, each bullet linked to its source. A coverage meter shows how much of the day was actually captured, and each morning the watch shows today's commitments.

*How it works:* Per-conversation summaries run on AFM (chunked to fit its 4K context) or claude-haiku-5-5. Day synthesis uses claude-opus-5-5 with structured outputs {bullets:[{text, span_ids}]}. Coverage compares captured minutes with awake minutes, using HealthKit sleep data relayed from the iPhone and gap reasons from the ledger. Media is excluded (#15). The recap arrives as a passive notification at the learned wind-down time, and the brief as a morning Smart Stack widget. Markdown export goes to Apple Notes, Journal and Day One.

*Inspired by:* Apple Siri Recap, Bee daily summaries, Omi daily recaps

### 31. Self-verifying summaries  `Next` · value 5 · novelty 4 · feasibility 4

Every summary is checked against its own sources before you see it. Unsupported claims are removed or flagged amber, and verified bullets get a badge.

*How it works:* Each output is split into atomic claims. Deterministic checks run first: numbers, dates and proper nouns must appear in the cited span, a quoted speaker must match the diarization label, and negations are compared. Then a claude-haiku-5-5 judge returns {supported, contradicted, not_in_source}. A contradicted claim is regenerated once and dropped if it fails again. Your 'that's wrong' taps are stored as labeled errors to track weekly precision. The gate runs before anything reaches the watch, the recap or the MCP server.

*Inspired by:* original; UCLA AI-scribe RCT; Apple paused notification summaries after the BBC error

### 32. Context templates and custom summary skills  `Next` · value 4 · novelty 2 · feasibility 5

Summaries adapt to the situation: 1:1, standup, lecture, doctor visit or sales call. The template is picked automatically from your calendar and location or chosen by you, and you can write your own skills in plain language.

*How it works:* A template is a prompt plus a JSON schema, stored as Markdown in the vault. Selection uses the EventKit title and attendee count, the place category, and an AFM classifier on the first window of the conversation. It runs on claude-haiku-5-5, or claude-opus-5-5 for long sessions, with structured outputs. The doctor-visit template applies sealed handling (#78).

*Inspired by:* Plaud templates/Skills; Bee Templates; Whisper Memos templates

### 33. Rewrite voice notes in your own style  `Next` · value 4 · novelty 2 · feasibility 5

Turn a ramble from your walk into an email, a social post or a journal entry in a style learned from your own writing, with an intensity slider and no invented content.

*How it works:* A style card is built from 10-20 sent emails or notes that you choose. claude-opus-5-5 rewrites the note with an instruction to keep every claim, and the verification gate (#31) confirms no new facts were added. Output goes to a Mail draft, Apple Notes or the clipboard.

*Inspired by:* AudioPen, Wispr Flow, Monologue

### 34. Topic storylines  `Later` · value 4 · novelty 4 · feasibility 4

Conversations about the same ongoing thing, such as the kitchen renovation, the job search or Dad's health, are stitched across weeks into a storyline page with decisions, numbers, open questions and the people involved.

*How it works:* Each night, segment embeddings are clustered with HDBSCAN on UMAP-reduced vectors, and new segments are assigned incrementally. claude-haiku-5-5 names clusters and merges near-duplicates. claude-opus-5-5 maintains a structured, cited storyline document that is updated only from new spans; these nightly runs use the Message Batches API at 50% cost. NSDataDetector traces amounts and dates, so 'budget $40k to $55k' is traceable. You can split, merge and rename storylines.

*Inspired by:* Bee's daily topic segments (no threading across days); Granola folders

### 35. Natural-language custom trackers  `Later` · value 4 · novelty 5 · feasibility 4

Type any pattern you want tracked, such as 'how often I apologize' or 'mentions of the Q1 deadline'. The app builds a tracker, checks it with you on past examples, and charts it nightly.

*How it works:* claude-opus-5-5 compiles the request into a spec {scope, prefilter keywords or regex, classifier_prompt, unit}. You label 15-20 sampled past spans, which gives a precision estimate. Nightly runs use on-device AFM yes/no classification on the prefiltered spans, so cost is near zero. Results appear in Swift Charts, in a Smart Stack widget and through an MCP tool.

*Inspired by:* original

## Life Progress & Coaching

### 36. Intention tracker and stuck-loop breaker  `Next` · value 5 · novelty 5 · feasibility 4 — ✅ built: Partly: goals you mention are captured, updated with progress notes and asked about.

The app notices things you keep telling yourself you'll do and whether they happen. When something has come up three or more times with no action, it offers one tiny first step with the setup already done.

*How it works:* claude-haiku-5-5 extracts intentions from the wearer's own speech as {intention, type, first_said, repeat_count}, and NLContextualEmbedding clusters repeats. Evidence of follow-through comes from later transcripts, HealthKit workouts relayed from the iPhone, completed EKReminders and attended events. A loop (3+ mentions over 5+ days, no evidence) triggers one question through the question gate (#44). If you say yes, Claude stages the smallest action behind a single Approve: open a folder with NSWorkspace, create a Mail draft via AppleScript, or add an EKReminder. A monthly card shows your kept-rate without judgment.

*Inspired by:* original; Gollwitzer & Sheeran 2006; Masicampo & Baumeister 2011

### 37. Spoken WOOP with cue-armed if-then plans  `Next` · value 5 · novelty 4 · feasibility 4

A 60-second voice conversation turns a confirmed goal into Wish, Outcome, Obstacle and Plan, and the plan's 'if' becomes a real trigger. When you leave the office or finish a workout, the watch taps you with your own if-then sentence.

*How it works:* claude-opus-5-5 at effort low runs the MCII dialog in short turns. The cue is compiled into a deterministic trigger: a CLMonitor geofence, an EKEvent end time, an HKObserverQuery for workout completion on the iPhone, or a time of day. The notification body is your plan word for word. Yes/no adherence is logged on the wrist.

*Inspired by:* WOOP app (static text); MCII and implementation-intention meta-analyses

### 38. Decision journal with outcome follow-ups  `Next` · value 4 · novelty 5 · feasibility 4

Decisions you make out loud are logged with the alternatives and your reasons in your own words, plus a one-tap confidence rating. At 1, 3 and 12 months the watch asks how each turned out, building a chart of how well your confidence matched what happened.

*How it works:* An AFM classifier spots decision statements, and claude-opus-5-5 extracts {decision, alternatives, rationale_spans, expected_outcome}. A Crown picker records confidence from 50 to 100%. The Mac schedules review questions through the question gate (#44) at natural breaks. The calibration view shows a Brier score and reliability curve, and 'why did we choose X?' search runs on the memory index.

*Inspired by:* original; Annie Duke-style decision journals exist only as manual templates

### 39. Weekly review co-pilot, delta only  `Next` · value 4 · novelty 3 · feasibility 5 — ✅ built: Partly: a weekly review with wins, themes, goal progress and if-then plans.

A 10-minute weekly review that reports only what changed: new topics, numbers that moved, loops that closed, promises going stale. It ends with a plan for next week that you approve as one calendar diff.

*How it works:* Daily structured extracts roll up overnight through claude-opus-5-5 on the Message Batches API at 50% cost. A novelty filter compares each item with the previous 4 weeks by embedding and by value. The output is a set of proposed EKEvent time blocks and EKReminders, shown as an add/move/delete diff before EventKit writes anything. An optional 60-second audio version uses AVSpeechSynthesizer.

*Inspired by:* GTD weekly review; Sunsama; Omi's meaningful-change rule

### 40. Spaced recall for advice and ideas  `Next` · value 4 · novelty 4 · feasibility 5

A mentor's advice, a lecture's key point, or your own shower-thought comes back at expanding intervals as a wrist quiz or Smart Stack card, so it sticks instead of sitting in an archive.

*How it works:* claude-haiku-5-5 flags advice, definitions and ideas spoken by the wearer, and a 'Keep this' App Intent adds items by hand. Each card is a question, a cloze or your verbatim idea, linked to its span. Scheduling uses FSRS with a horizon you choose. The notification shows the question, Double Tap reveals the answer, and the Crown rates how well you recalled it, at most 2 cards a day at natural breaks. 'Develop' sends an idea to Apple Notes as an outline via AppleScript.

*Inspired by:* Anki/FSRS, Readwise, Memoro (CHI 2024); Cepeda et al. 2008

### 41. Values-vs-time mirror  `Later` · value 4 · novelty 5 · feasibility 4

Rank what matters to you once. Each week you see how your conversation and calendar time actually split across those areas, with one non-judgmental question when a top value goes quiet.

*How it works:* Onboarding is an ACT-style values card sort on the Mac. Each segment is labeled on-device with an AFM @Generable LifeDomain, and only the label, duration and participant count are kept. EventKit events are labeled the same way. Swift Charts compares each value's rank with its share of time. If a top-2 value stays below its 8-week baseline for 2 weeks, the weekly review gets one question with a calendar hold already drafted.

*Inspired by:* original; Acceptance and Commitment Therapy values work

### 42. Conversation dynamics mirror and skills gym  `Later` · value 4 · novelty 4 · feasibility 4

Private analytics on how you converse: talk share, interruptions, questions asked, pace and filler words, by person and context. Optional two-week skill sprints, such as 'ask before advising', build on them.

*How it works:* Computed on the Mac from diarized, word-timestamped transcripts. Metrics: talk share, overlaps where the wearer starts speaking over someone, question rate (AFM classifier), words per minute and filler rate. Other people's speech is used only for timing, never content. A passive card shows the micro-goal before a meeting, a score card arrives at the next break afterward, and Swift Charts compares baseline with now. Feedback targets the behavior, not the person.

*Inspired by:* Gong/Chorus, Teams Speaker Coach, Yoodli/Poised; Kluger & DeNisi 1996

### 43. Automaticity habit tracker, no fragile streaks  `Later` · value 4 · novelty 4 · feasibility 4

Habits are tracked from passive evidence (workouts, mindful minutes, saying 'just finished guitar practice', app usage) plus a monthly four-question automaticity check on the Crown. You see a habit-strength curve instead of a streak that resets after one bad day.

*How it works:* Evidence sources: HKWorkout and mindfulSession data relayed from the iPhone, app activations on the Mac (NSWorkspace), and AFM tags on the wearer's own reports, confirmed by tap for the first few times. Once a month you answer the 4-item SRBAI on the Crown. Each habit gets an asymptotic curve fit, and a missed day shows as 'never miss twice' rather than a reset.

*Inspired by:* Streaks/Habitica; Lally et al. 2010

## Proactive Questions

### 44. Value-of-information question gate  `MVP` · value 5 · novelty 4 · feasibility 4 — ✅ built: Built: every question must say which decision it unlocks, or it is dropped.

The AI may ask you something only if your answer would change what it does next, and it has to name that action. Everything else gets a sensible default logged under 'Assumptions I made', so most days bring zero to two questions.

*How it works:* Each candidate question is a record {decision_unlocked, options, default_if_unasked, stakes, deadline}, and questions without decision_unlocked are rejected in code. claude-haiku-5-5 scores the chance the answer changes the action, times stakes and urgency, minus interruption cost and a penalty for recently asked topics. The daily budget starts at 2, shrinks after ignored prompts, and never exceeds your cap. Questions that aren't asked fall back to their defaults, which you can see and correct on the Mac.

*Inspired by:* original; Omi founder: 'The hardest part was to nail proactivity'; HN 'micromanager in a box'; Friend's unprompted texts

### 45. Conversation-boundary delivery  `MVP` · value 5 · novelty 4 · feasibility 4 — ✅ built: Built: questions wait for quiet hours to end, for conversation to pause and for calendar meetings to finish, with daily caps and minimum gaps.

Nudges never arrive while you're talking or listening. They wait for a natural break, such as a conversation ending, standing up to walk or a calendar gap, and they respect quiet hours and a daily cap.

*How it works:* The watch's running input tap gives a local 'in conversation' state from the VAD. Breakpoints: at least 2 minutes of silence after at least 5 minutes of speech, CMMotionActivity changing from stationary to walking, or an EKEvent ending. Non-urgent items are batched into 1-3 small decks a day. The interruption level is .passive by default and .timeSensitive only for commitments with deadlines. Quiet hours and per-category toggles apply, following the HIG rule against repeat notifications. Later, a receptivity model trained on the Mac tunes the thresholds.

*Inspired by:* JITAI (Nahum-Shani 2018); Adamczyk & Bailey on breakpoints; Omi rate limits

### 46. Three-second wrist answers  `MVP` · value 5 · novelty 3 · feasibility 5 — ✅ built: Built: one-tap answer choices on the watch and in notification actions.

Every question can be answered in about three seconds without opening the app: Double Tap for yes, one of up to three buttons, a Crown scale or one dictated sentence. Every question also offers 'Don't ask about this', which is permanent.

*How it works:* Claude structured outputs force each question into one shape: binary, choice (3 options at most), scale or dictation. It is shown as a UNNotificationCategory with up to 4 actions, the HIG maximum, and Double Tap selects the first nondestructive action. Dictation uses UNTextInputNotificationAction, and scales use a custom long-look view with .digitalCrownRotation. 'Don't ask' writes a negative topic preference to the gate. Each answer and how long it took are logged.

*Inspired by:* Fieldy swipe-to-approve; Apple HIG notification rules

### 47. Wish ledger  `Next` · value 5 · novelty 5 · feasibility 4

The app notices when you say 'I've always wanted to learn to sail' or 'we should visit Grandma more' and keeps it as an unconfirmed wish. It asks once whether the wish is real, then makes it a goal or a Someday item that comes back at fresh starts like a new month or your birthday.

*How it works:* Claude extracts desire statements from the wearer's own speech as {type: wish/should/plan, object, repetition_count}; media and other people's speech are excluded. An unconfirmed wish expires after 30 days unless it comes up again. Within 48 hours the gate asks: Make it a goal (opens #37) / Someday / Just talk. Fresh-start dates come from Calendar and your Contacts card, and each item has a 'Why am I seeing this?' link to the original quote.

*Inspired by:* original; fresh-start effect (Dai, Milkman & Riis 2014); Bee's unsolicited 'Lactaid' inference

### 48. Editable nudge constitution  `Next` · value 4 · novelty 4 · feasibility 5

A short charter you write sets what the AI may nudge you about, how often and in what tone ('Never mention my weight. Two a day max. Blunt about work, gentle about family.'). You can amend it by voice, and once a month it proposes changes based on what you've been ignoring.

*How it works:* The charter is enforced two ways: deterministic rules in code (category allow and deny lists, quiet hours, a daily maximum, people never to mention) and tone text in the Claude system prompt. A spoken amendment becomes a proposed diff that you approve. The monthly card is built from dismissal statistics.

*Inspired by:* Pew 2025 (61% want more control over AI); Omi removed its automatic daily reflection notifications

### 49. Bystander-aware nudge privacy  `Later` · value 4 · novelty 4 · feasibility 3

When other people are around or you're in a meeting, a nudge shows only 'A note for later'. Anything about health, money or relationships waits until you're alone.

*How it works:* Presence is inferred from the watch VAD, other voices in recently processed audio on the iPhone, and the attendees of the current EKEvent. Each nudge carries a sensitivity tag. With others present, the alert body is redacted, the haptic is suppressed, and details appear only in the long look after a deliberate tap. Sensitive categories are held until a 'probably alone' break. Mac banners are held while you're in a call.

*Inspired by:* original; Apple HIG guidance on sensitive information in short looks

### 50. Personal nudge lab  `Later` · value 4 · novelty 5 · feasibility 4

The app runs a transparent experiment on its own nudges. It randomly sends or skips eligible ones and varies their wording and timing, then drops what doesn't help you. A 'What works for you' page shows the results with error bars.

*How it works:* At each eligible moment the app randomizes whether to send (p about 0.6) and which variant: question vs statement, with or without your own quote, and timing. Short-term outcomes come from data the app already has: steps in the next 30 minutes, a commitment closed within 24 hours, or habit evidence. Effects are estimated with the weighted, centered least-squares method from micro-randomized trials, then Thompson sampling once variants separate. A variant whose credible interval still includes zero after N exposures is dropped, and wear-off is tracked per variant. It is opt-in.

*Inspired by:* original as a consumer feature; HeartSteps (Klasnja 2019)

### 51. Hands-free spoken replies  `Later` · value 4 · novelty 5 · feasibility 3 — ✅ built: Built: "Say it" lets you answer out loud; the always-on recorder captures the answer window.

Answer a nudge out loud without raising your wrist ('yeah, tomorrow morning', 'not now'). A subtle haptic confirms what it understood, and only your enrolled voice counts as an answer.

*How it works:* When a nudge fires, the watch marks a 20-second reply window and sends that chunk right away via WCSession.sendMessageData. The iPhone transcribes it with SpeechTranscriber, checks it against your voice embedding (FluidAudio), and classifies the intent with AFM as {accept, snooze(date), decline, never, unclear}. The watch plays .success, or .retry when the reply was unclear. When the iPhone is out of reach, it falls back to buttons.

*Inspired by:* original

## Mac Actions & Automation

### 52. Blast-radius approval tiers with undo journal  `MVP` · value 5 · novelty 3 · feasibility 5 — ✅ built: Partly: actions are tiered low, medium and high risk with per-tier auto-approval. No undo journal yet.

Every proposed action is labeled by how much harm it could do, and that label decides where you approve it. Local, undoable actions take one wrist tap; anything that leaves your Mac needs the Mac review sheet; purchases and deletions need Touch ID. Every action has a timed Undo.

*How it works:* A fixed policy table, not the model, assigns tiers. T0 (read-only) runs automatically. T1 (EventKit reminder, tentative hold, Finder tag) is a watch notification with Approve first and a 10-minute Undo. T2 (send mail, calendar invite, Slack post) puts 'Review on Mac' as the first watch action, so Double Tap can never send. T3 (irreversible or financial) is Mac-only via LAContext .deviceOwnerAuthenticationWithBiometricsOrWatch. An append-only journal stores each action's inverse (EKEventStore.remove, delete the draft). Claude runs with tool_choice auto and strict tools, because forced tool_choice returns 400 on Opus 5.5.

*Inspired by:* Thin approval UX in Rabbit DLAM and Omi's desktop agent; HIG Double Tap semantics; the tiering scheme is original

### 53. Action inbox with batched wrist approval  `MVP` · value 5 · novelty 2 · feasibility 5 — ✅ built: Built: the Inbox lists suggested actions and questions; the agent sends approvals to the watch.

Commitments, dates and requests from your conversations become proposed reminders, calendar holds and drafts. They arrive as one batched card ('3 actions from your 2 pm meeting') to approve or dismiss on the wrist or the Mac.

*How it works:* claude-haiku-5-5 structured outputs extract {type, title, due (resolved against when it was said), people, span_id}. The owner comes from diarization, so other people's tasks and media lines don't become yours. Cards are batched at conversation breaks (#45). Approved items are written through EventKit: EKReminders in a dedicated list with a deep link back to the span, and tentative EKEvent holds. Unapproved items expire after 72 hours.

*Inspired by:* Fieldy swipe-to-approve; Bee Actions; Omi to-dos

### 54. Deterministic-first tool ladder  `MVP` · value 4 · novelty 3 · feasibility 4 — ✅ built: Built: the agent uses Reminders, Calendar, Notes, Mail drafts, Shortcuts and AppleScript before falling back to computer use.

The agent always tries the most reliable route first: native frameworks, then Shortcuts, then AppleScript, then the Accessibility tree. The approval card shows which route it used.

*How it works:* An ordered tool registry is exposed to claude-opus-5-5, 3-5 relevant tools per step: (1) EventKit, Contacts and NSWorkspace; (2) Shortcuts through the shortcuts CLI; (3) user-installed AppleScripts via NSUserAppleScriptTask from ~/Library/Application Scripts/<bundle-id>, or Apple Events with the automation entitlement; (4) AXUIElement actions after AXIsProcessTrustedWithOptions. Each rung returns a structured failure so the agent moves up exactly one rung. The app ships as a notarized Developer ID build, because Mac App Store sandboxing (2.4.5) blocks most of this.

*Inspired by:* Research guidance to prefer deterministic tools over pixel control; brittleness of Rabbit's LAM

### 55. Wrist-to-Mac voice commands  `Next` · value 4 · novelty 3 · feasibility 4 — ✅ built: Built: Do requests from the wrist run the Mac agent and report back.

Hold to say 'on my Mac, open the Q3 deck and start my focus playlist' or 'run my standup shortcut'. The Mac plans it, shows the steps on your wrist, and runs them after you approve.

*How it works:* A push-to-talk note tagged #mac (#5) is transcribed on the iPhone or Mac. claude-opus-5-5 at effort low plans it using the tool ladder (#54) and approval tiers (#52). If the Mac is asleep, the plan waits in a tray that opens when the screen unlocks (com.apple.screenIsUnlocked). The result comes back as a notification.

*Inspired by:* Rabbit R1, Omi desktop agent, Siri

### 56. Promise-to-deliverable assembler  `Next` · value 5 · novelty 5 · feasibility 4

'I'll send you the deck by Friday' becomes more than a to-do. The Mac finds the likely file and drafts the email to the right person with it attached, and on Friday morning your watch offers Send / Review on Mac / Snooze.

*How it works:* The commitment comes from the promise ledger (#61) as {owner, recipient, object, deadline, span}. The recipient is resolved through CNContactStore plus the attendees of the meeting where the promise was made. File candidates come from NSMetadataQuery (display name, last-used date, content match) and are ranked by claude-haiku-5-5. A Mail draft with the attachment is created via AppleScript, and the card arrives on the deadline morning. Sending is a T2 action, so it needs a Mac review unless you lower the tier for that recipient.

*Inspired by:* original

### 57. Computer-use fallback with replay  `Next` · value 4 · novelty 3 · feasibility 3 — ✅ built: Partly: optional Claude computer use with a step log and screenshots for each run.

When no API or script can do the job, the agent operates the app on screen. You get a slow-motion replay you can scrub, and the approval card carries a 'Used screen control' badge.

*How it works:* Uses Claude computer use through computer_toolset_20260801 (GA; results must echo toolset_name 'computer'). Frames come from ScreenCaptureKit SCScreenshotManager, downscaled to 1280x720 or 1024x768, the recommended desktop sizes (avoid anything above 1920x1080). It runs only for approved T1/T2 tasks, and each step's frame and action are saved to a local replay. Onboarding explains macOS Sequoia's monthly screen-recording re-prompt. It is disabled entirely in Local-only mode.

*Inspired by:* Claude computer use; Rabbit LAM; Screenpipe's accessibility-first approach

### 58. Scheduled agent pipes in Markdown  `Next` · value 4 · novelty 3 · feasibility 5

Define recurring jobs in plain Markdown, such as a standup update every morning, CRM notes after sales calls, or a Friday wins email to yourself. They run on your memory under your approval rules.

*How it works:* A pipe is a .md file in the vault holding a prompt, a schedule, the tools it may use and a maximum tier. A Mac scheduler (NSBackgroundActivityScheduler or a launchd agent) runs it with claude-opus-5-5 or claude-haiku-5-5 over retrieved spans. Outputs go to the action inbox and never run above their tier limit. Overnight jobs can use the Batch API.

*Inspired by:* Screenpipe pipes

### 59. Auto time-blocking for commitments  `Later` · value 4 · novelty 3 · feasibility 4

Approved promises with deadlines get realistic focus blocks on your calendar, sized by how long similar tasks took you before.

*How it works:* Duration is estimated from past similar commitments (embedding similarity plus completion times), with a buffer for the planning fallacy. Free slots come from EKEventStore. The proposal appears as a calendar diff of T1 tentative holds that you approve on the wrist, and blocks move when conflicts appear.

*Inspired by:* Reclaim/Motion (which see only calendar inputs); Buehler 1994 planning fallacy

### 60. Meeting stage-setter  `Later` · value 3 · novelty 3 · feasibility 4

Five minutes before a meeting, the Mac opens what you'll need (the doc you promised, the last notes with these people, the call link) as one approved 'set the stage' action.

*How it works:* Using the EKEvent attendees and people pages, claude-haiku-5-5 picks the relevant files (NSMetadataQuery), notes and URLs. They're staged as an open-only T0/T1 action through NSWorkspace, with a wrist card asking 'Set up for Design review?'

*Inspired by:* Dex/Clay meeting prep (without Mac actions)

## Relationships & Meetings

### 61. Two-way promise ledger  `MVP` · value 5 · novelty 3 · feasibility 5 — ✅ built: Built: promises are recorded both ways ("You promised" and "Promised to you") with the other person.

Promises are split into 'I owe' and 'Waiting on', each with the exact quote, person and due date. One batched card after a conversation lets you track, edit or dismiss them, and overdue 'Waiting on' items get a polite nudge draft.

*How it works:* Diarization assigns each promise's owner, so tasks other people say and podcast lines don't become yours. claude-haiku-5-5 extracts {owner, counterparty, action, due_text, span_id}, and NSDataDetector resolves due dates against when the promise was made. The card arrives at the conversation break with Track / Edit on Mac / Dismiss, and Double Tap picks Track. Approved 'I owe' items become EKReminders in a Promises list. Evidence closes items automatically: Mail Sent via AppleScript, a completed reminder, or a later 'sent it over'. At most 3 'Did this happen?' questions a day.

*Inspired by:* Fieldy/Bee/Omi to-do extraction; Omi's cap of 3 a day

### 62. Post-meeting follow-up drafter with off-the-record filter  `MVP` · value 5 · novelty 3 · feasibility 5 — ✅ built: Partly: suggested actions and the agent can draft follow-up emails in Mail; nothing is ever sent.

When a meeting ends, the app drafts a recap email in your style with decisions, owners and dates, and your watch asks 'Draft recap to 3 attendees?' Anything said off the record ('between us...') is left out automatically.

*How it works:* A meeting counts as ended at the EKEvent end time plus 2 minutes with no multi-speaker speech, or when the meeting app quits (NSWorkspace). claude-opus-5-5 drafts from a style card. An off-the-record classifier drops spans with verbal cues, and every item cites a span. The draft is created in Mail.app via AppleScript, or as a Gmail/Outlook draft. Sending is a T2 action and always needs explicit approval.

*Inspired by:* Fathom and Granola follow-up emails; Bee Actions

### 63. Voiceprint-linked people pages  `Next` · value 5 · novelty 3 · feasibility 4

Everyone you talk to regularly gets an auto-built page: when you last talked, time together, topics, facts they've shared, what you owe each other and what they recommended. A voice profile is used only with that person's consent; otherwise the page is built from names and calendar.

*How it works:* SpeakerKit/FluidAudio embeddings are clustered across conversations with centroid updates, names come from #17, and each person links to a CNContact. The page pulls together fact cards, the promise ledger, recommendations and storylines. Voiceprints are biometric data under GDPR Art. 9, so they stay on the Mac, carry a per-person consent flag, can be deleted per person, and are off by default where explicit consent is required.

*Inspired by:* Clay, Dex, Monica personal CRMs (manual entry)

### 64. Pre-meeting wrist brief with rolling 1:1 agenda  `Next` · value 5 · novelty 2 · feasibility 5

Ten minutes before a meeting or lunch, the watch shows what you last discussed with each attendee, what you owe each other, and one personal thing to ask about. Recurring 1:1s carry over unresolved items and flag themes that haven't come up in weeks.

*How it works:* The iPhone scans EKEventStore for events whose attendees match people pages, and claude-haiku-5-5 condenses each into 3 cited lines. Delivery is an active-level notification plus a relevance widget. Recurring two-person series are detected; the carry-over list comes from the promise ledger and decision journal, and AFM theme tags fill a coverage table. Handoff opens the full brief on the Mac.

*Inspired by:* Dex/Clay meeting prep; Fellow/Hypercontext rolling agendas

### 65. Room + remote meeting fusion  `Later` · value 4 · novelty 5 · feasibility 3

In a hybrid meeting, the watch's room audio and the Mac's call audio merge into one transcript ('Room: Priya', 'Remote: Jordan (Zoom)'), with no bot and no duplicated lines.

*How it works:* Remote audio comes from a Core Audio process tap on the meeting app, so it is already separated by source. Watch chunks are aligned to the Mac clock by GCC-PHAT cross-correlation (vDSP) against the Mac mic's room audio, correcting skew to tens of milliseconds. For each turn the merger keeps the source with the higher SNR. Remote voices the watch picked up from the laptop speakers are removed by matching against the tap stream. Remote names come from Accessibility participant lists where they are exposed.

*Inspired by:* original

### 66. Relationship drift radar  `Next` · value 4 · novelty 3 · feasibility 5

The app learns your natural rhythm with each close person and tells you when someone has drifted past their usual gap, with a hook from your last conversation. At most two suggestions a week, in the weekly review.

*How it works:* For each person, gaps between contacts are modeled from captured conversations and calendar events. Someone is flagged when the current gap exceeds the larger of 1.5x their median gap and their 90th percentile, and only for people in tiers you set. claude-haiku-5-5 writes the hook from cited spans. The action opens a Messages draft (an sms: URL on iPhone, AppleScript on Mac). Snooze and 'seasonal friend' options adjust the cadence.

*Inspired by:* Keep-in-touch reminders in Dex, Clay and Monica (manual cadence)

### 67. Life-event check-ins and gift ideas  `Next` · value 5 · novelty 4 · feasibility 5

When someone mentions surgery on the 12th or a job interview on Tuesday, you're reminded to check in the day after. Wishes they mention are saved as gift ideas and come back two weeks before their birthday.

*How it works:* claude-haiku-5-5 extracts {person, event, date, valence, sensitivity} from other people's speech, but only where their speech is retained under #70. Sensitive events stay on the Mac, and the watch short look says only 'Check in with Dana' (HIG). A passive morning card offers Draft / Done / Skip. Birthdays come from CNContact. At most one a day, and none for people tagged 'work only'.

*Inspired by:* original

### 68. Appreciation nudges  `Later` · value 4 · novelty 4 · feasibility 4

When someone helps you and the app sees no thank-you within a day or two, it sends one quiet nudge with a short thank-you drafted in your style.

*How it works:* Claude tags 'help received' events along with who helped. It then looks for thanks in later transcripts, in Mail Sent via AppleScript, and, if you grant Full Disk Access, in your outgoing Messages. If there's none after 24-48 hours, a passive nudge arrives at a break: Send draft (a T2 action via Messages or Mail after approval) / Did it in person / Skip. At most 2 a week.

*Inspired by:* raw idea 'You haven't thanked Mom yet'; Kumar & Epley 2018

### 69. Introductions matchmaker  `Later` · value 4 · novelty 5 · feasibility 4

The app notices when one person in your life needs what another offers ('we're hiring an iOS dev' / 'I just went freelance as an iOS dev') and suggests a double-opt-in introduction, at most once a week.

*How it works:* claude-haiku-5-5 extracts needs and offers for each person, only from what they said directly to the wearer. Each night, needs are matched to offers by embedding similarity, and a claude-opus-5-5 judge scores fit, recency and whether it's shareable, excluding off-the-record and sensitive spans. The Mac card shows exactly what would be shared, and drafts go to Mail or Messages for approval.

*Inspired by:* original

## Privacy & Trust

### 70. Wearer-only default with jurisdiction-aware consent scopes  `MVP` · value 5 · novelty 3 · feasibility 4

By default only your own words are kept verbatim. Other voices are kept only for people who have consented, or in settings you've allowed, and the defaults tighten automatically in all-party-consent states and in the EU and UK.

*How it works:* Mac diarization labels each turn as me, consented profile or unknown. For unknown turns, audio is deleted after processing and the text is replaced with a placeholder, or, if you enabled it in a one-party jurisdiction, a quote-free abstract. Jurisdiction comes from the iPhone's location (CLGeocoder). The 13 all-party states per Kilpatrick, the EEA/UK and Germany (§201 StGB) default to wearer-only. Onboarding explains the rules plainly and says it is not legal advice.

*Inspired by:* Nirva wearer-focused capture; Limitless help center; EDPB Statement 01/2026; Otter lawsuit

### 71. Pause zones and capture schedules  `MVP` · value 5 · novelty 3 · feasibility 4 — ✅ built: Partly: privacy pause for 15 minutes, an hour or until you resume. No zones or schedules.

Capture stops automatically at places, times and Focus modes you choose: the doctor's office, home after 9 pm, private calendar events, while headphones are playing. The watch tells you whether it's a soft pause (mic open, audio discarded) or a hard stop (mic off, tap to resume).

*How it works:* Triggers are CLMonitor CircularGeographicCondition geofences, SetFocusFilterIntent so any Focus can set the capture mode, EventKit private events, and a headphone output route (matching Apple's Recap rule). watchOS can't restart a recording from the background, so a soft pause keeps AVAudioEngine running but zeroes buffers before encoding; the orange mic indicator stays on and the status says so. A hard stop deactivates the session, and when you leave the zone a timeSensitive 'Resume?' notification offers a foreground action.

*Inspired by:* Siri Recap time/location schedules; Screenpipe recording schedules; EDPB geofencing recommendation

### 72. Visible recording signals and bystander privacy card  `MVP` · value 5 · novelty 2 · feasibility 5 — ✅ built: Partly: the system orange microphone indicator and a clear recording state on the watch.

A chime and haptic when capture starts, a distinct recording state on the watch face, and a 'Show card' screen with a QR code to a plain-language page about what is and isn't kept.

*How it works:* Start and stop play a short chime plus a WKHapticType.start or .stop haptic. In all-party jurisdictions the chime can't be turned off. The system orange mic indicator stays visible, which supports the recording indication that App Review 2.5.14 requires. A WidgetKit complication shows the live state. The card is a full-screen SwiftUI view with a QR code (CoreImage CIQRCodeGenerator) linking to a static privacy page.

*Inspired by:* Apple Live Rewind chime and animation; Limitless guidance that the LED alone is not enough

### 73. Local redaction and pseudonymization before the cloud  `MVP` · value 5 · novelty 4 · feasibility 4 — ✅ built: Built: e-mails, phone, card, IBAN and account numbers, SSNs and one-time codes are replaced locally before text goes to Claude.

Before any text reaches Claude, your Mac deletes passwords, one-time codes, card numbers and government IDs, and swaps names, numbers and addresses for placeholders. Claude reasons over '[PERSON_2] promised [ORG_1] the deck by [DATE_1]', and the Mac restores the real values locally.

*How it works:* Detection uses NLTagger(.nameType) plus Contacts matching for people, organizations and places; NSDataDetector for phones, addresses and dates; Luhn, IBAN and SSN patterns; and an AFM @Generable classifier for health, auth codes and self-harm language, mirroring Siri Recap's filter categories. Never-send categories are deleted, not tokenized. Placeholders stay consistent for a day, and the mapping is encrypted with a Keychain key that never leaves the Mac. Onboarding obtains the explicit permission for third-party AI that Guideline 5.1.2(i) requires.

*Inspired by:* Siri Recap sensitive-data filtering; enterprise DLP pseudonymization

### 74. Shutdown-proof local vault and open export  `MVP` · value 5 · novelty 3 · feasibility 5 — ✅ built: Partly: everything stays in a local SQLite database, and Export writes Markdown transcripts and JSON for all your data.

Your memories live in a folder on your Mac in open formats (Markdown, JSON and audio files) that stay readable without the app. Core features need no account, and one click exports to Obsidian, Apple Notes or Day One.

*How it works:* The vault is a SQLCipher database, a Markdown mirror per day, a documented and versioned JSON schema, and AAC audio, with the vault key in the Keychain. Optional sync between Macs uses a CloudKit private database with encryptedValues, so the vendor holds no copy. The license check fails open, and an MIT-licensed reader and the schema are published at launch.

*Inspired by:* Limitless regional shutdown and data deletion (Dec 2025); Humane Pins stopped working (Feb 2025); Screenpipe's local-first pitch

### 75. Data-flow dial and egress receipts  `Next` · value 4 · novelty 3 · feasibility 5

A three-position dial (Local only / Local + Claude for chosen tasks / Cloud-assisted) sets where processing happens. Every AI output has a receipt showing exactly what text left the Mac, to which model, and when.

*How it works:* All network egress goes through one Swift actor (EgressGate), which logs the payload hash, the redacted payload, model ID, token counts and purpose, and every summary links to 'View what was sent'. Local only runs SpeechTranscriber plus Foundation Models with chunked map-reduce inside the 4K on-device context. PCC is optional; it needs a managed entitlement, has daily quotas, and the app handles Error.quotaLimitReached. A published list of hostnames lets you confirm with a firewall that Local only sends nothing.

*Inspired by:* App Review 5.1.2(i) disclosure; Apple PCC transparency

### 76. Consent quarantine with a show-and-ask card  `Later` · value 4 · novelty 5 · feasibility 3

In one-party jurisdictions, when a new voice joins, nothing they say is kept yet. Their words sit encrypted for up to 3 minutes while your watch taps once and you show an 'I take AI notes. OK?' card; Yes releases them, No or a timeout destroys them.

*How it works:* The iPhone runs streaming speaker-change detection (FluidAudio streaming diarization) on relayed chunks and flags an unknown voice, and the watch plays one passive haptic per conversation. Quarantined text and audio are encrypted with an in-memory CryptoKit SymmetricKey that is discarded on timeout or No, and the tap becomes a consent record. The EDPB considers consent obtained after recording invalid, so in the EEA and all-party states this is not used as a legal basis: wearer-only (#70) applies and the card only pauses further capture.

*Inspired by:* original

### 77. Memory that fades on purpose  `Next` · value 4 · novelty 5 · feasibility 5 — ✅ built: Partly: raw audio is deleted after a chosen number of days, and you can forget a time range.

Instead of one delete date, detail fades in stages: audio after 3 days, verbatim transcripts after 60, leaving the summary and the facts you confirmed. Anything pinned, bookmarked or tied to an open commitment is kept, and you can set rules per person or place.

*How it works:* A retention engine gives each artifact a tier (audio, transcript, summary, fact) and a time to live. A nightly NSBackgroundActivityScheduler job steps items down: it deletes audio, replaces transcripts with summaries that cite 'expired source' markers, and re-embeds for search. Each tier and day has its own file key, so deleting the key crypto-shreds the data, even in Time Machine backups. The morning brief lists what is about to fade.

*Inspired by:* original; EDPB recommends persistent storage off by default

### 78. Sealed envelopes for sensitive conversations  `Later` · value 4 · novelty 5 · feasibility 4

Conversations that look medical, legal, therapeutic, financial or intimate are sealed automatically. They're kept out of AI summaries, search, recaps and agent access until you open them with Touch ID.

*How it works:* Sealing is triggered by an AFM @Generable classifier on the first window plus the MapKit point-of-interest category of the visit (hospital, pharmacy, law office). Sealed content is re-encrypted with a Secure Enclave key that requires biometry (kSecAccessControlBiometryCurrentSet). No embeddings are created, the MCP server sees only metadata, and nothing is sent to the cloud. Actions: unseal, delete, always seal here.

*Inspired by:* original

### 79. Agent scope firewall for the memory MCP server  `Next` · value 4 · novelty 5 · feasibility 4

Claude Desktop or any other agent sees only what it is allowed to: specific people, projects or date ranges, never sealed or non-consented content. Broad requests like 'everything about my partner' need a tap on your watch.

*How it works:* Each client gets a capability token scoped by people IDs, tags, time window, maximum results and redaction level. A query planner estimates how broad a request is (result count, distinct people, sensitive tags). Above a threshold, an actionable notification (Allow once / Always for this scope / Deny) goes to the watch and Mac. Requests are rate-limited, and every access is logged to the egress ledger.

*Inspired by:* original

### 80. Voiceprint minimization and 'forget me' receipts  `Next` · value 4 · novelty 4 · feasibility 4

Other people's voiceprints exist only for the length of one conversation unless they agree to a lasting profile. If someone asks to be forgotten, one action deletes everything they said and their voiceprint, and produces a receipt you can show them.

*How it works:* Per-conversation embeddings are held only in memory, and a lasting centroid requires a consent record. 'Forget person' finds their segments by profile ID and by name mentions, crypto-shreds their audio, replaces their text with [removed], deletes the centroid, purges the index and regenerates affected summaries locally. It then issues a signed receipt with the segment count, date range and timestamp.

*Inspired by:* GDPR Art. 9; EDPB 01/2026 pseudonymisation; Limitless guidance to delete audio captured without consent

### 81. Signed provenance: verbatim vs AI-written  `Later` · value 3 · novelty 5 · feasibility 4

Every transcript line carries a badge (captured verbatim, machine-corrected, edited by you, or AI-written), backed by a hash chain that starts on the watch, so a shared quote can be verified.

*How it works:* The watch signs each chunk's hash with a CryptoKit SecureEnclave.P256 key, and each sidecar includes the previous chunk's hash, forming a chain. The Mac verifies the chain. Transcript records keep the ASR model and version, edits are stored as diffs, and summaries point back to their spans. A shared quote exports with a C2PA-style JSON manifest that includes consent status.

*Inspired by:* original; TechCrunch op-ed on evidentiary authentication

## Wellbeing

### 82. Social connection dose  `Next` · value 5 · novelty 5 · feasibility 4

A weekly view of your in-person social life as data: minutes in real conversation, distinct people, time with close ties, and substantive conversation vs small talk. It flags only a sustained drop against your own baseline.

*How it works:* It uses diarization timing only: the wearer's turns inside multi-speaker segments and the number of distinct voice clusters, unnamed unless tagged. That makes it work in wearer-only mode, because other people are counted, not transcribed. An AFM @Generable rubric labels each exchange as substantive or small talk, and only the label is kept. The flag fires when 2-week minutes fall more than 40% below the 8-week baseline. It appears in the weekly review with one suggested person and a drafted text.

*Inspired by:* original; Mehl et al. 2010 EAR study; Holt-Lunstad et al. 2010

### 83. Evening reflection and bedtime brain dump  `Next` · value 4 · novelty 3 · feasibility 5 — ✅ built: Partly: each digest ends with an evening reflection question.

At wind-down time, the watch offers a two-minute voice chat about the day, using what was captured, plus a dump of tomorrow's worries. The Mac turns it into an editable journal entry and tomorrow's morning list.

*How it works:* Wind-down time is learned from HealthKit sleep history relayed by the iPhone, or set by you, and a passive notification arrives 45 minutes before. Capture is push-to-talk. claude-opus-5-5 asks 2-3 questions based on the day's recap, and claude-haiku-5-5 de-duplicates worries against open promises and the calendar and slots items into tomorrow. Entries export to Journal or Day One, and nudges stay muted until you wake.

*Inspired by:* Day One Daily Chat, Rosebud; Scullin et al. 2018

### 84. Post-conversation decompression  `Later` · value 4 · novelty 4 · feasibility 4

After a conversation that was physically intense (voice louder and faster than usual, heart rate up while you sat still), the watch waits until it's over and offers a 60-second breathing reset paced by haptics.

*How it works:* The watch measures the wearer's vocal arousal locally (vDSP loudness plus a speech-rate estimate) against a personal baseline, and reads whatever heart-rate samples HealthKit has (background sampling is sparse without a workout session, which isn't allowed for this use) while CMMotionActivity reports stationary. The offer comes only after the VAD detects the conversation has ended. A tap starts a WKExtendedRuntimeSession of type mindfulness (its intended use, frontmost) with haptic-paced long exhales. At most once a day.

*Inspired by:* Apple Mindfulness app; Balban et al. 2023 cyclic sighing

### 85. Emotion granularity check-ins  `Next` · value 4 · novelty 4 · feasibility 5

After a notable conversation, an occasional question asks you to name the feeling precisely ('frustrated', 'relieved', 'proud') with a quick Crown picker. Over months, the Mac shows which people and situations lift or drain you.

*How it works:* At most once a day, through the question gate, after long, high-arousal or tagged-person conversations. The Crown first sets valence from -1 to 1, then scrolls emotion labels filtered by it. The answer is saved through HealthKit as HKStateOfMind (.momentaryEmotion, with labels and associations such as .work or .family), so it also appears in Apple Health. The Mac relates labels to context and tracks how many distinct emotions you use.

*Inspired by:* Apple State of Mind logging; Kashdan, Barrett & McKnight 2015

### 86. Detachment guard  `Later` · value 4 · novelty 5 · feasibility 4

The app measures how much work spills into your evenings and weekends (work talk at home, work commitments made after hours) and holds your boundary: work nudges wait until the next workday.

*How it works:* An AFM classifier labels each conversation as work or non-work. Context comes from your work hours, a home geofence (CLMonitor) and Focus state via SetFocusFilterIntent. The weekly detachment score combines the share of after-hours conversation minutes about work with the number of commitments made after hours. Work nudges are queued until the next workday starts, and boundary experiments are measured in the nudge lab.

*Inspired by:* original; Sonnentag & Fritz detachment research

### 87. Stress-by-context map  `Later` · value 4 · novelty 4 · feasibility 3

A weekly Mac view of the situations that reliably come with stress for you (recurring meetings, people, topics, times of day), based on many occurrences and showing sample size and uncertainty.

*How it works:* The iPhone relays HealthKit heart rate, HRV (SDNN) and resting heart rate aggregates to the Mac. Each segment carries the attendee or voice cluster, an AFM topic label, time, motion and the wearer's vocal-arousal index. The voice index matters because continuous heart rate would need a workout session, which DTS says is invalid for this use. A mixed-effects model with a random intercept per day adjusts for activity. Only associations seen 10 or more times with a confidence interval excluding zero are shown, worded as 'tends to coincide'.

*Inspired by:* Bee's HealthKit integration; WHOOP/Oura stress scores without context

### 88. Getting-sick early warning  `Later` · value 4 · novelty 5 · feasibility 4

Combines how often you cough (from ambient audio) with overnight respiratory rate, wrist temperature and resting heart rate to warn you a day or two early that you may be getting sick, and offers to lighten tomorrow.

*How it works:* The Mac counts the wearer's coughs per hour with SoundAnalysis plus a speaker check. The iPhone relays HealthKit respiratoryRate, appleSleepingWristTemperature, restingHeartRate and HRV. Each signal becomes a personal z-score, and an alert fires when cough rate and at least 2 body signals rise together. It arrives as a passive morning card, with optional Claude-drafted reschedule emails that need T2 approval. Wellness only, not a diagnosis.

*Inspired by:* original; Mishra et al. 2020 (Nature Biomedical Engineering); Hyfe cough research

### 89. Worry-loop and inner-critic mirror  `Later` · value 4 · novelty 5 · feasibility 4

Once a week, privately, the Mac shows worries you've voiced again and again and harsh things you've said about yourself. For each it offers one small technique: a scheduled worry window, or a reframe in the third person.

*How it works:* Opt-in and limited to the wearer's own speech. Claude or AFM tags 'what if' worries and self-critical statements, and NLContextualEmbedding clusters them; a pattern needs 3 or more occurrences over 3 or more days. Nothing interrupts in real time. Worry postponement creates a daily EKEvent window plus a one-tap 'defer worry' on the watch. Self-harm language bypasses the LLM and shows crisis resources, as Siri Recap's filters do.

*Inspired by:* original; Kross et al. 2014; McGowan & Behar 2013

### 90. Therapy bridge journal  `Later` · value 4 · novelty 3 · feasibility 4

Between therapy sessions you journal by voice on the watch: thought records, wins, homework. Before each session the Mac builds a one-page prep you decide whether to share. Capture hard-stops at the therapist's office, and crisis language shows human help right away.

*How it works:* A push-to-talk CBT thought-record flow walks through situation, thought, feeling (logged as HKStateOfMind), evidence and alternative. Claude summarizes entries into a session-prep PDF that you review, and nothing is shared automatically. A CLMonitor geofence plus a calendar keyword hard-stops ambient capture. A safety layer (fixed keyword list plus classifier) bypasses the LLM and shows 988 or local crisis lines.

*Inspired by:* MindfulDiary (CHI 2024); Therabot NEJM AI RCT; the Bee user whose therapist objected

## Integrations

### 91. Personal-memory MCP server  `MVP` · value 5 · novelty 2 · feasibility 5 — ✅ built: Built: a read-only MCP endpoint lets Claude and other agents search memory, read transcripts, open loops, goals and digests.

Claude Desktop, Claude Code or any MCP client can query your memory ('what did the team decide about pricing?') through a local server bundled with the Mac app. It is read-only by default, and every call is logged.

*How it works:* A local stdio helper, plus streamable HTTP on localhost with per-client bearer tokens in the Keychain. Tools: search_memory, get_span, get_person, list_open_commitments, get_day_summary; resources like memory://day/2026-11-14. Government IDs, financial and health data are redacted before results are returned. Writes need in-app approval, and an audit log offers one-click revoke. The per-client grant doubles as the explicit permission for sharing with third-party AI under 5.1.2(i). Built on an MCP Swift SDK, which the research did not re-verify.

*Inspired by:* MCP servers from Granola, Otter, Omi, Screenpipe and Monologue

### 92. Local CLI and SQL/REST API  `Later` · value 3 · novelty 2 · feasibility 5

Power users can query and script their memory from Terminal ('mem promises --overdue', 'mem last-note --watch') or through a localhost API.

*How it works:* A signed CLI talks to the app over XPC. Read-only SQLite views have a documented schema. A localhost REST endpoint uses per-token scopes from the scope firewall (#79), with the same redaction rules as MCP.

*Inspired by:* Screenpipe localhost:3030 API; Monologue CLI

### 93. App Intents and Shortcuts library  `Next` · value 4 · novelty 2 · feasibility 5

Every core capability is a Shortcuts action (start or stop capture, add a bookmark, get today's promises, ask memory, summarize the last meeting), so you can build your own automations and Siri phrases.

*How it works:* App Intents on watchOS, iOS and macOS. StartCaptureIntent opens the app, because capture must start in the foreground; the others run in the background. AppShortcutsProvider supplies Siri phrases, SetFocusFilterIntent links capture to Focus, and the Ultra Action button runs a Shortcut that calls the app's intent.

*Inspired by:* Apple App Intents; Granola and Monologue integrations

### 94. Task, notes and workspace connectors  `Next` · value 4 · novelty 2 · feasibility 4

Send approved actions and notes to Things, Todoist, Linear, Notion, Obsidian, Day One, Slack or a CRM (HubSpot, Attio), not just Apple's own apps.

*How it works:* Deterministic connectors: the Things URL scheme; Todoist, Linear, Notion and Slack REST APIs with OAuth tokens in the Keychain; Obsidian through vault files; Day One through its URL scheme; CRMs through REST. Each connector declares its approval tier (#52), and an outgoing webhook covers everything else.

*Inspired by:* Monologue, Plaud and Bee integrations

### 95. Refugee importer  `Next` · value 4 · novelty 3 · feasibility 4

Bring your history from Limitless, Bee, Omi, Plaud, Granola or Otter exports into your local vault, so years of memories aren't stranded by another shutdown.

*How it works:* A parser for each service maps its export (transcript text or JSON, plus audio where provided) to the vault schema. Diarization and embeddings are re-run locally where audio exists, and imported items keep their source provenance. Each vendor's export format has to be checked; the research did not verify them.

*Inspired by:* Limitless shutdown and regional data deletion; Omi already imports Limitless transcripts

## Creative & Wild

### 96. Past-self and future-self voice capsules  `Later` · value 4 · novelty 5 · feasibility 4

When you're about to give up on a goal, you can hear a 10-second clip of yourself, in your real voice, explaining why it mattered. You can also record messages to your future self that play at a date, a place or a milestone.

*How it works:* When a goal is set (#37), the wearer-only audio of your 'why' is pinned, with diarization trimming everyone else out, and stored encrypted in the vault. Signs of wavering are 2 missed if-then cues or quit-talk flagged by Claude. Capsules are recorded with push-to-talk and triggered by a date, a CLMonitor geofence or a milestone. They play on the watch speaker or AirPods with a transcript.

*Inspired by:* original; contrast with Sandbar's 'Inner Voice' clone (Gizmodo: 'kind of creepy'); Hershfield et al. 2011

### 97. Name whisper  `Later` · value 4 · novelty 5 · feasibility 2

In an opt-in event mode, when someone you've met and named starts talking to you, the watch silently shows their name and one line of context ('Jordan, met at Sarah's party in May, works at Figma').

*How it works:* The watch streams 10-second chunks via WCSession.sendMessageData. The iPhone computes embeddings on the Neural Engine with FluidAudio or SpeakerKit and compares them only with the centroids of named, consented contacts; unnamed bystanders are never matched or stored. A match needs a calibrated cosine score in two consecutive windows, and triggers a silent notification with a Click haptic, about 5-10 s after they start speaking. The feature is disabled where processing bystanders' biometric data needs prior consent (the EU, and all-party states without a per-person consent flag).

*Inspired by:* original; Memoro (CHI 2024)

### 98. Overcommitment shield  `Later` · value 4 · novelty 5 · feasibility 3

When you say 'sure, I can do that' and your open promises already exceed what you usually finish, the watch gives one subtle tap and shows your capacity ('7 open, you close about 4 a week'), so you can renegotiate in the moment.

*How it works:* Opt-in, and only in the Meeting profile, because it needs near-real-time relay. The watch sends 30-second chunks via sendMessageData, and the iPhone transcribes them (no Speech APIs exist on the watch) and spots acceptance phrases in the wearer's turns. It compares the new commitment with the promise ledger's rolling 4-week completion rate and fires at most once per conversation, silently.

*Inspired by:* original; Buehler 1994 planning fallacy

### 99. Life chapters  `Later` · value 3 · novelty 5 · feasibility 4

Each month the app drafts a short memoir chapter of your life in your own words: what you worked on, who you spent time with, what changed. Over a year it becomes a book you can edit and print.

*How it works:* claude-opus-5-5 writes from the month's confirmed facts, storylines, bookmarks and pseudonymized quotes from your own speech, checked by the verification gate (#31). Chapters export as Markdown or PDF, and sealed content is excluded by default.

*Inspired by:* original

### 100. Family quote jar and highlight reel  `Later` · value 4 · novelty 4 · feasibility 4

Bookmark the funny, sweet or wise things your family says and get a private quote book plus a yearly two-minute audio highlight reel of laughs and milestones. It is consent-first, and children's voices never leave the Mac.

*How it works:* Bookmarks (#6) in family-tagged conversations, with explicit household consent, keep clips past the fade rules (#77). SoundAnalysis laughter detection suggests candidates. AVMutableComposition stitches the reel locally, and there is no cloud processing of children's audio.

*Inspired by:* original
