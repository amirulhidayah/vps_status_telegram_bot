#!/bin/bash
# ============================================================================
# VPS Monitor Telegram Bot - Standalone Installer
# ============================================================================
# Single command installer untuk bot Telegram monitoring VPS.
# Semua file di-embed dalam 1 file ini.
#
# Penggunaan:
#   # Interaktif (akan minta input)
#   bash vps-monitor-installer.sh
#
#   # Non-interaktif via argumen
#   bash vps-monitor-installer.sh \
#       --token="123456:ABC..." \
#       --chat="987654321" \
#       --url="https://domainanda.com"
#
#   # Via curl langsung (tanpa download)
#   bash <(curl -sSL https://yourdomain.com/vps-monitor-installer.sh) \
#       --token="123456:ABC..." \
#       --chat="987654321" \
#       --url="https://domainanda.com"
# ============================================================================

set -euo pipefail
IFS=$'\n\t'

# --- Warna untuk output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Default values ---
INSTALL_DIR="/opt/vps-monitor"
BOT_TOKEN=""
CHAT_ID=""
CHECK_URL=""
TZ_VALUE="Asia/Makassar"
SCRIPT_MODE="interactive"   # interactive / non-interactive

# ============================================================================
# Fungsi bantuan
# ============================================================================

print_banner() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           VPS Monitor Telegram Bot               ║${NC}"
    echo -e "${CYAN}║          Standalone Installer v1.0               ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

info()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[✗]${NC} $1"; }
step()  { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${NC}"; }

# ============================================================================
# Parse argumen CLI
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --token=*)
                BOT_TOKEN="${1#*=}"
                SCRIPT_MODE="non-interactive"
                shift
                ;;
            --chat=*)
                CHAT_ID="${1#*=}"
                SCRIPT_MODE="non-interactive"
                shift
                ;;
            --url=*)
                CHECK_URL="${1#*=}"
                SCRIPT_MODE="non-interactive"
                shift
                ;;
            --dir=*)
                INSTALL_DIR="${1#*=}"
                shift
                ;;
            --tz=*)
                TZ_VALUE="${1#*=}"
                shift
                ;;
            --help|-h)
                echo "Penggunaan: bash $0 [options]"
                echo ""
                echo "Options:"
                echo "  --token=TOKEN     BOT_TOKEN dari @BotFather (wajib non-interaktif)"
                echo "  --chat=CHAT_ID    CHAT_ID dari @userinfobot (wajib non-interaktif)"
                echo "  --url=URL         URL website untuk di-monitor (wajib non-interaktif)"
                echo "  --dir=PATH        Direktori instalasi (default: /opt/vps-monitor)"
                echo "  --tz=TZ           Timezone (default: Asia/Makassar)"
                echo "  --help, -h        Tampilkan pesan bantuan ini"
                echo ""
                echo "Contoh:"
                echo "  # Interaktif:"
                echo "    bash $0"
                echo ""
                echo "  # Non-interaktif:"
                echo "    bash $0 --token=\"123:ABC\" --chat=\"123\" --url=\"https://example.com\""
                exit 0
                ;;
            *)
                error "Argumen tidak dikenal: $1"
                echo "Gunakan --help untuk bantuan."
                exit 1
                ;;
        esac
    done
}

# ============================================================================
# Input interaktif
# ============================================================================

prompt_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    local input

    if [[ -n "$default" ]]; then
        read -p "$(echo -e "${CYAN}?${NC} ${prompt} [${default}]: ")" input
        input="${input:-$default}"
    else
        read -p "$(echo -e "${CYAN}?${NC} ${prompt}: ")" input
    fi

    eval "$var_name=\"$input\""
}

