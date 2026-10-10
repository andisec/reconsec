#!/usr/bin/env bash
# ============================================================================
#   R E C O N  —  Full Auto Recon Tool v4.0.1 PRO (31 Fitur)
#   Gunakan HANYA untuk target yang kamu punya izin resmi
#   (bug bounty program / pentest yang terkontrak). Bertanggung jawab bro!
#
#   CLI MODE (untuk cron/otomasi):
#     ./recon.sh --auto  example.com   (full auto scan 1 domain)
#     ./recon.sh --batch targets.txt   (full auto scan banyak domain)
# ============================================================================

VERSION="4.0.1"
RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'
CYAN=$'\033[0;36m'; MAGENTA=$'\033[0;35m'; NC=$'\033[0m'

# ------------------------- CONFIG -------------------------
THREADS=40
FFUF_THREADS=50
NMAP_RATE=1000
WORDLIST="$HOME/.wordlist/dirs.txt"
CONF_FILE="$HOME/recon.conf"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) ReconTool/4.0"
JS_LIMIT=50          # max file JS yang di-download utk secret scan
PARAM_URL_LIMIT=5   # max live URL utk param fuzzing
CORS_URL_LIMIT=20   # max live URL utk CORS check
HDR_URL_LIMIT=20    # max live URL utk security headers audit
VHOST_TARGETS=800   # max kata utk vhost fuzzing
# API keys (diisi otomatis dari recon.conf)
CHAOS_KEY=""; SHODAN_KEY=""; CENSYS_ID=""; CENSYS_SECRET=""; HUNTER_KEY=""

# ------------------------- STATE -------------------------
TARGET=""
BASE_DIR=""
LOG_FILE=""
START_TIME=""
STEPS_OK=0
STEPS_FAIL=0
FAILED_STEPS=""
WAF_NAME="Tidak terdeteksi"

# ------------------------- UTIL -------------------------
now() { date '+%H:%M:%S'; }

cnt() { local c; c=$(grep -c . "$1" 2>/dev/null); echo "${c:-0}"; }

banner() {
clear
echo -e "${RED}"
cat << 'EOF'
  ___  _____  _    _    __    ___  ____  ___
 / __)(  _  )( \/\/ )  /__\  / __)( ___)/ __)
( (_-. )(_)(  )    (  /(__)\ \__ \ )__)( (__ 
 \___/(_____)(__/\__)(__)(__)(___/(____)\___)
EOF
echo -e "${NC}"
echo -e "${CYAN} [+] Full Auto Recon Tool v$VERSION PRO — authorized pentest only [+]"
echo -e "${CYAN} [+] Gunakan hanya pada target yang kamu punya izin legal!   [+]"
echo ""
}

info()    { echo -e "${GREEN}[+]${NC} $(now) $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $(now) $1"; }
error()   { echo -e "${RED}[-]${NC} $(now) $1"; }
step()    { echo ""; echo -e "${MAGENTA}============================================================${NC}"; echo -e "${MAGENTA}  >> ${1}${NC}"; echo -e "${MAGENTA}============================================================${NC}"; }
section() { echo ""; echo -e "${BLUE}[*]${NC} $1"; }

mark_ok()   { STEPS_OK=$((STEPS_OK+1)); }
mark_fail() { STEPS_FAIL=$((STEPS_FAIL+1)); FAILED_STEPS="$FAILED_STEPS\n    - $1"; }

run_logged() {
  local desc="$1"; shift
  info "$desc ..."
  if "$@" >> "$LOG_FILE" 2>&1; then
    info "$desc — ${GREEN}OK${NC}"
    return 0
  else
    warn "$desc — selesai dengan warning/skip"
    return 1
  fi
}

valid_domain() {
  echo "$1" | grep -qE '^([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$'
}

init_target() {
  TARGET="$1"
  STEPS_OK=0; STEPS_FAIL=0; FAILED_STEPS=""
  WAF_NAME="Tidak terdeteksi"
  BASE_DIR="recon_results/$TARGET-$(date '+%Y%m%d_%H%M%S')"
  mkdir -p "$BASE_DIR"
  LOG_FILE="$BASE_DIR/recon.log"
  START_TIME=$(date '+%Y-%m-%d %H:%M:%S')
  touch "$LOG_FILE"
  info "Target     : ${GREEN}$TARGET${NC}"
  info "Output dir : $BASE_DIR"
}

setup_target() {
  local input
  read -rp "${CYAN}[?]${NC} Masukkan domain target (cth: example.com): " input
  input=$(echo "$input" | sed 's|https\?://||; s|/.*||; s|^www\.||' | tr -d '[:space:]')
  if [ -z "$input" ]; then
    error "Target kosong! Ulangi."
    return 1
  fi
  if ! valid_domain "$input"; then
    error "Format domain tidak valid: $input"
    return 1
  fi
  init_target "$input"
  return 0
}

# ------------------------- CONFIG FILE -------------------------
load_config() {
  if [ -f "$CONF_FILE" ]; then
    # shellcheck source=/dev/null
    . "$CONF_FILE" 2>/dev/null || warn "recon.conf ada tapi gagal dibaca"
    info "Config dimuat: $CONF_FILE"
  fi
}

config_setup() {
  step "[FITUR 31] Setup Config File (recon.conf)"
  info "Tekan ENTER saja kalau tidak punya / tidak mau pakai API key."
  local chaos shodan censys_id censys_secret hunter threads fthreads wordlist
  read -rp "Chaos API key (https://chaos.projectdiscovery.io): " chaos
  read -rp "Shodan API key: " shodan
  read -rp "Censys API ID: " censys_id
  read -rp "Censys API Secret: " censys_secret
  read -rp "Hunter.io API key: " hunter
  read -rp "Threads scan default [$THREADS]: " threads
  read -rp "ffuf threads default [$FFUF_THREADS]: " fthreads
  read -rp "Path wordlist directory [$WORDLIST]: " wordlist

  {
    echo "# RECON config — dibuat $(date)"
    echo "CHAOS_KEY=\"$chaos\""
    echo "SHODAN_KEY=\"$shodan\""
    echo "CENSYS_ID=\"$censys_id\""
    echo "CENSYS_SECRET=\"$censys_secret\""
    echo "HUNTER_KEY=\"$hunter\""
    [ -n "$threads" ] && echo "THREADS=$threads"
    [ -n "$fthreads" ] && echo "FFUF_THREADS=$fthreads"
    [ -n "$wordlist" ] && echo "WORDLIST=\"$wordlist\""
  } > "$CONF_FILE"

  # terapkan langsung di sesi ini
  CHAOS_KEY="$chaos"; SHODAN_KEY="$shodan"; CENSYS_ID="$censys_id"
  CENSYS_SECRET="$censys_secret"; HUNTER_KEY="$hunter"
  [ -n "$threads" ] && THREADS="$threads"
  [ -n "$fthreads" ] && FFUF_THREADS="$fthreads"
  [ -n "$wordlist" ] && WORDLIST="$wordlist"

  # tulis provider config untuk subfinder (passive source makin banyak)
  if [ -n "$chaos" ] || [ -n "$shodan" ] || [ -n "$censys_id" ]; then
    mkdir -p "$HOME/.config/subfinder"
    {
      echo "# provider config RECON"
      [ -n "$chaos" ] && { echo "chaos:"; echo "  - $chaos"; }
      [ -n "$shodan" ] && { echo "shodan:"; echo "  - $shodan"; }
      [ -n "$censys_id" ] && { echo "censys:"; echo "  - $censys_id:$censys_secret"; }
    } > "$HOME/.config/subfinder/provider-config.yaml"
    info "subfinder provider-config.yaml dibuat — subdomain makin banyak hasilnya"
  fi
  info "Config tersimpan: ${GREEN}$CONF_FILE${NC}"
  return 0
}

# ------------------------- DEPENDENCIES -------------------------
TOOLS_CORE=(curl jq nmap whois dig whatweb openssl unzip)

check_and_install_core() {
  section "Cek & install tool inti ..."
  for pkg in "${TOOLS_CORE[@]}"; do
    if ! command -v "$pkg" &>/dev/null; then
      warn "$pkg belum ada, mencoba install ..."
      if command -v apt &>/dev/null; then
        sudo apt-get install -y "$pkg" &>/dev/null || warn "gagal install $pkg (apt)"
      else
        warn "$pkg tidak ditemukan & apt tidak tersedia. Install manual!"
      fi
    else
      info "$pkg ${GREEN}OK${NC}"
    fi
  done
}

install_go_tools() {
  if ! command -v go &>/dev/null; then
    warn "Golang tidak ada — install dulu: https://go.dev/dl/ (script lanjut tanpa tool GO)"
    return 1
  fi
  section "Install/update tool berbasis Go ..."
  run_logged "subfinder"    go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
  run_logged "assetfinder"  go install -v github.com/tomnomnom/assetfinder@latest
  run_logged "httpx"        go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest
  run_logged "dnsx"         go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest
  run_logged "waybackurls"  go install -v github.com/tomnomnom/waybackurls@latest
  run_logged "ffuf"         go install -v github.com/ffuf/ffuf/v2@latest
  run_logged "nuclei"       go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
  run_logged "gowitness"   go install -v github.com/sensepost/gowitness@latest
  run_logged "dalfox"      go install -v github.com/hahwul/dalfox/v2@latest
  run_logged "alterx"      go install -v github.com/projectdiscovery/alterx/cmd/alterx@latest
  if [ -d "$HOME/go/bin" ]; then
    export PATH="$PATH:$HOME/go/bin"
  fi
}

ensure_wordlist() {
  if [ ! -s "$WORDLIST" ]; then
    warn "Wordlist tidak ada, download default (SecLists common.txt) ..."
    mkdir -p "$(dirname "$WORDLIST")"
    curl -sL "https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/common.txt" \
      -o "$WORDLIST" 2>/dev/null || { touch "$WORDLIST"; warn "gagal download wordlist, pakai file kosong"; }
  fi
}

# ------------------------- FITUR 2: SUBDOMAIN ENUM -------------------------
enum_subdomains() {
  step "[FITUR 2] Enumerasi Subdomain"
  local out="$BASE_DIR/subdomains"
  mkdir -p "$out"

  if command -v subfinder &>/dev/null; then
    run_logged "subfinder" subfinder -d "$TARGET" -silent -all -o "$out/sub_subfinder.txt" || mark_fail "subfinder"
  else warn "subfinder skip (belum terpasang)"; fi

  if command -v assetfinder &>/dev/null; then
    assetfinder --subs-only "$TARGET" > "$out/sub_assetfinder.txt" 2>/dev/null \
      && info "assetfinder — ${GREEN}OK${NC}" || warn "assetfinder warning/skip"
  else warn "assetfinder skip (belum terpasang)"; fi

  info "crt.sh (certificate transparency) ..."
  curl -s --max-time 60 "https://crt.sh/?q=%25.$TARGET&output=json" 2>/dev/null \
    | jq -r '.[].name_value' 2>/dev/null \
    | sed 's/\*\.//g' | sort -u > "$out/sub_crtsh.txt" || warn "crt.sh gagal/timeout"

  info "hackertarget ..."
  curl -s --max-time 30 "https://api.hackertarget.com/hostsearch/?q=$TARGET" 2>/dev/null \
    | cut -d',' -f1 | grep "\.$TARGET$" | sort -u > "$out/sub_hackertarget.txt" || warn "hackertarget gagal"

  if [ -n "$CHAOS_KEY" ]; then
    info "Chaos API (karena API key terpasang) ..."
    curl -s --max-time 60 -H "Authorization: $CHAOS_KEY" \
      "https://dns.projectdiscovery.io/dns/$TARGET/subdomains" 2>/dev/null \
      | jq -r '.subdomains[]' 2>/dev/null | sed "s/$/.$TARGET/" | sort -u > "$out/sub_chaos.txt" \
      || warn "Chaos API gagal"
  fi

  cat "$out"/sub_*.txt 2>/dev/null | sort -u > "$out/all_subdomains.txt"
  local count
  count=$(cnt "$out/all_subdomains.txt")
  info "Total subdomain ditemukan: ${GREEN}$count${NC}"
  [ "$count" -gt 0 ] && mark_ok || mark_fail "enum subdomain (0 hasil)"
  return 0
}

# ------------------------- FITUR 23: SUBDOMAIN PERMUTATION -------------------------
subdomain_permutation() {
  step "[FITUR 23] Subdomain Permutation (cari subdomain tersembunyi)"
  local out="$BASE_DIR/subdomains"
  local subs="$out/all_subdomains.txt"
  mkdir -p "$out/perm"

  [ -s "$subs" ] || { error "tidak ada subdomain, jalankan fitur 2 dulu"; mark_fail "permutation (tanpa subdomain)"; return 1; }

  local perms="$out/perm/permutations.txt"
  if command -v alterx &>/dev/null; then
    info "alterx generate permutasi dari subdomain yang ada ..."
    alterx -l "$subs" -o "$perms" >> "$LOG_FILE" 2>&1 || warn "alterx warning"
  else
    warn "alterx tidak ada — fallback generator manual (dependency-free)"
    : > "$perms"
    local prefixes=(dev development stage staging test testing uat prod production api admin internal intranet beta demo pre qa old backup bak archive vpn mail portal app dashboard monitoring grafana jenkins ci cd git lab s3 storage cdn static img images video media ws socket chat shop store pay payment billing login auth sso id account profile user users forum blog news wiki docs status)
    for p in "${prefixes[@]}"; do
      echo "$p.$TARGET" >> "$perms"
      echo "www-$p.$TARGET" >> "$perms"
      echo "$p-api.$TARGET" >> "$perms"
    done
    # permutasi dari subdomain yang sudah ada (x.target -> dev-x.target, x-dev.target)
    while read -r sub; do
      local first
      first=$(echo "$sub" | cut -d. -f1)
      [ "$first" = "$sub" ] && continue
      echo "dev-$sub" >> "$perms"
      echo "$first-dev.$TARGET" >> "$perms"
      echo "$first-staging.$TARGET" >> "$perms"
    done < "$subs"
    sort -u "$perms" -o "$perms" 2>/dev/null
  fi

  info "Resolve $(cnt "$perms") kandidat ..."
  local newsubs="$out/perm/new_subdomains.txt"
  if command -v dnsx &>/dev/null; then
    dnsx -l "$perms" -silent -a -o "$out/perm/resolved_all.txt" >> "$LOG_FILE" 2>&1 \
      || warn "dnsx warning"
    cut -d' ' -f1 "$out/perm/resolved_all.txt" 2>/dev/null | grep "\.$TARGET$" | sort -u > "$newsubs" 2>/dev/null
  else
    warn "dnsx tidak ada — fallback dig (agak lama, sabar)"
    : > "$out/perm/resolved_all.txt"
    : > "$newsubs"
    local i=0
    while read -r c; do
      i=$((i+1))
      [ $((i % 25)) -eq 0 ] && info "  progress: $i / $(cnt "$perms")"
      a=$(dig +short A "$c" @1.1.1.1 2>/dev/null | head -1)
      if [ -n "$a" ]; then
        echo "$c [$a]" >> "$out/perm/resolved_all.txt"
        echo "$c" >> "$newsubs"
      fi
    done < "$perms"
    sort -u "$newsubs" -o "$newsubs" 2>/dev/null
  fi

  # gabung yang baru (belum ada di daftar) ke all_subdomains.txt
  local brand_new
  brand_new=$(comm -13 <(sort -u "$subs" 2>/dev/null) <(sort -u "$newsubs" 2>/dev/null))
  if [ -n "$brand_new" ]; then
    echo "$brand_new" >> "$subs"
    sort -u "$subs" -o "$subs"
    local n
    n=$(echo "$brand_new" | grep -c .)
    info "Subdomain BARU dari permutation: ${YELLOW}$n${NC} (sudah digabung ke all_subdomains.txt)"
  else
    info "Tidak ada subdomain baru dari permutation."
  fi
  info "Total sekarang: $(cnt "$subs")"
  mark_ok
  return 0
}

# ------------------------- FITUR 3: LIVE HOST / HTTP PROBE -------------------------
probe_live() {
  step "[FITUR 3] Deteksi Live Host (HTTP Probing)"
  local out="$BASE_DIR/live"
  mkdir -p "$out"
  local subs="$BASE_DIR/subdomains/all_subdomains.txt"

  [ -s "$subs" ] || { error "tidak ada list subdomain, jalankan fitur 2 dulu"; mark_fail "probe live (tanpa subdomain)"; return 1; }

  if command -v httpx &>/dev/null; then
    run_logged "httpx probing" httpx -l "$subs" -silent -status-code -title \
      -tech-detect -content-length -follow-redirects -timeout 15 -threads "$THREADS" \
      -o "$out/live_hosts.txt" || mark_fail "httpx"
  else
    warn "httpx tidak ada — fallback curl sederhana"
    : > "$out/live_hosts.txt"
    while read -r s; do
      code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 -A "$USER_AGENT" "https://$s" 2>/dev/null)
      [ "$code" != "000" ] && echo "[https://$s] [$code]" >> "$out/live_hosts.txt"
    done < "$subs"
  fi

  local count
  count=$(cnt "$out/live_hosts.txt")
  info "Live host: ${GREEN}$count${NC}"
  grep -oE 'https?://[^ ]+' "$out/live_hosts.txt" 2>/dev/null | sort -u > "$out/live_urls.txt"
  [ "$count" -gt 0 ] && mark_ok || mark_fail "probe live (0 hasil)"
  return 0
}

