<div align="center">

```
  ___  _____  _    _    __    ___  ____  ___
 / __)(  _  )( \/\/ )  /__\  / __)( ___)/ __)
( (_-. )(_)(  )    (  /(__)\ \__ \ )__)( (__
 \___/(_____)(__/\__)(__)(__)(___/(____)\___)
```

# RECON — Full Auto Recon Tool v4.0 PRO

**All-in-one automated reconnaissance framework for authorized pentesting & bug bounty**

[![Version](https://img.shields.io/badge/version-4.0-00b894?style=flat-square)](https://github.com/andisec/reconsec)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue?style=flat-square)](LICENSE)
[![Bash](https://img.shields.io/badge/shell-bash-4EAA25?style=flat-square&logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Termux%20%7C%20Windows%20%7C%20macOS-333333?style=flat-square)](https://github.com/andisec/reconsec)
[![Features](https://img.shields.io/badge/features-31-6c5ce7?style=flat-square)](https://github.com/andisec/reconsec)

`31 Features` · `Full Auto Mode` · `Zero-Crash Design` · `WAF-Aware` · `Batch & Cron Ready`

**⭐ Star this repo if it helped your recon workflow! ⭐**

</div>

---

## ⚡ What is RECON?

RECON is a **fully automated reconnaissance tool** built in pure Bash. Input one domain, and it chains **22 scanning modules** end-to-end: subdomain enumeration, permutation, live host detection, WAF detection (with automatic rate limiting), port scanning, directory brute force, wayback extraction, secret scanning, XSS detection, CORS auditing, subdomain takeover, TLS analysis and more — then generates a **Markdown report, static HTML report, and an interactive searchable dashboard**.

> 🛡️ **Built for professionals.** Every module has a dependency-free fallback (`curl` / `dig` / `grep`), so the tool **never crashes** — it degrades gracefully and keeps scanning.

---

## 🚀 Quick Start

```bash
git clone https://github.com/andisec/reconsec.git
cd reconsec
chmod +x recon.sh
./recon.sh
```

That's it. Pick **menu 1 (FULL AUTO SCAN)**, enter your target domain, and let it rip.

### One-liner
```bash
curl -sL https://raw.githubusercontent.com/andisec/reconsec/main/recon.sh -o recon.sh && chmod +x recon.sh && ./recon.sh
```

---

## 📥 Installation Guide (All Platforms)

### 🌍 Platform Support Matrix

| Platform | Support | Screenshot / Chromium | Notes |
|----------|---------|----------------------|-------|
| 🐧 Linux (Debian/Ubuntu) | ✅ **Full** | ✅ Yes | Recommended daily driver |
| 🐧 Linux (Arch/Fedora) | ✅ Full | ✅ Yes | Install deps via pacman/dnf |
| 📱 Termux native | ⚠️ Lite | ❌ No | Fast setup, no chromium → screenshot auto-skip |
| 📱 Termux + proot-distro | ✅ **Almost Full** | ✅ Yes | **Recommended for Android** |
| 🪟 Windows 10/11 (WSL2) | ✅ **Full** | ✅ Yes | **Recommended for Windows** |
| 🪟 Windows (Git Bash) | ⚠️ Limited | ❌ No | Many tools missing, fallbacks kick in |
| 🍎 macOS | ⚠️ Partial | ⚠️ Via brew | `apt` absent → install tools via brew |

---

### 🐧 1. Linux (Ubuntu / Debian / Kali / Parrot)

**Step 1 — Core dependencies:**
```bash
sudo apt update
sudo apt install -y git curl jq nmap whois dnsutils whatweb openssl unzip wget
```

**Step 2 — Install Golang** (required for the Go-based tools):
```bash
# Cara cepat (apt) — versi distro kadang lama tapi jalan:
sudo apt install -y golang

# ATAU versi terbaru (recommended):
wget https://go.dev/dl/go1.22.5.linux-amd64.tar.gz -O /tmp/go.tgz
sudo tar -C /usr/local -xzf /tmp/go.tgz
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
source ~/.bashrc
```

**Step 3 — (Optional) Chromium untuk screenshot:**
```bash
sudo apt install -y chromium chromium-driver
# Debian older: sudo apt install -y chromium-browser
```

**Step 4 — Clone & run:**
```bash
git clone https://github.com/andisec/reconsec.git
cd reconsec
chmod +x recon.sh
./recon.sh
```

> 💡 RECON auto-installs Go tools (subfinder, httpx, ffuf, nuclei, etc.) on first run. Sit tight, it takes a few minutes — once only.

**Arch Linux:**
```bash
sudo pacman -S git curl jq nmap whois bind whatweb openssl unzip go chromium
git clone https://github.com/andisec/reconsec.git && cd reconsec && chmod +x recon.sh && ./recon.sh
```

**Fedora:**
```bash
sudo dnf install -y git curl jq nmap whois bind-utils whatweb openssl unzip golang chromium-headless
git clone https://github.com/andisec/reconsec.git && cd reconsec && chmod +x recon.sh && ./recon.sh
```

---

### 📱 2. Termux (Android) — Native Lite Mode

Instalasi cepat langsung di Termux tanpa root. Beberapa fitur (screenshot/gowitness, nmap SYN-scan) tidak tersedia di lingkungan non-root — RECON otomatis skip dengan rapi, semua fitur lain tetap jalan.

**Step 1 — Install Termux** dari [F-Droid](https://f-droid.org/en/packages/com.termux/) (⚠️ jangan dari Play Store — versinya jadul).

**Step 2 — Core dependencies:**
```bash
pkg update && pkg upgrade -y
pkg install -y git curl jq nmap whois dnsutils openssl unzip wget proot-distribution
```

**Step 3 — Install Golang:**
```bash
pkg install -y golang
```

**Step 4 — PATH untuk Go tools:**
```bash
echo 'export PATH=$PATH:$HOME/go/bin' >> ~/.bashrc
source ~/.bashrc
```

**Step 5 — Clone & run:**
```bash
git clone https://github.com/andisec/reconsec.git
cd reconsec
chmod +x recon.sh
bash recon.sh
```

> ⚠️ **Catatan Termux native:** tidak ada `sudo`/`apt` → nmap jalan mode limited (`-Pn --open` tetap OK), `whatweb` & `chromium` tidak tersedia → screenshot auto-skip, tool inti yang lain (subfinder, httpx, ffuf, nuclei, waybackurls) **semua jalan normal di arm64**. Untuk pengalaman penuh, pakai proot-distro di bawah.

---

### 📱 3. Termux + proot-distro (Recommended for Android) — Full Experience

Pakai distro Linux "asli" di dalam Termux — **semua 31 fitur jalan**, termasuk screenshot & chromium. Tanpa root HP.

**Step 1 — Install proot-distro & distro Debian/Ubuntu:**
```bash
pkg update && pkg install -y proot-distribution
proot-distro install debian        # atau: proot-distro install ubuntu
proot-distro login debian
```

**Step 2 — Sekarang kamu ada di dalam Debian (prompt berubah). Install semua deps:**
```bash
apt update && apt upgrade -y
apt install -y sudo git curl jq nmap whois dnsutils whatweb openssl unzip wget wget2
```

**Step 3 — Install Golang (arm64!):**
```bash
wget https://go.dev/dl/go1.22.5.linux-arm64.tar.gz -O /tmp/go.tgz
tar -C /usr/local -xzf /tmp/go.tgz
echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> ~/.bashrc
source ~/.bashrc
go version    # harus muncul versi
```

**Step 4 — (Optional) Chromium untuk screenshot:**
```bash
apt install -y chromium
# kalau pakai ubuntu: apt install -y chromium-browser
```

**Step 5 — Clone & run:**
```bash
git clone https://github.com/andisec/reconsec.git
cd reconsec
chmod +x recon.sh
./recon.sh
```

**Untuk masuk lagi lain waktu:**
```bash
proot-distro login debian
cd reconsec && ./recon.sh
```

> 💡 Hasil scan tersimpan di dalam filesystem proot. Ambil file ke HP dengan `cp -r ~/recon_results /sdcard/` (kalau storage sudah di-enable), atau buka langsung report.html via `termux-open` dari sisi Termux.

---

### 🪟 4. Windows 10/11 (WSL2) — Recommended

Cara paling mulus di Windows: pakai WSL2 (Windows Subsystem for Linux) — **semua fitur jalan full**.

**Step 1 — Install WSL2** (buka PowerShell **sebagai Administrator**):
```powershell
wsl --install -d Ubuntu
```
Restart PC, buka "Ubuntu" dari Start Menu, buat user & password.

> Sudah punya WSL? Pastikan versi 2: `wsl --set-default-version 2`

**Step 2 — Di dalam Ubuntu WSL, install semuanya:**
```bash
sudo apt update
sudo apt install -y git curl jq nmap whois dnsutils whatweb openssl unzip wget golang
```

**Step 3 — (Optional) Chromium untuk screenshot:**
```bash
sudo apt install -y chromium-browser
```

**Step 4 — Clone & run:**
```bash
git clone https://github.com/andisec/reconsec.git
cd reconsec
chmod +x recon.sh
./recon.sh
```

> 💡 Buka hasil dashboard langsung dari Windows: `explorer.exe $(wslpath -w $(pwd))` — drag `dashboard.html` ke browser. Atau akses file via `\\wsl$\Ubuntu\home\<user>\`.

**Git Bash (Lite alternative — tidak disarankan):**
```bash
# Kalau cuma mau coba-coba tanpa WSL:
winget install Git.Git
git clone https://github.com/andisec/reconsec.git
cd reconsec
bash recon.sh
```
> ⚠️ Git Bash tidak punya `nmap`, `dig`, `whois`, & chromium — RECON jalan mode kacang (fallback curl/grep aktif), tapi hasil jauh lebih sedikit. **Pakai WSL2 kalau serius.**

---

### 🍎 5. macOS (Experimental)

```bash
brew install git curl jq nmap whois whatweb openssl unzip go
git clone https://github.com/andisec/reconsec.git
cd reconsec
chmod +x recon.sh
bash recon.sh
```
> ⚠️ `dig` sudah bawaan macOS. `dnsutils`/`apt` tidak ada → script akan skip auto-install apt, tapi dependency-free fallback tetap jalan penuh.

---

## 🧰 31 Features

### 🎯 Recon Core
| # | Feature | Tools / Method |
|---|---------|----------------|
| 1 | **FULL AUTO SCAN** — runs everything below in sequence | ⭐ |
| 2 | Subdomain Enumeration | subfinder, assetfinder, crt.sh, hackertarget, Chaos API |
| 3 | Live Host Detection | httpx (+ curl fallback) |
| 4 | Port Scanning | nmap top-1000 |
| 5 | Directory & File Brute Force | ffuf + SecLists |
| 6 | Wayback / JS / Parameter Extraction | waybackurls, archive.org |
| 7 | DNS Records & WHOIS | dig, whois, dnsx |
| 8 | Technology Detection | whatweb, httpx tech-detect |

### 💥 Vulnerability & Payload
| # | Feature | Tools / Method |
|---|---------|----------------|
| 9 | Vulnerability Scan | nuclei (misconfig, exposure, CVE, unauth) |
| 10 | Subdomain Takeover Check | subzy, nuclei, CNAME fingerprint fallback |
| 11 | Screenshot Live Hosts | gowitness, aquatone |
| 12 | Email & Username Harvesting | theHarvester, wayback grep, homepage grep |
| 13 | Secret & API Key Scanner | AWS, Google, GitHub, Slack, Stripe, private keys in JS |
| 14 | Parameter Fuzzing | arjun, reflection probe fallback |
| 15 | CORS Misconfiguration Check | evil-origin reflection (curl) |
| 20 | Security Headers Audit | grade A–F per host (curl, zero deps) |
| 21 | XSS Scanner | dalfox on wayback parameter URLs |
| 22 | WAF Detection | wafw00f, header fingerprinting |

### 🔎 Advanced Recon
| # | Feature | Tools / Method |
|---|---------|----------------|
| 23 | Subdomain Permutation | alterx, 40-prefix generator + resolver fallback |
| 24 | TLS/SSL Analysis | cert SAN extraction, SSLv2/v3/TLS1.0 check, testssl.sh |
| 25 | Google Dork Generator | 45+ ready-to-use dorks |
| 26 | VHost Fuzzing | ffuf Host-header fuzz with auto-calibration |
| 27 | Reverse IP Neighbors | shared-hosting domain discovery |
| 28 | Mobile App Recon | APK → endpoints, API keys, emails (apkleaks / unzip+grep) |

### 🤖 Automation & Reporting
| # | Feature | Description |
|---|---------|-------------|
| 16 | Batch Mode | Scan unlimited domains from `targets.txt` |
| 17 | Asset Monitoring | Diff old vs new scan → detect new attack surface |
| 18 | HTML Export | Static, clean dark-theme report |
| 19 | Markdown Report | Auto-generated `REPORT.md` with all metrics |
| 29 | Cron Auto Re-scan | Daily scheduled scan via `--auto` CLI mode |
| 30 | Interactive Dashboard | Searchable/filterable HTML dashboard |
| 31 | Config Wizard | `recon.conf` + API keys (Chaos, Shodan, Censys, Hunter) |

---

## 🖥️ Usage

### Interactive Mode
```bash
./recon.sh
```
```
================= [ MENU RECON v4.0 PRO ] =================
--- Scan Utama ---
 1. FULL AUTO SCAN (semua fitur sekali jalan)
 2. Subdomain Enumeration      3. Live Host Detection
 4. Port Scanning (nmap)       5. Directory Brute Force
 ...
 0. Exit
===========================================================
```

### CLI Mode (for cron / CI / automation)
```bash
./recon.sh --auto example.com      # full auto scan, non-interactive
./recon.sh --batch targets.txt     # batch scan many domains
```

### Daily Monitoring (cron)
```bash
# menu 29 sets this up for you — or manually:
crontab -e
0 6 * * * /path/to/recon.sh --auto example.com >> ~/recon_cron.log 2>&1
```

### WAF-Aware Scanning
When a WAF (Cloudflare, Akamai, ModSecurity, Imperva, Sucuri...) is detected, RECON **automatically lowers scan rates** to avoid getting blocked mid-scan:
```
[!] WAF AKTIF (Cloudflare) — rate scan otomatis DITURUNKAN:
    threads: 40 -> 10 | ffuf: 50 -> 10 | nmap rate: 1000 -> 300
```

---

## 📂 Output Structure

```
recon_results/example.com-20261010_080000/
├── REPORT.md              # summary report (all metrics)
├── recon.log              # full process log
├── subdomains/            # subs + permutation results
├── live/                  # live hosts + tech detect
├── ports/                 # nmap results (.nmap/.gnmap/.xml)
├── dirs/                  # directory brute force (CSV)
├── wayback/               # wayback URLs, JS files, parameters
├── dns/                   # DNS records + whois
├── tech/                  # web technologies
├── nuclei/                # vulnerability findings
├── xss/                   # dalfox findings
├── takeover/              # takeover candidates
├── screenshots/           # live host screenshots
├── emails/                # harvested emails
├── secrets/               # API keys found in JS
├── params/                # hidden/reflected parameters
├── cors/                  # CORS audit
├── headers/               # security headers grades
├── waf/                   # WAF detection
├── tls/                   # TLS analysis + cert SAN
├── dorks/                 # generated google dorks
├── vhost/                 # vhost fuzzing results
├── reverseip/             # shared-hosting neighbors
└── mobile/                # APK recon results
```

---

## 📦 Dependencies

### Core (auto-installed via apt)
`curl` `jq` `nmap` `whois` `dig` `whatweb` `openssl` `unzip`

### Go Tools (auto-installed via `go install`)
`subfinder` `assetfinder` `httpx` `dnsx` `waybackurls` `ffuf` `nuclei` `gowitness` `dalfox` `alterx`

> RECON installs what's missing at startup — but **every module has a dependency-free fallback**, so missing tools only mean reduced depth, never a crash.

### Optional (for extra depth)
`testssl.sh` · `theHarvester` · `arjun` · `subzy` · `apkleaks` · `wafw00f` · `chromium` (for screenshots)

---

## ⚙️ Configuration (recon.conf)

Run **menu 31** (or create `~/recon.conf`) to unlock more passive sources:

```ini
CHAOS_KEY=""          # https://chaos.projectdiscovery.io
SHODAN_KEY=""         # https://shodan.io
CENSYS_ID=""          # https://search.censys.io
CENSYS_SECRET=""
HUNTER_KEY=""         # https://hunter.io
```

API keys are automatically written to subfinder's `provider-config.yaml` — subdomain results typically **increase 2–5×**.

---

## 📊 Example Output

```
╔═══════════════════════════════════════════════════╗
║           SCAN SELESAI — RINGKASAN v4.0 PRO       ║
╠═══════════════════════════════════════════════════╣
║  Target            : example.com                  ║
║  Subdomain         : 247                          ║
║  Live host         : 84                           ║
║  Port terbuka      : 231                          ║
║  Nuclei findings   : 9                            ║
║  Secret terkonfirmasi: 2                          ║
║  XSS / CORS bad    : 3 / 1                        ║
║  Header E/F / TLS  : 12 / 1                       ║
║  WAF               : YA (Cloudflare) — rate turun ║
║  Step OK / Gagal   : 22 / 0                       ║
╚═══════════════════════════════════════════════════╝
```

---

## 🧭 Roadmap

- [ ] Notifikasi Telegram/Discord
- [ ] Docker & Docker-Compose support
- [ ] Report PDF export
- [ ] Multi-user API (REST)
- [ ] Nuclei custom template packs

---

## 🤝 Contributing

Pull requests are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

1. Fork the repo
2. Create your branch (`git checkout -b feature/amazing`)
3. Commit (`git commit -m 'Add amazing feature'`)
4. Push (`git push origin feature/amazing`)
5. Open a PR

---

## ⚠️ Legal Disclaimer

```
This tool is provided for EDUCATIONAL and AUTHORIZED TESTING purposes only.
You are responsible for your own actions. Only use RECON against targets
you have explicit written permission to test (bug bounty programs with
defined scope, or contracted penetration tests).

Unauthorized scanning or attacking systems you don't own is ILLEGAL
(in Indonesia: UU ITE No. 11/2008 & UU No. 19/2016, and similar laws
worldwide). The authors accept no liability for misuse.
```

---

## 📜 License

Distributed under the [MIT License](LICENSE).

---

## 🙏 Acknowledgements

Built on the shoulders of giants — huge thanks to:

[ProjectDiscovery](https://github.com/projectdiscovery) (subfinder, httpx, nuclei, dnsx, alterx) · [Tomnomnom](https://github.com/tomnomnom) (assetfinder, waybackurls) · [ffuf](https://github.com/ffuf/ffuf) · [dalfox](https://github.com/hahwul/dalfox) · [gowitness](https://github.com/sensepost/gowitness) · [SecLists](https://github.com/danielmiessler/SecLists) · and the whole infosec community.

---

<div align="center">

**Made with 🔥 for the bug bounty community**

`RECON v4.0 PRO` — by **andisec**

</div>
