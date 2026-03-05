#!/bin/bash
#===============================================================================
# CLOUD PHONE MONITOR - Discord Bot Handler
# Script untuk terima commands dari Discord via webhook dan bot API
#===============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"
BOT_LOG="${SCRIPT_DIR}/discord-bot.log"
BOT_PID="${SCRIPT_DIR}/discord-bot.pid"
MONITOR_SCRIPT="${SCRIPT_DIR}/monitor.sh"

# Discord API base
DISCORD_API="https://discord.com/api/v10"

# Load config
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
    
    # Discord bot settings
    DISCORD_BOT_TOKEN="${DISCORD_BOT_TOKEN:-}"
    DISCORD_APP_ID="${DISCORD_APP_ID:-}"
    DISCORD_GUILD_ID="${DISCORD_GUILD_ID:-}"
    DISCORD_CHANNEL_ID="${DISCORD_CHANNEL_ID:-}"
    
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

# Send Discord message via webhook
send_webhook_message() {
    local webhook_url="$1"
    local content="$2"
    local embed_title="$3"
    local embed_desc="$4"
    local color="$5"
    
    local json='{"content": "'"$content"'"}'
    
    if [[ -n "$embed_title" ]]; then
        local color_code=3447003
        case "$color" in
            "green")  color_code=3066993 ;;
            "red")    color_code=15158332 ;;
            "yellow") color_code=15844367 ;;
            "purple") color_code=10181046 ;;
        esac
        
        json='{
            "content": "'"$content"'",
            "embeds": [{
                "title": "'"$embed_title"'",
                "description": "'"$embed_desc"'",
                "color": '"$color_code"',
                "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"
            }]
        }'
    fi
    
    curl -s -X POST "$webhook_url" \
        -H "Content-Type: application/json" \
        -d "$json" > /dev/null
}

# Send Discord message via bot API
send_bot_message() {
    local channel_id="$1"
    local content="$2"
    local embeds="$3"
    
    if [[ -z "$DISCORD_BOT_TOKEN" ]]; then
        log "${RED}Discord bot token not configured${NC}"
        return 1
    fi
    
    local url="${DISCORD_API}/channels/${channel_id}/messages"
    local json='{"content": "'"$content"'"}'
    
    if [[ -n "$embeds" ]]; then
        json='{"content": "'"$content"'", "embeds": '"$embeds"'}'
    fi
    
    curl -s -X POST "$url" \
        -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$json" > /dev/null
}

# Send Discord embed
send_embed() {
    local channel_id="$1"
    local title="$2"
    local description="$3"
    local color="$4"
    local fields="$5"
    
    local color_code=3447003
    case "$color" in
        "green")  color_code=3066993 ;;
        "red")    color_code=15158332 ;;
        "yellow") color_code=15844367 ;;
        "purple") color_code=10181046 ;;
    esac
    
    local embed='{
        "title": "'"$title"'",
        "description": "'"$description"'",
        "color": '"$color_code"',
        "timestamp": "'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'"'
    
    if [[ -n "$fields" ]]; then
        embed+=', "fields": '"$fields"
    fi
    
    embed+='}'
    
    send_bot_message "$channel_id" "" "[$embed]"
}

