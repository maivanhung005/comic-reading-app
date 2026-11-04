$ErrorActionPreference = 'Stop'
$BackendDir = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $BackendDir '.env.local'
if (-not (Test-Path $EnvFile)) {
    Write-Host 'Chua co backend/.env.local; se chay buoc tao cau hinh.'
    & (Join-Path $PSScriptRoot 'setup_backend_env_windows.ps1')
}
if (-not (Test-Path $EnvFile)) { throw 'Khong tao duoc .env.local.' }
Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith('#')) { return }
    $i = $line.IndexOf('=')
    if ($i -lt 1) { return }
    $key = $line.Substring(0, $i).Trim()
    $value = $line.Substring($i + 1)
    [Environment]::SetEnvironmentVariable($key, $value, 'Process')
}
if ([string]::IsNullOrWhiteSpace($env:JWT_SECRET) -or $env:JWT_SECRET.Length -lt 32) { throw 'JWT_SECRET khong hop le trong .env.local.' }
Set-Location $BackendDir
if (-not (Get-Command mvn -ErrorAction SilentlyContinue)) { throw 'Khong tim thay Maven (mvn). Cai Maven hoac mo terminal da co Maven trong PATH.' }
& mvn spring-boot:run
