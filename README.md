# Scam Detection Field

**Check a suspicious link or message before you act on it.**

Scam Detection Field is a mobile-first Flutter app that helps ordinary people
answer one question about a digital message they just received:

> **"Why should I be suspicious of this?"**

It does not pretend to know with certainty whether something is a scam. It
shows the *warning signs it actually found*, explains each one in plain
English, and gives a practical next step.

---

## The problem

Phishing and message scams work because they are designed to make people act
in a hurry: a fake delivery notice, a bank "suspension" warning, a prize, a
password request.

Most people who receive such a message have no safe way to check it. They
either click, or they forward it to a friend and guess. Existing tools tend to
answer "safe / unsafe" with no explanation, which teaches people nothing and
builds false confidence.

## Who it is for

* Everyday smartphone users who receive suspicious SMS, WhatsApp or e-mail
  messages.
* People who are not technical and need a plain-language reason, not a score.
* Anyone who wants a second opinion *before* clicking, paying or replying.

## The solution

1. Paste a **link** or a **message**.
2. The app runs transparent checks against well-known scam patterns.
3. You get:
   * a **risk level** — LOW / MEDIUM / HIGH,
   * **why** — every signal found, with a plain-English explanation,
   * **what to do next** — a practical recommendation,
   * an honest **limitation** note about what the tool can and cannot prove.

---

## Key features

* Link analysis and message analysis in one screen.
* More than 35 transparent checks covering, among others:
  * **Links** — brand impersonation, credential wording inside a domain,
    punycode/homograph characters, text before `@`, raw IP hosts, link
    shorteners, suspicious domain endings, many sub-domains/dashes/digits,
    `http://` connections, unusual ports, credential parameters in the query
    string, executable downloads, heavily encoded addresses.
  * **Messages** — urgency and deadlines, threats, requests for passwords /
    PINs / one-time codes, unusual payment demands (gift cards, crypto,
    wire transfer), "release fee" requests, fake prizes, authority
    impersonation, secrecy requests, too-good-to-be-true offers, click-and-reply
    pressure, generic greetings, chain-forwarding, off-platform contact.
* **Combination rule** — a link *plus* a request for money or information in
  the same message is treated as a strong signal.
* Every signal is shown with its **title, explanation, severity and source**
  (link or message).
* **Copy report** — the result can be copied as plain text and shared.
* Optional **AI explanation** (see below) that never changes the risk level.
* Works **fully offline** for the core analysis: no network is required to get
  a risk level and reasons.

## How it works

```
user input
   │
   ├── input detection (link vs. message, links inside a message)
   │
   ├── deterministic rules  ── url_rules.dart / message_rules.dart
   │        each match → Indicator {title, explanation, severity, source}
   │
   ├── risk scoring (risk_scorer.dart)
   │        warning = 1 point, critical = 5 points
   │        any critical signal            → HIGH
   │        7+ points from warnings        → HIGH
   │        2–6 points                     → MEDIUM
   │        0–1 points                     → LOW
   │
   ├── recommendation builder (rules + which signals fired)
   │
   └── optional AI step (services/ai_explainer.dart)
            adds a plain-language explanation only
            NEVER changes the risk level
```

The score is intentionally simple so it can be explained. The app does **not**
display a "confidence percentage", because no such number would be honest
here.

## AI usage

AI is used where it genuinely adds value: turning a list of technical signals
into a short explanation an everyday person can follow.

* The AI step sends the input, the risk level and the matched signals to an
  OpenAI-compatible chat-completions endpoint and asks for a short summary.
* **The risk level, the reasons and the recommendation all come from the
  deterministic rules.** AI only adds wording.
* Every response state is handled: not configured, HTTP error, timeout,
  network failure, rate limit, malformed response. In all of those cases the
  app falls back to the built-in explanations and says so in the UI
  ("An AI explanation was requested but could not be completed").
* **No API key is stored in this repository.** The key is passed at build or
  run time with `--dart-define`.

Enable it:

```bash
flutter run \
  --dart-define=AI_API_KEY=sk-... \
  --dart-define=AI_BASE_URL=https://api.openai.com/v1 \
  --dart-define=AI_MODEL=gpt-4o-mini
```

`AI_BASE_URL` accepts any OpenAI-compatible endpoint, so local or alternative
providers can be used. Without these values the app runs on rules only, which
is the default and the mode used in the submitted APK.

## Architecture

```
lib/
├── main.dart / app.dart            app entry, theme wiring
├── theme/app_theme.dart            colours, risk styling
├── models/analysis_result.dart     Indicator, AnalysisResult, enums (pure Dart)
├── analysis/
│   ├── input_classifier.dart       link vs message, link extraction
│   ├── url_rules.dart              deterministic URL checks
│   ├── message_rules.dart          deterministic message checks
│   ├── risk_scorer.dart            signals → LOW/MEDIUM/HIGH
│   └── analysis_engine.dart        orchestration + recommendation
├── services/ai_explainer.dart      optional AI explanation (dart-define)
├── screens/
│   ├── home_screen.dart            paste → analyse
│   └── result_screen.dart          risk, reasons, advice, copy report
└── widgets/                        risk header, indicator tile, section card
```

Models are pure Dart, so the whole analysis pipeline is unit-testable without
a device.

## Tech stack

* Flutter 3.44.6 / Dart 3.12.2
* Material 3
* [`http`](https://pub.dev/packages/http) — the only third-party dependency,
  used solely for the optional AI call
* Flutter built-in test framework — 50 tests

## Setup

```bash
flutter pub get
```

Run:

```bash
flutter run                 # any connected device
flutter run -d chrome       # quick check in the browser
```

Test:

```bash
flutter analyze             # static checks
flutter test                # 50 tests (rules, engine, AI fallback, UI)
```

Build the release APK:

```bash
flutter build apk --release
# output: build/app/outputs/flutter-apk/app-release.apk
```

## Known limitations

* The analysis is **pattern based**. A brand-new scam that uses none of the
  listed patterns can be scored LOW. The result is a set of reasons, not a
  guarantee.
* The app **never opens, visits or downloads** the link, so it performs no
  real-time domain-reputation or malware check. This is deliberate: the app
  must not put the user's device at risk.
* Brand impersonation uses a **fixed list of common brands**; organisations
  outside that list are only caught by the general wording rules.
* The interface and rule wording are **English only**.
* The AI explanation requires network access and a configured key; it is not
  part of the default build.
* Built and tested on Windows: the APK is produced and verified; the iOS
  bundle was not built in this environment.

## Challenge evolution

Recorded in [BUILD_LOG.md](BUILD_LOG.md) as each hackathon challenge card is
received (what was asked, the interpretation chosen, what changed and why).

## Demo script

1. **Problem** — show a realistic scam message (urgency + password + link).
2. **Input** — paste it in the app (or tap *Try a suspicious message*).
3. **Analysis** — tap *Analyse it*.
4. **Result** — HIGH RISK, then read 2–3 of the reasons out loud.
5. **Advice** — the "What you should do" box.
6. **Honesty** — point at the limitation note and the "About this analysis"
   section: the app never claims certainty.
7. **Evolution** — *(challenge-specific step added in the build log)*.

## License

Provided for the hackathon submission. Third-party packages keep their own
licenses (see `pubspec.yaml` and `pubspec.lock`).
