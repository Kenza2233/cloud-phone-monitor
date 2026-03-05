#!/bin/bash
#===============================================================================
# CLOUD PHONE MONITOR - Termux Script
# Script untuk monitor dan auto-restart app di cloud phone
# Support: Discord Webhook & Telegram Bot notifications
#===============================================================================

# Colors untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Path ke config file
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"
LOG_FILE="${SCRIPT_DIR}/monitor.log"
PID_FILE="${SCRIPT_DIR}/monitor.pid"
STATUS_FILE="${SCRIPT_DIR}/status.json"

# Default values
DEFAULT_CHECK_INTERVAL=60
DEFAULT_DISCORD_WEBHOOK=""
DEFAULT_TELEGRAM_TOKEN=""
DEFAULT_TELEGRAM_CHAT_ID=""
DEFAULT_SERVER_URL=""

# Status constants
STATUS_RUNNING="running"
STATUS_STOPPED="stopped"
STATUS_CRASHED="crashed"
STATUS_RESTARTED="restarted"
STATUS_OPENED="opened"

#===============================================================================
# FUNCTIONS
#===============================================================================

# Load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        echo -e "${RED}Error: Config file tidak dijumpai: $CONFIG_FILE${NC}"
        echo "Sila salin config.conf.example ke config.conf dan edit konfigurasi."
        exit 1
    fi
    
    source "$CONFIG_FILE"
    
    # Set defaults if not defined
    CHECK_INTERVAL="${CHECK_INTERVAL:-$DEFAULT_CHECK_INTERVAL}"
    DISCORD_WEBHOOK="${DISCORD_WEBHOOK:-$DEFAULT_DISCORD_WEBHOOK}"
    TELEGRAM_TOKEN="${TELEGRAM_TOKEN:-$DEFAULT_TELEGRAM_TOKEN}"
    TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-$DEFAULT_TELEGRAM_CHAT_ID}"
    SERVER_URL="${SERVER_URL:-$DEFAULT_SERVER_URL}"
    
    # Parse apps from config
    APPS=()
    if [[ -n "$APP_LIST" ]]; then
        IFS=',' read -ra APPS <<< "$APP_LIST"
    fi
}

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE"
    
    case "$level" in
        "ERROR")   echo -e "${RED}[${timestamp}] [${level}] ${message}${NC}" ;;
        "SUCCESS") echo -e "${GREEN}[${timestamp}] [${level}] ${message}${NC}" ;;
        "WARNING") echo -e "${YELLOW}[${timestamp}] [${level}] ${message}${NC}" ;;
        "INFO")    echo -e "${CYAN}[${timestamp}] [${level}] ${message}${NC}" ;;
        *)         echo -e "[${timestamp}] [${level}] ${message}" ;;
    esac
}

# Check if app is running
is_app_running() {
    local package_name="$1"
    
    # Method 1: Using dumpsys (requires root or adb)
    if command -v dumpsys &> /dev/null; then
        if dumpsys package "$package_name" 2>/dev/null | grep -q "mResumed=true\|mResumedActivity"; then
            return 0
        fi
    fi
    
    # Method 2: Using pidof (more reliable)
    if command -v pidof &> /dev/null; then
        local pid=$(pidof "$package_name" 2>/dev/null)
        if [[ -n "$pid" ]]; then
            return 0
        fi
    fi
    
    # Method 3: Using ps command
    if ps -ef 2>/dev/null | grep -q "[${package_name:0:8}]"; then
        return 0
    fi
    
    # Method 4: Check using pm path (app installed but not running)
    if command -v pm &> /dev/null; then
        if pm path "$package_name" &> /dev/null; then
            # App is installed, check if running using activity manager
            if command -v am &> /dev/null; then
                local activities=$(am stack list 2>/dev/null | grep -c "$package_name")
                if [[ "$activities" -gt 0 ]]; then
                    return 0
                fi
            fi
        fi
    fi
    
    return 1
}

