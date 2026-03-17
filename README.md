# Setup-EmulationStation

A single PowerShell script that bootstraps a complete [ES-DE (EmulationStation Desktop Edition)](https://es-de.org) portable install on Windows 11, targeting full parity with the [Batocera](https://batocera.org) x86_64 system list.

One command gives you the frontend, RetroArch with ~80 libretro cores, 17 standalone emulators (including Nintendo Switch), a detailed BIOS reference guide with MD5 checksums, and pre-configured emulator defaults so standalone emulators are used where they should be.

---

## What It Does

| Step | Description |
|------|-------------|
| **ES-DE portable** | Downloads the latest ES-DE portable release from GitLab and extracts it so `ES-DE.exe` sits at the install root. |
| **VC++ Redist** | Installs the Visual C++ x64 Redistributable if not already present (required by several emulators). |
| **RetroArch** | Downloads RetroArch 1.20.0 portable from the libretro buildbot, then pulls ~80 cores from the nightly channel. |
| **Standalone emulators** | Downloads 17 standalone emulators from their latest GitHub/GitLab releases into `Emulators\` where ES-DE auto-discovers them. |
| **Emulator defaults** | Pre-creates `ES-DE/es_settings.xml` with standalone emulators set as the system-level default for PS2, PS3, GameCube, Wii, Switch, PSX, PSP, NDS, Dreamcast, Xbox, Xbox 360, Wii U, and PS Vita. Per-game overrides remain enabled. |
| **ROM directories** | Creates an empty `ROMs\` directory. On first launch, ES-DE generates correctly named subfolders for all 150+ supported systems via its built-in directory generator. |
| **BIOS guide** | Generates `BIOS_README.txt` listing every required and optional firmware file with MD5 hashes. |
| **Quick-start guide** | Generates `QUICK_START.txt` with first-launch instructions. |
| **Launcher** | Creates `Launch_ES-DE.bat` at the install root. |

## Requirements

- **Windows 11** (Windows 10 should also work)
- **PowerShell 5.1+** (ships with Windows)
- **Internet connection** for downloading emulators and cores
- **~5-10 GB free disk space** depending on which emulators are downloaded
- Running as **Administrator** is recommended (needed for 7-Zip and VC++ Redist auto-install)

## Quick Start

```powershell
# Clone the repo
git clone https://github.com/dvandenburgh/Setup-EmulationStation.git
cd Setup-EmulationStation

# Run with default settings (installs to C:\EmulationStation)
.\Setup-EmulationStation.ps1
```

If PowerShell blocks the script, unblock it first:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Setup-EmulationStation.ps1
```

## Usage

```
.\Setup-EmulationStation.ps1 [-BasePath <path>] [-SkipDownloads] [-RetroArchOnly]
```

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BasePath` | `C:\EmulationStation` | Root directory. Becomes the ES-DE portable install root. |
| `-SkipDownloads` | off | Only create the directory structure and reference files -- download nothing. |
| `-RetroArchOnly` | off | Download RetroArch and cores but skip all standalone emulators. |

### Examples

```powershell
# Install to a different drive
.\Setup-EmulationStation.ps1 -BasePath "D:\EmulationStation"

# Scaffold the folder structure first, download later
.\Setup-EmulationStation.ps1 -SkipDownloads

# RetroArch + cores only (no standalone emulators)
.\Setup-EmulationStation.ps1 -RetroArchOnly
```

## Directory Layout

The install root **is** the ES-DE portable root. ES-DE auto-detects `Emulators\` on first launch. For `ROMs\`, click **"Generate directory structure"** in the first-launch dialog to create all system subfolders with the correct ES-DE names.

```
C:\EmulationStation\
|-- ES-DE.exe                       <- Launch this
|-- ES-DE\                          <- ES-DE config and settings
|   \-- es_settings.xml             <- Pre-configured emulator defaults
|-- ROMs\                           <- ES-DE generates system folders on first launch
|   |-- gc\                         <- GameCube (ES-DE names, NOT Batocera names)
|   |-- snes\
|   |-- psx\
|   |-- switch\
|   \-- ...                         <- 150+ system folders created by ES-DE
|-- Emulators\                      <- ES-DE searches here via es_find_rules.xml
|   |-- RetroArch\                  <- RetroArch 1.20.0 portable
|   |   |-- retroarch.exe
|   |   |-- cores\                  <- ~80 libretro core DLLs
|   |   \-- system\                 <- BIOS / firmware files go here
|   |       |-- BIOS_README.txt     <- Full BIOS reference with MD5 hashes
|   |       |-- dc\                 <- Dreamcast / NAOMI BIOS subfolder
|   |       |-- np2kai\             <- PC-9801 subfolder
|   |       \-- keropi\             <- X68000 subfolder
|   |-- Dolphin\                    <- GameCube / Wii
|   |-- PCSX2\                      <- PlayStation 2
|   |   \-- bios\                   <- PS2 BIOS files go here
|   |-- RPCS3\                      <- PlayStation 3
|   |-- duckstation\                <- PlayStation 1
|   |-- PPSSPP\                     <- PSP
|   |-- Cemu\                       <- Wii U
|   |-- Ryujinx\                    <- Nintendo Switch (Ryubing fork)
|   |-- shadPS4\                    <- PlayStation 4
|   |-- xemu\                       <- Xbox
|   |-- Xenia\                      <- Xbox 360
|   |-- melonDS\                    <- Nintendo DS
|   |-- mGBA\                       <- GBA / GB / GBC
|   |-- Flycast\                    <- Dreamcast / NAOMI / Atomiswave
|   |-- Vita3K\                     <- PS Vita
|   |-- MAME\                       <- Arcade
|   |-- dosbox-staging\             <- MS-DOS
|   \-- ScummVM\                    <- ScummVM
|-- BIOS_README.txt                 <- BIOS reference (copy at root for visibility)
|-- QUICK_START.txt                 <- First-launch setup guide
|-- Launch_ES-DE.bat                <- Quick launcher
\-- .downloads\                     <- Cached archives (safe to delete after setup)
```

## Standalone Emulators

All 17 are downloaded automatically from their official sources:

| Emulator | System(s) | Source |
|----------|-----------|--------|
| RetroArch | Most systems via ~80 libretro cores | libretro buildbot |
| Dolphin | GameCube, Wii | dl.dolphin-emu.org |
| PCSX2 | PlayStation 2 | PCSX2/pcsx2 |
| RPCS3 | PlayStation 3 | RPCS3/rpcs3-binaries-win |
| DuckStation | PlayStation 1 | stenzek/duckstation |
| PPSSPP | PSP | hrydgard/ppsspp |
| Cemu | Wii U | cemu-project/Cemu |
| Ryujinx (Ryubing) | Nintendo Switch | Kenji-NX/Releases |
| Xemu | Xbox | xemu-project/xemu |
| Xenia Canary | Xbox 360 | xenia-canary/xenia-canary-releases |
| melonDS | Nintendo DS | melonDS-emu/melonDS |
| mGBA | GBA, GB, GBC | mgba-emu/mgba |
| Flycast | Dreamcast, NAOMI, Atomiswave | flyinghead/flycast |
| Vita3K | PS Vita | Vita3K/Vita3K |
| MAME | Arcade | mamedev/mame |
| DOSBox Staging | MS-DOS | dosbox-staging/dosbox-staging |
| ScummVM | Adventure games | scummvm.org |
| shadPS4 | PlayStation 4 | shadps4-emu/shadPS4 |

## Emulator Configuration

The script pre-creates `ES-DE/es_settings.xml` with standalone emulators set as the **system-level default** for these systems:

| System | Default Emulator |
|--------|-----------------|
| PlayStation 2 | PCSX2 (Standalone) |
| PlayStation 3 | RPCS3 |
| PlayStation 1 | DuckStation (Standalone) |
| GameCube | Dolphin (Standalone) |
| Wii | Dolphin (Standalone) |
| Wii U | Cemu |
| Nintendo Switch | Ryujinx |
| PSP | PPSSPP (Standalone) |
| Nintendo DS | melonDS (Standalone) |
| Dreamcast | Flycast (Standalone) |
| Xbox | xemu |
| Xbox 360 | Xenia |
| PS Vita | Vita3K (Standalone) |
| PlayStation 4 | shadPS4 |

All other systems default to RetroArch with the appropriate core.

**Per-game alternative emulators are enabled** -- you can override the default for any individual game via Select > Edit This Game's Metadata > Alternative Emulator.

## Supported Systems

ES-DE supports 150+ game systems out of the box. When you click "Generate directory structure" on first launch, it creates ROM folders for all of them. Key systems include:

<details>
<summary><strong>Nintendo</strong></summary>

NES, SNES, N64, GameCube, Wii, Wii U, Switch, Game Boy, Game Boy Color, Game Boy Advance, Nintendo DS, Nintendo 3DS, Famicom Disk System, Satellaview, SuFami Turbo, Super Game Boy, Virtual Boy, Pokemon Mini

</details>

<details>
<summary><strong>Sony</strong></summary>

PlayStation, PlayStation 2, PlayStation 3, PlayStation 4, PSP, PS Vita

</details>

<details>
<summary><strong>Sega</strong></summary>

Master System, Genesis / Mega Drive, 32X, Sega CD, Saturn, Dreamcast, Game Gear, SG-1000, NAOMI, NAOMI 2, Atomiswave

</details>

<details>
<summary><strong>Atari</strong></summary>

2600, 5200, 7800, Jaguar, Lynx, ST/STE/TT/Falcon, 800/XL/XE

</details>

<details>
<summary><strong>NEC</strong></summary>

PC Engine / TurboGrafx-16, PC Engine CD, PC-FX, SuperGrafx

</details>

<details>
<summary><strong>SNK</strong></summary>

Neo Geo MVS/AES, Neo Geo CD, Neo Geo Pocket, Neo Geo Pocket Color

</details>

<details>
<summary><strong>Microsoft</strong></summary>

Xbox, Xbox 360

</details>

<details>
<summary><strong>Arcade</strong></summary>

MAME, FinalBurn Neo, CPS1, CPS2, CPS3, Sega Model 2, Sega Model 3, Daphne (Laserdisc)

</details>

<details>
<summary><strong>Computers</strong></summary>

MS-DOS, ScummVM, Amiga, Amiga CD32, Amiga 1200, C64, C128, VIC-20, PET, Plus/4, MSX, MSX2, MSX turboR, ZX Spectrum, ZX81, Apple II, Apple IIGS, TI-99/4A, SAM Coupe, Thomson MO/TO, Oric Atmos, NEC PC-8801, NEC PC-9801, Sharp X68000, Sharp X1, FM Towns, BBC Micro, Dragon 32/64, TRS-80 CoCo, TRS-80

</details>

<details>
<summary><strong>Other Consoles and Handhelds</strong></summary>

3DO, ColecoVision, Intellivision, Vectrex, Odyssey 2, Channel F, Watara Supervision, WonderSwan, WonderSwan Color, Uzebox, Videopac+ G7400, Philips CD-i, PICO-8, TIC-80, Game and Watch, Arduboy, Mega Duck, Gamate, Game Master

</details>

<details>
<summary><strong>Game Engines</strong></summary>

Cave Story (NXEngine), EasyRPG (RPG Maker 2000/2003), OpenBOR, Solarus, Lutro, Ports

</details>

## BIOS Files

The generated `BIOS_README.txt` (in both the install root and `Emulators\RetroArch\system\`) lists every BIOS file you may need with MD5 checksums. **You must legally obtain these from hardware you own.** Key systems:

- **PlayStation** -- `scph5501.bin` (USA), `scph5502.bin` (EU), `scph5500.bin` (JP) -- place in `Emulators\RetroArch\system\`
- **PlayStation 2** -- Any valid SCPH dump placed in `Emulators\PCSX2\bios\`
- **PlayStation 3** -- `PS3UPDAT.PUP` installed via RPCS3 > File > Install Firmware
- **Nintendo Switch** -- `prod.keys` dumped from your Switch, firmware installed via Ryujinx > Tools > Install Firmware
- **PlayStation 4** -- Firmware modules dumped from your PS4, placed in `Emulators\shadPS4\user\sys_modules\`
- **Dreamcast** -- `dc_boot.bin`, `dc_flash.bin` in `Emulators\RetroArch\system\dc\`
- **Saturn** -- `mpr-17933.bin` (USA/EU), `sega_101.bin` (JP)
- **Sega CD** -- `bios_CD_U.bin`, `bios_CD_E.bin`, `bios_CD_J.bin`
- **Neo Geo** -- `neogeo.zip` (place in both `Emulators\RetroArch\system\` and `ROMs\neogeo\`)

See `BIOS_README.txt` for the complete list.

## Post-Install

1. Run `ES-DE.exe` (or `Launch_ES-DE.bat`).
2. On first launch, click **"Generate directory structure"** to create all system ROM folders.
3. Add your legally obtained ROM files to the matching `ROMs\` subfolders. **Important:** ES-DE uses its own folder names (e.g. `gc` not `gamecube`, `n3ds` not `3ds`). The generated folders have the correct names.
4. Add BIOS files where needed (see `BIOS_README.txt`).
5. Standalone emulators are already configured as defaults -- no manual emulator selection needed.
6. Optionally, create a free [ScreenScraper](https://www.screenscraper.fr/) account and scrape your collection for artwork.

### PS3 Games (RPCS3)

PS3 games work differently from other systems. You can either place `.pkg` files in `ROMs\ps3\` and let ES-DE launch them through RPCS3, or install games directly in RPCS3 via File > Install .pkg. Make sure firmware is installed first (RPCS3 > File > Install Firmware).

## Re-running the Script

The script is safe to re-run. Already-downloaded archives in `.downloads\` are detected and skipped, emulators with their expected `.exe` already in place are skipped, and existing ROM/BIOS files are never modified or deleted.

## Notes

- **7-Zip** is auto-installed if needed (some emulators ship as `.7z`).
- **VC++ Redistributable** is auto-installed (required by Dolphin, PCSX2, and others).
- **GitHub API rate limits** apply (~60 unauthenticated requests/hour). If you hit limits mid-run, wait a few minutes and re-run.
- Some RetroArch cores from the nightly buildbot may fail to download -- this is expected for cores not yet built for the latest nightly.
- ES-DE is hosted on **GitLab** (not GitHub). The script queries the GitLab API with a hardcoded fallback URL.
- Large downloads (MAME, RPCS3) use a .NET WebClient fallback if `Invoke-WebRequest` fails.

## License

MIT -- see [LICENSE](LICENSE) for details.

This script downloads open-source emulators from their official sources. No ROMs, BIOS files, or copyrighted material is included or distributed. You are responsible for ensuring you legally own any software you use with these emulators.
