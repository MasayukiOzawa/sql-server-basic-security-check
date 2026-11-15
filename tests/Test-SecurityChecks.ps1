$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('security-batch-test-' + [guid]::NewGuid().ToString('N'))
$scripts = Join-Path $root 'scripts'
$queries = Join-Path $root 'assets/queries'
New-Item -ItemType Directory -Path $scripts, $queries -Force | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../scripts/Invoke-SecurityChecks.ps1') -Destination $scripts
    Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot '../assets/queries') -Filter '*.sql' |
        Copy-Item -Destination $queries
    # Isolated recording runner: no real sqlcmd or network access.
    @'
param($ServerInstance, $Database, $QueryFile, $Authentication, $UserName, [switch]$Execute)
$global:SecurityBatchCalls++
$global:SecurityBatchPath = $QueryFile
$global:SecurityBatchText = Get-Content -LiteralPath $QueryFile -Raw
if ($global:SecurityBatchFailure) { throw 'Simulated execution failure' }
if ($Execute) { 'Executed once' } else { [pscustomobject]@{Mode='Preview';QueryFile=$QueryFile} }
'@ | Set-Content -LiteralPath (Join-Path $scripts 'Invoke-SqlQuery.ps1') -Encoding utf8
    $runner = Join-Path $scripts 'Invoke-SecurityChecks.ps1'
    foreach ($mode in @('Preview','Execute','Failure')) {
        $global:SecurityBatchCalls = 0
        $global:SecurityBatchFailure = $mode -eq 'Failure'
        $caught = $false
        try {
            $result = & $runner -ServerInstance 'fixture.invalid' -Database 'master' `
                -Authentication EntraMfa -UserName 'fixture@example.com' -ExpectedServerName 'FIXTURE' `
                -Execute:($mode -ne 'Preview')
        } catch {
            $caught = $true
            if ($mode -ne 'Failure' -or $_.Exception.Message -notmatch 'Simulated') { throw }
        }
        if ($global:SecurityBatchCalls -ne 1) { throw 'Expected exactly one runner invocation.' }
        if (Test-Path -LiteralPath $global:SecurityBatchPath) { throw 'Temporary SQL was not removed.' }
        if ($global:SecurityBatchText -notmatch 'Unexpected server' -or $global:SecurityBatchText -notmatch 'sp_readerrorlog' -or $global:SecurityBatchText -notmatch 'sys.server_principals' -or $global:SecurityBatchText -notmatch 'o.modify_date >= @StartTime' -or $global:SecurityBatchText -notmatch 'FROM msdb.dbo.sysjobs' -or $global:SecurityBatchText -notmatch 'WITH Membership AS' -or $global:SecurityBatchText -notmatch 'is_admin_endpoint = 1' -or $global:SecurityBatchText -notmatch 'DAC XE tracking' -or $global:SecurityBatchText -notmatch 'FROM sys.dm_server_services' -or $global:SecurityBatchText -notmatch 'FROM sys.linked_logins' -or $global:SecurityBatchText -notmatch 'encryption certificate log') { throw 'Incomplete batch.' }
        if (($mode -eq 'Failure') -ne $caught) { throw 'Unexpected error handling.' }
        if ($mode -eq 'Preview' -and $result.Checks.Count -ne 14) { throw 'Missing default checks.' }
    }
    Write-Output 'PASS: one runner call per preview/execution/failure; context guard, all checks and cleanup. No DB connections.'
} finally {
    foreach ($name in @('SecurityBatchCalls','SecurityBatchPath','SecurityBatchText','SecurityBatchFailure')) {
        Remove-Variable -Name $name -Scope Global -ErrorAction SilentlyContinue
    }
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not [IO.Path]::GetFullPath($root).StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path.' }
    Remove-Item -LiteralPath $root -Recurse -Force
}