get_user_input() {
    print_banner

    echo -e "Masukkan konfigurasi bot Telegram. Biarkan kosong untuk default.\n"

    prompt_input "BOT_TOKEN (dari @BotFather)" "" "BOT_TOKEN"
    prompt_input "CHAT_ID (dari @userinfobot)" "" "CHAT_ID"
    prompt_input "URL website untuk di-monitor" "" "CHECK_URL"
    prompt_input "Direktori instalasi" "${INSTALL_DIR}" "INSTALL_DIR"
    prompt_input "Timezone" "${TZ_VALUE}" "TZ_VALUE"

    # Bersihkan trailing slash dari URL
    CHECK_URL="${CHECK_URL%/}"

    echo ""
    echo -e "${YELLOW}Ringkasan konfigurasi:${NC}"
    echo -e "  BOT_TOKEN    : ${BOT_TOKEN:0:10}...${BOT_TOKEN: -5}"
    echo -e "  CHAT_ID      : $CHAT_ID"
    echo -e "  CHECK_URL    : $CHECK_URL"
    echo -e "  INSTALL_DIR  : $INSTALL_DIR"
    echo -e "  TIMEZONE     : $TZ_VALUE"
    echo ""

    read -p "$(echo -e "${CYAN}?${NC} Lanjutkan instalasi? [Y/n]: ")" confirm
    confirm="${confirm:-Y}"
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        error "Dibatalkan oleh user."
        exit 1
    fi
}

validate_config() {
    local error_count=0

    if [[ -z "$BOT_TOKEN" ]]; then
        error "BOT_TOKEN tidak boleh kosong"
        error_count=$((error_count+1))
    fi

    if [[ -z "$CHAT_ID" ]]; then
        error "CHAT_ID tidak boleh kosong"
        error_count=$((error_count+1))
    fi

    if [[ -z "$CHECK_URL" ]]; then
        error "CHECK_URL tidak boleh kosong"
        error_count=$((error_count+1))
    fi

    if [[ $error_count -gt 0 ]]; then
        echo ""
        error "Ada ${error_count} error. Perbaiki lalu jalankan ulang."
        exit 1
    fi
}

# ============================================================================
# Step 1: Cek & Install dependencies
# ============================================================================

