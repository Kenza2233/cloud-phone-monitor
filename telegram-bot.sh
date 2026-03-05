#!/bin/bash
#===============================================================================
# CLOUD PHONE MONITOR - Telegram Bot Handler
# Script untuk terima command dari Telegram bot
# Run sebagai background service untuk listen commands
#===============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"
BOT_LOG="${SCRIPT_DIR}/bot.log"
BOT_PID="${SCRIPT_DIR}/bot.pid"
MONITOR_SCRIPT="${SCRIPT_DIR}/monitor.sh"

# Telegram API base URL
TELEGRAM_API="https://api.telegram.org"

# Load config
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
    
    if [[ -z "$TELEGRAM_TOKEN" ]]; then
        echo -e "${RED}Error: TELEGRAM_TOKEN tidak dijumpai dalam config${NC}"
        exit 1
    fi
    
    # Parse apps
    APPS=()
    if [[ -n "$APP_LIST" ]]; then
        IFS=',' read -ra APPS <<< "$APP_LIST"
    fi
}

# Logging
log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] $1" >> "$BOT_LOG"
    echo -e "$1"
}

# Send Telegram message
send_message() {
    local chat_id="$1"
    local text="$2"
    local reply_to="$3"
    
    local url="${TELEGRAM_API}/bot${TELEGRAM_TOKEN}/sendMessage"
    local data="chat_id=${chat_id}&text=${text}&parse_mode=HTML"
    
    if [[ -n "$reply_to" ]]; then
        data+="&reply_to_message_id=${reply_to}"
    fi
    
    curl -s -X POST "$url" -d "$data" > /dev/null
}

# Send Telegram message with keyboard
send_message_with_keyboard() {
    local chat_id="$1"
    local text="$2"
    local keyboard="$3"
    
    local url="${TELEGRAM_API}/bot${TELEGRAM_TOKEN}/sendMessage"
    
    curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "{
            \"chat_id\": \"${chat_id}\",
            \"text\": \"${text}\",
            \"parse_mode\": \"HTML\",
            \"reply_markup\": ${keyboard}
        }" > /dev/null
}

# Create inline keyboard for apps
create_app_keyboard() {
    local action="$1"
    local keyboard='{"inline_button": [['
    local first=true
    
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r package_name app_name _ <<< "$app_entry"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            keyboard+=','
        fi
        
        keyboard+="{\"text\": \"${app_name}\", \"callback_data\": \"${action}_${package_name}\"}"
    done
    
    keyboard+=']]}'
    echo "$keyboard"
}

# Create main menu keyboard
create_main_keyboard() {
    echo '{
        "keyboard": [
            ["📊 Status", "📱 Open App"],
            ["🔄 Restart App", "⏹️ Stop App"],
            ["📈 Hourly Report", "🔔 Test"],
            ["❓ Help"]
        ],
        "resize_keyboard": true,
        "one_time_keyboard": false
    }'
}

