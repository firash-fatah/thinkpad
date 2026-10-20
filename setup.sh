#!/usr/bin/env bash
# Setup tampilan login SSH: Starship + fastfetch bertema ThinkPad (Ubuntu 24.04)
# Pakai:  bash setup.sh      atau      curl -fsSL https://raw.githubusercontent.com/firash-fatah/thinkpad-setup/refs/heads/main/setup.sh | bash
# Ubah pengaturan lewat environment, contoh:
#   curl -fsSL https://raw.githubusercontent.com/firash-fatah/thinkpad/refs/heads/main/setup.sh | LOGO_TOP=4 INFO_TOP=1 AUTORUN=1 TIMEZONE=Asia/Jakarta bash
set -euo pipefail

LOGO_TOP="${LOGO_TOP:-5}"     # baris kosong di atas logo
INFO_TOP="${INFO_TOP:-2}"     # baris kosong di atas kotak keterangan
SNAKE="${SNAKE:-1}"           # 1 = ular Python selalu tampil di prompt, 0 = bawaan Starship
AUTORUN="${AUTORUN:-0}"       # 1 = fastfetch otomatis tiap login SSH interaktif
TIMEZONE="${TIMEZONE:-}"      # contoh: Asia/Jakarta (kosong = tidak diubah)
export DEBIAN_FRONTEND=noninteractive
SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"
say() { printf '\n==> %s\n' "$*"; }

say "1/5 Paket dasar"
need=""
for p in curl git python3; do command -v "$p" >/dev/null 2>&1 || need="$need $p"; done
if [ -n "$need" ]; then $SUDO apt-get update -y && $SUDO apt-get install -y $need; fi

say "2/5 Starship (prompt)"
if ! command -v starship >/dev/null 2>&1; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y
fi
touch ~/.bashrc
grep -q 'starship init' ~/.bashrc || echo 'eval "$(starship init bash)"' >> ~/.bashrc
mkdir -p ~/.config
if [ -f ~/.config/starship.toml ]; then cp ~/.config/starship.toml ~/.config/starship.toml.bak; fi
cat > ~/.config/starship.toml <<'TOMLEOF'
[username]
show_always = true
format = "[$user]($style) "
style_user = "bold yellow"

[hostname]
ssh_only = true
ssh_symbol = "🌐 "
format = "in [$ssh_symbol$hostname]($style) "
style = "bold green"

[directory]
format = "in [$path]($style) "
style = "bold cyan"

[character]
success_symbol = "[❯](bold green)"
error_symbol = "[❯](bold red)"
TOMLEOF
if [ "$SNAKE" = "1" ]; then
cat >> ~/.config/starship.toml <<'SNAKEEOF'

# ular Python selalu tampil (versi python3 yang terpasang)
[python]
disabled = true

[custom.python_always]
command = "python3 -V | cut -d' ' -f2"
when = true
format = "via [🐍 v$output]($style) "
style = "bold yellow"
SNAKEEOF
fi

say "3/5 fastfetch"
if ! command -v fastfetch >/dev/null 2>&1; then
  $SUDO apt-get install -y software-properties-common
  $SUDO add-apt-repository -y ppa:zhangsongcui3371/fastfetch
  $SUDO apt-get update -y
  $SUDO apt-get install -y fastfetch
fi

say "4/5 Config dan logo fastfetch"
LOGO_TOP="$LOGO_TOP" INFO_TOP="$INFO_TOP" python3 - <<'PYEOF'
import json, os, re, shutil, urllib.request

# ===== PENGATURAN YANG BOLEH DIUBAH =====
LOGO_TOP = int(os.environ["LOGO_TOP"])   # baris kosong di atas logo
INFO_TOP = int(os.environ["INFO_TOP"])   # baris kosong di atas kotak keterangan
ROSE  = "\u001b[38;2;193;105;110m"   # warna garis kotak + tulisan "Pad"
WHITE = "\u001b[38;2;232;232;232m"   # warna tulisan "Think"
# ========================================

RST = "\u001b[0m"
NAME_W = 11
D = os.path.expanduser("~/.config/fastfetch")
os.makedirs(D, exist_ok=True)
if os.path.exists(f"{D}/config.jsonc"):
    shutil.copy(f"{D}/config.jsonc", f"{D}/config.jsonc.bak")

I = {k: chr(v) for k, v in dict(
    header=0xF0BAF, ghost=0xF02A0, whoami=0xF0004, hostname=0xF048B, machine=0xF0322,
    distro=0xF0548, kernel=0xF0493, osage=0xF00ED, uptime=0xF0954, terminal=0xF018D,
    shell=0xF07B7, packages=0xF03D6, display=0xF0379, cpu=0xF061A, gpu=0xF08AE,
    memory=0xF035B, disk=0xF02CA, datetime=0xF00F0, lan=0xF0317, globe=0xF01E7,
    ssh=0xF08C0, pin=0xF034E).items()}

def line(kind):
    l, r = {"top": "╭╮", "mid": "├┤", "bot": "╰╯"}[kind]
    return {"type": "custom", "format": f"{ROSE}{l}{'─' * (NAME_W + 4)}{r}{RST}"}

