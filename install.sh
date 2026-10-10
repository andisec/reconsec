#!/usr/bin/env bash
# ==============================================================
#  R E C O N — INSTALLER v1.0.0
#  Installer interaktif untuk RECON — Full Auto Recon Tool
#  Repo    : https://github.com/andisec/reconsec
#  Author  : andisec (Gacor Kanda)
#  Lisensi : MIT — HANYA untuk pengujian yang berizin!
#
#  Pemakaian:
#    ./install.sh              -> menu interaktif (pilih nomor)
#    ./install.sh 1 2 5-8      -> langsung install ID tersebut
#    ./install.sh --all        -> install SEMUA tools
#    ./install.sh --check      -> cek status tools tanpa install
#    ./install.sh --help       -> bantuan
#
#  Daftar tools dibaca dari requirements.txt
#  Format tiap baris: id|name|category|source|description
# ==============================================================

VERSION="1.0.1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQ_FILE="${REQ_FILE:-$SCRIPT_DIR/requirements.txt}"
TOOLS_DIR="${TOOLS_DIR:-$HOME/tools}"
GOBIN="$HOME/go/bin"
PM="unknown"; SUDO=""; DISTRO="Linux"

# ── Warna (ANSI-C quoting, aman untuk semua terminal) ──
RED=$'\033[0;31m';     GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m';  CYAN=$'\033[0;36m'
MAGENTA=$'\033[0;35m'; BOLD=$'\033[1m'; NC=$'\033[0m'

info()  { printf '%s[i]%s %s\n' "$GREEN"  "$NC" "$*"; }
warn()  { printf '%s[!]%s %s\n' "$YELLOW" "$NC" "$*"; }
error() { printf '%s[x]%s %s\n' "$RED"    "$NC" "$*"; }
step()  { printf '%s[>]%s %s\n' "$CYAN"   "$NC" "$*"; }

# ── Registry tools (plain array, index = ID di requirements.txt) ──
R_NAME=(); R_CAT=(); R_SRC=(); R_DESC=(); R_GROUP=()
MAX_ID=0

load_registry() {
  local id name cat src desc REQ_TMP
  if [ ! -f "$REQ_FILE" ]; then
    error "File requirements.txt tidak ditemukan: $REQ_FILE"
    error "Pastikan install.sh dan requirements.txt berada di folder yang sama."
    exit 1
  fi
  REQ_TMP="$(mktemp 2>/dev/null || echo "/tmp/recon_req.$")"
  tr -d '\r' < "$REQ_FILE" > "$REQ_TMP"
  while IFS='|' read -r id name cat src desc; do
    case "$id" in ''|\#*) continue ;; esac
    R_NAME[$id]="$name"; R_CAT[$id]="$cat"
    R_SRC[$id]="$src";  R_DESC[$id]="$desc"
    case "$cat" in
      go)        R_GROUP[$id]="go" ;;
      pip|git|dl) R_GROUP[$id]="extra" ;;
      *)         R_GROUP[$id]="sys" ;;
    esac
    if [ "$id" -gt "$MAX_ID" ] 2>/dev/null; then MAX_ID=$id; fi
  done < "$REQ_TMP"
  rm -f "$REQ_TMP"
  if [ "$MAX_ID" -eq 0 ]; then
    error "requirements.txt kosong atau format salah."
    error "Format: id|name|category|source|description"
    exit 1
  fi
}

# ── Deteksi OS / package manager ──
detect_os() {
  if [ -n "${PREFIX:-}" ] && [ "${PREFIX#*com.termux}" != "$PREFIX" ]; then
    PM="pkg"; DISTRO="Termux (Android)"
  elif command -v apt-get >/dev/null 2>&1; then
    PM="apt"; DISTRO="$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-Debian/Ubuntu}")"
  elif command -v dnf >/dev/null 2>&1; then
    PM="dnf"; DISTRO="Fedora/RHEL"
  elif command -v pacman >/dev/null 2>&1; then
    PM="pacman"; DISTRO="Arch Linux"
  elif command -v brew >/dev/null 2>&1; then
    PM="brew"; DISTRO="macOS (Homebrew)"
  else
    PM="unknown"; DISTRO="tidak dikenali"
  fi
  if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
  elif [ "$PM" = "apt" ] || [ "$PM" = "dnf" ] || [ "$PM" = "pacman" ]; then
    command -v sudo >/dev/null 2>&1 && SUDO="sudo"
  fi
}