install_deps() {
    step "1/8 — Memeriksa & Menginstall Paket"

    local deps=("curl" "jq" "bc")
    local install_list=()

    for pkg in "${deps[@]}"; do
        if command -v "$pkg" &>/dev/null; then
            info "$pkg sudah terinstall"
        else
            warn "$pkg belum terinstall"
            install_list+=("$pkg")
        fi
    done

    if [[ ${#install_list[@]} -gt 0 ]]; then
        echo "  Menginstall: ${install_list[*]} ..."
        if command -v apt &>/dev/null; then
            sudo apt update -qq && sudo apt install -y -qq "${install_list[@]}"
        elif command -v yum &>/dev/null; then
            sudo yum install -y "${install_list[@]}"
        elif command -v dnf &>/dev/null; then
            sudo dnf install -y "${install_list[@]}"
        else
            error "Tidak bisa detect package manager. Install manual: ${install_list[*]}"
            exit 1
        fi
        info "Paket berhasil diinstall"
    fi
}

# ============================================================================
# Step 2: Buat direktori project
# ============================================================================

create_dirs() {
    step "2/8 — Membuat Struktur Direktori"

    sudo mkdir -p "$INSTALL_DIR"/{script,state,logs,services}
    sudo chmod 755 "$INSTALL_DIR"
    info "Direktori dibuat di: $INSTALL_DIR"

    BASE_DIR="$INSTALL_DIR"
}

# ============================================================================
# Step 3: Buat config.sh
# ============================================================================

create_config() {
    step "3/8 — Membuat config.sh"

    sudo tee "$BASE_DIR/config.sh" > /dev/null <<CONFIGEOF
#!/bin/bash
# ============================================================================
# Konfigurasi VPS Monitor Telegram Bot
# ============================================================================
# File ini digenerate otomatis oleh installer.
# Jangan diedit langsung — jalankan ulang installer untuk reset.

# ========== TELEGRAM ==========
BOT_TOKEN="${BOT_TOKEN}"
CHAT_ID="${CHAT_ID}"

# ========== WEBSITE ==========
CHECK_URL="${CHECK_URL}"

# ========== TIMEZONE ==========
export TZ="${TZ_VALUE}"

# ========== INTERVAL ==========
REPORT_INTERVAL=10800
CONFIGEOF

    sudo chmod +x "$BASE_DIR/config.sh"
    info "config.sh dibuat"
}

# ============================================================================
# Step 4: Buat script/send.sh
# ============================================================================

create_send() {
    step "4/8 — Membuat script/send.sh"

    sudo tee "$BASE_DIR/script/send.sh" > /dev/null <<'SENDEOF'
#!/bin/bash
# ============================================================================
# Kirim pesan ke Telegram
# ============================================================================
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.sh"

TEXT="$1"

if [[ -z "$TEXT" ]]; then
    echo "Usage: $0 <message_text>"
    exit 1
fi

HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
    "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d chat_id="$CHAT_ID" \
    --data-urlencode text="${TEXT}")

if [ "$HTTP_CODE" = "200" ]; then
    echo "Pesan terkirim."
else
    echo "Gagal mengirim pesan (HTTP $HTTP_CODE)."
    exit 1
fi
SENDEOF

    sudo chmod +x "$BASE_DIR/script/send.sh"
    info "script/send.sh dibuat"
}

# ============================================================================
# Step 5: Buat script/status.sh (script utama)
# ============================================================================

create_status() {
    step "5/8 — Membuat script/status.sh"

    sudo tee "$BASE_DIR/script/status.sh" > /dev/null <<'STATUSEOF'
#!/bin/bash
# ============================================================================
# Script utama: ambil status VPS, website, dan Docker
# ============================================================================
BASE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
source "$BASE_DIR/config.sh"

#################################
# WEBSITE CHECK
#################################
HTTP=$(curl -o /dev/null -s -w "%{http_code}" --max-time 10 "$CHECK_URL")
TIME=$(curl -o /dev/null -s -w "%{time_total}" --max-time 10 "$CHECK_URL")

if [ "$HTTP" = "200" ]; then
    WEB_STATUS="✅ ONLINE WEBSITE"
else
    WEB_STATUS="❌ DOWN WEBSITE"
fi

#################################
# VPS INFORMATION
#################################
HOST=$(hostname)
UPTIME=$(uptime -p | sed 's/up //')

# CPU Usage
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d ',')
if [ -z "$CPU_IDLE" ]; then
    CPU=0
else
    CPU=$(awk "BEGIN {printf \"%.0f\", 100-$CPU_IDLE}")
fi

# RAM Usage
RAM_USED=$(free -h | awk '/Mem:/ {print $3}')
RAM_TOTAL=$(free -h | awk '/Mem:/ {print $2}')
RAM_PERCENT=$(free | awk '/Mem:/ {printf("%.0f", $3/$2*100)}')

# Disk Usage
DISK_USED=$(df -h / | awk 'NR==2 {print $3}')
DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
DISK_PERCENT=$(df -h / | awk 'NR==2 {print $5}')

#################################
# DOCKER INFORMATION
#################################
if command -v docker &>/dev/null; then
    DOCKER_RUNNING=$(docker ps --format "{{.Names}}" 2>/dev/null | wc -l)
    DOCKER_STOPPED=$(docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null | wc -l)

    DOCKER_LIST=$(docker ps -a --format "{{.Names}}|{{.Status}}" 2>/dev/null | while IFS="|" read -r NAME STATUS
    do
        if [[ "$STATUS" == Up* ]]; then
            echo " ✅ $NAME"
        else
            echo " ❌ $NAME"
        fi
    done)

    DOCKER_SECTION="🐳 DOCKER

Running : $DOCKER_RUNNING
Stopped : $DOCKER_STOPPED
$DOCKER_LIST"
else
    DOCKER_SECTION="🐳 DOCKER
(tidak terinstall)"
fi

#################################
# TIMESTAMP
#################################
DATE=$(date +"%d-%m-%Y %H:%M:%S WITA %Z")

#################################
# OUTPUT
#################################
cat <<EOF
$WEB_STATUS
HTTP : $HTTP
Time : ${TIME}s

🖥️ VPS                     $HOST
CPU :                      ${CPU}%
RAM :                      $RAM_USED / $RAM_TOTAL (${RAM_PERCENT}%)
Disk :                     $DISK_USED / $DISK_TOTAL ($DISK_PERCENT)
Uptime :                   $UPTIME

$DOCKER_SECTION

📅 $DATE
EOF
STATUSEOF

    sudo chmod +x "$BASE_DIR/script/status.sh"
    info "script/status.sh dibuat"
}

# ============================================================================
# Step 6: Buat bot.sh (long polling)
# ============================================================================

create_bot() {
    step "6/8 — Membuat bot.sh"

    sudo tee "$BASE_DIR/bot.sh" > /dev/null <<'BOTEOF'
#!/bin/bash
# ============================================================================
# Long-polling Telegram Bot — mendengarkan perintah /status
# ============================================================================
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$BASE_DIR/config.sh"

OFFSET_FILE="$BASE_DIR/state/offset.dat"
LOG_FILE="$BASE_DIR/logs/bot.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log "Bot started"

if [ ! -f "$OFFSET_FILE" ]; then
    echo "0" > "$OFFSET_FILE"
fi

while true; do
    OFFSET=$(cat "$OFFSET_FILE")

    JSON=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates?offset=${OFFSET}&timeout=30")

    COUNT=$(echo "$JSON" | jq '.result | length' 2>/dev/null || echo "0")

    if [ "$COUNT" -gt 0 ]; then
        echo "$JSON" | jq -c '.result[]' 2>/dev/null | while read -r UPDATE; do
            UPDATE_ID=$(echo "$UPDATE" | jq '.update_id')
            NEXT_OFFSET=$((UPDATE_ID + 1))
            echo "$NEXT_OFFSET" > "$OFFSET_FILE"

            TEXT=$(echo "$UPDATE" | jq -r '.message.text // ""')
            CHAT=$(echo "$UPDATE" | jq -r '.message.chat.id // "0"')

            # Hanya layani CHAT_ID yang diizinkan
            if [ "$CHAT" != "$CHAT_ID" ]; then
                log "Ignored message from unauthorized chat: $CHAT"
                continue
            fi

            case "$TEXT" in
                "/status")
                    log "Processing /status request"
                    MESSAGE=$("$BASE_DIR/script/status.sh")
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                        -d chat_id="$CHAT_ID" \
                        --data-urlencode text="$MESSAGE" \
                        > /dev/null
                    log "Status sent"
                    ;;
                "/start")
                    WELCOME="✅ VPS Monitor aktif!

Perintah:
/status — Lihat status VPS, website & Docker
/help — Bantuan ini"
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                        -d chat_id="$CHAT_ID" \
                        --data-urlencode text="$WELCOME" \
                        > /dev/null
                    log "Welcome sent"
                    ;;
                "/help")
                    HELP="📋 Daftar perintah:

