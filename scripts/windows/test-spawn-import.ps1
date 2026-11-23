# Loaded by the runner after it has verified and migrated the disposable database.
function Test-SyntheticSpawnImport {
    param(
        [Parameter(Mandatory)][string]$Fixture,
        [Parameter(Mandatory)][string]$ArchCore,
        [Parameter(Mandatory)][string]$SqlClient,
        [Parameter(Mandatory)][string[]]$Endpoint
    )

    $ErrorActionPreference = 'Stop'
    $inputs = Join-Path $Fixture 'synthetic-spawn-inputs'
    if (Test-Path -LiteralPath $inputs) { throw 'Use a fresh fixture for the spawn import test.' }
    $clientTables = Join-Path $inputs 'client'
    $serverTables = Join-Path $inputs 'server'
    $null = New-Item -ItemType Directory -Path $clientTables
    $null = New-Item -ItemType Directory -Path (Join-Path $serverTables 'objects')
    $env:ARCHCORE_CLIENT_DATA_DIR = Join-Path $inputs 'game'

    function Write-Tables([string]$Folder, [string[]]$Empty, [hashtable]$Tables) {
        foreach ($name in $Empty) {
            [IO.File]::WriteAllText((Join-Path $Folder $name), '')
        }
        foreach ($name in $Tables.Keys) {
            [IO.File]::WriteAllText((Join-Path $Folder $name), $Tables[$name], [Text.Encoding]::ASCII)
        }
    }

    $npc = "[901]`nName=Fixture Keeper`nTID=9001`nPosition=10,20,30`nDegree=0,5`n"
    $npc += "[902]`nName=Missing Template`nTID=9003`nPosition=15,20,30`n"
    Write-Tables $clientTables @(
        'LevelUpExp.txt', 'GrowUpFactor.txt', 'logincharpos.ini', 'itemtemplateentry.ini', 'SKILLTEMPLATE.ini',
        'SKILL_SPEC.txt', 'SKILL_CONST.txt', 'itemoptiontable.txt', 'itemruneattributetable.txt',
        'npctradeitemlist.txt', 'RegionTemplate.ini', 'TeleportPoint.ini', 'itemdatatable.txt'
    ) @{
        'npc.ini' = $npc.Replace('10,20,30', '11,20,30')
        'charactertemplate.ini' = "[9001]`nName=Fixture Keeper`n[9002]`nName=Fixture Crawler`n"
        'CharacterDataTable.txt' = "TID`tName`n9001`tFixture Keeper`n9002`tFixture Crawler`n"
        'CharacterTemplatePublic.ini' = "[9002]`n1=Fixture Crawler`n"
    }
    Write-Tables $serverTables @(
        'itemdatatable.txt', 'skilltemplate.ini', 'itemoptiontable.txt', 'levelupexp.ini',
        'growupfactor.ini', 'skillspec.txt', 'skillconst.txt', 'itemruneattributetable.txt',
        'itemconverttable.txt', 'itemlotterybox.txt', 'avatarset.ini', 'gachatypetemplate.ini',
        'refineryrecipetable.txt', 'npctradelist.txt', 'regiontemplate.ini', 'teleportpoint.ini', 'teleportfee.txt'
    ) @{
        'npc.ini' = $npc
        'characterdatatable.txt' = "TID`tName`tLVL`n9001`tFixture Keeper`t1`n9002`tFixture Crawler`t4`n"
        'spawndatatable.txt' = (@(
            "GroupName`tName`tTotalMobCount`tSpawntime`tMobTID`tMobLV`tRate`tMaxMobCount`tMobAITID`tSiegeWarType`tIsBoss",
            "fixture`ttest-point`t2`t7`t9002`t1`t10000`t2`t0`t0`t0",
            "fixture`torphan-point`t1`t7`t9002`t1`t10000`t1`t0`t0`t0"
        ) -join "`n")
        'spawninstancetable.txt' = "Name`tPosition`tRotation`tRadius`ntest-point`t40,50,60`t0,15`t8`n"
    }

    $initial = @('SELECT (SELECT COUNT(*) FROM archcore_world.npc_spawn), (SELECT COUNT(*) FROM archcore_world.monster_spawn), (SELECT COUNT(*) FROM archcore_world.import_run);' |
        & $SqlClient @Endpoint --batch --raw --skip-column-names)
    if ($LASTEXITCODE -ne 0 -or $initial.Count -ne 1 -or $initial[0] -cne "0`t0`t0") {
        throw 'The spawn tables and import history must start empty.'
    }

    $log = Join-Path $Fixture 'spawn-import.log'
    & $ArchCore import $clientTables --server $serverTables > $log
    if ($LASTEXITCODE -ne 0) { throw 'The synthetic import failed. See spawn-import.log.' }

    $query = @'
SELECT COUNT(*), SUM(id=901 AND tid=9001 AND name='Fixture Keeper' AND pos_x=10 AND pos_y=20 AND pos_z=30 AND degree_y=5)
FROM archcore_world.npc_spawn;
SELECT COUNT(*), SUM(stable_key='test-point#1' AND tid=9002 AND display_name='Fixture Crawler'
    AND level=4 AND count=2 AND respawn_sec=7 AND pos_x=40 AND pos_y=50 AND pos_z=60 AND degree_y=15 AND radius=8)
FROM archcore_world.monster_spawn;
SELECT COUNT(*), SUM(finished_at IS NOT NULL) FROM archcore_world.import_run;
'@
    $observed = @($query | & $SqlClient @Endpoint --batch --raw --skip-column-names)
    if ($LASTEXITCODE -ne 0 -or ($observed -join '|') -cne "1`t1|1`t1|3`t3") {
        throw "Unexpected spawn import result: $($observed -join '; ')"
    }
    'Verified synthetic NPC merge, monster spawn join and three completed import stages.'
}
