#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Build', 'Launch', 'Enter', 'Reenter', 'Return', 'Observe', 'Inventory', 'Click', 'Key', 'Snapshot', 'Status', 'Close')]
    [string]$Action,

    [ValidateRange(0, 1919)][int]$X,
    [ValidateRange(0, 1079)][int]$Y,
    [switch]$RightButton,
    [ValidateSet('Escape', 'Enter', 'Tab', 'I')][string]$Key = 'Escape',
    [ValidateSet('AnchorKnight', 'AnchorProbe')][string]$Character = 'AnchorKnight',
    [ValidatePattern('^[A-Za-z0-9-]{1,48}$')][string]$Label = 'archonia',
    [ValidateRange(0, 240)][int]$SelectionDelaySeconds = 0,
    [ValidateRange(0, 300)][int]$ObserveSeconds = 0
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$local = Join-Path $root '.local'
$ui = Join-Path $local 'archonia-665-ui'
$game = Join-Path $ui 'Game'
$client = Join-Path $game 'Archonia.exe'
$record = Join-Path $ui 'copy-process.json'
$capture = Join-Path $ui 'capture.exe'
$fixture = Join-Path $local 'archcore-return-integration-anchorville-spawns\return-fixture-anchorville-spawns'
$account = Join-Path $fixture 'anchorville-665-test-account.txt'
$clientHash = 'E13603C37083AAA81E357A622F9CB99B32044F922D18441660C98D87290BB1A6'

function Get-TestClient {
    $saved = Get-Content -LiteralPath $record -Raw | ConvertFrom-Json
    $process = Get-Process -Id $saved.Id -ErrorAction SilentlyContinue
    if (!$process -or $process.StartTime.ToUniversalTime().Ticks.ToString() -ne $saved.StartTicks -or
        $process.Path -ne $client -or $process.MainWindowTitle -cne 'Archonia' -or
        $process.MainWindowHandle -eq [IntPtr]::Zero) {
        throw 'The managed Archonia copy is unavailable or closed unexpectedly.'
    }
    $process
}

function Save-Snapshot([string]$Name) {
    $process = Get-TestClient
    $path = Join-Path $ui "$Name-$([DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss-fff')).png"
    & $capture ([string]$process.MainWindowHandle) ([string]$process.Id) $path
    if ($LASTEXITCODE -ne 0) { throw "Archonia window capture failed (exit $LASTEXITCODE)." }
    $path
}

function Read-Snapshot([string]$Name) {
    $path = Save-Snapshot $Name
    $state = @(& (Join-Path $PSScriptRoot 'windows\read-archonia-ui.ps1') -Image $path)
    [pscustomobject]@{ Image = $path; State = $state }
}

function Wait-Screen([string]$Expected, [int]$Timeout = 15) {
    $clock = [Diagnostics.Stopwatch]::StartNew()
    do {
        $frame = Read-Snapshot "$Label-$Expected"
        if ($frame.State -contains 'ReconnectFailure') {
            throw "Archonia displayed the reconnect failure. Capture: $($frame.Image)"
        }
        if ($frame.State -contains $Expected) { return $frame }
        Start-Sleep -Milliseconds 350
    } while ($clock.Elapsed.TotalSeconds -lt $Timeout)
    throw "Screen '$Expected' was not identified ($($frame.State -join ', ')). Last capture: $($frame.Image)"
}