refresh_gobin() {
  if command -v go >/dev/null 2>&1; then
    GOBIN="$(go env GOPATH)/bin"
  fi
  [ -d "$GOBIN" ] || GOBIN="$HOME/go/bin"
  case ":$PATH:" in
    *":$GOBIN:"*) : ;;
    *) PATH="$PATH:$GOBIN"; export PATH ;;
  esac
}

# ── Nama paket per package manager (override) ──
resolve_pkg() {
  case "$1" in
    golang)
      case "$PM" in
        apt)    echo "golang-go" ;;
        dnf)    echo "golang" ;;
        pacman) echo "go" ;;
        brew)   echo "go" ;;
        pkg)    echo "golang" ;;
        *)      echo "golang-go" ;;
      esac ;;
    dig)
      case "$PM" in
        apt|pkg) echo "dnsutils" ;;
        dnf)     echo "bind-utils" ;;
        pacman)  echo "bind" ;;
        brew)    echo "bind" ;;
        *)       echo "dnsutils" ;;
      esac ;;
    netcat)
      case "$PM" in
        apt)    echo "netcat" ;;
        dnf)    echo "nmap-ncat" ;;
        pacman) echo "openbsd-netcat" ;;
        brew)   echo "netcat" ;;
        pkg)    echo "netcat-openbsd" ;;
        *)      echo "netcat" ;;
      esac ;;
    *)
      echo "$1" ;;
  esac
}

# ── Cek apakah tool sudah terpasang ──
check_tool() {
  local id="$1" name cat cands b
  name="${R_NAME[$id]}"; cat="${R_CAT[$id]}"
  case "$name" in
    golang)   cands="go" ;;
    chromium) cands="chromium chromium-browser google-chrome google-chrome-stable" ;;
    netcat)   cands="nc netcat ncat" ;;
    *)        cands="$name" ;;
  esac
  for b in $cands; do
    command -v "$b" >/dev/null 2>&1 && return 0
  done
  case "$cat" in go|pip) [ -x "$GOBIN/$name" ] && return 0 ;; esac
  case "$name" in testssl.sh) [ -x "$TOOLS_DIR/testssl.sh/testssl.sh" ] && return 0 ;; esac
  case "$cat" in
    dl)
      case "$name" in
        wordlist) [ -s "$HOME/.wordlist/dirs.txt" ] && return 0 ;;
        *)        [ -s "$TOOLS_DIR/$(basename "${R_SRC[$id]}")" ] && return 0 ;;
      esac ;;
  esac
  return 1
}

# ── Installer per kategori ──
APT_UPDATED=0

install_pkg() {
  local id="$1" name pkg
  name="${R_NAME[$id]}"; pkg="$(resolve_pkg "$name")"
  if [ "$PM" = "pkg" ] && [ "$name" = "chromium" ]; then
    warn "Chromium tidak tersedia di Termux native — pakai proot-distro (Ubuntu)."
    return 1
  fi
  case "$PM" in
    apt)
      [ "$APT_UPDATED" -eq 0 ] && { $SUDO apt-get update -qq >/dev/null 2>&1; APT_UPDATED=1; }
      if ! $SUDO apt-get install -y -qq "$pkg" >/dev/null 2>&1; then
        case "$name" in
          chromium) $SUDO apt-get install -y -qq chromium-browser >/dev/null 2>&1 || return 1 ;;
          netcat)   $SUDO apt-get install -y -qq netcat-openbsd   >/dev/null 2>&1 || return 1 ;;
          dig)      $SUDO apt-get install -y -qq bind9-dnsutils    >/dev/null 2>&1 || return 1 ;;
          *)        return 1 ;;
        esac
      fi
      hash -r
      return 0 ;;
    dnf)
      $SUDO dnf install -y "$pkg" >/dev/null 2>&1 || return 1; hash -r; return 0 ;;
    pacman)
      $SUDO pacman -S --noconfirm --needed "$pkg" >/dev/null 2>&1 || return 1; hash -r; return 0 ;;
    brew)
      brew install "$pkg" >/dev/null 2>&1 || return 1; hash -r; return 0 ;;
    pkg)
      pkg install -y "$pkg" >/dev/null 2>&1 || return 1; hash -r; return 0 ;;
    *)
      error "Manajer paket tidak dikenali — install '$name' secara manual."
      return 1 ;;
  esac
}

