#Requires -Version 5.1
<#
.SYNOPSIS
    Comprehensive EmulationStation Desktop Edition (ES-DE) setup for Windows 11.
    Mirrors the full Batocera x86_64 emulator/system set as closely as possible.

.DESCRIPTION
    This script will:
      1. Create a complete directory structure (emulators, ROMs, BIOS, saves, config)
      2. Download and extract ES-DE (EmulationStation Desktop Edition)
      3. Download and extract RetroArch (portable) with all relevant libretro cores
      4. Download standalone emulators for systems that need them
      5. Generate a BIOS guide with every required/optional BIOS file listed
      6. Generate an ES-DE systems configuration

    Run as Administrator for best results (some downloads may need it).
    Requires an active internet connection.

.PARAMETER BasePath
    Root directory for the entire setup. Default: C:\EmulationStation

.PARAMETER SkipDownloads
    If set, only creates the directory structure and config files without downloading.

.PARAMETER RetroArchOnly
    If set, only downloads RetroArch and its cores (skips standalone emulators).

.NOTES
    Author  : Claude (Anthropic) + David
    Version : 1.0.1
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

# -- Colour helpers ------------------------------------------------------------
function Write-Step  { param([string]$Msg) Write-Host "`n>> $Msg" -ForegroundColor Cyan }
function Write-OK    { param([string]$Msg) Write-Host "  [OK] $Msg" -ForegroundColor Green }
function Write-Skip  { param([string]$Msg) Write-Host "  [SKIP] $Msg" -ForegroundColor Yellow }
function Write-Err   { param([string]$Msg) Write-Host "  [FAIL] $Msg" -ForegroundColor Red }
function Write-Info  { param([string]$Msg) Write-Host "  [INFO] $Msg" -ForegroundColor Gray }

