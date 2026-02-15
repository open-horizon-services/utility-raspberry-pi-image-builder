# RPI Card Burner - Project Specification

## Overview
A macOS CLI tool to detect mounted SD cards, select one, burn a Raspberry Pi (or similar) image to it, and inject Cloud Init configuration.

## Technology Choice

**Language**: Python 3.10+ (cross-platform, rich libraries for disk operations, well-tested)

**Why Python**:
- `diskutil` integration via subprocess
- `pyyaml` for Cloud Init config
- `click` or `argparse` for CLI
- Easy to test with `pytest`

**Alternative considered**: Swift (native macOS) - would require more setup and is less portable

---

## Architecture

```
rpi-burner/
├── src/
│   └── rpi_burner/
│       ├── __init__.py
│       ├── cli.py              # CLI entry point
│       ├── disk_detector.py    # Detect mounted cards
│       ├── disk_writer.py      # Burn image to card
│       ├── cloud_init.py       # Inject cloud-init
│       └── models.py           # Data classes
├── tests/
│   ├── test_disk_detector.py
│   ├── test_disk_writer.py
│   └── test_cloud_init.py
├── pyproject.toml
├── README.md
└── AGENTS.md
```

---

## Step-by-Step Implementation Plan

### Step 1: Detect Mounted Memory Cards
**Goal**: List all mounted removable storage devices (SD cards, USB drives)

**Implementation**:
- Use `diskutil list -plist external physical` to get disk info
- Parse plist output to extract:
  - Device identifier (e.g., `/dev/disk4`)
  - Volume name
  - Size
  - File system type
- Filter for removable/ejectable media
- Return list of `Disk` objects

**CLI**: `rpi-burner list`

**Testing**:
- Mock `diskutil` output for unit tests
- Test on real hardware when available

---

### Step 2: User Card Selection
**Goal**: Allow interactive or flag-based card selection

**Implementation**:
- Add `--disk` / `-d` flag for manual selection
- If not provided, show interactive picker (numbered list)
- Display: device path, name, size, filesystem
- Validate selection exists before proceeding

**CLI**: `rpi-burner burn --disk /dev/disk4 image.img`

**Testing**:
- Test invalid disk handling
- Test interactive mode (can mock input)

---

### Step 3: Burn Image to Card
**Goal**: Write .img or .iso file to selected device

**Implementation**:
- Unmount disk first: `diskutil unmountDisk /dev/disk4`
- Use `dd` with progress: `dd if=image.img of=/dev/rdisk4 bs=1m status=progress`
- Verify write (optional: compare checksums)
- Eject after success: `diskutil eject /dev/disk4`

**Safety**:
- **CRITICAL**: Require `--confirm` flag to proceed
- Show warning with device info before burning
- Require typing device path to confirm

**CLI**: `rpi-burner burn -d /dev/disk4 image.img --confirm`

**Testing**:
- Mock `dd` output
- Test with small dummy file
- **NEVER test on real device in CI**

---

### Step 4: Cloud Init Configuration
**Goal**: Add cloud-init files to the burned card's boot partition

**Implementation**:
- Remount card after burning
- Detect boot partition (VFAT/FAT32)
- Write files:
  - `user-data` (cloud-config format)
  - `meta-data` (instance metadata)
  - `network-config` (optional)
- Files go to boot partition root

**Cloud Config Example** (user provides YAML):
```yaml
#cloud-config
hostname: rpi-hostname
ssh_pwauth: true
users:
  - name: pi
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    passwd: "$6$rounds=4096$...hashed..."
runcmd:
  - echo " Raspberry Pi booted" > /home/pi/booted.txt
```

**CLI**: 
- `rpi-burner burn -d /dev/disk4 image.img --cloud-init config.yaml`
- Or prompt for inline config

**Testing**:
- Test YAML parsing
- Test file writing to mock filesystem
- Validate cloud-config structure

---

## Build/Test Commands

```bash
# Setup
python -m venv venv
source venv/bin/activate
pip install -e ".[dev]"

# Run all tests
pytest

# Run single test
pytest tests/test_disk_detector.py::test_list_external_disks

# Lint
ruff check src/
ruff format src/

# Type check
mypy src/
```

---

## Code Style Guidelines

### Imports
```python
# Standard library first, then third-party, then local
import sys
import subprocess
from pathlib import Path
from dataclasses import dataclass

import click
import pyyaml
```

### Naming
- `snake_case` for functions/variables
- `PascalCase` for classes
- `SCREAMING_SNAKE_CASE` for constants

### Types
- Use type hints throughout
- Avoid `Any` unless necessary

### Error Handling
- Use custom exceptions
- Fail fast with clear messages
- Never suppress errors silently

### Documentation
- Docstrings for all public functions
- Google-style docstrings:
```python
def function(param: str) -> bool:
    """Short summary.

    Longer description if needed.

    Args:
        param: Description of param.

    Returns:
        Description of return value.

    Raises:
        ValueError: When something is wrong.
    """
```

---

## Progress Tracking

Each step will be confirmed working before proceeding:
1. [ ] Step 1: Detect mounted cards - **IN PROGRESS**
2. [ ] Step 2: Select a card
3. [ ] Step 3: Burn image to card
4. [ ] Step 4: Add Cloud Init

---

*Last updated: 2026-02-14*