install_go() {
  local id="$1" name src gid i
  name="${R_NAME[$id]}"; src="${R_SRC[$id]}"
  if ! command -v go >/dev/null 2>&1; then
    warn "Go belum terpasang — auto-install 'golang' (no 12) dulu..."
    gid=""
    for i in $(seq 1 "$MAX_ID"); do
      [ "${R_NAME[$i]:-}" = "golang" ] && gid=$i
    done
    if [ -n "$gid" ]; then
      install_pkg "$gid" || { error "Install Go gagal — manual: https://go.dev/dl/"; return 1; }
    else
      error "golang tidak ada di requirements.txt — install manual: https://go.dev/dl/"
      return 1
    fi
    refresh_gobin
    hash -r
    command -v go >/dev/null 2>&1 || { error "Go masih tidak terdeteksi — buka terminal baru lalu ulangi."; return 1; }
  fi
  mkdir -p "$GOBIN"
  step "go install ${src}@latest ..."
  if ! go install "${src}@latest" >/dev/null 2>&1; then
    error "go install $name gagal — cek koneksi internet / versi Go (min 1.21)."
    return 1
  fi
  if [ "$name" = "nuclei" ]; then
    "$GOBIN/nuclei" -update-templates >/dev/null 2>&1 || "$GOBIN/nuclei" -ut >/dev/null 2>&1 || true
  fi
  return 0
}

install_pip() {
  local id="$1" name src
  name="${R_NAME[$id]}"; src="${R_SRC[$id]}"
  if ! command -v pip3 >/dev/null 2>&1; then
    warn "pip3 belum ada — install python3-pip dulu..."
    case "$PM" in
      apt)    $SUDO apt-get install -y -qq python3-pip >/dev/null 2>&1 ;;
      dnf)    $SUDO dnf install -y python3-pip        >/dev/null 2>&1 ;;
      pacman) $SUDO pacman -S --noconfirm python-pip  >/dev/null 2>&1 ;;
      pkg)    pkg install -y python-pip               >/dev/null 2>&1 ;;
      brew)   brew install python                     >/dev/null 2>&1 ;;
    esac
    hash -r
    command -v pip3 >/dev/null 2>&1 || { error "pip3 tidak tersedia — install manual."; return 1; }
  fi
  pip3 install --user -q "$src" >/dev/null 2>&1 && return 0
  pip3 install --user --break-system-packages -q "$src" >/dev/null 2>&1 && return 0
  command -v pipx >/dev/null 2>&1 && pipx install "$src" >/dev/null 2>&1 && return 0
  error "pip install $name gagal."
  return 1
}

