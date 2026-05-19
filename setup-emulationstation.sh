#!/usr/bin/env bash
#
# setup-emulationstation.sh
#
# Comprehensive ES-DE (EmulationStation Desktop Edition) setup for Ubuntu /
# Kubuntu / any modern Debian-derivative. Mirrors the Windows Setup-EmulationStation
# script as closely as Linux distribution conventions allow.
#
# This script will:
#   1. Install prerequisites (curl, flatpak, fuse for AppImages)
#   2. Add Flathub if missing
#   3. Download the ES-DE Linux AppImage from GitLab
#   4. Install RetroArch as a Flatpak (org.libretro.RetroArch)
#   5. Bulk-download libretro cores from the official buildbot
#   6. Install 14+ standalone emulators as Flatpaks
#   7. Pre-create the ES-DE ROM directory tree (all 195 systems)
#   8. Write a pre-configured es_settings.xml selecting Standalone emulators
#      where appropriate (PS2, PS3, GC, Wii, etc.)
#   9. Write the Retro-Bit Tribute64 RetroArch autoconfig
#  10. Write BIOS_README.txt, CONTROLLERS.txt, and QUICK_START.txt with
#      Linux-specific paths
#
# Default install root: $HOME/EmulationStation (override with --base-path)
# Tested target:        Ubuntu 24.04 / 25.04 / Kubuntu 26.04
#
# Author  : David (Linux port assisted by Claude / Anthropic)
# Version : 1.0.0-linux
# License : MIT -- use at your own risk
#
# Usage:
#   chmod +x setup-emulationstation.sh
#   ./setup-emulationstation.sh                       # default install
#   ./setup-emulationstation.sh --base-path ~/Games   # custom location
#   ./setup-emulationstation.sh --skip-downloads      # dirs + configs only
#   ./setup-emulationstation.sh --retroarch-only      # skip standalone emus
#   ./setup-emulationstation.sh --no-flatpak-emus     # ES-DE + RetroArch only
#
set -Eeuo pipefail
IFS=$'\n\t'

# ==============================================================================
#  PARAMETERS
# ==============================================================================

BASE_PATH="${HOME}/EmulationStation"
SKIP_DOWNLOADS=0
RETROARCH_ONLY=0
SKIP_FLATPAK_EMUS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base-path)        BASE_PATH="$2";       shift 2 ;;
        --skip-downloads)   SKIP_DOWNLOADS=1;     shift   ;;
        --retroarch-only)   RETROARCH_ONLY=1;     shift   ;;
        --no-flatpak-emus)  SKIP_FLATPAK_EMUS=1;  shift   ;;
        -h|--help)
            awk 'NR>1 && /^#/{print; next} NR>1{exit}' "$0"
            exit 0 ;;
        *)
            echo "Unknown argument: $1" >&2
            exit 2 ;;
    esac
done

# Expand ~ if present in --base-path
BASE_PATH="${BASE_PATH/#\~/$HOME}"

ROMS_DIR="${BASE_PATH}/ROMs"
EMU_DIR="${BASE_PATH}/Emulators"
DL_DIR="${BASE_PATH}/.downloads"
ESDE_CFG_DIR="${BASE_PATH}/ES-DE"               # portable-mode config dir
RA_FLATPAK_CFG="${HOME}/.var/app/org.libretro.RetroArch/config/retroarch"
RA_CORES_DIR="${RA_FLATPAK_CFG}/cores"
RA_SYSTEM_DIR="${RA_FLATPAK_CFG}/system"
RA_AUTOCFG_DIR="${RA_FLATPAK_CFG}/autoconfig"

# ==============================================================================
#  OUTPUT HELPERS
# ==============================================================================

if [[ -t 1 ]]; then
    C_CYAN=$'\e[36m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
    C_RED=$'\e[31m';  C_GRAY=$'\e[90m';  C_MAGENTA=$'\e[35m'; C_RESET=$'\e[0m'
else
    C_CYAN=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_GRAY=""; C_MAGENTA=""; C_RESET=""
fi

step()  { printf '\n%s>> %s%s\n'    "$C_CYAN"    "$*" "$C_RESET"; }
ok()    { printf '  %s[OK]%s %s\n'   "$C_GREEN"   "$C_RESET" "$*"; }
skip()  { printf '  %s[SKIP]%s %s\n' "$C_YELLOW"  "$C_RESET" "$*"; }
err()   { printf '  %s[FAIL]%s %s\n' "$C_RED"     "$C_RESET" "$*" >&2; }
info()  { printf '  %s[INFO]%s %s\n' "$C_GRAY"    "$C_RESET" "$*"; }
warn()  { printf '  %s[WARN]%s %s\n' "$C_YELLOW"  "$C_RESET" "$*"; }

trap 'err "Script failed on line $LINENO (exit $?)"; exit 1' ERR

ensure_dir() { mkdir -p "$1"; }

# Download to $2; skip if already present.
download_file() {
    local url="$1" dest="$2" desc="${3:-file}"
    if [[ -z "$url" ]]; then err "No URL for $desc"; return 1; fi
    if [[ -s "$dest" ]]; then skip "$desc already downloaded"; return 0; fi
    info "Downloading $desc..."
    if curl --fail --location --silent --show-error \
            --retry 3 --retry-delay 2 --connect-timeout 30 \
            --user-agent "EmulationStation-Setup/1.0" \
            --output "$dest" "$url"; then
        ok "Downloaded $desc"
        return 0
    fi
    err "Failed to download $desc"
    return 1
}

# Fetch latest release JSON for a GitHub repo, e.g. RPCS3/rpcs3-binaries-linux
gh_latest_release() {
    local repo="$1"
    curl --fail --silent --location \
         --header "User-Agent: EmulationStation-Setup/1.0" \
         "https://api.github.com/repos/${repo}/releases/latest" 2>/dev/null \
    || curl --fail --silent --location \
            --header "User-Agent: EmulationStation-Setup/1.0" \
            "https://api.github.com/repos/${repo}/releases" 2>/dev/null \
        | head -c 1000000 \
        | python3 -c 'import json,sys; print(json.dumps(json.load(sys.stdin)[0]))' 2>/dev/null
}

