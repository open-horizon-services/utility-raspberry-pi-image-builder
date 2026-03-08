# AGENTS.md - RPI Burner Development Guide

## Project Overview
macOS-only CLI tool (Python 3.10+) to burn Raspberry Pi images to SD cards with Cloud Init support. Uses `diskutil` and `dd` under the hood — requires sudo for disk operations.

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
- Custom exceptions per module, inheriting from `Exception` (e.g., `DiskDetectorError`, `DiskWriterError`, `CloudInitError`)
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
  disk_detector.py   # diskutil plist parsing -> Disk objects
  disk_writer.py     # dd-based image writing, unmount/eject
  cloud_init.py      # Boot partition detection, cloud-init file injection
tests/
  test_disk_detector.py   # Unit tests with mocked subprocess
```

### Module Pattern
Each module follows: imports -> custom Exception class -> functions.
All subprocess interactions are in dedicated modules (not cli.py).

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
- Never test actual disk operations (dd, diskutil) in unit tests
- No integration tests currently (would require real hardware)

---

## Safety Notes for Agents
- **macOS-only**: All disk operations use `diskutil` (will not work on Linux)
- **Device paths are destructive**: Wrong `/dev/diskN` = data loss. Never hardcode device paths.
- **Subprocess calls need mocking**: Always mock in tests, never call real `diskutil`/`dd`
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
