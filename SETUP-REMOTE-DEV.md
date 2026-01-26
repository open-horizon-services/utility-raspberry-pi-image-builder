# Remote Linux Development Setup Guide

This guide will help you set up VS Code Remote-SSH with OpenCode for developing the Raspberry Pi Image Builder on a Linux machine while working from macOS.

## Overview

Your setup will work like this:

```
┌─────────────────────────────────┐
│   macOS (Your Computer)         │
│   - VS Code UI                  │
│   - Editor & Extensions UI      │
│   └─────────┬───────────────────┘
              │ SSH
              ▼
┌─────────────────────────────────┐
│   Linux Machine (192.168.0.101) │
│   - VS Code Server              │
│   - OpenCode CLI                │
│   - Build Scripts               │
│   - Native Linux Tools          │
└─────────────────────────────────┘
```

## ✅ Already Completed

The following has been automatically configured:

1. **SSH Keys**: Passwordless authentication set up
2. **SSH Config**: Friendly hostname `linux-dev` added to `~/.ssh/config`
3. **Repository Cloned**: Project is at `~/raspberry-pi-image-builder` on Linux
4. **Branch Ready**: `issue-5` branch checked out
5. **Sudo Config Prepared**: Configuration file ready at `/tmp/opencode-mount-sudo`
6. **Setup Script**: Automated setup script created at `/tmp/setup-linux-dev.sh`

## 🔧 Manual Steps Required

### Step 1: Run Setup Script on Linux Machine

SSH into your Linux machine and run the automated setup script:

```bash
# Connect to Linux machine
ssh linux-dev

# Run the setup script (requires sudo password)
bash /tmp/setup-linux-dev.sh
```

This script will:
- Install Node.js 20.x
- Install OpenCode CLI globally
- Configure passwordless sudo for mount operations
- Install required dependencies (qemu, parted, fdisk, etc.)

**Expected output**: You should see "Setup Complete" with a summary of installed tools.

### Step 2: Test SSH Connection

From your Mac, verify you can connect without password:

```bash
# This should work without asking for password
ssh linux-dev 'echo "Connection successful!"'
```

### Step 3: Set Up VS Code Remote-SSH

#### 3a. Install VS Code Extension

1. Open VS Code on your Mac
2. Click Extensions icon (⇧⌘X) or View → Extensions
3. Search for: **Remote - SSH**
4. Install the extension by Microsoft (ID: `ms-vscode-remote.remote-ssh`)

#### 3b. Connect to Linux Machine

1. Press `Cmd+Shift+P` to open Command Palette
2. Type: `Remote-SSH: Connect to Host`
3. Select `linux-dev` from the list
4. A new VS Code window will open
5. Wait for "Connected to linux-dev" in bottom-left corner
6. First connection will install VS Code Server (may take 1-2 minutes)

#### 3c. Open Project

1. In VS Code (connected to linux-dev):
2. File → Open Folder
3. Navigate to: `/home/jennbeck/raspberry-pi-image-builder`
4. Click "OK"

### Step 4: Verify OpenCode Installation

Open the integrated terminal in VS Code (Terminal → New Terminal) and verify:

```bash
# Check OpenCode is installed
opencode --version

# Check Node.js
node --version

# Check you're in the right directory
pwd
# Should show: /home/jennbeck/raspberry-pi-image-builder

# Check git status
git status
# Should show: On branch issue-5
```

### Step 5: Test OpenCode

In the VS Code terminal (on Linux), start OpenCode:

```bash
opencode
```

Then test with a simple command:
```
Check if the build script is executable and show its permissions
```

OpenCode should be able to read the file and respond.

### Step 6: Test Build Script Dependencies

Verify all dependencies are installed:

```bash
# Test platform detection
./lib/platform-detect.sh detect

# Check if sudo works without password (important!)
sudo losetup --version
# Should NOT ask for password

# Test QEMU installation
which qemu-arm-static

# Verify all required tools
./build-rpi-image.sh --help
```

## 🚀 Usage

### Starting a Development Session