# Find an asset download URL from a release JSON blob matching a regex on .name
gh_asset_url() {
    local release_json="$1" pattern="$2"
    [[ -z "$release_json" ]] && return 1
    printf '%s' "$release_json" | env PAT="$pattern" python3 -c '
import json, os, re, sys
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(1)
pat = re.compile(os.environ["PAT"])
for asset in data.get("assets", []):
    if pat.search(asset.get("name", "")):
        print(asset.get("browser_download_url", ""))
        break
'
}

# Pick the first link from a GitLab release whose name matches a regex.
# Outputs the direct_asset_url (or url) for downloading.
gitlab_release_link() {
    local project_path="$1" pattern="$2"
    curl --fail --silent --location \
         "https://gitlab.com/api/v4/projects/${project_path}/releases" 2>/dev/null \
        | env PAT="$pattern" python3 -c '
import json, os, re, sys
try:
    releases = json.load(sys.stdin)
except Exception:
    sys.exit(1)
if not releases:
    sys.exit(1)
pat = re.compile(os.environ["PAT"])
for rel in releases:
    for link in rel.get("assets", {}).get("links", []):
        if pat.search(link.get("name", "")):
            print(link.get("direct_asset_url") or link.get("url", ""))
            sys.exit(0)
sys.exit(1)
'
}

# Install a flatpak app if not already present. Returns 0 on success/skip.
flatpak_install() {
    local app_id="$1" desc="${2:-$1}"
    if flatpak --user info "$app_id" >/dev/null 2>&1; then
        skip "$desc already installed (flatpak)"
        return 0
    fi
    info "Installing $desc as flatpak ($app_id)..."
    if flatpak --user install -y --noninteractive flathub "$app_id" >/dev/null 2>&1; then
        ok "Installed $desc"
        return 0
    fi
    warn "Could not install $desc from Flathub (app id may be wrong or unavailable)"
    return 1
}

# ==============================================================================
#  ROM SYSTEM DIRECTORIES (from ES-DE v3.4 es_systems.xml)
# ==============================================================================

ROM_SYSTEMS=(
    3do adam ags amiga amiga1200 amiga600 amigacd32 amstradcpc
    android androidapps androidgames apple2 apple2gs arcade arcadia
    archimedes arduboy astrocde atari2600 atari5200 atari7800 atari800
    atarijaguar atarijaguarcd atarilynx atarist atarixe atomiswave
    bbcmicro c64 cdimono1 cdtv chailove channelf coco colecovision
    consolearcade cps cps1 cps2 cps3 crvision daphne desktop doom
    dos dragon32 dreamcast easyrpg electron emulators epic famicom
    fba fbneo fds flash fm7 fmtowns fpinball gamate gameandwatch
    gamecom gamegear gb gba gbc gc genesis gmaster gx4000
    intellivision j2me kodi laserdisc lcdgames lowresnx lutris lutro
    macintosh mame mame-advmame mark3 mastersystem megacd megacdjp
    megadrive megadrivejp megaduck mess model2 model3 moto msx msx1
    msx2 msxturbor mugen multivision n3ds n64 n64dd naomi naomi2
    naomigd nds neogeo neogeocd neogeocdjp nes ngage ngp ngpc
    odyssey2 openbor oric palm pc pc88 pc98 pcarcade pcengine
    pcenginecd pcfx pico8 plus4 pokemini ports ps2 ps3 ps4 psp
    psvita psx pv1000 quake samcoupe satellaview saturn saturnjp
    scummvm scv sega32x sega32xjp sega32xna segacd sfc sg-1000 sgb
    snes snesna solarus spectravideo steam stv sufami supergrafx
    supervision supracan switch symbian tanodragon tg-cd tg16 ti99
    tic80 to8 triforce trs-80 type-x uzebox vectrex vic20 videopac
    vircon32 virtualboy vpinball vsmile wasm4 wii wiiu windows
    windows3x windows9x wonderswan wonderswancolor x1 x68000 xbox
    xbox360 xboxone zmachine zx81 zxnext zxspectrum
)

# ==============================================================================
#  RETROARCH CORES (libretro Linux buildbot names)
# ==============================================================================
# Linux core archives use the same base names as Windows, but the file inside
# is .so instead of .dll. The buildbot serves them as:
#   https://buildbot.libretro.com/nightly/linux/x86_64/latest/<core>_libretro.so.zip
# Each zip contains a single <core>_libretro.so.

RETROARCH_CORES=(
    fceumm mesen nestopia snes9x bsnes mupen64plus_next parallel_n64
    gambatte mgba melonds desmume citra dolphin pokemini mednafen_vb
    swanstation pcsx_rearmed mednafen_psx_hw ppsspp genesis_plus_gx
    genesis_plus_gx_wide picodrive flycast kronos mednafen_saturn
    yabasanshiro mednafen_pce mednafen_pce_fast mednafen_pcfx fbneo
    mednafen_ngp stella stella2014 atari800 prosystem virtualjaguar
    handy mednafen_lynx hatari mame mame2003_plus mame2010 daphne
    dosbox_pure dosbox_svn scummvm puae vice_x64 vice_x128 vice_xvic
    vice_xpet vice_xplus4 bluemsx fmsx fuse 81 np2kai quasi88 px68k
    x1 theodore o2em freechaf potator uzem nxengine lutro easyrpg
    opera vecx freeintv mednafen_wswan gw arduous mesen-s nekop2
    fmtowns
)

# ==============================================================================
#  STANDALONE EMULATORS (Flathub IDs)
# ==============================================================================
# Format: "flatpak_id|Display Name|Notes"
# Emulators without a Flathub release are handled separately below.