# Open/Start app
open_app() {
    local package_name="$1"
    local app_name="${2:-$package_name}"
    
    log "INFO" "Membuka app: $app_name ($package_name)"
    
    # Method 1: Using monkey command
    if command -v monkey &> /dev/null; then
        monkey -p "$package_name" -c android.intent.category.LAUNCHER 1 &>/dev/null
        sleep 2
        if is_app_running "$package_name"; then
            log "SUCCESS" "App $app_name berjaya dibuka menggunakan monkey"
            return 0
        fi
    fi
    
    # Method 2: Using am start command
    if command -v am &> /dev/null; then
        # Try to launch main activity
        local main_activity=$(dumpsys package "$package_name" 2>/dev/null | grep -A1 "android.intent.action.MAIN" | grep "$package_name" | head -1 | awk '{print $2}')
        if [[ -n "$main_activity" ]]; then
            am start -n "$main_activity" &>/dev/null
        else
            am start -a android.intent.action.MAIN -n "$package_name/.MainActivity" &>/dev/null
            am start -a android.intent.action.MAIN -n "$package_name/.ui.MainActivity" &>/dev/null
        fi
        sleep 2
        if is_app_running "$package_name"; then
            log "SUCCESS" "App $app_name berjaya dibuka menggunakan am"
            return 0
        fi
    fi
    
    # Method 3: Using intent
    if command -v am &> /dev/null; then
        am start -a android.intent.action.VIEW -d "intent://#Intent;package=$package_name;end" &>/dev/null
        sleep 2
        if is_app_running "$package_name"; then
            log "SUCCESS" "App $app_name berjaya dibuka menggunakan intent"
            return 0
        fi
    fi
    
    log "ERROR" "Gagal membuka app $app_name"
    return 1
}

# Close/Force stop app
close_app() {
    local package_name="$1"
    local app_name="${2:-$package_name}"
    
    log "INFO" "Menutup app: $app_name ($package_name)"
    
    # Method 1: Using am force-stop
    if command -v am &> /dev/null; then
        am force-stop "$package_name" &>/dev/null
        sleep 1
        if ! is_app_running "$package_name"; then
            log "SUCCESS" "App $app_name berjaya ditutup"
            return 0
        fi
    fi
    
    # Method 2: Using killall
    if command -v killall &> /dev/null; then
        killall "$package_name" &>/dev/null
        sleep 1
        if ! is_app_running "$package_name"; then
            log "SUCCESS" "App $app_name berjaya ditutup menggunakan killall"
            return 0
        fi
    fi
    
    # Method 3: Using pkill
    if command -v pkill &> /dev/null; then
        pkill -f "$package_name" &>/dev/null
        sleep 1
        if ! is_app_running "$package_name"; then
            log "SUCCESS" "App $app_name berjaya ditutup menggunakan pkill"
            return 0
        fi
    fi
    
    log "WARNING" "Tidak dapat menutup app $app_name sepenuhnya"
    return 1
}

# Restart app
restart_app() {
    local package_name="$1"
    local app_name="${2:-$package_name}"
    
    log "INFO" "Restart app: $app_name ($package_name)"
    
    close_app "$package_name" "$app_name"
    sleep 2
    open_app "$package_name" "$app_name"
    
    if is_app_running "$package_name"; then
        log "SUCCESS" "App $app_name berjaya di-restart"
        return 0
    else
        log "ERROR" "Gagal restart app $app_name"
        return 1
    fi
}