1. Open VS Code on Mac
2. `Cmd+Shift+P` → `Remote-SSH: Connect to Host` → `linux-dev`
3. VS Code opens connected to Linux
4. Open integrated terminal
5. Run: `opencode`
6. Start coding!

### Working with Git

All git operations happen on the Linux machine:

```bash
# Make changes in VS Code editor
# Then in terminal:
git add .
git commit -s -m "Your message"
git push origin issue-5
```

### Running Build Script

Since you're on Linux, you have full access to native tools:

```bash
# Run with actual Linux mount operations
sudo ./build-rpi-image.sh \
  --oh-version "2.30.0" \
  --base-image "path/to/raspios.img" \
  --output-image "custom-rpi.img"
```

## 🔍 Troubleshooting

### SSH Connection Issues

**Problem**: Can't connect via SSH

```bash
# Test basic SSH
ssh linux-dev

# Test with verbose output
ssh -v linux-dev

# Check SSH config
cat ~/.ssh/config | grep -A 5 "linux-dev"
```

### OpenCode Not Found

**Problem**: `opencode: command not found`

```bash
# Check if Node.js is installed
node --version

# Check npm global directory
npm config get prefix

# Reinstall OpenCode
sudo npm install -g @opencode/cli

# Verify installation
which opencode
```

### Sudo Password Required for Mount

**Problem**: `sudo losetup` asks for password

```bash
# Check sudoers file
sudo cat /etc/sudoers.d/opencode-mount

# Should contain:
# jennbeck ALL=(ALL) NOPASSWD: /bin/mount, /bin/umount, /sbin/losetup...

# If missing, run setup script again:
bash /tmp/setup-linux-dev.sh
```

### VS Code Can't Find Files

**Problem**: VS Code can't access project files

1. Ensure you're connected to `linux-dev` (check bottom-left corner)
2. File → Open Folder → `/home/jennbeck/raspberry-pi-image-builder`
3. Trust the workspace when prompted

## 📝 Configuration Files

### SSH Config (~/.ssh/config on Mac)

```
Host linux-dev
    HostName 192.168.0.101
    User jennbeck
    ForwardAgent yes
```

### Sudoers Config (/etc/sudoers.d/opencode-mount on Linux)

```
# Allow user to run mount commands without password
jennbeck ALL=(ALL) NOPASSWD: /bin/mount, /bin/umount, /sbin/losetup, /usr/bin/qemu-arm-static, /usr/bin/chroot
```

## 🎯 Benefits of This Setup

✅ **Native Linux Environment**: Real mount, losetup, chroot operations  
✅ **Comfortable Editing**: macOS keyboard, display, and UI  
✅ **Full OpenCode Context**: Access to all Linux tools and capabilities  
✅ **Seamless Git**: Commit directly on Linux machine  
✅ **No Sync Issues**: Single source of truth for code  
✅ **Persistent Sessions**: OpenCode sessions stay on Linux between connections  

## 🔗 Quick Reference

| Action | Command |
|--------|---------|
| Connect to Linux | `ssh linux-dev` |
| Start VS Code Remote | Cmd+Shift+P → Remote-SSH: Connect → linux-dev |
| Start OpenCode | `opencode` (in VS Code terminal) |
| Run build script | `sudo ./build-rpi-image.sh ...` |
| Check git status | `git status` |
| Test dependencies | `./lib/platform-detect.sh detect` |

## 📚 Next Steps

Once your setup is working:

1. Read [AGENTS.md](AGENTS.md) for project coding standards
2. Review [README.md](README.md) for project overview
3. Run tests: `bats test/` (if BATS is installed)
4. Start developing with OpenCode on Linux!

## 🆘 Getting Help

If you encounter issues:

1. Check this guide's Troubleshooting section
2. Verify all steps were completed
3. Test each component individually (SSH, Node.js, OpenCode)
4. Check logs in VS Code: View → Output → Remote-SSH

---

**Setup completed by**: OpenCode Sisyphus Agent  
**Date**: 2026-01-26  
**Linux Machine**: 192.168.0.101 (Ubuntu 22.04.5 LTS)
