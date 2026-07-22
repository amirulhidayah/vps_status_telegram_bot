<div align="center">
  <br/>
  <img src="https://img.shields.io/badge/Platform-Linux-FF6C37?style=for-the-badge&logo=linux&logoColor=white" />
  <img src="https://img.shields.io/badge/Bash-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white" />
  <img src="https://img.shields.io/badge/Telegram_Bot-26A5E4?style=for-the-badge&logo=telegram&logoColor=white" />
  <img src="https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white" />
  <br/><br/>
</div>

<h1 align="center">
  🖥️ VPS Monitor — Telegram Bot
</h1>

<p align="center">
  <b>Monitor VPS, website, dan Docker langsung dari Telegram.</b>
  <br/>
  Satu perintah install — ringan, tanpa database, tanpa dashboard.
</p>

<br/>

<p align="center">
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" />
  <img src="https://img.shields.io/badge/status-stable-brightgreen?style=flat-square" />
  <img src="https://img.shields.io/github/issues-raw/hiday/your-repo?style=flat-square" />
</p>

<br/>

---

## 📋 Daftar Isi

- [✨ Fitur](#-fitur)
- [🚀 Instalasi 1 Detik](#-instalasi-1-detik)
- [📸 Contoh Output](#-contoh-output)
- [⚙️ Cara Kerja](#️-cara-kerja)
- [📁 Struktur Project](#-struktur-project)
- [💬 Perintah Telegram](#-perintah-telegram)
- [🛠️ Manajemen](#️-manajemen)
- [🧩 Requirements](#-requirements)
- [📄 Lisensi](#-lisensi)

---

## ✨ Fitur

| Fitur | Detail |
|-------|--------|
| ⚡ **Install 1 command** | Semua file + systemd auto setup |
| 🌐 **Cek Website** | HTTP status & response time |
| 🖥️ **Cek VPS** | CPU, RAM, Disk, Uptime, Hostname |
| 🐳 **Cek Docker** | Container running/stopped + status |
| 🤖 **Telegram Bot** | Perintah `/status`, `/help`, `/start` |
| ⏰ **Laporan Otomatis** | Tiap 3 jam via systemd timer |
| 🔄 **Auto-restart** | Bot restart otomatis jika crash |
| 🎯 **Multi-Arch** | Ubuntu, Debian, CentOS, Fedora |

---

## 🚀 Instalasi 1 Detik

### 🔹 Interaktif (paling gampang)

```bash
sudo bash vps-monitor-installer.sh
```

---

## 📸 Contoh Output

**Kirim `/status` ke bot Telegram:** 

```
✅ ONLINE WEBSITE
HTTP : 200
Time : 0.126s

🖥️ VPS                     vps-production
CPU :                      6%
RAM :                      2.4Gi / 8Gi (30%)
Disk :                     82G / 160G (51%)
Uptime :                   14 days

🐳 DOCKER

Running : 6
Stopped : 0

 ✅ coraza
 ✅ web
 ✅ scheduler
 ✅ queue
 ✅ mysql
 ✅ pma

📅 22-07-2026 22:30:00 WITA
```

> Kirim `/help` untuk daftar perintah lengkap.

---

## ⚙️ Cara Kerja

```
┌─────────────────────────────────────────────────┐
│                   VPS Anda                       │
│                                                  │
│  ┌──────────┐    ┌───────────────────────────┐   │
│  │ bot.sh   │◄──►│ Telegram API              │   │
│  │(long poll)│   │ (getUpdates/sendMessage)  │   │
│  └────┬─────┘    └───────────┬───────────────┘   │
│       │                      │                    │
│  ┌────▼─────┐                │                    │
│  │status.sh │                │                    │
│  │  CPU     │◄───────────────┘                    │
│  │  RAM     │                                     │
│  │  Disk    │         📱 Telegram                  │
│  │  Docker  │    ┌──────────────┐                 │
│  └────┬─────┘    │  /status     │                 │
│       │          │  /help       │                 │
│  ┌────▼─────┐    │  auto report │                 │
│  │send.sh   │────►│  (3 jam)    │                 │
│  └──────────┘    └──────────────┘                 │
└─────────────────────────────────────────────────┘
```

Ada **2 mode**:

1. **Bot Mode** — `bot.sh` jalan terus sebagai service, dengerin perintah `/status` via long-polling
2. **Report Mode** — `report.sh` dipanggil systemd timer tiap 3 jam, ngirim laporan otomatis

---

## 📁 Struktur Project

```
/opt/vps-monitor/
├── config.sh                 # Token & konfigurasi (auto-generate)
├── bot.sh                    # Long-polling Telegram bot
├── report.sh                 # Laporan otomatis 3 jam
├── script/
│   ├── send.sh               # Kirim pesan ke Telegram
│   └── status.sh             # Ambil status VPS (CPU, RAM, Disk, Docker)
├── state/
│   └── offset.dat            # Tracker update_id (anti duplikat pesan)
├── logs/
│   └── bot.log               # Log aktivitas bot
└── services/
    ├── telegram-bot.service
    ├── telegram-report.service
    └── telegram-report.timer
```

---

## 💬 Perintah Telegram

| Perintah | Fungsi |
|----------|--------|
| `/status` | Cek status VPS, website, dan Docker |
| `/help` | Tampilkan daftar perintah |
| `/start` | Pesan selamat datang |

Selain itu, bot otomatis kirim laporan **setiap 3 jam** tanpa perlu diminta.

---

## 🛠️ Manajemen

```bash
# Cek status bot
sudo systemctl status telegram-bot

# Restart bot
sudo systemctl restart telegram-bot

# Stop bot
sudo systemctl stop telegram-bot

# Lihat log realtime
journalctl -u telegram-bot -f

# Lihat log report
journalctl -u telegram-report.service -f

# Trigger report manual (tanpa nunggu 3 jam)
sudo systemctl start telegram-report.service

# Cek jadwal timer
systemctl list-timers telegram-report.timer
```

---

## 🧩 Requirements

- **OS**: Linux (Ubuntu, Debian, CentOS, Fedora, dll)
- **Paket**: `curl`, `jq`, `bc` — diinstall otomatis oleh script
- **Telegram**: BOT_TOKEN (dari @BotFather) & CHAT_ID (dari @userinfobot)
- **Docker**: Opsional — status Docker otomatis terdeteksi jika terinstall
- **Akses**: `sudo` atau root

### Cara dapatin BOT_TOKEN & CHAT_ID:

<details>
<summary>📖 Buka panduan lengkap</summary>

**BOT_TOKEN:**
1. Buka Telegram, cari `@BotFather`
2. Kirim `/newbot`
3. Masukkan nama & username bot
4. Simpan token yang dikasih BotFather

**CHAT_ID:**
1. Buka Telegram, cari `@userinfobot`
2. Klik Start
3. Bot akan kirim info kamu — `Id` adalah CHAT_ID
</details>

---

## 📄 Lisensi

Distributed under the **MIT License**. See `LICENSE` for more information.

---

<p align="center">
  <a href="#">↑ Kembali ke atas</a>
</p>
