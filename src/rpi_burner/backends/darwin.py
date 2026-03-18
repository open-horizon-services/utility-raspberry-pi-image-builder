"""macOS backend using diskutil and dd."""

import plistlib
import subprocess
import time
from pathlib import Path

from rpi_burner.exceptions import CloudInitError, DiskDetectorError, DiskWriterError
from rpi_burner.models import Disk


class DarwinBackend:
    def list_external_disks(self) -> list[Disk]:
        try:
            result = subprocess.run(
                ["diskutil", "list", "-plist", "external", "physical"],
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError as e:
            raise DiskDetectorError(f"Failed to list disks: {e.stderr}") from e

        plist_data = plistlib.loads(result.stdout.encode())

        disks: list[Disk] = []
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
                disks.append(
                    Disk(
                        device_path=device_path,
                        volume_name=volume_name,
                        size_bytes=size,
                        file_system=file_system,
                        is_removable=removable,
                        is_ejectable=ejectable,
                    )
                )

        return disks

    def get_disk_info(self, device_path: str) -> Disk:
        try:
            result = subprocess.run(
                ["diskutil", "info", "-plist", device_path],
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError as e:
            raise DiskDetectorError(f"Failed to get disk info: {e.stderr}") from e

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

    def unmount_disk(self, device_path: str) -> None:
        try:
            subprocess.run(
                ["diskutil", "unmountDisk", device_path],
                check=True,
                capture_output=True,
                text=True,
            )
        except subprocess.CalledProcessError as e:
            raise DiskWriterError(f"Failed to unmount disk: {e.stderr}") from e

    def burn_image(self, image_path: str, device_path: str, progress: bool = True) -> None:
        image_file = Path(image_path)
        if not image_file.exists():
            raise DiskWriterError(f"Image file not found: {image_path}")

        raw_device = self._get_raw_device(device_path)

        cmd = ["dd", f"if={image_path}", f"of={raw_device}", "bs=1m"]
        if progress:
            cmd.append("status=progress")

        try:
            subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as e:
            raise DiskWriterError(f"Failed to write image: {e}") from e

    def eject_disk(self, device_path: str) -> None:
        try:
            subprocess.run(
                ["diskutil", "eject", device_path],
                check=True,
                capture_output=True,
                text=True,
            )
        except subprocess.CalledProcessError as e:
            raise DiskWriterError(f"Failed to eject disk: {e.stderr}") from e

    def _reread_partition_table(self, device_path: str) -> None:
        """Force a rescan of the partition table on macOS."""
        try:
            subprocess.run(["sync"], check=False)
            subprocess.run(
                ["diskutil", "list", device_path],
                check=False,
                capture_output=True,
                text=True,
            )
            # Give the system a moment to process the rescan
            time.sleep(0.5)
        except Exception:
            # Ignore errors in rescan - best effort
            pass

    def get_boot_partition(self, device_path: str) -> str | None:
        self._reread_partition_table(device_path)
        try:
            result = subprocess.run(
                ["diskutil", "list", "-plist", device_path],
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError:
            return None

        plist_data = plistlib.loads(result.stdout.encode())

        all_disks = plist_data.get("AllDisksAndPartitions", [])
        for disk_info in all_disks:
            partitions = disk_info.get("Partitions", [])
            for partition in partitions:
                content = partition.get("Content", "")
                if content in ("DOS", "FAT32", "msdos", "Windows_FAT_32"):
                    device_id = partition.get("DeviceIdentifier")
                    if device_id:
                        return f"/dev/{device_id}"

        return None

    def mount_partition(self, partition_path: str) -> Path:
        try:
            subprocess.run(
                ["diskutil", "mount", partition_path],
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError:
            pass

        try:
            result = subprocess.run(
                ["diskutil", "info", "-plist", partition_path],
                capture_output=True,
                text=True,
                check=True,
            )
            plist_data = plistlib.loads(result.stdout.encode())
            mount_point = plist_data.get("MountPoint", "")
            if mount_point:
                return Path(mount_point)
        except subprocess.CalledProcessError:
            pass

        raise CloudInitError("Could not determine mount point")

    def write_file(self, path: Path, content: str) -> None:
        try:
            path.write_text(content)
        except OSError as e:
            raise CloudInitError(f"Failed to write {path}: {e}") from e

    @staticmethod
    def _get_raw_device(device_path: str) -> str:
        if device_path.startswith("/dev/r"):
            return device_path
        return device_path.replace("/dev/disk", "/dev/rdisk")
