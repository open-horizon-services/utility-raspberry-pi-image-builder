"""RPI Burner - macOS tool to burn Raspberry Pi images."""
from rpi_burner.cloud_init import (
    CloudInitError,
    get_boot_partition,
    load_cloud_config,
    mount_partition,
    write_cloud_init_files,
)
from rpi_burner.disk_detector import (
    DiskDetectorError,
    get_disk_info,
    list_external_disks,
)
from rpi_burner.disk_writer import (
    DiskWriterError,
    burn_image,
    eject_disk,
    unmount_disk,
)
from rpi_burner.models import Disk

__all__ = [
    "Disk",
    "DiskDetectorError",
    "DiskWriterError",
    "CloudInitError",
    "list_external_disks",
    "get_disk_info",
    "burn_image",
    "eject_disk",
    "unmount_disk",
    "get_boot_partition",
    "load_cloud_config",
    "mount_partition",
    "write_cloud_init_files",
]
