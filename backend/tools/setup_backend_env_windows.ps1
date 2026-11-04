$ErrorActionPreference = 'Stop'
$BackendDir = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $BackendDir '.env.local'
if (Test-Path $EnvFile) {
    $overwrite = Read-Host 'Da co backend/.env.local. Ghi de? (y/N)'
    if ($overwrite -notin @('y','Y')) { Write-Host 'Giu nguyen cau hinh hien tai.'; exit 0 }
}
$dbUser = Read-Host 'PostgreSQL username [postgres]'
if ([string]::IsNullOrWhiteSpace($dbUser)) { $dbUser = 'postgres' }
$dbPasswordSecure = Read-Host 'PostgreSQL password (an ky tu)' -AsSecureString
$dbPasswordPtr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($dbPasswordSecure)
try { $dbPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($dbPasswordPtr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($dbPasswordPtr) }
if ([string]::IsNullOrWhiteSpace($dbPassword)) { throw 'PostgreSQL password khong duoc de trong.' }
$bytes = New-Object byte[] 48
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
$jwtSecret = [Convert]::ToBase64String($bytes)
$lines = @(
  'DB_URL=jdbc:postgresql://localhost:5432/comic_db',
  "DB_USERNAME=$dbUser",
  "DB_PASSWORD=$dbPassword",
  "JWT_SECRET=$jwtSecret",
  'MAIL_HOST=smtp.gmail.com',
  'MAIL_PORT=587',
  'MAIL_USERNAME=',
  'MAIL_PASSWORD='
)
[System.IO.File]::WriteAllLines($EnvFile, $lines, [System.Text.UTF8Encoding]::new($false))
# Keep this local credential file out of source control and restrict access to the current Windows user.
try { & icacls $EnvFile /inheritance:r /grant:r "$($env:USERNAME):(R,W)" | Out-Null } catch { Write-Warning 'Khong the tu dong dat ACL; hay kiem tra quyen truy cap file .env.local.' }
Write-Host "Da tao cau hinh rieng: $EnvFile"
Write-Host 'Khong gui file nay cho nguoi khac va khong commit len Git.'
Write-Host 'JWT_SECRET duoc tao ngau nhien va duoc giu lai de token khong bi vo hieu sau moi lan khoi dong.'
