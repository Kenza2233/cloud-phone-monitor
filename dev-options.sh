#!/bin/bash
#===============================================================================
# CLOUD PHONE MONITOR - Developer Options & Permissions Setup
# Script untuk setup permissions dan developer options
#===============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Paths
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.conf"

# Banner
show_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║         CLOUD PHONE MONITOR - Developer Options               ║"
    echo "║                  Permissions & Setup                          ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${GREEN}✓ Running as root${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Not running as root${NC}"
        echo -e "${YELLOW}  Some features may require root access${NC}"
        return 1
    fi
}

# Check Termux environment
check_termux() {
    if [[ -n "$TERMUX_VERSION" ]]; then
        echo -e "${GREEN}✓ Running in Termux${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Not running in Termux${NC}"
        echo -e "${YELLOW}  Some Termux-specific features won't work${NC}"
        return 1
    fi
}

# Check and request storage permission
check_storage_permission() {
    echo -e "\n${CYAN}━━━ Storage Permission ━━━${NC}"
    
    if [[ -n "$TERMUX_VERSION" ]]; then
        # Check if storage directory exists
        if [[ -d "$HOME/storage" ]]; then
            echo -e "${GREEN}✓ Storage permission granted${NC}"
            echo -e "  Storage path: $HOME/storage"
            return 0
        else
            echo -e "${YELLOW}⚠ Storage permission not granted${NC}"
            echo -e "${YELLOW}  Requesting permission...${NC}"
            
            # Request storage permission
            if command -v termux-setup-storage &> /dev/null; then
                termux-setup-storage
                sleep 2
                if [[ -d "$HOME/storage" ]]; then
                    echo -e "${GREEN}✓ Storage permission granted!${NC}"
                    return 0
                fi
            fi
            
            echo -e "${RED}✗ Failed to get storage permission${NC}"
            echo -e "  Run manually: termux-setup-storage"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ Not in Termux - skipping${NC}"
        return 0
    fi
}

# Check Android permissions via termux-api
check_android_permissions() {
    echo -e "\n${CYAN}━━━ Android Permissions ━━━${NC}"
    
    if ! command -v termux-api &> /dev/null; then
        echo -e "${YELLOW}⚠ termux-api not installed${NC}"
        echo -e "  Install with: pkg install termux-api"
        echo -e "  Also install Termux:API app from F-Droid"
        return 1
    fi
    
    # Check battery optimization
    echo -e "\n${BLUE}Battery Optimization:${NC}"
    local battery_info=$(termux-battery-status 2>/dev/null)
    if [[ -n "$battery_info" ]]; then
        echo -e "${GREEN}✓ Battery API accessible${NC}"
    else
        echo -e "${YELLOW}⚠ Battery API not accessible${NC}"
    fi
    
    # Request ignore battery optimizations
    echo -e "\n${BLUE}Requesting battery optimization exemption...${NC}"
    if command -v am &> /dev/null; then
        am start -a android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS \
            -d "package:com.termux" 2>/dev/null
        echo -e "${YELLOW}  Please grant 'Ignore battery optimization' permission${NC}"
    fi
    
    return 0
}

# Setup accessibility service
setup_accessibility() {
    echo -e "\n${CYAN}━━━ Accessibility Service ━━━${NC}"
    
    echo -e "${YELLOW}Accessibility Service diperlukan untuk:${NC}"
    echo -e "  • Detect app yang sedang running"
    echo -e "  • Auto-restart crashed apps"
    echo -e "  • Monitor app state"
    
    echo -e "\n${BLUE}Steps untuk enable:${NC}"
    echo -e "  1. Open Android Settings"
    echo -e "  2. Go to Accessibility"
    echo -e "  3. Find 'Termux' or installed accessibility service"
    echo -e "  4. Enable the service"
    
    # Try to open accessibility settings
    if command -v am &> /dev/null; then
        echo -e "\n${CYAN}Opening Accessibility Settings...${NC}"
        am start -a android.settings.ACCESSIBILITY_SETTINGS 2>/dev/null
    fi
    
    echo -e "\n${YELLOW}Press Enter after enabling accessibility...${NC}"
    read -r
}