def key(icon, name):
    return f"{ROSE}│{RST}{WHITE} {I[icon]} {name.ljust(NAME_W)} {ROSE}│{RST}"

def mod(t, k, icon, **kw):
    return {"type": t, "key": key(icon, k), **kw}

cols = ["33", "90", "31", "32", "34", "35", "36", "37"]
ghosts = " ".join(f"\u001b[{c}m{I['header'] if n == 0 else I['ghost']}{RST}" for n, c in enumerate(cols))
header = {"type": "custom", "format": key("header", "fastfetch") + " " + ghosts}

osage = ('b=$(stat -c %W / 2>/dev/null); [ "${b:-0}" -gt 0 ] || b=$(stat -c %Y /etc/hostname); '
         'echo "$(( ($(date +%s) - b) / 86400 )) days"')

location = r'''ip="${SSH_CLIENT%% *}"; [ -n "$ip" ] || exit 0
c="$HOME/.cache/ff-loc-$ip"
if [ -s "$c" ]; then cat "$c"; exit 0; fi
mkdir -p "$HOME/.cache"
curl -s --max-time 1.5 "https://ipwho.is/$ip?fields=success,city,region,country" | python3 -c '
import sys, json
try: d = json.load(sys.stdin)
except Exception: sys.exit()
if d.get("success"):
    print(", ".join(x for x in (d.get("city"), d.get("region"), d.get("country")) if x))
' | tee "$c.tmp"
[ -s "$c.tmp" ] && mv "$c.tmp" "$c" || rm -f "$c.tmp"'''

modules = [{"type": "break"} for _ in range(INFO_TOP)] + [
    line("top"), header, line("mid"),
    mod("title", "whoami", "whoami", format="{user-name}"),
    mod("title", "hostname", "hostname", format="{host-name}"),
    mod("host", "machine", "machine"),
    mod("os", "distro", "distro", format="{pretty-name}"),
    mod("kernel", "kernel", "kernel"),
    mod("command", "os age", "osage", text=osage),
    mod("uptime", "uptime", "uptime"),
    line("mid"),
    mod("terminal", "terminal", "terminal"),
    mod("shell", "shell", "shell", format="{process-name}"),
    mod("packages", "packages", "packages"),
    line("mid"),
    mod("display", "display", "display", format="{width}x{height}"),
    mod("cpu", "cpu", "cpu"),
    mod("gpu", "gpu", "gpu", format="{name}"),
    mod("memory", "memory", "memory"),
    mod("disk", "disk", "disk", folders="/"),
    line("mid"),
    mod("datetime", "date/time", "datetime",
        format="{weekday-short}, {day-pretty}-{month-pretty}-{year} {hour-pretty}:{minute-pretty}:{second-pretty}"),
    mod("localip", "local ip", "lan", format="{ipv4} ({ifname})"),
    mod("publicip", "public ip", "globe", format="{ip}", timeout=1500),
    mod("command", "ssh from", "ssh", text='echo "${SSH_CLIENT%% *}"'),
    mod("command", "location", "pin", text=location),
    line("bot"),
]
cfg = {
    "logo": {"type": "file", "source": f"{D}/thinkpad.txt",
             "padding": {"top": LOGO_TOP, "left": 2, "right": 3}},
    "display": {"separator": " ", "color": {"output": "38;2;190;196;208"}},
    "modules": modules,
}
open(f"{D}/config.jsonc", "w").write(json.dumps(cfg, indent=2))

# logo ThinkPad 1x dari repo asli, diberi warna (Pad = rose, Think = putih)
url = "https://raw.githubusercontent.com/Sarthak-Sidhant/thinkpad-fastfetch/main/thinkpad.txt"
rows = urllib.request.urlopen(url).read().decode().split("\n")
rows = [re.sub(r"\x1b\[[0-9;]*m", "", r) for r in rows]
while rows and rows[-1] == "":
    rows.pop()
out = []
for n, r in enumerate(rows):
    if n <= 8:                out.append(f"{ROSE}{r}{RST}")
    elif r.startswith("▓▓"):  out.append(f"{ROSE}▓▓{RST}{WHITE}{r[2:]}{RST}")
    else:                     out.append(f"{WHITE}{r}{RST}")
open(f"{D}/thinkpad.txt", "w", encoding="utf-8").write("\n".join(out) + "\n")
print("Selesai. Jalankan: fastfetch")
PYEOF

say "5/5 Opsi tambahan"
if [ "$AUTORUN" = "1" ]; then
  grep -q 'ff-autorun' ~/.bashrc || echo '[[ $- == *i* && -n "$SSH_CONNECTION" ]] && fastfetch  # ff-autorun' >> ~/.bashrc
  echo "fastfetch otomatis aktif di login SSH berikutnya."
fi
if [ -n "$TIMEZONE" ]; then
  $SUDO timedatectl set-timezone "$TIMEZONE" && echo "Zona waktu: $TIMEZONE"
fi

printf '\nSelesai. Logout lalu SSH lagi, atau jalankan:  source ~/.bashrc && fastfetch\n'
