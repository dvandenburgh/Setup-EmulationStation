# Setup-EmulationStation

A single PowerShell script that bootstraps a complete [ES-DE (EmulationStation Desktop Edition)](https://es-de.org) install on Windows 11, targeting full parity with the [Batocera](https://batocera.org) x86_64 system list.

One command gives you the frontend, RetroArch with ~80 libretro cores, 15 standalone emulators, 100+ ROM directories, per-system save/state folders, and a detailed BIOS reference guide with MD5 checksums.

---

## What It Does

| Step | Description |
|------|-------------|
| **Directory tree** | Creates the full folder structure — ROMs, BIOS, saves, states, config — with per-system subfolders and `_info.txt` files listing supported extensions. |
| **ES-DE** | Downloads the latest ES-DE release from GitHub. |
| **RetroArch** | Downloads RetroArch portable from the libretro buildbot, then pulls ~80 cores from the nightly channel covering every system from Atari 2600 to Sharp X68000. |
| **Standalone emulators** | Downloads the latest GitHub release for Dolphin, PCSX2, RPCS3, DuckStation, PPSSPP, Cemu, Xemu, Xenia, melonDS, mGBA, Flycast, Vita3K, MAME, DOSBox Staging, and ScummVM. |
| **BIOS guide** | Generates `bios/BIOS_README.txt` listing every required and optional firmware file with MD5 hashes, organised by system. |
| **ES-DE config notes** | Generates `config/ES-DE_SETUP_NOTES.txt` mapping each standalone emulator to its ES-DE system entry. |
| **Launcher** | Creates `Launch_ES-DE.bat` at the install root. |

## Requirements

- **Windows 11** (Windows 10 should also work)
- **PowerShell 5.1+** (ships with Windows)
- **Internet connection** for downloading emulators and cores
- **~5–10 GB free disk space** depending on which emulators are downloaded
- Running as **Administrator** is recommended (needed for 7-Zip auto-install and NTFS junctions)

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
| `-BasePath` | `C:\EmulationStation` | Root directory for the entire install. |
| `-SkipDownloads` | off | Only create the directory structure and reference files — download nothing. |
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

After running the script your install root will look like this:

```
C:\EmulationStation\
├── emulators\
│   ├── ES-DE\              # EmulationStation Desktop Edition
│   ├── RetroArch\           # RetroArch portable
│   │   ├── cores\           # ~80 libretro core DLLs
│   │   └── system\          # Linked to bios\ for firmware lookups
│   ├── dolphin\             # GameCube / Wii
│   ├── pcsx2\               # PlayStation 2
│   ├── rpcs3\               # PlayStation 3
│   ├── duckstation\         # PlayStation 1
│   ├── ppsspp\              # PSP
│   ├── cemu\                # Wii U
│   ├── xemu\                # Xbox
│   ├── xenia\               # Xbox 360
│   ├── melonds\             # Nintendo DS
│   ├── mgba\                # GBA / GB / GBC
│   ├── flycast\             # Dreamcast / NAOMI / Atomiswave
│   ├── vita3k\              # PS Vita
│   ├── mame\                # Arcade (MAME)
│   ├── dosbox-staging\      # MS-DOS
│   └── scummvm\             # ScummVM
├── roms\
│   ├── nes\                 # Each system has its own folder
│   ├── snes\                #   with a _info.txt listing
│   ├── psx\                 #   supported file extensions
│   ├── ...                  # 100+ system folders total
│   └── mame\
├── bios\                    # Firmware / BIOS files go here
│   ├── BIOS_README.txt      # Full reference with MD5 hashes
│   ├── dc\                  # Dreamcast / NAOMI subfolder
│   ├── np2kai\              # PC-9801 subfolder
│   ├── keropi\              # X68000 subfolder
│   └── fmtowns\             # FM Towns subfolder
├── saves\                   # Per-system save directories
├── states\                  # Per-system save state directories
├── config\
│   └── ES-DE_SETUP_NOTES.txt
├── .downloads\              # Cached archives (safe to delete after setup)
└── Launch_ES-DE.bat         # Quick launcher
```

## Supported Systems

The script creates ROM directories and maps emulators for the full Batocera x86_64 system set, including but not limited to:

<details>
<summary><strong>Nintendo</strong></summary>

NES, SNES, N64, GameCube, Wii, Wii U, Switch, Game Boy, Game Boy Color, Game Boy Advance, Nintendo DS, Nintendo 3DS, Famicom Disk System, Satellaview, SuFami Turbo, Super Game Boy, Virtual Boy, Pokémon Mini

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

MS-DOS, ScummVM, Amiga, Amiga CD32, Amiga 1200, C64, C128, VIC-20, PET, Plus/4, MSX, MSX2, MSX turboR, ZX Spectrum, ZX81, Apple II, Apple IIGS, TI-99/4A, SAM Coupé, Thomson MO/TO, Oric Atmos, NEC PC-8801, NEC PC-9801, Sharp X68000, Sharp X1, FM Towns, BBC Micro, Dragon 32/64, TRS-80 CoCo, TRS-80

</details>

<details>
<summary><strong>Other Consoles & Handhelds</strong></summary>

3DO, ColecoVision, Intellivision, Vectrex, Odyssey², Channel F, Watara Supervision, WonderSwan, WonderSwan Color, Uzebox, Videopac+ G7400, Philips CD-i, PICO-8, TIC-80, Game & Watch, Arduboy, Mega Duck, Gamate, Game Master

</details>

<details>
<summary><strong>Game Engines</strong></summary>

Cave Story (NXEngine), EasyRPG (RPG Maker 2000/2003), OpenBOR, Solarus, Lutro, Ports

</details>

## BIOS Files

The generated `bios/BIOS_README.txt` lists every BIOS file you may need, organised by system, with MD5 checksums for verification. **You must legally obtain these from hardware you own.** Key systems requiring BIOS files:

- **PlayStation** — `scph5501.bin` (USA), `scph5502.bin` (EU), `scph5500.bin` (JP)
- **PlayStation 2** — Any valid SCPH dump placed in `emulators\pcsx2\bios\`
- **PlayStation 3** — `PS3UPDAT.PUP` (official firmware from Sony)
- **Dreamcast** — `dc_boot.bin`, `dc_flash.bin`
- **Saturn** — `mpr-17933.bin` (USA/EU), `sega_101.bin` (JP)
- **Sega CD** — `bios_CD_U.bin`, `bios_CD_E.bin`, `bios_CD_J.bin`
- **Neo Geo** — `neogeo.zip` (place in both `bios\` and `roms\neogeo\`)

See the full guide for all systems.

## Post-Install Configuration

1. **Launch ES-DE** via `Launch_ES-DE.bat` or the ES-DE executable.
2. Set your **ROM directory** to the `roms\` folder.
3. For each system using a standalone emulator, set the emulator path in ES-DE's per-system settings (see `config\ES-DE_SETUP_NOTES.txt`).
4. Create a free [ScreenScraper](https://www.screenscraper.fr/) account, then use ES-DE's built-in scraper to download box art, screenshots, and metadata for your collection.

## Re-running the Script

The script is safe to re-run. Already-downloaded archives in `.downloads\` are detected and skipped, so subsequent runs only fetch what's missing. Existing ROM and BIOS files are never modified or deleted.

## Notes

- **7-Zip** is auto-installed if needed (some emulators ship as `.7z`).
- **GitHub API rate limits** apply (~60 unauthenticated requests/hour). If you hit limits mid-run, wait a few minutes and re-run — completed downloads are skipped.
- **Nintendo Switch emulation** (Yuzu/Suyu) is not included due to the current legal landscape. ROM directories are created but no emulator is downloaded.
- Some RetroArch cores from the nightly buildbot may fail to download — this is expected for cores not yet built for the latest nightly. RetroArch will still function with the cores that succeed.

## License

MIT — see [LICENSE](LICENSE) for details.

This script downloads open-source emulators from their official sources. No ROMs, BIOS files, or copyrighted material is included or distributed. You are responsible for ensuring you legally own any software you use with these emulators.
