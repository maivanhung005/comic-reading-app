$ErrorActionPreference = 'Stop'
$BackendDir = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $BackendDir '.env.local'
if (-not (Test-Path $EnvFile)) { & (Join-Path $PSScriptRoot 'setup_backend_env_windows.ps1') }
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $i = $line.IndexOf('=')
    if ($i -lt 1) { return }
    [Environment]::SetEnvironmentVariable($line.Substring(0,$i).Trim(), $line.Substring($i+1), 'Process')
}
$email = (Read-Host 'Email Admin bootstrap rieng').Trim().ToLowerInvariant()
$username = (Read-Host 'Username Admin rieng').Trim()
$name = (Read-Host 'Ten hien thi Admin').Trim()
if ($email -notmatch '^[^\s@]+@[^\s@]+\.[^\s@]+$') { throw 'Email khong hop le.' }
if ($username -notmatch '^[A-Za-z0-9_.]{3,24}$') { throw 'Username phai dai 3-24 ky tu; chi dung chu, so, dau cham, gach duoi.' }
$secure = Read-Host 'Dat mat khau Admin (toi thieu 16 ky tu; khong duoc luu trong source)' -AsSecureString
$ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try { $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
if ($password.Length -lt 16) { throw 'Mat khau Admin phai co it nhat 16 ky tu.' }
if ([System.Text.Encoding]::UTF8.GetByteCount($password) -gt 72) { throw 'Mat khau Admin toi da 72 byte UTF-8 de phu hop voi BCrypt.' }
$env:ADMIN_BOOTSTRAP_ENABLED = 'true'
$env:ADMIN_BOOTSTRAP_EMAIL = $email
$env:ADMIN_BOOTSTRAP_USERNAME = $username
$env:ADMIN_BOOTSTRAP_NAME = $name
$env:ADMIN_BOOTSTRAP_PASSWORD = $password
try {
    Set-Location $BackendDir
    if (-not (Get-Command mvn -ErrorAction SilentlyContinue)) { throw 'Khong tim thay Maven trong PATH.' }
    Write-Host 'Dang khoi dong Backend de tao Admin mot lan. Mat khau khong duoc ghi vao project/log.'
    & mvn spring-boot:run
} finally {
    foreach ($key in @('ADMIN_BOOTSTRAP_ENABLED','ADMIN_BOOTSTRAP_EMAIL','ADMIN_BOOTSTRAP_USERNAME','ADMIN_BOOTSTRAP_NAME','ADMIN_BOOTSTRAP_PASSWORD')) { Remove-Item "Env:$key" -ErrorAction SilentlyContinue }
    $password = $null
    $secure = $null
}
