"""Write disk images to removable storage."""

from rpi_burner.backends import get_backend
from rpi_burner.exceptions import DiskWriterError

__all__ = ["DiskWriterError", "unmount_disk", "burn_image", "eject_disk"]


def unmount_disk(device_path: str) -> None:
    get_backend().unmount_disk(device_path)


def burn_image(image_path: str, device_path: str, progress: bool = True) -> None:
    get_backend().burn_image(image_path, device_path, progress)


def eject_disk(device_path: str) -> None:
    get_backend().eject_disk(device_path)
