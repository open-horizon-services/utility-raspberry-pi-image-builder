# Remote Development Workflow (OpenCode on macOS → Linux)

This document describes how to use OpenCode running on macOS to develop and test on a remote Linux machine.

## Architecture

```
┌───────────────────────────────────────┐
│  macOS (Local Machine)                │
│  - OpenCode running here              │
│  - Executes commands via SSH          │
│  - Git operations via SSH             │
└─────────────┬─────────────────────────┘
              │ SSH Connection
              ▼
┌───────────────────────────────────────┐
│  Linux (192.168.0.101 / linux-dev)    │
│  - VS Code Server                     │
│  - Code repository                    │
│  - Native Linux tools                 │
│  - Build scripts execute here         │
└───────────────────────────────────────┘
```

## Current Setup Status

✅ **Completed:**
- SSH passwordless authentication
- Repository cloned: `~/raspberry-pi-image-builder`
- Branch ready: `issue-5`
- VS Code Remote-SSH connected
- Build script working
- All library files present

⚠️ **Still Needed:**
- Passwordless sudo for mount operations
- QEMU and build dependencies

## Daily Workflow

### Starting Your Day

**1. Open VS Code and Connect to Linux:**
- Open VS Code on macOS
- Press `Cmd+Shift+P` → "Remote-SSH: Connect to Host" → `linux-dev`
- Open folder: `~/raspberry-pi-image-builder`

**2. Start OpenCode on macOS:**
In a separate terminal on macOS:
```bash
cd ~/local/rpi-hzn
opencode
```

**3. Now you have two terminals:**
- **VS Code Terminal**: Connected to Linux for manual commands
- **OpenCode Terminal**: On macOS, can execute commands on Linux via SSH

### Making Code Changes

**Option A: Edit in VS Code (Recommended)**
1. Open files in VS Code (connected to linux-dev)
2. Edit directly - changes are on Linux machine
3. Save files
4. Test in VS Code terminal or ask OpenCode to test via SSH

**Option B: Ask OpenCode to Make Changes**
```
You: "Update the mount_image function in lib/image-mount.sh to add better error handling"

OpenCode: [Executes via SSH to edit files on Linux]
```

### Running Build Script

**In VS Code Terminal (on Linux):**
```bash
cd ~/raspberry-pi-image-builder

# Test help
./build-rpi-image.sh --help

# Run actual build (requires sudo)
sudo ./build-rpi-image.sh \
  --oh-version "2.30.0" \
  --base-image "path/to/raspios.img" \
  --output-image "custom-rpi.img"
```

**Via OpenCode on macOS:**
```
You: "Test the platform detection on linux-dev"

OpenCode will run: ssh linux-dev 'cd ~/raspberry-pi-image-builder && ./lib/platform-detect.sh detect'
```

### Git Operations

**Via OpenCode on macOS:**
```
You: "Check git status on linux-dev"
You: "Commit changes on linux-dev with message 'Fix mount error handling'"
You: "Push to origin issue-5"
```

OpenCode executes these via SSH.

**Or manually in VS Code Terminal:**
```bash
git status
git add .
git commit -s -m "Your message"
git push origin issue-5
```

## Common OpenCode Commands

### Check Files on Linux
```
You: "Show the contents of build-rpi-image.sh on linux-dev"
You: "List all shell scripts in the lib directory on linux-dev"
You: "Check if README.md exists on linux-dev"
```

### Run Tests on Linux
```
You: "Run the platform detection script on linux-dev"
You: "Test if the build script is executable on linux-dev"
You: "Check the git log on linux-dev"
```

### Edit Files on Linux
```
You: "Edit lib/image-mount.sh on linux-dev to add error handling"
You: "Update the README.md on linux-dev with installation instructions"
```

### Git Operations
```
You: "Commit all changes on linux-dev with message 'Add feature X'"
You: "Push the current branch to origin"
You: "Create a new branch issue-6 on linux-dev"
```

## Completing the Setup

You still need to configure passwordless sudo for mount operations. 

**In VS Code Terminal (on linux-dev):**

```bash
# Install the sudoers configuration
sudo visudo -cf /tmp/opencode-mount-sudo && \
sudo cp /tmp/opencode-mount-sudo /etc/sudoers.d/opencode-mount && \
sudo chmod 440 /etc/sudoers.d/opencode-mount

# Test it works (should not ask for password)
sudo losetup --version
```

**Install build dependencies:**
```bash
sudo apt-get update
sudo apt-get install -y \
    qemu-user-static \
    binfmt-support \
    parted \
    fdisk \
    e2fsprogs \
    dosfstools
```

## Advantages of This Setup

✅ **Best of Both Worlds:**
- OpenCode AI assistance from macOS
- Native Linux environment for testing
- VS Code for comfortable editing
- SSH bridges them seamlessly

✅ **No Installation Issues:**
- Don't need OpenCode installed on Linux
- Avoid binary compatibility issues
- Keep OpenCode updated on one machine

✅ **Flexible:**
- Can use VS Code for quick edits
- Can use OpenCode for complex tasks
- Can mix both approaches

## Quick Reference

| Task | Where | How |
|------|-------|-----|
| Edit files | VS Code on Linux | Open files and edit directly |
| Run build script | VS Code terminal | `./build-rpi-image.sh ...` |
| Git operations | OpenCode or VS Code | Both work via SSH |
| Test features | VS Code terminal | Native Linux execution |
| AI assistance | OpenCode on macOS | Executes commands via SSH |
| Code review | OpenCode on macOS | Reads files via SSH |

## Troubleshooting

### Can't Connect via SSH
```bash
# Test from macOS terminal
ssh linux-dev 'echo "Connected!"'

# Check config
cat ~/.ssh/config | grep -A 5 linux-dev
```

### Files Not Syncing
- No need to sync! Files live on Linux only
- VS Code edits files directly on Linux via SSH
- OpenCode edits files via SSH commands
- Single source of truth: Linux machine

### Build Script Fails
```bash
# Check dependencies
ssh linux-dev 'which qemu-arm-static losetup mount'

# Test sudo access
ssh linux-dev 'sudo losetup --version'

# Check script permissions
ssh linux-dev 'ls -la ~/raspberry-pi-image-builder/build-rpi-image.sh'
```

## Next Steps

1. ✅ Complete sudo configuration (run commands above)
2. ✅ Install build dependencies (qemu, parted, etc.)
3. ✅ Test with a sample image build
4. ✅ Start developing features!

---

**Setup Date:** 2026-01-26  
**OpenCode Session:** Running on macOS  
**Development Target:** linux-dev (192.168.0.101)  
**Repository:** ~/raspberry-pi-image-builder on Linux
