# Feedback

Real tester feedback on Scam Detection Field, and what actually changed in
response. Every item here is a genuine observation that was sent to the
builder; nothing in this file is invented.

## How this was collected

A public post asked for honest feedback on the app. Two substantive technical
observations came back. Both are recorded below as **paraphrases**, with the
commenters' names and profile details withheld.

## Privacy

* Commenters are **not named**. They are described only by what they told us.
* Screenshots are supplied by the maintainer and show public profile names.
  They should **not** be committed without each commenter's agreement.
* No private message, phone number or e-mail address is reproduced here.

---

## Feedback 1 â€” Invalid URL instead of a LOW RISK

**What we heard** (paraphrase). A tester studying cybersecurity pasted random
text instead of a link into the **Link** tab. The app returned **LOW RISK**.
They asked for a URL validation check: if the input is not a proper link
format, show an **"Invalid URL"** error instead of assessing a risk.

**Why this mattered.** The report was correct. No address had been checked at
all, so "LOW RISK" read as *"your input is safe"* for a check that never ran.

**What changed**

| File | Change |
| --- | --- |
| `lib/analysis/input_classifier.dart` | New `validateLink()` and the `UrlRejection` enum: rejects free text, malformed addresses, missing hosts, and any scheme other than `http`/`https`. It parses the address and never opens it |
| `lib/models/analysis_result.dart` | New `InvalidUrlException`, documented as producing **no risk level** |
| `lib/analysis/analysis_engine.dart` | `analyze()` validates **before** `analyzeLink()`, so an invalid URL never reaches the scorer |
| `lib/screens/home_screen.dart` | Shows `Invalid URL â€” Please enter a valid website link to analyze.`; the text stays in the field so it can be corrected, and the existing **Switch to Message** action is offered |
| `lib/l10n/app_strings.dart`, `app_strings_ar.dart` | New `errorInvalidUrl` in both languages |
| `test/url_validation_test.dart` | 14 new tests: valid URLs, random text, malformed URLs, missing hosts, unsupported schemes, and message-mode separation |
| `test/app_test.dart` | 3 new widget tests, including "correct the input and retry" |

`errorLinkContainsSpaces` was **removed and replaced** by the single
`errorInvalidUrl`: one message for every invalid link is clearer than three,
and the Message tab is still offered by the error box.

**What deliberately did *not* change.** Valid URLs behave exactly as before.
`https://example.com` is still **LOW RISK** â€” that was never a defect. Raw IP
hosts such as `192.168.0.1` stay valid, because the rules flag them on
purpose. No detection rule, threshold or scoring order was touched.

**Known limitation.** A brand-new gTLD that is not `[a-z]{2,63}`, or a
non-ASCII domain written in Unicode rather than punycode, is refused as
malformed. That is a deliberate trade: refusing a rare valid address is
safer than scoring random text as a link.

---

## Feedback 2 â€” What the "website scan" actually does

**What we heard** (paraphrase). A tester who runs websites said the app
showed his sites as *"excellent and free of any vulnerabilities"*, and asked:
*"the scanning speed is very high... does the scan really take only a few
seconds?"*

**Why this mattered.** Also correct. The result was fast for the simplest
possible reason: **the app never scans the website.** It reads the address
only. The old disclaimer said it "cannot prove that something is safe", but
never said what was checked, so a reassuring LOW RISK was easy to read as a
clean security audit.

**What changed**

A new `linkScanScopeNote`, rendered **only for a link result**, in the
"About this analysis" card and in the copied plain-text report:

> This is not a security scan. The app reads the web address only and never
> opens or tests the website, so LOW RISK means no common warning signs were
> found in the link - not that the site is safe or free of vulnerabilities.

An Arabic equivalent ships with it. Message results do not show the note,
because they make no website claim at all.

**What deliberately did *not* change.**

* The scan was **not slowed down**. Speed was never the problem.
* **No vulnerability scanning was added, and none is claimed.** The app still
  performs no network request against the address at all.

---

## Verification

| Check | Result |
| --- | --- |
| `flutter analyze` | **No issues found** |
| `flutter test` | **205/205 passed** (was 188; +14 URL-validation tests, +3 widget tests) |

No test opens a network connection. `validateLink` parses an address; it
never fetches it.

---

## Screenshots â€” still to be added manually

The images below were supplied by the maintainer during a voice conversation
and could not be written into this repository by the tooling. They belong in
`feedback/screenshots/`:

| File | What it shows | Status |
| --- | --- | --- |
| `screenshots/01-result-message-high-risk.jpeg` | HIGH RISK message result with the AI explanation | **added** |
| `screenshots/02-outreach-post-1.jpeg` | The public post that asked for honest feedback (part 1) | **added** |
| `screenshots/03-outreach-post-2.jpeg` | The same post (part 2), with the repository link | **added** |
| `screenshots/04-feedback-inval-url.jpeg` | The cybersecurity tester's comment about random text returning "Low Risk" | **added** |
| `screenshots/05-feedback-scan-speed.jpeg` | The website owner's comment about scan speed and "free of vulnerabilities" | **added** |
| `screenshots/06-result-link-low-risk.jpeg` | The LOW RISK link result that prompted Feedback 2 | **added** |

Before committing any of them, confirm with each commenter that they are happy
for their name and comment to appear in a public repository.
