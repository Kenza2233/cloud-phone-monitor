#!/bin/bash
#===============================================================================
# CLOUD PHONE MONITOR - Termux Installation Script
# Run script ini di Termux untuk install semua dependencies
#===============================================================================

echo "========================================"
echo "  Cloud Phone Monitor - Termux Setup"
echo "========================================"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if running in Termux
if [[ -z "$TERMUX_VERSION" ]]; then
    echo -e "${YELLOW}Warning: Script ini direka untuk Termux.${NC}"
    echo "Ia masih boleh berfungsi di environment lain dengan beberapa limitations."
    echo ""
fi

# Update packages
echo -e "${CYAN}Updating packages...${NC}"
pkg update -y && pkg upgrade -y

# Install required packages
echo -e "${CYAN}Installing required packages...${NC}"

# curl - untuk HTTP requests
if ! command -v curl &> /dev/null; then
    pkg install curl -y
fi

# procps - untuk ps command
if ! command -v ps &> /dev/null; then
    pkg install procps -y
fi

# termux-api - untuk akses Android features (optional)
if ! command -v termux-notification &> /dev/null; then
    echo -e "${YELLOW}Installing termux-api (optional)...${NC}"
    pkg install termux-api -y
    echo -e "${YELLOW}Note: Anda perlu install app Termux:API dari Play Store untuk guna termux-api${NC}"
fi

# Create script directory
SCRIPT_DIR="$HOME/cloud-phone-monitor"
mkdir -p "$SCRIPT_DIR"

# Copy script files
echo -e "${CYAN}Setting up scripts...${NC}"

# Copy monitor.sh
if [[ -f "monitor.sh" ]]; then
    cp monitor.sh "$SCRIPT_DIR/"
else
    echo -e "${YELLOW}Downloading monitor.sh...${NC}"
    curl -sL "https://raw.githubusercontent.com/YOUR_REPO/monitor.sh" -o "$SCRIPT_DIR/monitor.sh"
fi

# Copy config file if not exists
if [[ ! -f "$SCRIPT_DIR/config.conf" ]]; then
    if [[ -f "config.conf.example" ]]; then
        cp config.conf.example "$SCRIPT_DIR/config.conf"
    else
        echo -e "${YELLOW}Downloading config.conf.example...${NC}"
        curl -sL "https://raw.githubusercontent.com/YOUR_REPO/config.conf.example" -o "$SCRIPT_DIR/config.conf"
    fi
fi

# Make executable
chmod +x "$SCRIPT_DIR/monitor.sh"

# Create aliases for easy access
echo ""
echo -e "${CYAN}Creating aliases...${NC}"
ALIAS_LINE="alias monitor='$SCRIPT_DIR/monitor.sh'"

if [[ -f "$HOME/.bashrc" ]]; then
    if ! grep -q "alias monitor=" "$HOME/.bashrc"; then
        echo "$ALIAS_LINE" >> "$HOME/.bashrc"
    fi
elif [[ -f "$HOME/.zshrc" ]]; then
    if ! grep -q "alias monitor=" "$HOME/.zshrc"; then
        echo "$ALIAS_LINE" >> "$HOME/.zshrc"
    fi
fi

# Setup autorun (optional)
echo ""
echo -e "${CYAN}Setup autorun? (Monitor akan start bila Termux dibuka)${NC}"
echo -n "(y/N): "
read -r autorun_choice

if [[ "$autorun_choice" =~ ^[Yy]$ ]]; then
    AUTORUN_LINE="$SCRIPT_DIR/monitor.sh start"
    
    if [[ -f "$HOME/.bashrc" ]]; then
        if ! grep -q "monitor.sh start" "$HOME/.bashrc"; then
            echo "# Auto-start Cloud Phone Monitor" >> "$HOME/.bashrc"
            echo "$AUTORUN_LINE" >> "$HOME/.bashrc"
            echo -e "${GREEN}Autorun added to .bashrc${NC}"
        fi
    elif [[ -f "$HOME/.zshrc" ]]; then
        if ! grep -q "monitor.sh start" "$HOME/.zshrc"; then
            echo "# Auto-start Cloud Phone Monitor" >> "$HOME/.zshrc"
            echo "$AUTORUN_LINE" >> "$HOME/.zshrc"
            echo -e "${GREEN}Autorun added to .zshrc${NC}"
        fi
    fi
fi

# Setup cron job for monitoring (alternative to background process)
echo ""
echo -e "${CYAN}Setup cron job? (Alternative monitoring method)${NC}"
echo -n "(y/N): "
read -r cron_choice

if [[ "$cron_choice" =~ ^[Yy]$ ]]; then
    pkg install cron -y
    
    # Create cron job
    CRON_JOB="* * * * * $SCRIPT_DIR/monitor.sh status > /dev/null 2>&1"
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    
    # Start cron daemon
    crond
    
    echo -e "${GREEN}Cron job setup complete${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}        Installation Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Script location: ${CYAN}$SCRIPT_DIR/monitor.sh${NC}"
echo ""
echo "Next steps:"
echo "1. Edit konfigurasi:"
echo -e "   ${CYAN}nano $SCRIPT_DIR/config.conf${NC}"
echo ""
echo "2. Test notification:"
echo -e "   ${CYAN}$SCRIPT_DIR/monitor.sh test${NC}"
echo ""
echo "3. Start monitoring:"
echo -e "   ${CYAN}$SCRIPT_DIR/monitor.sh start${NC}"
echo ""
echo "4. Check status:"
echo -e "   ${CYAN}$SCRIPT_DIR/monitor.sh status${NC}"
echo ""
echo "5. View logs:"
echo -e "   ${CYAN}$SCRIPT_DIR/monitor.sh logs${NC}"
echo ""
echo "For more commands:"
echo -e "   ${CYAN}$SCRIPT_DIR/monitor.sh help${NC}"
echo ""

# Grant necessary permissions
echo -e "${YELLOW}Note: Beberapa fitur memerlukan permissions khas:${NC}"
echo "- Accessibility Service (untuk detect app yang running)"
echo "- Usage Stats Access (untuk monitor app usage)"
echo "- Draw Over Other Apps (untuk beberapa fitur)"
echo ""
echo "Jika monitor tidak dapat detect app, sila enable:"
echo "Settings > Accessibility > Termux"
echo "Settings > Security > Usage Stats > Termux"