# Handle incoming message
handle_message() {
    local chat_id="$1"
    local message_id="$2"
    local text="$3"
    local username="$4"
    local first_name="$5"
    
    # Authorization check
    if [[ -n "$TELEGRAM_CHAT_ID" && "$chat_id" != "$TELEGRAM_CHAT_ID" ]]; then
        log "${YELLOW}Unauthorized access from chat_id: $chat_id${NC}"
        send_message "$chat_id" "⛔ Unauthorized. Chat ID anda: <code>$chat_id</code>"
        return
    fi
    
    log "${CYAN}Command from $first_name: $text${NC}"
    
    # Parse command
    local cmd=$(echo "$text" | awk '{print tolower($1)}')
    local arg=$(echo "$text" | cut -d' ' -f2-)
    
    case "$cmd" in
        /start|start)
            handle_start "$chat_id" "$first_name"
            ;;
        /status|📊\ status|status)
            handle_status "$chat_id"
            ;;
        /open|📱\ open\ app|open)
            handle_open_menu "$chat_id"
            ;;
        /restart|🔄\ restart\ app|restart)
            handle_restart_menu "$chat_id"
            ;;
        /stop|⏹️\ stop\ app|stop)
            handle_stop_menu "$chat_id"
            ;;
        /report|📈\ hourly\ report|report)
            handle_report "$chat_id"
            ;;
        /test|🔔\ test|test)
            handle_test "$chat_id"
            ;;
        /help|❓\ help|help)
            handle_help "$chat_id"
            ;;
        /monitor)
            handle_monitor "$chat_id" "$arg"
            ;;
        /*)
            send_message "$chat_id" "Command tidak dijumpai. Taip /help untuk bantuan."
            ;;
        *)
            # Try to match package name
            handle_app_command "$chat_id" "$text"
            ;;
    esac
}

# Handle callback query (inline button)
handle_callback() {
    local chat_id="$1"
    local message_id="$2"
    local data="$3"
    local username="$4"
    
    # Authorization check
    if [[ -n "$TELEGRAM_CHAT_ID" && "$chat_id" != "$TELEGRAM_CHAT_ID" ]]; then
        return
    fi
    
    log "${CYAN}Callback: $data${NC}"
    
    local action=$(echo "$data" | cut -d'_' -f1)
    local package=$(echo "$data" | cut -d'_' -f2-)
    
    # Answer callback
    local answer_url="${TELEGRAM_API}/bot${TELEGRAM_TOKEN}/answerCallbackQuery"
    curl -s -X POST "$answer_url" -d "callback_query_id=${data}" > /dev/null
    
    case "$action" in
        open)
            do_open_app "$chat_id" "$package"
            ;;
        restart)
            do_restart_app "$chat_id" "$package"
            ;;
        stop)
            do_stop_app "$chat_id" "$package"
            ;;
        status)
            do_app_status "$chat_id" "$package"
            ;;
    esac
}

# Command handlers
handle_start() {
    local chat_id="$1"
    local name="$2"
    
    local keyboard=$(create_main_keyboard)
    
    send_message_with_keyboard "$chat_id" \
        "👋 Hello, <b>$name</b>!

📱 <b>Cloud Phone Monitor Bot</b>

Saya boleh membantu anda:
• 📊 Monitor status app
• 📱 Buka app secara remote
• 🔄 Restart app jika crash
• 📈 Hantar laporan berkala

Pilih command dari menu di bawah atau taip /help untuk senarai penuh." \
        "$keyboard"
}

handle_status() {
    local chat_id="$1"
    local status_text="📊 <b>Status Semua Apps</b>\n"
    status_text+="━━━━━━━━━━━━━━━━━━━━\n\n"
    
    local running=0
    local stopped=0
    local total=${#APPS[@]}
    
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r package_name app_name _ <<< "$app_entry"
        
        local status_emoji="🔴"
        local status_text_app="Stopped"
        
        # Check if app is running
        if $MONITOR_SCRIPT _check_running "$package_name" 2>/dev/null; then
            status_emoji="🟢"
            status_text_app="Running"
            ((running++))
        else
            ((stopped++))
        fi
        
        status_text+="${status_emoji} <b>${app_name}</b>\n"
        status_text+="   📦 <code>${package_name}</code>\n"
        status_text+="   📋 Status: ${status_text_app}\n\n"
    done
    
    status_text+="━━━━━━━━━━━━━━━━━━━━\n"
    status_text+="📈 <b>Summary:</b> ${running} Running, ${stopped} Stopped (${total} Total)\n"
    status_text+="🕐 Updated: $(date '+%Y-%m-%d %H:%M:%S')"
    
    send_message "$chat_id" "$status_text"
}

handle_open_menu() {
    local chat_id="$1"
    
    if [[ ${#APPS[@]} -eq 0 ]]; then
        send_message "$chat_id" "⚠️ Tiada app dikonfigurasikan."
        return
    fi
    
    local keyboard='{"inline_keyboard": [['
    local first=true
    
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r package_name app_name _ <<< "$app_entry"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            keyboard+=','
        fi
        
        keyboard+="{\"text\": \"📱 ${app_name}\", \"callback_data\": \"open_${package_name}\"}"
    done
    
    keyboard+=']]}'
    
    send_message_with_keyboard "$chat_id" \
        "📱 <b>Pilih App untuk Dibuka:</b>" \
        "$keyboard"
}

handle_restart_menu() {
    local chat_id="$1"
    
    if [[ ${#APPS[@]} -eq 0 ]]; then
        send_message "$chat_id" "⚠️ Tiada app dikonfigurasikan."
        return
    fi
    
    local keyboard='{"inline_keyboard": [['
    local first=true
    
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r package_name app_name _ <<< "$app_entry"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            keyboard+=','
        fi
        
        keyboard+="{\"text\": \"🔄 ${app_name}\", \"callback_data\": \"restart_${package_name}\"}"
    done
    
    keyboard+=']]}'
    
    send_message_with_keyboard "$chat_id" \
        "🔄 <b>Pilih App untuk Restart:</b>" \
        "$keyboard"
}

handle_stop_menu() {
    local chat_id="$1"
    
    if [[ ${#APPS[@]} -eq 0 ]]; then
        send_message "$chat_id" "⚠️ Tiada app dikonfigurasikan."
        return
    fi
    
    local keyboard='{"inline_keyboard": [['
    local first=true
    
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r package_name app_name _ <<< "$app_entry"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            keyboard+=','
        fi
        
        keyboard+="{\"text\": \"⏹️ ${app_name}\", \"callback_data\": \"stop_${package_name}\"}"
    done
    
    keyboard+=']]}'
    
    send_message_with_keyboard "$chat_id" \
        "⏹️ <b>Pilih App untuk Stop:</b>" \
        "$keyboard"
}

handle_report() {
    local chat_id="$1"
    $MONITOR_SCRIPT _hourly_report "$chat_id" 2>/dev/null
    send_message "$chat_id" "📈 Laporan dihantar ke Discord dan Telegram."
}

handle_test() {
    local chat_id="$1"
    $MONITOR_SCRIPT test 2>/dev/null
    send_message "$chat_id" "🔔 Test notification dihantar ke Discord dan Telegram."
}

handle_help() {
    local chat_id="$1"
    
    send_message "$chat_id" \
"📖 <b>Cloud Phone Monitor - Help</b>

<b>Commands:</b>
/start - Mulakan bot
/status - Tunjuk status semua apps
/open - Buka menu untuk buka app
/restart - Buka menu untuk restart app
/stop - Buka menu untuk stop app
/report - Hantar laporan status
/test - Test notification ke Discord & Telegram
/help - Tunjuk bantuan ini

<b>Monitor Control:</b>
/monitor start - Mulakan monitoring
/monitor stop - Hentikan monitoring
/monitor status - Status monitoring

<b>Direct Commands:</b>
open [package_name] - Buka app terus
restart [package_name] - Restart app terus
stop [package_name] - Stop app terus

<b>Configuration:</b>
Edit file config.conf untuk:
• Tambah/buang apps
• Set Discord webhook
• Set Telegram bot token
• Set check interval"
}

handle_monitor() {
    local chat_id="$1"
    local action="$2"
    
    case "$action" in
        start)
            $MONITOR_SCRIPT start 2>/dev/null
            send_message "$chat_id" "✅ Monitoring dimulakan."
            ;;
        stop)
            $MONITOR_SCRIPT stop 2>/dev/null
            send_message "$chat_id" "⏹️ Monitoring dihentikan."
            ;;
        status)
            if [[ -f "${SCRIPT_DIR}/monitor.pid" ]]; then
                local pid=$(cat "${SCRIPT_DIR}/monitor.pid")
                if kill -0 "$pid" 2>/dev/null; then
                    send_message "$chat_id" "🟢 Monitoring sedang berjalan (PID: $pid)"
                else
                    send_message "$chat_id" "🔴 Monitoring tidak berjalan (stale PID)"
                fi
            else
                send_message "$chat_id" "🔴 Monitoring tidak berjalan"
            fi
            ;;
        *)
            send_message "$chat_id" "Usage: /monitor [start|stop|status]"
            ;;
    esac
}

handle_app_command() {
    local chat_id="$1"
    local text="$2"
    
    # Parse "open package_name" format
    local action=$(echo "$text" | awk '{print tolower($1)}')
    local package=$(echo "$text" | awk '{print $2}')
    
    if [[ -z "$package" ]]; then
        return
    fi
    
    case "$action" in
        open)
            do_open_app "$chat_id" "$package"
            ;;
        restart)
            do_restart_app "$chat_id" "$package"
            ;;
        stop)
            do_stop_app "$chat_id" "$package"
            ;;
    esac
}

# Action handlers
do_open_app() {
    local chat_id="$1"
    local package="$2"
    
    local app_name="$package"
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r pkg name _ <<< "$app_entry"
        if [[ "$pkg" == "$package" ]]; then
            app_name="$name"
            break
        fi
    done
    
    send_message "$chat_id" "📱 Membuka <b>${app_name}</b>..."
    
    if $MONITOR_SCRIPT open "$package" 2>/dev/null; then
        send_message "$chat_id" "✅ <b>${app_name}</b> berjaya dibuka."
    else
        send_message "$chat_id" "❌ Gagal membuka <b>${app_name}</b>."
    fi
}

do_restart_app() {
    local chat_id="$1"
    local package="$2"
    
    local app_name="$package"
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r pkg name _ <<< "$app_entry"
        if [[ "$pkg" == "$package" ]]; then
            app_name="$name"
            break
        fi
    done
    
    send_message "$chat_id" "🔄 Restart <b>${app_name}</b>..."
    
    if $MONITOR_SCRIPT restart "$package" 2>/dev/null; then
        send_message "$chat_id" "✅ <b>${app_name}</b> berjaya di-restart."
    else
        send_message "$chat_id" "❌ Gagal restart <b>${app_name}</b>."
    fi
}

do_stop_app() {
    local chat_id="$1"
    local package="$2"
    
    local app_name="$package"
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r pkg name _ <<< "$app_entry"
        if [[ "$pkg" == "$package" ]]; then
            app_name="$name"
            break
        fi
    done
    
    send_message "$chat_id" "⏹️ Menutup <b>${app_name}</b>..."
    
    if $MONITOR_SCRIPT close "$package" 2>/dev/null; then
        send_message "$chat_id" "✅ <b>${app_name}</b> berjaya ditutup."
    else
        send_message "$chat_id" "⚠️ Tidak dapat menutup <b>${app_name}</b> sepenuhnya."
    fi
}

do_app_status() {
    local chat_id="$1"
    local package="$2"
    
    local app_name="$package"
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r pkg name _ <<< "$app_entry"
        if [[ "$pkg" == "$package" ]]; then
            app_name="$name"
            break
        fi
    done
    
    local status_emoji="🔴"
    local status_text="Stopped"
    
    if $MONITOR_SCRIPT _check_running "$package" 2>/dev/null; then
        status_emoji="🟢"
        status_text="Running"
    fi
    
    send_message "$chat_id" "${status_emoji} <b>${app_name}</b>\nStatus: ${status_text}\nPackage: <code>${package}</code>"
}

# Main polling loop
start_bot() {
    log "${GREEN}Starting Telegram Bot...${NC}"
    log "Token: ${TELEGRAM_TOKEN:0:10}..."
    
    local last_update_id=0
    
    echo $$ > "$BOT_PID"
    
    while true; do
        # Get updates
        local url="${TELEGRAM_API}/bot${TELEGRAM_TOKEN}/getUpdates"
        local response=$(curl -s "$url?offset=$((last_update_id + 1))&timeout=30")
        
        # Parse updates
        local updates=$(echo "$response" | grep -o '"update_id":[0-9]*' | sed 's/"update_id"://')
        
        for update_id in $updates; do
            last_update_id=$update_id
            
            # Extract message data
            local chat_id=$(echo "$response" | grep -o "\"chat\":{\"id\":[0-9]*" | head -1 | grep -o '[0-9]*$')
            local message_id=$(echo "$response" | grep -o '"message_id":[0-9]*' | sed 's/"message_id"://' | head -1)
            local text=$(echo "$response" | grep -o '"text":"[^"]*"' | sed 's/"text":"//;s/"$//' | head -1)
            local username=$(echo "$response" | grep -o '"username":"[^"]*"' | sed 's/"username":"//;s/"$//' | head -1)
            local first_name=$(echo "$response" | grep -o '"first_name":"[^"]*"' | sed 's/"first_name":"//;s/"$//' | head -1)
            
            # Handle message
            if [[ -n "$chat_id" && -n "$text" ]]; then
                handle_message "$chat_id" "$message_id" "$text" "$username" "$first_name"
            fi
            
            # Handle callback query
            local callback_data=$(echo "$response" | grep -o '"callback_data":"[^"]*"' | sed 's/"callback_data":"//;s/"$//')
            if [[ -n "$callback_data" ]]; then
                handle_callback "$chat_id" "$message_id" "$callback_data" "$username"
            fi
        done
        
        sleep 1
    done
}

# Stop bot
stop_bot() {
    if [[ -f "$BOT_PID" ]]; then
        local pid=$(cat "$BOT_PID")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log "${GREEN}Bot stopped (PID: $pid)${NC}"
        fi
        rm -f "$BOT_PID"
    else
        log "${YELLOW}Bot tidak berjalan${NC}"
    fi
}

# Main
case "${1:-}" in
    start)
        load_config
        start_bot
        ;;
    stop)
        stop_bot
        ;;
    status)
        if [[ -f "$BOT_PID" ]]; then
            local pid=$(cat "$BOT_PID")
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${GREEN}Bot berjalan (PID: $pid)${NC}"
            else
                echo -e "${RED}Bot tidak berjalan (stale PID)${NC}"
            fi
        else
            echo -e "${RED}Bot tidak berjalan${NC}"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        echo ""
        echo "This script runs the Telegram bot handler."
        echo "Make sure config.conf has TELEGRAM_TOKEN configured."
        ;;
esac
