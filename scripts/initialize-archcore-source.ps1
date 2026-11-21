#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = Split-Path -Parent $PSScriptRoot
$relativePath = 'server/archcore'
$source = Join-Path $root $relativePath
$officialUrl = 'https://github.com/BlaMacfly/ArchCore.git'
$allowed = '.gitattributes', '.gitignore', 'Cargo.toml', 'Cargo.lock', 'LICENSE', 'README.md', 'crates', 'sql'
$patterns = '/.gitattributes', '/.gitignore', '/Cargo.toml', '/Cargo.lock', '/LICENSE', '/README.md', '/crates/', '/sql/'

function Invoke-Git([string[]]$Arguments) {
    & git -c core.hooksPath=NUL @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Git failed ($LASTEXITCODE)." }
}

function Get-ObjectBlobs {
    Invoke-Git @('-C', $source, 'cat-file', '--batch-all-objects', '--batch-check=%(objecttype) %(objectname)') |
        ForEach-Object { if ($_ -match '^blob ([0-9a-f]{40})$') { $Matches[1] } }
}

$url = Invoke-Git @('config', '--file', (Join-Path $root '.gitmodules'), '--get', 'submodule.server/archcore.url')
if ($url -cne $officialUrl) { throw 'The submodule URL is not the reviewed ArchCore upstream.' }
$entry = Invoke-Git @('-C', $root, 'ls-files', '--stage', '--', $relativePath)
if ($entry -notmatch "^160000 ([0-9a-f]{40}) 0\s+$relativePath$") { throw 'The primary repository index does not contain a single ArchCore gitlink.' }
$revision = $Matches[1]

$fresh = -not (Test-Path -LiteralPath (Join-Path $source '.git'))
if ($fresh) {
    if ((Test-Path -LiteralPath $source) -and @(Get-ChildItem -LiteralPath $source -Force).Count -ne 0) {
        throw 'The ArchCore destination already contains files.'
    }
    $traceSetting = $env:GIT_TRACE_PACKET
    try {
        $env:GIT_TRACE_PACKET = '1'
        $ErrorActionPreference = 'Continue'
        $remoteTrace = @(& git -c protocol.version=2 ls-remote $url HEAD 2>&1 | ForEach-Object { $_.ToString() })
        if ($LASTEXITCODE -ne 0 -or -not ($remoteTrace -match 'git< fetch=.*\bfilter\b')) {
            throw 'The upstream did not confirm partial clone support.'
        }
    } finally {
        $ErrorActionPreference = 'Stop'
        $env:GIT_TRACE_PACKET = $traceSetting
    }
    [void](New-Item -Path (Split-Path -Parent $source) -ItemType Directory -Force)
    Invoke-Git @('-c', 'protocol.version=2', 'clone', "--revision=$revision", '--filter=blob:none', '--no-checkout', '--no-tags', '--no-recurse-submodules', '--', $url, $source)
    if (@(Get-ObjectBlobs).Count -ne 0) { throw 'The initial partial clone contains unexpected blobs.' }

    $sourceEntries = @(Invoke-Git (@('-C', $source, 'ls-tree', '-r', $revision, '--') + $allowed))
    $expectedBlobs = $sourceEntries |
        ForEach-Object {
            if ($_ -notmatch '^100(?:644|755) blob ([0-9a-f]{40})\t(.+)$') {
                throw 'Unexpected object type in the ArchCore source paths.'
            }
            $objectId = $Matches[1]
            if ($Matches[2] -match '(?:^|/)\.gitattributes$') {
                $attributes = @(Invoke-Git @('-C', $source, 'cat-file', 'blob', $objectId))
                if ($attributes -match '(?:^|\s)filter(?:=|\s|$)') { throw 'The reviewed source checkout does not allow Git smudge filters.' }
            }
            $objectId
        } | Sort-Object -Unique
    Invoke-Git (@('-C', $source, 'sparse-checkout', 'set', '--no-cone', '--') + $patterns)
    Invoke-Git @('-C', $source, 'switch', '--detach', $revision)
} elseif ((Invoke-Git @('-C', $source, 'rev-parse', 'HEAD')) -ne $revision) {
    throw 'The existing ArchCore checkout is at a different revision. Review its status before switching.'
}

if ((Invoke-Git @('-C', $source, 'remote', 'get-url', 'origin')) -cne $url) { throw 'The ArchCore checkout uses an unexpected remote.' }
if ((Invoke-Git @('-C', $source, 'config', '--get', 'remote.origin.partialclonefilter')) -ne 'blob:none') { throw 'The ArchCore checkout is not a blobless partial clone.' }
$actualPatterns = @(Invoke-Git @('-C', $source, 'sparse-checkout', 'list'))
if (Compare-Object -ReferenceObject $patterns -DifferenceObject $actualPatterns) { throw 'The ArchCore sparse checkout paths differ from the reviewed profile.' }

if ($fresh) {
    $actualBlobs = Get-ObjectBlobs | Sort-Object -Unique
    if (-not $actualBlobs -or (Compare-Object -ReferenceObject $expectedBlobs -DifferenceObject $actualBlobs)) {
        throw 'The downloaded blobs differ from the selected source files.'
    }
}
if (@(Invoke-Git @('-C', $source, 'status', '--porcelain')).Count -ne 0) { throw 'ArchCore has local changes. Review them before initialising the submodule.' }
Invoke-Git @('-C', $root, 'submodule', 'init', '--', $relativePath)
Invoke-Git @('-C', $root, 'submodule', 'absorbgitdirs', '--', $relativePath)
Invoke-Git @('-C', $root, 'submodule', 'status', '--', $relativePath)
