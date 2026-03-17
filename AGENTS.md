# AGENTS.md - RPI Burner Development Guide

## Project Overview
Cross-platform CLI tool (Python 3.10+, macOS and Linux) to burn Raspberry Pi images to SD cards with Cloud Init support. Uses platform-specific backends (`diskutil`/`dd` on macOS, `lsblk`/`dd`/`umount`/`mount` on Linux). On Linux, privileged commands are automatically elevated via `sudo`. On macOS, the tool must be run under `sudo`.

## Technology Stack
- **Python 3.10+** (minimum, uses `X | Y` union syntax)
- **Click** (CLI framework), **Rich** (terminal UI), **PyYAML** (cloud-config)
- **pytest** + **pytest-mock** (testing), **ruff** (lint/format), **mypy** (type checking)

---

## Commands

### Setup
```bash
python -m venv venv && source venv/bin/activate
pip install -e ".[dev]"
```

### Running
```bash
rpi-burner list                                    # List removable disks
rpi-burner burn image.img                          # Interactive disk selection
rpi-burner burn image.img -d /dev/disk4            # Specify disk
rpi-burner burn image.img --confirm                # Skip confirmation
rpi-burner burn image.img --cloud-init config.yaml # With cloud-init
rpi-burner burn image.img --cloud-init config.yaml --network-config network.yaml  # With custom network
rpi-burner burn image.img --cloud-init config.yaml --wpa-supplicant wpa_supplicant.conf  # With WiFi
```

### Testing
```bash
pytest                    # All tests
pytest -v                 # Verbose
pytest tests/test_disk_detector.py                                          # Single file
pytest tests/test_disk_detector.py::test_list_external_disks_with_sd_card   # Single test
pytest -k "disk"          # Pattern match
```

### Linting & Type Checking
```bash
ruff check src/           # Lint
ruff check src/ --fix     # Auto-fix
ruff format src/          # Format
mypy src/                 # Type check
```

---

## Code Style

### Ruff Configuration (from pyproject.toml)
- **Line length**: 100
- **Target**: Python 3.10
- **Rules**: `E` (pycodestyle), `F` (pyflakes), `W` (warnings), `I` (isort), `N` (pep8-naming), `UP` (pyupgrade), `B` (bugbear), `C4` (comprehensions)

### Mypy Configuration
- **Strict mode** enabled (`strict = true`)
- `disallow_untyped_defs = false` (untyped defs are allowed)
- `warn_return_any = true`, `warn_unused_configs = true`

### Imports
Order enforced by ruff (`I` rule): stdlib -> third-party -> local, separated by blank lines.
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
Use modern Python 3.10+ syntax everywhere. No `typing` module imports for basic types:
```python
def func(path: str) -> list[Disk]:     # not List[Disk]
def func(path: str | None) -> None:    # not Optional[str]
```

### Error Handling
- Custom exceptions centralized in `exceptions.py`, inheriting from `Exception` (e.g., `DiskDetectorError`, `DiskWriterError`, `CloudInitError`)
- Re-raise with `from e` to preserve tracebacks: `raise FooError("msg") from e`
- Fail fast with clear messages. Never use bare `except` or empty `except: pass`

### Docstrings
- Module-level docstring on every file (one-line `"""Description."""`)
- Public functions get docstrings. Internal helpers may omit them.
- Style: short imperative summary. Multi-line when needed.

### Functions
Small and focused. One responsibility per function. Subprocess calls wrapped in try/except with custom errors.

---

## Project Structure
```
src/rpi_burner/
  __init__.py        # Public API re-exports with __all__
  cli.py             # Click CLI entry point + Rich terminal UI
  models.py          # Disk dataclass
  exceptions.py      # Centralized custom exceptions (DiskDetectorError, DiskWriterError, CloudInitError)
  disk_detector.py   # Thin delegate -> backends for disk listing/info
  disk_writer.py     # Thin delegate -> backends for burn/unmount/eject
  cloud_init.py      # Cloud-init loading (preserves #cloud-config header, generates meta-data with instance-id, default network-config, auto-injects keyboard layout, supports WPA supplicant for WiFi) + delegates boot partition/mount/file writes to backends
  backends/
    __init__.py      # get_backend() factory — selects DarwinBackend or LinuxBackend by sys.platform
    base.py          # PlatformBackend Protocol — interface all backends implement
    darwin.py        # macOS backend (diskutil plist parsing, dd, diskutil mount/eject, direct file writes)
    linux.py         # Linux backend (lsblk JSON parsing, dd, umount/mount, eject/udisksctl, file writes via sudo tee) — auto-elevates via sudo, re-reads partition table + udevadm settle after burn
tests/
  test_disk_detector.py   # Unit tests for macOS disk detection with mocked subprocess
  test_backend_linux.py   # Unit tests for Linux backend with mocked subprocess
  test_cloud_init.py      # Unit tests for cloud-init loading and file writing
```

### Module Pattern
Top-level modules (`disk_detector.py`, `disk_writer.py`, `cloud_init.py`) are thin delegates that call `get_backend()` and forward to the platform-specific backend. All subprocess interactions live in `backends/darwin.py` and `backends/linux.py` — never in `cli.py` or the delegate modules.

Custom exceptions are centralized in `exceptions.py` and re-exported from the delegate modules for backward compatibility.

---

## Testing Patterns

### Mocking subprocess
All tests mock `subprocess.run` since real disk operations are unsafe:
```python
from unittest.mock import patch, MagicMock

mock_result = MagicMock()
mock_result.stdout = mock_plist_string
with patch("subprocess.run", return_value=mock_result):
    result = function_under_test()
```

### Test helpers
`create_mock_diskutil_plist()` builds valid plist XML from dicts for disk detection tests.

### Test naming
- Files: `tests/test_<module>.py`
- Functions: `test_<what_it_tests>` (plain functions, no classes)

### What NOT to test
- Never test actual disk operations (dd, diskutil, lsblk) in unit tests
- No integration tests currently (would require real hardware)

---

## Safety Notes for Agents
- **Cross-platform**: macOS uses `diskutil`/`dd`, Linux uses `lsblk`/`dd`/`umount`/`mount`. Platform detected at runtime via `get_backend()`.
- **Device paths are destructive**: Wrong `/dev/diskN` (macOS) or `/dev/sdX` (Linux) = data loss. Never hardcode device paths.
- **Subprocess calls need mocking**: Always mock in tests, never call real `diskutil`/`dd`/`lsblk`
- Cloud-init files target FAT32 boot partitions specifically

---

## Common Workflows

### Adding a new feature
1. Implement in the appropriate module (not cli.py for logic)
2. Add CLI surface in cli.py if user-facing
3. Add tests in `tests/test_<module>.py`
4. Verify: `ruff check src/ --fix && ruff format src/ && mypy src/ && pytest`

### Fixing a bug
1. Write a failing test first
2. Fix minimally until test passes
3. Run full suite: `pytest`

### Adding a CLI option
1. Add `@click.option()` to the command in cli.py
2. Add corresponding parameter to the function signature
3. Use `str | None` for optional string params, not `Optional[str]`