# Setup usage stats access
setup_usage_stats() {
    echo -e "\n${CYAN}━━━ Usage Stats Access ━━━${NC}"
    
    echo -e "${YELLOW}Usage Stats diperlukan untuk:${NC}"
    echo -e "  • Monitor app usage"
    echo -e "  • Get detailed app information"
    echo -e "  • Track app states"
    
    echo -e "\n${BLUE}Steps untuk enable:${NC}"
    echo -e "  1. Open Android Settings"
    echo -e "  2. Go to Security"
    echo -e "  3. Find 'Usage Stats' or 'Apps with usage access'"
    echo -e "  4. Enable for Termux"
    
    # Try to open usage stats settings
    if command -v am &> /dev/null; then
        echo -e "\n${CYAN}Opening Usage Stats Settings...${NC}"
        am start -a android.settings.USAGE_ACCESS_SETTINGS 2>/dev/null
    fi
    
    echo -e "\n${YELLOW}Press Enter after enabling usage stats...${NC}"
    read -r
}

# Setup display over other apps
setup_display_over_apps() {
    echo -e "\n${CYAN}━━━ Display Over Other Apps ━━━${NC}"
    
    echo -e "${YELLOW}Display Over Other Apps diperlukan untuk:${NC}"
    echo -e "  • Show overlays"
    echo -e "  • Display notifications on top"
    echo -e "  • Some automation features"
    
    # Try to open the settings
    if command -v am &> /dev/null; then
        echo -e "\n${CYAN}Opening System Alert Window Settings...${NC}"
        am start -a android.settings.action.MANAGE_OVERLAY_PERMISSION \
            -d "package:com.termux" 2>/dev/null
    fi
    
    echo -e "\n${YELLOW}Press Enter after enabling...${NC}"
    read -r
}

# Setup developer options
setup_developer_options() {
    echo -e "\n${CYAN}━━━ Developer Options ━━━${NC}"
    
    echo -e "${YELLOW}Developer Options diperlukan untuk:${NC}"
    echo -e "  • ADB debugging"
    echo -e "  • Stay awake (prevent sleep)"
    echo -e "  • Background process limits"
    
    echo -e "\n${BLUE}Steps untuk enable:${NC}"
    echo -e "  1. Open Android Settings"
    echo -e "  2. Go to About Phone"
    echo -e "  3. Tap 'Build Number' 7 times"
    echo -e "  4. Go back to Developer Options"
    echo -e "  5. Enable USB Debugging"
    echo -e "  6. Enable Stay Awake"
    echo -e "  7. Set Background process limit to 'Standard limit'"
    
    # Try to open developer options
    if command -v am &> /dev/null; then
        echo -e "\n${CYAN}Opening Developer Options...${NC}"
        am start -a android.settings.APPLICATION_DEVELOPMENT_SETTINGS 2>/dev/null
    fi
    
    echo -e "\n${YELLOW}Press Enter after configuring...${NC}"
    read -r
}

# Setup ADB (Android Debug Bridge)
setup_adb() {
    echo -e "\n${CYAN}━━━ ADB Setup ━━━${NC}"
    
    # Check if adb is installed
    if command -v adb &> /dev/null; then
        echo -e "${GREEN}✓ ADB is installed${NC}"
        
        # Check ADB version
        local adb_version=$(adb version 2>/dev/null | head -1)
        echo -e "  Version: $adb_version"
        
        # Start ADB server
        echo -e "\n${BLUE}Starting ADB server...${NC}"
        adb start-server 2>/dev/null
        
        # Check connected devices
        echo -e "\n${BLUE}Connected devices:${NC}"
        adb devices 2>/dev/null
        
        return 0
    else
        echo -e "${YELLOW}⚠ ADB not installed${NC}"
        echo -e "  Installing ADB..."
        
        if command -v pkg &> /dev/null; then
            pkg install android-tools -y
            if [[ $? -eq 0 ]]; then
                echo -e "${GREEN}✓ ADB installed successfully${NC}"
                return 0
            fi
        fi
        
        echo -e "${RED}✗ Failed to install ADB${NC}"
        echo -e "  Install manually: pkg install android-tools"
        return 1
    fi
}

