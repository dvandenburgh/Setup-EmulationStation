# Setup-EmulationStation (Linux)

A single bash script that bootstraps a complete [ES-DE (EmulationStation Desktop Edition)](https://es-de.org) install on Ubuntu, Kubuntu, and other modern Debian-derivatives. Mirrors the Windows version: ES-DE portable AppImage, RetroArch with ~80 libretro cores, and 14 standalone emulators -- all pre-configured so games launch with the right emulator out of the box.

> **Looking for the Windows version?** See [README.md](README.md). The two scripts are kept in functional parity but use platform-native conventions (Flatpak on Linux, portable binaries on Windows).

---

## How to Install

### Step 1 — Download the script

```bash
curl -O https://raw.githubusercontent.com/dvandenburgh/Setup-EmulationStation/linux-port/setup-emulationstation.sh
chmod +x setup-emulationstation.sh
```

### Step 2 — Run it

```bash
./setup-emulationstation.sh
```

Do **not** run it as root. The script uses `flatpak --user` installs and `$HOME` paths, both of which require your normal user. It will use `sudo` only for the initial `apt-get install` of prerequisites (curl, flatpak, python3, unzip, libfuse).

The script takes **20–40 minutes** depending on your internet speed and how much of Flathub you already have cached. Leave the terminal open until it finishes; it's safe to re-run if anything hiccups (every step is idempotent).

### Step 3 — Launch ES-DE

```bash
~/EmulationStation/Launch_ES-DE.sh
```

On first launch ES-DE detects the sibling `ES-DE/` folder and runs in portable mode; all settings stay inside the install tree.

---

## Parameters

| Flag                | Default                 | Description                                              |
| ------------------- | ----------------------- | -------------------------------------------------------- |
| `--base-path PATH`  | `$HOME/EmulationStation`| Root directory for the install                           |
| `--skip-downloads`  | off                     | Create directory structure and config files only         |
| `--retroarch-only`  | off                     | Skip the 14 standalone emulator Flatpaks                 |
| `--no-flatpak-emus` | off                     | Same as `--retroarch-only` but kept for clarity          |
| `-h`, `--help`      | --                      | Print usage and exit                                     |

Example:

```bash
./setup-emulationstation.sh --base-path ~/Games/Emulation
```

---

## Requirements

- Ubuntu 22.04+, Kubuntu 24.04+, Debian 12+, or any reasonably modern Debian-derivative
- Sudo rights (for the one-time prerequisite install)
- ~5–10 GB free disk space
- Internet connection

The script auto-installs anything missing from this list: `curl`, `flatpak`, `python3`, `unzip`, `libfuse2`/`libfuse2t64`. It also adds the Flathub remote (user scope) if not already configured.

---

## What the Script Installs

Most things live in two places: the install root (`~/EmulationStation` by default) and the per-flatpak data directories under `~/.var/app/`. Delete the install root and `flatpak uninstall` the listed app IDs to remove everything.

1. **ES-DE** AppImage placed in the install root, portable-mode config beside it
2. **RetroArch** as the `org.libretro.RetroArch` Flatpak, plus ~80 libretro cores
3. **14 standalone emulators** as Flatpaks from Flathub
4. **All 195 ROM system folders** pre-created with ES-DE's expected names (`gc`, not `gamecube`, etc.)
5. **`ES-DE/settings/es_settings.xml`** with `AlternativeEmulator_*` defaults so standalone emulators launch where it matters (PS2, PS3, GC/Wii, Switch, etc.)
6. **`Retro-Bit Tribute64.cfg`** RetroArch autoconfig with discrete C-button mappings (udev driver)
7. **Mupen64Plus-Next core options** preset to "Right Analog" C-buttons (works for 8BitDo 64, any modern gamepad with a right stick)
8. **`BIOS_README.txt`**, **`CONTROLLERS.txt`**, **`QUICK_START.txt`** with Linux-specific paths
9. **Stub directories** for the three emulators not on Flathub, each with a README pointing to upstream

---

## Directory Layout

```
~/EmulationStation/
├── ES-DE-x86_64.AppImage     <- Launch this
├── ES-DE/                    <- Portable config (settings, themes, media)
│   └── settings/
│       └── es_settings.xml   <- Pre-configured standalone emulator defaults
├── ROMs/                     <- 195 system folders pre-created
│   ├── gc/, snes/, psx/, ps2/, ps3/, switch/ ...
├── Emulators/                <- Stubs for off-Flathub emulators only
│   ├── Ryujinx/README.txt
│   ├── shadps4/README.txt
│   └── xenia/README.txt
├── BIOS_README.txt
├── CONTROLLERS.txt
├── QUICK_START.txt
├── Launch_ES-DE.sh
└── .downloads/               <- Cached archives (safe to delete)
```

**Flatpak emulators live elsewhere**, under `~/.var/app/<app-id>/`. ES-DE's bundled `es_find_rules.xml` already knows how to invoke them — no PATH or symlink configuration needed.

---

## Emulator Configuration

The script writes `ES-DE/settings/es_settings.xml` with `AlternativeEmulator_<system>` entries so standalone emulators are picked over RetroArch cores where it matters. Labels match `es_systems.xml` exactly:

| ES-DE System | Default Emulator Label          | Flatpak ID                       |
| ------------ | ------------------------------- | -------------------------------- |
| ps2          | PCSX2 (Standalone)              | `net.pcsx2.PCSX2`                |
| ps3          | RPCS3 Directory (Standalone)    | `net.rpcs3.RPCS3`                |
| psx          | DuckStation (Standalone)        | `org.duckstation.DuckStation`    |
| psp          | PPSSPP (Standalone)             | `org.ppsspp.PPSSPP`              |
| gc / wii     | Dolphin (Standalone)            | `org.DolphinEmu.dolphin-emu`     |
| wiiu         | Cemu (Standalone)               | `info.cemu.Cemu`                 |
| nds          | melonDS (Standalone)            | `net.kuribo64.melonDS`           |
| dreamcast    | Flycast (Standalone)            | `org.flycast.Flycast`            |
| xbox         | xemu (Standalone)               | `app.xemu.xemu`                  |
| psvita       | Vita3K (Standalone)             | `net.vita3k.Vita3K`              |

**Per-game overrides are enabled.** Highlight a game → Select → Edit This Game's Metadata → Alternative Emulator to override on a per-title basis.

---

## Standalone Emulators (Flathub)

All 14 are installed user-scope from Flathub, so they update through Discover/`flatpak update --user` like any other Flatpak.

| Emulator       | System(s)                       | Flatpak ID                       |
| -------------- | ------------------------------- | -------------------------------- |
| Dolphin        | GameCube, Wii                   | `org.DolphinEmu.dolphin-emu`     |
| PCSX2          | PlayStation 2                   | `net.pcsx2.PCSX2`                |
| RPCS3          | PlayStation 3                   | `net.rpcs3.RPCS3`                |
| DuckStation    | PlayStation 1                   | `org.duckstation.DuckStation`    |
| PPSSPP         | PSP                             | `org.ppsspp.PPSSPP`              |
| Cemu           | Wii U                           | `info.cemu.Cemu`                 |
| xemu           | Xbox                            | `app.xemu.xemu`                  |
| melonDS        | Nintendo DS                     | `net.kuribo64.melonDS`           |
| mGBA           | GBA, GB, GBC                    | `io.mgba.mGBA`                   |
| Flycast        | Dreamcast, NAOMI, Atomiswave    | `org.flycast.Flycast`            |
| Vita3K         | PS Vita                         | `net.vita3k.Vita3K`              |
| MAME           | Arcade                          | `org.mamedev.MAME`               |
| DOSBox Staging | MS-DOS                          | `io.github.dosbox-staging`       |
| ScummVM        | Adventure games                 | `org.scummvm.ScummVM`            |

### Not on Flathub

These three need a manual download. The script creates stub directories with a `README.txt` pointing at the right upstream release:

- **Ryujinx (Ryubing fork)** — Linux binary from [github.com/Ryubing/Ryujinx](https://github.com/Ryubing/Ryujinx/releases). Extract to `~/EmulationStation/Emulators/Ryujinx/`. `prod.keys` goes in `~/.config/Ryujinx/system/`; install firmware via Ryujinx → Tools → Install Firmware.
- **shadPS4** — AppImage from [github.com/shadps4-emu/shadPS4](https://github.com/shadps4-emu/shadPS4/releases). Save as `~/EmulationStation/Emulators/shadps4/shadPS4.AppImage` and `chmod +x`.
- **Xenia** — Windows-only Xbox 360 emulator. No native Linux build exists. Run it through Wine/Bottles/Lutris if you need Xbox 360 emulation.

---

## BIOS Files

The generated `BIOS_README.txt` lists every required and optional firmware file with MD5 checksums and Linux-specific paths. You must legally obtain these from hardware you own.

| System                | Location                                                                  |
| --------------------- | ------------------------------------------------------------------------- |
| Most RetroArch cores  | `~/.var/app/org.libretro.RetroArch/config/retroarch/system/`              |
| Dreamcast / NAOMI     | `~/.var/app/org.libretro.RetroArch/config/retroarch/system/dc/`           |
| PlayStation 2 (PCSX2) | `~/.var/app/net.pcsx2.PCSX2/config/PCSX2/bios/`                           |
| PlayStation 3 (RPCS3) | Install via RPCS3 → File → Install Firmware                              |
| PlayStation 4         | shadPS4's data folder (see `BIOS_README.txt`)                            |
| Nintendo Switch       | `prod.keys` → `~/.config/Ryujinx/system/`; firmware via Ryujinx GUI       |
| Xbox (xemu)           | `~/.var/app/app.xemu.xemu/data/xemu/xemu/`                                |
| Neo Geo               | RetroArch system folder **and** `ROMs/neogeo/`                            |

Key files:

- **PS1** — `scph5501.bin` (USA), `scph5502.bin` (EU), `scph5500.bin` (JP)
- **PS2** — any valid SCPH dump (e.g. `SCPH-70012.bin`)
- **PS3** — `PS3UPDAT.PUP` from Sony's official site
- **Dreamcast** — `dc_boot.bin`, `dc_flash.bin`
- **Saturn** — `mpr-17933.bin` (USA/EU), `sega_101.bin` (JP)
- **Switch** — `prod.keys` from your own Switch

`BIOS_README.txt` has the complete list with MD5 checksums.

---

## Post-Install Checklist

1. Run `./Launch_ES-DE.sh`
2. ROM folders are already created — drop legally-owned ROMs into `ROMs/<system>/`
3. Add BIOS files where needed (see table above)
4. Standalone emulators are pre-set as defaults — no manual configuration needed
5. For Ryujinx, shadPS4, and Xenia, follow the instructions in their `Emulators/<name>/README.txt`
6. Optionally scrape artwork at [screenscraper.fr](https://www.screenscraper.fr/) (Main Menu → Scraper)

### System-specific notes

**PS3 (RPCS3):** Games must be in extracted directory format with an `EBOOT.BIN`. Place game directories (e.g. `BLUS12345`) in `ROMs/ps3/` with a `.ps3` extension on the directory name, or install `.pkg` files via RPCS3 → File → Install Packages. Firmware must be installed first.

**Nintendo Switch (Ryujinx):** Place `prod.keys` in `~/.config/Ryujinx/system/`. Install firmware via Ryujinx → Tools → Install Firmware. ROMs go in `ROMs/switch/`.

**Steam:** ES-DE can launch Steam games via the `steam` system. Add a `.url` shortcut per game (see ES-DE user guide for the format) or use the auto-import feature.

---

## Controller Support

Optimized for the same four controllers as the Windows version:

| Controller            | Connection                | Use Case                                                |
| --------------------- | ------------------------- | ------------------------------------------------------- |
| 8BitDo Ultimate 2C    | 2.4G dongle or USB-C      | General-purpose gamepad                                 |
| 8BitDo Pro 2          | XInput mode ("X" switch)  | General-purpose with back paddles                       |
| 8BitDo 64             | Bluetooth or USB-C        | N64 games — native C-pad layout via the right stick     |
| Retro-Bit Tribute64   | USB                       | N64 games — discrete digital C-buttons (most authentic) |

On Linux all four are handled by the kernel's HID/udev stack with no driver install needed. For the cleanest Bluetooth experience with 8BitDo controllers, install [xpadneo](https://atar-axis.github.io/xpadneo/) (`sudo apt install xpadneo-dkms` if your distro packages it).

### What the script configures

- **RetroArch joypad driver** set to `udev` (the Linux default; the script normalizes it just in case it was changed)
- **Mupen64Plus-Next core options** with C-buttons mapped to right analog stick — works for the 8BitDo 64 and any modern gamepad
- **Retro-Bit Tribute64 autoconfig** at `~/.var/app/org.libretro.RetroArch/config/retroarch/autoconfig/Retro-Bit Tribute64.cfg` — maps all 14 N64 inputs including discrete C-button digital inputs
- **`CONTROLLERS.txt`** with full button mapping tables and Linux-specific tips (input group membership, `jstest` for testing, xpadneo for Bluetooth)

---

## Technical Notes

- **ES-DE source**: GitLab. The script queries the GitLab releases API and downloads the Linux x86_64 AppImage. If the API call fails, it prints clear instructions for grabbing the AppImage manually from [es-de.org](https://es-de.org) and re-running.
- **Cores**: Pulled from `buildbot.libretro.com/nightly/linux/x86_64/latest`. Some nightlies may be missing for less-popular cores; the script reports counts at the end.
- **Flatpak scope**: Everything installed `--user`. No root flatpak installs means no system-wide cruft, and `flatpak update --user` keeps everything current.
- **Headless RetroArch init**: The script runs `flatpak run org.libretro.RetroArch --menu` briefly so RetroArch creates its config tree before cores and autoconfigs are dropped in.
- **Validation**: The script passes `bash -n` and `shellcheck -S warning` cleanly.

---

## Differences from the Windows Version

| Concern                    | Windows                              | Linux                                            |
| -------------------------- | ------------------------------------ | ------------------------------------------------ |
| ES-DE distribution         | Portable ZIP                         | AppImage (portable via sibling `ES-DE/` dir)     |
| RetroArch                  | Portable build in `Emulators/`       | `org.libretro.RetroArch` Flatpak                 |
| Standalone emulators       | 17 downloaded portables              | 14 Flathub Flatpaks + 3 manual stubs             |
| 7-Zip                      | Auto-installed (for `.7z` archives)  | Not needed (Flatpaks supply binaries)            |
| VC++ Redistributable       | Auto-installed                       | N/A                                              |
| Tribute64 autoconfig       | `input_driver = "dinput"`            | `input_driver = "udev"`                          |
| Config root for RetroArch  | `Emulators\RetroArch\`               | `~/.var/app/org.libretro.RetroArch/`             |

The CLI flags and behaviour are otherwise identical.

---

## License

MIT — see [LICENSE](LICENSE) for details.

No ROMs, BIOS files, or copyrighted material is included or distributed. You are responsible for legally owning any software you use with these emulators.