/status  — Cek status VPS, website, dan Docker
/help    — Tampilkan bantuan ini

Bot akan mengirim laporan otomatis setiap 3 jam."
                    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
                        -d chat_id="$CHAT_ID" \
                        --data-urlencode text="$HELP" \
                        > /dev/null
                    log "Help sent"
                    ;;
                *)
                    # Abaikan perintah tidak dikenal
                    ;;
            esac
        done
    fi

    sleep 1
done
BOTEOF

    sudo chmod +x "$BASE_DIR/bot.sh"
    info "bot.sh dibuat"
}

# ============================================================================
# Step 7: Buat report.sh
# ============================================================================

create_report() {
    step "7/8 — Membuat report.sh"

    sudo tee "$BASE_DIR/report.sh" > /dev/null <<'REPORTEOF'
#!/bin/bash
# ============================================================================
# Kirim laporan otomatis (dipanggil oleh systemd timer tiap 3 jam)
# ============================================================================
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$BASE_DIR/config.sh"
MESSAGE=$("$BASE_DIR/script/status.sh")
"$BASE_DIR/script/send.sh" "$MESSAGE"
REPORTEOF

    sudo chmod +x "$BASE_DIR/report.sh"
    info "report.sh dibuat"
}

# ============================================================================
# Step 8: Buat systemd service & timer
# ============================================================================

