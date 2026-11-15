$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../scripts/SqlPrerequisites.ps1')
$baseline = @{
    Windows = $true; PowerShellVersion = [version]'7.0'
    SqlcmdPath = 'fixture.exe'; SqlcmdVersion = [version]'15.0.4298.1'; OdbcSqlcmd = $true
    DriverName = 'ODBC Driver 17 for SQL Server'; DriverVersion = [version]'17.2'
    DriverPresent = $true; DesktopAvailable = $true; InputRedirected = $false; InspectionError = $null
}
foreach ($authentication in @('Windows', 'Sql', 'EntraMfa')) {
    Assert-SqlPrerequisites -Facts $baseline -Authentication $authentication
}
# Old or unavailable version metadata must never block an otherwise usable environment.
foreach ($version in @([version]'1.0', $null)) {
    $facts = $baseline.Clone()
    $facts.PowerShellVersion = $version
    $facts.SqlcmdVersion = $version
    $facts.DriverVersion = $version
    Assert-SqlPrerequisites -Facts $facts -Authentication Windows
}
$cases = @(
    @{ Field = 'Windows'; Value = $false; Auth = 'Windows'; Message = 'Windows' },
    @{ Field = 'SqlcmdPath'; Value = $null; Auth = 'Windows'; Message = '-SqlcmdPath' },
    @{ Field = 'OdbcSqlcmd'; Value = $false; Auth = 'Windows'; Message = 'ODBC' },
    @{ Field = 'DriverPresent'; Value = $false; Auth = 'Windows'; Message = 'インストール' },
    @{ Field = 'DesktopAvailable'; Value = $false; Auth = 'EntraMfa'; Message = '対話' },
    @{ Field = 'InputRedirected'; Value = $true; Auth = 'Sql'; Message = '標準入力' },
    @{ Field = 'InspectionError'; Value = '読み取り失敗'; Auth = 'Windows'; Message = '読み取り失敗' }
)
foreach ($case in $cases) {
    $facts = $baseline.Clone()
    $facts[$case.Field] = $case.Value
    $caught = $false
    try { Assert-SqlPrerequisites -Facts $facts -Authentication $case.Auth } catch {
        $caught = $true
        if ($_.Exception.Message -notmatch $case.Message) { throw }
    }
    if (-not $caught) { throw "Expected prerequisite failure: $($case.Field)" }
}
# Both entrypoint modes must reject a missing tool before any native SQL execution.
foreach ($execute in @($false, $true)) {
    $caught = $false
    try {
        & (Join-Path $PSScriptRoot '../scripts/Invoke-SqlQuery.ps1') `
            -ServerInstance 'preview.invalid' -Database 'master' `
            -QueryFile (Join-Path $PSScriptRoot '../assets/queries/check-xp-cmdshell.sql') `
            -SqlcmdPath 'missing-sqlcmd-prerequisite-test.exe' -Execute:$execute
    } catch {
        $caught = $true
        if ($_.Exception.Message -notmatch '前提環境チェックに失敗') { throw }
    }
    if (-not $caught) { throw 'Entrypoint failed to stop on missing sqlcmd.' }
}
Write-Output 'PASS: 5 valid environments (including old/missing versions), 7 prerequisite failures, 2 entrypoint stop checks. No database connections.'
