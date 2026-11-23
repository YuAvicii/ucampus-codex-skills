[CmdletBinding(DefaultParameterSetName = 'Catalog')]
param(
    [Parameter(Mandatory, ParameterSetName = 'Catalog')]
    [ValidatePattern('^u0[1-6]-[a-z0-9-]+$')]
    [string]$EntryId,

    [Parameter(ParameterSetName = 'Catalog')]
    [string]$CatalogPath = (Join-Path $PSScriptRoot '../references/oral-answers.json'),

    [Parameter(Mandatory, ParameterSetName = 'Text')]
    [string]$TextFile,

    [Parameter(Mandatory)]
    [string]$OutputDirectory,

    [ValidateSet('wav', 'mp3')]
    [string]$Format = 'wav',

    [ValidateRange(-10, 10)]
    [int]$Rate = 0,

    [string]$VoiceName,

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This script requires PowerShell 7 on Windows and a SAPI English voice.' }

if ($PSCmdlet.ParameterSetName -eq 'Catalog') {
    $catalog = Get-Content -LiteralPath $CatalogPath -Raw -Encoding utf8 | ConvertFrom-Json
    $entriesFound = @($catalog.entries | Where-Object { $_.id -eq $EntryId })
    if ($entriesFound.Count -ne 1) { throw "Expected one catalog entry for '$EntryId'." }
    $lines = @($entriesFound[0].segments | ForEach-Object { [string]$_ })
} else {
    $lines = @(Get-Content -LiteralPath $TextFile -Encoding utf8 | Where-Object { $_.Trim() })
}
if ($lines.Count -eq 0 -or @($lines | Where-Object { -not $_.Trim() }).Count -gt 0) {
    throw 'The text must contain at least one segment and no empty catalog segments.'
}

function Test-EnglishVoice {
    param($Token)
    foreach ($tag in ($Token.GetAttribute('Language') -split ';')) {
        if ($tag -match '^[0-9a-fA-F]+$' -and ([Convert]::ToInt32($tag, 16) -band 0x3ff) -eq 9) {
            return $true
        }
    }
    return $false
}

$voice = New-Object -ComObject SAPI.SpVoice
$tokens = $voice.GetVoices()
$selected = $null
for ($index = 0; $index -lt $tokens.Count; $index++) {
    $token = $tokens.Item($index)
    $description = $token.GetDescription()
    if ($VoiceName -and $description -eq $VoiceName) {
        $selected = $token
        break
    }
    if (-not $VoiceName -and (Test-EnglishVoice $token)) {
        if ($description -match '\bZira\b') {
            $selected = $token
            break
        }
        if ($null -eq $selected) { $selected = $token }
    }
}
if ($null -eq $selected) { throw 'No matching SAPI English voice was found. Check the local Windows voices.' }
$voice.Voice = $selected
$voice.Rate = $Rate

$ffmpeg = $null
if ($Format -eq 'mp3') { $ffmpeg = Get-Command ffmpeg -CommandType Application -ErrorAction Stop }
$output = [IO.Directory]::CreateDirectory($OutputDirectory).FullName
$targets = @(1..$lines.Count | ForEach-Object { Join-Path $output "sentence-$_.$Format" })
if (-not $Force) {
    $existing = @($targets | Where-Object { Test-Path -LiteralPath $_ })
    if ($existing.Count) { throw "Output already exists: $($existing[0]). Use a fresh directory or -Force." }
}

for ($index = 0; $index -lt $lines.Count; $index++) {
    $stem = Join-Path $output ('.tts-' + [guid]::NewGuid().ToString('N'))
    $wav = "$stem.wav"
    $encoded = "$stem.mp3"
    $stream = New-Object -ComObject SAPI.SpFileStream
    $stream.Format.Type = 22 # 22.05 kHz, 16-bit mono PCM
    try {
        $stream.Open($wav, 3)
        try {
            $voice.AudioOutputStream = $stream
            $null = $voice.Speak($lines[$index])
        } finally {
            $stream.Close()
        }
        $duration = [Math]::Round(([IO.FileInfo]::new($wav).Length - 44) / 44100, 2)
        $result = $wav
        if ($Format -eq 'mp3') {
            & $ffmpeg.Source -nostdin -v error -i $wav -codec:a libmp3lame -q:a 4 $encoded
            if ($LASTEXITCODE -ne 0) { throw "FFmpeg could not encode segment $($index + 1)." }
            $result = $encoded
        }
        [IO.File]::Move($result, $targets[$index], $Force.IsPresent)
        [pscustomobject]@{
            Number = $index + 1
            Path = $targets[$index]
            DurationSeconds = $duration
            Voice = $selected.GetDescription()
        }
    } finally {
        foreach ($temp in @($wav, $encoded)) {
            [IO.File]::Delete($temp)
        }
    }
}
