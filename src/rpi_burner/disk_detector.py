"""Detect mounted removable disks on macOS."""
import plistlib
import subprocess
from pathlib import Path

from rpi_burner.models import Disk


class DiskDetectorError(Exception):
    pass


def list_external_disks() -> list[Disk]:
    result = subprocess.run(
        ["diskutil", "list", "-plist", "external", "physical"],
        capture_output=True,
        text=True,
        check=True,
    )

    plist_data = plistlib.loads(result.stdout.encode())

    disks = []
    all_disks_and_partitions = plist_data.get("AllDisksAndPartitions", [])

    for disk_info in all_disks_and_partitions:
        disk_entry = disk_info.get("Disk", {})
        if not disk_entry:
            disk_entry = disk_info

        device_identifier = disk_entry.get("DeviceIdentifier", "")
        if not device_identifier:
            continue

        device_path = f"/dev/{device_identifier}"

        content = disk_entry.get("Content", "")
        size = disk_entry.get("Size", 0)
        removable = disk_entry.get("Removable", False)
        ejectable = disk_entry.get("Ejectable", False)

        volume_name = ""
        partitions = disk_info.get("Partitions", [])
        mount_point = ""
        for partition in partitions:
            vol_name = partition.get("VolumeName", "")
            if vol_name:
                volume_name = vol_name
            part_mount = partition.get("MountPoint", "")
            if part_mount:
                mount_point = part_mount

        if not volume_name and mount_point:
            volume_name = Path(mount_point).name

        file_system = content if content else "Unknown"

        if removable or ejectable or mount_point or partitions:
            disks.append(Disk(
                device_path=device_path,
                volume_name=volume_name,
                size_bytes=size,
                file_system=file_system,
                is_removable=removable,
                is_ejectable=ejectable,
            ))

    return disks


def get_disk_info(device_path: str) -> Disk:
    result = subprocess.run(
        ["diskutil", "info", "-plist", device_path],
        capture_output=True,
        text=True,
        check=True,
    )

    plist_data = plistlib.loads(result.stdout.encode())

    device_identifier = plist_data.get("DeviceIdentifier", "")
    volume_name = plist_data.get("VolumeName", "") or "Untitled"
    size = plist_data.get("Size", 0)
    content = plist_data.get("Content", "")
    removable = plist_data.get("Removable", False)
    ejectable = plist_data.get("Ejectable", False)

    return Disk(
        device_path=f"/dev/{device_identifier}",
        volume_name=volume_name,
        size_bytes=size,
        file_system=content or "Unknown",
        is_removable=removable,
        is_ejectable=ejectable,
    )
