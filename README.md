# Setup-EmulationStation

A single PowerShell script that bootstraps a complete [ES-DE (EmulationStation Desktop Edition)](https://es-de.org) portable install on Windows 11 with RetroArch, ~80 libretro cores, and 17 standalone emulators -- all pre-configured so games launch with the right emulator out of the box.

## Quick Start

```powershell
git clone https://github.com/dvandenburgh/Setup-EmulationStation.git
cd Setup-EmulationStation
.\Setup-EmulationStation.ps1
```

If PowerShell blocks the script:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Setup-EmulationStation.ps1
```

Default install path is `C:\EmulationStation`. Change it with `-BasePath`:

```powershell
.\Setup-EmulationStation.ps1 -BasePath "D:\EmulationStation"
```

---

## What the Script Does

1. Downloads ES-DE portable from GitLab and extracts it to the install root
2. Installs the Visual C++ x64 Redistributable (required by several emulators)
3. Downloads RetroArch 1.20.0 portable + ~80 libretro cores from the nightly buildbot
4. Downloads 17 standalone emulators into `Emulators\` where ES-DE auto-discovers them
5. Pre-creates `ES-DE/es_settings.xml` with correct standalone emulator defaults for 14 systems
6. Creates an empty `ROMs\` directory (ES-DE generates system subfolders on first launch)
7. Generates `BIOS_README.txt` with every required firmware file and MD5 checksums
8. Generates `QUICK_START.txt` and `Launch_ES-DE.bat`

The script is **idempotent** -- safe to re-run. Already-downloaded archives and installed emulators are detected and skipped. Existing ROM and BIOS files are never touched.

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BasePath` | `C:\EmulationStation` | Root directory for the entire installation |
| `-SkipDownloads` | off | Create directory structure and reference files only |
| `-RetroArchOnly` | off | Download RetroArch + cores, skip standalone emulators |

## Requirements

- Windows 10 or 11
- PowerShell 5.1+ (ships with Windows)
- Internet connection
- ~5-10 GB free disk space
- Administrator recommended (for 7-Zip and VC++ Redist auto-install)

---

## Directory Layout

```
C:\EmulationStation\
|-- ES-DE.exe                    <- Launch this
|-- ES-DE\
|   \-- es_settings.xml          <- Pre-configured emulator defaults
|-- ROMs\                        <- ES-DE generates system folders on first launch
|   |-- gc\, snes\, psx\, ps2\, ps3\, switch\, ...
|-- Emulators\
|   |-- RetroArch\
|   |   |-- retroarch.exe
|   |   |-- cores\               <- ~80 libretro core DLLs
|   |   \-- system\              <- BIOS / firmware files
|   |       |-- dc\, np2kai\, keropi\, fmtowns\
|   |-- Dolphin-x64\             <- GameCube / Wii
|   |-- PCSX2-Qt\                <- PlayStation 2
|   |   \-- bios\                <- PS2 BIOS files go here
|   |-- RPCS3\                   <- PlayStation 3
|   |-- duckstation\             <- PlayStation 1
|   |-- PPSSPP\                  <- PSP
|   |-- cemu\                    <- Wii U
|   |-- ryujinx\                 <- Nintendo Switch
|   |   \-- portable\            <- Config, saves, keys stay local
|   |-- shadPS4\                 <- PlayStation 4
|   |-- xemu\                    <- Xbox
|   |-- xenia_canary\            <- Xbox 360
|   |-- melonDS\                 <- Nintendo DS
|   |-- mGBA\                    <- GBA / GB / GBC
|   |-- flycast\                 <- Dreamcast / NAOMI / Atomiswave
|   |-- Vita3K\                  <- PS Vita
|   |-- mame\                    <- Arcade
|   |-- dosbox-staging\          <- MS-DOS
|   \-- scummvm\                 <- Adventure games
|-- BIOS_README.txt
|-- QUICK_START.txt
|-- Launch_ES-DE.bat
\-- .downloads\                  <- Cached archives (safe to delete)
```

ES-DE uses its own system folder names (e.g. `gc` not `gamecube`, `n3ds` not `3ds`). Click **"Generate directory structure"** on first launch to create all 150+ system folders with the correct names.

---

## Emulator Configuration

The script pre-creates `ES-DE/es_settings.xml` with the correct `AlternativeEmulator` settings so standalone emulators are used instead of RetroArch cores for systems where it matters. These labels must exactly match the command labels in ES-DE's bundled `es_systems.xml`:

| ES-DE System | Default Emulator Label | Folder |
|-------------|----------------------|--------|
| ps2 | PCSX2 (Standalone) | PCSX2-Qt |
| ps3 | RPCS3 Directory (Standalone) | RPCS3 |
| ps4 | shadPS4 eboot.bin (Standalone) | shadPS4 |
| psx | DuckStation (Standalone) | duckstation |
| psp | PPSSPP (Standalone) | PPSSPP |
| gc | Dolphin (Standalone) | Dolphin-x64 |
| wii | Dolphin (Standalone) | Dolphin-x64 |
| wiiu | Cemu (Standalone) | cemu |
| switch | Ryujinx (Standalone) | ryujinx |
| nds | melonDS (Standalone) | melonDS |
| dreamcast | Flycast (Standalone) | flycast |
| xbox | xemu (Standalone) | xemu |
| xbox360 | xenia (Standalone) | xenia_canary |
| psvita | Vita3K (Standalone) | Vita3K |

All other systems default to RetroArch with the appropriate libretro core.

**Per-game overrides are enabled.** To use a different emulator for a specific game: highlight the game, press Select, choose Edit This Game's Metadata, then Alternative Emulator.

---

## Standalone Emulators

All 17 are downloaded from official sources. ES-DE discovers them automatically via `es_find_rules.xml` in the `Emulators\` directory.

| Emulator | System(s) | Source | Exe |
|----------|-----------|--------|-----|
| Dolphin | GameCube, Wii | dl.dolphin-emu.org | Dolphin.exe |
| PCSX2 | PlayStation 2 | PCSX2/pcsx2 | pcsx2-qt.exe |
| RPCS3 | PlayStation 3 | RPCS3/rpcs3-binaries-win | rpcs3.exe |
| DuckStation | PlayStation 1 | stenzek/duckstation | duckstation-qt-x64-ReleaseLTCG.exe |
| PPSSPP | PSP | hrydgard/ppsspp | PPSSPPWindows64.exe |
| Cemu | Wii U | cemu-project/Cemu | Cemu.exe |
| Ryujinx (Ryubing) | Nintendo Switch | Kenji-NX/Releases | Ryujinx.exe |
| shadPS4 | PlayStation 4 | shadps4-emu/shadPS4 | shadPS4.exe |
| Xemu | Xbox | xemu-project/xemu | xemu.exe |
| Xenia Canary | Xbox 360 | xenia-canary/xenia-canary-releases | xenia_canary.exe |
| melonDS | Nintendo DS | melonDS-emu/melonDS | melonDS.exe |
| mGBA | GBA, GB, GBC | mgba-emu/mgba | mGBA.exe |
| Flycast | Dreamcast, NAOMI, Atomiswave | flyinghead/flycast | flycast.exe |
| Vita3K | PS Vita | Vita3K/Vita3K | Vita3K.exe |
| MAME | Arcade | mamedev/mame | mame.exe |
| DOSBox Staging | MS-DOS | dosbox-staging/dosbox-staging | dosbox.exe |
| ScummVM | Adventure games | scummvm.org | scummvm.exe |

### Portable mode

Where supported, emulators are configured for portable operation so all config stays within the install tree:

- **PCSX2**: `portable.ini` created in install directory
- **Ryujinx**: `portable\` folder created so config, saves, and keys stay local
- **RetroArch**: Downloaded as portable build; config stays in `Emulators\RetroArch\`

---

## BIOS Files

The generated `BIOS_README.txt` lists every required and optional firmware file with MD5 checksums. You must legally obtain these from hardware you own.

### Where BIOS files go

| System | Location |
|--------|----------|
| Most RetroArch systems | `Emulators\RetroArch\system\` |
| Dreamcast / NAOMI | `Emulators\RetroArch\system\dc\` |
| PlayStation 2 | `Emulators\PCSX2-Qt\bios\` |
| PlayStation 3 | Install via RPCS3 > File > Install Firmware |
| PlayStation 4 | `Emulators\shadPS4\user\sys_modules\` |
| Nintendo Switch | Keys in Ryujinx portable folder; firmware via Ryujinx > Tools > Install Firmware |
| Neo Geo | `Emulators\RetroArch\system\` AND `ROMs\neogeo\` |

### Key files

- **PlayStation 1**: `scph5501.bin` (USA), `scph5502.bin` (EU), `scph5500.bin` (JP)
- **PlayStation 2**: Any valid SCPH dump (e.g. `SCPH-70012.bin`)
- **PlayStation 3**: `PS3UPDAT.PUP` from Sony's official site
- **PlayStation 4**: Firmware modules dumped from your PS4 console
- **Dreamcast**: `dc_boot.bin`, `dc_flash.bin`
- **Saturn**: `mpr-17933.bin` (USA/EU), `sega_101.bin` (JP)
- **Nintendo Switch**: `prod.keys` dumped from your Switch

See `BIOS_README.txt` for the complete list with MD5 checksums.

---

## Post-Install

1. Run `ES-DE.exe` (or `Launch_ES-DE.bat`)
2. Click **"Generate directory structure"** to create ROM folders
3. Add BIOS files where needed (see table above)
4. Add ROM files to the matching `ROMs\` subfolders
5. Standalone emulators are already configured as defaults -- no manual selection needed

### System-specific notes

**PS3 (RPCS3):** Games must be in extracted directory format with an `EBOOT.BIN`. Place game directories (e.g. `BLUS12345`) in `ROMs\ps3\` with a `.ps3` extension on the directory name, or install `.pkg` files via RPCS3 > File > Install Packages. Firmware must be installed first.

**PS4 (shadPS4):** Games must be dumped as installed pkg folders (CUSAXXXXX format). Install via shadPS4's GUI or place game directories in `ROMs\ps4\`. PS4 firmware modules must be in `Emulators\shadPS4\user\sys_modules\`.

**Nintendo Switch (Ryujinx):** Place `prod.keys` in the Ryujinx portable folder's `system\` directory. Install firmware via Ryujinx > Tools > Install Firmware. ROM files go in `ROMs\switch\`.

---

## Supported Systems

ES-DE supports 150+ game systems. Key systems by manufacturer:

**Nintendo** -- NES, SNES, N64, GameCube, Wii, Wii U, Switch, Game Boy, GBC, GBA, DS, 3DS, FDS, Virtual Boy, Pokemon Mini

**Sony** -- PlayStation, PS2, PS3, PS4, PSP, PS Vita

**Sega** -- Master System, Genesis/Mega Drive, 32X, Sega CD, Saturn, Dreamcast, Game Gear, SG-1000, NAOMI, Atomiswave

**Microsoft** -- Xbox, Xbox 360

**Atari** -- 2600, 5200, 7800, Jaguar, Lynx, ST/STE/TT/Falcon, 800/XL/XE

**NEC** -- PC Engine/TurboGrafx-16, PC Engine CD, PC-FX, SuperGrafx

**SNK** -- Neo Geo MVS/AES, Neo Geo CD, Neo Geo Pocket/Color

**Arcade** -- MAME, FinalBurn Neo, CPS1/2/3, Daphne

**Computers** -- MS-DOS, ScummVM, Amiga, C64, MSX, ZX Spectrum, PC-9801, X68000, FM Towns, and many more

**Other** -- 3DO, ColecoVision, Intellivision, Vectrex, WonderSwan, Odyssey 2, Channel F, Arduboy, PICO-8, TIC-80

---

## Technical Notes

- **ES-DE source**: Hosted on GitLab (not GitHub). The script queries the GitLab releases API with a hardcoded fallback URL for v3.4.0.
- **7-Zip**: Auto-installed if not present (required for `.7z` archives from Dolphin, PCSX2, RPCS3, mGBA).
- **VC++ Redistributable**: Auto-installed silently (required by Dolphin, PCSX2, and others).
- **GitHub API rate limits**: ~60 unauthenticated requests/hour. If you hit limits mid-run, wait a few minutes and re-run.
- **RetroArch cores**: Some nightly cores may fail to download -- this is normal for cores not yet built for the latest nightly.
- **Large downloads**: MAME and RPCS3 use a .NET WebClient fallback if `Invoke-WebRequest` times out.
- **Pinned versions**: Dolphin (v2412), ScummVM (v2.9.1), and MAME (v0.286) use pinned direct URLs. Update these when new versions release.

## License

MIT -- see [LICENSE](LICENSE) for details.

No ROMs, BIOS files, or copyrighted material is included or distributed. You are responsible for legally owning any software you use with these emulators.
