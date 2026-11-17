# Tests for install.ps1, the Windows half of test/install_test.sh. They
# install real releases from GitHub into $HOME\bin and change the user Path,
# so run them on a throwaway machine (CI runs them on windows-latest, in both
# PowerShell 7 and Windows PowerShell 5.1).
#
#   pwsh -File test/install_test.ps1 [-Shell powershell]

param([string]$Shell = 'pwsh')

$ErrorActionPreference = 'Stop'
$installer = Join-Path $PSScriptRoot '..\install.ps1' | Resolve-Path
$releases = 'https://github.com/donedeploy/easyenv-cli/releases'
$older = '0.6.0'   # any earlier release
$dir = Join-Path $HOME 'bin'
$exe = Join-Path $dir 'easyenv.exe'
$script:failures = 0

function Pass($what) { Write-Host "ok   $what" }
function Fail($what) {
    Write-Host "FAIL $what"
    if ($script:out) { $script:out | ForEach-Object { Write-Host "     | $_" } }
    $script:failures++
}
# The way people run it: the script's text piped into iex, in a fresh shell.
function Install-Easyenv([hashtable]$envs = @{}) {
    foreach ($k in $envs.Keys) { Set-Item "env:$k" $envs[$k] }
    try {
        $script:out = & $Shell -NoProfile -ExecutionPolicy Bypass -Command "Get-Content -Raw -LiteralPath '$installer' | Invoke-Expression" 2>&1
        return $LASTEXITCODE -eq 0
    } finally {
        foreach ($k in $envs.Keys) { Remove-Item "env:$k" -ErrorAction SilentlyContinue }
    }
}
function Version-Of($path) { if (Test-Path $path) { ((& $path --version) -split ' ')[2] } }
function User-Path-Count {
    $p = [Environment]::GetEnvironmentVariable('Path', 'User')
    @($p -split ';' | Where-Object { $_ -and $_.TrimEnd('\') -ieq $dir.TrimEnd('\') }).Count
}

$sums = (Invoke-WebRequest -UseBasicParsing "$releases/latest/download/checksums.txt").Content
if ($sums -is [byte[]]) { $sums = [Text.Encoding]::UTF8.GetString($sums) }
$latest = ([regex]'easyenv_([^_]+)_windows_amd64\.exe').Match($sums).Groups[1].Value
Write-Host "latest release: $latest, shell: $Shell"

# 1. Fresh install of the latest release, and $HOME\bin on the user Path once.
if ((Install-Easyenv) -and (Version-Of $exe) -eq $latest -and (User-Path-Count) -eq 1) {
    Pass "installs the latest release ($latest) to $exe and adds $dir to the user Path"
} else { Fail "installs the latest release ($latest) to $exe and adds $dir to the user Path" }

# 2. Again: same file, and the Path entry is not duplicated.
if ((Install-Easyenv) -and (Version-Of $exe) -eq $latest -and (User-Path-Count) -eq 1) {
    Pass 'running it again keeps one copy and one Path entry'
} else { Fail 'running it again keeps one copy and one Path entry' }

# 3. A pinned older release, then the latest over it: the upgrade path.
if ((Install-Easyenv @{ EASYENV_VERSION = $older }) -and (Version-Of $exe) -eq $older) {
    Pass "EASYENV_VERSION=$older installs that release"
} else { Fail "EASYENV_VERSION=$older installs that release" }
if ((Install-Easyenv) -and (Version-Of $exe) -eq $latest -and (User-Path-Count) -eq 1) {
    Pass "running it again upgrades in place ($older -> $latest)"
} else { Fail "running it again upgrades in place ($older -> $latest)" }

# 4. A checksum that does not match stops the install and leaves the
#    installed copy alone. The fake release is served over local http.
$fake = Join-Path ([IO.Path]::GetTempPath()) ('easyenv-fake-' + [guid]::NewGuid())
New-Item -ItemType Directory -Force "$fake\latest\download", "$fake\download\9.9.9" | Out-Null
Set-Content -LiteralPath "$fake\download\9.9.9\easyenv_9.9.9_windows_amd64.exe" -Value 'not the real binary'
Set-Content -LiteralPath "$fake\latest\download\checksums.txt" -Value (('0' * 64) + '  easyenv_9.9.9_windows_amd64.exe')
$port = Get-Random -Minimum 20000 -Maximum 40000
$server = Start-Process python -ArgumentList '-m', 'http.server', $port, '--bind', '127.0.0.1', '--directory', $fake -PassThru -WindowStyle Hidden
try {
    Start-Sleep -Seconds 2
    $ok = Install-Easyenv @{ EASYENV_RELEASES_URL = "http://127.0.0.1:$port" }
    if (-not $ok -and ($script:out -join "`n") -match 'checksum mismatch' -and (Version-Of $exe) -eq $latest) {
        Pass 'a wrong checksum stops the install, with a clear message, and keeps the installed copy'
    } else { Fail 'a wrong checksum stops the install, with a clear message, and keeps the installed copy' }
} finally {
    Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $fake -ErrorAction SilentlyContinue
}

if ($script:failures) { throw "$($script:failures) failed" }
Write-Host 'all passed'
