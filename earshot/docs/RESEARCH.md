# Earshot — research notes

## Market landscape

## Always-on transcription landscape (as of 2026-11-14)

How this was checked: the research agents ran out of web-search budget, so every claim was checked by fetching primary or press pages directly. Anything marked **UNVERIFIED** has only one non-primary source or could not be fetched.

| Product | Form factor | Status | Price | Standout features | Main complaints |
|---|---|---|---|---|---|
| **Apple Watch Audio Intelligence** (Live Rewind + Siri Recap) | Built into Series 12 / Ultra 4 (S11 chip); needs an Apple Intelligence iPhone 16 or later (not 16e) | watchOS 27.3 dev beta 1 shipped Nov 3, 2026. MacRumors expects a December release. Beta, English only, not initially in the EU (works in Switzerland per Heise), not for under-13s ([TechCrunch](https://techcrunch.com/2026/11/02/apple-watchs-ai-features-for-rewinding-and-recapping-conversations-begin-beta-testing/), [Heise](https://www.heise.de/en/news/watchOS-27-3-beta-activates-controversial-Audio-Intelligence-tech-11512706.html)) | Included; Series 12 from $399, up to 24 h battery | Live Rewind shows the last ~15 s as text on a Crown double-press, with a chime and animation even on silent; unsaved snippets are deleted after 30 s. Recap produces titled key-point summaries through Private Cloud Compute, can be scheduled by time or location or toggled in Control Center, is deleted after 7 days unless saved, and filters IDs, financial, auth and self-harm content. No audio is stored; outputs are E2E encrypted | No transcripts, no speaker identification, daily limits on server-model features, no developer API mentioned anywhere (absence only). The [TechCrunch op-ed](https://techcrunch.com/2026/09/09/apple-watchs-new-ai-features-are-normalizing-the-idea-that-technology-is-always-listening/) raises normalization, consent and evidentiary authentication; Engadget calls it a 'passive surveillance state' |
| **Limitless Pendant / Rewind** | Clip pendant + Mac/desktop app | **Acquired by Meta** Dec 5, 2025; Pendant sales stopped that day. Rewind/desktop screen and audio capture disabled Dec 19, 2025. Service ended Dec 5, 2025 in the EU, UK, Brazil, China, Israel, South Korea and Turkey; data there was deleted after Dec 19. Remaining owners got a free Unlimited plan, with support 'throughout 2026' / 'at least another year' ([limitless.ai](https://www.limitless.ai/)) | Was $99 + Unlimited $29/mo ($19/mo annual) | Search and Ask over your life; Leviathan-audited 'Confidential Cloud' | A 6-month user ([jock.pl](https://jock.pl), Jan 2026) found ~10% of 10 GB valuable: a 'fancy transcription service with a mediocre search'. Battery: 6-7 h real vs 100 h advertised (**UNVERIFIED**, [third-party review](https://fast.io/resources/limitless-ai-review-2026/)). 'Consent Mode' is **UNVERIFIED** on Limitless's own pages; its [help center](https://help.limitless.ai/en/articles/10540861-how-to-ask-for-consent-and-let-others-know-you-are-recording) says relying on the LED alone is 'not enough' |
| **Bee** (Amazon) | Frontier: wrist or clip band (IP67). Eclipse: magnetic phone-back card | Amazon confirmed the acquisition Jul 22, 2025. Frontier on sale Oct 15, 2026; Eclipse 'coming soon' ([TechCrunch](https://techcrunch.com/2026/10/15/amazons-bee-launches-two-new-personal-ai-devices-starting-at-75/)) | Frontier $74.99, Eclipse $99.99. Bee Pro $11.99/mo or $99.99/yr; free tier keeps 14 days | Up to 7 days (Frontier) and 21+ days (Eclipse) battery, both vendor claims. Audio is 'processed entirely in memory and immediately deleted'. Actions, Daily Insights, Templates; Gmail, Google Calendar, Outlook, HealthKit, Alexa+ | The Verge's review found speaker confusion, TV and songs treated as conversation, and muted periods leaking into summaries. No audio playback means nothing can be checked. TechCrunch's hands-on: the band fell off twice. Trustpilot 2.6 (only 31 reviews) |
| **Omi** (Based Hardware) | Open-source pendant + phone/desktop apps | Active | $129 (from $179). Pro $29.99/mo or $269.91/yr. Free: unlimited on-phone transcription, 5 h cloud/mo | Open hardware and software, MCP links to ChatGPT and Claude, desktop agent that 'takes action' (Apr 2026), goals tracking, daily recaps | A Watch-app chunk-streaming bug lost ~11 h of recording (reported Sept 6, fix pending as of Oct 18). HN: 'micromanager in a box', 'flow-breaker'. The founder: 'The hardest part was to nail proactivity' |
| **Plaud** NotePin / Note / Note Pro | Pin and card recorders | Active | NotePin $159; Note $159; Note Pro $179-189 (sources differ). Pro $99.99/yr, Unlimited $239.99/yr | 20 h recording, 112 languages, templates/Skills, bot-free desktop capture for Zoom/Meet/Teams (beta, Mar 2026), Memory (Jul 2026), Find My | Subscription cost. NotePin S at $179 is medium confidence; the '2M users' figure is **UNVERIFIED** |
| **Granola** | Mac, Windows, iPhone, Android, Apple Watch (launched Jul 28, 2026; watchOS 11+) | Active. $125M Series C at a $1.5B valuation (month **UNVERIFIED**) | Basic $0 (30-day history); Business $14/user/mo; Enterprise $35/user/mo | The Watch keeps recording wrist-down and offline. Visible sync states (Saved → Syncing → Uploading → Generating → Complete) with retry. MCP on all plans | Interrupted Watch recordings can't be resumed, and the start/stop chime can't be disabled. Link sharing defaulted to 'anyone with the link' (secondary source). *Chamberlain v. Granola* (N.D. Cal. 3:26-cv-07926) comes only from a [competitor blog](https://blog.buildbetter.ai/do-they-own-your-data-granola-ai-privacy-policy-reviewed/); docket **UNVERIFIED** |
| **Otter** | Web, Mac, Windows + meeting bot | Active | Basic free (300 min); Pro $16.99/mo ($8.33 annual); Business $30/mo ($19.99 annual) | MCP server (Oct 2025); MCP-client search across Gmail, Drive, Notion, Jira and Salesforce (Apr 2026, [TechCrunch](https://techcrunch.com/2026/04/28/otters-new-feature-lets-users-search-across-their-enterprise-tools)); botless capture on Mac since late 2025 | *Brewer v. Otter.ai* (N.D. Cal., Aug 15, 2025) alleges the notetaker joins without participant consent and trains on recordings |
| **Friend** | AI companion pendant | Friend 2.0 launched Jul 30, 2026 | $249; ~$10/mo to keep memory beyond 30 days | Built-in speaker | [Fortune](https://fortune.com/2025/10/03/friend-ai-necklace-review-avi-schiffmann/): 7-10 s replies, had to repeat herself 2-3 times, the device forgot her name after ~1.5 weeks. ~3,000 v1 units sold, 1,000 shipped. Unprompted 'Everything alright?' texts were seen as intrusive |
| **Sandbar Stream Ring** | Smart ring, push-to-talk with haptics | Preorder. Batches 1-3 sold out; Batch 4 slipped to fall 2026 (US). iOS only | $249 silver / $299 gold; $10/mo after 3 free months | 'Inner Voice' replies in a clone of your voice. $23M Series A ([iTechGuides](https://www.itechguides.com/sandbar-secures-23m-series-a-for-its-ai-note-taking-ring/)) | Gizmodo: the voice clone is 'kind of creepy'; shipping delays |
| **Pebble Index 01** | Ring, records only while the button is held | Units began reaching buyers around Aug 5, 2026 | $99 ($75 preorder ended Mar 2026); no subscription | On-phone STT and LLM, MCP actions, non-rechargeable battery (~2 years, 12-14 h total recording), mail-back recycling | [Gadgets & Wearables](https://gadgetsandwearables.com/2026/08/05/pebble-index-01-first-impressions/): Android sync and onboarding bugs, ~4 s latency, inconsistent sizing |
| **Nirva** | 8 g wearable | Preorders Nov 2026; shipping targeted by end of 2026 | $249 | TechCrunch says it 'listens to the wearer's speech' (dual mics); no default retention (vendor claim) | Not shipping yet. 'Wearer-only' isolation not independently confirmed |
| **Meta Ray-Ban Gen 3 / Ray-Ban Meta Audio** | Glasses (Audio model has no camera) | Gen 3 $449; Audio $349 shipping Oct 13, 2026 | Hearing enhancement $149.99 (FDA-cleared) | Conversation Focus (Dec 2025, US/CA early access) | *Subia v. Meta* (Oct 19, 2026, 3:26-cv-12135, CIPA) alleges recording without 'Hey Meta' |
| **Screenpipe** | Desktop screen + audio capture | Active (YC S26) | Free; Basic $21/mo; Business $42/seat/mo | Local-only, accessibility tree first with OCR fallback, MCP server, Markdown 'pipes', recording schedules ([GitHub](https://github.com/mediar-ai/screenpipe)) | License changed from MIT to source-available |
| **Watch voice-note apps** | Watch apps | Active | Just Press Record $6.99; Whisper Memos $69.99/yr; Monologue Notes $15/mo; Day One Gold $74.99/yr | Standalone Watch recording, AirPods-from-Watch (Just Press Record); API/CLI/MCP (Monologue) | Day One's Watch app records but doesn't transcribe; it transcribes only recordings up to 10 min |
| **Humane Ai Pin** | Pin | **Dead.** Stopped working normally Feb 28, 2025; HP paid $116M for staff and IP (device business excluded) | n/a | n/a | Bricked devices; refunds only within 90 days |
| **Rabbit R1** | Handheld | Active; rabbitOS 2.3.1 (Sept 10, 2026). OS3 is web beta only ([forum](https://forum.rabbitcommunity.tech/t/rabbitos-release-notes/40)) | n/a | 2.3 lets DLAM use your own Anthropic or OpenAI key; Claude Code via the rabbit agent | The Verge (2024): ~5,000 of ~100,000 buyers active at any time |

**Watch list (not yet shipping or unclear):** OpenAI / Jony Ive device. Court filings say it won't ship before end of Feb 2027 and the 'io' name was dropped; Bloomberg describes a screen-free device to be unveiled in 2026 and released in 2027. Brilliant Labs Halo began batch shipping in Oct 2026 at $299, ~11 months late. Fieldy is cited at $15.99-19.99/mo, which is **UNVERIFIED**.

### Lessons learned
1. **Apple now sets the baseline and is a direct competitor.** Siri Recap and Live Rewind make ambient capture look normal, but they deliberately leave out full transcripts, speaker attribution, retention beyond 7 days, non-English languages, the EU, older watches, Mac workflows and agent access. A third-party app wins on exactly those gaps.
2. **Apple also set the privacy bar.** Opt-in, schedules and location rules, a Control Center toggle, a chime and mic indicator, sensitive-data filters, E2E encryption and short retention are now table stakes. Any difference, such as keeping audio for verification, has to be explained plainly.
3. **Company failure is a real risk.** Humane devices were bricked, and Limitless shut off capture and deleted regional data within two weeks of its acquisition. Local-first storage, open formats and a no-account mode are selling points.
4. **Accuracy failures hurt trust more than missing features do.** Bee treated TV as conversation, Friend forgot the user's name, and Bee's discarded audio means summaries can't be checked. Citations to transcript spans, media filtering and a verification window for audio are essential.
5. **Speaker diarization is weak almost everywhere** (Limitless, Bee, Granola), and Apple doesn't attempt it. Reliably separating 'me' from 'others' is an open opportunity.
6. **Unwanted proactivity backfires.** Friend's unprompted texts and Omi's 'micromanager' critique show the risk; Omi removed its automatic reflection notifications and caps open-loop questions. Nudges must be rare, well-timed and something the user controls.
7. **The category is splitting** into always-on (Bee, Omi, Nirva, Recap) and intentional push-to-talk (Pebble, Sandbar, Plaud, Live Rewind) devices. A watch can do both: scheduled ambient sessions plus hold-to-capture and rewind.
8. **Watch capture is fragile.** Omi lost 11 hours, Granola can't resume interrupted recordings, and Bee's founders describe needing to re-enable capture, calls interrupting it, and no gain control. Chunked sync with visible states and resume nudges is required.
9. **Battery numbers are mostly vendor claims** (Bee Eclipse 21+ days, TicNote 24 h, Limitless 100 h), and the Series 12 is rated at 24 h for everything. Be honest and budget the battery: VAD gating, compressed chunks, off-wrist ASR.
10. **Legal exposure is rising.** Otter and Meta face wiretap/CIPA suits, the Granola suit is unverified, early-2026 pleading-stage rulings largely favored plaintiffs on wiretap claims (Holland & Knight), the EDPB published a smart-glasses statement, and California's SB 1130 indicator mandate passed before being vetoed.
11. **Agent access is now table stakes.** Granola, Otter, Omi, Screenpipe, Monologue and Pebble all expose MCP, an API or a CLI.
12. **Social settings are abandoned first.** A long-term Limitless user stopped wearing it at social gatherings, then casual meetings, until only calls remained. A Bee user's partner banned it at home, and a therapist objected. Wearer-only mode and pause zones protect retention.
13. **Subscription fatigue is real.** Prices run $10-30/mo (Bee $11.99, Omi $29.99, Plaud up to $239.99/yr). Pebble markets 'no subscription' and on-device processing. Local processing on the user's Mac keeps marginal cost low.

## Technical constraints

## Verified technical facts and constraints

How this was checked: claims come from direct fetches of Apple documentation and forums, Anthropic platform docs, the EDPB PDF and press articles. Items marked **UNVERIFIED** were not re-fetched or have only one secondary source.

### 1. Apple Watch capture
- **Recording must start from a user action in the foreground.** It can then continue in the background with the wrist down. An Apple Frameworks Engineer says an interrupted recording **cannot be resumed from the background**; reactivating the session failed with 'Session activation failed' ([forum 750432](https://developer.apple.com/forums/thread/750432)). Apple DTS believes foreground-started recordings may continue indefinitely in the background with the orange indicator. One developer, however, reports a rejection because reviewers said the audio background mode is for playback ([forum 776949](https://developer.apple.com/forums/thread/776949)).
- **Extended runtime sessions** ([WKExtendedRuntimeSession](https://developer.apple.com/documentation/watchkit/wkextendedruntimesession)) cannot keep the app alive all day:
  - Self care: frontmost, 10 min.
  - Mindfulness: frontmost, 1 h.
  - Physical therapy: background, 1 h.
  - Smart alarm: background, 30 min.
  - One type per app; sustained high CPU ends the session with exceededResourceLimits.
  - Apple WWDR warns that using them outside these purposes risks rejection ([forum 819449](https://developer.apple.com/forums/thread/819449)).
- **HKWorkoutSession** for a non-workout purpose is invalid under guideline 2.5.1, and DTS says 12 hours of it 'will consume a lot of energy'. Apps are normally suspended on wrist-down, and the orange mic indicator appears whenever the mic is listening.
- **Gestures.** On Series 12 / Ultra 4, the Crown double-press belongs to Apple's Live Rewind. Use Double Tap (`.handGestureShortcut(.primaryAction)`), complications, Smart Stack widgets, App Intents, or a Shortcut on the Ultra Action button.
- **Battery.** Series 12 is rated up to 24 h. Figures for continuous recording on the Watch are **UNVERIFIED**, as is the 64 GB storage figure for Series 11.
- **Interruptions.** Calls, Siri and other audio apps end a recording. Granola confirms interrupted Watch recordings can be synced in part but not resumed.

### 2. Getting audio off the wrist
- **No low-level networking.** [TN3135](https://developer.apple.com/documentation/technotes/tn3135-low-level-networking-on-watchos) allows it only for active audio streaming, CallKit VoIP and the DeviceDiscoveryUI tvOS listener. Otherwise NWConnection waits with ENETDOWN, and BSD sockets never work, so **a watch app cannot reach a Mac over Bonjour or raw TCP/WebSocket**. The Simulator always allows low-level networking, so test with the iPhone's Wi-Fi and Bluetooth off in Settings.
- **WCSession.transferFile** is asynchronous, may be throttled for power, has no documented size limit and isn't supported in the Simulator. Monitor `outstandingFileTransfers`.
- **Background URLSession.** Always use background transfers. With a complication on the active face, an app gets up to 4 refresh tasks per hour. DTS notes that iOS can defer background transfers, often overnight, and was unsure whether the Watch behaves the same. Expect minutes of latency, not real time.
- **Evidence for chunked, ledgered sync:** Omi lost ~11 h of Watch recording to a chunk-streaming bug; Granola shows explicit sync states with retry.

### 3. Speech recognition and diarization (off the wrist)
- **No Speech framework on the watch.** SFSpeechRecognizer (iOS 10+, macOS 10.15+) and SpeechAnalyzer/SpeechTranscriber (iOS/macOS/visionOS 26) are **not available on watchOS**. ASR must run on the iPhone, the Mac or a server ([SpeechAnalyzer docs](https://developer.apple.com/documentation/speech/speechanalyzer)). Apple says to plan for a one-minute limit on SFSpeechRecognizer's network recognition.
- **SpeechTranscriber** (WWDC25 session 277) is built for long-form and distant audio. Its model lives outside the app's memory and is managed by AssetInventory, apps can allocate only a few languages at a time, and DictationTranscriber is the fallback. It **lacks custom vocabulary** (per Argmax).
- **Speed and accuracy.**
  - A MacStories test (via MacRumors) of Yap, built on SpeechAnalyzer, transcribed 34 min in 45 s; MacWhisper Large V3 Turbo took 1:41.
  - Argmax's own earnings22 benchmark (M4 Mac mini): SpeechTranscriber WER 14.0 at 70x real time; whisper-small.en 12.8 at 35x; Pro parakeet-v2 11.7 at 359x.
- **Open-source options.**
  - [WhisperKit / SpeakerKit (Argmax, MIT)](https://github.com/argmaxinc/WhisperKit): SpeakerKit uses pyannote v4 community-1; needs macOS 14+.
  - [FluidAudio](https://github.com/FluidInference/FluidAudio): ANE-only; Parakeet TDT v3 covers 25 European languages; offline diarization with pyannote community-1 plus VBx; streaming diarization; Silero VAD v6. Requires **Swift 5.10+ and is not Swift 6**, so isolate it in its own module.
- **Biometric data.** Voiceprints of bystanders may count as GDPR Art. 9 biometric data.

### 4. On-device and Apple cloud models
- **Apple Foundation Models on device:** 4,096-token context per session, counting instructions, prompts, tool schemas and outputs (TN3193). Use `tokenCount(for:)` and give the model at most 3-5 tools.
  - AFM Core: 3B, 4-8K context.
  - AFM Core Advanced: 20B, 8K context; macOS 27 on M3 or later.
  - AFM Cloud: 32K context through PCC.
  - Apps can't choose the on-device variant, and SystemLanguageModel has **no watchOS support**.
- **PrivateCloudComputeLanguageModel** (OS 27): 32K context and reasoning levels. It needs the managed entitlement `com.apple.developer.private-cloud-compute`, has daily per-person quotas (`Error.quotaLimitReached`) and works online only. Don't build core features on it.

### 5. Claude API ([platform.claude.com](https://platform.claude.com/docs/en/about-claude/pricing))
- **Models (input/output per MTok, all 1M context, 128K output):**
  - `claude-opus-5-5`: $4 / $20; the recommended default; effort defaults to medium.
  - `claude-sonnet-5-5`: $2 / $10.
  - `claude-haiku-5-5`: $0.10 / $0.50 up to 100K-token prompts, $0.50 / $2.50 above.
  - `claude-fable-5-2`: $8 / $40.
  - Message Batches cost 50% less, which suits nightly and weekly synthesis.
- **Request rules.**
  - On Opus 5.5, thinking is always on: `disabled` or `budget_tokens` returns 400, so control depth with `output_config.effort`.
  - Forced `tool_choice` (any/tool) returns 400; use `auto` with `strict: true` tools or `output_config.format` structured outputs.
  - Assistant prefill returns 400.
  - Check `stop_reason: 'refusal'` and `stop_details`.
  - API version `2026-10-21` rejects `temperature`, `top_p` and `top_k`, even at default values.
  - Server-side fallback uses the beta header `server-side-fallback-2026-07-01` with `fallbacks: 'default'`.
- **Swift access.** There is no general-purpose Swift SDK, so call `POST /v1/messages` with URLSession. Anthropic ships a **beta Swift package, [ClaudeForFoundationModels](https://github.com/anthropics/ClaudeForFoundationModels)** ([docs](https://platform.claude.com/docs/en/cli-sdks-libraries/libraries/apple-foundation-models)) that plugs Claude into Apple's `LanguageModelSession`.
  - Supports respond, streaming, @Generable, tools and server tools on iOS, macOS, visionOS and **watchOS 27**.
  - Auth: `.appAttest` ships no key and needs no backend (1-hour tokens, physical device only); `.proxied` goes through your backend; `.apiKey` is for development only.
  - No prompt-caching control, stop sequences, batch, Files API, token counting or beta headers, so the MCP connector still needs REST.
- **MCP connector.** Send beta header `mcp-client-2026-09-15` (a superset of `mcp-client-2025-11-20`, which is still accepted). Pass `mcp_servers` plus exactly one `mcp_toolset` per server ([docs](https://platform.claude.com/docs/en/agents-and-tools/mcp-connector)).
- **Computer use.** `computer_toolset_20260801` is GA (no beta header) with 17 members, and results must echo `toolset_name: 'computer'`.
  - Screenshots can be up to 2,576 px on the long edge (4,784 visual tokens), with no server downscaling.
  - Recommended sizes: 1024x768 or 1280x720 for desktop tasks; avoid anything above 1920x1080. A stricter per-side limit applies beyond 20 images.
  - Not available in Managed Agents.

### 6. Mac capture and automation
- **Core Audio process taps** (macOS 14.2+: `CATapDescription`, `AudioHardwareCreateProcessTap`, added to an aggregate device) capture per-app audio. They need `NSAudioCaptureUsageDescription` and show a system-audio recording prompt; Screen Recording is not mentioned ([Apple](https://developer.apple.com/documentation/coreaudio/capturing-system-audio-with-core-audio-taps)).
- **[NSUserAppleScriptTask](https://developer.apple.com/documentation/foundation/nsuserapplescripttask)** runs user scripts outside the sandbox. They must live in `~/Library/Application Scripts/<code-signing-id>`, which the app can read but not write.
- **Mac App Store guideline 2.4.5** requires sandboxing, no downloaded code, no root, and updates only through the store. Full automation therefore points to a notarized Developer ID build.
- **Screen recording permission.** macOS Sequoia re-prompts monthly ('Allow For One Month'), even for ScreenCaptureKit apps.
- **Not re-fetched (UNVERIFIED in this pass):** EventKit access levels, Hardened Runtime entitlements, QA1888, the Accessibility/CGEvent thread, the `shortcuts` CLI, and the MCP Swift SDK.

### 7. App Review guidelines ([guidelines](https://developer.apple.com/app-store/review/guidelines/))
- **2.5.4:** background services only for their intended purpose.
- **2.5.14:** explicit user consent plus a clear visual or audible indication when recording.
- **5.1.2(i):** disclose data sharing with third parties, 'including with third-party AI', and obtain explicit permission.
- **2.4.5:** Mac App Store sandbox rules.
- Plan TestFlight distribution first and consult App Review (Meet with Apple) before submitting an always-recording app.

### 8. Legal and consent (not legal advice)
- **US.** Kilpatrick lists **13 all-party-consent states** (CA, CT, DE, FL, IL, MD, MA, MT, NV, NH, OR, PA, WA); another source (Entrepreneur) says 'about 11'. Federal law is one-party, and the strictest rule generally applies to multi-state conversations.
- **California SB 1130** would have required capture indicators on wearables sold from 2028-01-01. It passed both chambers and was **vetoed** on Sept 30, 2026, partly because its definitions could cover smartwatches.
- **EDPB Statement 01/2026** on smart glasses (adopted Oct 13, 2026; mentions voice assistants on smart watches):
  - The household exemption is narrow.
  - Controllers 'should not rely on the users' actions' for transparency.
  - **Consent obtained after recording is invalid.**
  - Legitimate interests are hard to justify for commercial reuse.
  - Recommended: in-the-moment indicators, limits on continuous recording, on-device processing, persistent storage off by default, bystander pseudonymisation and geofencing.
- **Germany §201 StGB:** recording non-public spoken words without authorization carries up to 3 years' imprisonment or a fine.
- **Litigation.**
  - *Brewer v. Otter.ai* (Aug 15, 2025): verified.
  - *Subia v. Meta* (Oct 19, 2026, CIPA): verified.
  - *Chamberlain v. Granola* (ECPA, CIPA, CDAFA): **UNVERIFIED**, single competitor-blog source.
  - Early-2026 pleading-stage rulings largely favored plaintiffs on wiretap claims (Holland & Knight), but no court has found AI note-takers unlawful.
- **Limitless's own guidance:** notify and get consent from everyone recorded; the LED alone is not enough; turn the device off if someone declines; delete audio captured without consent.

### 9. Flagged or uncertain items
- Granola lawsuit docket; Limitless 'Consent Mode' and its real-world battery; Bee real-world battery (1.5-2 days, secondary source).
- Any battery figure for continuous recording on Apple Watch.
- Whether App Review accepts a foreground-started, all-day background recording session (DTS can't speak for App Review).
- Whether the Watch defers background URLSession uploads as iOS does.
- Fireflies pricing; Fathom's '5 calls/month' cap.
- Whether third-party apps can use Apple's Audio Intelligence at all (no API mentioned anywhere).

## Architecture implications

- The watch is a thin, honest recorder. Capture is a user-started foreground AVAudioSession (.record) with an AVAudioEngine input tap that keeps running in the background with the wrist down. The engine is never stopped during silence, because it can't be restarted from the background; silent frames are dropped in RAM. Speech is encoded to AAC (16 kHz mono, 24-32 kbps) in 2-minute chunks with JSON sidecars. Do not use HKWorkoutSession or extended-runtime sessions as keep-alives (guidelines 2.5.1 and 2.5.4). Use the mindfulness session only for a real breathing exercise.
- Build interruption recovery into v1. Watch AVAudioSession interruptions and route changes, finalize the open chunk with a reason, send one .timeSensitive notification with a foreground Resume action, switch the complication to a Resume state, and pass explicit GAP tokens to every summarizer.
- Plan a relay, because the watch cannot reach the Mac directly (TN3135: no Bonjour or sockets). Primary path: WCSession.transferFile to an iPhone companion, which forwards to the Mac over Network framework Bonjour plus TLS on the LAN, or through a CloudKit private database when away. Fallback: background URLSession from the watch to the same CloudKit/HTTPS endpoint. Keep a hashed chunk ledger on the watch, delete only after the Mac ACKs, and show sync states. Expect minutes of latency (about 4 background refreshes per hour with a complication on the face).
- The iPhone companion is required, not optional. It relays audio, reads HealthKit and location (CLVisit, CLMonitor), runs fast ASR for Rewind and Ask (SpeechTranscriber on iOS 26), and keeps an encrypted search replica for when the Mac is offline.
- Transcribe and diarize on the Mac, never on the watch, which has no SFSpeechRecognizer or SpeechAnalyzer. Use SpeechTranscriber (macOS 26, timestamped long-form) as the default engine. Use WhisperKit for languages it doesn't cover and for vocabulary prompting, since SpeechAnalyzer lacks custom vocabulary. Use SpeakerKit or FluidAudio (pyannote community-1 plus VBx) for diarization aligned to audioTimeRange, and SoundAnalysis plus ShazamKit to filter media. Keep FluidAudio in a separate Swift 5.10 module or XPC service, since it doesn't support Swift 6.
- Route models by job. Use Apple Foundation Models on the Mac for free, offline triage of each chunk with @Generable schemas, sized to the 4,096-token on-device context and 3-5 tools. Use claude-haiku-5-5 ($0.10/$0.50 per MTok up to 100K) for bulk extraction, and claude-opus-5-5 ($4/$20) for daily synthesis, planning and tool use. Run nightly and weekly rollups on the Message Batches API at 50% cost. Don't build core features on PCC, which needs a managed entitlement and has daily quotas.
- Write the Claude client to current API rules. Swift has no general-purpose SDK, so call POST /v1/messages with URLSession and anthropic-version 2026-10-21. Never send temperature, top_p or top_k. Opus 5.5 always thinks, so tune output_config.effort (low for routine extraction, medium or high for planning). Forced tool_choice returns 400, so use auto with strict:true tools or output_config.format structured outputs. Don't prefill. Check stop_reason 'refusal' and opt into server-side fallback (beta server-side-fallback-2026-07-01, fallbacks:'default'). Stream long responses.
- Keep API keys out of the clients. On the Mac, hold the key in the Keychain or behind your own proxy. On iPhone and watch (OS 27), consider Anthropic's beta ClaudeForFoundationModels package with .appAttest, which ships no key. It doesn't support beta headers, the MCP connector, prompt-caching control or batch, so those stay on Mac-side REST.
- Every derived object carries source_span_ids: summaries, facts, promises, answers. This is what enables one-click citations, the self-verification gate before anything reaches the watch or MCP, and honest 'not recorded' answers backed by a capture-coverage table.
- Execute actions through a deterministic ladder with a fixed blast-radius policy. Order: EventKit/Contacts/NSWorkspace, then the shortcuts CLI, then NSUserAppleScriptTask scripts (from ~/Library/Application Scripts/<bundle-id>) or Apple Events, then the Accessibility API, and only as a last resort Claude computer use via computer_toolset_20260801 at 1280x720 or 1024x768. Tiers come from a static table, not the model. Double Tap may only trigger nondestructive actions, and every executed action is journaled with its inverse for Undo.
- Distribute the Mac app as a notarized Developer ID build outside the Mac App Store. The MAS sandbox (2.4.5) blocks most Apple Events and AppleScript automation, Accessibility control and helper processes. Prepare users for macOS Sequoia's monthly screen-recording re-prompt if computer use is enabled. Ship the watch and iPhone apps through TestFlight first, and talk to App Review before submitting an all-day recording app.
- Privacy defaults must be defensible on day one. Make wearer-only retention the default, tightened by jurisdiction (13 all-party US states per Kilpatrick, EEA/UK, Germany §201). Provide pause zones, schedules and Focus links. Play an audible start chime and keep the visible mic indicator (2.5.14). Get explicit consent for third-party AI before any Claude call (5.1.2(i)), and redact or pseudonymize locally through one egress gate that logs every payload. No training on user data, and keep raw audio only briefly by default.
- Store everything local-first in a user-owned vault: SQLCipher, a Markdown mirror per day, a documented JSON schema and AAC audio, with keys in the Keychain. Sync between Macs through CloudKit private-database encryptedValues so the vendor holds no copy. Retention keys per tier and day enable crypto-shredding. Publish the schema and an open-source reader as a guarantee against shutdown.
- Ship a local MCP server in the MVP (stdio plus localhost with per-client tokens). Start read-only, with redaction and an audit log, then add per-client scope tokens and watch approval for broad queries. Agent access is now table stakes (Granola, Otter, Omi, Screenpipe).
- Send all proactivity through one notification service: the value-of-information gate (a question must name the decision it unlocks, default 2 a day), conversation-boundary detection from the watch VAD plus motion and calendar, quiet hours, batching into 1-3 decks a day, .passive by default, and .timeSensitive only for deadlines. No feature may post to the watch directly.
- Be honest about battery. Measure drain per profile on the user's watch (Series 12 is rated 24 h for everything), show projected hours on a complication, and step down automatically. Market user-started capture sessions and scheduled windows, not literal 24/7 hidden recording.
- Avoid Apple's gesture and feature collisions. On Series 12 / Ultra 4 the Crown double-press belongs to Live Rewind, so use Double Tap (.handGestureShortcut), complications, Smart Stack relevance widgets, App Intents and the Ultra Action button through Shortcuts. Compete where Apple stops: full transcripts, speaker labels, retention beyond 7 days, older watches, more languages, the EU, Mac workflows and agents.
