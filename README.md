# Setup-EmulationStation

A single PowerShell script that bootstraps a complete [ES-DE (EmulationStation Desktop Edition)](https://es-de.org) portable install on Windows 11, targeting full parity with the [Batocera](https://batocera.org) x86_64 system list.

One command gives you the frontend, RetroArch with ~80 libretro cores, 16 standalone emulators (including Nintendo Switch), 100+ ROM directories, and a detailed BIOS reference guide with MD5 checksums — all laid out exactly where ES-DE portable expects to find them.

---

## What It Does

| Step | Description |
|------|-------------|
| **ES-DE portable** | Downloads the latest ES-DE portable release from GitLab and extracts it so `ES-DE.exe` sits at the install root. |
| **RetroArch** | Downloads RetroArch portable from the libretro buildbot, then pulls ~80 cores from the nightly channel covering every system from Atari 2600 to Sharp X68000. |
| **Standalone emulators** | Downloads 16 standalone emulators from their latest GitHub/GitLab releases into `Emulators\` where ES-DE auto-discovers them. |
| **ROM directories** | Creates `ROMs\<system>\` folders for 100+ systems with `_info.txt` files listing supported extensions. |
| **BIOS guide** | Generates `BIOS_README.txt` listing every required and optional firmware file with MD5 hashes. |
| **Quick-start guide** | Generates `QUICK_START.txt` with first-launch instructions. |
| **Launcher** | Creates `Launch_ES-DE.bat` at the install root. |

## Requirements

- **Windows 11** (Windows 10 should also work)
- **PowerShell 5.1+** (ships with Windows)
- **Internet connection** for downloading emulators and cores
- **~5-10 GB free disk space** depending on which emulators are downloaded
- Running as **Administrator** is recommended (needed for 7-Zip auto-install)

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
.\Setup-EmulationStation.ps1 -BasePath "D:\Emulation"

# Scaffold the folder structure first, download later
.\Setup-EmulationStation.ps1 -SkipDownloads

# RetroArch + cores only (no standalone emulators)
.\Setup-EmulationStation.ps1 -RetroArchOnly
```

## Directory Layout

The install root **is** the ES-DE portable root. ES-DE auto-detects `ROMs\` and `Emulators\` with zero configuration needed on first launch.

```
C:\EmulationStation\
|-- ES-DE.exe                       <- Launch this
|-- ROMs\                           <- ES-DE default ROM path (portable mode)
|   |-- nes\                        <- Each system has its own folder
|   |-- snes\                       <-   with a _info.txt listing
|   |-- psx\                        <-   supported file extensions
|   |-- switch\
|   |-- ...                         <- 100+ system folders total
|   \-- mame\
|-- Emulators\                      <- ES-DE searches here via es_find_rules.xml
|   |-- RetroArch\                  <- RetroArch portable
|   |   |-- retroarch.exe
|   |   |-- cores\                  <- ~80 libretro core DLLs
|   |   \-- system\                 <- BIOS / firmware files go here
|   |       |-- BIOS_README.txt     <- Full BIOS reference with MD5 hashes
|   |       |-- dc\                 <- Dreamcast / NAOMI BIOS subfolder
|   |       |-- np2kai\             <- PC-9801 subfolder
|   |       \-- keropi\             <- X68000 subfolder
|   |-- Dolphin\                    <- GameCube / Wii
|   |-- PCSX2\                      <- PlayStation 2
|   |-- RPCS3\                      <- PlayStation 3
|   |-- duckstation\                <- PlayStation 1
|   |-- PPSSPP\                     <- PSP
|   |-- Cemu\                       <- Wii U
|   |-- Ryujinx\                    <- Nintendo Switch (Ryubing fork)
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

All 16 are downloaded automatically from their official GitHub/GitLab releases:

| Emulator | System(s) | Source |
|----------|-----------|--------|
| RetroArch | Most systems via ~80 libretro cores | libretro buildbot |
| Dolphin | GameCube, Wii | dolphin-emu/dolphin |
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
| ScummVM | Adventure games | scummvm/scummvm |

## Supported Systems

The script creates ROM directories and maps emulators for the full Batocera x86_64 system set, including but not limited to:

<details>
<summary><strong>Nintendo</strong></summary>

NES, SNES, N64, GameCube, Wii, Wii U, Switch, Game Boy, Game Boy Color, Game Boy Advance, Nintendo DS, Nintendo 3DS, Famicom Disk System, Satellaview, SuFami Turbo, Super Game Boy, Virtual Boy, Pokemon Mini

</details>

<details>
<summary><strong>Sony</strong></summary>

PlayStation, PlayStation 2, PlayStation 3, PSP, PS Vita

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

The generated `BIOS_README.txt` (in both the install root and `Emulators\RetroArch\system\`) lists every BIOS file you may need, organised by system, with MD5 checksums for verification. **You must legally obtain these from hardware you own.** Key systems requiring BIOS files:

- **PlayStation** -- `scph5501.bin` (USA), `scph5502.bin` (EU), `scph5500.bin` (JP) -- place in `Emulators\RetroArch\system\`
- **PlayStation 2** -- Any valid SCPH dump placed in `Emulators\PCSX2\bios\`
- **PlayStation 3** -- `PS3UPDAT.PUP` installed via RPCS3 > File > Install Firmware
- **Nintendo Switch** -- `prod.keys` dumped from your Switch, firmware installed via Ryujinx > Tools > Install Firmware
- **Dreamcast** -- `dc_boot.bin`, `dc_flash.bin` in `Emulators\RetroArch\system\dc\`
- **Saturn** -- `mpr-17933.bin` (USA/EU), `sega_101.bin` (JP)
- **Sega CD** -- `bios_CD_U.bin`, `bios_CD_E.bin`, `bios_CD_J.bin`
- **Neo Geo** -- `neogeo.zip` (place in both `Emulators\RetroArch\system\` and `ROMs\neogeo\`)

See `BIOS_README.txt` for the complete list.

## Post-Install Configuration

ES-DE portable auto-detects ROMs and emulators from the directory layout this script creates. **No manual path configuration should be needed on first launch.**

1. Run `ES-DE.exe` (or `Launch_ES-DE.bat`).
2. ES-DE finds your `ROMs\` and `Emulators\` directories automatically.
3. Add your legally obtained ROM files to the matching `ROMs\` subfolders.
4. Add BIOS files where needed (see `BIOS_README.txt`).
5. Optionally, create a free [ScreenScraper](https://www.screenscraper.fr/) account and use ES-DE's built-in scraper to download box art, screenshots, and metadata.

## Re-running the Script

The script is safe to re-run. Already-downloaded archives in `.downloads\` are detected and skipped, so subsequent runs only fetch what's missing. Existing ROM and BIOS files are never modified or deleted.

## Notes

- **7-Zip** is auto-installed if needed (some emulators ship as `.7z`).
- **GitHub API rate limits** apply (~60 unauthenticated requests/hour). If you hit limits mid-run, wait a few minutes and re-run -- completed downloads are skipped.
- Some RetroArch cores from the nightly buildbot may fail to download -- this is expected for cores not yet built for the latest nightly. RetroArch will still function with the cores that succeed.
- ES-DE is hosted on **GitLab** (not GitHub). The script queries the GitLab API with a hardcoded fallback URL.

## License

MIT -- see [LICENSE](LICENSE) for details.

This script downloads open-source emulators from their official sources. No ROMs, BIOS files, or copyrighted material is included or distributed. You are responsible for ensuring you legally own any software you use with these emulators.
