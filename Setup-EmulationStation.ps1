#Requires -Version 5.1
<#
.SYNOPSIS
    Comprehensive EmulationStation Desktop Edition (ES-DE) setup for Windows 11.
    Mirrors the full Batocera x86_64 emulator/system set as closely as possible.

.DESCRIPTION
    This script will:
      1. Download and extract ES-DE portable for Windows
      2. Create ROMs/ and Emulators/ directories where ES-DE expects them
      3. Download RetroArch portable with ~80 libretro cores
      4. Download 15 standalone emulators into Emulators/
      5. Generate a BIOS reference guide with MD5 checksums
      6. Generate a quick-start configuration guide

    The resulting directory layout matches ES-DE portable conventions:
      BasePath/ES-DE.exe
      BasePath/ROMs/<system>/
      BasePath/Emulators/RetroArch/
      BasePath/Emulators/<standalone>/

    Run as Administrator for best results (7-Zip install, NTFS junctions).
    Requires an active internet connection.

.PARAMETER BasePath
    Root directory for the entire setup. Default: C:\EmulationStation
    This directory becomes the ES-DE portable installation root.

.PARAMETER SkipDownloads
    If set, only creates the directory structure and config files without downloading.

.PARAMETER RetroArchOnly
    If set, only downloads RetroArch and its cores (skips standalone emulators).

.NOTES
    Author  : Claude (Anthropic) + David
    Version : 1.1.0
    Date    : 2026-03-16
    License : MIT -- use at your own risk
#>

[CmdletBinding()]
param(
    [string]$BasePath = "C:\EmulationStation",
    [switch]$SkipDownloads,
    [switch]$RetroArchOnly
)

# -- Strict mode ---------------------------------------------------------------
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # speeds up Invoke-WebRequest dramatically