# Grant runtime permissions via ADB
grant_adb_permissions() {
    echo -e "\n${CYAN}━━━ Grant Permissions via ADB ━━━${NC}"
    
    if ! command -v adb &> /dev/null; then
        echo -e "${RED}✗ ADB not available${NC}"
        return 1
    fi
    
    # Check if device is connected
    local devices=$(adb devices | grep -v "List" | grep -c "device")
    if [[ "$devices" -eq 0 ]]; then
        echo -e "${YELLOW}⚠ No device connected via ADB${NC}"
        echo -e "  For local device, adb should show 'emulator' or device ID"
        return 1
    fi
    
    echo -e "${BLUE}Granting permissions to Termux...${NC}"
    
    # Grant READ_EXTERNAL_STORAGE
    adb shell pm grant com.termux android.permission.READ_EXTERNAL_STORAGE 2>/dev/null
    echo -e "  ${GREEN}✓${NC} READ_EXTERNAL_STORAGE"
    
    # Grant WRITE_EXTERNAL_STORAGE
    adb shell pm grant com.termux android.permission.WRITE_EXTERNAL_STORAGE 2>/dev/null
    echo -e "  ${GREEN}✓${NC} WRITE_EXTERNAL_STORAGE"
    
    # Grant READ_PHONE_STATE
    adb shell pm grant com.termux android.permission.READ_PHONE_STATE 2>/dev/null
    echo -e "  ${GREEN}✓${NC} READ_PHONE_STATE"
    
    # Grant ACCESS_FINE_LOCATION
    adb shell pm grant com.termux android.permission.ACCESS_FINE_LOCATION 2>/dev/null
    echo -e "  ${GREEN}✓${NC} ACCESS_FINE_LOCATION"
    
    # Grant ACCESS_COARSE_LOCATION
    adb shell pm grant com.termux android.permission.ACCESS_COARSE_LOCATION 2>/dev/null
    echo -e "  ${GREEN}✓${NC} ACCESS_COARSE_LOCATION"
    
    # Grant CAMERA
    adb shell pm grant com.termux android.permission.CAMERA 2>/dev/null
    echo -e "  ${GREEN}✓${NC} CAMERA"
    
    # Grant RECORD_AUDIO
    adb shell pm grant com.termux android.permission.RECORD_AUDIO 2>/dev/null
    echo -e "  ${GREEN}✓${NC} RECORD_AUDIO"
    
    echo -e "\n${GREEN}✓ Permissions granted successfully!${NC}"
    return 0
}

# Setup wake lock (prevent device from sleeping)
setup_wake_lock() {
    echo -e "\n${CYAN}━━━ Wake Lock Setup ━━━${NC}"
    
    echo -e "${YELLOW}Wake Lock mencegah device dari tidur${NC}"
    echo -e "  Ini penting untuk monitoring berterusan"
    
    if command -v termux-wake-lock &> /dev/null; then
        echo -e "\n${BLUE}Acquiring wake lock...${NC}"
        termux-wake-lock
        echo -e "${GREEN}✓ Wake lock acquired${NC}"
        echo -e "  Device akan kekal aktif semasa monitoring"
        return 0
    else
        echo -e "${YELLOW}⚠ termux-api not available${NC}"
        echo -e "  Alternative: Use 'svc power stayon true' (requires root)"
        
        if command -v svc &> /dev/null && [[ $EUID -eq 0 ]]; then
            svc power stayon true
            echo -e "${GREEN}✓ Stay awake enabled via svc${NC}"
        fi
        
        return 1
    fi
}

# Setup boot receiver
setup_boot_receiver() {
    echo -e "\n${CYAN}━━━ Boot Receiver Setup ━━━${NC}"
    
    echo -e "${YELLOW}Auto-start on boot${NC}"
    echo -e "  Monitor akan start automatically bila device boot"
    
    # Check if Termux:Boot is installed
    local boot_dir="$HOME/.termux/boot"
    
    if [[ ! -d "$boot_dir" ]]; then
        mkdir -p "$boot_dir"
    fi
    
    local boot_script="$boot_dir/cloud-phone-monitor.sh"
    
    cat > "$boot_script" << 'BOOTSCRIPT'
#!/bin/bash
# Cloud Phone Monitor - Boot Receiver
# This script runs when device boots up

# Wait for device to fully boot
sleep 30

# Start monitoring
~/cloud-phone-monitor/monitor.sh start

# Start Telegram bot
~/cloud-phone-monitor/telegram-bot.sh start

# Start Discord bot
~/cloud-phone-monitor/discord-bot.sh start
BOOTSCRIPT
    
    chmod +x "$boot_script"
    
    echo -e "${GREEN}✓ Boot script created${NC}"
    echo -e "  Location: $boot_script"
    echo -e "\n${YELLOW}Note: Install Termux:Boot app from F-Droid for this to work${NC}"
    
    return 0
}

