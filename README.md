# Setup-EmulationStation

A single PowerShell script that bootstraps a complete [ES-DE (EmulationStation Desktop Edition)](https://es-de.org) portable install on Windows 11 with RetroArch, ~80 libretro cores, and 17 standalone emulators -- all pre-configured so games launch with the right emulator out of the box.

---

## How to Install

### Step 1 — Download the script

You don't need Git or any special tools. Just download the script directly:

1. Click this link: **[Download Setup-EmulationStation.ps1](https://raw.githubusercontent.com/dvandenburgh/Setup-EmulationStation/main/Setup-EmulationStation.ps1)**
2. Your browser may ask what to do with the file — choose **Save** (or **Save As**)
3. Save it somewhere easy to find, like your **Desktop** or **Downloads** folder

> **Tip:** If the file saves as `Setup-EmulationStation.ps1.txt`, rename it and remove the `.txt` at the end so it ends in `.ps1` only.

---

### Step 2 — Open PowerShell as Administrator

The script downloads and installs several programs, so it needs to run with administrator privileges.

1. Press the **Windows key**, type `PowerShell`
2. Right-click **Windows PowerShell** in the results
3. Click **Run as administrator**
4. Click **Yes** if Windows asks for permission

---

### Step 3 — Run the script

In the PowerShell window, paste the following two commands one at a time, pressing **Enter** after each.

**First**, allow the script to run (Windows blocks downloaded scripts by default):

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

**Then**, run the script. Replace the path below with wherever you saved the file in Step 1:

```powershell
& "$env:USERPROFILE\Downloads\Setup-EmulationStation.ps1"
```

> **Saved it somewhere else?** Just change the path. For example, if it's on your Desktop:
> ```powershell
> & "$env:USERPROFILE\Desktop\Setup-EmulationStation.ps1"
> ```

The script will now download everything automatically. This may take **20–40 minutes** depending on your internet speed. You'll see progress as it goes. Leave the window open until it finishes.

---

### Step 4 — Launch ES-DE

When the script finishes, open `C:\EmulationStation` in File Explorer and run **`ES-DE.exe`** (or double-click `Launch_ES-DE.bat`).

On first launch, click **"Generate directory structure"** to create all the ROM subfolders.

---

### Optional: Install to a different drive

By default everything goes to `C:\EmulationStation`. If you'd rather install to a different drive (recommended if your C: drive is low on space — the full install is 5–10 GB), add `-BasePath` when you run the script in Step 3:

```powershell
& "$env:USERPROFILE\Downloads\Setup-EmulationStation.ps1" -BasePath "D:\EmulationStation"
```

---

### Troubleshooting

**"Running scripts is disabled on this system"** — Make sure you ran the `Set-ExecutionPolicy` command in Step 3 first, and that PowerShell is open as Administrator.

**A download fails or times out** — The script is safe to re-run. It skips anything already downloaded and picks up where it left off. Just run the same command again.

**GitHub rate limit error** — The script makes several calls to GitHub's API. If you see a rate limit message, wait 10–15 minutes and re-run.

---

## What the Script Installs

Everything lands inside a single folder (`C:\EmulationStation` by default) — nothing is scattered around your system. Delete the folder to uninstall completely.

1. **ES-DE** — the game library frontend
2. **RetroArch** with ~80 libretro cores — handles most older systems (SNES, N64, PS1, GBA, etc.)
3. **17 standalone emulators** for systems that need them (PS2, PS3, GameCube, Switch, and more)
4. **195 ROM system folders** pre-created so ES-DE is ready to use immediately
5. A pre-built `es_settings.xml` so the right emulator launches automatically per system
6. **Controller profiles** for 8BitDo Ultimate 2C, Pro 2, and 64 (XInput) plus a **Retro-Bit Tribute64** RetroArch autoconfig (dinput) with discrete C-button mapping and optimized N64 core options
7. `BIOS_README.txt` — a reference file listing every BIOS/firmware file you'll need, with MD5 checksums
8. `CONTROLLERS.txt` — setup guide for recommended 8BitDo controllers
9. `QUICK_START.txt` and `Launch_ES-DE.bat` for convenience

---

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-BasePath` | `C:\EmulationStation` | Root directory for the entire installation |
| `-SkipDownloads` | off | Create directory structure and config files only, no downloads |
| `-RetroArchOnly` | off | Download RetroArch + cores only, skip standalone emulators |

---

## Requirements

- Windows 10 or 11
- PowerShell 5.1+ (already installed on all modern Windows machines)
- Internet connection
- ~5–10 GB free disk space
- Administrator rights recommended

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
|-- CONTROLLERS.txt              <- 8BitDo controller setup guide
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

**Per-game overrides are supported.** To use a different emulator for a specific game: highlight it, press Select → Edit This Game's Metadata → Alternative Emulator.

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

## Post-Install Checklist

1. Run `ES-DE.exe` (or `Launch_ES-DE.bat`)
2. Click **"Generate directory structure"** to create ROM folders
3. Add BIOS files where needed (see table above)
4. Drop ROM files into the matching subfolder inside `ROMs\`
5. Standalone emulators are already set as defaults — no manual configuration needed

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

## Controller Support

The script is optimized for four controllers covering XInput and authentic N64 layouts:

| Controller | Connection | Use Case |
|-----------|-----------|----------|
| **8BitDo Ultimate 2C** | 2.4G dongle or USB-C wired | General-purpose gamepad for all systems |
| **8BitDo Pro 2** | XInput mode (switch to "X") | General-purpose with back paddles |
| **8BitDo 64** | Bluetooth or USB-C wired | N64 games — native C-pad layout via XInput |
| **Retro-Bit Tribute64** | USB | N64 games — discrete C-buttons, most authentic feel |

The 8BitDo controllers work in XInput mode on Windows, appearing as standard Xbox controllers to RetroArch and every standalone emulator. The Retro-Bit Tribute64 connects as a DirectInput (dinput) HID device and uses a pre-installed RetroArch autoconfig.

### What the script configures

- **RetroArch input driver** set to `xinput` for reliable 8BitDo detection
- **N64 core options** for mupen64plus_next: C-buttons mapped to right analog stick (matches the 8BitDo 64's C-pad and any standard gamepad's right thumbstick)
- **Retro-Bit Tribute64 autoconfig** written to `Emulators\RetroArch\autoconfig\Retro-Bit Tribute64.cfg` — maps all 14 N64 inputs including discrete C-button digital inputs, no right-analog mode required
- **`CONTROLLERS.txt`** reference guide with full button mapping tables for all four controllers, including the Xbox-to-RetroPad-to-N64 translation chain

### 8BitDo 64 — N64 button mapping

The 8BitDo 64's unique N64-style layout maps naturally to the mupen64plus_next core:

| 8BitDo 64 Button | XInput | N64 Function |
|-----------------|--------|-------------|
| A (big button) | Xbox A | N64 A |
| B | Xbox B | N64 B |
| C-Up | Xbox X | C-Up (via right stick) |
| C-Down | Xbox Y | C-Down (via right stick) |
| C-Left | R Stick Left | C-Left |
| C-Right | R Stick Right | C-Right |
| Z (left trigger) | Xbox LT | N64 Z |
| L | Xbox LB | N64 L |
| R | Xbox RB | N64 R |
| Start | Xbox Start | N64 Start |

### Retro-Bit Tribute64 — N64 button mapping

The Tribute64 uses discrete digital C-buttons (not an analog stick), so it connects as a DirectInput device with a dedicated RetroArch autoconfig pre-installed at `Emulators\RetroArch\autoconfig\Retro-Bit Tribute64.cfg`:

| Tribute64 Button | Input | N64 Function |
|-----------------|-------|-------------|
| A | Button 0 | N64 A |
| B | Button 1 | N64 B |
| C-Up | Button 10 | C-Up |
| C-Down | Button 11 | C-Down |
| C-Left | Button 12 | C-Left |
| C-Right | Button 13 | C-Right |
| Z | Button 6 | N64 Z |
| L | Button 4 | N64 L |
| R | Button 5 | N64 R |
| Start | Button 9 | N64 Start |

No right-analog-stick core option needed — C-buttons are recognized as discrete digital inputs by mupen64plus_next and ParaLLEl-N64 automatically.

See `CONTROLLERS.txt` in the install directory for the complete guide.

---

## Technical Notes

- **ES-DE source**: Hosted on GitLab (not GitHub). The script queries the GitLab releases API with a hardcoded fallback URL for v3.4.0.
- **7-Zip**: Auto-installed if not present (required for `.7z` archives from Dolphin, PCSX2, RPCS3, mGBA).
- **VC++ Redistributable**: Auto-installed silently (required by Dolphin, PCSX2, and others).
- **GitHub API rate limits**: ~60 unauthenticated requests/hour. If you hit limits mid-run, wait a few minutes and re-run.
- **RetroArch cores**: Some nightly cores may fail to download -- this is normal for cores not yet built for the latest nightly.
- **Large downloads**: MAME and RPCS3 use a .NET WebClient fallback if `Invoke-WebRequest` times out.
- **Pinned versions**: Dolphin (v2412), ScummVM (v2.9.1), and MAME (v0.286) use pinned direct URLs. Update these when new versions release.

---

## License

MIT -- see [LICENSE](LICENSE) for details.

No ROMs, BIOS files, or copyrighted material is included or distributed. You are responsible for legally owning any software you use with these emulators.
