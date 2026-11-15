<#
.SYNOPSIS
Preview or execute a UTF-8 T-SQL file using ODBC sqlcmd.
.DESCRIPTION
No connection is made unless -Execute is supplied. This helper does not enforce
read-only SQL; database permissions and the caller's authorized scope apply.
Encryption is requested; server certificate validation is skipped as configured.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $ServerInstance,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $Database,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string] $QueryFile,

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
. (Join-Path $PSScriptRoot 'SqlPrerequisites.ps1')

if ($Authentication -eq 'Windows' -and $PSBoundParameters.ContainsKey('UserName')) {
    throw 'UserName is not supported with Windows authentication.'
}
if ($Authentication -ne 'Windows' -and [string]::IsNullOrWhiteSpace($UserName)) {
    throw 'UserName is required for Sql and EntraMfa authentication.'
}
if ($Authentication -eq 'EntraMfa') {
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { throw 'EntraMfa requires Windows and interactive ODBC sqlcmd.' }
    if (-not $PSBoundParameters.ContainsKey('LoginTimeoutSeconds')) {
        $LoginTimeoutSeconds = 120
    }
}
$authenticationArguments = switch ($Authentication) {
    'Windows' { '-E' }
    'Sql' { '-U'; $UserName }
    'EntraMfa' { '-G'; '-U'; $UserName }
}

if ([string]::IsNullOrWhiteSpace($ServerInstance) -or [string]::IsNullOrWhiteSpace($Database)) {
    throw 'ServerInstance and Database must not be blank.'
}
if (-not (Test-Path -LiteralPath $QueryFile -PathType Leaf)) {
    throw "SQL file not found: $QueryFile"
}
$resolvedQueryFile = (Resolve-Path -LiteralPath $QueryFile).ProviderPath
if ([IO.Path]::GetExtension($resolvedQueryFile) -ine '.sql') {
    throw 'QueryFile must have a .sql extension.'
}
$queryText = Get-Content -LiteralPath $resolvedQueryFile -Raw -Encoding utf8
if ([string]::IsNullOrWhiteSpace($queryText)) {
    throw 'QueryFile must not be empty.'
}
# This is a conservative client-command check, not a T-SQL permission check.
if ($queryText -match '(?m)^[\t ]*(?::|!!)') {
    throw 'sqlcmd directives and shell commands are not supported. Use T-SQL and GO only.'
}

$sqlcmdArguments = @(
    '-S', $ServerInstance,
    '-d', $Database,
    '-N', '-C', '-b', '-r', '1', '-X1', '-x',
    '-l', $LoginTimeoutSeconds.ToString(),
    '-t', $QueryTimeoutSeconds.ToString(),
    '-f', '65001',
    '-y', '0',
    '-i', $resolvedQueryFile
) + @($authenticationArguments)

$prerequisites = Get-SqlPrerequisiteFacts -SqlcmdPath $SqlcmdPath
Assert-SqlPrerequisites -Facts $prerequisites -Authentication $Authentication

if (-not $Execute) {
    [pscustomobject]@{
        Mode = 'Preview'
        ServerInstance = $ServerInstance
        Database = $Database
        Authentication = $Authentication
        EncryptConnection = $true
        TrustServerCertificate = $true
        UserName = $UserName
        QueryFile = $resolvedQueryFile
        LoginTimeoutSeconds = $LoginTimeoutSeconds
        QueryTimeoutSeconds = $QueryTimeoutSeconds
        SqlcmdPath = $SqlcmdPath
        Arguments = $sqlcmdArguments
        Prerequisites = 'Passed (local checks only)'
        ResolvedSqlcmdPath = $prerequisites.SqlcmdPath
        DriverName = $prerequisites.DriverName
    }
    return
}

# Inspect the native exit code ourselves, independently of the caller's setting.
$PSNativeCommandUseErrorActionPreference = $false
$savedPassword = [Environment]::GetEnvironmentVariable('SQLCMDPASSWORD', 'Process')
try {
    # Always prompt for SQL credentials / Entra interaction; never inherit a password.
    [Environment]::SetEnvironmentVariable('SQLCMDPASSWORD', $null, 'Process')
    & $prerequisites.SqlcmdPath @sqlcmdArguments
    if ($LASTEXITCODE -ne 0) {
        throw "sqlcmd failed with exit code $LASTEXITCODE. 未判定として停止します。上のエラーに従い、接続先と通信、認証方式／資格情報、TLS の対応状況、チェック定義の必要権限を確認してください。設定や認証方式は自動変更しません。"
    }
} finally {
    [Environment]::SetEnvironmentVariable('SQLCMDPASSWORD', $savedPassword, 'Process')
    $savedPassword = $null
}
