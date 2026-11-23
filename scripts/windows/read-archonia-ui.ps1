#requires -Version 5.1
param([Parameter(Mandatory)][string]$Image)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
Add-Type -AssemblyName System.Drawing
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetGenericArguments().Count -eq 1 -and $_.GetParameters().Count -eq 1
} | Select-Object -First 1
function Receive-WinRt($Operation,[type]$Result) {
    $task = $asTask.MakeGenericMethod($Result).Invoke($null,@($Operation))
    if (!$task.Wait(10000)) { throw 'Screenshot OCR timed out.' }
    $task.Result
}
$fileType = [Windows.Storage.StorageFile, Windows.Storage, ContentType=WindowsRuntime]
$streamType = [Windows.Storage.Streams.IRandomAccessStream, Windows.Storage.Streams, ContentType=WindowsRuntime]
$decoderType = [Windows.Graphics.Imaging.BitmapDecoder, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
$bitmapType = [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Graphics.Imaging, ContentType=WindowsRuntime]
$resultType = [Windows.Media.Ocr.OcrResult, Windows.Media.Ocr, ContentType=WindowsRuntime]
$engineType = [Windows.Media.Ocr.OcrEngine, Windows.Media.Ocr, ContentType=WindowsRuntime]
$engine = $engineType::TryCreateFromUserProfileLanguages()
if (!$engine) { throw 'No OCR language is installed in the Windows profile.' }
$path = (Resolve-Path -LiteralPath $Image).Path
function Recognize-Image([string]$FilePath) {
    $storageFile = Receive-WinRt ($fileType::GetFileFromPathAsync($FilePath)) $fileType
    $stream = Receive-WinRt ($storageFile.OpenAsync([Windows.Storage.FileAccessMode, Windows.Storage, ContentType=WindowsRuntime]::Read)) $streamType
    try {
        $decoder = Receive-WinRt ($decoderType::CreateAsync($stream)) $decoderType
        $bitmap = Receive-WinRt ($decoder.GetSoftwareBitmapAsync()) $bitmapType
        try { (Receive-WinRt ($engine.RecognizeAsync($bitmap)) $resultType).Text }
        finally { $bitmap.Dispose() }
    } finally { $stream.Dispose() }
}
function Recognize-Region($Bitmap,[double[]]$Bounds) {
    $rect = [Drawing.Rectangle]::new(
        [int]($Bitmap.Width*$Bounds[0]), [int]($Bitmap.Height*$Bounds[1]),
        [int]($Bitmap.Width*$Bounds[2]), [int]($Bitmap.Height*$Bounds[3]))
    $scaled = [Drawing.Bitmap]::new(3*$rect.Width,3*$rect.Height)
    $g = [Drawing.Graphics]::FromImage($scaled)
    $tmp = Join-Path (Split-Path -Parent $path) ("ocr-"+[Guid]::NewGuid().ToString('N')+'.png')
    try {
        $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($Bitmap,[Drawing.Rectangle]::new(0,0,$scaled.Width,$scaled.Height),$rect,[Drawing.GraphicsUnit]::Pixel)
        $scaled.Save($tmp,[Drawing.Imaging.ImageFormat]::Png)
        Recognize-Image $tmp
    } finally {
        $g.Dispose(); $scaled.Dispose()
        if([IO.File]::Exists($tmp)){[IO.File]::Delete($tmp)}
    }
}

function Test-ReconnectDialog($Bitmap) {
    if ($Bitmap.Width -ne 1920 -or $Bitmap.Height -ne 1080) { return $false }
    # Match the narrow line of bright text in the dark modal in both tested window modes.
    $lineWidths = @(105, 84, 94, 69, 81, 113)
    foreach ($top in 523..540) {
        $background = $Bitmap.GetPixel(850, $top)
        if (($background.R + $background.G + $background.B) -gt 95) { continue }
        $matchesLine = $true
        for ($row = 0; $row -lt $lineWidths.Count; $row++) {
            $bright = 0
            for ($x = 843; $x -le 1077; $x++) {
                $pixel = $Bitmap.GetPixel($x, $top + $row)
                if (($pixel.R + $pixel.G + $pixel.B) -gt 420) { $bright++ }
            }
            if ([Math]::Abs($bright - $lineWidths[$row]) -gt 4) {
                $matchesLine = $false
                break
            }
        }
        if ($matchesLine) { return $true }
    }
    $false
}

function Test-WorldHud($Bitmap) {
    if ($Bitmap.Width -ne 1920 -or $Bitmap.Height -ne 1080) { return $false }
    # Full HP and MP are expected for this dedicated test Knight on entry.
    $red = 0
    $blue = 0
    for ($x = 810; $x -le 1100; $x++) {
        $hp = $Bitmap.GetPixel($x, 997)
        $mp = $Bitmap.GetPixel($x, 1007)
        if ($hp.R -gt 125 -and $hp.R -gt ($hp.B + 45) -and $hp.R -gt ($hp.G + 45)) { $red++ }
        if ($mp.B -gt 110 -and $mp.B -gt ($mp.R + 45) -and $mp.B -gt ($mp.G + 32)) { $blue++ }
    }
    $red -gt 190 -and $blue -gt 190
}

function Test-QuitDialog($Bitmap) {
    if ($Bitmap.Width -ne 1920 -or $Bitmap.Height -ne 1080) { return $false }
    # The confirmation text is rendered above the two buttons on a dark modal.
    $lineWidths = @(122, 85, 89, 67, 75, 110)
    for ($row = 0; $row -lt $lineWidths.Count; $row++) {
        $bright = 0
        for ($x = 839; $x -le 1084; $x++) {
            $pixel = $Bitmap.GetPixel($x, 524 + $row)
            if (($pixel.R + $pixel.G + $pixel.B) -gt 510) { $bright++ }
        }
        if ([Math]::Abs($bright - $lineWidths[$row]) -gt 3) { return $false }
    }
    $true
}

function Test-GameMenu($Bitmap) {
    if ($Bitmap.Width -ne 1920 -or $Bitmap.Height -ne 1080) { return $false }
    # Check both metallic sides and the title bar of the centered menu.
    $bright = 0
    $samples = 0
    for ($y = 465; $y -le 620; $y += 5) {
        foreach ($x in (848, 1065)) {
            $pixel = $Bitmap.GetPixel($x, $y)
            if (($pixel.R + $pixel.G + $pixel.B) -gt 280) { $bright++ }
            $samples++
        }
    }
    for ($x = 857; $x -le 1050; $x += 5) {
        $pixel = $Bitmap.GetPixel($x, 449)
        if (($pixel.R + $pixel.G + $pixel.B) -gt 280) { $bright++ }
        $samples++
    }
    $bright -gt ($samples * 0.95)
}

$known = [ordered]@{
    Login = '\bUser\s*ID\b.*\bPassword\b'
    ServerGroup = 'Select\s+Server\s+Group'
    WorldList = 'Select\s+World'
    CharacterList = 'Anchor\s*Knight.*Anchor\s*Probe|Anchor\s*Probe.*Anchor\s*Knight'
    ChatPreference = 'Chat\s+Safety\s+Preference'
    ReconnectFailure = 'Failed\s+reconnecting\s+to\s+the\s+server'
    Anchorville = 'Anchorville'
    Conversation = 'Conversation'
    Inventory = '\bInventory\b'
    Store = '^Store$'
}
$bitmap = [Drawing.Bitmap]::new($path)
try {
    if (Test-ReconnectDialog $bitmap) {
        'ReconnectFailure'
        return
    }
    if (Test-QuitDialog $bitmap) {
        'Quit'
        return
    }
    $segments = @(
        (Recognize-Image $path)
        (Recognize-Region $bitmap @(0.435,0.432,0.134,0.157))
        (Recognize-Region $bitmap @(0.36,0.35,0.28,0.30))
        (Recognize-Region $bitmap @(0.15,0.74,0.44,0.21))
        (Recognize-Region $bitmap @(0.92,0,0.07,0.022))
        (Recognize-Region $bitmap @(0.92,0.028,0.07,0.020))
        (Recognize-Region $bitmap @(0.43,0.477,0.14,0.036))
        (Recognize-Region $bitmap @(0.43,0.491,0.14,0.024))
        (Recognize-Region $bitmap @(0.42,0.351,0.16,0.032))
        (Recognize-Region $bitmap @(0.758,0.339,0.142,0.024))
        (Recognize-Region $bitmap @(0.102,0.164,0.113,0.025))
        (Recognize-Region $bitmap @(0.292,0.165,0.123,0.022))
    )
    $detected = foreach($item in $known.GetEnumerator()){
        if($segments -match $item.Value){$item.Key}
    }
    if (Test-GameMenu $bitmap) { $detected = @($detected) + 'GameMenu' }
    if (Test-WorldHud $bitmap) { $detected = @($detected) + 'WorldHud' }
    if ($detected) { $detected | Where-Object { $_ } } else { 'Unclassified' }
} finally {$bitmap.Dispose()}