# Send to Discord webhook
send_discord() {
    local title="$1"
    local description="$2"
    local color="$3"
    local fields="$4"
    
    if [[ -z "$DISCORD_WEBHOOK" ]]; then
        return 0
    fi
    
    local color_code=3447003  # Blue
    case "$color" in
        "green")  color_code=3066993 ;;
        "red")    color_code=15158332 ;;
        "yellow") color_code=15844367 ;;
        "purple") color_code=10181046 ;;
    esac
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local device_name="${DEVICE_NAME:-$(hostname)}"
    
    local json='{
        "embeds": [{
            "title": "'"${title}"'",
            "description": "'"${description}"'",
            "color": '"${color_code}"',
            "author": {
                "name": "Cloud Phone Monitor",
                "icon_url": "https://cdn-icons-png.flaticon.com/512/2933/2933245.png"
            },
            "footer": {
                "text": "Device: '"${device_name}"'",
                "icon_url": "https://cdn-icons-png.flaticon.com/512/2933/2933245.png"
            },
            "timestamp": "'"${timestamp}"'"
        }]
    }'
    
    if [[ -n "$fields" ]]; then
        json=$(echo "$json" | sed "s/\"timestamp\":/\"fields\": $fields, \"timestamp\":/")
    fi
    
    curl -s -H "Content-Type: application/json" -d "$json" "$DISCORD_WEBHOOK" &>/dev/null
}

# Send to Telegram
send_telegram() {
    local message="$1"
    local parse_mode="${2:-HTML}"
    
    if [[ -z "$TELEGRAM_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        return 0
    fi
    
    local url="https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage"
    
    curl -s -X POST "$url" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=${parse_mode}" \
        &>/dev/null
}

# Send notification to both Discord and Telegram
notify_status() {
    local app_name="$1"
    local package_name="$2"
    local status="$3"
    local message="$4"
    
    local device_name="${DEVICE_NAME:-$(hostname)}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Discord notification
    local color="blue"
    local status_emoji="🔵"
    case "$status" in
        "$STATUS_RUNNING")   color="green"; status_emoji="🟢" ;;
        "$STATUS_STOPPED")   color="yellow"; status_emoji="🟡" ;;
        "$STATUS_CRASHED")   color="red"; status_emoji="🔴" ;;
        "$STATUS_RESTARTED") color="purple"; status_emoji="🔄" ;;
        "$STATUS_OPENED")    color="green"; status_emoji="✅" ;;
    esac
    
    send_discord "📱 App Status: $app_name" "$status_emoji **Status:** $status\n\n$message\n\n📅 Time: $timestamp" "$color"
    
    # Telegram notification
    local telegram_message="📱 <b>App Status Alert</b>

${status_emoji} <b>App:</b> $app_name
<b>Package:</b> <code>$package_name</code>
<b>Status:</b> $status
<b>Device:</b> $device_name

📝 $message

📅 Time: $timestamp"
    
    send_telegram "$telegram_message"
    
    log "INFO" "Notification sent for $app_name: $status"
}

# Send hourly report
send_hourly_report() {
    local report=""
    local device_name="${DEVICE_NAME:-$(hostname)}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local running_count=0
    local stopped_count=0
    local total_count=${#APPS[@]}
    
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r package_name app_name auto_restart <<< "$app_entry"
        
        if is_app_running "$package_name"; then
            report+="🟢 $app_name - Running\n"
            ((running_count++))
        else
            report+="🔴 $app_name - Stopped\n"
            ((stopped_count++))
        fi
    done
    
    # Discord hourly report
    send_discord "📊 Hourly Report - $device_name" \
        "**Total Apps:** $total_count\n**Running:** $running_count\n**Stopped:** $stopped_count\n\n$report\n\n📅 $timestamp" \
        "blue"
    
    # Telegram hourly report
    local telegram_report="📊 <b>Hourly Status Report</b>

<b>Device:</b> $device_name
<b>Time:</b> $timestamp

<b>Summary:</b>
• Total Apps: $total_count
• Running: $running_count
• Stopped: $stopped_count

<b>Details:</b>
$report"
    
    send_telegram "$telegram_report"
    
    log "INFO" "Hourly report sent"
}

# Update status to server
update_server_status() {
    if [[ -z "$SERVER_URL" ]]; then
        return 0
    fi
    
    local device_name="${DEVICE_NAME:-$(hostname)}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Build status JSON
    local status_json='{"device":"'"${device_name}"'","timestamp":"'"${timestamp}"'","apps":['
    local first=true
    
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r package_name app_name auto_restart <<< "$app_entry"
        
        local status="stopped"
        if is_app_running "$package_name"; then
            status="running"
        fi
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            status_json+=","
        fi
        
        status_json+="{\"package\":\"${package_name}\",\"name\":\"${app_name}\",\"status\":\"${status}\"}"
    done
    
    status_json+="]}"
    
    curl -s -X POST "${SERVER_URL}/api/status" \
        -H "Content-Type: application/json" \
        -d "$status_json" \
        &>/dev/null
}

# Save status to file
save_status() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    echo "{\"lastUpdate\":\"${timestamp}\",\"apps\":[" > "$STATUS_FILE"
    
    local first=true
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r package_name app_name auto_restart <<< "$app_entry"
        
        local status="stopped"
        if is_app_running "$package_name"; then
            status="running"
        fi
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$STATUS_FILE"
        fi
        
        echo "{\"package\":\"${package_name}\",\"name\":\"${app_name}\",\"status\":\"${status}\"}" >> "$STATUS_FILE"
    done
    
    echo "]}" >> "$STATUS_FILE"
}

