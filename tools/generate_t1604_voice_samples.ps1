param(
    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Speech

$resolvedOutput = [System.IO.Path]::GetFullPath($OutputDirectory)
[System.IO.Directory]::CreateDirectory($resolvedOutput) | Out-Null

$voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
$zhVoice = $voice.GetInstalledVoices() |
    Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.Name -eq "zh-CN" } |
    Select-Object -First 1
if ($null -eq $zhVoice) {
    throw "No enabled zh-CN SAPI voice is installed."
}
$voice.SelectVoice($zhVoice.VoiceInfo.Name)
$voice.SetOutputToWaveFile((Join-Path $resolvedOutput "female_short.wav"))
$voice.Rate = 0
function ConvertFrom-Utf8Base64([string]$Value) {
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}
$voice.Speak((ConvertFrom-Utf8Base64 "5oiR6ZyA6KaB5L2g5L+d5Y2r6am/56uZ44CC"))

$samples = [ordered]@{
    "female_terms.wav" = "5a6I5aSH5a6Y77yM6K+36K6p5qC85Lym44CB6ZOB5Yyg5ZKM6ICB5YW15Ymv5a6Y5Yiw6am/56uZ5Li75Y6F6ZuG5ZCI44CC"
    "target_neutral.wav" = "5LuK5aSp55qE5beh6YC754Wn5bi46L+b6KGM44CC"
    "target_happy.wav" = "5aSq5aW95LqG77yM5oiR5Lus57uI5LqO5a6I5L2P6am/56uZ5LqG77yB"
    "target_sad.wav" = "5oiR5Lus5aSx5Y675LqG57Ku6aOf77yM5aSn5a626YO95b6I6Zq+6L+H44CC"
    "target_disgusted.wav" = "6L+Z5Lqb6IWQ5Z2P55qE6aOf54mp55yf6K6p5Lq65oG25b+D44CC"
    "target_angry.wav" = "56uL5Yi756a75byA6L+Z6YeM77yM5LiN6K645YaN6Z2g6L+R6am/56uZ77yB"
    "target_fearful.wav" = "5pWM5Lq65bey57uP5Yiw5LqG6Zeo5aSW77yM5oiR55yf55qE5b6I5a6z5oCV44CC"
    "target_surprised.wav" = "5LuA5LmI77yf5o+05Yab56uf54S2546w5Zyo5bCx5Yiw5LqG77yB"
    "female_near_30s.wav" = "5a6I5aSH5a6Y77yM6K+35ZCs5oiR5rGH5oql44CC5YyX6Zeo5aSW5Y+R546w5LqG5pWM5Lq655qE6ISa5Y2w77yM6ams5aSr5bey57uP5oqK6ams5Yy554m15Zue6ams5Y6p77yM5Y6o5a2Q5q2j5Zyo5riF54K557Ku6aOf77yM6ZOB5Yyg5YeG5aSH5L+u6KGl5q2m5Zmo77yM5Yy755Sf5Lmf5pW055CG5aW95LqG6I2v5ZOB44CC5oiR5Lus6ZyA6KaB5a6J5o6S5Lik5Liq5Lq65beh6YC75Zu05aKZ77yM5YaN6K6p5YW25LuW5Lq65Yqg5Zu65Li75Y6F44CC5aaC5p6c5LuK5pma5rKh5pyJ5paw55qE5oOF5Ya177yM5piO5aSp5riF5pmo6L+Y6KaB5qOA5p+l5rC05LqV44CB5LuT5bqT5ZKM6YCa5b6A6am/56uZ55qE6YGT6Lev77yM5bm25oqK57uT5p6c5ZGK6K+J5omA5pyJ5Lq644CC"
}

foreach ($entry in $samples.GetEnumerator()) {
    $voice.SetOutputToWaveFile((Join-Path $resolvedOutput $entry.Key))
    $voice.Rate = if ($entry.Key -eq "female_near_30s.wav") { 2 } else { 0 }
    $voice.Speak((ConvertFrom-Utf8Base64 $entry.Value))
}
$voice.Dispose()

$manifest = [ordered]@{
    generator = "Windows SAPI"
    voice_name = $zhVoice.VoiceInfo.Name
    culture = $zhVoice.VoiceInfo.Culture.Name
    gender = $zhVoice.VoiceInfo.Gender.ToString()
    samples = @("female_short.wav") + @($samples.Keys)
    limitations = @(
        "Synthetic speech is suitable for transport/transcription checks, not final emotion-quality acceptance.",
        "A real Mandarin male speaker and physical microphone recording remain manual acceptance items."
    )
}
$manifest | ConvertTo-Json -Depth 4 | Set-Content -Encoding UTF8 (Join-Path $resolvedOutput "manifest.json")
Write-Output (Join-Path $resolvedOutput "manifest.json")