function Watch-World([int]$Seconds) {
    $first = Wait-Screen 'WorldHud'
    $frame = $first
    $samples = 1
    $previousSampleMs = 0
    $maxSampleGapMs = 0
    $clock = [Diagnostics.Stopwatch]::StartNew()
    do {
        $remainingMs = ($Seconds * 1000) - $clock.ElapsedMilliseconds
        Start-Sleep -Milliseconds ([int][Math]::Max(0, [Math]::Min(3000, $remainingMs)))
        $frame = Read-Snapshot "$Label-WorldHud"
        if ($frame.State -notcontains 'WorldHud' -or $frame.State -contains 'ReconnectFailure') {
            throw "The world HUD was interrupted ($($frame.State -join ', ')). Capture: $($frame.Image)"
        }
        $sampleMs = $clock.ElapsedMilliseconds
        $maxSampleGapMs = [Math]::Max($maxSampleGapMs, $sampleMs - $previousSampleMs)
        $previousSampleMs = $sampleMs
        $samples++
    } while ($clock.Elapsed.TotalSeconds -lt $Seconds)
    [pscustomobject]@{
        ElapsedSeconds = [Math]::Round($clock.Elapsed.TotalSeconds, 2)
        Samples = $samples
        MaxSampleGapSeconds = $maxSampleGapMs / 1000
        FirstImage = $first.Image
        LastImage = $frame.Image
    }
}

function Invoke-Click([int]$Left, [int]$Top, [switch]$UseRightButton) {
    $process = Get-TestClient
    [ArchoniaUiInput]::Click($process.MainWindowHandle, $Left, $Top, $UseRightButton.IsPresent)
}

function Invoke-Key([byte]$Code) {
    $process = Get-TestClient
    [ArchoniaUiInput]::Press($process.MainWindowHandle, $Code)
}

function Open-GameMenu($Frame) {
    if ($Frame.State -notcontains 'GameMenu') {
        Invoke-Key 27
        $null = Wait-Screen 'GameMenu' 8
    }
}

function Enter-World {
    $null = Wait-Screen 'CharacterList'
    $slot = @{ AnchorKnight = 951; AnchorProbe = 429 }[$Character]
    Invoke-Click $slot 847
    Start-Sleep -Milliseconds 850
    if ($SelectionDelaySeconds) { Start-Sleep -Seconds $SelectionDelaySeconds }
    Invoke-Click 1792 927
    Invoke-Click 1792 927
    $frame = Wait-Screen 'WorldHud' 35
    if ($frame.State -contains 'ChatPreference') {
        Invoke-Click 793 608
        $frame = Wait-Screen 'WorldHud'
    }
    $frame
    if ($ObserveSeconds) { Watch-World $ObserveSeconds }
}

