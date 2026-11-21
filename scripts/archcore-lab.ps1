#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateSet('Start', 'Stop', 'Status', 'Signal')]
    [string]$Action,

    [string]$LabRoot = $env:ARCHCORE_LAB_ROOT,
    [string]$MariaDbBin = $env:ARCHCORE_MARIADB_BIN,
    [string]$ArchCoreExe = $env:ARCHCORE_EXE
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $LabRoot) {
    $projects = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $LabRoot = Join-Path $projects 'archcore-windows-lab'
}
$LabRoot = (Get-Item -LiteralPath $LabRoot).FullName
$lab = (Get-Item -LiteralPath (Join-Path $LabRoot 'local-server')).FullName
if (-not $MariaDbBin) { $MariaDbBin = Join-Path $lab 'distribution\mariadb-11.4.14-winx64\bin' }
if (-not $ArchCoreExe) { $ArchCoreExe = Join-Path $LabRoot 'target\x86_64-pc-windows-msvc\release\archcore.exe' }
$MariaDbBin = (Get-Item -LiteralPath $MariaDbBin).FullName

$hostAddress = '127.0.0.1'
$ports = @{ MariaDB = @(3317); ArchCore = @(11002, 11008) }
$executables = @{
    MariaDB = (Get-Item -LiteralPath (Join-Path $MariaDbBin 'mariadbd.exe')).FullName
    ArchCore = (Get-Item -LiteralPath $ArchCoreExe).FullName
}
$databaseConfig = Join-Path $lab 'mariadb.ini'
$configDir = Join-Path $lab 'archcore-config'
$stateFile = Join-Path $lab 'controls.json'
$runtimeClient = Join-Path $lab 'private\runtime.ini'
$adminClient = Join-Path $lab 'private\admin.ini'
$roles = 'MariaDB', 'ArchCore'