# Monitor single app
monitor_app() {
    local package_name="$1"
    local app_name="$2"
    local auto_restart="$3"
    
    local prev_status=""
    
    # Get previous status
    if [[ -f "$STATUS_FILE" ]]; then
        prev_status=$(grep -o "\"$package_name\".*\"status\":\"[^\"]*\"" "$STATUS_FILE" | grep -o "status\":\"[^\"]*" | cut -d'"' -f3)
    fi
    
    local current_status="stopped"
    if is_app_running "$package_name"; then
        current_status="running"
    fi
    
    # Check for crash (was running, now stopped)
    if [[ "$prev_status" == "running" && "$current_status" == "stopped" && "$auto_restart" == "true" ]]; then
        log "WARNING" "App $app_name nampaknya telah crash, mencuba restart..."
        notify_status "$app_name" "$package_name" "$STATUS_CRASHED" "App telah crash, sedang mencuba restart..."
        
        if open_app "$package_name" "$app_name"; then
            notify_status "$app_name" "$package_name" "$STATUS_RESTARTED" "App berjaya di-restart secara automatik"
            current_status="running"
        else
            notify_status "$app_name" "$package_name" "$STATUS_STOPPED" "Gagal restart app secara automatik"
        fi
    fi
    
    # Status change notification
    if [[ "$prev_status" != "$current_status" && -n "$prev_status" ]]; then
        notify_status "$app_name" "$package_name" "$current_status" "Status telah berubah dari $prev_status ke $current_status"
    fi
    
    echo "$package_name|$app_name|$current_status"
}