# ------------------------- FITUR 22: WAF DETECTION -------------------------
waf_detect() {
  step "[FITUR 22] WAF Detection ( + auto-adjust rate scan )"
  local out="$BASE_DIR/waf"
  mkdir -p "$out"
  local urls="$BASE_DIR/live/live_urls.txt"

  if [ ! -s "$urls" ]; then
    warn "tidak ada live host — WAF check di main domain saja"
    : > "$urls"
    echo "https://$TARGET" > "$urls"
  fi

  : > "$out/waf_detected.txt"
  if command -v wafw00f &>/dev/null; then
    while read -r url; do
      wafw00f -a "$url" 2>/dev/null | grep -iE 'is behind|waf' | head -3 >> "$out/waf_detected.txt"
    done < <(head -n 5 "$urls")
  else
    warn "wafw00f tidak ada — fallback header fingerprint (dependency-free)"
    local i=0
    while read -r url; do
      [ "$i" -ge 5 ] && break
      i=$((i+1))
      local hdrs waf
      hdrs=$(curl -s -D - -o /dev/null --max-time 10 -A "$USER_AGENT" "$url" 2>/dev/null)
      waf=""
      echo "$hdrs" | grep -qi 'cf-ray\|cloudflare'                 && waf="Cloudflare"
      echo "$hdrs" | grep -qi 'x-akamai\|akamaighost'              && waf="Akamai"
      echo "$hdrs" | grep -qi 'x-sucuri\|sucuri'                   && waf="Sucuri"
      echo "$hdrs" | grep -qi 'x-iinfo\|imperva\|incapsula'       && waf="Imperva/Incapsula"
      echo "$hdrs" | grep -qi 'mod_security\|modsecurity'         && waf="ModSecurity"
      echo "$hdrs" | grep -qi 'x-cdn\|edgecast\|firebase'         && waf="CDN/Edge"
      if [ -n "$waf" ]; then
        echo "$url -> $waf" >> "$out/waf_detected.txt"
        warn "WAF terdeteksi: $waf di $url"
      fi
    done < "$urls"
  fi

  if [ -s "$out/waf_detected.txt" ]; then
    WAF_NAME=$(head -1 "$out/waf_detected.txt" | grep -oE '[A-Za-z/]+$' | head -1)
    WAF_NAME=${WAF_NAME:-Terdeteksi}
    warn "WAF AKTIF ($WAF_NAME) — rate scan otomatis DITURUNKAN biar tidak diblokir:"
    warn "  threads: $THREADS -> 10 | ffuf: $FFUF_THREADS -> 10 | nmap rate: $NMAP_RATE -> 300"
    THREADS=10; FFUF_THREADS=10; NMAP_RATE=300
  else
    info "WAF tidak terdeteksi — rate scan normal"
  fi
  mark_ok
  return 0
}

# ------------------------- FITUR 20: SECURITY HEADERS AUDIT -------------------------
security_headers() {
  step "[FITUR 20] Security Headers Audit (grade A-F)"
  local out="$BASE_DIR/headers"
  mkdir -p "$out"
  local urls="$BASE_DIR/live/live_urls.txt"

  [ -s "$urls" ] || { error "tidak ada live host, jalankan fitur 3 dulu"; mark_fail "headers (tanpa live host)"; return 1; }

  info "Audit 6 security header di $HDR_URL_LIMIT host pertama ..."
  : > "$out/headers_audit.txt"
  : > "$out/headers_grade_f.txt"
  local i=0
  while read -r url; do
    [ "$i" -ge "$HDR_URL_LIMIT" ] && break
    i=$((i+1))
    local hdrs score missing grade
    hdrs=$(curl -s -D - -o /dev/null --max-time 10 -A "$USER_AGENT" -L "$url" 2>/dev/null)
    score=0; missing=""
    for h in Strict-Transport-Security Content-Security-Policy X-Content-Type-Options X-Frame-Options Referrer-Policy Permissions-Policy; do
      if echo "$hdrs" | grep -qi "^$h:"; then
        score=$((score+1))
      else
        missing="$missing $h"
      fi
    done
    case $score in
      6) grade="A" ;; 5) grade="B" ;; 4) grade="C" ;;
      3) grade="D" ;; 2) grade="E" ;; *) grade="F" ;;
    esac
    echo "$url | grade $grade | score $score/6 | missing:$missing" >> "$out/headers_audit.txt"
    { [ "$grade" = "F" ] || [ "$grade" = "E" ]; } && echo "$url (grade $grade)" >> "$out/headers_grade_f.txt"
  done < "$urls"

  local bad
  bad=$(cnt "$out/headers_grade_f.txt")
  info "Audit selesai. Host grade E/F (header sangat lemah): ${YELLOW}$bad${NC}"
  head -10 "$out/headers_audit.txt"
  mark_ok
  return 0
}