# Create embed fields
create_fields() {
    local fields="["
    local first=true
    
    while [[ $# -gt 0 ]]; do
        local name="$1"
        local value="$2"
        local inline="${3:-false}"
        shift 3
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            fields+=","
        fi
        
        fields+="{\"name\": \"${name}\", \"value\": \"${value}\", \"inline\": ${inline}}"
    done
    
    fields+="]"
    echo "$fields"
}

# Register slash commands
register_commands() {
    if [[ -z "$DISCORD_BOT_TOKEN" || -z "$DISCORD_APP_ID" ]]; then
        log "${RED}Discord bot token or app ID not configured${NC}"
        return 1
    fi
    
    local url="${DISCORD_API}/applications/${DISCORD_APP_ID}/commands"
    
    # Register commands
    local commands='[
        {
            "name": "status",
            "description": "Show status of all monitored apps",
            "type": 1
        },
        {
            "name": "open",
            "description": "Open an app",
            "type": 1,
            "options": [{
                "name": "app",
                "description": "The app to open",
                "type": 3,
                "required": true,
                "choices": []
            }]
        },
        {
            "name": "close",
            "description": "Close an app",
            "type": 1,
            "options": [{
                "name": "app",
                "description": "The app to close",
                "type": 3,
                "required": true
            }]
        },
        {
            "name": "restart",
            "description": "Restart an app",
            "type": 1,
            "options": [{
                "name": "app",
                "description": "The app to restart",
                "type": 3,
                "required": true
            }]
        },
        {
            "name": "monitor",
            "description": "Control the monitor service",
            "type": 1,
            "options": [{
                "name": "action",
                "description": "start, stop, or status",
                "type": 3,
                "required": true,
                "choices": [
                    {"name": "Start", "value": "start"},
                    {"name": "Stop", "value": "stop"},
                    {"name": "Status", "value": "status"}
                ]
            }]
        },
        {
            "name": "report",
            "description": "Send a status report",
            "type": 1
        },
        {
            "name": "help",
            "description": "Show help message",
            "type": 1
        }
    ]'
    
    # Add app choices to open/close/restart commands
    local app_choices="["
    local first=true
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r package_name app_name _ <<< "$app_entry"
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            app_choices+=","
        fi
        
        app_choices+="{\"name\": \"${app_name}\", \"value\": \"${package_name}\"}"
    done
    app_choices+="]"
    
    # Update commands with app choices
    commands=$(echo "$commands" | sed "s/\"choices\": \[\]/\"choices\": ${app_choices}/g")
    
    # Register commands globally (or to specific guild)
    if [[ -n "$DISCORD_GUILD_ID" ]]; then
        url="${DISCORD_API}/applications/${DISCORD_APP_ID}/guilds/${DISCORD_GUILD_ID}/commands"
    fi
    
    local response=$(curl -s -X PUT "$url" \
        -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$commands")
    
    if echo "$response" | grep -q "id"; then
        log "${GREEN}Slash commands registered successfully!${NC}"
        return 0
    else
        log "${RED}Failed to register commands: $response${NC}"
        return 1
    fi
}

# Handle interaction
handle_interaction() {
    local interaction_id="$1"
    local interaction_token="$2"
    local data="$3"
    
    local url="${DISCORD_API}/interactions/${interaction_id}/${interaction_token}/callback"
    
    # Parse command
    local command_name=$(echo "$data" | grep -o '"name":"[^"]*"' | head -1 | sed 's/"name":"//;s/"$//')
    local options=$(echo "$data" | grep -o '"options":\[.*\]' | sed 's/"options"://')
    
    local response_type=4  # CHANNEL_MESSAGE_WITH_SOURCE
    local response_data="{}"
    
    case "$command_name" in
        status)
            response_data=$(handle_status_command)
            ;;
        open)
            local app_value=$(echo "$options" | grep -o '"value":"[^"]*"' | sed 's/"value":"//;s/"$//')
            response_data=$(handle_open_command "$app_value")
            ;;
        close)
            local app_value=$(echo "$options" | grep -o '"value":"[^"]*"' | sed 's/"value":"//;s/"$//')
            response_data=$(handle_close_command "$app_value")
            ;;
        restart)
            local app_value=$(echo "$options" | grep -o '"value":"[^"]*"' | sed 's/"value":"//;s/"$//')
            response_data=$(handle_restart_command "$app_value")
            ;;
        monitor)
            local action=$(echo "$options" | grep -o '"value":"[^"]*"' | sed 's/"value":"//;s/"$//')
            response_data=$(handle_monitor_command "$action")
            ;;
        report)
            response_data=$(handle_report_command)
            ;;
        help)
            response_data=$(handle_help_command)
            ;;
        *)
            response_data='{"content": "Unknown command"}'
            ;;
    esac
    
    local json='{"type": '"$response_type"', "data": '"$response_data"'}'
    
    curl -s -X POST "$url" \
        -H "Authorization: Bot ${DISCORD_BOT_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "$json" > /dev/null
}

