[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Directory,

    [Parameter(Mandatory)]
    [ValidateRange(1, 10000)]
    [int[]]$Numbers,

    [ValidateSet('Immediate', 'OnChromeMicrophone')]
    [string]$Mode = 'Immediate',

    [string]$StatusFile,

    [string]$ChromeExe,

    [ValidateRange(1, 600)]
    [int]$WaitSeconds = 120,

    [ValidateRange(1, 600)]
    [int]$CloseSeconds = 90,

    [ValidateRange(0, 5000)]
    [int]$LeadInMilliseconds = 550
)

$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'This playback helper requires PowerShell 7 on Windows.' }
$directoryPath = (Get-Item -LiteralPath $Directory).FullName
$files = @{}
foreach ($number in $Numbers) {
    $file = Join-Path $directoryPath "sentence-$number.wav"
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Missing audio file: $file" }
    $files[$number] = $file
}
if ($StatusFile) {
    $StatusFile = [IO.Path]::GetFullPath($StatusFile, $PWD.ProviderPath)
    $null = [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($StatusFile))
}

function Set-PlaybackState {
    param([string]$Phase, [int]$Number)
    if (-not $StatusFile) { return }
    $json = @{ phase = $Phase; number = $Number } | ConvertTo-Json -Compress
    $tempFile = $StatusFile + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllText($tempFile, $json)
        [IO.File]::Move($tempFile, $StatusFile, $true)
    } finally {
        [IO.File]::Delete($tempFile)
    }
}

function Find-ChromeMicrophoneKey {
    $storePath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\microphone\NonPackaged'
    $keys = @(Get-ChildItem -LiteralPath $storePath -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '(?i)#chrome\.exe$' })
    if ($ChromeExe) {
        $expectedKey = [IO.Path]::GetFullPath($ChromeExe) -replace '\\', '#'
        $keys = @($keys | Where-Object { $_.PSChildName -eq $expectedKey })
    } elseif ($keys.Count -gt 1) {
        $runningKeys = @(Get-Process -Name chrome -ErrorAction SilentlyContinue |
            ForEach-Object { if ($_.Path) { $_.Path -replace '\\', '#' } } |
            Select-Object -Unique)
        $keys = @($keys | Where-Object { $_.PSChildName -in $runningKeys })
    }
    if ($keys.Count -ne 1) {
        throw 'Could not identify one Chrome microphone activity entry. Use -ChromeExe or Immediate mode.'
    }
    return $keys[0].PSPath
}

function Wait-ChromeMicrophone {
    param([string]$KeyPath, [long]$AfterStart, [bool]$Opening, [int]$TimeoutSeconds)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        $state = Get-ItemProperty -LiteralPath $KeyPath
        if ($Opening) {
            if ($state.LastUsedTimeStart -gt $AfterStart -and $state.LastUsedTimeStop -eq 0) {
                return [long]$state.LastUsedTimeStart
            }
        } elseif ($state.LastUsedTimeStop -gt 0) {
            return
        }
        Start-Sleep -Milliseconds 125
    } while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds)
    if ($Opening) { throw "No new Chrome microphone session started within $TimeoutSeconds seconds." }
    throw "The Chrome microphone did not close within $TimeoutSeconds seconds."
}

$keyPath = $null
$previousStart = 0L
if ($Mode -eq 'OnChromeMicrophone') {
    $keyPath = Find-ChromeMicrophoneKey
    $initial = Get-ItemProperty -LiteralPath $keyPath
    $previousStart = [long]$initial.LastUsedTimeStart
    if ($previousStart -gt 0 -and $initial.LastUsedTimeStop -eq 0) {
        throw 'Chrome is already recording. Stop the previous recording before arming this queue.'
    }
}

Set-PlaybackState 'ready' 0
foreach ($number in $Numbers) {
    $player = [System.Media.SoundPlayer]::new($files[$number])
    try {
        $player.Load()
        if ($keyPath) {
            $previousStart = Wait-ChromeMicrophone -KeyPath $keyPath -AfterStart $previousStart -Opening $true -TimeoutSeconds $WaitSeconds
            Set-PlaybackState 'recording' $number
            Start-Sleep -Milliseconds $LeadInMilliseconds
            if ((Get-ItemProperty -LiteralPath $keyPath).LastUsedTimeStop -ne 0) {
                throw "Chrome stopped before audio $number could play."
            }
        }
        $player.PlaySync()
        Set-PlaybackState 'played' $number
        Write-Output "Played sentence $number."
        if ($keyPath) {
            Wait-ChromeMicrophone -KeyPath $keyPath -AfterStart $previousStart -Opening $false -TimeoutSeconds $CloseSeconds
            Set-PlaybackState 'closed' $number
            Write-Output "Recording closed for sentence $number."
        }
    } catch {
        Set-PlaybackState 'error' $number
        throw
    } finally {
        $player.Dispose()
    }
}