install_git() {
  local id="$1" src dest
  src="${R_SRC[$id]}"
  command -v git >/dev/null 2>&1 || { error "git belum terpasang — install lewat menu no 20."; return 1; }
  dest="$TOOLS_DIR/$(basename "$src" .git)"
  mkdir -p "$TOOLS_DIR"
  step "git clone $src -> $dest"
  rm -rf "$dest"
  if ! git clone --depth 1 "$src" "$dest" >/dev/null 2>&1; then
    error "git clone gagal — cek koneksi internet."
    return 1
  fi
  chmod +x "$dest"/*.sh 2>/dev/null
  if [ "$(id -u)" -eq 0 ] || [ -w /usr/local/bin ]; then
    ln -sf "$dest/testssl.sh" /usr/local/bin/testssl.sh 2>/dev/null
  else
    warn "Tambahkan ke PATH: export PATH=\"\$PATH:$dest\""
  fi
  return 0
}

install_dl() {
  local id="$1" src dest
  src="${R_SRC[$id]}"
  command -v curl >/dev/null 2>&1 || { error "curl belum terpasang — install lewat menu no 13."; return 1; }
  case "${R_NAME[$id]}" in
    wordlist) dest="$HOME/.wordlist/dirs.txt" ;;
    *)        dest="$TOOLS_DIR/$(basename "$src")" ;;
  esac
  mkdir -p "$(dirname "$dest")"
  step "download $src"
  if ! curl -sL --max-time 120 "$src" -o "$dest" >/dev/null 2>&1 || [ ! -s "$dest" ]; then
    error "download gagal — cek koneksi internet."
    rm -f "$dest" 2>/dev/null
    return 1
  fi
  info "Tersimpan: $dest"
  return 0
}

# ── Tampilkan PATH hint ke ~/.bashrc (sekali saja) ──
path_hint() {
  local add="" rc
  case ":$PATH:" in *":$GOBIN:"*) ;; *) add="$GOBIN" ;; esac
  if [ -x "$TOOLS_DIR/testssl.sh/testssl.sh" ]; then
    case ":$PATH:" in *":$TOOLS_DIR/testssl.sh:"*) ;; *) add="${add:+$add:}$TOOLS_DIR/testssl.sh" ;; esac
  fi
  [ -z "$add" ] && return 0
  rc="$HOME/.bashrc"
  if ! grep -q "RECON installer" "$rc" 2>/dev/null; then
    {
      echo ""
      echo "# RECON installer (andisec/reconsec)"
      echo "export PATH=\"\$PATH:$add\""
    } >> "$rc"
    warn "PATH baru ditambahkan ke ~/.bashrc — jalankan: source ~/.bashrc"
  fi
}

# ── Menu & status ──
count_installed() {
  local id n=0
  for id in $(seq 1 "$MAX_ID"); do
    [ -z "${R_NAME[$id]:-}" ] && continue
    check_tool "$id" && n=$((n+1))
  done
  echo "$n"
}

count_total() {
  local id n=0
  for id in $(seq 1 "$MAX_ID"); do
    [ -n "${R_NAME[$id]:-}" ] && n=$((n+1))
  done
  echo "$n"
}

show_group() {
  local title="$1" grp="$2" id st name col
  printf '%s  -- %s --%s\n' "$BOLD" "$title" "$NC"
  for id in $(seq 1 "$MAX_ID"); do
    [ "${R_GROUP[$id]:-}" = "$grp" ] || continue
    name="${R_NAME[$id]}"
    if check_tool "$id"; then
      st="${GREEN}+${NC}"; col="$GREEN"
    else
      st="${RED}-${NC}"; col="$NC"
    fi
    printf '  [%s] %s%-3s %-13s%s %s\n' "$st" "$col" "$id." "$name" "$NC" "${R_DESC[$id]}"
  done
  printf '\n'
}

show_menu() {
  printf '\n%s============================================================%s\n' "$MAGENTA" "$NC"
  printf '  %sRECON INSTALLER%s v%s  —  github.com/andisec/reconsec\n' "$BOLD" "$NC" "$VERSION"
  printf '%s============================================================%s\n' "$MAGENTA" "$NC"
  printf '  Sistem : %s\n' "$DISTRO"
  if command -v go >/dev/null 2>&1; then
    printf '  Go     : %s OK %s (%s)\n' "$GREEN" "$NC" "$(go version 2>/dev/null | awk '{print $3}')"
  else
    printf '  Go     : %s belum terpasang%s (auto-install saat pilih tools Go)\n' "$RED" "$NC"
  fi
  printf '  Status : %s%s/%s%s tools terpasang\n' "$GREEN" "$(count_installed)" "$(count_total)" "$NC"
  printf '%s============================================================%s\n\n' "$MAGENTA" "$NC"
  show_group 'GO TOOLS (go install)'         'go'
  show_group 'SYSTEM / PACKAGE MANAGER'      'sys'
  show_group 'EXTRA (pip / git / download)' 'extra'
  printf '%s  -- AKSI --%s\n' "$BOLD" "$NC"
  printf '   0  all     install SEMUA sekaligus\n'
  printf '   c  check   lihat status detail semua tools\n'
  printf '   q  quit    keluar\n'
}

show_check() {
  local id st
  printf '\n  %-4s %-14s %-6s %s\n' "ID" "TOOL" "TYPE" "STATUS"
  printf '  %s\n' "--------------------------------------------------"
  for id in $(seq 1 "$MAX_ID"); do
    [ -z "${R_NAME[$id]:-}" ] && continue
    if check_tool "$id"; then
      st="${GREEN}TERPASANG${NC}"
    else
      st="${RED}BELUM${NC}"
    fi
    printf '  %-4s %-14s %-6s %s\n' "$id" "${R_NAME[$id]}" "${R_CAT[$id]}" "$st"
  done
  printf '\n  Total: %s/%s terpasang\n\n' "$(count_installed)" "$(count_total)"
}

# ── Parser input: "1 2 5-8" / "all" / "q" ──
parse_sel() {
  local raw="$1" tok out="" a b i
  raw="${raw//,/ }"
  for tok in $raw; do
    case "$tok" in
      all|ALL|a|A|0) echo "ALL";  return 0 ;;
      q|Q|quit|exit) echo "QUIT"; return 0 ;;
      *-*)
        a="${tok%%-*}"; b="${tok##*-}"
        if [ "$a" -ge 1 ] 2>/dev/null && [ "$b" -ge "$a" ] 2>/dev/null; then
          i=$a
          while [ "$i" -le "$b" ]; do out="$out $i"; i=$((i+1)); done
        else
          warn "Range tidak valid: $tok"
        fi ;;
      *)
        if [ "$tok" -gt 0 ] 2>/dev/null; then
          out="$out $tok"
        else
          warn "Input tidak dikenal: $tok"
        fi ;;
    esac
  done
  echo "$out"
}

# ── Jalankan install per ID + ringkasan hasil ──
install_ids() {
  local ids="$1" id ok=0 skip=0 fail=0 failed=""
  for id in $ids; do
    if [ -z "${R_NAME[$id]:-}" ]; then
      warn "ID '$id' tidak ada di daftar — dilewati"
      continue
    fi
    if check_tool "$id"; then
      skip=$((skip+1))
      info "[$id] ${R_NAME[$id]} sudah terpasang — skip"
      continue
    fi
    step "Install [$id] ${R_NAME[$id]} ..."
    case "${R_CAT[$id]}" in
      pkg) install_pkg "$id" && ok=$((ok+1)) || { fail=$((fail+1)); failed="$failed ${R_NAME[$id]}"; } ;;
      go)  install_go  "$id" && ok=$((ok+1)) || { fail=$((fail+1)); failed="$failed ${R_NAME[$id]}"; } ;;
      pip) install_pip "$id" && ok=$((ok+1)) || { fail=$((fail+1)); failed="$failed ${R_NAME[$id]}"; } ;;
      git) install_git "$id" && ok=$((ok+1)) || { fail=$((fail+1)); failed="$failed ${R_NAME[$id]}"; } ;;
      dl)  install_dl  "$id" && ok=$((ok+1)) || { fail=$((fail+1)); failed="$failed ${R_NAME[$id]}"; } ;;
    esac
  done
  printf '\n%s------------------------------------------------------------%s\n' "$MAGENTA" "$NC"
  printf '  Hasil: %s%s OK%s · %s%s skip%s · %s%s gagal%s\n' \
    "$GREEN" "$ok" "$NC" "$CYAN" "$skip" "$NC" "$RED" "$fail" "$NC"
  [ -n "$failed" ] && warn "Gagal install:$failed — cek koneksi internet atau install manual."
  printf '%s------------------------------------------------------------%s\n\n' "$MAGENTA" "$NC"
}

# ── Mode interaktif ──
interactive() {
  local sel ids
  while true; do
    show_menu
    if ! read -rp "${CYAN}[?]${NC} Pilih nomor (mis. 1 2 5-8 / 0=all / q=keluar): " sel; then
      printf '\n'
      break
    fi
    [ -z "$sel" ] && continue
    case "$sel" in
      c|C|check) show_check; continue ;;
    esac
    ids="$(parse_sel "$sel")"
    [ -z "$ids" ] && continue
    case "$ids" in
      QUIT) break ;;
      ALL)  ids="$(seq -s ' ' 1 "$MAX_ID")" ;;
    esac
    install_ids "$ids"
    printf '%s Tekan ENTER untuk kembali ke menu (atau Ctrl+C untuk keluar)...%s' "$CYAN" "$NC"
    read -r _junk
    printf '\n'
  done
  path_hint
  info "Selesai! Sekarang jalankan: bash recon.sh"
}

show_help() {
  cat <<EOF
RECON INSTALLER v$VERSION — github.com/andisec/reconsec

Pemakaian:
  ./install.sh                Menu interaktif — pilih nomor tools
  ./install.sh 1 2 5-8        Install langsung ID tersebut
  ./install.sh --all          Install SEMUA tools
  ./install.sh --check        Cek status tools tanpa install
  ./install.sh --help         Bantuan ini

Contoh:
  ./install.sh 1 2 3          # install nuclei, subfinder, httpx
  ./install.sh 1-8            # install semua Go tools
  ./install.sh 12 13 14 15    # install golang, curl, jq, nmap

Environment:
  REQ_FILE=path/requirements.txt   File daftar tools (default: samping install.sh)
  TOOLS_DIR=\$HOME/tools           Folder clone (testssl.sh, dll)

Catatan:
  - Tools bernomor sesuai requirements.txt (id|name|category|source|desc)
  - Tool yang sudah terpasang otomatis di-skip
  - HANYA untuk pengujian keamanan yang berizin!
EOF
}

# ── Main ──
main() {
  detect_os
  load_registry
  refresh_gobin
  case "${1:-}" in
    -h|--help)
      show_help; exit 0 ;;
    -c|--check)
      show_check; exit 0 ;;
    -v|--version)
      echo "recon-install v$VERSION (andisec/reconsec)"; exit 0 ;;
    -a|--all|all)
      install_ids "$(seq -s ' ' 1 "$MAX_ID")"
      path_hint
      info "Selesai! Sekarang jalankan: bash recon.sh"
      exit 0 ;;
    -*)
      error "Opsi tidak dikenal: $1 (lihat --help)"; exit 1 ;;
    "")
      interactive ;;
    *)
      install_ids "$*"
      path_hint
      info "Selesai! Sekarang jalankan: bash recon.sh" ;;
  esac
}

main "$@"
