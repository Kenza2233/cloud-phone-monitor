# 📱 Cloud Phone Monitor - Termux Scripts

Scripts untuk monitor dan auto-restart apps di cloud phone dengan notification ke Discord dan Telegram.

## 🚀 Features

- ✅ **Monitor Status App** - Pantau status app secara berkala
- ✅ **Auto-Restart** - Buka semula app jika crash
- ✅ **Discord Webhook** - Hantar notification ke Discord
- ✅ **Discord Bot** - Control apps melalui Discord dengan slash commands
- ✅ **Telegram Bot** - Control apps melalui Telegram
- ✅ **Developer Options** - Setup permissions dengan mudah
- ✅ **Hourly Report** - Laporan status setiap 1 jam
- ✅ **Remote Control** - Buka/tutup app dari jauh

## 📦 Installation

### 1. Install Termux

Download dan install Termux dari:
- [F-Droid](https://f-droid.org/packages/com.termux/) (Recommended)
- [GitHub Releases](https://github.com/termux/termux-app/releases)

**Note:** Jangan install dari Play Store kerana version sudah outdated.

### 2. Install Termux:API (Optional)

Untuk features tambahan:
- Install app **Termux:API** dari F-Droid
- Run di Termux: `pkg install termux-api`

### 3. Run Installation Script

```bash
# Download dan run install script
curl -sL https://your-domain.com/termux-scripts/install.sh | bash

# Atau manual:
pkg update && pkg upgrade -y
pkg install curl procps -y
```

### 4. Copy Scripts

```bash
mkdir -p ~/cloud-phone-monitor
cd ~/cloud-phone-monitor

# Download all scripts
curl -O https://your-domain.com/termux-scripts/monitor.sh
curl -O https://your-domain.com/termux-scripts/telegram-bot.sh
curl -O https://your-domain.com/termux-scripts/discord-bot.sh
curl -O https://your-domain.com/termux-scripts/dev-options.sh
curl -O https://your-domain.com/termux-scripts/config.conf.example

chmod +x *.sh
cp config.conf.example config.conf
```

### 5. Setup Permissions

Run the Developer Options script untuk setup semua permissions:

```bash
./dev-options.sh
```

Pilih "Quick Setup" untuk setup semua permissions yang diperlukan.

## ⚙️ Configuration

Edit `config.conf`:

```bash
nano ~/cloud-phone-monitor/config.conf
```

### Discord Webhook

1. Buka Discord server anda
2. Server Settings → Integrations → Webhooks
3. Click "New Webhook"
4. Copy webhook URL dan paste dalam config:

```bash
DISCORD_WEBHOOK="https://discord.com/api/webhooks/WEBHOOK_ID/WEBHOOK_TOKEN"
```

### Discord Bot (untuk commands)

1. Pergi ke [Discord Developer Portal](https://discord.com/developers/applications)
2. Click "New Application" dan beri nama
3. Pergi ke tab "Bot" → Click "Add Bot"
4. Copy Bot Token
5. Enable "Message Content Intent" di Privileged Gateway Intents
6. Pergi ke OAuth2 → URL Generator
7. Pilih scopes: `bot` dan `applications.commands`
8. Pilih permissions: Send Messages, Embed Links, Use Slash Commands
9. Copy URL dan authorize bot ke server
10. Update config:

```bash
DISCORD_BOT_TOKEN="YOUR_BOT_TOKEN"
DISCORD_APP_ID="YOUR_APP_ID"
DISCORD_GUILD_ID="YOUR_GUILD_ID"
DISCORD_CHANNEL_ID="YOUR_CHANNEL_ID"
```

### Telegram Bot

1. Buka [@BotFather](https://t.me/botfather) di Telegram
2. Hantar `/newbot` dan ikut arahan
3. Copy bot token yang diberikan

4. Dapatkan Chat ID:
   - Untuk personal: Hantar mesej ke bot, buka `https://api.telegram.org/botYOUR_TOKEN/getUpdates`
   - Untuk group: Tambah [@RawDataBot](https://t.me/RawDataBot) ke group

5. Update config:

```bash
TELEGRAM_TOKEN="YOUR_BOT_TOKEN"
TELEGRAM_CHAT_ID="YOUR_CHAT_ID"
```

### Apps Configuration

Format: `package_name|display_name|auto_restart`

```bash
APP_LIST="com.whatsapp|WhatsApp|true,org.telegram.messenger|Telegram|true,com.zhiliaoapp.musically|TikTok|true"
```

**Common Package Names:**
| App | Package Name |
|-----|-------------|
| WhatsApp | com.whatsapp |
| Telegram | org.telegram.messenger |
| TikTok | com.zhiliaoapp.musically |
| Facebook | com.facebook.katana |
| Instagram | com.instagram.android |
| Shopee | com.shopee.id |
| Grab | com.grab.taxibooking |
| Gojek | com.gojek.app |

## 🎮 Usage

### Basic Commands

```bash
# Start monitoring (background)
./monitor.sh start

# Stop monitoring
./monitor.sh stop

# Show status
./monitor.sh status

# Test notifications
./monitor.sh test

# View logs
./monitor.sh logs

# Help
./monitor.sh help
```

### Manual App Control

```bash
# Open app
./monitor.sh open com.whatsapp

# Close app
./monitor.sh close com.whatsapp

# Restart app
./monitor.sh restart com.whatsapp
```

### Telegram Bot

```bash
# Start bot
./telegram-bot.sh start

# Stop bot
./telegram-bot.sh stop

# Check status
./telegram-bot.sh status
```

### Discord Bot

```bash
# Setup instructions
./discord-bot.sh setup

# Register slash commands
./discord-bot.sh register

# Start bot
./discord-bot.sh start

# Stop bot
./discord-bot.sh stop

# Test connection
./discord-bot.sh test
```

### Developer Options

```bash
# Interactive menu
./dev-options.sh

# Quick setup (all permissions)
./dev-options.sh quick

# Test permissions
./dev-options.sh test

# Show status
./dev-options.sh status
```

## 📱 Telegram Bot Commands

| Command | Description |
|---------|-------------|
| `/start` | Mulakan bot |
| `/status` | Status semua apps |
| `/open` | Menu untuk buka app |
| `/restart` | Menu untuk restart app |
| `/stop` | Menu untuk stop app |
| `/report` | Hantar laporan |
| `/test` | Test notification |
| `/help` | Bantuan |
| `/monitor start/stop/status` | Control monitoring |

## 💬 Discord Bot Commands

| Command | Description |
|---------|-------------|
| `/status` | Status semua apps |
| `/open <app>` | Buka app |
| `/close <app>` | Tutup app |
| `/restart <app>` | Restart app |
| `/monitor <action>` | Control monitor (start/stop/status) |
| `/report` | Hantar status report |
| `/help` | Bantuan |

## 🔄 Auto-Start on Boot

### Method 1: Using .bashrc

```bash
echo "~/cloud-phone-monitor/monitor.sh start" >> ~/.bashrc
echo "~/cloud-phone-monitor/telegram-bot.sh start" >> ~/.bashrc
```

### Method 2: Using Termux:Boot

1. Install Termux:Boot app dari F-Droid
2. Create script:

```bash
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/monitor.sh << 'EOF'
#!/bin/bash
~/cloud-phone-monitor/monitor.sh start
~/cloud-phone-monitor/telegram-bot.sh start
EOF
chmod +x ~/.termux/boot/monitor.sh
```

## 📊 Monitoring Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    CLOUD PHONE MONITOR                       │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │  Check App  │───▶│  Running?   │───▶│   Notify    │     │
│  │   Status    │    │             │    │  (Changed)  │     │
│  └─────────────┘    └──────┬──────┘    └─────────────┘     │
│                            │                                 │
│                     ┌──────▼──────┐                         │
│                     │   Stopped?  │                         │
│                     └──────┬──────┘                         │
│                            │                                 │
│              ┌─────────────┴─────────────┐                  │
│              │                           │                  │
│       ┌──────▼──────┐            ┌───────▼───────┐         │
│       │ Auto-Restart│            │    Notify     │         │
│       │   Enabled?  │            │   (Crashed)   │         │
│       └──────┬──────┘            └───────────────┘         │
│              │                                               │
│       ┌──────▼──────┐                                       │
│       │  Open App   │                                       │
│       │  (Restart)  │                                       │
│       └─────────────┘                                       │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              NOTIFICATIONS                           │   │
│  │  ┌─────────────┐        ┌─────────────┐            │   │
│  │  │   Discord   │        │  Telegram   │            │   │
│  │  │   Webhook   │        │    Bot      │            │   │
│  │  └─────────────┘        └─────────────┘            │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  Every Hour: Send Status Report                             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Troubleshooting

### App tidak dapat di-detect

1. Enable Accessibility Service:
   - Settings → Accessibility → Termux

2. Enable Usage Stats:
   - Settings → Security → Usage Stats → Termux

3. Check with manual command:
   ```bash
   pidof com.whatsapp
   ps -ef | grep whatsapp
   ```

### Notification tidak sampai

1. Test webhook URL:
   ```bash
   curl -X POST "YOUR_WEBHOOK_URL" \
     -H "Content-Type: application/json" \
     -d '{"content":"Test message"}'
   ```

2. Test Telegram:
   ```bash
   curl "https://api.telegram.org/botYOUR_TOKEN/sendMessage?chat_id=YOUR_CHAT_ID&text=Test"
   ```

### Permission Denied

```bash
chmod +x ~/cloud-phone-monitor/*.sh
```

### Termux Killed by Android

Android mungkin kill Termux untuk save battery. Solutions:

1. Disable battery optimization untuk Termux
2. Lock Termux in recent apps
3. Use Termux:Boot untuk auto-restart
4. Use foreground service with notification

## 📝 Files Structure

```
~/cloud-phone-monitor/
├── monitor.sh          # Main monitoring script
├── telegram-bot.sh     # Telegram bot handler
├── discord-bot.sh      # Discord bot handler
├── dev-options.sh      # Developer options & permissions setup
├── config.conf         # Configuration file
├── config.conf.example # Example configuration
├── install.sh          # Installation script
├── monitor.log         # Monitor logs
├── bot.log             # Telegram bot logs
├── discord-bot.log     # Discord bot logs
├── monitor.pid         # Monitor PID file
├── bot.pid             # Telegram bot PID file
├── discord-bot.pid     # Discord bot PID file
└── status.json         # Current status cache
```

## 🔐 Security Notes

1. **Jangan share** `config.conf` kerana mengandungi tokens
2. Gunakan authorized chat ID untuk Telegram bot
3. Protect webhook URLs daripada public access
4. Consider using environment variables untuk sensitive data

## 📄 License

MIT License - Free to use and modify.

## 🤝 Contributing

Feel free to submit issues and pull requests!