# -- Output helpers ------------------------------------------------------------
function Write-Step  { param([string]$Msg) Write-Host "`n>> $Msg" -ForegroundColor Cyan }
function Write-OK    { param([string]$Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Skip  { param([string]$Msg) Write-Host "  [SKIP] $Msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$Msg) Write-Host "  [FAIL] $Msg" -ForegroundColor Red }
function Write-Info  { param([string]$Msg) Write-Host "  [INFO] $Msg" -ForegroundColor Gray }

# -- Global paths --------------------------------------------------------------
# ES-DE portable expects:
#   <root>/ES-DE.exe           (or wherever the exe lands)
#   <root>/ROMs/<system>/      (default ROM path for portable mode)
#   <root>/Emulators/          (searched by es_find_rules.xml)
#
# We make BasePath the ES-DE portable root. Everything lives here.

$Paths = @{
    Base       = $BasePath
    ROMs       = "$BasePath\ROMs"
    Emulators  = "$BasePath\Emulators"
    BIOS       = "$BasePath\Emulators\RetroArch\system"
    Downloads  = "$BasePath\.downloads"
    RetroArch  = "$BasePath\Emulators\RetroArch"
    RACores    = "$BasePath\Emulators\RetroArch\cores"
    RASystem   = "$BasePath\Emulators\RetroArch\system"
}

# -- TLS 1.2 for GitHub -------------------------------------------------------
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ==============================================================================
#  HELPER FUNCTIONS
# ==============================================================================

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Get-GitHubLatestRelease {
    param([string]$Repo)
    try {
        $uri = "https://api.github.com/repos/$Repo/releases/latest"
        $release = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent' = 'EmulationStation-Setup/1.0' }
        return $release
    }
    catch {
        try {
            $uri = "https://api.github.com/repos/$Repo/releases"
            $releases = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent' = 'EmulationStation-Setup/1.0' }
            return $releases | Select-Object -First 1
        }
        catch {
            Write-Err "Failed to query GitHub releases for $Repo : $_"
            return $null
        }
    }
}

function Get-GitHubAssetUrl {
    param(
        [object]$Release,
        [string]$Pattern
    )
    if (-not $Release) { return $null }
    $asset = $Release.assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1
    if ($asset) { return $asset.browser_download_url }
    return $null
}

function Download-File {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Description = "file"
    )
    if (-not $Url) {
        Write-Err "No download URL for $Description"
        return $false
    }
    if (Test-Path $Destination) {
        Write-Skip "$Description already downloaded"
        return $true
    }
    try {
        Write-Info "Downloading $Description..."
        # Try Invoke-WebRequest first
        try {
            Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -TimeoutSec 300 -MaximumRedirection 10
        }
        catch {
            # Fallback to .NET WebClient for large files (more reliable with redirects)
            Write-Info "Retrying with WebClient..."
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($Url, $Destination)
            $wc.Dispose()
        }
        Write-OK "Downloaded $Description"
        return $true
    }
    catch {
        Write-Err "Failed to download ${Description}: $_"
        return $false
    }
}

function Extract-Archive {
    param(
        [string]$Archive,
        [string]$Destination,
        [string]$Description = "archive"
    )
    if (-not (Test-Path $Archive)) {
        Write-Err "Archive not found: $Archive"
        return $false
    }
    Ensure-Dir $Destination
    try {
        if ($Archive -match '\.zip$') {
            Expand-Archive -Path $Archive -DestinationPath $Destination -Force
        }
        elseif ($Archive -match '\.(7z|tar\.gz|tar\.xz)$') {
            $7z = Get-7ZipPath
            if (-not $7z) {
                Write-Err "7-Zip required but not found for $Description"
                return $false
            }
            & $7z x "$Archive" -o"$Destination" -y | Out-Null
        }
        else {
            Expand-Archive -Path $Archive -DestinationPath $Destination -Force
        }
        Write-OK "Extracted $Description"
        return $true
    }
    catch {
        Write-Err "Failed to extract ${Description}: $_"
        return $false
    }
}

function Get-7ZipPath {
    $candidates = @(
        "${env:ProgramFiles}\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "$($Paths.Emulators)\7zip\7z.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }
    try {
        $7zDir = "$($Paths.Emulators)\7zip"
        Ensure-Dir $7zDir
        $7zInstallerUrl = "https://github.com/ip7z/7zip/releases/download/24.09/7z2409-x64.exe"
        $7zInstaller = "$($Paths.Downloads)\7z-setup.exe"
        Invoke-WebRequest -Uri $7zInstallerUrl -OutFile $7zInstaller -UseBasicParsing
        Start-Process -FilePath $7zInstaller -ArgumentList "/S" -Wait
        if (Test-Path "${env:ProgramFiles}\7-Zip\7z.exe") {
            return "${env:ProgramFiles}\7-Zip\7z.exe"
        }
    }
    catch {
        Write-Err "Could not install 7-Zip: $_"
    }
    return $null
}

# Moves contents of a single nested subfolder up to the parent.
# e.g. if extracting creates Base\EmulationStation-DE\ES-DE.exe,
# this moves everything up so Base\ES-DE.exe exists.
function Flatten-SingleSubfolder {
    param([string]$Dir)
    $children = @(Get-ChildItem -Path $Dir -Force)
    if ($children.Count -eq 1 -and $children[0].PSIsContainer) {
        $subfolder = $children[0].FullName
        Write-Info "Flattening nested folder: $($children[0].Name)"
        Get-ChildItem -Path $subfolder -Force | ForEach-Object {
            $destPath = Join-Path $Dir $_.Name
            if (-not (Test-Path $destPath)) {
                Move-Item -Path $_.FullName -Destination $Dir -Force
            }
        }
        # Remove the now-empty subfolder
        if (@(Get-ChildItem -Path $subfolder -Force).Count -eq 0) {
            Remove-Item -Path $subfolder -Force
        }
    }
}

# ==============================================================================
#  NOTE ON ROM DIRECTORIES
# ==============================================================================
#  ES-DE has its own system folder names defined in its bundled es_systems.xml
#  (e.g. "gc" for GameCube, "gameandwatch" for Game & Watch, etc.) which differ
#  from Batocera naming. Rather than maintain a hand-coded list that drifts out
#  of sync, this script creates an empty ROMs\ directory and lets ES-DE
#  generate the correct subdirectories on first launch via its built-in
#  "Generate directory structure" button in the startup dialog.
# ==============================================================================

# ==============================================================================
#  RETROARCH CORES -- mapped to systems
# ==============================================================================

$RetroArchCores = [ordered]@{
    "fceumm"                 = @("nes","fds")
    "mesen"                  = @("nes","fds")
    "nestopia"               = @("nes","fds")
    "snes9x"                 = @("snes","satellaview","sufami","sgb")
    "bsnes"                  = @("snes","satellaview","sufami","sgb")
    "mupen64plus_next"       = @("n64")
    "parallel_n64"           = @("n64")
    "gambatte"               = @("gb","gbc","sgb")
    "mgba"                   = @("gba","gb","gbc","sgb")
    "melonds"                = @("nds")
    "desmume"                = @("nds")
    "citra"                  = @("n3ds")
    "dolphin"                = @("gamecube","wii")
    "pokemini"               = @("pokemini")
    "mednafen_vb"            = @("virtualboy")
    "swanstation"            = @("psx")
    "pcsx_rearmed"           = @("psx")
    "mednafen_psx_hw"        = @("psx")
    "ppsspp"                 = @("psp")
    "genesis_plus_gx"        = @("mastersystem","megadrive","segacd","gamegear","sg1000")
    "genesis_plus_gx_wide"   = @("mastersystem","megadrive","segacd","gamegear","sg1000")
    "picodrive"              = @("mastersystem","megadrive","sega32x","segacd")
    "flycast"                = @("dreamcast","naomi","naomi2","atomiswave")
    "kronos"                 = @("saturn")
    "mednafen_saturn"        = @("saturn")
    "yabasanshiro"           = @("saturn")
    "mednafen_pce"           = @("pcengine","pcenginecd","supergrafx")
    "mednafen_pce_fast"      = @("pcengine","pcenginecd","supergrafx")
    "mednafen_pcfx"          = @("pcfx")
    "fbneo"                  = @("neogeo","neogeocd","fbneo","cps","cps2","cps3")
    "mednafen_ngp"           = @("ngp","ngpc")
    "stella"                 = @("atari2600")
    "stella2014"             = @("atari2600")
    "atari800"               = @("atari5200","atarixe")
    "prosystem"              = @("atari7800")
    "virtualjaguar"          = @("atarijaguar")
    "handy"                  = @("atarilynx")
    "mednafen_lynx"          = @("atarilynx")
    "hatari"                 = @("atarist")
    "mame"                   = @("mame")
    "mame2003_plus"          = @("mame")
    "mame2010"               = @("mame")
    "daphne"                 = @("daphne")
    "dosbox_pure"            = @("dos")
    "dosbox_svn"             = @("dos")
    "scummvm"                = @("scummvm")
    "puae"                   = @("amiga","amigacd32","amiga1200")
    "vice_x64"               = @("c64")
    "vice_x128"              = @("c128")
    "vice_xvic"              = @("vic20")
    "vice_xpet"              = @("pet")
    "vice_xplus4"            = @("plus4")
    "bluemsx"                = @("msx","msx2","msxturbor","colecovision","spectravideo")
    "fmsx"                   = @("msx","msx2")
    "fuse"                   = @("zxspectrum")
    "81"                     = @("zx81")
    "np2kai"                 = @("pc98")
    "quasi88"                = @("pc88")
    "px68k"                  = @("x68000")
    "x1"                     = @("x1")
    "theodore"               = @("thomson")
    "o2em"                   = @("odyssey2","videopac")
    "freechaf"               = @("channelf")
    "potator"                = @("supervision")
    "uzem"                   = @("uzebox")
    "nxengine"               = @("cavestory")
    "lutro"                  = @("lutro")
    "easyrpg"                = @("easyrpg")
    "opera"                  = @("3do")
    "vecx"                   = @("vectrex")
    "freeintv"               = @("intellivision")
    "mednafen_wswan"         = @("wonderswan","wonderswancolor","wswan","wswanc")
    "gw"                     = @("gw")
    "arduous"                = @("arduboy")
    "bk"                     = @("coco")
    "mesen-s"                = @("snes","gb","gbc")
    "nekop2"                 = @("pc98")
    "cap32"                  = @()
    "crocods"                = @()
    "fmtowns"               = @("fmtowns")
}

# ==============================================================================
#  STANDALONE EMULATORS
# ==============================================================================
# Folder names here must match what es_find_rules.xml expects inside Emulators/.
# ES-DE searches for e.g. Emulators/PCSX2/pcsx2*.exe, Emulators/Dolphin/Dolphin.exe, etc.

$StandaloneEmulators = @(
    @{
        Name      = "Dolphin"
        Folder    = "Dolphin"
        DirectUrl = "https://dl.dolphin-emu.org/releases/2412/dolphin-2412-x64.7z"
        Notes     = "GameCube and Wii emulator"
    },
    @{
        Name      = "PCSX2"
        Folder    = "PCSX2"
        Repo      = "PCSX2/pcsx2"
        Pattern   = "pcsx2.*windows.*x64.*\.7z$|pcsx2.*win.*64.*\.zip$"
        Notes     = "PlayStation 2 emulator"
    },
    @{
        Name      = "RPCS3"
        Folder    = "RPCS3"
        Repo      = "RPCS3/rpcs3-binaries-win"
        Pattern   = "rpcs3.*win64.*\.7z$"
        Notes     = "PlayStation 3 emulator -- requires PS3 firmware (PS3UPDAT.PUP)"
    },
    @{
        Name      = "DuckStation"
        Folder    = "duckstation"
        Repo      = "stenzek/duckstation"
        Pattern   = "duckstation.*windows.*x64.*\.zip$"
        Notes     = "PlayStation 1 emulator (high accuracy)"
    },
    @{
        Name      = "PPSSPP"
        Folder    = "PPSSPP"
        Repo      = "hrydgard/ppsspp"
        Pattern   = "ppsspp.*windows.*64.*\.zip$|PPSSPPWindows64.*\.zip$"
        Notes     = "PlayStation Portable emulator"
    },
    @{
        Name      = "Cemu"
        Folder    = "Cemu"
        Repo      = "cemu-project/Cemu"
        Pattern   = "cemu.*windows.*x64.*\.zip$"
        Notes     = "Wii U emulator"
    },
    @{
        Name      = "Xemu"
        Folder    = "xemu"
        Repo      = "xemu-project/xemu"
        Pattern   = "xemu.*win.*\.zip$"
        Notes     = "Original Xbox emulator -- requires MCPX boot ROM + flash BIOS"
    },
    @{
        Name      = "Xenia Canary"
        Folder    = "Xenia"
        Repo      = "xenia-canary/xenia-canary-releases"
        Pattern   = "xenia_canary.*\.zip$"
        Notes     = "Xbox 360 emulator (experimental)"
    },
    @{
        Name      = "melonDS"
        Folder    = "melonDS"
        Repo      = "melonDS-emu/melonDS"
        Pattern   = "melonDS.*win.*x64.*\.zip$|melonDS.*windows.*\.zip$"
        Notes     = "Nintendo DS emulator"
    },
    @{
        Name      = "mGBA"
        Folder    = "mGBA"
        Repo      = "mgba-emu/mgba"
        Pattern   = "mGBA.*win.*64.*\.7z$|mGBA.*windows.*\.zip$"
        Notes     = "Game Boy / GBC / GBA emulator"
    },
    @{
        Name      = "DOSBox Staging"
        Folder    = "dosbox-staging"
        Repo      = "dosbox-staging/dosbox-staging"
        Pattern   = "dosbox-staging.*windows.*x86_64.*\.zip$|dosbox-staging.*win.*\.zip$"
        Notes     = "Enhanced DOSBox fork for DOS gaming"
    },
    @{
        Name      = "ScummVM"
        Folder    = "ScummVM"
        DirectUrl = "https://downloads.scummvm.org/frs/scummvm/2.9.1/scummvm-2.9.1-win32-x86_64.zip"
        Notes     = "Adventure game engine"
    },
    @{
        Name      = "Flycast"
        Folder    = "Flycast"
        Repo      = "flyinghead/flycast"
        Pattern   = "flycast.*win.*x64.*\.zip$|flycast.*windows.*\.zip$"
        Notes     = "Dreamcast / NAOMI / Atomiswave emulator"
    },
    @{
        Name      = "Vita3K"
        Folder    = "Vita3K"
        Repo      = "Vita3K/Vita3K"
        Pattern   = "Vita3K.*windows.*\.zip$|windows.*\.zip$"
        Notes     = "PlayStation Vita emulator (experimental)"
    },
    @{
        Name      = "MAME"
        Folder    = "MAME"
        Repo      = "mamedev/mame"
        Pattern   = "mame.*b_x64\.exe$"
        Notes     = "Multi-Arcade Machine Emulator (self-extracting archive)"
    },
    @{
        Name      = "Ryujinx (Ryubing)"
        Folder    = "Ryujinx"
        Repo      = "Kenji-NX/Releases"
        Pattern   = "ryujinx.*win.*x64.*\.zip$|.*[Ww]indows.*[Aa]rtifact.*\.zip$"
        Notes     = "Nintendo Switch emulator -- requires prod.keys and firmware from your Switch"
    }
)

# ==============================================================================
#  BIOS FILE REFERENCE
# ==============================================================================

$biosDir = $Paths.RASystem
$emuDir = $Paths.Emulators

$BIOSGuide = @"
+==============================================================================+
|               BIOS / FIRMWARE FILE REFERENCE GUIDE                           |
|                                                                              |
|  RetroArch BIOS path:  $biosDir
|  (This is Emulators\RetroArch\system\ inside your ES-DE folder)             |
|                                                                              |
|  All BIOS files must be legally obtained from hardware you own.              |
+==============================================================================+

  Most BIOS files go in: Emulators\RetroArch\system\
  PCSX2 BIOS goes in:    Emulators\PCSX2\bios\
  RPCS3 firmware:        Install via RPCS3 > File > Install Firmware

-----------------------------------------------
  PLAYSTATION (PSX) -- DuckStation / Beetle PSX
-----------------------------------------------
  scph5500.bin   -- PS1 BIOS (Japan)       (MD5: 8dd7d5296a650fac7319bce665a6a53c)
  scph5501.bin   -- PS1 BIOS (USA)         (MD5: 490f666e1afb15b7362b406ed1cea246)
  scph5502.bin   -- PS1 BIOS (Europe)      (MD5: 32736f17079d0b2b7024407c39bd3050)

-----------------------------------------------
  PLAYSTATION 2 -- PCSX2
-----------------------------------------------
  Place in: $emuDir\PCSX2\bios\
  SCPH-70012.bin -- PS2 BIOS (USA, v12)
  SCPH-70004.bin -- PS2 BIOS (Europe)
  SCPH-70000.bin -- PS2 BIOS (Japan)

-----------------------------------------------
  PLAYSTATION 3 -- RPCS3
-----------------------------------------------
  PS3UPDAT.PUP   -- PS3 Firmware (download from Sony official site)
  Install via RPCS3 > File > Install Firmware

-----------------------------------------------
  SEGA DREAMCAST -- Flycast
-----------------------------------------------
  dc\dc_boot.bin     -- Dreamcast BIOS       (MD5: e10c53c2f8b90bab96ead2d368858623)
  dc\dc_flash.bin    -- Dreamcast Flash ROM   (MD5: 0a93f7940c455905bea6e392dfde92a4)

-----------------------------------------------
  SEGA SATURN -- Mednafen Saturn / Kronos
-----------------------------------------------
  sega_101.bin       -- Saturn BIOS (Japan)   (MD5: 85ec9ca47d8f6807718151cbcbf8b689)
  mpr-17933.bin      -- Saturn BIOS (USA/EU)  (MD5: 3240872c70984b6cbfda1586cab68dbe)

-----------------------------------------------
  SEGA CD / MEGA CD
-----------------------------------------------
  bios_CD_U.bin      -- Sega CD BIOS (USA)
  bios_CD_E.bin      -- Sega CD BIOS (Europe)
  bios_CD_J.bin      -- Sega CD BIOS (Japan)

-----------------------------------------------
  NAOMI / ATOMISWAVE
-----------------------------------------------
  dc\naomi.zip       -- NAOMI BIOS
  dc\awbios.zip      -- Atomiswave BIOS

-----------------------------------------------
  NINTENDO DS -- melonDS / DeSmuME
-----------------------------------------------
  bios7.bin          -- ARM7 BIOS             (MD5: df692a80a5b1bc90728bc3dfc76cd948)
  bios9.bin          -- ARM9 BIOS             (MD5: a392174eb3e572fed6447e956bde4b25)
  firmware.bin       -- NDS Firmware           (MD5: 145eaef5bd3037cbc247c213bb3da1b3)

-----------------------------------------------
  GBA / GB / GBC (optional, for boot logos)
-----------------------------------------------
  gba_bios.bin       -- GBA BIOS              (MD5: a860e8c0b6d573d191e4ec7db1b1e4f6)
  gb_bios.bin        -- Game Boy BIOS          (MD5: 32fbbd84168d3482956eb3c5051637f5)
  gbc_bios.bin       -- GBC BIOS               (MD5: dbfce9db9deaa2567f6a84fde55f9680)
  sgb_bios.bin       -- Super Game Boy BIOS    (MD5: d574d4f9c12f305571c6b0ce18f0c563)

-----------------------------------------------
  FAMICOM DISK SYSTEM
-----------------------------------------------
  disksys.rom        -- FDS BIOS              (MD5: ca30b50f880eb660a320571e2a116f56)

-----------------------------------------------
  PC ENGINE CD / TURBOGRAFX-CD
-----------------------------------------------
  syscard3.pce       -- System Card 3.0       (MD5: 38179df8f4ac870017db21ebcbf53114)

-----------------------------------------------
  PC-FX
-----------------------------------------------
  pcfx.rom           -- PC-FX BIOS            (MD5: 08e36edbea28a017f79f8d4f7ff9b6d7)

-----------------------------------------------
  3DO -- Opera
-----------------------------------------------
  panafz1.bin        -- Panasonic FZ-1 BIOS   (MD5: f47264dd47fe30f73ab3c010015c155b)
  panafz10.bin       -- Panasonic FZ-10 BIOS  (MD5: 51f2f43ae2f3508a14d9f56597e2d3ce)

-----------------------------------------------
  COLECOVISION / INTELLIVISION
-----------------------------------------------
  colecovision.rom   -- ColecoVision BIOS     (MD5: 2c66f5911e5b42b8ebe113403548eee7)
  exec.bin           -- Intellivision Exec    (MD5: 62e761035cb657903761800f4437b8af)
  grom.bin           -- Intellivision GROM    (MD5: 0cd5946c6473e42e8e4c2137785e427f)

-----------------------------------------------
  AMIGA -- PUAE
-----------------------------------------------
  kick34005.A500     -- Amiga 500 Kickstart 1.3
  kick40063.A600     -- Amiga 600 Kickstart 2.05
  kick40068.A1200    -- Amiga 1200 Kickstart 3.1
  kick40060.CD32     -- CD32 Kickstart 3.1
  kick40060.CD32.ext -- CD32 Extended ROM

-----------------------------------------------
  ATARI
-----------------------------------------------
  5200.rom           -- Atari 5200 BIOS       (MD5: 281f20ea4320404ec820fb7ec0693b38)
  ATARIXL.ROM        -- Atari XL/XE OS
  ATARIBAS.ROM       -- Atari BASIC
  7800 BIOS (U).rom  -- Atari 7800 BIOS       (MD5: 0763f1ffb006ddbe32e52d497ee848ae)
  lynxboot.img       -- Lynx Boot ROM         (MD5: fcd403db69f54290b51035d82f835e7b)
  tos.img            -- Atari ST TOS ROM

-----------------------------------------------
  NEO GEO / ARCADE
-----------------------------------------------
  neogeo.zip         -- Neo Geo BIOS (also place in ROMs\neogeo\)

-----------------------------------------------
  XBOX (ORIGINAL) -- Xemu
-----------------------------------------------
  mcpx_1.0.bin       -- MCPX Boot ROM
  Complex_4627.bin   -- Flash BIOS image

-----------------------------------------------
  NINTENDO SWITCH -- Ryujinx (Ryubing)
-----------------------------------------------
  prod.keys          -- Production keys (dump from your own Switch)
  title.keys         -- Title keys (optional, not required for most games)
  Switch firmware     -- Install via Ryujinx > Tools > Install Firmware
  (Keys go in Ryujinx user folder > system\, firmware installed via GUI)

-----------------------------------------------
  NOTES
-----------------------------------------------
  * All paths above are relative to Emulators\RetroArch\system\ unless noted.
  * Create subdirectories (dc\, np2kai\, keropi\) as needed for specific cores.
  * Neo Geo BIOS (neogeo.zip) should be in BOTH the BIOS folder AND ROMs\neogeo\.
  * For systems not listed, the emulator likely does not require BIOS (HLE mode).
"@

# ==============================================================================
#  MAIN EXECUTION
# ==============================================================================

Write-Host ""
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host "  EmulationStation Desktop Edition -- Full Setup Script" -ForegroundColor Magenta
Write-Host "  Batocera x86_64 parity - $(Get-Date -Format 'yyyy-MM-dd')" -ForegroundColor Magenta
Write-Host "================================================================" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Base path: $BasePath" -ForegroundColor White
Write-Host "  (This will be your ES-DE portable root)" -ForegroundColor Gray
Write-Host ""

# -- 1. Create directory structure ---------------------------------------------
Write-Step "Creating directory structure..."

Ensure-Dir $BasePath
Ensure-Dir $Paths.Downloads
Ensure-Dir $Paths.ROMs
Ensure-Dir $Paths.Emulators
Ensure-Dir $Paths.RetroArch
Ensure-Dir $Paths.RACores
Ensure-Dir $Paths.RASystem

# BIOS subdirectories inside RetroArch\system\
foreach ($sub in @("dc","np2kai","keropi","fmtowns","Machines","Databases")) {
    Ensure-Dir "$($Paths.RASystem)\$sub"
}

Write-OK "Created directory structure and BIOS subdirectories"

# -- 2. Generate BIOS guide ----------------------------------------------------
Write-Step "Writing BIOS reference guide..."
$BIOSGuide | Out-File -FilePath "$($Paths.RASystem)\BIOS_README.txt" -Encoding ASCII -Force
# Also put a copy at the base for visibility
$BIOSGuide | Out-File -FilePath "$BasePath\BIOS_README.txt" -Encoding ASCII -Force
Write-OK "BIOS guide written to BIOS_README.txt"

# -- If SkipDownloads, stop here -----------------------------------------------
if ($SkipDownloads) {
    Write-Host ""
    Write-Host "  Directory structure created. Skipping downloads (-SkipDownloads)." -ForegroundColor Yellow
    Write-Host "  Manually download ES-DE portable from https://es-de.org" -ForegroundColor Yellow
    Write-Host "  Extract it so ES-DE.exe is at: $BasePath\ES-DE.exe" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# -- 4. Download and extract ES-DE portable ------------------------------------
Write-Step "Downloading EmulationStation Desktop Edition (ES-DE) portable..."

$esdeUrl = $null
$esdeDl = "$($Paths.Downloads)\esde.zip"

# Method 1: GitLab releases API
try {
    Write-Info "Querying GitLab for latest ES-DE release..."
    $gitlabApi = "https://gitlab.com/api/v4/projects/es-de%2Femulationstation-de/releases"
    $esdeReleases = Invoke-RestMethod -Uri $gitlabApi -Headers @{ 'User-Agent' = 'EmulationStation-Setup/1.0' }
    $latestRelease = $esdeReleases | Select-Object -First 1
    if ($latestRelease) {
        Write-Info "Found ES-DE $($latestRelease.tag_name)"
        $windowsLink = $latestRelease.assets.links |
            Where-Object { $_.name -match 'portable' -or $_.name -match '[Ww]indows.*portable' } |
            Select-Object -First 1
        if ($windowsLink) {
            $esdeUrl = $windowsLink.direct_asset_url
            if (-not $esdeUrl) { $esdeUrl = $windowsLink.url }
        }
        if (-not $esdeUrl) {
            $windowsLink = $latestRelease.assets.links |
                Where-Object { $_.name -match '[Ww]indows' } |
                Select-Object -First 1
            if ($windowsLink) {
                $esdeUrl = $windowsLink.direct_asset_url
                if (-not $esdeUrl) { $esdeUrl = $windowsLink.url }
            }
        }
    }
}
catch {
    Write-Info "GitLab API query failed, trying direct download..."
}

# Method 2: Known direct download URL (ES-DE v3.4.0 Windows portable)
if (-not $esdeUrl) {
    Write-Info "Using known download URL for ES-DE v3.4.0..."
    $esdeUrl = "https://gitlab.com/es-de/emulationstation-de/-/package_files/243196975/download"
}

if (Download-File -Url $esdeUrl -Destination $esdeDl -Description "ES-DE portable") {
    # Extract to a temp staging directory first
    $esdeStaging = "$($Paths.Downloads)\_esde_staging"
    if (Test-Path $esdeStaging) { Remove-Item -Path $esdeStaging -Recurse -Force }
    Extract-Archive -Archive $esdeDl -Destination $esdeStaging -Description "ES-DE"

    # The ZIP typically extracts into a subfolder like "EmulationStation-DE".
    # We need to move the contents up into BasePath so ES-DE.exe is at the root.
    Write-Info "Installing ES-DE to $BasePath..."
    Flatten-SingleSubfolder $esdeStaging

    # Copy all ES-DE files to BasePath (don't overwrite our ROMs/Emulators dirs)
    Get-ChildItem -Path $esdeStaging -Force | ForEach-Object {
        $destItem = Join-Path $BasePath $_.Name
        # Skip if it is our ROMs or Emulators directory
        if ($_.Name -eq "ROMs" -or $_.Name -eq "Emulators" -or $_.Name -eq ".downloads") {
            return
        }
        if (Test-Path $destItem) {
            # Overwrite files, merge directories
            if ($_.PSIsContainer) {
                Copy-Item -Path $_.FullName -Destination $BasePath -Recurse -Force
            }
            else {
                Copy-Item -Path $_.FullName -Destination $destItem -Force
            }
        }
        else {
            Move-Item -Path $_.FullName -Destination $BasePath -Force
        }
    }

    # Verify ES-DE.exe exists
    $esdeExe = Get-ChildItem -Path $BasePath -Filter "ES-DE.exe" -ErrorAction SilentlyContinue
    if ($esdeExe) {
        Write-OK "ES-DE.exe installed at $($esdeExe.FullName)"
    }
    else {
        # Try to find it in case the name is different
        $anyExe = Get-ChildItem -Path $BasePath -Filter "*.exe" |
            Where-Object { $_.Name -notmatch 'unins' -and $_.Name -ne '7z.exe' } |
            Select-Object -First 1
        if ($anyExe) {
            Write-OK "ES-DE executable found: $($anyExe.Name)"
        }
        else {
            Write-Err "Could not find ES-DE.exe in $BasePath -- check the extraction"
        }
    }

    # Clean up staging
    Remove-Item -Path $esdeStaging -Recurse -Force -ErrorAction SilentlyContinue
}
else {
    Write-Err "Could not download ES-DE. Get it manually from https://es-de.org"
    Write-Info "Extract the portable ZIP so ES-DE.exe is at: $BasePath\ES-DE.exe"
}

# -- 5. Download RetroArch -----------------------------------------------------
Write-Step "Downloading RetroArch into Emulators\RetroArch..."

$raUrl = "https://buildbot.libretro.com/stable/1.19.1/windows/x86_64/RetroArch.7z"
$raFallback = "https://buildbot.libretro.com/stable/1.19.1/windows/x86_64/RetroArch.zip"
$raDl = "$($Paths.Downloads)\retroarch.7z"
$raDlZip = "$($Paths.Downloads)\retroarch.zip"

$raDownloaded = Download-File -Url $raUrl -Destination $raDl -Description "RetroArch (7z)"
if ($raDownloaded) {
    Extract-Archive -Archive $raDl -Destination $Paths.RetroArch -Description "RetroArch"
    Flatten-SingleSubfolder $Paths.RetroArch
}
else {
    $raDownloaded = Download-File -Url $raFallback -Destination $raDlZip -Description "RetroArch (zip)"
    if ($raDownloaded) {
        Extract-Archive -Archive $raDlZip -Destination $Paths.RetroArch -Description "RetroArch"
        Flatten-SingleSubfolder $Paths.RetroArch
    }
}

# Ensure cores and system dirs exist (may have been created by extraction)
Ensure-Dir $Paths.RACores
Ensure-Dir $Paths.RASystem

# -- 6. Download RetroArch Cores -----------------------------------------------
$coreTotal = $RetroArchCores.Count
Write-Step "Downloading RetroArch cores ($coreTotal cores)..."

$coreBaseUrl = "https://buildbot.libretro.com/nightly/windows/x86_64/latest"
$coreCount = 0
$coreFails = 0

Ensure-Dir "$($Paths.Downloads)\cores"

foreach ($core in $RetroArchCores.Keys) {
    $coreDll = "${core}_libretro.dll"
    $coreZip = "${coreDll}.zip"
    $coreUrl = "$coreBaseUrl/$coreZip"
    $coreDest = "$($Paths.Downloads)\cores\$coreZip"
    $coreFinal = "$($Paths.RACores)\$coreDll"

    if (Test-Path $coreFinal) {
        $coreCount++
        continue
    }

    try {
        Invoke-WebRequest -Uri $coreUrl -OutFile $coreDest -UseBasicParsing -ErrorAction Stop
        Expand-Archive -Path $coreDest -DestinationPath $Paths.RACores -Force
        $coreCount++
    }
    catch {
        $coreFails++
    }
}

Write-OK "Downloaded $coreCount cores ($coreFails unavailable/failed)"

# -- 7. Download Standalone Emulators ------------------------------------------
if (-not $RetroArchOnly) {
    $emuTotal = $StandaloneEmulators.Count
    Write-Step "Downloading standalone emulators into Emulators\ ($emuTotal emulators)..."

    foreach ($emu in $StandaloneEmulators) {
        Write-Info "Fetching $($emu.Name)..."
        $emuInstallDir = "$($Paths.Emulators)\$($emu.Folder)"
        Ensure-Dir $emuInstallDir

        $assetUrl = $null

        # Method 1: Direct URL (for emulators that don't use GitHub releases)
        if ($emu.ContainsKey('DirectUrl') -and $emu.DirectUrl) {
            $assetUrl = $emu.DirectUrl
        }
        # Method 2: GitHub releases API
        elseif ($emu.ContainsKey('Repo') -and $emu.Repo) {
            $release = Get-GitHubLatestRelease -Repo $emu.Repo
            if (-not $release) {
                Write-Err "Could not find release for $($emu.Name) ($($emu.Repo))"
                continue
            }

            $assetUrl = Get-GitHubAssetUrl -Release $release -Pattern $emu.Pattern
            if (-not $assetUrl) {
                $assetUrl = $release.assets |
                    Where-Object { $_.name -match 'win' -and $_.name -match '(64|x64|x86_64)' } |
                    Select-Object -First 1 |
                    ForEach-Object { $_.browser_download_url }
            }
        }

        if (-not $assetUrl) {
            Write-Err "No download source found for $($emu.Name)"
            continue
        }

        $ext = if ($assetUrl -match '\.7z$') { ".7z" } elseif ($assetUrl -match '\.exe$') { ".exe" } else { ".zip" }
        $dlPath = "$($Paths.Downloads)\$($emu.Folder)$ext"

        if (Download-File -Url $assetUrl -Destination $dlPath -Description $emu.Name) {
            if ($ext -eq ".exe") {
                Copy-Item -Path $dlPath -Destination "$emuInstallDir\$($emu.Folder).exe" -Force
                Write-OK "Installed $($emu.Name)"
            }
            else {
                Extract-Archive -Archive $dlPath -Destination $emuInstallDir -Description $emu.Name
                Flatten-SingleSubfolder $emuInstallDir
            }
        }
    }
}
else {
    Write-Skip "Skipping standalone emulators (-RetroArchOnly)"
    $emuTotal = 0
}

# -- 8. Generate quick-start guide ---------------------------------------------
Write-Step "Generating quick-start guide..."

$guideText = @"
==============================================================================
 ES-DE Portable -- Quick Start Guide
==============================================================================

 Your ES-DE portable installation is at: $BasePath

 DIRECTORY LAYOUT (matching ES-DE portable defaults):
   $BasePath\ES-DE.exe          -- Launch this
   $BasePath\ROMs\              -- Your game ROMs (one subfolder per system)
   $BasePath\Emulators\         -- All emulators live here
   $BasePath\Emulators\RetroArch\       -- RetroArch + cores
   $BasePath\Emulators\RetroArch\system\ -- BIOS/firmware files go here

 FIRST LAUNCH:
   1. Run ES-DE.exe
   2. ES-DE will auto-detect ROMs\ as the ROM directory (portable default)
   3. ES-DE will auto-find emulators in Emulators\ via es_find_rules.xml
   4. Click "Generate directory structure" when prompted to create all
      system ROM folders (e.g. gc\, snes\, psx\, n64\, etc.)
   5. No additional path configuration should be needed!

 ADDING GAMES:
   Drop your legally obtained ROM files into the matching ROMs\ subfolder.
   IMPORTANT: Use ES-DE folder names, NOT Batocera names! For example:
     ROMs\gc\        (NOT ROMs\gamecube\)
     ROMs\n3ds\      (NOT ROMs\3ds\)
     ROMs\genesis\   (for Sega Genesis)

 BIOS FILES:
   See BIOS_README.txt for the full list with MD5 checksums.
   Most go in: Emulators\RetroArch\system\
   PCSX2 BIOS goes in: Emulators\PCSX2\bios\

 SCRAPING (box art, screenshots, descriptions):
   1. Create a free account at https://www.screenscraper.fr/
   2. In ES-DE: Main Menu > Scraper > ScreenScraper
   3. Enter your credentials and scrape your collection

 EMULATOR SELECTION:
   ES-DE auto-selects the default emulator for each system.
   To change: highlight a game > press Select > Edit > Alternative Emulator

==============================================================================
"@

$guideText | Out-File -FilePath "$BasePath\QUICK_START.txt" -Encoding ASCII -Force
Write-OK "Quick-start guide written to QUICK_START.txt"

# -- 9. Create launcher batch file ---------------------------------------------
Write-Step "Creating launcher..."

$launcherText = @"
@echo off
title EmulationStation Desktop Edition
cd /d "$BasePath"
if exist "ES-DE.exe" (
    start "" "ES-DE.exe"
) else (
    echo ES-DE.exe not found in $BasePath
    echo Download the portable version from https://es-de.org
    pause
)
"@

$launcherText | Out-File -FilePath "$BasePath\Launch_ES-DE.bat" -Encoding ASCII -Force
Write-OK "Launcher created: Launch_ES-DE.bat"

# -- 10. Summary ---------------------------------------------------------------
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "                      SETUP COMPLETE" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  $BasePath" -ForegroundColor White
Write-Host "    |-- ES-DE.exe             <- Launch this!" -ForegroundColor White
Write-Host "    |-- ROMs\                 <- ES-DE generates system folders on first launch" -ForegroundColor White
Write-Host "    |   |-- nes\" -ForegroundColor Gray
Write-Host "    |   |-- snes\" -ForegroundColor Gray
Write-Host "    |   |-- psx\" -ForegroundColor Gray
Write-Host "    |   \-- ... (all systems)" -ForegroundColor Gray
Write-Host "    |-- Emulators\" -ForegroundColor White
Write-Host "    |   |-- RetroArch\        <- RetroArch + $coreTotal cores" -ForegroundColor White
Write-Host "    |   |   |-- cores\        <- libretro core DLLs" -ForegroundColor Gray
Write-Host "    |   |   \-- system\       <- BIOS files go here" -ForegroundColor Gray
Write-Host "    |   |-- Dolphin\          <- GameCube / Wii" -ForegroundColor Gray
Write-Host "    |   |-- PCSX2\            <- PlayStation 2" -ForegroundColor Gray
Write-Host "    |   |-- RPCS3\            <- PlayStation 3" -ForegroundColor Gray
Write-Host "    |   |-- duckstation\      <- PlayStation 1" -ForegroundColor Gray
Write-Host "    |   |-- PPSSPP\           <- PSP" -ForegroundColor Gray
Write-Host "    |   \-- ... (15 standalone emulators)" -ForegroundColor Gray
Write-Host "    |-- BIOS_README.txt       <- BIOS reference with MD5s" -ForegroundColor White
Write-Host "    |-- QUICK_START.txt       <- Setup guide" -ForegroundColor White
Write-Host "    \-- Launch_ES-DE.bat      <- Quick launcher" -ForegroundColor White
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
Write-Host "    1. Run ES-DE.exe (or Launch_ES-DE.bat)" -ForegroundColor White
Write-Host "    2. Click 'Generate directory structure' to create ROM folders" -ForegroundColor White
Write-Host "    3. Add BIOS files to Emulators\RetroArch\system\ (see BIOS_README.txt)" -ForegroundColor White
Write-Host "    4. Add your ROM files to the matching ROMs\ subfolders" -ForegroundColor White
Write-Host "    5. Note: ES-DE uses its own folder names (e.g. gc, not gamecube)" -ForegroundColor White
Write-Host "    6. Optionally scrape for artwork at screenscraper.fr" -ForegroundColor White
Write-Host ""
Write-Host "  RetroArch cores: $coreTotal" -ForegroundColor Cyan
if ($emuTotal -gt 0) {
    Write-Host "  Standalone emulators: $emuTotal" -ForegroundColor Cyan
}
Write-Host ""
