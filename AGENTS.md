# AGENTS.md - RPI Burner Development Guide

## Project Overview
macOS CLI tool to burn Raspberry Pi images to SD cards with Cloud Init support.

## Technology Stack
- Python 3.10+
- Click (CLI framework)
- Rich (terminal UI)
- PyYAML (cloud-config parsing)
- pytest (testing)

---

## Commands

### Setup
```bash
python -m venv venv
source venv/bin/activate
pip install -e ".[dev]"
```

### Running
```bash
rpi-burner list                    # List removable disks
rpi-burner burn image.img          # Burn with interactive selection
rpi-burner burn image.img -d /dev/disk4  # Specify disk directly
rpi-burner burn image.img --confirm      # Skip confirmation (dangerous)
rpi-burner burn image.img --cloud-init config.yaml  # Add cloud-init
```

### Testing
```bash
pytest                 # Run all tests
pytest -v            # Verbose output
pytest tests/        # Specific directory
pytest tests/test_disk_detector.py::test_list_external_disks_with_sd_card  # Single test
pytest -k "disk"     # Run tests matching "disk"
```

### Linting & Type Checking
```bash
ruff check src/              # Lint
ruff check src/ --fix       # Auto-fix
ruff format src/             # Format
mypy src/                   # Type check
```

---

## Code Style Guidelines

### Imports
Order: standard library → third-party → local
```python
import sys
import subprocess
from pathlib import Path

import click
from rich.console import Console

from rpi_burner.models import Disk
```

### Naming
- Functions/variables: `snake_case`
- Classes: `PascalCase`
- Constants: `SCREAMING_SNAKE_CASE`

### Type Hints
Use type hints throughout. Prefer built-in types over typing module:
```python
def func(path: str) -> list[Disk]:
def func(path: str | None) -> dict[str, int]:
```

### Error Handling
- Use custom exception classes inheriting from Exception
- Fail fast with clear error messages
- Never suppress errors with bare except or pass

### Functions
Keep functions small and focused. One purpose per function.

---

## Project Structure
```
src/rpi_burner/
├── __init__.py      # Package exports
├── cli.py           # CLI entry point
├── models.py        # Data classes (Disk)
├── disk_detector.py # Detect removable disks
├── disk_writer.py   # Write images to disk
└── cloud_init.py    # Cloud-init support
tests/
└── test_disk_detector.py
```

---

## Module Responsibilities

### disk_detector.py
- Uses `diskutil list -plist external physical` to list disks
- Filters for removable/ejectable media
- Returns `Disk` dataclass instances

### disk_writer.py
- Unmounts disk before writing
- Uses `dd` with `bs=1m status=progress`
- Converts `/dev/diskN` to `/dev/rdiskN` for raw writes
- Ejects after successful write

### cloud_init.py
- Finds boot partition (FAT32/MS-DOS)
- Mounts partition
- Writes `user-data` and `meta-data` files

### cli.py
- Uses Click for CLI structure
- Rich for terminal tables/colors
- Prompts for interactive disk selection
- Confirmation required before burning

---

## Testing Strategy

### Unit Tests
- Mock `subprocess.run` calls to diskutil/dd
- Test with plistlib to create mock diskutil output
- Never test actual disk operations in unit tests

### Integration Tests
- None currently (requires real hardware)

### Test File Naming
- `tests/test_<module>.py`

---

## Safety Features

1. **Confirmation Required**: User must type "yes" to confirm
2. **--confirm Flag**: For scripting (use with caution)
3. **Raw Device Warning**: Only works with `/dev/diskN` (not `/dev/rdiskN`)
4. **No Overwrite Protection**: Could overwrite system disks - be careful

---

## Common Tasks

### Adding a New Feature
1. Implement in appropriate module
2. Add to CLI in cli.py if needed
3. Add tests in tests/
4. Run `ruff check src/ --fix` and `pytest`

### Fixing a Bug
1. Write failing test first
2. Fix code until test passes
3. Run full test suite

### Adding CLI Option
1. Add `@click.option()` decorator to command
2. Add parameter to function
3. Use option in function body

---

## Notes for Agents

- This is a macOS-only tool (uses diskutil)
- Requires sudo/root for dd operations
- Be careful with device paths - wrong path = data loss
- Test on real hardware before releasing
- Cloud-init files go on FAT32 boot partition

Last updated: 2026-02-14
