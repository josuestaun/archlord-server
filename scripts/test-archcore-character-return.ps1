#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Prepare', 'Build', 'Start', 'Test', 'TestImport', 'Stop')]
    [string]$Action,

    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9][a-z0-9-]{0,31}$')]
    [string]$Run,

    [string]$MariaDbBin = $env:ARCHCORE_MARIADB_BIN
)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$relativeBuild = ".local/archcore-return-integration-$Run"
$build = Join-Path $workspace $relativeBuild
$source = Join-Path $workspace 'server/archcore'
$pin = 'ad280a6efc069526fc58445e5397d52a0e809500'
$target = 'x86_64-pc-windows-msvc'
$toolchain = "stable-$target"
$cargoArgs = @('--offline', '--locked', '--release', '--target', $target, '--target-dir', '.\target', '--quiet')
$dbPort = 3347
$loginPort = 12102
$worldPort = 12108
$root = Join-Path $build "return-fixture-$Run"
$data = Join-Path $root 'database'
$conf = Join-Path $root 'config'
if (-not $MariaDbBin) {
    $MariaDbBin = Join-Path (Split-Path -Parent $workspace) 'archcore-windows-lab\local-server\distribution\mariadb-11.4.14-winx64\bin'
}
if ($Action -in @('Start', 'Test', 'TestImport', 'Stop')) {
    $MariaDbBin = (Get-Item -LiteralPath $MariaDbBin).FullName
}
$maria = Split-Path -Parent $MariaDbBin
$initializer = Join-Path $MariaDbBin 'mariadb-install-db.exe'
$server = Join-Path $MariaDbBin 'mariadbd.exe'
$client = Join-Path $MariaDbBin 'mariadb.exe'
$admin = Join-Path $MariaDbBin 'mariadb-admin.exe'
$serverIni = Join-Path $root 'mariadb.ini'
$clientIni = Join-Path $root 'client.ini'
$recordPath = Join-Path $root 'mariadb-process.json'
$utf8 = [Text.UTF8Encoding]::new($false)
$endpoint = @("--defaults-file=$clientIni", '--protocol=tcp', '--host=127.0.0.1', "--port=$dbPort")

function Invoke-Git([string[]]$Arguments) {
    & git --no-lazy-fetch --no-optional-locks -c core.autocrlf=false @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Git failed ($LASTEXITCODE)." }
}

