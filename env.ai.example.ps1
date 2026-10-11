<#
  Local AI configuration - Scam Detection Field
  =================================================================================
  This file is a TEMPLATE and is committed to the repository on purpose, so
  it contains no secret.

  Setup
  -----
    1. Copy this file to `env.ai.ps1` in this same folder.
       `env.ai.ps1` is listed in .gitignore, so it can never be committed.
    2. Paste your Gemini API key on the marked line below.
    3. From this folder run:

           .\env.ai.ps1                # analyse in a browser with AI wording
           .\env.ai.ps1 -Device windows   # ...or on a Windows device
           .\env.ai.ps1 -BuildApk      # build a private APK that carries the key

  Where the key goes
  ------------------
  It is passed straight to the Dart compiler as a --dart-define and is never
  written into this repository. It is still embedded in any binary you build,
  and a Flutter web build serves it to anyone who opens the browser console -
  so never distribute a build made from this script.

  What not to do
  --------------
  Never paste the key into a chat, a screenshot, a commit message, an issue,
  or a build log. Never commit `env.ai.ps1`. To turn AI off again, delete the
  key from that file; the app then runs on its built-in rules alone.
#>

param(
  # Browser is the quickest way to try a real request; use -Device windows,
  # android or ios for a connected device instead.
  [string]$Device = 'chrome',
  [switch]$BuildApk
)

$GeminiApiKey  = ''    # <--- paste your Gemini API key between these quotes
$GeminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/openai/'
$GeminiModel   = 'gemini-3.8-flash'

if ([string]::IsNullOrWhiteSpace($GeminiApiKey)) {
  Write-Host ''
  Write-Host '  No API key set.' -ForegroundColor Yellow
  Write-Host '  Copy env.ai.example.ps1 to env.ai.ps1 and paste your Gemini'
  Write-Host '  API key on the marked line, then run .\env.ai.ps1 again.'
  Write-Host ''
  Write-Host '  Running without a key is also fine - the app falls back to'
  Write-Host '  its built-in rules and analyses as usual.'
  Write-Host ''
  return
}

$defines = @(
  "--dart-define=AI_API_KEY=$GeminiApiKey"
  "--dart-define=AI_BASE_URL=$GeminiBaseUrl"
  "--dart-define=AI_MODEL=$GeminiModel"
)

Write-Host ''
Write-Host '  AI enabled. The risk level still comes from the built-in rules;'
Write-Host '  the model only adds the plain-language explanation.'
Write-Host '  Look for "AI explanation" on the result screen.'
Write-Host ''

if ($BuildApk) {
  flutter build apk --release @defines
} else {
  flutter run -d "$Device" @defines
}
