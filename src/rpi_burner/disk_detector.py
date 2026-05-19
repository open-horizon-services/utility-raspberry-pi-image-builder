"""Detect mounted removable disks."""

from rpi_burner.backends import get_backend
from rpi_burner.exceptions import DiskDetectorError
from rpi_burner.models import Disk

__all__ = ["DiskDetectorError", "list_external_disks", "get_disk_info"]


def list_external_disks() -> list[Disk]:
    return get_backend().list_external_disks()


def get_disk_info(device_path: str) -> Disk:
    return get_backend().get_disk_info(device_path)
