# Brief: building an always-running voice-capture app for Apple Watch (as of 2026-11-16)

**Confidence tags:** [H] high, [M] medium, [L] low.

**Platform baseline.** The current release is **watchOS 27.2.1**, shipped Nov 9, 2026 (https://www.macrumors.com/2026/11/09/apple-releases-watchos-27-2-1/). watchOS 27.3 is in beta. watchOS 27 runs on Series 9 and later, Ultra 2 and later, and SE 3 (https://www.macrumors.com/2026/09/14/apple-releases-watchos-27/) [H]. Target watchOS 27 and keep a watchOS 26 fallback.

## 1. Background audio recording

- **Audio background mode is the only legitimate path for long recording.** The user has to start the session while the app is in the foreground. It then keeps running in the background, and watchOS shows the app again whenever the wrist is raised (https://developer.apple.com/documentation/watchkit/enabling-background-sessions.md) [H].
  - Apple's documentation describes this mode in playback terms. Long-form playback needs a Bluetooth route (https://developer.apple.com/documentation/watchkit/playing-background-audio.md) [H].
  - An Apple Frameworks Engineer confirmed on the forums that recording keeps going after the app moves to the background. The same engineer said that **"Recording cannot be resumed when the app is in the background on watchOS. It must be a user-initiated event while the app is in the foreground."** A call or Siri therefore ends capture until the user reopens the app (https://developer.apple.com/forums/thread/750432) [H].
  - In that thread a developer asked whether App Review accepts long user-started recording. Apple did not answer [M].
  - **Design consequence:** never stop and restart the audio engine to save power. Keep the mic open and do the gating downstream [M].
- **WKExtendedRuntimeSession is no use for all-day capture.** The four session types and limits are:

  | Session type | Runs as | Time limit |
  |---|---|---|
  | Self care | Frontmost | 10 min |
  | Mindfulness | Frontmost | 1 h |
  | Physical therapy | Background | 1 h |
  | Smart alarm | Background, schedulable | 30 min |

  Each app gets one type. The session must start while the app is active. Apple says to pick the type "based on the app's intended use," and the system can cancel a session for sustained CPU use (https://developer.apple.com/documentation/watchkit/using-extended-runtime-sessions.md) [H].
- **HKWorkoutSession runs indefinitely but is a policy trap.** Guideline 2.5.4 limits background services to their intended purposes (https://developer.apple.com/app-store/review/guidelines/) [H]. One developer was rejected repeatedly for "improper use of HKWorkoutSession" (https://developer.apple.com/forums/thread/734323). Apple DTS defers these calls to App Review (https://developer.apple.com/forums/thread/773305). A workout session also moves the user's Activity rings [M]. Don't use it.
- **AudioRecordingIntent (watchOS 11+)** makes the system show a recording indicator. Its documentation says that on watchOS you must keep a Live Activity running while recording (https://developer.apple.com/documentation/appintents/audiorecordingintent.md). However, `Activity.request` lists only iOS and macOS (https://developer.apple.com/documentation/activitykit/activity/request(attributes:content:pushtype:).md). The behaviour on watch is unclear, so test on a device [L]. On iOS, developers report that a recording can't be cold-started from the background (https://developer.apple.com/forums/thread/815725) [M].

## 2. How existing watch recorders work

All of them use **user-started sessions**. None does true ambient, voice-triggered capture [M].

- **Omi:** streams roughly 1-minute chunks to the iPhone. One 11 h 06 min session was lost. The fix adds a complete session file on the watch, crash recovery, and keeping chunks until the iPhone confirms receipt (https://github.com/BasedHardware/omi/issues/20479) [H].
- **Bee (Amazon):** has a watch app (watchOS 10+). Its founders say watchOS limits mean the app "could never fully replicate" their wristband (https://www.androidauthority.com/bee-ai-wearable-3515345/) [M].
- **Limitless:** acquired by Meta in December 2025 and the pendant discontinued. I found no watch app (https://www.usecarly.com/blog/meta-limitless-acquisition/) [M].
- **Whisper Memos:** starts from a complication tap, works standalone, uploads over cellular, caps recordings at 90 min (https://whispermemos.com/features/start-recording/watch-complication) [M].
- **Just Press Record:** has recorded in the background since watchOS 4 (https://www.applevis.com/apps/apple-watch/utilities/just-press-record) [L].
- **Wave:** says it uses extended runtime sessions and auto-stops at 10% battery (https://wave.co/updates/wave-apple-watch-recording) [L].
- **Tiro:** auto-stops below 25% battery or 50 MB free storage (https://docs.tiro.ooo/en/guide/recording/watch) [M].
- **Hedy:** caps sessions at 4 h and reports about 3% battery per hour and about 10 MB per hour (https://www.aimeetingassistantreviews.com/blog/best-ai-note-taker-apple-watch/) [L, vendor claim].
- **Granola:** starts with two taps on a complication and keeps recording with the screen dimmed (same source) [L].
- **Apple Siri Recap and Live Rewind:** scheduled or ambient listening on **Series 12 and Ultra 4 only**. Audio is processed in the S11 Secure Exclave, transcribed on the iPhone, and summarised on PCC. They need an iPhone 16 or later, are in the watchOS 27.3 beta, English only, not in the EU or China, and 18+ (https://support.apple.com/en-us/148354) [H]. I found no third-party API (https://www.engadget.com/2304993/apples-latest-watchos-27-beta-enables-siri-recap-and-live-rewind-audio-features/) [M].

## 3. Battery

- **Rated battery life (normal / Low Power Mode):**

  | Model | Normal | Low Power Mode |
  |---|---|---|
  | Series 11 | 24 h | 38 h |
  | Ultra 3 | 42 h | 72 h |
  | SE 3 | 18 h | 32 h |
  | Series 12 | 24 h | 38 h |
  | Ultra 4 | 50 h | 84 h |

  Sources: https://www.macrumors.com/guide/buyers-guide-apple-watch-se-3-series-11-ultra-3/ and https://www.techrepublic.com/article/news-apple-watch-series-12-ultra-4/ [H]. Series 11 battery capacity is 1.245–1.403 Wh (https://www.macrumors.com/2025/09/12/apple-watch-series-11-increased-battery-catch/) [M].
- **No rigorous public measurement of mic drain exists.** Vendor figures range from about 3%/h with the screen off (Hedy) to 15–20%/h, where a 2 h lecture takes 30–40% (https://speakwiseapp.com/blog/how-to-record-audio-apple-watch) [L].
- **My estimate of realistic hours from 100% to a 10–15% auto-stop** [L, my own calculation]:
  - Series 11/12: about 10–14 h
  - SE 3: about 8–11 h
  - Ultra 3: about 18–24 h; Ultra 4 somewhat more
  - Wi-Fi/cellular streaming, screen-on time and on-watch ML all cut these figures.
- **Low Power Mode** turns off the always-on display and background heart rate. Wi-Fi and cellular go off when the iPhone is away but come back when an app needs data. Background refresh runs less often (https://support.apple.com/HT213336) [M]. Whether recording works under Low Power Mode is untested here [L].
- **Apple's own Audio Intelligence** claims no battery impact (https://techcrunch.com/2026/11/02/apple-watchs-ai-features-for-rewinding-and-recapping-conversations-begin-beta-testing/). That depends on S11 hardware [M].

## 4. On-device speech and AI on watchOS

- **No speech recognition on the watch:**
  - `SFSpeechRecognizer` has no watchOS availability (https://developer.apple.com/documentation/speech/sfspeechrecognizer.md) [H].
  - `SpeechAnalyzer`/`SpeechTranscriber` cover iOS, macOS, tvOS and visionOS 26, not watchOS (https://developer.apple.com/documentation/speech/speechanalyzer.md) [H].
  - The only option is system dictation through text-input UI, which returns final text only [M].
- **Foundation Models on watchOS 27 is cloud-only:**
  - `SystemLanguageModel` (the on-device model) is not on watchOS (https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel.md) [H].
  - `PrivateCloudComputeLanguageModel` is, on watchOS 27+. It needs an entitlement and has per-user daily quotas (`quotaLimitReached`) (https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel.md) [H].
  - In Apple's watchOS group lab, Apple said: "There is no on-device model on the watch itself"; every call is a network hop to PCC; the paired iPhone isn't needed (https://jcalderita.com/wwdc26/watchos-group-lab/) [M].
  - The WWDC session confirms that PCC is what brings the framework to the watch (https://developer.apple.com/videos/play/wwdc2026/241/) [H].
- **Voice activity detection (VAD) is possible on the watch.** SoundAnalysis is available on watchOS 9+, and its built-in classifier covers 300+ sounds, including speech (https://developer.apple.com/documentation/soundanalysis.md) [H]. Core ML also runs on the watch. Whether third-party models get the Neural Engine is unconfirmed (https://developer.apple.com/forums/thread/738445) [L]. A cheap energy-based detector feeding a SoundAnalysis speech check is feasible [M].
- **Siri AI on watchOS 27** needs an iPhone that supports Apple Intelligence (https://www.macrumors.com/2026/09/14/apple-releases-watchos-27/) [H].

## 5. Data path

- **`WCSession.transferFile`** is asynchronous, runs in the background, and is "throttle[d]...to accommodate performance and power." You can track it with `outstandingFileTransfers`. No size limit is published, and it doesn't work in the Simulator (https://developer.apple.com/documentation/watchconnectivity/wcsession/transferfile(_:metadata:).md) [H]. One developer reports a file under 30 MB failing on watchOS 10.5 (https://origin-devforums.apple.com/forums/thread/751623?page=2) [L]. Keep segments of 1–5 min, no more than a few MB each [M].
- **`sendMessage`** fails when the iPhone app is backgrounded. Use `transferUserInfo` for control messages (https://developer.apple.com/forums/thread/762327) [M].
- **Low-level networking** (Network framework, WebSockets) is allowed only while actively streaming audio, during a CallKit VoIP call, or for a DeviceDiscoveryUI connection to tvOS (https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos.md) [H]. A developer measured the network path being revoked every ~36–38 s while an audio session is active. DTS tied this to repeated session activation and filed it as bug FB24377808 (https://developer.apple.com/forums/thread/841590) [M].
- **URLSession over cellular:** background URLSession uploads may wait for Wi-Fi. DTS's suggestion is to upload with a standard session during runtime the app already has (https://developer.apple.com/forums/thread/843751) [M].
- **Storage and file sizes:**
  - Storage is 64 GB on SE 3 (https://www.apple.com/sg/apple-watch-se-3/specs/) [H] and about 64 GB on current models [M].
  - Size per hour [H, arithmetic]:

    | Format | MB per hour |
    |---|---|
    | AAC mono at 24 kbps | ≈ 10.8 |
    | AAC mono at 32 kbps | ≈ 14.4 |
    | LPCM 16 kHz / 16-bit | ≈ 115 |

  - A 16 h day at 24–32 kbps AAC is about 175–230 MB.
  - Opus encoding on the watch is unverified. Older reports say only AAC and LPCM work (https://developer.apple.com/forums/thread/5653) [L]. Record AAC and transcode on the iPhone.

## 6. Input and UI affordances

- **Action Button (Ultra only).** watchOS 26 Controls can be assigned to it on all Ultra models (https://www.macrumors.com/2025/06/15/watchos-26-custom-controls/) [H].
- **Controls** in Control Center and the Smart Stack are new in watchOS 26. They run in the widget extension (https://charleswiltgen.github.io/Axiom/skills/watchos/controls-and-live-activities) [H]. Because capture must start in the foreground, a control should open the app [M].
- **Double Tap:** use `handGestureShortcut(.primaryAction)`. It works on S9 and later, including SE 3 with the S10 chip (https://www.apple.com/newsroom/2025/09/apple-introduces-apple-watch-se-3/). It doesn't work in Low Power Mode or with the wrist down (https://docs.tiro.ooo/en/guide/recording/watch) [H].
- **Wrist flick has no developer API.** It is system-only (https://developer.apple.com/forums/thread/791574) [H].
- **The watchOS 27 single pinch** selects Smart Stack widgets. I found no API for it [M].
- **Live Activities** are started on the iPhone and mirrored to the watch Smart Stack [M].
- **Complications, Smart Stack widgets and RelevanceKit** can be used for status and glanceable summaries [H].

## 7. Privacy and legal

- **Mic indicator:** watchOS shows an orange mic icon whenever an app is using the microphone (https://support.apple.com/108038) [H].
- **App Store rules:**
  - Guideline 2.5.14: "explicit user consent and... clear visual and/or audible indication when recording."
  - Guideline 5.1.2(i): disclose sharing with "third-party AI" and get explicit permission first.
  - Guideline 2.5.19: no hidden features.
  - Source: https://developer.apple.com/app-store/review/guidelines/ [H].
- **US recording law:** federal law is one-party consent. About 11–13 states require all-party consent, including CA, FL, IL, WA, PA, MD and MA, with hybrids in OR, CT and MI (https://www.layer3labs.io/guides/two-party-consent-states) [M; secondary source, verify statutes].
- **EU:** the EDPB smart-glasses statement (Oct 13, 2026) says:
  - The household exemption is narrow.
  - Manufacturers can't push GDPR duties onto users.
  - Recording indicators should be on by default and hard to disable.
  - Consent obtained after recording is invalid.
  - Source: https://www.edpb.europa.eu/system/files/2026-10/20261310_edpb_statement_smart-glasses_en.pdf [M].
- **Apple's own baseline for bystanders:** Live Rewind plays a chime even when the watch is silenced and shows an animation. Siri Recap pauses during calls and FaceTime, omits sensitive data, and doesn't attribute speakers (https://support.apple.com/en-us/148354) [H]. The EFF has criticised Siri Recap (https://www.pcworld.com/article/3232402/will-siri-recap-make-the-apple-watch-creepy-privacy-experts-weigh-in.html) [M].
- **Workplace:** recording at work needs employer policy and notice. Expect pushback on bystander privacy [M].

## 8. What's new in watchOS 26 and 27

- **watchOS 26:** Controls, wrist flick (system-only), RelevanceKit, and arm64 on S9 and later (https://wwdcnotes.com/documentation/wwdc25-334-whats-new-in-watchos-26/) [H].
- **watchOS 27:** Foundation Models via PCC, Vision on the watch, Siri AI, and Audio Intelligence on S12/U4 only (https://developer.apple.com/watchos/whats-new/) [H].
- watchOS 27 can also offer to turn off gestures and Raise to Speak to save battery (https://www.macrumors.com/2026/09/14/apple-releases-watchos-27/) [M].

## Feasibility verdict

**Possible:**
- A user-started recording session that keeps running in the background for many hours with the screen off [H].
- Voice detection on the watch to throw away silence [M].
- Chunked AAC files queued to the iPhone, plus Wi-Fi/cellular upload when standalone [H].
- Transcription on the iPhone with SpeechAnalyzer and on-device Foundation Models [H].
- Summaries from the watch via PCC when online [H].
- Starting from a complication, Control, Action Button (Ultra) or Double Tap inside the app [H].

**Impossible or not allowed:**
- Starting or resuming capture without the user in the foreground: after a call or Siri interruption, a reboot, a crash, or on a schedule [H].
- Siri Recap-style ambient listening using Apple's Secure Exclave hardware [H].
- Speech-to-text on the watch through the Speech framework [H].
- An on-device LLM on the watch [M].
- Hiding the mic indicator [H].
- Using a workout session for non-fitness recording [M].
- A wrist-flick trigger [H].
- Reliable WebSocket streaming [M].

**Recommended capture architecture:**
1. **Start:** a "Start my day" tap from a complication, Control, Action Button or Double Tap. The app is in the foreground, shows a consent reminder, and activates `AVAudioSession(.record or .playAndRecord)`. Activate once and never re-activate, because of the networking bug in section 5.
2. **Capture:** an `AVAudioEngine` input tap feeding a ring buffer. A cheap energy-based detector, confirmed by the SoundAnalysis speech class, gates writing. The mic stays open; the gating is only at the encoder.
3. **Storage:** AAC mono, 16 kHz, 24–32 kbps, in 1–5 min segment files, each flushed to disk and recorded in a journal.
4. **Sync:** `transferFile` with receipts from the iPhone; delete a segment only after the iPhone confirms it. If the phone is unreachable, upload over URLSession.
5. **Phone side:** transcribe with SpeechAnalyzer, summarise with Foundation Models, then push results back to Smart Stack widgets and complications.
6. **Interruptions:** close the current segment, then send a time-sensitive notification with a haptic: "Tap to resume."
7. **Battery and storage guards:** stop at 15% battery or under 100 MB free, and switch to a lower bitrate in Low Power Mode.
8. **Compliance:**
   - Show an obvious in-app recording state and a one-tap pause ("bystander mode").
   - Show consent notices that depend on the user's jurisdiction.
   - Disclose any third-party AI and set clear retention and deletion policies.