# ------------------------- FITUR 4: PORT SCAN -------------------------
port_scan() {
  step "[FITUR 4] Port Scanning"
  local out="$BASE_DIR/ports"
  mkdir -p "$out"
  local subs="$BASE_DIR/subdomains/all_subdomains.txt"

  if ! command -v nmap &>/dev/null; then
    error "nmap tidak tersedia — install: sudo apt install nmap"; mark_fail "port scan (nmap hilang)"; return 1
  fi
  [ -s "$subs" ] || { error "tidak ada subdomain, jalankan fitur 2 dulu"; mark_fail "port scan (tanpa subdomain)"; return 1; }

  local total
  total=$(cnt "$subs")
  if [ "$total" -gt 300 ]; then
    warn "subdomain banyak ($total) — scan hanya top 300 biar hemat waktu"
    head -300 "$subs" > "$out/scan_targets.txt"
  else
    cp "$subs" "$out/scan_targets.txt"
  fi

  info "nmap top-1000 port (rate: $NMAP_RATE) ..."
  if nmap -iL "$out/scan_targets.txt" --top-ports 1000 -T4 --open \
       -Pn --max-rate "$NMAP_RATE" -oA "$out/nmap_result" >> "$LOG_FILE" 2>&1; then
    info "Port scan — ${GREEN}OK${NC} (hasil: $out/nmap_result.nmap)"
    grep -oE '[0-9]+/open/tcp' "$out/nmap_result.gnmap" 2>/dev/null | sort -u | head -30
    mark_ok
  else
    warn "nmap selesai dengan warning (cek log)"; mark_fail "port scan"
  fi
  return 0
}

# ------------------------- FITUR 5: DIRECTORY BRUTE FORCE -------------------------
dir_brute() {
  step "[FITUR 5] Directory & File Brute Force"
  local out="$BASE_DIR/dirs"
  mkdir -p "$out"
  local urls="$BASE_DIR/live/live_urls.txt"

  if ! command -v ffuf &>/dev/null; then
    error "ffuf tidak tersedia — install via go install"; mark_fail "dir brute (ffuf hilang)"; return 1
  fi
  [ -s "$urls" ] || { error "tidak ada live host, jalankan fitur 3 dulu"; mark_fail "dir brute (tanpa live host)"; return 1; }
  ensure_wordlist

  local max_hosts
  max_hosts=$(cnt "$urls")
  if [ "$max_hosts" -gt 20 ]; then
    max_hosts=20
    warn "live host > 20, scan hanya 20 pertama biar tidak kemalaman"
  fi

  local i=0
  while read -r url; do
    [ "$i" -ge "$max_hosts" ] && break
    i=$((i+1))
    local host
    host=$(echo "$url" | sed 's|https\?://||; s|/.*||; s|:.*||')
    info "ffuf: $url (host $i/$max_hosts)"
    ffuf -u "$url/FUZZ" -w "$WORDLIST" -mc 200,204,301,302,307,401,403 \
        -t "$FFUF_THREADS" -timeout 15 -k -ac -of csv \
        -o "$out/dir_${host//./_}.csv" >> "$LOG_FILE" 2>&1 \
      && info "  ${GREEN}$host${NC} selesai" \
      || warn "  $host selesai dengan warning"
  done < "$urls"
  mark_ok
  return 0
}

# ------------------------- FITUR 6: WAYBACK / JS & PARAMETER -------------------------
wayback_extract() {
  step "[FITUR 6] Wayback URL, JS & Parameter Extraction"
  local out="$BASE_DIR/wayback"
  mkdir -p "$out"

  if command -v waybackurls &>/dev/null; then
    waybackurls "$TARGET" > "$out/wayback_all.txt" 2>/dev/null \
      && info "waybackurls — ${GREEN}OK${NC}" || warn "waybackurls warning"
  else
    warn "waybackurls tidak ada — fallback ke archive.org API"
    curl -s --max-time 120 "http://web.archive.org/cdx/search/cdx?url=*.$TARGET/*&output=text&fl=original&collapse=urlkey" \
      > "$out/wayback_all.txt" 2>/dev/null || warn "archive.org fallback gagal"
  fi

  if [ -s "$out/wayback_all.txt" ]; then
    grep -iE '\.js($|\?)' "$out/wayback_all.txt" | sort -u > "$out/js_files.txt"
    grep -E '\?.*='   "$out/wayback_all.txt" | sort -u > "$out/with_params.txt"
    grep -oE '\?[a-zA-Z0-9_\-]+=' "$out/wayback_all.txt" | sort -u > "$out/param_names.txt"
    info "Total wayback URL : $(cnt "$out/wayback_all.txt")"
    info "File JS           : $(cnt "$out/js_files.txt")"
    info "URL dengan param  : $(cnt "$out/with_params.txt")"
    mark_ok
  else
    warn "wayback kosong"; mark_fail "wayback (0 hasil)"
  fi
  return 0
}

# ------------------------- FITUR 7: DNS & WHOIS -------------------------
dns_info() {
  step "[FITUR 7] DNS Records & WHOIS"
  local out="$BASE_DIR/dns"
  mkdir -p "$out"

  info "DNS records ..."
  : > "$out/dns_records.txt"
  for t in A AAAA MX NS TXT SOA CNAME; do
    echo "=== $t ===" >> "$out/dns_records.txt"
    dig +short "$TARGET" "$t" @1.1.1.1 >> "$out/dns_records.txt" 2>/dev/null
  done
  info "DNS — ${GREEN}OK${NC}"

  info "WHOIS ..."
  if command -v whois &>/dev/null; then
    whois "$TARGET" > "$out/whois.txt" 2>/dev/null && info "WHOIS — ${GREEN}OK${NC}" || warn "whois warning"
  else
    warn "whois tidak tersedia, skip"
  fi

  if command -v dnsx &>/dev/null && [ -s "$BASE_DIR/subdomains/all_subdomains.txt" ]; then
    dnsx -l "$BASE_DIR/subdomains/all_subdomains.txt" -silent -a -resp -o "$out/dnsx_resolved.txt" \
      >> "$LOG_FILE" 2>&1 && info "dnsx — ${GREEN}OK${NC}" || warn "dnsx warning"
  fi
  mark_ok
  return 0
}

# ------------------------- FITUR 8: TECH DETECTION -------------------------
tech_detect() {
  step "[FITUR 8] Technology Detection"
  local out="$BASE_DIR/tech"
  mkdir -p "$out"
  local urls="$BASE_DIR/live/live_urls.txt"

  if command -v whatweb &>/dev/null && [ -s "$urls" ]; then
    whatweb --no-errors -q --color=never -i "$urls" > "$out/whatweb.txt" 2>/dev/null \
      && info "whatweb — ${GREEN}OK${NC}" || warn "whatweb warning"
  else
    warn "whatweb tidak ada / tidak ada live host, skip"
  fi

  grep -iE 'tech|nginx|apache|cloudflare|iis|express|php|laravel' \
    "$BASE_DIR/live/live_hosts.txt" 2>/dev/null | head -20 > "$out/tech_from_httpx.txt"
  mark_ok
  return 0
}

# ------------------------- FITUR 24: TLS / SSL ANALYSIS -------------------------
tls_analysis() {
  step "[FITUR 24] TLS/SSL Analysis + Cert SAN Extraction"
  local out="$BASE_DIR/tls"
  mkdir -p "$out"
  local urls="$BASE_DIR/live/live_urls.txt"
  if [ ! -s "$urls" ]; then echo "https://$TARGET" > "$urls"; fi

  # 1. Ekstrak SAN dari sertifikat (sumber subdomain tambahan)
  info "Ekstrak Subject Alternative Name dari sertifikat (top 20 host) ..."
  : > "$out/san_all.txt"
  local i=0
  while read -r url; do
    [ "$i" -ge 20 ] && break
    i=$((i+1))
    local host
    host=$(echo "$url" | sed 's|https\?://||; s|/.*||; s|:.*||')
    echo | openssl s_client -connect "$host:443" -servername "$host" 2>/dev/null \
      | openssl x509 -noout -text 2>/dev/null \
      | grep -oE 'DNS:[a-zA-Z0-9.*_-]+' | sed 's/DNS://' >> "$out/san_all.txt"
  done < "$urls"
  grep "\.$TARGET$" "$out/san_all.txt" 2>/dev/null | sort -u > "$out/san_subdomains.txt"
  local san_new
  san_new=$(comm -13 <(sort -u "$BASE_DIR/subdomains/all_subdomains.txt" 2>/dev/null) \
                    <(sort -u "$out/san_subdomains.txt" 2>/dev/null))
  if [ -n "$san_new" ]; then
    echo "$san_new" >> "$BASE_DIR/subdomains/all_subdomains.txt"
    sort -u "$BASE_DIR/subdomains/all_subdomains.txt" -o "$BASE_DIR/subdomains/all_subdomains.txt"
    warn "Subdomain BARU dari cert SAN: $(echo "$san_new" | grep -c .) (digabung ke daftar)"
  fi

  # 2. Cek protocol lemah di main host
  info "Cek protocol lemah (SSLv2/v3, TLS 1.0) di $TARGET ..."
  : > "$out/tls_issues.txt"
  for proto in ssl2 ssl3 tls1; do
    if echo | openssl s_client -"$proto" -connect "$TARGET:443" 2>/dev/null | grep -q 'BEGIN CERT'; then
      echo "WEAK: $TARGET masih menerima $proto!" >> "$out/tls_issues.txt"
      warn "$TARGET masih menerima $proto — ini lemah!"
    fi
  done

  # 3. Info sertifikat main host
  echo | openssl s_client -connect "$TARGET:443" -servername "$TARGET" 2>/dev/null \
    | openssl x509 -noout -subject -issuer -dates 2>/dev/null > "$out/cert_info.txt"

  # 4. testssl.sh kalau ada (detail penuh)
  if command -v testssl.sh &>/dev/null; then
    info "testssl.sh jalan di $TARGET (agak lama) ..."
    testssl.sh --quiet --color 0 "$TARGET" > "$out/testssl.txt" 2>&1 \
      && info "testssl — ${GREEN}OK${NC}" || warn "testssl warning"
  else
    warn "testssl.sh tidak ada (opsional: install dari https://testssl.sh) — analisa dasar tetap jalan"
  fi

  info "TLS issues: ${YELLOW}$(cnt "$out/tls_issues.txt")${NC} | SAN unik: $(cnt "$out/san_subdomains.txt")"
  mark_ok
  return 0
}

