# 🚀 Tutorial: Push ke GitHub

## 📋 Prerequisites

Sebelum mula, pastikan anda ada:
- ✅ Akaun GitHub (https://github.com)
- ✅ Git installed di komputer
- ✅ Semua script files yang diperlukan

---

## 📁 Step 1: Sediakan Files

### Files yang Diperlukan

Buat folder baru dan download semua files ini:

```
cloud-phone-monitor/
├── monitor.sh          # Main monitoring script
├── telegram-bot.sh     # Telegram bot handler
├── discord-bot.sh      # Discord bot handler
├── dev-options.sh      # Developer options setup
├── install.sh          # Installation script
├── config.conf.example # Config template
├── README.md           # Documentation
├── LICENSE             # License file (All Rights Reserved)
├── TUTORIAL.md         # Tutorial ini
└── .gitignore          # Git ignore file
```

---

## 🔧 Step 2: Install Git (Jika Belum)

### Windows

```bash
# Download dari https://git-scm.com/download/win
# Atau guna winget
winget install Git.Git
```

### Mac

```bash
brew install git
```

### Linux/Termux

```bash
# Ubuntu/Debian
sudo apt install git

# Termux
pkg install git
```

---

## ⚙️ Step 3: Configure Git

```bash
# Set nama
git config --global user.name "Nama Anda"

# Set email (guna email GitHub anda)
git config --global user.email "email@github.com"
```

---

## 🌐 Step 4: Create GitHub Repository

### Di GitHub Website:

1. **Login ke GitHub**
   - Pergi ke https://github.com
   - Login dengan akaun anda

2. **Create New Repository**
   - Click **+** di pojok kanan atas
   - Pilih **New repository**

3. **Isi Maklumat Repository**
   - **Repository name:** `cloud-phone-monitor`
   - **Description:** `Monitor dan auto-restart apps di cloud phone`
   - **Visibility:** Public atau Private
   - **⚠️ PENTING:** JANGAN check "Add a README file"
   - **⚠️ PENTING:** JANGAN pilih license (kita ada license sendiri)
   - **⚠️ PENTING:** JANGAN add .gitignore (kita ada sendiri)

4. **Click "Create repository"**

---

## 📤 Step 5: Initialize dan Push

### Di Terminal/Command Prompt:

```bash
# Pergi ke folder yang ada semua files
cd cloud-phone-monitor

# Initialize git repository
git init

# Add semua files
git add .

# Check apa yang akan di-commit
git status

# Commit
git commit -m "Initial commit: Cloud Phone Monitor"

# Add remote (GANTIKAN YOUR_USERNAME dengan GitHub username anda)
git remote add origin https://github.com/YOUR_USERNAME/cloud-phone-monitor.git

# Rename branch ke main
git branch -M main

# Push ke GitHub
git push -u origin main
```

---

## 🔑 Step 6: Authentication

### Jika Diminta Login:

#### Option 1: Personal Access Token (Recommended)

1. Pergi ke GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token"
3. Pilih scopes: `repo` (full control)
4. Copy token
5. Guna token sebagai password

#### Option 2: GitHub CLI

```bash
# Install GitHub CLI
# Windows: winget install GitHub.cli
# Mac: brew install gh
# Linux: sudo apt install gh

# Login
gh auth login

# Push
git push -u origin main
```

#### Option 3: SSH Key

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "email@github.com"

# Copy public key
cat ~/.ssh/id_ed25519.pub

# Add ke GitHub: Settings → SSH and GPG keys → New SSH key

# Guna SSH URL
git remote set-url origin git@github.com:YOUR_USERNAME/cloud-phone-monitor.git
git push -u origin main
```

---

## ✅ Step 7: Verify

1. Buka repository anda di GitHub:
   `https://github.com/YOUR_USERNAME/cloud-phone-monitor`

2. Pastikan semua files ada

3. Check README.md dipaparkan dengan betul

---

## 🔄 Update Repository (Kemudian)

```bash
# Edit files yang perlu
nano config.conf.example

# Add changes
git add .

# Commit
git commit -m "Update: Description of changes"

# Push
git push
```

---

## 📱 Update Install Script

Selepas push ke GitHub, update `install.sh`:

```bash
# Edit install.sh
nano install.sh

# Tukar line ini:
GITHUB_REPO="https://raw.githubusercontent.com/YOUR_USERNAME/cloud-phone-monitor/main"
```

Commit dan push:

```bash
git add install.sh
git commit -m "Update: GitHub repo URL"
git push
```

---

## 🎉 Selesai!

Sekarang orang lain boleh install dengan:

```bash
curl -sL https://raw.githubusercontent.com/YOUR_USERNAME/cloud-phone-monitor/main/install.sh | bash
```

---

## ❓ Troubleshooting

### Error: "fatal: not a git repository"
```bash
git init
```

### Error: "fatal: remote origin already exists"
```bash
git remote remove origin
git remote add origin https://github.com/YOUR_USERNAME/cloud-phone-monitor.git
```

### Error: "fatal: authentication failed"
- Guna Personal Access Token
- Atau login dengan GitHub CLI

### Error: "failed to push some refs"
```bash
git pull origin main --rebase
git push -u origin main
```

### Error: "Permission denied (publickey)"
- Setup SSH key dengan betul
- Atau guna HTTPS dengan token