function Import-ConsoleControl {
    if ('ArchCoreLab.ConsoleControl' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace ArchCoreLab
{
    public static class ConsoleControl
    {
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool FreeConsole();
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool AttachConsole(uint pid);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern uint GetConsoleProcessList([Out] uint[] ids, uint count);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool SetConsoleCtrlHandler(IntPtr handler, bool add);
        [DllImport("kernel32.dll", SetLastError = true)] private static extern bool GenerateConsoleCtrlEvent(uint kind, uint group);

        public static void EnableInterrupts()
        {
            if (!SetConsoleCtrlHandler(IntPtr.Zero, false)) throw new Win32Exception();
        }

        public static void InterruptIsolatedConsole(uint target)
        {
            FreeConsole();
            try
            {
                if (!AttachConsole(target)) throw new Win32Exception();
                var members = new uint[2];
                var self = (uint)Process.GetCurrentProcess().Id;
                if (GetConsoleProcessList(members, (uint)members.Length) != members.Length ||
                    Array.IndexOf(members, target) < 0 || Array.IndexOf(members, self) < 0)
                    throw new InvalidOperationException("ArchCore is not the only process in its console.");
                if (!SetConsoleCtrlHandler(IntPtr.Zero, true)) throw new Win32Exception();
                if (!GenerateConsoleCtrlEvent(0, 0)) throw new Win32Exception();
                System.Threading.Thread.Sleep(300);
            }
            finally { FreeConsole(); }
        }
    }
}
'@
}

function Read-LabState {
    $records = @{ MariaDB = $null; ArchCore = $null }
    if (Test-Path -LiteralPath $stateFile) {
        try {
            $stored = Get-Content -Raw -LiteralPath $stateFile | ConvertFrom-Json
            foreach ($role in $roles) {
                $record = $stored.$role
                if ($null -ne $record -and ($record.Id -notmatch '^[1-9]\d*$' -or $record.StartTicks -notmatch '^\d+$')) {
                    throw 'Invalid process record.'
                }
                $records[$role] = $record
            }
        } catch { throw 'Cannot read the lab process state. No processes were changed.' }
    }
    $records
}

function Save-LabState {
    $tempFile = Join-Path $lab ('controls-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $json = ConvertTo-Json -InputObject $script:records -Compress
    [IO.File]::WriteAllText($tempFile, $json)
    if ([IO.File]::Exists($stateFile)) { [IO.File]::Replace($tempFile, $stateFile, [NullString]::Value) }
    else { [IO.File]::Move($tempFile, $stateFile) }
}

function Get-ManagedProcess([string]$Role) {
    $record = $script:records[$Role]
    if ($null -eq $record) { return }
    $process = Get-Process -Id $record.Id -ErrorAction SilentlyContinue
    if ($null -ne $process -and $process.Path -eq $executables[$Role] -and
        $process.StartTime.ToUniversalTime().Ticks.ToString() -eq $record.StartTicks) { $process }
}

function Get-LabSockets {
    Get-NetTCPConnection -State Listen
}

function Assert-LabSockets($Sockets, $Processes) {
    foreach ($role in $roles) {
        $process = $Processes[$role]
        $relevant = @($Sockets | Where-Object { $_.LocalPort -in $ports[$role] -or ($null -ne $process -and $_.OwningProcess -eq $process.Id) })
        foreach ($socket in $relevant) {
            if ($null -eq $process -or $socket.OwningProcess -ne $process.Id) {
                throw "TCP port $($socket.LocalPort) is in use by an unmanaged process (PID $($socket.OwningProcess))."
            }
            if ($socket.LocalAddress -ne $hostAddress -or $socket.LocalPort -notin $ports[$role]) {
                throw "Unexpected $role listener on $($socket.LocalAddress) port $($socket.LocalPort)."
            }
        }
    }
}

function Assert-MariaDbConfig {
    $printer = Join-Path $MariaDbBin 'my_print_defaults.exe'
    $options = @(& $printer "--defaults-file=$databaseConfig" --mysqld 2>$null)
    if ($LASTEXITCODE -ne 0) { throw 'Cannot read the existing MariaDB options.' }
    $expected = 'basedir', 'datadir', 'bind-address', 'port', 'skip-name-resolve', 'skip-log-bin', 'general-log', 'event-scheduler', 'local-infile', 'log-error'
    $parsed = @{}
    foreach ($option in $options) {
        if ($option -cnotmatch '^--([a-z-]+)(?:=(.*))?$' -or $Matches[1] -notin $expected) {
            throw 'The MariaDB configuration contains an option outside the local lab profile.'
        }
        $parsed[$Matches[1]] = $Matches[2]
    }
    if (-not $parsed.ContainsKey('datadir') -or -not $parsed.ContainsKey('basedir')) { throw 'The MariaDB instance paths are missing.' }
    $dataDir = (Get-Item -LiteralPath (Join-Path $lab 'database')).FullName
    $baseDir = Split-Path -Parent (Split-Path -Parent $executables.MariaDB)
    if ([IO.Path]::GetFullPath($parsed.datadir) -ne $dataDir -or [IO.Path]::GetFullPath($parsed.basedir) -ne $baseDir) {
        throw 'The MariaDB option file points outside the selected instance.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $dataDir 'mysql') -PathType Container)) {
        throw 'The existing MariaDB instance has no system tables.'
    }
}

function Invoke-DatabaseClient([string]$Tool, [string]$Config, [string[]]$Arguments) {
    $common = "--defaults-file=$Config", '--protocol=tcp', "--host=$hostAddress", "--port=$($ports.MariaDB[0])", '--connect-timeout=2'
    $ErrorActionPreference = 'Continue'
    $result = @(& (Join-Path $MariaDbBin $Tool) @common @Arguments 2>$null)
    [pscustomobject]@{ ExitCode = $LASTEXITCODE; Output = $result }
}

function Wait-LabReady([string]$Role, $Processes) {
    $deadline = [DateTime]::UtcNow.AddSeconds(25)
    $process = $Processes[$Role]
    do {
        if ($process.HasExited) { throw "$Role exited before becoming ready (exit $($process.ExitCode))." }
        $sockets = @(Get-LabSockets)
        Assert-LabSockets $sockets $Processes
        $listening = @($sockets | Where-Object OwningProcess -eq $process.Id | Select-Object -ExpandProperty LocalPort -Unique)
        if ($listening.Count -eq $ports[$Role].Count) {
            if ($Role -eq 'ArchCore') { return }
            $probe = Invoke-DatabaseClient 'mariadb.exe' $runtimeClient @('--batch', '--skip-column-names', '--execute=SELECT 1')
            if ($probe.ExitCode -eq 0 -and $probe.Output -contains '1') { return }
        }
        Start-Sleep -Milliseconds 350
    } while ([DateTime]::UtcNow -lt $deadline)
    throw "$Role did not become ready. Check the lab logs and run Status."
}

function Start-MariaDb {
    $arguments = "--defaults-file=`"$databaseConfig`" --bind-address=$hostAddress --port=$($ports.MariaDB[0])"
    Start-Process -FilePath $executables.MariaDB -ArgumentList $arguments -WorkingDirectory $lab -WindowStyle Hidden -PassThru
}

function Start-ArchCore {
    $settings = @{
        ARCHCORE_ROOT = $lab
        ARCHCORE_CONF_DIR = $configDir
        ARCHCORE_DATABASE_HOST = $hostAddress
        ARCHCORE_DATABASE_PORT = $ports.MariaDB[0]
        ARCHCORE_LOGIN_SERVER_BIND = $hostAddress
        ARCHCORE_LOGIN_SERVER_PORT = $ports.ArchCore[0]
        ARCHCORE_WORLD_SERVER_BIND = $hostAddress
        ARCHCORE_WORLD_SERVER_PORT = $ports.ArchCore[1]
        ARCHCORE_WORLD_SERVER_PUBLIC_ADDRESS = $hostAddress
        ARCHCORE_SOAP_ENABLED = '0'
    }
    $previous = @{}
    foreach ($item in Get-ChildItem Env: | Where-Object Name -like 'ARCHCORE_*') { $previous[$item.Name] = $item.Value }
    try {
        foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
        foreach ($name in $settings.Keys) { [Environment]::SetEnvironmentVariable($name, $settings[$name], 'Process') }
        Import-ConsoleControl
        [ArchCoreLab.ConsoleControl]::EnableInterrupts()
        Start-Process -FilePath $executables.ArchCore -ArgumentList 'all' -WorkingDirectory $lab -WindowStyle Normal -PassThru
    } finally {
        foreach ($name in $settings.Keys) { [Environment]::SetEnvironmentVariable($name, $null, 'Process') }
        foreach ($name in $previous.Keys) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
    }
}

function Stop-ManagedProcess([string]$Role) {
    $process = Get-ManagedProcess $Role
    if ($null -eq $process) { return }
    $null = $process.Handle
    if ($Role -eq 'ArchCore') {
        # Deliver Ctrl+C from a separate console so the calling terminal stays attached.
        $shell = (Get-Process -Id $PID).Path
        $arguments = "-NoProfile -NonInteractive -ExecutionPolicy RemoteSigned -File `"$PSCommandPath`" Signal -LabRoot `"$LabRoot`" -MariaDbBin `"$MariaDbBin`" -ArchCoreExe `"$($executables.ArchCore)`""
        $signal = Start-Process -FilePath $shell -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
        if ($signal.ExitCode -ne 0 -and -not $process.HasExited) { throw 'Ctrl+C could not be delivered to the isolated ArchCore console.' }
    } else {
        $listeners = @(Get-LabSockets | Where-Object LocalPort -eq $ports.MariaDB[0])
        if ($listeners.Count -ne 1 -or $listeners[0].OwningProcess -ne $process.Id -or $listeners[0].LocalAddress -ne $hostAddress) {
            throw 'Cannot verify the managed MariaDB endpoint for shutdown.'
        }
        $shutdown = Invoke-DatabaseClient 'mariadb-admin.exe' $adminClient @('shutdown')
        if ($shutdown.ExitCode -ne 0 -and -not $process.HasExited) { throw 'MariaDB rejected orderly shutdown.' }
    }
    if (-not $process.WaitForExit(12000)) { throw "$Role did not stop after its orderly shutdown request." }
    Write-Host "$Role stopped (PID $($process.Id), exit $($process.ExitCode))."
    $script:records[$Role] = $null
    Save-LabState
    if ($process.ExitCode -ne 0) { Write-Warning "$Role did not return a successful exit code." }
}

function Get-UnmanagedProcesses([string]$Role, $ManagedProcess) {
    $name = [IO.Path]::GetFileNameWithoutExtension($executables[$Role])
    Get-Process -Name $name -ErrorAction SilentlyContinue | Where-Object {
        $_.Path -eq $executables[$Role] -and ($null -eq $ManagedProcess -or $_.Id -ne $ManagedProcess.Id)
    }
}

function Show-LabStatus($Processes) {
    $sockets = @(Get-LabSockets)
    $inspection = @()
    foreach ($role in $roles) {
        $process = $Processes[$role]
        $unmanaged = @(Get-UnmanagedProcesses $role $process)
        if ($null -eq $process) { Write-Host "$role is stopped (no managed process)." }
        else { Write-Host "$role is running (PID $($process.Id))." }
        foreach ($other in $unmanaged) { Write-Warning "$role has an unmanaged instance (PID $($other.Id))." }
        $inspection += @($sockets | Where-Object {
            $_.LocalPort -in $ports[$role] -or ($null -ne $process -and $_.OwningProcess -eq $process.Id) -or $_.OwningProcess -in @($unmanaged | ForEach-Object Id)
        })
    }
    if ($inspection.Count -eq 0) { Write-Host 'No laboratory TCP listeners.'; return }
    $inspection |
        Sort-Object LocalPort, LocalAddress, OwningProcess -Unique |
        Select-Object @{Name='PID'; Expression={$_.OwningProcess}}, LocalAddress, LocalPort, @{Name='Loopback'; Expression={[Net.IPAddress]::IsLoopback([Net.IPAddress]::Parse($_.LocalAddress))}} |
        Format-Table -AutoSize | Out-Host
    if (@($inspection | Where-Object { -not [Net.IPAddress]::IsLoopback([Net.IPAddress]::Parse($_.LocalAddress)) }).Count -gt 0) {
        Write-Warning 'A listener is not limited to loopback.'
    } elseif (@($inspection | Where-Object LocalAddress -ne $hostAddress).Count -gt 0) { Write-Warning 'A loopback listener uses a different address than 127.0.0.1.' }
    else { Write-Host 'All listed listeners are bound to 127.0.0.1.' }
}

if ($Action -eq 'Signal') {
    # This helper reads the existing identity while Stop holds the lock.
    $script:records = Read-LabState
    $process = Get-ManagedProcess 'ArchCore'
    if ($null -ne $process) {
        Import-ConsoleControl
        [ArchCoreLab.ConsoleControl]::InterruptIsolatedConsole([uint32]$process.Id)
    }
    exit 0
}

$lockPath = Join-Path $lab 'controls.lock'
try { $lock = [IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None') }
catch [IO.IOException] { throw 'A laboratory control command is already running, or the lock is unavailable.' }
try {
    $script:records = Read-LabState
    $processes = @{ MariaDB = Get-ManagedProcess 'MariaDB'; ArchCore = Get-ManagedProcess 'ArchCore' }
    if ($Action -eq 'Status') { Show-LabStatus $processes; return }
    foreach ($role in $roles) {
        if ($null -eq $processes[$role]) { $script:records[$role] = $null }
    }
    if ($Action -eq 'Stop') {
        Stop-ManagedProcess 'ArchCore'
        Stop-ManagedProcess 'MariaDB'
        $listeners = @(Get-LabSockets | Where-Object LocalPort -in ($ports.MariaDB + $ports.ArchCore))
        if ($listeners.Count -gt 0) { throw 'A laboratory port is still occupied. Run Status to see the owning PID.' }
        foreach ($role in $roles) {
            if (@(Get-UnmanagedProcesses $role $null).Count -gt 0) { throw "An unmanaged $role process remains. Run Status for details." }
        }
        Save-LabState
        Write-Host 'Laboratory TCP ports are free.'
        return
    }

    foreach ($role in $roles) {
        if (@(Get-UnmanagedProcesses $role $processes[$role]).Count -gt 0) { throw "An unmanaged $role instance is already running. Run Status for details." }
    }
    Assert-LabSockets @(Get-LabSockets) $processes
    if ($null -ne $processes.ArchCore -and $null -eq $processes.MariaDB) { throw 'Stop the managed ArchCore instance before restarting MariaDB.' }
    foreach ($path in @($databaseConfig, $runtimeClient, $adminClient, (Join-Path $configDir 'auth.conf'), (Join-Path $configDir 'world.conf'))) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required laboratory configuration is missing: $path" }
    }
    Assert-MariaDbConfig
    Save-LabState
    $started = @()
    try {
        foreach ($role in $roles) {
            if ($null -eq $processes[$role]) {
                $process = if ($role -eq 'MariaDB') { Start-MariaDb } else { Start-ArchCore }
                $processes[$role] = $process
                $started = ,$role + $started
                $script:records[$role] = @{ Id = $process.Id; StartTicks = $process.StartTime.ToUniversalTime().Ticks.ToString() }
                Save-LabState
            }
            Wait-LabReady $role $processes
        }
        Show-LabStatus $processes
    } catch {
        $startupError = $_
        foreach ($role in $started) {
            try { Stop-ManagedProcess $role }
            catch { throw "$($startupError.Exception.Message) Cleanup failed for $role. $($_.Exception.Message)" }
        }
        throw $startupError
    }
} finally { $lock.Dispose() }