# ------------------------- FITUR 25: GOOGLE DORK GENERATOR -------------------------
google_dorks() {
  step "[FITUR 25] Google Dork Generator"
  local out="$BASE_DIR/dorks"
  mkdir -p "$out"

  {
    echo "# Google Dorks untuk $TARGET — copy-paste ke browser"
    echo "# Generated: $(date)"
    echo ""
    echo "site:*.$TARGET"
    echo "site:$TARGET inurl:admin"
    echo "site:$TARGET inurl:login"
    echo "site:$TARGET inurl:signin"
    echo "site:$TARGET inurl:signup"
    echo "site:$TARGET inurl:register"
    echo "site:$TARGET inurl:dashboard"
    echo "site:$TARGET inurl:upload"
    echo "site:$TARGET inurl:config"
    echo "site:$TARGET inurl:backup"
    echo "site:$TARGET inurl:api"
    echo "site:$TARGET inurl:redirect"
    echo "site:$TARGET inurl:return"
    echo "site:$TARGET inurl:test"
    echo "site:$TARGET inurl:dev"
    echo "site:$TARGET inurl:staging"
    echo "site:$TARGET inurl:phpinfo"
    echo "site:$TARGET intitle:\"index of\""
    echo "site:$TARGET intitle:\"admin panel\""
    echo "site:$TARGET intitle:\"dashboard\""
    echo "site:$TARGET intitle:\"login\""
    echo "site:$TARGET ext:sql"
    echo "site:$TARGET ext:env"
    echo "site:$TARGET ext:bak"
    echo "site:$TARGET ext:log"
    echo "site:$TARGET ext:conf"
    echo "site:$TARGET ext:ini"
    echo "site:$TARGET ext:old"
    echo "site:$TARGET ext:swp"
    echo "site:$TARGET ext:zip"
    echo "site:$TARGET ext:tar"
    echo "site:$TARGET ext:gz"
    echo "site:$TARGET ext:xml"
    echo "site:$TARGET ext:csv"
    echo "site:$TARGET \"index of /\""
    echo "site:$TARGET \"password\""
    echo "site:$TARGET \"api key\""
    echo "site:$TARGET \"token\""
    echo "site:$TARGET \"confidential\""
    echo "site:$TARGET \"internal use only\""
    echo "inurl:\"$TARGET\""
    echo "\"$TARGET\" password filetype:pdf"
    echo "\"$TARGET\" username filetype:xls"
    echo "\"$TARGET\" inurl:wp-admin"
    echo "\"$TARGET\" inurl:wp-content"
  } > "$out/dorks_google.txt"

  # URL siap pakai (ter-encode)
  grep '^https' /dev/null 2>/dev/null
  sed -n 's/^https.*$//p' "$out/dorks_google.txt" >/dev/null 2>&1
  {
    while read -r line; do
      case "$line" in
        \#*) continue ;;
        *) echo "https://www.google.com/search?q=$(echo "$line" | sed 's/ /%20/g; s/"/%22/g')" ;;
      esac
    done < "$out/dorks_google.txt"
  } > "$out/dorks_urls.txt" 2>/dev/null

  info "Dork generated: ${GREEN}$(grep -c . "$out/dorks_google.txt")${NC} (dorks_google.txt)"
  info "URL siap buka : $(cnt "$out/dorks_urls.txt") (dorks_urls.txt)"
  info "Tips: buka dorks_urls.txt, copy link satu-satu ke browser bro."
  mark_ok
  return 0
}