function Assert-PreparedSource {
    $buildItem = Get-Item -LiteralPath $build -Force
    if (-not $buildItem.PSIsContainer -or ($buildItem.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw 'Unexpected integration directory.'
    }
    $marker = Join-Path $build 'archcore-base.txt'
    if ([IO.File]::ReadAllText($marker).Trim() -cne $pin) { throw 'Unexpected integration source pin.' }
}

function Get-Listeners {
    foreach ($line in (netstat.exe -ano -p tcp)) {
        if ($line -match '^\s*TCP\s+(\S+):(\d+)\s+\S+\s+LISTENING\s+(\d+)\s*$') {
            [pscustomobject]@{ Address=$Matches[1]; Port=[int]$Matches[2]; Id=[int]$Matches[3] }
        }
    }
}

function Get-FixtureDatabase {
    $record = Get-Content -LiteralPath $recordPath -Raw | ConvertFrom-Json
    $process = Get-Process -Id $record.Id
    if ($process.Path -ne $server -or $process.StartTime.ToUniversalTime().Ticks.ToString() -ne $record.StartTicks) {
        throw 'Unexpected fixture database process.'
    }
    $listeners = @(Get-Listeners | Where-Object Id -eq $process.Id)
    if ($listeners.Count -ne 1 -or $listeners[0].Address -ne '127.0.0.1' -or $listeners[0].Port -ne $dbPort) {
        throw 'Unexpected fixture database listener.'
    }
    $observed = @('SELECT @@datadir, @@port, @@bind_address, @@global.general_log;' | & $client @endpoint --batch --raw --skip-column-names 2>$null)
    if ($LASTEXITCODE -ne 0 -or $observed.Count -ne 1) { throw 'Fixture database is not ready.' }
    $fields = $observed[0] -split '\t'
    if ($fields.Count -ne 4 -or $fields[0].TrimEnd('\', '/').Replace('\', '/') -ne $data.Replace('\', '/') -or
        $fields[1] -ne "$dbPort" -or $fields[2] -ne '127.0.0.1' -or $fields[3] -ne '0') {
        throw 'Unexpected database data directory or configuration.'
    }
    $process
}

switch ($Action) {
    'Prepare' {
        if (Test-Path -LiteralPath $build) { throw 'Pick an unused run name to preserve earlier fixtures.' }
        $gitlink = Invoke-Git @('-C', $workspace, 'ls-files', '--stage', '--', 'server/archcore')
        if ($gitlink -cne "160000 $pin 0	server/archcore") { throw 'Unexpected main-repository ArchCore pin.' }
        if ((Invoke-Git @('-C', $source, 'rev-parse', '--verify', 'HEAD')) -cne $pin -or
            @(Invoke-Git @('-C', $source, 'status', '--porcelain')).Count) {
            throw 'ArchCore must be clean at the reviewed pin before preparing the integration.'
        }
        $files = @(Invoke-Git @('-C', $source, 'ls-tree', '-r', $pin, '--', 'Cargo.toml', 'Cargo.lock', 'LICENSE', 'crates', 'sql'))
        if (-not $files.Count) { throw 'No reviewed ArchCore source files were found.' }
        $local = Join-Path $workspace '.local'
        if (-not (Test-Path -LiteralPath $local)) { $null = New-Item -Path $local -ItemType Directory }
        if ((Get-Item -LiteralPath $local -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw 'The local artifact directory must not be redirected.'
        }
        $null = New-Item -Path $build -ItemType Directory
        foreach ($entry in $files) {
            if ($entry -notmatch '^100(?:644|755) blob [0-9a-f]{40}\t([a-zA-Z0-9_./-]+)$') {
                throw 'An unexpected file was present in the reviewed source list.'
            }
            $path = $Matches[1]
            $original = Get-Item -LiteralPath (Join-Path $source $path) -Force
            if ($original.PSIsContainer -or ($original.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw "The reviewed source file is not an ordinary file: $path"
            }
            $destination = Join-Path $build $path
            $null = New-Item -Path (Split-Path -Parent $destination) -ItemType Directory -Force
            Copy-Item -LiteralPath $original.FullName -Destination $destination
        }
        $patchDir = Join-Path $workspace 'server/patches/archcore'
        $patches = @(
            (Join-Path $patchDir '0001-fix-character-selection-return.patch')
            (Join-Path $patchDir '0002-test-character-selection-return.patch')
            (Join-Path $patchDir '0003-defer-login-handoff-close.patch')
        )
        $apply = @('-C', $workspace, 'apply', '--whitespace=error', "--directory=$relativeBuild")
        foreach ($patch in $patches) {
            Invoke-Git ($apply + @('--check', $patch))
            Invoke-Git ($apply + $patch)
        }
        [IO.File]::WriteAllText((Join-Path $build 'archcore-base.txt'), $pin + [Environment]::NewLine, $utf8)
        "Prepared patched ArchCore sources in $build"
    }
    'Build' {
        Assert-PreparedSource
        Push-Location -LiteralPath $build
        try {
            & rustup run $toolchain cargo build @cargoArgs -p archcore
            if ($LASTEXITCODE -ne 0) { throw 'ArchCore compilation failed.' }
            & rustup run $toolchain cargo test @cargoArgs -p archcore -p archcore-net
            if ($LASTEXITCODE -ne 0) { throw 'ArchCore unit tests failed.' }
        } finally {
            Pop-Location
        }
    }
    'Start' {
        Assert-PreparedSource
        if (Test-Path -LiteralPath $root) { throw 'Pick an unused run name to preserve earlier fixtures.' }
        if (@(Get-Listeners | Where-Object Port -in @(3327,3337,$dbPort,$loginPort,$worldPort)).Count) {
            throw 'A persistent lab or fixture endpoint is already in use.'
        }
        $null = New-Item -Path $root -ItemType Directory
        $null = New-Item -Path $conf -ItemType Directory
        $dbPassword = [Guid]::NewGuid().ToString('N')
        $null = & $initializer "--datadir=$data" "--password=$dbPassword" '--skip-networking' "--port=$dbPort"
        if ($LASTEXITCODE -ne 0) { throw "Disposable MariaDB initialization failed (exit $LASTEXITCODE)." }
        [IO.File]::WriteAllLines($serverIni, @(
            '[mariadbd]', "basedir=$($maria.Replace('\', '/'))", "datadir=$($data.Replace('\', '/'))",
            'bind-address=127.0.0.1', "port=$dbPort", 'skip-name-resolve', 'skip-log-bin',
            'general-log=0', 'event-scheduler=OFF', 'local-infile=0'
        ), $utf8)
        [IO.File]::WriteAllLines($clientIni, @(
            '[client]', 'protocol=tcp', 'host=127.0.0.1', "port=$dbPort", 'user=root', "password=$dbPassword"
        ), $utf8)
        [IO.File]::WriteAllLines((Join-Path $conf 'auth.conf'), @(
            'LoginServer.Bind = "127.0.0.1"', "LoginServer.Port = $loginPort"
        ), $utf8)
        [IO.File]::WriteAllLines((Join-Path $conf 'world.conf'), @(
            'WorldServer.Bind = "127.0.0.1"', 'WorldServer.PublicAddress = "127.0.0.1"', "WorldServer.Port = $worldPort",
            'SOAP.Enabled = 0', ('ReturnToLogin.LoginAddress = "127.0.0.1:' + $loginPort + '"')
        ), $utf8)
        $launch = @{
            FilePath=$server; ArgumentList=@(('--defaults-file="' + $serverIni + '"'), '--console')
            WorkingDirectory=$root; WindowStyle='Hidden'; PassThru=$true
            RedirectStandardOutput=(Join-Path $root 'mariadb.log')
            RedirectStandardError=(Join-Path $root 'mariadb-error.log')
        }
        $process = Start-Process @launch
        $record = @{Id=$process.Id; StartTicks=$process.StartTime.ToUniversalTime().Ticks.ToString()}
        [IO.File]::WriteAllText($recordPath, ($record | ConvertTo-Json -Compress), $utf8)
        for ($i=0; $i -lt 40 -and !$process.HasExited; $i++) {
            try { $null = Get-FixtureDatabase; "Fixture database ready on 127.0.0.1:$dbPort (PID $($process.Id))."; return }
            catch { Start-Sleep -Milliseconds 350 }
        }
        throw 'Fixture MariaDB did not become ready.'
    }
    { $_ -in 'Test', 'TestImport' } {
        Assert-PreparedSource
        $null = Get-FixtureDatabase
        if (@(Get-Listeners | Where-Object Port -in @($loginPort,$worldPort)).Count) { throw 'A fixture game port is busy.' }
        Get-ChildItem Env:ARCHCORE_* | ForEach-Object { Remove-Item -LiteralPath ("Env:" + $_.Name) }
        $passwordLine = @(Get-Content -LiteralPath $clientIni | Where-Object { $_ -match '^password=[a-f0-9]{32}$' })
        if ($passwordLine.Count -ne 1) { throw 'Unexpected fixture credential format.' }
        $env:ARCHCORE_ROOT = $root
        $env:ARCHCORE_CONF_DIR = $conf
        $env:ARCHCORE_DATABASE_HOST = '127.0.0.1'
        $env:ARCHCORE_DATABASE_PORT = "$dbPort"
        $env:ARCHCORE_DATABASE_USER = 'root'
        $env:ARCHCORE_DATABASE_PASSWORD = $passwordLine[0].Substring(9)
        $env:ARCHCORE_TRACE = '0'
        $env:ARCHCORE_PROBE = '0'
        Push-Location -LiteralPath $build
        try {
            $archcore = Join-Path $build "target\$target\release\archcore.exe"
            $initOutput = @(& $archcore db-init)
            if ($LASTEXITCODE -ne 0) { throw 'Fixture ArchCore migration failed.' }
            $initOutput | Set-Content -Encoding UTF8 -LiteralPath (Join-Path $root 'migrations.log')
            if ($Action -eq 'TestImport') {
                . (Join-Path $PSScriptRoot 'windows\test-spawn-import.ps1')
                Test-SyntheticSpawnImport -Fixture $root -ArchCore $archcore -SqlClient $client -Endpoint $endpoint
                return
            }
            $name = 'tools::sim::return_regression::archonia_665_return_to_selection'
            $testOutput = @(& rustup run $toolchain cargo test @cargoArgs -p archcore -- $name --exact --ignored --nocapture)
            $success = $LASTEXITCODE -eq 0
            $testOutput | Where-Object { $_ -match '^\[fixture-(?:login|world)\]|^test |^Verified normal login' } |
                Set-Content -Encoding UTF8 -LiteralPath (Join-Path $root 'regression.log')
            $testOutput | Where-Object { $_ -match '^Verified normal login|^test result:' }
            if (!$success) { throw 'The return regression failed. See the local regression log.' }
        } finally {
            Pop-Location
            Remove-Item -LiteralPath Env:ARCHCORE_DATABASE_PASSWORD -ErrorAction SilentlyContinue
        }
    }
    'Stop' {
        $process = Get-FixtureDatabase
        $null = $process.Handle
        & $admin @endpoint shutdown 2>$null
        if ($LASTEXITCODE -ne 0 -or !$process.WaitForExit(15000) -or $process.ExitCode -ne 0) {
            throw 'Fixture MariaDB failed to shut down cleanly.'
        }
        if (@(Get-Listeners | Where-Object Port -in @($dbPort,$loginPort,$worldPort)).Count) {
            throw 'A fixture listener remained after shutdown.'
        }
        'Fixture stopped. Database and logs preserved.'
    }
}