# Main monitoring loop
start_monitoring() {
    log "INFO" "========================================"
    log "INFO" "Cloud Phone Monitor Started"
    log "INFO" "========================================"
    log "INFO" "Device: ${DEVICE_NAME:-$(hostname)}"
    log "INFO" "Check Interval: ${CHECK_INTERVAL} seconds"
    log "INFO" "Apps to monitor: ${#APPS[@]}"
    log "INFO" "Discord Webhook: $([ -n "$DISCORD_WEBHOOK" ] && echo "Configured" || echo "Not configured")"
    log "INFO" "Telegram Bot: $([ -n "$TELEGRAM_TOKEN" ] && echo "Configured" || echo "Not configured")"
    log "INFO" "========================================"
    
    # Initial notification
    send_discord "🚀 Monitor Started" "Cloud Phone Monitor telah dimulakan di device **${DEVICE_NAME:-$(hostname)}**\n\nMonitoring ${#APPS[@]} apps" "green"
    send_telegram "🚀 <b>Monitor Started</b>

Cloud Phone Monitor telah dimulakan
<b>Device:</b> ${DEVICE_NAME:-$(hostname)}
<b>Apps:</b> ${#APPS[@]}
<b>Interval:</b> ${CHECK_INTERVAL} seconds"
    
    # Save PID
    echo $$ > "$PID_FILE"
    
    local last_hourly=$(date +%H)
    local iteration=0
    
    while true; do
        ((iteration++))
        log "INFO" "--- Check iteration #$iteration ---"
        
        # Monitor each app
        for app_entry in "${APPS[@]}"; do
            IFS='|' read -r package_name app_name auto_restart <<< "$app_entry"
            monitor_app "$package_name" "$app_name" "$auto_restart"
        done
        
        # Save status
        save_status
        
        # Update server
        update_server_status
        
        # Hourly report
        local current_hour=$(date +%H)
        if [[ "$current_hour" != "$last_hourly" ]]; then
            send_hourly_report
            last_hourly="$current_hour"
        fi
        
        log "INFO" "Check completed. Sleeping for ${CHECK_INTERVAL} seconds..."
        sleep "$CHECK_INTERVAL"
    done
}

# Stop monitoring
stop_monitoring() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$PID_FILE"
            log "SUCCESS" "Monitor stopped (PID: $pid)"
            
            send_discord "⏹️ Monitor Stopped" "Cloud Phone Monitor telah dihentikan" "red"
            send_telegram "⏹️ <b>Monitor Stopped</b>

Cloud Phone Monitor telah dihentikan."
        else
            log "WARNING" "Monitor tidak berjalan"
            rm -f "$PID_FILE"
        fi
    else
        log "WARNING" "PID file tidak dijumpai"
    fi
}

# Show status
show_status() {
    echo -e "\n${CYAN}========================================${NC}"
    echo -e "${CYAN}       CLOUD PHONE MONITOR STATUS${NC}"
    echo -e "${CYAN}========================================${NC}"
    
    local device_name="${DEVICE_NAME:-$(hostname)}"
    echo -e "Device: ${GREEN}$device_name${NC}"
    echo -e "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    if [[ ${#APPS[@]} -eq 0 ]]; then
        echo -e "${YELLOW}Tiada apps dikonfigurasikan${NC}"
        return
    fi
    
    echo -e "${BLUE}Apps Status:${NC}"
    echo "----------------------------------------"
    
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r package_name app_name auto_restart <<< "$app_entry"
        
        if is_app_running "$package_name"; then
            echo -e "🟢 $app_name"
            echo -e "   Package: $package_name"
            echo -e "   Status: ${GREEN}Running${NC}"
        else
            echo -e "🔴 $app_name"
            echo -e "   Package: $package_name"
            echo -e "   Status: ${RED}Stopped${NC}"
        fi
        echo -e "   Auto-restart: $auto_restart"
        echo ""
    done
    
    echo -e "${CYAN}========================================${NC}"
}

# Manual open app command
cmd_open() {
    local package_name="$1"
    
    if [[ -z "$package_name" ]]; then
        echo -e "${YELLOW}Usage: $0 open <package_name>${NC}"
        echo "Available apps:"
        for app_entry in "${APPS[@]}"; do
            IFS='|' read -r pkg name _ <<< "$app_entry"
            echo "  - $name ($pkg)"
        done
        return 1
    fi
    
    local app_name="$package_name"
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r pkg name _ <<< "$app_entry"
        if [[ "$pkg" == "$package_name" ]]; then
            app_name="$name"
            break
        fi
    done
    
    if open_app "$package_name" "$app_name"; then
        notify_status "$app_name" "$package_name" "$STATUS_OPENED" "App dibuka secara manual"
        return 0
    fi
    return 1
}

# Manual close app command
cmd_close() {
    local package_name="$1"
    
    if [[ -z "$package_name" ]]; then
        echo -e "${YELLOW}Usage: $0 close <package_name>${NC}"
        return 1
    fi
    
    local app_name="$package_name"
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r pkg name _ <<< "$app_entry"
        if [[ "$pkg" == "$package_name" ]]; then
            app_name="$name"
            break
        fi
    done
    
    close_app "$package_name" "$app_name"
    notify_status "$app_name" "$package_name" "$STATUS_STOPPED" "App ditutup secara manual"
}