# ------------------------- FITUR 26: VHOST FUZZING -------------------------
vhost_fuzz() {
  step "[FITUR 26] VHost Fuzzing (hidden virtual host)"
  local out="$BASE_DIR/vhost"
  mkdir -p "$out"

  if ! command -v ffuf &>/dev/null; then
    error "ffuf tidak tersedia"; mark_fail "vhost (ffuf hilang)"; return 1
  fi
  ensure_wordlist

  local ip
  ip=$(dig +short A "$TARGET" @1.1.1.1 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
  if [ -z "$ip" ]; then
    error "IP utama $TARGET tidak ketemu"; mark_fail "vhost (tanpa IP)"; return 1
  fi
  info "IP utama: $ip"

  # gabung wordlist: subdomain yang ada + kata umum
  {
    cut -d. -f1 "$BASE_DIR/subdomains/all_subdomains.txt" 2>/dev/null
    cat "$WORDLIST" 2>/dev/null
  } | sort -u | head -n "$VHOST_TARGETS" > "$out/vhost_words.txt"

  info "Fuzz Host header di https://$ip dengan $(cnt "$out/vhost_words.txt") kata (auto-calibrate) ..."
  if ffuf -u "https://$ip" -H "Host: FUZZ.$TARGET" -w "$out/vhost_words.txt" \
      -ac -mc 200,301,302,307,401,403 -t "$FFUF_THREADS" -timeout 15 -k \
      -of csv -o "$out/vhost_results.csv" >> "$LOG_FILE" 2>&1; then
    local found
    found=$(grep -c 'FUZZ' "$out/vhost_results.csv" 2>/dev/null)
    info "VHost menarik: ${YELLOW}${found:-0}${NC} (cek $out/vhost_results.csv)"
    mark_ok
  else
    warn "vhost fuzzing warning"; mark_fail "vhost"
  fi
  return 0
}

# ------------------------- FITUR 27: REVERSE IP NEIGHBOR -------------------------
reverse_ip() {
  step "[FITUR 27] Reverse IP — Domain Tetangga (shared hosting)"
  local out="$BASE_DIR/reverseip"
  mkdir -p "$out"

  info "Ambil IP dari $TARGET ..."
  local ips
  ips=$(dig +short A "$TARGET" @1.1.1.1 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | sort -u | head -3)
  if [ -z "$ips" ]; then
    error "IP tidak ketemu"; mark_fail "reverse ip (tanpa IP)"; return 1
  fi

  : > "$out/neighbors.txt"
  local n=0
  for ip in $ips; do
    n=$((n+1))
    info "Reverse lookup IP #$n: $ip"
    echo "=== IP: $ip ===" >> "$out/neighbors.txt"
    curl -s --max-time 30 "https://api.hackertarget.com/reverseiplookup/?q=$ip" 2>/dev/null \
      | grep -v 'error\|exceeded\|API count' >> "$out/neighbors.txt"
  done

  local total
  total=$(grep -cE '^[a-zA-Z0-9.-]+\.[a-z]{2,}' "$out/neighbors.txt" 2>/dev/null)
  info "Domain tetangga ditemukan: ${GREEN}${total:-0}${NC}"
  info "Insight: kalau server shared, kelemahan domain lain bisa berdampak ke target."
  mark_ok
  return 0
}

# ------------------------- FITUR 9: NUCLEI SCAN -------------------------
nuclei_scan() {
  step "[FITUR 9] Vulnerability Scan (Nuclei)"
  local out="$BASE_DIR/nuclei"
  mkdir -p "$out"
  local urls="$BASE_DIR/live/live_urls.txt"

  if ! command -v nuclei &>/dev/null; then
    error "nuclei tidak tersedia — install: go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"
    mark_fail "nuclei (tool hilang)"; return 1
  fi
  [ -s "$urls" ] || { error "tidak ada live host, jalankan fitur 3 dulu"; mark_fail "nuclei (tanpa live host)"; return 1; }

  info "update templates (sekali saja, sabar)..."
  nuclei -update-templates >> "$LOG_FILE" 2>&1 || warn "update template skip"

  info "nuclei scan berjalan (misconfig, exposures, takeovers, CVE) ..."
  if nuclei -l "$urls" -severity low,medium,high,critical \
      -tags exposure,misconfig,takeover,cve,unauth \
      -c "$THREADS" -timeout 15 -silent -nc \
      -o "$out/nuclei_findings.txt" >> "$LOG_FILE" 2>&1; then
    local count
    count=$(cnt "$out/nuclei_findings.txt")
    info "Nuclei — ${GREEN}OK${NC} | Findings: ${YELLOW}$count${NC}"
    [ "$count" -gt 0 ] && head -20 "$out/nuclei_findings.txt"
    mark_ok
  else
    warn "nuclei warning — cek $out/nuclei_findings.txt"; mark_fail "nuclei"
  fi
  return 0
}

# ------------------------- FITUR 21: XSS SCANNER -------------------------
xss_scan() {
  step "[FITUR 21] XSS Scanner (dalfox) — URL ber-parameter"
  local out="$BASE_DIR/xss"
  mkdir -p "$out"
  local params_file="$BASE_DIR/wayback/with_params.txt"

  if ! command -v dalfox &>/dev/null; then
    error "dalfox tidak tersedia — install: go install github.com/hahwul/dalfox/v2@latest"
    mark_fail "xss (dalfox hilang)"; return 1
  fi
  [ -s "$params_file" ] || { error "tidak ada URL ber-parameter, jalankan fitur 6 dulu"; mark_fail "xss (tanpa param)"; return 1; }

  info "Ambil 200 URL ber-parameter utk scan XSS (dari wayback) ..."
  head -200 "$params_file" | grep "^https\?://" > "$out/xss_targets.txt"
  info "dalfox jalan di $(cnt "$out/xss_targets.txt") URL (sabar, ini scan paling lama) ..."
  if dalfox file "$out/xss_targets.txt" --silence --skip-bav -o "$out/xss_findings.txt" >> "$LOG_FILE" 2>&1; then
    local count
    count=$(cnt "$out/xss_findings.txt")
    info "XSS — ${GREEN}OK${NC} | Temuan: ${YELLOW}$count${NC}"
    [ "$count" -gt 0 ] && head -20 "$out/xss_findings.txt"
    mark_ok
  else
    warn "dalfox warning — cek $out/xss_findings.txt"; mark_fail "xss"
  fi
  return 0
}

# ------------------------- FITUR 10: SUBDOMAIN TAKEOVER -------------------------
takeover_check() {
  step "[FITUR 10] Subdomain Takeover Check"
  local out="$BASE_DIR/takeover"
  mkdir -p "$out"
  local subs="$BASE_DIR/subdomains/all_subdomains.txt"

  [ -s "$subs" ] || { error "tidak ada subdomain, jalankan fitur 2 dulu"; mark_fail "takeover (tanpa subdomain)"; return 1; }

  if command -v subzy &>/dev/null; then
    run_logged "subzy takeover check" subzy run --targets "$subs" --hide_fails --output "$out/takeover_subzy.txt" \
      || mark_fail "takeover (subzy)"
  elif command -v nuclei &>/dev/null && [ -s "$BASE_DIR/live/live_urls.txt" ]; then
    run_logged "nuclei takeover templates" nuclei -l "$BASE_DIR/live/live_urls.txt" -tags takeover \
      -silent -nc -timeout 15 -o "$out/takeover_nuclei.txt" || mark_fail "takeover (nuclei)"
  else
    warn "subzy/nuclei tidak ada — fallback CNAME fingerprint (dependency-free)"
    info "cek CNAME subdomain ke layanan yang sering kena takeover ..."
    : > "$out/takeover_cname.txt"
    while read -r sub; do
      cname=$(dig +short CNAME "$sub" @1.1.1.1 2>/dev/null | head -1)
      if [ -n "$cname" ]; then
        echo "$cname" | grep -qiE 'herokuapp|github\.io|azurewebsites|cloudfront|amazonaws|trafficmanager|cloudapp|blob\.core|storage\.googleapis|pages\.dev|vercel|netlify|wordpress\.com|tumblr|fastly|pantheon|readme\.io|surge\.sh|webflow\.io' \
          && echo "MUNGKIN TAKEOVER: $sub -> $cname" >> "$out/takeover_cname.txt" \
          && warn "MUNGKIN TAKEOVER: $sub -> $cname"
      fi
    done < "$subs"
  fi

  local count
  count=$(cat "$out"/takeover_*.txt 2>/dev/null | grep -c .)
  info "Kandidat takeover: ${YELLOW}$count${NC} (cek manual ya bro)"
  mark_ok
  return 0
}

# ------------------------- FITUR 11: SCREENSHOT -------------------------
screenshot_hosts() {
  step "[FITUR 11] Screenshot Otomatis Live Host"
  local out="$BASE_DIR/screenshots"
  mkdir -p "$out"
  local urls="$BASE_DIR/live/live_urls.txt"

  [ -s "$urls" ] || { error "tidak ada live host, jalankan fitur 3 dulu"; mark_fail "screenshot (tanpa live host)"; return 1; }

  if command -v gowitness &>/dev/null; then
    info "gowitness jalan (butuh chromium headless, sabar)..."
    if gowitness scan file -f "$urls" --screenshot-path "$out" >> "$LOG_FILE" 2>&1; then
      info "gowitness — ${GREEN}OK${NC}"
    elif gowitness file -f "$urls" -s "$out" >> "$LOG_FILE" 2>&1; then
      info "gowitness (mode lama) — ${GREEN}OK${NC}"
    else
      warn "gowitness gagal (cek chromium terinstall?)"
    fi
  elif command -v aquatone &>/dev/null; then
    info "aquatone jalan ..."
    cat "$urls" | aquatone -out "$out" -silent >> "$LOG_FILE" 2>&1 \
      && info "aquatone — ${GREEN}OK${NC}" || warn "aquatone warning"
  else
    error "gowitness/aquatone tidak tersedia — install: go install github.com/sensepost/gowitness@latest + chromium"
    mark_fail "screenshot (tool hilang)"; return 1
  fi

  local count
  count=$(find "$out" \( -name '*.png' -o -name '*.jpg' \) 2>/dev/null | grep -c .)
  info "Screenshot tersimpan: ${GREEN}$count${NC} di $out"
  [ "$count" -gt 0 ] && mark_ok || mark_fail "screenshot (0 hasil)"
  return 0
}

# ------------------------- FITUR 12: EMAIL & USERNAME HARVEST -------------------------
harvest_emails() {
  step "[FITUR 12] Email & Username Harvesting"
  local out="$BASE_DIR/emails"
  mkdir -p "$out"
  local EMAIL_RE='[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'

  if command -v theHarvester &>/dev/null; then
    run_logged "theHarvester" theHarvester -d "$TARGET" -b all -f "$out/harvester.html" || warn "theHarvester warning"
  else
    warn "theHarvester tidak ada — pakai metode grep (tetap jalan, dependency-free)"
  fi

  info "kumpulin email dari semua sumber yang sudah ada ..."
  : > "$out/emails.txt"
  grep -hoE "$EMAIL_RE" "$BASE_DIR/wayback/wayback_all.txt" 2>/dev/null >> "$out/emails.txt"
  grep -rhoE "$EMAIL_RE" "$BASE_DIR"/secrets/*.js 2>/dev/null >> "$out/emails.txt"
  for u in "https://$TARGET" "https://www.$TARGET"; do
    curl -sL --max-time 15 -A "$USER_AGENT" "$u" 2>/dev/null | grep -oE "$EMAIL_RE" >> "$out/emails.txt"
  done
  sort -u "$out/emails.txt" -o "$out/emails.txt" 2>/dev/null

  local count
  count=$(cnt "$out/emails.txt")
  info "Email ditemukan: ${GREEN}$count${NC}"
  [ "$count" -gt 0 ] && head -10 "$out/emails.txt"
  mark_ok
  return 0
}

# ------------------------- FITUR 13: SECRET / API KEY SCANNER -------------------------
scan_secrets() {
  step "[FITUR 13] Secret & API Key Scanner (dalam file JS)"
  local out="$BASE_DIR/secrets"
  mkdir -p "$out"
  local js_list="$BASE_DIR/wayback/js_files.txt"

  if [ -s "$js_list" ]; then
    info "download maks. $JS_LIMIT file JS untuk dianalisa ..."
    local i=0
    while read -r js; do
      [ "$i" -ge "$JS_LIMIT" ] && break
      i=$((i+1))
      local fn
      fn="$out/js_$(printf '%03d' "$i").js"
      curl -sL --max-time 10 -A "$USER_AGENT" "$js" -o "$fn" 2>/dev/null || rm -f "$fn"
    done < "$js_list"
    info "Downloaded JS: $(ls "$out"/*.js 2>/dev/null | grep -c .)"
  else
    warn "belum ada list JS — jalankan fitur 6 dulu"
  fi

  info "scan pattern API key & secret ..."
  grep -RInE 'AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|xox[baprs]-[0-9A-Za-z-]+|sk_live_[0-9a-zA-Z]+|BEGIN (RSA|EC|OPENSSH|DSA) PRIVATE KEY|hooks\.slack\.com/services/T[0-9A-Za-z]+' \
    "$out" --include='*.js' 2>/dev/null > "$out/secrets_confirmed.txt" || true

  info "scan keyword sensitif (perlu review manual) ..."
  grep -RInE "(api[_-]?key|apikey|client[_-]?secret|secret[_-]?key|access[_-]?token|auth[_-]?token|password)[\"' ]*[:=]" \
    "$out" --include='*.js' 2>/dev/null | head -200 > "$out/secrets_keywords.txt" || true

  local confirmed keywords
  confirmed=$(cnt "$out/secrets_confirmed.txt")
  keywords=$(cnt "$out/secrets_keywords.txt")
  info "Secret terkonfirmasi pattern: ${YELLOW}$confirmed${NC} | Keyword mencurigakan: $keywords"
  [ "$confirmed" -gt 0 ] && head -10 "$out/secrets_confirmed.txt"
  mark_ok
  return 0
}

# ------------------------- FITUR 28: MOBILE APP RECON -------------------------
mobile_recon() {
  step "[FITUR 28] Mobile App Recon (APK → endpoint & API key)"
  local out="$BASE_DIR/mobile"
  mkdir -p "$out"

  local src
  read -rp "${CYAN}[?]${NC} Path/URL file APK target: " src
  if [ -z "$src" ]; then
    error "Tidak ada input APK"; mark_fail "mobile recon (tanpa APK)"; return 1
  fi
  local apk="$out/app.apk"
  if echo "$src" | grep -q '^https\?://'; then
    info "Download APK dari $src ..."
    curl -sL --max-time 300 -A "$USER_AGENT" "$src" -o "$apk" || { error "gagal download"; mark_fail "mobile recon (download gagal)"; return 1; }
  else
    [ -f "$src" ] || { error "File tidak ada: $src"; mark_fail "mobile recon (APK hilang)"; return 1; }
    cp "$src" "$apk"
  fi
  [ -s "$apk" ] || { error "APK kosong"; mark_fail "mobile recon (APK kosong)"; return 1; }

  if command -v apkleaks &>/dev/null; then
    info "apkleaks jalan ..."
    apkleaks -f "$apk" -o "$out/apkleaks.txt" >> "$LOG_FILE" 2>&1 \
      && info "apkleaks — ${GREEN}OK${NC}" || warn "apkleaks warning"
  else
    warn "apkleaks tidak ada — fallback unzip + grep (dependency-free)"
  fi

  # ekstraksi manual (selalu jalan sebagai pelengkap)
  info "Ekstrak & grep manual dari APK ..."
  local ex="$out/extracted"
  mkdir -p "$ex"
  unzip -o -q "$apk" -d "$ex" >> "$LOG_FILE" 2>&1 || warn "unzip warning (APK mungkin diproteksi)"

  info "Kumpulin endpoint URL ..."
  grep -rhoE 'https?://[a-zA-Z0-9._~:/?#@!$&()*+,;=%-]+' "$ex" 2>/dev/null \
    | grep -vE 'w3\.org|apache\.org|xmlpull|google\.com/schema|schemas\.android' \
    | sort -u | head -500 > "$out/endpoints.txt"
  grep "\.$TARGET" "$out/endpoints.txt" 2>/dev/null | sort -u > "$out/endpoints_target.txt"

  info "Scan API key & secret di dalam APK ..."
  grep -rhoE 'AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|ghp_[A-Za-z0-9]{36}|xox[baprs]-[0-9A-Za-z-]+|sk_live_[0-9a-zA-Z]+' \
    "$ex" 2>/dev/null | sort -u > "$out/mobile_secrets.txt" || true

  info "Kumpulin email dari APK ..."
  grep -rhoE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' "$ex" 2>/dev/null \
    | sort -u | head -100 > "$out/mobile_emails.txt" || true

  info "Endpoint ditemukan   : ${GREEN}$(cnt "$out/endpoints.txt")${NC} (milik target: $(cnt "$out/endpoints_target.txt"))"
  info "Secret pattern       : ${YELLOW}$(cnt "$out/mobile_secrets.txt")${NC}"
  info "Email dari APK       : $(cnt "$out/mobile_emails.txt")"
  mark_ok
  return 0
}

# ------------------------- FITUR 14: PARAMETER FUZZING -------------------------
param_fuzz() {
  step "[FITUR 14] Parameter Fuzzing (parameter tersembunyi)"
  local out="$BASE_DIR/params"
  mkdir -p "$out"
  local urls="$BASE_DIR/live/live_urls.txt"

  [ -s "$urls" ] || { error "tidak ada live host, jalankan fitur 3 dulu"; mark_fail "param fuzz (tanpa live host)"; return 1; }

  if command -v arjun &>/dev/null; then
    local i=0
    while read -r url; do
      [ "$i" -ge "$PARAM_URL_LIMIT" ] && break
      i=$((i+1))
      run_logged "arjun: $url" arjun -u "$url" -t 10 -o "$out/arjun_$(echo "$url" | md5sum | cut -c1-8).txt" || warn "arjun warning: $url"
    done < "$urls"
  else
    warn "arjun tidak ada — fallback probe refleksi (dependency-free)"
    info "uji refleksi parameter di $PARAM_URL_LIMIT host pertama ..."
    local probe_params=(id q url redirect next page file path template debug cmd search keyword user admin token key email type name callback return dest data)
    : > "$out/reflected_params.txt"
    local i=0
    while read -r url; do
      [ "$i" -ge "$PARAM_URL_LIMIT" ] && break
      i=$((i+1))
      info "  probe: $url"
      for p in "${probe_params[@]}"; do
        resp=$(curl -s --max-time 8 -A "$USER_AGENT" "$url?$p=ReconProbe123xY" 2>/dev/null)
        if echo "$resp" | grep -q "ReconProbe123xY" 2>/dev/null; then
          echo "REFLECTED: $url?$p=  (potensi XSS — cek manual)" >> "$out/reflected_params.txt"
        fi
      done
    done < "$urls"
  fi

  local count
  count=$(cat "$out"/*.txt 2>/dev/null | grep -c .)
  info "Parameter menarik: ${YELLOW}$count${NC} (cek manual untuk exploitasi)"
  mark_ok
  return 0
}

# ------------------------- FITUR 15: CORS CHECK -------------------------
cors_check() {
  step "[FITUR 15] CORS Misconfiguration Check"
  local out="$BASE_DIR/cors"
  mkdir -p "$out"
  local urls="$BASE_DIR/live/live_urls.txt"

  [ -s "$urls" ] || { error "tidak ada live host, jalankan fitur 3 dulu"; mark_fail "CORS (tanpa live host)"; return 1; }

  info "uji refleksi Origin jahat (evil-recon-test.com) di $CORS_URL_LIMIT host pertama ..."
  : > "$out/cors_headers.txt"
  : > "$out/cors_reflected.txt"
  local i=0
  while read -r url; do
    [ "$i" -ge "$CORS_URL_LIMIT" ] && break
    i=$((i+1))
    local headers acao
    headers=$(curl -s -D - -o /dev/null --max-time 10 -A "$USER_AGENT" \
              -H "Origin: https://evil-recon-test.com" "$url" 2>/dev/null)
    acao=$(echo "$headers" | grep -i 'access-control-allow-origin' | head -1 | tr -d '\r')
    if [ -n "$acao" ]; then
      echo "$url | $acao" >> "$out/cors_headers.txt"
      if echo "$acao" | grep -qi 'evil-recon-test'; then
        echo "REFLECTED ORIGIN: $url  → CORS misconfiguration!" >> "$out/cors_reflected.txt"
        warn "CORS misconfig: $url"
      fi
    fi
  done < "$urls"

  local reflected total
  reflected=$(cnt "$out/cors_reflected.txt")
  total=$(cnt "$out/cors_headers.txt")
  info "Header CORS ditemukan: $total | Reflected (bahaya): ${YELLOW}$reflected${NC}"
  mark_ok
  return 0
}

# ------------------------- FITUR 16: MODE BATCH -------------------------
full_auto_flow() {
  info "TARGET LOCKED: ${GREEN}$TARGET${NC} — mulai scan penuh otomatis..."
  echo "=== FULL AUTO RECON v$VERSION — $TARGET — mulai $START_TIME ===" >> "$LOG_FILE"

  # Jalankan SEMUA fitur berurutan; error apapun TIDAK menghentikan script
  enum_subdomains      || true
  subdomain_permutation || true
  probe_live           || true
  waf_detect           || true
  security_headers     || true
  port_scan            || true
  wayback_extract      || true
  dns_info             || true
  tech_detect          || true
  dir_brute            || true
  scan_secrets         || true
  param_fuzz           || true
  cors_check           || true
  vhost_fuzz           || true
  reverse_ip           || true
  google_dorks         || true
  takeover_check       || true
  nuclei_scan          || true
  xss_scan             || true
  tls_analysis         || true
  harvest_emails       || true
  screenshot_hosts     || true

  generate_report
}

full_auto() {
  step "[FITUR 1] FULL AUTO RECON — Semua Fitur Sekali Jalan"
  setup_target || return 1
  full_auto_flow
}

batch_run() {
  local list_file="$1"
  if [ ! -s "$list_file" ]; then
    error "File tidak ada / kosong: $list_file"
    return 1
  fi
  local total ok skip
  total=$(cnt "$list_file"); ok=0; skip=0
  info "Total target di file: $total — mulai batch scan..."
  while read -r dom; do
    dom=$(echo "$dom" | sed 's|https\?://||; s|/.*||; s|^www\.||' | tr -d '[:space:]')
    [ -z "$dom" ] && continue
    if ! valid_domain "$dom"; then
      warn "SKIP (bukan domain valid): $dom"; skip=$((skip+1)); continue
    fi
    echo ""
    echo -e "${CYAN}============================================================${NC}"
    info "BATCH TARGET: ${GREEN}$dom${NC}"
    echo -e "${CYAN}============================================================${NC}"
    init_target "$dom"
    full_auto_flow || true
    ok=$((ok+1))
  done < "$list_file"
  echo ""
  info "Batch selesai: ${GREEN}$ok sukses${NC}, $skip skip, dari $total target"
  return 0
}

batch_mode() {
  step "[FITUR 16] Mode Batch — Multi Target dari File"
  local list_file
  read -rp "${CYAN}[?]${NC} Path file daftar target (1 domain per baris, cth: targets.txt): " list_file
  batch_run "$list_file"
}

# ------------------------- FITUR 17: MONITORING / DIFF ASSET BARU -------------------------
monitor_diff() {
  step "[FITUR 17] Monitoring — Deteksi Asset Baru (Diff Scan Lama vs Baru)"
  local input
  read -rp "${CYAN}[?]${NC} Domain yang sudah pernah di-scan minimal 2x: " input
  input=$(echo "$input" | sed 's|https\?://||; s|/.*||; s|^www\.||' | tr -d '[:space:]')
  if ! valid_domain "$input"; then
    error "Format domain tidak valid: $input"
    return 1
  fi

  local dirs latest prev
  dirs=$(ls -dt recon_results/"$input"-* 2>/dev/null | head -2)
  if [ "$(echo "$dirs" | grep -c .)" -lt 2 ]; then
    warn "Butuh minimal 2x scan untuk '$input'. Scan dulu, lalu scan lagi nanti untuk melihat perubahan."
    return 1
  fi
  latest=$(echo "$dirs" | head -1)
  prev=$(echo "$dirs" | tail -1)
  info "Scan terbaru : $latest"
  info "Scan sebelum : $prev"

  local report="$latest/monitor_diff.txt"
  {
    echo "=== MONITORING DIFF — $input ==="
    echo "Terbaru : $latest"
    echo "Lama    : $prev"
    echo "Waktu   : $(date)"
    echo ""
    echo "--- SUBDOMAIN BARU (tidak ada di scan lama) ---"
    comm -13 <(sort -u "$prev/subdomains/all_subdomains.txt" 2>/dev/null) \
             <(sort -u "$latest/subdomains/all_subdomains.txt" 2>/dev/null) | sed 's/^/  + /'
    echo ""
    echo "--- SUBDOMAIN HILANG ---"
    comm -23 <(sort -u "$prev/subdomains/all_subdomains.txt" 2>/dev/null) \
             <(sort -u "$latest/subdomains/all_subdomains.txt" 2>/dev/null) | sed 's/^/  - /'
    echo ""
    echo "--- LIVE HOST BARU ---"
    comm -13 <(sort -u "$prev/live/live_urls.txt" 2>/dev/null) \
             <(sort -u "$latest/live/live_urls.txt" 2>/dev/null) | sed 's/^/  + /'
  } > "$report"

  local new_sub new_live
  new_sub=$(comm -13 <(sort -u "$prev/subdomains/all_subdomains.txt" 2>/dev/null) \
                     <(sort -u "$latest/subdomains/all_subdomains.txt" 2>/dev/null) | grep -c .)
  new_live=$(comm -13 <(sort -u "$prev/live/live_urls.txt" 2>/dev/null) \
                      <(sort -u "$latest/live/live_urls.txt" 2>/dev/null) | grep -c .)
  info "Subdomain baru : ${GREEN}$new_sub${NC}"
  info "Live host baru : ${GREEN}$new_live${NC}"
  info "Laporan diff   : $report"
  if [ "$new_sub" -gt 0 ] || [ "$new_live" -gt 0 ]; then
    warn "ADA ASSET BARU! Subdomain/live host baru itu target menarik buat di-scan lebih dalam."
  else
    info "Tidak ada asset baru — keadaan stabil."
  fi
  return 0
}

# ------------------------- FITUR 29: CRON AUTO RE-SCAN -------------------------
cron_setup() {
  step "[FITUR 29] Auto Re-scan Terjadwal (cron)"
  local dom hour
  read -rp "${CYAN}[?]${NC} Domain yang mau di-monitor tiap hari: " dom
  dom=$(echo "$dom" | sed 's|https\?://||; s|/.*||; s|^www\.||' | tr -d '[:space:]')
  if ! valid_domain "$dom"; then
    error "Format domain tidak valid"
    return 1
  fi
  read -rp "${CYAN}[?]${NC} Jam berapa scan jalan tiap hari [6]: " hour
  hour=${hour:-6}
  case "$hour" in
    ''|*[!0-9]*) error "Jam harus angka 0-23"; return 1 ;;
  esac
  if [ "$hour" -lt 0 ] || [ "$hour" -gt 23 ]; then
    error "Jam harus 0-23"
    return 1
  fi

  local script_path
  script_path=$(readlink -f "$0" 2>/dev/null || echo "$0")
  local log_path
  log_path="$HOME/recon_cron.log"
  local line="0 $hour * * * $script_path --auto $dom >> $log_path 2>&1"

  if command -v crontab &>/dev/null; then
    (crontab -l 2>/dev/null | grep -v "$script_path --auto $dom"; echo "$line") | crontab -
    info "Cron terpasang: setiap hari jam $hour — $dom"
    info "Log hasil scan otomatis: $log_path"
    info "Hasil tiap scan masuk folder recon_results/$dom-<tanggal>"
    info "Hapus cron nanti: crontab -e lalu hapus baris '$line'"
  else
    warn "crontab tidak tersedia — pasang manual baris ini:"
    echo "    $line"
  fi
  return 0
}

# ------------------------- FITUR 18: EXPORT HTML STATIS -------------------------
html_pre() {
  echo "<h3>$1</h3><pre>$(head -100 "$2" 2>/dev/null)</pre>"
}

export_html() {
  step "[FITUR 18] Export Laporan ke HTML (statis)"
  local src="$BASE_DIR"
  if [ -z "$src" ] || [ ! -f "$src/REPORT.md" ]; then
    local input
    read -rp "${CYAN}[?]${NC} Domain hasil scan yang mau di-export: " input
    input=$(echo "$input" | sed 's|https\?://||; s|/.*||; s|^www\.||' | tr -d '[:space:]')
    src=$(ls -dt recon_results/"$input"-* 2>/dev/null | head -1)
  fi
  if [ -z "$src" ] || [ ! -d "$src" ]; then
    error "Tidak ada hasil scan untuk di-export. Scan dulu bro!"
    return 1
  fi

  local out="$src/report.html"
  info "Generate HTML dari: $src"
  {
    echo "<!DOCTYPE html><html><head><meta charset='utf-8'>"
    echo "<title>RECON Report — $TARGET</title>"
    echo "<style>body{font-family:monospace;background:#111;color:#ddd;padding:24px;max-width:1000px;margin:auto}"
    echo "h1{color:#4ec94e}h3{color:#4ec94e;border-bottom:1px solid #333}"
    echo "table{border-collapse:collapse;margin:12px 0}td,th{border:1px solid #444;padding:6px 14px}"
    echo "pre{background:#1a1a1a;padding:12px;overflow-x:auto;border-radius:6px;color:#9cdc9c}"
    echo ".warn{color:#e6c22e}.vuln{color:#ff5f5f}</style></head><body>"
    echo "<h1>RECON REPORT v$VERSION</h1>"
    echo "<p>Target: <b>$TARGET</b> | Direktori: $src | Dibuat: $(date)</p>"
    echo "<h2>Ringkasan</h2><table>"
    echo "<tr><th>Metric</th><th>Jumlah</th></tr>"
    echo "<tr><td>Subdomain</td><td>$(cnt "$src/subdomains/all_subdomains.txt")</td></tr>"
    echo "<tr><td>Live host</td><td>$(cnt "$src/live/live_hosts.txt")</td></tr>"
    echo "<tr><td>Port terbuka</td><td>$(grep -hE '[0-9]+/open/tcp' "$src/ports/nmap_result.gnmap" 2>/dev/null | grep -c .)</td></tr>"
    echo "<tr><td>Nuclei findings</td><td>$(cnt "$src/nuclei/nuclei_findings.txt")</td></tr>"
    echo "<tr><td>Kandidat takeover</td><td>$(cat "$src"/takeover/takeover_*.txt 2>/dev/null | grep -c .)</td></tr>"
    echo "<tr><td>Secret terkonfirmasi</td><td>$(cnt "$src/secrets/secrets_confirmed.txt")</td></tr>"
    echo "<tr><td>Email ditemukan</td><td>$(cnt "$src/emails/emails.txt")</td></tr>"
    echo "<tr><td>CORS reflected</td><td>$(cnt "$src/cors/cors_reflected.txt")</td></tr>"
    echo "<tr><td>Header grade E/F</td><td>$(cnt "$src/headers/headers_grade_f.txt")</td></tr>"
    echo "<tr><td>XSS temuan</td><td>$(cnt "$src/xss/xss_findings.txt")</td></tr>"
    echo "<tr><td>Screenshot</td><td>$(find "$src/screenshots" \( -name '*.png' -o -name '*.jpg' \) 2>/dev/null | grep -c .)</td></tr>"
    echo "</table>"
    html_pre "Nuclei Findings" "$src/nuclei/nuclei_findings.txt"
    html_pre "Secret Confirmed" "$src/secrets/secrets_confirmed.txt"
    html_pre "CORS Reflected" "$src/cors/cors_reflected.txt"
    html_pre "Security Headers Audit" "$src/headers/headers_audit.txt"
    html_pre "Email" "$src/emails/emails.txt"
    html_pre "Live Hosts" "$src/live/live_hosts.txt"
    html_pre "Subdomain" "$src/subdomains/all_subdomains.txt"
    echo "<hr><p style='color:#666'>RECON v$VERSION — gunakan hanya untuk pengujian yang sah.</p>"
    echo "</body></html>"
  } > "$out"

  info "Laporan HTML — ${GREEN}OK${NC}: $out"
  info "Buka di browser: ${CYAN}xdg-open $out${NC}"
  return 0
}

# ------------------------- FITUR 30: DASHBOARD HTML INTERAKTIF -------------------------
dashboard_html() {
  step "[FITUR 30] Dashboard HTML Interaktif (search/filter)"
  local src="$BASE_DIR"
  if [ -z "$src" ] || [ ! -f "$src/REPORT.md" ]; then
    local input
    read -rp "${CYAN}[?]${NC} Domain hasil scan yang mau di-dashboard: " input
    input=$(echo "$input" | sed 's|https\?://||; s|/.*||; s|^www\.||' | tr -d '[:space:]')
    src=$(ls -dt recon_results/"$input"-* 2>/dev/null | head -1)
  fi
  if [ -z "$src" ] || [ ! -d "$src" ]; then
    error "Tidak ada hasil scan. Scan dulu bro!"
    return 1
  fi

  local out="$src/dashboard.html"
  info "Generate dashboard dari: $src"

  # helper: section collapsible
  dash_section() {
    echo "<details open><summary>$1</summary><pre>$(head -300 "$2" 2>/dev/null)</pre></details>"
  }

  local sec_count cors_count hgf_count
  sec_count=$(cnt "$src/secrets/secrets_confirmed.txt")
  cors_count=$(cnt "$src/cors/cors_reflected.txt")
  hgf_count=$(cnt "$src/headers/headers_grade_f.txt")

  {
    echo "<!DOCTYPE html><html><head><meta charset='utf-8'>"
    echo "<title>RECON Dashboard — $TARGET</title>"
    echo "<style>"
    echo "body{font-family:monospace;background:#0d1117;color:#c9d1d9;padding:24px;max-width:1100px;margin:auto}"
    echo "h1{color:#58a6ff}h2{color:#58a6ff;border-bottom:1px solid #21262d;padding-bottom:6px}"
    echo ".cards{display:flex;flex-wrap:wrap;gap:12px;margin:16px 0}"
    echo ".card{background:#161b22;border:1px solid #30363d;border-radius:8px;padding:14px 20px;min-width:130px}"
    echo ".card .v{font-size:26px;font-weight:bold;color:#3fb950}.card .v.warn{color:#d29922}.card .v.vuln{color:#f85149}"
    echo ".card .l{color:#8b949e;font-size:12px;margin-top:4px}"
    echo "input[type=text]{width:100%;padding:10px 14px;margin:10px 0;background:#161b22;color:#c9d1d9;border:1px solid #30363d;border-radius:6px;font-size:14px}"
    echo "details{background:#161b22;border:1px solid #30363d;border-radius:8px;margin:10px 0;padding:6px 14px}"
    echo "summary{cursor:pointer;color:#58a6ff;font-weight:bold;padding:8px 0}"
    echo "pre{background:#0d1117;padding:12px;overflow-x:auto;border-radius:6px;font-size:12px;white-space:pre-wrap}"
    echo "table{border-collapse:collapse;width:100%;margin:8px 0}td,th{border:1px solid #30363d;padding:6px 12px;text-align:left}"
    echo "</style></head><body>"
    echo "<h1>RECON Dashboard v$VERSION</h1>"
    echo "<p>Target: <b>$TARGET</b> | $src | $(date)</p>"
    echo "<input type='text' id='q' onkeyup='filterAll(this.value)' placeholder='Ketik untuk filter semua hasil (cth: admin, .json, [critical], 403)...'>"
    # --- kartu ringkasan
    echo "<div class='cards'>"
    echo "<div class='card'><div class='v'>$(cnt "$src/subdomains/all_subdomains.txt")</div><div class='l'>Subdomain</div></div>"
    echo "<div class='card'><div class='v'>$(cnt "$src/live/live_hosts.txt")</div><div class='l'>Live Host</div></div>"
    echo "<div class='card'><div class='v'>$(cnt "$src/nuclei/nuclei_findings.txt")</div><div class='l'>Nuclei</div></div>"
    echo "<div class='card'><div class='v"
    [ "$sec_count" -gt 0 ] && echo -n " vuln"
    echo "'>$sec_count</div><div class='l'>Secret</div></div>"
    echo "<div class='card'><div class='v"
    [ "$cors_count" -gt 0 ] && echo -n " vuln"
    echo "'>$cors_count</div><div class='l'>CORS Bad</div></div>"
    echo "<div class='card'><div class='v"
    [ "$hgf_count" -gt 0 ] && echo -n " warn"
    echo "'>$hgf_count</div><div class='l'>Header E/F</div></div>"
    echo "<div class='card'><div class='v'>$(cnt "$src/xss/xss_findings.txt")</div><div class='l'>XSS</div></div>"
    echo "<div class='card'><div class='v'>$(cat "$src"/takeover/takeover_*.txt 2>/dev/null | grep -c .)</div><div class='l'>Takeover</div></div>"
    echo "<div class='card'><div class='v'>$(cnt "$src/emails/emails.txt")</div><div class='l'>Email</div></div>"
    echo "<div class='card'><div class='v'>$(cnt "$src/wayback/wayback_all.txt")</div><div class='l'>Wayback URL</div></div>"
    echo "</div>"
    # --- temuan prioritas
    echo "<h2>Temuan Prioritas (cek ini dulu)</h2>"
    dash_section "Nuclei Findings (vuln/misconfig)" "$src/nuclei/nuclei_findings.txt"
    dash_section "Secret / API Key Terkonfirmasi" "$src/secrets/secrets_confirmed.txt"
    dash_section "CORS Misconfiguration" "$src/cors/cors_reflected.txt"
    dash_section "Kandidat Subdomain Takeover" "$src/takeover/takeover_cname.txt"
    # --- attack surface
    echo "<h2>Attack Surface</h2>"
    dash_section "Live Hosts" "$src/live/live_hosts.txt"
    dash_section "Security Headers Audit" "$src/headers/headers_audit.txt"
    dash_section "Parameter Reflected" "$src/params/reflected_params.txt"
    dash_section "VHost Menarik (CSV)" "$src/vhost/vhost_results.csv"
    dash_section "Domain Tetangga (reverse IP)" "$src/reverseip/neighbors.txt"
    dash_section "TLS Issues" "$src/tls/tls_issues.txt"
    dash_section "Email" "$src/emails/emails.txt"
    # --- inventaris
    echo "<h2>Inventaris</h2>"
    dash_section "Subdomain ($(cnt "$src/subdomains/all_subdomains.txt"))" "$src/subdomains/all_subdomains.txt"
    dash_section "Wayback URL ber-parameter" "$src/wayback/with_params.txt"
    dash_section "File JS" "$src/wayback/js_files.txt"
    dash_section "Google Dorks" "$src/dorks/dorks_google.txt"
    echo "<script>"
    echo "function filterAll(q){"
    echo " var s=q.toLowerCase();"
    echo " var pres=document.getElementsByTagName('pre');"
    echo " for(var i=0;i<pres.length;i++){"
    echo "  if(s===''){continue;}"
    echo "  var lines=pres[i].innerHTML.split('\n');"
    echo "  var out='';"
    echo "  for(var j=0;j<lines.length;j++){"
    echo "   if(lines[j].toLowerCase().indexOf(s)>-1){out+=lines[j]+'\n';}"
    echo "  }"
    echo "  pres[i].textContent=out;"
    echo " }"
    echo "}"
    echo "</script>"
    echo "<hr><p style='color:#8b949e'>RECON v$VERSION PRO — hanya untuk pengujian yang sah (bug bounty/pentest berizin).</p>"
    echo "</body></html>"
  } > "$out"

  info "Dashboard — ${GREEN}OK${NC}: $out"
  info "Buka di browser: ${CYAN}xdg-open $out${NC}"
  return 0
}

# ------------------------- FITUR 19: REPORT (MARKDOWN) -------------------------
generate_report() {
  step "LAPORAN AKHIR"

  local end_time
  end_time=$(date '+%Y-%m-%d %H:%M:%S')
  local sub_count live_count port_count nuclei_count takeover_count secret_count email_count cors_count param_count shot_count xss_count badhdr_count waf_note tls_count dork_count vhost_count neigh_count
  sub_count=$(cnt "$BASE_DIR/subdomains/all_subdomains.txt")
  live_count=$(cnt "$BASE_DIR/live/live_hosts.txt")
  port_count=$(grep -hE '[0-9]+/open/tcp' "$BASE_DIR/ports/nmap_result.gnmap" 2>/dev/null | grep -c .)
  port_count=${port_count:-0}
  nuclei_count=$(cnt "$BASE_DIR/nuclei/nuclei_findings.txt")
  takeover_count=$(cat "$BASE_DIR"/takeover/takeover_*.txt 2>/dev/null | grep -c .)
  secret_count=$(cnt "$BASE_DIR/secrets/secrets_confirmed.txt")
  email_count=$(cnt "$BASE_DIR/emails/emails.txt")
  cors_count=$(cnt "$BASE_DIR/cors/cors_reflected.txt")
  param_count=$(cat "$BASE_DIR"/params/*.txt 2>/dev/null | grep -c .)
  shot_count=$(find "$BASE_DIR/screenshots" \( -name '*.png' -o -name '*.jpg' \) 2>/dev/null | grep -c .)
  xss_count=$(cnt "$BASE_DIR/xss/xss_findings.txt")
  badhdr_count=$(cnt "$BASE_DIR/headers/headers_grade_f.txt")
  tls_count=$(cnt "$BASE_DIR/tls/tls_issues.txt")
  dork_count=$(cnt "$BASE_DIR/dorks/dorks_google.txt")
  vhost_count=$(grep -c 'FUZZ' "$BASE_DIR/vhost/vhost_results.csv" 2>/dev/null)
  vhost_count=${vhost_count:-0}
  neigh_count=$(grep -cE '^[a-zA-Z0-9.-]+\.[a-z]{2,}' "$BASE_DIR/reverseip/neighbors.txt" 2>/dev/null)
  neigh_count=${neigh_count:-0}
  if [ -s "$BASE_DIR/waf/waf_detected.txt" ]; then waf_note="YA ($WAF_NAME) — rate scan diturunkan"; else waf_note="Tidak"; fi

  {
    echo "# RECON REPORT — $TARGET"
    echo "Waktu mulai  : $START_TIME"
    echo "Waktu selesai: $end_time"
    echo ""
    echo "## Ringkasan"
    echo "| Metrik                  | Jumlah |"
    echo "|-------------------------|--------|"
    echo "| Subdomain ditemukan     | $sub_count |"
    echo "| Live host (HTTP)        | $live_count |"
    echo "| Port terbuka            | $port_count |"
    echo "| Nuclei findings         | $nuclei_count |"
    echo "| Kandidat takeover       | $takeover_count |"
    echo "| Secret terkonfirmasi    | $secret_count |"
    echo "| XSS temuan              | $xss_count |"
    echo "| CORS reflected          | $cors_count |"
    echo "| Parameter menarik       | $param_count |"
    echo "| Host header grade E/F   | $badhdr_count |"
    echo "| TLS issues              | $tls_count |"
    echo "| VHost menarik           | $vhost_count |"
    echo "| Domain tetangga (IP)    | $neigh_count |"
    echo "| WAF                     | $waf_note |"
    echo "| Email ditemukan         | $email_count |"
    echo "| Screenshot              | $shot_count |"
    echo "| Dorks generated         | $dork_count |"
    echo "| Step sukses             | $STEPS_OK |"
    echo "| Step gagal/skip         | $STEPS_FAIL |"
    echo ""
    echo "## Struktur Output"
    echo "- subdomains/   : subdomain + hasil permutation"
    echo "- live/         : host aktif + tech detect"
    echo "- ports/        : hasil nmap"
    echo "- dirs/         : brute force directory (CSV)"
    echo "- wayback/      : URL wayback, JS, parameter"
    echo "- dns/          : DNS records + whois"
    echo "- tech/         : teknologi web"
    echo "- nuclei/       : vulnerability findings"
    echo "- xss/          : temuan XSS (dalfox)"
    echo "- takeover/     : kandidat takeover"
    echo "- screenshots/  : screenshot live host"
    echo "- emails/       : hasil harvesting"
    echo "- secrets/      : API key/secret di JS"
    echo "- params/       : parameter tersembunyi"
    echo "- cors/         : hasil CORS check"
    echo "- headers/      : security headers audit"
    echo "- waf/          : deteksi WAF"
    echo "- tls/          : analisa TLS/SSL + cert SAN"
    echo "- dorks/        : google dorks"
    echo "- vhost/        : vhost fuzzing"
    echo "- reverseip/    : domain tetangga"
    echo "- mobile/       : recon APK (jika dijalankan)"
    echo "- recon.log     : log lengkap"
    if [ "$STEPS_FAIL" -gt 0 ]; then
      echo ""
      echo "## Step yang gagal/skip"
      echo -e "$FAILED_STEPS"
    fi
  } > "$BASE_DIR/REPORT.md"

  echo ""
  echo -e "${GREEN}  ==============================================================${NC}"
  echo -e "${GREEN}             SCAN SELESAI — RINGKASAN v$VERSION PRO           ${NC}"
  echo -e "${GREEN}  ==============================================================${NC}"
  printf  "${GREEN}  Target            : %-29s${NC}\n" "$TARGET"
  printf  "${GREEN}  Subdomain         : %-29s${NC}\n" "$sub_count"
  printf  "${GREEN}  Live host         : %-29s${NC}\n" "$live_count"
  printf  "${GREEN}  Port terbuka      : %-29s${NC}\n" "$port_count"
  printf  "${GREEN}  Nuclei findings   : %-29s${NC}\n" "$nuclei_count"
  printf  "${GREEN}  Secret terkonfirmasi: %-28s${NC}\n" "$secret_count"
  printf  "${GREEN}  XSS / CORS bad    : %-29s${NC}\n" "$xss_count / $cors_count"
  printf  "${GREEN}  Header E/F / TLS  : %-29s${NC}\n" "$badhdr_count / $tls_count"
  printf  "${GREEN}  WAF               : %-29s${NC}\n" "$waf_note"
  printf  "${GREEN}  Step OK / Gagal   : %-29s${NC}\n" "$STEPS_OK / $STEPS_FAIL"
  echo -e "${GREEN}  ==============================================================${NC}"
  echo -e "  Laporan MD  : ${CYAN}$BASE_DIR/REPORT.md${NC}"
  echo -e "  Dashboard   : ${CYAN}jalankan fitur 30${NC}"
  if [ "$STEPS_FAIL" -gt 0 ]; then
    echo -e "${YELLOW}  [!] Step yang perlu dicek:$FAILED_STEPS${NC}"
  fi
  return 0
}

# ------------------------- MENU -------------------------
menu() {
  while true; do
    banner
    echo -e "${CYAN}  ================ [ MENU RECON v$VERSION PRO ] ================${NC}"
    echo -e "${CYAN}  --- Scan Utama ---${NC}"
    echo -e "   ${GREEN}1.${NC} FULL AUTO SCAN (semua fitur sekali jalan)"
    echo -e "   ${GREEN}2.${NC} Subdomain Enumeration      ${GREEN}3.${NC} Live Host Detection"
    echo -e "   ${GREEN}4.${NC} Port Scanning (nmap)       ${GREEN}5.${NC} Directory Brute Force"
    echo -e "   ${GREEN}6.${NC} Wayback / JS / Parameter   ${GREEN}7.${NC} DNS Records & WHOIS"
    echo -e "   ${GREEN}8.${NC} Technology Detection       ${GREEN}9.${NC} Vulnerability Scan (nuclei)"
    echo -e "${CYAN}  --- Vulnerability & Payload ---${NC}"
    echo -e "   ${GREEN}10.${NC} Subdomain Takeover Check"
    echo -e "   ${GREEN}11.${NC} Screenshot Otomatis       ${GREEN}12.${NC} Email Harvesting"
    echo -e "   ${GREEN}13.${NC} Secret/API Key Scanner    ${GREEN}14.${NC} Parameter Fuzzing"
    echo -e "   ${GREEN}15.${NC} CORS Check                ${GREEN}20.${NC} Security Headers Audit"
    echo -e "   ${GREEN}21.${NC} XSS Scanner (dalfox)      ${GREEN}22.${NC} WAF Detection"
    echo -e "${CYAN}  --- Recon Lanjutan ---${NC}"
    echo -e "   ${GREEN}23.${NC} Subdomain Permutation     ${GREEN}24.${NC} TLS/SSL Analysis + SAN"
    echo -e "   ${GREEN}25.${NC} Google Dork Generator     ${GREEN}26.${NC} VHost Fuzzing"
    echo -e "   ${GREEN}27.${NC} Reverse IP Neighbor       ${GREEN}28.${NC} Mobile App Recon (APK)"
    echo -e "${CYAN}  --- Otomasi & Reporting ---${NC}"
    echo -e "   ${GREEN}16.${NC} Mode Batch (multi target)"
    echo -e "   ${GREEN}17.${NC} Monitoring Asset Baru     ${GREEN}29.${NC} Cron Auto Re-scan"
    echo -e "   ${GREEN}18.${NC} Export HTML Statis        ${GREEN}30.${NC} Dashboard Interaktif"
    echo -e "   ${GREEN}31.${NC} Setup Config (API keys)   ${GREEN}19.${NC} Generate Report MD"
    echo -e "   ${GREEN}0.${NC} Exit"
    echo -e "${CYAN}  ===============================================================${NC}"
    echo ""
    read -rp "${CYAN}[?]${NC} Pilih menu: " choice
    case "$choice" in
      1)  full_auto ;;
      2)  setup_target && enum_subdomains ;;
      3)  setup_target && probe_live ;;
      4)  setup_target && port_scan ;;
      5)  setup_target && dir_brute ;;
      6)  setup_target && wayback_extract ;;
      7)  setup_target && dns_info ;;
      8)  setup_target && tech_detect ;;
      9)  setup_target && nuclei_scan ;;
      10) setup_target && takeover_check ;;
      11) setup_target && screenshot_hosts ;;
      12) setup_target && harvest_emails ;;
      13) setup_target && scan_secrets ;;
      14) setup_target && param_fuzz ;;
      15) setup_target && cors_check ;;
      16) batch_mode ;;
      17) monitor_diff ;;
      18) export_html ;;
      19) [ -n "$BASE_DIR" ] && generate_report || error "Belum ada target, jalankan scan dulu!" ;;
      20) setup_target && security_headers ;;
      21) setup_target && xss_scan ;;
      22) setup_target && waf_detect ;;
      23) setup_target && subdomain_permutation ;;
      24) setup_target && tls_analysis ;;
      25) setup_target && google_dorks ;;
      26) setup_target && vhost_fuzz ;;
      27) setup_target && reverse_ip ;;
      28) mobile_recon ;;
      29) cron_setup ;;
      30) dashboard_html ;;
      31) config_setup ;;
      0)  echo -e "${GREEN}Bye bro! Happy (legal) hunting! 👋${NC}"; exit 0 ;;
      *)  error "Pilihan tidak ada, coba lagi!" ;;
    esac
    echo ""
    read -rp "Tekan ENTER untuk kembali ke menu..."
  done
}

# ------------------------- MAIN -------------------------
main() {
  # CLI MODE: untuk cron / otomasi (non-interaktif)
  case "${1:-}" in
    --auto)
      if [ -z "${2:-}" ] || ! valid_domain "$2"; then
        echo "Usage: $0 --auto domain.tld"
        exit 1
      fi
      load_config
      init_target "$2"
      full_auto_flow
      exit 0
      ;;
    --batch)
      if [ -z "${2:-}" ]; then
        echo "Usage: $0 --batch targets.txt"
        exit 1
      fi
      load_config
      batch_run "$2"
      exit 0
      ;;
  esac

  # INTERACTIVE MODE
  if [ "$(id -u)" -eq 0 ]; then
    warn "Jangan pakai root penuh kalau tidak perlu (nmap butuh sudo saja)"
  fi
  banner
  echo -e "${YELLOW}  DISCLAIMER: Tool ini hanya untuk pengujian yang SAH${NC}"
  echo -e "${YELLOW}     (bug bounty resmi / pentest dengan izin tertulis).${NC}"
  echo -e "${YELLOW}     Kamu bertanggung jawab penuh atas penggunaannya.${NC}"
  echo ""
  read -rp "Setuju & lanjut? (y/n): " agree
  if [ "$agree" != "y" ] && [ "$agree" != "Y" ]; then
    echo "Sampai jumpa!"; exit 0
  fi

  load_config
  check_and_install_core
  install_go_tools
  menu
}

main "$@"