FLATPAK_EMULATORS=(
    "org.DolphinEmu.dolphin-emu|Dolphin|GameCube and Wii"
    "net.pcsx2.PCSX2|PCSX2|PlayStation 2"
    "net.rpcs3.RPCS3|RPCS3|PlayStation 3 -- requires PS3UPDAT.PUP firmware"
    "org.duckstation.DuckStation|DuckStation|PlayStation 1"
    "org.ppsspp.PPSSPP|PPSSPP|PlayStation Portable"
    "info.cemu.Cemu|Cemu|Wii U"
    "app.xemu.xemu|xemu|Original Xbox -- requires MCPX + flash BIOS"
    "net.kuribo64.melonDS|melonDS|Nintendo DS"
    "io.mgba.mGBA|mGBA|GBA / GB / GBC"
    "org.flycast.Flycast|Flycast|Dreamcast / NAOMI / Atomiswave"
    "net.vita3k.Vita3K|Vita3K|PlayStation Vita (experimental)"
    "org.mamedev.MAME|MAME|Arcade"
    "io.github.dosbox-staging|DOSBox Staging|MS-DOS"
    "org.scummvm.ScummVM|ScummVM|Adventure games"
)
# Emulators NOT on Flathub (or unreliable there):
#   * Ryujinx (Ryubing fork)  -- download Linux binary from GitHub
#   * shadPS4                 -- download Linux AppImage from GitHub
#   * Xenia                   -- Windows-only; use Wine/Bottles separately


# ==============================================================================
#  CONFIG FILE GENERATORS
# ==============================================================================

write_esde_settings() {
    # ES-DE on Linux uses portable mode when an 'ES-DE/' folder exists next to
    # the application. We always create $ESDE_CFG_DIR so config stays in the
    # install tree, not in $HOME/ES-DE.
    ensure_dir "$ESDE_CFG_DIR/settings"
    local settings_file="$ESDE_CFG_DIR/settings/es_settings.xml"

    # System -> standalone emulator label. These match es_systems.xml on Linux,
    # which uses the same "(Standalone)" suffix as Windows.
    cat > "$settings_file" <<'XML'
<?xml version="1.0"?>
<settings>
  <bool name="AlternativeEmulatorPerGame" value="true" />
  <string name="AlternativeEmulator_ps2"       value="PCSX2 (Standalone)" />
  <string name="AlternativeEmulator_ps3"       value="RPCS3 Directory (Standalone)" />
  <string name="AlternativeEmulator_gc"        value="Dolphin (Standalone)" />
  <string name="AlternativeEmulator_wii"       value="Dolphin (Standalone)" />
  <string name="AlternativeEmulator_wiiu"      value="Cemu (Standalone)" />
  <string name="AlternativeEmulator_switch"    value="Ryujinx (Standalone)" />
  <string name="AlternativeEmulator_psx"       value="DuckStation (Standalone)" />
  <string name="AlternativeEmulator_psp"       value="PPSSPP (Standalone)" />
  <string name="AlternativeEmulator_nds"       value="melonDS (Standalone)" />
  <string name="AlternativeEmulator_dreamcast" value="Flycast (Standalone)" />
  <string name="AlternativeEmulator_xbox"      value="xemu (Standalone)" />
  <string name="AlternativeEmulator_psvita"    value="Vita3K (Standalone)" />
  <string name="AlternativeEmulator_ps4"       value="shadPS4 eboot.bin (Standalone)" />
  <string name="ROMDirectory"                  value="ROMS_DIR_PLACEHOLDER" />
</settings>
XML
    sed -i "s|ROMS_DIR_PLACEHOLDER|${ROMS_DIR}|" "$settings_file"
    ok "ES-DE settings written ($settings_file)"
}

write_retro_bit_autoconfig() {
    ensure_dir "$RA_AUTOCFG_DIR"
    local cfg="${RA_AUTOCFG_DIR}/Retro-Bit Tribute64.cfg"
    if [[ -f "$cfg" ]]; then
        skip "Retro-Bit Tribute64 autoconfig already present"
        return 0
    fi
    # SDL2 driver names instead of dinput. Vendor/product IDs are the same as
    # the libretro Windows autoconfig; udev/SDL2 will match on those.
    cat > "$cfg" <<'CFG'
# Retro-Bit Tribute64 - USB
# Linux port -- matches udev/SDL2 button mapping
# Tested with Mupen64Plus-Next; works with ParaLLEl-N64 too
input_driver = "udev"
input_device = "Retro-Bit Tribute64 - USB"
input_device_display_name = "Retro-Bit Tribute64 - USB"
input_vendor_id = "9571"
input_product_id = "1397"

input_b_btn = "1"
input_a_btn = "2"
input_y_btn = "2"
input_start_btn = "12"
input_up_btn = "h0up"
input_down_btn = "h0down"
input_left_btn = "h0left"
input_right_btn = "h0right"
input_l_btn = "4"
input_r_btn = "5"
input_l2_btn = "6"
input_r2_btn = "7"

input_l_x_plus_axis = "+0"
input_l_x_minus_axis = "-0"
input_l_y_plus_axis = "+1"
input_l_y_minus_axis = "-1"

input_r_x_plus_btn = "9"
input_r_x_minus_btn = "3"
input_r_y_plus_btn = "0"
input_r_y_minus_btn = "8"

input_b_btn_label = "A"
input_y_btn_label = "B"
input_start_btn_label = "Start"
input_up_btn_label = "D-Pad Up"
input_down_btn_label = "D-Pad Down"
input_left_btn_label = "D-Pad Left"
input_right_btn_label = "D-Pad Right"
input_l_btn_label = "L"
input_r_btn_label = "R"
input_l2_btn_label = "Z"
input_r2_btn_label = "ZR"
input_l_x_plus_axis_label = "Joystick Right"
input_l_x_minus_axis_label = "Joystick Left"
input_l_y_plus_axis_label = "Joystick Down"
input_l_y_minus_axis_label = "Joystick Up"
input_r_x_plus_btn_label = "C Right"
input_r_x_minus_btn_label = "C Left"
input_r_y_plus_btn_label = "C Up"
input_r_y_minus_btn_label = "C Down"
CFG
    ok "Retro-Bit Tribute64 RetroArch autoconfig written"
}

write_n64_core_options() {
    # mupen64plus-next core options live under config/Mupen64Plus-Next/
    local core_opts_dir="${RA_FLATPAK_CFG}/config/Mupen64Plus-Next"
    ensure_dir "$core_opts_dir"
    local core_opts="${core_opts_dir}/Mupen64Plus-Next.opt"
    if [[ -f "$core_opts" ]]; then
        skip "Mupen64Plus-Next core options already present"
        return 0
    fi
    cat > "$core_opts" <<'OPT'
mupen64plus-astick-deadzone = "15"
mupen64plus-r-cbuttons = "Right Analog"
mupen64plus-pak1 = "memory"
OPT
    ok "N64 core options written (C-buttons = Right Analog)"
}

