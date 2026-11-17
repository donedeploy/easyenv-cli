# Install the easyenv CLI on Windows. In PowerShell:
#
#   irm https://get.easyenv.io/cli.ps1 | iex
#
# It takes the latest release, checks the download against that release's
# checksums.txt, puts easyenv.exe in $HOME\bin, and adds that folder to your
# user Path when it is not there yet. Run it again to upgrade in place.
#
# Optional settings:
#   $env:EASYENV_VERSION = '0.6.1'     install that release instead of the latest
#   $env:EASYENV_RELEASES_URL = '...'  a mirror laid out like the GitHub releases
#
# `iex` runs this inside your own PowerShell session, so all of it is one
# script block: no variable leaks into your session, and a failure is a
# `throw` that stops the install, never an `exit` that would close your window.

& {
    $ErrorActionPreference = 'Stop'
    # Windows PowerShell 5.1 downloads many times slower while it draws a progress bar.
    $ProgressPreference = 'SilentlyContinue'
    # Windows PowerShell 5.1 on an older .NET offers only TLS 1.0 and 1.1, which GitHub refuses.
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    if ($PSVersionTable.PSVersion.Major -ge 6 -and -not $IsWindows) {
        throw 'easyenv install: this script is for Windows. On macOS and Linux run: curl -fsSL https://get.easyenv.io/cli | sh'
    }
    # A 32-bit PowerShell on 64-bit Windows says x86 here and names the real CPU in PROCESSOR_ARCHITEW6432.
    $cpu = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    if ($cpu -ne 'AMD64' -and $cpu -ne 'ARM64') {
        throw "easyenv install: there is no easyenv build for $cpu Windows. The Windows build is for 64-bit x64 (Windows 11 on arm64 runs it too)."
    }

    $releases = if ($env:EASYENV_RELEASES_URL) { $env:EASYENV_RELEASES_URL.TrimEnd('/') } else { 'https://github.com/donedeploy/easyenv-cli/releases' }
    $version = if ($env:EASYENV_VERSION) { $env:EASYENV_VERSION.Trim().TrimStart('v') } else { 'latest' }
    # The checksums name every build, version included, so they answer which
    # release is the latest without the GitHub API and its rate limit. The
    # binary is then fetched from that exact release.
    $sumsUrl = if ($version -eq 'latest') { "$releases/latest/download/checksums.txt" } else { "$releases/download/$version/checksums.txt" }

    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('easyenv-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Path $tmp | Out-Null
    try {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $sumsUrl -OutFile "$tmp\checksums.txt"
        } catch {
            throw "easyenv install: could not download ${sumsUrl}: $($_.Exception.Message)"
        }
        $want = $null; $name = $null; $ver = $null
        foreach ($line in Get-Content -LiteralPath "$tmp\checksums.txt") {
            $parts = -split $line
            if ($parts.Count -ge 2 -and $parts[1].TrimStart('*') -match '^easyenv_(.+)_windows_amd64\.exe$') {
                $want = $parts[0].ToLowerInvariant(); $name = $parts[1].TrimStart('*'); $ver = $Matches[1]
                break
            }
        }
        if (-not $name) { throw "easyenv install: release $version has no Windows build" }

        $url = "$releases/download/$ver/$name"
        Write-Host "Downloading easyenv $ver for windows/amd64"
        try {
            Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile "$tmp\easyenv.exe"
        } catch {
            throw "easyenv install: could not download ${url}: $($_.Exception.Message)"
        }
        $got = (Get-FileHash -Algorithm SHA256 -LiteralPath "$tmp\easyenv.exe").Hash.ToLowerInvariant()
        if ($got -ne $want) {
            throw "easyenv install: checksum mismatch for ${name}: checksums.txt says $want, the download is $got. The file is damaged or is not the one that was released, so nothing was installed. Try again; if it happens again, report it at https://github.com/donedeploy/easyenv-cli/issues"
        }

        $dir = Join-Path $HOME 'bin'
        $exe = Join-Path $dir 'easyenv.exe'
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        # A running easyenv.exe cannot be overwritten, but it can be renamed
        # out of the way; the old copy is deleted when nothing holds it.
        $old = "$exe.old"
        Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $exe) { Move-Item -LiteralPath $exe -Destination $old -Force }
        Move-Item -LiteralPath "$tmp\easyenv.exe" -Destination $exe
        Remove-Item -LiteralPath $old -Force -ErrorAction SilentlyContinue
        Unblock-File -LiteralPath $exe -ErrorAction SilentlyContinue
        Write-Host "Installed $exe"

        # The user's own Path, read from the registry as stored: $env:Path is
        # the machine and user Paths joined, and writing that back would copy
        # every machine entry into the user's. Read unexpanded and written back
        # as an expandable string, so entries like %USERPROFILE%\... stay as
        # they are. Added only when missing, so a rerun never grows it.
        $same = { param($entry) [Environment]::ExpandEnvironmentVariables($entry).TrimEnd('\') -ieq $dir.TrimEnd('\') }
        $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true)
        try {
            $userPath = [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
            if (-not ($userPath -split ';' | Where-Object { $_ -and (& $same $_) })) {
                $newPath = if ($userPath.TrimEnd(';')) { $userPath.TrimEnd(';') + ';' + $dir } else { $dir }
                $key.SetValue('Path', $newPath, [Microsoft.Win32.RegistryValueKind]::ExpandString)
                # The registry write alone does not tell Explorer, so terminals
                # opened from it would not see the change. Setting a variable
                # through .NET broadcasts that the environment changed.
                [Environment]::SetEnvironmentVariable('EASYENV_INSTALL_REFRESH', '1', 'User')
                [Environment]::SetEnvironmentVariable('EASYENV_INSTALL_REFRESH', $null, 'User')
                Write-Host "Added $dir to your user Path"
            }
        } finally {
            $key.Close()
        }
        # This window too, so easyenv works here without opening a new one.
        if (-not ($env:Path -split ';' | Where-Object { $_ -and (& $same $_) })) {
            $env:Path = $env:Path.TrimEnd(';') + ';' + $dir
        }

        & $exe --version
        if ($LASTEXITCODE -ne 0) { throw "easyenv install: $exe was installed but does not run on this machine" }
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}