# Manual restart app command
cmd_restart() {
    local package_name="$1"
    
    if [[ -z "$package_name" ]]; then
        echo -e "${YELLOW}Usage: $0 restart <package_name>${NC}"
        return 1
    fi
    
    local app_name="$package_name"
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r pkg name _ <<< "$app_entry"
        if [[ "$pkg" == "$package_name" ]]; then
            app_name="$name"
            break
        fi
    done
    
    if restart_app "$package_name" "$app_name"; then
        notify_status "$app_name" "$package_name" "$STATUS_RESTARTED" "App di-restart secara manual"
        return 0
    fi
    return 1
}

# Test notifications
test_notifications() {
    log "INFO" "Testing notifications..."
    
    send_discord "🧪 Test Notification" "Ini adalah test notification dari Cloud Phone Monitor\n\nJika anda terima ini, konfigurasi Discord webhook adalah betul." "blue"
    
    send_telegram "🧪 <b>Test Notification</b>

Ini adalah test notification dari Cloud Phone Monitor.

Jika anda terima ini, konfigurasi Telegram bot adalah betul."
    
    log "SUCCESS" "Test notifications sent!"
}

# Show help
show_help() {
    echo -e "${CYAN}"
    echo "========================================"
    echo "   CLOUD PHONE MONITOR - Termux Script"
    echo "========================================"
    echo -e "${NC}"
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start       Start monitoring (background)"
    echo "  stop        Stop monitoring"
    echo "  status      Show current status of all apps"
    echo "  open <pkg>  Manually open an app"
    echo "  close <pkg> Manually close an app"
    echo "  restart <pkg> Manually restart an app"
    echo "  test        Test Discord and Telegram notifications"
    echo "  logs        Show recent logs"
    echo "  help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 start                  # Start monitoring all apps"
    echo "  $0 status                 # Show status of all apps"
    echo "  $0 open com.whatsapp      # Open WhatsApp"
    echo "  $0 restart com.telegram   # Restart Telegram"
    echo ""
    echo "Configuration:"
    echo "  Edit config.conf to set:"
    echo "  - Apps to monitor"
    echo "  - Discord webhook URL"
    echo "  - Telegram bot token and chat ID"
    echo "  - Check interval"
    echo ""
}

# Show recent logs
show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -n 50 "$LOG_FILE"
    else
        echo "Log file tidak dijumpai"
    fi
}

#===============================================================================
# MAIN
#===============================================================================

case "${1:-}" in
    start)
        load_config
        
        # Check if already running
        if [[ -f "$PID_FILE" ]]; then
            pid=$(cat "$PID_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${YELLOW}Monitor sudah berjalan (PID: $pid)${NC}"
                exit 0
            fi
        fi
        
        # Start in background
        nohup "$0" _monitor_loop > /dev/null 2>&1 &
        echo -e "${GREEN}Monitor started in background${NC}"
        echo "PID: $!"
        ;;
    
    _monitor_loop)
        load_config
        start_monitoring
        ;;
    
    stop)
        load_config
        stop_monitoring
        ;;
    
    status)
        load_config
        show_status
        ;;
    
    open)
        load_config
        cmd_open "$2"
        ;;
    
    close)
        load_config
        cmd_close "$2"
        ;;
    
    restart)
        load_config
        cmd_restart "$2"
        ;;
    
    test)
        load_config
        test_notifications
        ;;
    
    logs)
        show_logs
        ;;
    
    help|--help|-h)
        show_help
        ;;
    
    *)
        if [[ -z "${1:-}" ]]; then
            show_help
        else
            echo -e "${RED}Unknown command: $1${NC}"
            echo "Run '$0 help' for usage information"
            exit 1
        fi
        ;;
esac