# Test permissions
test_permissions() {
    echo -e "\n${CYAN}━━━ Testing Permissions ━━━${NC}"
    
    local all_ok=true
    
    # Test storage
    echo -e "\n${BLUE}Testing Storage...${NC}"
    if [[ -d "$HOME/storage" ]]; then
        echo -e "  ${GREEN}✓${NC} Storage accessible"
    else
        echo -e "  ${RED}✗${NC} Storage not accessible"
        all_ok=false
    fi
    
    # Test package manager
    echo -e "\n${BLUE}Testing Package Manager (pm)...${NC}"
    if command -v pm &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} pm command available"
        pm list packages | head -3
    else
        echo -e "  ${YELLOW}!${NC} pm command not available"
    fi
    
    # Test activity manager
    echo -e "\n${BLUE}Testing Activity Manager (am)...${NC}"
    if command -v am &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} am command available"
    else
        echo -e "  ${YELLOW}!${NC} am command not available"
    fi
    
    # Test monkey
    echo -e "\n${BLUE}Testing Monkey...${NC}"
    if command -v monkey &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} monkey command available"
    else
        echo -e "  ${YELLOW}!${NC} monkey command not available"
    fi
    
    # Test network
    echo -e "\n${BLUE}Testing Network...${NC}"
    if ping -c 1 google.com &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Network accessible"
    else
        echo -e "  ${RED}✗${NC} Network not accessible"
        all_ok=false
    fi
    
    # Test curl
    echo -e "\n${BLUE}Testing Curl...${NC}"
    if command -v curl &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} curl available"
    else
        echo -e "  ${RED}✗${NC} curl not available"
        all_ok=false
    fi
    
    # Summary
    echo -e "\n${CYAN}━━━ Summary ━━━${NC}"
    if [[ "$all_ok" == "true" ]]; then
        echo -e "${GREEN}✓ All core permissions are working!${NC}"
    else
        echo -e "${YELLOW}⚠ Some permissions are missing${NC}"
        echo -e "  Run individual setup commands to fix"
    fi
}