# Command handlers
handle_status_command() {
    local status_text="📊 **Status of All Apps**\n━━━━━━━━━━━━━━━━━━━━\n\n"
    
    local running=0
    local stopped=0
    local total=${#APPS[@]}
    
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r package_name app_name _ <<< "$app_entry"
        
        local status_emoji="🔴"
        local status_text_app="Stopped"
        
        if $MONITOR_SCRIPT _check_running "$package_name" 2>/dev/null; then
            status_emoji="🟢"
            status_text_app="Running"
            ((running++))
        else
            ((stopped++))
        fi
        
        status_text+="${status_emoji} **${app_name}**\n"
        status_text+="   📦 \`${package_name}\`\n"
        status_text+="   📋 Status: ${status_text_app}\n\n"
    done
    
    status_text+="━━━━━━━━━━━━━━━━━━━━\n"
    status_text+="📈 **Summary:** ${running} Running, ${stopped} Stopped (${total} Total)"
    
    echo '{"content": "'"${status_text}"'"}'
}

handle_open_command() {
    local package="$1"
    
    local app_name="$package"
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r pkg name _ <<< "$app_entry"
        if [[ "$pkg" == "$package" ]]; then
            app_name="$name"
            break
        fi
    done
    
    if $MONITOR_SCRIPT open "$package" 2>/dev/null; then
        echo '{"content": "✅ **'"${app_name}"'** opened successfully!"}'
    else
        echo '{"content": "❌ Failed to open **'"${app_name}"'**"}'
    fi
}

handle_close_command() {
    local package="$1"
    
    local app_name="$package"
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r pkg name _ <<< "$app_entry"
        if [[ "$pkg" == "$package" ]]; then
            app_name="$name"
            break
        fi
    done
    
    if $MONITOR_SCRIPT close "$package" 2>/dev/null; then
        echo '{"content": "✅ **'"${app_name}"'** closed successfully!"}'
    else
        echo '{"content": "⚠️ Could not fully close **'"${app_name}"'**"}'
    fi
}

handle_restart_command() {
    local package="$1"
    
    local app_name="$package"
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r pkg name _ <<< "$app_entry"
        if [[ "$pkg" == "$package" ]]; then
            app_name="$name"
            break
        fi
    done
    
    if $MONITOR_SCRIPT restart "$package" 2>/dev/null; then
        echo '{"content": "✅ **'"${app_name}"'** restarted successfully!"}'
    else
        echo '{"content": "❌ Failed to restart **'"${app_name}"'**"}'
    fi
}

handle_monitor_command() {
    local action="$1"
    
    case "$action" in
        start)
            $MONITOR_SCRIPT start 2>/dev/null
            echo '{"content": "✅ Monitor started!"}'
            ;;
        stop)
            $MONITOR_SCRIPT stop 2>/dev/null
            echo '{"content": "⏹️ Monitor stopped!"}'
            ;;
        status)
            if [[ -f "${SCRIPT_DIR}/monitor.pid" ]]; then
                local pid=$(cat "${SCRIPT_DIR}/monitor.pid")
                if kill -0 "$pid" 2>/dev/null; then
                    echo '{"content": "🟢 Monitor is running (PID: '"${pid}"')"}'
                else
                    echo '{"content": "🔴 Monitor is not running (stale PID)"}'
                fi
            else
                echo '{"content": "🔴 Monitor is not running"}'
            fi
            ;;
        *)
            echo '{"content": "Invalid action. Use start, stop, or status."}'
            ;;
    esac
}

handle_report_command() {
    local report="📊 **Hourly Status Report**\n"
    report+="━━━━━━━━━━━━━━━━━━━━\n\n"
    
    local device_name="${DEVICE_NAME:-$(hostname)}"
    report+="📱 **Device:** ${device_name}\n"
    report+="🕐 **Time:** $(date '+%Y-%m-%d %H:%M:%S')\n\n"
    
    local running=0
    local stopped=0
    
    for app_entry in "${APPS[@]}"; do
        IFS='|' read -r package_name app_name _ <<< "$app_entry"
        
        if $MONITOR_SCRIPT _check_running "$package_name" 2>/dev/null; then
            report+="🟢 ${app_name}\n"
            ((running++))
        else
            report+="🔴 ${app_name}\n"
            ((stopped++))
        fi
    done
    
    report+="\n━━━━━━━━━━━━━━━━━━━━\n"
    report+="📈 **Running:** ${running} | **Stopped:** ${stopped}"
    
    echo '{"content": "'"${report}"'"}'
}

