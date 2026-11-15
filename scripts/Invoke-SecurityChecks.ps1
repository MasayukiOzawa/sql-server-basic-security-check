<#
.SYNOPSIS
Run connection context and selected security checks in one sqlcmd session.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ServerInstance,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Database,

    [ValidateNotNullOrEmpty()]
    [ValidateSet('xp_cmdshell', 'Ole Automation Procedures', 'clr enabled', 'Configuration option log', 'sa login', 'trustworthy', 'recent object changes', 'recent agent job changes', 'sysadmin logins', 'DAC connections', 'DAC XE tracking', 'service accounts', 'linked servers', 'encryption certificate log')]
    [string[]] $Checks = @('xp_cmdshell', 'Ole Automation Procedures', 'clr enabled', 'Configuration option log', 'sa login', 'trustworthy', 'recent object changes', 'recent agent job changes', 'sysadmin logins', 'DAC connections', 'DAC XE tracking', 'service accounts', 'linked servers', 'encryption certificate log'),

    [string] $ExpectedServerName,

    [ValidateSet('Windows', 'Sql', 'EntraMfa')]
    [string] $Authentication = 'Windows',

    [string] $UserName,

    [ValidateRange(1, 65534)]
    [int] $LoginTimeoutSeconds = 15,

    [ValidateRange(1, 65534)]
    [int] $QueryTimeoutSeconds = 30,

    [ValidateNotNullOrEmpty()]
    [string] $SqlcmdPath = 'sqlcmd',

    [switch] $Execute
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$catalog = [ordered]@{
    'xp_cmdshell' = 'check-xp-cmdshell.sql'
    'Ole Automation Procedures' = 'check-ole-automation-procedures.sql'
    'clr enabled' = 'check-clr-enabled.sql'
    'Configuration option log' = 'check-configuration-option-log.sql'
    'sa login' = 'check-sa-login.sql'
    'trustworthy' = 'check-trustworthy.sql'
    'recent object changes' = 'check-recent-object-changes.sql'
    'recent agent job changes' = 'check-recent-agent-job-changes.sql'
    'sysadmin logins' = 'check-sysadmin-logins.sql'
    'DAC connections' = 'check-dac-connections.sql'
    'DAC XE tracking' = 'check-dac-xe-tracking.sql'
    'service accounts' = 'check-service-accounts.sql'
    'linked servers' = 'check-linked-servers.sql'
    'encryption certificate log' = 'check-encryption-certificate-log.sql'
}
$queryRoot = Join-Path $PSScriptRoot '../assets/queries'
$selected = @($Checks | Select-Object -Unique)
$files = @((Join-Path $queryRoot 'connection-check.sql'))
foreach ($check in $selected) { $files += Join-Path $queryRoot $catalog[$check] }
# Validate the context in the same session, before running any diagnostic query.
$databaseLiteral = $Database.Replace("'", "''")
$guard = "IF DB_NAME() <> N'$databaseLiteral' THROW 51000, 'Unexpected database. Checks stopped.', 1;"
if (-not [string]::IsNullOrWhiteSpace($ExpectedServerName)) {
    $serverLiteral = $ExpectedServerName.Replace("'", "''")
    $guard += "`nIF CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')) IS NULL OR CONVERT(nvarchar(128), SERVERPROPERTY('ServerName')) <> N'$serverLiteral' THROW 51001, 'Unexpected server. Checks stopped.', 1;"
}
$parts = @($guard)
foreach ($file in $files) {
    $text = Get-Content -LiteralPath $file -Raw -Encoding utf8
    if ([string]::IsNullOrWhiteSpace($text)) { throw "SQL file is empty: $file" }
    $parts += $text
}
$batchSql = $parts -join "`r`nGO`r`n"
$batchFile = Join-Path ([IO.Path]::GetTempPath()) ('sql-security-' + [guid]::NewGuid().ToString('N') + '.sql')
try {
    Set-Content -LiteralPath $batchFile -Value $batchSql -Encoding utf8
    $parameters = @{}
    foreach ($key in $PSBoundParameters.Keys) {
        if ($key -notin @('Checks', 'ExpectedServerName')) { $parameters[$key] = $PSBoundParameters[$key] }
    }
    $parameters.QueryFile = $batchFile
    # Exactly one invocation: one sqlcmd process / one connection when executing.
    $output = & (Join-Path $PSScriptRoot 'Invoke-SqlQuery.ps1') @parameters
    if ($Execute) { $output } else {
        $output | Add-Member -NotePropertyName Checks -NotePropertyValue $selected
        $output | Add-Member -NotePropertyName SourceFiles -NotePropertyValue $files
        $output | Add-Member -NotePropertyName BatchSql -NotePropertyValue $batchSql
        $output
    }
} finally {
    if (Test-Path -LiteralPath $batchFile) { Remove-Item -LiteralPath $batchFile }
}