# Show current status
show_status() {
    echo -e "\n${CYAN}━━━ Current Status ━━━${NC}"
    
    # Device info
    echo -e "\n${BLUE}Device Info:${NC}"
    echo -e "  Device: ${DEVICE_NAME:-$(hostname)}"
    echo -e "  Termux: ${TERMUX_VERSION:-Not running in Termux}"
    echo -e "  Root: $([ $EUID -eq 0 ] && echo 'Yes' || echo 'No')"
    
    # Storage
    echo -e "\n${BLUE}Storage:${NC}"
    echo -e "  Storage dir: $([ -d "$HOME/storage" ] && echo 'Available' || echo 'Not available')"
    
    # Network
    echo -e "\n${BLUE}Network:${NC}"
    echo -e "  Internet: $(ping -c 1 google.com &> /dev/null && echo 'Connected' || echo 'Disconnected')"
    
    # Running services
    echo -e "\n${BLUE}Running Services:${NC}"
    if [[ -f "${SCRIPT_DIR}/monitor.pid" ]]; then
        local pid=$(cat "${SCRIPT_DIR}/monitor.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  Monitor: ${GREEN}Running${NC} (PID: $pid)"
        else
            echo -e "  Monitor: ${RED}Stopped${NC}"
        fi
    else
        echo -e "  Monitor: ${YELLOW}Not started${NC}"
    fi
    
    if [[ -f "${SCRIPT_DIR}/bot.pid" ]]; then
        local pid=$(cat "${SCRIPT_DIR}/bot.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  Telegram Bot: ${GREEN}Running${NC} (PID: $pid)"
        else
            echo -e "  Telegram Bot: ${RED}Stopped${NC}"
        fi
    else
        echo -e "  Telegram Bot: ${YELLOW}Not started${NC}"
    fi
    
    if [[ -f "${SCRIPT_DIR}/discord-bot.pid" ]]; then
        local pid=$(cat "${SCRIPT_DIR}/discord-bot.pid")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "  Discord Bot: ${GREEN}Running${NC} (PID: $pid)"
        else
            echo -e "  Discord Bot: ${RED}Stopped${NC}"
        fi
    else
        echo -e "  Discord Bot: ${YELLOW}Not started${NC}"
    fi
}

# Install required packages
install_packages() {
    echo -e "\n${CYAN}━━━ Installing Required Packages ━━━${NC}"
    
    local packages=(
        "curl"
        "procps"
        "cron"
        "nano"
        "jq"
        "netcat"
    )
    
    if command -v pkg &> /dev/null; then
        echo -e "${BLUE}Updating package lists...${NC}"
        pkg update -y
        
        for pkg in "${packages[@]}"; do
            echo -e "${BLUE}Installing $pkg...${NC}"
            pkg install "$pkg" -y
        done
        
        # Optional: termux-api
        echo -e "\n${YELLOW}Install termux-api? (Required for some features)${NC}"
        echo -n "(y/N): "
        read -r install_api
        
        if [[ "$install_api" =~ ^[Yy]$ ]]; then
            pkg install termux-api -y
            echo -e "${YELLOW}Note: Also install Termux:API app from F-Droid${NC}"
        fi
        
        # Optional: android-tools (ADB)
        echo -e "\n${YELLOW}Install android-tools (ADB)? (Useful for permissions)${NC}"
        echo -n "(y/N): "
        read -r install_adb
        
        if [[ "$install_adb" =~ ^[Yy]$ ]]; then
            pkg install android-tools -y
        fi
        
        echo -e "\n${GREEN}✓ Packages installed successfully!${NC}"
    else
        echo -e "${RED}✗ Not running in Termux${NC}"
        echo -e "  Please install packages manually using your package manager"
    fi
}

# Quick setup (all essential)
quick_setup() {
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}                 QUICK SETUP - All Essential Permissions${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Install packages
    install_packages
    
    # Storage permission
    check_storage_permission
    
    # Setup wake lock
    setup_wake_lock
    
    # Setup boot receiver
    setup_boot_receiver
    
    # Test permissions
    test_permissions
    
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}            Quick Setup Complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "\n${YELLOW}Next steps:${NC}"
    echo -e "  1. Enable Accessibility Service (for app detection)"
    echo -e "  2. Enable Usage Stats Access (for detailed monitoring)"
    echo -e "  3. Configure config.conf"
    echo -e "  4. Start monitoring: ./monitor.sh start"
}

# Interactive menu
show_menu() {
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}                       MAIN MENU${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    echo -e "\n${BLUE}Setup Permissions:${NC}"
    echo -e "  1) Quick Setup (All Essential)"
    echo -e "  2) Storage Permission"
    echo -e "  3) Accessibility Service"
    echo -e "  4) Usage Stats Access"
    echo -e "  5) Display Over Other Apps"
    echo -e "  6) Developer Options"
    echo -e "  7) ADB Setup"
    echo -e "  8) Grant Permissions via ADB"
    
    echo -e "\n${BLUE}System:${NC}"
    echo -e "  9) Install Required Packages"
    echo -e "  10) Setup Wake Lock"
    echo -e "  11) Setup Boot Receiver"
    echo -e "  12) Test Permissions"
    echo -e "  13) Show Status"
    
    echo -e "\n${BLUE}Options:${NC}"
    echo -e "  0) Exit"
    
    echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -n "Select option: "
}

# Main loop
main() {
    show_banner
    check_termux
    check_root
    
    while true; do
        show_menu
        read -r choice
        
        case "$choice" in
            1) quick_setup ;;
            2) check_storage_permission ;;
            3) setup_accessibility ;;
            4) setup_usage_stats ;;
            5) setup_display_over_apps ;;
            6) setup_developer_options ;;
            7) setup_adb ;;
            8) grant_adb_permissions ;;
            9) install_packages ;;
            10) setup_wake_lock ;;
            11) setup_boot_receiver ;;
            12) test_permissions ;;
            13) show_status ;;
            0) 
                echo -e "\n${GREEN}Goodbye!${NC}"
                exit 0 
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        
        echo -e "\n${YELLOW}Press Enter to continue...${NC}"
        read -r
    done
}

# Run with command line args or interactive menu
case "${1:-}" in
    quick)
        quick_setup
        ;;
    storage)
        check_storage_permission
        ;;
    accessibility)
        setup_accessibility
        ;;
    usage-stats)
        setup_usage_stats
        ;;
    adb)
        setup_adb
        ;;
    grant)
        grant_adb_permissions
        ;;
    wake-lock)
        setup_wake_lock
        ;;
    boot)
        setup_boot_receiver
        ;;
    test)
        test_permissions
        ;;
    status)
        show_status
        ;;
    packages)
        install_packages
        ;;
    *)
        main
        ;;
esac
