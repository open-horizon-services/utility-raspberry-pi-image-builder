"""Platform backend selection."""

import sys

from rpi_burner.backends.base import PlatformBackend


def get_backend() -> PlatformBackend:
    if sys.platform == "darwin":
        from rpi_burner.backends.darwin import DarwinBackend

        return DarwinBackend()
    elif sys.platform == "linux":
        from rpi_burner.backends.linux import LinuxBackend

        return LinuxBackend()
    else:
        raise RuntimeError(f"Unsupported platform: {sys.platform}")
