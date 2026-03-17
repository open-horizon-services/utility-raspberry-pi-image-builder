"""RPI Burner - burn Raspberry Pi images on macOS and Linux."""

from rpi_burner.cloud_init import (
    generate_meta_data,
    get_boot_partition,
    load_cloud_config,
    load_network_config,
    mount_partition,
    write_cloud_init_files,
)
from rpi_burner.disk_detector import (
    get_disk_info,
    list_external_disks,
)
from rpi_burner.disk_writer import (
    burn_image,
    eject_disk,
    unmount_disk,
)
from rpi_burner.exceptions import (
    CloudInitError,
    DiskDetectorError,
    DiskWriterError,
)
from rpi_burner.models import Disk

__all__ = [
    "Disk",
    "DiskDetectorError",
    "DiskWriterError",
    "CloudInitError",
    "generate_meta_data",
    "load_network_config",
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