if ($Action -eq 'Build') {
    if (!(Get-Command cl.exe -ErrorAction SilentlyContinue)) {
        throw 'Open an x64 Visual Studio developer prompt with the Windows SDK, then repeat Build.'
    }
    $null = New-Item -ItemType Directory -Path $ui -Force
    Push-Location -LiteralPath $ui
    try {
        & cl.exe /nologo /std:c++17 /EHsc /W4 /utf-8 (Join-Path $PSScriptRoot 'windows\archonia-capture.cpp') `
            /Fe:capture.exe d3d11.lib runtimeobject.lib windowscodecs.lib ole32.lib oleaut32.lib user32.lib
        if ($LASTEXITCODE -ne 0) { throw 'Archonia screenshot helper failed to compile.' }
    } finally { Pop-Location }
    return
}

if ($Action -eq 'Launch') {
    if ((Get-Item -LiteralPath $client).Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw 'The test executable must be a real local file.'
    }
    if ((Get-FileHash -LiteralPath $client -Algorithm SHA256).Hash -cne $clientHash) {
        throw 'Unexpected Archonia binary in the isolated copy.'
    }
    $directory = Get-Item -LiteralPath $game
    while ($directory.FullName -ne $root) {
        if ($directory.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'The copy must be a real directory.' }
        $directory = $directory.Parent
    }
    if (Get-Process -Name Archonia -ErrorAction SilentlyContinue | Where-Object Path -eq $client) {
        throw 'The managed copy is already running.'
    }
    $config = [xml][IO.File]::ReadAllText((Join-Path $game 'ArchoniaTest.ini'))
    $servers = @($config.SelectNodes('//ServerGroup'))
    if ($servers.Count -ne 1 -or $servers[0].IP -cne '127.0.0.1:12102') {
        throw 'The managed copy must have only the disposable loopback server (127.0.0.1:12102).'
    }
    $setup = [Diagnostics.ProcessStartInfo]::new($client)
    $setup.WorkingDirectory = $game
    $setup.UseShellExecute = $false
    $setup.CreateNoWindow = $true
    $setup.EnvironmentVariables['__COMPAT_LAYER'] = 'RunAsInvoker'
    $process = [Diagnostics.Process]::Start($setup)
    @{Id = $process.Id; StartTicks = $process.StartTime.ToUniversalTime().Ticks.ToString()} |
        ConvertTo-Json -Compress | Set-Content -LiteralPath $record -Encoding ASCII
    $clock = [Diagnostics.Stopwatch]::StartNew()
    do {
        $process.Refresh()
        if ($process.HasExited) { throw "Archonia exited during launch ($($process.ExitCode))." }
        if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
            Write-Output "Isolated Archonia window ready (PID $($process.Id))."
            return
        }
        Start-Sleep -Milliseconds 500
    } while ($clock.Elapsed.TotalSeconds -lt 45)
    throw 'Archonia did not show a window.'
}

if ($Action -in 'Enter', 'Reenter', 'Return', 'Inventory', 'Click', 'Key', 'Close') {
    if (!('ArchoniaUiInput' -as [type])) { Add-Type -Path (Join-Path $PSScriptRoot 'windows\ArchoniaUiInput.cs') }
}

switch ($Action) {
    'Status' { Get-TestClient | Select-Object Id, StartTime, MainWindowTitle, Responding }
    'Snapshot' { Read-Snapshot $Label }
    'Click' { Invoke-Click $X $Y -UseRightButton:$RightButton }
    'Key' { Invoke-Key @{Escape = 27; Enter = 13; Tab = 9; I = 73}[$Key] }
    'Observe' {
        if (!$ObserveSeconds) { throw 'Observe requires a positive -ObserveSeconds value.' }
        Watch-World $ObserveSeconds
    }
    'Inventory' {
        $frame = Wait-Screen 'WorldHud'
        if ($frame.State -contains 'Inventory') {
            $frame
        } else {
            Invoke-Key 73
            Wait-Screen 'Inventory' 8
            Invoke-Key 73
        }
    }
    'Close' {
        $process = Get-TestClient
        $null = $process.Handle
        $frame = Read-Snapshot "$Label-Close"
        if ($frame.State -contains 'ReconnectFailure') {
            Invoke-Click 960 598
        } elseif ($frame.State -contains 'Quit') {
            Invoke-Click 920 598
        } elseif ($frame.State -contains 'GameMenu' -or $frame.State -contains 'WorldHud') {
            Open-GameMenu $frame
            Invoke-Click 960 612
            $null = Wait-Screen 'Quit' 8
            Invoke-Click 920 598
        } else {
            $null = $process.CloseMainWindow()
        }
        if (!$process.WaitForExit(12000)) {
            throw "Archonia kept its window open. Last capture: $($frame.Image)"
        }
        Write-Output "Archonia closed ($($process.ExitCode))."
    }
    'Enter' {
        $null = Wait-Screen 'Login' 45
        $lines = [IO.File]::ReadAllLines($account)
        if ($lines.Count -ne 3 -or $lines[0] -cne 'Username: anchortrial' -or
            $lines[1] -cnotmatch '^Password: [a-f0-9]{12}$' -or $lines[2] -cne 'Character: AnchorKnight') {
            throw 'Unexpected disposable account file.'
        }
        $process = Get-TestClient
        [ArchoniaUiInput]::FillLogin($process.MainWindowHandle, 'anchortrial', $lines[1].Substring(10))
        # Select the only allowed server group as soon as its dialog replaces the credential form.
        # Take no screenshots of the credential form after entering the password.
        Start-Sleep -Milliseconds 700
        Invoke-Click 965 550
        Invoke-Click 904 609
        $null = Wait-Screen 'WorldList'
        Invoke-Click 894 456
        Invoke-Click 901 681
        Enter-World
    }
    'Reenter' { Enter-World }
    'Return' {
        $frame = Wait-Screen 'WorldHud'
        Open-GameMenu $frame
        Invoke-Click 960 520
        Wait-Screen 'CharacterList' 25
    }
}
