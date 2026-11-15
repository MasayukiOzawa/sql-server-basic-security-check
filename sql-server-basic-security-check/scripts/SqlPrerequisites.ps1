# Local checks only: do not connect, install software, or change settings.
function Get-SqlPrerequisiteFacts {
    param([string] $SqlcmdPath)
    $facts = @{
        Windows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
        SqlcmdPath = $null; OdbcSqlcmd = $false
        DriverName = $null; DriverPresent = $false
        DesktopAvailable = [Environment]::UserInteractive -and
            ([Diagnostics.Process]::GetCurrentProcess().SessionId -gt 0)
        InputRedirected = [Console]::IsInputRedirected
        InspectionError = $null
    }
    if (-not $facts.Windows) { return $facts }
    try {
        $command = Get-Command -Name $SqlcmdPath -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $command) { return $facts }
        $facts.SqlcmdPath = $command.Source
        $info = [Diagnostics.FileVersionInfo]::GetVersionInfo($command.Source)
        $bytes = [IO.File]::ReadAllBytes($command.Source)
        $dependency = [regex]::Match([Text.Encoding]::ASCII.GetString($bytes), 'msodbcsql(\d+)\.dll', 'IgnoreCase')
        $facts.OdbcSqlcmd = $info.OriginalFilename -ieq 'SQLCMD.exe' -and $dependency.Success
        if (-not $facts.OdbcSqlcmd) { return $facts }
        $peOffset = [BitConverter]::ToInt32($bytes, 0x3c)
        $machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
        $view = switch ($machine) {
            0x8664 { [Microsoft.Win32.RegistryView]::Registry64 }
            0x014c { [Microsoft.Win32.RegistryView]::Registry32 }
            default { throw 'sqlcmd の CPU アーキテクチャを確認できません。x64 / x86 版を指定してください。' }
        }
        $facts.DriverName = "ODBC Driver $($dependency.Groups[1].Value) for SQL Server"
        $registry = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine, $view)
        try {
            $key = $registry.OpenSubKey("SOFTWARE\ODBC\ODBCINST.INI\$($facts.DriverName)")
            if ($key) {
                try { $driverPath = [string]$key.GetValue('Driver') } finally { $key.Dispose() }
                if ($driverPath -and (Test-Path -LiteralPath $driverPath -PathType Leaf)) {
                    $driverBytes = [IO.File]::ReadAllBytes($driverPath)
                    $driverPeOffset = [BitConverter]::ToInt32($driverBytes, 0x3c)
                    $facts.DriverPresent = [BitConverter]::ToUInt16($driverBytes, $driverPeOffset + 4) -eq $machine
                }
            }
        } finally { $registry.Dispose() }
    } catch {
        $facts.InspectionError = '実行ファイルまたは ODBC の登録情報を読み取れません。読み取り権限とインストール状態を確認してください。'
    }
    return $facts
}

function Assert-SqlPrerequisites {
    param([hashtable] $Facts, [string] $Authentication)
    $issues = [Collections.Generic.List[string]]::new()
    if (-not $Facts.Windows) { $issues.Add('Windows 上の PowerShell 7 で実行してください。') }
    if (-not $Facts.SqlcmdPath) {
        $issues.Add('ODBC 版 sqlcmd をインストールして PATH に追加するか、-SqlcmdPath に実行ファイルの絶対パスを指定してください。')
    } elseif (-not $Facts.OdbcSqlcmd) {
        $issues.Add('ODBC 版 sqlcmd を確認できません。Go 版や別コマンドではなく、Microsoft の ODBC 版 sqlcmd を -SqlcmdPath で指定してください。')
    } else {
        if (-not $Facts.DriverPresent) {
            $issues.Add("$($Facts.DriverName) の対応 DLL が見つからないか CPU アーキテクチャが異なるため、sqlcmd と同じ CPU アーキテクチャのドライバーをインストール／修復してください。別系列のドライバーだけでは代用できません。")
        }
    }
    if ($Facts.InspectionError) { $issues.Add($Facts.InspectionError) }
    if ($Authentication -ne 'Windows' -and -not $Facts.DesktopAvailable) {
        $issues.Add('対話セッションを確認できません。Windows にサインインしたユーザーの PowerShell 7 ターミナルで実行してください。')
    }
    if ($Authentication -eq 'Sql' -and $Facts.InputRedirected) {
        $issues.Add('SQL 認証のパスワードを入力できません。標準入力をリダイレクトせず、ユーザーの対話ターミナルで実行してください。')
    }
    if ($issues.Count) {
        throw ("前提環境チェックに失敗しました。DB には接続していません。`n- " +
            ($issues -join "`n- ") + "`n導入案内: https://learn.microsoft.com/sql/tools/sqlcmd/sqlcmd-download-install`nドライバー: https://learn.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server")
    }
}
