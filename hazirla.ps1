#Requires -Version 5.1
<#
  Yeni bilgisayarda bir kez calistir: hazirla.bat
  Godot 4.7.2 kurulur. oyna.bat bu dosyayi acar:
  %LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*\Godot_v*_win64.exe
#>
$ErrorActionPreference = 'Stop'
if (Test-Path variable:PSNativeCommandUseErrorActionPreference) {
    $PSNativeCommandUseErrorActionPreference = $false
}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$GodotVersion = '4.7.2'
$GodotId = 'GodotEngine.GodotEngine'
$GodotZipSha256 = '731980F9608D61333E5BAF54A2EF17210ACC7A538446C0CB9969F002ACA1E953'
$MinVersion = [version]'4.7.0'

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machine;$user"
}

function Get-GodotVersionFromName([string]$Path) {
    $name = [IO.Path]::GetFileNameWithoutExtension($Path)
    if ($name -match '^Godot_v(\d+\.\d+(?:\.\d+)?)') {
        $raw = $Matches[1]
        if (($raw.Split('.')).Count -eq 2) { $raw = "$raw.0" }
        return [version]$raw
    }
    return $null
}

function Get-WhereCommand([string]$Name) {
    $output = @()
    try {
        $output = @(& where.exe $Name 2>$null)
    } catch {
        return @()
    }
    if ($LASTEXITCODE -ne 0) { return @() }
    return @($output | Where-Object { $_ })
}

function Find-SuitableGodot {
    $candidates = New-Object System.Collections.Generic.List[string]

    foreach ($cmd in (Get-WhereCommand 'godot.cmd')) {
        $dir = Split-Path -Parent $cmd
        if (-not $dir) { continue }
        Get-ChildItem -LiteralPath $dir -Filter 'Godot_v*_win64.exe' -File -ErrorAction SilentlyContinue |
            ForEach-Object { $candidates.Add($_.FullName) }
    }

    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'),
        (Join-Path $env:ProgramFiles 'WinGet\Packages')
    )
    foreach ($root in $roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Directory -Filter 'GodotEngine.GodotEngine_*' -ErrorAction SilentlyContinue |
            ForEach-Object {
                Get-ChildItem -LiteralPath $_.FullName -Filter 'Godot_v*_win64.exe' -File -ErrorAction SilentlyContinue |
                    ForEach-Object { $candidates.Add($_.FullName) }
            }
    }

    $best = $null
    $bestVer = $null
    foreach ($path in $candidates) {
        $ver = Get-GodotVersionFromName $path
        if ($null -eq $ver -or $ver -lt $MinVersion) { continue }
        if ($null -eq $bestVer -or $ver -gt $bestVer) {
            $bestVer = $ver
            $best = $path
        }
    }
    return $best
}

function Get-WingetPath {
    Refresh-Path
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }
    $candidate = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    return $null
}

function Test-WingetWorks([string]$Path) {
    if (-not $Path) { return $false }
    try {
        & $Path --version 1>$null 2>$null
    } catch {
        return $false
    }
    return ($LASTEXITCODE -eq 0)
}

function Ensure-Winget {
    $winget = Get-WingetPath
    if (Test-WingetWorks $winget) { return $winget }

    Write-Host "Winget yok, kuruluyor..."
    try {
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop
    } catch {
        Write-Host "Winget kaydi yenilenemedi, indiriliyor..."
    }

    $winget = Get-WingetPath
    if (Test-WingetWorks $winget) { return $winget }

    $dir = Join-Path $env:TEMP 'mt-oyun-hazirla'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $bundle = Join-Path $dir 'Microsoft.DesktopAppInstaller.msixbundle'
    Invoke-WebRequest -Uri 'https://aka.ms/getwinget' -OutFile $bundle -UseBasicParsing
    Add-AppxPackage -Path $bundle
    Refresh-Path

    $winget = Get-WingetPath
    if (-not (Test-WingetWorks $winget)) {
        throw "Winget kurulamadi. Microsoft Store'dan Uygulama Yukleyici'yi kur, sonra hazirla.bat dosyasini tekrar calistir."
    }
    return $winget
}

function Test-VcRedist {
    $sys = Join-Path $env:WINDIR 'System32'
    return (Test-Path -LiteralPath (Join-Path $sys 'vcruntime140.dll')) -and
           (Test-Path -LiteralPath (Join-Path $sys 'vcruntime140_1.dll'))
}