create_systemd() {
    step "8/8 — Membuat & Mengaktifkan Systemd Service"

    local BASE_DIR="$INSTALL_DIR"

    # --- telegram-bot.service ---
    sudo tee "$BASE_DIR/services/telegram-bot.service" > /dev/null <<SERVICEEOF
[Unit]
Description=Telegram VPS Status Bot
After=network.target

[Service]
Type=simple
WorkingDirectory=${BASE_DIR}
ExecStart=${BASE_DIR}/bot.sh
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
SERVICEEOF

    # --- telegram-report.service ---
    sudo tee "$BASE_DIR/services/telegram-report.service" > /dev/null <<REPORTSERVICEEOF
[Unit]
Description=Telegram VPS Status Report

[Service]
Type=oneshot
WorkingDirectory=${BASE_DIR}
ExecStart=${BASE_DIR}/report.sh
REPORTSERVICEEOF

    # --- telegram-report.timer ---
    sudo tee "$BASE_DIR/services/telegram-report.timer" > /dev/null <<TIMEREOF
[Unit]
Description=Send VPS Status Every 3 Hours

[Timer]
OnBootSec=10min
OnUnitActiveSec=3h
Persistent=true

[Install]
WantedBy=timers.target
TIMEREOF

    info "File service/timer dibuat di $BASE_DIR/services/"

    # Install ke systemd
    echo "  Menginstall ke /etc/systemd/system/ ..."
    sudo cp "$BASE_DIR/services/telegram-bot.service" /etc/systemd/system/
    sudo cp "$BASE_DIR/services/telegram-report.service" /etc/systemd/system/
    sudo cp "$BASE_DIR/services/telegram-report.timer" /etc/systemd/system/
    sudo systemctl daemon-reload

    # Enable & start
    sudo systemctl enable telegram-bot
    sudo systemctl start telegram-bot
    info "telegram-bot.service → aktif"

    sudo systemctl enable telegram-report.timer
    sudo systemctl start telegram-report.timer
    info "telegram-report.timer → aktif"
}

# ============================================================================
# Final: Tes & Ringkasan
# ============================================================================

final_check() {
    step "✅ Final — Verifikasi & Informasi"

    echo ""
    echo -e "${BOLD}Status:${NC}"
    echo ""

    # Cek service
    if systemctl is-active --quiet telegram-bot; then
        info "telegram-bot.service    : RUNNING"
    else
        warn "telegram-bot.service    : NOT RUNNING (cek: sudo systemctl status telegram-bot)"
    fi

    if systemctl is-active --quiet telegram-report.timer; then
        info "telegram-report.timer   : ACTIVE"
    else
        warn "telegram-report.timer   : NOT ACTIVE"
    fi

    echo ""
    echo -e "${BOLD}Struktur direktori:${NC}"
    echo ""
    tree "$INSTALL_DIR" -L 2 2>/dev/null || find "$INSTALL_DIR" -maxdepth 2 -not -path '*/\.*' | sort

    echo ""
    echo -e "${BOLD}Cara penggunaan:${NC}"
    echo ""
    echo -e "  Kirim ${CYAN}/status${NC} ke bot Telegram untuk cek VPS"
    echo -e "  Kirim ${CYAN}/help${NC} untuk daftar perintah"
    echo ""
    echo -e "  Lihat log bot:   ${YELLOW}journalctl -u telegram-bot -f${NC}"
    echo -e "  Lihat log timer: ${YELLOW}journalctl -u telegram-report.service -f${NC}"
    echo ""
    echo -e "  Trigger report manual: ${YELLOW}sudo systemctl start telegram-report.service${NC}"
    echo ""
    echo -e "  Restart bot:           ${YELLOW}sudo systemctl restart telegram-bot${NC}"
    echo ""

    # Tes kirim pesan
    echo -e "${BOLD}Mengirim pesan tes ke Telegram...${NC}"
    TEST_MSG="✅ VPS Monitor berhasil diinstall!

Host : $(hostname)
Tanggal : $(date)
Installasi: ${INSTALL_DIR}"

    if sudo "$INSTALL_DIR/script/send.sh" "$TEST_MSG"; then
        info "Pesan tes terkirim! Cek Telegram kamu."
    else
        warn "Gagal kirim pesan tes. Cek BOT_TOKEN dan CHAT_ID."
    fi

    echo ""
    echo -e "${GREEN}${BOLD}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║   INSTALASI SELESAI! 🎉              ║${NC}"
    echo -e "${GREEN}${BOLD}╚══════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    # Parse argumen CLI
    parse_args "$@"

    # Cek root / sudo access
    if [[ $EUID -ne 0 ]] && ! command -v sudo &>/dev/null; then
        error "Script ini butuh akses root/sudo. Jalankan dengan: sudo bash $0"
        exit 1
    fi

    # Input interaktif jika tidak ada argumen
    if [[ "$SCRIPT_MODE" == "interactive" ]]; then
        get_user_input
    else
        print_banner
    fi

    # Validasi (dipanggil sekali untuk kedua mode)
    validate_config

    # Eksekusi
    install_deps
    create_dirs
    create_config
    create_send
    create_status
    create_bot
    create_report
    create_systemd
    final_check
}

main "$@"