# -- Global paths --------------------------------------------------------------
$Paths = @{
    Base       = $BasePath
    Emulators  = "$BasePath\emulators"
    ROMs       = "$BasePath\roms"
    BIOS       = "$BasePath\bios"
    Saves      = "$BasePath\saves"
    States     = "$BasePath\states"
    Config     = "$BasePath\config"
    Downloads  = "$BasePath\.downloads"
    ESDE       = "$BasePath\emulators\ES-DE"
    RetroArch  = "$BasePath\emulators\RetroArch"
    RACores    = "$BasePath\emulators\RetroArch\cores"
    RASystem   = "$BasePath\emulators\RetroArch\system"
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
    <# Returns the latest release object from a GitHub repo #>
    param([string]$Repo)
    try {
        $uri = "https://api.github.com/repos/$Repo/releases/latest"
        $release = Invoke-RestMethod -Uri $uri -Headers @{ 'User-Agent' = 'EmulationStation-Setup/1.0' }
        return $release
    }
    catch {
        # Some repos use pre-releases only
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
    <# Finds a download URL matching a pattern from a GitHub release #>
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
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
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
            # Requires 7-Zip -- we will install it if missing
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
    # Try to download portable 7-Zip
    try {
        $7zDir = "$($Paths.Emulators)\7zip"
        Ensure-Dir $7zDir
        $7zInstallerUrl = "https://github.com/ip7z/7zip/releases/download/24.09/7z2409-x64.exe"
        $7zInstaller = "$($Paths.Downloads)\7z-setup.exe"
        Invoke-WebRequest -Uri $7zInstallerUrl -OutFile $7zInstaller -UseBasicParsing
        # Silent install
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

# ==============================================================================
#  SYSTEM / ROM DIRECTORY DEFINITIONS
# ==============================================================================
#  Every system Batocera supports on x86_64 with its ROM folder name,
#  friendly display name, and supported file extensions.

$Systems = [ordered]@{
    # -- Atari ------------------------------------------------------------------
    "atari2600"       = @{ Name = "Atari 2600";              Ext = ".a26,.bin,.rom,.zip,.7z" }
    "atari5200"       = @{ Name = "Atari 5200";              Ext = ".a52,.bin,.rom,.zip,.7z" }
    "atari7800"       = @{ Name = "Atari 7800";              Ext = ".a78,.bin,.rom,.zip,.7z" }
    "atarijaguar"     = @{ Name = "Atari Jaguar";            Ext = ".j64,.jag,.rom,.zip,.7z" }
    "atarilynx"       = @{ Name = "Atari Lynx";              Ext = ".lnx,.zip,.7z" }
    "atarist"         = @{ Name = "Atari ST/STE/TT/Falcon";  Ext = ".st,.stx,.msa,.dim,.ipf,.zip,.7z" }
    "atarixe"         = @{ Name = "Atari 800/XL/XE";         Ext = ".xex,.atr,.atx,.bin,.rom,.zip,.7z" }
    # -- Nintendo ---------------------------------------------------------------
    "nes"             = @{ Name = "Nintendo Entertainment System"; Ext = ".nes,.unf,.unif,.fds,.zip,.7z" }
    "snes"            = @{ Name = "Super Nintendo";           Ext = ".sfc,.smc,.fig,.swc,.zip,.7z" }
    "n64"             = @{ Name = "Nintendo 64";              Ext = ".n64,.v64,.z64,.ndd,.zip,.7z" }
    "gamecube"        = @{ Name = "Nintendo GameCube";        Ext = ".iso,.gcm,.gcz,.ciso,.rvz,.nkit.iso,.wbfs" }
    "wii"             = @{ Name = "Nintendo Wii";             Ext = ".iso,.wbfs,.gcz,.ciso,.rvz,.nkit.iso" }
    "wiiu"            = @{ Name = "Nintendo Wii U";           Ext = ".wua,.wux,.rpx,.wud" }
    "switch"          = @{ Name = "Nintendo Switch";          Ext = ".nsp,.xci,.nca,.nsz,.xcz" }
    "gb"              = @{ Name = "Game Boy";                 Ext = ".gb,.gbc,.zip,.7z" }
    "gbc"             = @{ Name = "Game Boy Color";           Ext = ".gbc,.gb,.zip,.7z" }
    "gba"             = @{ Name = "Game Boy Advance";         Ext = ".gba,.zip,.7z" }
    "nds"             = @{ Name = "Nintendo DS";              Ext = ".nds,.zip,.7z" }
    "n3ds"            = @{ Name = "Nintendo 3DS";             Ext = ".3ds,.cia,.cxi,.app,.3dsx" }
    "fds"             = @{ Name = "Famicom Disk System";      Ext = ".fds,.nes,.zip,.7z" }
    "satellaview"     = @{ Name = "Satellaview";              Ext = ".bs,.sfc,.smc,.zip,.7z" }
    "sufami"          = @{ Name = "SuFami Turbo";             Ext = ".sfc,.smc,.zip,.7z" }
    "sgb"             = @{ Name = "Super Game Boy";           Ext = ".gb,.gbc,.sgb,.zip,.7z" }
    "pokemini"        = @{ Name = "Pokemon Mini";             Ext = ".min,.zip,.7z" }
    "virtualboy"      = @{ Name = "Virtual Boy";              Ext = ".vb,.vboy,.zip,.7z" }
    # -- Sony -------------------------------------------------------------------
    "psx"             = @{ Name = "PlayStation";              Ext = ".cue,.bin,.iso,.img,.pbp,.chd,.m3u,.mds,.ccd" }
    "ps2"             = @{ Name = "PlayStation 2";            Ext = ".iso,.bin,.chd,.cso,.gz,.zso" }
    "ps3"             = @{ Name = "PlayStation 3";            Ext = ".ps3dir (folder),.pkg" }
    "psp"             = @{ Name = "PlayStation Portable";     Ext = ".iso,.cso,.pbp,.chd" }
    "psvita"          = @{ Name = "PlayStation Vita";         Ext = ".vpk,.mai" }
    # -- Sega -------------------------------------------------------------------
    "mastersystem"    = @{ Name = "Sega Master System";       Ext = ".sms,.bin,.zip,.7z" }
    "megadrive"       = @{ Name = "Sega Genesis / Mega Drive";Ext = ".md,.smd,.gen,.bin,.zip,.7z" }
    "sega32x"         = @{ Name = "Sega 32X";                Ext = ".32x,.smd,.bin,.zip,.7z" }
    "segacd"          = @{ Name = "Sega CD / Mega CD";       Ext = ".cue,.bin,.iso,.chd" }
    "saturn"          = @{ Name = "Sega Saturn";             Ext = ".cue,.bin,.iso,.chd,.mds,.ccd" }
    "dreamcast"       = @{ Name = "Sega Dreamcast";          Ext = ".cdi,.gdi,.chd,.cue,.bin,.iso" }
    "gamegear"        = @{ Name = "Sega Game Gear";          Ext = ".gg,.bin,.zip,.7z" }
    "sg1000"          = @{ Name = "Sega SG-1000";            Ext = ".sg,.sc,.bin,.zip,.7z" }
    "naomi"           = @{ Name = "Sega NAOMI";              Ext = ".zip,.7z,.dat,.bin,.lst" }
    "naomi2"          = @{ Name = "Sega NAOMI 2";            Ext = ".zip,.7z,.dat,.bin,.lst" }
    "atomiswave"      = @{ Name = "Sammy Atomiswave";        Ext = ".zip,.7z,.bin,.dat,.lst" }
    # -- NEC --------------------------------------------------------------------
    "pcengine"        = @{ Name = "PC Engine / TurboGrafx-16";Ext = ".pce,.cue,.bin,.iso,.chd,.zip,.7z" }
    "pcenginecd"      = @{ Name = "PC Engine CD / TurboGrafx-CD"; Ext = ".cue,.bin,.iso,.chd" }
    "pcfx"            = @{ Name = "PC-FX";                   Ext = ".cue,.bin,.iso,.chd" }
    "supergrafx"      = @{ Name = "SuperGrafx";              Ext = ".pce,.sgx,.cue,.zip,.7z" }
    # -- SNK --------------------------------------------------------------------
    "neogeo"          = @{ Name = "Neo Geo (MVS/AES)";       Ext = ".zip,.7z" }
    "neogeocd"        = @{ Name = "Neo Geo CD";              Ext = ".cue,.bin,.iso,.chd" }
    "ngp"             = @{ Name = "Neo Geo Pocket";          Ext = ".ngp,.ngc,.zip,.7z" }
    "ngpc"            = @{ Name = "Neo Geo Pocket Color";    Ext = ".ngc,.ngp,.zip,.7z" }
    # -- Microsoft --------------------------------------------------------------
    "xbox"            = @{ Name = "Microsoft Xbox";          Ext = ".iso,.xiso" }
    "xbox360"         = @{ Name = "Microsoft Xbox 360";      Ext = ".xex,.iso,.god,.xbla" }
    # -- Arcade -----------------------------------------------------------------
    "mame"            = @{ Name = "MAME (Arcade)";           Ext = ".zip,.7z" }
    "fbneo"           = @{ Name = "FinalBurn Neo";           Ext = ".zip,.7z" }
    "cps"             = @{ Name = "Capcom Play System";      Ext = ".zip,.7z" }
    "cps2"            = @{ Name = "Capcom Play System II";   Ext = ".zip,.7z" }
    "cps3"            = @{ Name = "Capcom Play System III";  Ext = ".zip,.7z" }
    "model2"          = @{ Name = "Sega Model 2";            Ext = ".zip,.7z" }
    "model3"          = @{ Name = "Sega Model 3";            Ext = ".zip,.7z" }
    "daphne"          = @{ Name = "Daphne (Laserdisc)";      Ext = ".daphne,.singe" }
    # -- Computers --------------------------------------------------------------
    "dos"             = @{ Name = "MS-DOS";                  Ext = ".exe,.com,.bat,.conf,.zip,.7z,.dosz" }
    "scummvm"         = @{ Name = "ScummVM";                 Ext = ".scummvm,.svm" }
    "amiga"           = @{ Name = "Commodore Amiga";         Ext = ".adf,.adz,.dms,.hdf,.hdz,.ipf,.lha,.zip,.7z" }
    "amigacd32"       = @{ Name = "Amiga CD32";              Ext = ".cue,.bin,.iso,.chd,.lha" }
    "amiga1200"       = @{ Name = "Amiga 1200 (AGA)";       Ext = ".adf,.adz,.dms,.hdf,.hdz,.ipf,.lha,.zip,.7z" }
    "c64"             = @{ Name = "Commodore 64";            Ext = ".d64,.t64,.tap,.prg,.crt,.g64,.p00,.zip,.7z" }
    "c128"            = @{ Name = "Commodore 128";           Ext = ".d64,.d81,.t64,.tap,.prg,.crt,.zip,.7z" }
    "vic20"           = @{ Name = "Commodore VIC-20";        Ext = ".d64,.t64,.tap,.prg,.crt,.zip,.7z" }
    "pet"             = @{ Name = "Commodore PET";           Ext = ".d64,.d80,.d82,.prg,.tap,.zip,.7z" }
    "plus4"           = @{ Name = "Commodore Plus/4";        Ext = ".d64,.t64,.tap,.prg,.crt,.zip,.7z" }
    "msx"             = @{ Name = "MSX";                     Ext = ".rom,.mx1,.mx2,.dsk,.cas,.zip,.7z" }
    "msx2"            = @{ Name = "MSX2";                    Ext = ".rom,.mx2,.dsk,.cas,.zip,.7z" }
    "msxturbor"       = @{ Name = "MSX turboR";             Ext = ".rom,.dsk,.cas,.zip,.7z" }
    "zxspectrum"      = @{ Name = "ZX Spectrum";             Ext = ".tzx,.tap,.sna,.z80,.szx,.dsk,.zip,.7z" }
    "zx81"            = @{ Name = "Sinclair ZX81";           Ext = ".p,.tzx,.o,.zip,.7z" }
    "apple2"          = @{ Name = "Apple II";                Ext = ".dsk,.do,.po,.nib,.woz,.zip,.7z" }
    "apple2gs"        = @{ Name = "Apple IIGS";              Ext = ".2mg,.po,.dsk,.woz,.zip,.7z" }
    "ti99"            = @{ Name = "TI-99/4A";                Ext = ".rpk,.zip,.7z" }
    "samcoupe"        = @{ Name = "SAM Coupe";               Ext = ".dsk,.mgt,.sbt,.cpm,.zip,.7z" }
    "thomson"         = @{ Name = "Thomson MO/TO";           Ext = ".fd,.sap,.k7,.m5,.m7,.rom,.zip,.7z" }
    "oricatmos"       = @{ Name = "Oric / Oric Atmos";       Ext = ".dsk,.tap,.zip,.7z" }
    "pc88"            = @{ Name = "NEC PC-8801";             Ext = ".d88,.cmt,.t88,.zip,.7z" }
    "pc98"            = @{ Name = "NEC PC-9801";             Ext = ".fdi,.hdi,.d88,.d98,.zip,.7z,.hdd" }
    "x68000"          = @{ Name = "Sharp X68000";            Ext = ".dim,.hdf,.2hd,.xdf,.cmd,.m3u,.zip,.7z" }
    "x1"              = @{ Name = "Sharp X1";                Ext = ".dx1,.2d,.2hd,.tap,.cmd,.zip,.7z" }
    "fmtowns"         = @{ Name = "Fujitsu FM Towns";        Ext = ".cue,.bin,.iso,.chd,.ccd" }
    "spectravideo"    = @{ Name = "SpectraVideo SVI-3x8";    Ext = ".rom,.dsk,.cas,.zip,.7z" }
    "bbc"             = @{ Name = "BBC Micro";               Ext = ".ssd,.dsd,.uef,.zip,.7z" }
    "dragon"          = @{ Name = "Dragon 32/64";            Ext = ".cas,.wav,.bas,.rom,.ccc,.dmk,.jvc,.os9,.vdk,.zip,.7z" }
    "coco"            = @{ Name = "TRS-80 Color Computer";   Ext = ".cas,.wav,.bas,.rom,.ccc,.dmk,.jvc,.os9,.vdk,.dsk,.zip,.7z" }
    "trs80"           = @{ Name = "TRS-80";                  Ext = ".dsk,.cas,.cmd,.zip,.7z" }
    # -- Misc Consoles ----------------------------------------------------------
    "3do"             = @{ Name = "3DO Interactive Multiplayer"; Ext = ".iso,.cue,.bin,.chd" }
    "colecovision"    = @{ Name = "ColecoVision";            Ext = ".col,.rom,.bin,.zip,.7z" }
    "intellivision"   = @{ Name = "Intellivision";           Ext = ".int,.bin,.rom,.zip,.7z" }
    "vectrex"         = @{ Name = "Vectrex";                 Ext = ".vec,.bin,.gam,.zip,.7z" }
    "odyssey2"        = @{ Name = "Magnavox Odyssey 2";      Ext = ".bin,.zip,.7z" }
    "channelf"        = @{ Name = "Fairchild Channel F";     Ext = ".bin,.chf,.zip,.7z" }
    "supervision"     = @{ Name = "Watara Supervision";      Ext = ".sv,.bin,.zip,.7z" }
    "wonderswan"      = @{ Name = "WonderSwan";              Ext = ".ws,.zip,.7z" }
    "wonderswancolor" = @{ Name = "WonderSwan Color";        Ext = ".wsc,.ws,.zip,.7z" }
    "uzebox"          = @{ Name = "Uzebox";                  Ext = ".uze,.zip,.7z" }
    "videopac"        = @{ Name = "Videopac+ G7400";         Ext = ".bin,.zip,.7z" }
    "cdimono1"        = @{ Name = "Philips CD-i";            Ext = ".cue,.bin,.iso,.chd" }
    "pico8"           = @{ Name = "PICO-8";                  Ext = ".p8,.png" }
    "tic80"           = @{ Name = "TIC-80";                  Ext = ".tic" }
    "lutro"           = @{ Name = "Lutro (LOVE for RetroArch)"; Ext = ".lutro,.love" }
    "cavestory"       = @{ Name = "Cave Story (NXEngine)";   Ext = ".exe" }
    "easyrpg"         = @{ Name = "EasyRPG (RPG Maker 2000/2003)"; Ext = ".easyrpg,.ldb" }
    "openbor"         = @{ Name = "OpenBOR";                 Ext = ".pak" }
    "solarus"         = @{ Name = "Solarus";                 Ext = ".solarus" }
    "ports"           = @{ Name = "Ports";                   Ext = ".sh,.bat,.exe" }
    # -- Handheld ---------------------------------------------------------------
    "wswan"           = @{ Name = "Bandai WonderSwan";       Ext = ".ws,.zip,.7z" }
    "wswanc"          = @{ Name = "Bandai WonderSwan Color"; Ext = ".wsc,.ws,.zip,.7z" }
    "gw"              = @{ Name = "Game and Watch";          Ext = ".mgw,.zip,.7z" }
    "arduboy"         = @{ Name = "Arduboy";                 Ext = ".hex,.arduboy,.zip" }
    "gamate"          = @{ Name = "Bit Corp Gamate";         Ext = ".bin,.zip,.7z" }
    "megaduck"        = @{ Name = "Mega Duck";               Ext = ".bin,.zip,.7z" }
    "gmaster"         = @{ Name = "Hartung Game Master";     Ext = ".bin,.zip,.7z" }
}

# ==============================================================================
#  RETROARCH CORES -- mapped to systems
# ==============================================================================
#  Core DLL name -> array of system folder(s) it serves
#  These will be downloaded from the Buildbot.

$RetroArchCores = [ordered]@{
    # -- Nintendo ---------------------------------------------------------------
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
    # -- Sony -------------------------------------------------------------------
    "swanstation"            = @("psx")
    "pcsx_rearmed"           = @("psx")
    "mednafen_psx_hw"        = @("psx")
    "ppsspp"                 = @("psp")
    # -- Sega -------------------------------------------------------------------
    "genesis_plus_gx"        = @("mastersystem","megadrive","segacd","gamegear","sg1000")
    "genesis_plus_gx_wide"   = @("mastersystem","megadrive","segacd","gamegear","sg1000")
    "picodrive"              = @("mastersystem","megadrive","sega32x","segacd")
    "flycast"                = @("dreamcast","naomi","naomi2","atomiswave")
    "kronos"                 = @("saturn")
    "mednafen_saturn"        = @("saturn")
    "yabasanshiro"           = @("saturn")
    # -- NEC --------------------------------------------------------------------
    "mednafen_pce"           = @("pcengine","pcenginecd","supergrafx")
    "mednafen_pce_fast"      = @("pcengine","pcenginecd","supergrafx")
    "mednafen_pcfx"          = @("pcfx")
    # -- SNK --------------------------------------------------------------------
    "fbneo"                  = @("neogeo","neogeocd","fbneo","cps","cps2","cps3")
    "mednafen_ngp"           = @("ngp","ngpc")
    # -- Atari ------------------------------------------------------------------
    "stella"                 = @("atari2600")
    "stella2014"             = @("atari2600")
    "atari800"               = @("atari5200","atarixe")
    "prosystem"              = @("atari7800")
    "virtualjaguar"          = @("atarijaguar")
    "handy"                  = @("atarilynx")
    "mednafen_lynx"          = @("atarilynx")
    "hatari"                 = @("atarist")
    # -- Arcade -----------------------------------------------------------------
    "mame"                   = @("mame")
    "mame2003_plus"          = @("mame")
    "mame2010"               = @("mame")
    "daphne"                 = @("daphne")
    # -- Computers --------------------------------------------------------------
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
    # -- Misc Consoles ----------------------------------------------------------
    "opera"                  = @("3do")
    "vecx"                   = @("vectrex")
    "freeintv"               = @("intellivision")
    "mednafen_wswan"         = @("wonderswan","wonderswancolor","wswan","wswanc")
    "gw"                     = @("gw")
    "arduous"                = @("arduboy")
    "bk"                     = @("coco")
    "mesen-s"                = @("snes","gb","gbc")
    # -- Additional Japanese/obscure --------------------------------------------
    "nekop2"                 = @("pc98")
    "cap32"                  = @()  # Amstrad CPC (not in our systems but core exists)
    "crocods"                = @()  # Amstrad CPC
    "fmtowns"               = @("fmtowns")
}

# ==============================================================================
#  STANDALONE EMULATORS -- downloaded from GitHub where possible
# ==============================================================================

$StandaloneEmulators = @(
    @{
        Name      = "Dolphin"
        Folder    = "dolphin"
        Repo      = "dolphin-emu/dolphin"
        Pattern   = "Dolphin.*x64.*\.7z$"
        Systems   = @("gamecube","wii")
        Notes     = "GameCube and Wii emulator"
    },
    @{
        Name      = "PCSX2"
        Folder    = "pcsx2"
        Repo      = "PCSX2/pcsx2"
        Pattern   = "pcsx2.*windows.*x64.*\.7z$|pcsx2.*win.*64.*\.zip$"
        Systems   = @("ps2")
        Notes     = "PlayStation 2 emulator"
    },
    @{
        Name      = "RPCS3"
        Folder    = "rpcs3"
        Repo      = "RPCS3/rpcs3-binaries-win"
        Pattern   = "rpcs3.*win64.*\.7z$"
        Systems   = @("ps3")
        Notes     = "PlayStation 3 emulator -- requires PS3 firmware (PS3UPDAT.PUP)"
    },
    @{
        Name      = "DuckStation"
        Folder    = "duckstation"
        Repo      = "stenzek/duckstation"
        Pattern   = "duckstation.*windows.*x64.*\.zip$"
        Systems   = @("psx")
        Notes     = "PlayStation 1 emulator (high accuracy)"
    },
    @{
        Name      = "PPSSPP"
        Folder    = "ppsspp"
        Repo      = "hrydgard/ppsspp"
        Pattern   = "ppsspp.*windows.*64.*\.zip$|PPSSPPWindows64.*\.zip$"
        Systems   = @("psp")
        Notes     = "PlayStation Portable emulator"
    },
    @{
        Name      = "Cemu"
        Folder    = "cemu"
        Repo      = "cemu-project/Cemu"
        Pattern   = "cemu.*windows.*x64.*\.zip$"
        Systems   = @("wiiu")
        Notes     = "Wii U emulator"
    },
    @{
        Name      = "Xemu"
        Folder    = "xemu"
        Repo      = "xemu-project/xemu"
        Pattern   = "xemu.*win.*\.zip$"
        Systems   = @("xbox")
        Notes     = "Original Xbox emulator -- requires MCPX boot ROM + flash BIOS"
    },
    @{
        Name      = "Xenia Canary"
        Folder    = "xenia"
        Repo      = "xenia-canary/xenia-canary"
        Pattern   = "xenia_canary.*\.zip$"
        Systems   = @("xbox360")
        Notes     = "Xbox 360 emulator (experimental)"
    },
    @{
        Name      = "melonDS"
        Folder    = "melonds"
        Repo      = "melonDS-emu/melonDS"
        Pattern   = "melonDS.*win.*x64.*\.zip$|melonDS.*windows.*\.zip$"
        Systems   = @("nds")
        Notes     = "Nintendo DS emulator"
    },
    @{
        Name      = "mGBA"
        Folder    = "mgba"
        Repo      = "mgba-emu/mgba"
        Pattern   = "mGBA.*win.*64.*\.7z$|mGBA.*windows.*\.zip$"
        Systems   = @("gba","gb","gbc")
        Notes     = "Game Boy / GBC / GBA emulator"
    },
    @{
        Name      = "DOSBox Staging"
        Folder    = "dosbox-staging"
        Repo      = "dosbox-staging/dosbox-staging"
        Pattern   = "dosbox-staging.*windows.*x86_64.*\.zip$|dosbox-staging.*win.*\.zip$"
        Systems   = @("dos")
        Notes     = "Enhanced DOSBox fork for DOS gaming"
    },
    @{
        Name      = "ScummVM"
        Folder    = "scummvm"
        Repo      = "scummvm/scummvm"
        Pattern   = "scummvm.*win32.*x86_64.*\.zip$|scummvm.*windows.*\.zip$"
        Systems   = @("scummvm")
        Notes     = "Adventure game engine"
    },
    @{
        Name      = "Flycast"
        Folder    = "flycast"
        Repo      = "flyinghead/flycast"
        Pattern   = "flycast.*win.*x64.*\.zip$|flycast.*windows.*\.zip$"
        Systems   = @("dreamcast","naomi","naomi2","atomiswave")
        Notes     = "Dreamcast / NAOMI / Atomiswave emulator"
    },
    @{
        Name      = "Vita3K"
        Folder    = "vita3k"
        Repo      = "Vita3K/Vita3K"
        Pattern   = "Vita3K.*windows.*\.zip$|windows.*\.zip$"
        Systems   = @("psvita")
        Notes     = "PlayStation Vita emulator (experimental)"
    },
    @{
        Name      = "MAME"
        Folder    = "mame"
        Repo      = "mamedev/mame"
        Pattern   = "mame.*64bit.*\.exe$|mame.*win.*\.zip$"
        Systems   = @("mame","cps","cps2","cps3","model2","model3","neogeo","daphne")
        Notes     = "Multi-Arcade Machine Emulator"
    }
)

# ==============================================================================
#  BIOS FILE REFERENCE
# ==============================================================================

$BIOSPath = $Paths.BIOS
$RASystemPath = $Paths.RASystem
$EmulatorsPath = $Paths.Emulators

$BIOSGuide = @"
+==============================================================================+
|               BIOS / FIRMWARE FILE REFERENCE GUIDE                           |
|                                                                              |
|  Place all BIOS files in: $BIOSPath
|  RetroArch also checks:   $RASystemPath
|                                                                              |
|  All BIOS files must be legally obtained from hardware you own.              |
+==============================================================================+

-----------------------------------------------
  PLAYSTATION (PSX) -- DuckStation / Beetle PSX
-----------------------------------------------
  scph5500.bin   -- PS1 BIOS (Japan)       (MD5: 8dd7d5296a650fac7319bce665a6a53c)
  scph5501.bin   -- PS1 BIOS (USA)         (MD5: 490f666e1afb15b7362b406ed1cea246)
  scph5502.bin   -- PS1 BIOS (Europe)      (MD5: 32736f17079d0b2b7024407c39bd3050)

-----------------------------------------------
  PLAYSTATION 2 -- PCSX2
-----------------------------------------------
  Place in: $EmulatorsPath\pcsx2\bios\
  SCPH-70012.bin -- PS2 BIOS (USA, v12)
  SCPH-70004.bin -- PS2 BIOS (Europe)
  SCPH-70000.bin -- PS2 BIOS (Japan)
  (Any valid PS2 BIOS dump will work; PCSX2 auto-detects)

-----------------------------------------------
  PLAYSTATION 3 -- RPCS3
-----------------------------------------------
  PS3UPDAT.PUP   -- PS3 Firmware (download from Sony official site)
  Install via RPCS3 > File > Install Firmware

-----------------------------------------------
  SEGA DREAMCAST -- Flycast / RetroArch Flycast
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
  SEGA NAOMI / NAOMI 2 / ATOMISWAVE
-----------------------------------------------
  dc\naomi.zip       -- NAOMI BIOS
  dc\awbios.zip      -- Atomiswave BIOS
  (Place in dc subfolder within BIOS directory)

-----------------------------------------------
  NINTENDO DS -- melonDS / DeSmuME
-----------------------------------------------
  bios7.bin          -- ARM7 BIOS             (MD5: df692a80a5b1bc90728bc3dfc76cd948)
  bios9.bin          -- ARM9 BIOS             (MD5: a392174eb3e572fed6447e956bde4b25)
  firmware.bin       -- NDS Firmware           (MD5: 145eaef5bd3037cbc247c213bb3da1b3)
  (melonDS can run without BIOS using built-in HLE, but some games need them)

-----------------------------------------------
  NINTENDO 3DS -- Citra (and forks)
-----------------------------------------------
  Requires AES keys dumped from your 3DS console.
  aes_keys.txt       -- Place in Citra user directory

-----------------------------------------------
  GAME BOY ADVANCE -- mGBA / RetroArch mGBA
-----------------------------------------------
  gba_bios.bin       -- GBA BIOS (optional)   (MD5: a860e8c0b6d573d191e4ec7db1b1e4f6)

-----------------------------------------------
  GAME BOY / GAME BOY COLOR -- Gambatte
-----------------------------------------------
  gb_bios.bin        -- Game Boy BIOS (optional)  (MD5: 32fbbd84168d3482956eb3c5051637f5)
  gbc_bios.bin       -- GBC BIOS (optional)       (MD5: dbfce9db9deaa2567f6a84fde55f9680)
  sgb_bios.bin       -- Super Game Boy BIOS       (MD5: d574d4f9c12f305571c6b0ce18f0c563)

-----------------------------------------------
  SUPER NINTENDO -- BSnes (Super Game Boy)
-----------------------------------------------
  sgb2_boot.bin      -- Super Game Boy 2 BIOS

-----------------------------------------------
  FAMICOM DISK SYSTEM
-----------------------------------------------
  disksys.rom        -- FDS BIOS              (MD5: ca30b50f880eb660a320571e2a116f56)

-----------------------------------------------
  NEC PC ENGINE CD / TURBOGRAFX-CD
-----------------------------------------------
  syscard3.pce       -- System Card 3.0       (MD5: 38179df8f4ac870017db21ebcbf53114)

-----------------------------------------------
  NEC PC-FX
-----------------------------------------------
  pcfx.rom           -- PC-FX BIOS            (MD5: 08e36edbea28a017f79f8d4f7ff9b6d7)

-----------------------------------------------
  NEC PC-9801 -- Neko Project II
-----------------------------------------------
  np2kai\bios.rom    -- PC-98 BIOS
  np2kai\font.bmp    -- PC-98 Font
  np2kai\FONT.ROM    -- PC-98 Font ROM
  np2kai\itf.rom     -- ITF ROM
  np2kai\sound.rom   -- Sound BIOS

-----------------------------------------------
  SHARP X68000 -- PX68k
-----------------------------------------------
  keropi\iplrom.dat  -- X68000 IPL ROM
  keropi\cgrom.dat   -- X68000 CG ROM

-----------------------------------------------
  3DO INTERACTIVE MULTIPLAYER -- Opera
-----------------------------------------------
  panafz1.bin        -- Panasonic FZ-1 BIOS   (MD5: f47264dd47fe30f73ab3c010015c155b)
  panafz10.bin       -- Panasonic FZ-10 BIOS  (MD5: 51f2f43ae2f3508a14d9f56597e2d3ce)
  goldstar.bin       -- Goldstar GDO-101M     (MD5: 8970fc987ab89a7f64da9f8a8c4333ff)

-----------------------------------------------
  COLECOVISION
-----------------------------------------------
  colecovision.rom   -- ColecoVision BIOS     (MD5: 2c66f5911e5b42b8ebe113403548eee7)

-----------------------------------------------
  INTELLIVISION
-----------------------------------------------
  exec.bin           -- Executive ROM          (MD5: 62e761035cb657903761800f4437b8af)
  grom.bin           -- Graphics ROM           (MD5: 0cd5946c6473e42e8e4c2137785e427f)

-----------------------------------------------
  MSX / MSX2 / MSX turboR -- blueMSX
-----------------------------------------------
  Machines\           -- Directory of MSX machine configs
  Databases\          -- Directory of MSX databases
  (Download the full blueMSX Data Pack)

-----------------------------------------------
  COMMODORE AMIGA -- PUAE
-----------------------------------------------
  kick34005.A500     -- Amiga 500 Kickstart 1.3
  kick40063.A600     -- Amiga 600 Kickstart 2.05
  kick40068.A1200    -- Amiga 1200 Kickstart 3.1
  kick40060.CD32     -- CD32 Kickstart 3.1
  kick40060.CD32.ext -- CD32 Extended ROM

-----------------------------------------------
  ATARI 5200 / 800 -- Atari800
-----------------------------------------------
  5200.rom           -- Atari 5200 BIOS       (MD5: 281f20ea4320404ec820fb7ec0693b38)
  ATARIXL.ROM        -- Atari XL/XE OS
  ATARIBAS.ROM       -- Atari BASIC
  ATARIOSA.ROM       -- Atari OS/A

-----------------------------------------------
  ATARI 7800
-----------------------------------------------
  7800 BIOS (U).rom  -- Atari 7800 BIOS       (MD5: 0763f1ffb006ddbe32e52d497ee848ae)

-----------------------------------------------
  ATARI LYNX
-----------------------------------------------
  lynxboot.img       -- Lynx Boot ROM         (MD5: fcd403db69f54290b51035d82f835e7b)

-----------------------------------------------
  ATARI ST -- Hatari
-----------------------------------------------
  tos.img            -- TOS ROM (any version)

-----------------------------------------------
  NEO GEO -- FBNeo / MAME
-----------------------------------------------
  neogeo.zip         -- Neo Geo BIOS (place in ROMs dir alongside games)

-----------------------------------------------
  FAIRCHILD CHANNEL F -- FreeChaF
-----------------------------------------------
  sl31253.bin        -- ChannelF BIOS 1       (MD5: ac9804d4c0e9d07e33472e3726ed15c3)
  sl31254.bin        -- ChannelF BIOS 2       (MD5: da98f4f2c0ef0dcb26db376c069ba5cc)

-----------------------------------------------
  MAGNAVOX ODYSSEY 2 / VIDEOPAC
-----------------------------------------------
  o2rom.bin          -- Odyssey 2 BIOS        (MD5: 562d5ebf9e030a40d6fabfc2f33139fd)
  c52.bin            -- Videopac+ G7400 BIOS

-----------------------------------------------
  XBOX (ORIGINAL) -- Xemu
-----------------------------------------------
  mcpx_1.0.bin       -- MCPX Boot ROM
  Complex_4627.bin   -- Flash BIOS image (or other compatible BIOS)
  (Place in xemu directory)

-----------------------------------------------
  PHILIPS CD-i
-----------------------------------------------
  cdimono1.zip       -- CD-i BIOS (MAME format)
  cdibios.zip        -- Alternative BIOS pack

-----------------------------------------------
  FUJITSU FM TOWNS
-----------------------------------------------
  fmtowns\fmt_dic.rom    -- Dictionary ROM
  fmtowns\fmt_dos.rom    -- DOS ROM
  fmtowns\fmt_fnt.rom    -- Font ROM
  fmtowns\fmt_sys.rom    -- System ROM

-----------------------------------------------
  NOTES
-----------------------------------------------
  * Many RetroArch cores also check the "system" subfolder inside RetroArch.
    A symbolic link or copy in both locations ensures maximum compatibility.
  * MAME/FBNeo ROMs must match the exact version of the emulator.
  * Neo Geo BIOS (neogeo.zip) should be in BOTH the bios folder AND the
    roms/neogeo folder for compatibility with different emulator configs.
  * For systems not listed here, the emulator likely does not require BIOS files
    (software-only emulation / HLE).
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
Write-Host ""

# -- 1. Create directory structure ---------------------------------------------
Write-Step "Creating directory structure..."

foreach ($dir in $Paths.Values) {
    Ensure-Dir $dir
}

# ROM directories
foreach ($sys in $Systems.Keys) {
    Ensure-Dir "$($Paths.ROMs)\$sys"
}

# BIOS subdirectories
foreach ($sub in @("dc","np2kai","keropi","fmtowns","Machines","Databases")) {
    Ensure-Dir "$($Paths.BIOS)\$sub"
}

# Save/state directories per system
foreach ($sys in $Systems.Keys) {
    Ensure-Dir "$($Paths.Saves)\$sys"
    Ensure-Dir "$($Paths.States)\$sys"
}

$sysCount = $Systems.Count
Write-OK "Created $sysCount ROM directories, BIOS structure, saves and states"

# -- 2. Generate BIOS guide ----------------------------------------------------
Write-Step "Writing BIOS reference guide..."
$BIOSGuide | Out-File -FilePath "$($Paths.BIOS)\BIOS_README.txt" -Encoding ASCII -Force
Write-OK "BIOS guide written to $($Paths.BIOS)\BIOS_README.txt"

# -- 3. Generate ROM directory README files ------------------------------------
Write-Step "Writing ROM directory info files..."
foreach ($sys in $Systems.Keys) {
    $info = $Systems[$sys]
    $sysName = $info.Name
    $sysExt = $info.Ext
    $readme = @"
System: $sysName
Folder: $sys
Supported extensions: $sysExt

Place your legally obtained ROM/disc images in this folder.
"@
    $readmePath = "$($Paths.ROMs)\$sys\_info.txt"
    $readme | Out-File -FilePath $readmePath -Encoding ASCII -Force
}
Write-OK "ROM info files created for $sysCount systems"

# -- If SkipDownloads, stop here -----------------------------------------------
if ($SkipDownloads) {
    Write-Host ""
    Write-Host "  Directory structure created. Skipping downloads (-SkipDownloads)." -ForegroundColor Yellow
    Write-Host "  Manually download emulators to: $($Paths.Emulators)" -ForegroundColor Yellow
    Write-Host ""
    exit 0
}

# -- 4. Download ES-DE ---------------------------------------------------------
Write-Step "Downloading EmulationStation Desktop Edition (ES-DE)..."
Ensure-Dir $Paths.ESDE

$esdeRelease = Get-GitHubLatestRelease -Repo "ES-DE/ES-DE"
if ($esdeRelease) {
    $esdeUrl = Get-GitHubAssetUrl -Release $esdeRelease -Pattern "ES-DE.*Windows.*x64.*\.zip$|ES-DE.*Win64.*\.zip$"
    if (-not $esdeUrl) {
        # Try portable
        $esdeUrl = Get-GitHubAssetUrl -Release $esdeRelease -Pattern "ES-DE.*portable.*\.zip$|ES-DE.*\.zip$"
    }
    $esdeDl = "$($Paths.Downloads)\esde.zip"
    if (Download-File -Url $esdeUrl -Destination $esdeDl -Description "ES-DE") {
        Extract-Archive -Archive $esdeDl -Destination $Paths.ESDE -Description "ES-DE"
    }
}
else {
    Write-Err "Could not find ES-DE release. Download manually from https://es-de.org"
}

# -- 5. Download RetroArch -----------------------------------------------------
Write-Step "Downloading RetroArch..."
Ensure-Dir $Paths.RetroArch
Ensure-Dir $Paths.RACores
Ensure-Dir $Paths.RASystem

# RetroArch stable from buildbot
$raUrl = "https://buildbot.libretro.com/stable/1.19.1/windows/x86_64/RetroArch.7z"
$raFallback = "https://buildbot.libretro.com/stable/1.19.1/windows/x86_64/RetroArch.zip"
$raDl = "$($Paths.Downloads)\retroarch.7z"
$raDlZip = "$($Paths.Downloads)\retroarch.zip"

$raDownloaded = Download-File -Url $raUrl -Destination $raDl -Description "RetroArch (7z)"
if ($raDownloaded) {
    Extract-Archive -Archive $raDl -Destination $Paths.RetroArch -Description "RetroArch"
}
else {
    $raDownloaded = Download-File -Url $raFallback -Destination $raDlZip -Description "RetroArch (zip)"
    if ($raDownloaded) {
        Extract-Archive -Archive $raDlZip -Destination $Paths.RetroArch -Description "RetroArch"
    }
}

# -- 6. Download RetroArch Cores -----------------------------------------------
$coreTotal = $RetroArchCores.Count
Write-Step "Downloading RetroArch cores ($coreTotal cores)..."

$coreBaseUrl = "https://buildbot.libretro.com/nightly/windows/x86_64/latest"
$coreCount = 0
$coreFails = 0

foreach ($core in $RetroArchCores.Keys) {
    $coreDll = "${core}_libretro.dll"
    $coreZip = "${coreDll}.zip"
    $coreUrl = "$coreBaseUrl/$coreZip"
    $coreDest = "$($Paths.Downloads)\cores\$coreZip"
    $coreFinal = "$($Paths.RACores)\$coreDll"

    Ensure-Dir "$($Paths.Downloads)\cores"

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
        # Silent -- many cores may not exist on nightly for every name variant
    }
}

Write-OK "Downloaded $coreCount cores ($coreFails unavailable/failed)"

# -- 7. Download Standalone Emulators ------------------------------------------
if (-not $RetroArchOnly) {
    $emuTotal = $StandaloneEmulators.Count
    Write-Step "Downloading standalone emulators ($emuTotal emulators)..."

    foreach ($emu in $StandaloneEmulators) {
        Write-Info "Fetching $($emu.Name)..."
        $emuDir = "$($Paths.Emulators)\$($emu.Folder)"
        Ensure-Dir $emuDir

        $release = Get-GitHubLatestRelease -Repo $emu.Repo
        if (-not $release) {
            Write-Err "Could not find release for $($emu.Name) ($($emu.Repo))"
            continue
        }

        $assetUrl = Get-GitHubAssetUrl -Release $release -Pattern $emu.Pattern
        if (-not $assetUrl) {
            # Try broader match
            $assetUrl = $release.assets |
                Where-Object { $_.name -match 'win' -and $_.name -match '(64|x64|x86_64)' } |
                Select-Object -First 1 |
                ForEach-Object { $_.browser_download_url }
        }
        if (-not $assetUrl) {
            Write-Err "No matching Windows x64 asset found for $($emu.Name)"
            continue
        }

        $ext = if ($assetUrl -match '\.7z$') { ".7z" } elseif ($assetUrl -match '\.exe$') { ".exe" } else { ".zip" }
        $dlPath = "$($Paths.Downloads)\$($emu.Folder)$ext"

        if (Download-File -Url $assetUrl -Destination $dlPath -Description $emu.Name) {
            if ($ext -eq ".exe") {
                # Standalone exe -- just copy
                Copy-Item -Path $dlPath -Destination "$emuDir\$($emu.Folder).exe" -Force
                Write-OK "Installed $($emu.Name)"
            }
            else {
                Extract-Archive -Archive $dlPath -Destination $emuDir -Description $emu.Name
            }
        }
    }
}
else {
    Write-Skip "Skipping standalone emulators (-RetroArchOnly)"
}

# -- 8. Create RetroArch system BIOS symlink -----------------------------------
Write-Step "Linking BIOS directory to RetroArch system folder..."
try {
    $linkTarget = $Paths.BIOS
    $linkPath = $Paths.RASystem

    $existingItem = Get-Item $linkPath -ErrorAction SilentlyContinue
    $isJunction = $false
    if ($existingItem) {
        $isJunction = $existingItem.Attributes.ToString().Contains("ReparsePoint")
    }

    if (-not $isJunction) {
        # Try junction first (no admin needed)
        cmd /c mklink /J "`"$linkPath`"" "`"$linkTarget`"" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Created junction: RetroArch\system -> bios"
        }
        else {
            Write-Info "Junction failed -- BIOS files should be copied to both locations"
        }
    }
}
catch {
    Write-Info "Could not link BIOS dirs. Copy BIOS files to both $($Paths.BIOS) and $($Paths.RASystem)"
}

# -- 9. Generate ES-DE custom systems config snippet --------------------------
Write-Step "Generating ES-DE configuration notes..."

$romsPath = $Paths.ROMs
$retroArchPath = $Paths.RetroArch
$coresPath = $Paths.RACores

$esdeConfig = @"
==============================================================================
 ES-DE Configuration Notes
==============================================================================

 ES-DE will auto-detect most settings. The key paths to configure in ES-DE:

 ROM Directory:        $romsPath
 Media Directory:      $BasePath\downloaded_media

 ES-DE Settings > Other Settings:
   - Set "ROM directory" to the path above
   - Set "Media directory" to $BasePath\downloaded_media

 ES-DE Settings > Emulator / core assignments (per system):
   Default emulator should be RetroArch for most systems.
   Configure exceptions for standalone emulators:

   PlayStation 2   > PCSX2 (standalone)     : $EmulatorsPath\pcsx2\
   PlayStation 3   > RPCS3 (standalone)     : $EmulatorsPath\rpcs3\
   PlayStation 1   > DuckStation (standalone): $EmulatorsPath\duckstation\
   GameCube/Wii    > Dolphin (standalone)   : $EmulatorsPath\dolphin\
   Wii U           > Cemu (standalone)      : $EmulatorsPath\cemu\
   Xbox            > Xemu (standalone)      : $EmulatorsPath\xemu\
   Xbox 360        > Xenia (standalone)     : $EmulatorsPath\xenia\
   Nintendo DS     > melonDS (standalone)   : $EmulatorsPath\melonds\
   PSP             > PPSSPP (standalone)    : $EmulatorsPath\ppsspp\
   PS Vita         > Vita3K (standalone)    : $EmulatorsPath\vita3k\
   Dreamcast       > Flycast (standalone)   : $EmulatorsPath\flycast\
   Arcade/MAME     > MAME (standalone)      : $EmulatorsPath\mame\
   DOS             > DOSBox Staging         : $EmulatorsPath\dosbox-staging\
   ScummVM         > ScummVM (standalone)   : $EmulatorsPath\scummvm\

 All other systems default to RetroArch with the appropriate core.

 RetroArch Location:   $retroArchPath
 RetroArch Cores:      $coresPath

==============================================================================

 SCRAPING: ES-DE has a built-in scraper. Go to:
   Main Menu > Scraper > ScreenScraper (recommended)
   Create a free account at https://www.screenscraper.fr/
   Then scrape your ROM collection for box art, descriptions, videos, etc.

==============================================================================
"@

$esdeConfig | Out-File -FilePath "$($Paths.Config)\ES-DE_SETUP_NOTES.txt" -Encoding ASCII -Force
Write-OK "Configuration notes written to $($Paths.Config)\ES-DE_SETUP_NOTES.txt"

# -- 10. Create a quick-launch batch file --------------------------------------
Write-Step "Creating launcher..."

$esdePath = $Paths.ESDE

$launcher = @"
@echo off
title EmulationStation Desktop Edition
echo Starting ES-DE...
cd /d "$esdePath"

REM Try common ES-DE executable names
if exist "ES-DE.exe" (
    start "" "ES-DE.exe"
    exit
)
if exist "EmulationStation.exe" (
    start "" "EmulationStation.exe"
    exit
)

REM Search for any exe in the ES-DE folder
for %%f in (*.exe) do (
    start "" "%%f"
    exit
)

echo Could not find ES-DE executable. Please check $esdePath
pause
"@

$launcher | Out-File -FilePath "$BasePath\Launch_ES-DE.bat" -Encoding ASCII -Force
Write-OK "Launcher created: $BasePath\Launch_ES-DE.bat"

# -- 11. Summary ---------------------------------------------------------------
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "                      SETUP COMPLETE" -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Directory structure:" -ForegroundColor White
Write-Host "    $BasePath"
Write-Host "    |-- emulators\        <- All emulators (ES-DE, RetroArch, standalone)"
Write-Host "    |   |-- ES-DE\        <- EmulationStation Desktop Edition"
Write-Host "    |   |-- RetroArch\    <- RetroArch portable with cores"
Write-Host "    |   |-- dolphin\      <- GameCube / Wii"
Write-Host "    |   |-- pcsx2\        <- PlayStation 2"
Write-Host "    |   |-- rpcs3\        <- PlayStation 3"
Write-Host "    |   |-- duckstation\  <- PlayStation 1"
Write-Host "    |   |-- ppsspp\       <- PSP"
Write-Host "    |   |-- cemu\         <- Wii U"
Write-Host "    |   |-- xemu\         <- Xbox"
Write-Host "    |   |-- xenia\        <- Xbox 360"
Write-Host "    |   |-- melonds\      <- Nintendo DS"
Write-Host "    |   |-- mgba\         <- GBA / GB / GBC"
Write-Host "    |   |-- flycast\      <- Dreamcast / NAOMI"
Write-Host "    |   |-- vita3k\       <- PS Vita"
Write-Host "    |   |-- mame\         <- Arcade (MAME)"
Write-Host "    |   |-- dosbox-staging\ <- MS-DOS"
Write-Host "    |   \-- scummvm\      <- ScummVM"
Write-Host "    |-- roms\             <- $sysCount system folders"
Write-Host "    |-- bios\             <- BIOS/firmware files (see BIOS_README.txt)"
Write-Host "    |-- saves\            <- Save files per system"
Write-Host "    |-- states\           <- Save states per system"
Write-Host "    |-- config\           <- Configuration files"
Write-Host "    \-- Launch_ES-DE.bat  <- Quick launcher"
Write-Host ""
Write-Host "  NEXT STEPS:" -ForegroundColor Yellow
Write-Host "    1. Read $($Paths.BIOS)\BIOS_README.txt and add your BIOS files" -ForegroundColor White
Write-Host "    2. Read $($Paths.Config)\ES-DE_SETUP_NOTES.txt for ES-DE config" -ForegroundColor White
Write-Host "    3. Place your legally obtained ROMs in the appropriate roms\ subfolder" -ForegroundColor White
Write-Host "    4. Launch ES-DE and configure ROM/media paths" -ForegroundColor White
Write-Host "    5. Scrape your collection for artwork and metadata" -ForegroundColor White
Write-Host ""
Write-Host "  Total systems configured: $sysCount" -ForegroundColor Cyan
Write-Host "  RetroArch cores included: $coreTotal" -ForegroundColor Cyan
Write-Host "  Standalone emulators:     $emuTotal" -ForegroundColor Cyan
Write-Host ""