handle_help_command() {
    local help="📖 **Cloud Phone Monitor - Help**\n"
    help+="━━━━━━━━━━━━━━━━━━━━\n\n"
    help+="**Commands:**\n"
    help+="/status - Show status of all apps\n"
    help+="/open <app> - Open an app\n"
    help+="/close <app> - Close an app\n"
    help+="/restart <app> - Restart an app\n"
    help+="/monitor <action> - Control monitor service\n"
    help+="  • start - Start monitoring\n"
    help+="  • stop - Stop monitoring\n"
    help+="  • status - Show monitor status\n"
    help+="/report - Send status report\n"
    help+="/help - Show this help\n\n"
    help+="**Configuration:**\n"
    help+="Edit config.conf to add/remove apps and configure notifications."
    
    echo '{"content": "'"${help}"'"}'
}

# Poll for interactions (simplified - for production use a proper gateway connection)
poll_interactions() {
    # Note: This is a simplified version
    # For a proper Discord bot, you should use the Gateway API with WebSocket
    # Or use a library like discord.js, discord.py, etc.
    
    log "${YELLOW}Note: This is a basic interaction handler${NC}"
    log "${YELLOW}For full functionality, use the webhook-based approach${NC}"
    log "${YELLOW}or implement a proper Gateway connection${NC}"
    
    # In practice, you'd use a WebSocket connection to Discord Gateway
    # or use webhooks to receive interactions
    
    echo "$$" > "$BOT_PID"
    
    while true; do
        # Placeholder for interaction polling
        # Real implementation would use Discord Gateway
        sleep 60
    done
}

# Setup instructions
show_setup_instructions() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║           DISCORD BOT SETUP INSTRUCTIONS                      ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "\n${CYAN}Step 1: Create Discord Application${NC}"
    echo -e "  1. Go to ${BLUE}https://discord.com/developers/applications${NC}"
    echo -e "  2. Click 'New Application'"
    echo -e "  3. Give it a name (e.g., 'Cloud Phone Monitor')"
    echo -e "  4. Copy the ${GREEN}Application ID${NC} (this is DISCORD_APP_ID)"
    
    echo -e "\n${CYAN}Step 2: Create Bot User${NC}"
    echo -e "  1. Go to 'Bot' section in left sidebar"
    echo -e "  2. Click 'Add Bot'"
    echo -e "  3. Copy the ${GREEN}Token${NC} (this is DISCORD_BOT_TOKEN)"
    echo -e "  4. Enable 'Message Content Intent' under Privileged Gateway Intents"
    echo -e "  5. Enable 'Application Commands' under Bot permissions"
    
    echo -e "\n${CYAN}Step 3: Get Channel ID${NC}"
    echo -e "  1. Enable Developer Mode in Discord (Settings > Advanced)"
    echo -e "  2. Right-click on your channel"
    echo -e "  3. Click 'Copy ID' (this is DISCORD_CHANNEL_ID)"
    
    echo -e "\n${CYAN}Step 4: Get Guild (Server) ID${NC}"
    echo -e "  1. Right-click on your server"
    echo -e "  2. Click 'Copy ID' (this is DISCORD_GUILD_ID)"
    
    echo -e "\n${CYAN}Step 5: Invite Bot to Server${NC}"
    echo -e "  1. Go to 'OAuth2' > 'URL Generator'"
    echo -e "  2. Select 'bot' and 'applications.commands' scopes"
    echo -e "  3. Select permissions: Send Messages, Embed Links, Use Slash Commands"
    echo -e "  4. Copy and open the generated URL"
    echo -e "  5. Authorize the bot to join your server"
    
    echo -e "\n${CYAN}Step 6: Update Config${NC}"
    echo -e "  Add these to your config.conf:"
    echo -e ""
    echo -e "  ${GREEN}DISCORD_BOT_TOKEN=\"your_bot_token\"${NC}"
    echo -e "  ${GREEN}DISCORD_APP_ID=\"your_app_id\"${NC}"
    echo -e "  ${GREEN}DISCORD_GUILD_ID=\"your_guild_id\"${NC}"
    echo -e "  ${GREEN}DISCORD_CHANNEL_ID=\"your_channel_id\"${NC}"
    
    echo -e "\n${CYAN}Step 7: Register Commands${NC}"
    echo -e "  Run: ${GREEN}./discord-bot.sh register${NC}"
    
    echo -e "\n${CYAN}Step 8: Start Bot${NC}"
    echo -e "  Run: ${GREEN}./discord-bot.sh start${NC}"
}