function Install-VcRedist([string]$Winget) {
    if (Test-VcRedist) { return }
    Write-Host "Visual C++ eksik, kuruluyor. Pencere acilirsa Evet de."

    if ($Winget) {
        & $Winget install --id 'Microsoft.VCRedist.2015+.x64' --exact --scope machine -s winget --accept-package-agreements --accept-source-agreements --disable-interactivity
        if (Test-VcRedist) { return }
    }

    $dir = Join-Path $env:TEMP 'mt-oyun-hazirla'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $setup = Join-Path $dir 'vc_redist.x64.exe'
    & curl.exe -L --fail --retry 3 --retry-delay 2 --output $setup 'https://aka.ms/vs/17/release/vc_redist.x64.exe'
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Visual C++ indirilemedi. Oyun acilmazsa hazirla.bat dosyasini tekrar calistir."
        return
    }
    $proc = Start-Process -FilePath $setup -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru
    if (-not (Test-VcRedist)) {
        Write-Host "Visual C++ kurulamadi (cikis $($proc.ExitCode)). Oyun acilmazsa hazirla.bat dosyasini tekrar calistir ve Evet de."
    }
}

function Install-GodotWithWinget([string]$Winget) {
    Write-Host "Winget ile Godot $GodotVersion kuruluyor. Bu biraz surebilir."
    $common = @(
        '--id', $GodotId,
        '--version', $GodotVersion,
        '--exact',
        '--scope', 'user',
        '--architecture', 'x64',
        '-s', 'winget',
        '--accept-package-agreements',
        '--accept-source-agreements',
        '--disable-interactivity'
    )
    & $Winget install @common
    if (Find-SuitableGodot) { return }
    & $Winget upgrade @common
    if (Find-SuitableGodot) { return }
    Write-Host "Paket listesi yenileniyor..."
    & $Winget source update -s winget --disable-interactivity
    & $Winget install @common
}

function Install-GodotFromRelease {
    Write-Host "Godot resmi siteden indiriliyor..."
    $dir = Join-Path $env:TEMP 'mt-oyun-hazirla'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $zip = Join-Path $dir "Godot_v$GodotVersion-stable_win64.exe.zip"
    $url = "https://github.com/godotengine/godot/releases/download/$GodotVersion-stable/Godot_v$GodotVersion-stable_win64.exe.zip"
    & curl.exe -L --fail --retry 3 --retry-delay 2 --output $zip $url
    if ($LASTEXITCODE -ne 0) { throw "Godot indirilemedi. Internet baglantisini kontrol et." }

    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $zip).Hash
    if ($hash -ne $GodotZipSha256) { throw "Indirilen Godot dosyasi dogrulanamadi." }

    $dest = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\GodotEngine.GodotEngine_$GodotVersion"
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $dest -Force
    $exe = Join-Path $dest "Godot_v$GodotVersion-stable_win64.exe"
    if (-not (Test-Path -LiteralPath $exe)) { throw "Godot paketi acilamadi." }
    Unblock-File -LiteralPath $exe
    $console = Join-Path $dest "Godot_v$GodotVersion-stable_win64_console.exe"
    if (Test-Path -LiteralPath $console) { Unblock-File -LiteralPath $console }
}

function Main {
    if (-not [Environment]::Is64BitOperatingSystem) {
        throw "Bu oyun 64 bit Windows ister."
    }

    Write-Host "Oyun icin kurulum basliyor."

    $winget = $null
    try {
        $winget = Ensure-Winget
    } catch {
        Write-Host $_.Exception.Message
    }

    Install-VcRedist $winget

    $found = Find-SuitableGodot
    if ($found) {
        $ver = Get-GodotVersionFromName $found
        Write-Host ""
        Write-Host "Godot $ver zaten hazir."
        Write-Host "Simdi oyna.bat dosyasina cift tikla."
        exit 0
    }

    if ($winget) {
        Install-GodotWithWinget $winget
        $found = Find-SuitableGodot
    }

    if (-not $found) {
        Install-GodotFromRelease
        $found = Find-SuitableGodot
    }

    if (-not $found) {
        throw "Godot kuruldu ama oyna.bat'in baktigi yerde bulunamadi."
    }

    $ver = Get-GodotVersionFromName $found
    Write-Host ""
    Write-Host "Godot $ver hazir."
    Write-Host "Simdi oyna.bat dosyasina cift tikla."
    exit 0
}

try {
    Main
} catch {
    Write-Host ""
    Write-Host "Kurulum olmadi: $($_.Exception.Message)"
    exit 1
}
