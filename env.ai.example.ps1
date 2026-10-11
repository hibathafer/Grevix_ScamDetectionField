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

           .\env.ai.ps1                # first connected Android device
           .\env.ai.ps1 -Device chrome    # ...or force the browser
           .\env.ai.ps1 -Device windows   # ...or a Windows device
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
  # Empty targets the first connected Android device, falling back to the
  # browser. Force a target with -Device chrome, windows, ios or a device id.
  [string]$Device,
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
  if ([string]::IsNullOrWhiteSpace($Device)) {
    # First connected Android device, so a plugged-in phone beats the
    # browser. Only the device id is printed - never the key, never @defines.
    try {
      $machine = flutter devices --machine 2>$null | Out-String
      if ($machine) {
        foreach ($d in (ConvertFrom-Json -InputObject $machine)) {
          if ($d.isSupported -and ($d.targetPlatform -like 'android*')) {
            $Device = $d.id
            break
          }
        }
      }
    } catch { }
  }
  if ([string]::IsNullOrWhiteSpace($Device)) {
    Write-Host '  No Android device found - opening the browser instead.' -ForegroundColor Yellow
    $Device = 'chrome'
  }
  Write-Host "  Target device: $Device"
  flutter run -d "$Device" @defines
}