# Test Discord connection
test_connection() {
    echo -e "${CYAN}Testing Discord connection...${NC}"
    
    if [[ -z "$DISCORD_BOT_TOKEN" ]]; then
        echo -e "${RED}✗ DISCORD_BOT_TOKEN not set${NC}"
        return 1
    fi
    
    # Test API access
    local response=$(curl -s "${DISCORD_API}/users/@me" \
        -H "Authorization: Bot ${DISCORD_BOT_TOKEN}")
    
    if echo "$response" | grep -q '"id"'; then
        local bot_name=$(echo "$response" | grep -o '"username":"[^"]*"' | sed 's/"username":"//;s/"$//')
        echo -e "${GREEN}✓ Connected as: ${bot_name}${NC}"
        
        # Check channel access
        if [[ -n "$DISCORD_CHANNEL_ID" ]]; then
            local channel_check=$(curl -s "${DISCORD_API}/channels/${DISCORD_CHANNEL_ID}" \
                -H "Authorization: Bot ${DISCORD_BOT_TOKEN}")
            
            if echo "$channel_check" | grep -q '"id"'; then
                local channel_name=$(echo "$channel_check" | grep -o '"name":"[^"]*"' | sed 's/"name":"//;s/"$//')
                echo -e "${GREEN}✓ Channel access: #${channel_name}${NC}"
            else
                echo -e "${RED}✗ Cannot access channel ${DISCORD_CHANNEL_ID}${NC}"
            fi
        fi
        
        return 0
    else
        echo -e "${RED}✗ Failed to connect to Discord API${NC}"
        echo -e "  Response: $response"
        return 1
    fi
}

# Send test message
send_test_message() {
    if [[ -z "$DISCORD_CHANNEL_ID" ]]; then
        echo -e "${RED}DISCORD_CHANNEL_ID not set${NC}"
        return 1
    fi
    
    send_bot_message "$DISCORD_CHANNEL_ID" \
        "🧪 **Test Message**\n\nThis is a test message from Cloud Phone Monitor.\n\n✅ If you see this, the bot is working correctly!"
    
    echo -e "${GREEN}✓ Test message sent to Discord${NC}"
}

# Stop bot
stop_bot() {
    if [[ -f "$BOT_PID" ]]; then
        local pid=$(cat "$BOT_PID")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            log "${GREEN}Discord bot stopped (PID: $pid)${NC}"
        fi
        rm -f "$BOT_PID"
    else
        log "${YELLOW}Discord bot not running${NC}"
    fi
}

# Main
case "${1:-}" in
    setup)
        show_setup_instructions
        ;;
    register)
        load_config
        register_commands
        ;;
    start)
        load_config
        log "${GREEN}Starting Discord Bot...${NC}"
        test_connection || exit 1
        poll_interactions
        ;;
    stop)
        stop_bot
        ;;
    test)
        load_config
        test_connection
        send_test_message
        ;;
    status)
        if [[ -f "$BOT_PID" ]]; then
            local pid=$(cat "$BOT_PID")
            if kill -0 "$pid" 2>/dev/null; then
                echo -e "${GREEN}Discord bot running (PID: $pid)${NC}"
            else
                echo -e "${RED}Discord bot not running (stale PID)${NC}"
            fi
        else
            echo -e "${RED}Discord bot not running${NC}"
        fi
        ;;
    help|--help|-h)
        echo "Usage: $0 {setup|register|start|stop|test|status}"
        echo ""
        echo "Commands:"
        echo "  setup    - Show setup instructions"
        echo "  register - Register slash commands"
        echo "  start    - Start the bot"
        echo "  stop     - Stop the bot"
        echo "  test     - Test Discord connection"
        echo "  status   - Show bot status"
        ;;
    *)
        show_setup_instructions
        ;;
esac