write_retroarch_joypad_driver() {
    local cfg="${RA_FLATPAK_CFG}/retroarch.cfg"
    [[ -f "$cfg" ]] || return 0
    # On Linux, udev is the recommended joypad driver. The default is already
    # udev on most distros, so we only set it if a different driver is in use.
    if grep -q '^input_joypad_driver' "$cfg"; then
        sed -i 's|^input_joypad_driver.*|input_joypad_driver = "udev"|' "$cfg"
    else
        printf '\ninput_joypad_driver = "udev"\n' >> "$cfg"
    fi
    ok "RetroArch joypad driver set to udev"
}


# ==============================================================================
#  BIOS / CONTROLLERS / QUICK-START GUIDES
# ==============================================================================

write_bios_guide() {
    local out="$1"
    cat > "$out" <<EOF
+==============================================================================+
|               BIOS / FIRMWARE FILE REFERENCE GUIDE (Linux)                  |
|                                                                              |
|  Flatpak RetroArch system path:                                              |
|    ${RA_SYSTEM_DIR}    |
|                                                                              |
|  All BIOS files must be legally obtained from hardware you own.              |
+==============================================================================+

  Most BIOS files go in: RetroArch system folder (path above)
  PCSX2 BIOS goes in:    ~/.var/app/net.pcsx2.PCSX2/config/PCSX2/bios/
  RPCS3 firmware:        Install via RPCS3 > File > Install Firmware

-----------------------------------------------
  PLAYSTATION (PSX) -- DuckStation / Beetle PSX
-----------------------------------------------
  scph5500.bin   -- PS1 BIOS (Japan)       (MD5: 8dd7d5296a650fac7319bce665a6a53c)
  scph5501.bin   -- PS1 BIOS (USA)         (MD5: 490f666e1afb15b7362b406ed1cea246)
  scph5502.bin   -- PS1 BIOS (Europe)      (MD5: 32736f17079d0b2b7024407c39bd3050)
  DuckStation flatpak BIOS goes in:
    ~/.var/app/org.duckstation.DuckStation/config/duckstation/bios/

-----------------------------------------------
  PLAYSTATION 2 -- PCSX2
-----------------------------------------------
  Place in: ~/.var/app/net.pcsx2.PCSX2/config/PCSX2/bios/
  SCPH-70012.bin -- PS2 BIOS (USA, v12)
  SCPH-70004.bin -- PS2 BIOS (Europe)
  SCPH-70000.bin -- PS2 BIOS (Japan)

-----------------------------------------------
  PLAYSTATION 3 -- RPCS3
-----------------------------------------------
  PS3UPDAT.PUP   -- PS3 Firmware (download from Sony official site)
  Install via RPCS3 > File > Install Firmware
  RPCS3 flatpak config: ~/.var/app/net.rpcs3.RPCS3/config/rpcs3/

-----------------------------------------------
  SEGA DREAMCAST -- Flycast
-----------------------------------------------
  dc/dc_boot.bin     -- Dreamcast BIOS       (MD5: e10c53c2f8b90bab96ead2d368858623)
  dc/dc_flash.bin    -- Dreamcast Flash ROM  (MD5: 0a93f7940c455905bea6e392dfde92a4)
  (Standalone Flycast uses its own BIOS dir:
    ~/.var/app/org.flycast.Flycast/config/flycast/data/)

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
  dc/naomi.zip       -- NAOMI BIOS
  dc/awbios.zip      -- Atomiswave BIOS

-----------------------------------------------
  NINTENDO DS -- melonDS / DeSmuME
-----------------------------------------------
  bios7.bin          -- ARM7 BIOS             (MD5: df692a80a5b1bc90728bc3dfc76cd948)
  bios9.bin          -- ARM9 BIOS             (MD5: a392174eb3e572fed6447e956bde4b25)
  firmware.bin       -- NDS Firmware          (MD5: 145eaef5bd3037cbc247c213bb3da1b3)

-----------------------------------------------
  GBA / GB / GBC (optional, for boot logos)
-----------------------------------------------
  gba_bios.bin       -- GBA BIOS              (MD5: a860e8c0b6d573d191e4ec7db1b1e4f6)
  gb_bios.bin        -- Game Boy BIOS         (MD5: 32fbbd84168d3482956eb3c5051637f5)
  gbc_bios.bin       -- GBC BIOS              (MD5: dbfce9db9deaa2567f6a84fde55f9680)
  sgb_bios.bin       -- Super Game Boy BIOS   (MD5: d574d4f9c12f305571c6b0ce18f0c563)

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
  neogeo.zip         -- Neo Geo BIOS (also place in ROMs/neogeo/)

-----------------------------------------------
  XBOX (ORIGINAL) -- xemu
-----------------------------------------------
  mcpx_1.0.bin       -- MCPX Boot ROM
  Complex_4627.bin   -- Flash BIOS image
  xemu flatpak data: ~/.var/app/app.xemu.xemu/data/xemu/xemu/

-----------------------------------------------
  NINTENDO SWITCH -- Ryujinx (Ryubing fork)
-----------------------------------------------
  prod.keys          -- Production keys (dump from your own Switch)
  title.keys         -- Title keys (optional)
  Switch firmware    -- Install via Ryujinx > Tools > Install Firmware
  Ryujinx config:    ~/.config/Ryujinx/system/   (prod.keys goes here)

-----------------------------------------------
  PLAYSTATION 4 -- shadPS4
-----------------------------------------------
  Requires PS4 firmware modules dumped from your own console.
  Place them in: ~/.local/share/shadPS4/sys_modules/  (or wherever shadPS4
  is configured to look -- check shadPS4's own quickstart guide).

-----------------------------------------------
  NOTES
-----------------------------------------------
  * Most paths above are relative to the RetroArch flatpak system folder:
    ~/.var/app/org.libretro.RetroArch/config/retroarch/system/
  * Standalone emulator flatpaks store config under:
    ~/.var/app/<app.id>/config/<emulator>/
  * Neo Geo BIOS (neogeo.zip) belongs in BOTH the RetroArch BIOS folder
    AND in ROMs/neogeo/ so MAME-style cores can find it.
  * For systems not listed, the emulator likely runs in HLE mode without BIOS.
EOF
    ok "BIOS guide written to $(basename "$out")"
}

write_controllers_guide() {
    local out="$1"
    cat > "$out" <<'EOF'
==============================================================================
 CONTROLLER SETUP GUIDE (Linux)
==============================================================================

 This setup is optimized for the following controllers:
   - 8BitDo Ultimate 2C  (Wired / 2.4G dongle / Bluetooth)
   - 8BitDo Pro 2        (Bluetooth, X-input mode)
   - 8BitDo 64           (Bluetooth or USB-C -- N64-style)
   - Retro-Bit Tribute64 (USB -- discrete C-buttons)

 On Linux, all four controllers work as standard SDL2/udev gamepads.
 RetroArch uses the udev driver (default on Linux) which auto-detects them.
 An autoconfig for the Retro-Bit Tribute64 is pre-installed at:
   ~/.var/app/org.libretro.RetroArch/config/retroarch/autoconfig/Retro-Bit Tribute64.cfg

==============================================================================
 RECOMMENDED MODE FOR EACH CONTROLLER
==============================================================================

 8BitDo Ultimate 2C:
   - Use 2.4G mode (USB dongle) or Wired mode for lowest latency.
   - L4/R4 back buttons can be remapped on the controller itself
     (hold Mapping button + L4/R4 + desired button).
   - Modern kernels (6.x and later) handle these as standard XBox-style
     gamepads via xpadneo/hid-generic -- no extra driver setup needed.

 8BitDo Pro 2:
   - Set physical mode switch to "X" before connecting.
   - For Bluetooth, install the xpadneo kernel driver for the cleanest
     experience -- on Ubuntu:  sudo apt install dkms xpadneo-dkms
     (or build from https://atar-axis.github.io/xpadneo/)
   - Back paddle buttons are exposed as extra buttons in X mode.

 8BitDo 64 (N64 controller):
   - Connect via Bluetooth or USB-C.
   - The C-pad reports as the right analog stick.
   - mupen64plus-next's default "Right Analog" C-button mode is already
     written to: ~/.var/app/org.libretro.RetroArch/config/retroarch/
     config/Mupen64Plus-Next/Mupen64Plus-Next.opt

 Retro-Bit Tribute64 (USB):
   - Plug in -- no drivers, no mode switching required.
   - SDL2 / udev see it as a standard HID device.
   - The pre-installed autoconfig maps every button correctly, including
     C-buttons as discrete digital inputs (no right-analog mode needed).

==============================================================================
 RETROARCH BUTTON MAPPING (default RetroPad on Linux)
==============================================================================

 Xbox / 8BitDo X-input layout -> RetroPad -> system buttons:
   A   -> RetroPad B  -> SNES B / Genesis B / PS Cross
   B   -> RetroPad A  -> SNES A / Genesis C / PS Circle
   X   -> RetroPad Y  -> SNES Y / Genesis A / PS Square
   Y   -> RetroPad X  -> SNES X / Genesis X / PS Triangle
   LB  -> RetroPad L          RB  -> RetroPad R
   LT  -> RetroPad L2         RT  -> RetroPad R2

 N64 (mupen64plus-next core):
   A   -> N64 A          B   -> N64 B
   Right stick          -> N64 C-buttons (Right Analog mode)
   LT  -> N64 Z          LB  -> N64 L
   RB  -> N64 R          Start -> N64 Start

 Retro-Bit Tribute64 -- discrete C-button digital inputs are handled
 by the autoconfig; no core-side remap needed.

==============================================================================
 STANDALONE EMULATORS (PCSX2, RPCS3, Dolphin, etc.)
==============================================================================

 All standalone emulators installed by this script are Flatpaks. They use
 SDL2 internally and will see your controllers as standard gamepads. No
 extra configuration is needed for basic use; per-emulator controller
 customization is done inside each emulator's GUI.

 If a controller is not detected by a Flatpak emulator:
   - Ensure your user is in the 'input' group:
       sudo usermod -aG input $USER
   - Re-plug or re-pair the controller.
   - For Bluetooth 8BitDo controllers, the xpadneo driver gives the
     cleanest XInput-style experience.

==============================================================================
 TIPS
==============================================================================

 - To test controller input system-wide:  sudo apt install joystick
   then run:  jstest /dev/input/js0
 - RetroArch quit hotkey default: Select + Start.
 - The 8BitDo 64 is the most ergonomic modern N64 controller.
 - The Retro-Bit Tribute64 gives the most authentic feel with real
   C-buttons -- best paired with mupen64plus-next or ParaLLEl-N64.
 - All 8BitDo controllers support firmware updates via support.8bitdo.com
   (the updater app runs under Wine if needed).

==============================================================================
EOF
    ok "Controller guide written to $(basename "$out")"
}

write_quick_start_guide() {
    local out="$1"
    cat > "$out" <<EOF
==============================================================================
 ES-DE Portable (Linux) -- Quick Start Guide
==============================================================================

 Install root: ${BASE_PATH}

 DIRECTORY LAYOUT:
   ${BASE_PATH}/
     ES-DE-x86_64.AppImage    <- Launch this (or use Launch_ES-DE.sh)
     ES-DE/                   <- Portable config dir (settings, themes, etc.)
     ROMs/                    <- All 195 system folders pre-created
     Emulators/               <- Reserved (most live as Flatpaks instead)
     .downloads/              <- Cached archives (safe to delete)
     BIOS_README.txt
     CONTROLLERS.txt
     QUICK_START.txt
     Launch_ES-DE.sh

 EMULATORS ARE FLATPAKS:
   On Linux this script installs emulators as Flatpaks from Flathub. They
   live at:
     ~/.var/app/<flatpak-id>/
   ES-DE's bundled es_find_rules.xml already knows how to find Flatpak
   emulators -- no PATH or symlink work is needed.

 RETROARCH FLATPAK PATHS:
   Config:   ~/.var/app/org.libretro.RetroArch/config/retroarch/
   Cores:    ${RA_CORES_DIR}
   BIOS:     ${RA_SYSTEM_DIR}
   Autoconf: ${RA_AUTOCFG_DIR}

 FIRST LAUNCH:
   1. Run ./Launch_ES-DE.sh (or ./ES-DE-x86_64.AppImage)
   2. ES-DE detects the ES-DE/ folder next to the AppImage and runs in
      portable mode -- all settings stay in this folder.
   3. ROMs/ is already populated with all 195 system subfolders.
   4. Standalone emulators are pre-selected as defaults for PS2, PS3,
      GameCube/Wii, etc. (see ES-DE/settings/es_settings.xml).

 ADDING GAMES:
   Drop legally-obtained ROMs into ROMs/<system>/ using ES-DE folder names:
     ROMs/gc/        (NOT gamecube)
     ROMs/n3ds/      (NOT 3ds)
     ROMs/genesis/   (Sega Genesis / Mega Drive)
     ROMs/psx/       (PlayStation 1)

 BIOS FILES:
   See BIOS_README.txt for the complete list with MD5 checksums.
   Most live in ${RA_SYSTEM_DIR}/ ; PCSX2 and a few others use their own
   Flatpak data dirs (paths in BIOS_README.txt).

 SCRAPING (box art, screenshots, descriptions):
   1. Free account at https://www.screenscraper.fr/
   2. ES-DE Main Menu > Scraper > ScreenScraper
   3. Enter credentials and scrape.

 EMULATORS NOT ON FLATHUB:
   * Ryujinx (Ryubing) -- not on Flathub. Grab the Linux binary from:
       https://github.com/Ryubing/Ryujinx/releases
     Extract to: ${EMU_DIR}/Ryujinx/  (ES-DE will discover it there)
   * shadPS4 -- AppImage from:
       https://github.com/shadps4-emu/shadPS4/releases
     Save as: ${EMU_DIR}/shadps4/shadPS4.AppImage  (chmod +x)
   * Xenia -- Windows-only Xbox 360 emulator. Run via Wine/Bottles or
       Lutris if you need it. No native Linux build exists.

==============================================================================
EOF
    ok "Quick-start guide written"
}


# ==============================================================================
#  MAIN EXECUTION
# ==============================================================================

printf '\n%s================================================================%s\n' "$C_MAGENTA" "$C_RESET"
printf   '%s  EmulationStation Desktop Edition -- Linux Setup Script%s\n'        "$C_MAGENTA" "$C_RESET"
printf   '%s  %s%s\n'                                                            "$C_MAGENTA" "$(date '+%Y-%m-%d')" "$C_RESET"
printf   '%s================================================================%s\n\n' "$C_MAGENTA" "$C_RESET"
printf   '  Base path: %s\n'                                                     "$BASE_PATH"
printf   '  ES-DE portable root (AppImage + ES-DE/ config dir live here)\n\n'

# -- 1. Prerequisites ----------------------------------------------------------
step "Checking prerequisites..."

if [[ "$EUID" -eq 0 ]]; then
    err "Do not run this script as root. Flatpak --user installs and \$HOME paths"
    err "must belong to your normal user. Re-run as yourself."
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    warn "apt-get not found -- this script targets Ubuntu/Debian-derivatives."
    warn "You'll need to install equivalents (curl, flatpak, libfuse2) manually."
fi

NEEDED_PKGS=()
command -v curl     >/dev/null 2>&1 || NEEDED_PKGS+=("curl")
command -v flatpak  >/dev/null 2>&1 || NEEDED_PKGS+=("flatpak")
command -v python3  >/dev/null 2>&1 || NEEDED_PKGS+=("python3")
command -v unzip    >/dev/null 2>&1 || NEEDED_PKGS+=("unzip")
# libfuse2 is needed for older AppImages on Ubuntu 22.04+/24.04+; ES-DE's
# AppImage is built with libfuse3 but pulling libfuse2 covers most fallbacks.
dpkg -s libfuse2t64 >/dev/null 2>&1 || dpkg -s libfuse2 >/dev/null 2>&1 || NEEDED_PKGS+=("libfuse2t64")

if [[ ${#NEEDED_PKGS[@]} -gt 0 ]]; then
    info "Installing: ${NEEDED_PKGS[*]}"
    if sudo apt-get update -y >/dev/null 2>&1 && \
       sudo apt-get install -y "${NEEDED_PKGS[@]}" >/dev/null 2>&1; then
        ok "Installed system packages"
    else
        # libfuse2t64 doesn't exist on older Ubuntu; retry without it
        FILTERED=()
        for p in "${NEEDED_PKGS[@]}"; do
            [[ "$p" != "libfuse2t64" ]] && FILTERED+=("$p")
        done
        if sudo apt-get install -y "${FILTERED[@]}" libfuse2 >/dev/null 2>&1; then
            ok "Installed system packages (libfuse2 fallback)"
        else
            warn "Some packages failed to install. Continuing anyway."
        fi
    fi
else
    ok "All prerequisites already installed"
fi

# Flathub remote (user-scope)
if ! flatpak --user remotes | grep -q '^flathub'; then
    info "Adding Flathub remote..."
    flatpak --user remote-add --if-not-exists flathub \
        https://flathub.org/repo/flathub.flatpakrepo
    ok "Flathub added (user scope)"
else
    ok "Flathub already configured"
fi

# -- 2. Directory structure ----------------------------------------------------
step "Creating directory structure..."

ensure_dir "$BASE_PATH"
ensure_dir "$DL_DIR"
ensure_dir "$ROMS_DIR"
ensure_dir "$EMU_DIR"
ensure_dir "$ESDE_CFG_DIR/settings"
ensure_dir "$ESDE_CFG_DIR/themes"
ensure_dir "$ESDE_CFG_DIR/downloaded_media"
ensure_dir "$ESDE_CFG_DIR/custom_systems"

rom_created=0
for sys in "${ROM_SYSTEMS[@]}"; do
    if [[ ! -d "${ROMS_DIR}/${sys}" ]]; then
        mkdir -p "${ROMS_DIR}/${sys}"
        rom_created=$((rom_created + 1))
    fi
done
ok "ROM system folders ready (${#ROM_SYSTEMS[@]} total, ${rom_created} new)"

# -- 3. BIOS / controllers / quick-start guides --------------------------------
step "Writing reference guides..."

if [[ $SKIP_DOWNLOADS -eq 0 ]]; then
    # Real RetroArch system dir requires the flatpak to exist first; defer
    # writing the BIOS guide until after that step in download mode.
    :
else
    # In skip-downloads mode the user only wants config skeletons -- write
    # everything we can with the paths we know.
    ensure_dir "$RA_FLATPAK_CFG"
    ensure_dir "$RA_CORES_DIR"
    ensure_dir "$RA_SYSTEM_DIR"
    write_bios_guide "${BASE_PATH}/BIOS_README.txt"
    write_controllers_guide "${BASE_PATH}/CONTROLLERS.txt"
    write_quick_start_guide "${BASE_PATH}/QUICK_START.txt"
    write_esde_settings
    info "Skipping downloads (--skip-downloads). Done."
    exit 0
fi

# -- 4. Download ES-DE AppImage ------------------------------------------------
step "Downloading ES-DE Linux AppImage..."

ESDE_DL_RAW="${DL_DIR}/ES-DE-linux.zip"   # the GitLab package is a .zip
ESDE_DL_APPIMAGE="${BASE_PATH}/ES-DE-x86_64.AppImage"

esde_url=""
info "Querying GitLab for latest ES-DE Linux release..."
if esde_url=$(gitlab_release_link "es-de%2Femulationstation-de" \
        '(?i)^ES-DE_Linux.*x86[_-]?64.*AppImage(\.zip)?$'); then
    info "Found: ${esde_url}"
fi

if [[ -x "$ESDE_DL_APPIMAGE" ]]; then
    skip "ES-DE AppImage already installed"
elif [[ -z "$esde_url" ]]; then
    warn "GitLab API lookup failed."
    warn "Manually download the Linux x86_64 AppImage from:"
    warn "  https://es-de.org/  (Releases section)"
    warn "and place it at: ${ESDE_DL_APPIMAGE}"
    warn "Then re-run this script -- everything else will pick up where it left off."
else
    if download_file "$esde_url" "$ESDE_DL_RAW" "ES-DE AppImage archive"; then
        # The GitLab package is typically a zip containing the AppImage.
        # If the file is already an AppImage, just copy it.
        if file "$ESDE_DL_RAW" 2>/dev/null | grep -qi 'zip archive'; then
            info "Extracting AppImage from zip..."
            tmp_extract="${DL_DIR}/_esde_extract"
            rm -rf "$tmp_extract"
            mkdir -p "$tmp_extract"
            unzip -q -o "$ESDE_DL_RAW" -d "$tmp_extract"
            appimage_path=$(find "$tmp_extract" -type f -iname '*.AppImage' | head -n1)
            if [[ -n "$appimage_path" ]]; then
                cp "$appimage_path" "$ESDE_DL_APPIMAGE"
                chmod +x "$ESDE_DL_APPIMAGE"
                ok "ES-DE AppImage installed: $(basename "$ESDE_DL_APPIMAGE")"
            else
                err "Could not find an AppImage inside the downloaded zip"
            fi
            rm -rf "$tmp_extract"
        elif file "$ESDE_DL_RAW" 2>/dev/null | grep -qi 'elf'; then
            cp "$ESDE_DL_RAW" "$ESDE_DL_APPIMAGE"
            chmod +x "$ESDE_DL_APPIMAGE"
            ok "ES-DE AppImage installed (direct)"
        else
            warn "Downloaded file type unrecognized; saved as ${ESDE_DL_RAW}"
            warn "Grab the AppImage manually from https://es-de.org and place"
            warn "it at: ${ESDE_DL_APPIMAGE}"
        fi
    fi
fi

# -- 5. RetroArch via Flatpak --------------------------------------------------
step "Installing RetroArch (Flatpak)..."
flatpak_install "org.libretro.RetroArch" "RetroArch"

# First-launch RetroArch once so it creates its config tree. This is the
# canonical way to make config / cores / system / autoconfig dirs exist.
if [[ ! -d "$RA_FLATPAK_CFG" ]]; then
    info "Initializing RetroArch config (first launch, headless)..."
    # --menu starts RetroArch's menu without a game. We send it to background
    # for a moment so it can write its config, then kill it.
    if command -v timeout >/dev/null 2>&1; then
        timeout 8s flatpak --user run org.libretro.RetroArch --menu >/dev/null 2>&1 || true
    else
        ( flatpak --user run org.libretro.RetroArch --menu >/dev/null 2>&1 ) &
        sleep 8
        kill %1 2>/dev/null || true
        wait 2>/dev/null || true
    fi
fi
ensure_dir "$RA_CORES_DIR"
ensure_dir "$RA_SYSTEM_DIR"
ensure_dir "$RA_AUTOCFG_DIR"
ensure_dir "${RA_SYSTEM_DIR}/dc"
ensure_dir "${RA_SYSTEM_DIR}/np2kai"
ensure_dir "${RA_SYSTEM_DIR}/keropi"
ensure_dir "${RA_SYSTEM_DIR}/fmtowns"

# -- 6. Bulk-download libretro cores -------------------------------------------
step "Downloading libretro cores (${#RETROARCH_CORES[@]} cores)..."

CORE_BASE_URL="https://buildbot.libretro.com/nightly/linux/x86_64/latest"
ensure_dir "${DL_DIR}/cores"
core_ok=0
core_fail=0
for core in "${RETROARCH_CORES[@]}"; do
    core_so="${core}_libretro.so"
    if [[ -f "${RA_CORES_DIR}/${core_so}" ]]; then
        core_ok=$((core_ok + 1))
        continue
    fi
    core_zip="${core_so}.zip"
    core_url="${CORE_BASE_URL}/${core_zip}"
    core_dest="${DL_DIR}/cores/${core_zip}"
    if curl --fail --silent --location --connect-timeout 15 \
            --output "$core_dest" "$core_url" 2>/dev/null; then
        if unzip -q -o "$core_dest" -d "$RA_CORES_DIR" 2>/dev/null; then
            core_ok=$((core_ok + 1))
        else
            core_fail=$((core_fail + 1))
        fi
    else
        core_fail=$((core_fail + 1))
    fi
done
ok "Cores installed: ${core_ok}  (failed/unavailable: ${core_fail})"

# -- 7. Standalone emulators via Flatpak ---------------------------------------
if [[ $RETROARCH_ONLY -eq 1 || $SKIP_FLATPAK_EMUS -eq 1 ]]; then
    skip "Skipping standalone emulator flatpaks (per flags)"
else
    step "Installing standalone emulators (Flatpak)..."
    emu_total=${#FLATPAK_EMULATORS[@]}
    emu_ok=0
    emu_fail=0
    for entry in "${FLATPAK_EMULATORS[@]}"; do
        IFS='|' read -r app_id name notes <<< "$entry"
        info "${name}: ${notes}"
        if flatpak_install "$app_id" "$name"; then
            emu_ok=$((emu_ok + 1))
        else
            emu_fail=$((emu_fail + 1))
        fi
    done
    ok "Standalone emulators installed: ${emu_ok}/${emu_total}  (failed: ${emu_fail})"

    # Off-Flathub emulators: drop stub directories so the user knows where
    # to put the binaries if they grab them manually.
    ensure_dir "${EMU_DIR}/Ryujinx"
    ensure_dir "${EMU_DIR}/shadps4"
    ensure_dir "${EMU_DIR}/xenia"
    cat > "${EMU_DIR}/Ryujinx/README.txt" <<EOF
Ryujinx is not on Flathub. Grab the Linux build from:
  https://github.com/Ryubing/Ryujinx/releases
Extract the contents here so 'Ryujinx' (or 'Ryujinx.sh') sits next to this
file. Place prod.keys in ~/.config/Ryujinx/system/ , then install firmware
via Ryujinx > Tools > Install Firmware.
EOF
    cat > "${EMU_DIR}/shadps4/README.txt" <<EOF
shadPS4 is not on Flathub. Grab the Linux AppImage from:
  https://github.com/shadps4-emu/shadPS4/releases
Save it here as: shadPS4.AppImage   then run: chmod +x shadPS4.AppImage
PS4 firmware modules go in shadPS4's data folder (check its quickstart).
EOF
    cat > "${EMU_DIR}/xenia/README.txt" <<EOF
Xenia is a Windows-only Xbox 360 emulator. There is no native Linux build.
Run it via Wine/Bottles/Lutris. Recommended: a fresh Bottles 'gaming' bottle
with the latest xenia_canary.exe from:
  https://github.com/xenia-canary/xenia-canary-releases/releases
EOF
fi

# -- 8. Pre-configured ES-DE settings ------------------------------------------
step "Writing ES-DE settings..."
write_esde_settings

# -- 9. RetroArch tweaks: joypad driver, N64 core opts, Tribute64 autoconfig ---
step "Configuring RetroArch (joypad driver, N64, Tribute64 autoconfig)..."
write_retroarch_joypad_driver
write_n64_core_options
write_retro_bit_autoconfig

# -- 10. Reference guides ------------------------------------------------------
step "Writing reference guides..."
write_bios_guide "${BASE_PATH}/BIOS_README.txt"
write_controllers_guide "${BASE_PATH}/CONTROLLERS.txt"
write_quick_start_guide "${BASE_PATH}/QUICK_START.txt"

# -- 11. Launch helper ---------------------------------------------------------
step "Creating launcher..."
LAUNCHER="${BASE_PATH}/Launch_ES-DE.sh"
cat > "$LAUNCHER" <<EOF
#!/usr/bin/env bash
# Launch ES-DE in portable mode (uses the sibling ES-DE/ folder for config).
set -e
cd "\$(dirname "\$(readlink -f "\$0")")"
if [[ -x "./ES-DE-x86_64.AppImage" ]]; then
    exec ./ES-DE-x86_64.AppImage "\$@"
else
    echo "ES-DE-x86_64.AppImage not found in \$(pwd)"
    echo "Download it from https://es-de.org and place it here."
    exit 1
fi
EOF
chmod +x "$LAUNCHER"
ok "Launcher: $(basename "$LAUNCHER")"

# -- 12. Summary ---------------------------------------------------------------
printf '\n%s================================================================%s\n' "$C_GREEN" "$C_RESET"
printf   '%s                      SETUP COMPLETE%s\n'                            "$C_GREEN" "$C_RESET"
printf   '%s================================================================%s\n\n' "$C_GREEN" "$C_RESET"
cat <<EOF
  ${BASE_PATH}/
    |-- ES-DE-x86_64.AppImage  <- Launch this!
    |-- ES-DE/                 <- Portable config (settings, themes)
    |-- ROMs/                  <- ${#ROM_SYSTEMS[@]} system folders pre-created
    |   |-- nes/  snes/  psx/  ps2/  gc/  switch/  ...
    |-- Emulators/             <- Stubs for off-Flathub emulators
    |-- BIOS_README.txt        <- Full BIOS reference w/ MD5s and Linux paths
    |-- CONTROLLERS.txt        <- 8BitDo + Tribute64 setup guide
    |-- QUICK_START.txt        <- First-run walkthrough
    \\-- Launch_ES-DE.sh        <- Quick launcher

  Flatpak emulators live at: ~/.var/app/<flatpak-id>/
  RetroArch BIOS dir:        ${RA_SYSTEM_DIR}

  NEXT STEPS:
    1. Run ./Launch_ES-DE.sh (or the AppImage directly)
    2. ROM folders are already created -- drop legally-owned ROMs into ROMs/
    3. Drop BIOS files into the locations listed in BIOS_README.txt
    4. Standalone emulators are pre-set as defaults for PS2/PS3/GC/Wii/etc.
    5. For Ryujinx, shadPS4, and Xenia, see Emulators/<name>/README.txt
    6. Optionally scrape artwork at screenscraper.fr (Main Menu > Scraper)

  RetroArch cores installed: ${core_ok}
EOF
if [[ $RETROARCH_ONLY -eq 0 && $SKIP_FLATPAK_EMUS -eq 0 ]]; then
    printf '  Standalone Flatpak emulators: %d/%d\n' "$emu_ok" "$emu_total"
fi
printf '\n'
