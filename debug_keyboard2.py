#!/usr/bin/env python3

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "src"))

from rpi_burner.cloud_init import load_cloud_config, detect_keyboard_layout
import tempfile

print(f"detect_keyboard_layout function: {detect_keyboard_layout}")
print(f"detect_keyboard_layout result: '{detect_keyboard_layout()}'")

# Test with a simple config
config_content = """#cloud-config
hostname: test
"""

with tempfile.NamedTemporaryFile(mode="w", suffix=".yaml", delete=False) as f:
    f.write(config_content)
    config_path = Path(f.name)

try:
    result = load_cloud_config(config_path)
    print("\nResult:")
    print(repr(result))
    print("\nFormatted result:")
    print(result)

    # Check for keyboard
    if "keyboard:" in result:
        print("\n✓ Keyboard section FOUND")
    else:
        print("\n✗ Keyboard section NOT FOUND")

finally:
    config_path.unlink()
